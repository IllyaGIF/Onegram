#import "TGModernLabelViewModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../OnegramPlatform/OGPlatformText.h"

@interface TGModernLabelViewModel ()
{
    NSString *_text;
    CTLineRef _line;
    CTFontRef _font;
    bool _truncateInTheMiddle;
    
    CGSize _lastSize;
}

@end

@implementation TGModernLabelViewModel

- (instancetype)initWithText:(NSString *)text textColor:(UIColor *)textColor font:(CTFontRef)font maxWidth:(CGFloat)maxWidth
{
    return [self initWithText:text textColor:textColor font:font maxWidth:maxWidth truncateInTheMiddle:false];
}

- (instancetype)initWithText:(NSString *)text textColor:(UIColor *)textColor font:(CTFontRef)font maxWidth:(CGFloat)maxWidth truncateInTheMiddle:(bool)truncateInTheMiddle
{
    self = [super init];
    if (self != nil)
    {
        self.hasNoView = true;
        
        _textColor = textColor;
        
        if (font != NULL)
            _font = CFRetain(font);
        
        _truncateInTheMiddle = truncateInTheMiddle;
        
        [self setText:text maxWidth:maxWidth];
    }
    return self;
}

- (void)dealloc
{
    if (_line != NULL)
    {
        CFRelease(_line);
        _line = NULL;
    }
    
    if (_font != NULL)
    {
        CFRelease(_font);
        _font = nil;
    }
}

- (bool)updateFont:(CTFontRef)font
{
    if (_font == font || (_font != NULL && font != NULL && CFEqual(_font, font)))
        return false;
    CTFontRef previousFont = _font;
    _font = font == NULL ? NULL : CFRetain(font);
    if (previousFont != NULL)
        CFRelease(previousFont);
    [self setText:_text maxWidth:_maxWidth];
    return true;
}

- (void)setText:(NSString *)text maxWidth:(CGFloat)maxWidth
{
    [self setText:text maxWidth:maxWidth needsContentUpdate:NULL];
}

- (void)setText:(NSString *)text maxWidth:(CGFloat)maxWidth needsContentUpdate:(bool *)needsContentUpdate
{
    text = text ? : @"";
    
    _text = text;
    _maxWidth = maxWidth;
    
    if (_line != NULL)
    {
        CFRelease(_line);
        _line = nil;
    }
    
    if (_font != NULL)
    {
        NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:text attributes:[[NSDictionary alloc] initWithObjectsAndKeys:(__bridge id)_font, (__bridge id)kCTFontAttributeName, kCFBooleanTrue, (__bridge id)kCTForegroundColorFromContextAttributeName, nil]];
        if (maxWidth < FLT_MAX - FLT_EPSILON)
        {
            static NSString *tokenString = nil;
            if (tokenString == nil)
            {
                unichar tokenChar = 0x2026;
                tokenString = [[NSString alloc] initWithCharacters:&tokenChar length:1];
            }
            
            NSMutableDictionary *truncationTokenAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:(__bridge id)_font, (__bridge NSString *)kCTFontAttributeName, (__bridge id)_textColor.CGColor, (__bridge NSString *)kCTForegroundColorAttributeName, nil];
            NSAttributedString *truncationTokenString = [[NSAttributedString alloc] initWithString:tokenString attributes:truncationTokenAttributes];
            _line = OGPlatformCreateTruncatedLine(NULL, (__bridge CFAttributedStringRef)attributedText, CFRangeMake(0, (CFIndex)attributedText.length), 0.0, maxWidth, _truncateInTheMiddle ? kCTLineTruncationMiddle : kCTLineTruncationEnd, (__bridge CFAttributedStringRef)truncationTokenString, false);
        }
        else
            _line = OGPlatformTextCreateLine((__bridge CFAttributedStringRef)attributedText);
        
        if (_line != NULL)
        {
            CGFloat ascent = 0.0f;
            CGFloat descent = 0.0f;
            CGFloat leading = 0.0f;
            CGFloat width = (CGFloat)CTLineGetTypographicBounds(_line, &ascent, &descent, &leading);
            
            CGRect bounds = CGRectMake(0.0f, -descent, width, ascent + descent + leading);
            bounds.origin = CGPointZero;
            bounds.size.width = CGFloor(bounds.size.width);
            bounds.size.height = CGFloor(bounds.size.height);
            if (!CGRectIsNull(bounds))
            {
                CGRect frame = self.frame;
                frame.size = bounds.size;
                self.frame = frame;
            }
            
            if (needsContentUpdate)
                *needsContentUpdate = CGSizeEqualToSize(bounds.size, _lastSize);
            _lastSize = bounds.size;
        }
    }
}

- (NSString *)text
{
    return _text;
}

- (void)setMaxWidth:(CGFloat)maxWidth
{
    if (ABS(_maxWidth - maxWidth) > FLT_EPSILON)
    {
        _maxWidth = maxWidth;
        [self setText:_text maxWidth:_maxWidth];
    }
}

static void TGModernLabelViewModelDrawOperation(CGContextRef context, TGModernDrawingOperation *operation)
{
    CGContextSetTextPosition(context, 0.0f, 0.0f);
    CGAffineTransform xform = CGAffineTransformMake(1.0, 0.0, 0.0, -1.0f, 0.0, CGFloor(operation.rect.size.height / 1.0f));
    CGContextSetTextMatrix(context, xform);
    
    CGContextSetFillColorWithColor(context, operation.color.CGColor);
    
    CTLineRef line = (__bridge CTLineRef)operation.object;
    if (line != NULL)
        CTLineDraw(line, context);
    
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
}

- (bool)recordDrawing:(TGModernDrawingRecording *)recording
{
    if (![self drawsInContextWithImplementationOfClass:[TGModernLabelViewModel class]])
        return false;
    if (![self recordBaseDrawing:recording])
        return false;
    [recording addOperationWithFunction:&TGModernLabelViewModelDrawOperation rect:CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height) object:(__bridge id)_line secondaryObject:nil color:_textColor == nil ? [UIColor blackColor] : _textColor size:CGSizeZero value:0.0f flags:0];
    return true;
}

- (void)drawInContext:(CGContextRef)context
{
    [super drawInContext:context];
    
    CGContextSetTextPosition(context, 0.0f, 0.0f);
    CGAffineTransform xform = CGAffineTransformMake(1.0, 0.0, 0.0, -1.0f, 0.0, CGFloor(self.frame.size.height / 1.0f));
    CGContextSetTextMatrix(context, xform);
    
    if (_textColor == nil)
        CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    else
        CGContextSetFillColorWithColor(context, _textColor.CGColor);
    
    if (_line != NULL)
        CTLineDraw(_line, context);
    
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
}

@end
