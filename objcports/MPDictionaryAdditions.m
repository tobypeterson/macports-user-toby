#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPDictionaryAdditions.h"
#include "MPStringAdditions.h"

@implementation NSDictionary (MPDictionaryAdditions)

- (id)initWithTclObjects:(Tcl_Obj * const *)objects count:(int)count
{
	int count2, i;
	NSDictionary *result;

	if ((count % 2) != 0) {
		return nil;
	}

	count2 = count / 2;

	NSString *keys[count2];
	NSString *objs[count2];
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
