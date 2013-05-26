//
//  OptionsViewController.h
//  simpleUI
//
//  Created by Stephen Tarzia on 11/9/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

// for email
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

@interface OptionsViewController : UITableViewController 
<UIAlertViewDelegate, MFMailComposeViewControllerDelegate> {
	AppDelegate* app;
	UITextField* URLField;
	UISwitch* sharing;
}
@property (nonatomic, retain) AppDelegate* app;
@property (nonatomic, retain) UITextField* URLField;
@property (nonatomic, retain) UISwitch* sharing;

// custom initializer
- (id)initWithStyle:(UITableViewStyle)style app:(AppDelegate *)theApp;

@end
