//
//  SensorManager.m
//  SensorCapture
//
//  Created by Stephen Tarzia on 3/15/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SensorManager.hpp"

#pragma mark -
#pragma mark SensorManager
@implementation SensorManager
@synthesize storagePath;
@synthesize session;
@synthesize videoInput;
@synthesize stillImageOutput;
@synthesize stillTimer;
@synthesize audioTimer;
@synthesize scanTimer;
@synthesize recorder;
@synthesize locationManager;
@synthesize motionManager;
@synthesize opq;
@synthesize bootTime;
@synthesize networksManager;
@synthesize view;
@synthesize motionFile;


-(void)stopAudio{
	if( self.recorder != nil ){
		[self.recorder stop];
	}
	
}


-(void)restartAudio{
	// build filename
	NSDate *now = [NSDate date];
	NSString *wavFile = [NSString stringWithFormat:@"%@/%.2f.wav",
						 self.storagePath,[now timeIntervalSinceReferenceDate]];
	NSURL *wavFileURL = [NSURL fileURLWithPath:wavFile];
	
	NSDictionary *recordSettings = [NSDictionary 
									dictionaryWithObjectsAndKeys:
									[NSNumber numberWithInt:kAudioFormatLinearPCM], 
									AVFormatIDKey,
									[NSNumber numberWithInt: 16], 
									AVLinearPCMBitDepthKey,
									[NSNumber numberWithInt: 1], 
									AVNumberOfChannelsKey,
									[NSNumber numberWithFloat:44100.0], 
									AVSampleRateKey,
									nil];

	AVAudioRecorder* audioRecorder = [[AVAudioRecorder alloc] initWithURL:wavFileURL
																 settings:recordSettings
																	error:nil];
	[audioRecorder prepareToRecord];
	
	// stop previous recorder, if any
	[self stopAudio];
	
	// start new recorder
	[audioRecorder record];
	///NSLog(@"started recording to: %@", wavFile);
	self.recorder = audioRecorder;
	[audioRecorder release];
}


-(id)initWithStoragePath:(NSString*)path view:(UIView*)flashView{
	self = [super init];
	if( self != nil ){
		self.storagePath = path;
		self.recorder = nil;
		self.bootTime= -1.0; // set this when first motion event happens
		self.networksManager = [[[SOLStumbler alloc] init] autorelease];
		self.view = flashView;
		self.motionFile = new std::ofstream();
		
		// SET UP VIDEO DEVICE.  See code in AVCamDemo for dealing w/ device conection and disconnection
		// find the correct video device
		AVCaptureDevice* camera;
		NSArray *devices = [AVCaptureDevice devices];
		for (AVCaptureDevice *device in devices) {
			if ([device hasMediaType:AVMediaTypeVideo]) {
				if ([device position] == AVCaptureDevicePositionBack) {
					camera = device;
				}
			}
		}
		// lock white balance so that snapshot colors are comparable
		[camera lockForConfiguration:NULL];
		camera.whiteBalanceMode = AVCaptureWhiteBalanceModeLocked;
		[camera unlockForConfiguration];
		NSLog(@"using camera: %@", [camera localizedName] );
		
		// Init the device inputs
		AVCaptureDeviceInput *tVideoInput = [[[AVCaptureDeviceInput alloc] 
											 initWithDevice:camera
													  error:nil] autorelease];
		[self setVideoInput:tVideoInput]; // stash this for later use if we need to switch cameras
				
		// Setup the default file outputs
		AVCaptureStillImageOutput *tStillImageOutput = [[[AVCaptureStillImageOutput alloc] init] autorelease];
		NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
										AVVideoCodecJPEG, AVVideoCodecKey,
										nil];
		[tStillImageOutput setOutputSettings:outputSettings];
		[outputSettings release];
		[self setStillImageOutput:tStillImageOutput];
				
		// Setup and start the capture session
		AVCaptureSession *tSession = [[AVCaptureSession alloc] init];
		[tSession beginConfiguration];
    	
		if ([tSession canAddInput:videoInput]) {
			[tSession addInput:videoInput];
		}
		if ([tSession canAddOutput:stillImageOutput]) {
			[tSession addOutput:stillImageOutput];
		}
		
		[tSession setSessionPreset:AVCaptureSessionPreset640x480];
		[tSession commitConfiguration];
		
		[tSession startRunning];
		
		[self setSession:tSession];
		[tSession release];

		// SET TIMER FOR STILLS
		self.stillTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
														   target:self
														 selector:@selector(captureStillImage)
														 userInfo:nil
														  repeats:YES];
		
		// SET TIMER FOR AUDIO
		[self restartAudio]; // get started immediately
		self.audioTimer = [NSTimer scheduledTimerWithTimeInterval:10
														   target:self
														 selector:@selector(restartAudio)
														 userInfo:nil
														  repeats:YES];
		
		// SET TIMER FOR WIFI SCAN
		self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:1
														  target:self
														 selector:@selector(scanWiFi)
														 userInfo:nil
														  repeats:YES];
		
		// SET UP CORE LOCATION LOGGING
		self.locationManager = [[[CLLocationManager alloc] init] autorelease];
		self.locationManager.delegate = self; // send loc updates to myself
		// Note that desiredAccuracy affects power consumption
		locationManager.desiredAccuracy = kCLLocationAccuracyBest; // best accuracy
		locationManager.distanceFilter = kCLDistanceFilterNone; // notify me of all location changes, even if small
		locationManager.headingFilter = kCLHeadingFilterNone; // as above
		locationManager.purpose = @"Location information from the device's radios can be used to improve accuracy."; // to be displayed in system's user prompt
		[self.locationManager startUpdatingLocation]; // start location service
		
		// SETUP MOTION LOGGING
		self.motionManager = [[[CMMotionManager alloc] init] autorelease];
		self.motionManager.deviceMotionUpdateInterval = 0.001; //in seconds.  If a very small value is chosen, then the minimum HW sampling period is used instead
		
		if(!motionManager.deviceMotionAvailable){
			NSLog(@"ERROR: device motion not available!");
		}
		
		// block for motion data callback
		CMDeviceMotionHandler motionHandler = ^ (CMDeviceMotion *motionData, NSError *error) {
			[self handleMotionData:motionData];
		};
		
		// start receiving updates
		self.opq = [[[NSOperationQueue alloc] init] autorelease];
		[self.motionManager startDeviceMotionUpdatesToQueue:self.opq
												withHandler:motionHandler];
	}
	return self;	
}

+(AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType 
								 fromConnections:(NSArray *)connections;{
	for ( AVCaptureConnection *connection in connections ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:mediaType] ) {
				return [[connection retain] autorelease];
			}
		}
	}
	return nil;
}

- (void) captureStillImage{
    AVCaptureConnection *videoConnection = [SensorManager 
											connectionWithMediaType:AVMediaTypeVideo 
													fromConnections:[[self stillImageOutput] connections]];
    if ([videoConnection isVideoOrientationSupported]) {
        [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }
    
    [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:videoConnection
                                                         completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                                             if (imageDataSampleBuffer != NULL) {
                                                                 NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
																 
																 // build filename
																 NSDate *now = [NSDate date];
																 NSString *jpgFile = [NSString stringWithFormat:@"%@/%.2f.jpg",
																					  self.storagePath,[now timeIntervalSinceReferenceDate]];
																 ///NSLog(@"wrote to file: %@",jpgFile);
																 [imageData writeToFile:jpgFile atomically:YES];
																 
																 // flash screen
																 if( self.view != nil ){
																	 UIView *flashView = [[UIView alloc] initWithFrame:[self.view frame]];
																	 [flashView setBackgroundColor:[UIColor whiteColor]];
																	 [flashView setAlpha:0.f];
																	 [[self.view window] addSubview:flashView];
																	 
																	 [UIView animateWithDuration:.2f
																					  animations:^{
																						  [flashView setAlpha:1.f];
																						  [flashView setAlpha:0.f];
																					  }
																					  completion:^(BOOL finished){
																						  [flashView removeFromSuperview];
																						  [flashView release];
																					  }
																	  ];
																 }
                                                             } else if (error) {
                                                                 NSLog(@"still image capture error");
                                                             }
                                                         }];
}

-(void)dealloc{
	self.motionFile->close();
	delete self.motionFile;
	[self stopAudio];
	[super dealloc];
}

-(CLLocation*)getLocation{
	return locationManager.location;
}

-(void) scanWiFi{
	[self.networksManager scanNetworks];
	NSDictionary* networks = [[self.networksManager networks] retain];
	// open data file for appending
	NSString* filename = [NSString stringWithFormat:@"%@/scans.txt", self.storagePath];
	std::ofstream dFile;
	dFile.open([filename UTF8String], std::ios::out | std::ios::app);
	NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
	NSMutableString* newEntry = [[NSMutableString alloc] initWithFormat:@"%.2f\n",now];
	// scan through each AP
	for (id key in [self.networksManager networks]){
		// save new line in data file
		[newEntry appendFormat:@"\t%@\t%@\t%@\t%@\n",
					key, //Station BBSID (MAC Address)
					[[networks objectForKey: key] objectForKey:@"RSSI"], //Signal Strength
					[[networks objectForKey: key] objectForKey:@"CHANNEL"],  //Operating Channel
					[[networks objectForKey: key] objectForKey:@"SSID_STR"] //Station Name
		 ];
	}
	dFile << [newEntry UTF8String]; // append the new entry
	dFile.close();
	[networks release];
}


#pragma mark -
#pragma mark CLLocationManagerDelegate
// Core Location code adapted from http://mobileorchard.com/hello-there-a-corelocation-tutorial/
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation 
{
	// convert userAcceleration to world frame
	///multiplyVecByMat( &userAccel, motionData.attitude.rotationMatrix );
	// save new line in data file
	NSString* line = [newLocation description];
	
	// open data file for appending
	NSString* filename = [NSString stringWithFormat:@"%@/location.txt", self.storagePath];
	std::ofstream dFile;
	dFile.open([filename UTF8String], std::ios::out | std::ios::app);
	dFile.precision(13); // high precision for timestamp
	dFile << [[NSDate date] timeIntervalSinceReferenceDate] << '\t' << [line UTF8String] << '\n'; // append the new entry
	dFile.close();
}

- (void)locationManager:(CLLocationManager *)manager
	   didFailWithError:(NSError *)error
{
	NSLog(@"Error: %@", [error description]);
}


#pragma mark -
#pragma mark logging (motion)

// perform affine transformation specified in matrix m.
void multiplyVecByMat( CMAcceleration* a, CMRotationMatrix m ){
	CMAcceleration old_a = *a;
	a->x = old_a.x * m.m11 + old_a.y * m.m12 + old_a.z * m.m13;	
	a->y = old_a.x * m.m21 + old_a.y * m.m22 + old_a.z * m.m23;	
	a->z = old_a.x * m.m31 + old_a.y * m.m32 + old_a.z * m.m33;	
}


-(void) handleMotionData:(CMDeviceMotion*) motionData{
	// motionData timestamp is time since the device was booted.
	// first set the timestamp offset, if needed
	if( self.bootTime < 0 ){
		NSTimeInterval currTime = [[NSDate date] timeIntervalSinceReferenceDate];
		self.bootTime = currTime - motionData.timestamp;
	}
	CMAttitude* att = motionData.attitude;
	CMAcceleration userAccel = motionData.userAcceleration;
	CMAcceleration grav = motionData.gravity;
	CMRotationRate rot = motionData.rotationRate;
	// convert userAcceleration to world frame
	///multiplyVecByMat( &userAccel, motionData.attitude.rotationMatrix );
	// save new line in data file
	NSString* line = [[NSString alloc] initWithFormat:@"%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\n", 
					  motionData.timestamp+self.bootTime, userAccel.x, userAccel.y, userAccel.z,
					  att.roll, att.pitch, att.yaw, rot.x, rot.y, rot.z, grav.x, grav.y, grav.z
					  ]; 
	
	// if necessary, open data file for appending
	if( !self.motionFile->is_open() ){
		NSString* filename = [NSString stringWithFormat:@"%@/motion.txt", self.storagePath];
		self.motionFile->open([filename UTF8String], std::ios::out | std::ios::app);
	}
	self.motionFile->precision(13); // high precision for timestamp
	*(self.motionFile) << [line UTF8String]; // append the new entry
	[line release];
}

@end
