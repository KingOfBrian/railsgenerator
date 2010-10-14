/*******************************************************************************
	mogenerator.h - <http://github.com/rentzsch/mogenerator>
		Copyright (c) 2006-2009 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
		Some rights reserved: <http://opensource.org/licenses/mit-license.php>

	***************************************************************************/

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "MiscMergeTemplate.h"
#import "MiscMergeCommandBlock.h"
#import "MiscMergeEngine.h"
#import "FoundationAdditions.h"
#import "nsenumerate.h"
#import "NSString+MiscAdditions.h"
#import "DDCommandLineInterface.h"


@interface MOGeneratorApp : NSObject <DDCliApplicationDelegate> {
	NSString				*tempMOMPath;
	NSManagedObjectModel	*model;
	NSString				*baseClass;
	NSString				*includem;
	NSString				*templatePath;
	NSString				*outputDir;
	NSString				*machineDir;
	NSString				*humanDir;
	NSString				*templateGroup;
	BOOL					_help;
	BOOL					_version;
}

- (NSString*)appSupportFileNamed:(NSString*)fileName_;
- (NSString*)templateFileDirectory;
- (NSArray*)templateFiles;
@end