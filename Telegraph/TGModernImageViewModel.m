#import "TGModernImageViewModel.h"

#import "TGModernImageView.h"

@interface TGModernImageViewModel ()
{
    bool _accountForTransform;
}
@end

@implementation TGModernImageViewModel

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super init];
    if (self != nil)
    {
        _image = image;
    }
    return self;
}

- (void)setAccountForTransform:(bool)accountForTransform
{
    _accountForTransform = accountForTransform;
    TGModernImageView *view = (TGModernImageView *)[self boundView];
    if (view != nil)
        [view setAccountForTransform:_accountForTransform];
}

- (Class)viewClass
{
    return [TGModernImageView class];
}

- (void)_updateViewStateIdentifier
{
    self.viewStateIdentifier = [[NSString alloc] initWithFormat:@"TGModernImageView/%lx", (long)_image];
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [self _updateViewStateIdentifier];
    
    [super bindViewToContainer:container viewStorage:viewStorage];
    
    TGModernImageView *view = (TGModernImageView *)[self boundView];
    if (!TGStringCompare(view.viewStateIdentifier, self.viewStateIdentifier))
        view.image = _image;
    
    if (iosMajorVersion() >= 11)
        view.accessibilityIgnoresInvertColors = _ignoresInvertColors;
    
    view.extendedEdges = _extendedEdges;
    [view setAccountForTransform:_accountForTransform];
}

- (void)setIgnoresInvertColors:(bool)ignoresInvertColors
{
    _ignoresInvertColors = ignoresInvertColors;
    if (iosMajorVersion() >= 11)
        ((TGModernImageView *)self.boundView).accessibilityIgnoresInvertColors = _ignoresInvertColors;
}

static void TGModernImageViewModelDrawOperation(__unused CGContextRef context, TGModernDrawingOperation *operation)
{
    [(UIImage *)operation.object drawInRect:operation.rect blendMode:(CGBlendMode)operation.flags alpha:1.0f];
}

- (bool)recordDrawing:(TGModernDrawingRecording *)recording
{
    if (![self drawsInContextWithImplementationOfClass:[TGModernImageViewModel class]])
        return false;
    if (![self recordBaseDrawing:recording])
        return false;
    if (!self.skipDrawInContext && self.alpha > FLT_EPSILON && !self.hidden && _image != nil)
        [recording addOperationWithFunction:&TGModernImageViewModelDrawOperation rect:self.bounds object:_image secondaryObject:nil color:nil size:CGSizeZero value:0.0f flags:(int)_blendMode];
    return true;
}

- (void)drawInContext:(CGContextRef)context
{
    [super drawInContext:context];
    
    if (!self.skipDrawInContext && self.alpha > FLT_EPSILON && !self.hidden)
        [_image drawInRect:self.bounds blendMode:_blendMode alpha:1.0f];
}

- (void)sizeToFit
{
    CGRect frame = self.frame;
    frame.size = _image.size;
    self.frame = frame;
}

@end
