@class MPParser;

@interface MPPort : NSObject
{
	NSString *_portfile;
	MPParser *_parser;
}

- (id)initWithPortfile:(NSString *)port options:(NSDictionary *)options;

- (NSString *)portfile;

- (NSArray *)defaults;
- (NSString *)default:(NSString *)def;

- (NSString *)option:(NSString *)option;
- (NSArray *)variants;
- (NSArray *)platforms;

@end
