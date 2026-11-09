#import "TGCollectionItem.h"

@class TGStarGift;

@interface TGStarGiftHeaderCollectionItem : TGCollectionItem

@property (nonatomic, strong) TGStarGift *gift;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;

@end
