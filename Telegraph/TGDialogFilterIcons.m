#import "TGDialogFilterIcons.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGDialogFilter.h"

static const CGFloat TGDialogFilterGlyphSide = 24.0f;

static void TGDialogFilterAddRoundedRect(CGContextRef context, CGRect rect, CGFloat radius)
{
    radius = MIN(radius, MIN(rect.size.width, rect.size.height) / 2.0f);
    CGFloat minX = CGRectGetMinX(rect);
    CGFloat minY = CGRectGetMinY(rect);
    CGFloat maxX = CGRectGetMaxX(rect);
    CGFloat maxY = CGRectGetMaxY(rect);
    CGContextMoveToPoint(context, minX + radius, minY);
    CGContextAddArcToPoint(context, maxX, minY, maxX, maxY, radius);
    CGContextAddArcToPoint(context, maxX, maxY, minX, maxY, radius);
    CGContextAddArcToPoint(context, minX, maxY, minX, minY, radius);
    CGContextAddArcToPoint(context, minX, minY, maxX, minY, radius);
    CGContextClosePath(context);
}

static void TGDialogFilterDrawPerson(CGContextRef context, CGFloat centerX, CGFloat top, CGFloat scale)
{
    CGFloat headRadius = 4.2f * scale;
    CGContextFillEllipseInRect(context, CGRectMake(centerX - headRadius, top, headRadius * 2.0f, headRadius * 2.0f));
    CGFloat bodyTop = top + headRadius * 2.0f + 1.4f * scale;
    CGFloat bodyWidth = 13.0f * scale;
    CGFloat bodyHeight = 6.6f * scale;
    CGContextSaveGState(context);
    CGContextClipToRect(context, CGRectMake(centerX - bodyWidth / 2.0f, bodyTop, bodyWidth, bodyHeight));
    CGContextFillEllipseInRect(context, CGRectMake(centerX - bodyWidth / 2.0f, bodyTop, bodyWidth, bodyHeight * 2.0f));
    CGContextRestoreGState(context);
}

static void TGDialogFilterDrawFolder(CGContextRef context)
{
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 3.0f, 7.0f);
    CGContextAddLineToPoint(context, 3.0f, 5.5f);
    CGContextAddArcToPoint(context, 3.0f, 4.0f, 4.5f, 4.0f, 1.5f);
    CGContextAddLineToPoint(context, 9.0f, 4.0f);
    CGContextAddLineToPoint(context, 11.0f, 6.0f);
    CGContextAddLineToPoint(context, 19.5f, 6.0f);
    CGContextAddArcToPoint(context, 21.0f, 6.0f, 21.0f, 7.5f, 1.5f);
    CGContextAddLineToPoint(context, 21.0f, 7.0f);
    CGContextClosePath(context);
    CGContextFillPath(context);
    CGContextBeginPath(context);
    TGDialogFilterAddRoundedRect(context, CGRectMake(3.0f, 8.0f, 18.0f, 12.0f), 2.0f);
    CGContextFillPath(context);
}

static void TGDialogFilterDrawGlyph(CGContextRef context, int32_t category)
{
    switch (category)
    {
        case TGDialogFilterIncludeContacts:
            TGDialogFilterDrawPerson(context, 12.0f, 4.0f, 1.0f);
            break;
        case TGDialogFilterIncludeNonContacts:
        {
            TGDialogFilterDrawPerson(context, 10.0f, 4.5f, 0.92f);
            CGContextSetLineWidth(context, 1.8f);
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, 17.0f, 6.5f);
            CGContextAddLineToPoint(context, 21.0f, 10.5f);
            CGContextMoveToPoint(context, 21.0f, 6.5f);
            CGContextAddLineToPoint(context, 17.0f, 10.5f);
            CGContextStrokePath(context);
            break;
        }
        case TGDialogFilterIncludeGroups:
        {
            CGContextSaveGState(context);
            CGContextSetAlpha(context, 0.75f);
            TGDialogFilterDrawPerson(context, 16.0f, 5.0f, 0.78f);
            CGContextRestoreGState(context);
            TGDialogFilterDrawPerson(context, 9.5f, 4.5f, 0.92f);
            break;
        }
        case TGDialogFilterIncludeChannels:
        {
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, 4.0f, 9.5f);
            CGContextAddLineToPoint(context, 9.0f, 9.5f);
            CGContextAddLineToPoint(context, 18.0f, 5.0f);
            CGContextAddLineToPoint(context, 18.0f, 19.0f);
            CGContextAddLineToPoint(context, 9.0f, 14.5f);
            CGContextAddLineToPoint(context, 4.0f, 14.5f);
            CGContextClosePath(context);
            CGContextFillPath(context);
            CGContextFillRect(context, CGRectMake(6.5f, 14.0f, 2.8f, 5.5f));
            CGContextSetLineWidth(context, 1.8f);
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, 20.5f, 10.0f);
            CGContextAddLineToPoint(context, 20.5f, 14.0f);
            CGContextStrokePath(context);
            break;
        }
        case TGDialogFilterIncludeBots:
        {
            CGContextFillRect(context, CGRectMake(11.1f, 3.5f, 1.8f, 3.0f));
            CGContextFillEllipseInRect(context, CGRectMake(10.25f, 2.0f, 3.5f, 3.5f));
            CGContextBeginPath(context);
            TGDialogFilterAddRoundedRect(context, CGRectMake(4.0f, 6.5f, 16.0f, 12.5f), 4.0f);
            CGContextFillPath(context);
            CGContextSetBlendMode(context, kCGBlendModeClear);
            CGContextFillEllipseInRect(context, CGRectMake(7.5f, 10.0f, 3.2f, 3.2f));
            CGContextFillEllipseInRect(context, CGRectMake(13.3f, 10.0f, 3.2f, 3.2f));
            CGContextFillRect(context, CGRectMake(9.0f, 15.0f, 6.0f, 1.4f));
            CGContextSetBlendMode(context, kCGBlendModeNormal);
            break;
        }
        case TGDialogFilterExcludeMuted:
        {
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, 12.0f, 3.5f);
            CGContextAddCurveToPoint(context, 8.0f, 3.5f, 6.5f, 6.5f, 6.5f, 10.0f);
            CGContextAddLineToPoint(context, 6.5f, 14.0f);
            CGContextAddLineToPoint(context, 4.5f, 17.0f);
            CGContextAddLineToPoint(context, 19.5f, 17.0f);
            CGContextAddLineToPoint(context, 17.5f, 14.0f);
            CGContextAddLineToPoint(context, 17.5f, 10.0f);
            CGContextAddCurveToPoint(context, 17.5f, 6.5f, 16.0f, 3.5f, 12.0f, 3.5f);
            CGContextClosePath(context);
            CGContextFillPath(context);
            CGContextFillEllipseInRect(context, CGRectMake(10.0f, 17.5f, 4.0f, 3.0f));
            CGContextSetBlendMode(context, kCGBlendModeClear);
            CGContextSetLineWidth(context, 4.2f);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, 4.0f, 4.0f);
            CGContextAddLineToPoint(context, 20.0f, 20.0f);
            CGContextStrokePath(context);
            CGContextSetBlendMode(context, kCGBlendModeNormal);
            CGContextSetLineWidth(context, 1.8f);
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, 4.5f, 4.5f);
            CGContextAddLineToPoint(context, 19.5f, 19.5f);
            CGContextStrokePath(context);
            break;
        }
        case TGDialogFilterExcludeRead:
        {
            CGContextSetLineWidth(context, 2.4f);
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextSetLineJoin(context, kCGLineJoinRound);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, 4.5f, 12.5f);
            CGContextAddLineToPoint(context, 9.5f, 17.5f);
            CGContextAddLineToPoint(context, 19.5f, 6.5f);
            CGContextStrokePath(context);
            break;
        }
        case TGDialogFilterExcludeArchived:
        {
            CGContextBeginPath(context);
            TGDialogFilterAddRoundedRect(context, CGRectMake(3.0f, 4.0f, 18.0f, 4.5f), 1.2f);
            CGContextFillPath(context);
            CGContextBeginPath(context);
            TGDialogFilterAddRoundedRect(context, CGRectMake(4.5f, 9.5f, 15.0f, 10.5f), 1.6f);
            CGContextFillPath(context);
            CGContextSetBlendMode(context, kCGBlendModeClear);
            CGContextBeginPath(context);
            TGDialogFilterAddRoundedRect(context, CGRectMake(9.0f, 11.5f, 6.0f, 2.0f), 1.0f);
            CGContextFillPath(context);
            CGContextSetBlendMode(context, kCGBlendModeNormal);
            break;
        }
        default:
            TGDialogFilterDrawFolder(context);
            break;
    }
}

static UIColor *TGDialogFilterCategoryColor(int32_t category)
{
    switch (category)
    {
        case TGDialogFilterIncludeContacts:
            return UIColorRGB(0x2f8cf0);
        case TGDialogFilterIncludeNonContacts:
            return UIColorRGB(0xf0a030);
        case TGDialogFilterIncludeGroups:
            return UIColorRGB(0x4cc85b);
        case TGDialogFilterIncludeChannels:
            return UIColorRGB(0x5ab0f0);
        case TGDialogFilterIncludeBots:
            return UIColorRGB(0x9a6ee0);
        case TGDialogFilterExcludeMuted:
            return UIColorRGB(0xf05050);
        case TGDialogFilterExcludeRead:
            return UIColorRGB(0x3dc1a5);
        case TGDialogFilterExcludeArchived:
            return UIColorRGB(0x8aa0b4);
        default:
            return UIColorRGB(0x2f8cf0);
    }
}

static UIImage *TGDialogFilterGlyphImage(int32_t category, UIColor *backgroundColor, CGFloat side, CGFloat glyphSide, bool circle, CGFloat cornerRadius)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
    if (circle)
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, side, side));
    else
    {
        CGContextBeginPath(context);
        TGDialogFilterAddRoundedRect(context, CGRectMake(0.0f, 0.0f, side, side), cornerRadius);
        CGContextFillPath(context);
    }
    CGContextTranslateCTM(context, (side - glyphSide) / 2.0f, (side - glyphSide) / 2.0f);
    CGContextScaleCTM(context, glyphSide / TGDialogFilterGlyphSide, glyphSide / TGDialogFilterGlyphSide);
    CGContextBeginTransparencyLayer(context, NULL);
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    TGDialogFilterDrawGlyph(context, category);
    CGContextEndTransparencyLayer(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

UIImage *TGDialogFilterCategoryIcon(int32_t category)
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });
    NSNumber *key = @(category);
    UIImage *image = nil;
    @synchronized(cache)
    {
        image = cache[key];
    }
    if (image != nil)
        return image;
    image = TGDialogFilterGlyphImage(category, TGDialogFilterCategoryColor(category), 30.0f, 20.0f, true, 0.0f);
    if (image != nil)
    {
        @synchronized(cache)
        {
            cache[key] = image;
        }
    }
    return image;
}

UIImage *TGDialogFilterSettingsIcon(void)
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = TGDialogFilterGlyphImage(0, UIColorRGB(0x2f8cf0), 29.0f, 19.0f, false, 6.5f);
    });
    return image;
}

UIImage *TGDialogFilterFolderIcon(UIColor *color, CGFloat side)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, side / TGDialogFilterGlyphSide, side / TGDialogFilterGlyphSide);
    CGContextSetFillColorWithColor(context, color.CGColor);
    TGDialogFilterDrawFolder(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

UIImage *TGDialogFilterEmoticonIcon(NSString *emoticon, CGFloat side)
{
    if (emoticon.length == 0)
        return nil;
    UIFont *font = [UIFont systemFontOfSize:CGFloor(side * 0.78f)];
    CGSize size = [emoticon sizeWithFont:font];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), false, 0.0f);
    [emoticon drawAtPoint:CGPointMake(CGFloor((side - size.width) / 2.0f), CGFloor((side - size.height) / 2.0f)) withFont:font];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

UIImage *TGDialogFilterColorDotImage(UIColor *color, CGFloat side, bool selected, UIColor *ringColor)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    if (selected)
    {
        CGContextSetStrokeColorWithColor(context, color.CGColor);
        CGContextSetLineWidth(context, 2.0f);
        CGContextStrokeEllipseInRect(context, CGRectMake(1.0f, 1.0f, side - 2.0f, side - 2.0f));
        CGContextFillEllipseInRect(context, CGRectMake(5.0f, 5.0f, side - 10.0f, side - 10.0f));
    }
    else
        CGContextFillEllipseInRect(context, CGRectMake(3.0f, 3.0f, side - 6.0f, side - 6.0f));
    if (selected && ringColor != nil)
    {
        CGContextSetStrokeColorWithColor(context, ringColor.CGColor);
        CGContextSetLineWidth(context, 1.0f);
        CGContextStrokeEllipseInRect(context, CGRectMake(3.5f, 3.5f, side - 7.0f, side - 7.0f));
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

UIImage *TGDialogFilterNoColorImage(UIColor *strokeColor, CGFloat side, bool selected, UIColor *ringColor)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, strokeColor.CGColor);
    CGContextSetLineWidth(context, 1.5f);
    CGRect circle = selected ? CGRectMake(5.0f, 5.0f, side - 10.0f, side - 10.0f) : CGRectMake(3.75f, 3.75f, side - 7.5f, side - 7.5f);
    CGContextStrokeEllipseInRect(context, circle);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, CGRectGetMinX(circle) + circle.size.width * 0.15f, CGRectGetMaxY(circle) - circle.size.height * 0.15f);
    CGContextAddLineToPoint(context, CGRectGetMaxX(circle) - circle.size.width * 0.15f, CGRectGetMinY(circle) + circle.size.height * 0.15f);
    CGContextStrokePath(context);
    if (selected)
    {
        CGContextSetStrokeColorWithColor(context, (ringColor ?: strokeColor).CGColor);
        CGContextSetLineWidth(context, 2.0f);
        CGContextStrokeEllipseInRect(context, CGRectMake(1.0f, 1.0f, side - 2.0f, side - 2.0f));
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

CGSize TGDialogFilterTagSize(NSString *title, UIFont *font)
{
    if (title.length == 0 || font == nil)
        return CGSizeZero;
    CGSize textSize = [title sizeWithFont:font];
    return CGSizeMake(CGCeil(textSize.width) + 10.0f, CGCeil(textSize.height) + 2.0f);
}

void TGDialogFilterDrawTag(NSString *title, UIColor *color, UIFont *font, CGRect rect)
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL || title.length == 0 || color == nil)
        return;
    CGContextSaveGState(context);
    CGContextSetFillColorWithColor(context, [color colorWithAlphaComponent:0.16f].CGColor);
    CGContextBeginPath(context);
    TGDialogFilterAddRoundedRect(context, rect, MIN(5.0f, rect.size.height / 2.0f));
    CGContextFillPath(context);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGSize textSize = [title sizeWithFont:font];
    CGRect textRect = CGRectMake(rect.origin.x + 5.0f, rect.origin.y + CGFloor((rect.size.height - textSize.height) / 2.0f), rect.size.width - 10.0f, textSize.height);
    [title drawInRect:textRect withFont:font lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentLeft];
    CGContextRestoreGState(context);
}
