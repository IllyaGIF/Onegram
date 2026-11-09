#import <UIKit/UIKit.h>

typedef struct
{
    NSInteger framesPerSecond;
    CGFloat maximumPixelSide;
    NSUInteger maximumPlayingCount;
    NSUInteger memoryCacheBytes;
    bool animatesWhileScrolling;
} TGAnimatedStickerTier;

#ifdef __cplusplus
extern "C" {
#endif

TGAnimatedStickerTier TGAnimatedStickerCurrentTier(void);
dispatch_queue_t TGAnimatedStickerRenderQueue(void);

#ifdef __cplusplus
}
#endif

@interface TGAnimatedStickerFrames : NSObject

@property (nonatomic, readonly) NSString *key;
@property (nonatomic, readonly) CGSize pixelSize;
@property (nonatomic, readonly) NSTimeInterval frameDuration;

+ (TGAnimatedStickerFrames *)framesWithKey:(NSString *)key filePath:(NSString *)filePath pixelSize:(CGSize)pixelSize;
+ (TGAnimatedStickerFrames *)framesWithKey:(NSString *)key filePath:(NSString *)filePath pixelSize:(CGSize)pixelSize sourceFrameRate:(bool)sourceFrameRate;

- (NSUInteger)frameCount;
- (NSInteger)framesPerSecond;
- (NSUInteger)availableFrameCount;
- (float)preparationFramesPerSecond;
- (bool)isComplete;
- (bool)renderRemainingFramesCancelled:(bool (^)(void))cancelled;
- (CGImageRef)copyImageForFrame:(NSUInteger)index CF_RETURNS_RETAINED;
- (CGImageRef)copyImageForFrame:(NSUInteger)index cancelled:(bool (^)(void))cancelled CF_RETURNS_RETAINED;
- (CGImageRef)copyPosterImage CF_RETURNS_RETAINED;
- (CGImageRef)copyStoredImageForFrame:(NSUInteger)index CF_RETURNS_RETAINED;

@end
