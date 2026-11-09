#import "TGModernTextViewModel.h"

#import "TGModernTextView.h"

#import "TGReusableLabel.h"
#import "../OnegramPlatform/OGMemoryCache.h"

@interface TGModernTextLayoutKey : NSObject <NSCopying>
{
@public
    NSString *_text;
    NSArray *_additionalAttributes;
    NSArray *_textCheckingResults;
    CTFontRef _font;
    UIColor *_textColor;
    UIColor *_linkColor;
    CGFloat _width;
    int _flags;
    NSTextAlignment _alignment;
    CGFloat _additionalTrailingWidth;
    NSUInteger _maxNumberOfLines;
    NSUInteger _numberOfLinesToInset;
    CGFloat _linesInset;
    CGFloat _additionalLineSpacing;
    NSString *_ellipsisString;
    bool _underlineAllLinks;
}
@end

@implementation TGModernTextLayoutKey

- (void)dealloc
{
    if (_font != NULL)
        CFRelease(_font);
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    return self;
}

- (NSUInteger)hash
{
    return _text.hash ^ ((NSUInteger)lroundf((float)_width * 4.0f) << 8) ^ ((NSUInteger)_flags << 20) ^ (_textCheckingResults.count << 26);
}

static bool TGModernTextLayoutObjectsEqual(id lhs, id rhs)
{
    return lhs == rhs || [lhs isEqual:rhs];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[TGModernTextLayoutKey class]])
        return NO;
    TGModernTextLayoutKey *other = object;
    if (_width != other->_width || _flags != other->_flags || _alignment != other->_alignment || _additionalTrailingWidth != other->_additionalTrailingWidth || _maxNumberOfLines != other->_maxNumberOfLines || _numberOfLinesToInset != other->_numberOfLinesToInset || _linesInset != other->_linesInset || _additionalLineSpacing != other->_additionalLineSpacing || _underlineAllLinks != other->_underlineAllLinks)
        return NO;
    if (!(_font == other->_font || (_font != NULL && other->_font != NULL && CFEqual(_font, other->_font))))
        return NO;
    if (![_text isEqualToString:other->_text])
        return NO;
    return TGModernTextLayoutObjectsEqual(_textColor, other->_textColor) && TGModernTextLayoutObjectsEqual(_linkColor, other->_linkColor) && TGModernTextLayoutObjectsEqual(_ellipsisString, other->_ellipsisString) && TGModernTextLayoutObjectsEqual(_textCheckingResults, other->_textCheckingResults) && TGModernTextLayoutObjectsEqual(_additionalAttributes, other->_additionalAttributes);
}

@end

@interface TGModernTextLayoutResult : NSObject
{
@public
    TGReusableLabelLayoutData *_layoutData;
    bool _isRTL;
    bool _containsEmptyNewline;
}
@end

@implementation TGModernTextLayoutResult
@end

static OGMemoryCache *TGModernTextLayoutCache(void)
{
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[OGMemoryCache alloc] initWithCountLimit:384 costLimit:OGMemoryCacheBudget(3 * 1024 * 1024)];
    });
    return cache;
}

@implementation TGModernTextViewLinesInset

- (instancetype)initWithNumberOfLinesToInset:(NSUInteger)numberOfLinesToInset inset:(CGFloat)inset
{
    self = [super init];
    if (self != nil)
    {
        _numberOfLinesToInset = numberOfLinesToInset;
        _inset = inset;
    }
    return self;
}

@end

@interface TGModernTextViewModel ()
{
    TGReusableLabelLayoutData *_layoutData;
    CGFloat _cachedLayoutContainerWidth;
    int _cachedLayoutFlags;
    CGFloat _cachedAdditionalTrailingWidth;
    NSUInteger _pluginColorGeneration;
}

@end

@implementation TGModernTextViewModel

- (instancetype)initWithText:(NSString *)text font:(CTFontRef)font
{
    self = [super init];
    if (self != nil)
    {
        if (text.length != 0)
            _text = text;
        else
            _text = @" ";
        
        _linkColor = UIColorRGB(0x004bad);
        
        if (font != NULL)
            _font = (CTFontRef)CFRetain(font);

    }
    return self;
}

- (void)dealloc
{
    if (_font != NULL)
    {
        CFRelease(_font);
        _font = NULL;
    }
}

- (Class)viewClass
{
    return [TGModernTextView class];
}

- (void)sizeToFit
{
    
}

- (void)drawInContext:(CGContextRef)context
{
    [super drawInContext:context];
    
    if (_layoutData != nil)
    {
        [TGReusableLabel drawRichTextInRect:self.bounds precalculatedLayout:_layoutData linesRange:NSMakeRange(0, 0) shadowColor:_shadowColor shadowOffset:_shadowOffset];
    }
}

static void TGModernTextViewModelDrawOperation(__unused CGContextRef context, TGModernDrawingOperation *operation)
{
    [TGReusableLabel drawRichTextInRect:operation.rect precalculatedLayout:operation.object linesRange:NSMakeRange(0, 0) shadowColor:operation.color shadowOffset:operation.size];
}

- (bool)recordDrawing:(TGModernDrawingRecording *)recording
{
    if (![self drawsInContextWithImplementationOfClass:[TGModernTextViewModel class]])
        return false;
    if (![self recordBaseDrawing:recording])
        return false;
    if (_layoutData != nil)
    {
        TGReusableLabelLayoutData *layout = _layoutData;
        CGRect bounds = self.bounds;
        UIColor *shadowColor = _shadowColor;
        CGSize shadowOffset = _shadowOffset;
        [recording addOperationWithFunction:&TGModernTextViewModelDrawOperation rect:bounds object:layout secondaryObject:nil color:shadowColor size:shadowOffset value:0.0f flags:0];
        if (layout.hasCustomDrawing)
        {
            [recording prepareLastOperationWithBlock:^id(CGRect rect)
            {
                return [layout asynchronousDrawingLayoutForWidth:bounds.size.width drawingRect:rect shadowColor:shadowColor shadowOffset:shadowOffset];
            }];
        }
    }
    return true;
}

- (bool)layoutNeedsUpdatingForContainerSize:(CGSize)containerSize
{
    return [self layoutNeedsUpdatingForContainerSize:containerSize additionalTrailingWidth:_additionalTrailingWidth layoutFlags:_layoutFlags];
}

- (bool)layoutNeedsUpdatingForContainerSize:(CGSize)containerSize additionalTrailingWidth:(CGFloat)additionalTrailingWidth layoutFlags:(int)layoutFlags
{
    if (_layoutData == nil || ABS(containerSize.width - _cachedLayoutContainerWidth) > FLT_EPSILON || _cachedLayoutFlags != layoutFlags || ABS(_cachedAdditionalTrailingWidth - additionalTrailingWidth) > FLT_EPSILON)
        return true;
    return false;
}

- (void)setText:(NSString *)text
{
    if (!TGStringCompare(_text, text))
    {
        _cachedLayoutContainerWidth = 0.0f;
        _cachedLayoutFlags = 0;
        
        if (text.length != 0)
            _text = text;
        else
            _text = @" ";

    }
}

- (void)setMaxNumberOfLines:(NSUInteger)maxNumberOfLines
{
    if (_maxNumberOfLines != maxNumberOfLines)
    {
        _maxNumberOfLines = maxNumberOfLines;
        _cachedLayoutContainerWidth = 0.0f;
        _cachedLayoutFlags = 0;
    }
}

- (void)setFont:(CTFontRef)font
{
    if (_font != font)
    {
        _cachedLayoutContainerWidth = 0.0f;
        _cachedLayoutFlags = 0;
        
        if (_font != NULL)
        {
            CFRelease(_font);
            _font = NULL;
        }
        
        if (font != NULL)
            _font = (CTFontRef)CFRetain(font);
    }
}

- (void)layoutForContainerSize:(CGSize)containerSize
{
    if (_layoutData == nil || ABS(containerSize.width - _cachedLayoutContainerWidth) > FLT_EPSILON || _cachedLayoutFlags != _layoutFlags || ABS(_additionalTrailingWidth - _cachedAdditionalTrailingWidth) > FLT_EPSILON)
    {
        TGModernTextLayoutKey *key = [[TGModernTextLayoutKey alloc] init];
        key->_text = [_text copy];
        key->_additionalAttributes = [_additionalAttributes copy];
        key->_textCheckingResults = [_textCheckingResults copy];
        key->_font = _font != NULL ? (CTFontRef)CFRetain(_font) : NULL;
        key->_textColor = _textColor;
        key->_linkColor = _linkColor;
        key->_width = (CGFloat)(float)containerSize.width;
        key->_flags = _layoutFlags;
        key->_alignment = (NSTextAlignment)_alignment;
        key->_additionalTrailingWidth = _additionalTrailingWidth;
        key->_maxNumberOfLines = _maxNumberOfLines;
        key->_numberOfLinesToInset = _linesInset.numberOfLinesToInset;
        key->_linesInset = _linesInset.inset;
        key->_additionalLineSpacing = _additionalLineSpacing;
        key->_ellipsisString = [_ellipsisString copy];
        key->_underlineAllLinks = _underlineAllLinks;
        OGMemoryCache *cache = TGModernTextLayoutCache();
        TGModernTextLayoutResult *cached = [cache objectForKey:key];
        if (cached != nil)
        {
            _layoutData = cached->_layoutData;
            _isRTL = cached->_isRTL;
            _containsEmptyNewline = cached->_containsEmptyNewline;
        }
        else
        {
            _containsEmptyNewline = false;
            _layoutData = [TGReusableLabel calculateLayout:_text additionalAttributes:_additionalAttributes textCheckingResults:_textCheckingResults font:_font textColor:_textColor linkColor:_linkColor frame:CGRectZero orMaxWidth:(float)containerSize.width flags:_layoutFlags textAlignment:(NSTextAlignment)_alignment outIsRTL:&_isRTL additionalTrailingWidth:_additionalTrailingWidth maxNumberOfLines:_maxNumberOfLines numberOfLinesToInset:_linesInset.numberOfLinesToInset linesInset:_linesInset.inset containsEmptyNewline:&_containsEmptyNewline additionalLineSpacing:_additionalLineSpacing ellipsisString:_ellipsisString underlineAllLinks:_underlineAllLinks];
            if (_layoutData != nil)
            {
                TGModernTextLayoutResult *result = [[TGModernTextLayoutResult alloc] init];
                result->_layoutData = _layoutData;
                result->_isRTL = _isRTL;
                result->_containsEmptyNewline = _containsEmptyNewline;
                [cache setObject:result forKey:key cost:512 + _text.length * 8];
            }
        }
        _cachedLayoutContainerWidth = containerSize.width;
        _cachedLayoutFlags = _layoutFlags;
        _cachedAdditionalTrailingWidth = _additionalTrailingWidth;
    }
    
    CGRect frame = self.frame;
    frame.size = _layoutData.size;
    frame.size.width = CGFloor(frame.size.width);
    frame.size.height = CGFloor(frame.size.height);
    self.frame = frame;

}

- (void)refreshPluginColors
{
    CGFloat width = _cachedLayoutContainerWidth > FLT_EPSILON ? _cachedLayoutContainerWidth : MAX(1.0f, self.frame.size.width);
    NSUInteger generation = ++_pluginColorGeneration;
    NSString *text = [_text copy];
    NSArray *attributes = [_additionalAttributes copy];
    NSArray *checks = [_textCheckingResults copy];
    CTFontRef font = _font != NULL ? (CTFontRef)CFRetain(_font) : NULL;
    UIColor *textColor = _textColor;
    UIColor *linkColor = _linkColor;
    int flags = _layoutFlags;
    NSTextAlignment alignment = _alignment;
    CGFloat trailingWidth = _additionalTrailingWidth;
    NSUInteger maxLines = _maxNumberOfLines;
    NSUInteger insetLines = _linesInset.numberOfLinesToInset;
    CGFloat linesInset = _linesInset.inset;
    CGFloat spacing = _additionalLineSpacing;
    NSString *ellipsis = [_ellipsisString copy];
    bool underline = _underlineAllLinks;
    __weak TGModernTextViewModel *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        TGModernTextLayoutKey *key = [[TGModernTextLayoutKey alloc] init];
        key->_text = text;
        key->_additionalAttributes = attributes;
        key->_textCheckingResults = checks;
        key->_font = font != NULL ? (CTFontRef)CFRetain(font) : NULL;
        key->_textColor = textColor;
        key->_linkColor = linkColor;
        key->_width = (CGFloat)(float)width;
        key->_flags = flags;
        key->_alignment = alignment;
        key->_additionalTrailingWidth = trailingWidth;
        key->_maxNumberOfLines = maxLines;
        key->_numberOfLinesToInset = insetLines;
        key->_linesInset = linesInset;
        key->_additionalLineSpacing = spacing;
        key->_ellipsisString = ellipsis;
        key->_underlineAllLinks = underline;
        OGMemoryCache *cache = TGModernTextLayoutCache();
        if ([cache objectForKey:key] == nil)
        {
            bool rtl = false;
            bool containsNewline = false;
            TGReusableLabelLayoutData *layout = [TGReusableLabel calculateLayout:text additionalAttributes:attributes textCheckingResults:checks font:font textColor:textColor linkColor:linkColor frame:CGRectZero orMaxWidth:(float)width flags:flags textAlignment:alignment outIsRTL:&rtl additionalTrailingWidth:trailingWidth maxNumberOfLines:maxLines numberOfLinesToInset:insetLines linesInset:linesInset containsEmptyNewline:&containsNewline additionalLineSpacing:spacing ellipsisString:ellipsis underlineAllLinks:underline];
            if (layout != nil)
            {
                TGModernTextLayoutResult *value = [[TGModernTextLayoutResult alloc] init];
                value->_layoutData = layout;
                value->_isRTL = rtl;
                value->_containsEmptyNewline = containsNewline;
                [cache setObject:value forKey:key cost:512 + text.length * 8];
            }
        }
        if (font != NULL)
            CFRelease(font);
        dispatch_async(dispatch_get_main_queue(), ^
        {
            TGModernTextViewModel *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf->_pluginColorGeneration != generation || !TGStringCompare(strongSelf->_text, text) || strongSelf->_textColor != textColor || strongSelf->_linkColor != linkColor)
                return;
            strongSelf->_cachedLayoutContainerWidth = 0.0f;
            [strongSelf layoutForContainerSize:CGSizeMake(width, 0.0f)];
            [[strongSelf boundView] setNeedsDisplay];
        });
    });
}

- (NSString *)linkAtPoint:(CGPoint)point regionData:(__autoreleasing NSArray **)regionData
{
    return [self linkAtPoint:point regionData:regionData hiddenLink:NULL];
}

- (NSString *)linkAtPoint:(CGPoint)point regionData:(__autoreleasing NSArray **)regionData hiddenLink:(bool *)hiddenLink {
    return [self linkAtPoint:point regionData:regionData hiddenLink:hiddenLink linkText:nil];
}

- (NSString *)linkAtPoint:(CGPoint)point regionData:(__autoreleasing NSArray **)regionData hiddenLink:(bool *)hiddenLink linkText:(__autoreleasing NSString **)linkText
{
    CGRect topRegion = CGRectZero;
    CGRect middleRegion = CGRectZero;
    CGRect bottomRegion = CGRectZero;
    
    NSString *result = [_layoutData linkAtPoint:point topRegion:&topRegion middleRegion:&middleRegion bottomRegion:&bottomRegion hiddenLink:hiddenLink linkText:linkText];
    if (result != nil)
    {
        NSMutableArray *array = [[NSMutableArray alloc] init];
        if (!CGRectIsEmpty(topRegion))
            [array addObject:[NSValue valueWithCGRect:topRegion]];
        if (!CGRectIsEmpty(middleRegion))
            [array addObject:[NSValue valueWithCGRect:middleRegion]];
        if (!CGRectIsEmpty(bottomRegion))
            [array addObject:[NSValue valueWithCGRect:bottomRegion]];
        
        if (regionData != NULL)
            *regionData = array;
    }
    
    return result;
}

- (void)enumerateSearchRegionsForString:(NSString *)string withBlock:(void (^)(CGRect))block
{
    [_layoutData enumerateSearchRegionsForString:string withBlock:block];
}

- (NSUInteger)measuredNumberOfLines
{
    if (_layoutData.lineOrigins == NULL)
        return 0;
    return (NSUInteger)_layoutData.lineOrigins->size();
}

- (CGFloat)lastLineBaseline
{
    return _layoutData.lastLineBaseline;
}

- (CGFloat)trailingBaseline
{
    return _layoutData.trailingBaseline;
}

@end
