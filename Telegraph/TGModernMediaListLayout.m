#import "TGModernMediaListLayout.h"

@interface TGModernMediaListLayout ()
{
    bool _updatingCollectionItems;
}

@end

@implementation TGModernMediaListLayout

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
    }
    return self;
}


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
