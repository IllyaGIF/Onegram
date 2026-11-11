#import "TGCollectionItem.h"

@interface TGDialogFilterCollectionItem : TGCollectionItem

@property (nonatomic, strong) id representedObject;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic) bool enableEditing;
@property (nonatomic) bool showsDisclosure;
@property (nonatomic, strong) NSString *addButtonTitle;

@property (nonatomic, copy) void (^pressed)(void);
@property (nonatomic, copy) void (^deletePressed)(void);
@property (nonatomic, copy) void (^addPressed)(void);

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon;

@end
