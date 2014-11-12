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

#pragma mark -
#pragma mark Initialization


// The custom initializer.  
- (id)initWithStyle:(UITableViewStyle)style app:(AppDelegate *)theApp{
    if ((self = [super initWithStyle:style])) {
		self.app = theApp;	
    }
    return self;
}

-(UINavigationItem*)navigationItem{
    if( !navItem ){
        navItem = [[UINavigationItem alloc] initWithTitle:@"Options"];
    }
    return navItem;
}


#pragma mark -
#pragma mark MKMailComposeViewControllerDelegate

// finished trying to email
- (void)mailComposeController:(MFMailComposeViewController*)controller 
		  didFinishWithResult:(MFMailComposeResult)result 
						error:(NSError*)error{
	// make email window disappear
	[controller dismissViewControllerAnimated:YES completion:nil];
}



#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    // If detailed logging is enabled then show controls
    return 2 + self.app.detailedLogging;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if( section == 0 ){
		return [NSString stringWithFormat:@"Batphone version: %@",
				[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
	}else if( section == 1 ){
		return @"Advanced fingerprint options";		
	}else if( section == 2 ){
		return @"Advanced logging options";		
	}else{
		return @"";
	}
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if( section == 0 ){
		return 2;
	}else if( section == 1 ){
		return 3;
	}else if( section == 2 ){
		return 2;
	}else{
		return 0;
	}
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
	
	cell.accessoryView = nil;

	// Configure the cell...
	if( indexPath.section == 0 ){
		if( indexPath.row == 0 ){
			cell.textLabel.text = @"Send us feedback";
		}else if(indexPath.row == 1){
			cell.textLabel.text = @"Visit the project website";
		}
	}else if( indexPath.section == 1 ){
		if( indexPath.row == 0 ){
			cell.textLabel.text = @"Email database";
		}else if(indexPath.row == 1){
			cell.textLabel.text = @"Load database";
		}else if(indexPath.row == 2){
			cell.textLabel.text = @"Clear database";
		}
	}else if( indexPath.section == 2 ){
		if( indexPath.row == 0 ){
			cell.textLabel.text = @"Email motion/audio data";
		}else if(indexPath.row == 1){
			cell.textLabel.text = @"Clear motion/audio data";
		}
	}	
    return cell;
}



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
				[mailer setSubject:[NSString stringWithFormat:@"[Batphone DB v%@]",
				 [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]] ];
				[mailer setMessageBody:@"Data in database.txt is stored with one line per tagged fingerprint.  Each line has the following fields (separated by tabs): tag id, unix-style timestamp, latitude, longitude, altitude (m), horizontal accuracy (m), vertical accuracy (m), building name, room name, fingerprint[0],...,fingerprint[n]\n" 
								isHTML:NO];
				[mailer addAttachmentData:[NSData dataWithContentsOfFile:[app.database getDBFilename]] 
								 mimeType:@"text/plain" 
								 fileName:@"database.txt"];
			}else if( indexPath.section == 2 ){
				// email motion data
				[mailer setSubject:[NSString stringWithFormat:@"[Batphone motion v%@]",
									[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]] ];
				[mailer setMessageBody:@"Data in motion.txt is stored with one line per motion vector.  Each line has the following fields (separated by tabs): G_x, G_y, G_z, userAccel_x, userAccel_y, userAccel_z" 
								isHTML:NO];
				[mailer addAttachmentData:[NSData dataWithContentsOfFile:[app getMotionDataFilename]] 
								 mimeType:@"text/plain" 
								 fileName:@"motion.txt"];
				[mailer addAttachmentData:[NSData dataWithContentsOfFile:[app getSpectrogramFilename]] 
								 mimeType:@"text/plain" 
								 fileName:@"spectrogram.txt"];
			}else if(indexPath.section == 0 ){
				// email feedback
				[mailer setSubject:[NSString stringWithFormat:@"[Batphone feedback v%@]",
									[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]] ];
				[mailer setMessageBody:@"" isHTML:NO];
       	        [mailer setToRecipients:[NSArray arrayWithObject:@"steve@stevetarzia.com"]];
			}
			
			[self presentViewController:mailer
                               animated:YES
                             completion:nil];
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
	// delete database
	else if( indexPath.section == 1 && indexPath.row == 2 ){
		UIAlertView *myAlert = [[UIAlertView alloc] initWithTitle:@"Really clear database?" 
														  message:@"You are about to delete ALL of your location tags." 
														 delegate:self 
												cancelButtonTitle:@"Cancel" 
												otherButtonTitles:@"Delete",nil];
		[myAlert show];
		[myAlert release];
	}
	// delete logging data files
	else if( indexPath.section == 2 && indexPath.row == 1 ){
		[[NSFileManager defaultManager] removeItemAtPath:[app getMotionDataFilename]
												   error:nil];
		// must pause logging to close the file first
		self.app.fp->spectrogram.disableLogging();
		[[NSFileManager defaultManager] removeItemAtPath:[app getSpectrogramFilename]
												   error:nil];
		//re-enable logging
		if( self.app.detailedLogging ){
			self.app.fp->spectrogram.enableLoggingToFilename( [[self.app getSpectrogramFilename] UTF8String] );
		}
		
		// deselect
		[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
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
        alertview.alertViewStyle = UIAlertViewStylePlainTextInput;
        [alertview textFieldAtIndex:0].placeholder = @"eg. http://somesite.com/file.txt";
        [alertview textFieldAtIndex:0].text = @"http://stevetarzia.com/batphone/database.txt";
		
		// Show alert on screen.
		[alertview show];
		[alertview release];
	} 
	// share data setting
	else if( indexPath.section == 0 && indexPath.row == 0 ){
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
	}
}

	
	
#pragma mark -
#pragma mark UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
	// clear database alert
	if( [alertView.title isEqualToString:@"Really clear database?"] ){
		// if "delete" button was clicked then clear the database
		if( buttonIndex == 1 ){
			[app.database clearCache];
			// TODO: somehow clear the match table
		}
	}
	// load URL alert
	else if( [alertView.title isEqualToString:@"Please supply a URL"] ){
		// if load button was clicked
		if( buttonIndex == 1 ){
			// try downloading
            UITextField* URLField = [alertView textFieldAtIndex:0];
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
				if( [app.database loadCacheFromString:urlContents] ){
					// successfully loaded database
					[app.database saveCache];
				}else{
					[app.database clearCache];
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
	[app release];
    [super dealloc];
}


@end

