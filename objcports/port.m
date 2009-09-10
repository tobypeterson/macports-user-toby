#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPIndex.h"
#include "MPPort.h"
#include "MPConfig.h"

int
main(int argc, char *argv[])
{
#if 0
	CFDictionaryRef config = MPCopyConfig();
	CFShow(config);
	CFRelease(config);
	return 0;
#endif

	if (argc < 2)
		exit(1);

#if 0
	CFStringRef filename = CFStringCreateWithCString(NULL, argv[1], kCFStringEncodingUTF8);
	CFDictionaryRef index = MPCopyPortIndex(filename);
	CFShow(index);
	CFRelease(index);
	CFRelease(filename);
	return 0;
#endif

	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
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
