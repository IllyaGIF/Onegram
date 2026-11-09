#import <Foundation/Foundation.h>

@interface OGStickerWorker : NSObject

+ (OGStickerWorker *)preparationWorker;
+ (OGStickerWorker *)auxiliaryWorker;

- (void)perform:(dispatch_block_t)block;

@end
