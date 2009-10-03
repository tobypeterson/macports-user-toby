#include <CoreFoundation/CoreFoundation.h>
#include <tcl.h>
#include <sys/utsname.h>
#include <mach-o/getsect.h>

#include "MPPort.h"
#include "cftcl.h"
#include "internal.h"

struct mp_port_s {
	CFURLRef _url;
	
	CFMutableDictionaryRef _variableInfo;
	CFMutableDictionaryRef _variables;
	
	CFMutableArrayRef _platforms;
	CFMutableDictionaryRef _variants;
	
	Tcl_Interp *_interp;
};

static CFStringRef kPortVariableType = CFSTR("Type");
static CFStringRef kPortVariableConstant = CFSTR("Constant");
static CFStringRef kPortVariableDefault = CFSTR("Default");
static CFStringRef kPortVariableCallback = CFSTR("Callback");

static void command_create(Tcl_Interp *interp, const char *cmdName, ClientData clientData);
static void command_create_cf(Tcl_Interp *interp, CFStringRef cmdName, ClientData clientData);
static char *variable_read(ClientData clientData, Tcl_Interp *interp, const char *name1, const char *name2, int flags);
static int _nslog(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int _fake_boolean(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);

static CFStringRef mp_port_portfile(mp_port_t);
static CFArrayRef mp_port_targets(mp_port_t);
static CFArrayRef mp_port_variables(mp_port_t);
static CFArrayRef mp_port_settable_variables(mp_port_t);
static CFArrayRef mp_port_settable_array_variables(mp_port_t);

static Boolean mp_port_variable_is_array(mp_port_t, CFStringRef var);

void mp_port_variable_set(mp_port_t, CFStringRef, CFArrayRef);
void mp_port_variable_append(mp_port_t, CFStringRef, CFArrayRef);
void mp_port_variable_delete(mp_port_t, CFStringRef, CFArrayRef);

Boolean mp_port_test_and_record_platform(mp_port_t, CFArrayRef);
Boolean mp_port_test_and_record_variant(mp_port_t, CFStringRef, CFDictionaryRef);

void mp_port_perform_command(mp_port_t, CFArrayRef);

// essentially 'commands' from portutil.tcl
static void
add_command_var(CFMutableDictionaryRef varinfo, CFStringRef command)
{
	CFDictionaryRef emptydict;
	CFMutableDictionaryRef arraydict;

	emptydict = CFDictionaryCreate(NULL, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	arraydict = CFDictionaryCreateMutable(NULL, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	CFDictionarySetValue(arraydict, kPortVariableType, CFSTR("Array"));

	void (^addcomm_block)(CFStringRef, CFDictionaryRef) = ^(CFStringRef format, CFDictionaryRef dict) {
		CFStringRef tmp;

		tmp = CFStringCreateWithFormat(NULL, NULL, format, command);
		CFDictionarySetValue(varinfo, tmp, dict);
		CFRelease(tmp);
	};

	addcomm_block(CFSTR("use_%@"), emptydict);
	addcomm_block(CFSTR("%@.dir"), emptydict);
	addcomm_block(CFSTR("%@.pre_args"), arraydict);
	addcomm_block(CFSTR("%@.args"), arraydict);
	addcomm_block(CFSTR("%@.post_args"), arraydict);
	addcomm_block(CFSTR("%@.env"), arraydict);
	addcomm_block(CFSTR("%@.type"), emptydict);
	addcomm_block(CFSTR("%@.cmd"), arraydict);

	CFRelease(emptydict);
	CFRelease(arraydict);
}

static CFMutableDictionaryRef
_copy_variable_info(void)
{
	char *sectdata;
	unsigned long sectsize;
	CFDataRef data;
	CFMutableDictionaryRef result;

	sectdata = getsectdata("MacPorts", "variables", &sectsize);
	assert(sectdata);

	data = CFDataCreateWithBytesNoCopy(NULL, (UInt8 *)sectdata, sectsize, kCFAllocatorNull);
	result = (CFMutableDictionaryRef)CFPropertyListCreateWithData(NULL, data, kCFPropertyListMutableContainersAndLeaves, NULL, NULL);
	CFRelease(data);

	return result;
}

mp_port_t
mp_port_create(CFURLRef url, CFDictionaryRef options)
{
	mp_port_t port;

	port = calloc(1, sizeof(struct mp_port_s));

	port->_url = CFRetain(url);

	port->_platforms = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
	port->_variants = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

	port->_variables = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

	port->_variableInfo = _copy_variable_info();

	add_command_var(port->_variableInfo, CFSTR("cvs")); // portfetch.tcl
	add_command_var(port->_variableInfo, CFSTR("svn")); // portfetch.tcl
	add_command_var(port->_variableInfo, CFSTR("extract")); // portextract.tcl
	add_command_var(port->_variableInfo, CFSTR("patch")); // portpatch.tcl
	add_command_var(port->_variableInfo, CFSTR("configure")); // portconfigure.tcl
	add_command_var(port->_variableInfo, CFSTR("autoreconf")); // portconfigure.tcl
	add_command_var(port->_variableInfo, CFSTR("automake")); // portconfigure.tcl
	add_command_var(port->_variableInfo, CFSTR("autoconf")); // portconfigure.tcl
	add_command_var(port->_variableInfo, CFSTR("xmkmf")); // portconfigure.tcl
	add_command_var(port->_variableInfo, CFSTR("build")); // portbuild.tcl
	add_command_var(port->_variableInfo, CFSTR("test")); // porttest.tcl
	add_command_var(port->_variableInfo, CFSTR("destroot")); // portdestroot.tcl

	port->_interp = Tcl_CreateInterp();
	Tcl_MakeSafe(port->_interp);
	Tcl_UnsetVar(port->_interp, "tcl_version", 0);
	Tcl_UnsetVar(port->_interp, "tcl_patchLevel", 0);
	Tcl_UnsetVar(port->_interp, "tcl_platform", 0);
	Tcl_DeleteCommand(port->_interp, "tell");
	Tcl_DeleteCommand(port->_interp, "eof");
	// XXX: etc?

	do {
		CFArrayRef tmparr;

		Tcl_Preserve(port->_interp);
		
		Tcl_CreateObjCommand(port->_interp, "nslog", _nslog, NULL, NULL); // XXX: debugging
		//Tcl_Eval(_interp, "nslog [info commands]");
		
		command_create(port->_interp, "PortSystem", port);
		command_create(port->_interp, "PortGroup", port);
		command_create(port->_interp, "platform", port);
		command_create(port->_interp, "variant", port);

		tmparr = mp_port_targets(port);
		CFArrayApplyBlock2(tmparr, ^(const void *target) {
			CFStringRef tmp;

			command_create_cf(port->_interp, target, port);

			tmp = CFStringCreateWithFormat(NULL, NULL, CFSTR("pre-%@"), target);
			command_create_cf(port->_interp, tmp, port);
			CFRelease(tmp);

			tmp = CFStringCreateWithFormat(NULL, NULL, CFSTR("post-%@"), target);
			command_create_cf(port->_interp, tmp, port);
			CFRelease(tmp);
		});
		CFRelease(tmparr);

		tmparr = mp_port_settable_variables(port);
		CFArrayApplyBlock2(tmparr, ^(const void *opt) {
			command_create_cf(port->_interp, opt, port);
		});
		CFRelease(tmparr);

		tmparr = mp_port_settable_array_variables(port);
		CFArrayApplyBlock2(tmparr, ^(const void *opt) {
			CFStringRef tmp;

			tmp = CFStringCreateWithFormat(NULL, NULL, CFSTR("%@-append"), opt);
			command_create_cf(port->_interp, tmp, port);
			CFRelease(tmp);

			tmp = CFStringCreateWithFormat(NULL, NULL, CFSTR("%@-delete"), opt);
			command_create_cf(port->_interp, tmp, port);
			CFRelease(tmp);
		});
		CFRelease(tmparr);
		
		tmparr = mp_port_variables(port);
		CFArrayApplyBlock2(tmparr, ^(const void *var) {
			char *s = strdup_cf(var);
			Tcl_TraceVar(port->_interp, s, TCL_TRACE_READS, variable_read, port);
			free(s);
		});
		CFRelease(tmparr);
		
		// bogus targets
		Tcl_CreateObjCommand(port->_interp, "pre-activate", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "post-activate", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "pre-install", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "post-install", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "post-pkg", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "post-mpkg", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "archive", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "install", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "activate", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "unarchive", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "post-clean", _nslog, NULL, NULL); // XXX: debugging
		
		// functions we need to provide (?)
		Tcl_CreateObjCommand(port->_interp, "variant_isset", _fake_boolean, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "variant_set", _fake_boolean, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "tbool", _fake_boolean, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "strsed", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "suffix", _nslog, NULL, NULL); // XXX: debugging
		Tcl_CreateObjCommand(port->_interp, "include", _nslog, NULL, NULL); // XXX: debugging
		
		// variables that should be constant
		Tcl_CreateObjCommand(port->_interp, "prefix", _nslog, NULL, NULL);
		
		CFStringRef pf = mp_port_portfile(port);
		char *s = strdup_cf(pf);
		if (Tcl_EvalFile(port->_interp, s) != TCL_OK) {
			fprintf(stderr, "Tcl_EvalFile(): %s\n", Tcl_GetStringResult(port->_interp));
			exit(1);
		}
		free(s);
		CFRelease(pf);
		
		Tcl_Release(port->_interp);
	} while (0);
	
	return port;
}

void
mp_port_destroy(mp_port_t port)
{
	CFRelease(port->_url);
	
	CFRelease(port->_variableInfo);
	CFRelease(port->_variables);
	
	CFRelease(port->_platforms);
	CFRelease(port->_variants);
	
	Tcl_DeleteInterp(port->_interp);

	free(port); // XXX
}

CFStringRef
mp_port_variable(mp_port_t port, CFStringRef name)
{
	CFDictionaryRef info;
	CFTypeRef setValue;
	CFTypeRef defValue;
	CFTypeRef callback;
	CFStringRef ret;
	CFStringRef subst = NULL;
	
	info = CFDictionaryGetValue(port->_variableInfo, name);
	if (info != NULL) {
		if ((setValue = CFDictionaryGetValue(port->_variables, name))) {
			if (mp_port_variable_is_array(port, name)) {
				assert(CFGetTypeID(setValue) == CFArrayGetTypeID());
				ret = CFStringCreateByCombiningStrings(NULL, setValue, CFSTR(" "));
			} else {
				assert(CFGetTypeID(setValue) == CFStringGetTypeID());
				ret = CFRetain(setValue);
			}
		} else if ((defValue = CFDictionaryGetValue(info, kPortVariableDefault))) {
			ret = CFRetain(defValue);
		} else if ((callback = CFDictionaryGetValue(info, kPortVariableCallback))) {
			assert(CFGetTypeID(callback) == CFStringGetTypeID());
			// XXX
			//ret = [self performSelector:NSSelectorFromString(callback) withObject:name];
			ret = CFSTR("callback unimplemented");
		} else {
			ret = CFSTR("");
		}
		char *s = strdup_cf(ret);
		subst = CFStringCreateWithTclObject(NULL, Tcl_SubstObj(port->_interp, Tcl_NewStringObj(s, -1), TCL_SUBST_VARIABLES));
		free(s);
		CFRelease(ret);
	} else {
		fprintf_cf(stderr, "WARNING: unknown variable %@\n", name);
	}
	return subst;
}

CFStringRef
mp_port_portfile(mp_port_t port)
{
	CFStringRef path;
	CFStringRef pf;
	path = CFURLCopyStrictPath(port->_url, NULL);
	pf = CFStringCreateWithFormat(NULL, NULL, CFSTR("/%@/Portfile"), path);
	CFRelease(path);
	return pf;
}

CFArrayRef
mp_port_targets(mp_port_t port)
{
	CFMutableArrayRef results;

	results = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
	CFArrayAppendValue(results, CFSTR("fetch"));
	CFArrayAppendValue(results, CFSTR("checksum"));
	CFArrayAppendValue(results, CFSTR("extract"));
	CFArrayAppendValue(results, CFSTR("patch"));
	CFArrayAppendValue(results, CFSTR("configure"));
	CFArrayAppendValue(results, CFSTR("build"));
	CFArrayAppendValue(results, CFSTR("test"));
	CFArrayAppendValue(results, CFSTR("destroot"));

	return results;
}

static Boolean
mp_port_is_target(mp_port_t port, CFStringRef target)
{
	CFArrayRef tmp;
	Boolean result;

	if (CFStringHasPrefix(target, CFSTR("pre-"))) {
		target = CFStringCreateWithSubstring(NULL, target, CFRangeMake(4, CFStringGetLength(target) - 4));
	} else if (CFStringHasPrefix(target, CFSTR("post-"))) {
		target = CFStringCreateWithSubstring(NULL, target, CFRangeMake(5, CFStringGetLength(target) - 5));
	} else {
		target = CFRetain(target);
	}

	tmp = mp_port_targets(port);
	result = CFArrayContainsValue(tmp, CFRangeMake(0, CFArrayGetCount(tmp)), target);
	CFRelease(tmp);

	CFRelease(target);

	return result;
}

CFArrayRef
mp_port_variables(mp_port_t port)
{
	CFIndex count = CFDictionaryGetCount(port->_variableInfo);
	const void *keys[count];
	CFArrayRef vars;

	CFDictionaryGetKeysAndValues(port->_variableInfo, keys, NULL);
	vars = CFArrayCreate(NULL, keys, count, &kCFTypeArrayCallBacks);

	return vars;
}

static Boolean
mp_port_variable_is_array(mp_port_t port, CFStringRef var)
{
	CFStringRef type;

	type = CFDictionaryGetValue(CFDictionaryGetValue(port->_variableInfo, var), kPortVariableType);
	return type && (CFStringCompare(type, CFSTR("Array"), 0) == kCFCompareEqualTo);
}

CFArrayRef
mp_port_settable_variables(mp_port_t port)
{
	CFMutableArrayRef ret = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
	CFArrayRef vars;
	vars = mp_port_variables(port);
	CFArrayApplyBlock2(vars, ^(const void *var) {
		CFBooleanRef constant = CFDictionaryGetValue(CFDictionaryGetValue(port->_variableInfo, var), kPortVariableConstant);
		if (constant == NULL || constant != kCFBooleanTrue) {
			CFArrayAppendValue(ret, var);
		}
	});
	CFRelease(vars);
	return ret;
}

CFArrayRef
mp_port_settable_array_variables(mp_port_t port)
{
	CFMutableArrayRef ret = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
	CFArrayRef vars;
	vars = mp_port_settable_variables(port);
	CFArrayApplyBlock2(vars, ^(const void *var) {
		if (mp_port_variable_is_array(port, var)) {
			CFArrayAppendValue(ret, var);
		}
	});
	CFRelease(vars);
	return ret;
}

void
mp_port_variable_set(mp_port_t port, CFStringRef var, CFArrayRef value)
{
	if (mp_port_variable_is_array(port, var)) {
		CFDictionarySetValue(port->_variables, var, value);
	} else {
		CFStringRef str = CFStringCreateByCombiningStrings(NULL, value, CFSTR(" "));
		CFDictionarySetValue(port->_variables, var, str);
		CFRelease(str);
	}
}

void
mp_port_variable_append(mp_port_t port, CFStringRef var, CFArrayRef value)
{
	CFTypeRef old = CFDictionaryGetValue(port->_variables, var);
	if (old) {
		CFMutableArrayRef array;

		assert(CFGetTypeID(old) == CFArrayGetTypeID());

		array = CFArrayCreateMutableCopy(NULL, 0, old);
		CFArrayAppendArray(array, value, CFRangeMake(0, CFArrayGetCount(value)));
		CFDictionarySetValue(port->_variables, var, array);
		CFRelease(array);
	} else {
		CFDictionarySetValue(port->_variables, var, value);
	}
}

void
mp_port_variable_delete(mp_port_t port, CFStringRef var, CFArrayRef value)
{
	CFTypeRef old;
	CFMutableArrayRef tmp;

	old = CFDictionaryGetValue(port->_variables, var);
	if (old == NULL) {
		return;
	}
	assert(CFGetTypeID(old) == CFArrayGetTypeID());
	tmp = CFArrayCreateMutableCopy(NULL, 0, old);
	CFArrayApplyBlock2(value, ^(const void *v) {
		CFArrayRemoveValueAtIndex(tmp, CFArrayGetFirstIndexOfValue(tmp, CFRangeMake(0, CFArrayGetCount(tmp)), v));
	});
	CFDictionarySetValue(port->_variables, var, tmp);
	CFRelease(tmp);
}

CFArrayRef
mp_port_defined_platforms(mp_port_t port)
{
	CFMutableArrayRef ret = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
	CFArrayApplyBlock2(port->_platforms, ^(const void *plat) {
		CFStringRef tmp = CFStringCreateByCombiningStrings(NULL, plat, CFSTR("_"));
		CFArrayAppendValue(ret, tmp);
		CFRelease(tmp);
	});
	return ret;
}

Boolean
mp_port_test_and_record_platform(mp_port_t port, CFArrayRef platform)
{
	struct utsname u;
	CFStringRef os;
	CFStringRef release;
	CFStringRef arch;
	CFTypeRef tmp;
	Boolean result = TRUE;
	
	CFArrayAppendValue(port->_platforms, platform);
	
	assert(uname(&u) == 0);
	os = CFStringCreateWithCString(NULL, u.sysname, kCFStringEncodingUTF8);
	release = CFStringCreateWithCString(NULL, u.release, kCFStringEncodingUTF8);
	arch = CFStringCreateWithCString(NULL, u.machine, kCFStringEncodingUTF8);
	
	tmp = CFArrayGetValueAtIndex(platform, 0);
	if (tmp != kCFNull && CFStringCompare(tmp, os, kCFCompareCaseInsensitive) != kCFCompareEqualTo) {
		result = FALSE;
	}
	
	tmp = CFArrayGetValueAtIndex(platform, 1);
	if (tmp != kCFNull && CFStringCompare(tmp, release, kCFCompareCaseInsensitive) != kCFCompareEqualTo) {
		result = FALSE;
	}
	
	tmp = CFArrayGetValueAtIndex(platform, 2);
	if (tmp != kCFNull && CFStringCompare(tmp, arch, kCFCompareCaseInsensitive) != kCFCompareEqualTo) {
		result = FALSE;
	}
	
	CFRelease(os);
	CFRelease(release);
	CFRelease(arch);

	return result;
}

CFArrayRef
mp_port_defined_variants(mp_port_t port)
{
	CFIndex count = CFDictionaryGetCount(port->_variants);
	const void *keys[count];
	CFArrayRef vars;
	
	CFDictionaryGetKeysAndValues(port->_variants, keys, NULL);
	vars = CFArrayCreate(NULL, keys, count, &kCFTypeArrayCallBacks);
	
	return vars;
}

Boolean
mp_port_test_and_record_variant(mp_port_t port, CFStringRef variant, CFDictionaryRef props)
{
	// XXX: check for dupes (w/ platforms too)
	CFDictionarySetValue(port->_variants, variant, props);
	// XXX: make sure it's set, like platforms just pretend
	return TRUE;
}

void
mp_port_perform_command(mp_port_t port, CFArrayRef args)
{
	CFStringRef command;
	CFIndex count;

	command = CFArrayGetValueAtIndex(args, 0);
	count = CFArrayGetCount(args);

	if (CFStringCompare(command, CFSTR("PortSystem"), 0) == kCFCompareEqualTo) {
		assert(count == 2);
		assert(CFStringCompare(CFArrayGetValueAtIndex(args, 1), CFSTR("1.0"), 0) == kCFCompareEqualTo);
	} else if (CFStringCompare(command, CFSTR("PortGroup"), 0) == kCFCompareEqualTo) {
		fprintf_cf(stderr, "ignoring %@, grps r hard m'kay\n", command);
		// XXX: this should probably set some state in parent port instance
		// (ugh, more tcl parsing)
	} else if (CFStringCompare(command, CFSTR("platform"), 0) == kCFCompareEqualTo) {
		CFStringRef os = NULL;
		CFTypeRef release = kCFNull;
		CFTypeRef arch = kCFNull;
		
		if (count < 3 || count > 5) {
			fprintf(stderr, "bogus platform declaration\n");
			return;
		}
		
		os = CFArrayGetValueAtIndex(args, 1);
		
		if (count == 4) {
			SInt32 rel = CFStringGetIntValue(CFArrayGetValueAtIndex(args, 2));
			if (rel != 0) {
				release = CFNumberCreate(NULL, kCFNumberIntType, &rel);
			} else {
				arch = CFArrayGetValueAtIndex(args, 2);
			}
		} else if (count == 5) {
			SInt32 rel = CFStringGetIntValue(CFArrayGetValueAtIndex(args, 2));
			release = CFNumberCreate(NULL, kCFNumberIntType, &rel);
			arch = CFArrayGetValueAtIndex(args, 3);
		}
		
		CFMutableArrayRef platform = CFArrayCreateMutable(NULL, 3, &kCFTypeArrayCallBacks);
		CFArrayAppendValue(platform, os);
		CFArrayAppendValue(platform, release);
		CFArrayAppendValue(platform, arch);
		CFRelease(release);

		if (mp_port_test_and_record_platform(port, platform)) {
			char *s = strdup_cf(CFArrayGetValueAtIndex(args, count - 1));
			Tcl_Eval(port->_interp, s);
			free(s);
		}
		CFRelease(platform);
	} else if (CFStringCompare(command, CFSTR("variant"), 0) == kCFCompareEqualTo) {
		CFStringRef name;
		CFMutableDictionaryRef props;
		CFIndex i;
		
		// variant name [a b c d] {}
		if (count < 3) {
			fprintf(stderr, "bogus variant declaration\n");
			return;
		}
		
		name = CFArrayGetValueAtIndex(args, 1);
		
		// this isn't quite right, conflicts can take multiple "arguments"
		props = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
 		for (i = 2; i < count - 1; i += 2) {
			CFDictionarySetValue(props, CFArrayGetValueAtIndex(args, i), CFArrayGetValueAtIndex(args, i + 1));
		}
		
		if (mp_port_test_and_record_variant(port, name, props)) {
			char *s = strdup_cf(CFArrayGetValueAtIndex(args, count - 1));
			Tcl_Eval(port->_interp, s);
			free(s);
		}

		CFRelease(props);
	} else if (mp_port_is_target(port, command)) {
		// XXX: store for later use...
	} else {
		const void *values[count - 1];
		CFArrayRef foo;
		CFStringRef tmp;

		CFArrayGetValues(args, CFRangeMake(1, count - 1), values);
		foo = CFArrayCreate(NULL, values, count - 1, &kCFTypeArrayCallBacks);

		if (CFStringHasSuffix(command, CFSTR("-append"))) {
			tmp = CFStringCreateWithSubstring(NULL, command, CFRangeMake(0, CFStringGetLength(command) - 7));
			mp_port_variable_append(port, tmp, foo);
			CFRelease(tmp);
		} else if (CFStringHasSuffix(command, CFSTR("-delete"))) {
			tmp = CFStringCreateWithSubstring(NULL, command, CFRangeMake(0, CFStringGetLength(command) - 7));
			mp_port_variable_delete(port, tmp, foo);
			CFRelease(tmp);
		} else {
			mp_port_variable_set(port, command, foo);
		}

		CFRelease(foo);
	}
}

//

static int
command_trampoline(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	CFArrayRef args = CFArrayCreateWithTclObjects(NULL, objv, objc);
	mp_port_perform_command(clientData, args);
	CFRelease(args);
	
	return TCL_OK;
}

static void
command_create(Tcl_Interp *interp, const char *cmdName, ClientData clientData)
{
	Tcl_CmdInfo info;
	if (Tcl_GetCommandInfo(interp, cmdName, &info) != 0) {
		fprintf(stderr, "Command '%s' already exists, bailing.", cmdName);
		abort();
	}
	Tcl_CreateObjCommand(interp, cmdName, command_trampoline, clientData, NULL);
}

static void
command_create_cf(Tcl_Interp *interp, CFStringRef cmdName, ClientData clientData)
{
	char *s = strdup_cf(cmdName);
	command_create(interp, s, clientData);
	free(s);
}

static char *
variable_read(ClientData clientData, Tcl_Interp *interp, const char *name1, const char *name2, int flags)
{
	CFStringRef tmp, var;
	char *s;

	tmp = CFStringCreateWithCString(NULL, name1, kCFStringEncodingUTF8);
	var = mp_port_variable(clientData, tmp);
	CFRelease(tmp);

	assert(var);

	s = strdup_cf(var);
	Tcl_SetVar2(interp, name1, name2, s, 0);
	free(s);

	CFRelease(var);

	return NULL;
}

// debugging
static int
_nslog(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	CFArrayRef args;
	CFStringRef str;

	args = CFArrayCreateWithTclObjects(NULL, ++objv, --objc);
	if (args) {
		str = CFStringCreateByCombiningStrings(NULL, args, CFSTR(" "));
		if (str) {
			CFShow(str);
			CFRelease(str);
		}
		CFRelease(args);
	}
	
	return TCL_OK;
}

static int
_fake_boolean(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	Tcl_SetObjResult(interp, Tcl_NewBooleanObj(0));
	return TCL_OK;
}
