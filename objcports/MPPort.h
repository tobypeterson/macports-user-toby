@class MPParser;

@interface MPPort : NSObject
{
	NSString *_portfile;
	MPParser *_parser;

	NSMutableArray *_procs; 

	NSMutableArray *_targets;

	NSMutableArray *_commands;

	NSMutableDictionary *_options;
	NSMutableDictionary *_constants;
}

- (id)initWithPortfile:(NSString *)port options:(NSDictionary *)options;

- (NSString *)portfile;

- (NSArray *)procs;

- (BOOL)isTarget:(NSString *)target;

- (NSArray *)variables;
- (NSString *)variable:(NSString *)name;

- (void)option:(NSString *)option set:(NSArray *)value;
- (void)option:(NSString *)option append:(NSArray *)value;
- (void)option:(NSString *)option delete:(NSArray *)value;

// Access to underlying parser...
- (NSArray *)variants;
- (NSArray *)platforms;

@end
