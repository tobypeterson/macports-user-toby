@interface NSString (nstcl)
+ (id)stringWithTclObject:(Tcl_Obj *)object;
- (id)initWithTclObject:(Tcl_Obj *)object;
@end

@interface NSArray (nstcl)
+ (id)arrayWithTclObjects:(Tcl_Obj **)objects count:(NSUInteger)count;
- (id)initWithTclObjects:(Tcl_Obj **)objects count:(NSUInteger)count;
@end

@interface NSDictionary (nstcl)
+ (id)dictionaryWithTclObjects:(Tcl_Obj **)objects count:(NSUInteger)count;
- (id)initWithTclObjects:(Tcl_Obj **)objects count:(NSUInteger)count;
@end
