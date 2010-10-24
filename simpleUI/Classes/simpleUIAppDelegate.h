//
//  simpleUIAppDelegate.h
//  simpleUI
//
//  Created by Stephen Tarzia on 9/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Fingerprinter.h"
#import "plotView.h"
#import "FingerprintDB.h"
#import <vector>
#import <CoreLocation/CoreLocation.h>

using std::vector;

@interface simpleUIAppDelegate : NSObject 
<UIApplicationDelegate, UITextFieldDelegate, CLLocationManagerDelegate, UIAlertViewDelegate> {
	// data members
    UIWindow *window;
	UINavigationBar *navBar;
	UILabel  *label;
	UIButton *saveButton;
	UIButton *queryButton;
	UIButton *clearButton;
	UITextField *nameLabel;
	plotView *plot;            // live fingerprint plot
	vector<plotView*>* candidatePlots; 
	Fingerprint newFingerprint;
	Fingerprint* candidates;
	NSTimer  *plotTimer; // periodic timer to update the plot
	Fingerprinter* fp;
	FingerprintDB* database;
	CLLocationManager *locationManager; 	// data for SkyHook/GPS localization
}

// accessors
@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) UINavigationBar* navBar;
@property (nonatomic, retain) UILabel *label;
@property (nonatomic, retain) UIButton *saveButton;
@property (nonatomic, retain) UIButton *queryButton;
@property (nonatomic, retain) UIButton *clearButton;
@property (nonatomic, retain) UITextField *nameLabel;;
@property (retain) plotView *plot;
@property (retain) NSTimer* plotTimer;
@property vector<plotView*>* candidatePlots;
@property Fingerprint newFingerprint;
@property Fingerprint* candidates;
@property (nonatomic) Fingerprinter* fp; 
@property (nonatomic, retain) FingerprintDB* database;
@property (nonatomic, retain) CLLocationManager *locationManager;  

// member functions
-(void) printFingerprint: (Fingerprint) fingerprint;
-(void) saveButtonHandler:(id)sender;
-(void) queryButtonHandler:(id)sender;
-(void) clearButtonHandler:(id)sender;
-(void) updatePlot;
-(GPSLocation)getLocation; // return the current GPSLocation from locationManager

// the following callback functions are for the CLLocationManagerDelegate protocol
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation;

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error;

// the following callback functions are for the UIAlertViewDelegate protocol
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;

@end

