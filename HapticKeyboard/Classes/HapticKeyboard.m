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
- (void) hk_setInputString:(id) string;
- (BOOL) hk_acceptInputString:(id) string;
@end 

static void __haptic_uikeyboardimpl_addInputString (id<RenamedMethods> self, SEL sel, id string) {
    // [[UIApplication sharedApplication] vibrateForDuration:1000];
    // AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
    [self hk_addInputString:string];
    int intensity = 1;
    [haptic performSelector:@selector(shutoff) withObject:nil afterDelay:0.1];
    _CTServerConnectionSetVibratorState(&x, connection, 3, intensity, 1, 1, 1);
}

static void __haptic_uikeyboardimpl_setInputString (id<RenamedMethods> self, SEL sel, id string) {
    // NSLog ([NSString stringWithFormat:@"setInputString called [%@]", string]);
    [self hk_setInputString:string];
}

static bool __haptic_uikeyboardimpl_acceptInputString (id<RenamedMethods> self, SEL sel, id string) {
    // NSLog ([NSString stringWithFormat:@"acceptInputString here [%@]", string]);
    return [self hk_acceptInputString:string];
}

@class SBApplication;
@class SBUIController;

__attribute__((constructor))
static void HapticKeyboardInitializer()
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    haptic = nil;
    
    NSString *appId = [[NSBundle mainBundle] bundleIdentifier];
    haptic = [[HapticKeyboard alloc] init];
    [haptic performSelectorOnMainThread: @selector(didInjectIntoProgram) withObject: nil waitUntilDone: NO];
    MyRename(YES, "UIKeyboardImpl", @selector(addInputString:), (IMP)&__haptic_uikeyboardimpl_addInputString);
    // MyRename(YES, "UIKeyboardImpl", @selector(setInputString:), (IMP)&__haptic_uikeyboardimpl_setInputString);
    // MyRename(YES, "UIKeyboardImpl", @selector(acceptInputString:), (IMP)&__haptic_uikeyboardimpl_acceptInputString);
        
    [pool release]; 
}

@implementation HapticKeyboard

- (void) didInjectIntoProgram {
    [self performSelector: @selector(inject) withObject: nil afterDelay: 0.1];
}

int vibratecallback(void *connection, CFStringRef string, CFDictionaryRef dictionary, void *data) {
    return 0;
}

- (void) shutoff { 
    NSLog ([NSString stringWithFormat:@"shutoff called!"]);
    _CTServerConnectionSetVibratorState(&x, connection, 0, 0, 0, 0, 0);
}

- (void) inject {
    NSLog(@"HapticKeyboard initializing");
    connection = _CTServerConnectionCreate(kCFAllocatorDefault, &vibratecallback, &x);
}

@end

