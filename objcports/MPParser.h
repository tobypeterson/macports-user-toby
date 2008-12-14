@interface MPParser : NSObject
{
	Tcl_Interp *_interp;

	// set before parsing (list obtained elsewhere...)
	// actual values are stored inside the interpreter for now
	NSMutableArray *_options;

	// also set before parsing, from external list
	// remember that not every subcommand should be a target :)
	NSMutableArray *_targets;

	// information gathered during parsing, not stored in interpreter
	NSMutableDictionary *_variants;
	NSMutableArray *_platforms; // just a list, for dupe checking
}

- (id)initWithPortfile:(NSString *)portfile;

- (NSString *)option:(NSString *)option;
- (NSArray *)variants;
- (NSArray *)platforms;

@end
