#import "TGUserInfoButtonCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"

@interface TGUserInfoButtonCollectionItemView ()
{
    CALayer *_separatorLayer;
    
    UILabel *_titleLabel;
    UIImageView *_iconView;
    UIImageView *_arrowView;
}

@end

@implementation TGUserInfoButtonCollectionItemView

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
        [self addSubview:_titleLabel];

        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.hidden = true;
        [self addSubview:_iconView];

        _arrowView = [[UIImageView alloc] init];
        _arrowView.hidden = true;
        [self addSubview:_arrowView];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
    _separatorLayer.backgroundColor = presentation.pallete.collectionMenuSeparatorColor.CGColor;
    _titleLabel.font = brandedIOS6Style ? TGBoldSystemFontOfSize(18.0f) : TGSystemFontOfSize(17.0f);
    _titleLabel.textColor = brandedIOS6Style ? UIColorRGB(0x000000) : presentation.pallete.collectionMenuTextColor;
    _titleLabel.shadowColor = brandedIOS6Style ? UIColorRGBA(0x000000, 0.2f) : nil;
    _titleLabel.shadowOffset = brandedIOS6Style ? CGSizeMake(0.0f, 1.0f) : CGSizeZero;
    self.classicIOS6HorizontalInset = 9.0f;
    _arrowView.image = brandedIOS6Style ? [TGPresentation classicIOS6ResourceImage:@"MenuDisclosureIndicator"] : presentation.images.collectionMenuDisclosureIcon;
    _arrowView.hidden = !brandedIOS6Style;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
    [self setNeedsLayout];
}

- (void)setTitleColor:(UIColor *)titleColor
{
    _titleLabel.textColor = titleColor;
}

- (void)setIconName:(NSString *)iconName
{
    _iconView.image = iconName.length == 0 ? nil : ([TGPresentation brandedIOS6Style] ? [TGPresentation brandedIOS6ResourceImage:iconName] : [TGPresentation brandedIOS6ResourceImage:iconName]);
    _iconView.hidden = ![TGPresentation brandedIOS6Style] || _iconView.image == nil;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    
    CGFloat separatorHeight = TGScreenPixel;
    CGFloat separatorInset = ([TGPresentation brandedIOS6Style] ? 0.0f : (_editing ? 15.0f : 15.0f)) + self.safeAreaInset.left;
    _separatorLayer.hidden = [TGPresentation brandedIOS6Style];
    _separatorLayer.frame = CGRectMake(separatorInset, bounds.size.height - separatorHeight, bounds.size.width - separatorInset, separatorHeight);
    
    CGFloat leftPadding = ([TGPresentation brandedIOS6Style] ? 50.0f : 15.0f + TGScreenPixel) + self.safeAreaInset.left;
    
    CGSize titleSize = [_titleLabel sizeThatFits:CGSizeMake(bounds.size.width - leftPadding - 30.0f - self.safeAreaInset.right, CGFLOAT_MAX)];
    CGFloat titleHeight = MAX(titleSize.height, ceilf(_titleLabel.font.lineHeight));
    _titleLabel.frame = CGRectMake(leftPadding, CGFloor((bounds.size.height - titleHeight) / 2.0f), titleSize.width, titleHeight);
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
        _titleLabel.frame = CGRectMake(43.0f + self.safeAreaInset.left, 7.0f, MAX(0.0f, CGRectGetMinX(_arrowView.frame) - 51.0f - self.safeAreaInset.left), 22.0f);
    }
}

@end
