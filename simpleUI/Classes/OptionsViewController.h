//
//  OptionsViewController.h
//  simpleUI
//
//  Created by Stephen Tarzia on 11/9/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

@interface OptionsViewController : UITableViewController <UIAlertViewDelegate> {
	AppDelegate* app;
}
@property (nonatomic, retain) AppDelegate* app;

// custom initializer
- (id)initWithStyle:(UITableViewStyle)style app:(AppDelegate *)theApp;

@end
