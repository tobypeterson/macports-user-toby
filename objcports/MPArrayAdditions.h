@interface NSArray (MPArrayAdditions)
+ (id)arrayWithTclObjects:(Tcl_Obj * const *)objects count:(int)count;
- (id)initWithTclObjects:(Tcl_Obj * const *)objects count:(int)count;
@end
