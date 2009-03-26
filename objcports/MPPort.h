@class MPParser;

@interface MPPort : NSObject
{
	NSString *_portfile;
	MPParser *_parser;

	NSMutableDictionary *_variableInfo;
	NSMutableDictionary *_variables;

	NSMutableArray *_platforms;
	NSMutableDictionary *_variants;
}

- (id)initWithPortfile:(NSString *)port options:(NSDictionary *)options;

- (NSString *)portfile;

- (NSArray *)targets;
- (BOOL)isTarget:(NSString *)target;

- (NSArray *)variables;
- (NSString *)variable:(NSString *)name;

- (NSArray *)settableVariables;
- (void)variable:(NSString *)var set:(NSArray *)value;

- (NSArray *)modifiableVariables;
- (void)variable:(NSString *)var append:(NSArray *)value;
- (void)variable:(NSString *)var delete:(NSArray *)value;

- (BOOL)addPlatform:(NSArray *)platform;
- (NSArray *)platforms;

- (BOOL)addVariant:(NSString *)variant properties:(NSDictionary *)props;
- (NSArray *)variants;

@end
