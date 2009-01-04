#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPParser.h"
#include "MPPort.h"
#include "MPArrayAdditions.h"
#include "MPStringAdditions.h"

static int _nslog(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int _unknown(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static char *_default(ClientData clientData, Tcl_Interp *interp, const char *name1, const char *name2, int flags);
static void info(Tcl_Interp *interp, const char *command); // debugging

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

		/* Handle defaults. Ports shouldn't expect any other variables to be set,
		 * so we can just set them as we go. */
		for (NSString *def in [_port defaults]) {
			Tcl_TraceVar(_interp, [def UTF8String], TCL_TRACE_READS, _default, port);
		}

		Tcl_CreateObjCommand(_interp, "nslog", _nslog, NULL, NULL);

		/* Handle *all* commands via the "unknown" mechanism. */
		Tcl_CreateObjCommand(_interp, "unknown", _unknown, self, NULL);

		NSString *portfile = [_port portfile];
		if (Tcl_EvalFile(_interp, [portfile UTF8String]) != TCL_OK) {
			NSLog(@"Tcl_EvalFile(%@): %s", portfile, Tcl_GetStringResult(_interp));
		}

		//fprintf(stderr, "%s\n", Tcl_GetString(Tcl_SubstObj(_interp, Tcl_NewStringObj("$prefix/${extract.suffix}", -1), TCL_SUBST_ALL)));

		Tcl_Release(_interp);
	}
	@catch (NSException *exception) {
		NSLog(@"%@: %@", [exception name], [exception reason]);
		[self release];
		self = nil;
	}
	@finally {
		info(_interp, "[info globals]");
		info(_interp, "[info commands]");
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

- (NSString *)option:(NSString *)option
{
	const char *val = Tcl_GetVar(_interp, [option UTF8String], 0);
	return val ? [NSString stringWithUTF8String:val] : nil;
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
	} else if ([[_port procs] containsObject:command]) {
		// callback somewhere...
	} else if ([_port isTarget:command]) {
		// XXX: store for later use...
	} else {
		NSString *option;
		enum { OPTION_SET, OPTION_APPEND, OPTION_DELETE } action;
		if ([command hasSuffix:@"-append"]) {
			option = [command substringWithRange:NSMakeRange(0, [command length] - 7)];
			action = OPTION_APPEND;
		} else if ([command hasSuffix:@"-delete"]) {
			option = [command substringWithRange:NSMakeRange(0, [command length] - 7)];
			action = OPTION_DELETE;
		} else {
			option = command;
			action = OPTION_SET;
		}

		if (![[_port options] containsObject:option]) {
			NSLog(@"? %@", option);
		}

		// XXX: also need to skip if overridden on command line
		switch (action) {
		case OPTION_SET:
			Tcl_SetVar(_interp, [option UTF8String], [[args componentsJoinedByString:@" "] UTF8String], 0);
			break;
		case OPTION_APPEND: {
			Tcl_Obj *val = Tcl_GetVar2Ex(_interp, [option UTF8String], NULL, 0);
			int length;
			if (val == NULL) {
				val = Tcl_NewListObj(0, NULL);
				Tcl_SetVar2Ex(_interp, [option UTF8String], NULL, val, 0);
			}
			Tcl_ListObjLength(_interp, val, &length);
			for (NSString *arg in args) {
				Tcl_Obj *str = Tcl_NewStringObj([arg UTF8String], -1);
				Tcl_ListObjReplace(_interp, val, length++, 0, 1, &str);
			}
			break;
		}
		case OPTION_DELETE: {
			Tcl_Obj *val = Tcl_GetVar2Ex(_interp, [option UTF8String], NULL, 0);
			int objc;
			Tcl_Obj **objv;
			for (NSString *arg in args) {
				int i;
				Tcl_ListObjGetElements(_interp, val, &objc, &objv);
				for (i = 0; i < objc; i++) {
					if ([arg isEqualToString:[NSString stringWithTclObject:objv[i]]]) {
						Tcl_ListObjReplace(_interp, val, i, 1, 0, NULL);
						break; // just want to delete one occurrence
					}
				}
			}
			// XXX: unset if empty
			break;
		}
		default:
			abort();
			break;
		}
	}
}

@end

static int _nslog(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	NSArray *args = [[NSArray alloc] initWithTclObjects:++objv count:--objc];
	NSLog(@"%@", [args componentsJoinedByString:@" "]);
	[args release];

	return TCL_OK;
}

static int
_unknown(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	assert(objc >= 2);
	assert(!strcmp(Tcl_GetString(objv[0]), "::unknown"));

	NSArray *args = [[NSArray alloc] initWithTclObjects:++objv count:--objc];
	[(id)clientData performCommand:[args objectAtIndex:0] arguments:[args subarrayWithRange:NSMakeRange(1, [args count] - 1)]];
	[args release];

	return TCL_OK;
}

static char *
_default(ClientData clientData, Tcl_Interp *interp, const char *name1, const char *name2, int flags)
{
	assert(flags == TCL_TRACE_READS);
	assert(name2 == NULL);
	Tcl_SetVar(interp, name1, [[(id)clientData default:[NSString stringWithUTF8String:name1]] UTF8String], 0);
	return NULL;
}

// debugging
static void
info(Tcl_Interp *interp, const char *command)
{
	Tcl_Obj *result;
	int objc;
	Tcl_Obj **objv;

	Tcl_ExprObj(interp, Tcl_NewStringObj(command, -1), &result);
	Tcl_ListObjGetElements(interp, result, &objc, &objv);
	//NSLog(@"%@", [NSArray arrayWithTclObjects:objv count:objc]);
}
