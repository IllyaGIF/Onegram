#import "TGSettingsAccountCollectionItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"

#import "TGCollectionItemView.h"
#import "../OnegramPlatform/OGPlatformText.h"
#import "TGPresentation.h"
#import "TGAccountManager.h"
#import "TGAccountSwitcherPanel.h"

static const CGFloat TGSettingsAccountAvatarSide = 30.0f;

@interface TGSettingsAccountCollectionItemView : TGCollectionItemView
{
    TGLetteredAvatarView *_avatarView;
    UIImageView *_addIconView;
    UILabel *_titleLabel;
    UIImageView *_disclosureView;
    NSString *_accountId;
}

- (void)setAccount:(TGAccountRecord *)account;

@end

@implementation TGSettingsAccountCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, TGSettingsAccountAvatarSide, TGSettingsAccountAvatarSide)];
        [_avatarView setSingleFontSize:13.0f doubleFontSize:13.0f useBoldFont:true];
        _avatarView.userInteractionEnabled = false;
        [self addSubview:_avatarView];

        _addIconView = [[UIImageView alloc] init];
        _addIconView.contentMode = UIViewContentModeCenter;
        [self addSubview:_addIconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_titleLabel];

        _disclosureView = [[UIImageView alloc] init];
        [self addSubview:_disclosureView];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        self.separatorInset = 59.0f;
#endif
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    _addIconView.image = presentation.images.collectionMenuAddImage;
    _disclosureView.image = presentation.images.collectionMenuDisclosureIcon;
    [_disclosureView sizeToFit];
    _titleLabel.textColor = _accountId == nil ? presentation.pallete.collectionMenuAccentColor : presentation.pallete.collectionMenuTextColor;
    [self setNeedsLayout];
}

- (void)setAccount:(TGAccountRecord *)account
{
    _accountId = account.accountId;
    _avatarView.hidden = account == nil;
    _addIconView.hidden = account != nil;
    _titleLabel.text = account == nil ? TGLocalized(@"Accounts.AddAccount") : [account displayName];
    _titleLabel.textColor = account == nil ? self.presentation.pallete.collectionMenuAccentColor : self.presentation.pallete.collectionMenuTextColor;
    if (account != nil)
    {
        CGSize avatarSize = CGSizeMake(TGSettingsAccountAvatarSide, TGSettingsAccountAvatarSide);
        [_avatarView loadUserPlaceholderWithSize:avatarSize uid:account.userId firstName:account.firstName lastName:account.lastName placeholder:[self.presentation.images avatarPlaceholderWithDiameter:TGSettingsAccountAvatarSide]];

        NSString *path = [[TGAccountManager instance] avatarPathForAccount:account];
        NSString *accountId = account.accountId;
        __weak TGSettingsAccountCollectionItemView *weakSelf = self;
        if (path != nil)
        {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
            {
                UIImage *image = [[NSFileManager defaultManager] fileExistsAtPath:path] ? TGAccountAvatarCircularImage(path, TGSettingsAccountAvatarSide) : nil;
                if (image == nil)
                    return;
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    __strong TGSettingsAccountCollectionItemView *strongSelf = weakSelf;
                    if (strongSelf != nil && [strongSelf->_accountId isEqualToString:accountId])
                        [strongSelf->_avatarView loadImage:image];
                });
            });
        }
    }
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    CGFloat iconCenterX = 29.0f + self.safeAreaInset.left;
    _avatarView.frame = CGRectMake(CGFloor(iconCenterX - TGSettingsAccountAvatarSide / 2.0f), CGFloor((bounds.size.height - TGSettingsAccountAvatarSide) / 2.0f), TGSettingsAccountAvatarSide, TGSettingsAccountAvatarSide);
    _addIconView.frame = _avatarView.frame;
    CGSize disclosureSize = _disclosureView.frame.size;
    _disclosureView.frame = CGRectMake(bounds.size.width - 15.0f - self.safeAreaInset.right - disclosureSize.width, CGFloor((bounds.size.height - disclosureSize.height) / 2.0f), disclosureSize.width, disclosureSize.height);
    CGFloat titleLeft = 59.0f + self.safeAreaInset.left;
    CGFloat titleHeight = CGCeil(OGPlatformFontLineHeight(_titleLabel.font));
    _titleLabel.frame = CGRectMake(titleLeft, CGFloor((bounds.size.height - titleHeight) / 2.0f), MAX(0.0f, CGRectGetMinX(_disclosureView.frame) - 8.0f - titleLeft), titleHeight);
}

@end

@implementation TGSettingsAccountCollectionItem

- (instancetype)initWithAccount:(TGAccountRecord *)account
{
    self = [super init];
    if (self != nil)
    {
        _account = account;
        self.selectable = true;
        self.highlightable = true;
        self.deselectAutomatically = true;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGSettingsAccountCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 48.0f);
}

- (void)bindView:(TGSettingsAccountCollectionItemView *)view
{
    [super bindView:view];
    [view setAccount:_account];
}

- (void)itemSelected:(id)__unused actionTarget
{
    if (_pressed != nil)
        _pressed();
}

@end
