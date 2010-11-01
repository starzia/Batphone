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
	UILabel *locationLabel;
	AppDelegate *app;
	
	// picker state
	vector<NSString*> buildingsCache;
	vector<NSString*> roomsCache;
	NSString* currentBuilding;	
}

@property (nonatomic, retain) AppDelegate* app;
@property (nonatomic, retain) UITextField *buildingField;
@property (nonatomic, retain) UITextField *roomField;
@property (nonatomic, retain) UIPickerView *roomPicker;
@property (nonatomic, retain) UILabel *locationLabel;

@property (nonatomic) vector<NSString*> buildingsCache;
@property (nonatomic) vector<NSString*> roomsCache;
@property (nonatomic, retain) NSString* currentBuilding;

// custom initializer
- (id)initWithApp:(AppDelegate *)theApp;

-(bool) saveButtonHandler;

@end
