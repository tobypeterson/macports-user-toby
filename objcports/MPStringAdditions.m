#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPStringAdditions.h"

CFStringRef
CFStringCreateWithTclObject(CFAllocatorRef allocator, Tcl_Obj *object)
{
	return CFStringCreateWithCString(allocator, Tcl_GetString(object), kCFStringEncodingUTF8);
}

@implementation NSString (MPStringAdditions)

- (id)initWithTclObject:(Tcl_Obj *)object
{
	return [self initWithUTF8String:Tcl_GetString(object)];
}

@end
