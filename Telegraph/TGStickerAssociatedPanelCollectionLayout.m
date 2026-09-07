#import "TGStickerAssociatedPanelCollectionLayout.h"

@interface TGStickerAssociatedPanelCollectionLayout ()
{
    bool _updatingCollectionItems;
}

@end

@implementation TGStickerAssociatedPanelCollectionLayout

- (PSUICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)itemIndexPath
{
    if (_updatingCollectionItems || itemIndexPath.section != 0)
        return [super initialLayoutAttributesForAppearingItemAtIndexPath:itemIndexPath];
    
    return nil;
}

- (PSUICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)itemIndexPath
{
    if (_updatingCollectionItems || itemIndexPath.section != 0)
        return [super finalLayoutAttributesForDisappearingItemAtIndexPath:itemIndexPath];
    
    return [self layoutAttributesForItemAtIndexPath:itemIndexPath];
}

@end
