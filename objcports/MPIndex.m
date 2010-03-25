#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPIndex.h"
#include "Tcl_NSDataChannel.h"
#include "nstcl.h"

static NSMutableDictionary *
MPCopyPortIndex(NSData *data)
{
	NSMutableDictionary *result;
	Tcl_Interp *interp;
	Tcl_Channel chan;

	result = [[NSMutableDictionary alloc] initWithCapacity:0];

	interp = Tcl_CreateInterp();
	Tcl_SetSystemEncoding(interp, "utf-8");

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
		key = [[NSString alloc] initWithTclObject:objv[0]];
		Tcl_GetIntFromObj(interp, objv[1], &len);

		/* Read dictionary. */
		Tcl_ReadChars(chan, line, len, 0);
		Tcl_ListObjGetElements(interp, line, &objc, &objv);
		value = [[NSDictionary alloc] initWithTclObjects:objv count:objc];
		assert(value);

		/* Store data. */
		[result setObject:value forKey:key];
		[key release];
		[value release];

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

- (NSDictionary *)index
{
	return _index;
}

@end
