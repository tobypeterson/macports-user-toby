#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPStringAdditions.h"

@implementation NSString (MPStringAdditions)

- (id)initWithTclObject:(Tcl_Obj *)object
{
	return [self initWithUTF8String:Tcl_GetString(object)];
}

@end
