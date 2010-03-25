@interface MPIndex : NSObject {
	NSURL *_source;
	NSMutableDictionary *_index;
}

- (id)initWithSourceURL:(NSURL *)source;
- (NSDictionary *)index;

@end
