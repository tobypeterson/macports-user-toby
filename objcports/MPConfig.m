#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPConfig.h"

NSDictionary *
MPCopyConfig()
{
	Tcl_Interp *interp;
	NSAutoreleasePool *pool;
	NSMutableDictionary *config;
	NSMutableArray *configFiles;
	char *s;

	pool = [NSAutoreleasePool new];

	configFiles = [NSMutableArray arrayWithCapacity:3];

	interp = Tcl_CreateInterp(); 
	if (interp && Tcl_EvalFile(interp, "/Library/Tcl/macports1.0/macports_autoconf.tcl") == TCL_OK) {
		NSString *tmp;
		tmp = [NSString stringWithUTF8String:Tcl_GetVar(interp, "macports::autoconf::macports_conf_path", 0)];
		[configFiles addObject:[[tmp stringByAppendingPathComponent:@"macports.conf"] stringByStandardizingPath]];
		tmp = [NSString stringWithUTF8String:Tcl_GetVar(interp, "macports::autoconf::macports_user_dir", 0)];
		[configFiles addObject:[[tmp stringByAppendingPathComponent:@"macports.conf"] stringByStandardizingPath]];
	}
	Tcl_DeleteInterp(interp);

	if ((s = getenv("PORTSRC"))) {
		[configFiles addObject:[[NSString stringWithUTF8String:s] stringByStandardizingPath]];
	}

	config = [[NSMutableDictionary alloc] initWithCapacity:0];

	for (NSString *configFile in configFiles) {
		NSString *file = [NSString stringWithContentsOfFile:configFile encoding:NSUTF8StringEncoding error:NULL];
		[file enumerateLinesUsingBlock:^(NSString *line, BOOL *stop __unused) {
			if ([line rangeOfCharacterFromSet:[NSCharacterSet lowercaseLetterCharacterSet]].location == 0) {
				NSString *key, *obj;
				NSRange ws;

				ws = [line rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
				if (ws.length == 1) {
					key = [line substringWithRange:NSMakeRange(0, ws.location)];
					obj = [[line substringWithRange:NSMakeRange(ws.location, [line length] - ws.location)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
				} else {
					key = line;
					obj = @"";
				}
				[config setObject:obj forKey:key];
			}
		}];
	}

	[pool drain];

	return config;
}
