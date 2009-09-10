#include <CoreFoundation/CoreFoundation.h>
#include <tcl.h>
#include <regex.h>

#include "MPConfig.h"
#include "internal.h"

static void
load_autoconf(CFMutableDictionaryRef config)
{
	Tcl_Interp *interp;
	int rc;
	CFStringRef tmp;
	
	interp = Tcl_CreateInterp(); 
	rc = Tcl_EvalFile(interp, "/Library/Tcl/macports1.0/macports_autoconf.tcl");
	if (rc == 0) {
		tmp = CFStringCreateWithCString(NULL, Tcl_GetVar(interp, "macports::autoconf::macports_conf_path", 0), kCFStringEncodingUTF8);
		if (tmp) {
			CFDictionarySetValue(config, CFSTR("macports_conf_path"), tmp);
			CFRelease(tmp);
		}

		tmp = CFStringCreateWithCString(NULL, Tcl_GetVar(interp, "macports::autoconf::macports_user_dir", 0), kCFStringEncodingUTF8);
		if (tmp) {
			CFDictionarySetValue(config, CFSTR("macports_user_dir"), tmp);
			CFRelease(tmp);
		}
	}
	Tcl_DeleteInterp(interp);
}

CFDictionaryRef
MPCopyConfig()
{
	CFMutableDictionaryRef config = NULL;
	CFMutableArrayRef configFiles;
	CFStringRef tmp;
	CFIndex i, count;
	char *s;
	int rc;

	config = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	
	load_autoconf(config);

	configFiles = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);

	// XXX: should probably construct path intelligently
	tmp = CFStringCreateWithFormat(NULL, NULL, CFSTR("%@/macports.conf"), CFDictionaryGetValue(config, CFSTR("macports_conf_path")));
	CFArrayAppendValue(configFiles, tmp);
	CFRelease(tmp);

#if 0
	// XXX: need to expand macports_user_dir
	tmp = CFStringCreateWithFormat(NULL, NULL, CFSTR("%@/macports.conf"), CFDictionaryGetValue(config, CFSTR("macports_user_dir")));
	CFArrayAppendValue(configFiles, tmp);
	CFRelease(tmp);
#endif

	if ((s = getenv("PORTSRC"))) {
		tmp = CFStringCreateWithCString(NULL, s, kCFStringEncodingUTF8);
		CFArrayAppendValue(configFiles, tmp);
		CFRelease(tmp);
	}

	regex_t re;
	rc = regcomp(&re, "^([A-Za-z_]+)([\\\t ]+(.*))?$", REG_EXTENDED);
	assert(rc == 0);
	assert(re.re_nsub == 3);
	count = CFArrayGetCount(configFiles);
	for (i = 0; i < count; i++) {
		char *f;
		size_t len;
		char *line;
		FILE *fp;
		f = strdup_cf(CFArrayGetValueAtIndex(configFiles, i));
		fp = fopen(f, "r");
		free(f);
		if (fp == NULL) continue;
		while ((line = fgetln(fp, &len))) {
			regmatch_t match[4];
			line[len - 1] = '\0';
			rc = regexec(&re, line, 4, match, 0);
			if (rc == 0) {
				const void *key, *value;
				key = CFStringCreateWithBytes(NULL, (UInt8 *)&line[match[1].rm_so], match[1].rm_eo - match[1].rm_so, kCFStringEncodingUTF8, FALSE);
				if (match[3].rm_so >= 0) {
					value = CFStringCreateWithBytes(NULL, (UInt8 *)&line[match[3].rm_so], match[3].rm_eo - match[3].rm_so, kCFStringEncodingUTF8, FALSE);
				} else {
					value = CFSTR("");
				}
				CFDictionarySetValue(config, key, value);
				CFRelease(key);
				CFRelease(value);
			}
		}
		fclose(fp);
	}
	regfree(&re);

	CFRelease(configFiles);

	return config;
}
