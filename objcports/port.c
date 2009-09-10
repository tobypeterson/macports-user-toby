#include <CoreFoundation/CoreFoundation.h>
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
	while (--argc) {
		CFStringRef path;
		CFURLRef url;
		mp_port_t port;
		CFStringRef tmp;

		path = CFStringCreateWithCString(NULL, *++argv, kCFStringEncodingUTF8);
		url = CFURLCreateWithFileSystemPath(NULL, path, kCFURLPOSIXPathStyle, TRUE);
		port = mp_port_create(url, NULL);
		fprintf_cf(stdout, CFSTR("%@ @%@ (%@)\n"), mp_port_variable(port, CFSTR("name")), mp_port_variable(port, CFSTR("version")), mp_port_variable(port, CFSTR("categories")));
		tmp = CFStringCreateByCombiningStrings(NULL, mp_port_defined_variants(port), CFSTR(", "));
		fprintf_cf(stdout, CFSTR("Variants:             %@\n"), tmp);
		tmp = CFStringCreateByCombiningStrings(NULL, mp_port_defined_platforms(port), CFSTR(", "));
		fprintf_cf(stdout, CFSTR("PlatformVariants:     %@\n"), tmp);
		fprintf_cf(stdout, CFSTR("Brief Description:    %@\n"), mp_port_variable(port, CFSTR("description")));
		fprintf_cf(stdout, CFSTR("Description:          %@\n"), mp_port_variable(port, CFSTR("long_description")));
		fprintf_cf(stdout, CFSTR("Homepage:             %@\n"), mp_port_variable(port, CFSTR("homepage")));
		fprintf_cf(stdout, CFSTR("Build Dependencies:   %@\n"), mp_port_variable(port, CFSTR("depends_build")));
		fprintf_cf(stdout, CFSTR("Library Dependencies: %@\n"), mp_port_variable(port, CFSTR("depends_lib")));
		fprintf_cf(stdout, CFSTR("Platforms:            %@\n"), mp_port_variable(port, CFSTR("platforms")));
		fprintf_cf(stdout, CFSTR("Maintainers:          %@\n"), mp_port_variable(port, CFSTR("maintainers")));
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

	pause();
	return 0;
}
