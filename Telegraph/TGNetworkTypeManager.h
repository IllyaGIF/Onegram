#import <Foundation/Foundation.h>
#import "../OnegramRuntime/OGTransferPolicy.h"
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

+ (OGTransferParameters)transferParametersForUpload:(bool)upload;
+ (void)recordTransferBytes:(int64_t)bytes started:(NSTimeInterval)started upload:(bool)upload generation:(uint32_t)generation;
+ (void)recordTransferFailureForUpload:(bool)upload generation:(uint32_t)generation;

- (TGNetworkType)networkType;
- (SSignal *)networkTypeSignal;

@end
