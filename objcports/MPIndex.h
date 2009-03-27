@interface MPIndex : NSObject
{
	NSMutableDictionary *_storage;
}

- (id)initWithPortindex:(NSString *)portindex;

- (NSDictionary *)fullIndex;

@end
