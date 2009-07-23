#include <Foundation/Foundation.h>
#include <tcl.h>
#include <sys/utsname.h>

#include "MPPort.h"
#include "MPArrayAdditions.h"
#include "MPStringAdditions.h"

static NSString *kPortVariableType = @"Type";
static NSString *kPortVariableConstant = @"Constant";
static NSString *kPortVariableDefault = @"Default";
static NSString *kPortVariableCallback = @"Callback";

static void command_create(Tcl_Interp *interp, const char *cmdName, ClientData clientData);
static char *variable_read(ClientData clientData, Tcl_Interp *interp, const char *name1, const char *name2, int flags);
static int _nslog(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int _fake_boolean(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);

@interface MPPort (private)
- (NSString *)portfile;
- (NSArray *)targets;
- (NSArray *)variables;
- (NSArray *)settableVariables;
- (NSArray *)settableArrayVariables;
@end

@implementation MPPort

- (id)initWithURL:(NSURL *)url options:(NSDictionary *)options
{
	NSData *vdata;
	self = [super init];
	_url = [url retain];

	_platforms = [[NSMutableArray alloc] initWithCapacity:0];
	_variants = [[NSMutableDictionary alloc] initWithCapacity:0];

	_variables = [[NSMutableDictionary alloc] initWithCapacity:0];

	//_variableInfo = [[NSMutableDictionary alloc] initWithContentsOfFile:@"variables.plist"];
	vdata = [[NSData alloc] initWithContentsOfMappedFile:@"variables.plist"];
	_variableInfo = [[NSPropertyListSerialization propertyListWithData:vdata options:kCFPropertyListMutableContainersAndLeaves format:NULL error:NULL] retain];
	[vdata release];

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

	_interp = Tcl_CreateInterp();
	Tcl_MakeSafe(_interp);
	Tcl_UnsetVar(_interp, "tcl_version", 0);
	Tcl_UnsetVar(_interp, "tcl_patchLevel", 0);
	Tcl_UnsetVar(_interp, "tcl_platform", 0);
	Tcl_DeleteCommand(_interp, "tell");
	Tcl_DeleteCommand(_interp, "eof");
	// XXX: etc?
	
	@try {
		Tcl_Preserve(_interp);
		
		Tcl_CreateObjCommand(_interp, "nslog", _nslog, NULL, NULL); // XXX: debugging
		//Tcl_Eval(_interp, "nslog [info commands]");
		
		command_create(_interp, "PortSystem", self);
		command_create(_interp, "PortGroup", self);
		command_create(_interp, "platform", self);
		command_create(_interp, "variant", self);
		
		for (NSString *target in [self targets]) {
			command_create(_interp, [target UTF8String], self);
			command_create(_interp, [[@"pre-" stringByAppendingString:target] UTF8String], self);
			command_create(_interp, [[@"post-" stringByAppendingString:target] UTF8String], self);
		}
		
		for (NSString *opt in [self settableVariables]) {
			command_create(_interp, [opt UTF8String], self);
		}
		for (NSString *opt in [self settableArrayVariables]) {
			command_create(_interp, [[opt stringByAppendingString:@"-append"] UTF8String], self);
			command_create(_interp, [[opt stringByAppendingString:@"-delete"] UTF8String], self);
		}
		
		for (NSString *var in [self variables]) {
			Tcl_TraceVar(_interp, [var UTF8String], TCL_TRACE_READS, variable_read, self);
		}
		
		// bogus targets
		Tcl_CreateObjCommand(_interp, "pre-activate", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "post-activate", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "pre-install", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "post-install", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "post-pkg", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "post-mpkg", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "archive", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "install", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "activate", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "unarchive", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "post-clean", _nslog, NULL, NULL); // XXX: debugging
		
		// functions we need to provide (?)
		Tcl_CreateObjCommand(_interp, "variant_isset", _fake_boolean, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "variant_set", _fake_boolean, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "tbool", _fake_boolean, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "strsed", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "suffix", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "include", _nslog, NULL, NULL); // XXX: debugging
		
		// variables that should be constant
		Tcl_CreateObjCommand(_interp, "prefix", _nslog, NULL, NULL);
		
		if (Tcl_EvalFile(_interp, [[self portfile] UTF8String]) != TCL_OK) {
			NSLog(@"Tcl_EvalFile(): %s", Tcl_GetStringResult(_interp));
			exit(1);
		}
		
		Tcl_Release(_interp);
	}
	@catch (NSException *exception) {
		NSLog(@"%@: %@", [exception name], [exception reason]);
		[self release];
		self = nil;
	}

	for (NSString *vv in _variableInfo) {
		NSLog(@"%@ -- %@ -- %@", vv, [_variables objectForKey:vv], [self variable:vv]);
	}

	return self;
}

- (id)initWithPath:(NSString *)path options:(NSDictionary *)options
{
	NSString *standardizedPath;
	NSURL *url;

	standardizedPath = [path stringByStandardizingPath];
	url = [NSURL fileURLWithPath:standardizedPath isDirectory:YES];
	return [self initWithURL:url options:options];
}

- (void)dealloc
{
	[_url release];

	[_variableInfo release];
	[_variables release];

	[_platforms release];
	[_variants release];

	Tcl_DeleteInterp(_interp);

	[super dealloc];
}

- (NSString *)portfile
{
	return [[_url path] stringByAppendingPathComponent:@"Portfile"];
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

- (id)defaultCallback:(NSString *)name
{
	return @"";
}

- (id)osInfo:(NSString *)name
{
	NSString *ret = nil;
	int rc;
	struct utsname u;

	rc = uname(&u);
	assert(rc == 0);

	if ([name isEqualToString:@"os.platform"]) {
		ret = [[NSString stringWithUTF8String:u.sysname] lowercaseString];
	} else if ([name isEqualToString:@"os.arch"]) {
		ret = [NSString stringWithUTF8String:u.machine];
	} else if ([name isEqualToString:@"os.endian"]) {
#ifdef __BIG_ENDIAN__
		ret = @"big";
#else
		ret = @"little";
#endif
	} else if ([name isEqualToString:@"os.major"]) {
		ret = [[[NSString stringWithUTF8String:u.release] componentsSeparatedByString:@"."] objectAtIndex:0];
	} else if ([name isEqualToString:@"os.version"]) {
		ret = [NSString stringWithUTF8String:u.release];
	} else {
		abort();
	}

	return ret;
}

- (NSString *)variable:(NSString *)name
{
	NSDictionary *info;
	id setValue;
	id defValue;
	id callback;
	NSString *ret = nil;

	info = [_variableInfo objectForKey:name];
	if (info != nil) {
		if ((setValue = [_variables objectForKey:name])) {
			if ([self variableIsArray:name]) {
				NSLog(@"%@ %@", name, setValue);
				assert([setValue isKindOfClass:[NSArray class]]);
				ret = [setValue componentsJoinedByString:@" "];
			} else {
				assert([setValue isKindOfClass:[NSString class]]);
				ret = setValue;
			}
		} else if ((defValue = [info objectForKey:kPortVariableDefault])) {
			ret = defValue;
		} else if ((callback = [info objectForKey:kPortVariableCallback])) {
			assert([callback isKindOfClass:[NSString class]]);
			ret = [self performSelector:NSSelectorFromString(callback) withObject:name];
		} else {
			ret = [NSString stringWithUTF8String:""];
		}
		ret = [[[NSString alloc] initWithTclObject:Tcl_SubstObj(_interp, Tcl_NewStringObj([ret UTF8String], -1), TCL_SUBST_VARIABLES)] autorelease];
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

- (void)performCommand:(NSString *)command arguments:(NSArray *)args
{
	if ([command isEqualToString:@"PortSystem"]) {
		assert([args count] == 1);
		assert([[args objectAtIndex:0] isEqualToString:@"1.0"]);
	} else if ([command isEqualToString:@"PortGroup"]) {
		NSLog(@"ignoring %@, grps r hard m'kay", command);
		// XXX: this should probably set some state in parent port instance
		// (ugh, more tcl parsing)
	} else if ([command isEqualToString:@"platform"]) {
		NSUInteger count = [args count];
		NSString *os = nil;
		id release = [NSNull null];
		id arch = [NSNull null];
		
		if (count < 2 || count > 4) {
			NSLog(@"bogus platform declaration");
			return;
		}
		
		os = [args objectAtIndex:0];
		
		if (count == 3) {
			NSInteger rel = [[args objectAtIndex:1] integerValue];
			if (rel != 0) {
				release = [NSNumber numberWithInteger:rel];
			} else {
				arch = [args objectAtIndex:1];
			}
		} else if (count == 4) {
			release = [NSNumber numberWithInteger:[[args objectAtIndex:1] integerValue]];
			arch = [args objectAtIndex:2];
		}
		
		if ([self testAndRecordPlatform:[NSArray arrayWithObjects:os, release, arch, nil]]) {
			Tcl_Eval(_interp, [[args lastObject] UTF8String]);
		}
	} else if ([command isEqualToString:@"variant"]) {
		NSUInteger count = [args count];
		NSString *name;
		NSMutableDictionary *props;
		int i;
		
		// variant name [a b c d] {}
		if (count < 2 || count % 2) {
			NSLog(@"bogus variant declaration");
			return;
		}
		
		name = [args objectAtIndex:0];
		
		// this isn't quite right, conflicts can take multiple "arguments"
		props = [NSMutableDictionary dictionaryWithCapacity:count-2];
 		for (i = 1; i < count - 1; i += 2) {
			[props setObject:[args objectAtIndex:i+1] forKey:[args objectAtIndex:i]];
		}
		
		if ([self testAndRecordVariant:name withProperties:props]) {
			Tcl_Eval(_interp, [[args lastObject] UTF8String]);
		}
	} else if ([self isTarget:command]) {
		// XXX: store for later use...
	} else {
		if ([command hasSuffix:@"-append"]) {
			[self variable:[command substringWithRange:NSMakeRange(0, [command length] - 7)] append:args];
		} else if ([command hasSuffix:@"-delete"]) {
			[self variable:[command substringWithRange:NSMakeRange(0, [command length] - 7)] delete:args];
		} else {
			[self variable:command set:args];
		}
	}
}

@end

static int
command_trampoline(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	NSArray *args = [[NSArray alloc] initWithTclObjects:objv count:objc];
	[(MPPort *)clientData performCommand:[args objectAtIndex:0] arguments:[args subarrayWithRange:NSMakeRange(1, [args count] - 1)]];
	[args release];
	
	return TCL_OK;
}

static void
command_create(Tcl_Interp *interp, const char *cmdName, ClientData clientData)
{
	Tcl_CmdInfo info;
	if (Tcl_GetCommandInfo(interp, cmdName, &info) != 0) {
		NSLog(@"Command '%s' already exists, bailing.", cmdName);
		abort();
	}
	Tcl_CreateObjCommand(interp, cmdName, command_trampoline, clientData, NULL);
}

static char *
variable_read(ClientData clientData, Tcl_Interp *interp, const char *name1, const char *name2, int flags)
{
	NSString *var = [(MPPort *)clientData variable:[NSString stringWithUTF8String:name1]];
	assert(var != nil);
	Tcl_SetVar2(interp, name1, name2, [var UTF8String], 0);
	return NULL;
}

// debugging
static int
_nslog(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	NSArray *args = [[NSArray alloc] initWithTclObjects:++objv count:--objc];
	NSLog(@"%@", [args componentsJoinedByString:@" "]);
	[args release];
	
	return TCL_OK;
}

static int
_fake_boolean(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	Tcl_SetObjResult(interp, Tcl_NewBooleanObj(0));
	return TCL_OK;
}
