//
//  NewViewController.m
//  simpleUI
//
//  Created by Stephen Tarzia on 10/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import "NewViewController.h"


@implementation NewViewController

@synthesize app;
@synthesize nameLabel;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		self.view.backgroundColor = [UIColor clearColor]; // set striped BG
		
		// create textField
		CGFloat x = 320/2 - 300/2; // screen width / 2 - label width / 2
		CGRect labelRect = CGRectMake(x , 80, 300.0f, 30.0f);
		self.nameLabel = [[[UITextField alloc] initWithFrame:labelRect] autorelease];
		[nameLabel setPlaceholder:@"new room's name"];
		[nameLabel setBorderStyle:UITextBorderStyleRoundedRect];
		nameLabel.autocorrectionType = UITextAutocorrectionTypeNo;
		nameLabel.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x'
		nameLabel.delegate = self; // sends events to this class, so this class must implement UITextFieldDelegate protocol
		[self.view addSubview:nameLabel];
    }
    return self;
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

/* called by button */
-(void) saveButtonHandler{
	// build name
	NSString* newName;
	if( self.nameLabel.text.length > 0 ){
		newName = [[NSString alloc] initWithString:self.nameLabel.text]; 
	}else{
		newName = [[NSString alloc] initWithFormat:@"<unnamed>"];
	}
	
	// get new fingerprint
	Fingerprint newFP = new float[Fingerprinter::fpLength];
	app.fp->getFingerprint( newFP );
	// add to database
	UInt32 uid = app.database->insertFingerprint(newFP, newName, [app getLocation] );
	[newName release];
	delete [] newFP;
	NSLog(@"room #%d: %@ saved",uid,newName);
	
	// save the entire database, since it's changed
	app.database->save();
}

#pragma mark -
#pragma mark UITextFieldDelegate

// make the keyboard dissapear after hit return. 
// We are overriding a method inherited from the UITextFieldDelegate protocol
- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
    if (theTextField == self.nameLabel) {
        [self.nameLabel resignFirstResponder]; // make keyboard dissapear
    }
    return YES;	
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
	[nameLabel release];

    [super dealloc];
}


@end
