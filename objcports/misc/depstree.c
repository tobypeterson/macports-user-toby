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
	char *result;
	CFIndex length, size;

	if ((result = CFStringGetCStringPtr(str, kCFStringEncodingUTF8))) {
		result = strdup(result);
	} else {
		length = CFStringGetLength(str);
		size = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
		result = malloc(size);
		if (result) {
			if (!CFStringGetCString(str, result, size, kCFStringEncodingUTF8)) {
				free(result);
				result = NULL;
			}
		}
	}

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
	context.copyDescription = CFCopyDescription;
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

// percentage of nodes to visit before the root
typedef enum {
	TRAVERSE_PREORDER = 0,
	TRAVERSE_INORDER = 50,
	TRAVERSE_POSTORDER = 100,
} traverse_method_t;

typedef void (^traverse_handler_t)(CFTreeRef tree, CFIndex level, Boolean *stop);

Boolean
traverse_tree(CFTreeRef tree, traverse_method_t method, CFIndex level, traverse_handler_t handler)
{
	CFIndex i, count = CFTreeGetChildCount(tree), cutoff = (count * method) / 100;
	CFTreeRef children[count];
	Boolean stop = FALSE;

	CFTreeGetChildren(tree, children);

	for (i = 0; i < cutoff; i++) {
		stop = traverse_tree(children[i], method, level + 1, handler);
		if (stop) break;
	}
	if (!stop) handler(tree, level, &stop);
	if (!stop) {
		for (i = cutoff; i < count; i++) {
			stop = traverse_tree(children[i], method, level + 1, handler);
			if (stop) break;
		}
	}

	return stop;
}

static void __dead2
usage(void)
{
	fprintf(stderr, "usage: depstree port\n");
	exit(1);
}

void
print_deps(CFTreeRef root)
{
	traverse_tree(root, TRAVERSE_PREORDER, 0,
		^(CFTreeRef tree, CFIndex level, Boolean *stop __unused) {
			CFIndex i;
			CFMutableStringRef output;
			CFTreeContext context;

			output = CFStringCreateMutable(NULL, 0);
			for (i = 0; i < level; i++) {
				CFStringAppend(output, CFSTR("  "));
			}

			CFTreeGetContext(tree, &context);
			CFStringAppend(output, context.info);
			fprintf_cf(stdout, level ? CFSTR("%@\n") : CFSTR("Dependencies of %@:\n"), output);
			CFRelease(output);
		}
	);
}

void
build_port(CFTreeRef root, long jobs)
{
	dispatch_semaphore_t sema;
	dispatch_queue_t queue;
	dispatch_queue_t print_queue;
	CFMutableArrayRef working;
	__block int done = 0;
	__block CFStringRef port;
	CFStringRef tmp;

	// TODO: synchronize access to this
	working = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);

	sema = dispatch_semaphore_create(jobs);
	queue = dispatch_queue_create("lame queue", NULL);
	print_queue = dispatch_queue_create("CFShow", NULL);

	for (;;) {
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

		port = NULL;
		fprintf(stderr, "... find next\n");
		traverse_tree(root, TRAVERSE_POSTORDER, 0,
			^(CFTreeRef tree, CFIndex level __unused, Boolean *stop) {
				CFTreeContext context;
				__block int skip = 0;

				CFTreeGetContext(tree, &context);

				dispatch_sync(queue, ^{
					if (CFArrayContainsValue(working, CFRangeMake(0, CFArrayGetCount(working)), context.info)) {
						fprintf_cf(stderr, CFSTR("skip %@ (in progress / already built)\n"), context.info);
						skip = 1;
					}
					if (CFTreeGetChildCount(tree)) {
						fprintf_cf(stderr, CFSTR("skip %@ (blocked)\n"), context.info);
						skip = 1;
					}
					if (!skip) {
						fprintf_cf(stderr, CFSTR("+++ build %@\n"), context.info);
						CFArrayAppendValue(working, context.info);
						port = CFStringCreateCopy(NULL, context.info);
						*stop = 1;
					}
				});
			}
		);

		if (port) {
			tmp = CFStringCreateCopy(NULL, port);
			dispatch_async(dispatch_get_global_queue(0, 0), ^{
				fprintf_cf(stderr, CFSTR("start %@\n"), tmp);
				sleep(2);
				fprintf_cf(stderr, CFSTR("done %@\n"), tmp);
				dispatch_sync(queue, ^{
					traverse_tree(root, TRAVERSE_POSTORDER, 0,
						^(CFTreeRef xtree, CFIndex xlevel __unused, Boolean *xstop __unused) {
							CFTreeContext xcontext;
							CFTreeGetContext(xtree, &xcontext);
							if (CFStringCompare(xcontext.info, tmp, 0) == kCFCompareEqualTo) {
								CFTreeRemove(xtree);
							}
						}
					);
				});
				CFRelease(tmp);
				dispatch_semaphore_signal(sema);
			});
		} else {
			fprintf(stderr, "lost\n");
		}
	}
}

int
main(int argc, char *argv[])
{
	int ch;
	CFStringRef port;
	CFTreeRef tree;
	long jobs;

	while ((ch = getopt(argc, argv, "")) != -1) {
		switch (ch) {
		default:
			usage();
			break;
		}
	}

	argc -= optind;
	argv += optind;

	if (argc < 1) {
		usage();
	}

	port = CFStringCreateWithCString(NULL, argv[0], kCFStringEncodingUTF8);
	tree = create_port_tree(port);
	CFRelease(port);

	if (argc < 2) {
		print_deps(tree);
	} else {
		jobs = strtol(argv[1], NULL, 0);
		if (!jobs) jobs = 2;
		build_port(tree, jobs);
	}
	CFRelease(tree);

	return 0;
}
