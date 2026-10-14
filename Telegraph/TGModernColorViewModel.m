#import "TGModernColorViewModel.h"

#import "TGModernColorView.h"

@interface TGModernColorViewModel ()
{
    UIColor *_color;
    CGFloat _cornerRadius;
}

@end

@implementation TGModernColorViewModel

- (instancetype)initWithColor:(UIColor *)color
{
    return [self initWithColor:color cornerRadius:0.0f];
}

- (instancetype)initWithColor:(UIColor *)color cornerRadius:(CGFloat)cornerRadius
{
    self = [super init];
    if (self != nil)
    {
        _color = color;
        _cornerRadius = cornerRadius;
    }
    return self;
}

- (Class)viewClass
{
    return [TGModernColorView class];
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [super bindViewToContainer:container viewStorage:viewStorage];
    
    [self boundView].backgroundColor = _color;
}

static void TGModernColorViewModelDrawOperation(CGContextRef context, TGModernDrawingOperation *operation)
{
    CGContextSetFillColorWithColor(context, operation.color.CGColor);
    if (operation.value > FLT_EPSILON) {
        CGContextAddPath(context, [UIBezierPath bezierPathWithRoundedRect:operation.rect cornerRadius:operation.value].CGPath);
        CGContextFillPath(context);
    } else {
        CGContextFillRect(context, operation.rect);
    }
}

- (bool)recordDrawing:(TGModernDrawingRecording *)recording
{
    if (![self drawsInContextWithImplementationOfClass:[TGModernColorViewModel class]])
        return false;
    if (![self recordBaseDrawing:recording])
        return false;
    if (!self.skipDrawInContext && _color != nil && self.alpha > FLT_EPSILON)
        [recording addOperationWithFunction:&TGModernColorViewModelDrawOperation rect:self.bounds object:nil secondaryObject:nil color:_color size:CGSizeZero value:_cornerRadius flags:0];
    return true;
}

- (void)drawInContext:(CGContextRef)context
{
    [super drawInContext:context];
    
    if (!self.skipDrawInContext && _color != nil && self.alpha > FLT_EPSILON)
    {
        CGContextSetFillColorWithColor(context, _color.CGColor);
        if (_cornerRadius > FLT_EPSILON) {
            CGContextAddPath(context, [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:_cornerRadius].CGPath);
            CGContextFillPath(context);
        } else {
            CGContextFillRect(context, self.bounds);
        }
    }
}

@end
