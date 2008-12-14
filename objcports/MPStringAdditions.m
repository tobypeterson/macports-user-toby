#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPStringAdditions.h"

@implementation NSString (MPStringAdditions)

+ (id)stringWithTclObject:(Tcl_Obj *)object
{
	return [[[self alloc] initWithTclObject:object] autorelease];
}

- (id)initWithTclObject:(Tcl_Obj *)object
{
	return [self initWithUTF8String:Tcl_GetString(object)];
}

@end
