//
//  SensorManager.h
//  SensorCapture
//
//  Created by Stephen Tarzia on 3/15/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

// for data motion file writing
#import <iostream>
#import <fstream>


#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>
#import "SOLStumbler.h"


@interface SensorManager : NSObject <CLLocationManagerDelegate> {
	NSString* storagePath;
	
	AVCaptureSession *session;
    AVCaptureDeviceInput *videoInput;
    AVCaptureStillImageOutput *stillImageOutput;
	NSTimer* stillTimer;
	NSTimer* audioTimer;
	NSTimer* scanTimer;
	AVAudioRecorder* recorder;
	
	CLLocationManager *locationManager; 	// data for SkyHook/GPS localization
	CMMotionManager* motionManager;
	NSOperationQueue *opq; // operation queue for motion updates
	NSTimeInterval bootTime; // used to convert timestamps
	SOLStumbler *networksManager;
	UIView *view; // view on top of which to flash when photo is taken. Can be null
	std::ofstream *motionFile; // log file for motion data
}

@property (nonatomic,retain) NSString* storagePath;

@property (nonatomic,retain) AVCaptureSession *session;
@property (nonatomic,retain) AVCaptureDeviceInput *videoInput;
@property (nonatomic,retain) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic,retain) NSTimer* stillTimer;
@property (nonatomic,retain) NSTimer* audioTimer;
@property (nonatomic,retain) NSTimer* scanTimer;
@property (nonatomic,retain) AVAudioRecorder* recorder;
@property (nonatomic,retain) CLLocationManager *locationManager;
@property (nonatomic,retain) CMMotionManager* motionManager;
@property (nonatomic,retain) NSOperationQueue* opq;
@property (nonatomic) NSTimeInterval bootTime;
@property (nonatomic,retain) SOLStumbler *networksManager;
@property (nonatomic,retain) UIView *view;
@property (nonatomic) std::ofstream *motionFile;

-(id)initWithStoragePath:(NSString*)path view:(UIView*)view;
-(CLLocation*)getLocation; // return the current GPSLocation from locationManager
-(void) handleMotionData:(CMDeviceMotion*) motionData;
-(void) scanWiFi;

@end
