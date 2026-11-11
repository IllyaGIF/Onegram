#import "TGDialogFilterCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"

#import "TGPresentation.h"

@interface TGDialogFilterCollectionItemView ()
{
    UIImageView *_iconView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIImageView *_disclosureView;
    UIImageView *_reorderingControl;
    TGModernButton *_addButton;
    bool _showsDisclosure;
    bool _requestedDeleteIndicator;
}

@end

@implementation TGDialogFilterCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeCenter;
        [self.editingContentView addSubview:_iconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        [self.editingContentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.font = TGSystemFontOfSize(13.0f);
        [self.editingContentView addSubview:_subtitleLabel];

        _disclosureView = [[UIImageView alloc] init];
        _disclosureView.hidden = true;
        [self.editingContentView addSubview:_disclosureView];

        _reorderingControl = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 22.0f, 9.0f)];
        _reorderingControl.alpha = 0.0f;
        [self.contentView addSubview:_reorderingControl];

        [self setIndicatorMode:TGEditableCollectionItemViewIndicatorDelete];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];

    _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
    _subtitleLabel.textColor = presentation.pallete.collectionMenuVariantColor;
    _disclosureView.image = presentation.images.collectionMenuDisclosureIcon;
    [_disclosureView sizeToFit];
    _reorderingControl.image = presentation.images.collectionMenuReorderIcon;
    [_addButton setBackgroundColor:presentation.pallete.collectionMenuAccentColor];
}

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon
{
    _titleLabel.text = title;
    _subtitleLabel.text = subtitle;
    _subtitleLabel.hidden = subtitle.length == 0;
    _iconView.image = icon;
    _iconView.hidden = icon == nil;
    [self setNeedsLayout];
}

- (void)setShowsDisclosure:(bool)showsDisclosure
{
    _showsDisclosure = showsDisclosure;
    _disclosureView.hidden = !showsDisclosure;
    [self setNeedsLayout];
}

- (void)setAddButtonTitle:(NSString *)addButtonTitle
{
    if (addButtonTitle.length == 0)
    {
        [_addButton removeFromSuperview];
        _addButton = nil;
        [self setNeedsLayout];
        return;
    }
    if (_addButton == nil)
    {
        _addButton = [[TGModernButton alloc] init];
        _addButton.titleLabel.font = TGBoldSystemFontOfSize(13.0f);
        [_addButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _addButton.backgroundColor = self.presentation.pallete.collectionMenuAccentColor;
        _addButton.layer.cornerRadius = 14.0f;
        _addButton.clipsToBounds = true;
        _addButton.modernHighlight = true;
        _addButton.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 12.0f, 0.0f, 12.0f);
        [_addButton addTarget:self action:@selector(addButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self.editingContentView addSubview:_addButton];
    }
    [_addButton setTitle:addButtonTitle forState:UIControlStateNormal];
    [self setNeedsLayout];
}

- (void)setShowsDeleteIndicator:(bool)showsDeleteIndicator animated:(bool)animated
{
    _requestedDeleteIndicator = showsDeleteIndicator;
    [super setShowsDeleteIndicator:showsDeleteIndicator && self.enableEditing animated:animated];
}

- (void)setEnableEditing:(bool)enableEditing animated:(bool)animated
{
    [super setEnableEditing:enableEditing animated:animated];
    [super setShowsDeleteIndicator:_requestedDeleteIndicator && enableEditing animated:animated];
}

- (void)addButtonPressed
{
    if (_addPressed)
        _addPressed();
}

- (void)deleteAction
{
    if (_deletePressed)
        _deletePressed();
}

- (void)layoutSubviews
{
    CGFloat leftInset = (self.showsDeleteIndicator ? 38.0f : 0.0f) + self.safeAreaInset.left;
    CGFloat rightInset = (self.showsDeleteIndicator ? 38.0f : 0.0f) + self.safeAreaInset.right;
    bool hasIcon = _iconView.image != nil;
    CGFloat contentX = leftInset + (hasIcon ? 60.0f : 15.0f);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    self.separatorInset = contentX;
#endif

    [super layoutSubviews];

    CGRect bounds = self.bounds;
    _iconView.frame = CGRectMake(leftInset + 15.0f, CGFloor((bounds.size.height - 30.0f) / 2.0f), 30.0f, 30.0f);

    CGFloat accessoryWidth = 15.0f;
    if (_addButton != nil)
    {
        CGSize buttonSize = [_addButton sizeThatFits:CGSizeMake(200.0f, 28.0f)];
        CGFloat buttonWidth = MAX(64.0f, buttonSize.width);
        _addButton.frame = CGRectMake(bounds.size.width - rightInset - 15.0f - buttonWidth, CGFloor((bounds.size.height - 28.0f) / 2.0f), buttonWidth, 28.0f);
        accessoryWidth = buttonWidth + 27.0f;
    }
    else if (_showsDisclosure && !self.showsDeleteIndicator)
    {
        CGSize disclosureSize = _disclosureView.frame.size;
        _disclosureView.frame = CGRectMake(bounds.size.width - rightInset - 15.0f - disclosureSize.width, CGFloor((bounds.size.height - disclosureSize.height) / 2.0f), disclosureSize.width, disclosureSize.height);
        accessoryWidth = disclosureSize.width + 27.0f;
    }
    _disclosureView.alpha = self.showsDeleteIndicator ? 0.0f : 1.0f;

    CGFloat availableWidth = MAX(0.0f, bounds.size.width - contentX - rightInset - accessoryWidth);
    CGSize titleSize = [_titleLabel.text sizeWithFont:_titleLabel.font];
    CGSize subtitleSize = _subtitleLabel.hidden ? CGSizeZero : [_subtitleLabel.text sizeWithFont:_subtitleLabel.font];
    CGFloat spacing = _subtitleLabel.hidden ? 0.0f : 2.0f;
    CGFloat originY = CGFloor((bounds.size.height - titleSize.height - subtitleSize.height - spacing) / 2.0f);
    _titleLabel.frame = CGRectMake(contentX, originY, MIN(availableWidth, CGCeil(titleSize.width)), CGCeil(titleSize.height));
    _subtitleLabel.frame = CGRectMake(contentX, originY + CGCeil(titleSize.height) + spacing, MIN(availableWidth, CGCeil(subtitleSize.width)), CGCeil(subtitleSize.height));

    _reorderingControl.alpha = self.showsDeleteIndicator && self.boundItem.canBeMovedToSectionAtIndex != nil ? 1.0f : 0.0f;
    _reorderingControl.frame = CGRectMake(self.contentView.frame.size.width - 15.0f - _reorderingControl.frame.size.width - self.safeAreaInset.right, CGFloor((self.contentView.frame.size.height - _reorderingControl.frame.size.height) / 2.0f), _reorderingControl.frame.size.width, _reorderingControl.frame.size.height);
}

@end
