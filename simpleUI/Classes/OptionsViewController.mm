//
//  OptionsViewController.mm
//  simpleUI
//
//  Created by Stephen Tarzia on 11/9/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import "OptionsViewController.h"

@implementation OptionsViewController

@synthesize app;
@synthesize URLField;

#pragma mark -
#pragma mark Initialization


// The custom initializer.  
- (id)initWithStyle:(UITableViewStyle)style app:(AppDelegate *)theApp{
    if ((self = [super initWithStyle:style])) {
		self.app = theApp;
		
		// create URL text field
		UITextField *utextfield = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 120.0, 260.0, 25.0)]; 
		self.URLField = utextfield;
		[utextfield release];		
		URLField.placeholder = @"eg. http://somesite.com/file.txt";
		URLField.text = @"http://stevetarzia.com/batphone/database.txt";
		[URLField setBackgroundColor:[UIColor whiteColor]];
		
    }
    return self;
}


#pragma mark -
#pragma mark View lifecycle

/*
- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}
*/

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
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
#pragma mark MKMailComposeViewControllerDelegate

// finished trying to email
- (void)mailComposeController:(MFMailComposeViewController*)controller 
		  didFinishWithResult:(MFMailComposeResult)result 
						error:(NSError*)error{
	// make email window disappear
	[controller dismissModalViewControllerAnimated:YES];
}



#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if( section == 1 ){
		return @"Advanced database options";
	}else{
		return @"Batphone version: 1.1";
	}
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
	if( section == 0 ){
		return 2;
	}else{
		return 3;
	}
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    // Configure the cell...
	if(indexPath.section == 1 ){
		if(indexPath.row == 0){
			cell.textLabel.text = @"Email database";
		}else if(indexPath.row == 1){
			cell.textLabel.text = @"Load database";
		}else if(indexPath.row == 2){
			cell.textLabel.text = @"Clear database";
		}
	}else if( indexPath.section == 0){
		if( indexPath.row == 0 ){
			cell.textLabel.text = @"Send us feedback";
		}else if(indexPath.row == 1){
			cell.textLabel.text = @"Visit the project website";
		}
	}
	
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	// Email DB or feedback
	if( indexPath.row == 0 ){
		if( [MFMailComposeViewController canSendMail] ){
			MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
			mailer.mailComposeDelegate = self;
			
			if( indexPath.section == 1 ){
				// email database
				[mailer setSubject:@"[Batphone DB]"];
				[mailer setMessageBody:@"Data in database.txt is stored with one line per tagged fingerprint.  Each line has the following fields (separated by tabs): tag id, unix-style timestamp, latitude, longitude, altitude (m), horizontal accuracy (m), vertical accuracy (m), building name, room name, fingerprint[0],...,fingerprint[1023]\n" 
								isHTML:NO];
				[mailer addAttachmentData:[NSData dataWithContentsOfFile:app.database->getDBFilename()] 
								 mimeType:@"text/plain" 
								 fileName:@"database.txt"];
			}else{
				// email feedback
				[mailer setSubject:@"[Batphone feedback]"];
				[mailer setMessageBody:@"" isHTML:NO];
			}
			[mailer setToRecipients:[NSArray arrayWithObject:@"steve@stevetarzia.com"]];
			
			[self presentModalViewController:mailer animated:YES];
			[mailer release];
		}else{
			UIAlertView *myAlert = [[UIAlertView alloc] initWithTitle:@"Email unavailable" 
															  message:@"Please configure your email settings before trying to use this option." 
															 delegate:self 
													cancelButtonTitle:@"OK" 
													otherButtonTitles:nil];
			[myAlert show];
			[myAlert release];	
		}
	}
	// visit website
	else if( indexPath.section == 0 && indexPath.row == 1 ){
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.stevetarzia.com/batphone"]]; 
		[tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
	// delete
	else if( indexPath.section == 1 && indexPath.row == 2 ){
		UIAlertView *myAlert = [[UIAlertView alloc] initWithTitle:@"Really clear database?" 
														  message:@"You are about to delete ALL of your location tags." 
														 delegate:self 
												cancelButtonTitle:@"Cancel" 
												otherButtonTitles:@"Delete",nil];
		[myAlert show];
		[myAlert release];
	}
	// load from URL
	else if( indexPath.section == 1 && indexPath.row == 1 ){
		// Ask for URL
		UIAlertView *alertview = [[UIAlertView alloc] initWithTitle:@"Please supply a URL" 
															message:@"These location tags will be added to your current database.  You should backup your database first.\n\n\n" 
														   delegate:self 
												  cancelButtonTitle:@"Cancel" 
												  otherButtonTitles:@"Load", nil];
		// Adds a URL Field
		[alertview addSubview:self.URLField];
		
		// Show alert on screen.
		[alertview show];
		[alertview release];
	} 
}

	
	
#pragma mark -
#pragma mark UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
	// clear database alert
	if( [alertView.title isEqualToString:@"Really clear database?"] ){
		// if "delete" button was clicked then clear the database
		if( buttonIndex == 1 ){
			app.database->clear();
			// TODO: somehow clear the match table
		}
	}
	// load URL alert
	else if( [alertView.title isEqualToString:@"Please supply a URL"] ){
		// if load button was clicked
		if( buttonIndex == 1 ){
			// try downloading
			NSString* urlContents = [[NSString alloc] initWithContentsOfURL:[NSURL URLWithString:URLField.text]
																   encoding:NSUTF8StringEncoding
																	  error:nil];
			if( urlContents == nil ){
				// if download failed
				UIAlertView *myAlert = [[UIAlertView alloc] initWithTitle:@"Error downloading database" 
																  message:@"The URL you specified could not be downloaded." 
																 delegate:self 
														cancelButtonTitle:@"OK" 
														otherButtonTitles:nil];
				[myAlert show];
				[myAlert release];
			}else{
				// if download succeeded
				if( app.database->loadFromString( urlContents ) ){
					// successfully loaded database
					app.database->save();
				}else{
					app.database->clear();
					UIAlertView *myAlert = [[UIAlertView alloc] initWithTitle:@"Error loading database" 
																	  message:@"The file you specified is not a valid database file." 
																	 delegate:self 
															cancelButtonTitle:@"OK" 
															otherButtonTitles:nil];
					[myAlert show];
					[myAlert release];
				}
			}
		}
	}
	// Unselect the selected row if any
	NSIndexPath* selection = [self.tableView indexPathForSelectedRow];
	if (selection){
		[self.tableView deselectRowAtIndexPath:selection animated:YES];
	}
	[self.tableView reloadData];
}



#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}


- (void)dealloc {
	[URLField release];
	[app release];
    [super dealloc];
}


@end

