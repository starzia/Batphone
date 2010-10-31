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
@synthesize locationLabel;

@synthesize buildingsCache;
@synthesize roomsCache;
@synthesize currentBuilding;

#pragma mark -
#pragma mark UIViewController inherited

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		self.view.backgroundColor = [UIColor clearColor]; // set striped BG
		
		// create instruction label
		self.locationLabel = [[[UILabel alloc] initWithFrame:CGRectMake(10 , 200, 300.0f, 30.0f)] autorelease];
		// Set the value of our string
		[locationLabel setText:@"Describe your current location:"];
		// Center Align the label's text
		[locationLabel setTextAlignment:UITextAlignmentLeft];
		locationLabel.textColor = [UIColor darkTextColor];
		locationLabel.backgroundColor = [UIColor clearColor];
		// set font
		[locationLabel setFont:[UIFont fontWithName:@"Arial" size:12]];
		// Add the label to the window.
		[self.view addSubview:locationLabel];
		
		// create buildingField
		CGRect rect = CGRectMake(10 , 230, 150.0f, 30.0f);
		self.buildingField = [[[UITextField alloc] initWithFrame:rect] autorelease];
		[buildingField setPlaceholder:@"building's name"];
		[buildingField setBorderStyle:UITextBorderStyleRoundedRect];
		buildingField.autocorrectionType = UITextAutocorrectionTypeNo;
		buildingField.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x'
		buildingField.delegate = self; // sends events to this class, so this class must implement UITextFieldDelegate protocol
		[self.view addSubview:buildingField];
		
		// create roomField
		rect = CGRectMake(160 , 230, 150.0f, 30.0f);
		self.roomField = [[[UITextField alloc] initWithFrame:rect] autorelease];
		[roomField setPlaceholder:@"room's name"];
		[roomField setBorderStyle:UITextBorderStyleRoundedRect];
		roomField.autocorrectionType = UITextAutocorrectionTypeNo;
		roomField.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x'
		roomField.delegate = self; // sends events to this class, so this class must implement UITextFieldDelegate protocol
		[self.view addSubview:roomField];
		
		// create picker
		currentBuilding = @"";
		rect = CGRectMake( 0, 265, 300, 300 );
		self.roomPicker = [[[UIPickerView alloc] initWithFrame:rect] autorelease];
		roomPicker.delegate = roomPicker.dataSource = self;
		roomPicker.showsSelectionIndicator = YES;
		[self.view addSubview:roomPicker];
    }
    return self;
}

-(void) viewWillAppear:(BOOL)animated{
	[super viewWillAppear:animated];
	if( [currentBuilding isEqualToString:@""] ){
		// by default set building picker to <new>
		// Note that we call pickerView:numberOfRowsInComponent: to build buildingCache
		[roomPicker selectRow:[self pickerView:roomPicker numberOfRowsInComponent:0]-1
				  inComponent:0 animated:NO];
	}
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

#pragma mark -
#pragma mark button event handling

/* called by button */
-(bool) saveButtonHandler{
	if( self.buildingField.text.length > 0  && self.roomField.text.length > 0 ){
		// build name
		NSString* newBuilding = [[NSString alloc] initWithString:self.buildingField.text]; 
		NSString* newRoom = [[NSString alloc] initWithString:self.roomField.text];
		currentBuilding = newBuilding;
		
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
		
		return true;
	}else{
		// notify user that text fields cannot be left blank
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Name is missing" 
														message:@"You must choose a building and room name before saving this Fingerprint.  You may choose from existing names or enter a new name." 
													   delegate:nil 
											  cancelButtonTitle:@"OK" 
											  otherButtonTitles:nil];
		[alert show];
		[alert release];
		return false;
	}
}


#pragma mark -
#pragma mark UITextFieldDelegate

// make the keyboard dissapear after hit return. 
// We are overriding a method inherited from the UITextFieldDelegate protocol
- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
    [theTextField resignFirstResponder]; // make keyboard dissapear
    return YES;	
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	// if user is editing field, then set picker to <new> row
	if( textField == buildingField ){
		[roomPicker selectRow:buildingsCache.size() inComponent:0 animated:NO];
		[self pickerView:roomPicker didSelectRow:buildingsCache.size() inComponent:0];
	}else{
		[roomPicker selectRow:roomsCache.size() inComponent:1 animated:NO];
		[self pickerView:roomPicker didSelectRow:roomsCache.size() inComponent:1];
	}
}

#pragma mark -
#pragma mark UIPickerViewDelegate

- (void)pickerView:(UIPickerView *)pickerView 
	  didSelectRow:(NSInteger)row 
	   inComponent:(NSInteger)component{
	// set appropriate fields
	if( component == 0 ){
		if ( row == buildingsCache.size() ){
			// if <new> was selected, clear the textfield
			currentBuilding = @"";
		}else{
			// if a buiding name was selected, set it in the textfield
			currentBuilding = buildingsCache[row];
		}
		[pickerView reloadComponent:1]; // reload room names
		[buildingField setText:currentBuilding];
		[pickerView selectRow:roomsCache.size() inComponent:1 animated:NO]; // reset room picker
		[self pickerView:roomPicker didSelectRow:roomsCache.size() inComponent:1];
	}else if( component == 1){
		if ( row == roomsCache.size() ){
			// if <new> was selected, clear the textfield
			[roomField setText:@""];
		}else{
			// if a room name was selected, set it in the textfield
			[roomField setText:roomsCache[row]];
		}
	}
}

- (NSString *)pickerView:(UIPickerView *)pickerView 
			 titleForRow:(NSInteger)row 
			forComponent:(NSInteger)component{
	if( component == 0 ){
		if( row < buildingsCache.size() ){
			return buildingsCache[row];
		}else{
			return @""; //@"<new>";
		}
	}else{
		if( row < roomsCache.size() ){
			return roomsCache[row];
		}else{
			return @""; //@"<new>";
		}
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
		
		return buildingsCache.size()+1; // plus one for "custom" row
	}else{
		// reload list of rooms
		roomsCache.clear();
		app.database->getRoomsInBuilding( roomsCache, currentBuilding );
		return roomsCache.size()+1; // plus one for "custom" row
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
