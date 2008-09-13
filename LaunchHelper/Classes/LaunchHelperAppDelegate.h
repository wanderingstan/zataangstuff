//
//  LaunchHelperAppDelegate.h
//  LaunchHelper
//

#import <UIKit/UIKit.h>

@class LaunchHelperViewController;

@interface LaunchHelperAppDelegate : NSObject <UIApplicationDelegate> {
	IBOutlet UIWindow *window;
}

@property (nonatomic, retain) UIWindow *window;

@end

