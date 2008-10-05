//
//  LogMailerAppDelegate.h
//  LogMailer
//
//  Created by Ashwin Bharambe on 10/4/08.
//  Copyright Buxfer, Inc. 2008. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LogMailerAppDelegate : NSObject <UIApplicationDelegate> {
    
    UIWindow *window;
    UINavigationController *navigationController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;

@end

