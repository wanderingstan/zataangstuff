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

// OPTIONS
bool vibrusEnabled;
bool dialPadEnabled;
bool kbEnabled;
int intensity;
int duration;

extern void * _CTServerConnectionCreate(CFAllocatorRef, int (*)(void *, CFStringRef, CFDictionaryRef, void *), int *);
extern int _CTServerConnectionSetVibratorState(int *, void *, int, int, float, float, float);

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
    _CTServerConnectionSetVibratorState(&x, connection, 3, intensity, 1000.0, 1000.0, 1000.0);
}

static void stop_vib () {
    usleep(duration);
    _CTServerConnectionSetVibratorState(&x, connection, 0, 0, 0, 0, 0);
}

static void __haptic_uikeyboardimpl_addInputString (id<RenamedMethods> self, SEL sel, id string) {
    start_vib ();
    [self hk_addInputString:string];
    stop_vib ();
}

static void __haptic_uikeyboardimpl_deleteFromInput (id<RenamedMethods> self, SEL sel) {
    start_vib ();
    [self hk_deleteFromInput];
    stop_vib ();
}

static void __haptic_dialercontroller_phonePad_appendString (id<RenamedMethods> self, SEL sel, id fp8, id fp12) {
    start_vib ();
    [self hk_phonePad:fp8 appendString:fp12];
    stop_vib ();
}

static void __haptic_dialercontroller_phonePadDeleteLastDigit (id<RenamedMethods> self, SEL sel, id fp8) {
    start_vib ();
    [self hk_phonePadDeleteLastDigit:fp8];
    stop_vib ();
}

@class SBApplication;
@class SBUIController;

__attribute__((constructor))
static void HapticKeyboardInitializer()
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    haptic = nil;

    vibrusEnabled = YES;
    dialPadEnabled = YES;
    kbEnabled = YES;
    intensity = 2;
    duration = 50000;

    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/vibrus.plist"];
    if (prefs) { 
        vibrusEnabled = [[prefs objectForKey:@"vibrusEnabled"] integerValue];
        kbEnabled = [[prefs objectForKey:@"kbEnabled"] integerValue];
        dialPadEnabled = [[prefs objectForKey:@"dialPadEnabled"] integerValue];
        duration = [[prefs objectForKey:@"duration"] integerValue];
        intensity = [[prefs objectForKey:@"intensity"] integerValue];
    }

    if (!vibrusEnabled)
        return;
    
    NSString *appId = [[NSBundle mainBundle] bundleIdentifier];
    haptic = [[HapticKeyboard alloc] init];
    [haptic performSelectorOnMainThread: @selector(didInjectIntoProgram) withObject: nil waitUntilDone: NO];

    if (kbEnabled) {
        MyRename(YES, "UIKeyboardImpl", @selector(addInputString:), (IMP)&__haptic_uikeyboardimpl_addInputString);
        MyRename(YES, "UIKeyboardImpl", @selector(deleteFromInput), (IMP)&__haptic_uikeyboardimpl_deleteFromInput);
    }

    if (dialPadEnabled && [appId isEqual:@"com.apple.mobilephone"]) { 
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

