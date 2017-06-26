//
//  Organize_Images.m
//  Organize Images
//
//  Created by Matt Johnson on 12-01-11.
//  Copyright (c) 2012 Primality, Inc. All rights reserved.
//

#import "Organize_Images.h"

@implementation Organize_Images

static BOOL internalPutTimeZone = NO;

//------------------------------------------------------
+(NSDictionary*)GPSTimeZoneMap
{
	static NSDictionary *gpsTimeZoneMap = nil;
	if (gpsTimeZoneMap == nil)
		gpsTimeZoneMap = [[NSMutableDictionary alloc] init];

	return gpsTimeZoneMap;
}

//------------------------------------------------------
-(void) populateGPSTimeZoneMap
{
	NSString *filePath = [NSString stringWithFormat:@"%@/gpstimezone.txt", [[self parameters] valueForKey:@"archiveDirectory"]];
	
	if(![[NSFileManager defaultManager] fileExistsAtPath: filePath])
	{
		[[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@.tmp", filePath] toPath:filePath error:nil];
		
		if(![[NSFileManager defaultManager] fileExistsAtPath: filePath])
			return;
	}
	
	NSString* string = [NSString stringWithContentsOfFile:filePath encoding: NSUTF8StringEncoding error:nil];
							  
	unsigned long length = [string length];
	unsigned long paraStart = 0, paraEnd = 0, contentsEnd = 0;
	NSRange currentRange;
	while (paraEnd < length)
	{
		[string getParagraphStart:&paraStart end:&paraEnd
					  contentsEnd:&contentsEnd forRange:NSMakeRange(paraEnd, 0)];
		currentRange = NSMakeRange(paraStart, contentsEnd - paraStart);
		
		NSString *currentLine = [string substringWithRange:currentRange];
		
		NSArray* tabArray = [currentLine componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\t"]];
		
		[(NSMutableDictionary *) [Organize_Images GPSTimeZoneMap] setObject:[tabArray objectAtIndex:1] forKey:[tabArray objectAtIndex:0]];

		NSLog(@"Reading gps data %@ -> %@", [tabArray objectAtIndex:0], [tabArray objectAtIndex:1]);
	}	

	return;
}

//------------------------------------------------------
-(void) createExifToolConfig
{
    NSString *filePath = [NSString stringWithFormat:@"/tmp/oiconfig.txt"];
    
    if([[NSFileManager defaultManager] fileExistsAtPath: filePath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    NSData *textData = [@"%Image::ExifTool::UserDefined = (\n'Image::ExifTool::XMP::xmp' => {OriginalFile => { Name => 'OriginalFile' }});" dataUsingEncoding:NSUTF8StringEncoding];
    
    [fileHandle writeData:textData];
    [fileHandle synchronizeFile];
    [fileHandle closeFile];

    return;
}

//------------------------------------------------------
-(void) removeExifToolConfig
{
    NSLog(@"Removing ExifTool Config");
    
    NSString *filePath = [NSString stringWithFormat:@"/tmp/oiconfig.txt"];
    
    if([[NSFileManager defaultManager] fileExistsAtPath: filePath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    
    return;
}

//------------------------------------------------------
-(void) writeGPSTimeZoneMap
{	
	if(internalPutTimeZone == NO)
		return;
	
	NSString *filePath = [NSString stringWithFormat:@"%@/gpstimezone.txt", [[self parameters] valueForKey:@"archiveDirectory"]];
	
	if([[NSFileManager defaultManager] fileExistsAtPath: filePath])
	{
		[[NSFileManager defaultManager] moveItemAtPath:filePath toPath:[NSString stringWithFormat:@"%@.tmp", filePath] error:nil];
	}
	
	NSLog(@"Writing GPS time zones to %@", filePath);
	
	BOOL	firstWrite = YES;
	NSFileHandle *fileHandle = nil;
	
	for(NSString* gpsCoordinates in [[Organize_Images GPSTimeZoneMap] allKeys])
	{
		if(firstWrite)
		{
			[[NSString stringWithFormat:@"%@\t%@\n", gpsCoordinates, [[Organize_Images GPSTimeZoneMap] valueForKey:gpsCoordinates]] writeToFile:filePath atomically:YES encoding: NSUTF8StringEncoding error: NULL];
			firstWrite = NO;

			fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
			
			continue;
		}
		
		[fileHandle seekToEndOfFile];
		
		// convert the string to an NSData object
		NSData *textData = [[NSString stringWithFormat:@"%@\t%@\n", gpsCoordinates, [[Organize_Images GPSTimeZoneMap] valueForKey:gpsCoordinates]] dataUsingEncoding:NSUTF8StringEncoding];
		
		NSLog(@"Writing gps data %@ -> %@", gpsCoordinates, [[Organize_Images GPSTimeZoneMap] valueForKey:gpsCoordinates]);

		// write the data to the end of the file
		[fileHandle writeData:textData];
		
		firstWrite = NO;
	}
	
	[fileHandle synchronizeFile];
	[fileHandle closeFile];

	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@.tmp", filePath] error:nil];
	
	internalPutTimeZone = NO;
}

//------------------------------------------------------
-(NSTimeZone *) getGPSTimeZone:(NSString *) latitude :(NSString *) longitude
{
	NSString *zoneString = [[Organize_Images GPSTimeZoneMap] valueForKey:[NSString stringWithFormat:@"%@,%@", latitude, longitude]];
	
	if(zoneString == nil)
		zoneString = [[Organize_Images GPSTimeZoneMap] valueForKey:[NSString stringWithFormat:@"%.2f,%.2f", ceilf([latitude floatValue] * 4.0f) / 4.0f, ceilf([longitude floatValue] * 4.0f) / 4.0f]];
	
	if(zoneString == nil)
		zoneString = [[Organize_Images GPSTimeZoneMap] valueForKey:[NSString stringWithFormat:@"%.1f,%.1f", ceilf([latitude floatValue] * 2.0f) / 2.0f, ceilf([longitude floatValue] * 2.0f) / 2.0f]];
	
	if(zoneString == nil)
		return(nil);
	
	return [NSTimeZone timeZoneWithName:zoneString];
}

//------------------------------------------------------
-(NSTimeZone *) getGPSTimeZoneOffset:(NSString *) latitude :(NSString *) longitude atDate:(NSString*) dateString
{
	NSTimeZone *timeZone = [self getGPSTimeZone:latitude:longitude];
	
	NSString *filteredDateString = [dateString stringByReplacingOccurrencesOfString:@":" withString:@""];
	
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	
	NSDateComponents *comps = [[NSDateComponents alloc] init];
	[comps setYear:[[filteredDateString substringWithRange:NSMakeRange(0, 4)] intValue]];
	[comps setMonth:[[filteredDateString substringWithRange:NSMakeRange(4, 2)] intValue]];
	[comps setDay:[[filteredDateString substringWithRange:NSMakeRange(6, 2)] intValue]];
	[comps setHour:[[filteredDateString substringWithRange:NSMakeRange(9, 2)] intValue]];
	[comps setMinute:[[filteredDateString substringWithRange:NSMakeRange(11, 2)] intValue]];
	[comps setSecond:[[filteredDateString substringWithRange:NSMakeRange(13, 2)] intValue]];
	
	if(timeZone == nil)
		timeZone = [NSTimeZone localTimeZone];
	
	[comps setTimeZone:timeZone];
	
	NSDate *date = [gregorian dateFromComponents:comps];
		
	NSInteger zoneOffsetSeconds = [timeZone secondsFromGMTForDate:date];
	
	timeZone = [NSTimeZone timeZoneForSecondsFromGMT:zoneOffsetSeconds];
	
	NSLog(@"Getting Time Zone From GPS Time Zone: %@", timeZone);
	
	return timeZone;
}

//------------------------------------------------------
-(void) setGPSTimeZone:(NSString *) latitude :(NSString *) longitude withTimeZone:(NSTimeZone *)timeZone
{
	NSLog(@"Setting GPS Time Zone For [%@]", [NSString stringWithFormat:@"%.1f,%.1f", ceilf([latitude floatValue] * 2.0f) / 2.0f, ceilf([longitude floatValue] * 2.0f)/ 2.0f]);
	
	NSString *zoneString = [[Organize_Images GPSTimeZoneMap] valueForKey:[NSString stringWithFormat:@"%.1f,%.1f", ceilf([latitude floatValue] * 2.0f) / 2.0f, ceilf([longitude floatValue] * 2.0f)/ 2.0f]];
	
	if([zoneString length] > 0)
	{
		NSLog(@"Found Zone String [%@]", zoneString);
		return;
	}
	
	[(NSMutableDictionary *) [Organize_Images GPSTimeZoneMap] setObject:[timeZone name] forKey:[NSString stringWithFormat:@"%.1f,%.1f", ceilf([latitude floatValue] * 2.0f) / 2.0f, ceilf([longitude floatValue] * 2.0f)/ 2.0f]];
	
	NSLog(@"Set Zone String");

	internalPutTimeZone = YES;
}

//------------------------------------------------------
-(id)runWithInput:(id)input fromAction:(AMAction *)anAction error:(NSDictionary **)errorInfo
{
	[self populateGPSTimeZoneMap];
	
	@try
	{
        [self createExifToolConfig];
        
		for(NSString* inputPath in input) 
			[self processFile:inputPath];
	}
	
	@catch (NSException *exception)
	{
		NSArray *objsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:errOSASystemError],[NSString stringWithFormat:@"ERROR: %@\n", [exception reason]], nil];
		
		NSArray *keysArray = [NSArray arrayWithObjects:NSAppleScriptErrorNumber,NSAppleScriptErrorMessage, nil];
		*errorInfo = [NSDictionary dictionaryWithObjects:objsArray forKeys:keysArray];
	}
	
	@finally
	{
		[self writeGPSTimeZoneMap];
        [self removeExifToolConfig];
	}
	
	return input;
}

//------------------------------------------------------
-(NSArray *) runCommand:(NSString *) command :(NSArray *) arguments
{
	NSTask *task = nil;
	NSMutableArray *array = nil;
	NSString *string = nil;
	NSFileHandle *file = nil;
	
	@try
	{
		task = [[NSTask alloc] init];
		[task setLaunchPath: command];
		
		[task setArguments: arguments];

		NSPipe *pipe;
		pipe = [NSPipe pipe];
		[task setStandardOutput: pipe];

		file = [pipe fileHandleForReading];

		[task launch];

		NSData *data;
		data = [file readDataToEndOfFile];

		string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
		
		unsigned long length = [string length];
		unsigned long paraStart = 0, paraEnd = 0, contentsEnd = 0;
		array = [NSMutableArray array];
		NSRange currentRange;
		while (paraEnd < length) {
			[string getParagraphStart:&paraStart end:&paraEnd
						  contentsEnd:&contentsEnd forRange:NSMakeRange(paraEnd, 0)];
			currentRange = NSMakeRange(paraStart, contentsEnd - paraStart);
			[array addObject:[string substringWithRange:currentRange]];
		}	
	}

	@catch (NSException *exception)
	{		
		@throw exception;
	}
	@finally
	{
		[file closeFile];
		
		string = nil;
		task = nil;
	}
	
	return(array);
}

//------------------------------------------------------
-(void) processDirectory:(NSString *) inputPath
{
	@autoreleasepool {
		NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:inputPath error:nil];				
		for(NSString *dirPath in dirContents)
		{
			@try
			{
				[self processFile:[NSString stringWithFormat:@"%@/%@",inputPath,dirPath]];
			}
			
			@catch(NSException *exception)
			{
				NSLog(@"Error Processing [%@]", inputPath);
				@throw exception;
			}
		}

		[self writeGPSTimeZoneMap];
		
		
		return;
	}
}

//------------------------------------------------------
-(void) processFile:(NSString *)inputPath
{
	BOOL isDir;
	
	if([[[self parameters] valueForKey:@"archiveDirectory"] length] == 0)
	{
		@throw [NSException exceptionWithName:@"error"
									   reason:@"Archive Directory Not Specified"
									 userInfo:nil];
	}
	
	if([[NSFileManager defaultManager] fileExistsAtPath: inputPath isDirectory: &isDir] && isDir)
	{
		[self processDirectory:inputPath];
		return;
	}
	
	NSLog(@"File: %@", inputPath);
	
	NSArray *standardTags = [NSArray arrayWithObjects:@"DateTimeOriginal", @"DigitalCreationDateTime", @"CreationDate", @"CreateDate", @"Make", @"Model", @"MimeType", @"Duration#", @"RedBalance#", @"GreenBalance#", @"BlueBalance#", @"FocalLength#", @"Aperture#", @"PreviewImageLength#", @"ISO#", @"ImageDataSize#", @"ExposureTime#",  @"SubjectArea#", @"LightValue#", @"Caption-Abstract", @"UserComment", @"Comment", @"Description", @"GPSAltitude#", @"GPSLatitude#", @"GPSLongitude#", @"GPSTimeStamp", @"GPSDateTime", @"GPSImgDirection#", @"VideoCodec", @"Timezone", @"TimeZoneOffset#", @"Rotation#", @"SequenceNumber#", @"ThumbnailLength#", @"OriginalFile", @"Software", nil];
	
	NSDictionary *tagValues = [self getTagInformation:inputPath withTags:standardTags];
	
	if(![[tagValues valueForKey:@"MimeType"] hasPrefix:@"video"] && ![[tagValues valueForKey:@"MimeType"] hasPrefix:@"image"])
		return;
	
	if([[[self parameters] valueForKey:@"onlyProcessImageFiles"] boolValue])
	if([[tagValues valueForKey:@"MimeType"] hasPrefix:@"video"])
	{
		NSLog(@"Skipping Video File");
		return;
	}
	
	if([[[self parameters] valueForKey:@"ignoreMPEG4Files"] boolValue])
	if([[inputPath pathExtension] caseInsensitiveCompare:@"MP4"] == NSOrderedSame)
	{
		NSLog(@"Skipping Video File");
		return;
	}

//	for(NSString* tag in [tagValues allKeys])
//		NSLog(@"%@: %@", tag, [tagValues valueForKey:tag]);
	
	[self addUnknownTags:tagValues forPath:inputPath];
	
	NSString *inputFileOffsetPath = [NSString stringWithFormat:@"%@/../%@_%@.mp4", [inputPath stringByDeletingLastPathComponent], [tagValues valueForKey:@"OutputFormattedDate"], [tagValues valueForKey:@"Model"]];

	//! Need to look for new original_video path as well
	
	NSLog(@"Checking Sub File: %@", inputFileOffsetPath);

	if([[NSFileManager defaultManager] fileExistsAtPath: inputFileOffsetPath])
	{
		NSLog(@"Found Sub File: %@", inputFileOffsetPath);
		
		NSDictionary *subFileTagValues = [self getTagInformation:inputFileOffsetPath withTags:standardTags];
	
		if(subFileTagValues != nil)
		{
			NSLog(@"Updating Tags");
			
			if([[subFileTagValues valueForKey:@"Caption-Abstract"] length] > 0)
				[(NSMutableDictionary *) tagValues setObject:[subFileTagValues valueForKey:@"Caption-Abstract"] forKey:	@"Caption-Abstract"];
			if([[subFileTagValues valueForKey:@"UserComment"] length] > 0)
				[(NSMutableDictionary *) tagValues setObject:[subFileTagValues valueForKey:@"UserComment"] forKey:@"UserComment"];
			if([[subFileTagValues valueForKey:@"Comment"] length] > 0)
				[(NSMutableDictionary *) tagValues setObject:[subFileTagValues valueForKey:@"Comment"] forKey:@"Comment"];
			if([[subFileTagValues valueForKey:@"GPSAltitude"] length] > 0)
				[(NSMutableDictionary *) tagValues setObject:[subFileTagValues valueForKey:@"GPSAltitude"] forKey:@"GPSAltitude"];
			if([[subFileTagValues valueForKey:@"GPSLatitude"] length] > 0)
				[(NSMutableDictionary *) tagValues setObject:[subFileTagValues valueForKey:@"GPSLatitude"] forKey:@"GPSLatitude"];
			if([[subFileTagValues valueForKey:@"GPSLongitude"] length] > 0)
				[(NSMutableDictionary *) tagValues setObject:[subFileTagValues valueForKey:@"GPSLongitude"] forKey:@"GPSLongitude"];
			if([[subFileTagValues valueForKey:@"GPSDateTime"] length] > 0)
				[(NSMutableDictionary *) tagValues setObject:[subFileTagValues valueForKey:@"GPSDateTime"] forKey:@"GPSDateTime"];
			if([[subFileTagValues valueForKey:@"Timezone"] length] > 0)
				[(NSMutableDictionary *) tagValues setObject:[subFileTagValues valueForKey:@"Timezone"] forKey:@"Timezone"];

			if(([[tagValues valueForKey:@"FileNameOverRide"] length] == 0) && ([[tagValues valueForKey:@"OriginalFile"] length] > 0))
			if([[subFileTagValues valueForKey:@"OriginalFile"] rangeOfString:[NSString stringWithFormat:@".%@",[inputPath pathExtension]]].location != NSNotFound)
			{
				NSLog(@"File name should be: %@", [subFileTagValues valueForKey:@"OriginalFile"]);

				[(NSMutableDictionary *) tagValues setValue:[subFileTagValues valueForKey:@"OriginalFile"] forKey:@"FileNameOverRide"];

				[(NSMutableDictionary *) tagValues setObject:[NSString stringWithFormat:@"%@/%@", [tagValues valueForKey:@"OutputFullDirectoryPath"], [subFileTagValues valueForKey:@"OriginalFile"]]  forKey:@"OutputFilePath"];
			}
		}
	}
	
    NSLog(@"Checking for file name override");
    
	if(([[tagValues valueForKey:@"FileNameOverRide"] length] == 0) && ([[tagValues valueForKey:@"OriginalFile"] length] > 0))
		if([[tagValues valueForKey:@"OriginalFile"] rangeOfString:[NSString stringWithFormat:@".%@",[inputPath pathExtension]]].location != NSNotFound)
		{
			NSLog(@"File name should be: %@", [tagValues valueForKey:@"OriginalFile"]);
			
			[(NSMutableDictionary *) tagValues setValue:[tagValues valueForKey:@"OriginalFile"] forKey:@"FileNameOverRide"];
			
			if([[tagValues valueForKey:@"OutputVideo"] boolValue])
				[(NSMutableDictionary *) tagValues setObject:[NSString stringWithFormat:@"%@/%@", [tagValues valueForKey:@"OutputFullDirectoryPath"], [tagValues valueForKey:@"OriginalFile"]]  forKey:@"OutputFilePath"];
		}
	
    if(([[tagValues valueForKey:@"FileNameOverRide"] length] == 0) && ([[tagValues valueForKey:@"UserComment"] length] > 0))
        if([[tagValues valueForKey:@"OriginalFile"] rangeOfString:[NSString stringWithFormat:@".%@",[inputPath pathExtension]]].location != NSNotFound)
        {
            NSLog(@"File name should be: %@", [tagValues valueForKey:@"UserComment"]);
            
            [(NSMutableDictionary *) tagValues setValue:[tagValues valueForKey:@"UserComment"] forKey:@"FileNameOverRide"];
            
            if([[tagValues valueForKey:@"OutputVideo"] boolValue])
                [(NSMutableDictionary *) tagValues setObject:[NSString stringWithFormat:@"%@/%@", [tagValues valueForKey:@"OutputFullDirectoryPath"], [tagValues valueForKey:@"UserComment"]]  forKey:@"OutputFilePath"];
        }

    if([[tagValues valueForKey:@"FileNameOverRide"] length] == 0)
		[(NSMutableDictionary *) tagValues setValue:[inputPath lastPathComponent] forKey:@"FileNameOverRide"];


	BOOL copiedFile = [self copyFile:inputPath withTags:tagValues withStandardTags:standardTags];
	
	if(copiedFile)
	{
        [self updateVideo:inputPath withTags:tagValues useHEVC:true];
        [self updateTags:inputPath withTags:tagValues withOverride:true];
	}
	
	if([[[self parameters] valueForKey:@"setModifiedDateOfFileToImageDate"] boolValue])
	{
		[[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:[NSDate dateFromEXIF:[tagValues valueForKey:@"DateTimeOriginal"]] forKey:NSFileModificationDate] ofItemAtPath:[tagValues valueForKey:@"OutputFilePath"] error:nil];

		[[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:[NSDate dateFromEXIF:[tagValues valueForKey:@"DateTimeOriginal"]] forKey:NSFileCreationDate] ofItemAtPath:[tagValues valueForKey:@"OutputFilePath"] error:nil];

        if([[tagValues valueForKey:@"MimeType"] hasPrefix:@"video"]) {
            [[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:[NSDate dateFromEXIF:[tagValues valueForKey:@"DateTimeOriginal"]] forKey:NSFileModificationDate] ofItemAtPath:[tagValues valueForKey:@"OutputProperFullFilePath"] error:nil];
            
            [[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:[NSDate dateFromEXIF:[tagValues valueForKey:@"DateTimeOriginal"]] forKey:NSFileCreationDate] ofItemAtPath:[tagValues valueForKey:@"OutputProperFullFilePath"] error:nil];
        }
    }
	
	//	NSMutableArray *scriptParameters = [[NSMutableArray alloc] initWithCapacity:0];
	
/*	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:@"Alert"];
	
	[alert setInformativeText:[NSString stringWithFormat:@"Image Archive: %@",inputPath]];
	[alert runModal];	
	[alert release]; 	

	alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:@"Alert"];
	
	[alert setInformativeText:[NSString stringWithFormat:@"Image Archive: %@",[[self parameters] valueForKey:@"archiveDirectory"]]];
	[alert runModal];	
	[alert release]; 	

	alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:@"Alert"];
	
	[alert setInformativeText:[NSString stringWithFormat:@"Remove Current Keywords: %@",[[self parameters] valueForKey:@"removeCurrentKeywords"]]];
	[alert runModal];	
	[alert release]; 	
*/
}

-(BOOL) copyFile:(NSString *)inputPath withTags:(NSDictionary *)tagValues withStandardTags:(NSArray *) standardTags
{
	if(![[[self parameters] valueForKey:@"copyUpdatedFile"] boolValue])
	{
		[(NSMutableDictionary *) tagValues setObject:inputPath forKey:@"OutputFilePath"];		
		
		return(YES);
	}
	
	NSString *fileNameOverride = [tagValues valueForKey:@"FileNameOverRide"];
	if(fileNameOverride == nil)
		fileNameOverride = [inputPath lastPathComponent];
	
	NSError * error = nil;
	BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:[tagValues valueForKey:@"OutputFullDirectoryPath"] withIntermediateDirectories:YES attributes:nil error:&error];
	
	if (!success || error) {
		NSLog(@"Error! %@", error);
	} else {
		NSLog(@"Success!");
	}
	
	NSLog(@"filePath: %@", [tagValues valueForKey:@"OutputFilePath"]);
	
	BOOL			fileExists = NO;
	unsigned int	fileOffset = 0;
	NSString		*moveFilePath = nil;
	
	if([[[self parameters] valueForKey:@"renameFile"] boolValue])
	{
		if([[tagValues valueForKey:@"OutputVideo"] boolValue])
			moveFilePath = [NSString stringWithFormat:@"%@/%@-%d.%@", [tagValues valueForKey:@"OutputFullDirectoryPath"], fileNameOverride, 1, [inputPath pathExtension]];
		
		else
			moveFilePath = [NSString stringWithFormat:@"%@/%@_%@-%d.%@", [tagValues valueForKey:@"OutputFullDirectoryPath"], [tagValues valueForKey:@"OutputFormattedDate"], [tagValues valueForKey:@"Model"], 1, [inputPath pathExtension]];
	}
	
	else
	{
		moveFilePath = [NSString stringWithFormat:@"%@/%@-%d.%@", [tagValues valueForKey:@"OutputFullDirectoryPath"], fileNameOverride, 1, [inputPath pathExtension]];
	}
	
	NSLog(@"movePath: %@", moveFilePath);
	
	if([[NSFileManager defaultManager] fileExistsAtPath: [tagValues valueForKey:@"OutputFilePath"]])
		fileExists = YES;
	
	else
	{
		if([[NSFileManager defaultManager] fileExistsAtPath: moveFilePath])
		{
			fileExists = YES;
			fileOffset = 1;
			
			[(NSMutableDictionary *) tagValues setObject:moveFilePath forKey:@"OutputFilePath"];
		}
	}
	
	while(fileExists)
	{
		NSLog(@"Checking File %@", [tagValues valueForKey:@"OutputFilePath"]);
		
		NSDictionary *fileTagValues = [self getTagInformation:[tagValues valueForKey:@"OutputFilePath"] withTags:standardTags];
		
		[self addUnknownTags:fileTagValues forPath:[tagValues valueForKey:@"OutputFilePath"]];
		
		[(NSMutableDictionary *) fileTagValues setObject:[tagValues valueForKey:@"OriginalDateNotFound"] forKey:@"OriginalDateNotFound"];
		[(NSMutableDictionary *) fileTagValues setObject:[tagValues valueForKey:@"OverrideTime"] forKey:@"OverrideTime"];
		
		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"OutputFilePath"] forKey:@"OutputFilePath"];

		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"UserComment"] forKey:@"UserComment"];
		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"Caption-Abstract"] forKey:@"Caption-Abstract"];
		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"Comment"] forKey:@"Comment"];
		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"Description"] forKey:@"Description"];
		
		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"GPSAltitude"] forKey:@"GPSAltitude"];
		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"GPSLatitude"] forKey:@"GPSLatitude"];
		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"GPSLongitude"] forKey:@"GPSLongitude"];
		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"GPSDateTime"] forKey:@"GPSDateTime"];
		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"GPSTimeStamp"] forKey:@"GPSTimeStamp"];
		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"DigitalCreationDateTime"] forKey:@"DigitalCreationDateTime"];
        [(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"CreationDate"] forKey:@"CreationDate"];
		
		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"TimeZoneOffset"] forKey:@"TimeZoneOffset"];

		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"Timezone"] forKey:@"Timezone"];

		[(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"FileNameOverRide"] forKey:@"FileNameOverRide"];
        [(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"OriginalFile"] forKey:@"OriginalFile"];
        [(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"Software"] forKey:@"Software"];
        [(NSMutableDictionary *) fileTagValues setValue:[tagValues valueForKey:@"OutputProperFullDirectoryPath"] forKey:@"OutputProperFullDirectoryPath"];
        
		if([self tagsEqual:tagValues withTags:fileTagValues])
			if([[[self parameters] valueForKey:@"skipDuplicates"] boolValue])
			{
                if([[[self parameters] valueForKey:@"updateDuplicates"] boolValue])
                {
                    NSLog(@"Skipping And Updating Duplicate:! %@", inputPath);
                    return(YES);
                }
                
                else
                {
                    NSLog(@"Skipping Duplicate:! %@", inputPath);
                    return(NO);
                }
			}
		
		if(fileOffset == 0)
		{
			[[NSFileManager defaultManager] moveItemAtPath:[tagValues valueForKey:@"OutputFilePath"] toPath:moveFilePath error:nil];
			
			++fileOffset;
		}
		
		if([[[self parameters] valueForKey:@"renameFile"] boolValue])
		{
			if([[tagValues valueForKey:@"OutputVideo"] boolValue])
				[(NSMutableDictionary *) tagValues setObject:[NSString stringWithFormat:@"%@/%@-%d.%@", [tagValues valueForKey:@"OutputFullDirectoryPath"], fileNameOverride, ++fileOffset, [inputPath pathExtension]]  forKey:@"OutputFilePath"];
			
			else
				[(NSMutableDictionary *) tagValues setObject:[NSString stringWithFormat:@"%@/%@_%@-%d.%@", [tagValues valueForKey:@"OutputFullDirectoryPath"], [tagValues valueForKey:@"OutputFormattedDate"], [tagValues valueForKey:@"Model"], ++fileOffset, [inputPath pathExtension]] forKey:@"OutputFilePath"];
		}
		
		else
		{
			[(NSMutableDictionary *) tagValues setObject:[NSString stringWithFormat:@"%@/%@-%d.%@", [tagValues valueForKey:@"OutputFullDirectoryPath"], fileNameOverride, ++fileOffset, [inputPath pathExtension]]  forKey:@"OutputFilePath"];
		}
		
		if(![[NSFileManager defaultManager] fileExistsAtPath: [tagValues valueForKey:@"OutputFilePath"]])
			fileExists = NO;
	}
	
	[[NSFileManager defaultManager] copyItemAtPath:inputPath toPath:[tagValues valueForKey:@"OutputFilePath"] error:nil];
	
	NSLog(@"Done copying:! %@", inputPath);	
	
	return(YES);
}

-(void) updateImage:(NSDictionary *)tagValues
{
}

//------------------------------------------------------
-(NSArray *) runExifTool:(NSArray *) arguments
{
	return [self runCommand:@"/usr/bin/exiftool":arguments];
}

//------------------------------------------------------
-(NSArray *) runHandBrake:(NSArray *) arguments
{
	return [self runCommand:@"/usr/local/bin/HandBrakeCLI":arguments];
}

//------------------------------------------------------
-(NSArray *) runFFMPEG:(NSArray *) arguments
{
	return [self runCommand:@"~/git/ffmpeg/ffmpeg":arguments];
}

//------------------------------------------------------
-(NSArray *) runAtomicParsley:(NSArray *) arguments
{
	return [self runCommand:@"/usr/local/bin/AtomicParsley":arguments];
}

//------------------------------------------------------
-(NSDictionary *) getTagInformation:(NSString *)inputPath withTags:(NSArray *) tags
{
	NSMutableArray *arguments = [[NSMutableArray alloc] initWithCapacity:0];
	
	NSMutableDictionary *tagValues = [[NSMutableDictionary alloc] init];
	
	[arguments addObject:@"-f"];
	[arguments addObject:@"-s"];
	[arguments addObject:@"-s"];
	[arguments addObject:@"-s"];
	
	for(NSString* tag in tags)
		[arguments addObject:[NSString stringWithFormat:@"-%@", tag]];
	
	[arguments addObject:[NSString stringWithFormat:@"%@",inputPath]];
	
	NSArray *commandResults = nil;
	
	@try
	{
		commandResults = [self runExifTool:arguments];
	}
	@catch (NSException *exception)
	{
		NSLog(@"Error [%@] in file [%@]", [exception reason], inputPath);
		
		if([[exception reason] caseInsensitiveCompare:@"Unknown file type"] != NSOrderedSame)
		   @throw exception;
	}
	
	for (unsigned long i = 0; i < [commandResults count]; i++)
	{
		NSString *commandResult = [commandResults objectAtIndex:i];
		NSString *key = [[tags objectAtIndex:i] stringByReplacingOccurrencesOfString:@"#" withString:@""];
		
		if([commandResult caseInsensitiveCompare:@"-"] == NSOrderedSame)
			commandResult = nil;
		
        if(commandResult != nil) {
            [tagValues setObject:commandResult forKey:key];
        }
	}

	
	return tagValues;
}

//------------------------------------------------------
-(void) updateTags:(NSString *)inputPath withTags:(NSDictionary *) tags withOverride:(BOOL) override
{
	if((![[tags valueForKey:@"MimeType"] hasPrefix:@"image"]) && !override)
		return;

    BOOL isVideo = NO;
    
    if([[tags valueForKey:@"MimeType"] hasPrefix:@"video"])
        isVideo = YES;

    NSString *fileNameOverride = [tags valueForKey:@"FileNameOverRide"];
	if(fileNameOverride == nil)
		fileNameOverride = [inputPath lastPathComponent];

	NSMutableArray *arguments = [[NSMutableArray alloc] initWithCapacity:0];
		
    [arguments addObject:@"-config"];
    [arguments addObject:@"/tmp/oiconfig.txt"];
    
    if(![[tags valueForKey:@"MimeType"] hasPrefix:@"image"]) {
        [arguments addObject:@"-TagsFromFile"];
        [arguments addObject:inputPath];
    }
    
	[arguments addObject:@"-overwrite_original"];
	
    [arguments addObject:[NSString stringWithFormat:@"-xmp-xmp:OriginalFile=%@", fileNameOverride]];
    
	if([[[self parameters] valueForKey:@"removeCurrentKeywords"] boolValue])
		[arguments addObject:@"-Keywords="];
	
	if([[[self parameters] valueForKey:@"keywords"] length] > 0)
	{
		NSArray *tokens = [[[self parameters] valueForKey:@"keywords"] componentsSeparatedByString:@","];
		
		for (unsigned long i = 0; i < [tokens count]; i++)
		{
			[arguments addObject:[NSString stringWithFormat:@"-Keywords+=%@", [[tokens objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];
		}
	}
	
	if([[[self parameters] valueForKey:@"putOriginalFileNameAsDescription"] boolValue])
	{
		NSLog(@"Putting Original File Name as Description");
		
		if(([[tags valueForKey:@"Caption-Abstract"] length] == 0) || ([[tags valueForKey:@"Caption-Abstract"] rangeOfString:[NSString stringWithFormat:@".%@",[inputPath pathExtension]]].location == NSNotFound))
		{
			NSLog(@"Didn't Find Caption Abstract [%@]", [tags valueForKey:@"Caption-Abstract"]);
            NSLog(@"Setting Caption Abstract [%@]", fileNameOverride);
                
            if([[tags valueForKey:@"Caption-Abstract"] length] > 0)
                [arguments addObject:[NSString stringWithFormat:@"-Caption-Abstract=%@ %@", [tags valueForKey:@"Caption-Abstract"], fileNameOverride]];

            else
                [arguments addObject:[NSString stringWithFormat:@"-Caption-Abstract=%@", fileNameOverride]];
		}
		
		if(([[tags valueForKey:@"UserComment"] length] == 0) || ([[tags valueForKey:@"UserComment"] rangeOfString:[NSString stringWithFormat:@".%@",[inputPath pathExtension]]].location == NSNotFound))
		{
			NSLog(@"Didn't Find User Comment [%@]", [tags valueForKey:@"UserComment"]);

            NSLog(@"Setting User Commment [%@]", fileNameOverride);

            if([[tags valueForKey:@"UserComment"] length] > 0)
                [arguments addObject:[NSString stringWithFormat:@"-UserComment=%@ %@", [tags valueForKey:@"UserComment"], fileNameOverride]];
            
            else
                [arguments addObject:[NSString stringWithFormat:@"-UserComment=%@", fileNameOverride]];
		}

		if(([[tags valueForKey:@"Comment"] length] == 0) || ([[tags valueForKey:@"Comment"] rangeOfString:[NSString stringWithFormat:@".%@",[inputPath pathExtension]]].location == NSNotFound))
		{
			NSLog(@"Didn't Find Comment [%@]", [tags valueForKey:@"Comment"]);
			
            NSLog(@"Setting Comment [%@]", fileNameOverride);

            if([[tags valueForKey:@"Comment"] length] > 0)
                [arguments addObject:[NSString stringWithFormat:@"-Comment=%@ %@", [tags valueForKey:@"Comment"], fileNameOverride]];
            
            else
            [arguments addObject:[NSString stringWithFormat:@"-Comment=%@", fileNameOverride]];
		}

		if(([[tags valueForKey:@"Description"] length] == 0) || ([[tags valueForKey:@"Description"] rangeOfString:[NSString stringWithFormat:@".%@",[inputPath pathExtension]]].location == NSNotFound))
		{
			NSLog(@"Didn't Find Description [%@]", [tags valueForKey:@"Description"]);
			
            NSLog(@"Setting Description [%@]", fileNameOverride);

            if([[tags valueForKey:@"Description"] length] > 0)
                [arguments addObject:[NSString stringWithFormat:@"-Description=%@ %@", [tags valueForKey:@"Description"], fileNameOverride]];
            
            else
                [arguments addObject:[NSString stringWithFormat:@"-Description=%@", fileNameOverride]];
		}
	}
	
	if([[tags valueForKey:@"OriginalDateNotFound"] boolValue])
	{
		[arguments addObject:[NSString stringWithFormat:@"-DateTimeOriginal=%@", [tags valueForKey:@"DateTimeOriginal"]]];
	}

	if(([[tags valueForKey:@"OverrideTime"] boolValue] == YES) || ([[tags valueForKey:@"DigitalCreationDateTime"] length] == 0))
	{
		NSLog(@"Overwriting Digital Creation Date and Time with [%@]", [tags valueForKey:@"DateTimeOriginal"]);

		[arguments addObject:[NSString stringWithFormat:@"-DigitalCreationDate=%@", [tags valueForKey:@"DateTimeOriginal"]]];

		[arguments addObject:[NSString stringWithFormat:@"-DigitalCreationTime=%@", [tags valueForKey:@"DateTimeOriginal"]]];
	}
	
	if([[tags valueForKey:@"GPSDateTime"] length] < 11)
	{
		NSLog(@"Overwriting GPS Date and Time with [%@]", [tags valueForKey:@"DateTimeOriginal"]);
		
		NSDate *exifDate = [NSDate dateFromEXIF:[tags valueForKey:@"DateTimeOriginal"]];
		
		NSDateFormatter* timestampDateFormatter = [[NSDateFormatter alloc] init];
		
		[timestampDateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
		
		[timestampDateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
		
		[arguments addObject:[NSString stringWithFormat:@"-GPSDateTime=%@Z", [timestampDateFormatter stringFromDate:exifDate]]];
		
	}
	
	if(([[tags valueForKey:@"OverrideTime"] boolValue] == YES) || ([[tags valueForKey:@"TimeZoneOffset"] length] == 0))
	{
		NSLog(@"Writing Time Zone Offset: %@", [tags valueForKey:@"Timezone"]);

		NSInteger zoneOffset = [[[tags valueForKey:@"Timezone"] stringByReplacingOccurrencesOfString:@":" withString:@""] intValue];
		
		NSInteger hourOffset = zoneOffset / 100;
		
		[arguments addObject:[NSString stringWithFormat:@"-TimeZoneOffset=%@", [NSString stringWithFormat:@"%ld", hourOffset]]];
	}

	if([[[self parameters] valueForKey:@"latitude"] length] > 0)
		[arguments addObject:[NSString stringWithFormat:@"-exif:gpslatitude=%@", [[self parameters] valueForKey:@"latitude"]]];
																
	if([[[self parameters] valueForKey:@"longitude"] length] > 0)
		[arguments addObject:[NSString stringWithFormat:@"-exif:gpslongitude%@", [[self parameters] valueForKey:@"longitude"]]];

	if([[[self parameters] valueForKey:@"rotate"] length] > 0)
	{
		if([[[self parameters] valueForKey:@"rotate"] caseInsensitiveCompare:@"0°"] == NSOrderedSame)
			[arguments addObject:[NSString stringWithFormat:@"-Orientation=Horizontal"]];

		if([[[self parameters] valueForKey:@"rotate"] caseInsensitiveCompare:@"Left 90°"] == NSOrderedSame)
			[arguments addObject:[NSString stringWithFormat:@"-Orientation=Rotate 270 CW"]];

		if([[[self parameters] valueForKey:@"rotate"] caseInsensitiveCompare:@"Right 90°"] == NSOrderedSame)
			[arguments addObject:[NSString stringWithFormat:@"-Orientation=Rotate 90 CW"]];

		if([[[self parameters] valueForKey:@"rotate"] caseInsensitiveCompare:@"180°"] == NSOrderedSame)
			[arguments addObject:[NSString stringWithFormat:@"-Orientation=Rotate 180"]];
    }

    if(isVideo) {
        [arguments addObject:[tags valueForKey:@"OutputProperFullFilePath"]];
    } else {
        [arguments addObject:[tags valueForKey:@"OutputFilePath"]];
    }
	
	[self runExifTool:arguments];
	
	return;
}

//------------------------------------------------------
-(void) updateVideo:(NSString *)inputPath withTags:(NSDictionary *) tags useHEVC:(BOOL) hevc
{
	if(![[tags valueForKey:@"MimeType"] hasPrefix:@"video"])
		return;
	
	NSLog(@"Updating Video Tags");
	
	BOOL	convertVideo = hevc;
	
	if([[inputPath pathExtension] caseInsensitiveCompare:@"MTS"] == NSOrderedSame)
		convertVideo = YES;
	
	if([[tags valueForKey:@"VideoCodec"] caseInsensitiveCompare:@"MJPG"] == NSOrderedSame)
		convertVideo = YES;

    if([[[self parameters] valueForKey:@"copyUpdatedFile"] boolValue])
        convertVideo = YES;
    
	NSError * error = nil;
	BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:[tags valueForKey:@"OutputProperFullDirectoryPath"] withIntermediateDirectories:YES attributes:nil error:&error];

	if (!success || error) {
		NSLog(@"Error! %@", error);
	} else {
		NSLog(@"Success!");
	}

	NSString *outputVideoPath = [NSString stringWithFormat:@"%@/%@_%@.mp4", [tags valueForKey:@"OutputProperFullDirectoryPath"], [tags valueForKey:@"OutputFormattedDate"], [tags valueForKey:@"Model"]];
	
	NSMutableArray *arguments;
	NSString *videoPath = inputPath;
	
    if(convertVideo) {
        arguments = [[NSMutableArray alloc] initWithCapacity:0];
        videoPath = [NSString stringWithFormat:@"%@.tmp.mp4", [tags valueForKey:@"OutputFilePath"]];
        
        [arguments addObject:@"-i"];
        [arguments addObject:inputPath];
        [arguments addObject:@"-c:v"];
        [arguments addObject:@"libx265"];
        [arguments addObject:@"-preset"];
        [arguments addObject:@"medium"];
        [arguments addObject:@"-crf"];
        [arguments addObject:@"20"];
        [arguments addObject:@"-map_metadata"];
        [arguments addObject:@"0"];

        if([[inputPath pathExtension] caseInsensitiveCompare:@"MTS"] == NSOrderedSame)
        {
            [arguments addObject:@"-vf"];
            [arguments addObject:@"yadif"];
        }

        if([[inputPath pathExtension] caseInsensitiveCompare:@"AVI"] != NSOrderedSame)
        {
            [arguments addObject:@"-c:a"];
            [arguments addObject:@"copy"];
        } else {
            [arguments addObject:@"-c:a"];
            [arguments addObject:@"aac"];
            [arguments addObject:@"-b:a"];
            [arguments addObject:@"128k"];
        }

        [arguments addObject:[NSString stringWithFormat:@"%@.tmp.mp4",outputVideoPath]];
        
        [self runFFMPEG:arguments];
        
        [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
        
        if([[NSFileManager defaultManager] fileExistsAtPath: outputVideoPath])
            [[NSFileManager defaultManager] removeItemAtPath:outputVideoPath error:nil];

        arguments = [[NSMutableArray alloc] initWithCapacity:0];
        
        [arguments addObject:@"-i"];
        [arguments addObject:[NSString stringWithFormat:@"%@.tmp.mp4",outputVideoPath]];
        [arguments addObject:@"-c"];
        [arguments addObject:@"copy"];
        
        if([[[self parameters] valueForKey:@"rotate"] length] > 0)
        {
            [arguments addObject:@"-metadata:s:v:0"];
            
            if([[[self parameters] valueForKey:@"rotate"] caseInsensitiveCompare:@"0°"] == NSOrderedSame)
                [arguments addObject:@"rotate=0"];
            
            if([[[self parameters] valueForKey:@"rotate"] caseInsensitiveCompare:@"Left 90°"] == NSOrderedSame)
                [arguments addObject:@"rotate=90"];
            
            if([[[self parameters] valueForKey:@"rotate"] caseInsensitiveCompare:@"Right 90°"] == NSOrderedSame)
                [arguments addObject:@"rotate=270"];
            
            if([[[self parameters] valueForKey:@"rotate"] caseInsensitiveCompare:@"180°"] == NSOrderedSame)
                [arguments addObject:@"rotate=180"];
        }
        
        if([tags valueForKey:@"OriginalModel"] == nil) {
            [arguments addObject:@"-metadata:g:0"];
            [arguments addObject:@"model=Unknown"];
        } else {
            [arguments addObject:@"-metadata:g:0"];
            [arguments addObject:[NSString stringWithFormat:@"model=%@",[tags valueForKey:@"OriginalModel"]]];
        }
        
        if([tags valueForKey:@"OriginalMake"] == nil) {
            [arguments addObject:@"-metadata:g:0"];
            [arguments addObject:@"make=Unknown"];
        } else {
            [arguments addObject:@"-metadata:g:0"];
            [arguments addObject:[NSString stringWithFormat:@"make=%@",[tags valueForKey:@"OriginalMake"]]];
        }

        if([[[self parameters] valueForKey:@"latitude"] length] > 0 && [[[self parameters] valueForKey:@"longitude"] length] > 0) {
            double latitude = [[[self parameters] valueForKey:@"latitude"] doubleValue];
            double longitude = [[[self parameters] valueForKey:@"longitude"] doubleValue];
            
            NSString *latitudeString = [NSString stringWithFormat:@"%s%@", (latitude >= 0) ? "+" : "", [[self parameters] valueForKey:@"latitude"]];
            NSString *longitudeString = [NSString stringWithFormat:@"%s%@",(longitude >= 0) ? "+" : "", [[self parameters] valueForKey:@"longitude"]];
            
            
            [arguments addObject:@"-metadata:g:0"];
            [arguments addObject:[NSString stringWithFormat:@"location=%@",[NSString stringWithFormat:@"%@%@/", latitudeString, longitudeString]]];
            [arguments addObject:@"-metadata:g:0"];
            [arguments addObject:[NSString stringWithFormat:@"location-eng=%@",[NSString stringWithFormat:@"%@%@/", latitudeString, longitudeString]]];
        } else {
            if([[tags valueForKey:@"GPSLatitude"] length] > 0 && [[tags valueForKey:@"GPSLongitude"] length] > 0) {
                
                double latitude = [[tags valueForKey:@"GPSLatitude"] doubleValue];
                double longitude = [[tags valueForKey:@"GPSLongitude"] doubleValue];
                double altitude = -1.0;
                
                if([[tags valueForKey:@"GPSAltitude"] length] > 0) {
                    altitude =[[tags valueForKey:@"GPSAltitude"] doubleValue];
                }
                
                NSLog(@"GPS Altitude [%@]", [tags valueForKey:@"GPSAltitude"]);
                
                NSString *latitudeString = [NSString stringWithFormat:@"%s%@", (latitude >= 0) ? "+" : "", [tags valueForKey:@"GPSLatitude"]];
                NSString *longitudeString = [NSString stringWithFormat:@"%s%@",(longitude >= 0) ? "+" : "", [tags valueForKey:@"GPSLongitude"]];
                NSString *altitudeString = [NSString stringWithFormat:@"%s%@",(altitude >= 0) ? "+" : "", (altitude >= 0) ? [tags valueForKey:@"GPSAltitude"] : @""];
                
                
                [arguments addObject:@"-metadata:g:0"];
                [arguments addObject:[NSString stringWithFormat:@"location=%@",[NSString stringWithFormat:@"%@%@%@/", latitudeString, longitudeString, altitudeString]]];
                [arguments addObject:@"-metadata:g:0"];
                [arguments addObject:[NSString stringWithFormat:@"location-eng=%@",[NSString stringWithFormat:@"%@%@%@/", latitudeString, longitudeString, altitudeString]]];
            }
        }

        [arguments addObject:outputVideoPath];
        
        NSLog(@"Adding Video Metadata [%@]", arguments);
        [self runFFMPEG:arguments];

        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@.tmp.mp4",outputVideoPath] error:nil];
    }
}

//------------------------------------------------------
-(void) addUnknownTags:(NSDictionary *)tags forPath:(NSString *)path
{
	[self addUnknownTags:tags forPath:path withOffset:0];
}

//------------------------------------------------------
-(void) addUnknownTags:(NSDictionary *)tags forPath:(NSString *)path withOffset:(NSUInteger)offset
{
	BOOL isVideo = NO;
	
	NSLog(@"Checking Date: %@", [tags valueForKey:@"DateTimeOriginal"]);

	NSDate		*exifDate = nil;
	NSTimeZone	*exifTimeZone = nil;
	
	[(NSMutableDictionary *) tags setObject:[NSNumber numberWithBool:NO] forKey:@"OriginalDateNotFound"];
	[(NSMutableDictionary *) tags setObject:[NSNumber numberWithBool:NO] forKey:@"OverrideTime"];
	
	if([[tags valueForKey:@"DateTimeOriginal"] length] == 0)
		[(NSMutableDictionary *) tags setObject:[NSNumber numberWithBool:YES] forKey:@"OriginalDateNotFound"];

	if([[tags valueForKey:@"DateTimeOriginal"] length] == 0)
	if([[tags valueForKey:@"DigitalCreationDateTime"] length] > 0)
		[(NSMutableDictionary *) tags setObject:[tags valueForKey:@"DigitalCreationDateTime"] forKey:@"DateTimeOriginal"];

    if([[tags valueForKey:@"DateTimeOriginal"] length] == 0)
        if([[tags valueForKey:@"CreationDate"] length] > 0)
            [(NSMutableDictionary *) tags setObject:[tags valueForKey:@"CreationDate"] forKey:@"DateTimeOriginal"];

    if([[tags valueForKey:@"DateTimeOriginal"] length] == 0)
	{
		NSLog(@"No Date Time Original, Checking Created Date [%@]", [tags valueForKey:@"CreateDate"]);
		
		if([[tags valueForKey:@"CreateDate"] length] > 0)
			[(NSMutableDictionary *) tags setObject:[tags valueForKey:@"CreateDate"] forKey:@"DateTimeOriginal"];
		
		else
		{
			NSLog(@"No Original Date In File");
			
			NSDictionary *attribs = [[NSFileManager defaultManager] attributesOfItemAtPath: path error: NULL];
			
			NSLog(@"File Creation Date: %@", [attribs objectForKey: NSFileCreationDate]);
			
			[(NSMutableDictionary *) tags setObject:[NSDate exifStringFromDate:[attribs objectForKey: NSFileCreationDate]] forKey:@"DateTimeOriginal"];
		}
	}
	
	exifDate = [NSDate dateFromEXIF:[tags valueForKey:@"DateTimeOriginal"]];
	
	if((exifTimeZone == nil) && ([[tags valueForKey:@"GPSLatitude"] length] > 0) && ([[tags valueForKey:@"GPSLongitude"] length] > 0))
	{
		exifTimeZone = [self getGPSTimeZoneOffset:[tags valueForKey:@"GPSLatitude"]:[tags valueForKey:@"GPSLongitude"] atDate:[tags valueForKey:@"DateTimeOriginal"]];

		NSLog(@"Setting Time Zone from offset %@", exifTimeZone);
		
		[(NSMutableDictionary *) tags setObject:[NSNumber numberWithBool:YES] forKey:@"OverrideTime"];
	}
	
	if([[tags valueForKey:@"Timezone"] length] > 0)
	{
		exifTimeZone = [NSTimeZone timeZoneWithAbbreviation:[tags valueForKey:@"Timezone"]];

		if(exifTimeZone == nil)
		{
			NSInteger zoneOffset = [[[tags valueForKey:@"Timezone"] stringByReplacingOccurrencesOfString:@":" withString:@""] intValue];
			
			NSInteger minuteOffset = abs((int) zoneOffset) % 100;
			NSInteger hourOffset = zoneOffset / 100;
			
			NSInteger zoneOffsetSeconds = hourOffset * 60 * 60 + minuteOffset * 60;
			
			exifTimeZone = [NSTimeZone timeZoneForSecondsFromGMT:zoneOffsetSeconds];
		}

		NSLog(@"Setting Time Zone to Time Zone %@", exifTimeZone);
	}
	
	if((exifTimeZone == nil) && ([[tags valueForKey:@"DateTimeOriginal"] length] > 19))
	{
		NSString *filteredDateString = [[tags valueForKey:@"DateTimeOriginal"] stringByReplacingOccurrencesOfString:@":" withString:@""];
		NSString *zoneString = [filteredDateString substringFromIndex:15];

		if([zoneString caseInsensitiveCompare:@"Z"] == NSOrderedSame)
			zoneString = @"GMT";
		
		NSLog(@"Zone In Original Date: [%@] for [%@]", zoneString, filteredDateString);
		
		exifTimeZone = [NSTimeZone timeZoneWithAbbreviation:zoneString];
		
		if(exifTimeZone == nil)
		{
			NSInteger zoneOffset = [[zoneString stringByReplacingOccurrencesOfString:@":" withString:@""] intValue];
			
			NSInteger minuteOffset = abs((int) zoneOffset) % 100;
			NSInteger hourOffset = zoneOffset / 100;
			
			NSInteger zoneOffsetSeconds = hourOffset * 60 * 60 + minuteOffset * 60;
			
			exifTimeZone = [NSTimeZone timeZoneForSecondsFromGMT:zoneOffsetSeconds];
			
			NSLog(@"Found Offset Zone in Original Date: [%@]", exifTimeZone);
		}
	}
	
	if((exifTimeZone == nil) && ([[tags valueForKey:@"GPSDateTime"] length] > 0))
	{
		NSString *originalDateTimeString = [tags valueForKey:@"DateTimeOriginal"];
		if([originalDateTimeString length] == 19)
			originalDateTimeString = [NSString stringWithFormat:@"%@Z", originalDateTimeString];
		
		NSLog(@"Checking GPS Date [%@] vs [%@]", [tags valueForKey:@"GPSDateTime"], originalDateTimeString);
		
		NSDate *tempDate = [NSDate dateFromEXIF:originalDateTimeString];
		NSDate *gpsDate = [NSDate dateFromEXIF:[tags valueForKey:@"GPSDateTime"]];
		
		NSTimeInterval interval = [gpsDate timeIntervalSinceDate: tempDate];
		
		if(fabs(fmodf(interval, 3600)) < 10)
		{
			NSLog(@"GPS Date Interval %f", interval);
			
			NSInteger zoneOffset;
			
			if(interval < 0)
				zoneOffset = (int) interval + ((int) -interval % 3600);
			
			else
				zoneOffset = (int) interval - ((int) interval % 3600);
			
			NSInteger minuteOffset = abs((int) zoneOffset) % 100;
			NSInteger hourOffset = zoneOffset / 100;
			
			NSInteger zoneOffsetSeconds = hourOffset * 60 * 60 + minuteOffset * 60;
			
			exifTimeZone = [NSTimeZone timeZoneForSecondsFromGMT:zoneOffsetSeconds];

			NSLog(@"GPS Date Time Zone %@", exifTimeZone);
		}
	}
	
	if((exifTimeZone == nil) && ([[tags valueForKey:@"TimeZoneOffset"] length] > 0))
	{
		NSInteger hourOffset = [[[tags valueForKey:@"TimeZoneOffset"] stringByReplacingOccurrencesOfString:@":" withString:@""] intValue];
		
		NSInteger zoneOffsetSeconds = hourOffset * 60 * 60;
		
		exifTimeZone = [NSTimeZone timeZoneForSecondsFromGMT:zoneOffsetSeconds];
		
		NSLog(@"Setting Time Zone to Time Zone Offset %@", exifTimeZone);
	}
	
	if(exifTimeZone == nil)
	{
		exifTimeZone = [NSTimeZone localTimeZone];
		
		NSLog(@"Setting Time Zone to Local Time Zone %@", exifTimeZone);
	}
	
    if([[[self parameters] valueForKey:@"make"] length] > 0)
        [(NSMutableDictionary *) tags setObject:[[self parameters] valueForKey:@"make"] forKey:@"Make"];
    
    if([[[self parameters] valueForKey:@"model"] length] > 0)
        [(NSMutableDictionary *) tags setObject:[[self parameters] valueForKey:@"model"] forKey:@"Model"];
    
    if([tags valueForKey:@"Timezone"] == nil)
	{
		NSString	*sign = @"+";
		
		if([exifTimeZone secondsFromGMT] < 0)
			sign = @"-";
		
		[(NSMutableDictionary *) tags setObject:[NSString stringWithFormat:@"%@%02d:%02d", sign, abs((int) [exifTimeZone secondsFromGMTForDate:exifDate] / 60 / 60), abs((int) [exifTimeZone secondsFromGMTForDate:exifDate] / 60 % 60)] forKey:@"Timezone"];
	}
	
	if([[tags valueForKey:@"DateTimeOriginal"] length] == 19)
	if([tags valueForKey:@"Timezone"] != nil)
	{
		NSLog(@"Checking Date with time zone (%ld): %@", [[tags valueForKey:@"DateTimeOriginal"] length], [NSString stringWithFormat:@"%@%@", [tags valueForKey:@"DateTimeOriginal"], [tags valueForKey:@"Timezone"]]);

		[(NSMutableDictionary *) tags setObject:[NSString stringWithFormat:@"%@%@", [tags valueForKey:@"DateTimeOriginal"], [tags valueForKey:@"Timezone"]] forKey:@"DateTimeOriginal"];
	}
	
	exifDate = [NSDate dateFromEXIF:[tags valueForKey:@"DateTimeOriginal"]];

	NSLog(@"Determined Date: %@ for %@", exifDate, [tags valueForKey:@"DateTimeOriginal"]);
	
	if(([[tags valueForKey:@"GPSLatitude"] length] > 0) && ([[tags valueForKey:@"GPSLatitude"] length] > 0))
		[self setGPSTimeZone:[tags valueForKey:@"GPSLatitude"]:[tags valueForKey:@"GPSLongitude"] withTimeZone:exifTimeZone];
	
	NSLog(@"Setting Original Date: %@", [NSDate exifStringFromDate:exifDate]);

	[(NSMutableDictionary *) tags setObject:[NSDate exifStringFromDate:exifDate] forKey:@"DateTimeOriginal"];
	
	if([[tags valueForKey:@"MimeType"] hasPrefix:@"video"])
		isVideo = YES;
	
	if([tags valueForKey:@"Model"] == nil)
		[(NSMutableDictionary *) tags setObject:@"Unknown" forKey:@"Model"];
	
	[(NSMutableDictionary *) tags setObject:[tags valueForKey:@"Model"] forKey:@"OriginalModel"];
	[(NSMutableDictionary *) tags setObject:[[tags valueForKey:@"Model"] stringByReplacingOccurrencesOfString:@" " withString:@"_"] forKey:@"Model"];
	
	if([tags valueForKey:@"Make"] == nil)
		[(NSMutableDictionary *) tags setObject:@"Unknown" forKey:@"Make"];
	
	[(NSMutableDictionary *) tags setObject:[tags valueForKey:@"Make"] forKey:@"OriginalMake"];
	[(NSMutableDictionary *) tags setObject:[[tags valueForKey:@"Make"] stringByReplacingOccurrencesOfString:@" " withString:@"_"] forKey:@"Make"];

	if([tags valueForKey:@"VideoCodec"] == nil)
		[(NSMutableDictionary *) tags setObject:@"Unknown" forKey:@"VideoCodec"];
	
	if([[[self parameters] valueForKey:@"latitude"] length] > 0)
		[(NSMutableDictionary *) tags setObject:[[self parameters] valueForKey:@"latitude"] forKey:@"GPSLatitude"];
	
	if([[[self parameters] valueForKey:@"longitude"] length] > 0)
		[(NSMutableDictionary *) tags setObject:[[self parameters] valueForKey:@"longitude"] forKey:@"GPSLongitude"];
	
	if([[[self parameters] valueForKey:@"rotate"] length] > 0)
	{
		if([[[self parameters] valueForKey:@"rotate"] caseInsensitiveCompare:@"0°"] == NSOrderedSame)
			[(NSMutableDictionary *) tags setObject:@"Horizontal" forKey:@"Orientation"];
		
		if([[[self parameters] valueForKey:@"rotate"] caseInsensitiveCompare:@"Left 90°"] == NSOrderedSame)
			[(NSMutableDictionary *) tags setObject:@"Rotate 270 CW" forKey:@"Orientation"];
		
		if([[[self parameters] valueForKey:@"rotate"] caseInsensitiveCompare:@"Right 90°"] == NSOrderedSame)
			[(NSMutableDictionary *) tags setObject:@"Rotate 90 CW" forKey:@"Orientation"];
		
		if([[[self parameters] valueForKey:@"rotate"] caseInsensitiveCompare:@"180°"] == NSOrderedSame)
			[(NSMutableDictionary *) tags setObject:@"Rotate 180" forKey:@"Orientation"];
	}

	if([tags valueForKey:@"GPSImgDirection"] == nil)
		[(NSMutableDictionary *) tags setObject:[NSNull null] forKey:@"GPSImgDirection"];

	if([tags valueForKey:@"SubjectArea"] == nil)
		[(NSMutableDictionary *) tags setObject:[NSNull null] forKey:@"SubjectArea"];
	
    if([tags valueForKey:@"ThumbnailLength"] == nil)
        [(NSMutableDictionary *) tags setObject:[NSNull null] forKey:@"ThumbnailLength"];
    
    [(NSMutableDictionary *) tags setObject:[NSNumber numberWithBool:isVideo] forKey:@"OutputVideo"];
		
	NSDateFormatter* localDateFormatter = [[NSDateFormatter alloc] init];
	
	[localDateFormatter setDateFormat:@"yyyy/MM"];
	
	[(NSMutableDictionary *) tags setObject:[localDateFormatter stringFromDate:exifDate] forKey:@"OutputDirectoryPath"];
	[localDateFormatter setDateFormat:@"yyyyMMdd_HHmmss"];
	
	[(NSMutableDictionary *) tags setObject:[localDateFormatter stringFromDate:exifDate] forKey:@"OutputFormattedDate"];
	
	
	NSString *fullDirectoryPath = [NSString stringWithFormat:@"%@/%@", [[self parameters] valueForKey:@"archiveDirectory"], [tags valueForKey:@"OutputDirectoryPath"], nil];
	
	[(NSMutableDictionary *) tags setObject:fullDirectoryPath forKey:@"OutputProperFullDirectoryPath"];	

    NSString *outputVideoPath = [NSString stringWithFormat:@"%@/%@_%@.mp4", [tags valueForKey:@"OutputProperFullDirectoryPath"], [tags valueForKey:@"OutputFormattedDate"], [tags valueForKey:@"Model"]];
    
    
    [(NSMutableDictionary *) tags setObject:outputVideoPath forKey:@"OutputProperFullFilePath"];

    if(isVideo)
	{
		fullDirectoryPath = [NSString stringWithFormat:@"%@/original_video/%@", [[self parameters] valueForKey:@"archiveDirectory"], [tags valueForKey:@"OutputDirectoryPath"], nil];
	}
	
	[(NSMutableDictionary *) tags setObject:fullDirectoryPath forKey:@"OutputFullDirectoryPath"];	
	
	if([[[self parameters] valueForKey:@"renameFile"] boolValue])
	{
		if(offset == 0L)
		{
			if(isVideo)
				[(NSMutableDictionary *) tags setObject:[NSString stringWithFormat:@"%@/%@.%@", fullDirectoryPath, [[path lastPathComponent] stringByDeletingPathExtension], [path pathExtension]]  forKey:@"OutputFilePath"];
			
			else
				[(NSMutableDictionary *) tags setObject:[NSString stringWithFormat:@"%@/%@_%@.%@", [tags valueForKey:@"OutputFullDirectoryPath"], [tags valueForKey:@"OutputFormattedDate"], [tags valueForKey:@"Model"], [path pathExtension]] forKey:@"OutputFilePath"];
		}
		
		else
		{
			if(isVideo)
			{
				[(NSMutableDictionary *) tags setObject:[NSString stringWithFormat:@"%@/%@-%ld.%@", [tags valueForKey:@"OutputFullDirectoryPath"], [[path lastPathComponent] stringByDeletingPathExtension], offset, [path pathExtension]]  forKey:@"OutputFilePath"];
			}
			
			else
				[(NSMutableDictionary *) tags setObject:[NSString stringWithFormat:@"%@/%@_%@-%ld.%@", [tags valueForKey:@"OutputFullDirectoryPath"], [tags valueForKey:@"OutputFormattedDate"], [tags valueForKey:@"Model"], offset, [path pathExtension]] forKey:@"OutputFilePath"];
		}
	}
	
	else
	{
		if(offset == 0L)
		{
			[(NSMutableDictionary *) tags setObject:[NSString stringWithFormat:@"%@/%@.%@", fullDirectoryPath, [[path lastPathComponent] stringByDeletingPathExtension], [path pathExtension]]  forKey:@"OutputFilePath"];
		}
		
		else
		{
			[(NSMutableDictionary *) tags setObject:[NSString stringWithFormat:@"%@/%@-%ld.%@", [tags valueForKey:@"OutputFullDirectoryPath"], [[path lastPathComponent] stringByDeletingPathExtension], offset, [path pathExtension]]  forKey:@"OutputFilePath"];
		}
	}
}

//------------------------------------------------------
-(BOOL) tagsEqual:(NSDictionary *)firstTags withTags:(NSDictionary *) secondTags
{
	NSLog(@"Tag Count [%ld] = [%ld]", [firstTags count], [secondTags count]);

//	for(NSString* tag in [firstTags allKeys])
//	{
//		NSLog(@"Checking %@[%@] = %@[%@]", tag, [firstTags valueForKey:tag], tag, [secondTags valueForKey:tag]);
//	}
	
	for(NSString* tag in [firstTags allKeys])
	{
		if(([firstTags valueForKey:tag] != nil) && ([secondTags valueForKey:tag] == nil))
			NSLog(@"Found Missing Value In Check File %@[%@] = %@[%@]", tag, [firstTags valueForKey:tag], tag, [secondTags valueForKey:tag]);
	}

	for(NSString* tag in [secondTags allKeys])
	{
		if(([firstTags valueForKey:tag] == nil) && ([secondTags valueForKey:tag] != nil))
			NSLog(@"Found Missing Value In Image File %@[%@] = %@[%@]", tag, [firstTags valueForKey:tag], tag, [secondTags valueForKey:tag]);
	}

	if([firstTags count] != [secondTags count])
    {
		@throw [NSException exceptionWithName:@"error"
									   reason:@"Something is a miss"
									 userInfo:nil];
    }
	
	for(NSString* tag in [firstTags allKeys])
	{
//		NSLog(@"Comparing %@[%@] = %@[%@]", tag, [firstTags valueForKey:tag], tag, [secondTags valueForKey:tag]);
		
        if(![[firstTags valueForKey:tag] isEqual:[secondTags valueForKey:tag]]) {
            NSLog(@"Found Non-Equal Values for Tag %@[%@] != %@[%@]", tag, [firstTags valueForKey:tag], tag, [secondTags valueForKey:tag]);
            return(NO);
        }
	}
	
	return(YES);
}

@end

//------------------------------------------------------
@implementation NSDate (EXIFDate)

+ (NSDate*)dateFromEXIF:(NSString *)exifDate
{
	NSString *filteredDateString = [exifDate stringByReplacingOccurrencesOfString:@":" withString:@""];
	
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	NSTimeZone	*timeZone = nil;
	
	NSLog(@"Processing Date String: [%@]", exifDate);
	
	NSDateComponents *comps = [[NSDateComponents alloc] init];
	[comps setYear:[[filteredDateString substringWithRange:NSMakeRange(0, 4)] intValue]];
	[comps setMonth:[[filteredDateString substringWithRange:NSMakeRange(4, 2)] intValue]];
	[comps setDay:[[filteredDateString substringWithRange:NSMakeRange(6, 2)] intValue]];
	[comps setHour:[[filteredDateString substringWithRange:NSMakeRange(9, 2)] intValue]];
	[comps setMinute:[[filteredDateString substringWithRange:NSMakeRange(11, 2)] intValue]];
	[comps setSecond:[[filteredDateString substringWithRange:NSMakeRange(13, 2)] intValue]];
	
	if([filteredDateString length] > 15)
	{
		NSString *zoneString = [filteredDateString substringFromIndex:15];
		
		if([zoneString caseInsensitiveCompare:@"Z"] == NSOrderedSame)
			zoneString = @"GMT";
		
		NSLog(@"Found Zone String: [%@] for [%@]", zoneString, filteredDateString);
		
		timeZone = [NSTimeZone timeZoneWithAbbreviation:zoneString];

		if(timeZone == nil)
		{
			NSInteger zoneOffset = [[zoneString stringByReplacingOccurrencesOfString:@":" withString:@""] intValue];

			NSInteger minuteOffset = abs((int) zoneOffset) % 100;
			NSInteger hourOffset = zoneOffset / 100;
			
			NSInteger zoneOffsetSeconds = hourOffset * 60 * 60 + minuteOffset * 60;
			
			timeZone = [NSTimeZone timeZoneForSecondsFromGMT:zoneOffsetSeconds];

			NSLog(@"Found Offset Zone: [%@]", timeZone);
		}
	}
	
	if(timeZone == nil)
		timeZone = [NSTimeZone localTimeZone];
	
	[comps setTimeZone:timeZone];

	NSDate *date = [gregorian dateFromComponents:comps];
	
	NSInteger zoneOffsetSeconds = [timeZone secondsFromGMTForDate:date];
	timeZone = [NSTimeZone timeZoneForSecondsFromGMT:zoneOffsetSeconds];
	
	NSLog(@"Setting Time Zone: %@", timeZone);
	
	[comps setTimeZone:timeZone];
	
	date = [gregorian dateFromComponents:comps];
	
	
	return(date);
}

+ (NSString*)exifStringFromDate:(NSDate *)exifDate
{
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	NSDateComponents *comps = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit |NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit | NSTimeZoneCalendarUnit) fromDate:exifDate];

	
	NSTimeZone *timeZone = [comps timeZone];	
	NSInteger zoneOffsetSeconds = [timeZone secondsFromGMTForDate:exifDate];
	
	NSLog(@"%ld for %@", zoneOffsetSeconds, timeZone);
	
	NSString *timeZoneString = [NSString stringWithFormat:@"%@%02d:%02d", ((zoneOffsetSeconds < 0) ? @"-" : @"+"), abs((int) zoneOffsetSeconds) / 60 / 60, abs((int) zoneOffsetSeconds) / 60 % 60];
	
	NSLog(@"%@", timeZoneString);
	
	return([NSString stringWithFormat:@"%04ld:%02ld:%02ld %02ld:%02ld:%02ld%@", [comps year], [comps month], [comps day], [comps hour], [comps minute], [comps second], timeZoneString]);
}

@end