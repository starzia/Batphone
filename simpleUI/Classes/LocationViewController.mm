//
//  LocationViewController.m
//  simpleUI
//
//  Created by Stephen Tarzia on 10/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import "LocationViewController.h"


@implementation LocationViewController

@synthesize app;
@synthesize room;
@synthesize building;
@synthesize fingerprints;
@synthesize plot;
@synthesize plotTimer;
@synthesize plotIndex;
@synthesize label;


 // The custom initializer.  
- (id)initWithApp:(AppDelegate *)theApp 
		 building:(NSString*)theBuilding
			 room:(NSString*)theRoom{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        // set member variables
		self.app = theApp;
		self.building = theBuilding;
		self.room = theRoom;
		self.plotIndex = 0;
		
		// load room's fingerprints from database
		app.database->getEntriesFrom( fingerprints, self.building, self.room );

		// set up view
		self.view.backgroundColor = [UIColor clearColor];
		
		// Add plot label
		CGRect labelRect = CGRectMake(0 , 200, 320.0f, 20.0f);
		self.label = [[[UILabel alloc] initWithFrame:labelRect] autorelease];
		[label setTextAlignment:UITextAlignmentCenter];
		label.textColor = [UIColor darkTextColor];
		label.backgroundColor = [UIColor clearColor];
		[label setFont:[UIFont fontWithName:@"Arial" size:10]];
		[self.view addSubview:label];	
		
		if( fingerprints.size() > 0 ){
			// Add plot to window
			CGRect rect = CGRectMake(0, 80, 320.0f, 100.0f);
			self.plot = [[[plotView alloc] initWith_Frame:rect] autorelease];
			[self updatePlot];
			[self.view addSubview:plot];
		
			// create timer to update the plot
			self.plotTimer = [NSTimer scheduledTimerWithTimeInterval:1
															  target:self
															selector:@selector(updatePlot)
															userInfo:nil
															 repeats:YES];
		}
	}
    return self;
}

/* called by timer */
-(void) updatePlot{
	// switch to the next fingerprint
	plotIndex = (plotIndex+1) % fingerprints.size();
	
	[self.plot setVector:fingerprints[plotIndex].fingerprint length: Fingerprinter::fpLength];
	NSString* dateString = [[NSDate dateWithTimeIntervalSince1970:fingerprints[plotIndex].timestamp] 
							descriptionWithLocale:[NSLocale currentLocale]];
	[self.label setText:dateString];
	[self.plot setNeedsDisplay];
}

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

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
	[building release];
	[room release];
	[plot release];
	[plotTimer release];
    [super dealloc];
}


@end
