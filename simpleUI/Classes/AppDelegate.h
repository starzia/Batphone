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

@interface AppDelegate : NSObject 
<UIApplicationDelegate, CLLocationManagerDelegate, UINavigationBarDelegate> {
	// data members
    UIWindow *window;
	UINavigationBar *navBar;
	MatchViewController *matchViewController;
	NewViewController *newViewController;
	LocationViewController *locationViewController;

	Fingerprinter* fp;
	FingerprintDB* database;
	CLLocationManager *locationManager; 	// data for SkyHook/GPS localization
}

// accessors
@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) UINavigationBar* navBar;
@property (nonatomic, retain) MatchViewController *matchViewController;
@property (nonatomic, retain) NewViewController *newViewController;
@property (nonatomic, retain) LocationViewController *locationViewController;

@property (nonatomic) Fingerprinter* fp; 
@property (nonatomic) FingerprintDB* database;
@property (nonatomic, retain) CLLocationManager *locationManager;  

// member functions
-(void) printFingerprint: (Fingerprint) fingerprint;
-(GPSLocation)getLocation; // return the current GPSLocation from locationManager
 
@end

