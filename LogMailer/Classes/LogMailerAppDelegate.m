//
//  LogMailerAppDelegate.m
//  LogMailer
//
//  Created by Ashwin Bharambe on 10/4/08.
//  Copyright Buxfer, Inc. 2008. All rights reserved.
//

#import "LogMailerAppDelegate.h"
#import "RootViewController.h"


@implementation LogMailerAppDelegate

@synthesize window;
@synthesize navigationController;


- (void)applicationDidFinishLaunching:(UIApplication *)application {
	
	// Configure and show the window
	[window addSubview:[navigationController view]];
	[window makeKeyAndVisible];
}


- (void)applicationWillTerminate:(UIApplication *)application {
	// Save data if appropriate
}


- (void)dealloc {
	[navigationController release];
	[window release];
	[super dealloc];
}

@end
