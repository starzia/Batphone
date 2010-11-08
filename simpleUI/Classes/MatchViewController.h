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
<UIAlertViewDelegate, UITableViewDelegate, UITableViewDataSource,
 UITabBarDelegate>{
	AppDelegate *app;
	plotView *plot;            // live fingerprint plot
	Fingerprint newFingerprint;
	NSTimer  *plotTimer; // periodic timer to update the plot
	NSTimer  *queryTimer; // periodic timer to query the DB for matches
	UITableView *matchTable; // table of DB matches
	QueryResult matches;
    bool useAcousticDistance; // vs physical distance for DB match query
	UIAlertView *alert; // popup explaining that there is not enough data yet
	UITabBar* tabBar; // choose acoustic/CL localization
}

@property (nonatomic, retain) AppDelegate* app;
@property (nonatomic, retain) plotView *plot;            // live fingerprint plot
@property Fingerprint newFingerprint;
@property (nonatomic, retain) NSTimer  *plotTimer; // periodic timer to update the plot
@property (nonatomic, retain) NSTimer  *queryTimer; // periodic timer to update the plot
@property (nonatomic, retain) UITableView *matchTable;
@property (nonatomic) QueryResult matches;
@property (nonatomic) bool useAcousticDistance;
@property (nonatomic, retain) UIAlertView *alert;
@property (nonatomic, retain) UITabBar *tabBar;

// custom initializer
- (id)initWithApp:(AppDelegate *)theApp;

-(void) clearButtonHandler;
-(void) query;
-(void) updatePlot;

@end
