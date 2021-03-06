//
//  HapticKeyboard.m
//  HapticKeyboard
//

#include <objc/runtime.h>
#include <objc/message.h>
#include <stdlib.h>
#include <ctype.h>
#include "substrate.h"
#import <AudioToolbox/AudioServices.h>

#import "HapticKeyboard.h"
#define RenamePrefix "hk_"

extern void * _CTServerConnectionCreate(CFAllocatorRef, int (*)(void *, CFStringRef, CFDictionaryRef, void *), int *);
extern int _CTServerConnectionSetVibratorState(int *, void *, int, int, float, float, float);
extern int _CTSetVibratorState(int *, int, int, float, float, float);

static void* connection = nil;
static int x = 0;
bool Debug_ = true;
bool Engineer_ = false;

void MyInject(const char *classname, const char *oldname, IMP newimp, const char *type) {
    Class _class = objc_getClass(classname);
    if (_class == nil)
        return;
    if (!class_addMethod(_class, sel_registerName(oldname), newimp, type))
        NSLog(@"WB:Error: failed to inject [%s %s]", classname, oldname);
}       

void MyRename(bool instance, const char *name, SEL sel, IMP newimp) {
    NSLog(@"Renaming %s::%@", name, NSStringFromSelector(sel));
    Class _class = objc_getClass(name);
    if (_class == nil) {
        if (Debug_)
            NSLog(@"WB:Warning: cannot find class [%s]", name);
        return;
    }   
    if (!instance)
        _class = object_getClass(_class);
    MSHookMessage(_class, sel, newimp, RenamePrefix);
    NSLog ([NSString stringWithFormat:@"rename success"]);
}   
BOOL isSpringBoard;
HapticKeyboard *haptic;

@protocol RenamedMethods 
- (void) hk_addInputString:(id) string;
- (void) hk_deleteFromInput;
- (void) hk_phonePad:(id)fp8 appendString:(id)fp12;
- (void) hk_phonePadDeleteLastDigit:(id) fp8;
@end 

static void start_vib () {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/vibrus.plist"];
    int intensity = (prefs ? [[prefs objectForKey:@"intensity"] integerValue] : 2);
//      NSLog(@"INTENSITY: %i", intensity);
//      int intensity = 10;
    if (!prefs || [[prefs objectForKey:@"vibrusEnabled"] integerValue]) {
        _CTServerConnectionSetVibratorState(&x, connection, 3, intensity, 0, 0, 0);
        // _CTSetVibratorState(&x, 3, intensity, 0, 0, 0);
    }
}

static void stop_vib () {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/vibrus.plist"];
    int duration = [[prefs objectForKey:@"duration"] integerValue];
//      NSLog(@"DURATION: %i", duration);
    if (!prefs || [[prefs objectForKey:@"vibrusEnabled"] integerValue])
    {
        usleep(duration);
        _CTServerConnectionSetVibratorState(&x, connection, 0, 0, 0, 0, 0);
    }
}

bool pwn_low_level_stuff = FALSE;

static void __haptic_uikeyboardimpl_addInputString (id<RenamedMethods> self, SEL sel, id string) {
    if (pwn_low_level_stuff) { 
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
        [self hk_addInputString:string];
        return;
    }

    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/vibrus.plist"];
    BOOL kbEnabled = (prefs ? [[prefs objectForKey:@"kbEnabled"] integerValue] : YES);
    if (kbEnabled)
        start_vib ();
    [self hk_addInputString:string];
    if (kbEnabled)
        stop_vib ();
}

static void __haptic_uikeyboardimpl_deleteFromInput (id<RenamedMethods> self, SEL sel) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/vibrus.plist"];
    BOOL kbEnabled = (prefs ? [[prefs objectForKey:@"kbEnabled"] integerValue] : YES);
    if (kbEnabled)
        start_vib ();
    [self hk_deleteFromInput];
    if (kbEnabled)
        stop_vib ();
}

static void __haptic_dialercontroller_phonePad_appendString (id<RenamedMethods> self, SEL sel, id fp8, id fp12) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/vibrus.plist"];
    BOOL dialPadEnabled = (prefs ? [[prefs objectForKey:@"dialPadEnabled"] integerValue] : YES);
    if (dialPadEnabled)
        start_vib ();
    [self hk_phonePad:fp8 appendString:fp12];
    if (dialPadEnabled)
        stop_vib ();
}

static void __haptic_dialercontroller_phonePadDeleteLastDigit (id<RenamedMethods> self, SEL sel, id fp8) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/vibrus.plist"];
    BOOL dialPadEnabled = (prefs ? [[prefs objectForKey:@"dialPadEnabled"] integerValue] : YES);
    if (dialPadEnabled)
        start_vib ();
    [self hk_phonePadDeleteLastDigit:fp8];
    if (dialPadEnabled)
        stop_vib ();
}

@class SBApplication;
@class SBUIController;

/*
MSHook(int, _CTServerConnectionSetVibratorState,
           int *x,
           void *connection,
           int first,
           int second,
           float f_one,
           float f_two,
           float f_three) 
{
    NSLog ([NSString stringWithFormat:@"first=%d second=%d f_one=%f f_two=%f f_three=%f", first, second, f_one, f_two, f_three]);
    int v = __CTServerConnectionSetVibratorState(x, connection, first, second, f_one, f_two, f_three);
    NSLog ([NSString stringWithFormat:@"after call: x=%d", x]);
    return v;
}
*/

__attribute__((constructor))
static void HapticKeyboardInitializer()
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    haptic = nil;
    
    NSString *appId = [[NSBundle mainBundle] bundleIdentifier];
    haptic = [[HapticKeyboard alloc] init];
    [haptic performSelectorOnMainThread: @selector(didInjectIntoProgram) withObject: nil waitUntilDone: NO];
    MyRename(YES, "UIKeyboardImpl", @selector(addInputString:), (IMP)&__haptic_uikeyboardimpl_addInputString);
    MyRename(YES, "UIKeyboardImpl", @selector(deleteFromInput), (IMP)&__haptic_uikeyboardimpl_deleteFromInput);

    /*
    if (pwn_low_level_stuff) { 
        MSHookFunction(&_CTServerConnectionSetVibratorState, &$_CTServerConnectionSetVibratorState, &__CTServerConnectionSetVibratorState);
    }
*/

    if ([appId isEqual:@"com.apple.mobilephone"]) { 
        MyRename(YES, "DialerController", @selector(phonePad:appendString:), (IMP)&__haptic_dialercontroller_phonePad_appendString);
        MyRename(YES, "DialerController", @selector(phonePadDeleteLastDigit:), (IMP)&__haptic_dialercontroller_phonePadDeleteLastDigit);
    }

    [pool release]; 
}

@implementation HapticKeyboard

- (void) didInjectIntoProgram {
    [self performSelector: @selector(inject) withObject: nil afterDelay: 0.1];
}

int vibratecallback(void *connection, CFStringRef string, CFDictionaryRef dictionary, void *data) {
    NSLog ([NSString stringWithFormat:@"vibrate callback: string:%@ dictionary:%@", string, dictionary]);
    return 0;
}

/*
- (void) setShutoffTimer { 
    NSLog ([NSString stringWithFormat:@"setShutoffTimer called!"]);
    [self performSelector: @selector(shutoff) withObject: nil afterDelay: 0.1];
}

- (void) shutoff { 
    NSLog ([NSString stringWithFormat:@"shutoff called!"]);
    _CTServerConnectionSetVibratorState(&x, connection, 0, 0, 0, 0, 0);
}
*/

- (void) inject {
    NSLog(@"HapticKeyboard initializing");
    connection = _CTServerConnectionCreate(kCFAllocatorDefault, &vibratecallback, &x);
}

@end

