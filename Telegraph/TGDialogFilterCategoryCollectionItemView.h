#import "TGEditableCollectionItemView.h"

@interface TGDialogFilterCategoryCollectionItemView : TGEditableCollectionItemView

@property (nonatomic, copy) void (^deletePressed)(void);

- (void)setTitle:(NSString *)title icon:(UIImage *)icon;
- (void)setDisplayCheck:(bool)displayCheck checkIsOn:(bool)checkIsOn;

@end
