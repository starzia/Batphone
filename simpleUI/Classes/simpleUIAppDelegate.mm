//
//  simpleUIAppDelegate.m
//  simpleUI
//
//  Created by Stephen Tarzia on 9/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import "simpleUIAppDelegate.h"
#import "Fingerprinter.h"
#import <iostream>
#include <unistd.h>

using namespace std;


@implementation simpleUIAppDelegate

@synthesize window;
@synthesize label;
@synthesize button;
@synthesize plot;


- (void) printFingerprint: (Fingerprint*) fingerprint{
	for( unsigned int i=0; i<Fingerprinter::fpLength; ++i ){
		cout << (*fingerprint)[i] << ' ';
	}
	// just print first number in fingerprint vector
    [label setText:[[NSString alloc] initWithFormat:@"%10.0f",(*fingerprint)[0]]];
	cout << endl;
}


-(void)test{	
	// record a new fingerprint using the microphone
	Fingerprint* observed = fp.recordFingerprint();
	cout << "Newly observed fingerprint:" <<endl;
	[self printFingerprint:observed];
}

-(void) buttonHandler:(id)sender{
	// run fingerprinter
	[self test];
}

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    // Override point for customization after application launch.
	
	// screen width / 2 - label width / 2
    CGFloat x = 320/2 - 120/2;
    // screen height / 2 - label height / 2
    CGFloat y = 480/2 - 45/2;
    CGRect labelRect = CGRectMake(x , y-80, 120.0f, 45.0f);

    // Create the label.
    self.label = [[[UILabel alloc] initWithFrame:labelRect] autorelease];
    // Set the value of our string
    [label setText:@"Hello World!"];
    // Center Align the label's text
    [label setTextAlignment:UITextAlignmentCenter];

	// Add the label to the window.
	[window addSubview:label];
	
	// Add button to the window
	button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[button addTarget:self action:@selector(buttonHandler:) forControlEvents:UIControlEventTouchUpInside];
	[button setTitle:@"get fingerprint" forState:UIControlStateNormal];
	button.frame = CGRectMake(80.0, 60.0, 160.0, 40.0);
	[window addSubview:button];
	
	// Add plot to window
	CGRect plotRect = CGRectMake(10, 270, 300.0f, 200.0f);
	self.plot = [[[plotView alloc] initWithFrame:plotRect] autorelease];
	[window addSubview:plot];
	
	// update view
    [window makeKeyAndVisible];
	
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}


- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
}


#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
}


- (void)dealloc {
    [window release];
	[label release];
	[button release];
    [super dealloc];
}


@end
