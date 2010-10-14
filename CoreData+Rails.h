//
//  CoreData+Rails.h
//  RailsGenerator
//
//  Created by Brian King on 10/8/10.
//  Copyright 2010 King Software Design. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSEntityDescription (RailsGenerator)
- (NSString*) railsClassName;
- (NSString*) railsClassNameUnderscore;
- (NSString*) railsTableName;
@end

@interface NSPropertyDescription (RailsGenerator)
- (NSString*) railsName;
- (BOOL) railsIgnore;

// These are implemented by subclasses
- (NSString*) railsMigrationString;
- (NSString*) railsMigrationIndexString;
- (NSString*) railsModelString;

@end

@interface NSRelationshipDescription (RailsGenerator)
- (BOOL) railsBelongsTo;
@end

