CFStringRef CFStringCreateWithTclObject(CFAllocatorRef allocator, Tcl_Obj *object);
CFArrayRef CFArrayCreateWithTclObjects(CFAllocatorRef allocator, Tcl_Obj * const *objects, CFIndex count);
CFDictionaryRef CFDictionaryCreateWithTclObjects(CFAllocatorRef allocator, Tcl_Obj **objects, CFIndex count);
