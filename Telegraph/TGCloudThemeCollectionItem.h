#import "TGCollectionItem.h"

@interface TGCloudThemeCollectionItem : TGCollectionItem

@property (nonatomic, strong) NSString *title;
@property (nonatomic) bool isChecked;
@property (nonatomic, copy) void (^pressed)(void);
@property (nonatomic, copy) void (^removeRequested)(void);

@end
