//
//  CoreData+Rails.m
//  RailsGenerator
//
//  Created by Brian King on 10/8/10.
//  Copyright 2010 King Software Design. All rights reserved.
//

#import "CoreData+Rails.h"
#import "NSString+InflectionSupport.h"

@implementation NSEntityDescription (RailsGenerator)

- (NSString*) railsClass {
	if ([self.userInfo objectForKey:@"railsName"]) {
		return [self.userInfo objectForKey:@"railsName"];
	} 
	return [self name];
}

- (NSString*) railsClassName {
	NSString *cstring = [self railsClass];
	NSString *cam = [cstring camelize];
	NSString *cap = [cam capitalize];
	return cap;
//	return [[[self railsClass] camelize] capitalizedString];
}
- (NSString*) railsClassNameUnderscore {
	return [[[self railsClass] decapitalize] underscore];
}
- (NSString*) railsTableName {
	return [NSString stringWithFormat:@"%@", [[self railsClassNameUnderscore] pluralize]];
}
@end

@implementation NSPropertyDescription (RailsGenerator)
- (NSString*) railsName {
	if ([self.userInfo objectForKey:@"railsName"]) {
		return [self.userInfo objectForKey:@"railsName"];
	}
	return [[self name] underscore];
}
- (BOOL) railsIgnore {
	return [self.userInfo objectForKey:@"railsIgnore"] != nil;
}

- (NSString*) railsMigrationString {
	return nil;
}
- (NSString*) railsModelString {
	return nil;
}
- (NSString*) railsMigrationIndexString {
	return nil;
}

@end

@implementation NSAttributeDescription (RailsGenerator)
- (NSString*) railsMigrationIndexString {
	if ([self isIndexed] && ![self railsIgnore]) {
		return [NSString stringWithFormat:@"add_index :%@, :%@", [[self entity] railsTableName], [self railsName]];
	}
	return nil;
}
- (NSString*) railsModelString {
	if ([self isTransient] || [self railsIgnore]) {
		return nil;
	}
	
	switch ([self attributeType]) {
		case NSUndefinedAttributeType:
		case NSInteger16AttributeType:
		case NSInteger32AttributeType:
		case NSInteger64AttributeType:
		case NSDecimalAttributeType:
		case NSDoubleAttributeType:
		case NSFloatAttributeType:
		case NSStringAttributeType:
		case NSBooleanAttributeType:
		case NSDateAttributeType:
			return [NSString stringWithFormat:@"attr_accessible :%@", [self railsName]];
		case NSBinaryDataAttributeType:
		case NSTransformableAttributeType:
//		case NSObjectIDAttributeType:
			break;
	}
	return nil;
}
- (NSString*) railsMigrationString {
	if ([self isTransient] || [self railsIgnore]) {
		return nil;
	}
	switch ([self attributeType]) {
		case NSUndefinedAttributeType:
		case NSInteger16AttributeType:
		case NSInteger32AttributeType:
		case NSInteger64AttributeType:
			return [NSString stringWithFormat:@"t.integer :%@", [self railsName]];
		case NSDecimalAttributeType:
		case NSDoubleAttributeType:
		case NSFloatAttributeType:
			return [NSString stringWithFormat:@"t.float :%@", [self railsName]];
		case NSStringAttributeType:
			return [NSString stringWithFormat:@"t.string :%@", [self railsName]];
		case NSBooleanAttributeType:
			return [NSString stringWithFormat:@"t.boolean :%@", [self railsName]];
		case NSDateAttributeType:
			return [NSString stringWithFormat:@"t.date :%@", [self railsName]];
		case NSBinaryDataAttributeType:
		case NSTransformableAttributeType:
//		case NSObjectIDAttributeType:
			NSLog(@"Igoring type %d", [self attributeType]);
	}
	return nil;
}

@end


@implementation NSRelationshipDescription (RailsGenerator)
- (BOOL) railsBelongsTo {
	return [self.userInfo objectForKey:@"belongsTo"] != nil;
}
- (NSString*) railsMigrationIndexString {
	NSRelationshipDescription *inverseRelationship = [self inverseRelationship];
	if (![self isToMany] && [inverseRelationship isToMany]) {
		return [NSString stringWithFormat:@"add_index :%@, :%@_id", [[self entity] railsTableName], [self railsName]];		
	} else if (![self isToMany] && [self railsBelongsTo]) {
		return [NSString stringWithFormat:@"add_index :%@, :%@_id", [[self entity] railsTableName], [self railsName]];		
	}
	return nil;
}

- (NSString*) railsMigrationString {
	if ([self railsIgnore]) {
		return nil;
	}
	NSRelationshipDescription *inverseRelationship = [self inverseRelationship];
	if ([self isToMany]) {
		if ([inverseRelationship isToMany]) {
			// defined in join table
		} else {
			// reference held on other side
		}
	} else {
		if ([inverseRelationship isToMany]) {
			return [NSString stringWithFormat:@"t.references :%@", [self railsName]];			
		} else if ([self railsBelongsTo]) {
			return [NSString stringWithFormat:@"t.references :%@", [self railsName]];			
		} else if ([inverseRelationship railsBelongsTo]) {
			// Other side holds reference
		} else {
			// Error
		}
	}
	return nil;
}
- (NSString*) railsModelString {
	if ([self railsIgnore]) {
		return nil;
	}
	NSRelationshipDescription *inverseRelationship = [self inverseRelationship];
	NSEntityDescription       *inverseEntity =       [self destinationEntity];
	
	NSString *remoteEntityCapital = [inverseEntity railsClassName];
	NSString *remoteEntityUnder   = [inverseEntity railsClassNameUnderscore];
	NSString *fieldName           = [self  railsName];
	
	// Determine if remoteEntityName and fieldName match. 
	// Foo.bars and entity Bar have matching class convention (ie ignore plurality)
	NSRange compareRange = NSMakeRange(0, [remoteEntityUnder length]);
	BOOL classMatchesConvention = [fieldName compare:remoteEntityUnder
											 options:NSLiteralSearch 
											   range:compareRange] == NSOrderedSame;
	
	NSMutableString *tailDeclaration = [NSMutableString stringWithFormat:@":%@", fieldName];
	
	if (!classMatchesConvention) [tailDeclaration appendFormat:@", :class_name => \"%@\"", remoteEntityCapital];
	if ([self deleteRule] == NSNullifyDeleteRule &&
		// Ignore nullify for belongs_to
		!(![self isToMany] && ([inverseRelationship isToMany] || [self railsBelongsTo]))) {
		[tailDeclaration appendFormat:@", :dependent => :nullify"];
	} else if ([self deleteRule] == NSCascadeDeleteRule) {
		[tailDeclaration appendFormat:@", :dependent => :destroy"];
	}
	
	if ([self isToMany]) {
		if ([inverseRelationship isToMany]) {
			return [NSString stringWithFormat:@"has_and_belongs_to_many %@", tailDeclaration];
		} else {
			return [NSString stringWithFormat:@"has_many %@", tailDeclaration];
		}
	} else {
		if ([inverseRelationship isToMany]) {
			return [NSString stringWithFormat:@"belongs_to %@", tailDeclaration];
		} else if ([self railsBelongsTo]) {
			return [NSString stringWithFormat:@"belongs_to %@", tailDeclaration];
		} else if ([inverseRelationship railsBelongsTo]) {
			return [NSString stringWithFormat:@"has_one %@", tailDeclaration];
		} else {
			//			NSLog(@"Must declare belongs_to in userInfo on one side of one-one relationship");
		}
	}
	return nil;
}
@end

