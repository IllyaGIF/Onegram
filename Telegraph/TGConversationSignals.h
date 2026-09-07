#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGConversationSignals : NSObject

+ (SSignal *)conversationWithPeerId:(int64_t)peerId full:(bool)full;

@end
