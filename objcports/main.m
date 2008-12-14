#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPParser.h"

int
main(int argc, char *argv[])
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

	MPParser *port = [[MPParser alloc] initWithPortfile:[NSString stringWithUTF8String:argv[1]]];
	[port release];

	[pool release];
	return 0;
}
