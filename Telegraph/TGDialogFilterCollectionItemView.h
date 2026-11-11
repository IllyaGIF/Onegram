#import "TGEditableCollectionItemView.h"

@interface TGDialogFilterCollectionItemView : TGEditableCollectionItemView

@property (nonatomic, copy) void (^deletePressed)(void);
@property (nonatomic, copy) void (^addPressed)(void);

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon;
- (void)setShowsDisclosure:(bool)showsDisclosure;
- (void)setAddButtonTitle:(NSString *)addButtonTitle;

@end
