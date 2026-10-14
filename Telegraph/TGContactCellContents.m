#import "TGContactCellContents.h"

#import "TGPresentation.h"

@interface TGContactCellContents ()

@property (nonatomic) NSString *validTitleFirst;
@property (nonatomic) NSString *validTitleSecond;
@property (nonatomic) int validTitleBoldMode;
@property (nonatomic) CGFloat validWidth;
@property (nonatomic) CGPoint validTitleOffset;
@property (nonatomic) bool validHighlighted;

@end

@implementation TGContactCellContents

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.opaque = false;
        self.contentMode = UIViewContentModeLeft;
    }
    return self;
}

- (void)requestRedrawIfNeeded
{
    if (_validHighlighted != self.highlighted ||
        ABS(_validWidth - self.frame.size.width) > FLT_EPSILON ||
        !CGPointEqualToPoint(_validTitleOffset, _titleOffset) ||
        _validTitleBoldMode != _titleBoldMode ||
        ((_validTitleFirst == nil) != (_titleFirst != nil) || (_validTitleFirst != nil && ![_validTitleFirst isEqualToString:_titleFirst])) ||
        ((_validTitleSecond == nil) != (_titleSecond != nil) || (_validTitleSecond != nil && ![_validTitleSecond isEqualToString:_titleSecond])))
    {
        [self setNeedsDisplay];
    }
}

- (void)setHighlighted:(bool)highlighted
{
    _highlighted = highlighted;
    
    [self requestRedrawIfNeeded];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    [self requestRedrawIfNeeded];
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)__unused rect
{
    CGSize size = self.frame.size;
    
    _validTitleFirst = _titleFirst;
    _validTitleSecond = _titleSecond;
    _validTitleBoldMode = _titleBoldMode;
    _validWidth = size.width;
    _validTitleOffset = _titleOffset;
    _validHighlighted = self.highlighted;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIFont *titleFirstFont = (_titleBoldMode & 1) ? _titleBoldFont : _titleFont;
    UIFont *titleSecondFont = (_titleBoldMode & 2) ? _titleBoldFont : _titleFont;
    
    CGSize titleFirstSize = [_titleFirst sizeWithFont:titleFirstFont];
    CGFloat rightInset = _titleRightInset > 0.0f ? _titleRightInset : 8.0f;
    CGFloat availableWidth = MAX(0.0f, size.width - _titleOffset.x - rightInset);
    titleFirstSize.width = MIN(titleFirstSize.width, MAX(0.0f, availableWidth - (_titleRightInset <= 0.0f || _titleSecond.length != 0 ? 11.0f : 0.0f)));
    
    CGSize titleSecondSize = [_titleSecond sizeWithFont:titleSecondFont];
    titleSecondSize.width = MIN(titleSecondSize.width, MAX(0.0f, availableWidth - titleFirstSize.width - 4.0f));
    
    if (_isDisabled)
    {
        static UIColor *disabledColor = nil;
        if (disabledColor == nil)
            disabledColor = UIColorRGB(0xaeaeae);
        CGContextSetFillColorWithColor(context, disabledColor.CGColor);
    }
    else
        CGContextSetFillColorWithColor(context, (_titleColor ?: _presentation.pallete.textColor).CGColor);
    
    [_titleFirst drawInRect:CGRectMake(_titleOffset.x, _titleOffset.y, titleFirstSize.width, titleFirstSize.height) withFont:titleFirstFont lineBreakMode:NSLineBreakByTruncatingTail];
    
    [_titleSecond drawInRect:CGRectMake(_titleOffset.x + titleFirstSize.width + 4, _titleOffset.y, titleSecondSize.width, titleFirstSize.height) withFont:titleSecondFont];
    
    if (_dateLabel != nil && !_dateLabel.hidden && _dateLabel.frame.size.width > FLT_EPSILON && _dateLabel.frame.size.height > FLT_EPSILON)
    {
        CGRect dateFrame = _dateLabel.frame;
        CGContextTranslateCTM(context, dateFrame.origin.x, dateFrame.origin.y);
        _dateLabel.highlighted = _highlighted;
        [_dateLabel drawRect:CGRectMake(0, 0, dateFrame.size.width, dateFrame.size.height)];
    }
}

@end
