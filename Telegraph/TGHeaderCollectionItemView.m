#import "TGHeaderCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGSettingsAppearance.h"
#import "../OnegramUI/Lists/OGSettingsCell.h"

@interface TGHeaderCollectionItemView ()
{
    UILabel *_label;
    UIView *_badgeView;
    UILabel *_badgeLabel;
    bool _brandedHeaderStyle;
}

@end

@implementation TGHeaderCollectionItemView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _label = [[UILabel alloc] init];
        _label.backgroundColor = [UIColor clearColor];
        _label.font = TGSystemFontOfSize(14.0f);
        _label.textAlignment = NSTextAlignmentLeft;
        _label.lineBreakMode = NSLineBreakByTruncatingTail;
        _label.numberOfLines = 1;
        [self addSubview:_label];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    _brandedHeaderStyle = [TGPresentation brandedIOS6Style] && [OGSettingsCell applyLegacyBrandedHeaderStyleWithTheme:[OGTheme brandedTheme] headerLabel:_label];
    if (!_brandedHeaderStyle)
    {
        _label.font = TGSystemFontOfSize(14.0f);
        _label.textColor = presentation.pallete.collectionMenuCommentColor;
        _label.shadowColor = nil;
        _label.shadowOffset = CGSizeZero;
    }
    [self updateBadgeColors];
    [self setNeedsLayout];
}

- (void)setTitle:(NSString *)title
{
    _label.text = title;
    [self setNeedsLayout];
}

- (void)setBadgeText:(NSString *)badgeText
{
    if (badgeText.length != 0 && _badgeView == nil)
    {
        _badgeView = [[UIView alloc] init];
        _badgeView.userInteractionEnabled = false;
        _badgeView.clipsToBounds = true;
        [self addSubview:_badgeView];

        _badgeLabel = [[UILabel alloc] init];
        _badgeLabel.backgroundColor = [UIColor clearColor];
        _badgeLabel.font = TGSystemFontOfSize(12.0f);
        [_badgeView addSubview:_badgeLabel];
        [self updateBadgeColors];
    }
    _badgeLabel.text = badgeText;
    _badgeView.hidden = badgeText.length == 0;
    [self setNeedsLayout];
}

- (void)updateBadgeColors
{
    UIColor *color = _label.textColor;
    _badgeLabel.textColor = color;
    _badgeView.backgroundColor = [color colorWithAlphaComponent:0.15f];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat labelX = _brandedHeaderStyle ? [OGTheme brandedTheme].settingsAppearance.headerX : 15.0f;
    CGSize labelSize = [_label sizeThatFits:CGSizeMake(self.bounds.size.width - labelX * 2.0f, CGFLOAT_MAX)];
    _label.frame = CGRectMake(labelX + self.safeAreaInset.left, 0.0f, labelSize.width, labelSize.height);

    if (_badgeView != nil && !_badgeView.hidden)
    {
        CGFloat badgeLeft = CGRectGetMaxX(_label.frame) + 6.0f;
        CGFloat maxBadgeWidth = MAX(0.0f, self.bounds.size.width - labelX - self.safeAreaInset.right - badgeLeft);
        CGSize textSize = [_badgeLabel sizeThatFits:CGSizeMake(MAX(0.0f, maxBadgeWidth - 12.0f), CGFLOAT_MAX)];
        CGFloat badgeHeight = CGCeil(textSize.height) + 2.0f;
        CGFloat badgeWidth = MIN(maxBadgeWidth, CGCeil(textSize.width) + 12.0f);
        _badgeView.frame = CGRectMake(badgeLeft, CGFloor(CGRectGetMidY(_label.frame) - badgeHeight / 2.0f), badgeWidth, badgeHeight);
        _badgeView.layer.cornerRadius = badgeHeight / 2.0f;
        _badgeLabel.frame = CGRectMake(6.0f, 1.0f, MAX(0.0f, badgeWidth - 12.0f), CGCeil(textSize.height));
    }
}

@end
