#import "OGComponentGalleryController.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
#import "../Core/OGMetrics.h"
#import "../Common/OGBadgeView.h"
#import "../Common/OGPresenceView.h"
#import "../Lists/OGSettingsCell.h"
#import "../Lists/OGContactCell.h"
#import "../Lists/OGDialogCell.h"
#import "OGPreviewData.h"

@implementation OGComponentGalleryController
- (void)loadView
{
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    OGTheme *theme = [OGTheme brandedTheme];
    scrollView.backgroundColor = theme.palette.backgroundColor;

    CGFloat width = 320.0f;
    CGFloat y = 18.0f;
    NSArray *counts = [OGPreviewData badgeCounts];
    for (NSNumber *number in counts)
    {
        OGBadgeView *badge = [[OGBadgeView alloc] initWithFrame:CGRectZero];
        badge.theme = theme;
        badge.count = [number integerValue];
        CGSize size = [badge sizeThatFits:CGSizeMake(120.0f, theme.metrics.badgeHeight)];
        badge.frame = CGRectMake(20.0f, y, size.width, size.height);
        [scrollView addSubview:badge];
        y += 28.0f;
    }

    OGSettingsCell *settings = [[OGSettingsCell alloc] initWithFrame:CGRectMake(0.0f, y + 8.0f, width, theme.metrics.settingsRowHeight)];
    settings.theme = theme;
    settings.titleLabel.text = @"Settings Cell";
    settings.showsIcon = YES;
    settings.showsAccessory = YES;
    [scrollView addSubview:settings];
    y = CGRectGetMaxY(settings.frame) + 10.0f;

    OGContactCell *contact = [[OGContactCell alloc] initWithFrame:CGRectMake(0.0f, y, width, 56.0f)];
    contact.theme = theme;
    contact.titleLabel.text = @"Contact";
    contact.subtitleLabel.text = @"Online";
    [scrollView addSubview:contact];
    y = CGRectGetMaxY(contact.frame) + 10.0f;

    OGDialogCell *dialog = [[OGDialogCell alloc] initWithFrame:CGRectMake(0.0f, y, width, theme.metrics.dialogRowHeight)];
    dialog.theme = theme;
    dialog.titleLabel.text = @"Saved Messages";
    dialog.subtitleLabel.text = @"Onegram UI Kit preview";
    dialog.detailLabel.text = @"22:41";
    dialog.badgeView.count = 42;
    [scrollView addSubview:dialog];
    y = CGRectGetMaxY(dialog.frame) + 24.0f;

    scrollView.contentSize = CGSizeMake(width, y);
    self.view = scrollView;
}
@end
