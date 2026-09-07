#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

typedef enum {
    TGNetworkTypeUnknown,
    TGNetworkTypeNone,
    TGNetworkTypeGPRS,
    TGNetworkTypeEdge,
    TGNetworkType3G,
    TGNetworkTypeLTE,
    TGNetworkTypeWiFi,
} TGNetworkType;

@interface TGNetworkTypeManager : NSObject

- (TGNetworkType)networkType;
- (SSignal *)networkTypeSignal;

@end
