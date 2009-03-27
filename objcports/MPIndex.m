#include <Foundation/Foundation.h>
#include <tcl.h>

#include "MPIndex.h"
#include "MPArrayAdditions.h"
#include "MPDictionaryAdditions.h"
#include "MPStringAdditions.h"

static NSDictionary *
CopyIndexEntryFromTclList(Tcl_Interp *interp, Tcl_Obj **objects, int count)
{
	int count2, i;
	NSDictionary *result = nil;

	if ((count % 2) != 0) {
		return nil;
	}

	count2 = count / 2;

	NSString *keys[count2];
	id objs[count2];
	for (i = 0; i < count2; i++) {
		keys[i] = [[NSString alloc] initWithTclObject:objects[i * 2]];
		if ([keys[i] isEqualToString:@"variant_desc"]) {
			int objc;
			Tcl_Obj **objv;
			Tcl_ListObjGetElements(interp, objects[i * 2 + 1], &objc, &objv);
			objs[i] = [[NSDictionary alloc] initWithTclObjects:objv count:objc];
		} else if ([keys[i] isEqualToString:@"categories"] || [keys[i] isEqualToString:@"maintainers"] || [keys[i] isEqualToString:@"platforms"] || [keys[i] isEqualToString:@"variants"]) {
			int objc;
			Tcl_Obj **objv;
			Tcl_ListObjGetElements(interp, objects[i * 2 + 1], &objc, &objv);
			objs[i] = [[NSArray alloc] initWithTclObjects:objv count:objc];
		} else {
			objs[i] = [[NSString alloc] initWithTclObject:objects[i * 2 + 1]];
		}
	}
	result = [[NSDictionary alloc] initWithObjects:objs forKeys:keys count:count2];
	for (i = 0; i < count2; i++) {
		[keys[i] release];
		[objs[i] release];
	}
	return result;
}

@implementation MPIndex

- (id)initWithPortindex:(NSString *)portindex
{
	Tcl_Interp *interp;
	Tcl_Channel chan;

	self = [super init];

	_storage = [[NSMutableDictionary alloc] initWithCapacity:0];

	interp = Tcl_CreateInterp();
	assert(Tcl_SetSystemEncoding(interp, "utf-8") == TCL_OK);
	chan = Tcl_OpenFileChannel(interp, [portindex UTF8String], "r", 0);
	Tcl_RegisterChannel(interp, chan);

	while (1) {
		int objc;
		Tcl_Obj **objv;
		id key, object;
		NSArray *info;
		Tcl_Obj *line;
		int len;

		line = Tcl_NewObj();
		Tcl_IncrRefCount(line);

		/* Read info line. */
		if (Tcl_GetsObj(chan, line) < 0) {
			Tcl_DecrRefCount(line);
			break;
		}
		Tcl_ListObjGetElements(interp, line, &objc, &objv);
		info = [[NSArray alloc] initWithTclObjects:objv count:objc];
		assert([info count] == 2);
		key = [[info objectAtIndex:0] retain];
		len = [[info objectAtIndex:1] intValue];
		[info release];

		/* Read dictionary. */
		Tcl_ReadChars(chan, line, len, 0);
		Tcl_ListObjGetElements(interp, line, &objc, &objv);
		object = CopyIndexEntryFromTclList(interp, objv, objc);
		assert(object != nil);

		/* Store data. */
		[_storage setObject:object forKey:key];
		[object release];
		[key release];

		Tcl_DecrRefCount(line);
	}

	Tcl_UnregisterChannel(interp, chan);
	Tcl_DeleteInterp(interp);

	return self;
}

- (void)dealloc
{
	[_storage release];
	[super dealloc];
}

@end
