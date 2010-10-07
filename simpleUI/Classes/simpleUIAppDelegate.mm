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
@synthesize saveButton;
@synthesize startButton;
@synthesize plot;
@synthesize plotOld;
@synthesize plotTimer;
@synthesize newFingerprint;
@synthesize oldFingerprint;
@synthesize fp;


- (void) printFingerprint: (Fingerprint*) fingerprint{
	for( unsigned int i=0; i<Fingerprinter::fpLength; ++i ){
		cout << (*fingerprint)[i] << ' ';
	}
	// just print first number in fingerprint vector
    [label setText:[[NSString alloc] initWithFormat:@"%10.0f",(*fingerprint)[0]]];
	cout << endl;
}


/* called by button */
-(void) saveButtonHandler:(id)sender{
	// get the current fingerprint and save to "Old" slot
	self.fp->getFingerprint( self.oldFingerprint );
	[self.plotOld setNeedsDisplay];
}

-(void) startButtonHandler:(id)sender{
	// record a new fingerprint using the microphone
	self.fp->startRecording();
	[self.startButton setEnabled:NO];
}

/* called by timer */
-(void) updatePlot{
	// get the current fingerprint and save to "New" slot
	self.fp->getFingerprint( self.newFingerprint );
	[self.plot setNeedsDisplay];	
}

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    // Override point for customization after application launch.
	
	self.fp = new Fingerprinter();
	
	// screen width / 2 - label width / 2
    CGFloat x = 320/2 - 300/2;
    // screen height / 2 - label height / 2
    CGFloat y = 480/2 - 45/2;
    CGRect labelRect = CGRectMake(x , y-120, 300.0f, 45.0f);

    // Create the label.
    self.label = [[[UILabel alloc] initWithFrame:labelRect] autorelease];
    // Set the value of our string
    [label setText:@"push 'start' then wait 10 seconds"];
    // Center Align the label's text
    [label setTextAlignment:UITextAlignmentCenter];

	// Add the label to the window.
	[window addSubview:label];
	
	// Add button to the window
	startButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[startButton addTarget:self action:@selector(startButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
	[startButton setTitle:@"start" forState:UIControlStateNormal];
	startButton.frame = CGRectMake(50.0, 40.0, 60.0, 40.0);
	[window addSubview:startButton];

	// Add button to the window
	saveButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[saveButton addTarget:self action:@selector(saveButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
	[saveButton setTitle:@"save" forState:UIControlStateNormal];
	saveButton.frame = CGRectMake(190.0, 40.0, 60.0, 40.0);
	[window addSubview:saveButton];
	
	// initialize fingerprints
	self.newFingerprint = new float[Fingerprinter::fpLength];
	self.oldFingerprint = new float[Fingerprinter::fpLength];
	for (int i=0; i<Fingerprinter::fpLength; ++i){
		self.newFingerprint[i] = 0 ; // blank filler
		self.oldFingerprint[i] = 0 ; // blank filler
	}
	
	// Add plot to window
	CGRect plotRect = CGRectMake(10, 320, 300.0f, 150.0f);
	self.plot = [[[plotView alloc] initWith_Frame:plotRect] autorelease];
	[self.plot setVector: newFingerprint length: Fingerprinter::fpLength];
	[window addSubview:plot];

	// Add another plot to window
	plotRect = CGRectMake(10, 160, 300.0f, 150.0f);
	self.plotOld = [[[plotView alloc] initWith_Frame:plotRect] autorelease];
	[self.plotOld setVector: oldFingerprint length: Fingerprinter::fpLength];
	[window addSubview:plotOld];
	
	// create timer to update the plot
	self.plotTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
													  target:self
													selector:@selector(updatePlot)
													userInfo:nil
													 repeats:YES];	
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
	[startButton release];
	[saveButton release];
	[plot release];
	[plotOld release];
	[plotTimer release];
	delete fp;
	delete oldFingerprint;
    [super dealloc];
}


@end
