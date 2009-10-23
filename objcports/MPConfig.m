#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPConfig.h"
#include "internal.h"

static void
load_autoconf(NSMutableDictionary *config)
{
	Tcl_Interp *interp;
	int rc;
	CFStringRef tmp;
	
	interp = Tcl_CreateInterp(); 
	rc = Tcl_EvalFile(interp, "/Library/Tcl/macports1.0/macports_autoconf.tcl");
	if (rc == 0) {
		tmp = CFStringCreateWithCString(NULL, Tcl_GetVar(interp, "macports::autoconf::macports_conf_path", 0), kCFStringEncodingUTF8);
		if (tmp) {
			[config setObject:(NSString *)tmp forKey:@"macports_conf_path"];
			CFRelease(tmp);
		}

		tmp = CFStringCreateWithCString(NULL, Tcl_GetVar(interp, "macports::autoconf::macports_user_dir", 0), kCFStringEncodingUTF8);
		if (tmp) {
			[config setObject:(NSString *)tmp forKey:@"macports_user_dir"];
			CFRelease(tmp);
		}
	}
	Tcl_DeleteInterp(interp);
}

NSDictionary *
MPCopyConfig()
{
	NSAutoreleasePool *pool;
	NSMutableDictionary *config;
	NSMutableArray *configFiles;
	char *s;

	config = [[NSMutableDictionary alloc] initWithCapacity:0];
	
	pool = [NSAutoreleasePool new];
	
	load_autoconf(config);

	configFiles = [NSMutableArray arrayWithCapacity:3];
	[configFiles addObject:[[[config objectForKey:@"macports_conf_path"] stringByAppendingPathComponent:@"macports.conf"] stringByStandardizingPath]];
	[configFiles addObject:[[[config objectForKey:@"macports_user_dir"] stringByAppendingPathComponent:@"macports.conf"] stringByStandardizingPath]];
	if ((s = getenv("PORTSRC"))) {
		[configFiles addObject:[[NSString stringWithUTF8String:s] stringByStandardizingPath]];
	}

	for (NSString *configFile in configFiles) {
		NSString *file = [NSString stringWithContentsOfFile:configFile encoding:NSUTF8StringEncoding error:NULL];
		[file enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
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
