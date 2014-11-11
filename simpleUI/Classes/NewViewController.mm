//
//  NewViewController.m
//  simpleUI
//
//  Created by Stephen Tarzia on 10/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import "NewViewController.h"
#import "LocationViewController.h" // for map zoom

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

- (id)initWithApp:(AppDelegate *)theApp {
	self.app = theApp;
	if ((self = [super initWithNibName:nil bundle:nil])) {
        // Custom initialization
		self.view.backgroundColor = [UIColor whiteColor];

        // add extra padding to the top of the view on iOS >= 7
        CGFloat topPadding = [[UIDevice currentDevice] systemVersion].floatValue >= 7? 64 : 0;
        CGFloat screenHeight = self.view.frame.size.height - topPadding;

		// create instruction label
		self.locationLabel = [[[UILabel alloc] initWithFrame:
                               CGRectMake(10 , topPadding + 5, 300.0f, 35.0f)] autorelease];
		// Set the value of our string
		[locationLabel setText:@"Describe your current location:"];
		// Center Align the label's text
		[locationLabel setTextAlignment:NSTextAlignmentLeft];
		locationLabel.textColor = [UIColor darkTextColor];
		locationLabel.backgroundColor = [UIColor clearColor];
		// set font
		[locationLabel setFont:[UIFont fontWithName:@"Arial" size:18]];
		// Add the label to the window.
		[self.view addSubview:locationLabel];
		
		// create buildingField
		CGRect rect = CGRectMake(10 , topPadding + 40, 150.0f, 30.0f);
		self.buildingField = [[[UITextField alloc] initWithFrame:rect] autorelease];
		[buildingField setPlaceholder:@"building's name"];
		[buildingField setBorderStyle:UITextBorderStyleRoundedRect];
		buildingField.autocorrectionType = UITextAutocorrectionTypeNo;
		buildingField.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x'
		buildingField.delegate = self; // sends events to this class, so this class must implement UITextFieldDelegate protocol
		[self.view addSubview:buildingField];
		
		// create roomField
		rect = CGRectMake(160 , topPadding + 40, 150.0f, 30.0f);
		self.roomField = [[[UITextField alloc] initWithFrame:rect] autorelease];
		[roomField setPlaceholder:@"room's name"];
		[roomField setBorderStyle:UITextBorderStyleRoundedRect];
		roomField.autocorrectionType = UITextAutocorrectionTypeNo;
		roomField.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x'
		roomField.delegate = self; // sends events to this class, so this class must implement UITextFieldDelegate protocol
		[self.view addSubview:roomField];
		
		// create picker
        CGFloat keyboardHeight = 216;
		currentBuilding = @"";
		rect = CGRectMake( 0, topPadding + 70, 320, screenHeight - keyboardHeight - (topPadding + 70));
		self.roomPicker = [[[UIPickerView alloc] initWithFrame:rect] autorelease];
		roomPicker.delegate = self;
        roomPicker.dataSource = self;
		roomPicker.showsSelectionIndicator = YES;
		[self.view addSubview:roomPicker];
    }
    return self;
}

-(UINavigationItem*)navigationItem{
    if( !navItem ){
        navItem = [[UINavigationItem alloc] initWithTitle:@"Check in"];
        // add button to navigation bar
        UIBarButtonItem* newButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                   target:self
                                                                                   action:@selector(saveButtonHandler)];
        [navItem setRightBarButtonItem:newButton animated:NO];
    }
    return navItem;
}

-(void) viewWillAppear:(BOOL)animated{
	[super viewWillAppear:animated];
	if( [currentBuilding isEqualToString:@""] ){
		// by default set building picker to <new>
		// Note that we call pickerView:numberOfRowsInComponent: to build buildingCache
		[roomPicker selectRow:[self pickerView:roomPicker numberOfRowsInComponent:0]-1
				  inComponent:0 animated:NO];
	}
    // update picker to reflect possible database changes (new/deleted rooms)
    [roomPicker reloadAllComponents];
}

#pragma mark -
#pragma mark button event handling

/* called by button */
-(bool) saveButtonHandler{
	if( self.buildingField.text.length > 0  && self.roomField.text.length > 0 ){
		// build name
		NSString* newBuilding = [[NSString alloc] initWithString:self.buildingField.text]; 
		NSString* newRoom = [[NSString alloc] initWithString:self.roomField.text];
		currentBuilding = newBuilding;
		
		[self.app checkinWithRoom:newRoom inBuilding:newBuilding];
		[newBuilding release];
		[newRoom release];
		
        [self.navigationController popViewControllerAnimated:YES];
	}else{
		// notify user that text fields cannot be left blank
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Name is missing" 
														message:@"You must choose a building and room name before saving this location tag.  You may choose from existing names or enter a new name." 
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
-(void) resetPicker{
	// reload list of buildings
	buildingsCache.clear();
	[app.database getAllBuildings:buildingsCache];
	currentBuilding = @"";
	
	// clear list of rooms
	roomsCache.clear();

	[buildingField setText:@""];
	[roomField setText:@""];
	[roomPicker reloadAllComponents];
}

#pragma mark UIPickerView Delegate

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

#pragma mark UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView{
	return 2;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView 
numberOfRowsInComponent:(NSInteger)component{
	if( component == 0 ){
		// reload list of buildings
		buildingsCache.clear();
		[app.database getAllBuildings:buildingsCache];
		
		return buildingsCache.size()+1; // plus one for "custom" row
	}else{
		// reload list of rooms
		roomsCache.clear();
		[app.database getRooms:roomsCache inBuilding:currentBuilding];
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
