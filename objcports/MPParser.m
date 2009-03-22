#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPParser.h"
#include "MPPort.h"
#include "MPArrayAdditions.h"
#include "MPStringAdditions.h"

static char *variable_read(ClientData clientData, Tcl_Interp *interp, const char *name1, const char *name2, int flags);
static int unknown_trampoline(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);

static int _nslog(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static void _info(Tcl_Interp *interp, const char *command); // debugging

@implementation MPParser

- (id)initWithPort:(MPPort *)port
{
	self = [super init];
	_port = [port retain];
	_interp = Tcl_CreateInterp();
	_variants = [[NSMutableDictionary alloc] initWithCapacity:0];
	_platforms = [[NSMutableArray alloc] initWithCapacity:0];

	// XXX: should probably remove even more functionality
	Tcl_MakeSafe(_interp);

	@try {
		Tcl_Preserve(_interp);

		for (NSString *var in [_port variables]) {
			Tcl_TraceVar(_interp, [var UTF8String], TCL_TRACE_READS, variable_read, port);
		}

		Tcl_CreateObjCommand(_interp, "nslog", _nslog, NULL, NULL);

		/* Handle *all* commands via the "unknown" mechanism. */
		Tcl_CreateObjCommand(_interp, "unknown", unknown_trampoline, self, NULL);

		const char *portfile = [[_port portfile] UTF8String];
		if (Tcl_EvalFile(_interp, portfile) != TCL_OK) {
			NSLog(@"Tcl_EvalFile(%s): %s", portfile, Tcl_GetStringResult(_interp));
		}

		Tcl_Release(_interp);
	}
	@catch (NSException *exception) {
		NSLog(@"%@: %@", [exception name], [exception reason]);
		[self release];
		self = nil;
	}
	@finally {
		_info(_interp, "[info globals]");
		_info(_interp, "[info commands]");
		//NSLog(@"%@", _variants);
	}

	return self;
}

- (void)dealloc
{
	[_variants release];
	[_platforms release];
	Tcl_DeleteInterp(_interp);
	[_port release];
	[super dealloc];
}

- (NSArray *)variants
{
	return [_variants allKeys];
}

- (NSArray *)platforms
{
	return _platforms;
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
		NSString *os, *arch = nil;
		NSInteger release = 0;

		if (count < 2 || count > 4) {
			NSLog(@"bogus platform declaration");
			return;
		}

		os = [args objectAtIndex:0];
		if (count == 3) {
			release = [[args objectAtIndex:1] integerValue];
			arch = release ? nil : [args objectAtIndex:1];
		} else if (count == 4) {
			release = [[args objectAtIndex:1] integerValue];
			arch = [args objectAtIndex:2];
		}

		NSString *platformFull = [NSString stringWithFormat:@"%@%@%@",
			os,
			release ? [NSString stringWithFormat:@"_%ld", release] : @"",
			arch ? [NSString stringWithFormat:@"_%@", arch] : @""];

		// XXX: dupe check
		[_platforms addObject:platformFull];
		// XXX: check match, right now pretend all platforms are true
		if (YES) {
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

		props = [NSMutableDictionary dictionaryWithCapacity:count-2];
 		for (i = 1; i < count - 1; i += 2) {
			[props setObject:[args objectAtIndex:i+1] forKey:[args objectAtIndex:i]];
		}

		// XXX: check for dupes (w/ platforms too)
		[_variants setObject:props forKey:name];

		// XXX: make sure it's set, like platforms just pretend
		if (YES) {
			Tcl_Eval(_interp, [[args lastObject] UTF8String]);
		}
	} else if ([_port isTarget:command]) {
		// XXX: store for later use...
	} else {
		if ([command hasSuffix:@"-append"]) {
			[_port option:[command substringWithRange:NSMakeRange(0, [command length] - 7)] append:args];
		} else if ([command hasSuffix:@"-delete"]) {
			[_port option:[command substringWithRange:NSMakeRange(0, [command length] - 7)] delete:args];
		} else {
			[_port option:command set:args];
		}
	}
}

@end

static int
unknown_trampoline(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	assert(objc >= 2);
	assert(!strcmp(Tcl_GetString(objv[0]), "::unknown"));

	NSArray *args = [[NSArray alloc] initWithTclObjects:++objv count:--objc];
	[(id)clientData performCommand:[args objectAtIndex:0] arguments:[args subarrayWithRange:NSMakeRange(1, [args count] - 1)]];
	[args release];

	return TCL_OK;
}

static char *
variable_read(ClientData clientData, Tcl_Interp *interp, const char *name1, const char *name2, int flags)
{
	Tcl_SetVar2Ex(interp, name1, name2, Tcl_SubstObj(interp, Tcl_NewStringObj([[(id)clientData variable:[NSString stringWithUTF8String:name1]] UTF8String], -1), TCL_SUBST_ALL), 0);
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

static void
_info(Tcl_Interp *interp, const char *command)
{
	Tcl_Obj *result;
	int objc;
	Tcl_Obj **objv;

	Tcl_ExprObj(interp, Tcl_NewStringObj(command, -1), &result);
	Tcl_ListObjGetElements(interp, result, &objc, &objv);
	//NSLog(@"%@", [NSArray arrayWithTclObjects:objv count:objc]);
}
