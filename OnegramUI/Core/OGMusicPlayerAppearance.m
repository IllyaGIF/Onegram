#import "OGMusicPlayerAppearance.h"
#import "OGSurfaceStyle.h"

@interface OGMusicPlayerAppearance ()
{
    BOOL _dark;
}
@end

@implementation OGMusicPlayerAppearance

+ (OGMusicPlayerAppearance *)brandedAppearanceDark:(BOOL)dark
{
    OGMusicPlayerAppearance *appearance = [[OGMusicPlayerAppearance alloc] init];
    appearance->_dark = dark;
    appearance.height = 44.0f;
    appearance.displayLeftInset = dark ? 26.0f : 25.0f;
    appearance.displayRightInset = dark ? 45.0f : 46.0f;
    appearance.displayTopInset = dark ? 7.0f : 8.0f;
    appearance.controlLeftInset = dark ? 5.0f : 4.0f;
    appearance.controlTopInset = dark ? 14.0f : 15.0f;
    appearance.closeRightInset = dark ? 5.0f : 6.0f;
    appearance.closeTopInset = dark ? 11.0f : 12.0f;
    appearance.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:12.0f] ?: [UIFont systemFontOfSize:12.0f];
    appearance.titleColor = [UIColor colorWithWhite:55.0f / 255.0f alpha:1.0f];
    appearance.timeColor = [UIColor colorWithWhite:96.0f / 255.0f alpha:1.0f];
    appearance.controlColor = dark ? [UIColor whiteColor] : appearance.timeColor;

    OGSurfaceStyle *background = [[OGSurfaceStyle alloc] init];
    background.shape = OGSurfaceShapeBand;
    background.textureResourceDirectory = @"ios6style";
    background.textureAssetName = dark ? @"alcantara.png" : @"metal2.jpg";
    background.textureReferenceWidth = dark ? 153.6f : 320.0f;
    background.textureTiled = dark;
    background.shadows = dark ? @[
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.2f] offset:CGSizeMake(0.0f, 0.5f) blur:0.5f]
    ] : @[
        [OGSurfaceShadow dropShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
    ];
    appearance.backgroundSurfaceStyle = background;

    OGSurfaceStyle *display = [[OGSurfaceStyle alloc] init];
    display.shape = OGSurfaceShapeRoundedRect;
    display.cornerRadius = 14.5f;
    display.fillColor = [UIColor colorWithRed:215.0f / 255.0f green:219.0f / 255.0f blue:192.0f / 255.0f alpha:1.0f];
    display.shadows = @[
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.25f] offset:CGSizeMake(0.0f, 4.0f) blur:4.0f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.7f] offset:CGSizeMake(0.0f, -2.0f) blur:0.5f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.3f] offset:CGSizeMake(0.0f, 2.0f) blur:0.5f]
    ];
    appearance.displaySurfaceStyle = display;
    return appearance;
}

+ (OGMusicPlayerAppearance *)conversationAppearanceDark:(BOOL)dark compact:(BOOL)compact
{
    static OGMusicPlayerAppearance *appearances[4];
    NSUInteger index = (dark ? 2 : 0) + (compact ? 1 : 0);
    @synchronized (self)
    {
        OGMusicPlayerAppearance *appearance = appearances[index];
        if (appearance != nil)
            return appearance;
        appearance = [self brandedAppearanceDark:NO];
        appearance.height = compact ? 21.0f : 44.0f;
        appearance.displayRightInset = 51.0f;
        appearance.closeRightInset = 0.0f;
        appearance.backgroundSurfaceStyle.shape = dark ? OGSurfaceShapeSheet : OGSurfaceShapeBand;
        appearance.backgroundSurfaceStyle.cornerRadius = dark ? 13.0f : 0.0f;
        if (compact)
        {
            appearance.font = [UIFont fontWithName:@"HelveticaNeue" size:10.0f] ?: [UIFont systemFontOfSize:10.0f];
            appearance.titleColor = [UIColor colorWithWhite:87.0f / 255.0f alpha:1.0f];
        }
        appearances[index] = appearance;
        return appearance;
    }
}

- (UIImage *)imageForGlyph:(OGMusicPlayerGlyph)glyph
{
    CGFloat side = glyph == OGMusicPlayerGlyphChevron ? 13.0f : (glyph == OGMusicPlayerGlyphClose ? 20.0f : 16.0f);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, glyph == OGMusicPlayerGlyphChevron ? 9.0f : side), NO, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIColor *color = glyph == OGMusicPlayerGlyphChevron ? [UIColor colorWithRed:119.0f / 255.0f green:116.0f / 255.0f blue:116.0f / 255.0f alpha:1.0f] : (glyph == OGMusicPlayerGlyphMusic ? _timeColor : _controlColor);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    if (glyph == OGMusicPlayerGlyphPlay || glyph == OGMusicPlayerGlyphPause)
    {
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 16.0f, 16.0f));
        CGContextSetBlendMode(context, kCGBlendModeClear);
        if (glyph == OGMusicPlayerGlyphPlay)
        {
            CGContextMoveToPoint(context, 6.0f, 4.5f);
            CGContextAddLineToPoint(context, 11.0f, 8.0f);
            CGContextAddLineToPoint(context, 6.0f, 11.5f);
            CGContextClosePath(context);
            CGContextFillPath(context);
        }
        else
        {
            CGContextFillRect(context, CGRectMake(5.0f, 4.5f, 2.0f, 7.0f));
            CGContextFillRect(context, CGRectMake(9.0f, 4.5f, 2.0f, 7.0f));
        }
    }
    else if (glyph == OGMusicPlayerGlyphClose)
    {
        CGContextSetLineWidth(context, 1.2f);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextMoveToPoint(context, 5.625f, 5.625f);
        CGContextAddLineToPoint(context, 14.375f, 14.375f);
        CGContextMoveToPoint(context, 14.375f, 5.625f);
        CGContextAddLineToPoint(context, 5.625f, 14.375f);
        CGContextStrokePath(context);
    }
    else if (glyph == OGMusicPlayerGlyphChevron)
    {
        CGContextSetLineWidth(context, 3.0f);
        CGContextSetLineJoin(context, kCGLineJoinMiter);
        CGContextMoveToPoint(context, 2.0f, 2.0f);
        CGContextAddLineToPoint(context, 6.5f, 6.5f);
        CGContextAddLineToPoint(context, 11.0f, 2.0f);
        CGContextStrokePath(context);
    }
    else
    {
        CGContextFillEllipseInRect(context, CGRectMake(1.0f, 11.0f, 5.0f, 4.0f));
        CGContextFillEllipseInRect(context, CGRectMake(10.0f, 9.0f, 5.0f, 4.0f));
        CGContextSetLineWidth(context, 1.0f);
        CGContextMoveToPoint(context, 5.5f, 2.0f);
        CGContextAddLineToPoint(context, 5.5f, 13.0f);
        CGContextMoveToPoint(context, 14.5f, 1.0f);
        CGContextAddLineToPoint(context, 14.5f, 11.0f);
        CGContextStrokePath(context);
        CGContextMoveToPoint(context, 5.0f, 2.0f);
        CGContextAddLineToPoint(context, 15.0f, 1.0f);
        CGContextAddLineToPoint(context, 15.0f, 4.0f);
        CGContextAddLineToPoint(context, 5.0f, 5.0f);
        CGContextClosePath(context);
        CGContextFillPath(context);
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (!_dark || glyph == OGMusicPlayerGlyphMusic)
    {
        CGFloat opacity = glyph == OGMusicPlayerGlyphChevron ? 0.25f : (glyph == OGMusicPlayerGlyphMusic ? 0.3f : 0.5f);
        CGRect rect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
        UIGraphicsBeginImageContextWithOptions(rect.size, NO, image.scale);
        CGContextRef inverseContext = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(inverseContext, [UIColor blackColor].CGColor);
        CGContextFillRect(inverseContext, rect);
        CGContextSetBlendMode(inverseContext, kCGBlendModeDestinationOut);
        [image drawAtPoint:CGPointZero];
        UIImage *inverse = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        UIGraphicsBeginImageContextWithOptions(rect.size, NO, image.scale);
        CGContextRef shadowContext = UIGraphicsGetCurrentContext();
        [image drawAtPoint:CGPointZero];
        CGContextTranslateCTM(shadowContext, 0.0f, rect.size.height);
        CGContextScaleCTM(shadowContext, 1.0f, -1.0f);
        CGContextClipToMask(shadowContext, rect, image.CGImage);
        CGContextScaleCTM(shadowContext, 1.0f, -1.0f);
        CGContextTranslateCTM(shadowContext, 0.0f, -rect.size.height);
        CGContextSetShadowWithColor(shadowContext, CGSizeMake(0.0f, glyph == OGMusicPlayerGlyphChevron ? 0.5f : 1.0f), 0.5f, [UIColor colorWithWhite:0.0f alpha:opacity].CGColor);
        [inverse drawAtPoint:CGPointZero];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return image;
}

@end
