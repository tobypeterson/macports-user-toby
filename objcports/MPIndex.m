#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPIndex.h"
#include "cftcl.h"

struct NSData_channel_ctx {
	NSData *data;
	off_t offset;
};

static int
dataclose(ClientData instanceData, Tcl_Interp *interp)
{
	struct NSData_channel_ctx *ctx = (struct NSData_channel_ctx *)instanceData;

	[ctx->data release];
	free(ctx);

	return 0;
}

static int
datainput(ClientData instanceData, char *buf, int bufSize, int *errorCodePtr)
{
	struct NSData_channel_ctx *ctx = (struct NSData_channel_ctx *)instanceData;
	size_t bytes;

	bytes = MIN([ctx->data length] - ctx->offset, bufSize);

	memcpy(buf, [ctx->data bytes] + ctx->offset, bytes);
	ctx->offset += bytes;

	return (int)bytes;
}

static void
datawatch(ClientData instanceData, int mask)
{
	//printf("%s (%p %d)\n", __FUNCTION__, instanceData, mask);
}

static Tcl_ChannelType NSDataChannelType = {
	"NSData",				// typeName
	TCL_CHANNEL_VERSION_5,	// version
	dataclose,				// closeProc
	datainput,				// inputProc
	NULL,					// outputProc (maybe)
	NULL,					// seekProc
	NULL,					// setOptionProc
	NULL,					// getOptionProc
	datawatch,				// watchProc
	NULL,					// getHandleProc (maybe)
	NULL,					// close2Proc
	NULL,					// blockModeProc
	NULL,					// flushProc (2)
	NULL,					// handlerProc (2)
	NULL,					// wideSeekProc (3)
	NULL,					// threadActionProc (4)
	NULL,					// truncateProc (5)
};

Tcl_Channel
Tcl_CreateNSDataChannel(NSData *data)
{
	char *channel_name;
	Tcl_Channel channel = NULL;
	struct NSData_channel_ctx *ctx;

	if (data) {
		ctx = malloc(sizeof(*ctx));
		ctx->data = [data retain];
		ctx->offset = 0;

		asprintf(&channel_name, "%p", data);
		channel = Tcl_CreateChannel(&NSDataChannelType, channel_name, ctx, TCL_READABLE);
		free(channel_name);
	}

	return channel;
}

static NSMutableDictionary *
MPCopyPortIndex(NSData *data)
{
	NSMutableDictionary *result;
	Tcl_Interp *interp;
	Tcl_Channel chan;
	
	result = [[NSMutableDictionary alloc] initWithCapacity:0];
	
	interp = Tcl_CreateInterp();
	assert(Tcl_SetSystemEncoding(interp, "utf-8") == TCL_OK);
	
	chan = Tcl_CreateNSDataChannel(data);
	Tcl_RegisterChannel(interp, chan);
	
	for (;;) {
		int objc;
		Tcl_Obj **objv;
		Tcl_Obj *line;
		int len;
		NSString *key;
		NSDictionary *value;
		
		line = Tcl_NewObj();
		Tcl_IncrRefCount(line);
		
		/* Read info line. */
		if (Tcl_GetsObj(chan, line) < 0) {
			Tcl_DecrRefCount(line);
			break;
		}
		Tcl_ListObjGetElements(interp, line, &objc, &objv);
		assert(objc == 2);
		key = CFStringCreateWithTclObject(NULL, objv[0]);
		Tcl_GetIntFromObj(interp, objv[1], &len);
		
		/* Read dictionary. */
		Tcl_ReadChars(chan, line, len, 0);
		Tcl_ListObjGetElements(interp, line, &objc, &objv);
		value = CFDictionaryCreateWithTclObjects(NULL, objv, objc);
		assert(value);
		
		/* Store data. */
		[result setObject:value forKey:key];
		CFRelease(key);
		CFRelease(value);
		
		Tcl_DecrRefCount(line);
	}
	
	Tcl_UnregisterChannel(interp, chan);
	Tcl_DeleteInterp(interp);
	
	return result;
}

@implementation MPIndex

- (id)initWithSourceURL:(NSURL *)source
{
	NSError *error;
	NSData *data;

	self = [super init];

	_source = [source retain];

	data = [[NSData alloc] initWithContentsOfURL:[_source URLByAppendingPathComponent:@"PortIndex"] options:(NSDataReadingMapped | NSDataReadingUncached) error:&error];
	if (data) {
		_index = MPCopyPortIndex(data);
		[data release];
	} else {
		NSLog(@"%@", error);
	}

	return self;
}

- (void)dealloc
{
	[_source release];
	[_index release];
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %@>", [self class], _source];
}

@end
