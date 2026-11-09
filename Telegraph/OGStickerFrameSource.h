#import <Foundation/Foundation.h>

@protocol OGStickerFrameSource <NSObject>

- (NSTimeInterval)duration;
- (bool)renderAtTime:(NSTimeInterval)time intoBGRA:(uint8_t *)pixels cancelled:(bool (^)(void))cancelled;
- (bool)hasAlpha;
- (NSUInteger)memoryCost;

@optional

- (double)frameRate;

@end
