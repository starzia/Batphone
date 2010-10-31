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
@synthesize queryTimer;
@synthesize newFingerprint;
@synthesize matchTable;

// CONSTANTS
static const int numCandidates = 3;

#pragma mark -
#pragma mark UIViewController inherited

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
 */


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
	self.view.backgroundColor = [UIColor clearColor]; // set striped BG
	
	// Create text label.
	CGFloat x = 320/2 - 300/2; // screen width / 2 - label width / 2
	CGRect labelRect = CGRectMake(x , 80, 300.0f, 45.0f);
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
	CGRect rect = CGRectMake(0, 150, 320.0f, 100.0f);
	self.plot = [[[plotView alloc] initWith_Frame:rect] autorelease];
	[self.plot setVector: newFingerprint length: Fingerprinter::fpLength];
	[self.view addSubview:plot];
	
	// Add candidate plots to window
	rect = CGRectMake(0, 250, 320.0f, 100.0f);
	self.candidatePlots = new vector<plotView*>();
	for( int i=0; i<numCandidates; i++ ){
		plotView* thisCandidatePlot = [[plotView alloc] initWith_Frame:rect];
		self.candidatePlots->push_back( thisCandidatePlot );
		// assign the appropriate data vector to each plot
		[thisCandidatePlot setVector:candidates[i] length: Fingerprinter::fpLength];
		// change color of candidates line (from default of black = {0,0,0}
		thisCandidatePlot.lineColor[i%numCandidates] = 1; // set either R, G, or B to 1.0
		[self.view addSubview:thisCandidatePlot];
	}
	
	// create matchTable
	rect = CGRectMake( 0, 265, 320, 215 );
	self.matchTable = [[[UITableView alloc] initWithFrame:rect] autorelease];
	matchTable.backgroundColor = [UIColor clearColor];
	matchTable.delegate = matchTable.dataSource = self;
	[self.view addSubview:matchTable];
	
	// create timer to update the plot
	self.plotTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
													  target:self
													selector:@selector(updatePlot)
													userInfo:nil
													 repeats:YES];
	// create timer to continuously query
	self.plotTimer = [NSTimer scheduledTimerWithTimeInterval:2
													  target:self
													selector:@selector(query)
													userInfo:nil
													 repeats:YES];
    [super viewDidLoad];
}


/*
 // Override to allow orientations other than the default portrait orientation.
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
 // Return YES for supported orientations
 return (interfaceOrientation == UIInterfaceOrientationPortrait);
 }
 */


/*
 NOTE we don't actually disable timers.  This means that as long as the app
 is running, plotting and querying continue.  If the app moves into the
 background, then the OS ignores these timers.
 
// restart timers for plotting and querying
-(void) viewWillAppear:(BOOL)animated{
}

// pause timers for plotting and querying
-(void) viewDidDissapear:(BOOL)animated{
}
 */

#pragma mark -
#pragma mark app events

-(void) query{
	// query for matches
	QueryResult result;
	unsigned int numMatches = app.database->queryMatches( result, self.newFingerprint, 
														  numCandidates, [app getLocation] );
	
	// update status display
	NSMutableString* ss = [[NSMutableString alloc] initWithFormat:@"%d matches: ",numMatches];
	if( numMatches >= 1 ){
		[ss appendFormat:@"%@ %@",result[0].entry.building,result[0].entry.room];
	}
	if( numMatches >= 2 ){
		[ss appendFormat:@" / %@ %@",result[1].entry.building,result[1].entry.room];
	}
	if( numMatches >= 3 ){
		[ss appendFormat:@" / %@ %@",result[2].entry.building,result[2].entry.room];
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


-(void)clearButtonHandler{
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
		[self query]; // this is a hack to clear the candidate plots
		[statusLabel setText:@"Database cleared"];
	}
}


#pragma mark -
#pragma mark TableView DataSource/Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return @"Room matches";
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
	return numCandidates;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // The cells for the location rows use the cell style "UITableViewCellStyleSubtitle", which has a left-aligned label across the top and a left-aligned label below it in smaller gray text. The text label shows the coordinates for the location and the detail text label shows its timestamp.
	static NSString * const kMatchCellID = @"MatchCellID";
	UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:kMatchCellID];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle 
									   reuseIdentifier:kMatchCellID] autorelease];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	cell.textLabel.text = @"some match";
	cell.detailTextLabel.text = @"some timestamp or coordinates";
    return cell;
}

/*
// Delegate method invoked after the user selects a row. Selecting a row containing a location object
// will navigate to a new view controller displaying details about that location.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    CLLocation *location = [locationMeasurements objectAtIndex:indexPath.row];
    self.locationDetailViewController.location = location;
    [self.navigationController pushViewController:locationDetailViewController animated:YES];
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
