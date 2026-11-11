#import "TGDialogFilterCategoryCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"

@interface TGDialogFilterCategoryCollectionItemView ()
{
    UIImageView *_iconView;
    UILabel *_titleLabel;
    UIImageView *_checkView;
}

@end

@implementation TGDialogFilterCategoryCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _iconView = [[UIImageView alloc] init];
        [self.editingContentView addSubview:_iconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        [self.editingContentView addSubview:_titleLabel];

        _checkView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 14.0f, 11.0f)];
        _checkView.hidden = true;
        [self.editingContentView addSubview:_checkView];

        [self setIndicatorMode:TGEditableCollectionItemViewIndicatorDelete];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        self.separatorInset = 65.0f;
#endif
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];

    _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
    _checkView.image = presentation.images.collectionMenuCheckImage;
}

- (void)setTitle:(NSString *)title icon:(UIImage *)icon
{
    _titleLabel.text = title;
    _iconView.image = icon;
    [self setNeedsLayout];
}

- (void)setDisplayCheck:(bool)displayCheck checkIsOn:(bool)checkIsOn
{
    _checkView.hidden = !(displayCheck && checkIsOn);
}

- (void)deleteAction
{
    if (_deletePressed)
        _deletePressed();
}

- (void)layoutSubviews
{
    CGFloat leftInset = (self.showsDeleteIndicator ? 38.0f : 0.0f) + self.safeAreaInset.left;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    self.separatorInset = 65.0f + leftInset;
#endif

    [super layoutSubviews];

    CGRect bounds = self.bounds;
    _iconView.frame = CGRectMake(leftInset + 15.0f, CGFloor((bounds.size.height - 30.0f) / 2.0f), 30.0f, 30.0f);
    CGFloat rightInset = 15.0f + self.safeAreaInset.right + (_checkView.hidden ? 0.0f : 22.0f);
    _titleLabel.frame = CGRectMake(leftInset + 65.0f, CGFloor((bounds.size.height - 22.0f) / 2.0f), MAX(0.0f, bounds.size.width - leftInset - 65.0f - rightInset), 22.0f);
    CGSize checkSize = _checkView.frame.size;
    _checkView.frame = CGRectMake(bounds.size.width - 15.0f - checkSize.width - self.safeAreaInset.right, CGFloor((bounds.size.height - checkSize.height) / 2.0f), checkSize.width, checkSize.height);
}

@end
