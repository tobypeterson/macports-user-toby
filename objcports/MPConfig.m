#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPConfig.h"

static MPConfig *sharedConfigInstance = nil;

@interface MPConfig (priv)
- (NSString *)macportsConfPath;
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

	self = [super init];

	configFiles = [NSMutableArray arrayWithObject:[[self macportsConfPath] stringByAppendingPathComponent:@"macports.conf"]];
	for (NSString *f in configFiles) {
		NSLog(@"%@", f);
	}

	return self;
}

- (NSString *)macportsConfPath
{
	Tcl_Interp *interp;
	int rc;
	const char *path;
	NSString *result = nil;

	interp = Tcl_CreateInterp(); 
	rc = Tcl_EvalFile(interp, "/Library/Tcl/macports1.0/macports_autoconf.tcl");
	if (rc == 0) {
		path = Tcl_GetVar(interp, "macports::autoconf::macports_conf_path", 0);
		if (path) {
			result = [NSString stringWithUTF8String:path];
		}
	}
	Tcl_DeleteInterp(interp);

	return result;
}

@end
