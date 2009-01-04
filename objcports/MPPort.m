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

	_targets = [[NSMutableArray alloc] initWithCapacity:0];
	[_targets addObject:@"configure"];
	[_targets addObject:@"build"];
	[_targets addObject:@"destroot"];

	_options = [[NSMutableArray alloc] initWithCapacity:0];
	[self addCommand:@"configure"];
	[_options addObject:@"name"];
	[_options addObject:@"version"];
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
	[_options addObject:@"depends_build"];
	[_options addObject:@"depends_lib"];

	[_options addObject:@"test.run"];
	[_options addObject:@"test.target"];

	[_options addObject:@"livecheck.check"];

	_defaults = [[NSMutableArray alloc] initWithCapacity:0];
	[_defaults addObject:@"prefix"];

	_parser = [[MPParser alloc] initWithPort:self];

	return self;
}

- (void)dealloc
{
	[_parser release];
	[_portfile release];

	[_targets release];
	[_options release];
	[_defaults release];

	[super dealloc];
}

- (NSString *)portfile
{
	return _portfile;
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
	return _defaults;
}

- (NSString *)default:(NSString *)def
{
	// XXX: selector (NSInvocation?) or constant NSString...
	return def;
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
