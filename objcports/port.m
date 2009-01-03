#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPPort.h"

int
main(int argc, char *argv[])
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

	MPPort *port = [[MPPort alloc] initWithPortfile:[NSString stringWithUTF8String:argv[1]] options:nil];
	NSLog(@"%@ @%@ (%@)", [port option:@"name"], [port option:@"version"], [port option:@"categories"]);
	NSLog(@"Variants:     %@", [[port variants] componentsJoinedByString:@", "]);
	NSLog(@"PlatVariants: %@", [[port platforms] componentsJoinedByString:@", "]);
	NSLog(@"%@", [port option:@"long_description"]);
	NSLog(@"Homepage:             %@", [port option:@"homepage"]);
	NSLog(@"Platforms:            %@", [port option:@"platforms"]);
	NSLog(@"Maintainers:          %@", [port option:@"maintainers"]);

	[port release];

	[pool release];
	return 0;
}
