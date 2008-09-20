#ifndef ____SUBSTRATE__H
#define ____SUBSTRATE__H

#ifdef __cplusplus
extern "C" {
#endif
    void MSHookMessage(Class _class, SEL sel, IMP imp, const char *prefix);
#ifdef __cplusplus
};
#endif

#endif /* ____SUBSTRATE__H */
// Local Variables:
// Mode: c++
// c-basic-offset: 4
// tab-width: 8
// indent-tabs-mode: t
// End:
