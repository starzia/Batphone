//
//  MatchViewController.m
//  simpleUI
//
//  Created by Stephen Tarzia on 10/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import "MatchViewController.h"


@implementation MatchViewController

@synthesize app;
@synthesize statusLabel;
@synthesize plot;
@synthesize candidatePlots;
@synthesize candidates;
@synthesize plotTimer;
@synthesize queryButton;
@synthesize clearButton;
@synthesize newFingerprint;

// CONSTANTS
static const int numCandidates = 3;


 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		
		// Create text label.
		CGFloat x = 320/2 - 300/2; // screen width / 2 - label width / 2
		CGRect labelRect = CGRectMake(x , 110, 300.0f, 45.0f);
		self.statusLabel = [[[UILabel alloc] initWithFrame:labelRect] autorelease];
		// Set the value of our string
		[statusLabel setText:@"Fingerprinter is running..."];
		// Center Align the label's text
		[statusLabel setTextAlignment:UITextAlignmentCenter];
		statusLabel.textColor = [UIColor darkTextColor];
		statusLabel.backgroundColor = [UIColor clearColor];
		// set font
		[statusLabel setFont:[UIFont fontWithName:@"Arial" size:12]];
		// Add the label to the window.
		[self.view addSubview:statusLabel];
		
		// Add query button to the window
		queryButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
		[queryButton addTarget:self action:@selector(queryButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
		[queryButton setTitle:@"query for match" forState:UIControlStateNormal];
		queryButton.frame = CGRectMake(10.0, 70.0, 145.0, 40.0);
		[self.view addSubview:queryButton];
		
		// Add clear button to the window
		clearButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
		[clearButton addTarget:self action:@selector(clearButtonHandler:) forControlEvents:UIControlEventTouchUpInside];
		[clearButton setTitle:@"clear database" forState:UIControlStateNormal];
		clearButton.frame = CGRectMake(10.0, 430.0, 145.0, 40.0);
		[self.view addSubview:clearButton];
		
		// initialize and blank fingerprints
		self.candidates = new float*[numCandidates];
		for( int i=0; i<numCandidates; i++ ){
			self.candidates[i] = new float[Fingerprinter::fpLength];
			for (int j=0; j<Fingerprinter::fpLength; ++j){
				self.candidates[i][j] = 0;
			}
		}
		self.newFingerprint = new float[Fingerprinter::fpLength];
		for (int i=0; i<Fingerprinter::fpLength; ++i){
			// blank fingerprint
			self.newFingerprint[i] = 0;
		}
		
		// Add plot to window
		CGRect plotRect = CGRectMake(0, 150, 320.0f, 100.0f);
		self.plot = [[[plotView alloc] initWith_Frame:plotRect] autorelease];
		[self.plot setVector: newFingerprint length: Fingerprinter::fpLength];
		[self.view addSubview:plot];
		
		// Add candidate plots to window
		plotRect = CGRectMake(0, 250, 320.0f, 100.0f);
		self.candidatePlots = new vector<plotView*>();
		for( int i=0; i<numCandidates; i++ ){
			plotView* thisCandidatePlot = [[plotView alloc] initWith_Frame:plotRect];
			self.candidatePlots->push_back( thisCandidatePlot );
			// assign the appropriate data vector to each plot
			[thisCandidatePlot setVector:candidates[i] length: Fingerprinter::fpLength];
			// change color of candidates line (from default of black = {0,0,0}
			thisCandidatePlot.lineColor[i%numCandidates] = 1; // set either R, G, or B to 1.0
			[self.view addSubview:thisCandidatePlot];
		}
		
		// create timer to update the plot
		self.plotTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
														  target:self
														selector:@selector(updatePlot)
														userInfo:nil
														 repeats:YES];
    }
    return self;
}

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

-(void) queryButtonHandler:(id)sender{
	// query for matches
	QueryResult result;
	unsigned int numMatches = app.database->queryMatches( result, self.newFingerprint, 
														  numCandidates, [app getLocation] );
	
	// update status display
	NSMutableString* ss = [[NSMutableString alloc] initWithFormat:@"%d matches: ",numMatches];
	if( numMatches >= 1 ){
		[ss appendString:result[0].entry.name];
	}
	if( numMatches >= 2 ){
		[ss appendFormat:@" / %@",result[1].entry.name];
	}
	if( numMatches >= 3 ){
		[ss appendFormat:@" / %@",result[2].entry.name];
	}
    [statusLabel setText:ss];
	[ss release];
	
	// update candidate line plots
	for( int i=0; i<numCandidates; ++i ){
		plotView* candidatePlot = (*self.candidatePlots)[i];
		if( i<numMatches ){
			// plot this candidate
			memcpy( self.candidates[i], result[i].entry.fingerprint, sizeof(float)*Fingerprinter::fpLength);
		}else{
			// blank out this plot slot
			for (int j=0; j<Fingerprinter::fpLength; ++j){
				self.candidates[i][j] = 0;
			}
		}
		[candidatePlot setNeedsDisplay];
	}
}


-(void)clearButtonHandler:(id)sender{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Really clear database?" 
													message:@"You are about to erase the entire room fingerprint database." 
												   delegate:self 
										  cancelButtonTitle:@"Cancel" 
										  otherButtonTitles:nil];
	[alert addButtonWithTitle:@"OK"];
	[alert show];
	[alert release];
}

/* called by timer */
-(void) updatePlot{
	// get the current fingerprint and save to "New" slot
	if( app.fp->getFingerprint( self.newFingerprint ) ){
		// if successful, then redraw
		[self.plot setNeedsDisplay];
	}
}


#pragma mark -
#pragma mark UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
	// if "ok" button was clicked then clear the database
	if( buttonIndex == 1 ){
		app.database->clear();
		[self queryButtonHandler:nil]; // this is a hack to clear the candidate plots
		[statusLabel setText:@"Database cleared"];
	}
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

#pragma mark -
#pragma mark memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
	[statusLabel release];
	[queryButton release];
	[plot release];
	[plotTimer release];
	for( int i=0; i<numCandidates; i++ ){
		delete[] candidates[i];
		delete (*candidatePlots)[i];
	}
	delete[] candidates;
	delete[] newFingerprint;
	delete candidatePlots;	
	
    [super dealloc];
}


@end
