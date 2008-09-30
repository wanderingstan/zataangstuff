//
//  VibrusAppDelegate.m
//  Vibrus
//
//  Created by Youssef Francis on 9/30/08.
//  Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import "VibrusAppDelegate.h"
#import "RootViewController.h"


@implementation VibrusAppDelegate

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
