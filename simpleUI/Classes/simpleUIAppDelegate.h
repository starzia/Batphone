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

@interface simpleUIAppDelegate : NSObject <UIApplicationDelegate> {
	// data members
    UIWindow *window;
	UILabel  *label;
	UIButton *saveButton;
	UIButton *resetButton;
	plotView *plot;
	plotView *plotOld;
	Fingerprint newFingerprint;
	Fingerprint oldFingerprint;
	NSTimer  *plotTimer; // periodic timer to update the plot
	Fingerprinter* fp;
}

// accessors
@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) UILabel *label;
@property (nonatomic, retain) UIButton *saveButton;
@property (nonatomic, retain) UIButton *startButton;
@property (retain) plotView *plot;
@property (retain) plotView *plotOld;
@property (retain) NSTimer* plotTimer;
@property Fingerprint newFingerprint;
@property Fingerprint oldFingerprint;
@property (nonatomic) Fingerprinter* fp; 

// member functions
-(void) printFingerprint: (Fingerprint*) fingerprint;
-(void) saveButtonHandler:(id)sender;
-(void) startButtonHandler:(id)sender;
-(void) updatePlot;

@end

