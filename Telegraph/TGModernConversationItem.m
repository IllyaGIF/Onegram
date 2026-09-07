#import "TGModernConversationItem.h"

@interface TGModernConversationItem ()
{
    NSString *_viewIdentifier;
}

@end

@implementation TGModernConversationItem

- (Class)cellClass
{
    return nil;
}

- (bool)collapseWithItem:(TGModernConversationItem *)__unused item forContainerSize:(CGSize)__unused containerSize
{
    return false;
}

- (TGModernCollectionCell *)dequeueCollectionCell:(PSUICollectionView *)collectionView registeredIdentifiers:(NSMutableSet *)registeredIdentifiers forIndexPath:(NSIndexPath *)indexPath
{
    if (_viewIdentifier == nil)
        _viewIdentifier = [[NSString alloc] initWithFormat:@"View_%@", NSStringFromClass([self cellClass])];
    if (![registeredIdentifiers containsObject:_viewIdentifier])
    {
        [collectionView registerClass:[self cellClass] forCellWithReuseIdentifier:_viewIdentifier];
        [registeredIdentifiers addObject:_viewIdentifier];
    }
    
    return [collectionView dequeueReusableCellWithReuseIdentifier:_viewIdentifier forIndexPath:indexPath];
}

- (void)bindCell:(TGModernCollectionCell *)cell viewStorage:(TGModernViewStorage *)__unused viewStorage
{
    if (_cell != nil && _cell != cell && _cell.boundItem == self)
        _cell.boundItem = nil;
    if (cell.boundItem != self)
        cell.boundItem = nil;
    _cell = cell;
    _cell.boundItem = self;
}

- (void)unbindCell:(TGModernViewStorage *)__unused viewStorage
{
    if (_cell.boundItem == self)
        _cell.boundItem = nil;
    _cell = nil;
}

- (void)moveToCell:(TGModernCollectionCell *)cell
{
    if (_cell.boundItem == self)
        _cell.boundItem = nil;
    _cell = cell;
    _cell.boundItem = self;
}

- (void)temporaryMoveToView:(UIView *)__unused view
{
    if (_cell.boundItem == self)
        _cell.boundItem = nil;
    _cell = nil;
}

- (TGModernCollectionCell *)boundCell
{
    if (_cell != nil && _cell.boundItem != self)
        _cell = nil;
    return _cell;
}

- (void)dealloc
{
    if (_cell.boundItem == self)
        _cell.boundItem = nil;
}

- (TGModernViewModel *)viewModel
{
    return nil;
}

- (void)bindSpecialViewsToContainer:(UIView *)__unused container viewStorage:(TGModernViewStorage *)__unused viewStorage atItemPosition:(CGPoint)__unused itemPosition
{
}

- (void)drawInContext:(CGContextRef)__unused context
{
}

- (CGSize)sizeForContainerSize:(CGSize)containerSize viewStorage:(TGModernViewStorage *)__unused viewStorage
{
    return CGSizeMake(containerSize.width, 0.0f);
}

- (void)updateToItem:(TGModernConversationItem *)__unused updatedItem viewStorage:(TGModernViewStorage *)__unused viewStorage sizeChanged:(bool *)__unused sizeChanged delayAvailability:(bool)__unused delayAvailability containerSize:(CGSize)__unused containerSize
{
    [self updateToItem:updatedItem viewStorage:viewStorage sizeChanged:sizeChanged delayAvailability:delayAvailability containerSize:containerSize force:false];
}

- (void)updateToItem:(TGModernConversationItem *)__unused updatedItem viewStorage:(TGModernViewStorage *)__unused viewStorage sizeChanged:(bool *)__unused sizeChanged delayAvailability:(bool)__unused delayAvailability containerSize:(CGSize)__unused containerSize force:(bool)__unused force
{
}

- (void)updateProgress:(float)__unused progress viewStorage:(TGModernViewStorage *)__unused viewStorage animated:(bool)__unused animated
{
}

- (void)updateInlineMediaContext
{
}

- (void)updateAnimationsEnabled
{
}

- (void)stopInlineMedia:(int32_t)__unused excludeMid
{
}

- (void)resumeInlineMedia
{
}

- (void)updateGroupedLayout:(TGMessageGroupedLayout *)__unused groupedLayout
{
}

- (void)resetViewModel
{
}

@end
