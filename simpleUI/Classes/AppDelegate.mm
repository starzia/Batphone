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

// for data motion file writing
#include <iostream>
#include <fstream>

using namespace std;


@implementation AppDelegate

@synthesize window;
@synthesize navController;
@synthesize matchViewController;
@synthesize myNewViewController;
@synthesize locationViewController;
@synthesize optionsViewController;

@synthesize fp;
@synthesize database;
@synthesize locationManager;
@synthesize motionManager;
@synthesize options;
@synthesize detailedLogging;
@synthesize watchdogTimer;

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


-(void)checkAudio{
	// get new fingerprint
	Fingerprint newFP = new float[Fingerprinter::fpLength];
	if( !fp->getFingerprint( newFP ) ){
		// if there is no valid fingerprint, then reset audio
		self.fp->stopRecording();
		self.fp->startRecording();
	}
}


#pragma mark -
#pragma mark CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations
{
#ifdef DEBUG
    NSLog(@"Location: %@", locations);
#endif
}

- (void)locationManager:(CLLocationManager *)manager
	   didFailWithError:(NSError *)error
{
	NSLog(@"Error: %@", [error description]);
}

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusDenied) {
        NSLog(@"Localication manager authorized");
    }else if (status == kCLAuthorizationStatusAuthorized) {
        NSLog(@"Location manager denied!");
    }
}


#pragma mark -
#pragma mark app events

-(void) newButtonHandler{
	if( !myNewViewController ){
		// create view controller
		self.myNewViewController = [[NewViewController alloc] initWithApp:self];
	}
	// swap views
	[navController pushViewController:myNewViewController animated:YES];
}

// called after clicking a room in MatchViewController's matchTable
-(void) showRoom:(NSString*)room inBuilding:(NSString*)building{
	if( !locationViewController ){
		// create view controller
		self.locationViewController = [[LocationViewController alloc]
							           initWithApp:self building:building room:room];
	}else{
		// reset room data
		[self.locationViewController resetWithBuilding:building room:room];
	}
	
	// swap views
	[navController pushViewController:locationViewController animated:YES];
}

-(void) optionsButtonHandler{
	if( !optionsViewController ){
		// create new if we haven't yet
	    self.optionsViewController = [[OptionsViewController alloc]
                                      initWithStyle:UITableViewStyleGrouped
                                                app:self];
	}
	// swap views
	[navController pushViewController:optionsViewController animated:YES];
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
#pragma mark logging (motion)

// perform affine transformation specified in matrix m.
void multiplyVecByMat( CMAcceleration* a, CMRotationMatrix m ){
	CMAcceleration old_a = *a;
	a->x = old_a.x * m.m11 + old_a.y * m.m12 + old_a.z * m.m13;	
	a->y = old_a.x * m.m21 + old_a.y * m.m22 + old_a.z * m.m23;	
	a->z = old_a.x * m.m31 + old_a.y * m.m32 + old_a.z * m.m33;	
}

-(NSString*)getMotionDataFilename{
	// get the documents directory:
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	
	// build the full filename
	return [NSString stringWithFormat:@"%@/%@", documentsDirectory, @"motion.txt"];
}

-(NSString*)getSpectrogramFilename{
	// get the documents directory:
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	
	// build the full filename
	return [NSString stringWithFormat:@"%@/%@", documentsDirectory, @"spectrogram.txt"];
}

-(void) handleMotionData:(CMDeviceMotion*) motionData{
	CMAttitude* att = motionData.attitude;
	CMAcceleration userAccel = motionData.userAcceleration;
	// convert userAcceleration to world frame
	///multiplyVecByMat( &userAccel, motionData.attitude.rotationMatrix );
	// save new line in data file
	NSString* line = [[NSString alloc] initWithFormat:@"%f\t%f\t%f\t%f\t%f\t%f\t%f\n", 
					  motionData.timestamp, userAccel.x, userAccel.y, userAccel.z,
					  att.roll, att.pitch, att.yaw
					  ]; 
		
	// open data file for appending
	NSString* filename = [[self getMotionDataFilename] retain];
	std::ofstream dFile;
	dFile.open([filename UTF8String], std::ios::out | std::ios::app);
	dFile << [line UTF8String]; // append the new entry
	dFile.close();
	[filename release];
	
	[line release];
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
	self.detailedLogging = false; // Detailed logging should never be enabled for a public release
	
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
								 
	// set up Core Location
	self.locationManager = [[[CLLocationManager alloc] init] autorelease];
	self.locationManager.delegate = self; // send loc updates to myself
	// Note that desiredAccuracy affects power consumption
	locationManager.desiredAccuracy = kCLLocationAccuracyBest; // best accuracy
	locationManager.distanceFilter = kCLDistanceFilterNone; // notify me of all location changes, even if small
	locationManager.headingFilter = kCLHeadingFilterNone; // as above
	[self.locationManager startUpdatingLocation]; // start location service
		
	// set up motion and spectrogram logging
	if( self.detailedLogging ){
		self.motionManager = [[[CMMotionManager alloc] init] autorelease];
		self.motionManager.deviceMotionUpdateInterval = 0.001; //in seconds.  If a very small value is chosen, then the minimum HW sampling period is used instead

		if(!motionManager.deviceMotionAvailable){
			NSLog(@"ERROR: device motion not available!");
		}
			
		// block for motion data callback
		CMDeviceMotionHandler motionHandler = ^ (CMDeviceMotion *motionData, NSError *error) {
			[self handleMotionData:motionData];
		};
		
		// start receiving updates
		[self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue]
												withHandler:motionHandler];
		
		// set up logging of spectrogram
		self.fp->spectrogram.enableLoggingToFilename( [[self getSpectrogramFilename] UTF8String] );
	}
		
	// initialize the first view controller
    self.matchViewController = [[MatchViewController alloc] initWithApp:self];;

	// set up navigation controller
	self.navController = [[UINavigationController alloc] initWithRootViewController:matchViewController];
	
    // update view
    window.rootViewController = navController;
    [window makeKeyAndVisible];

	// start recording
	self.fp->startRecording();

	// disable shake-to-undo because user will be moving around a lot with this app
	[UIApplication sharedApplication].applicationSupportsShakeToEdit = NO; 
	
	// start watchdog timer for audio
	// This should not fire when app is in background, so we don't have to worry about it
	// starting audio when it should be stopped.
	self.watchdogTimer = [NSTimer scheduledTimerWithTimeInterval:15
														  target:self
														selector:@selector(checkAudio)
														userInfo:nil
														 repeats:YES];
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
	[myNewViewController release];
	[matchViewController release];
	[locationViewController release];
	[optionsViewController release];
	[navController release];

	delete[] fp;
	[self.database release];
    [self.locationManager release];
	[self.motionManager release];
    
	[super dealloc];
}


@end
