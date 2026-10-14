#import "TGRichMessageTheme.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGModernViewContext.h"
#import "TGMessageViewModel.h"
#import "TGPresentation.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"

static NSMutableDictionary *TGRichMessageFontCache(void)
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });
    return cache;
}

static bool TGRichMessageFontNameHasItalic(NSString *name)
{
    NSString *lowercase = name.lowercaseString;
    return [lowercase rangeOfString:@"italic"].location != NSNotFound || [lowercase rangeOfString:@"oblique"].location != NSNotFound;
}

static bool TGRichMessageFontNameHasBold(NSString *name)
{
    NSString *lowercase = name.lowercaseString;
    return [lowercase rangeOfString:@"bold"].location != NSNotFound || [lowercase rangeOfString:@"heavy"].location != NSNotFound || [lowercase rangeOfString:@"black"].location != NSNotFound;
}

static bool TGRichMessageFontNameIsUnusualWeight(NSString *name)
{
    NSString *lowercase = name.lowercaseString;
    for (NSString *token in @[@"light", @"thin", @"ultra", @"condensed", @"medium", @"semibold", @"demi", @"black", @"heavy", @"compressed", @"rounded"])
    {
        if ([lowercase rangeOfString:token].location != NSNotFound)
            return true;
    }
    return false;
}

@implementation TGRichMessageTheme

- (instancetype)initWithContext:(TGModernViewContext *)context incoming:(bool)incoming
{
    self = [super init];
    if (self != nil)
    {
        _incoming = incoming;
        _branded = [TGPresentation brandedIOS6Style];
        _fontSize = TGGetMessageViewModelLayoutConstants()->textFontSize;
        TGPresentationPallete *pallete = context.presentation.pallete;
        _textColor = incoming ? pallete.chatIncomingTextColor : pallete.chatOutgoingTextColor;
        _secondaryColor = incoming ? pallete.chatIncomingSubtextColor : pallete.chatOutgoingSubtextColor;
        _accentColor = incoming ? pallete.chatIncomingAccentColor : pallete.chatOutgoingAccentColor;
        _linkColor = incoming ? pallete.chatIncomingLinkColor : pallete.chatOutgoingLinkColor;
        _lineColor = incoming ? pallete.chatIncomingLineColor : pallete.chatOutgoingLineColor;
        if (_branded)
        {
            OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];
            _baseFont = appearance.messageFont != nil ? [appearance.messageFont fontWithSize:_fontSize] : TGSystemFontOfSize(_fontSize);
            _shadowColor = appearance.messageShadowColor;
            _shadowOffset = appearance.messageShadowOffset;
        }
        else
            _baseFont = TGSystemFontOfSize(_fontSize);
        if (_textColor == nil)
            _textColor = [UIColor blackColor];
        if (_secondaryColor == nil)
            _secondaryColor = [_textColor colorWithAlphaComponent:0.6f];
        if (_accentColor == nil)
            _accentColor = UIColorRGB(0x007ee5);
        if (_linkColor == nil)
            _linkColor = _accentColor;
        if (_lineColor == nil)
            _lineColor = [_accentColor colorWithAlphaComponent:0.5f];
    }
    return self;
}

- (UIColor *)colorForKind:(TGRichMessageColorKind)kind
{
    switch (kind)
    {
        case TGRichMessageColorSecondary:
            return _secondaryColor;
        case TGRichMessageColorAccent:
            return _accentColor;
        case TGRichMessageColorRemoved:
            return UIColorRGB(0xd2453f);
        case TGRichMessageColorInverted:
            return [UIColor whiteColor];
        default:
            return _textColor;
    }
}

- (UIColor *)markedColor
{
    return _branded ? UIColorRGBA(0xffde59, 0.6f) : UIColorRGBA(0xffd60a, 0.38f);
}

- (UIColor *)addedColor
{
    return UIColorRGBA(0x34c759, 0.24f);
}

- (UIColor *)inlineCodeColor
{
    return _branded ? UIColorRGBA(0xffffff, 0.55f) : [_textColor colorWithAlphaComponent:0.08f];
}

- (UIColor *)inlineCodeBorderColor
{
    return _branded ? UIColorRGBA(0x000000, 0.14f) : nil;
}

- (UIFont *)fontWithSize:(CGFloat)size bold:(bool)bold italic:(bool)italic mono:(bool)mono
{
    size = MAX(6.0f, size);
    if (mono)
    {
        UIFont *font = [UIFont fontWithName:bold ? @"Menlo-Bold" : @"Menlo-Regular" size:size];
        if (font == nil)
            font = [UIFont fontWithName:bold ? @"Courier-Bold" : @"Courier" size:size];
        return font ?: TGFixedSystemFontOfSize(size);
    }

    UIFont *base = _baseFont;
    if (!bold && !italic)
        return [base fontWithSize:size];

    UIFont *system = [UIFont systemFontOfSize:base.pointSize];
    bool isSystemFont = [system.fontName isEqualToString:base.fontName] || [base.familyName hasPrefix:@"."];
    if (!isSystemFont)
    {
        NSString *bestName = nil;
        int bestScore = -1000;
        for (NSString *name in [UIFont fontNamesForFamilyName:base.familyName])
        {
            int score = 0;
            score += (TGRichMessageFontNameHasBold(name) == bold) ? 10 : -10;
            score += (TGRichMessageFontNameHasItalic(name) == italic) ? 10 : -10;
            if (TGRichMessageFontNameIsUnusualWeight(name))
                score -= 3;
            if (score > bestScore)
            {
                bestScore = score;
                bestName = name;
            }
        }
        if (bestName != nil && bestScore >= 17)
        {
            UIFont *font = [UIFont fontWithName:bestName size:size];
            if (font != nil)
                return font;
        }
    }

    if (bold)
        return TGBoldSystemFontOfSize(size);
    return TGItalicSystemFontOfSize(size);
}

- (CTFontRef)coreTextFontWithSize:(CGFloat)size bold:(bool)bold italic:(bool)italic mono:(bool)mono
{
    UIFont *font = [self fontWithSize:size bold:bold italic:italic mono:mono];
    NSString *key = [[NSString alloc] initWithFormat:@"%@|%d|%d%d%d", font.fontName, (int)lrintf(size * 4.0f), bold ? 1 : 0, italic ? 1 : 0, mono ? 1 : 0];
    NSMutableDictionary *cache = TGRichMessageFontCache();
    id cached = nil;
    @synchronized(cache)
    {
        cached = cache[key];
    }
    if (cached != nil)
        return (__bridge CTFontRef)cached;

    CTFontRef coreTextFont = TGCoreTextFontForUIFont(font);
#if OG_PLATFORM_HAS_CORETEXT
    if (italic && coreTextFont != NULL && !TGRichMessageFontNameHasItalic(font.fontName))
    {
        CGAffineTransform skew = CGAffineTransformMake(1.0f, 0.0f, 0.2f, 1.0f, 0.0f, 0.0f);
        CTFontRef skewed = CTFontCreateCopyWithAttributes(coreTextFont, 0.0f, &skew, NULL);
        if (skewed != NULL)
        {
            CFRelease(coreTextFont);
            coreTextFont = skewed;
        }
    }
#endif
    if (coreTextFont == NULL)
        return NULL;

    id object = (__bridge_transfer id)coreTextFont;
    @synchronized(cache)
    {
        if (cache[key] == nil)
            cache[key] = object;
        object = cache[key];
    }
    return (__bridge CTFontRef)object;
}

@end
