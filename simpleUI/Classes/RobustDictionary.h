//
//  RobustDictionary.h
//  simpleUI
//
//  Created by Stephen Tarzia on 2/4/11.
//  Copyright 2011 Northwestern University. All rights reserved.
//

/* RobustDictionary is a persistent dictionary which is useful for storing app
 options.  It includes a backing file store and a set of default values for keys.
 */

#import <Foundation/Foundation.h>


@interface RobustDictionary : NSObject {
	NSMutableDictionary* dict;
	NSDictionary* defaultsDict;
	NSString* filename; // file where dictionary is stored
	NSString* defaultsFilename; // file where dictionary of default values is stored
}

@property (retain) NSMutableDictionary* dict;
@property (retain) NSDictionary* defaultsDict;
@property (nonatomic,retain) NSString* filename;
@property (nonatomic,retain) NSString* defaultsFilename;

-(id) initWithFilename:(NSString*)fn defaultsFilename:(NSString*)dfn;
-(id) objectForKey:(NSString*)key;
-(void) setObject:(id)obj forKey:(NSString*)key;

-(void) load; // load values from persistent store
-(void) save; // save values to persistent store

@end
