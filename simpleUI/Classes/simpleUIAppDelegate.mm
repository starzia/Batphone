//
//  simpleUIAppDelegate.m
//  simpleUI
//
//  Created by Stephen Tarzia on 9/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import "simpleUIAppDelegate.h"
#import "Fingerprinter.h"
#import <iostream>
#include <unistd.h>

using namespace std;


@implementation simpleUIAppDelegate

@synthesize window;
@synthesize label;
@synthesize saveButton;
@synthesize queryButton;
@synthesize nameLabel;
@synthesize plot;
@synthesize plotTimer;
@synthesize candidatePlots;
@synthesize newFingerprint;
@synthesize candidates;
@synthesize fp;
@synthesize database;

#import <sstream>

static const int numCandidates = 3;


- (void) printFingerprint: (Fingerprint) fingerprint{
	for( unsigned int i=0; i<Fingerprinter::fpLength; ++i ){
		cout << fingerprint[i] << ' ';
	}
	cout << endl;
}


/* called by button */
-(void) saveButtonHandler:(id)sender{
	string newName = [self.nameLabel.text UTF8String]; 
	self.database->insertFingerprint(self.newFingerprint, newName);
}

-(void) queryButtonHandler:(id)sender{
	// query for matches
	QueryResult result;
	unsigned int numMatches = self.database->queryMatches( result, self.newFingerprint, numCandidates );

	// update candidate line plots
	std::ostringstream ss;
	ss << numMatches << " matches: "
			<< result[0].entry.name << " / "
			<< result[1].entry.name << " / "
			<< result[2].entry.name;
    [label setText:[[NSString alloc] initWithCString:ss.str().c_str()] ];
	for( unsigned int i=0; i<numMatches; ++i ){
		[self printFingerprint:result[i].entry.fingerprint];
		// plot this candidate
		plotView* candidatePlot = (*self.candidatePlots)[i];
		[candidatePlot setVector:result[i].entry.fingerprint length:Fingerprinter::fpLength];
		[candidatePlot setNeedsDisplay];
	}
}

// make the keyboard dissapear after hit return. 
// We are overriding a method inherited from the UITextFieldDelegate protocol
- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
    if (theTextField == self.nameLabel) {
        [self.nameLabel resignFirstResponder]; // make keyboard dissapear
    }
    return YES;	
}

/* called by timer */
-(void) updatePlot{
	// get the current fingerprint and save to "New" slot
	if( self.fp->getFingerprint( self.newFingerprint ) ){
		// if successful, then redraw
		[self.plot setNeedsDisplay];
	}
}

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    // Override point for customization after application launch.
	self.fp = new Fingerprinter();
	self.database = new FingerprintDB(Fingerprinter::fpLength);
	
    // Create text label.
    CGFloat x = 320/2 - 300/2; // screen width / 2 - label width / 2
    CGFloat y = 480/2 - 45/2; // screen height / 2 - label height / 2
    CGRect labelRect = CGRectMake(x , 110, 300.0f, 45.0f);
    self.label = [[[UILabel alloc] initWithFrame:labelRect] autorelease];
    // Set the value of our string
    [label setText:@"Fingerprinter is running..."];
    // Center Align the label's text
    [label setTextAlignment:UITextAlignmentCenter];
	label.textColor = [UIColor darkTextColor];
	label.backgroundColor = [UIColor clearColor];
	// Add the label to the window.
	[window addSubview:label];

	// create textField
	x = 320/2 - 300/2; // screen width / 2 - label width / 2
    y = 480/2 - 30/2;  // screen height / 2 - label height / 2
    labelRect = CGRectMake(x , 30, 300.0f, 30.0f);
	self.nameLabel = [[[UITextField alloc] initWithFrame:labelRect] autorelease];
	[nameLabel setPlaceholder:@"new room's name"];
	[nameLabel setBorderStyle:UITextBorderStyleRoundedRect];
	nameLabel.autocorrectionType = UITextAutocorrectionTypeNo;
	nameLabel.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x'
	nameLabel.delegate = self; // sends events to this class, so this class must implement UITextFieldDelegate protocol
    [window addSubview:nameLabel];
	
	// Add button to the window
	queryButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[queryButton addTarget:self action:@selector(queryButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
	[queryButton setTitle:@"query for match" forState:UIControlStateNormal];
	queryButton.frame = CGRectMake(10.0, 70.0, 145.0, 40.0);
	[window addSubview:queryButton];

	// Add button to the window
	saveButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[saveButton addTarget:self action:@selector(saveButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
	[saveButton setTitle:@"save as new" forState:UIControlStateNormal];
	saveButton.frame = CGRectMake(165.0, 70.0, 145.0, 40.0);
	[window addSubview:saveButton];
	
	// initialize fingerprints
	self.newFingerprint = new float[Fingerprinter::fpLength];
	self.candidates = new float*[numCandidates];
	for( int i=0; i<numCandidates; i++ ){
		self.candidates[i] = new float[Fingerprinter::fpLength];
		for (int j=0; j<Fingerprinter::fpLength; ++j){
			self.candidates[i][j] = 0;
		}
	}
	for (int i=0; i<Fingerprinter::fpLength; ++i){
		// blank all fingerprints
		self.newFingerprint[i] = 0;
	}
	
	// Add plot to window
	CGRect plotRect = CGRectMake(10, 370, 300.0f, 100.0f);
	self.plot = [[[plotView alloc] initWith_Frame:plotRect] autorelease];
	[self.plot setVector: newFingerprint length: Fingerprinter::fpLength];
	[window addSubview:plot];

	// Add candidate plots to window
	plotRect = CGRectMake(10, 270, 300.0f, 100.0f);
	self.candidatePlots = new vector<plotView*>();
	for( int i=0; i<numCandidates; i++ ){
		plotView* thisCandidatePlot = [[[plotView alloc] initWith_Frame:plotRect] autorelease];
		self.candidatePlots->push_back( thisCandidatePlot );
		// assign the appropriate data vector to each plot
		[thisCandidatePlot setVector:candidates[i] length: Fingerprinter::fpLength];
		// change color of candidates line (from default of black = {0,0,0}
		thisCandidatePlot.lineColor[i%numCandidates] = 1; // set either R, G, or B to 1.0
		[window addSubview:thisCandidatePlot];
	}
	
	// create timer to update the plot
	self.plotTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
													  target:self
													selector:@selector(updatePlot)
													userInfo:nil
													 repeats:YES];	
	// update view
	window.backgroundColor = [UIColor groupTableViewBackgroundColor]; // set striped BG
    [window makeKeyAndVisible];
	
	// auto start recording
	self.fp->startRecording();
	
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
	self.fp->stopRecording();
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
	self.fp->startRecording();
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}


- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
	self.fp->stopRecording();
}


#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
}


- (void)dealloc {
    [window release];
	[label release];
	[nameLabel release];
	[queryButton release];
	[saveButton release];
	[plot release];
	[plotTimer release];
	for( int i=0; i<numCandidates; i++ ){
		delete[] candidates[i];
		delete (*candidatePlots)[i];
	}
	delete[] candidates;
	delete candidatePlots;	
	delete[] fp;
	delete database;
    [super dealloc];
}


@end
