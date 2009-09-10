#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPConfig.h"
#include "MPIndex.h"
#include "MPPort.h"

static void
do_showconfig()
{
	CFDictionaryRef config;

	config = MPCopyConfig();
	CFShow(config);
	CFRelease(config);
}

static void
do_showindex(char *f)
{
	CFStringRef filename;
	CFDictionaryRef index;

	filename = CFStringCreateWithCString(NULL, f, kCFStringEncodingUTF8);
	index = MPCopyPortIndex(filename);
	CFShow(index);
	CFRelease(index);
	CFRelease(filename);
}

static void
do_info(int argc, char *argv[])
{
	printf("%d\n", argc);
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
}

int
main(int argc, char *argv[])
{

	if (argc < 2)
		exit(1);

	if (!strcmp(argv[1], "showconfig")) {
		do_showconfig();
	} else {
		if (argc < 3)
			exit(1);

		if (!strcmp(argv[1], "showindex")) {
			do_showindex(argv[2]);
		} else {
			do_info(argc - 1, argv + 1);
		}
	}

	return 0;
}
