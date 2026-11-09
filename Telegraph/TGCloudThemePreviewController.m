#import "TGCloudThemePreviewController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageUtils.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGWallpaperInfo.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGNavigationController.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGAppDelegate.h"
#import "TGCustomAlertView.h"
#import "TGPresentation.h"
#import "TGPresentationPallete.h"
#import "TGCloudTheme.h"

typedef enum {
    TGCloudThemePreviewPageChatList = 0,
    TGCloudThemePreviewPageChat = 1
} TGCloudThemePreviewPage;

static const CGFloat TGCloudThemePreviewNavigationHeight = 44.0f;
static const CGFloat TGCloudThemePreviewTabBarHeight = 49.0f;
static const CGFloat TGCloudThemePreviewInputHeight = 45.0f;

static void TGCloudThemePreviewFillRoundedRect(CGContextRef context, CGRect rect, CGFloat radius, UIColor *color)
{
    if (color == nil)
        return;
    radius = MIN(radius, MIN(rect.size.width, rect.size.height) / 2.0f);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, CGRectGetMinX(rect), CGRectGetMidY(rect));
    CGContextAddArcToPoint(context, CGRectGetMinX(rect), CGRectGetMinY(rect), CGRectGetMidX(rect), CGRectGetMinY(rect), radius);
    CGContextAddArcToPoint(context, CGRectGetMaxX(rect), CGRectGetMinY(rect), CGRectGetMaxX(rect), CGRectGetMidY(rect), radius);
    CGContextAddArcToPoint(context, CGRectGetMaxX(rect), CGRectGetMaxY(rect), CGRectGetMidX(rect), CGRectGetMaxY(rect), radius);
    CGContextAddArcToPoint(context, CGRectGetMinX(rect), CGRectGetMaxY(rect), CGRectGetMinX(rect), CGRectGetMidY(rect), radius);
    CGContextClosePath(context);
    CGContextFillPath(context);
}

static void TGCloudThemePreviewFillRect(CGContextRef context, CGRect rect, UIColor *color)
{
    if (color == nil)
        return;
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, rect);
}

static CGFloat TGCloudThemePreviewDrawText(CGContextRef context, NSString *text, CGRect rect, UIFont *font, UIColor *color, NSTextAlignment alignment, bool singleLine)
{
    if (text.length == 0 || color == nil)
        return 0.0f;
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGSize size = singleLine ? rect.size : [text sizeWithFont:font constrainedToSize:rect.size lineBreakMode:NSLineBreakByWordWrapping];
    CGRect drawRect = CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, MIN(rect.size.height, size.height));
    [text drawInRect:drawRect withFont:font lineBreakMode:singleLine ? NSLineBreakByTruncatingTail : NSLineBreakByWordWrapping alignment:alignment];
    return drawRect.size.height;
}

static void TGCloudThemePreviewStrokeChecks(CGContextRef context, CGPoint origin, UIColor *color, bool read)
{
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, 1.4f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    for (int i = 0; i < (read ? 2 : 1); i++)
    {
        CGFloat offset = (CGFloat)i * 4.0f;
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, origin.x + offset, origin.y + 4.0f);
        CGContextAddLineToPoint(context, origin.x + offset + 2.5f, origin.y + 6.5f);
        CGContextAddLineToPoint(context, origin.x + offset + 8.0f, origin.y);
        CGContextStrokePath(context);
    }
}

static UIColor *TGCloudThemePreviewAvatarColor(NSUInteger index)
{
    static const uint32_t colors[] = {0xe17076, 0x7bc862, 0x65aadd, 0xee7aae, 0xf2a35a};
    return UIColorRGB(colors[index % (sizeof(colors) / sizeof(colors[0]))]);
}

@interface TGCloudThemePreviewPageView : UIView
{
    TGCloudThemePreviewPage _page;
    TGPresentationPallete *_pallete;
    UIImage *_wallpaperImage;
}

- (instancetype)initWithPage:(TGCloudThemePreviewPage)page pallete:(TGPresentationPallete *)pallete wallpaperImage:(UIImage *)wallpaperImage;

@end

@implementation TGCloudThemePreviewPageView

- (instancetype)initWithPage:(TGCloudThemePreviewPage)page pallete:(TGPresentationPallete *)pallete wallpaperImage:(UIImage *)wallpaperImage
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _page = page;
        _pallete = pallete;
        _wallpaperImage = wallpaperImage;
        self.opaque = true;
        self.contentMode = UIViewContentModeRedraw;
        self.backgroundColor = pallete.backgroundColor;
    }
    return self;
}

- (void)drawRect:(CGRect)__unused rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (_page == TGCloudThemePreviewPageChatList)
        [self drawChatListInContext:context];
    else
        [self drawChatInContext:context];
}

- (void)drawNavigationBarInContext:(CGContextRef)context
{
    CGFloat width = self.bounds.size.width;
    TGCloudThemePreviewFillRect(context, CGRectMake(0.0f, 0.0f, width, TGCloudThemePreviewNavigationHeight), _pallete.barBackgroundColor);
    TGCloudThemePreviewFillRect(context, CGRectMake(0.0f, TGCloudThemePreviewNavigationHeight - TGScreenPixel, width, TGScreenPixel), _pallete.barSeparatorColor);
}

- (void)drawChatListInContext:(CGContextRef)context
{
    TGPresentationPallete *pallete = _pallete;
    CGSize size = self.bounds.size;
    TGCloudThemePreviewFillRect(context, self.bounds, pallete.backgroundColor);

    [self drawNavigationBarInContext:context];
    UIFont *titleFont = TGBoldSystemFontOfSize(17.0f);
    TGCloudThemePreviewDrawText(context, TGLocalized(@"DialogList.Title"), CGRectMake(60.0f, 11.0f, size.width - 120.0f, 22.0f), titleFont, pallete.navigationTitleColor, NSTextAlignmentCenter, true);
    TGCloudThemePreviewDrawText(context, TGLocalized(@"Common.Edit"), CGRectMake(10.0f, 11.0f, 70.0f, 22.0f), TGSystemFontOfSize(17.0f), pallete.navigationButtonColor, NSTextAlignmentLeft, true);
    CGContextSetStrokeColorWithColor(context, pallete.navigationButtonColor.CGColor);
    CGContextSetLineWidth(context, 1.5f);
    CGContextStrokeRect(context, CGRectMake(size.width - 31.0f, 13.0f, 17.0f, 17.0f));
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, size.width - 25.0f, 24.0f);
    CGContextAddLineToPoint(context, size.width - 11.0f, 10.0f);
    CGContextStrokePath(context);

    CGFloat y = TGCloudThemePreviewNavigationHeight;
    CGRect field = CGRectMake(8.0f, y + 8.0f, size.width - 16.0f, 28.0f);
    TGCloudThemePreviewFillRoundedRect(context, field, 10.0f, pallete.searchBarBackgroundColor);
    TGCloudThemePreviewDrawText(context, TGLocalized(@"Common.Search"), CGRectMake(field.origin.x, field.origin.y + 6.0f, field.size.width, 17.0f), TGSystemFontOfSize(14.0f), pallete.searchBarPlaceholderColor, NSTextAlignmentCenter, true);
    y += 44.0f;

    NSArray *names = @[TGLocalized(@"OnegramTheme.Sample.Name1"), TGLocalized(@"OnegramTheme.Sample.Name2"), TGLocalized(@"OnegramTheme.Sample.Name3"), TGLocalized(@"OnegramTheme.Sample.Name4"), TGLocalized(@"OnegramTheme.Sample.Name5")];
    NSArray *texts = @[TGLocalized(@"OnegramTheme.Sample.Text1"), TGLocalized(@"OnegramTheme.Sample.Text2"), TGLocalized(@"OnegramTheme.Sample.Text3"), TGLocalized(@"OnegramTheme.Sample.Text4"), TGLocalized(@"OnegramTheme.Sample.Text5")];
    NSArray *dates = @[@"21:42", @"20:10", @"18:03", @"17:55", @"12:30"];
    const CGFloat rowHeight = 76.0f;
    CGFloat contentBottom = size.height - TGCloudThemePreviewTabBarHeight;
    for (NSUInteger i = 0; i < names.count && y < contentBottom; i++)
    {
        CGRect row = CGRectMake(0.0f, y, size.width, rowHeight);
        TGCloudThemePreviewFillRect(context, row, i == 0 ? pallete.dialogPinnedBackgroundColor : pallete.backgroundColor);

        CGRect avatar = CGRectMake(10.0f, y + 8.0f, 60.0f, 60.0f);
        CGContextSetFillColorWithColor(context, TGCloudThemePreviewAvatarColor(i).CGColor);
        CGContextFillEllipseInRect(context, avatar);
        NSString *name = names[i];
        NSString *initial = name.length != 0 ? [[name substringToIndex:1] uppercaseString] : @"";
        TGCloudThemePreviewDrawText(context, initial, CGRectMake(avatar.origin.x, avatar.origin.y + 17.0f, avatar.size.width, 26.0f), TGBoldSystemFontOfSize(22.0f), [UIColor whiteColor], NSTextAlignmentCenter, true);

        CGFloat textX = 80.0f;
        CGFloat rightX = size.width - 10.0f;
        UIFont *dateFont = TGSystemFontOfSize(14.0f);
        NSString *date = dates[i];
        CGFloat dateWidth = [date sizeWithFont:dateFont].width;
        TGCloudThemePreviewDrawText(context, date, CGRectMake(rightX - dateWidth, y + 10.0f, dateWidth, 18.0f), dateFont, pallete.dialogDateColor, NSTextAlignmentRight, true);
        CGFloat nameRight = rightX - dateWidth - 6.0f;
        if (i == 1)
        {
            TGCloudThemePreviewStrokeChecks(context, CGPointMake(nameRight - 13.0f, y + 15.0f), pallete.dialogChecksColor, true);
            nameRight -= 18.0f;
        }
        UIColor *titleColor = i == 4 ? pallete.dialogEncryptedColor : pallete.dialogTitleColor;
        TGCloudThemePreviewDrawText(context, name, CGRectMake(textX, y + 9.0f, nameRight - textX, 20.0f), TGMediumSystemFontOfSize(16.0f), titleColor, NSTextAlignmentLeft, true);

        CGFloat messageRight = rightX - ((i == 0 || i == 2) ? 32.0f : 0.0f);
        UIFont *messageFont = TGSystemFontOfSize(15.0f);
        if (i == 2)
        {
            TGCloudThemePreviewDrawText(context, TGLocalized(@"OnegramTheme.Sample.Author3"), CGRectMake(textX, y + 31.0f, messageRight - textX, 19.0f), messageFont, pallete.dialogNameColor, NSTextAlignmentLeft, true);
            TGCloudThemePreviewDrawText(context, texts[i], CGRectMake(textX, y + 50.0f, messageRight - textX, 19.0f), messageFont, pallete.dialogTextColor, NSTextAlignmentLeft, true);
        }
        else
            TGCloudThemePreviewDrawText(context, texts[i], CGRectMake(textX, y + 31.0f, messageRight - textX, 38.0f), messageFont, i == 3 ? pallete.dialogDraftColor : pallete.dialogTextColor, NSTextAlignmentLeft, false);

        if (i == 0 || i == 2)
        {
            NSString *count = i == 0 ? @"2" : @"14";
            UIFont *badgeFont = TGSystemFontOfSize(14.0f);
            CGFloat badgeWidth = MAX(20.0f, [count sizeWithFont:badgeFont].width + 10.0f);
            CGRect badge = CGRectMake(rightX - badgeWidth, y + 40.0f, badgeWidth, 20.0f);
            TGCloudThemePreviewFillRoundedRect(context, badge, 10.0f, i == 0 ? pallete.dialogBadgeColor : pallete.dialogBadgeMutedColor);
            TGCloudThemePreviewDrawText(context, count, CGRectMake(badge.origin.x, badge.origin.y + 1.5f, badge.size.width, 17.0f), badgeFont, i == 0 ? pallete.dialogBadgeTextColor : pallete.dialogBadgeMutedTextColor, NSTextAlignmentCenter, true);
        }
        y += rowHeight;
        TGCloudThemePreviewFillRect(context, CGRectMake(textX, y - TGScreenPixel, size.width - textX, TGScreenPixel), pallete.separatorColor);
    }

    [self drawTabBarInContext:context];
}

- (void)drawTabIcon:(NSUInteger)index center:(CGPoint)center color:(UIColor *)color context:(CGContextRef)context
{
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, 1.6f);
    switch (index)
    {
        case 0:
            CGContextFillEllipseInRect(context, CGRectMake(center.x - 5.0f, center.y - 11.0f, 10.0f, 10.0f));
            CGContextBeginPath(context);
            CGContextAddArc(context, center.x, center.y + 11.0f, 10.0f, (CGFloat)M_PI, 0.0f, 0);
            CGContextClosePath(context);
            CGContextFillPath(context);
            break;
        case 1:
            CGContextStrokeEllipseInRect(context, CGRectMake(center.x - 11.0f, center.y - 11.0f, 22.0f, 22.0f));
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, center.x, center.y - 6.0f);
            CGContextAddLineToPoint(context, center.x, center.y);
            CGContextAddLineToPoint(context, center.x + 5.0f, center.y + 3.0f);
            CGContextStrokePath(context);
            break;
        case 2:
            TGCloudThemePreviewFillRoundedRect(context, CGRectMake(center.x - 12.0f, center.y - 10.0f, 24.0f, 18.0f), 8.0f, color);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, center.x - 9.0f, center.y + 4.0f);
            CGContextAddLineToPoint(context, center.x - 11.0f, center.y + 11.0f);
            CGContextAddLineToPoint(context, center.x - 3.0f, center.y + 7.0f);
            CGContextClosePath(context);
            CGContextFillPath(context);
            break;
        default:
        {
            CGContextSetLineWidth(context, 3.0f);
            CGContextStrokeEllipseInRect(context, CGRectMake(center.x - 8.0f, center.y - 8.0f, 16.0f, 16.0f));
            CGContextSetLineWidth(context, 3.0f);
            for (int i = 0; i < 8; i++)
            {
                CGFloat angle = (CGFloat)i * (CGFloat)M_PI / 4.0f;
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, center.x + cos(angle) * 8.0f, center.y + sin(angle) * 8.0f);
                CGContextAddLineToPoint(context, center.x + cos(angle) * 12.0f, center.y + sin(angle) * 12.0f);
                CGContextStrokePath(context);
            }
            break;
        }
    }
}

- (void)drawTabBarInContext:(CGContextRef)context
{
    TGPresentationPallete *pallete = _pallete;
    CGSize size = self.bounds.size;
    CGFloat top = size.height - TGCloudThemePreviewTabBarHeight;
    TGCloudThemePreviewFillRect(context, CGRectMake(0.0f, top, size.width, TGCloudThemePreviewTabBarHeight), pallete.barBackgroundColor);
    TGCloudThemePreviewFillRect(context, CGRectMake(0.0f, top, size.width, TGScreenPixel), pallete.barSeparatorColor);
    NSArray *titles = @[TGLocalized(@"Contacts.Title"), TGLocalized(@"Calls.TabTitle"), TGLocalized(@"DialogList.Title"), TGLocalized(@"Settings.Title")];
    CGFloat tabWidth = size.width / (CGFloat)titles.count;
    for (NSUInteger i = 0; i < titles.count; i++)
    {
        bool active = i == 2;
        UIColor *iconColor = active ? pallete.tabActiveIconColor : pallete.tabIconColor;
        CGPoint center = CGPointMake(tabWidth * (CGFloat)i + tabWidth / 2.0f, top + 18.0f);
        [self drawTabIcon:i center:center color:iconColor context:context];
        TGCloudThemePreviewDrawText(context, titles[i], CGRectMake(tabWidth * (CGFloat)i, top + 33.0f, tabWidth, 13.0f), TGSystemFontOfSize(10.0f), active ? pallete.tabActiveIconColor : pallete.tabTextColor, NSTextAlignmentCenter, true);
        if (active)
        {
            CGRect badge = CGRectMake(center.x + 6.0f, top + 3.0f, 18.0f, 18.0f);
            TGCloudThemePreviewFillRoundedRect(context, badge, 9.0f, pallete.tabBadgeColor);
            TGCloudThemePreviewDrawText(context, @"3", CGRectMake(badge.origin.x, badge.origin.y + 1.5f, badge.size.width, 15.0f), TGSystemFontOfSize(12.0f), pallete.tabBadgeTextColor, NSTextAlignmentCenter, true);
        }
    }
}

- (CGFloat)drawBubbleWithText:(NSString *)text replyAuthor:(NSString *)replyAuthor replyText:(NSString *)replyText outgoing:(bool)outgoing y:(CGFloat)y context:(CGContextRef)context
{
    TGPresentationPallete *pallete = _pallete;
    CGSize size = self.bounds.size;
    UIFont *textFont = TGSystemFontOfSize(16.0f);
    UIFont *replyFont = TGSystemFontOfSize(14.0f);
    UIFont *dateFont = TGSystemFontOfSize(11.0f);
    NSString *time = outgoing ? @"21:43" : @"21:41";
    CGFloat maxTextWidth = MIN(260.0f, size.width * 0.72f) - 24.0f;
    CGSize textSize = [text sizeWithFont:textFont constrainedToSize:CGSizeMake(maxTextWidth, 200.0f) lineBreakMode:NSLineBreakByWordWrapping];
    CGFloat statusWidth = [time sizeWithFont:dateFont].width + (outgoing ? 18.0f : 0.0f);
    CGFloat contentWidth = MAX(textSize.width, MIN(maxTextWidth, textSize.width + statusWidth + 8.0f));
    CGFloat replyHeight = 0.0f;
    if (replyAuthor != nil)
    {
        contentWidth = MAX(contentWidth, MIN(maxTextWidth, MAX([replyAuthor sizeWithFont:TGMediumSystemFontOfSize(14.0f)].width, [replyText sizeWithFont:replyFont].width) + 10.0f));
        replyHeight = 40.0f;
    }
    CGFloat bubbleWidth = contentWidth + 24.0f;
    CGFloat bubbleHeight = replyHeight + textSize.height + 26.0f;
    CGFloat x = outgoing ? size.width - bubbleWidth - 8.0f : 8.0f;
    CGRect bubble = CGRectMake(x, y, bubbleWidth, bubbleHeight);
    TGCloudThemePreviewFillRoundedRect(context, bubble, 16.0f, outgoing ? pallete.chatOutgoingBubbleBorderColor : pallete.chatIncomingBubbleBorderColor);
    TGCloudThemePreviewFillRoundedRect(context, CGRectInset(bubble, TGScreenPixel, TGScreenPixel), 16.0f, outgoing ? pallete.chatOutgoingBubbleColor : pallete.chatIncomingBubbleColor);

    CGFloat contentX = x + 12.0f;
    CGFloat contentY = y + 7.0f;
    if (replyAuthor != nil)
    {
        TGCloudThemePreviewFillRoundedRect(context, CGRectMake(contentX, contentY + 2.0f, 2.0f, 34.0f), 1.0f, outgoing ? pallete.chatOutgoingLineColor : pallete.chatIncomingLineColor);
        TGCloudThemePreviewDrawText(context, replyAuthor, CGRectMake(contentX + 8.0f, contentY + 1.0f, contentWidth - 8.0f, 18.0f), TGMediumSystemFontOfSize(14.0f), outgoing ? pallete.chatOutgoingAccentColor : pallete.chatIncomingAccentColor, NSTextAlignmentLeft, true);
        TGCloudThemePreviewDrawText(context, replyText, CGRectMake(contentX + 8.0f, contentY + 19.0f, contentWidth - 8.0f, 18.0f), replyFont, outgoing ? pallete.chatOutgoingSubtextColor : pallete.chatIncomingSubtextColor, NSTextAlignmentLeft, true);
        contentY += replyHeight;
    }
    TGCloudThemePreviewDrawText(context, text, CGRectMake(contentX, contentY, contentWidth, textSize.height), textFont, outgoing ? pallete.chatOutgoingTextColor : pallete.chatIncomingTextColor, NSTextAlignmentLeft, false);

    CGFloat statusRight = CGRectGetMaxX(bubble) - 10.0f;
    CGFloat statusY = CGRectGetMaxY(bubble) - 17.0f;
    if (outgoing)
    {
        TGCloudThemePreviewStrokeChecks(context, CGPointMake(statusRight - 12.0f, statusY + 3.0f), pallete.chatChecksColor, true);
        statusRight -= 17.0f;
    }
    CGFloat timeWidth = [time sizeWithFont:dateFont].width;
    TGCloudThemePreviewDrawText(context, time, CGRectMake(statusRight - timeWidth, statusY, timeWidth, 14.0f), dateFont, outgoing ? pallete.chatOutgoingDateColor : pallete.chatIncomingDateColor, NSTextAlignmentRight, true);
    return bubbleHeight;
}

- (void)drawChatInContext:(CGContextRef)context
{
    TGPresentationPallete *pallete = _pallete;
    CGSize size = self.bounds.size;
    TGCloudThemePreviewFillRect(context, self.bounds, pallete.backgroundColor);
    if (_wallpaperImage != nil && _wallpaperImage.size.width > 0.0f && _wallpaperImage.size.height > 0.0f)
    {
        CGFloat scale = MAX(size.width / _wallpaperImage.size.width, size.height / _wallpaperImage.size.height);
        CGSize imageSize = CGSizeMake(_wallpaperImage.size.width * scale, _wallpaperImage.size.height * scale);
        CGContextSaveGState(context);
        CGContextClipToRect(context, self.bounds);
        [_wallpaperImage drawInRect:CGRectMake((size.width - imageSize.width) / 2.0f, (size.height - imageSize.height) / 2.0f, imageSize.width, imageSize.height)];
        CGContextRestoreGState(context);
    }

    [self drawNavigationBarInContext:context];
    CGContextSetStrokeColorWithColor(context, pallete.navigationButtonColor.CGColor);
    CGContextSetLineWidth(context, 2.5f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 18.0f, 13.0f);
    CGContextAddLineToPoint(context, 10.0f, 22.0f);
    CGContextAddLineToPoint(context, 18.0f, 31.0f);
    CGContextStrokePath(context);
    TGCloudThemePreviewDrawText(context, TGLocalized(@"DialogList.Title"), CGRectMake(24.0f, 11.0f, 70.0f, 22.0f), TGSystemFontOfSize(17.0f), pallete.navigationButtonColor, NSTextAlignmentLeft, true);
    NSString *author = TGLocalized(@"Appearance.PreviewReplyAuthor");
    TGCloudThemePreviewDrawText(context, author, CGRectMake(90.0f, 4.0f, size.width - 180.0f, 20.0f), TGBoldSystemFontOfSize(16.0f), pallete.navigationTitleColor, NSTextAlignmentCenter, true);
    TGCloudThemePreviewDrawText(context, TGLocalized(@"Presence.online"), CGRectMake(90.0f, 23.0f, size.width - 180.0f, 16.0f), TGSystemFontOfSize(13.0f), pallete.navigationActiveSubtitleColor, NSTextAlignmentCenter, true);
    CGRect avatar = CGRectMake(size.width - 45.0f, 3.0f, 37.0f, 37.0f);
    CGContextSetFillColorWithColor(context, TGCloudThemePreviewAvatarColor(0).CGColor);
    CGContextFillEllipseInRect(context, avatar);
    TGCloudThemePreviewDrawText(context, author.length != 0 ? [[author substringToIndex:1] uppercaseString] : @"", CGRectMake(avatar.origin.x, avatar.origin.y + 9.0f, avatar.size.width, 20.0f), TGBoldSystemFontOfSize(16.0f), [UIColor whiteColor], NSTextAlignmentCenter, true);

    CGFloat y = TGCloudThemePreviewNavigationHeight + 12.0f;
    NSString *date = TGLocalized(@"OnegramTheme.Today");
    UIFont *dateFont = TGBoldSystemFontOfSize(13.0f);
    CGFloat dateWidth = [date sizeWithFont:dateFont].width + 16.0f;
    CGRect datePill = CGRectMake(CGFloor((size.width - dateWidth) / 2.0f), y, dateWidth, 22.0f);
    TGCloudThemePreviewFillRoundedRect(context, datePill, 11.0f, pallete.chatSystemBackgroundColor);
    TGCloudThemePreviewDrawText(context, date, CGRectMake(datePill.origin.x, datePill.origin.y + 3.0f, datePill.size.width, 16.0f), dateFont, pallete.chatSystemTextColor, NSTextAlignmentCenter, true);
    y += 34.0f;

    y += [self drawBubbleWithText:TGLocalized(@"Appearance.PreviewIncomingText") replyAuthor:author replyText:TGLocalized(@"Appearance.PreviewReplyText") outgoing:false y:y context:context] + 8.0f;
    y += [self drawBubbleWithText:TGLocalized(@"Appearance.PreviewOutgoingText") replyAuthor:nil replyText:nil outgoing:true y:y context:context] + 8.0f;
    y += [self drawBubbleWithText:TGLocalized(@"OnegramTheme.Sample.Incoming") replyAuthor:nil replyText:nil outgoing:false y:y context:context] + 8.0f;
    [self drawBubbleWithText:TGLocalized(@"OnegramTheme.Sample.Outgoing") replyAuthor:nil replyText:nil outgoing:true y:y context:context];

    CGFloat top = size.height - TGCloudThemePreviewInputHeight;
    TGCloudThemePreviewFillRect(context, CGRectMake(0.0f, top, size.width, TGCloudThemePreviewInputHeight), pallete.barBackgroundColor);
    TGCloudThemePreviewFillRect(context, CGRectMake(0.0f, top, size.width, TGScreenPixel), pallete.barSeparatorColor);
    CGContextSetStrokeColorWithColor(context, pallete.chatInputButtonColor.CGColor);
    CGContextSetLineWidth(context, 1.8f);
    CGContextStrokeEllipseInRect(context, CGRectMake(10.0f, top + 10.0f, 24.0f, 24.0f));
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 22.0f, top + 16.0f);
    CGContextAddLineToPoint(context, 22.0f, top + 28.0f);
    CGContextMoveToPoint(context, 16.0f, top + 22.0f);
    CGContextAddLineToPoint(context, 28.0f, top + 22.0f);
    CGContextStrokePath(context);
    CGRect field = CGRectMake(42.0f, top + 7.0f, size.width - 42.0f - 46.0f, 31.0f);
    TGCloudThemePreviewFillRoundedRect(context, field, 15.5f, pallete.chatInputBorderColor);
    TGCloudThemePreviewFillRoundedRect(context, CGRectInset(field, TGScreenPixel, TGScreenPixel), 15.5f, pallete.chatInputBackgroundColor);
    TGCloudThemePreviewDrawText(context, TGLocalized(@"Conversation.InputTextPlaceholder"), CGRectMake(field.origin.x + 12.0f, field.origin.y + 6.0f, field.size.width - 24.0f, 20.0f), TGSystemFontOfSize(16.0f), pallete.chatInputPlaceholderColor, NSTextAlignmentLeft, true);
    CGRect send = CGRectMake(size.width - 38.0f, top + 7.0f, 31.0f, 31.0f);
    CGContextSetFillColorWithColor(context, pallete.chatInputSendButtonColor.CGColor);
    CGContextFillEllipseInRect(context, send);
    CGContextSetStrokeColorWithColor(context, pallete.chatInputSendButtonIconColor.CGColor);
    CGContextSetLineWidth(context, 2.2f);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, CGRectGetMidX(send), CGRectGetMaxY(send) - 8.0f);
    CGContextAddLineToPoint(context, CGRectGetMidX(send), CGRectGetMinY(send) + 8.0f);
    CGContextMoveToPoint(context, CGRectGetMidX(send) - 6.0f, CGRectGetMinY(send) + 14.0f);
    CGContextAddLineToPoint(context, CGRectGetMidX(send), CGRectGetMinY(send) + 8.0f);
    CGContextAddLineToPoint(context, CGRectGetMidX(send) + 6.0f, CGRectGetMinY(send) + 14.0f);
    CGContextStrokePath(context);
}

@end

@interface TGCloudThemePageIndicator : UIView

@property (nonatomic) NSUInteger currentPage;
@property (nonatomic, strong) UIColor *activeColor;
@property (nonatomic, strong) UIColor *inactiveColor;

@end

@implementation TGCloudThemePageIndicator

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.opaque = false;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setCurrentPage:(NSUInteger)currentPage
{
    if (_currentPage == currentPage)
        return;
    _currentPage = currentPage;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)__unused rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    const CGFloat diameter = 7.0f;
    const CGFloat spacing = 9.0f;
    CGFloat x = CGFloor((self.bounds.size.width - diameter * 2.0f - spacing) / 2.0f);
    CGFloat y = CGFloor((self.bounds.size.height - diameter) / 2.0f);
    for (NSUInteger i = 0; i < 2; i++)
    {
        CGContextSetFillColorWithColor(context, (i == _currentPage ? _activeColor : _inactiveColor).CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(x + (diameter + spacing) * (CGFloat)i, y, diameter, diameter));
    }
}

@end

@interface TGCloudThemePreviewView : UIView <UIScrollViewDelegate>
{
    UIScrollView *_scrollView;
    NSArray *_pageViews;
    UIView *_panelView;
    UIView *_panelSeparatorView;
    UIView *_buttonSeparatorView;
    TGCloudThemePageIndicator *_pageIndicator;
    UIButton *_cancelButton;
    UIButton *_applyButton;
}

@property (nonatomic) UIEdgeInsets insets;
@property (nonatomic, copy) void (^cancelPressed)(void);
@property (nonatomic, copy) void (^applyPressed)(void);

- (instancetype)initWithFrame:(CGRect)frame theme:(TGCloudTheme *)theme presentation:(TGPresentation *)presentation;

@end

@implementation TGCloudThemePreviewView

- (instancetype)initWithFrame:(CGRect)frame theme:(TGCloudTheme *)theme presentation:(TGPresentation *)presentation
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        TGPresentationPallete *pallete = presentation.pallete;
        self.backgroundColor = pallete.collectionMenuBackgroundColor;

        _scrollView = [[UIScrollView alloc] init];
        _scrollView.pagingEnabled = true;
        _scrollView.showsHorizontalScrollIndicator = false;
        _scrollView.showsVerticalScrollIndicator = false;
        _scrollView.alwaysBounceVertical = false;
        _scrollView.scrollsToTop = false;
        _scrollView.delegate = self;
        [self addSubview:_scrollView];

        TGPresentationPallete *themePallete = [theme previewPallete];
        UIImage *wallpaperImage = [[theme wallpaperInfo] image];
        _pageViews = @[
            [[TGCloudThemePreviewPageView alloc] initWithPage:TGCloudThemePreviewPageChatList pallete:themePallete wallpaperImage:nil],
            [[TGCloudThemePreviewPageView alloc] initWithPage:TGCloudThemePreviewPageChat pallete:themePallete wallpaperImage:wallpaperImage]
        ];
        for (UIView *pageView in _pageViews)
            [_scrollView addSubview:pageView];

        _panelView = [[UIView alloc] init];
        _panelView.backgroundColor = pallete.barBackgroundColor;
        [self addSubview:_panelView];

        _panelSeparatorView = [[UIView alloc] init];
        _panelSeparatorView.backgroundColor = pallete.barSeparatorColor;
        [_panelView addSubview:_panelSeparatorView];

        _pageIndicator = [[TGCloudThemePageIndicator alloc] init];
        _pageIndicator.activeColor = pallete.accentColor;
        _pageIndicator.inactiveColor = [pallete.secondaryTextColor colorWithAlphaComponent:0.4f];
        [_panelView addSubview:_pageIndicator];

        _cancelButton = [self buttonWithTitle:TGLocalized(@"Common.Cancel") font:TGSystemFontOfSize(17.0f) color:pallete.accentColor action:@selector(cancelButtonPressed)];
        _applyButton = [self buttonWithTitle:TGLocalized(@"OnegramTheme.Apply") font:TGBoldSystemFontOfSize(17.0f) color:pallete.accentColor action:@selector(applyButtonPressed)];

        _buttonSeparatorView = [[UIView alloc] init];
        _buttonSeparatorView.backgroundColor = pallete.barSeparatorColor;
        [_panelView addSubview:_buttonSeparatorView];
    }
    return self;
}

- (UIButton *)buttonWithTitle:(NSString *)title font:(UIFont *)font color:(UIColor *)color action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateNormal];
    [button setTitleColor:[color colorWithAlphaComponent:0.4f] forState:UIControlStateHighlighted];
    button.titleLabel.font = font;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:button];
    return button;
}

- (void)setInsets:(UIEdgeInsets)insets
{
    _insets = insets;
    [self setNeedsLayout];
}

- (void)cancelButtonPressed
{
    if (_cancelPressed)
        _cancelPressed();
}

- (void)applyButtonPressed
{
    if (_applyPressed)
        _applyPressed();
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGSize size = self.bounds.size;
    const CGFloat indicatorHeight = 22.0f;
    const CGFloat buttonsHeight = 48.0f;
    CGFloat panelHeight = indicatorHeight + buttonsHeight + _insets.bottom;
    _panelView.frame = CGRectMake(0.0f, size.height - panelHeight, size.width, panelHeight);
    _panelSeparatorView.frame = CGRectMake(0.0f, 0.0f, size.width, TGScreenPixel);
    _pageIndicator.frame = CGRectMake(0.0f, 4.0f, size.width, indicatorHeight - 4.0f);
    CGFloat half = CGFloor(size.width / 2.0f);
    _cancelButton.frame = CGRectMake(0.0f, indicatorHeight, half, buttonsHeight);
    _applyButton.frame = CGRectMake(half, indicatorHeight, size.width - half, buttonsHeight);
    _buttonSeparatorView.frame = CGRectMake(half, indicatorHeight + 10.0f, TGScreenPixel, buttonsHeight - 20.0f);

    CGFloat pageHeight = MAX(0.0f, size.height - panelHeight - _insets.top);
    NSUInteger currentPage = _pageIndicator.currentPage;
    _scrollView.frame = CGRectMake(0.0f, _insets.top, size.width, pageHeight);
    _scrollView.contentSize = CGSizeMake(size.width * (CGFloat)_pageViews.count, pageHeight);
    for (NSUInteger i = 0; i < _pageViews.count; i++)
    {
        UIView *pageView = _pageViews[i];
        CGRect frame = CGRectMake(size.width * (CGFloat)i, 0.0f, size.width, pageHeight);
        if (!CGRectEqualToRect(pageView.frame, frame))
        {
            pageView.frame = frame;
            [pageView setNeedsDisplay];
        }
    }
    _scrollView.contentOffset = CGPointMake(size.width * (CGFloat)currentPage, 0.0f);
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat width = scrollView.bounds.size.width;
    if (width <= 0.0f)
        return;
    NSInteger page = (NSInteger)floor(scrollView.contentOffset.x / width + 0.5f);
    _pageIndicator.currentPage = (NSUInteger)MAX(0, MIN((NSInteger)_pageViews.count - 1, page));
}

@end

@interface TGCloudThemePreviewController ()
{
    TGCloudTheme *_theme;
    TGCloudThemePreviewView *_previewView;
}

@end

@implementation TGCloudThemePreviewController

- (instancetype)initWithTheme:(TGCloudTheme *)theme
{
    self = [super init];
    if (self != nil)
    {
        _theme = theme;
        self.title = theme.title.length != 0 ? theme.title : TGLocalized(@"OnegramTheme.Preview");
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    self.view.backgroundColor = [TGPresentation current].pallete.collectionMenuBackgroundColor;
    _previewView = [[TGCloudThemePreviewView alloc] initWithFrame:self.view.bounds theme:_theme presentation:[TGPresentation current]];
    _previewView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    __weak TGCloudThemePreviewController *weakSelf = self;
    _previewView.cancelPressed = ^
    {
        __strong TGCloudThemePreviewController *strongSelf = weakSelf;
        [strongSelf.presentingViewController dismissViewControllerAnimated:true completion:nil];
    };
    _previewView.applyPressed = ^
    {
        __strong TGCloudThemePreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        TGCloudTheme *theme = strongSelf->_theme;
        [strongSelf.presentingViewController dismissViewControllerAnimated:true completion:^
        {
            [TGAppDelegateInstance rebuildInterfaceApplyingChange:^
            {
                [theme install];
            }];
        }];
    };
    [self.view addSubview:_previewView];

    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    _previewView.insets = UIEdgeInsetsMake(self.controllerInset.top, 0.0f, self.controllerSafeAreaInset.bottom, 0.0f);
}

+ (void)presentTheme:(TGCloudTheme *)theme
{
    UIViewController *parentController = TGAppDelegateInstance.rootController;
    while (parentController.presentedViewController != nil)
        parentController = parentController.presentedViewController;
    [parentController.view endEditing:true];

    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[[[TGCloudThemePreviewController alloc] initWithTheme:theme]]];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [parentController presentViewController:navigationController animated:true completion:nil];
}

+ (void)presentThemeWithSignal:(SSignal *)signal
{
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.1];
    [[[signal deliverOn:[SQueue mainQueue]] onDispose:^
    {
        TGDispatchOnMainThread(^
        {
            [progressWindow dismiss:true];
        });
    }] startWithNext:^(TGCloudTheme *theme)
    {
        [self presentTheme:theme];
    } error:^(id error)
    {
        bool unsupported = [error isKindOfClass:[NSNumber class]] && [error intValue] == TGCloudThemeErrorUnsupported;
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(unsupported ? @"OnegramTheme.Unsupported" : @"OnegramTheme.LoadFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    } completed:nil];
}

@end
