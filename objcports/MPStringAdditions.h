CFStringRef CFStringCreateWithTclObject(CFAllocatorRef allocator, Tcl_Obj *object);

#ifdef __OBJC__
@interface NSString (MPStringAdditions)
- (id)initWithTclObject:(Tcl_Obj *)object;
@end
#endif
