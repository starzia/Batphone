//
//  MatchViewController.m
//  simpleUI
//
//  Created by Stephen Tarzia on 10/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import "MatchViewController.h"
#import "LocationViewController.h" // for map functions

@implementation MatchViewController

@synthesize app;
@synthesize plot;
@synthesize plotTimer;
@synthesize queryTimer;
@synthesize newFingerprint;
@synthesize matchTable;
@synthesize matches;
@synthesize alert;
@synthesize tabBar;
@synthesize useAcousticDistance;
@synthesize map;

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

- (id)initWithApp:(AppDelegate *)theApp{
	if ((self = [super initWithNibName:nil bundle:nil])) {
        // Custom initialization
		self.app = theApp;
    }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
	self.view.backgroundColor = [UIColor clearColor];
		
	// initialize and blank fingerprint
	self.newFingerprint = new float[Fingerprinter::fpLength];
	for (int i=0; i<Fingerprinter::fpLength; ++i){
		// blank fingerprint
		self.newFingerprint[i] = 0;
	}
	
	// add CRT image to window
	UIImage* crtImage = [UIImage imageNamed:@"crt.png"];
	UIImageView* imageView = [[UIImageView alloc] initWithImage:crtImage];
	imageView.center = CGPointMake(160, 105);
	[self.view addSubview:imageView];
	[imageView release];
	
	// Add plot to window
	CGRect rect = CGRectMake(10, 55, 300.0f, 100.0f);
	self.plot = [[[plotView alloc] initWith_Frame:rect] autorelease];
	[self.plot setVector: newFingerprint length: Fingerprinter::fpLength];
	// make line red
	self.plot.lineColor[0] = 0.5; //R
	self.plot.lineColor[1] = 1; //G
	self.plot.lineColor[2] = 0.2; //B
	[self.view addSubview:plot];
	
	// Add map which will be show alternatively in place of plot
	self.map = [[[MKMapView alloc] initWithFrame:CGRectMake(0,40,320,135)] autorelease];
	map.scrollEnabled = NO;
	map.zoomEnabled = NO;
	map.mapType = MKMapTypeHybrid;
	[self.view addSubview:map];
	
	// create matchTable
	rect = CGRectMake( 0, 165, 320, 245 );
	self.matchTable = [[[UITableView alloc] initWithFrame:rect style:UITableViewStylePlain] autorelease];
	matchTable.backgroundColor = [UIColor clearColor];
	matchTable.delegate = matchTable.dataSource = self;
	[self.view addSubview:matchTable];
	
	// create tabbar at bottom
	rect = CGRectMake(0, 410, 320, 50);
	self.tabBar = [[[UITabBar alloc] initWithFrame:rect] autorelease];
	tabBar.delegate = self;
	UITabBarItem* acousticButton = [[UITabBarItem alloc] autorelease];
	[acousticButton initWithTitle:@"Acoustic" 
							image:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"mic" 
																								   ofType:@"png"]] 
							  tag:0];	
	UITabBarItem* wifiButton = [[UITabBarItem alloc] autorelease];
	[wifiButton initWithTitle:@"GPS/Wifi"
						image:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"bullseye" 
																							   ofType:@"png"]]  
						  tag:0];
	NSArray* barItems = [NSArray arrayWithObjects:acousticButton,wifiButton,nil];
	[self.tabBar setItems:barItems animated:NO];
	[self tabBar:tabBar didSelectItem:acousticButton]; // default tabBar choice
	[self.view addSubview:tabBar];
	
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
	// alert user that fingerprint is not yet ready
	alert = [[UIAlertView alloc] initWithTitle:@"Please wait" 
									   message:@"Ten seconds of audio is needed to compute a room fingerprint." 
									  delegate:nil 
							 cancelButtonTitle:nil 
							 otherButtonTitles:nil];
	[alert show];
	// add spinning activity indicator
	UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]  
										  initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];  
	indicator.center = CGPointMake(alert.bounds.size.width / 2,   
								   alert.bounds.size.height - 45);  
	[indicator startAnimating];  
	[alert addSubview:indicator];  
	[indicator release];  
	
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
	app.database->queryMatches( matches, self.newFingerprint, numCandidates, 
							    [app getLocation], useAcousticDistance );
	// update table
	[matchTable reloadData];
	
	// update map
	[map removeAnnotations:map.annotations];
	[LocationViewController annotateMap:map 
							   location:[self.app getLocation]
								  title:@"approximate GPS location"];
	[LocationViewController zoomToFitMapAnnotations:map];
}


-(void)clearButtonHandler{
	UIAlertView *myAlert = [[UIAlertView alloc] initWithTitle:@"Really clear database?" 
													  message:@"You are about to delete ALL of your location tags." 
													 delegate:self 
											cancelButtonTitle:@"Cancel" 
											otherButtonTitles:nil];
	[myAlert addButtonWithTitle:@"Delete"];
	[myAlert show];
	[myAlert release];
}

/* called by timer */
-(void) updatePlot{
	// get the current fingerprint and save to "New" slot
	if( app.fp->getFingerprint( self.newFingerprint ) ){
		// if successful, then redraw
		[self.plot setNeedsDisplay];
		
		// if fingerprint is newly available, then dismiss alert
		if( alert.visible && self.newFingerprint[0]>0 ){
			[alert dismissWithClickedButtonIndex:0 animated:YES];
		}
	}
}


#pragma mark -
#pragma mark UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
	// if "delete" button was clicked then clear the database
	if( buttonIndex == 1 ){
		app.database->clear();
		[self query]; // this is a hack to clear the candidate plots
	}
}


#pragma mark -
#pragma mark UITabBarDelegate
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item{
	// change distance metric accordingly
	useAcousticDistance = [item.title isEqualToString:@"Acoustic"];
	// reload table
	[self query];
	// switch between plot/map
	if( useAcousticDistance ){
		[plot setHidden:NO];
		[map setHidden:YES];
	}else{
		[map setHidden:NO];
		[plot setHidden:YES];
	}
}


#pragma mark -
#pragma mark TableView DataSource/Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return @"Closest tags";
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
	DBEntry* entry = &matches[indexPath.row].entry;
	// main label is the room name
	cell.textLabel.text = [[[NSString alloc] 
		initWithFormat:@"%d) %@ : %@",indexPath.row+1,
						entry->building, entry->room ] autorelease];
	// secondary label depends on the distance metric
	NSString* detailText;
	if( useAcousticDistance ){
		detailText = [[NSString alloc] initWithFormat:@"acoustic fingerprint distance: %.1f dB", 
											matches[indexPath.row].distance];		
	}else{
		detailText = [[NSString alloc] initWithFormat:@"estimated GPS distance: %.0f meters", 
											matches[indexPath.row].distance];
	}
	cell.detailTextLabel.text = detailText;
	[detailText release];
    return cell;
}

// Delegate method invoked after the user selects a row. Selecting a row containing a location object
// will navigate to a new view controller displaying details about that location.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
	DBEntry* entry = &matches[indexPath.row].entry;
	[app showRoom:entry->room inBuilding:entry->building];
}


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
	[alert release];
	[tabBar release];
	[map release];
    [super dealloc];
}


@end
