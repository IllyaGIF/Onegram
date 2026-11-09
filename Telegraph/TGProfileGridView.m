#import "TGProfileGridView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

@interface TGProfileGridView ()
{
    NSMutableDictionary *_visibleTiles;
    NSMutableArray *_reusableTiles;
    CGSize _lastBoundsSize;
}

@end

@implementation TGProfileGridView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _columns = 3;
        _tileAspect = 1.0f;
        _spacing = 2.0f;
        _visibleTiles = [[NSMutableDictionary alloc] init];
        _reusableTiles = [[NSMutableArray alloc] init];
        self.alwaysBounceVertical = true;
    }
    return self;
}

- (CGSize)tileSize
{
    CGFloat width = self.bounds.size.width - _gridInsets.left - _gridInsets.right;
    CGFloat tileWidth = CGFloor((width - _spacing * (_columns - 1)) / MAX((NSUInteger)1, _columns));
    return CGSizeMake(tileWidth, CGFloor(tileWidth * _tileAspect));
}

- (CGRect)frameForIndex:(NSUInteger)index
{
    CGSize tileSize = [self tileSize];
    NSUInteger row = index / _columns;
    NSUInteger column = index % _columns;
    return CGRectMake(_gridInsets.left + column * (tileSize.width + _spacing), _gridInsets.top + row * (tileSize.height + _spacing), tileSize.width, tileSize.height);
}

- (void)updateContentSize
{
    CGSize tileSize = [self tileSize];
    NSUInteger rows = (_itemCount + _columns - 1) / MAX((NSUInteger)1, _columns);
    CGFloat height = _gridInsets.top + _gridInsets.bottom + rows * tileSize.height + (rows > 0 ? (rows - 1) * _spacing : 0.0f);
    self.contentSize = CGSizeMake(self.bounds.size.width, height);
}

- (void)reloadData
{
    for (NSNumber *key in [_visibleTiles allKeys])
    {
        UIView *tile = [_visibleTiles objectForKey:key];
        tile.hidden = true;
        [_reusableTiles addObject:tile];
    }
    [_visibleTiles removeAllObjects];
    [self updateContentSize];
    [self layoutVisibleTiles];
}

- (void)reloadTileAtIndex:(NSUInteger)index
{
    UIView *tile = [_visibleTiles objectForKey:@(index)];
    if (tile != nil && _configureTile != nil)
        _configureTile(tile, index);
}

- (void)tilePressed:(UIView *)tile
{
    for (NSNumber *key in _visibleTiles)
    {
        if ([_visibleTiles objectForKey:key] == tile)
        {
            if (_tileSelected != nil)
                _tileSelected([key unsignedIntegerValue]);
            return;
        }
    }
}

- (UIView *)dequeueTile
{
    UIView *tile = [_reusableTiles lastObject];
    if (tile != nil)
    {
        [_reusableTiles removeLastObject];
        tile.hidden = false;
        return tile;
    }
    tile = _tileFactory != nil ? _tileFactory() : [[UIView alloc] init];
    if ([tile isKindOfClass:[UIControl class]])
        [(UIControl *)tile addTarget:self action:@selector(tilePressed:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:tile];
    return tile;
}

- (void)layoutVisibleTiles
{
    if (_itemCount == 0 || self.bounds.size.width < 1.0f)
        return;
    CGSize tileSize = [self tileSize];
    CGFloat rowHeight = tileSize.height + _spacing;
    CGFloat minY = self.contentOffset.y - rowHeight;
    CGFloat maxY = self.contentOffset.y + self.bounds.size.height + rowHeight;
    NSInteger firstRow = MAX(0, (NSInteger)floor((minY - _gridInsets.top) / rowHeight));
    NSInteger lastRow = MAX(0, (NSInteger)floor((maxY - _gridInsets.top) / rowHeight));
    NSUInteger firstIndex = (NSUInteger)firstRow * _columns;
    NSUInteger lastIndex = MIN(_itemCount, (NSUInteger)(lastRow + 1) * _columns);

    for (NSNumber *key in [_visibleTiles allKeys])
    {
        NSUInteger index = [key unsignedIntegerValue];
        if (index < firstIndex || index >= lastIndex)
        {
            UIView *tile = [_visibleTiles objectForKey:key];
            tile.hidden = true;
            [_reusableTiles addObject:tile];
            [_visibleTiles removeObjectForKey:key];
        }
    }
    for (NSUInteger index = firstIndex; index < lastIndex; index++)
    {
        NSNumber *key = @(index);
        UIView *tile = [_visibleTiles objectForKey:key];
        if (tile == nil)
        {
            tile = [self dequeueTile];
            [_visibleTiles setObject:tile forKey:key];
            if (_configureTile != nil)
                _configureTile(tile, index);
        }
        tile.frame = [self frameForIndex:index];
    }

    if (_nearEnd != nil && self.contentOffset.y + self.bounds.size.height * 2.0f >= self.contentSize.height)
        _nearEnd();
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (!CGSizeEqualToSize(_lastBoundsSize, self.bounds.size))
    {
        _lastBoundsSize = self.bounds.size;
        [self updateContentSize];
    }
    [self layoutVisibleTiles];
}

@end
