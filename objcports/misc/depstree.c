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

	if ((result = (char *)CFStringGetCStringPtr(str, kCFStringEncodingUTF8))) {
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
fprintf_cf(FILE *stream, const char *format, ...)
{
	CFStringRef formatstr, str;
	va_list ap;
	char *output;
	int rc = -1;

	formatstr = CFStringCreateWithCString(NULL, format, kCFStringEncodingUTF8);

	va_start(ap, format);
	str = CFStringCreateWithFormatAndArguments(NULL, NULL, formatstr, ap);
	va_end(ap);

	CFRelease(formatstr);

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
			fprintf_cf(stdout, level ? "%@\n" : "Dependencies of %@:\n", output);
			CFRelease(output);
		}
	);
}

struct port_context_s {
	dispatch_queue_t queue;
	CFTreeRef tree;
	CFMutableArrayRef working;
};
typedef struct port_context_s *port_context_t;

CFStringRef
find_next(port_context_t portctx)
{
	__block CFStringRef result = NULL;

	dispatch_sync(portctx->queue, ^{
		traverse_tree(portctx->tree, TRAVERSE_POSTORDER, 0,
			^(CFTreeRef tree, CFIndex level __unused, Boolean *stop) {
				CFTreeContext context;
				__block int skip = 0;

				CFTreeGetContext(tree, &context);

				if (CFArrayContainsValue(portctx->working, CFRangeMake(0, CFArrayGetCount(portctx->working)), context.info)) {
					skip = 1;
				}
				if (CFTreeGetChildCount(tree)) {
					assert(skip == 0); // just in case
					skip = 1;
				}
				if (!skip) {
					CFArrayAppendValue(portctx->working, context.info);
					result = CFStringCreateCopy(NULL, context.info);
					*stop = 1;
				}
			}
		);
	});

	return result;
}

void
finish_port(port_context_t portctx, CFStringRef port)
{
	dispatch_sync(portctx->queue, ^{
		traverse_tree(portctx->tree, TRAVERSE_POSTORDER, 0,
			^(CFTreeRef tree, CFIndex level __unused, Boolean *stop __unused) {
				CFTreeContext context;
				CFTreeGetContext(tree, &context);
				if (CFStringCompare(context.info, port, 0) == kCFCompareEqualTo) {
					CFTreeRemove(tree);
				}
			}
		);
	});
}

void
build_port(CFTreeRef root, long jobs)
{
	port_context_t portctx;
	dispatch_semaphore_t sema;
	dispatch_queue_t print_queue;
	CFStringRef port;

	portctx = calloc(1, sizeof(*portctx));
	portctx->queue = dispatch_queue_create("port", NULL);
	portctx->tree = (CFTreeRef)CFRetain(root);
	portctx->working = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);

	sema = dispatch_semaphore_create(jobs);
	print_queue = dispatch_queue_create("CFShow", NULL);

	for (;;) {
		// limit concurrency to jobs
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

		// find_next does postorder tree traversal to find the next
		// "available" port - i.e. a port with no children that isn't
		// already being built
		port = find_next(portctx);

		if (port) {
			dispatch_async(dispatch_get_global_queue(0, 0), ^{
				// fake build
				fprintf_cf(stderr, "start %@\n", port);
				usleep(random() / 1000);
				fprintf_cf(stderr, "done %@\n", port);

				// finish_port removes all matching ports
				// from the build tree
				finish_port(portctx, port);

				CFRelease(port);
				dispatch_semaphore_signal(sema);
			});
		} else {
			// TODO: figure out a way to "recover concurrency" if we aren't able to find ports to build
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
