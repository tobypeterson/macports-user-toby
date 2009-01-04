@class MPParser;

@interface MPPort : NSObject
{
	NSString *_portfile;
	MPParser *_parser;

	NSMutableArray *_targets;

	NSMutableArray *_options;
	NSMutableArray *_defaults;
}

- (id)initWithPortfile:(NSString *)port options:(NSDictionary *)options;

- (NSString *)portfile;

- (NSArray *)targets;
- (BOOL)isTarget:(NSString *)target;

- (NSArray *)defaults;
- (NSString *)default:(NSString *)def;

- (NSArray *)options;

// Access to underlying parser...
- (NSString *)option:(NSString *)option;
- (NSArray *)variants;
- (NSArray *)platforms;

@end
