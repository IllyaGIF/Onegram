#import "TGUserInfoVariantCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"

@interface TGUserInfoVariantCollectionItemView ()
{
    CALayer *_separatorLayer;
    
    UILabel *_titleLabel;
    UILabel *_variantLabel;
    UIImageView *_arrowView;
    
    UIImageView *_variantImageView;
    UIImageView *_iconView;
}

@end

@implementation TGUserInfoVariantCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.selectionInsets = UIEdgeInsetsMake(TGScreenPixel, 0.0f, 0.0f, 0.0f);
        
        _separatorLayer = [[CALayer alloc] init];
        _separatorLayer.backgroundColor = TGSeparatorColor().CGColor;
        [self.backgroundView.layer addSublayer:_separatorLayer];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        _titleLabel.textColor = [UIColor blackColor];
        [self addSubview:_titleLabel];
        
        _variantLabel = [[UILabel alloc] init];
        _variantLabel.backgroundColor = [UIColor clearColor];
        _variantLabel.font = TGSystemFontOfSize(17.0f);
        _variantLabel.textColor = UIColorRGB(0x8e8e93);
        [self addSubview:_variantLabel];
        
        _arrowView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 8.0f, 14.0f)];
        [self addSubview:_arrowView];

        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.hidden = true;
        [self addSubview:_iconView];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
    _titleLabel.textColor = brandedIOS6Style ? UIColorRGB(0x000000) : presentation.pallete.collectionMenuTextColor;
    _variantLabel.textColor = brandedIOS6Style ? UIColorRGB(0x7f7f7f) : presentation.pallete.collectionMenuVariantColor;
    _separatorLayer.backgroundColor = presentation.pallete.collectionMenuSeparatorColor.CGColor;
    _arrowView.image = brandedIOS6Style ? [TGPresentation classicIOS6ResourceImage:@"MenuDisclosureIndicator"] : presentation.images.collectionMenuDisclosureIcon;
    _titleLabel.font = brandedIOS6Style ? TGBoldSystemFontOfSize(18.0f) : TGSystemFontOfSize(17.0f);
    _titleLabel.shadowColor = brandedIOS6Style ? UIColorRGBA(0x000000, 0.2f) : nil;
    _titleLabel.shadowOffset = brandedIOS6Style ? CGSizeMake(0.0f, 1.0f) : CGSizeZero;
    _variantLabel.font = TGSystemFontOfSize(brandedIOS6Style ? 14.0f : 17.0f);
    self.classicIOS6HorizontalInset = 9.0f;
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

- (void)setIconName:(NSString *)iconName
{
    _iconView.image = iconName.length == 0 ? nil : ([TGPresentation brandedIOS6Style] ? [TGPresentation brandedIOS6ResourceImage:iconName] : [TGPresentation brandedIOS6ResourceImage:iconName]);
    _iconView.hidden = ![TGPresentation brandedIOS6Style] || _iconView.image == nil;
    [self setNeedsLayout];
}

- (void)setVariantImage:(UIImage *)variantImage
{
    if (variantImage != nil)
    {
        if (_variantImageView == nil)
        {
            _variantImageView = [[UIImageView alloc] init];
            [self addSubview:_variantImageView];
        }
        _variantImageView.image = variantImage;
        [_variantImageView sizeToFit];
        _variantImageView.hidden = false;
    }
    else
        _variantImageView.hidden = true;
    
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    
    CGFloat separatorHeight = TGScreenPixel;
    CGFloat separatorInset = ([TGPresentation brandedIOS6Style] ? 0.0f : 15.0f) + self.safeAreaInset.left;
    _separatorLayer.hidden = [TGPresentation brandedIOS6Style];
    _separatorLayer.frame = CGRectMake(separatorInset, bounds.size.height - separatorHeight, bounds.size.width - separatorInset, separatorHeight);
    
    CGFloat leftPadding = ([TGPresentation brandedIOS6Style] ? 50.0f : 15.0f + TGScreenPixel) + self.safeAreaInset.left;
    
    CGSize titleSize = [_titleLabel sizeThatFits:CGSizeMake(bounds.size.width - leftPadding - self.safeAreaInset.right - 10.0f, CGFLOAT_MAX)];
    CGFloat titleHeight = MAX(titleSize.height, ceilf(_titleLabel.font.lineHeight));
    _titleLabel.frame = CGRectMake(leftPadding, CGFloor((bounds.size.height - titleHeight) / 2.0f), titleSize.width, titleHeight);
    
    CGSize variantSize = [_variantLabel sizeThatFits:CGSizeMake(bounds.size.width - leftPadding - self.safeAreaInset.right - 10.0f, CGFLOAT_MAX)];
    CGFloat variantHeight = MAX(variantSize.height, ceilf(_variantLabel.font.lineHeight));
    _variantLabel.frame = CGRectMake(bounds.size.width - 34.0f - variantSize.width - self.safeAreaInset.right, CGFloor((bounds.size.height - variantHeight) / 2.0f), variantSize.width, variantHeight);
    
    if (_variantImageView != nil)
    {
        _variantImageView.frame = CGRectMake(bounds.size.width - 34.0f - _variantImageView.frame.size.width - self.safeAreaInset.right, CGFloor((bounds.size.height - _variantImageView.frame.size.height) / 2.0f), _variantImageView.frame.size.width, _variantImageView.frame.size.height);
    }
    
    CGSize arrowSize = _arrowView.bounds.size;
    _arrowView.frame = CGRectMake(bounds.size.width - 15.0f - arrowSize.width - self.safeAreaInset.right, CGFloor((bounds.size.height - arrowSize.height) / 2.0f), arrowSize.width, arrowSize.height);
    if ([TGPresentation brandedIOS6Style])
    {
        if (_iconView.image != nil)
        {
            _iconView.contentMode = UIViewContentModeScaleAspectFit;
            _iconView.frame = CGRectMake(17.0f + self.safeAreaInset.left, CGFloor((bounds.size.height - 16.0f) / 2.0f) + 1.0f, 16.0f, 16.0f);
            _iconView.layer.shadowColor = [UIColor blackColor].CGColor;
            _iconView.layer.shadowOpacity = 0.1f;
            _iconView.layer.shadowRadius = 0.5f;
            _iconView.layer.shadowOffset = CGSizeMake(0.0f, 1.0f);
        }
        _arrowView.image = [TGPresentation classicIOS6ResourceImage:@"MenuDisclosureIndicator"];
        _arrowView.frame = CGRectMake(bounds.size.width - 23.0f - self.safeAreaInset.right - 8.0f, CGFloor((bounds.size.height - 14.0f) / 2.0f) + 1.0f, 8.0f, 14.0f);
        CGFloat variantRightEdge = CGRectGetMinX(_arrowView.frame) - 8.0f;
        if (_variantImageView != nil && !_variantImageView.hidden)
        {
            _variantImageView.frame = CGRectMake(variantRightEdge - _variantImageView.frame.size.width, CGFloor((bounds.size.height - _variantImageView.frame.size.height) / 2.0f), _variantImageView.frame.size.width, _variantImageView.frame.size.height);
            variantRightEdge = CGRectGetMinX(_variantImageView.frame) - 8.0f;
        }
        else
        {
            CGFloat brandedVariantHeight = MAX(variantSize.height, ceilf(_variantLabel.font.lineHeight));
            _variantLabel.frame = CGRectMake(variantRightEdge - variantSize.width, CGFloor((bounds.size.height - brandedVariantHeight) / 2.0f) + 1.0f, variantSize.width, brandedVariantHeight);
            variantRightEdge = CGRectGetMinX(_variantLabel.frame) - 8.0f;
        }
        _titleLabel.frame = CGRectMake(43.0f + self.safeAreaInset.left, 7.0f, MAX(0.0f, variantRightEdge - 43.0f - self.safeAreaInset.left), 22.0f);
    }
}

@end
