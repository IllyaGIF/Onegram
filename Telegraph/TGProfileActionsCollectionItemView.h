#import "TGCollectionItemView.h"

#import "TGProfileActionsCollectionItem.h"

#ifdef __cplusplus
extern "C" {
#endif

extern const CGFloat TGProfileActionsCollectionItemViewHeight;

UIImage *TGProfileActionGlyphImage(TGProfileActionIcon icon, UIColor *color);
UIImage *TGProfileActionSettingsIconImage(TGProfileActionIcon icon, UIColor *backgroundColor);

#ifdef __cplusplus
}
#endif

@interface TGProfileActionsCollectionItemView : TGCollectionItemView

@property (nonatomic, copy) void (^actionSelected)(TGProfileAction *action);

- (void)setActions:(NSArray *)actions;
- (void)setButtonColor:(UIColor *)buttonColor;
- (void)setButtonStyle:(NSDictionary *)buttonStyle;
- (UIView *)buttonForActionWithSelector:(SEL)action;

@end
