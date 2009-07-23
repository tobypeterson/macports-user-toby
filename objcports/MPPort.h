@class MPParser;

@interface MPPort : NSObject
{
	NSURL *_url;

	NSMutableDictionary *_variableInfo;
	NSMutableDictionary *_variables;

	NSMutableArray *_platforms;
	NSMutableDictionary *_variants;

	Tcl_Interp *_interp;
}

- (id)initWithPath:(NSString *)url options:(NSDictionary *)options;
- (NSString *)variable:(NSString *)name;
- (NSArray *)definedVariants;
- (NSArray *)definedPlatforms;

@end
