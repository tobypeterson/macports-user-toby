#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPParser.h"
#include "MPPort.h"
#include "MPArrayAdditions.h"
#include "MPStringAdditions.h"

static void command_create(Tcl_Interp *interp, const char *cmdName, ClientData clientData);
static char *variable_read(ClientData clientData, Tcl_Interp *interp, const char *name1, const char *name2, int flags);
static int _nslog(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);

@implementation MPParser

- (id)initWithPort:(MPPort *)port
{
	self = [super init];

	_port = [port retain];

	_interp = Tcl_CreateInterp();
	Tcl_MakeSafe(_interp); // XXX: should probably remove even more functionality

	@try {
		Tcl_Preserve(_interp);

		command_create(_interp, "PortSystem", self);
		command_create(_interp, "PortGroup", self);
		command_create(_interp, "platform", self);
		command_create(_interp, "variant", self);

		for (NSString *target in [_port targets]) {
			command_create(_interp, [target UTF8String], self);
			command_create(_interp, [[@"pre-" stringByAppendingString:target] UTF8String], self);
			command_create(_interp, [[@"post-" stringByAppendingString:target] UTF8String], self);
		}

		for (NSString *opt in [_port settableVariables]) {
			command_create(_interp, [opt UTF8String], self);
		}
		for (NSString *opt in [_port modifiableVariables]) {
			command_create(_interp, [[opt stringByAppendingString:@"-append"] UTF8String], self);
			command_create(_interp, [[opt stringByAppendingString:@"-delete"] UTF8String], self);
		}

		for (NSString *var in [_port variables]) {
			Tcl_TraceVar(_interp, [var UTF8String], TCL_TRACE_READS, variable_read, port);
		}

		Tcl_CreateObjCommand(_interp, "nslog", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(_interp, "post-activate", _nslog, NULL, NULL); // XXX: debugging

		if (Tcl_EvalFile(_interp, [[_port portfile] UTF8String]) != TCL_OK) {
			NSLog(@"Tcl_EvalFile(): %s", Tcl_GetStringResult(_interp));
		}

		Tcl_Release(_interp);
	}
	@catch (NSException *exception) {
		NSLog(@"%@: %@", [exception name], [exception reason]);
		[self release];
		self = nil;
	}

	return self;
}

- (void)dealloc
{
	Tcl_DeleteInterp(_interp);
	[_port release];
	[super dealloc];
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

		if ([_port testAndRecordPlatform:[NSArray arrayWithObjects:os, release, arch, nil]]) {
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

		if ([_port testAndRecordVariant:name withProperties:props]) {
			Tcl_Eval(_interp, [[args lastObject] UTF8String]);
		}
	} else if ([_port isTarget:command]) {
		// XXX: store for later use...
	} else {
		if ([command hasSuffix:@"-append"]) {
			[_port variable:[command substringWithRange:NSMakeRange(0, [command length] - 7)] append:args];
		} else if ([command hasSuffix:@"-delete"]) {
			[_port variable:[command substringWithRange:NSMakeRange(0, [command length] - 7)] delete:args];
		} else {
			[_port variable:command set:args];
		}
	}
}

@end

static int
command_trampoline(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	NSArray *args = [[NSArray alloc] initWithTclObjects:objv count:objc];
	[(MPParser *)clientData performCommand:[args objectAtIndex:0] arguments:[args subarrayWithRange:NSMakeRange(1, [args count] - 1)]];
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
	Tcl_SetVar2Ex(interp, name1, name2, Tcl_SubstObj(interp, Tcl_NewStringObj([var UTF8String], -1), TCL_SUBST_ALL), 0);
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
