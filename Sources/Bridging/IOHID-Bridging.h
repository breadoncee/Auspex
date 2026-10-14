#ifndef IOHID_Bridging_h
#define IOHID_Bridging_h

#import <Foundation/Foundation.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>
#include <dlfcn.h>
#include <math.h>

#define kIOHIDEventTypeTemperature 15
typedef struct CF_BRIDGED_TYPE(id) __IOHIDEvent * IOHIDEventRef;

// Resolve private symbols at runtime. Missing symbols on a new macOS version
// must disable temperature readouts, never prevent the entire app launching.
static inline IOHIDEventSystemClientRef _Nullable
AuspexHIDClientCreate(CFAllocatorRef _Nullable allocator) {
    typedef IOHIDEventSystemClientRef (*Function)(CFAllocatorRef);
    Function function = (Function)dlsym(RTLD_DEFAULT, "IOHIDEventSystemClientCreate");
    return function ? function(allocator) : NULL;
}

static inline bool AuspexHIDSetMatching(IOHIDEventSystemClientRef _Nonnull client,
                                      CFDictionaryRef _Nonnull match) {
    typedef void (*Function)(IOHIDEventSystemClientRef, CFDictionaryRef);
    Function function = (Function)dlsym(RTLD_DEFAULT, "IOHIDEventSystemClientSetMatching");
    if (!function) return false;
    function(client, match);
    return true;
}

static inline IOHIDEventRef _Nullable
AuspexHIDCopyEvent(IOHIDServiceClientRef _Nonnull service, int64_t type,
                  int32_t options, int64_t timeout) {
    typedef IOHIDEventRef (*Function)(IOHIDServiceClientRef, int64_t, int32_t, int64_t);
    Function function = (Function)dlsym(RTLD_DEFAULT, "IOHIDServiceClientCopyEvent");
    return function ? function(service, type, options, timeout) : NULL;
}

static inline double AuspexHIDTemperature(IOHIDEventRef _Nonnull event, int32_t field) {
    typedef double (*Function)(IOHIDEventRef, int32_t);
    Function function = (Function)dlsym(RTLD_DEFAULT, "IOHIDEventGetFloatValue");
    return function ? function(event, field) : NAN;
}

#endif
