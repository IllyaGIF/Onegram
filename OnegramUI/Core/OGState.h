#import <Foundation/Foundation.h>

typedef enum {
    OGControlStateNormal = 0,
    OGControlStateHighlighted = 1,
    OGControlStateDisabled = 2,
    OGControlStateSelected = 3
} OGControlState;

typedef enum {
    OGDeliveryStateNone = 0,
    OGDeliveryStateSending = 1,
    OGDeliveryStateSent = 2,
    OGDeliveryStateDelivered = 3,
    OGDeliveryStateRead = 4,
    OGDeliveryStateFailed = 5
} OGDeliveryState;

typedef enum {
    OGMessageAlignmentIncoming = 0,
    OGMessageAlignmentOutgoing = 1
} OGMessageAlignment;

typedef enum {
    OGPresenceStateUnknown = 0,
    OGPresenceStateOffline = 1,
    OGPresenceStateOnline = 2
} OGPresenceState;
