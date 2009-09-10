#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPArrayAdditions.h"
#include "MPStringAdditions.h"

CFArrayRef
CFArrayCreateWithTclObjects(CFAllocatorRef allocator, Tcl_Obj **objects, CFIndex count)
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

@implementation NSArray (MPArrayAdditions)

- (id)initWithTclObjects:(Tcl_Obj * const *)objects count:(int)count
{
	int i;
	NSString *array[count];
	NSArray *result;
	for (i = 0; i < count; i++) {
		array[i] = [[NSString alloc] initWithTclObject:objects[i]];
	}
	result = [self initWithObjects:array count:count];
	for (i = 0; i < count; i++) {
		[array[i] release];
	}
	return result;
}

@end
