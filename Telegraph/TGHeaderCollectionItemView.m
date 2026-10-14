#import "TGHeaderCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGSettingsAppearance.h"
#import "../OnegramUI/Lists/OGSettingsCell.h"

@interface TGHeaderCollectionItemView ()
{
    UILabel *_label;
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
    [self setNeedsLayout];
}

- (void)setTitle:(NSString *)title
{
    _label.text = title;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat labelX = _brandedHeaderStyle ? [OGTheme brandedTheme].settingsAppearance.headerX : 15.0f;
    CGSize labelSize = [_label sizeThatFits:CGSizeMake(self.bounds.size.width - labelX * 2.0f, CGFLOAT_MAX)];
    _label.frame = CGRectMake(labelX + self.safeAreaInset.left, 0.0f, labelSize.width, labelSize.height);
}

@end
