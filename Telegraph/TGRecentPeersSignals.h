#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGRecentPeersSignals : NSObject

+ (SSignal *)recentPeers;
+ (SSignal *)updateRecentPeers;
+ (SSignal *)resetGenericPeerRating:(int64_t)peerId accessHash:(int64_t)accessHash;
+ (SSignal *)toggleRecentPeersEnabled:(bool)enabled;

@end
