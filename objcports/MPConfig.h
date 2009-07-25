@interface MPConfig : NSObject
{
	NSMutableDictionary *_config;
}

+ (MPConfig *)sharedConfig;

@end
