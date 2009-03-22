@class MPPort;

@interface MPParser : NSObject
{
	MPPort *_port;
	Tcl_Interp *_interp;

	// information gathered during parsing, not stored in interpreter
	NSMutableDictionary *_variants;
	NSMutableArray *_platforms; // just a list, for dupe checking
}

- (id)initWithPort:(MPPort *)port;

- (NSArray *)variants;
- (NSArray *)platforms;

@end
