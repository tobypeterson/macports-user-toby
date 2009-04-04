#include <Foundation/Foundation.h>
#include <tcl.h>
#include <sys/utsname.h>

#include "MPPort.h"
#include "MPParser.h"

static NSString *kPortVariableType = @"Type";
static NSString *kPortVariableConstant = @"Constant";

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
		[_variableInfo setObject:[NSDictionary dictionaryWithObject:@"Array" forKey:kPortVariableType] forKey:[NSString stringWithFormat:@"%@.pre_args", command]];
		[_variableInfo setObject:[NSDictionary dictionaryWithObject:@"Array" forKey:kPortVariableType] forKey:[NSString stringWithFormat:@"%@.args", command]];
		[_variableInfo setObject:[NSDictionary dictionaryWithObject:@"Array" forKey:kPortVariableType] forKey:[NSString stringWithFormat:@"%@.post_args", command]];
		[_variableInfo setObject:[NSDictionary dictionaryWithObject:@"Array" forKey:kPortVariableType] forKey:[NSString stringWithFormat:@"%@.env", command]];
		[_variableInfo setObject:[NSDictionary dictionary] forKey:[NSString stringWithFormat:@"%@.type", command]];
		[_variableInfo setObject:[NSDictionary dictionaryWithObject:@"Array" forKey:kPortVariableType] forKey:[NSString stringWithFormat:@"%@.cmd", command]];
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
		@"checksum",
		@"extract",
		@"patch",
		@"configure",
		@"build",
		@"test",
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

- (BOOL)variableIsArray:(NSString *)var
{
	NSString *type = [[_variableInfo objectForKey:var] objectForKey:kPortVariableType];
	return [type isEqualToString:@"Array"];
}

- (NSString *)variable:(NSString *)name
{
	NSString *ret = @"";
	id val;
	if ([_variableInfo objectForKey:name] != nil) {
		val = [_variables objectForKey:name];
		if ([self variableIsArray:name]) {
			if (val) {
				NSLog(@"%@ %@", name, val);
				assert([val isKindOfClass:[NSArray class]]);
				ret = [val componentsJoinedByString:@" "];
			}
		} else {
			if (val) {
				assert([val isKindOfClass:[NSString class]]);
				ret = val;
			}
		}
	} else {
		NSLog(@"WARNING: unknown variable %@", name);
	}
	return ret;
}

- (NSArray *)settableVariables
{
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:0];
	for (NSString *var in [self variables]) {
		NSNumber *constant = [[_variableInfo objectForKey:var] objectForKey:kPortVariableConstant];
		if (constant == nil || [constant boolValue] == NO) {
			[ret addObject:var];
		}
	}
	return ret;
}

- (void)variable:(NSString *)var set:(NSArray *)value
{
	if ([self variableIsArray:var]) {
		[_variables setObject:value forKey:var];
	} else {
		[_variables setObject:[value componentsJoinedByString:@" "] forKey:var];
	}
}

- (NSArray *)settableArrayVariables
{
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:0];
	for (NSString *var in [self settableVariables]) {
		if ([self variableIsArray:var]) {
			[ret addObject:var];
		}
	}
	return ret;
}

- (void)variable:(NSString *)var append:(NSArray *)value
{
	id old = [_variables objectForKey:var];
	if (old) {
		assert([old isKindOfClass:[NSArray class]]);
		[_variables setObject:[old arrayByAddingObjectsFromArray:value] forKey:var];
	} else {
		[_variables setObject:value forKey:var];
	}
}

- (void)variable:(NSString *)var delete:(NSArray *)value
{
	id old;
	NSMutableArray *tmp;

	old = [_variables objectForKey:var];
	if (old == nil) {
		return;
	}
	assert([old isKindOfClass:[NSArray class]]);
	tmp = [old mutableCopy];
	for (NSString *v in value) {
		[tmp removeObject:v];
	}
	[_variables setObject:tmp forKey:var];
	[tmp release];
}

- (NSArray *)definedPlatforms
{
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:0];
	for (NSArray *plat in _platforms) {
		[ret addObject:[plat componentsJoinedByString:@"_"]];
	}
	return ret;
}

- (BOOL)testAndRecordPlatform:(NSArray *)platform
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

- (NSArray *)definedVariants
{
	return [_variants allKeys];
}

- (BOOL)testAndRecordVariant:(NSString *)variant withProperties:(NSDictionary *)props
{
	// XXX: check for dupes (w/ platforms too)
	[_variants setObject:props forKey:variant];
	// XXX: make sure it's set, like platforms just pretend
	return YES;
}

@end
