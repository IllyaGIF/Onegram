#import "TGStoryViewerCollectionItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGStoryViewerCollectionItemView.h"

@implementation TGStoryViewerCollectionItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.highlightable = false;
        self.selectable = false;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGStoryViewerCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 56.0f);
}

- (void)bindView:(TGStoryViewerCollectionItemView *)view
{
    [super bindView:view];
    [view setUser:_user date:_date hasReaction:_hasReaction reaction:_reaction blocked:_blocked];
}

@end
