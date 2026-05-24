//
//  IOHID-Bridging.h
//  ResourceMonitor
//
//  Declarations for the *private* parts of the IOHIDEventSystemClient API
//  used to read on-die temperature sensors. The client/service TYPES and
//  several functions (CopyServices, CopyProperty) are already public in the
//  SDK, so we import those headers and declare ONLY the private symbols here:
//  the matching-capable Create, SetMatching, CopyEvent, GetFloatValue, plus
//  the IOHIDEvent type and the temperature event-type constant.
//
//  Apple Silicon exposes no public temperature API; this is the same approach
//  used by Stats.app / fermion-star/apple_sensors. Private API — may break on
//  future macOS releases. ThermalCollector guards every call and degrades to
//  ProcessInfo.thermalState when no sensors are returned.
//

#ifndef IOHID_Bridging_h
#define IOHID_Bridging_h

#import <Foundation/Foundation.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>   // public: IOHIDEventSystemClientRef, CopyServices, CopyProperty
#import <IOKit/hidsystem/IOHIDServiceClient.h>        // public: IOHIDServiceClientRef, CopyProperty, ConformsTo

// Temperature HID event type (note: function-like macros are NOT imported into
// Swift, so the field selector is computed Swift-side as type << 16).
#define kIOHIDEventTypeTemperature 15

// Private event handle type (no public typedef exists).
typedef struct CF_BRIDGED_TYPE(id) __IOHIDEvent * IOHIDEventRef;

// --- Private functions (not present in the public SDK) ---

// Matching-capable client (public SDK only ships CreateSimpleClient).
CF_EXPORT IOHIDEventSystemClientRef _Nullable
IOHIDEventSystemClientCreate(CFAllocatorRef _Nullable allocator);

CF_EXPORT void
IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef _Nonnull client,
                                  CFDictionaryRef _Nonnull match);

CF_EXPORT IOHIDEventRef _Nullable
IOHIDServiceClientCopyEvent(IOHIDServiceClientRef _Nonnull service,
                            int64_t type,
                            int32_t options,
                            int64_t timeout);

CF_EXPORT double
IOHIDEventGetFloatValue(IOHIDEventRef _Nonnull event, int32_t field);

#endif /* IOHID_Bridging_h */
