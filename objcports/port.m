#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPPort.h"

int
main(int argc, char *argv[])
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

	if (argc != 2)
		exit(1);

	MPPort *port = [[MPPort alloc] initWithPortfile:[NSString stringWithUTF8String:argv[1]] options:nil];
	NSLog(@"%@ @%@ (%@)", [port option:@"name"], [port option:@"version"], [port option:@"categories"]);
	NSLog(@"Variants:             %@", [[port variants] componentsJoinedByString:@", "]);
	NSLog(@"PlatformVariants:     %@", [[port platforms] componentsJoinedByString:@", "]);
	NSLog(@"Brief Description:    %@", [port option:@"description"]);
	NSLog(@"Description:          %@", [port option:@"long_description"]);
	NSLog(@"Homepage:             %@", [port option:@"homepage"]);
	NSLog(@"Build Dependencies:   %@", [port option:@"depends_build"]);
	NSLog(@"Library Dependencies: %@", [port option:@"depends_lib"]);
	NSLog(@"Platforms:            %@", [port option:@"platforms"]);
	NSLog(@"Maintainers:          %@", [port option:@"maintainers"]);

	[port release];

	[pool release];
	return 0;
}
