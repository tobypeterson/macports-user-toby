#include <Foundation/Foundation.h>
#include <tcl.h>
#include <sys/utsname.h>

#include "MPPort.h"
#include "MPParser.h"

@implementation MPPort

- (id)initWithPortfile:(NSString *)portfile options:(NSDictionary *)options
{
	self = [super init];
	_portfile = [portfile retain];

	_platforms = [[NSMutableArray alloc] initWithCapacity:0];
	_variants = [[NSMutableDictionary alloc] initWithCapacity:0];

	_options = [[NSMutableDictionary alloc] initWithCapacity:0];
	[_options setObject:@"/opt/local" forKey:@"prefix"]; // portmain.tcl
	[_options setObject:@"" forKey:@"name"]; // portmain.tcl
	[_options setObject:@"" forKey:@"version"]; // portmain.tcl
	[_options setObject:@"0" forKey:@"revision"]; // portmain.tcl
	[_options setObject:@"0" forKey:@"epoch"]; // portmain.tcl
	[_options setObject:@"" forKey:@"categories"]; // portmain.tcl
	[_options setObject:@"" forKey:@"maintainers"]; // portmain.tcl
	[_options setObject:@"" forKey:@"long_description"]; // portmain.tcl
	[_options setObject:@"" forKey:@"description"]; // portmain.tcl
	[_options setObject:@"" forKey:@"homepage"]; // portmain.tcl
	[_options setObject:@"" forKey:@"worksrcdir"]; // portmain.tcl
	[_options setObject:@"" forKey:@"filesdir"]; // portmain.tcl
	[_options setObject:@"" forKey:@"distname"]; // portmain.tcl
	[_options setObject:@"" forKey:@"portdbpath"]; // portmain.tcl
	[_options setObject:@"" forKey:@"libpath"]; // portmain.tcl
	[_options setObject:@"" forKey:@"distpath"]; // portmain.tcl
	[_options setObject:@"" forKey:@"sources_conf"]; // portmain.tcl
	[_options setObject:@"" forKey:@"os.platform"]; // portmain.tcl
	[_options setObject:@"" forKey:@"os.version"]; // portmain.tcl
	[_options setObject:@"" forKey:@"os.major"]; // portmain.tcl
	[_options setObject:@"" forKey:@"os.arch"]; // portmain.tcl
	[_options setObject:@"" forKey:@"os.endian"]; // portmain.tcl
	[_options setObject:@"" forKey:@"platforms"]; // portmain.tcl
	[_options setObject:@"" forKey:@"default_variants"]; // portmain.tcl
	[_options setObject:@"" forKey:@"install.user"]; // portmain.tcl
	[_options setObject:@"" forKey:@"install.group"]; // portmain.tcl
	[_options setObject:@"" forKey:@"macosx_deployment_target"]; // portmain.tcl
	[_options setObject:@"" forKey:@"universal_variant"]; // portmain.tcl
	[_options setObject:@"" forKey:@"os.universal_supported"]; // portmain.tcl
	[_options setObject:@"" forKey:@"master_sites"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"patch_sites"]; // portfetch.tcl
	[_options setObject:@".tar.gz" forKey:@"extract.suffix"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"distfiles"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"patchfiles"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"use_zip"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"use_bzip2"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"use_lzma"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"use_dmg"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"dist_subdir"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"fetch.type"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"fetch.user"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"fetch.password"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"fetch.use_epsv"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"fetch.ignore_sslcert"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"master_sites.mirror_subdir"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"patch_sites.mirror_subdir"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"portname"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"cvs.module"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"cvs.root"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"cvs.password"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"cvs.date"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"cvs.tag"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"cvs.method"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"svn.url"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"svn.tag"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"svn.method"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"git.url"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"git.branch"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"hg.url"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"hg.tag"]; // portfetch.tcl
	[_options setObject:@"" forKey:@"build.target"]; // portbuild.tcl
	[_options setObject:@"" forKey:@"build.nice"]; // portbuild.tcl
	[_options setObject:@"" forKey:@"build.jobs"]; // portbuild.tcl
	[_options setObject:@"" forKey:@"use_parallel_build"];
	[_options setObject:@"" forKey:@"checksums"];
	[_options setObject:@"" forKey:@"patchfiles"];
	[_options setObject:@"" forKey:@"depends_run"];
	[_options setObject:@"" forKey:@"depends_build"];
	[_options setObject:@"" forKey:@"depends_lib"];
	[_options setObject:@"" forKey:@"universal_variant"];
	[_options setObject:@"" forKey:@"build.target"];
	[_options setObject:@"" forKey:@"destroot.destdir"];
	[_options setObject:@"" forKey:@"livecheck.check"];
	[_options setObject:@"" forKey:@"livecheck.url"];
	[_options setObject:@"" forKey:@"livecheck.regex"];
	[_options setObject:@"" forKey:@"livecheck.distname"];
	[_options setObject:@"" forKey:@"test.run"]; // porttest.tcl
	[_options setObject:@"test" forKey:@"test.target"]; // porttest.tcl
	[_options setObject:@"" forKey:@"configure.compiler"];

	NSArray *commands = [NSArray arrayWithObjects:
		@"cvs", // portfetch.tcl
		@"svn", // portfetch.tcl
		@"extract", // portextract.tcl
		@"patch", // portpatch.tcl
		@"configure", // portconfigure.tcl
		@"autoreconf", // portconfigure.tcl
		@"automake", // portconfigure.tcl
		@"autoconf", // portconfigure.tcl
		@"xmkmf", // portconfigure.tcl
		@"build", // portbuild.tcl
		@"parallel_build", // portbuild.tcl
		@"test", // porttest.tcl
		@"destroot", // portdestroot.tcl
		nil];

	// essentially 'commands' from portutil.tcl
	for (NSString *command in commands) {
		[_options setObject:@"" forKey:[NSString stringWithFormat:@"use_%@", command]];
		[_options setObject:@"" forKey:[NSString stringWithFormat:@"%@.dir", command]];
		[_options setObject:@"" forKey:[NSString stringWithFormat:@"%@.pre_args", command]];
		[_options setObject:@"" forKey:[NSString stringWithFormat:@"%@.args", command]];
		[_options setObject:@"" forKey:[NSString stringWithFormat:@"%@.post_args", command]];
		[_options setObject:@"" forKey:[NSString stringWithFormat:@"%@.env", command]];
		[_options setObject:@"" forKey:[NSString stringWithFormat:@"%@.type", command]];
		[_options setObject:@"" forKey:[NSString stringWithFormat:@"%@.cmd", command]];
	}

	_constants = [[NSMutableDictionary alloc] initWithCapacity:0];
	[_constants setObject:@"XXX" forKey:@"worksrcpath"]; // portmain.tcl
	[_constants setObject:@"XXX" forKey:@"destroot"];

	_parser = [[MPParser alloc] initWithPort:self];

	return self;
}

- (void)dealloc
{
	[_parser release];
	[_portfile release];

	[_options release];
	[_constants release];

	[_platforms release];
	[_variants release];

	[super dealloc];
}

- (NSString *)portfile
{
	return _portfile;
}

- (NSArray *)targets
{
	return [NSArray arrayWithObjects:
		@"fetch",
		@"extract",
		@"patch",
		@"configure",
		@"build",
		@"destroot",
		nil];
}

- (BOOL)isTarget:(NSString *)target
{
	if ([target hasPrefix:@"pre-"]) {
		target = [target substringWithRange:NSMakeRange(4, [target length] - 4)];
	} else if ([target hasPrefix:@"post-"]) {
		target = [target substringWithRange:NSMakeRange(5, [target length] - 5)];
	}

	return [[self targets] containsObject:target];
}

- (NSArray *)variables
{
	return [[_options allKeys] arrayByAddingObjectsFromArray:[_constants allKeys]];
}

- (NSString *)variable:(NSString *)name
{
	NSString *ret;
	ret = [_options objectForKey:name];
	if (ret == nil) {
		ret = [_constants objectForKey:name];
	}
	return ret;
}

- (NSArray *)options
{
	return [_options allKeys];
}

- (void)option:(NSString *)option set:(NSArray *)value
{
	[_options setObject:[value componentsJoinedByString:@" "] forKey:option];
}

- (void)option:(NSString *)option append:(NSArray *)value
{
	[_options setObject:[NSString stringWithFormat:@"%@ %@", [_options objectForKey:option], [value componentsJoinedByString:@" "]] forKey:option];
}

- (void)option:(NSString *)option delete:(NSArray *)value
{
	NSMutableArray *tmp = [[[_options objectForKey:option] componentsSeparatedByString:@" "] mutableCopy];
	for (NSString *v in value) {
		[tmp removeObject:v];
	}
	[_options setObject:[tmp componentsJoinedByString:@" "] forKey:option];
	[tmp release];
}

- (BOOL)addPlatform:(NSArray *)platform
{
	struct utsname u;
	NSString *os;
	NSNumber *release;
	NSString *arch;
	id tmp;

	[_platforms addObject:platform];

	assert(uname(&u) == 0);
	os = [[NSString stringWithUTF8String:u.sysname] lowercaseString];
	release = [NSNumber numberWithInteger:[[NSString stringWithUTF8String:u.release] integerValue]];
	arch = [NSString stringWithUTF8String:u.machine];

	tmp = [platform objectAtIndex:0];
	if (tmp != [NSNull null] && ![tmp isEqualToString:os]) {
		return NO;
	}

	tmp = [platform objectAtIndex:1];
	if (tmp != [NSNull null] && ![tmp isEqual:release]) {
		return NO;
	}

	tmp = [platform objectAtIndex:2];
	if (tmp != [NSNull null] && ![tmp isEqual:arch]) {
		return NO;
	}

	return YES;
}

- (NSArray *)platforms
{
	return _platforms;
}

- (BOOL)addVariant:(NSString *)variant properties:(NSDictionary *)props
{
	// XXX: check for dupes (w/ platforms too)
	[_variants setObject:props forKey:variant];
	// XXX: make sure it's set, like platforms just pretend
	return YES;
}

- (NSArray *)variants
{
	return [_variants allKeys];
}

@end
