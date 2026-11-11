#import "TGCollectionItemView.h"

@interface TGDialogFilterColorsCollectionItemView : TGCollectionItemView

@property (nonatomic, copy) void (^colorSelected)(int32_t color);

- (void)setSelectedColor:(int32_t)selectedColor previewTitle:(NSString *)previewTitle;

@end
