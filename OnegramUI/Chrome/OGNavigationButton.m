#import "OGNavigationButton.h"
#import "../Core/OGTheme.h"
#import "../Core/OGTypography.h"
#import "../Core/OGNavigationAppearance.h"

@implementation OGNavigationButton
- (void)applyTheme
{
    [super applyTheme];
    OGNavigationAppearance *appearance = self.theme.navigationAppearance;
    self.titleLabel.font = appearance.buttonFont;
    [self setTitleColor:appearance.buttonTitleColor forState:UIControlStateNormal];
    [self setTitleColor:[appearance.buttonTitleColor colorWithAlphaComponent:appearance.buttonHighlightedAlpha] forState:UIControlStateHighlighted];
    self.titleLabel.shadowColor = appearance.buttonShadowColor;
    self.titleLabel.shadowOffset = CGSizeMake(appearance.buttonShadowOffset.horizontal, appearance.buttonShadowOffset.vertical);
}
@end
