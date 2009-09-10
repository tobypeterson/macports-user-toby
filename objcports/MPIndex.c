#include <CoreFoundation/CoreFoundation.h>
#include <tcl.h>

#include "MPIndex.h"
#include "MPArrayAdditions.h"
#include "MPDictionaryAdditions.h"
#include "MPStringAdditions.h"
#include "internal.h"

CFDictionaryRef
MPCopyPortIndex(CFStringRef filename)
{
	CFMutableDictionaryRef result = NULL;
	Tcl_Interp *interp;
	char *fn;
	Tcl_Channel chan;

	result = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

	interp = Tcl_CreateInterp();
	assert(Tcl_SetSystemEncoding(interp, "utf-8") == TCL_OK);
	fn = strdup_cf(filename);
	chan = Tcl_OpenFileChannel(interp, fn, "r", 0);
	free(fn);
	Tcl_RegisterChannel(interp, chan);

	while (1) {
		int objc;
		Tcl_Obj **objv;
		const void *key, *value;
		CFArrayRef info;
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
		info = CFArrayCreateWithTclObjects(NULL, objv, objc);
		assert(CFArrayGetCount(info) == 2);
		key = CFRetain(CFArrayGetValueAtIndex(info, 0));
		len = CFStringGetIntValue(CFArrayGetValueAtIndex(info, 1));
		CFRelease(info);

		/* Read dictionary. */
		Tcl_ReadChars(chan, line, len, 0);
		Tcl_ListObjGetElements(interp, line, &objc, &objv);
		value = CFDictionaryCreateWithTclObjects(NULL, objv, objc);
		assert(value != nil);

		/* Store data. */
		CFDictionarySetValue(result, key, value);
		CFRelease(key);
		CFRelease(value);

		Tcl_DecrRefCount(line);
	}

	Tcl_UnregisterChannel(interp, chan);
	Tcl_DeleteInterp(interp);

	return result;
}
