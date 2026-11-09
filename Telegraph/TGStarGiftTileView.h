#import <UIKit/UIKit.h>

#import "TGModernView.h"

@class TGStarGift;
@class TGSavedStarGift;
@class TGPresentation;
@class TGLetteredAvatarView;

@interface TGStarGiftTileView : UIControl <TGModernView>

@property (nonatomic, strong) TGPresentation *presentation;
@property (nonatomic) bool profileStyle;
@property (nonatomic) bool animated;

- (void)setGift:(TGStarGift *)gift caption:(NSString *)caption;
- (void)setSavedGift:(TGSavedStarGift *)savedGift;

@end

UIImage *TGStarGiftBackdropImage(CGSize size, UIColor *centerColor, UIColor *edgeColor, CGFloat cornerRadius);
NSString *TGStarGiftStarsString(int64_t stars);
NSString *TGStarGiftFormattedNumber(int64_t number);
NSString *TGStarGiftCompactCount(int32_t count);
UIImage *TGStarGiftRibbonImage(UIColor *bottomRightColor, UIColor *topLeftColor);
int64_t TGStarGiftResaleStars(TGStarGift *gift);
UIColor *TGStarGiftMixedColor(UIColor *color, UIColor *other, CGFloat fraction);
UIColor *TGStarGiftMultipliedColor(UIColor *color, CGFloat hue, CGFloat saturation, CGFloat brightness);
UIImage *TGStarGiftAnonymousAvatarImage(CGFloat diameter);
void TGStarGiftSetPeerAvatar(TGLetteredAvatarView *avatarView, int64_t peerId, CGFloat diameter, TGPresentation *presentation);
