//
//  LaunchHelper.m
//  LaunchHelper
//

#include <objc/runtime.h>
#include <objc/message.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdlib.h>
#include <ctype.h>

#import "LaunchHelper.h"
#define LAUNCH_HELPER_PORT 30000
#define BUFSIZE 256

bool Debug_ = true;
bool Engineer_ = false;

NSMutableArray * sbIcons;
NSArray * allApps;
BOOL isSpringBoard;
NSMutableDictionary * prefs;
NSMutableArray *launchieNames;
NSMutableArray *matches;
NSMutableDictionary *launchieDetailsByName;
LaunchHelper *lhelper;
LaunchHelperRelay *relay;

#define WBPrefix "lh_"
void LaunchHelperInject(const char *classname, const char *oldname, IMP newimp, const char *type) {
    Class _class = objc_getClass(classname);
    if (_class == nil)
        return;
    if (!class_addMethod(_class, sel_registerName(oldname), newimp, type))
        NSLog(@"WB:Error: failed to inject [%s %s]", classname, oldname);
    
    NSLog([NSString stringWithFormat:@"injected %s successfully!", oldname]);
}

void LaunchHelperRename(bool instance, const char *classname, const char *oldname, IMP newimp) {
    NSLog(@"Renaming %s::%s", classname, oldname);
    Class _class = objc_getClass(classname);
    if (_class == nil) {
        if (Debug_)
            NSLog(@"WB:Warning: cannot find class [%s]", classname);
        return;
    }
    if (!instance)
        _class = object_getClass(_class);
    Method method = class_getInstanceMethod(_class, sel_getUid(oldname));
    if (method == nil) {
        if (Debug_)
            NSLog(@"WB:Warning: cannot find method [%s %s]", classname, oldname);
        return;
    }
    size_t namelen = strlen(oldname);
    char newname[sizeof(WBPrefix) + namelen];
    memcpy(newname, WBPrefix, sizeof(WBPrefix) - 1);
    memcpy(newname + sizeof(WBPrefix) - 1, oldname, namelen + 1);
    const char *type = method_getTypeEncoding(method);
    if (!class_addMethod(_class, sel_registerName(newname), method_getImplementation(method), type))
        NSLog(@"WB:Error: failed to rename [%s %s]", classname, oldname);
    unsigned int count;
    Method *methods = class_copyMethodList(_class, &count);
    unsigned int index;
    for (index = 0; index != count; ++index)
        if (methods[index] == method)
            goto found;
    if (newimp != NULL)
        if (!class_addMethod(_class, sel_getUid(oldname), newimp, type))
            NSLog(@"WB:Error: failed to rename [%s %s]", classname, oldname);
    goto done;
found:
    if (newimp != NULL)
        method_setImplementation(method, newimp);
    NSLog(@"Rename success");
done:
    free(methods);
}

static void LaunchHelper_uiapplication_specialLaunchApp(id self, SEL sel, NSString *identifier) {
    [relay sendAppForLaunch:identifier];
}

@class SBApplication;
@class SBUIController;

__attribute__((constructor))
static void LaunchHelperInitializer()
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    NSLog(@"LaunchHelper.dylib: The main injection constructor called");
    
    lhelper = nil;
    relay = nil;
    
    NSString *appId = [[NSBundle mainBundle] bundleIdentifier];
    if ([appId hasSuffix: @"springboard"]) { 
        isSpringBoard = YES;
        lhelper = [[LaunchHelper alloc] init];
        [lhelper performSelectorOnMainThread: @selector(didInjectIntoProgram) withObject: nil waitUntilDone: NO];
    } else {
        isSpringBoard = NO;
        LaunchHelperInject("UIApplication", "specialLaunchApp:", (IMP)&LaunchHelper_uiapplication_specialLaunchApp, "");
        
        relay = [[LaunchHelperRelay alloc] init];
        [relay performSelectorOnMainThread: @selector(didInjectIntoProgram) withObject: nil waitUntilDone: NO];
    } 
    
    [pool release]; 
}

@implementation LaunchHelper

- (void) didInjectIntoProgram {
    [self performSelector: @selector(inject) withObject: nil afterDelay: 0.1];
}

- (void) inject {
    NSLog(@"LaunchHelper initializing");
    [self listenForRelayConnections];
}

static void relayDataCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    NSLog ([NSString stringWithFormat:@" received data!"]);
    NSData * d = (NSData *) data;
    if ([d length] == BUFSIZE) {
        char *buf = (char *) [d bytes];
        NSString *str = [NSString stringWithFormat:@"%s", buf];

        Class SBUIController = objc_getClass("SBUIController");
        id uiController = [SBUIController sharedInstance];
        [uiController quitTopApplication];

        Class SBApplicationController = objc_getClass("SBApplicationController");
        id appController = [SBApplicationController sharedInstance];
        NSArray *apps = [appController applicationsWithBundleIdentifier:str];
        if ([apps count] > 0) { 
            [lhelper performSelector:@selector(launchTheApp:) withObject:[apps objectAtIndex:0] afterDelay: 0.1];
        } 
    }
}

- (void) launchTheApp:(id) app {
    NSLog ([NSString stringWithFormat:@"launching now! %@", [app bundleIdentifier]]);
    Class SBUIController = objc_getClass("SBUIController");
    id uiController = [SBUIController sharedInstance];
    [uiController animateLaunchApplication:app];
}

- (void) listenForRelayConnections {
    CFSocketContext ctx = {0, self, NULL, NULL, NULL};
    CFSocketRef sock = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_DGRAM, 
                                      IPPROTO_UDP, kCFSocketDataCallBack, (CFSocketCallBack)&relayDataCallBack, &ctx);
    if (!sock) { NSLog(@"LaunchHelper: Failed to create listen socket"); return; }
    struct sockaddr_in addr4;
    memset(&addr4, 0, sizeof(addr4));
    addr4.sin_len = sizeof(addr4);
    addr4.sin_family = AF_INET;
    addr4.sin_port = htons(LAUNCH_HELPER_PORT);
    addr4.sin_addr.s_addr = inet_addr("127.0.0.1");
    NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];

    CFSocketError err;
    if ((err = CFSocketSetAddress(sock, (CFDataRef)address4)) != kCFSocketSuccess) {
        NSLog(@"LaunchHelper: Failed to bind socket to port: error=%@", strerror(errno));
        CFRelease(sock);
        return;
    }

    CFRunLoopRef cfrl = CFRunLoopGetCurrent();
    CFRunLoopSourceRef source4 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, sock, 0);
    CFRunLoopAddSource(cfrl, source4, kCFRunLoopCommonModes);
    CFRelease(source4);
    NSLog(@"created socket and bound successfully!");
}

@end

@implementation LaunchHelperRelay

- (void) didInjectIntoProgram {
    [self performSelector: @selector(inject) withObject: nil afterDelay: 0.1];
}

- (void) inject {
    NSLog(@"LaunchHelperRelay inject initializing");
    sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_len = sizeof(struct sockaddr_in);
    serverAddr.sin_port = htons(LAUNCH_HELPER_PORT);
    serverAddr.sin_addr.s_addr = inet_addr("127.0.0.1");
}

- (void) sendAppForLaunch:(NSString *) appId {
    char buf[BUFSIZE];
    for (int i = 0; i < BUFSIZE; i++) { 
        buf [i] = '\0';
    }
    strncpy (buf, [appId UTF8String], sizeof (buf));
    NSLog([NSString stringWithFormat:@"sending string: %s", buf]);
    sendto(sock, &buf, BUFSIZE, 0, (struct sockaddr *) &serverAddr, sizeof(struct sockaddr_in));
}
@end

