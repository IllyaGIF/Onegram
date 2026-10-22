#import "TGModernCollectionCell.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGMessageModernConversationItem.h"
#import "TGModernFlatteningViewModel.h"

@interface TGModernCollectionCellLayer : CALayer

@end

@implementation TGModernCollectionCellLayer

- (void)setShouldRasterize:(BOOL)shouldRasterize
{
    if (shouldRasterize)
        [super setShouldRasterize:false];
}

- (void)setHidden:(BOOL)hidden
{
    [super setHidden:hidden];
}

@end

@interface TGModernCollectionCell ()
{
    bool _editing;
    UIView *_contentViewForBinding;
}

@end

@implementation TGModernCollectionCell

+ (Class)layerClass
{
    return [TGModernCollectionCellLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.clipsToBounds = true;
        
        _contentViewForBinding = [[UIView alloc] initWithFrame:(CGRect){CGPointZero, self.bounds.size}];
        _contentViewForBinding.transform = CGAffineTransformMakeScale(-1.0f, -1.0f);
        [self addSubview:_contentViewForBinding];
        [self _layoutContentViewForBinding];
    }
    return self;
}

- (void)relativeBoundsUpdated:(CGRect)bounds
{
    id item = _boundItem;
    if (item != nil && [item conformsToProtocol:@protocol(TGModernCollectionRelativeBoundsObserver)])
    {
        CGRect convertedBounds = [[self contentViewForBinding] convertRect:bounds fromView:self];
        [item relativeBoundsUpdated:self bounds:convertedBounds];
    }
}

- (void)setEditing:(bool)editing animated:(bool)__unused animated viewStorage:(TGModernViewStorage *)__unused viewStorage
{
    if (_editing != editing)
    {
        _editing = editing;
        [self contentViewForBinding].userInteractionEnabled = !_editing;
    }
}

- (void)_layoutContentViewForBinding
{
    if (_contentViewForBinding == nil)
        return;
    CGRect bounds = self.bounds;
    CGRect contentBounds = (CGRect){CGPointZero, bounds.size};
    if (!CGRectEqualToRect(_contentViewForBinding.bounds, contentBounds))
        _contentViewForBinding.bounds = contentBounds;
    CGPoint center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    if (!CGPointEqualToPoint(_contentViewForBinding.center, center))
        _contentViewForBinding.center = center;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self _layoutContentViewForBinding];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    
    [self _layoutContentViewForBinding];
}

- (UIView *)contentViewForBinding
{
    return _contentViewForBinding;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    bool initial = [super pointInside:point withEvent:event];
    
    id item = _boundItem;
    if (initial && item != nil && [item conformsToProtocol:@protocol(TGModernCollectionPointInsideSolver)])
    {
        if ([item pointInside] != nil)
        {
            CGPoint convertedPoint = [[self contentViewForBinding] convertPoint:point fromView:self];
            return [item pointInside](convertedPoint);
        }
    }
    
    return initial;
}

@end
