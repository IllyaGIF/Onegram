#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGSearchPeersSignals : NSObject

+ (SSignal *)searchPeersWithQuery:(NSString *)query;

@end
