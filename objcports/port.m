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
	NSLog(@"%@ @%@ (%@)", [port variable:@"name"], [port variable:@"version"], [port variable:@"categories"]);
	NSLog(@"Variants:             %@", [[port variants] componentsJoinedByString:@", "]);
	NSLog(@"PlatformVariants:     %@", [[port platforms] componentsJoinedByString:@", "]);
	NSLog(@"Brief Description:    %@", [port variable:@"description"]);
	NSLog(@"Description:          %@", [port variable:@"long_description"]);
	NSLog(@"Homepage:             %@", [port variable:@"homepage"]);
	NSLog(@"Build Dependencies:   %@", [port variable:@"depends_build"]);
	NSLog(@"Library Dependencies: %@", [port variable:@"depends_lib"]);
	NSLog(@"Platforms:            %@", [port variable:@"platforms"]);
	NSLog(@"Maintainers:          %@", [port variable:@"maintainers"]);

	[port release];

	[pool release];
	return 0;
}
