#include <CoreFoundation/CoreFoundation.h>
#include <tcl.h>

#include "MPDictionaryAdditions.h"
#include "MPStringAdditions.h"

CFDictionaryRef
CFDictionaryCreateWithTclObjects(CFAllocatorRef allocator, Tcl_Obj **objects, CFIndex count)
{
	CFIndex count2, i;
	CFDictionaryRef result;

	if ((count % 2) != 0) {
		return nil;
	}

	count2 = count / 2;
	
	const void *keys[count2];
	const void *values[count2];
	for (i = 0; i < count2; i++) {
		keys[i] = CFStringCreateWithTclObject(allocator, objects[i * 2]);
		values[i] = CFStringCreateWithTclObject(allocator, objects[i * 2 + 1]);
	}
	result = CFDictionaryCreate(allocator, keys, values, count2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	for (i = 0; i < count2; i++) {
		CFRelease(keys[i]);
		CFRelease(values[i]);
	}
	return result;
}
