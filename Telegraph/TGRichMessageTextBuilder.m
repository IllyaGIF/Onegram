#import "TGRichMessageTextBuilder.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLocalization.h"

#import "../OnegramPlatform/OGPlatformText.h"
#import "../OnegramPlatform/OGPlatformGraphics.h"

#import "TGRichMessage.h"
#import "TGRichMessageMath.h"
#import "TGRichMessageInlineImageStore.h"
#import "TGModernTextViewModel.h"
#import "TGReusableLabel.h"
#import "TGSharedFileSignals.h"
#import "TGSharedMediaUtils.h"
#import "TLUser$modernUser.h"

static NSString *const TGRichMessageSpoilerLink = @"tg-rich-spoiler:";

@implementation TGRichMessageTextStyle

+ (instancetype)styleWithSize:(CGFloat)size
{
    TGRichMessageTextStyle *style = [[TGRichMessageTextStyle alloc] init];
    style.size = size;
    style.alignment = NSTextAlignmentLeft;
    return style;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGRichMessageTextStyle *style = [[TGRichMessageTextStyle alloc] init];
    style.size = _size;
    style.bold = _bold;
    style.italic = _italic;
    style.mono = _mono;
    style.codeBlock = _codeBlock;
    style.underline = _underline;
    style.strike = _strike;
    style.marked = _marked;
    style.spoiler = _spoiler;
    style.colorKind = _colorKind;
    style.link = _link;
    style.alignment = _alignment;
    style.maxNumberOfLines = _maxNumberOfLines;
    return style;
}

@end

@interface TGRichMessageTextBuilder : NSObject
{
    TGRichMessageTextEnvironment *_environment;
    TGRichMessageTheme *_theme;
    NSMutableString *_string;
    NSMutableArray *_attributes;
    NSMutableArray *_linkRanges;
    NSMutableArray *_linkUrls;
    NSMutableDictionary *_anchors;
    NSMutableDictionary *_decorations;
}

@end

@implementation TGRichMessageTextBuilder

- (instancetype)initWithEnvironment:(TGRichMessageTextEnvironment *)environment anchors:(NSMutableDictionary *)anchors
{
    self = [super init];
    if (self != nil)
    {
        _environment = environment;
        _theme = environment.theme;
        _string = [[NSMutableString alloc] init];
        _attributes = [[NSMutableArray alloc] init];
        _linkRanges = [[NSMutableArray alloc] init];
        _linkUrls = [[NSMutableArray alloc] init];
        _anchors = anchors;
        _decorations = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)addAttribute:(id)value name:(CFStringRef)name range:(NSRange)range
{
    if (value == nil || range.length == 0)
        return;
    [_attributes addObject:[NSValue valueWithRange:range]];
    [_attributes addObject:@[value, (__bridge NSString *)name]];
}

- (void)addLink:(NSString *)url range:(NSRange)range
{
    if (url.length == 0 || range.length == 0)
        return;
    NSValue *lastRange = _linkRanges.lastObject;
    if (lastRange != nil && [_linkUrls.lastObject isEqualToString:url] && NSMaxRange([lastRange rangeValue]) == range.location)
    {
        NSRange merged = [lastRange rangeValue];
        merged.length += range.length;
        _linkRanges[_linkRanges.count - 1] = [NSValue valueWithRange:merged];
        return;
    }
    [_linkRanges addObject:[NSValue valueWithRange:range]];
    [_linkUrls addObject:url];
}

- (bool)hiddenForStyle:(TGRichMessageTextStyle *)style
{
    return style.spoiler && !_environment.spoilersRevealed;
}

- (NSString *)linkForStyle:(TGRichMessageTextStyle *)style
{
    if ([self hiddenForStyle:style])
        return TGRichMessageSpoilerLink;
    return style.link;
}

- (UIColor *)colorForStyle:(TGRichMessageTextStyle *)style
{
    if (style.link != nil && ![self hiddenForStyle:style])
        return _theme.linkColor;
    return [_theme colorForKind:style.colorKind];
}

- (TGReusableLabelRunDecoration *)decorationForStyle:(TGRichMessageTextStyle *)style
{
    bool hidden = [self hiddenForStyle:style];
    bool chip = style.mono && !style.codeBlock;
    bool added = style.colorKind == TGRichMessageColorAdded;
    if (!style.underline && !style.strike && !style.marked && !chip && !hidden && !added)
        return nil;

    bool linked = style.link != nil && !hidden;
    NSString *key = [[NSString alloc] initWithFormat:@"%d%d%d%d%d%d%d", style.underline ? 1 : 0, style.strike ? 1 : 0, style.marked ? 1 : 0, chip ? 1 : 0, hidden ? 1 : 0, (int)style.colorKind, linked ? 1 : 0];
    TGReusableLabelRunDecoration *decoration = _decorations[key];
    if (decoration != nil)
        return decoration;

    UIColor *color = [self colorForStyle:style];
    decoration = [[TGReusableLabelRunDecoration alloc] init];
    if (style.marked)
    {
        decoration.backgroundColor = [_theme markedColor];
        decoration.backgroundCornerRadius = 2.0f;
        decoration.backgroundHorizontalOutset = 1.0f;
    }
    else if (added)
    {
        decoration.backgroundColor = [_theme addedColor];
        decoration.backgroundCornerRadius = 2.0f;
        decoration.backgroundHorizontalOutset = 1.0f;
    }
    else if (chip)
    {
        decoration.backgroundColor = [_theme inlineCodeColor];
        decoration.backgroundBorderColor = [_theme inlineCodeBorderColor];
        decoration.backgroundCornerRadius = 3.0f;
        decoration.backgroundHorizontalOutset = 2.0f;
    }
    if (style.underline)
        decoration.underlineColor = color;
    if (style.strike)
        decoration.strikethroughColor = color;
    if (hidden)
        decoration.coverColor = [_theme colorForKind:style.colorKind];
    _decorations[key] = decoration;
    return decoration;
}

- (void)applyFontAndColor:(TGRichMessageTextStyle *)style range:(NSRange)range
{
    CTFontRef font = [_theme coreTextFontWithSize:style.size bold:style.bold italic:style.italic mono:style.mono];
    if (font != NULL)
        [self addAttribute:(__bridge id)font name:kCTFontAttributeName range:range];
    UIColor *color = [self hiddenForStyle:style] ? [UIColor clearColor] : [_theme colorForKind:style.colorKind];
    [self addAttribute:(__bridge id)color.CGColor name:kCTForegroundColorAttributeName range:range];
}

- (void)appendString:(NSString *)string style:(TGRichMessageTextStyle *)style
{
    if (string.length == 0)
        return;
    NSRange range = NSMakeRange(_string.length, string.length);
    [_string appendString:string];
    [self applyFontAndColor:style range:range];
    TGReusableLabelRunDecoration *decoration = [self decorationForStyle:style];
    if (decoration != nil)
        [self addAttribute:decoration name:(__bridge CFStringRef)TGReusableLabelRunDecorationAttributeName range:range];
    [self addLink:[self linkForStyle:style] range:range];
}

- (void)appendAttachmentWithWidth:(CGFloat)width ascent:(CGFloat)ascent descent:(CGFloat)descent style:(TGRichMessageTextStyle *)style link:(NSString *)link draw:(void (^)(CGContextRef context, CGRect rect, UIColor *color))draw
{
    bool hidden = [self hiddenForStyle:style];
    NSRange range = NSMakeRange(_string.length, 1);
    [_string appendString:@"￼"];

    CTFontRef font = [_theme coreTextFontWithSize:style.size bold:style.bold italic:style.italic mono:style.mono];
    if (font != NULL)
        [self addAttribute:(__bridge id)font name:kCTFontAttributeName range:range];
    [self addAttribute:(__bridge id)[UIColor clearColor].CGColor name:kCTForegroundColorAttributeName range:range];

    CTRunDelegateRef delegate = TGReusableLabelCreateAttachmentRunDelegate(ascent, descent, width);
    if (delegate != NULL)
        [self addAttribute:(__bridge_transfer id)delegate name:kCTRunDelegateAttributeName range:range];

    UIColor *color = (link != nil || style.link != nil) && !hidden ? _theme.linkColor : [_theme colorForKind:style.colorKind];
    TGReusableLabelRunDecoration *decoration = [[TGReusableLabelRunDecoration alloc] init];
    if (hidden)
        decoration.coverColor = [_theme colorForKind:style.colorKind];
    else if (draw != nil)
    {
        decoration.drawContent = ^(CGContextRef context, CGRect rect)
        {
            draw(context, rect, color);
        };
    }
    if (style.underline && !hidden)
        decoration.underlineColor = color;
    if (style.strike && !hidden)
        decoration.strikethroughColor = color;
    [self addAttribute:decoration name:(__bridge CFStringRef)TGReusableLabelRunDecorationAttributeName range:range];
    [self addLink:hidden ? TGRichMessageSpoilerLink : (link ?: style.link) range:range];
}

- (void)appendScript:(NSString *)string superscript:(bool)superscript style:(TGRichMessageTextStyle *)style
{
    if (string.length == 0)
        return;
    UIFont *baseFont = [_theme fontWithSize:style.size bold:style.bold italic:style.italic mono:style.mono];
    UIFont *scriptFont = [_theme fontWithSize:style.size * 0.72f bold:style.bold italic:style.italic mono:style.mono];
    CGFloat ascent = baseFont.ascender;
    CGFloat descent = -baseFont.descender;
    CGFloat width = ceil([string sizeWithFont:scriptFont].width) + 1.0f;
    CGFloat offset = superscript ? -style.size * 0.34f : style.size * 0.14f;
    [self appendAttachmentWithWidth:width ascent:ascent descent:descent style:style link:nil draw:^(CGContextRef context, CGRect rect, UIColor *color)
    {
        CGFloat baseline = rect.origin.y + ascent + offset;
        UIGraphicsPushContext(context);
        [color set];
        [string drawAtPoint:CGPointMake(rect.origin.x, baseline - scriptFont.ascender) withFont:scriptFont];
        UIGraphicsPopContext();
    }];
}

- (void)appendMath:(NSString *)source style:(TGRichMessageTextStyle *)style
{
    if (source.length == 0)
        return;
    UIFont *baseFont = [_theme fontWithSize:style.size bold:style.bold italic:style.italic mono:style.mono];
    CGFloat ascent = baseFont.ascender;
    CGFloat descent = -baseFont.descender;
    CGFloat fontSize = style.size;
    TGRichMessageMathLayout *layout = [TGRichMessageMathLayout layoutWithSource:source fontSize:fontSize display:false];
    CGFloat maximumAscent = ascent * 1.1f;
    CGFloat maximumDescent = descent * 1.35f;
    if (layout.ascent > maximumAscent || layout.descent > maximumDescent)
    {
        CGFloat scale = MIN(maximumAscent / MAX(1.0f, layout.ascent), maximumDescent / MAX(1.0f, layout.descent));
        layout = [TGRichMessageMathLayout layoutWithSource:source fontSize:MAX(fontSize * 0.55f, fontSize * scale) display:false];
    }
    [self appendAttachmentWithWidth:layout.width + 2.0f ascent:ascent descent:descent style:style link:nil draw:^(CGContextRef context, CGRect rect, UIColor *color)
    {
        [layout drawInContext:context baselineOrigin:CGPointMake(rect.origin.x + 1.0f, rect.origin.y + ascent) color:color];
    }];
}

- (void)appendInlineImageWithKey:(NSString *)key size:(CGSize)imageSize fallback:(NSString *)fallback signalGenerator:(SSignal *(^)(void))signalGenerator style:(TGRichMessageTextStyle *)style
{
    if (signalGenerator != nil)
    {
        [_environment.inlineImageKeys addObject:key];
        [TGRichMessageInlineImageStore requestImageForKey:key signalGenerator:signalGenerator];
    }
    UIFont *baseFont = [_theme fontWithSize:style.size bold:style.bold italic:style.italic mono:style.mono];
    CGFloat ascent = baseFont.ascender;
    CGFloat descent = -baseFont.descender;
    [self appendAttachmentWithWidth:imageSize.width + 2.0f ascent:ascent descent:descent style:style link:nil draw:^(CGContextRef context, CGRect rect, UIColor *color)
    {
        CGRect imageRect = CGRectMake(rect.origin.x + 1.0f, rect.origin.y + ascent - imageSize.height + MIN(descent, imageSize.height * 0.18f), imageSize.width, imageSize.height);
        UIImage *image = [TGRichMessageInlineImageStore imageForKey:key];
        if (image == nil && signalGenerator != nil)
            [TGRichMessageInlineImageStore requestImageForKey:key signalGenerator:signalGenerator];
        if (image == nil && fallback.length != 0)
            image = TGEmojiCachedImageOfSize(fallback, imageSize.height) ?: TGEmojiImageOfSize(fallback, imageSize.height);
        UIGraphicsPushContext(context);
        if (image != nil)
        {
            CGSize fitted = TGFitSize(image.size, imageRect.size);
            [image drawInRect:CGRectMake(imageRect.origin.x + (imageRect.size.width - fitted.width) / 2.0f, imageRect.origin.y + (imageRect.size.height - fitted.height) / 2.0f, fitted.width, fitted.height)];
        }
        else
        {
            CGContextSetFillColorWithColor(context, [color colorWithAlphaComponent:0.12f].CGColor);
            CGContextFillEllipseInRect(context, CGRectInset(imageRect, imageRect.size.width * 0.08f, imageRect.size.height * 0.08f));
        }
        UIGraphicsPopContext();
    }];
}

- (void)appendButton:(TGRichMessageText *)text style:(TGRichMessageTextStyle *)style
{
    NSString *title = [text plainText];
    if (title.length == 0)
        title = @" ";
    NSUInteger index = _environment.buttons.count;
    if (text.button != nil)
        [_environment.buttons addObject:text.button];
    else
        [_environment.buttons addObject:[NSNull null]];

    UIFont *baseFont = [_theme fontWithSize:style.size bold:style.bold italic:style.italic mono:style.mono];
    UIFont *titleFont = [_theme fontWithSize:style.size * 0.88f bold:true italic:false mono:false];
    CGFloat ascent = baseFont.ascender;
    CGFloat descent = -baseFont.descender;
    CGFloat width = ceil([title sizeWithFont:titleFont].width) + 18.0f;
    int32_t buttonStyle = text.button.style;
    TGRichMessageTheme *theme = _theme;
    NSString *link = [[NSString alloc] initWithFormat:@"tg-rich-button:%d", (int)index];
    [self appendAttachmentWithWidth:width + 4.0f ascent:ascent descent:descent style:style link:link draw:^(CGContextRef context, CGRect rect, __unused UIColor *color)
    {
        CGFloat height = CGCeil(titleFont.ascender - titleFont.descender + 6.0f);
        CGFloat centerY = rect.origin.y + ascent - ascent * 0.36f;
        CGRect pill = CGRectMake(rect.origin.x + 2.0f, CGFloor(centerY - height / 2.0f), width, height);
        UIColor *fill = nil;
        UIColor *titleColor = nil;
        if (buttonStyle & TGRichMessageButtonStyleDanger)
            fill = UIColorRGB(0xe5484d);
        else if (buttonStyle & TGRichMessageButtonStyleSuccess)
            fill = UIColorRGB(0x34a853);
        else if (buttonStyle & TGRichMessageButtonStylePrimary)
            fill = theme.accentColor;
        if (buttonStyle & TGRichMessageButtonStyleLink)
        {
            fill = nil;
            titleColor = theme.linkColor;
        }
        CGContextSaveGState(context);
        CGContextSetShadowWithColor(context, CGSizeZero, 0.0f, NULL);
        OGPlatformAddRoundedRectPath(context, pill, height / 2.0f);
        if (fill != nil)
        {
            CGContextSetFillColorWithColor(context, fill.CGColor);
            CGContextFillPath(context);
            titleColor = [UIColor whiteColor];
        }
        else if (!(buttonStyle & TGRichMessageButtonStyleLink))
        {
            CGContextSetFillColorWithColor(context, [theme.accentColor colorWithAlphaComponent:theme.branded ? 0.16f : 0.12f].CGColor);
            CGContextFillPath(context);
            titleColor = theme.accentColor;
        }
        else
            CGContextBeginPath(context);
        if (theme.branded && fill != nil)
        {
            CGContextSaveGState(context);
            OGPlatformAddRoundedRectPath(context, pill, height / 2.0f);
            CGContextClip(context);
            OGPlatformDrawVerticalGradient(context, CGRectMake(pill.origin.x, pill.origin.y, pill.size.width, pill.size.height / 2.0f), UIColorRGBA(0xffffff, 0.35f), UIColorRGBA(0xffffff, 0.08f));
            CGContextRestoreGState(context);
        }
        CGContextRestoreGState(context);
        UIGraphicsPushContext(context);
        [titleColor set];
        CGSize titleSize = [title sizeWithFont:titleFont];
        [title drawAtPoint:CGPointMake(CGFloor(pill.origin.x + (pill.size.width - titleSize.width) / 2.0f), CGFloor(pill.origin.y + (pill.size.height - titleSize.height) / 2.0f)) withFont:titleFont];
        UIGraphicsPopContext();
    }];
}

- (NSString *)stripPrefix:(NSString *)prefix from:(NSString *)string
{
    return [string hasPrefix:prefix] ? [string substringFromIndex:prefix.length] : string;
}

- (void)appendChildrenOf:(TGRichMessageText *)text style:(TGRichMessageTextStyle *)style
{
    for (TGRichMessageText *child in text.texts)
        [self appendText:child style:style];
}

- (void)appendText:(TGRichMessageText *)text style:(TGRichMessageTextStyle *)style
{
    if (text == nil)
        return;
    TGRichMessageTextStyle *childStyle = [style copy];
    switch (text.kind)
    {
        case TGRichMessageTextKindEmpty:
            break;
        case TGRichMessageTextKindPlain:
            [self appendString:text.string style:style];
            break;
        case TGRichMessageTextKindConcat:
            [self appendChildrenOf:text style:style];
            break;
        case TGRichMessageTextKindBold:
            childStyle.bold = true;
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindItalic:
            childStyle.italic = true;
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindUnderline:
            childStyle.underline = true;
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindStrike:
            childStyle.strike = true;
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindFixed:
            childStyle.mono = true;
            childStyle.size = style.codeBlock ? style.size : style.size * 0.94f;
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindMarked:
            childStyle.marked = true;
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindSpoiler:
            childStyle.spoiler = true;
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindSubscript:
        case TGRichMessageTextKindSuperscript:
        {
            NSString *plain = [text plainText];
            [self appendScript:plain superscript:text.kind == TGRichMessageTextKindSuperscript style:style];
            break;
        }
        case TGRichMessageTextKindUrl:
            childStyle.link = text.string.length != 0 ? text.string : style.link;
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindEmail:
            childStyle.link = [@"mailto:" stringByAppendingString:text.string ?: @""];
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindPhone:
            childStyle.link = [@"tel:" stringByAppendingString:text.string ?: @""];
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindAnchor:
            if (text.string.length != 0 && _anchors != nil && _anchors[text.string] == nil)
                _anchors[text.string] = @(_string.length);
            [self appendChildrenOf:text style:style];
            break;
        case TGRichMessageTextKindMath:
            [self appendMath:text.string style:style];
            break;
        case TGRichMessageTextKindCustomEmoji:
        {
            UIFont *font = [_theme fontWithSize:style.size bold:style.bold italic:style.italic mono:style.mono];
            CGFloat side = CGFloor((font.ascender - font.descender) * 0.92f);
            NSString *key = [TGRichMessageInlineImageStore customEmojiKey:text.identifier];
            int64_t documentId = text.identifier;
            SSignal *(^generator)(void) = documentId == 0 ? nil : ^SSignal *
            {
                return [TGRichMessageInlineImageStore customEmojiImageSignal:documentId];
            };
            [self appendInlineImageWithKey:key size:CGSizeMake(side, side) fallback:text.string signalGenerator:generator style:style];
            break;
        }
        case TGRichMessageTextKindImage:
        {
            TGDocumentMediaAttachment *document = [_environment.richMessage documentWithId:text.identifier];
            UIFont *font = [_theme fontWithSize:style.size bold:style.bold italic:style.italic mono:style.mono];
            CGFloat maximumHeight = CGFloor(font.ascender - font.descender);
            CGSize size = text.size;
            if (size.width <= 0.0f || size.height <= 0.0f)
                size = document != nil ? [document pictureSize] : CGSizeZero;
            if (size.width <= 0.0f || size.height <= 0.0f)
                size = CGSizeMake(maximumHeight, maximumHeight);
            CGSize fitted = TGFitSize(size, CGSizeMake(maximumHeight * 4.0f, maximumHeight));
            fitted = CGSizeMake(CGCeil(fitted.width), CGCeil(fitted.height));
            NSString *key = [[NSString alloc] initWithFormat:@"rich-document-%lld-%dx%d", text.identifier, (int)fitted.width, (int)fitted.height];
            CGSize pixelSize = fitted;
            SSignal *(^generator)(void) = document == nil ? nil : ^SSignal *
            {
                return [TGSharedFileSignals squareFileThumbnail:document ofSize:pixelSize threadPool:[TGSharedMediaUtils sharedMediaImageProcessingThreadPool] memoryCache:[TGSharedMediaUtils sharedMediaMemoryImageCache] pixelProcessingBlock:nil];
            };
            [self appendInlineImageWithKey:key size:fitted fallback:nil signalGenerator:generator style:style];
            break;
        }
        case TGRichMessageTextKindMention:
            childStyle.link = [@"mention://" stringByAppendingString:[self stripPrefix:@"@" from:[text plainText]]];
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindHashtag:
            childStyle.link = [@"hashtag://" stringByAppendingString:[self stripPrefix:@"#" from:[text plainText]]];
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindCashtag:
            childStyle.link = [@"cashtag://" stringByAppendingString:[self stripPrefix:@"$" from:[text plainText]]];
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindBotCommand:
            childStyle.link = [@"command://" stringByAppendingString:[self stripPrefix:@"/" from:[text plainText]]];
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindAutoUrl:
        {
            NSString *url = [text plainText];
            if ([url rangeOfString:@"://"].location == NSNotFound)
                url = [@"http://" stringByAppendingString:url];
            childStyle.link = url;
            [self appendChildrenOf:text style:childStyle];
            break;
        }
        case TGRichMessageTextKindAutoEmail:
            childStyle.link = [@"mailto:" stringByAppendingString:[text plainText]];
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindAutoPhone:
            childStyle.link = [@"tel:" stringByAppendingString:[text plainText]];
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindBankCard:
            childStyle.link = [@"tg-rich-copy:" stringByAppendingString:[text plainText]];
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindMentionName:
            childStyle.link = [[NSString alloc] initWithFormat:@"tg-user://%d", (int)TGModernLegacyIdForModernId(text.identifier)];
            [self appendChildrenOf:text style:childStyle];
            break;
        case TGRichMessageTextKindDate:
        {
            NSString *formatted = [TGRichMessageTextEnvironment formattedDate:text.value flags:text.flags];
            if (formatted.length != 0)
                [self appendString:formatted style:style];
            else
                [self appendChildrenOf:text style:style];
            break;
        }
        case TGRichMessageTextKindDiff:
        {
            if (text.texts.count > 1)
            {
                TGRichMessageTextStyle *removedStyle = [style copy];
                removedStyle.strike = true;
                removedStyle.colorKind = TGRichMessageColorRemoved;
                [self appendText:text.texts[1] style:removedStyle];
            }
            TGRichMessageTextStyle *addedStyle = [style copy];
            addedStyle.colorKind = TGRichMessageColorAdded;
            [self appendText:[text text] style:addedStyle];
            break;
        }
        case TGRichMessageTextKindButton:
            [self appendButton:text style:style];
            break;
    }
}

- (NSArray *)textCheckingResults
{
    NSMutableArray *results = [[NSMutableArray alloc] init];
    for (NSUInteger index = 0; index < _linkRanges.count; index++)
    {
        [results addObject:[[TGTextCheckingResult alloc] initWithRange:[_linkRanges[index] rangeValue] type:TGTextCheckingResultTypeLink contents:_linkUrls[index] value:nil highlightAsLink:false]];
    }
    return results;
}

- (NSString *)string
{
    return _string;
}

- (NSArray *)attributes
{
    return _attributes;
}

@end

@implementation TGRichMessageTextEnvironment

- (instancetype)initWithTheme:(TGRichMessageTheme *)theme richMessage:(TGRichMessage *)richMessage spoilersRevealed:(bool)spoilersRevealed
{
    self = [super init];
    if (self != nil)
    {
        _theme = theme;
        _richMessage = richMessage;
        _spoilersRevealed = spoilersRevealed;
        _buttons = [[NSMutableArray alloc] init];
        _inlineImageKeys = [[NSMutableSet alloc] init];
    }
    return self;
}

- (TGModernTextViewModel *)modelWithString:(NSString *)string attributes:(NSArray *)attributes results:(NSArray *)results style:(TGRichMessageTextStyle *)style
{
    TGModernTextViewModel *model = [[TGModernTextViewModel alloc] initWithText:string font:[_theme coreTextFontWithSize:style.size bold:style.bold italic:style.italic mono:style.mono]];
    model.textColor = [_theme colorForKind:style.colorKind];
    model.linkColor = _theme.linkColor;
    model.layoutFlags = TGReusableLabelLayoutMultiline | TGReusableLabelLayoutHighlightLinks;
    model.additionalAttributes = attributes.count == 0 ? nil : attributes;
    model.textCheckingResults = results.count == 0 ? nil : results;
    model.alignment = style.alignment;
    model.maxNumberOfLines = style.maxNumberOfLines;
    model.additionalLineSpacing = style.codeBlock ? 0.0f : CGFloor(style.size * 0.1f);
    if (_theme.branded && style.colorKind != TGRichMessageColorInverted)
    {
        model.shadowColor = _theme.shadowColor;
        model.shadowOffset = _theme.shadowOffset;
    }
    return model;
}

- (TGModernTextViewModel *)textModelWithText:(TGRichMessageText *)text style:(TGRichMessageTextStyle *)style anchors:(NSMutableDictionary *)anchors
{
    TGRichMessageTextBuilder *builder = [[TGRichMessageTextBuilder alloc] initWithEnvironment:self anchors:anchors];
    [builder appendText:text style:style];
    NSString *string = [builder string];
    if (string.length == 0)
        return nil;
    return [self modelWithString:[string copy] attributes:[builder attributes] results:[builder textCheckingResults] style:style];
}

- (TGModernTextViewModel *)textModelWithString:(NSString *)string style:(TGRichMessageTextStyle *)style
{
    if (string.length == 0)
        return nil;
    TGRichMessageTextBuilder *builder = [[TGRichMessageTextBuilder alloc] initWithEnvironment:self anchors:nil];
    [builder appendString:string style:style];
    return [self modelWithString:string attributes:[builder attributes] results:[builder textCheckingResults] style:style];
}

+ (NSString *)relativeStringForDelta:(int32_t)delta
{
    int32_t absolute = ABS(delta);
    bool future = delta > 0;
    if (absolute < 60)
        return TGLocalized(@"RichMessage.Relative.Now");
    NSString *key = nil;
    int32_t value = 0;
    if (absolute < 60 * 60)
    {
        value = absolute / 60;
        key = future ? @"RichMessage.Relative.InMinutes" : @"RichMessage.Relative.MinutesAgo";
    }
    else if (absolute < 24 * 60 * 60)
    {
        value = absolute / (60 * 60);
        key = future ? @"RichMessage.Relative.InHours" : @"RichMessage.Relative.HoursAgo";
    }
    else
    {
        value = absolute / (24 * 60 * 60);
        key = future ? @"RichMessage.Relative.InDays" : @"RichMessage.Relative.DaysAgo";
    }
    return [[NSString alloc] initWithFormat:TGLocalized(key), [[NSString alloc] initWithFormat:@"%d", (int)value]];
}

+ (NSString *)string:(NSDate *)date template:(NSString *)templateString locale:(NSLocale *)locale
{
    NSString *format = OGPlatformDateFormatFromTemplate(templateString, 0, locale);
    if (format.length == 0)
        return nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = locale;
    formatter.dateFormat = format;
    return [formatter stringFromDate:date];
}

+ (NSString *)formattedDate:(int32_t)date flags:(int32_t)flags
{
    if (flags == 0)
        return nil;

    if (flags & TGRichMessageDateFlagRelative)
        return [self relativeStringForDelta:date - (int32_t)[[NSDate date] timeIntervalSince1970]];

    NSDate *value = [NSDate dateWithTimeIntervalSince1970:date];
    NSLocale *locale = [effectiveLocalization() locale] ?: [NSLocale currentLocale];
    NSMutableArray *parts = [[NSMutableArray alloc] init];
    if (flags & TGRichMessageDateFlagDayOfWeek)
    {
        NSString *dayOfWeek = [TGDateUtils stringForDayOfWeek:date];
        if (dayOfWeek.length != 0)
            [parts addObject:dayOfWeek];
    }
    if (flags & TGRichMessageDateFlagLongDate)
    {
        NSString *longDate = [self string:value template:@"dMMMMy" locale:locale];
        if (longDate.length != 0)
            [parts addObject:longDate];
    }
    else if (flags & TGRichMessageDateFlagShortDate)
    {
        NSString *shortDate = [TGDateUtils stringForFullDate:date];
        if (shortDate.length != 0)
            [parts addObject:shortDate];
    }
    if (flags & TGRichMessageDateFlagLongTime)
    {
        NSString *longTime = [self string:value template:@"jjmmss" locale:locale];
        if (longTime.length != 0)
            [parts addObject:longTime];
    }
    else if (flags & TGRichMessageDateFlagShortTime)
    {
        NSString *shortTime = [TGDateUtils stringForShortTime:date];
        if (shortTime.length != 0)
            [parts addObject:shortTime];
    }
    return parts.count == 0 ? nil : [parts componentsJoinedByString:@", "];
}

@end
