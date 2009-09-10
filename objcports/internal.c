#include <CoreFoundation/CoreFoundation.h>

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
