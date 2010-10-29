//
//  MatchViewController.h
//  simpleUI
//
//  Created by Stephen Tarzia on 10/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "plotView.h"
#import "AppDelegate.h"

using std::vector;


@interface MatchViewController : UIViewController <UIAlertViewDelegate>{
	AppDelegate *app;
	UILabel  *statusLabel;
	plotView *plot;            // live fingerprint plot
	vector<plotView*>* candidatePlots; 
	Fingerprint* candidates;
	Fingerprint newFingerprint;
	NSTimer  *plotTimer; // periodic timer to update the plot
	
	// PROBABLY WON'T NEED THESE
	UIButton *clearButton;
}

@property (nonatomic, retain) AppDelegate* app;
@property (nonatomic, retain) IBOutlet UILabel  *statusLabel;
@property (nonatomic, retain) IBOutlet plotView *plot;            // live fingerprint plot
@property (nonatomic) vector<plotView*>* candidatePlots; 
@property Fingerprint* candidates;
@property Fingerprint newFingerprint;
@property (nonatomic, retain) NSTimer  *plotTimer; // periodic timer to update the plot

// PROBABLY WON'T NEED THESE
@property (nonatomic, retain) IBOutlet UIButton *clearButton;


-(void) queryButtonHandler;
-(IBAction) clearButtonHandler:(id)sender;
-(void) updatePlot;

@end
