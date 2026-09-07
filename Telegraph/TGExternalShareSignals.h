#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGMessage;

@interface TGExternalShareSignals : NSObject

+ (SSignal *)shareItemsForMessages:(NSArray *)messages;

@end
