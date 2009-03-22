@class MPParser;

@interface MPPort : NSObject
{
	NSString *_portfile;
	MPParser *_parser;

	NSMutableArray *_targets;

	NSMutableArray *_commands;

	NSMutableDictionary *_options;
	NSMutableDictionary *_constants;
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

// Access to underlying parser...
- (NSArray *)variants;
- (NSArray *)platforms;

@end
