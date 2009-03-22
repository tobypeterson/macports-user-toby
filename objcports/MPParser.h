@class MPPort;

@interface MPParser : NSObject
{
	MPPort *_port;
	Tcl_Interp *_interp;
}

- (id)initWithPort:(MPPort *)port;

@end
