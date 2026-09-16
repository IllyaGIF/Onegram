#import "TGVersionCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "TGAppDelegate.h"
#import "TGPresentation.h"

@interface TGVersionCollectionItemView ()
{
    UILabel *_titleLabel;
    UILabel *_versionLabel;
}
@end

@implementation TGVersionCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGMediumSystemFontOfSize(14);
        _titleLabel.numberOfLines = 1;
        _titleLabel.text = TGAppDelegateInstance.applicationName;
        _titleLabel.textColor = UIColorRGB(0x6d6d72);
        [self addSubview:_titleLabel];
        [_titleLabel sizeToFit];
        
        _versionLabel = [[UILabel alloc] init];
        _versionLabel.backgroundColor = [UIColor clearColor];
        _versionLabel.font = TGSystemFontOfSize(14);
        _versionLabel.numberOfLines = 1;
        _versionLabel.textColor = UIColorRGB(0x6d6d72);
        [self addSubview:_versionLabel];
    }
    return self;
}


- (void)setVersion:(NSString *)version
{
    _versionLabel.text = version;
    [_versionLabel sizeToFit];
    _versionLabel.frame = CGRectMake(_versionLabel.frame.origin.x, _versionLabel.frame.origin.y, ceil(_versionLabel.frame.size.width), ceil(_versionLabel.frame.size.height));
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if ([TGPresentation brandedIOS6Style])
    {
        _titleLabel.font = TGBoldSystemFontOfSize(11.0f);
        _titleLabel.textColor = UIColorRGB(0x717171);
        _titleLabel.shadowColor = UIColorRGBA(0xffffff, 0.8f);
        _titleLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        [_titleLabel sizeToFit];
        _versionLabel.font = TGSystemFontOfSize(11.0f);
        _versionLabel.textColor = UIColorRGB(0x717171);
        _versionLabel.shadowColor = UIColorRGBA(0xffffff, 0.8f);
        _versionLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        [_versionLabel sizeToFit];
        CGFloat startingY = 14.0f;
        _titleLabel.frame = CGRectMake(ceil((self.frame.size.width - _titleLabel.frame.size.width) / 2.0f), startingY, _titleLabel.frame.size.width, _titleLabel.frame.size.height);
        _versionLabel.frame = CGRectMake(ceil((self.frame.size.width - _versionLabel.frame.size.width) / 2.0f), CGRectGetMaxY(_titleLabel.frame) + 2.0f, _versionLabel.frame.size.width, _versionLabel.frame.size.height);
        return;
    }

    CGFloat startingY = CGCeil((self.frame.size.height + 35.0f - _titleLabel.frame.size.height - _versionLabel.frame.size.height - 2.0f) / 2.0f);
    _titleLabel.frame = CGRectMake(ceil((self.frame.size.width - _titleLabel.frame.size.width) / 2.0f), startingY, _titleLabel.frame.size.width, _titleLabel.frame.size.height);
    _versionLabel.frame = CGRectMake(ceil((self.frame.size.width - _versionLabel.frame.size.width) / 2.0f), CGRectGetMaxY(_titleLabel.frame) + 2.0f, _versionLabel.frame.size.width, _versionLabel.frame.size.height);
}

@end
