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
#import <vector>
#import <CoreLocation/CoreLocation.h>

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
	NewViewController *newViewController;
	LocationViewController *locationViewController;
	OptionsViewController *optionsViewController;
	 
	Fingerprinter* fp;
	CLLocationManager *locationManager; 	// data for SkyHook/GPS localization
	FingerprintDB* database;
}

// accessors
@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) UINavigationController* navController;
@property (nonatomic, retain) MatchViewController *matchViewController;
@property (nonatomic, retain) NewViewController *newViewController;
@property (nonatomic, retain) LocationViewController *locationViewController;
@property (nonatomic, retain) OptionsViewController *optionsViewController;

@property (nonatomic) Fingerprinter* fp; 
@property (nonatomic, retain) FingerprintDB* database;
@property (nonatomic, retain) CLLocationManager *locationManager;  

// member functions
-(void) printFingerprint: (Fingerprint) fingerprint;
-(CLLocation*)getLocation; // return the current GPSLocation from locationManager

// show details of a room
-(void) showRoom:(NSString*)room inBuilding:(NSString*)building;
 
@end

