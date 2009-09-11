#include <CoreFoundation/CoreFoundation.h>
#include <tcl.h>

#include "cftcl.h"

CFStringRef
CFStringCreateWithTclObject(CFAllocatorRef allocator, Tcl_Obj *object)
{
	return CFStringCreateWithCString(allocator, Tcl_GetString(object), kCFStringEncodingUTF8);
}

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

CFDictionaryRef
CFDictionaryCreateWithTclObjects(CFAllocatorRef allocator, Tcl_Obj **objects, CFIndex count)
{
	CFIndex count2, i;
	CFDictionaryRef result;
	
	if ((count % 2) != 0) {
		return nil;
	}
	
	count2 = count / 2;
	
	CFStringRef keys[count2];
	CFStringRef values[count2];
	for (i = 0; i < count2; i++) {
		keys[i] = CFStringCreateWithTclObject(allocator, objects[i * 2]);
		values[i] = CFStringCreateWithTclObject(allocator, objects[i * 2 + 1]);
	}
	result = CFDictionaryCreate(allocator, (const void **)keys, (const void **)values, count2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	for (i = 0; i < count2; i++) {
		CFRelease(keys[i]);
		CFRelease(values[i]);
	}
	return result;
}
