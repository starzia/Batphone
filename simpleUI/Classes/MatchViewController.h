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


@interface MatchViewController : UIViewController 
<UIAlertViewDelegate, UITableViewDelegate, UITableViewDataSource>{
	AppDelegate *app;
	UILabel  *statusLabel;
	plotView *plot;            // live fingerprint plot
	vector<plotView*>* candidatePlots; 
	Fingerprint* candidates;
	Fingerprint newFingerprint;
	NSTimer  *plotTimer; // periodic timer to update the plot
	NSTimer  *queryTimer; // periodic timer to query the DB for matches
	UITableView *matchTable; // table of DB matches
}

@property (nonatomic, retain) AppDelegate* app;
@property (nonatomic, retain) UILabel  *statusLabel;
@property (nonatomic, retain) plotView *plot;            // live fingerprint plot
@property (nonatomic) vector<plotView*>* candidatePlots; 
@property Fingerprint* candidates;
@property Fingerprint newFingerprint;
@property (nonatomic, retain) NSTimer  *plotTimer; // periodic timer to update the plot
@property (nonatomic, retain) NSTimer  *queryTimer; // periodic timer to update the plot
@property (nonatomic, retain) UITableView *matchTable;

-(void) clearButtonHandler;
-(void) query;
-(void) updatePlot;

@end
