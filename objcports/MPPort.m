#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPPort.h"
#include "MPParser.h"

@implementation MPPort

- (id)initWithPortfile:(NSString *)portfile options:(NSDictionary *)options
{
	self = [super init];
	_portfile = [portfile retain];
	_parser = [[MPParser alloc] initWithPort:self];
	return self;
}

- (void)dealloc
{
	[_parser release];
	[_portfile release];
	[super dealloc];
}

- (NSString *)portfile
{
	return _portfile;
}

- (NSArray *)defaults
{
	return [NSArray arrayWithObjects:@"prefix", @"worksrcpath", nil];
}

- (NSString *)default:(NSString *)def
{
	// XXX: selector (NSInvocation?) or constant NSString...
	NSLog(@"default: '%@'", def);
	return def;
}

- (NSString *)option:(NSString *)option
{
	return [_parser option:option];
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
