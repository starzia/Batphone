//
//  MatchViewController.m
//  simpleUI
//
//  Created by Stephen Tarzia on 10/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//
// Note that bat image is from http://commons.wikimedia.org/wiki/File:Bat_(PSF).jpg
// By Pearson Scott Foresman [Public domain], via Wikimedia Commons

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
@synthesize distanceMetric;
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
		self.matches = [[NSMutableArray alloc] init];
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
	imageView.center = CGPointMake(160, 60);
	[self.view addSubview:imageView];
	[imageView release];
	
	// add bat image to window
	UIImage* batImage = [UIImage imageNamed:@"bat.png"];
	UIImageView* imageView2 = [[UIImageView alloc] initWithImage:batImage];
	imageView2.alpha = 0.2;
	imageView2.center = CGPointMake(160, 230);
	[self.view addSubview:imageView2];
	[imageView2 release];
	
	// Add plot to window
	CGRect rect = CGRectMake(10, 10, 300.0f, 100.0f);
	self.plot = [[[plotView alloc] initWith_Frame:rect] autorelease];
	[self.plot setVector: newFingerprint length: Fingerprinter::fpLength];
	// make line green
	self.plot.lineColor[0] = 0.5; //R
	self.plot.lineColor[1] = 1; //G
	self.plot.lineColor[2] = 0.2; //B
	[self.view addSubview:plot];
	
	// Add map which will be show alternatively in place of plot
	self.map = [[[MKMapView alloc] initWithFrame:CGRectMake(0,0,320,125)] autorelease];
	map.scrollEnabled = NO;
	map.zoomEnabled = NO;
	map.mapType = MKMapTypeHybrid;
	[self.view addSubview:map];
	
	// create matchTable
	rect = CGRectMake( 0, 120, 320, 245 );
	self.matchTable = [[[UITableView alloc] initWithFrame:rect style:UITableViewStylePlain] autorelease];
	matchTable.backgroundColor = [UIColor clearColor];
	matchTable.delegate = self;
    matchTable.dataSource = self;
	[self.view addSubview:matchTable];
	
	// create tabbar at bottom
	rect = CGRectMake(0, 366, 320, 50);
	self.tabBar = [[[UITabBar alloc] initWithFrame:rect] autorelease];
	tabBar.delegate = self;
	UITabBarItem* acousticButton = [[UITabBarItem alloc] autorelease];
	[acousticButton initWithTitle:@"Acoustic" 
							image:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"mic" 
																								   ofType:@"png"]] 
							  tag:0];	
	UITabBarItem* combinedButton = [[UITabBarItem alloc] autorelease];
	[combinedButton initWithTitle:@"Combined"
							image:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"combined" 
																								   ofType:@"png"]]  
							  tag:1];
	UITabBarItem* wifiButton = [[UITabBarItem alloc] autorelease];
	[wifiButton initWithTitle:@"Radio"
						image:[UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"bullseye" 
																							   ofType:@"png"]]  
						  tag:2];
	NSArray* barItems = [NSArray arrayWithObjects:acousticButton,combinedButton,wifiButton,nil];
	[self.tabBar setItems:barItems animated:NO];
	[self.view addSubview:tabBar];
	
	// decide which tab should be used by default.
	int defaultTab = 1;
	self.tabBar.selectedItem=[tabBar.items objectAtIndex:defaultTab];
	[self tabBar:tabBar didSelectItem:[tabBar.items objectAtIndex:defaultTab]]; 
	
	// alert user that fingerprint is not yet ready
	alert = [[UIAlertView alloc] initWithTitle:@"Please wait" 
									   message:@"Ten seconds of audio are needed to compute a room fingerprint." 
									  delegate:nil 
							 cancelButtonTitle:nil 
							 otherButtonTitles:nil];
	[alert show];
	// add spinning activity indicator
	UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]  
										  initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];  
	indicator.center = CGPointMake(140, 110);  
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


// restart timers for plotting and querying
-(void) viewWillAppear:(BOOL)animated{
	if( !plotTimer ){
		// create timer to update the plot
		self.plotTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
														  target:self
														selector:@selector(updatePlot)
														userInfo:nil
														 repeats:YES];
	}
	if( !queryTimer ){
		// create timer to continuously query
		self.queryTimer = [NSTimer scheduledTimerWithTimeInterval:2
														   target:self
														 selector:@selector(query)
														 userInfo:nil
														  repeats:YES];
	}
}

// pause timers for plotting and querying
-(void) viewDidDissapear:(BOOL)animated{
	[plotTimer invalidate];
	[plotTimer release];
	plotTimer = nil;
	[queryTimer invalidate];
	[queryTimer release];
	queryTimer = nil;
}


#pragma mark -
#pragma mark app events

-(void) query{
	// query for matches
	[matches removeAllObjects]; // clear previous results
	[app.database startQueryWithObservation:self.newFingerprint
								 numMatches:numCandidates
								   location:[app getLocation]
							 distanceMetric:distanceMetric
							   resultTarget:self
								   selector:@selector(updateMatches:)];

	// UNRELATED TO QUERY...
	// update map with current skyhook location
	[map removeAnnotations:map.annotations];
	[LocationViewController annotateMap:map 
							   location:[self.app getLocation]
								  title:@"approximate location"];
	[LocationViewController zoomToFitMapAnnotations:map];
}

/* called by FingerprintDB query callback */
-(void) updateMatches:(NSArray*) results{
	// load in the new results
	if( results != nil ){
		[matches setArray:results];
	}
	[matchTable reloadData];
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
			[self.plot autoRange]; // set plot range
		}
	}
}


#pragma mark -
#pragma mark UITabBarDelegate
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item{
	// change distance metric accordingly
	// and switch between plot/map
	if( item.tag == 0 ){ // Acoustic
		distanceMetric = DistanceMetricAcoustic;
		[plot setHidden:NO];
		[map setHidden:YES];
	}else if( item.tag == 2 ){ // Radio
		distanceMetric = DistanceMetricPhysical;
		[map setHidden:NO];
		[plot setHidden:YES];
	}else if( item.tag == 1 ){ //  Combined
		distanceMetric = DistanceMetricCombined;
		[map setHidden:YES];
		[plot setHidden:NO];
	}
	// reload table
	[self query];
}


#pragma mark -
#pragma mark TableView DataSource/Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if( distanceMetric == DistanceMetricCombined ){
		return [NSString stringWithFormat:@"Closest locations"];
	}else if( distanceMetric == DistanceMetricPhysical ){
		return [NSString stringWithFormat:@"Closest locations (%.0f m accuracy)",
				app.getLocation.horizontalAccuracy];
	}else{
		return @"Closest locations";
	}
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
	return [matches count];
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
	if( [matches count] > indexPath.row ){
		Match* match = [matches objectAtIndex:indexPath.row];
		DBEntry* entry =  match.entry;
		// main label is the room name
		cell.textLabel.text = [[[NSString alloc] 
								initWithFormat:@"%ld) %@ : %@",(unsigned long)indexPath.row+1,
								entry.building, entry.room ] autorelease];
		// secondary label depends on the distance metric
		NSString* detailText;
		if( distanceMetric == DistanceMetricAcoustic ){
			detailText = [[NSString alloc] initWithFormat:@"acoustic fingerprint distance: %.1f dB", 
						  match.distance];		
		}else if( distanceMetric == DistanceMetricPhysical ){
			detailText = [[NSString alloc] initWithFormat:@"estimated physical distance: %.0f meters", 
						  match.distance];
		}else{ // DistanceMetricCombined
			detailText = [[NSString alloc] initWithFormat:@"acoustic+physical distance: %.3f", 
						  match.distance];		
		}
		cell.detailTextLabel.text = detailText;
		[detailText release];
	}
    return cell;
}

// Delegate method invoked after the user selects a row. Selecting a row containing a location object
// will navigate to a new view controller displaying details about that location.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
	Match* match = [matches objectAtIndex:indexPath.row];
	DBEntry* entry =  match.entry;
	[app showRoom:entry.room inBuilding:entry.building];
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
	[queryTimer release];
	delete[] newFingerprint;
	[matchTable release];
	[alert release];
	[tabBar release];
	[map release];
    [super dealloc];
}


@end
