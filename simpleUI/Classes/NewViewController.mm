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
@synthesize buildingField;
@synthesize roomField;
@synthesize roomPicker;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		self.view.backgroundColor = [UIColor clearColor]; // set striped BG
		
		// create buildingField
		CGRect rect = CGRectMake(10 , 80, 150.0f, 30.0f);
		self.buildingField = [[[UITextField alloc] initWithFrame:rect] autorelease];
		[buildingField setPlaceholder:@"building's name"];
		[buildingField setBorderStyle:UITextBorderStyleRoundedRect];
		buildingField.autocorrectionType = UITextAutocorrectionTypeNo;
		buildingField.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x'
		buildingField.delegate = self; // sends events to this class, so this class must implement UITextFieldDelegate protocol
		[self.view addSubview:buildingField];
		
		// create roomField
		rect = CGRectMake(160 , 80, 150.0f, 30.0f);
		self.roomField = [[[UITextField alloc] initWithFrame:rect] autorelease];
		[roomField setPlaceholder:@"new room's name"];
		[roomField setBorderStyle:UITextBorderStyleRoundedRect];
		roomField.autocorrectionType = UITextAutocorrectionTypeNo;
		roomField.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x'
		roomField.delegate = self; // sends events to this class, so this class must implement UITextFieldDelegate protocol
		[self.view addSubview:roomField];
		
		// create picker
		rect = CGRectMake( 0, 265, 300, 300 );
		self.roomPicker = [[[UIPickerView alloc] initWithFrame:rect] autorelease];
		roomPicker.delegate = roomPicker.dataSource = self;
		roomPicker.showsSelectionIndicator = YES;
		[self.view addSubview:roomPicker];
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
	NSString* newBuilding;
	if( self.buildingField.text.length > 0 ){
		newBuilding = [[NSString alloc] initWithString:self.buildingField.text]; 
	}else{
		newBuilding = [[NSString alloc] initWithFormat:@"<unnamed>"];
	}
	NSString* newRoom;
	if( self.roomField.text.length > 0 ){
		newRoom = [[NSString alloc] initWithString:self.roomField.text]; 
	}else{
		newRoom = [[NSString alloc] initWithFormat:@"<unnamed>"];
	}
	
	// get new fingerprint
	Fingerprint newFP = new float[Fingerprinter::fpLength];
	app.fp->getFingerprint( newFP );
	// add to database
	UInt32 uid = app.database->insertFingerprint(newFP, newBuilding, newRoom, [app getLocation] );
	NSLog(@"room #%d: %@ %@ saved",uid,newBuilding,newRoom);
	[newBuilding release];
	[newRoom release];
	delete [] newFP;
	
	// save the entire database, since it's changed
	app.database->save();
}

#pragma mark -
#pragma mark UITextFieldDelegate

// make the keyboard dissapear after hit return. 
// We are overriding a method inherited from the UITextFieldDelegate protocol
- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
    [theTextField resignFirstResponder]; // make keyboard dissapear
    return YES;	
}

#pragma mark -
#pragma mark UIPickerViewDelegate

// picker state
vector<NSString*> buildingsCache;
vector<NSString*> roomsCache;
NSString* currentBuilding;

- (void)pickerView:(UIPickerView *)pickerView 
	  didSelectRow:(NSInteger)row 
	   inComponent:(NSInteger)component{
	// set appropriate fields
	if( component == 0 ){
		currentBuilding = buildingsCache[row];
		[pickerView reloadComponent:1]; // reload room names
		[buildingField setText:currentBuilding];
		[pickerView selectRow:0 inComponent:1 animated:NO]; // reset picker placement
		[roomField setText:roomsCache[0]]; // adjust textfield
	}else{
		[roomField setText:roomsCache[row]];
	}
}

- (NSString *)pickerView:(UIPickerView *)pickerView 
			 titleForRow:(NSInteger)row 
			forComponent:(NSInteger)component{
	if( component == 0 ){
		return buildingsCache[row];
	}else{
		return roomsCache[row];
	}
}

#pragma mark -
#pragma mark UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView{
	return 2;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView 
numberOfRowsInComponent:(NSInteger)component{
	if( component == 0 ){
		// reload list of buildings
		buildingsCache.clear();
		app.database->getAllBuildings( buildingsCache );
		if( currentBuilding == nil ) currentBuilding = buildingsCache[0]; // default picker placement
		return buildingsCache.size();
	}else{
		// reload list of rooms
		roomsCache.clear();
		app.database->getRoomsInBuilding( roomsCache, currentBuilding );
		return roomsCache.size();
	}
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
	[roomField release];
	[buildingField release];
	[roomPicker release];

    [super dealloc];
}


@end
