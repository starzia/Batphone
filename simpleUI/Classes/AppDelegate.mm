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

using namespace std;


@implementation AppDelegate

@synthesize window;
@synthesize navBar;
@synthesize matchViewController;
@synthesize newViewController;
@synthesize locationViewController;

@synthesize fp;
@synthesize database;
@synthesize locationManager;


- (void) printFingerprint: (Fingerprint) fingerprint{
	for( unsigned int i=0; i<Fingerprinter::fpLength; ++i ){
		cout << fingerprint[i] << ' ';
	}
	cout << endl;
}

-(GPSLocation)getLocation{
	// get location
	GPSLocation currentLocation;
	CLLocation *loc = locationManager.location;
	currentLocation.latitude = loc.coordinate.latitude;
	currentLocation.longitude = loc.coordinate.longitude;
	currentLocation.altitude = loc.altitude;
	return currentLocation;
}


#pragma mark -
#pragma mark CLLocationManagerDelegate
// Core Location code adapted from http://mobileorchard.com/hello-there-a-corelocation-tutorial/
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation 
{
    NSLog(@"Location: %@", [newLocation description]);
}

- (void)locationManager:(CLLocationManager *)manager
	   didFailWithError:(NSError *)error
{
	NSLog(@"Error: %@", [error description]);
}


#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
	// initialize view controllers
	MatchViewController *aMatchViewController = [[MatchViewController alloc]
												 initWithNibName:@"MatchViewController" bundle:[NSBundle mainBundle]];
	self.matchViewController = aMatchViewController;
	[aMatchViewController release];
	
	NewViewController *aNewViewController = [[NewViewController alloc]
											 initWithNibName:@"NewViewController" bundle:[NSBundle mainBundle]];
	self.newViewController = aNewViewController;
	[aNewViewController release];
	
	LocationViewController *aLocationViewController = [[LocationViewController alloc]
												 initWithNibName:@"LocationViewController" bundle:[NSBundle mainBundle]];
	self.locationViewController = aLocationViewController;
	[aLocationViewController release];
	
	// set up fingerprinter
	self.fp = new Fingerprinter();
	self.database = new FingerprintDB(Fingerprinter::fpLength);
	self.database->load(); // load the database.
	
	// set up Core Location
	self.locationManager = [[[CLLocationManager alloc] init] autorelease];
	self.locationManager.delegate = self; // send loc updates to myself
	// Note that desiredAccuracy affects power consumption
	locationManager.desiredAccuracy = kCLLocationAccuracyBest; // best accuracy
	locationManager.distanceFilter = kCLDistanceFilterNone; // notify me of all location changes, even if small
	locationManager.headingFilter = kCLHeadingFilterNone; // as above
	[self.locationManager startUpdatingLocation]; // start location service
	
	// Create navigation bar
	CGRect navRect = CGRectMake(0, 20, 320, 44);
	self.navBar = [[[UINavigationBar alloc] initWithFrame:navRect] autorelease];
	[window addSubview:navBar];
	
	// update view
	window.backgroundColor = [UIColor groupTableViewBackgroundColor]; // set striped BG
    [window makeKeyAndVisible];
	
	// auto start recording
	self.fp->startRecording();
	
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
	[navBar release];

	delete[] fp;
	delete database;
    [self.locationManager release];
    [super dealloc];
}


@end
