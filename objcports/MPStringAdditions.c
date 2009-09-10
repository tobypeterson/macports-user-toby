#include <CoreFoundation/CoreFoundation.h>
#include <tcl.h>

#include "MPStringAdditions.h"

CFStringRef
CFStringCreateWithTclObject(CFAllocatorRef allocator, Tcl_Obj *object)
{
	return CFStringCreateWithCString(allocator, Tcl_GetString(object), kCFStringEncodingUTF8);
}
