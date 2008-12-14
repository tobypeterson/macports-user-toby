#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPArrayAdditions.h"
#include "MPStringAdditions.h"

@implementation NSArray (MPArrayAdditions)

+ (id)arrayWithTclObjects:(Tcl_Obj * const *)objects count:(int)count
{
	return [[[self alloc] initWithTclObjects:objects count:count] autorelease];
}

- (id)initWithTclObjects:(Tcl_Obj * const *)objects count:(int)count;
{
	int i;
	NSString *array[count];
	for (i = 0; i < count; i++) {
		array[i] = [NSString stringWithTclObject:objects[i]];
	}
	return [self initWithObjects:array count:count];
}

@end
