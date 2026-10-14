#import "TGUserInfoEditingVariantCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGProfileAppearance.h"
#import "../OnegramUI/Lists/OGSettingsCell.h"

@interface TGUserInfoEditingVariantCollectionItemView ()
{
    CALayer *_separatorLayer;
    
    UILabel *_titleLabel;
    UILabel *_variantLabel;
    UIImageView *_arrowView;
}

@end

@implementation TGUserInfoEditingVariantCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _separatorLayer = [[CALayer alloc] init];
        _separatorLayer.backgroundColor = TGSeparatorColor().CGColor;
        [self.backgroundView.layer addSublayer:_separatorLayer];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = TGAccentColor();
        _titleLabel.font = TGSystemFontOfSize(14.0f);
        [self addSubview:_titleLabel];
        
        _variantLabel = [[UILabel alloc] init];
        _variantLabel.backgroundColor = [UIColor clearColor];
        _variantLabel.textColor = [UIColor blackColor];
        _variantLabel.font = TGSystemFontOfSize(17.0f);
        [self addSubview:_variantLabel];
        
        _arrowView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 8.0f, 14.0f)];
        [self addSubview:_arrowView];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    if ([TGPresentation brandedIOS6Style])
    {
        OGTheme *theme = [OGTheme brandedTheme];
        OGProfileAppearance *appearance = theme.profileAppearance;
        _titleLabel.font = TGSystemFontOfSize(appearance.detailTitleFontSize);
        _titleLabel.textColor = appearance.detailTitleColor;
        _variantLabel.font = TGSystemFontOfSize(appearance.detailVariantFontSize);
        _variantLabel.textColor = appearance.detailVariantColor;
        _arrowView.image = [OGSettingsCell legacyBrandedDisclosureImageWithTheme:theme];
        _separatorLayer.backgroundColor = appearance.detailSeparatorColor.CGColor;
    }
    else
    {
        _titleLabel.font = TGSystemFontOfSize(14.0f);
        _titleLabel.textColor = presentation.pallete.collectionMenuAccentColor;
        _variantLabel.font = TGSystemFontOfSize(17.0f);
        _variantLabel.textColor = presentation.pallete.collectionMenuVariantColor;
        _arrowView.image = presentation.images.collectionMenuDisclosureIcon;
    }
    if (![TGPresentation brandedIOS6Style])
        _separatorLayer.backgroundColor = presentation.pallete.collectionMenuSeparatorColor.CGColor;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
    [self setNeedsLayout];
}

- (void)setVariant:(NSString *)variant
{
    _variantLabel.text = variant;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
    OGProfileAppearance *appearance = [OGTheme brandedTheme].profileAppearance;
    CGFloat separatorHeight = TGScreenPixel;
    CGFloat separatorInset = (brandedIOS6Style ? appearance.detailSeparatorInset : 15.0f) + self.safeAreaInset.left;
    _separatorLayer.frame = CGRectMake(separatorInset, bounds.size.height - separatorHeight, bounds.size.width - separatorInset, separatorHeight);

    CGFloat leftPadding = (brandedIOS6Style ? appearance.detailLeft : 15.0f + TGScreenPixel) + self.safeAreaInset.left;
    CGFloat titleMaximumWidth = brandedIOS6Style ? appearance.detailTitleMaximumWidth : 70.0f;
    CGSize titleSize = [_titleLabel sizeThatFits:CGSizeMake(titleMaximumWidth, CGFLOAT_MAX)];
    _titleLabel.frame = CGRectMake(leftPadding, brandedIOS6Style ? appearance.detailTitleTop : 14.0f, titleSize.width, titleSize.height);

    CGFloat variantReservedWidth = brandedIOS6Style ? appearance.detailVariantReservedWidth : 122.0f;
    CGFloat disclosureRight = brandedIOS6Style ? appearance.detailDisclosureRight : 15.0f;
    CGFloat variantRight = brandedIOS6Style ? appearance.detailVariantRight : 35.0f;
    CGSize variantSize = [_variantLabel sizeThatFits:CGSizeMake(bounds.size.width - variantReservedWidth - disclosureRight, CGFLOAT_MAX)];
    _variantLabel.frame = CGRectMake(bounds.size.width - variantSize.width - variantRight - self.safeAreaInset.right, brandedIOS6Style ? appearance.detailVariantTop : 12.0f, variantSize.width, variantSize.height);

    if (brandedIOS6Style)
        _arrowView.image = [OGSettingsCell legacyBrandedDisclosureImageWithTheme:[OGTheme brandedTheme]];
    CGSize arrowSize = _arrowView.image == nil ? _arrowView.bounds.size : _arrowView.image.size;
    _arrowView.frame = CGRectMake(bounds.size.width - disclosureRight - arrowSize.width - self.safeAreaInset.right, (self.frame.size.height - arrowSize.height) / 2.0f, arrowSize.width, arrowSize.height);
}

@end
