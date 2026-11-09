#import "TGCollectionMenuController.h"

@interface TGProfileColorController : TGCollectionMenuController

@property (nonatomic, copy) void (^colorsChanged)(int32_t profileColor, int32_t nameColor);

- (instancetype)initWithProfileColor:(int32_t)profileColor nameColor:(int32_t)nameColor;

@end
