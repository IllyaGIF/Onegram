#import <UIKit/UIKit.h>

@class TGStarGift;

@interface TGStarGiftCoverView : UIView

@property (nonatomic) CGPoint avatarCenter;
@property (nonatomic) CGFloat defaultHeight;
@property (nonatomic) CGRect gradientFrame;

- (void)setGift:(TGStarGift *)gift;

@end
