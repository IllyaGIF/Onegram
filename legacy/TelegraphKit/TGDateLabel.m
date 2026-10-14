#import "TGDateLabel.h"
#import "../../OnegramPlatform/OGMemoryCache.h"

@interface NSAttributedString (TGDateLabelDrawing)
- (CGSize)size;
- (void)drawAtPoint:(CGPoint)point;
@end

#import "../../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

typedef enum {
    TGDateLabelFormatModeNone = 0,
    TGDateLabelFormatModeAm = 1,
    TGDateLabelFormatModePm = 2
} TGDateLabelFormatMode;

@interface TGDateLabel ()
{
    CGSize _measuredTextSize;
    bool _measuredTextSizeIsValid;
    NSAttributedString *_attributedDateText;
}

@property (nonatomic) TGDateLabelFormatMode formatMode;

@end

@implementation TGDateLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
    }
    return self;
}

- (void)setDateFont:(UIFont *)value
{
    if (_dateFont == value)
        return;
    _dateFont = value;
    _measuredTextSizeIsValid = false;
    [self setNeedsDisplay];
}

- (void)setDateTextFont:(UIFont *)value
{
    if (_dateTextFont == value)
        return;
    _dateTextFont = value;
    _measuredTextSizeIsValid = false;
    [self setNeedsDisplay];
}

- (void)setDateLabelFont:(UIFont *)value
{
    if (_dateLabelFont == value)
        return;
    _dateLabelFont = value;
    _measuredTextSizeIsValid = false;
    [self setNeedsDisplay];
}

- (void)setAmWidth:(CGFloat)value
{
    if (_amWidth == value)
        return;
    _amWidth = value;
    _measuredTextSizeIsValid = false;
    [self setNeedsDisplay];
}

- (void)setPmWidth:(CGFloat)value
{
    if (_pmWidth == value)
        return;
    _pmWidth = value;
    _measuredTextSizeIsValid = false;
    [self setNeedsDisplay];
}

- (void)setText:(NSString *)text
{
    [self setDateText:text];
}

- (void)setDateText:(NSString *)dateText
{
    dateText = [dateText copy];
    BOOL use12h = TGUse12hDateFormat();
    BOOL isAm = use12h && [dateText hasSuffix:@" AM"];
    BOOL isPm = use12h && [dateText hasSuffix:@" PM"];
    TGDateLabelFormatMode format = isAm ? TGDateLabelFormatModeAm : (isPm ? TGDateLabelFormatModePm : TGDateLabelFormatModeNone);
    if (_attributedDateText == nil && format == _formatMode && (_rawDateText == dateText || [_rawDateText isEqualToString:dateText]))
        return;
    _attributedDateText = nil;
    _measuredTextSizeIsValid = false;
    _rawDateText = dateText;
    _formatMode = format;
    _dateText = format == TGDateLabelFormatModeNone ? dateText : [dateText substringToIndex:dateText.length - 3];
    [self setNeedsDisplay];
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    _dateText = nil;
    _rawDateText = nil;
    _attributedDateText = [attributedText copy];
    _measuredTextSizeIsValid = false;
    [self setNeedsDisplay];
}

+ (CGSize)measureDateText:(NSString *)text dateFont:(UIFont *)dateFont textFont:(UIFont *)textFont amWidth:(CGFloat)amWidth pmWidth:(CGFloat)pmWidth
{
    if (text.length == 0 || dateFont == nil)
        return CGSizeZero;
    text = [text copy];
    BOOL use12h = TGUse12hDateFormat();
    NSArray *key = @[text, dateFont, textFont ?: dateFont, @(amWidth), @(pmWidth), @(use12h)];
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[OGMemoryCache alloc] initWithCountLimit:256 costLimit:64 * 1024];
    });
    NSValue *cached = [cache objectForKey:key];
    if (cached != nil)
        return cached.CGSizeValue;
    BOOL isAm = use12h && [text hasSuffix:@" AM"];
    BOOL isPm = use12h && [text hasSuffix:@" PM"];
    NSString *date = isAm || isPm ? [text substringToIndex:text.length - 3] : text;
    CGSize size = [date sizeWithFont:isAm || isPm ? (textFont ?: dateFont) : dateFont];
    size.width += isAm ? amWidth : (isPm ? pmWidth : 0.0f);
    [cache setObject:[NSValue valueWithCGSize:size] forKey:key cost:128 + text.length * sizeof(unichar)];
    return size;
}

- (CGSize)measureTextSize
{
    if (_measuredTextSizeIsValid)
        return _measuredTextSize;
    
    if (_attributedDateText != nil)
    {
        CGSize textSize = [_attributedDateText size];
        _measuredTextSize = textSize;
        _measuredTextSizeIsValid = true;
        return textSize;
    }
    else
    {
        CGSize textSize = [TGDateLabel measureDateText:_rawDateText dateFont:_dateFont textFont:_dateTextFont amWidth:_amWidth pmWidth:_pmWidth];

        _measuredTextSize = textSize;
        _measuredTextSizeIsValid = true;
        return textSize;
    }
}

- (void)setHighlighted:(BOOL)__unused highlighted
{
}

- (void)drawTextInRect:(CGRect)__unused rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if (_attributedDateText != nil)
    {
        [_attributedDateText drawAtPoint:CGPointMake(0.0f, 0.0f)];
    }
    else
    {
        switch (self.textAlignment)
        {
            case NSTextAlignmentCenter:
                CGContextTranslateCTM(context, CGFloor((self.frame.size.width - _measuredTextSize.width) / 2), 0);
                break;
            default:
                break;
        }
        
        if (self.shadowColor != nil)
            CGContextSetShadowWithColor(context, self.shadowOffset, 0.0f, self.shadowColor.CGColor);
        
        if (_isDisabled)
        {
            if (_disabledColor != nil)
                CGContextSetFillColorWithColor(context, [_disabledColor CGColor]);
            else
            {
                static UIColor *disabledColor = nil;
                if (disabledColor == nil)
                    disabledColor = UIColorRGB(0xaeaeae);
                CGContextSetFillColorWithColor(context, disabledColor.CGColor);
            }
        }
        else
        {
            CGContextSetFillColorWithColor(context, self.textColor.CGColor);
        }
        
        [_dateText drawAtPoint:CGPointMake(0, 0) withFont:_formatMode != TGDateLabelFormatModeNone ? _dateTextFont : _dateFont];
        
        if (_formatMode != TGDateLabelFormatModeNone)
            [_formatMode == TGDateLabelFormatModeAm ? @"AM" : @"PM" drawInRect:CGRectMake(0, _dstOffset, _measuredTextSize.width, self.bounds.size.height) withFont:_dateLabelFont lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentRight];
    }
}

- (void)drawRect:(CGRect)__unused rect
{
    [self drawTextInRect:self.bounds];
}

@end
