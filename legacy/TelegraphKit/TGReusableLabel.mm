#import "TGReusableLabel.h"

#import "../../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import <CoreText/CoreText.h>

#include <tr1/unordered_map>
#include <vector>

typedef struct
{
    CGFloat ascent;
    CGFloat descent;
    CGFloat width;
} TGEmojiRunContext;

typedef struct
{
    NSRange sourceRange;
    NSRange displayRange;
} TGEmojiIndexMapping;

static const CGFloat TGOnegramEmojiScale = 0.8f;
static const CGFloat TGOnegramEmojiSpacing = 0.10f;

static void TGEmojiRunDeallocate(void *refCon)
{
    if (refCon != NULL)
        free(refCon);
}

static CGFloat TGEmojiRunGetAscent(void *refCon)
{
    return refCon == NULL ? 0.0f : ((TGEmojiRunContext *)refCon)->ascent;
}

static CGFloat TGEmojiRunGetDescent(void *refCon)
{
    return refCon == NULL ? 0.0f : ((TGEmojiRunContext *)refCon)->descent;
}

static CGFloat TGEmojiRunGetWidth(void *refCon)
{
    return refCon == NULL ? 0.0f : ((TGEmojiRunContext *)refCon)->width;
}

static bool TGNativeEmojiMetrics(CGFloat fontSize, CGFloat *ascent, CGFloat *descent, CGFloat *width)
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });

    NSNumber *cacheKey = [NSNumber numberWithInt:(int)lrintf(fontSize * 10.0f)];
    NSDictionary *cached = nil;
    @synchronized(cache)
    {
        cached = [cache objectForKey:cacheKey];
    }

    if (cached != nil)
    {
        if (ascent != NULL)
            *ascent = [[cached objectForKey:@"ascent"] floatValue];
        if (descent != NULL)
            *descent = [[cached objectForKey:@"descent"] floatValue];
        if (width != NULL)
            *width = [[cached objectForKey:@"width"] floatValue];
        return true;
    }

    CTFontRef emojiFont = CTFontCreateWithName(CFSTR("AppleColorEmoji"), fontSize, NULL);
    if (emojiFont == NULL)
        return false;

    NSDictionary *attributes = [NSDictionary dictionaryWithObject:(__bridge id)emojiFont forKey:(__bridge NSString *)kCTFontAttributeName];
    NSAttributedString *sample = [[NSAttributedString alloc] initWithString:@"\U0001F600" attributes:attributes];
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)sample);

    CGFloat measuredAscent = 0.0f;
    CGFloat measuredDescent = 0.0f;
    CGFloat measuredWidth = 0.0f;
    if (line != NULL)
    {
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        if (CFArrayGetCount(runs) != 0)
        {
            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, 0);
            CFIndex glyphCount = CTRunGetGlyphCount(run);
            if (glyphCount != 0)
                measuredWidth = (CGFloat)CTRunGetTypographicBounds(run, CFRangeMake(0, glyphCount), &measuredAscent, &measuredDescent, NULL);
        }
        CFRelease(line);
    }
    CFRelease(emojiFont);

    if (measuredAscent <= 0.0f || measuredWidth <= 0.0f)
        return false;

    NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithFloat:measuredAscent], @"ascent",
        [NSNumber numberWithFloat:measuredDescent], @"descent",
        [NSNumber numberWithFloat:measuredWidth], @"width",
        nil];
    @synchronized(cache)
    {
        [cache setObject:result forKey:cacheKey];
    }

    if (ascent != NULL)
        *ascent = measuredAscent;
    if (descent != NULL)
        *descent = measuredDescent;
    if (width != NULL)
        *width = measuredWidth;
    return true;
}

static NSUInteger TGDisplayIndexForSourceIndex(const std::vector<TGEmojiIndexMapping> *mappings, NSUInteger sourceIndex, bool endBoundary)
{
    if (mappings == NULL || mappings->empty())
        return sourceIndex;

    NSUInteger removed = 0;
    for (std::vector<TGEmojiIndexMapping>::const_iterator it = mappings->begin(); it != mappings->end(); ++it)
    {
        NSUInteger sourceStart = it->sourceRange.location;
        NSUInteger sourceEnd = NSMaxRange(it->sourceRange);

        if (sourceIndex <= sourceStart)
            break;

        if (sourceIndex >= sourceEnd)
        {
            if (it->sourceRange.length > 1)
                removed += it->sourceRange.length - 1;
            continue;
        }

        return it->displayRange.location + (endBoundary ? 1 : 0);
    }

    return sourceIndex >= removed ? sourceIndex - removed : 0;
}

static NSRange TGDisplayRangeForSourceRange(const std::vector<TGEmojiIndexMapping> *mappings, NSRange sourceRange)
{
    if (sourceRange.location == NSNotFound)
        return sourceRange;

    NSUInteger start = TGDisplayIndexForSourceIndex(mappings, sourceRange.location, false);
    NSUInteger end = TGDisplayIndexForSourceIndex(mappings, NSMaxRange(sourceRange), true);
    if (end < start)
        end = start;
    return NSMakeRange(start, end - start);
}

static void TGPrepareEmojiAttributedString(NSMutableAttributedString *string, NSString *text, CGFloat fontSize, CGFloat fontAscent, CGFloat fontDescent, std::vector<TGEmojiIndexMapping> *mappings)
{
    if (mappings != NULL)
        mappings->clear();
    if (string.length == 0 || text.length == 0)
        return;

    NSMutableArray *emojiRanges = [[NSMutableArray alloc] init];
    NSMutableArray *emojiValues = [[NSMutableArray alloc] init];
    NSUInteger sourceIndex = 0;
    NSUInteger removed = 0;

    while (sourceIndex < text.length)
    {
        NSRange emojiRange = NSMakeRange(0, 0);
        if (TGEmojiPackMatchAtIndex(text, sourceIndex, &emojiRange))
        {
            NSString *emoji = [text substringWithRange:emojiRange];
            if (TGEmojiNeedsPack(emoji))
            {
                [emojiRanges addObject:[NSValue valueWithRange:emojiRange]];
                [emojiValues addObject:emoji];
                if (mappings != NULL)
                {
                    TGEmojiIndexMapping mapping;
                    mapping.sourceRange = emojiRange;
                    mapping.displayRange = NSMakeRange(emojiRange.location - removed, 1);
                    mappings->push_back(mapping);
                }
                if (emojiRange.length > 1)
                    removed += emojiRange.length - 1;
            }
            sourceIndex = NSMaxRange(emojiRange);
        }
        else
        {
            sourceIndex++;
        }
    }

    CGFloat sourceHeight = MAX(1.0f, fontAscent + fontDescent);
    CGFloat emojiAscent = 0.0f;
    CGFloat emojiDescent = 0.0f;
    CGFloat emojiWidth = 0.0f;
    if (!TGNativeEmojiMetrics(fontSize, &emojiAscent, &emojiDescent, &emojiWidth))
    {
        CGFloat emojiSize = MAX(1.0f, fontSize) * TGOnegramEmojiScale;
        emojiDescent = emojiSize * fontDescent / sourceHeight;
        emojiAscent = emojiSize - emojiDescent;
        emojiWidth = emojiSize;
    }
    else
    {
        emojiAscent *= TGOnegramEmojiScale;
        emojiDescent *= TGOnegramEmojiScale;
        emojiWidth *= TGOnegramEmojiScale;
    }

    for (NSInteger index = (NSInteger)emojiRanges.count - 1; index >= 0; index--)
    {
        NSRange sourceRange = [[emojiRanges objectAtIndex:(NSUInteger)index] rangeValue];
        NSString *emoji = [emojiValues objectAtIndex:(NSUInteger)index];
        NSDictionary *baseAttributes = sourceRange.location < string.length ? [string attributesAtIndex:sourceRange.location effectiveRange:NULL] : nil;
        NSMutableAttributedString *replacement = [[NSMutableAttributedString alloc] initWithString:@"\uFFFC" attributes:baseAttributes];

        CGFloat trailingSpacing = 0.0f;
        if ((NSUInteger)index + 1 < emojiRanges.count)
        {
            NSRange nextRange = [[emojiRanges objectAtIndex:(NSUInteger)index + 1] rangeValue];
            if (NSMaxRange(sourceRange) == nextRange.location)
                trailingSpacing = MAX(1.0f, fontSize * TGOnegramEmojiSpacing);
        }

        TGEmojiRunContext *context = (TGEmojiRunContext *)malloc(sizeof(TGEmojiRunContext));
        if (context == NULL)
            continue;
        context->ascent = emojiAscent;
        context->descent = emojiDescent;
        context->width = MAX(1.0f, emojiAscent + emojiDescent) + trailingSpacing;

        CTRunDelegateCallbacks callbacks;
        callbacks.version = kCTRunDelegateVersion1;
        callbacks.dealloc = TGEmojiRunDeallocate;
        callbacks.getAscent = TGEmojiRunGetAscent;
        callbacks.getDescent = TGEmojiRunGetDescent;
        callbacks.getWidth = TGEmojiRunGetWidth;

        CTRunDelegateRef delegate = CTRunDelegateCreate(&callbacks, context);
        if (delegate == NULL)
        {
            free(context);
            continue;
        }

        CFAttributedStringSetAttribute((CFMutableAttributedStringRef)replacement, CFRangeMake(0, 1), kCTRunDelegateAttributeName, delegate);
        CFAttributedStringSetAttribute((CFMutableAttributedStringRef)replacement, CFRangeMake(0, 1), CFSTR("TGOnegramEmoji"), (__bridge CFStringRef)emoji);
        CFAttributedStringSetAttribute((CFMutableAttributedStringRef)replacement, CFRangeMake(0, 1), CFSTR("TGOnegramEmojiTrailingSpacing"), (__bridge CFNumberRef)[NSNumber numberWithFloat:trailingSpacing]);
        CFAttributedStringSetAttribute((CFMutableAttributedStringRef)replacement, CFRangeMake(0, 1), kCTForegroundColorAttributeName, [UIColor clearColor].CGColor);
        [string replaceCharactersInRange:sourceRange withAttributedString:replacement];
        CFRelease(delegate);
    }
}

@interface TGReusableLabelLayoutData ()
{
    std::tr1::unordered_map<int, std::tr1::unordered_map<int, int> > _lineOffsets;
    std::vector<TGLinePosition> _lineOrigins;
    
    std::vector<TGLinkData> _links;
    std::vector<TGEmojiIndexMapping> _emojiMappings;
}

@property (nonatomic, strong) NSArray *textLines;
@property (nonatomic) CGSize drawingSize;
@property (nonatomic) CGPoint drawingOffset;
@property (nonatomic, strong) NSString *text;

@property (nonatomic) CGFloat fontLineHeight;
@property (nonatomic) CGFloat fontLineSpacing;

- (std::tr1::unordered_map<int, std::tr1::unordered_map<int, int> > *)lineOffsets;
- (std::vector<TGEmojiIndexMapping> *)emojiMappings;

@end

@implementation TGReusableLabelLayoutData

- (CGFloat)drawingWidth
{
    return _drawingSize.width;
}

- (std::tr1::unordered_map<int, std::tr1::unordered_map<int, int> > *)lineOffsets
{
    return &_lineOffsets;
}

- (std::vector<TGLinePosition> *)lineOrigins
{
    return &_lineOrigins;
}

- (std::vector<TGLinkData> *)links
{
    return &_links;
}

- (std::vector<TGEmojiIndexMapping> *)emojiMappings
{
    return &_emojiMappings;
}

- (NSString *)linkAtPoint:(CGPoint)point topRegion:(CGRect *)topRegion middleRegion:(CGRect *)middleRegion bottomRegion:(CGRect *)bottomRegion hiddenLink:(bool *)hiddenLink linkText:(NSString *__autoreleasing *)linkText
{
    if (!_links.empty())
    {
        for (std::vector<TGLinkData>::iterator it = _links.begin(); it != _links.end(); it++)
        {
            if ((it->topRegion.size.height != 0 && CGRectContainsPoint(CGRectInset(it->topRegion, -2, -2), point)) || (it->middleRegion.size.height != 0 && CGRectContainsPoint(CGRectInset(it->middleRegion, -2, -2), point)) || (it->bottomRegion.size.height != 0 && CGRectContainsPoint(CGRectInset(it->bottomRegion, -2, -2), point)))
            {
                if (topRegion != NULL)
                    *topRegion = it->topRegion;
                if (middleRegion != NULL)
                    *middleRegion = it->middleRegion;
                if (bottomRegion != NULL)
                    *bottomRegion = it->bottomRegion;
                if (hiddenLink) {
                    *hiddenLink = it->hidden;
                }
                if (linkText) {
                    *linkText = it->text;
                }
                return it->url;
            }
        }
    }
    return nil;
}

- (void)enumerateSearchRegionsForString:(NSString *)string withBlock:(void (^)(CGRect))block
{
    if (string.length == 0)
        return;
    
    static NSCharacterSet *alphaSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        alphaSet = [NSCharacterSet alphanumericCharacterSet];
    });
    
    NSUInteger length = _text.length;
    for (NSUInteger offset = 0; offset != NSNotFound && offset < length; )
    {
        NSRange range = [_text rangeOfString:string options:NSCaseInsensitiveSearch range:NSMakeRange(offset, length - offset)];
        if (range.location == NSNotFound)
            break;
        offset = range.location + range.length;
        if (range.location > 0)
        {
            unichar c = [_text characterAtIndex:range.location - 1];
            if ([alphaSet characterIsMember:c])
                continue;
        }
        
        int lineIndex = -1;
        for (id bridgedLine in _textLines)
        {
            lineIndex++;
            CTLineRef line = (__bridge CTLineRef)bridgedLine;
            
            CFRange lineRange = CTLineGetStringRange(line);
            CGPoint lineOrigin = CGPointMake(_lineOrigins[lineIndex].horizontalOffset, _lineOrigins[lineIndex].offset);
            NSRange displayRange = TGDisplayRangeForSourceRange(&_emojiMappings, range);
            NSRange intersectionRange = NSIntersectionRange(displayRange, NSMakeRange(lineRange.location, lineRange.length));
            if (intersectionRange.length != 0)
            {
                CGFloat startX = 0.0f;
                CGFloat endX = 0.0f;
                
                /*if (resultHadRTL)
                {
                    bool appliedAnyPosition = false;
                    
                    CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
                    int glyphRunCount = (int)CFArrayGetCount(glyphRuns);
                    for (int iRun = 0; iRun < glyphRunCount; iRun++)
                    {
                        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(glyphRuns, iRun);
                        CFIndex glyphCount = CTRunGetGlyphCount(run);
                        if (glyphCount > 0)
                        {
                            CFIndex startIndex = 0;
                            CFIndex endIndex = 0;
                            
                            CTRunGetStringIndices(run, CFRangeMake(0, 1), &startIndex);
                            CTRunGetStringIndices(run, CFRangeMake(glyphCount - 1, 1), &endIndex);
                            
                            if (startIndex >= (CFIndex)it->range.location && endIndex < (CFIndex)(it->range.location + it->range.length))
                            {
                                CGPoint leftPosition = CGPointZero;
                                CGPoint rightPosition = CGPointZero;
                                
                                CTRunGetPositions(run, CFRangeMake(0, 1), &leftPosition);
                                float runWidth = (float)CTRunGetTypographicBounds(run, CFRangeMake(0, glyphCount), NULL, NULL, NULL);
                                rightPosition.x = leftPosition.x + runWidth;
                                
                                if (!appliedAnyPosition)
                                {
                                    appliedAnyPosition = true;
                                    
                                    startX = leftPosition.x;
                                    endX = rightPosition.x;
                                }
                                else
                                {
                                    if (leftPosition.x < startX)
                                        startX = leftPosition.x;
                                    if (rightPosition.x > endX)
                                        endX = rightPosition.x;
                                }
                            }
                        }
                    }
                    
                    startX = CGFloor(startX + lineOrigin.x);
                    endX = CGCeil(endX + lineOrigin.x);
                }
                else*/
                {
                    startX = CGCeil(CTLineGetOffsetForStringIndex(line, intersectionRange.location, NULL) + lineOrigin.x);
                    endX = CGCeil(CTLineGetOffsetForStringIndex(line, intersectionRange.location + intersectionRange.length, NULL) + lineOrigin.x);
                }
                
                if (startX > endX)
                {
                    CGFloat tmp = startX;
                    startX = endX;
                    endX = tmp;
                }
                
                /*bool tillEndOfLine = false;
                if (intersectionRange.location + intersectionRange.length >= (NSUInteger)(lineRange.location + lineRange.length) && ABS(endX - layoutSize.width) < 16)
                {
                    tillEndOfLine = true;
                    endX = layoutSize.width + lineOrigin.x;
                }*/
                CGRect region = CGRectMake(CGCeil(startX - 3), CGCeil(lineOrigin.y - _fontLineHeight + _fontLineHeight * 0.1f), CGCeil(endX - startX + 6), CGCeil(_fontLineSpacing));
                if (block)
                    block(region);
            }
        }
    }
}

@end

@interface TGReusableLabel ()

@end

@implementation TGReusableLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _reuseIdentifier = @"ReusableLabel";
    }
    return self;
}

- (void)setHighlighted:(bool)highlighted
{
    if (highlighted != _highlighted)
    {
        _highlighted = highlighted;
        [self setNeedsDisplay];
    }
}

- (void)setFrame:(CGRect)frame
{
    if (!CGSizeEqualToSize(self.frame.size, frame.size))
    {
        [self setNeedsDisplay];
    }
    [super setFrame:frame];
}

- (void)setText:(NSString *)text
{
    if (text != _text)
    {
        _text = text;
        [self setNeedsDisplay];
    }
}

- (CGSize)sizeThatFits:(CGSize)size
{
    if (_text.length == 0 || _font == nil)
        return CGSizeZero;

    if (iosMajorVersion() < 7)
    {
        CTFontRef coreTextFont = TGCoreTextFontForUIFont(_font);
        if (coreTextFont != NULL)
        {
            TGReusableLabelLayoutData *layout = [TGReusableLabel calculateLayout:_text additionalAttributes:nil textCheckingResults:nil font:coreTextFont textColor:_textColor ?: [UIColor blackColor] linkColor:nil frame:CGRectZero orMaxWidth:size.width flags:TGReusableLabelLayoutMultiline textAlignment:_textAlignment outIsRTL:NULL additionalTrailingWidth:0.0f maxNumberOfLines:_numberOfLines <= 0 ? 0 : (NSUInteger)_numberOfLines numberOfLinesToInset:0 linesInset:0.0f containsEmptyNewline:NULL additionalLineSpacing:0.0f ellipsisString:nil underlineAllLinks:false];
            CFRelease(coreTextFont);
            if (layout != nil)
                return CGSizeMake(MIN(size.width, CGCeil(layout.drawingSize.width)), MIN(size.height, CGCeil(layout.size.height)));
        }
    }

    CGSize result = [_text sizeWithFont:_font constrainedToSize:size lineBreakMode:(_numberOfLines == 1 ? NSLineBreakByTruncatingTail : NSLineBreakByWordWrapping)];
    return CGSizeMake(CGCeil(result.width), CGCeil(result.height));
}

+ (void)preloadData
{
}

+ (TGReusableLabelLayoutData *)calculateLayout:(NSString *)text additionalAttributes:(NSArray *)additionalAttributes textCheckingResults:(NSArray *)textCheckingResults font:(CTFontRef)font textColor:(UIColor *)textColor linkColor:(UIColor *)linkColor frame:(CGRect)frame orMaxWidth:(float)maxWidth flags:(int)flags textAlignment:(NSTextAlignment)textAlignment outIsRTL:(bool *)outIsRTL
{
    return [self calculateLayout:text additionalAttributes:additionalAttributes textCheckingResults:textCheckingResults font:font textColor:textColor linkColor:linkColor frame:frame orMaxWidth:maxWidth flags:flags textAlignment:textAlignment outIsRTL:outIsRTL additionalTrailingWidth:0.0f maxNumberOfLines:0 numberOfLinesToInset:0 linesInset:0.0f containsEmptyNewline:NULL additionalLineSpacing:0.0f ellipsisString:nil underlineAllLinks:false];
}

+ (TGReusableLabelLayoutData *)calculateLayout:(NSString *)text additionalAttributes:(NSArray *)additionalAttributes textCheckingResults:(NSArray *)textCheckingResults font:(CTFontRef)font textColor:(UIColor *)textColor linkColor:(UIColor *)linkColor frame:(CGRect)frame orMaxWidth:(float)maxWidth flags:(int)flags textAlignment:(NSTextAlignment)textAlignment outIsRTL:(bool *)outIsRTL additionalTrailingWidth:(CGFloat)additionalTrailingWidth maxNumberOfLines:(NSUInteger)maxNumberOfLines numberOfLinesToInset:(NSUInteger)numberOfLinesToInset linesInset:(CGFloat)linesInset containsEmptyNewline:(bool *)containsEmptyNewline additionalLineSpacing:(CGFloat)additionalLineSpacing ellipsisString:(NSString *)ellipsisString underlineAllLinks:(bool)underlineAllLinks
{
    if (font == NULL || text == nil)
        return nil;
    
    bool justify = textAlignment == NSTextAlignmentJustified;
    if (justify) {
        textAlignment = NSTextAlignmentLeft;
    }
    
    static bool needToOffsetEmoji = false;
    static bool needToOffsetEmojiInitialized = false;
    static bool enableUnderline = true;
    if (!needToOffsetEmojiInitialized)
    {
        needToOffsetEmojiInitialized = true;
        needToOffsetEmoji = iosMajorVersion() < 6;
        enableUnderline = !(iosMajorVersion() == 7 && (iosMinorVersion() == 0 || iosMinorVersion() == 1));
    }
    
    TGReusableLabelLayoutData *layout = [[TGReusableLabelLayoutData alloc] init];
    layout.text = text;
    
    CGFloat fontSize = CTFontGetSize(font);
    CGFloat fontAscent = CTFontGetAscent(font);
    CGFloat fontDescent = CTFontGetDescent(font);
    
    CGFloat fontLineHeight = CGFloor(fontAscent + fontDescent);
    CGFloat fontLineSpacing = CGFloor(fontLineHeight * 1.12f + additionalLineSpacing);
    
    layout.fontLineHeight = fontLineHeight;
    layout.fontLineSpacing = fontLineSpacing;
    
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:(__bridge id)font, (NSString *)kCTFontAttributeName, nil];
    
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:text attributes:attributes];
    
    if (textColor != NULL)
        CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(0, string.length), kCTForegroundColorAttributeName, textColor.CGColor);
    
    if (additionalAttributes != nil)
    {
        int count = (int)additionalAttributes.count;
        for (int i = 0; i < count; i += 2)
        {
            NSRange range = NSMakeRange(0, 0);
            [(NSValue *)[additionalAttributes objectAtIndex:i] getValue:&range];
            NSArray *attributes = [additionalAttributes objectAtIndex:i + 1];
            
            if (range.location + range.length <= string.length)
            {
                CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(range.location, range.length), (CFStringRef)[attributes objectAtIndex:1], (CFTypeRef)[attributes objectAtIndex:0]);
            }
        }
    }
    
    CTFontRef boldFont = NULL;
    CTFontRef ultraBoldFont = NULL;
    CTFontRef italicFont = NULL;
    CTFontRef fixedFont = NULL;
    
    NSRange *pLinkRanges = NULL;
    int linkRangeActualCount = 0;
    
    if (textCheckingResults != nil && textCheckingResults.count != 0)
    {
        NSNumber *underlineStyle = [[NSNumber alloc] initWithInt:kCTUnderlineStyleSingle];
        
        int index = -1;
        for (id match in textCheckingResults)
        {
            NSRange linkRange = [match range];
            if (linkRange.location == NSNotFound || linkRange.location + linkRange.length > string.length) {
                continue;
            }
            
            
            bool useRange = false;
            bool useRangeUnderline = false;
            
            if ([match isKindOfClass:[NSTextCheckingResult class]])
            {
                NSString *url = ((NSTextCheckingResult *)match).resultType == NSTextCheckingTypePhoneNumber ? [[NSString alloc] initWithFormat:@"tel:%@", ((NSTextCheckingResult *)match).phoneNumber] : [((NSTextCheckingResult *)match).URL absoluteString];
                bool hidden = [(NSTextCheckingResult *)match isTelegramHiddenLink];
                NSString *linkText = nil;
                if (linkRange.location < text.length) {
                    NSRange fixedLinkRange = NSMakeRange(linkRange.location, MIN(text.length - linkRange.location, linkRange.location + linkRange.length));
                    if (fixedLinkRange.length > 0) {
                        linkText = [text substringWithRange:fixedLinkRange];
                    }
                }
                layout.links->push_back(TGLinkData(linkRange, url, linkText, hidden));
                
                if (flags & TGReusableLabelLayoutHighlightLinks && linkColor != NULL)
                {
                    CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTForegroundColorAttributeName, linkColor.CGColor);
                    
                    if (enableUnderline) {
                        CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTUnderlineStyleAttributeName, (CFNumberRef)underlineStyle);
                    }
                }
                
                useRange = true;
            }
            else if ([match isKindOfClass:[TGTextCheckingResult class]])
            {
                NSString *url = nil;
                
                switch (((TGTextCheckingResult *)match).type)
                {
                    case TGTextCheckingResultTypeMention:
                    {
                        url = [[NSString alloc] initWithFormat:@"mention://%@", ((TGTextCheckingResult *)match).contents];
                        useRange = true;
                        useRangeUnderline = underlineAllLinks;
                        break;
                    }
                    case TGTextCheckingResultTypeHashtag:
                    {
                        url = [[NSString alloc] initWithFormat:@"hashtag://%@", ((TGTextCheckingResult *)match).contents];
                        useRange = true;
                        useRangeUnderline = underlineAllLinks;
                        break;
                    }
                    case TGTextCheckingResultTypeCashtag:
                    {
                        url = [[NSString alloc] initWithFormat:@"cashtag://%@", ((TGTextCheckingResult *)match).contents];
                        useRange = true;
                        useRangeUnderline = underlineAllLinks;
                        break;
                    }
                    case TGTextCheckingResultTypeCommand:
                    {
                        if (flags & TGReusableLabelLayoutHighlightCommands)
                        {
                            useRange = true;
                            url = [[NSString alloc] initWithFormat:@"command://%@", ((TGTextCheckingResult *)match).contents];
                            useRangeUnderline = underlineAllLinks;
                        }
                        break;
                    }
                    case TGTextCheckingResultTypeCode:
                    {
                        if (fixedFont == nil) {
                            fixedFont = TGCoreTextFixedFontOfSize(fontSize);
                        }
                        
                        CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTFontAttributeName, fixedFont);
                        
                        break;
                    }
                    case TGTextCheckingResultTypeItalic:
                    {
                        if (italicFont == nil) {
                            italicFont = TGCoreTextItalicFontOfSize(fontSize);
                        }
                        
                        CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTFontAttributeName, italicFont);
                        
                        break;
                    }
                    case TGTextCheckingResultTypeBold:
                    {
                        if (boldFont == nil) {
                            boldFont = TGCoreTextBoldFontOfSize(fontSize);
                        }
                        
                        CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTFontAttributeName, boldFont);
                        
                        break;
                    }
                    case TGTextCheckingResultTypeColor:
                    {
                        if (((TGTextCheckingResult *)match).value != nil) {
                            UIColor *color = ((TGTextCheckingResult *)match).value;
                            CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTForegroundColorAttributeName, color.CGColor);
                        }
                        
                        break;
                    }
                    case TGTextCheckingResultTypeUltraBold:
                    {
                        if (ultraBoldFont == nil) {
                            ultraBoldFont = TGCoreTextBoldFontOfSize(fontSize);
                        }
                        
                        CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTFontAttributeName, ultraBoldFont);
                        
                        break;
                    }
                    case TGTextCheckingResultTypeLink:
                    {
                        url = ((TGTextCheckingResult *)match).contents;
                        useRange = true;
                        useRangeUnderline = ((TGTextCheckingResult *)match).highlightAsLink || underlineAllLinks;
                        
                        break;
                    }
                }
                
                if (useRange)
                {
                    NSString *linkText = nil;
                    if (linkRange.location < text.length) {
                        NSRange fixedLinkRange = NSMakeRange(linkRange.location, MIN(text.length - linkRange.location, linkRange.location + linkRange.length));
                        if (fixedLinkRange.length > 0) {
                            linkText = [text substringWithRange:fixedLinkRange];
                        }
                    }
                    layout.links->push_back(TGLinkData(linkRange, url, linkText, false));
                
                    if (flags & TGReusableLabelLayoutHighlightLinks && linkColor != NULL)
                    {
                        CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTForegroundColorAttributeName, linkColor.CGColor);
                        
                        if (enableUnderline && useRangeUnderline) {
                            CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTUnderlineStyleAttributeName, (CFNumberRef)underlineStyle);
                        }
                    }
                }
            }
            
            if (useRange)
            {
                if (pLinkRanges == NULL)
                {
                    pLinkRanges = new NSRange[(int)textCheckingResults.count];
                }
                
                pLinkRanges[++index] = linkRange;
                linkRangeActualCount++;
            }
        }
    }
    
    TGPrepareEmojiAttributedString(string, text, fontSize, fontAscent, fontDescent, [layout emojiMappings]);
    if (pLinkRanges != NULL)
    {
        for (int i = 0; i < linkRangeActualCount; i++)
            pLinkRanges[i] = TGDisplayRangeForSourceRange([layout emojiMappings], pLinkRanges[i]);
    }

    NSArray *resultLines = nil;
    std::vector<TGLinePosition> *pLineOrigins = layout.lineOrigins;
    bool resultHadRTL = false;
    CGRect resultRect = CGRectZero;
    
    if (flags & TGReusableLabelLayoutMultiline)
    {
        CGRect rect = CGRectZero;
        rect.origin = frame.origin;
        
        pLineOrigins->erase(pLineOrigins->begin(), pLineOrigins->end());
        
        NSMutableArray *textLines = [[NSMutableArray alloc] init];
        
        bool hadRTL = false;
        
        CGFloat lastLineWidth = 0.0f;
        
        CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)string);
        
        CFIndex lastIndex = 0;
        float currentLineOffset = 0;
        
        while (true)
        {
            CGFloat currentMaxWidth = maxWidth;
            CGFloat currentLineInset = 0.0f;
            if (numberOfLinesToInset != 0 && textLines.count < numberOfLinesToInset)
            {
                currentMaxWidth -= linesInset;
                currentLineInset = linesInset;
            }
            
            CFIndex lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, lastIndex, currentMaxWidth);
            
            if (pLinkRanges != NULL && flags & TGReusableLabelLayoutHighlightLinks)
            {
                CFIndex endIndex = lastIndex + lineCharacterCount;
                
                for (int i = 0; i < linkRangeActualCount; i++)
                {
                    if (pLinkRanges[i].location < (NSUInteger)endIndex && pLinkRanges[i].location + pLinkRanges[i].length >= (NSUInteger)endIndex)
                    {
                        lineCharacterCount = MAX(lineCharacterCount, CTTypesetterSuggestClusterBreak(typesetter, lastIndex, currentMaxWidth));
                        
                        if (pLinkRanges[i].location > (NSUInteger)lastIndex && lineCharacterCount < (CFIndex)(pLinkRanges[i].location + pLinkRanges[i].length - (NSUInteger)lastIndex))
                        {
                            lineCharacterCount = pLinkRanges[i].location - lastIndex;
                        }
                        
                        break;
                    }
                }
            }
            
            if (lineCharacterCount > 0)
            {
                CTLineRef line = NULL;
                
                if (maxNumberOfLines != 0 && textLines.count == maxNumberOfLines - 1)
                {
                    CTLineRef originalLine = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(lastIndex, MAX(lineCharacterCount, (CFIndex)string.length - lastIndex)), 100.0);
                    
                    if (CTLineGetTypographicBounds(originalLine, NULL, NULL, NULL) - (float)CTLineGetTrailingWhitespaceWidth(originalLine) <= currentMaxWidth)
                        line = originalLine;
                    else
                    {
                        NSMutableDictionary *truncationTokenAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:(__bridge id)font, (NSString *)kCTFontAttributeName, (__bridge id)textColor.CGColor, (NSString *)kCTForegroundColorAttributeName, nil];
                        
                        static NSString *tokenString = nil;
                        if (tokenString == nil)
                        {
                            unichar tokenChar = 0x2026;
                            tokenString = [[NSString alloc] initWithCharacters:&tokenChar length:1];
                        }
                        
                        NSAttributedString *truncationTokenString = [[NSAttributedString alloc] initWithString:ellipsisString == nil ? tokenString : ellipsisString attributes:truncationTokenAttributes];
                        CTLineRef truncationToken = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)truncationTokenString);
                        
                        line = CTLineCreateTruncatedLine(originalLine, currentMaxWidth, (flags & TGReusableLabelTruncateInTheMiddle) ? kCTLineTruncationMiddle : kCTLineTruncationEnd, truncationToken);
                        CFRelease(originalLine);
                        CFRelease(truncationToken);
                    }
                }
                else
                {
                    line = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(lastIndex, lineCharacterCount), 100.0);
                }
                
                if (line != NULL)
                {
                    [textLines addObject:(__bridge id)line];
                
                    bool rightAligned = false;
                    
                    CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
                    if (CFArrayGetCount(glyphRuns) != 0)
                    {
                        if (CTRunGetStatus((CTRunRef)CFArrayGetValueAtIndex(glyphRuns, 0)) & kCTRunStatusRightToLeft)
                            rightAligned = true;
                    }
                    
                    hadRTL |= rightAligned;
                    
                    CGFloat lineWidth = (CGFloat)CTLineGetTypographicBounds(line, NULL, NULL, NULL) - (CGFloat)CTLineGetTrailingWhitespaceWidth(line) + currentLineInset;
                    
                    TGLinePosition linePosition = {.offset = (CGFloat)(currentLineOffset + fontLineHeight), .horizontalOffset = 0.0f, .alignment = (uint8_t)(textAlignment == NSTextAlignmentCenter ? 1 : (rightAligned ? 2 : 0)), .lineWidth = lineWidth};
                    pLineOrigins->push_back(linePosition);
                    
                    currentLineOffset += fontLineSpacing;
                    rect.size.height += fontLineSpacing;
                    rect.size.width = MAX(rect.size.width, lineWidth);
                    
                    CFRelease(line);
                    
                    lastLineWidth = lineWidth;
                    
                    lastIndex += lineCharacterCount;
                }
                else
                    break;
            }
            else
                break;
            
            if (maxNumberOfLines != 0 && textLines.count == maxNumberOfLines)
                break;
        }
        
        if (additionalTrailingWidth > FLT_EPSILON)
        {
            if (textLines.count == 1)
            {
                if (lastLineWidth + additionalTrailingWidth <= maxWidth)
                {
                    rect.size.width += additionalTrailingWidth;
                    if (pLineOrigins->at(textLines.count - 1).alignment == 2)
                    {
                        pLineOrigins->at(textLines.count - 1).horizontalOffset -= additionalTrailingWidth;
                    }
                }
                else
                {
                    rect.size.height += fontLineHeight * 0.7f;
                    if (containsEmptyNewline)
                        *containsEmptyNewline = true;
                }
            }
            else if (textLines.count != 0)
            {
                if (rect.size.width - lastLineWidth < additionalTrailingWidth)
                {
                    if (lastLineWidth + additionalTrailingWidth <= maxWidth)
                    {
                        if (pLineOrigins->at(textLines.count - 1).alignment == 2)
                        {
                            rect.size.height += fontLineHeight * 0.7f;
                            if (containsEmptyNewline)
                                *containsEmptyNewline = true;
                            rect.size.width = MAX(rect.size.width, additionalTrailingWidth - 12);
                        }
                        else
                            rect.size.width = lastLineWidth + additionalTrailingWidth;
                    }
                    else
                    {
                        rect.size.height += fontLineHeight * 0.7f;
                        if (containsEmptyNewline)
                            *containsEmptyNewline = true;
                    
                        if (rect.size.width < additionalTrailingWidth - 12)
                            rect.size.width = additionalTrailingWidth - 12;
                    }
                }
                else
                {
                    if (pLineOrigins->at(textLines.count - 1).alignment == 2)
                    {
                        rect.size.height += fontLineHeight * 0.7f;
                        if (containsEmptyNewline)
                            *containsEmptyNewline = true;
                    }
                }
            }
        }
        
        if ((flags & TGReusableLabelLayoutOffsetLastLine) && textLines.count != 0) {
            pLineOrigins->at(textLines.count - 1).offset += 2.0f;
            rect.size.height += 3.0f;
        }
        
        layout.size = CGSizeMake(CGFloor(rect.size.width), CGFloor(rect.size.height + fontLineHeight * 0.1f));
        layout.drawingSize = rect.size;
        
        if (justify) {
            NSMutableArray *justifiedLines = [[NSMutableArray alloc] init];
            for (NSInteger i = 0; i < (NSInteger)textLines.count; i++) {
                if (i != (NSInteger)textLines.count - 1) {
                    CGFloat width = layout.size.width;
                    if (i < (NSInteger)numberOfLinesToInset) {
                        width -= linesInset;
                    }
                    
                    CTLineRef line = CTLineCreateJustifiedLine((__bridge CTLineRef)textLines[i], 1.0f, width);
                    if (line != NULL) {
                        [justifiedLines addObject:(__bridge id)line];
                        CFRelease(line);
                    } else {
                        [justifiedLines addObject:textLines[i]];
                    }
                } else {
                    [justifiedLines addObject:textLines[i]];
                }
            }
            textLines = justifiedLines;
        }
        
        layout.textLines = textLines;
        
        if (typesetter != NULL)
            CFRelease(typesetter);
        
        resultLines = textLines;
        resultHadRTL = hadRTL;
        resultRect = rect;
    }
    else
    {
        CGRect rect = CGRectZero;
        rect.origin = frame.origin;
        
        pLineOrigins->erase(pLineOrigins->begin(), pLineOrigins->end());
        
        NSMutableArray *textLines = [[NSMutableArray alloc] init];
        
        NSMutableDictionary *truncationTokenAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:(__bridge id)font, (NSString *)kCTFontAttributeName, (__bridge id)textColor.CGColor, (NSString *)kCTForegroundColorAttributeName, nil];
        
        static NSString *tokenString = nil;
        if (tokenString == nil)
        {
            unichar tokenChar = 0x2026;
            tokenString = [[NSString alloc] initWithCharacters:&tokenChar length:1];
        }
        
        CTLineRef line = NULL;
        
        NSAttributedString *truncationTokenString = [[NSAttributedString alloc] initWithString:ellipsisString == nil ? tokenString : ellipsisString attributes:truncationTokenAttributes];
        CTLineRef truncationToken = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)truncationTokenString);
        
        CTLineRef originalLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)string);
        if (CTLineGetTypographicBounds(originalLine, NULL, NULL, NULL) - (float)CTLineGetTrailingWhitespaceWidth(originalLine) <= maxWidth)
            line = originalLine;
        else
        {
            line = CTLineCreateTruncatedLine(originalLine, maxWidth, (flags & TGReusableLabelTruncateInTheMiddle) ? kCTLineTruncationMiddle : kCTLineTruncationEnd, truncationToken);
            CFRelease(originalLine);
        }
        
        CFRelease(truncationToken);
        
        if (line != NULL)
        {
            CGFloat lineWidth = (float)CTLineGetTypographicBounds(line, NULL, NULL, NULL) - (float)CTLineGetTrailingWhitespaceWidth(line);
            
            TGLinePosition linePosition = {.offset = 0.0f + fontLineHeight, .horizontalOffset = 0.0f, .alignment = 0, .lineWidth = lineWidth};
            pLineOrigins->push_back(linePosition);
            
            layout.size = CGSizeMake(lineWidth, fontLineSpacing);
            layout.drawingSize = layout.size;
            
            [textLines addObject:(__bridge id)line];
            layout.textLines = textLines;
            
            CFRelease(line);
        }
        
        resultLines = textLines;
        resultRect = rect;
    }
    
    if (!layout.links->empty())
    {
        std::vector<TGLinkData>::iterator linksBegin = layout.links->begin();
        std::vector<TGLinkData>::iterator linksEnd = layout.links->end();
        
        CGSize layoutSize = layout.size;
        layoutSize.height -= 1;
        
        int numberOfLines = (int)resultLines.count;
        for (int iLine = 0; iLine < numberOfLines; iLine++)
        {
            CTLineRef line = (__bridge CTLineRef)[resultLines objectAtIndex:iLine];
            CFRange lineRange = CTLineGetStringRange(line);
            
            TGLinePosition const &linePosition = pLineOrigins->at(iLine);
            CGPoint lineOrigin = CGPointMake(linePosition.alignment == 0 ? 0.0f : ((float)CTLineGetPenOffsetForFlush(line, linePosition.alignment == 1 ? 0.5f : 1.0f, resultRect.size.width)) + linePosition.horizontalOffset, linePosition.offset);
            
            for (std::vector<TGLinkData>::iterator it = linksBegin; it != linksEnd; it++)
            {
                NSRange displayLinkRange = TGDisplayRangeForSourceRange([layout emojiMappings], it->range);
                NSRange intersectionRange = NSIntersectionRange(displayLinkRange, NSMakeRange(lineRange.location, lineRange.length));
                if (intersectionRange.length != 0)
                {
                    CGFloat startX = 0.0f;
                    CGFloat endX = 0.0f;
                 
                    if (resultHadRTL)
                    {
                        bool appliedAnyPosition = false;
                        
                        CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
                        int glyphRunCount = (int)CFArrayGetCount(glyphRuns);
                        for (int iRun = 0; iRun < glyphRunCount; iRun++)
                        {
                            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(glyphRuns, iRun);
                            CFIndex glyphCount = CTRunGetGlyphCount(run);
                            if (glyphCount > 0)
                            {
                                CFIndex startIndex = 0;
                                CFIndex endIndex = 0;
                                
                                CTRunGetStringIndices(run, CFRangeMake(0, 1), &startIndex);
                                CTRunGetStringIndices(run, CFRangeMake(glyphCount - 1, 1), &endIndex);
                                
                                if (startIndex >= (CFIndex)displayLinkRange.location && endIndex < (CFIndex)(displayLinkRange.location + displayLinkRange.length))
                                {
                                    CGPoint leftPosition = CGPointZero;
                                    CGPoint rightPosition = CGPointZero;
                                    
                                    CTRunGetPositions(run, CFRangeMake(0, 1), &leftPosition);
                                    float runWidth = (float)CTRunGetTypographicBounds(run, CFRangeMake(0, glyphCount), NULL, NULL, NULL);
                                    rightPosition.x = leftPosition.x + runWidth;
                                    
                                    if (!appliedAnyPosition)
                                    {
                                        appliedAnyPosition = true;
                                        
                                        startX = leftPosition.x;
                                        endX = rightPosition.x;
                                    }
                                    else
                                    {
                                        if (leftPosition.x < startX)
                                            startX = leftPosition.x;
                                        if (rightPosition.x > endX)
                                            endX = rightPosition.x;
                                    }
                                }
                            }
                        }
                        
                        startX = CGFloor(startX + lineOrigin.x);
                        endX = CGCeil(endX + lineOrigin.x);
                    }
                    else
                    {
                        startX = CGCeil(CTLineGetOffsetForStringIndex(line, intersectionRange.location, NULL) + lineOrigin.x);
                        endX = CGCeil(CTLineGetOffsetForStringIndex(line, intersectionRange.location + intersectionRange.length, NULL) + lineOrigin.x);
                    }
                    
                    if (startX > endX)
                    {
                        CGFloat tmp = startX;
                        startX = endX;
                        endX = tmp;
                    }
                    
                    bool tillEndOfLine = false;
                    if (intersectionRange.location + intersectionRange.length >= (NSUInteger)(lineRange.location + lineRange.length) && ABS(endX - layoutSize.width) < 16)
                    {
                        tillEndOfLine = true;
                        endX = layoutSize.width + lineOrigin.x;
                    }
                    CGRect region = CGRectMake(CGCeil(startX - 3), CGCeil(lineOrigin.y - fontLineHeight + fontLineHeight * 0.1f), CGCeil(endX - startX + 6), CGCeil(fontLineSpacing));
                    
                    if (it->topRegion.size.height == 0)
                        it->topRegion = region;
                    else
                    {
                        if (it->middleRegion.size.height == 0)
                            it->middleRegion = region;
                        else if (intersectionRange.location == (NSUInteger)lineRange.location && intersectionRange.length == (NSUInteger)lineRange.length && tillEndOfLine)
                            it->middleRegion.size.height += region.size.height;
                        else
                            it->bottomRegion = region;
                    }
                }
            }
        }
    }
    
    if (pLinkRanges != NULL)
        delete[] pLinkRanges;
    
    if (outIsRTL != NULL)
        *outIsRTL = resultHadRTL;
    
    return layout;
}

- (void)drawRect:(CGRect)__unused rect
{
    if (_richText)
        [TGReusableLabel drawRichTextInRect:self.bounds precalculatedLayout:_precalculatedLayout linesRange:NSMakeRange(0, 0) shadowColor:_shadowColor shadowOffset:_shadowOffset];
    else
        [TGReusableLabel drawTextInRect:self.bounds text:_text richText:_richText font:_font highlighted:_highlighted textColor:_textColor highlightedColor:_highlightedTextColor shadowColor:_shadowColor shadowOffset:_shadowOffset numberOfLines:_numberOfLines];
}

+ (void)drawTextInRect:(CGRect)rect text:(NSString *)text richText:(bool)richText font:(UIFont *)font highlighted:(bool)highlighted textColor:(UIColor *)textColor highlightedColor:(UIColor *)highlightedColor shadowColor:(UIColor *)shadowColor shadowOffset:(CGSize)shadowOffset numberOfLines:(int)numberOfLines
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!richText)
    {
        UIColor *effectiveColor = (highlighted && highlightedColor != nil) ? highlightedColor : textColor;
        UIColor *shadow = highlighted ? nil : shadowColor;

        if (iosMajorVersion() < 7)
        {
            CTFontRef coreTextFont = TGCoreTextFontForUIFont(font);
            if (coreTextFont != NULL)
            {
                TGReusableLabelLayoutData *layout = [TGReusableLabel calculateLayout:text additionalAttributes:nil textCheckingResults:nil font:coreTextFont textColor:effectiveColor linkColor:nil frame:CGRectZero orMaxWidth:rect.size.width flags:TGReusableLabelLayoutMultiline textAlignment:NSTextAlignmentLeft outIsRTL:NULL additionalTrailingWidth:0.0f maxNumberOfLines:numberOfLines <= 0 ? 0 : (NSUInteger)numberOfLines numberOfLinesToInset:0 linesInset:0.0f containsEmptyNewline:NULL additionalLineSpacing:0.0f ellipsisString:nil underlineAllLinks:false];
                CFRelease(coreTextFont);
                if (layout != nil)
                {
                    [TGReusableLabel drawRichTextInRect:rect precalculatedLayout:layout linesRange:NSMakeRange(0, 0) shadowColor:shadow shadowOffset:shadowOffset];
                    return;
                }
            }
        }

        CGContextSetFillColorWithColor(context, effectiveColor.CGColor);
        if (shadowColor != nil)
            CGContextSetShadowWithColor(context, shadowOffset, 0, shadow.CGColor);

        CGRect textRect = rect;
        [text drawInRect:textRect withFont:font lineBreakMode:(numberOfLines == 0 ? NSLineBreakByWordWrapping : NSLineBreakByTruncatingTail)];
    }
}

+ (void)drawRichTextInRect:(CGRect)rect precalculatedLayout:(TGReusableLabelLayoutData *)precalculatedLayout linesRange:(NSRange)linesRange shadowColor:(UIColor *)shadowColor shadowOffset:(CGSize)shadowOffset
{
    CFArrayRef lines = (__bridge CFArrayRef)precalculatedLayout.textLines;
    if (lines == nil)
    {
#if TARGET_IPHONE_SIMULATOR
        TGLog(@"%s:%d: warning: lines is nil", __PRETTY_FUNCTION__, __LINE__);
#endif
        
        return;
    }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    if (shadowColor != nil)
        CGContextSetShadowWithColor(context, shadowOffset, 0, shadowColor.CGColor);
    
    CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1.0f, -1.0f));
    CGContextTranslateCTM(context, rect.origin.x, rect.origin.y);
    
    CGRect clipRect = CGContextGetClipBoundingBox(context);
    
    NSInteger numberOfLines = CFArrayGetCount(lines);
    
    if (linesRange.length == 0)
        linesRange = NSMakeRange(0, numberOfLines);
    
    const std::vector<TGLinePosition> *pLineOrigins = precalculatedLayout.lineOrigins;
    
    CGFloat lineHeight = 64.0f;
    if (pLineOrigins->size() >= 2)
        lineHeight = ABS(pLineOrigins->at(0).offset - pLineOrigins->at(1).offset);
    
    CGFloat upperOriginBound = clipRect.origin.y - lineHeight;
    CGFloat lowerOriginBound = clipRect.origin.y + clipRect.size.height + lineHeight + lineHeight;

    // Very tall message bodies are rendered by TGModernFlatteningViewModel in
    // 512-point tiles.  On iOS 6 CGContextGetClipBoundingBox() may report the
    // tile clip in the bitmap's local coordinates even though the context has
    // already been translated to the full message coordinate space.  The
    // optimization below then rejects perfectly visible lines and produces a
    // message with a blank/missing middle or bottom.  Core Graphics still
    // clips the actual drawing to the tile, so for tall layouts it is both
    // correct and memory-safe to submit every CTLine and let the context clip.
    bool isIOS6TallText = rect.size.height > 1024.0f && [[[UIDevice currentDevice] systemVersion] intValue] <= 6;
    bool useClipLineCulling = !isIOS6TallText;
    
    for (CFIndex lineIndex = linesRange.location; lineIndex < (CFIndex)(linesRange.location + linesRange.length); lineIndex++)
    {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, lineIndex);
        
        TGLinePosition const &linePosition = pLineOrigins->at(lineIndex);
        
        CGFloat horizontalOffset = 0.0f;
        switch (linePosition.alignment)
        {
            case 1:
                horizontalOffset = CGFloor((rect.size.width - linePosition.lineWidth) / 2.0f);
                break;
            case 2:
                horizontalOffset = rect.size.width - linePosition.lineWidth;
                break;
            default:
                break;
        }
        
        CGPoint lineOrigin = CGPointMake(horizontalOffset + linePosition.horizontalOffset, linePosition.offset);
        
        if (useClipLineCulling && (lineOrigin.y < upperOriginBound || lineOrigin.y > lowerOriginBound))
            continue;
        
        CGContextSetTextPosition(context, lineOrigin.x, lineOrigin.y);
        CTLineDraw(line, context);

        CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
        CFIndex glyphRunCount = CFArrayGetCount(glyphRuns);
        for (CFIndex runIndex = 0; runIndex < glyphRunCount; runIndex++)
        {
            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(glyphRuns, runIndex);
            CFDictionaryRef attributes = CTRunGetAttributes(run);
            CFStringRef emojiValue = (CFStringRef)CFDictionaryGetValue(attributes, CFSTR("TGOnegramEmoji"));
            CFNumberRef trailingSpacingValue = (CFNumberRef)CFDictionaryGetValue(attributes, CFSTR("TGOnegramEmojiTrailingSpacing"));
            CFIndex emojiGlyphCount = CTRunGetGlyphCount(run);
            if (emojiValue == NULL || emojiGlyphCount == 0)
                continue;

            CGPoint runPosition = CGPointZero;
            CTRunGetPositions(run, CFRangeMake(0, 1), &runPosition);
            CGFloat ascent = 0.0f;
            CGFloat descent = 0.0f;
            CGFloat runWidth = (CGFloat)CTRunGetTypographicBounds(run, CFRangeMake(0, emojiGlyphCount), &ascent, &descent, NULL);
            CGFloat imageSize = MAX(1.0f, ascent + descent);
            CGFloat trailingSpacing = 0.0f;
            if (trailingSpacingValue != NULL)
                CFNumberGetValue(trailingSpacingValue, kCFNumberCGFloatType, &trailingSpacing);
            CGFloat contentWidth = MAX(1.0f, runWidth - trailingSpacing);
            UIImage *emojiImage = TGEmojiImageOfSize((__bridge NSString *)emojiValue, imageSize);
            if (emojiImage != nil)
            {
                CGFloat imageX = lineOrigin.x + runPosition.x + (contentWidth - imageSize) / 2.0f;
                CGFloat imageY = lineOrigin.y - ascent;
                [emojiImage drawInRect:CGRectMake(imageX, imageY, imageSize, imageSize)];
            }
        }
    }

    CGContextRestoreGState(context);
}

@end
