#import "TGCollectionItem.h"

@interface TGDialogFilterCategoryCollectionItem : TGCollectionItem

@property (nonatomic, readonly) int32_t category;
@property (nonatomic) bool displayCheck;
@property (nonatomic) bool checkIsOn;
@property (nonatomic) bool canDelete;

@property (nonatomic, copy) void (^pressed)(void);
@property (nonatomic, copy) void (^deletePressed)(void);

- (instancetype)initWithCategory:(int32_t)category;

@end
