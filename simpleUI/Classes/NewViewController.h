//
//  NewViewController.h
//  simpleUI
//
//  Created by Stephen Tarzia on 10/28/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

@interface NewViewController : UIViewController 
<UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource>{
	UITextField *buildingField;
	UITextField *roomField;
	UIPickerView *roomPicker;
	
	AppDelegate *app;
}

@property (nonatomic, retain) AppDelegate* app;
@property (nonatomic, retain) UITextField *buildingField;
@property (nonatomic, retain) UITextField *roomField;
@property (nonatomic, retain) UIPickerView *roomPicker;

-(IBAction) saveButtonHandler;

@end
