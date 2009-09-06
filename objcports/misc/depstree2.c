/*
 * Copyright (c) 2009 Toby Peterson <toby@macports.org>. All rights reserved.
 */

#include <CoreFoundation/CoreFoundation.h>
#include <tcl.h>
#include <unistd.h>

CFStringRef
CFStringCreateWithTclObject(CFAllocatorRef allocator, Tcl_Obj *obj)
{
	return CFStringCreateWithCString(allocator, Tcl_GetString(obj), kCFStringEncodingUTF8);
}

CFArrayRef
CFArrayCreateTcl(CFAllocatorRef allocator, Tcl_Obj **objects, CFIndex count)
{
	CFIndex i;
	CFStringRef array[count];
	CFArrayRef result;

	for (i = 0; i < count; i++) {
		array[i] = CFStringCreateWithTclObject(allocator, objects[i]);
	}
	result = CFArrayCreate(allocator, (const void **)array, count, &kCFTypeArrayCallBacks);
	for (i = 0; i < count; i++) {
		CFRelease(array[i]);
	}
	return result;
}

char *
strdup_cf(CFStringRef str)
{
	CFIndex length, size;
	char *result = NULL;

	length = CFStringGetLength(str);
	size = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
	result = malloc(size);
	CFStringGetCString(str, result, size, kCFStringEncodingUTF8);

	return result;
}

int
fprintf_cf(FILE *stream, CFStringRef format, ...)
{
	va_list ap;
	CFStringRef str;
	char *output;
	__block int rc = -1;

	static dispatch_once_t once;
	static dispatch_queue_t pqueue;

	dispatch_once(&once, ^{
		pqueue = dispatch_queue_create(NULL, NULL);
	});

	va_start(ap, format);
	str = CFStringCreateWithFormatAndArguments(NULL, NULL, format, ap);
	va_end(ap);

	output = strdup_cf(str);
	CFRelease(str);
	dispatch_sync(pqueue, ^{
		rc = fprintf(stream, "%s", output);
	});
	free(output);

	return rc;
}

CFDictionaryRef
copy_indexentry(Tcl_Interp *interp, Tcl_Obj **objects, CFIndex count)
{
	CFDictionaryRef result = NULL;
	CFIndex i;
	CFIndex count2 = count / 2;
	CFStringRef keys[count2];
	CFTypeRef values[count2];

	for (i = 0; i < count2; i++) {
		keys[i] = CFStringCreateWithTclObject(NULL, objects[i * 2]);
		if (CFStringHasPrefix(keys[i], CFSTR("depends_"))) {
			int objc;
			Tcl_Obj **objv;
			Tcl_ListObjGetElements(interp, objects[i * 2 + 1], &objc, &objv);
			values[i] = CFArrayCreateTcl(NULL, objv, objc);
		} else {
			values[i] = CFStringCreateWithTclObject(NULL, objects[i * 2 + 1]);
		}
	}
	result = CFDictionaryCreate(NULL, (const void **)keys, values, count2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	for (i = 0; i < count2; i++) {
		CFRelease(keys[i]);
		CFRelease(values[i]);
	}

	return result;
}

CFDictionaryRef
get_portindex()
{
	static CFMutableDictionaryRef dict;
	Tcl_Interp *interp;
	Tcl_Channel chan;

	if (dict) {
		return dict;
	}

	dict = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

	interp = Tcl_CreateInterp();
	assert(Tcl_SetSystemEncoding(interp, "utf-8") == TCL_OK);
	chan = Tcl_OpenFileChannel(interp, "/Volumes/data/source/macports/dports/PortIndex", "r", 0);
	Tcl_RegisterChannel(interp, chan);

	while (1) {
		int objc;
		Tcl_Obj **objv;
		CFTypeRef key, value;
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
		info = CFArrayCreateTcl(NULL, objv, objc);
		assert(CFArrayGetCount(info) == 2);
		key = CFRetain(CFArrayGetValueAtIndex(info, 0));
		len = CFStringGetIntValue(CFArrayGetValueAtIndex(info, 1));
		CFRelease(info);

		/* Read dictionary. */
		Tcl_ReadChars(chan, line, len, 0);
		Tcl_ListObjGetElements(interp, line, &objc, &objv);
		value = copy_indexentry(interp, objv, objc);
		assert(value != nil);

		/* Store data. */
		CFDictionarySetValue(dict, key, value);

		CFRelease(key);
		CFRelease(value);

		Tcl_DecrRefCount(line);
	}

	Tcl_UnregisterChannel(interp, chan);
	Tcl_DeleteInterp(interp);

	return dict;
}

static CFStringRef deptypes[] = {
	CFSTR("depends_build"),
	CFSTR("depends_lib"),
	CFSTR("depends_run"),
};

CFArrayRef
copy_deps(CFStringRef port)
{
	CFDictionaryRef info;
	CFMutableArrayRef deps;
	CFArrayRef tmp, split;
	CFIndex i, j, count;

	deps = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);

	info = CFDictionaryGetValue(get_portindex(), port);

	for (i = 0; i < 3; i++) {
		tmp = CFDictionaryGetValue(info, deptypes[i]);
		if (!tmp) continue;
		count = CFArrayGetCount(tmp);
		for (j = 0; j < count; j++) {
			split = CFStringCreateArrayBySeparatingStrings(NULL, CFArrayGetValueAtIndex(tmp, j), CFSTR(":"));
			CFArrayAppendValue(deps, CFArrayGetValueAtIndex(split, CFArrayGetCount(split) - 1));
			CFRelease(split);
		}
	}

	return deps;
}

static Boolean
skip_port(CFStringRef port, dispatch_group_t *group)
{
	static CFMutableDictionaryRef built;
	static dispatch_queue_t built_queue;
	static dispatch_once_t once;
	__block Boolean skip = TRUE;

	dispatch_once(&once, ^{
		built_queue = dispatch_queue_create(NULL, NULL);
		dispatch_sync(built_queue, ^{
			built = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
		});
	});

	dispatch_sync(built_queue, ^{
		if (!CFDictionaryContainsKey(built, port)) {
			skip = FALSE;
			*group = dispatch_group_create();
			CFDictionarySetValue(built, port, *group);
		} else {
			skip = TRUE;
			*group = (dispatch_group_t)CFDictionaryGetValue(built, port);
		}
	});

	return skip;
}

static void
build_port(CFStringRef port, CFIndex indent)
{
	CFMutableStringRef output;
	CFIndex j;
	dispatch_group_t group;

	if (skip_port(port, &group)) {
		dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
		return;
	}

	dispatch_group_enter(group);

	output = CFStringCreateMutable(NULL, 0);
	for (j = 0; j < indent; j++) {
		CFStringAppend(output, CFSTR("  "));
	}
	CFStringAppend(output, port);
	fprintf_cf(stdout, CFSTR("building %@\n"), output);

	// fake it
	usleep(random() / 700);

	fprintf_cf(stdout, CFSTR("    done %@\n"), output);

	CFRelease(output);

	dispatch_group_leave(group);
	// TODO: leaking this, not sure where to release it
	//dispatch_release(group);
}

static void
build_port_tree(CFStringRef port, CFIndex indent)
{
	dispatch_group_t group;
	CFArrayRef deps;
	CFIndex count;

	deps = copy_deps(port);
	count = CFArrayGetCount(deps);

	group = dispatch_group_create();

	if (count) {
		dispatch_apply(count, dispatch_get_global_queue(0, 0), ^(size_t i) {
			dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
				build_port_tree(CFArrayGetValueAtIndex(deps, i), indent + 1);
			});
		});
		dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
		CFRelease(deps);

		build_port(port, indent);
	} else {
		build_port(port, indent);
	}
}

int
main(int argc, char *argv[])
{
	CFStringRef port;

	if (argc != 2) {
		fprintf(stderr, "usage: depstree port\n");
		exit(1);
	}

	srandom(time(NULL));

	port = CFStringCreateWithCString(NULL, argv[1], kCFStringEncodingUTF8);
	build_port_tree(port, 0);
	CFRelease(port);

	dispatch_main();

	return 0;
}
