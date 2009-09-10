char *strdup_cf(CFStringRef str);
int fprintf_cf(FILE *stream, CFStringRef format, ...);

typedef void (^CFArrayApplierBlock)(const void *);
typedef void (^CFDictionaryApplierBlock)(const void *, const void *);

void CFArrayApplyBlock(CFArrayRef, CFRange, CFArrayApplierBlock);
void CFArrayApplyBlock2(CFArrayRef, CFArrayApplierBlock);
void CFDictionaryApplyBlock(CFDictionaryRef, CFDictionaryApplierBlock);
