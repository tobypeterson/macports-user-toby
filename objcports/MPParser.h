@interface MPParser : NSObject
{
	Tcl_Interp *_interp;
	NSMutableArray *_options;
}

- (id)initWithPortfile:(NSString *)portfile;

@end
