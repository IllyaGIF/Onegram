#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

#import "EMInMemoryImageCache.h"

@class TGDocumentMediaAttachment;

@interface TGStickerPreviewSignals : NSObject

+ (SSignal *)stickerThumbnail:(TGDocumentMediaAttachment *)documentAttachment ofSize:(CGSize)size threadPool:(SThreadPool *)threadPool memoryCache:(EMInMemoryImageCache *)memoryCache;

@end
