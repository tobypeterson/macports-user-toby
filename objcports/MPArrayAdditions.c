#include <CoreFoundation/CoreFoundation.h>
#include <tcl.h>

#include "MPArrayAdditions.h"
#include "MPStringAdditions.h"

CFArrayRef
CFArrayCreateWithTclObjects(CFAllocatorRef allocator, Tcl_Obj * const *objects, CFIndex count)
{
	CFIndex i;
	CFStringRef array[count];
	CFArrayRef result;

	for (i = 0; i < count; i++) {
		array[i] = CFStringCreateWithTclObject(allocator, objects[i]);
	}
	result = CFArrayCreate(allocator, (const void **)array, count, &kCFTypeArrayCallBacks);
	for (i = 0; i < count; i++) {
		CFRelease(array[i]);
	}
	return result;
}
