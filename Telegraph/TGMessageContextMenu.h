#import <UIKit/UIKit.h>
#import "TGCollectionItem.h"

@interface TGMessageContextMenu : UIView

@property (nonatomic, copy) void (^actionSelected)(NSDictionary *action);
@property (nonatomic, copy) void (^reactionSelected)(NSString *reaction);
@property (nonatomic, copy) void (^dismissed)(void);
@property (nonatomic) UIEdgeInsets contentInsets;
@property (nonatomic) CGFloat menuScale;
@property (nonatomic) bool previewMode;

- (instancetype)initWithActions:(NSArray *)actions sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect compact:(bool)compact;
- (void)setReactions:(NSArray *)reactions chosenReaction:(NSString *)chosenReaction;
- (void)presentInView:(UIView *)view;
- (void)dismissAnimated:(bool)animated completion:(void (^)(void))completion;

@end

@interface TGMessageMenuPreviewCollectionItem : TGCollectionItem

@property (nonatomic) CGFloat menuScale;

@end
