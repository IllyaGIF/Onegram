#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGVideoMediaAttachment;
@class TGMemoryImageCache;

@interface TGSharedVideoSignals : NSObject

+ (NSString *)pathForVideoDirectory:(TGVideoMediaAttachment *)videoAttachment;

+ (SSignal *)squareVideoThumbnail:(TGVideoMediaAttachment *)videoAttachment ofSize:(CGSize)size threadPool:(SThreadPool *)threadPool memoryCache:(TGMemoryImageCache *)memoryCache pixelProcessingBlock:(void (^)(void *, int, int, int))pixelProcessingBlock;
+ (SSignal *)squareVideoThumbnail:(TGVideoMediaAttachment *)videoAttachment ofSize:(CGSize)size threadPool:(SThreadPool *)threadPool memoryCache:(TGMemoryImageCache *)memoryCache pixelProcessingBlock:(void (^)(void *, int, int, int))pixelProcessingBlock downloadLargeThumbnail:(bool)downloadLargeThumbnail;

@end
