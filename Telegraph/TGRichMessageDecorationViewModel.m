#import "TGRichMessageDecorationViewModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../OnegramPlatform/OGPlatformGraphics.h"

#import "TGRichMessageTheme.h"
#import "TGRichMessageMath.h"

@implementation TGRichDecoration

+ (instancetype)decorationWithKind:(TGRichDecorationKind)kind rect:(CGRect)rect
{
    TGRichDecoration *decoration = [[TGRichDecoration alloc] init];
    decoration->_kind = kind;
    decoration->_rect = rect;
    decoration->_clipRect = CGRectNull;
    return decoration;
}

@end

static UIColor *TGRichAdjustedColor(UIColor *color, CGFloat amount)
{
    CGFloat red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 1.0f;
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    size_t count = CGColorGetNumberOfComponents(color.CGColor);
    if (components == NULL)
        return color;
    if (count >= 4)
    {
        red = components[0];
        green = components[1];
        blue = components[2];
        alpha = components[3];
    }
    else if (count >= 2)
    {
        red = green = blue = components[0];
        alpha = components[1];
    }
    if (amount >= 0.0f)
    {
        red += (1.0f - red) * amount;
        green += (1.0f - green) * amount;
        blue += (1.0f - blue) * amount;
    }
    else
    {
        red *= 1.0f + amount;
        green *= 1.0f + amount;
        blue *= 1.0f + amount;
    }
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

static void TGRichFillRounded(CGContextRef context, CGRect rect, CGFloat radius, UIColor *color)
{
    if (color == nil)
        return;
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextBeginPath(context);
    OGPlatformAddRoundedRectPath(context, rect, radius);
    CGContextFillPath(context);
}

static void TGRichStrokeRounded(CGContextRef context, CGRect rect, CGFloat radius, UIColor *color, CGFloat lineWidth)
{
    if (color == nil)
        return;
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, lineWidth);
    CGContextBeginPath(context);
    OGPlatformAddRoundedRectPath(context, CGRectInset(rect, lineWidth / 2.0f, lineWidth / 2.0f), MAX(0.0f, radius - lineWidth / 2.0f));
    CGContextStrokePath(context);
}

static void TGRichFillGradientRounded(CGContextRef context, CGRect rect, CGFloat radius, UIColor *top, UIColor *bottom)
{
    CGContextSaveGState(context);
    CGContextBeginPath(context);
    OGPlatformAddRoundedRectPath(context, rect, radius);
    CGContextClip(context);
    OGPlatformDrawVerticalGradient(context, rect, top, bottom);
    CGContextRestoreGState(context);
}

static void TGRichInnerShadow(CGContextRef context, CGRect rect, CGFloat radius, UIColor *color, CGFloat offset, CGFloat blur)
{
    CGContextSaveGState(context);
    CGContextBeginPath(context);
    OGPlatformAddRoundedRectPath(context, rect, radius);
    CGContextClip(context);
    CGContextSetShadowWithColor(context, CGSizeMake(0.0f, offset), blur, color.CGColor);
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextBeginPath(context);
    CGContextAddRect(context, CGRectInset(rect, -20.0f, -20.0f));
    OGPlatformAddRoundedRectPath(context, rect, radius);
    CGContextEOFillPath(context);
    CGContextRestoreGState(context);
}

static void TGRichFillLine(CGContextRef context, CGRect rect, UIColor *color)
{
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, rect);
}

static void TGRichDrawCheckmark(CGContextRef context, CGRect rect, UIColor *color, CGFloat lineWidth)
{
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, lineWidth);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, rect.origin.x + rect.size.width * 0.26f, rect.origin.y + rect.size.height * 0.52f);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width * 0.43f, rect.origin.y + rect.size.height * 0.7f);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width * 0.76f, rect.origin.y + rect.size.height * 0.32f);
    CGContextStrokePath(context);
}

static void TGRichDrawDust(CGContextRef context, CGRect rect, UIColor *color)
{
    CGContextSaveGState(context);
    CGContextSetFillColorWithColor(context, color.CGColor);
    uint32_t seed = ((uint32_t)lrintf(rect.origin.x * 5.0f) * 73856093u) ^ ((uint32_t)lrintf(rect.origin.y * 3.0f) * 19349663u);
    uint32_t width = (uint32_t)MAX(1.0f, CGFloor(rect.size.width));
    uint32_t height = (uint32_t)MAX(1.0f, CGFloor(rect.size.height));
    int count = (int)MIN(6000.0f, rect.size.width * rect.size.height / 22.0f);
    CGFloat dot = MAX(1.0f, TGScreenPixel * 2.0f);
    for (int i = 0; i < count; i++)
    {
        seed = seed * 1664525u + 1013904223u;
        CGFloat x = rect.origin.x + (CGFloat)((seed >> 8) % width);
        seed = seed * 1664525u + 1013904223u;
        CGFloat y = rect.origin.y + (CGFloat)((seed >> 8) % height);
        CGContextSetAlpha(context, 0.3f + 0.7f * (CGFloat)((seed >> 3) & 0xf) / 15.0f);
        CGContextFillRect(context, CGRectMake(x, y, dot, dot));
    }
    CGContextRestoreGState(context);
}

@interface TGRichMessageDecorationViewModel ()
{
    TGRichMessageTheme *_theme;
}

@end

@implementation TGRichMessageDecorationViewModel

- (instancetype)initWithTheme:(TGRichMessageTheme *)theme
{
    self = [super init];
    if (self != nil)
    {
        _theme = theme;
        self.hasNoView = true;
    }
    return self;
}

- (CGFloat)highlightOffset
{
    return _theme.shadowOffset.height >= 0.0f ? 1.0f : -1.0f;
}

- (void)drawInContext:(CGContextRef)context
{
    if (self.hidden || self.alpha < FLT_EPSILON)
        return;

    CGRect clip = CGContextGetClipBoundingBox(context);
    for (TGRichDecoration *decoration in _decorations)
    {
        if (!CGRectIntersectsRect(CGRectInset(decoration.rect, -6.0f, -6.0f), clip))
            continue;
        CGContextSaveGState(context);
        if (!CGRectIsNull(decoration.clipRect))
        {
            CGContextBeginPath(context);
            OGPlatformAddRoundedRectPath(context, decoration.clipRect, _theme.branded ? 6.0f : 7.0f);
            CGContextClip(context);
        }
        [self drawDecoration:decoration context:context];
        CGContextRestoreGState(context);
    }
}

- (void)drawDecoration:(TGRichDecoration *)decoration context:(CGContextRef)context
{
    CGRect rect = decoration.rect;
    bool branded = _theme.branded;
    UIColor *textColor = _theme.textColor;
    UIColor *accentColor = _theme.accentColor;
    UIColor *secondaryColor = _theme.secondaryColor;
    CGFloat pixel = TGScreenPixel;

    switch (decoration.kind)
    {
        case TGRichDecorationQuote:
        {
            CGFloat radius = 4.0f;
            if (branded)
            {
                TGRichFillRounded(context, CGRectOffset(rect, 0.0f, 1.0f), radius, UIColorRGBA(0xffffff, 0.55f));
                TGRichFillRounded(context, rect, radius, UIColorRGBA(0x000000, 0.05f));
                TGRichInnerShadow(context, rect, radius, UIColorRGBA(0x000000, 0.22f), [self highlightOffset], 2.0f);
            }
            else
                TGRichFillRounded(context, rect, radius, [accentColor colorWithAlphaComponent:0.1f]);
            CGContextSaveGState(context);
            CGContextBeginPath(context);
            OGPlatformAddRoundedRectPath(context, rect, radius);
            CGContextClip(context);
            CGRect bar = CGRectMake(rect.origin.x, rect.origin.y, 3.0f, rect.size.height);
            if (branded)
            {
                OGPlatformDrawVerticalGradient(context, bar, TGRichAdjustedColor(accentColor, 0.35f), TGRichAdjustedColor(accentColor, -0.15f));
                TGRichFillLine(context, CGRectMake(CGRectGetMaxX(bar), bar.origin.y, pixel, bar.size.height), UIColorRGBA(0xffffff, 0.6f));
            }
            else
                TGRichFillLine(context, bar, accentColor);
            CGContextRestoreGState(context);
            break;
        }
        case TGRichDecorationQuoteIcon:
        {
            UIFont *font = [UIFont fontWithName:@"Georgia-Bold" size:rect.size.height * 1.9f] ?: [UIFont boldSystemFontOfSize:rect.size.height * 1.9f];
            UIGraphicsPushContext(context);
            if (branded)
            {
                [UIColorRGBA(0xffffff, 0.7f) set];
                [@"”" drawAtPoint:CGPointMake(rect.origin.x, rect.origin.y - rect.size.height * 0.28f + [self highlightOffset]) withFont:font];
            }
            [[accentColor colorWithAlphaComponent:0.55f] set];
            [@"”" drawAtPoint:CGPointMake(rect.origin.x, rect.origin.y - rect.size.height * 0.28f) withFont:font];
            UIGraphicsPopContext();
            break;
        }
        case TGRichDecorationCodePanel:
        {
            CGFloat radius = branded ? 6.0f : 8.0f;
            CGFloat header = decoration.value;
            if (branded)
            {
                TGRichFillRounded(context, CGRectOffset(rect, 0.0f, 1.0f), radius, UIColorRGBA(0xffffff, 0.6f));
                TGRichFillGradientRounded(context, rect, radius, UIColorRGBA(0x000000, 0.08f), UIColorRGBA(0x000000, 0.04f));
                if (header > 0.0f)
                {
                    CGContextSaveGState(context);
                    CGContextBeginPath(context);
                    OGPlatformAddRoundedRectPath(context, rect, radius);
                    CGContextClip(context);
                    OGPlatformDrawVerticalGradient(context, CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, header), UIColorRGBA(0xffffff, 0.45f), UIColorRGBA(0xffffff, 0.12f));
                    TGRichFillLine(context, CGRectMake(rect.origin.x, rect.origin.y + header - pixel, rect.size.width, pixel), UIColorRGBA(0x000000, 0.16f));
                    TGRichFillLine(context, CGRectMake(rect.origin.x, rect.origin.y + header, rect.size.width, pixel), UIColorRGBA(0xffffff, 0.55f));
                    CGContextRestoreGState(context);
                }
                TGRichInnerShadow(context, rect, radius, UIColorRGBA(0x000000, 0.3f), [self highlightOffset], 2.5f);
                TGRichStrokeRounded(context, rect, radius, UIColorRGBA(0x000000, 0.12f), pixel);
            }
            else
            {
                TGRichFillRounded(context, rect, radius, [textColor colorWithAlphaComponent:0.06f]);
                if (header > 0.0f)
                {
                    CGContextSaveGState(context);
                    CGContextBeginPath(context);
                    OGPlatformAddRoundedRectPath(context, rect, radius);
                    CGContextClip(context);
                    TGRichFillLine(context, CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, header), [textColor colorWithAlphaComponent:0.05f]);
                    TGRichFillLine(context, CGRectMake(rect.origin.x, rect.origin.y + header - pixel, rect.size.width, pixel), [textColor colorWithAlphaComponent:0.1f]);
                    CGContextRestoreGState(context);
                }
            }
            break;
        }
        case TGRichDecorationCopyIcon:
        {
            CGFloat side = MIN(rect.size.width, rect.size.height) * 0.62f;
            CGRect back = CGRectMake(rect.origin.x + rect.size.width * 0.12f, rect.origin.y + rect.size.height * 0.12f, side, side);
            CGRect front = CGRectOffset(back, rect.size.width * 0.26f, rect.size.height * 0.26f);
            UIColor *color = decoration.flags & TGRichDecorationFlagChecked ? accentColor : secondaryColor;
            if (decoration.flags & TGRichDecorationFlagChecked)
            {
                TGRichDrawCheckmark(context, rect, color, 1.6f);
                break;
            }
            if (branded)
            {
                TGRichStrokeRounded(context, CGRectOffset(back, 0.0f, 1.0f), 2.0f, UIColorRGBA(0xffffff, 0.7f), 1.2f);
                TGRichStrokeRounded(context, CGRectOffset(front, 0.0f, 1.0f), 2.0f, UIColorRGBA(0xffffff, 0.7f), 1.2f);
            }
            TGRichStrokeRounded(context, back, 2.0f, color, 1.2f);
            TGRichFillRounded(context, front, 2.0f, branded ? UIColorRGBA(0xf2f3f5, 1.0f) : nil);
            TGRichStrokeRounded(context, front, 2.0f, color, 1.2f);
            break;
        }
        case TGRichDecorationDivider:
        case TGRichDecorationSeparator:
        case TGRichDecorationTableLine:
        {
            bool vertical = (decoration.flags & TGRichDecorationFlagVertical) != 0;
            CGRect line = vertical ? CGRectMake(rect.origin.x, rect.origin.y, pixel, rect.size.height) : CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, pixel);
            if (branded)
            {
                TGRichFillLine(context, line, UIColorRGBA(0x000000, decoration.kind == TGRichDecorationDivider ? 0.18f : 0.13f));
                TGRichFillLine(context, vertical ? CGRectOffset(line, pixel, 0.0f) : CGRectOffset(line, 0.0f, pixel), UIColorRGBA(0xffffff, 0.65f));
            }
            else
                TGRichFillLine(context, line, [textColor colorWithAlphaComponent:decoration.kind == TGRichDecorationDivider ? 0.22f : 0.14f]);
            break;
        }
        case TGRichDecorationBullet:
        {
            if (branded)
            {
                CGContextSetFillColorWithColor(context, UIColorRGBA(0xffffff, 0.7f).CGColor);
                CGContextFillEllipseInRect(context, CGRectOffset(rect, 0.0f, [self highlightOffset] * 0.5f));
            }
            CGContextSetFillColorWithColor(context, [textColor colorWithAlphaComponent:0.85f].CGColor);
            CGContextFillEllipseInRect(context, rect);
            break;
        }
        case TGRichDecorationCheckbox:
        {
            bool checked = (decoration.flags & TGRichDecorationFlagChecked) != 0;
            CGFloat radius = rect.size.width * 0.24f;
            if (branded)
            {
                TGRichFillRounded(context, CGRectOffset(rect, 0.0f, 1.0f), radius, UIColorRGBA(0xffffff, 0.7f));
                if (checked)
                {
                    TGRichFillGradientRounded(context, rect, radius, TGRichAdjustedColor(accentColor, 0.3f), TGRichAdjustedColor(accentColor, -0.18f));
                    TGRichStrokeRounded(context, rect, radius, TGRichAdjustedColor(accentColor, -0.4f), 1.0f);
                    CGContextSaveGState(context);
                    CGContextSetShadowWithColor(context, CGSizeMake(0.0f, -[self highlightOffset]), 0.0f, UIColorRGBA(0x000000, 0.35f).CGColor);
                    TGRichDrawCheckmark(context, rect, [UIColor whiteColor], 2.0f);
                    CGContextRestoreGState(context);
                }
                else
                {
                    TGRichFillGradientRounded(context, rect, radius, UIColorRGB(0xffffff), UIColorRGB(0xdfe3e8));
                    TGRichInnerShadow(context, rect, radius, UIColorRGBA(0x000000, 0.2f), [self highlightOffset], 1.5f);
                    TGRichStrokeRounded(context, rect, radius, UIColorRGBA(0x000000, 0.35f), 1.0f);
                }
            }
            else
            {
                if (checked)
                {
                    TGRichFillRounded(context, rect, radius, accentColor);
                    TGRichDrawCheckmark(context, rect, [UIColor whiteColor], 1.8f);
                }
                else
                    TGRichStrokeRounded(context, rect, radius, [secondaryColor colorWithAlphaComponent:0.8f], 1.5f);
            }
            break;
        }
        case TGRichDecorationChevron:
        {
            bool expanded = (decoration.flags & TGRichDecorationFlagExpanded) != 0;
            CGFloat midX = CGRectGetMidX(rect);
            CGFloat halfWidth = rect.size.width / 2.0f;
            CGFloat top = rect.origin.y + rect.size.height * 0.25f;
            CGFloat bottom = rect.origin.y + rect.size.height * 0.75f;
            void (^drawChevron)(CGFloat, UIColor *) = ^(CGFloat dy, UIColor *color)
            {
                CGContextSetStrokeColorWithColor(context, color.CGColor);
                CGContextSetLineWidth(context, 1.6f);
                CGContextSetLineCap(context, kCGLineCapRound);
                CGContextSetLineJoin(context, kCGLineJoinRound);
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, midX - halfWidth, (expanded ? bottom : top) + dy);
                CGContextAddLineToPoint(context, midX, (expanded ? top : bottom) + dy);
                CGContextAddLineToPoint(context, midX + halfWidth, (expanded ? bottom : top) + dy);
                CGContextStrokePath(context);
            };
            if (branded)
                drawChevron([self highlightOffset], UIColorRGBA(0xffffff, 0.75f));
            drawChevron(0.0f, secondaryColor);
            break;
        }
        case TGRichDecorationDetailsHeader:
        {
            CGFloat radius = 7.0f;
            if (branded)
            {
                TGRichFillRounded(context, CGRectOffset(rect, 0.0f, 1.0f), radius, UIColorRGBA(0xffffff, 0.55f));
                TGRichFillGradientRounded(context, rect, radius, UIColorRGBA(0xffffff, 0.75f), UIColorRGBA(0xffffff, 0.2f));
                TGRichFillGradientRounded(context, CGRectMake(rect.origin.x, rect.origin.y + rect.size.height / 2.0f, rect.size.width, rect.size.height / 2.0f), 0.0f, UIColorRGBA(0x000000, 0.0f), UIColorRGBA(0x000000, 0.05f));
                TGRichStrokeRounded(context, rect, radius, UIColorRGBA(0x000000, 0.18f), 1.0f);
            }
            else
                TGRichFillRounded(context, rect, radius, [textColor colorWithAlphaComponent:0.05f]);
            break;
        }
        case TGRichDecorationTableCell:
        {
            if (decoration.flags & TGRichDecorationFlagHeader)
            {
                if (branded)
                {
                    OGPlatformDrawVerticalGradient(context, rect, UIColorRGBA(0xffffff, 0.7f), UIColorRGBA(0x000000, 0.06f));
                }
                else
                    TGRichFillLine(context, rect, [textColor colorWithAlphaComponent:0.07f]);
            }
            else if (decoration.flags & TGRichDecorationFlagStripe)
                TGRichFillLine(context, rect, branded ? UIColorRGBA(0xffffff, 0.35f) : [textColor colorWithAlphaComponent:0.03f]);
            break;
        }
        case TGRichDecorationTableBorder:
        {
            CGFloat radius = branded ? 6.0f : 7.0f;
            if (branded)
            {
                TGRichStrokeRounded(context, CGRectOffset(rect, 0.0f, 1.0f), radius, UIColorRGBA(0xffffff, 0.6f), 1.0f);
                TGRichStrokeRounded(context, rect, radius, UIColorRGBA(0x000000, 0.2f), 1.0f);
            }
            else
                TGRichStrokeRounded(context, rect, radius, [textColor colorWithAlphaComponent:0.14f], 1.0f);
            break;
        }
        case TGRichDecorationMediaFrame:
        {
            CGFloat radius = decoration.value;
            if (branded)
            {
                TGRichFillRounded(context, CGRectOffset(CGRectInset(rect, -1.0f, -1.0f), 0.0f, 1.0f), radius + 1.0f, UIColorRGBA(0xffffff, 0.7f));
                TGRichFillRounded(context, CGRectInset(rect, -1.0f, -1.0f), radius + 1.0f, UIColorRGBA(0x000000, 0.22f));
                TGRichFillRounded(context, rect, radius, UIColorRGBA(0xd8dce2, 1.0f));
            }
            else
                TGRichFillRounded(context, rect, radius, [textColor colorWithAlphaComponent:0.08f]);
            break;
        }
        case TGRichDecorationMediaSpoiler:
        {
            CGFloat radius = decoration.value;
            TGRichFillRounded(context, rect, radius, branded ? UIColorRGB(0x8a94a3) : [textColor colorWithAlphaComponent:0.5f]);
            CGContextSaveGState(context);
            CGContextBeginPath(context);
            OGPlatformAddRoundedRectPath(context, rect, radius);
            CGContextClip(context);
            TGRichDrawDust(context, rect, [UIColor whiteColor]);
            CGContextRestoreGState(context);
            NSString *title = decoration.object;
            if ([title isKindOfClass:[NSString class]] && title.length != 0)
            {
                UIFont *font = [UIFont boldSystemFontOfSize:14.0f];
                CGSize size = [title sizeWithFont:font];
                CGRect pill = CGRectMake(CGFloor(CGRectGetMidX(rect) - size.width / 2.0f - 10.0f), CGFloor(CGRectGetMidY(rect) - size.height / 2.0f - 4.0f), CGCeil(size.width + 20.0f), CGCeil(size.height + 8.0f));
                TGRichFillRounded(context, pill, pill.size.height / 2.0f, UIColorRGBA(0x000000, 0.45f));
                UIGraphicsPushContext(context);
                [[UIColor whiteColor] set];
                [title drawAtPoint:CGPointMake(pill.origin.x + 10.0f, pill.origin.y + 4.0f) withFont:font];
                UIGraphicsPopContext();
            }
            break;
        }
        case TGRichDecorationAudioButton:
        {
            bool playing = (decoration.flags & TGRichDecorationFlagChecked) != 0;
            if (branded)
            {
                CGContextSetFillColorWithColor(context, UIColorRGBA(0xffffff, 0.7f).CGColor);
                CGContextFillEllipseInRect(context, CGRectOffset(rect, 0.0f, 1.0f));
                CGContextSaveGState(context);
                CGContextBeginPath(context);
                CGContextAddEllipseInRect(context, rect);
                CGContextClip(context);
                OGPlatformDrawVerticalGradient(context, rect, TGRichAdjustedColor(accentColor, 0.35f), TGRichAdjustedColor(accentColor, -0.2f));
                OGPlatformDrawVerticalGradient(context, CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height / 2.0f), UIColorRGBA(0xffffff, 0.35f), UIColorRGBA(0xffffff, 0.05f));
                CGContextRestoreGState(context);
                CGContextSetStrokeColorWithColor(context, TGRichAdjustedColor(accentColor, -0.45f).CGColor);
                CGContextSetLineWidth(context, 1.0f);
                CGContextStrokeEllipseInRect(context, CGRectInset(rect, 0.5f, 0.5f));
            }
            else
            {
                CGContextSetFillColorWithColor(context, accentColor.CGColor);
                CGContextFillEllipseInRect(context, rect);
            }
            CGContextSaveGState(context);
            if (branded)
                CGContextSetShadowWithColor(context, CGSizeMake(0.0f, -[self highlightOffset]), 0.0f, UIColorRGBA(0x000000, 0.35f).CGColor);
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
            CGFloat side = rect.size.width * 0.34f;
            CGFloat midX = CGRectGetMidX(rect);
            CGFloat midY = CGRectGetMidY(rect);
            if (playing)
            {
                CGContextFillRect(context, CGRectMake(midX - side * 0.55f, midY - side * 0.6f, side * 0.36f, side * 1.2f));
                CGContextFillRect(context, CGRectMake(midX + side * 0.19f, midY - side * 0.6f, side * 0.36f, side * 1.2f));
            }
            else
            {
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, midX - side * 0.4f, midY - side * 0.62f);
                CGContextAddLineToPoint(context, midX + side * 0.65f, midY);
                CGContextAddLineToPoint(context, midX - side * 0.4f, midY + side * 0.62f);
                CGContextClosePath(context);
                CGContextFillPath(context);
            }
            CGContextRestoreGState(context);
            break;
        }
        case TGRichDecorationFileIcon:
        {
            CGFloat radius = 6.0f;
            if (branded)
            {
                TGRichFillRounded(context, CGRectOffset(rect, 0.0f, 1.0f), radius, UIColorRGBA(0xffffff, 0.7f));
                TGRichFillGradientRounded(context, rect, radius, TGRichAdjustedColor(accentColor, 0.3f), TGRichAdjustedColor(accentColor, -0.2f));
                TGRichStrokeRounded(context, rect, radius, TGRichAdjustedColor(accentColor, -0.45f), 1.0f);
            }
            else
                TGRichFillRounded(context, rect, radius, accentColor);
            CGFloat fold = rect.size.width * 0.28f;
            CGContextSetFillColorWithColor(context, UIColorRGBA(0xffffff, 0.35f).CGColor);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, CGRectGetMaxX(rect) - fold, rect.origin.y);
            CGContextAddLineToPoint(context, CGRectGetMaxX(rect), rect.origin.y + fold);
            CGContextAddLineToPoint(context, CGRectGetMaxX(rect) - fold, rect.origin.y + fold);
            CGContextClosePath(context);
            CGContextFillPath(context);
            NSString *extension = decoration.object;
            if ([extension isKindOfClass:[NSString class]] && extension.length != 0)
            {
                UIFont *font = [UIFont boldSystemFontOfSize:extension.length > 3 ? 10.0f : 12.0f];
                CGSize size = [extension sizeWithFont:font];
                UIGraphicsPushContext(context);
                [[UIColor whiteColor] set];
                [extension drawAtPoint:CGPointMake(CGFloor(CGRectGetMidX(rect) - size.width / 2.0f), CGFloor(CGRectGetMidY(rect) - size.height / 2.0f + 3.0f)) withFont:font];
                UIGraphicsPopContext();
            }
            break;
        }
        case TGRichDecorationButton:
        {
            int32_t style = (int32_t)decoration.value;
            UIColor *fill = nil;
            if (style & (1 << 1))
                fill = UIColorRGB(0xe5484d);
            else if (style & (1 << 2))
                fill = UIColorRGB(0x34a853);
            else if (style & (1 << 0))
                fill = accentColor;
            if (style & (1 << 3))
                break;
            CGFloat radius = branded ? 8.0f : 10.0f;
            if (branded)
            {
                TGRichFillRounded(context, CGRectOffset(rect, 0.0f, 1.0f), radius, UIColorRGBA(0xffffff, 0.6f));
                if (fill != nil)
                {
                    TGRichFillGradientRounded(context, rect, radius, TGRichAdjustedColor(fill, 0.3f), TGRichAdjustedColor(fill, -0.15f));
                    TGRichFillGradientRounded(context, CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, CGFloor(rect.size.height / 2.0f)), radius, UIColorRGBA(0xffffff, 0.3f), UIColorRGBA(0xffffff, 0.08f));
                    TGRichStrokeRounded(context, rect, radius, TGRichAdjustedColor(fill, -0.45f), 1.0f);
                }
                else
                {
                    TGRichFillGradientRounded(context, rect, radius, UIColorRGB(0xfdfdfe), UIColorRGB(0xdde2e8));
                    TGRichFillLine(context, CGRectMake(rect.origin.x + radius, rect.origin.y + 1.0f, rect.size.width - radius * 2.0f, pixel), UIColorRGBA(0xffffff, 0.9f));
                    TGRichStrokeRounded(context, rect, radius, UIColorRGBA(0x000000, 0.25f), 1.0f);
                }
            }
            else
                TGRichFillRounded(context, rect, radius, fill ?: [accentColor colorWithAlphaComponent:0.12f]);
            break;
        }
        case TGRichDecorationMath:
        {
            TGRichMessageMathLayout *layout = decoration.object;
            if (![layout isKindOfClass:[TGRichMessageMathLayout class]])
                break;
            if (branded && _theme.shadowColor != nil)
                CGContextSetShadowWithColor(context, _theme.shadowOffset, 0.0f, _theme.shadowColor.CGColor);
            [layout drawInContext:context baselineOrigin:CGPointMake(rect.origin.x, rect.origin.y + layout.ascent) color:textColor];
            break;
        }
        case TGRichDecorationPullquote:
        {
            UIFont *font = [UIFont fontWithName:@"Georgia-Bold" size:34.0f] ?: [UIFont boldSystemFontOfSize:34.0f];
            UIGraphicsPushContext(context);
            [[accentColor colorWithAlphaComponent:0.35f] set];
            [@"“" drawAtPoint:CGPointMake(rect.origin.x, rect.origin.y - 8.0f) withFont:font];
            CGSize closing = [@"”" sizeWithFont:font];
            [@"”" drawAtPoint:CGPointMake(CGRectGetMaxX(rect) - closing.width, CGRectGetMaxY(rect) - closing.height + 14.0f) withFont:font];
            UIGraphicsPopContext();
            break;
        }
        case TGRichDecorationCard:
        {
            CGFloat radius = branded ? 6.0f : 8.0f;
            if (branded)
            {
                TGRichFillRounded(context, CGRectOffset(rect, 0.0f, 1.0f), radius, UIColorRGBA(0xffffff, 0.6f));
                TGRichFillGradientRounded(context, rect, radius, UIColorRGBA(0xffffff, 0.55f), UIColorRGBA(0xffffff, 0.15f));
                TGRichStrokeRounded(context, rect, radius, UIColorRGBA(0x000000, 0.16f), 1.0f);
            }
            else
            {
                TGRichFillRounded(context, rect, radius, [textColor colorWithAlphaComponent:0.04f]);
                TGRichStrokeRounded(context, rect, radius, [textColor colorWithAlphaComponent:0.12f], 1.0f);
            }
            break;
        }
    }
}

@end
