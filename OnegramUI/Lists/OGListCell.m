#import "OGListCell.h"
#import "../Common/OGAvatarView.h"
#import "../Common/OGBadgeView.h"
#import "../Base/OGIconView.h"
#import "../Base/OGLabel.h"
#import "../Base/OGSeparatorView.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
#import "../Core/OGTypography.h"
#import "../Core/OGMetrics.h"
#import "../Core/OGGeometry.h"
#import "OGPlatformText.h"

@implementation OGListCell
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _contentInsets = UIEdgeInsetsMake(0.0f, 8.0f, 0.0f, 8.0f);
        _avatarView = [[OGAvatarView alloc] initWithFrame:CGRectZero];
        _iconView = [[OGIconView alloc] initWithFrame:CGRectZero];
        _titleLabel = [[OGLabel alloc] initWithFrame:CGRectZero];
        _subtitleLabel = [[OGLabel alloc] initWithFrame:CGRectZero];
        _detailLabel = [[OGLabel alloc] initWithFrame:CGRectZero];
        _detailLabel.textAlignment = NSTextAlignmentRight;
        _badgeView = [[OGBadgeView alloc] initWithFrame:CGRectZero];
        _accessoryView = [[OGIconView alloc] initWithFrame:CGRectZero];
        _accessoryView.drawsShadow = NO;
        _separatorView = [[OGSeparatorView alloc] initWithFrame:CGRectZero];
        [self addSubview:_avatarView];
        [self addSubview:_iconView];
        [self addSubview:_titleLabel];
        [self addSubview:_subtitleLabel];
        [self addSubview:_detailLabel];
        [self addSubview:_badgeView];
        [self addSubview:_accessoryView];
        [self addSubview:_separatorView];
        _showsSeparator = YES;
        [self applyTheme];
    }
    return self;
}

- (void)setTheme:(OGTheme *)theme
{
    [super setTheme:theme];
    _avatarView.theme = self.theme;
    _iconView.theme = self.theme;
    _titleLabel.theme = self.theme;
    _subtitleLabel.theme = self.theme;
    _detailLabel.theme = self.theme;
    _badgeView.theme = self.theme;
    _accessoryView.theme = self.theme;
    _separatorView.theme = self.theme;
    [self applyTheme];
}

- (void)applyTheme
{
    [super applyTheme];
    _titleLabel.textColor = self.theme.palette.primaryTextColor;
    _titleLabel.font = self.theme.typography.bodyFont;
    _subtitleLabel.textColor = self.theme.palette.secondaryTextColor;
    _subtitleLabel.font = self.theme.typography.secondaryFont;
    _detailLabel.textColor = self.theme.palette.secondaryTextColor;
    _detailLabel.font = self.theme.typography.secondaryFont;
    self.backgroundColor = _highlighted ? self.theme.palette.selectionColor : self.theme.palette.cardColor;
}

- (void)setHighlighted:(BOOL)highlighted
{
    _highlighted = highlighted;
    self.backgroundColor = highlighted ? self.theme.palette.selectionColor : self.theme.palette.cardColor;
}

- (void)prepareForReuse
{
    _avatarView.image = nil;
    _iconView.image = nil;
    _accessoryView.image = nil;
    _titleLabel.text = nil;
    _subtitleLabel.text = nil;
    _detailLabel.text = nil;
    _badgeView.count = 0;
    self.highlighted = NO;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    CGFloat x = _contentInsets.left;
    CGFloat right = bounds.size.width - _contentInsets.right;
    CGFloat middle = OGPixelFloor(bounds.size.height * 0.5f);

    _avatarView.hidden = !_showsAvatar;
    _iconView.hidden = !_showsIcon;
    _accessoryView.hidden = !_showsAccessory;
    _separatorView.hidden = !_showsSeparator;

    if (_showsAvatar)
    {
        CGFloat size = self.theme.metrics.avatarSize;
        _avatarView.frame = CGRectMake(x, OGPixelFloor((bounds.size.height - size) * 0.5f), size, size);
        x += size + self.theme.metrics.listIconSpacing;
    }

    if (_showsIcon)
    {
        CGSize preferred = _iconView.preferredSize;
        CGFloat width = preferred.width > 0.0f ? preferred.width : self.theme.metrics.settingsIconSize;
        CGFloat height = preferred.height > 0.0f ? preferred.height : self.theme.metrics.settingsIconSize;
        _iconView.frame = CGRectMake(x, OGPixelFloor((bounds.size.height - height) * 0.5f), width, height);
        x += width + self.theme.metrics.listIconSpacing;
    }

    if (_showsAccessory)
    {
        CGSize preferred = _accessoryView.preferredSize;
        CGFloat width = preferred.width > 0.0f ? preferred.width : 8.0f;
        CGFloat height = preferred.height > 0.0f ? preferred.height : 14.0f;
        _accessoryView.frame = CGRectMake(right - width, OGPixelFloor((bounds.size.height - height) * 0.5f), width, height);
        right -= width + self.theme.metrics.listAccessorySpacing;
    }

    if (_badgeView.count > 0 || [_badgeView.displayText length] != 0)
    {
        CGSize badgeSize = [_badgeView sizeThatFits:CGSizeMake(MAX(0.0f, right - x), bounds.size.height)];
        _badgeView.hidden = NO;
        _badgeView.frame = CGRectMake(right - badgeSize.width, OGPixelFloor((bounds.size.height - badgeSize.height) * 0.5f), badgeSize.width, badgeSize.height);
        right -= badgeSize.width + self.theme.metrics.listAccessorySpacing;
    }
    else
    {
        _badgeView.hidden = YES;
    }

    CGFloat detailWidth = 0.0f;
    if ([_detailLabel.text length] != 0)
    {
        CGSize detailSize = [_detailLabel sizeThatFits:CGSizeMake(MIN(120.0f, MAX(0.0f, right - x)), bounds.size.height)];
        detailWidth = MIN(120.0f, ceilf(detailSize.width));
        _detailLabel.frame = CGRectMake(right - detailWidth, middle - 10.0f, detailWidth, 20.0f);
        right -= detailWidth + self.theme.metrics.listAccessorySpacing;
        _detailLabel.hidden = NO;
    }
    else
    {
        _detailLabel.hidden = YES;
    }

    CGFloat textWidth = MAX(0.0f, right - x);
    if ([_subtitleLabel.text length] == 0)
    {
        CGFloat titleHeight = MAX(22.0f, ceilf(OGPlatformFontLineHeight(_titleLabel.font)));
        _titleLabel.frame = CGRectMake(x, OGPixelFloor((bounds.size.height - titleHeight) * 0.5f), textWidth, titleHeight);
        _subtitleLabel.frame = CGRectZero;
        _subtitleLabel.hidden = YES;
    }
    else
    {
        _subtitleLabel.hidden = NO;
        _titleLabel.frame = CGRectMake(x, middle - 20.0f, textWidth, 21.0f);
        _subtitleLabel.frame = CGRectMake(x, middle + 2.0f, textWidth, 18.0f);
    }

    _separatorView.frame = CGRectMake(0.0f, bounds.size.height - self.theme.metrics.separatorHeight, bounds.size.width, self.theme.metrics.separatorHeight);
    _separatorView.insets = UIEdgeInsetsMake(0.0f, x, 0.0f, 0.0f);
}
@end
