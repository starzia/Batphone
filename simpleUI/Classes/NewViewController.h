//
//  NewViewController.h
//  simpleUI
//
//  Created by Stephen Tarzia on 10/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

@interface NewViewController : UIViewController <UITextFieldDelegate>{
	UIButton *saveButton;
	UITextField *nameLabel;	
	
	AppDelegate *app;
}

@property (nonatomic, retain) AppDelegate* app;
@property (nonatomic, retain) IBOutlet UIButton *saveButton;
@property (nonatomic, retain) IBOutlet UITextField *nameLabel;

-(IBAction) saveButtonHandler:(id)sender;

@end
