#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGChatListSignals : NSObject

+ (SSignal *)chatListWithLimit:(NSUInteger)limit;

@end
