//
//  LocationViewController.h
//  simpleUI
//
//  Created by Stephen Tarzia on 10/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "plotView.h"
#import <MapKit/MapKit.h>

@interface LocationViewController : UIViewController {
	AppDelegate *app;
	NSString* room;
	NSString* building;
	vector<DBEntry*> fingerprints;
	plotView *plot;
	NSTimer  *plotTimer; // periodic timer to update the plot
	int plotIndex; // index in fingerprints of currently-displayed plot
	UILabel *label;
	MKMapView *map;
	UIButton* checkinButton;
}
@property (nonatomic, retain) AppDelegate* app;
@property (nonatomic, retain) NSString* room;
@property (nonatomic, retain) NSString* building;
@property (nonatomic) vector<DBEntry*> fingerprints;
@property (nonatomic, retain) plotView *plot;
@property (nonatomic, retain) NSTimer  *plotTimer;
@property (nonatomic) int plotIndex;
@property (nonatomic, retain) UILabel* label;
@property (nonatomic, retain) MKMapView *map;
@property (nonatomic, retain) UIButton* checkinButton;

// custom initializer
- (id)initWithApp:(AppDelegate *)app 
		 building:(NSString*)building
			 room:(NSString*)room;
-(void)resetWithBuilding:(NSString*)building
					room:(NSString*)room;

// checkin button handler
-(void)checkIn;

// timer handler
-(void)updatePlot;

// add placemark to map
+(void)annotateMap:(MKMapView*)map 
		  location:(CLLocation*)location
			 title:(NSString*)title; // title can be nil
+(void)zoomToFitMapAnnotations:(MKMapView*)mapView;

@end
