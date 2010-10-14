/*******************************************************************************
	mogenerator.m - <http://github.com/rentzsch/mogenerator>
		Copyright (c) 2006-2009 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
		Some rights reserved: <http://opensource.org/licenses/mit-license.php>

	***************************************************************************/

#import "mogenerator.h"

@implementation NSEntityDescription (customBaseClass)
/** @TypeInfo NSAttributeDescription */
- (NSArray*)noninheritedAttributes {
	NSEntityDescription *superentity = [self superentity];
	if (superentity) {
		NSMutableArray *result = [[[[self attributesByName] allValues] mutableCopy] autorelease];
		[result removeObjectsInArray:[[superentity attributesByName] allValues]];
		return result;
	} else {
		return [[self attributesByName] allValues];
	}
}
/** @TypeInfo NSAttributeDescription */
- (NSArray*)noninheritedRelationships {
	NSEntityDescription *superentity = [self superentity];
	if (superentity) {
		NSMutableArray *result = [[[[self relationshipsByName] allValues] mutableCopy] autorelease];
		[result removeObjectsInArray:[[superentity relationshipsByName] allValues]];
		return result;
	} else {
		return [[self relationshipsByName] allValues];
	}
}

@end

static MiscMergeEngine* engineWithTemplatePath(NSString *templatePath_) {
	MiscMergeTemplate *template = [[[MiscMergeTemplate alloc] init] autorelease];
	[template setStartDelimiter:@"<$" endDelimiter:@"$>"];
	[template parseContentsOfFile:templatePath_];
	
	return [[[MiscMergeEngine alloc] initWithTemplate:template] autorelease];
}

@implementation MOGeneratorApp

NSString *ApplicationSupportSubdirectoryName = @"mogenerator";
- (NSString*)appSupportFileNamed:(NSString*)fileName_ {
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDirectory;
	NSString *templateFileDirectory = [self templateFileDirectory];
	
	NSString *appSupportFile = [templateFileDirectory stringByAppendingPathComponent:fileName_];
	
	if ([fm fileExistsAtPath:appSupportFile isDirectory:&isDirectory] && !isDirectory) {
		return appSupportFile;
	}
	
	NSLog(@"appSupportFileNamed:@\"%@\": file not found", fileName_);
	exit(EXIT_FAILURE);
	return nil;
}

- (NSString*) templateFileDirectory {
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDirectory;
	
	if (templatePath) {
		if ([fm fileExistsAtPath:templatePath isDirectory:&isDirectory] && isDirectory) {
			return templatePath;
		}
	} else {
		NSArray *appSupportDirectories = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask+NSLocalDomainMask, YES);
		assert(appSupportDirectories);
		
		nsenumerate (appSupportDirectories, NSString*, appSupportDirectory) {
			if ([fm fileExistsAtPath:appSupportDirectory isDirectory:&isDirectory]) {
				NSString *appSupportSubdirectory = [appSupportDirectory stringByAppendingPathComponent:ApplicationSupportSubdirectoryName];
				if (templateGroup) {
					appSupportSubdirectory = [appSupportSubdirectory stringByAppendingPathComponent:templateGroup];
				}
				if ([fm fileExistsAtPath:appSupportSubdirectory isDirectory:&isDirectory] && isDirectory) {
					return appSupportSubdirectory;
				}
			}
		}
		
	}
	
	NSLog(@"templateFiles: Could not locate template files");
	exit(EXIT_FAILURE);
	return nil;
}


- (void) application: (DDCliApplication *) app
    willParseOptions: (DDGetoptLongParser *) optionsParser;
{
    [optionsParser setGetoptLongOnly: YES];
    DDGetoptOption optionTable[] = 
    {
		// Long             Short   Argument options
		{@"model",          'm',    DDGetoptRequiredArgument},
		{@"template-path",  0,      DDGetoptRequiredArgument},
		{@"output-dir",     'O',    DDGetoptRequiredArgument},
		
		{@"help",           'h',    DDGetoptNoArgument},
		{@"version",        0,      DDGetoptNoArgument},
		{nil,               0,      0},
    };
    [optionsParser addOptionsFromTable: optionTable];
}

- (void) printUsage;
{
    ddprintf(@"%@: Usage [OPTIONS] <argument> [...]\n", DDCliApp);
    printf("\n"
           "  -m, --model MODEL             Path to model\n"
           "      --template-path PATH      Path to templates\n"
           "  -O, --output-dir DIR          Output directory\n"
           "      --version                 Display version and exit\n"
           "  -h, --help                    Display this help and exit\n"
           "\n"
           "Spikes an initial implementation for a rails app from Core Data.\n"
           "Inspired by mogenerator/eogenerator.\n");
}

- (void) setModel: (NSString *) path;
{
    assert(!model); // Currently we only can load one model.

    if( ![[NSFileManager defaultManager] fileExistsAtPath:path]){
        NSString * reason = [NSString stringWithFormat: @"error loading file at %@: no such file exists", path];
        DDCliParseException * e = [DDCliParseException parseExceptionWithReason: reason
                                                                       exitCode: EX_NOINPUT];
        @throw e;
    }

    if ([[path pathExtension] isEqualToString:@"xcdatamodel"]) {
        //	We've been handed a .xcdatamodel data model, transparently compile it into a .mom managed object model.
        
        //  Find where Xcode installed momc this week.
        NSString *momc = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Developer/usr/bin/momc"]) { // Xcode 3.1 installs it here.
            momc = @"/Developer/usr/bin/momc";
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/Application Support/Apple/Developer Tools/Plug-ins/XDCoreDataModel.xdplugin/Contents/Resources/momc"]) { // Xcode 3.0.
            momc = @"/Library/Application Support/Apple/Developer Tools/Plug-ins/XDCoreDataModel.xdplugin/Contents/Resources/momc";
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Developer/Library/Xcode/Plug-ins/XDCoreDataModel.xdplugin/Contents/Resources/momc"]) { // Xcode 2.4.
            momc = @"/Developer/Library/Xcode/Plug-ins/XDCoreDataModel.xdplugin/Contents/Resources/momc";
        }
        assert(momc && "momc not found");
        
        tempMOMPath = [[NSTemporaryDirectory() stringByAppendingPathComponent:[(id)CFUUIDCreateString(kCFAllocatorDefault, CFUUIDCreate(kCFAllocatorDefault)) autorelease]] stringByAppendingPathExtension:@"mom"];
        system([[NSString stringWithFormat:@"\"%@\" \"%@\" \"%@\"", momc, path, tempMOMPath] UTF8String]); // Ignored system's result -- momc doesn't return any relevent error codes.
        path = tempMOMPath;
    }
    model = [[[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]] autorelease];
    assert(model);
}

- (int) application: (DDCliApplication *) app
   runWithArguments: (NSArray *) arguments;
{
    if (_help)
    {
        [self printUsage];
        return EXIT_SUCCESS;
    }
    
    if (outputDir == nil)
        outputDir = @".";
	else 
		NSLog(@"Output files to: %@", outputDir);
	
	NSFileManager *fm = [NSFileManager defaultManager];

	if (!model) {        
		NSLog(@"No Model found");
		return EXIT_FAILURE;
	}
	int entityCount = [[model entities] count];
	
	if(entityCount == 0) { 
		printf("No entities found in model. No files will be generated.\n");
		NSLog(@"the model description is %@.", model);
		return EXIT_FAILURE;
	}
	NSNumber *migrationCount = [NSNumber numberWithInt:0];
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
	NSString *timestamp = [dateFormatter stringFromDate:[NSDate date]];
	
	NSArray *entityTemplates = [NSArray arrayWithObjects:@"migration.rb.motemplate", @"model.rb.motemplate", nil];
	for (NSString *templateFile in entityTemplates) {
		MiscMergeEngine *engine = engineWithTemplatePath([self appSupportFileNamed:templateFile]);
		assert(engine);	
		[engine setGlobalValue:timestamp forKey:@"timestamp"];
		
		nsenumerate ([model entities], NSEntityDescription, entity) {
			[engine setGlobalValue:migrationCount forKey:@"migrationCount"];

			NSString *generated = [engine executeWithObject:entity sender:nil];
			
			NSString* filename      = [engine globalValueForKey:@"FILENAME"];
			NSString* directory     = [engine globalValueForKey:@"DIRECTORY"];

			[fm deepCreateDirectoryAtPath:directory attributes:nil];
			
			[generated writeToFile:[NSString stringWithFormat:@"%@/%@/%@",outputDir, directory, filename] 
						atomically:NO];
			
			migrationCount = [NSNumber numberWithInt:[migrationCount intValue] + 1];
		}
						   
	}
	MiscMergeEngine *engine = engineWithTemplatePath([self appSupportFileNamed:@"join_migration.rb.motemplate"]);
	[engine setGlobalValue:timestamp forKey:@"timpstamp"];

	// Create join tables
	NSMutableSet *joinRelationships = [NSMutableSet set];
	for (NSEntityDescription *entity in model) {
		for (NSRelationshipDescription *rel in [[entity relationshipsByName] allValues]) {
			NSRelationshipDescription *invRel = [rel inverseRelationship];
			if ([rel isToMany] && [invRel isToMany] &&
				(![joinRelationships containsObject:rel] && ![joinRelationships containsObject:invRel])) {
				[engine setGlobalValue:migrationCount forKey:@"migrationCount"];
				[engine setGlobalValue:timestamp forKey:@"timestamp"];
				
				NSString *generated = [engine executeWithObject:rel sender:nil];
				
				NSString* filename      = [engine globalValueForKey:@"FILENAME"];
				NSString* directory     = [engine globalValueForKey:@"DIRECTORY"];
				
				[fm deepCreateDirectoryAtPath:directory attributes:nil];
				[generated writeToFile:[NSString stringWithFormat:@"%@/%@/%@",outputDir, directory, filename] 			
							atomically:NO];				
				
				migrationCount = [NSNumber numberWithInt:[migrationCount intValue] + 1];
				[joinRelationships addObject:rel];
				[joinRelationships addObject:invRel];
			}
		}
	}
	
	if (tempMOMPath) {
		[fm removeFileAtPath:tempMOMPath handler:nil];
	}
	
    return EXIT_SUCCESS;
}

@end

int main (int argc, char * const * argv)
{
    return DDCliAppRunWithClass([MOGeneratorApp class]);
}
