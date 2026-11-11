#import "TGCollectionItemView.h"

@class TGUser;

@interface TGStoryViewerCollectionItemView : TGCollectionItemView

- (void)setUser:(TGUser *)user date:(int32_t)date hasReaction:(bool)hasReaction reaction:(NSString *)reaction blocked:(bool)blocked;

@end
