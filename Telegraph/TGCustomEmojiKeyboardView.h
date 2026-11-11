#import <UIKit/UIKit.h>

@class TGPresentation;
@class TGCustomEmojiItem;

@interface TGCustomEmojiKeyboardView : UIView

@property (nonatomic, strong) TGPresentation *presentation;
@property (nonatomic) UIEdgeInsets contentInset;
@property (nonatomic, copy) void (^itemSelected)(TGCustomEmojiItem *item, UIImage *image);

- (void)loadIfNeeded;

@end
