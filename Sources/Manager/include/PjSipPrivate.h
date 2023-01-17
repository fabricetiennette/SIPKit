#ifndef PjSipPrivate_h
#define PjSipPrivate_h

// additional util imports
#import "PSUtil.h"

// just in case we need to compile w/o assertions
#define PSAssert NSAssert


// PJSIP status check macros
#define PSLogSipError(status_)                                      \
NSLog(@"Gossip: %@", [PSUtil errorWithSIPStatus:status_]);

#define PSLogIfFails(aStatement_) do {      \
pj_status_t status = (aStatement_);     \
if (status != PJ_SUCCESS)               \
PSLogSipError(status);              \
} while (0)

#define PSReturnValueIfFails(aStatement_, returnValue_) do {            \
pj_status_t status = (aStatement_);                                 \
if (status != PJ_SUCCESS) {                                         \
PSLogSipError(status);                                          \
return returnValue_;                                            \
}                                                                   \
} while(0)

#define PSReturnIfFails(aStatement_) PSReturnValueIfFails(aStatement_, )
#define PSReturnNoIfFails(aStatement_) PSReturnValueIfFails(aStatement_, NO)
#define PSReturnNilIfFails(aStatement_) PSReturnValueIfFails(aStatement_, nil)

#endif /* PjSipPrivate_h */
