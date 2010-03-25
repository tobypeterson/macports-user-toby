#include <Foundation/Foundation.h>
#include <tcl.h>

#include "nstcl.h"

@implementation NSString (nstcl)

+ (id)stringWithTclObject:(Tcl_Obj *)object
{
	return [[[self alloc] initWithTclObject:object] autorelease];
}

- (id)initWithTclObject:(Tcl_Obj *)object
{
	return [self initWithUTF8String:Tcl_GetString(object)];
}

@end

@implementation NSArray (nstcl)

+ (id)arrayWithTclObjects:(Tcl_Obj **)objects count:(NSUInteger)count
{
	return [[[self alloc] initWithTclObjects:objects count:count] autorelease];
}

- (id)initWithTclObjects:(Tcl_Obj **)objects count:(NSUInteger)count
{
	NSUInteger i;
	id *array;
	id result;

	array = alloca(count * sizeof(id));

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

@implementation NSDictionary (nstcl)

+ (id)dictionaryWithTclObjects:(Tcl_Obj **)objects count:(NSUInteger)count
{
	return [[[self alloc] initWithTclObjects:objects count:count] autorelease];
}

- (id)initWithTclObjects:(Tcl_Obj **)objects count:(NSUInteger)count
{
	NSUInteger count2, i;
	id *keys, *objs;
	id result;

	if ((count % 2) != 0) {
		return nil;
	}

	count2 = count / 2;
	keys = alloca(count2 * sizeof(id));
	objs = alloca(count2 * sizeof(id));

	for (i = 0; i < count2; i++) {
		keys[i] = [[NSString alloc] initWithTclObject:objects[i * 2]];
		objs[i] = [[NSString alloc] initWithTclObject:objects[i * 2 + 1]];
	}
	result = [self initWithObjects:objs forKeys:keys count:count2];
	for (i = 0; i < count2; i++) {
		[keys[i] release];
		[objs[i] release];
	}

	return result;
}

@end
