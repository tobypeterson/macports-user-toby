#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>

#include "internal.h"

char *
strdup_cf(CFStringRef str)
{
	CFIndex length, size;
	char *result;

	length = CFStringGetLength(str);
	size = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
	result = calloc(size, sizeof(char));
	if (result) {
		if (!CFStringGetCString(str, result, size, kCFStringEncodingUTF8)) {
			free(result);
			result = NULL;
		}
	}
	return result;
}

int
fprintf_cf(FILE *stream, const char *format, ...)
{
	va_list ap;
	CFStringRef formatstr, str;
	char *s;
	int rc;

	formatstr = CFStringCreateWithCString(NULL, format, kCFStringEncodingUTF8);
	
	va_start(ap, format);
	str = CFStringCreateWithFormatAndArguments(NULL, NULL, formatstr, ap);
	va_end(ap);

	s = strdup_cf(str);
	rc = fprintf(stream, "%s", s);
	free(s);

	CFRelease(str);
	CFRelease(formatstr);

	return rc;
}

void
CFArrayApplyBlock(CFArrayRef theArray, CFRange range, CFArrayApplierBlock applier)
{
	dispatch_queue_t apply_queue = dispatch_queue_create("CFArrayApplyBlock", NULL);
	const void *vals[range.length];
	CFArrayGetValues(theArray, range, vals);
	dispatch_apply(range.length, apply_queue, ^(size_t i) {
		applier(vals[i]);
	});
	dispatch_release(apply_queue);
}

void
CFArrayApplyBlock2(CFArrayRef theArray, CFArrayApplierBlock applier)
{
	CFArrayApplyBlock(theArray, CFRangeMake(0, CFArrayGetCount(theArray)), applier);
}

void
CFDictionaryApplyBlock(CFDictionaryRef theDict, CFDictionaryApplierBlock applier)
{
	dispatch_queue_t apply_queue = dispatch_queue_create("CFDictionaryApplyBlock", NULL);
	CFIndex count = CFDictionaryGetCount(theDict);
	const void *keys[count], *vals[count];
	CFDictionaryGetKeysAndValues(theDict, keys, vals);
	dispatch_apply(count, apply_queue, ^(size_t i) {
		applier(keys[i], vals[i]);
	});
	dispatch_release(apply_queue);
}
