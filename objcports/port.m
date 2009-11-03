#include <Foundation/Foundation.h>

#include "MPConfig.h"
#include "MPIndex.h"
#include "MPPort.h"

static void
do_showconfig()
{
	NSDictionary *config;

	config = (NSDictionary *)MPCopyConfig();
	if (config) {
		NSLog(@"%@", config);
		[config release];
	}
}

static void
do_showindex(char *f)
{
	NSDictionary *dict;

	dict = (NSDictionary *)MPCopyPortIndex((CFStringRef)[NSString stringWithUTF8String:f]);
	if (dict) {
		NSLog(@"%@", dict);
		[dict release];
	}
}

static void
do_info(int argc, char *argv[])
{
	while (--argc) {
		NSString *path;
		NSURL *url;
		mp_port_t port;
		id tmp1, tmp2, tmp3;

		path = [NSString stringWithUTF8String:*++argv];
		url = [NSURL fileURLWithPath:path isDirectory:YES];
		port = mp_port_create((CFURLRef)url, NULL);

 		tmp1 = [(id)mp_port_variable(port, (CFStringRef)@"name") autorelease];
		tmp2 = [(id)mp_port_variable(port, (CFStringRef)@"version") autorelease];
		tmp3 = [(id)mp_port_variable(port, (CFStringRef)@"categories") autorelease];
		fprintf(stdout, "%s @%s (%s)\n", [tmp1 UTF8String], [tmp2 UTF8String], [tmp3 UTF8String]);

		tmp1 = [(id)mp_port_defined_variants(port) autorelease];
		tmp2 = [tmp1 componentsJoinedByString:@", "];
		fprintf(stdout, "Variants:             %s\n", [tmp2 UTF8String]);

		tmp1 = [(id)mp_port_defined_platforms(port) autorelease];
		tmp2 = [tmp1 componentsJoinedByString:@", "];
		fprintf(stdout, "PlatformVariants:     %s\n", [tmp2 UTF8String]);

		fprintf(stdout, "\n");

		tmp1 = [(id)mp_port_variable(port, (CFStringRef)@"long_description") autorelease];
		fprintf(stdout, "Description:          %s\n", [tmp1 UTF8String]);
		
		tmp1 = [(id)mp_port_variable(port, (CFStringRef)@"homepage") autorelease];
		fprintf(stdout, "Homepage:             %s\n", [tmp1 UTF8String]);

		fprintf(stdout, "\n");

		tmp1 = [(id)mp_port_variable(port, (CFStringRef)@"depends_build") autorelease];
		fprintf(stdout, "Build Dependencies:   %s\n", [tmp1 UTF8String]);
		
		tmp1 = [(id)mp_port_variable(port, (CFStringRef)@"depends_lib") autorelease];
		fprintf(stdout, "Library Dependencies: %s\n", [tmp1 UTF8String]);
		
		tmp1 = [(id)mp_port_variable(port, (CFStringRef)@"platforms") autorelease];
		fprintf(stdout, "Platforms:            %s\n", [tmp1 UTF8String]);

		tmp1 = [(id)mp_port_variable(port, (CFStringRef)@"license") autorelease];
		fprintf(stdout, "License:              %s\n", [tmp1 UTF8String]);

		tmp1 = [(id)mp_port_variable(port, (CFStringRef)@"maintainers") autorelease];
		fprintf(stdout, "Maintainers:          %s\n", [tmp1 UTF8String]);

		mp_port_destroy(port);
	}
}

int
main(int argc, char *argv[])
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

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

	[pool drain];
	dispatch_main();
}
