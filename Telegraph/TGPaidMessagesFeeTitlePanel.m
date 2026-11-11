#import "TGPaidMessagesFeeTitlePanel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"

#import "TGPresentation.h"
#import "TGPaidMessagesSignals.h"

@interface TGPaidMessagesFeeTitlePanel ()
{
    CALayer *_stripeLayer;
    UIView *_backgroundView;
    UILabel *_titleLabel;
    TGModernButton *_actionButton;
}

@end

@implementation TGPaidMessagesFeeTitlePanel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, 54.0f)];
    if (self)
    {
        _backgroundView = [TGBackdropView viewWithLightNavigationBarStyle];
        [self addSubview:_backgroundView];

        _stripeLayer = [[CALayer alloc] init];
        _stripeLayer.backgroundColor = UIColorRGB(0xb2b2b2).CGColor;
        [self.layer addSublayer:_stripeLayer];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(13);
        _titleLabel.textColor = UIColorRGB(0x8e8e93);
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_titleLabel];

        _actionButton = [[TGModernButton alloc] init];
        _actionButton.adjustsImageWhenDisabled = false;
        _actionButton.adjustsImageWhenHighlighted = false;
        [_actionButton setTitleColor:TGAccentColor()];
        _actionButton.titleLabel.font = TGSystemFontOfSize(15);
        [_actionButton setTitle:TGLocalized(@"PaidMessages.RemoveFee") forState:UIControlStateNormal];
        [_actionButton addTarget:self action:@selector(actionButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_actionButton];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];

    _backgroundView.backgroundColor = presentation.pallete.barBackgroundColor;
    _stripeLayer.backgroundColor = presentation.pallete.barSeparatorColor.CGColor;
    _titleLabel.textColor = presentation.pallete.secondaryTextColor;
    [_actionButton setTitleColor:presentation.pallete.navigationButtonColor];
}

- (void)setUserName:(NSString *)userName stars:(int64_t)stars
{
    _titleLabel.text = [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.FeePanelTitle"), userName ?: @"", [TGPaidMessagesSignals starsString:stars]];
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    _backgroundView.frame = self.bounds;
    _stripeLayer.frame = CGRectMake(0.0f, self.frame.size.height - TGScreenPixel, self.frame.size.width, TGScreenPixel);
    CGFloat left = 12.0f + self.safeAreaInset.left;
    CGFloat width = self.frame.size.width - left - 12.0f - self.safeAreaInset.right;
    _titleLabel.frame = CGRectMake(left, 6.0f, width, 18.0f);
    _actionButton.frame = CGRectMake(left, 24.0f, width, 28.0f);
}

- (void)actionButtonPressed
{
    if (_removeFeePressed)
        _removeFeePressed();
}

@end
