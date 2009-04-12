#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPIndex.h"
#include "MPPort.h"

int
main(int argc, char *argv[])
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

	if (argc < 2)
		exit(1);

#if 0
	NSString *filename = [[NSString alloc] initWithUTF8String:argv[1]];
	MPIndex *index = [[MPIndex alloc] initWithPortindex:filename];
	[filename release];
	// do stuff
	[index release];
	return 0;
#endif

	while (--argc) {
		MPPort *port = [[MPPort alloc] initWithPath:[NSString stringWithUTF8String:*++argv] options:nil];
		NSLog(@"%@ @%@ (%@)", [port variable:@"name"], [port variable:@"version"], [port variable:@"categories"]);
		NSLog(@"Variants:             %@", [[port definedVariants] componentsJoinedByString:@", "]);
		NSLog(@"PlatformVariants:     %@", [[port definedPlatforms] componentsJoinedByString:@", "]);
		NSLog(@"Brief Description:    %@", [port variable:@"description"]);
		NSLog(@"Description:          %@", [port variable:@"long_description"]);
		NSLog(@"Homepage:             %@", [port variable:@"homepage"]);
		NSLog(@"Build Dependencies:   %@", [port variable:@"depends_build"]);
		NSLog(@"Library Dependencies: %@", [port variable:@"depends_lib"]);
		NSLog(@"Platforms:            %@", [port variable:@"platforms"]);
		NSLog(@"Maintainers:          %@", [port variable:@"maintainers"]);
		[port release];
	}

	[pool release];
	return 0;
}
