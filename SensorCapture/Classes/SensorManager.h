//
//  SensorManager.h
//  SensorCapture
//
//  Created by Stephen Tarzia on 3/15/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

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

-(id)initWithStoragePath:(NSString*)path;
-(CLLocation*)getLocation; // return the current GPSLocation from locationManager
-(void) handleMotionData:(CMDeviceMotion*) motionData;
-(void) scanWiFi;

@end
