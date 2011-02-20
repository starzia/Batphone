//
//  simpleUIAppDelegate.m
//  simpleUI
//
//  Created by Stephen Tarzia on 9/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import "AppDelegate.h"
#import "Fingerprinter.h"
#import <iostream>
#include <unistd.h>
#import "MatchViewController.h"
#import "NewViewController.h"
#import "LocationViewController.h"
#import "OptionsViewController.h"

using namespace std;


@implementation AppDelegate

@synthesize window;
@synthesize navController;
@synthesize matchViewController;
@synthesize newViewController;
@synthesize locationViewController;
@synthesize optionsViewController;

@synthesize fp;
@synthesize database;
@synthesize locationManager;
@synthesize motionManager;
@synthesize options;

- (void) printFingerprint: (Fingerprint) fingerprint{
	for( unsigned int i=0; i<Fingerprinter::fpLength; ++i ){
		cout << fingerprint[i] << ' ';
	}
	cout << endl;
}

-(CLLocation*)getLocation{
	return locationManager.location;
}

-(void)checkinWithRoom:(NSString*)newRoom inBuilding:(NSString*)newBuilding{
	// get new fingerprint
	Fingerprint newFP = new float[Fingerprinter::fpLength];
	fp->getFingerprint( newFP );
	// add to database
	NSString* uuid = [database insertFingerprint:newFP
										building:newBuilding
											room:newRoom
										location:[self getLocation] ];
	NSLog(@"room '%@': %@ %@ saved",uuid,newBuilding,newRoom);
	delete [] newFP;
}



#pragma mark -
#pragma mark CLLocationManagerDelegate
// Core Location code adapted from http://mobileorchard.com/hello-there-a-corelocation-tutorial/
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation 
{
    //NSLog(@"Location: %@", [newLocation description]);
}

- (void)locationManager:(CLLocationManager *)manager
	   didFailWithError:(NSError *)error
{
	NSLog(@"Error: %@", [error description]);
}


#pragma mark -
#pragma mark app events

-(void) newButtonHandler{
	if( !newViewController ){
		// create view controller
		NewViewController *aNewViewController = [[NewViewController alloc]
												 initWithApp:self];
		self.newViewController = aNewViewController;
		newViewController.title = @"Check in";
		[aNewViewController release];
	}
	// update picker to reflect possible database changes (new/deleted rooms)
	[newViewController.roomPicker reloadAllComponents];
	
	// swap views
	[navController pushViewController:newViewController animated:YES];

	// add button to navigation bar
	UIBarButtonItem* newButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
									target:self 
									action:@selector(saveButtonHandler)];
	[navController.navigationBar.topItem setRightBarButtonItem:newButton animated:YES];	
	[newButton release];
}

// called after clicking a room in MatchViewController's matchTable
-(void) showRoom:(NSString*)room inBuilding:(NSString*)building{
	if( !locationViewController ){
		// create view controller
		LocationViewController *aLocationViewController = [[LocationViewController alloc]
							   initWithApp:self building:building room:room];
		self.locationViewController = aLocationViewController;
		[aLocationViewController release];
	}else{
		// reset room data
		[self.locationViewController resetWithBuilding:building room:room];
	}

	// set up navigation bar
	NSString* title = [[NSString alloc] initWithFormat:@"%@ : %@",building,room];
	locationViewController.title = title;
	[title release];
	
	// swap views
	[navController pushViewController:locationViewController animated:YES];

	// add button
	UIBarButtonItem* deleteButton = [[UIBarButtonItem alloc] 
						initWithBarButtonSystemItem:UIBarButtonSystemItemTrash 
											 target:self 
											 action:@selector(deleteRoomButtonHandler)];
	[navController.navigationBar.topItem setRightBarButtonItem:deleteButton animated:YES];
	[deleteButton release];
}

-(void) optionsButtonHandler{
	if( !optionsViewController ){
		// create new if we haven't yet
	    OptionsViewController* opController = [[OptionsViewController alloc] 
										   initWithStyle:UITableViewStyleGrouped
										             app:self];
	    self.optionsViewController = opController;
		optionsViewController.title = @"Options";
	    [opController release];
	}
	// swap views
	[navController pushViewController:optionsViewController animated:YES];
}


-(void) saveButtonHandler{
	// pass message on to view controller
	if( [newViewController saveButtonHandler] ){
		// if save was successful
		// pop view off stack
		[navController popViewControllerAnimated:YES];
	}
}


// delete room
-(void) deleteRoomButtonHandler{
	// show confimation popup
	UIAlertView *myAlert = [[UIAlertView alloc] initWithTitle:@"Really delete location?" 
													  message:@"You are about to delete all history for this room." 
													 delegate:self 
											cancelButtonTitle:@"Cancel" 
											otherButtonTitles:nil];
	[myAlert addButtonWithTitle:@"Delete"];
	[myAlert show];
	[myAlert release];
}

#pragma mark -
#pragma mark UIAlertViewDelegate (delete room popup)
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
	// if "delete" button was clicked then clear this room from the database
	if( buttonIndex == 1 ){
		[database deleteRoom:locationViewController.room 
				  inBuilding:locationViewController.building ];
		// pop view off stack
		[navController popViewControllerAnimated:YES];
	}
}

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	// Turn off the idle timer, since this app doesn't rely on constant touch input
	application.idleTimerDisabled = YES;
	
	// set up options dictionary
	{
		// get the documents directory:
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentsDirectory = [paths objectAtIndex:0];
	
		// build the full filenames
		NSString* optionsFile = [NSString stringWithFormat:@"%@/options.dat", documentsDirectory];
		NSString* optionsDefaultFile = [[[NSBundle mainBundle] pathForResource:@"defaultOptions" 
																		ofType:@"plist"] retain];
		RobustDictionary* dict = [[RobustDictionary alloc] initWithFilename:optionsFile 
														   defaultsFilename:optionsDefaultFile];
		self.options = dict;
		[dict release];
	}
		
	window.backgroundColor = [UIColor groupTableViewBackgroundColor]; // set striped BG
	
	// set up fingerprinter
	self.fp = new Fingerprinter();
	self.database = [[[FingerprintDB alloc] initWithFPLength:Fingerprinter::fpLength] autorelease];
	self.database.useRemoteDB = [[self.options objectForKey:@"enableSharing"] boolValue];
								 
	// set up Core Location
	self.locationManager = [[[CLLocationManager alloc] init] autorelease];
	self.locationManager.delegate = self; // send loc updates to myself
	// Note that desiredAccuracy affects power consumption
	locationManager.desiredAccuracy = kCLLocationAccuracyBest; // best accuracy
	locationManager.distanceFilter = kCLDistanceFilterNone; // notify me of all location changes, even if small
	locationManager.headingFilter = kCLHeadingFilterNone; // as above
	locationManager.purpose = @"Location information from the device's radios can be used to improve accuracy."; // to be displayed in system's user prompt
	[self.locationManager startUpdatingLocation]; // start location service
		
	// set up motion
	{
		self.motionManager = [[[CMMotionManager alloc] init] autorelease];
		self.motionManager.deviceMotionUpdateInterval = 0.01; //in seconds

		if(!motionManager.deviceMotionAvailable){
			NSLog(@"ERROR: device motion not available!");
		}
			
		// block for motion data callback
		CMDeviceMotionHandler motionHandler = ^ (CMDeviceMotion *motionData, NSError *error) {
			NSLog(@"Motion: g:{%f %f %f} accel:{%f %f %f}", 
				  motionData.gravity.x, motionData.gravity.y, motionData.gravity.z, 
				  motionData.userAcceleration.x, motionData.userAcceleration.y, motionData.userAcceleration.z ); 
		};
		
		// start receiving updates
		[self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue]
												withHandler:motionHandler];
	}
	
	// initialize the first view controller
	MatchViewController *aMatchViewController = [[MatchViewController alloc]
												 initWithApp:self];
	self.matchViewController = aMatchViewController;
	matchViewController.title = @"Neighborhood";
	[aMatchViewController release];

	// set up navigation controller
	self.navController = [[UINavigationController alloc] initWithRootViewController:matchViewController];
	UIBarButtonItem* optionsButton = [[[UIBarButtonItem alloc] initWithTitle:@"Options"
																	   style:UIBarButtonItemStylePlain
																	  target:self 
																	  action:@selector(optionsButtonHandler)] autorelease];
	[navController.navigationBar.topItem setLeftBarButtonItem:optionsButton animated:YES];
	UIBarButtonItem* newButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd 
																				target:self 
																				action:@selector(newButtonHandler)] autorelease];
	[navController.navigationBar.topItem setRightBarButtonItem:newButton animated:YES];
	[window addSubview:navController.view];	
	
	// update view
    [window makeKeyAndVisible];
	
	// start recording
	self.fp->startRecording();

	// disable shake-to-undo because user will be moving around a lot with this app
	[UIApplication sharedApplication].applicationSupportsShakeToEdit = NO; 
	
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
	self.fp->stopRecording();
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
	self.fp->stopRecording();
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
	self.fp->startRecording();
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
	self.fp->startRecording();
}


- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
	self.fp->stopRecording();
	[self.motionManager stopDeviceMotionUpdates]; // turn off sensors.
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
	[newViewController release];
	[matchViewController release];
	[locationViewController release];
	[optionsViewController release];
	[navController release];

	delete[] fp;
	delete database;
    [self.locationManager release];
    [super dealloc];
}


@end
