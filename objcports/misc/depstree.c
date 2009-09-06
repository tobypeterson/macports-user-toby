#include <CoreFoundation/CoreFoundation.h>
#include <getopt.h>
#include <tcl.h>

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
	int rc = -1;

	va_start(ap, format);
	str = CFStringCreateWithFormatAndArguments(NULL, NULL, format, ap);
	va_end(ap);

	output = strdup_cf(str);
	CFRelease(str);
	rc = fprintf(stream, "%s", output);
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
find_deps(CFStringRef port)
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

static CFTreeRef
create_port_tree(CFStringRef port)
{
	CFTreeRef tree, child;
	CFTreeContext context;
	CFArrayRef deps;
	CFIndex i, count;

	bzero(&context, sizeof(context));
	context.info = (void *)port;
	context.retain = CFRetain;
	context.release = CFRelease;
	tree = CFTreeCreate(NULL, &context);

	deps = find_deps(port);
	count = CFArrayGetCount(deps);
	for (i = 0; i < count; i++) {
		child = create_port_tree(CFArrayGetValueAtIndex(deps, i));
		CFTreeAppendChild(tree, child);
		CFRelease(child);
	}
	CFRelease(deps);

	return tree;
}

static void
dump_tree(CFTreeRef tree, CFIndex indent)
{
	CFIndex i, count;
	CFMutableStringRef output;
	CFTreeContext context;

	output = CFStringCreateMutable(NULL, 0);
	for (i = 0; i < indent; i++) {
		CFStringAppend(output, CFSTR("  "));
	}

	CFTreeGetContext(tree, &context);
	CFStringAppend(output, context.info);
	fprintf_cf(stdout, indent ? CFSTR("%@\n") : CFSTR("Dependencies of %@:\n"), output);
	CFRelease(output);

	count = CFTreeGetChildCount(tree);
	for (i = 0; i < count; i++) {
		dump_tree(CFTreeGetChildAtIndex(tree, i), indent + 1);
	}
}

static void __dead2
usage(void)
{
	fprintf(stderr, "usage: depstree port\n");
	exit(1);
}

int
main(int argc, char *argv[])
{
	int ch;
	CFStringRef port;
	CFTreeRef tree;

	while ((ch = getopt(argc, argv, "")) != -1) {
		switch (ch) {
		default:
			usage();
			break;
		}
	}

	argc -= optind;
	argv += optind;

	if (argc != 1) {
		usage();
	}

	port = CFStringCreateWithCString(NULL, argv[0], kCFStringEncodingUTF8);
	tree = create_port_tree(port);
	CFRelease(port);
	dump_tree(tree, 0);
	CFRelease(tree);

	return 0;
}
