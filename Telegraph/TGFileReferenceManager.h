#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGMediaOriginInfo;

@interface TGFileReferenceManager : NSObject

- (SSignal *)updatedOriginInfo:(TGMediaOriginInfo *)originInfo;

@end
