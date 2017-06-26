//
//  Organize_Images.h
//  Organize Images
//
//  Created by Matt Johnson on 12-01-11.
//  Copyright (c) 2012 Primality, Inc. All rights reserved.
//

#import <Automator/AMBundleAction.h>

@interface Organize_Images : AMBundleAction

-(id)runWithInput:(id)input fromAction:(AMAction *)anAction error:(NSDictionary **)errorInfo;

-(NSArray *) runCommand:(NSString *) command :(NSArray *) arguments;

-(void) processDirectory:(NSString *) inputPaths;
-(void) processFile:(NSString *)inputPath;

-(BOOL) copyFile:(NSString *)inputPath withTags:(NSDictionary *)tagValues withStandardTags:(NSArray *) standardTags;
-(void) updateImage:(NSDictionary *)tagValues;
-(void) updateVideo:(NSString *)inputPath withTags:(NSDictionary *) tags useHEVC:(BOOL) hevc;

-(NSArray *) runExifTool:(NSArray *) arguments;
-(NSArray *) runHandBrake:(NSArray *) arguments;
-(NSArray *) runFFMPEG:(NSArray *) arguments;

-(void) updateTags:(NSString *)inputPath withTags:(NSDictionary *) tags withOverride:(BOOL) override;
-(NSDictionary *) getTagInformation:(NSString *)inputPath withTags:(NSArray *) tags;

-(void) addUnknownTags:(NSDictionary *)tags forPath:(NSString *)path;
-(void) addUnknownTags:(NSDictionary *)tags forPath:(NSString *)path withOffset:(NSUInteger)offset;
-(BOOL) tagsEqual:(NSDictionary *)firstTags withTags:(NSDictionary *) secondTags;

@end

@interface NSDate (EXIFDate)
+ (NSDate *)dateFromEXIF:(NSString *)exifDate;
+ (NSString*)exifStringFromDate:(NSDate *)exifDate;
@end
