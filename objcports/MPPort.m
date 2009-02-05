#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPPort.h"
#include "MPParser.h"

@interface MPPort (priv)
- (void)addCommand:(NSString *)command;
@end

@implementation MPPort

- (id)initWithPortfile:(NSString *)portfile options:(NSDictionary *)options
{
	self = [super init];
	_portfile = [portfile retain];

	_procs = [[NSMutableArray alloc] initWithCapacity:0];
	[_procs addObject:@"variant_isset"];
	[_procs addObject:@"strsed"];

	_targets = [[NSMutableArray alloc] initWithCapacity:0];
	[_targets addObject:@"fetch"];
	[_targets addObject:@"extract"];
	[_targets addObject:@"patch"];
	[_targets addObject:@"configure"];
	[_targets addObject:@"build"];
	[_targets addObject:@"destroot"];

	[self addCommand:@"cvs"]; // portfetch.tcl
	[self addCommand:@"svn"]; // portfetch.tcl
	[self addCommand:@"extract"]; // portextract.tcl
	[self addCommand:@"patch"]; // portpatch.tcl
	[self addCommand:@"configure"]; // portconfigure.tcl
	[self addCommand:@"autoreconf"]; // portconfigure.tcl
	[self addCommand:@"automake"]; // portconfigure.tcl
	[self addCommand:@"autoconf"]; // portconfigure.tcl
	[self addCommand:@"xmkmf"]; // portconfigure.tcl
	[self addCommand:@"build"]; // portbuild.tcl
	[self addCommand:@"parallel_build"]; // portbuild.tcl
	[self addCommand:@"test"]; // porttest.tcl
	[self addCommand:@"destroot"]; // portdestroot.tcl

	_options = [[NSMutableArray alloc] initWithCapacity:0];
	[_options addObject:@"prefix"]; // portmain.tcl
	[_options addObject:@"name"]; // portmain.tcl
	[_options addObject:@"version"]; // portmain.tcl
	[_options addObject:@"revision"]; // portmain.tcl
	[_options addObject:@"epoch"]; // portmain.tcl
	[_options addObject:@"categories"]; // portmain.tcl
	[_options addObject:@"maintainers"]; // portmain.tcl
	[_options addObject:@"long_description"]; // portmain.tcl
	[_options addObject:@"description"]; // portmain.tcl
	[_options addObject:@"homepage"]; // portmain.tcl
	[_options addObject:@"worksrcdir"]; // portmain.tcl
	[_options addObject:@"filesdir"]; // portmain.tcl
	[_options addObject:@"distname"]; // portmain.tcl
	[_options addObject:@"portdbpath"]; // portmain.tcl
	[_options addObject:@"libpath"]; // portmain.tcl
	[_options addObject:@"distpath"]; // portmain.tcl
	[_options addObject:@"sources_conf"]; // portmain.tcl
	[_options addObject:@"os.platform"]; // portmain.tcl
	[_options addObject:@"os.version"]; // portmain.tcl
	[_options addObject:@"os.major"]; // portmain.tcl
	[_options addObject:@"os.arch"]; // portmain.tcl
	[_options addObject:@"os.endian"]; // portmain.tcl
	[_options addObject:@"platforms"]; // portmain.tcl
	[_options addObject:@"default_variants"]; // portmain.tcl
	[_options addObject:@"install.user"]; // portmain.tcl
	[_options addObject:@"install.group"]; // portmain.tcl
	[_options addObject:@"macosx_deployment_target"]; // portmain.tcl
	[_options addObject:@"universal_variant"]; // portmain.tcl
	[_options addObject:@"os.universal_supported"]; // portmain.tcl
	
	[_options addObject:@"master_sites"]; // portfetch.tcl
	[_options addObject:@"patch_sites"]; // portfetch.tcl
	[_options addObject:@"extract.suffix"]; // portfetch.tcl
	[_options addObject:@"distfiles"]; // portfetch.tcl
	[_options addObject:@"patchfiles"]; // portfetch.tcl
	[_options addObject:@"use_zip"]; // portfetch.tcl
	[_options addObject:@"use_bzip2"]; // portfetch.tcl
	[_options addObject:@"use_lzma"]; // portfetch.tcl
	[_options addObject:@"use_dmg"]; // portfetch.tcl
	[_options addObject:@"dist_subdir"]; // portfetch.tcl
	[_options addObject:@"fetch.type"]; // portfetch.tcl
	[_options addObject:@"fetch.user"]; // portfetch.tcl
	[_options addObject:@"fetch.password"]; // portfetch.tcl
	[_options addObject:@"fetch.use_epsv"]; // portfetch.tcl
	[_options addObject:@"fetch.ignore_sslcert"]; // portfetch.tcl
	[_options addObject:@"master_sites.mirror_subdir"]; // portfetch.tcl
	[_options addObject:@"patch_sites.mirror_subdir"]; // portfetch.tcl
	[_options addObject:@"portname"]; // portfetch.tcl
	[_options addObject:@"cvs.module"]; // portfetch.tcl
	[_options addObject:@"cvs.root"]; // portfetch.tcl
	[_options addObject:@"cvs.password"]; // portfetch.tcl
	[_options addObject:@"cvs.date"]; // portfetch.tcl
	[_options addObject:@"cvs.tag"]; // portfetch.tcl
	[_options addObject:@"cvs.method"]; // portfetch.tcl
	[_options addObject:@"svn.url"]; // portfetch.tcl
	[_options addObject:@"svn.tag"]; // portfetch.tcl
	[_options addObject:@"svn.method"]; // portfetch.tcl
	[_options addObject:@"git.url"]; // portfetch.tcl
	[_options addObject:@"git.branch"]; // portfetch.tcl
	[_options addObject:@"hg.url"]; // portfetch.tcl
	[_options addObject:@"hg.tag"]; // portfetch.tcl
	[_options addObject:@"build.target"]; // portbuild.tcl
	[_options addObject:@"build.nice"]; // portbuild.tcl
	[_options addObject:@"build.jobs"]; // portbuild.tcl
	[_options addObject:@"use_parallel_build"];
	[_options addObject:@"checksums"];
	[_options addObject:@"patchfiles"];
	[_options addObject:@"depends_run"];
	[_options addObject:@"depends_build"];
	[_options addObject:@"depends_lib"];
	[_options addObject:@"universal_variant"];
	[_options addObject:@"build.target"];
	[_options addObject:@"destroot.destdir"];
	[_options addObject:@"livecheck.check"];
	[_options addObject:@"livecheck.url"];
	[_options addObject:@"livecheck.regex"];
	[_options addObject:@"livecheck.distname"];
	[_options addObject:@"test.run"]; // porttest.tcl
	[_options addObject:@"test.target"]; // porttest.tcl

	// *some* overlap with options
	_defaults = [[NSMutableDictionary alloc] initWithCapacity:0];
	[_defaults setObject:@"XXX" forKey:@"distpath"]; // portmain.tcl
	[_defaults setObject:@"XXX" forKey:@"workpath"]; // portmain.tcl
	[_defaults setObject:@"XXX" forKey:@"worksymlink"]; // portmain.tcl
	[_defaults setObject:@"/opt/local" forKey:@"prefix"]; // portmain.tcl
	[_defaults setObject:@"/usr/X11R6" forKey:@"x11prefix"]; // portmain.tcl
	[_defaults setObject:@"/Applications/MacPorts" forKey:@"applications_dir"]; // portmain.tcl
	[_defaults setObject:@"${prefix}/Library/Frameworks" forKey:@"frameworks_dir"]; // portmain.tcl
	[_defaults setObject:@"destroot" forKey:@"destdir"]; // portmain.tcl
	[_defaults setObject:@"${workpath}/${destdir}" forKey:@"destpath"]; // portmain.tcl
	[_defaults setObject:@"${destpath}" forKey:@"destroot"]; // portmain.tcl
	[_defaults setObject:@"files" forKey:@"filesdir"]; // portmain.tcl
	[_defaults setObject:@"0" forKey:@"revision"]; // portmain.tcl
	[_defaults setObject:@"0" forKey:@"epoch"]; // portmain.tcl
	[_defaults setObject:@"${portname}-${portversion}" forKey:@"distname"]; // portmain.tcl
	[_defaults setObject:@"${distname}" forKey:@"worksrcdir"]; // portmain.tcl
	[_defaults setObject:@"[file join ${portpath} ${filesdir}]" forKey:@"filespath"]; // portmain.tcl
	[_defaults setObject:@"[file join ${workpath} ${worksrcdir}]" forKey:@"worksrcpath"]; // portmain.tcl

	[_defaults setObject:@"XXX" forKey:@"os.arch"]; // portmain.tcl

	[_defaults setObject:@"" forKey:@"configure.cflags"];
	[_defaults setObject:@"" forKey:@"configure.ldflags"];

	[_defaults setObject:@".tar.gz" forKey:@"extract.suffix"]; // portfetch.tcl
	[_defaults setObject:@"standard" forKey:@"fetch.type"]; // portfetch.tcl
	[_defaults setObject:@"XXX" forKey:@"svn.cmd"]; // portfetch.tcl
	[_defaults setObject:@"${workpath}" forKey:@"svn.dir"]; // portfetch.tcl
	[_defaults setObject:@"export" forKey:@"svn.method"]; // portfetch.tcl
	[_defaults setObject:@"" forKey:@"svn.tag"]; // portfetch.tcl
	[_defaults setObject:@"" forKey:@"svn.env"]; // portfetch.tcl
	[_defaults setObject:@"--non-interactive" forKey:@"svn.pre_args"]; // portfetch.tcl
	[_defaults setObject:@"" forKey:@"svn.args"]; // portfetch.tcl
	[_defaults setObject:@"${svn.url}" forKey:@"svn.post_args"]; // portfetch.tcl
	[_defaults setObject:@"${workpath}" forKey:@"git.dir"]; // portfetch.tcl
	[_defaults setObject:@"" forKey:@"git.branch"]; // portfetch.tcl
	[_defaults setObject:@"${workpath}" forKey:@"hg.dir"]; // portfetch.tcl
	[_defaults setObject:@"tip" forKey:@"hg.tag"]; // portfetch.tcl
	[_defaults setObject:@"[suffix ${distname}" forKey:@"distfiles"]; // portfetch.tcl
	[_defaults setObject:@"${portname}" forKey:@"dist_subdir"]; // portfetch.tcl
	[_defaults setObject:@"" forKey:@"fetch.user"]; // portfetch.tcl
	[_defaults setObject:@"" forKey:@"fetch.password"]; // portfetch.tcl
	[_defaults setObject:@"yes" forKey:@"fetch.use_epsv"]; // portfetch.tcl
	[_defaults setObject:@"no" forKey:@"fetch.ignore_sslcert"]; // portfetch.tcl
	[_defaults setObject:@"no" forKey:@"fetch.remote_time"]; // portfetch.tcl
	[_defaults setObject:@"macports" forKey:@"fallback_mirror_site"]; // portfetch.tcl
	[_defaults setObject:@"macports_distfiles" forKey:@"global_mirror_site"]; // portfetch.tcl
	[_defaults setObject:@"mirror_sites.tcl" forKey:@"mirror_sites.listfile"]; // portfetch.tcl
	[_defaults setObject:@"port1.0/fetch" forKey:@"mirror_sites.listpath"]; // portfetch.tcl

	[_defaults setObject:@"${workpath}/${worksrcdir}" forKey:@"build.dir"]; // portbuild.tcl
	[_defaults setObject:@"XXX" forKey:@"build.cmd"]; // portbuild.tcl
	[_defaults setObject:@"XXX" forKey:@"build.nice"]; // portbuild.tcl
	[_defaults setObject:@"XXX" forKey:@"build.jobs"]; // portbuild.tcl
	[_defaults setObject:@"${build.target}" forKey:@"build.pre_args"]; // portbuild.tcl
	[_defaults setObject:@"all" forKey:@"build.target"]; // portbuild.tcl

	[_defaults setObject:@"${build.dir}" forKey:@"test.dir"]; // porttest.tcl
	[_defaults setObject:@"${build.cmd}" forKey:@"test.cmd"]; // porttest.tcl
	[_defaults setObject:@"${test.target}" forKey:@"test.pre_args"]; // porttest.tcl
	[_defaults setObject:@"test" forKey:@"test.target"]; // porttest.tcl

	// XXX: option_proc setup?
	// options_export?

	_parser = [[MPParser alloc] initWithPort:self];

	return self;
}

- (void)dealloc
{
	[_parser release];
	[_portfile release];

	[_procs release];
	[_targets release];
	[_options release];
	[_defaults release];

	[super dealloc];
}

- (NSString *)portfile
{
	return _portfile;
}

- (NSArray *)procs
{
	return _procs;
}

- (NSArray *)targets
{
	return _targets;
}

- (BOOL)isTarget:(NSString *)target
{
	if ([target hasPrefix:@"pre-"]) {
		target = [target substringWithRange:NSMakeRange(4, [target length] - 4)];
	} else if ([target hasPrefix:@"post-"]) {
		target = [target substringWithRange:NSMakeRange(5, [target length] - 5)];
	}

	return [_targets containsObject:target];
}

- (NSArray *)defaults
{
	return [_defaults allKeys];
}

- (NSString *)default:(NSString *)def
{
	// XXX: selector (NSInvocation?) or constant NSString...
	return [_defaults objectForKey:def];
}

- (NSArray *)options
{
	return _options;
}

- (NSString *)option:(NSString *)option
{
	return [_parser option:option];
}

// essentially 'commands' from portutil.tcl
- (void)addCommand:(NSString *)command
{
	[_options addObject:[NSString stringWithFormat:@"use_%@", command]];
	[_options addObject:[NSString stringWithFormat:@"%@.dir", command]];
	[_options addObject:[NSString stringWithFormat:@"%@.pre_args", command]];
	[_options addObject:[NSString stringWithFormat:@"%@.args", command]];
	[_options addObject:[NSString stringWithFormat:@"%@.post_args", command]];
	[_options addObject:[NSString stringWithFormat:@"%@.env", command]];
	[_options addObject:[NSString stringWithFormat:@"%@.type", command]];
	[_options addObject:[NSString stringWithFormat:@"%@.cmd", command]];
}

- (NSArray *)variants
{
	return [_parser variants];
}

- (NSArray *)platforms
{
	return [_parser platforms];
}

@end
