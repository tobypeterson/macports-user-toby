#include <CoreFoundation/CoreFoundation.h>

#include "MPConfig.h"
#include "MPIndex.h"
#include "MPPort.h"
#include "internal.h"

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
	if (filename) {
		index = MPCopyPortIndex(filename);
		CFRelease(filename);
		if (index) {
			CFShow(index);
			CFRelease(index);
		}
	}
}

static void
do_info(int argc, char *argv[])
{
	while (--argc) {
		CFStringRef path;
		CFURLRef url;
		mp_port_t port;
		CFTypeRef tmp1, tmp2, tmp3;

		path = CFStringCreateWithCString(NULL, *++argv, kCFStringEncodingUTF8);
		url = CFURLCreateWithFileSystemPath(NULL, path, kCFURLPOSIXPathStyle, TRUE);
		port = mp_port_create(url, NULL);
		CFRelease(url);
		CFRelease(path);

		tmp1 = mp_port_variable(port, CFSTR("name"));
		tmp2 = mp_port_variable(port, CFSTR("version"));
		tmp3 = mp_port_variable(port, CFSTR("categories"));
		fprintf_cf(stdout, "%@ @%@ (%@)\n", tmp1, tmp2, tmp3);
		CFRelease(tmp1); CFRelease(tmp2); CFRelease(tmp3);

		tmp1 = mp_port_defined_variants(port);
		tmp2 = CFStringCreateByCombiningStrings(NULL, tmp1, CFSTR(", "));
		fprintf_cf(stdout, "Variants:             %@\n", tmp2);
		CFRelease(tmp1); CFRelease(tmp2);

		tmp1 = mp_port_defined_platforms(port);
		tmp2 = CFStringCreateByCombiningStrings(NULL, tmp1, CFSTR(", "));
		fprintf_cf(stdout, "PlatformVariants:     %@\n", tmp2);
		CFRelease(tmp1); CFRelease(tmp2);

		fprintf_cf(stdout, "\n");

		tmp1 = mp_port_variable(port, CFSTR("long_description"));
		fprintf_cf(stdout, "Description:          %@\n", tmp1);
		CFRelease(tmp1);
		
		tmp1 = mp_port_variable(port, CFSTR("homepage"));
		fprintf_cf(stdout, "Homepage:             %@\n", tmp1);
		CFRelease(tmp1);
		
		fprintf_cf(stdout, "\n");

		tmp1 = mp_port_variable(port, CFSTR("depends_build"));
		fprintf_cf(stdout, "Build Dependencies:   %@\n", tmp1);
		CFRelease(tmp1);
		
		tmp1 = mp_port_variable(port, CFSTR("depends_lib"));
		fprintf_cf(stdout, "Library Dependencies: %@\n", tmp1);
		CFRelease(tmp1);
		
		tmp1 = mp_port_variable(port, CFSTR("platforms"));
		fprintf_cf(stdout, "Platforms:            %@\n", tmp1);
		CFRelease(tmp1);

		tmp1 = mp_port_variable(port, CFSTR("license"));
		fprintf_cf(stdout, "License:              %@\n", tmp1);
		CFRelease(tmp1);

		tmp1 = mp_port_variable(port, CFSTR("maintainers"));
		fprintf_cf(stdout, "Maintainers:          %@\n", tmp1);
		CFRelease(tmp1);

		mp_port_destroy(port);
	}
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

	dispatch_main();
}
