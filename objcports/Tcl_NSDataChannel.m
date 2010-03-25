#include <Foundation/Foundation.h>
#include <tcl.h>

#include "Tcl_NSDataChannel.h"

struct NSDataChannel_ctx_s {
	NSData *data;
	off_t offset;
};
typedef struct NSDataChannel_ctx_s *NSDataChannel_ctx_t;

static int
NSDataChannel_close(ClientData instanceData, Tcl_Interp *interp __unused)
{
	NSDataChannel_ctx_t ctx = (NSDataChannel_ctx_t)instanceData;

	[ctx->data release];
	free(ctx);

	return 0;
}

static int
NSDataChannel_input(ClientData instanceData, char *buf, int bufSize, int *errorCodePtr __unused)
{
	NSDataChannel_ctx_t ctx = (NSDataChannel_ctx_t)instanceData;
	size_t bytes;

	bytes = [ctx->data length] - ctx->offset;
	if (bytes > (size_t)bufSize) {
		bytes = bufSize;
	}

	memcpy(buf, (char *)[ctx->data bytes] + ctx->offset, bytes);
	ctx->offset += bytes;

	return (int)bytes;
}

static void
NSDataChannel_watch(ClientData instanceData __unused, int mask __unused)
{
}

static Tcl_ChannelType NSDataChannelType = {
	"NSData",				// typeName
	TCL_CHANNEL_VERSION_5,	// version
	NSDataChannel_close,	// closeProc
	NSDataChannel_input,	// inputProc
	NULL,					// outputProc
	NULL,					// seekProc
	NULL,					// setOptionProc
	NULL,					// getOptionProc
	NSDataChannel_watch,	// watchProc
	NULL,					// getHandleProc
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
	NSDataChannel_ctx_t ctx;

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
