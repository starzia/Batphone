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
@synthesize plot;
@synthesize plotTimer;
@synthesize queryTimer;
@synthesize newFingerprint;
@synthesize matchTable;
@synthesize matches;

// CONSTANTS
static const int numCandidates = 10;

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
		
	// initialize and blank fingerprint
	self.newFingerprint = new float[Fingerprinter::fpLength];
	for (int i=0; i<Fingerprinter::fpLength; ++i){
		// blank fingerprint
		self.newFingerprint[i] = 0;
	}
	
	// Add plot to window
	CGRect rect = CGRectMake(0, 80, 320.0f, 100.0f);
	self.plot = [[[plotView alloc] initWith_Frame:rect] autorelease];
	[self.plot setVector: newFingerprint length: Fingerprinter::fpLength];
	[self.view addSubview:plot];
	
	// create matchTable
	rect = CGRectMake( 0, 210, 320, 270 );
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
	matches.clear(); // clear previous results
	app.database->queryMatches( matches, self.newFingerprint, 
								numCandidates, [app getLocation] );
	// update table
	[matchTable reloadData];
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
	}
}


#pragma mark -
#pragma mark TableView DataSource/Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return @"Room fingerprint matches";
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
	return matches.size();
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
	cell.textLabel.text = [[[NSString alloc] 
		initWithFormat:@"%@ : %@",matches[indexPath.row].entry.building,
								  matches[indexPath.row].entry.room ] autorelease];
	cell.detailTextLabel.text = [[[NSString alloc]
		initWithFormat:@"GPS: %f %f %f",
					matches[indexPath.row].entry.location.latitude,
					matches[indexPath.row].entry.location.longitude,
					matches[indexPath.row].entry.location.altitude] autorelease];
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
	[plot release];
	[plotTimer release];
	delete[] newFingerprint;
	[matchTable release];
    [super dealloc];
}


@end
