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
using std::vector;

@interface simpleUIAppDelegate : NSObject <UIApplicationDelegate, UITextFieldDelegate> {
	// data members
    UIWindow *window;
	UILabel  *label;
	UIButton *saveButton;
	UIButton *resetButton;
	UITextField *nameLabel;
	plotView *plot;            // live fingerprint plot
	vector<plotView*>* candidatePlots; 
	Fingerprint newFingerprint;
	Fingerprint* candidates;
	NSTimer  *plotTimer; // periodic timer to update the plot
	Fingerprinter* fp;
	FingerprintDB* database;
}

// accessors
@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) UILabel *label;
@property (nonatomic, retain) UIButton *saveButton;
@property (nonatomic, retain) UIButton *queryButton;
@property (nonatomic, retain) UITextField *nameLabel;;
@property (retain) plotView *plot;
@property vector<plotView*>* candidatePlots;
@property (retain) NSTimer* plotTimer;
@property Fingerprint newFingerprint;
@property Fingerprint* candidates;
@property (nonatomic) Fingerprinter* fp; 
@property (nonatomic) FingerprintDB* database;

// member functions
-(void) printFingerprint: (Fingerprint) fingerprint;
-(void) saveButtonHandler:(id)sender;
-(void) queryButtonHandler:(id)sender;
-(void) updatePlot;

@end

