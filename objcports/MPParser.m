#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPParser.h"
#include "MPArrayAdditions.h"
#include "MPStringAdditions.h"

static int _unknown(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static void info(Tcl_Interp *interp, const char *command); // debugging

@implementation MPParser

- (id)initWithPortfile:(NSString *)portfile
{
	self = [super init];
	_interp = Tcl_CreateInterp();

	// XXX: should probably remove even more functionality
	//Tcl_MakeSafe(_interp);

	@try {
		Tcl_Preserve(_interp);

		// XXX: need to do all setup here
		Tcl_SetVar(_interp, "prefix", "/opt/local", 0);
		Tcl_SetVar(_interp, "worksrcpath", "/tmp/", 0);

		Tcl_CreateObjCommand(_interp, "unknown", _unknown, self, NULL);
		if (Tcl_EvalFile(_interp, [portfile UTF8String]) != TCL_OK) {
			NSLog(@"Tcl_EvalFile(%@): %s", portfile, Tcl_GetStringResult(_interp));
		}

		Tcl_Release(_interp);
	}
	@catch (NSException *exception) {
		NSLog(@"%@: %@", [exception name], [exception reason]);
		[self release];
		self = nil;
	}
	@finally {
		info(_interp, "[info globals]");
		//info(_interp, "[info commands]");
	}

	return self;
}

- (void)dealloc
{
	Tcl_DeleteInterp(_interp);
	[super dealloc];
}

- (void)performCommand:(NSString *)command arguments:(NSArray *)args
{
	if ([command isEqualToString:@"PortSystem"]) {
		assert([args count] == 1);
		assert([[args objectAtIndex:0] isEqualToString:@"1.0"]);
	} else if ([command isEqualToString:@"PortGroup"]) {
		NSLog(@"ignoring %@, grps r hard m'kay", command);
	} else if ([command isEqualToString:@"platform"]) {
		NSUInteger count = [args count];
		NSString *os, *arch;
		NSInteger release;

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
		// XXX: check match, right now pretend all platforms are true
		if (YES) {
			NSLog(@"eval'ing target %@", platformFull);
			Tcl_Eval(_interp, [[args lastObject] UTF8String]);
		}
	} else if ([command isEqualToString:@"variant"]) {
		NSUInteger count = [args count];
		NSString *name;

		// variant name [a b c d] {}
		if (count < 2 || count % 2) {
			NSLog(@"bogus variant declaration");
			return;
		}

		name = [args objectAtIndex:0];

		// XXX: actually pull in its properties.. need to provide externally
		// also check for dupes (w/ platforms too)

		// XXX: make sure it's set, like platforms just pretend
		if (YES) {
			NSLog(@"eval'ing variant %@", name);
			Tcl_Eval(_interp, [[args lastObject] UTF8String]);
		}
	//} else if ([_targets containsObject:command]) {
		// XXX: right now we just treat target-related things like options
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

		//if ([_options containsObject:option]) {
			// XXX: also need to ignore if overriden on command line
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
		//} else {
		//	NSLog(@"unknown option %@", option);
		//}
	}
}

@end

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

// debugging
static void
info(Tcl_Interp *interp, const char *command)
{
	Tcl_Obj *result;
	int objc;
	Tcl_Obj **objv;

	Tcl_ExprObj(interp, Tcl_NewStringObj(command, -1), &result);
	Tcl_ListObjGetElements(interp, result, &objc, &objv);
	NSLog(@"%@", [NSArray arrayWithTclObjects:objv count:objc]);
}
