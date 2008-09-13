//
//  LaunchHelper.h
//  LaunchHelper
//

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>

NSBundle * myBundle;

@interface LaunchHelper : NSObject {
    bool isDisplaying;
}

- (void) didInjectIntoProgram;
- (void) listenForRelayConnections;
- (void) launchTheApp:(id) app;

@end

@interface LaunchHelperRelay : NSObject { 
    int sock;
    struct sockaddr_in serverAddr;
}
- (void) sendAppForLaunch:(NSString *) appId;

@end
