#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

typedef enum {
    TGSynchronizationStateSynchronized,
    TGSynchronizationStateWaitingForNetwork,
    TGSynchronizationStateConnecting,
    TGSynchronizationStateConnectingToProxy,
    TGSynchronizationStateUpdating,
    TGSynchronizationStateProxyIssues,
} TGSynchronizationStateValue;

@interface TGSynchronizationStateSignal : NSObject

+ (SSignal *)synchronizationState;

@end
