@class MPParser;

@interface MPPort : NSObject
{
	NSString *_portfile;
	MPParser *_parser;

	NSMutableDictionary *_options;
	NSMutableDictionary *_constants;

	NSMutableArray *_platforms;
	NSMutableDictionary *_variants;
}

- (id)initWithPortfile:(NSString *)port options:(NSDictionary *)options;

- (NSString *)portfile;

- (NSArray *)targets;
- (BOOL)isTarget:(NSString *)target;

- (NSArray *)variables;
- (NSString *)variable:(NSString *)name;

- (NSArray *)options;
- (void)option:(NSString *)option set:(NSArray *)value;
- (void)option:(NSString *)option append:(NSArray *)value;
- (void)option:(NSString *)option delete:(NSArray *)value;

- (BOOL)addPlatform:(NSString *)platform;
- (NSArray *)platforms;

- (BOOL)addVariant:(NSString *)variant properties:(NSDictionary *)props;
- (NSArray *)variants;

@end
