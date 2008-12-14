@interface NSString (MPStringAdditions)
+ (id)stringWithTclObject:(Tcl_Obj *)object;
- (id)initWithTclObject:(Tcl_Obj *)object;
@end
