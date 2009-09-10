CFArrayRef CFArrayCreateWithTclObjects(CFAllocatorRef allocator, Tcl_Obj **objects, CFIndex count);

#ifdef __OBJC__
@interface NSArray (MPArrayAdditions)
- (id)initWithTclObjects:(Tcl_Obj * const *)objects count:(int)count;
@end
#endif
