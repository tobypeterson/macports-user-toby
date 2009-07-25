#include <Foundation/Foundation.h>
#include <tcl.h>
#include <regex.h>

#include "MPConfig.h"

static MPConfig *sharedConfigInstance = nil;

@interface MPConfig (priv)
- (void)loadAutoconf;
@end

@implementation MPConfig

+ (MPConfig *)sharedConfig
{
	@synchronized (self) {
		if (sharedConfigInstance == nil) {
			[[self alloc] init];
		}
	}

	return sharedConfigInstance;
}

+ (id)allocWithZone:(NSZone *)zone
{
	@synchronized (self) {
		if (sharedConfigInstance == nil) {
			sharedConfigInstance = [super allocWithZone:zone];
			return sharedConfigInstance;
		}
	}
	return nil;
}

- (id)init
{
	NSMutableArray *configFiles;
	char *s;
	int rc;

	self = [super init];

	_config = [[NSMutableDictionary alloc] initWithCapacity:0];
	
	[self loadAutoconf];

	configFiles = [NSMutableArray arrayWithCapacity:0];
	[configFiles addObject:[[_config objectForKey:@"macports_conf_path"] stringByAppendingPathComponent:@"macports.conf"]];
	[configFiles addObject:[[_config objectForKey:@"macports_user_dir"] stringByAppendingPathComponent:@"macports.conf"]];
	if ((s = getenv("PORTSRC"))) {
		[configFiles addObject:[NSString stringWithUTF8String:s]];
	}

	regex_t re;
	rc = regcomp(&re, "^([A-Za-z_]+)([\\\t ]+(.*))?$", REG_EXTENDED);
	assert(rc == 0);
	assert(re.re_nsub == 3);
	for (NSString *f in configFiles) {
		size_t len;
		char *line;
		FILE *fp = fopen([f UTF8String], "r");
		if (fp == NULL) continue;
		while ((line = fgetln(fp, &len))) {
			regmatch_t match[4];
			line[len - 1] = '\0';
			rc = regexec(&re, line, 4, match, 0);
			if (rc == 0) {
				NSString *k, *v;
				k = [[NSString alloc] initWithBytes:&line[match[1].rm_so] length:(match[1].rm_eo - match[1].rm_so) encoding:NSUTF8StringEncoding];
				if (match[3].rm_so >= 0) {
					v = [[NSString alloc] initWithBytes:&line[match[3].rm_so] length:(match[3].rm_eo - match[3].rm_so) encoding:NSUTF8StringEncoding];
				} else {
					v = @"";
				}
				[_config setObject:v forKey:k];
			}
		}
		fclose(fp);
	}
	regfree(&re);

	NSLog(@"%@", _config);

	return self;
}

- (void)dealloc
{
	[_config release];
	[super dealloc];
}

- (void)loadAutoconf
{
	Tcl_Interp *interp;
	int rc;
	NSString *tmp;

	interp = Tcl_CreateInterp(); 
	rc = Tcl_EvalFile(interp, "/Library/Tcl/macports1.0/macports_autoconf.tcl");
	if (rc == 0) {
		[_config setObject:[NSString stringWithUTF8String:Tcl_GetVar(interp, "macports::autoconf::macports_conf_path", 0)] forKey:@"macports_conf_path"];
		tmp = [NSString stringWithUTF8String:Tcl_GetVar(interp, "macports::autoconf::macports_user_dir", 0)];
		tmp = [tmp stringByExpandingTildeInPath];
		if (tmp) {
			[_config setObject:tmp forKey:@"macports_user_dir"];
		}
	}
	Tcl_DeleteInterp(interp);
}

@end
