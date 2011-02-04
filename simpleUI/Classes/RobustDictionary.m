//
//  RobustDictionary.m
//  simpleUI
//
//  Created by Stephen Tarzia on 2/4/11.
//  Copyright 2011 Northwestern University. All rights reserved.
//

#import "RobustDictionary.h"


@implementation RobustDictionary
@synthesize dict;
@synthesize defaultsDict;
@synthesize filename;
@synthesize defaultsFilename;

-(id) initWithFilename:(NSString*)fn defaultsFilename:(NSString*)dfn{
	if (self = [super init]) {
        // Custom initialization
		self.filename = fn;
		self.defaultsFilename = dfn;
		
		// load dictionary from file
		[self load];
    }
    return self;
}


-(id) objectForKey:(NSString*)key{
	id obj = [self.dict objectForKey:key];
	
	if( obj == nil ){
		/* NOTE that in some cases, key will be in defaults but not in the regular
		 dictionary.  This would happen if a new software version includes additional
		 options but we are still using the dictionary file from the old version */

		// get value from defaults dictionary (which may be nil)
		return [self.defaultsDict objectForKey:key];
	}else{
		return obj;
	}
}

-(void) setObject:(id)obj forKey:(NSString*)key{
	[self.dict setObject:obj forKey:key];
	[self save];
}


-(void) load{
	// first load defaults dictionary
	NSDictionary* dd = [[NSDictionary alloc] initWithContentsOfFile:defaultsFilename];
	self.defaultsDict = dd;
	[dd release];
	
	// test that dict file exists
	if( [[NSFileManager defaultManager] fileExistsAtPath:self.filename] ){
		// load dictionary
		NSMutableDictionary* d = [[NSMutableDictionary alloc] initWithContentsOfFile:defaultsFilename];
		self.dict = d;
		[d release];
	}else{
		// copy default values
		NSMutableDictionary* d = [[NSMutableDictionary alloc] initWithDictionary:self.defaultsDict];
		self.dict = d;
		[d release];
	}
	// TODO: file access error handling
}

-(void) save{
	[self.dict writeToFile:self.filename atomically:YES];
	// TODO: file access error handling
}

@end
