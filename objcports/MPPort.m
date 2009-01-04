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

	_options = [[NSMutableArray alloc] initWithCapacity:0];
	[self addCommand:@"autoconf"];
	[self addCommand:@"configure"];
	[self addCommand:@"extract"];
	[self addCommand:@"patch"];
	[self addCommand:@"fetch"];
	[self addCommand:@"build"];
	[self addCommand:@"destroot"];
	[_options addObject:@"name"];
	[_options addObject:@"version"];
	[_options addObject:@"revision"];
	[_options addObject:@"categories"];
	[_options addObject:@"maintainers"];
	[_options addObject:@"homepage"];
	[_options addObject:@"platforms"];
	[_options addObject:@"use_bzip2"];
	[_options addObject:@"use_parallel_build"];
	[_options addObject:@"description"];
	[_options addObject:@"long_description"];
	[_options addObject:@"master_sites"];
	[_options addObject:@"checksums"];
	[_options addObject:@"patchfiles"];
	[_options addObject:@"depends_run"];
	[_options addObject:@"depends_build"];
	[_options addObject:@"depends_lib"];
	[_options addObject:@"distname"];
	[_options addObject:@"extract.suffix"];
	[_options addObject:@"use_zip"];
	[_options addObject:@"universal_variant"];
	[_options addObject:@"build.target"];
	[_options addObject:@"test.run"];
	[_options addObject:@"test.target"];
	[_options addObject:@"destroot.destdir"];
	[_options addObject:@"livecheck.check"];
	[_options addObject:@"livecheck.url"];
	[_options addObject:@"livecheck.regex"];
	[_options addObject:@"livecheck.distname"];
	[_options addObject:@"worksrcdir"];

	// *some* overlap with options
	_defaults = [[NSMutableDictionary alloc] initWithCapacity:0];
	[_defaults setObject:@"/opt/local" forKey:@"prefix"];
	[_defaults setObject:@"" forKey:@"destroot"];
	[_defaults setObject:@"" forKey:@"distname"];
	[_defaults setObject:@"" forKey:@"os.arch"];
	[_defaults setObject:@"" forKey:@"configure.cflags"];
	[_defaults setObject:@"" forKey:@"configure.ldflags"];
	[_defaults setObject:@".tar.gz" forKey:@"extract.suffix"];

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
