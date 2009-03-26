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

	_variables = [[NSMutableDictionary alloc] initWithCapacity:0];
	_variableInfo = [[NSMutableDictionary alloc] initWithContentsOfFile:@"variables.plist"];

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
		@"test", // porttest.tcl
		@"destroot", // portdestroot.tcl
		nil];

	// essentially 'commands' from portutil.tcl
	for (NSString *command in commands) {
		[_variableInfo setObject:[NSDictionary dictionary] forKey:[NSString stringWithFormat:@"use_%@", command]];
		[_variableInfo setObject:[NSDictionary dictionary] forKey:[NSString stringWithFormat:@"%@.dir", command]];
		[_variableInfo setObject:[NSDictionary dictionary] forKey:[NSString stringWithFormat:@"%@.pre_args", command]];
		[_variableInfo setObject:[NSDictionary dictionary] forKey:[NSString stringWithFormat:@"%@.args", command]];
		[_variableInfo setObject:[NSDictionary dictionary] forKey:[NSString stringWithFormat:@"%@.post_args", command]];
		[_variableInfo setObject:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"AppendDelete"] forKey:[NSString stringWithFormat:@"%@.env", command]];
		[_variableInfo setObject:[NSDictionary dictionary] forKey:[NSString stringWithFormat:@"%@.type", command]];
		[_variableInfo setObject:[NSDictionary dictionary] forKey:[NSString stringWithFormat:@"%@.cmd", command]];
	}

	_parser = [[MPParser alloc] initWithPort:self];

	return self;
}

- (void)dealloc
{
	[_parser release];
	[_portfile release];

	[_variableInfo release];
	[_variables release];

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
	return [_variableInfo allKeys];
}

- (NSString *)variable:(NSString *)name
{
	NSString *ret = nil;
	if ([_variableInfo objectForKey:name] != nil) {
		ret = [_variables objectForKey:name];
		if (ret == nil) {
			ret = @"";
		}
		assert([ret isKindOfClass:[NSString class]]);
	} else {
		NSLog(@"WARNING: unknown variable %@", name);
	}
	return ret;
}

- (NSArray *)settableVariables
{
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:0];
	for (NSString *var in [self variables]) {
		if (![[[_variableInfo objectForKey:var] objectForKey:@"Constant"] boolValue]) {
			[ret addObject:var];
		}
	}
	return ret;
}

- (void)variable:(NSString *)var set:(NSArray *)value
{
	[_variables setObject:[value componentsJoinedByString:@" "] forKey:var];
}

- (NSArray *)modifiableVariables
{
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:0];
	for (NSString *var in [self variables]) {
		if ([[[_variableInfo objectForKey:var] objectForKey:@"AppendDelete"] boolValue]) {
			[ret addObject:var];
		}
	}
	return ret;
}

- (void)variable:(NSString *)var append:(NSArray *)value
{
	[_variables setObject:[NSString stringWithFormat:@"%@ %@", [_variables objectForKey:var], [value componentsJoinedByString:@" "]] forKey:var];
}

- (void)variable:(NSString *)var delete:(NSArray *)value
{
	NSMutableArray *tmp = [[[_variables objectForKey:var] componentsSeparatedByString:@" "] mutableCopy];
	for (NSString *v in value) {
		[tmp removeObject:v];
	}
	[_variables setObject:[tmp componentsJoinedByString:@" "] forKey:var];
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
