#import <UIKit/UIKit.h>
#import "TGCollectionItem.h"

typedef enum {
    TGMessageContextMenuStyleIOS = 0,
    TGMessageContextMenuStyleAndroid = 1
} TGMessageContextMenuStyle;

@interface TGMessageContextMenu : UIView

@property (nonatomic, readonly) TGMessageContextMenuStyle style;

@property (nonatomic, copy) void (^actionSelected)(NSDictionary *action);
@property (nonatomic, copy) void (^reactionSelected)(NSString *reaction);
@property (nonatomic, copy) void (^dismissed)(void);
@property (nonatomic) UIEdgeInsets contentInsets;
@property (nonatomic) CGFloat menuScale;
@property (nonatomic) bool previewMode;

+ (TGMessageContextMenuStyle)currentStyle;
+ (UIImage *)blurredSnapshotOfView:(UIView *)view;

- (instancetype)initWithActions:(NSArray *)actions style:(TGMessageContextMenuStyle)style sourceRect:(CGRect)sourceRect previewImage:(UIImage *)previewImage backgroundImage:(UIImage *)backgroundImage;
- (void)setReactions:(NSArray *)reactions chosenReaction:(NSString *)chosenReaction;
- (void)setInfoTitle:(NSString *)title forAction:(NSString *)action;
- (void)beginTrackingTouch;
- (CGFloat)requiredHeightBelowSourceInBounds:(CGRect)bounds;
- (void)updateSourceRect:(CGRect)sourceRect;
- (void)presentInView:(UIView *)view;
- (void)dismissAnimated:(bool)animated completion:(void (^)(void))completion;

@end

@interface TGMessageMenuPreviewCollectionItem : TGCollectionItem

@property (nonatomic) CGFloat menuScale;

@end
