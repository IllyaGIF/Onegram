#import "TGCollectionItem.h"

@class TGUser;

@interface TGStoryViewerCollectionItem : TGCollectionItem

@property (nonatomic, strong) TGUser *user;
@property (nonatomic) int32_t date;
@property (nonatomic, strong) NSString *reaction;
@property (nonatomic) bool hasReaction;
@property (nonatomic) bool blocked;

@end
