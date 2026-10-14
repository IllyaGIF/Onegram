#import "OGSectionHeader.h"
#import "../Base/OGLabel.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
#import "../Core/OGTypography.h"

@implementation OGSectionHeader
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _titleLabel = [[OGLabel alloc] initWithFrame:CGRectZero];
        [self addSubview:_titleLabel];
        [self applyTheme];
    }
    return self;
}

- (void)applyTheme
{
    [super applyTheme];
    _titleLabel.theme = self.theme;
    _titleLabel.font = self.theme.typography.sectionHeaderFont;
    _titleLabel.textColor = self.theme.palette.secondaryTextColor;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _titleLabel.frame = CGRectInset(self.bounds, 12.0f, 0.0f);
}
@end
