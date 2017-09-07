//
//  simpleUIAppDelegate.h
//  simpleUI
//
//  Created by Stephen Tarzia on 9/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Fingerprinter.h"
#import "FingerprintDB.h"
#import "RobustDictionary.h"
#import <vector>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>

using std::vector;

// forward declarations
@class MatchViewController;
@class NewViewController;
@class LocationViewController;
@class OptionsViewController;

@interface AppDelegate : NSObject 
<UIApplicationDelegate, CLLocationManagerDelegate, UINavigationBarDelegate,
 UIAlertViewDelegate> {
	// data members
    UIWindow *window;
	UINavigationController *navController;
	MatchViewController *matchViewController;
	NewViewController *myNewViewController;
	LocationViewController *locationViewController;
	OptionsViewController *optionsViewController;
	 
	Fingerprinter* fp;
	CLLocationManager *locationManager; 	// data for SkyHook/GPS localization
	CMMotionManager* motionManager;
	FingerprintDB* database;
	RobustDictionary* options;
	bool detailedLogging; // log fine-grained sensor data (for testing only!)
	NSTimer  *watchdogTimer; // periodic timer to reset audio if it's not working
}

// accessors
@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) UINavigationController* navController;
@property (nonatomic, retain) MatchViewController *matchViewController;
@property (nonatomic, retain) NewViewController *myNewViewController;
@property (nonatomic, retain) LocationViewController *locationViewController;
@property (nonatomic, retain) OptionsViewController *optionsViewController;

@property (nonatomic) Fingerprinter* fp; 
@property (nonatomic, retain) FingerprintDB* database;
@property (nonatomic, retain) CLLocationManager *locationManager;  
@property (nonatomic, retain) CMMotionManager* motionManager;
@property (nonatomic, retain) RobustDictionary* options;
@property (nonatomic) bool detailedLogging;
@property (nonatomic, retain) NSTimer  *watchdogTimer;

// member functions
-(void) printFingerprint: (Fingerprint) fingerprint;
-(CLLocation*)getLocation; // return the current GPSLocation from locationManager
-(NSString*)getMotionDataFilename;
-(NSString*)getSpectrogramFilename;
-(void)checkAudio; // tests that audio is working, if not reset.

// show details of a room
-(void) showRoom:(NSString*)room inBuilding:(NSString*)building;

// save a new room fingerprint
-(void)checkinWithRoom:(NSString*)newRoom inBuilding:(NSString*)newBuilding;

#pragma mark - UI event handlers
-(void) newButtonHandler;
-(void) optionsButtonHandler;
-(void) deleteRoomButtonHandler;

@end

