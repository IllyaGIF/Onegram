#import "TGCollectionItem.h"

@interface TGDialogFilterColorsCollectionItem : TGCollectionItem

@property (nonatomic) int32_t selectedColor;
@property (nonatomic, strong) NSString *previewTitle;
@property (nonatomic, copy) void (^colorSelected)(int32_t color);

@end
