#import <UIKit/UIKit.h>

#import "TGModernView.h"

@class TGDocumentMediaAttachment;

@interface TGAnimatedStickerView : UIView <TGModernView>

@property (nonatomic) bool playing;
@property (nonatomic) bool loops;
@property (nonatomic) bool usesSourceFrameRate;
@property (nonatomic) bool restsOnLastFrame;
@property (nonatomic, copy) void (^playbackFinished)(void);
@property (nonatomic, copy) void (^readyBlock)(void);
@property (nonatomic, readonly) bool contentReady;

+ (bool)isAnimatedStickerDocument:(TGDocumentMediaAttachment *)document;
+ (bool)isWebMStickerDocument:(TGDocumentMediaAttachment *)document;
+ (NSString *)animationKeyForDocument:(TGDocumentMediaAttachment *)document;
+ (NSString *)viewStateIdentifierForAnimationKey:(NSString *)key;
+ (NSString *)filePathForDocument:(TGDocumentMediaAttachment *)document;
+ (NSString *)placeholderUriForDocument:(TGDocumentMediaAttachment *)document size:(CGSize)size;

- (void)setDocument:(TGDocumentMediaAttachment *)document placeholderUri:(NSString *)placeholderUri;
- (void)setAnimationFilePath:(NSString *)filePath key:(NSString *)key placeholderImage:(UIImage *)placeholderImage;
- (void)reset;
- (void)restart;

@end
