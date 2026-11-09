#import <UIKit/UIKit.h>

#import "TGModernView.h"

@class TGStarGift;
@class TGPresentation;

@interface TGStarGiftMessageCardContent : NSObject

@property (nonatomic, strong) TGStarGift *gift;
@property (nonatomic) bool cover;
@property (nonatomic, strong) UIColor *plateColor;
@property (nonatomic, strong) UIColor *overlayColor;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) NSString *ribbonTitle;
@property (nonatomic, strong) NSArray *ribbonColors;
@property (nonatomic, strong) NSString *buttonTitle;
@property (nonatomic) CGFloat buttonOriginY;
@property (nonatomic) CGRect creatorFrame;
@property (nonatomic) CGRect bubbleFrame;
@property (nonatomic, strong) UIColor *bubbleColor;
@property (nonatomic) CGRect avatarFrame;
@property (nonatomic) int64_t avatarPeerId;

@end

@interface TGStarGiftMessageCardView : UIView <TGModernView>

@property (nonatomic, strong) TGPresentation *presentation;
@property (nonatomic, copy) void (^pressed)(CGPoint point);
@property (nonatomic, copy) void (^buttonPressed)(void);
@property (nonatomic, copy) void (^creatorPressed)(void);
@property (nonatomic, copy) void (^longPressed)(void);
@property (nonatomic, copy) void (^stickerFinished)(void);

- (void)setContent:(TGStarGiftMessageCardContent *)content;
- (void)playStickerOnce;

@end
