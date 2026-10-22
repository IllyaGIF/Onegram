#import "TGAccountSwitcherPanel.h"

#import <QuartzCore/QuartzCore.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGPhoneUtils.h"
#import "../OnegramPlatform/OGPlatformGraphics.h"

#import "TGAccountManager.h"
#import "TGAccountSwitcher.h"
#import "TGPresentation.h"

static const CGFloat TGAccountSwitcherPanelRowHeight = 60.0f;
static const CGFloat TGAccountSwitcherPanelAvatarSize = 40.0f;
static const CGFloat TGAccountSwitcherPanelSideInset = 8.0f;
static const CGFloat TGAccountSwitcherPanelMaxWidth = 420.0f;
static const CGFloat TGAccountSwitcherPanelCornerRadius = 12.0f;

static UIImage *TGAccountSwitcherPanelCircularImage(NSString *path, CGFloat diameter)
{
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
    if (image == nil || image.size.width < 1.0f || image.size.height < 1.0f)
        return nil;

    CGSize size = CGSizeMake(diameter, diameter);
    CGFloat scale = MAX(size.width / image.size.width, size.height / image.size.height);
    CGSize drawSize = CGSizeMake(image.size.width * scale, image.size.height * scale);

    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextAddEllipseInRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    CGContextClip(context);
    [image drawInRect:CGRectMake((size.width - drawSize.width) / 2.0f, (size.height - drawSize.height) / 2.0f, drawSize.width, drawSize.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@interface TGAccountSwitcherPanelRow : UIControl
{
    UIView *_highlightView;
    TGLetteredAvatarView *_avatarView;
    UIImageView *_addIconView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIImageView *_checkView;
    UIView *_separatorView;
}

@property (nonatomic, strong, readonly) TGAccountRecord *account;

- (instancetype)initWithAccount:(TGAccountRecord *)account active:(bool)active presentation:(TGPresentation *)presentation;
- (instancetype)initAddRowWithPresentation:(TGPresentation *)presentation;
- (void)setSeparatorHidden:(bool)hidden;
- (void)setAvatarImage:(UIImage *)image;

@end

@implementation TGAccountSwitcherPanelRow

- (instancetype)initWithPresentation:(TGPresentation *)presentation
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.isAccessibilityElement = true;
        self.accessibilityTraits = UIAccessibilityTraitButton;

        _highlightView = [[UIView alloc] init];
        _highlightView.backgroundColor = presentation.pallete.collectionMenuCellSelectionColor;
        _highlightView.userInteractionEnabled = false;
        _highlightView.hidden = true;
        [self addSubview:_highlightView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGMediumSystemFontOfSize(16.0f);
        _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
        _titleLabel.userInteractionEnabled = false;
        [self addSubview:_titleLabel];

        _separatorView = [[UIView alloc] init];
        _separatorView.backgroundColor = presentation.pallete.collectionMenuSeparatorColor;
        _separatorView.userInteractionEnabled = false;
        [self addSubview:_separatorView];
    }
    return self;
}

- (instancetype)initWithAccount:(TGAccountRecord *)account active:(bool)active presentation:(TGPresentation *)presentation
{
    self = [self initWithPresentation:presentation];
    if (self != nil)
    {
        _account = account;

        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, TGAccountSwitcherPanelAvatarSize, TGAccountSwitcherPanelAvatarSize)];
        [_avatarView setSingleFontSize:18.0f doubleFontSize:18.0f useBoldFont:true];
        _avatarView.fadeTransition = true;
        _avatarView.userInteractionEnabled = false;
        [_avatarView loadUserPlaceholderWithSize:CGSizeMake(TGAccountSwitcherPanelAvatarSize, TGAccountSwitcherPanelAvatarSize) uid:account.userId firstName:account.firstName lastName:account.lastName placeholder:[presentation.images avatarPlaceholderWithDiameter:TGAccountSwitcherPanelAvatarSize]];
        [self addSubview:_avatarView];

        _titleLabel.text = [account displayName];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.font = TGSystemFontOfSize(14.0f);
        _subtitleLabel.textColor = presentation.pallete.collectionMenuVariantColor;
        _subtitleLabel.userInteractionEnabled = false;
        _subtitleLabel.text = account.phoneNumber.length == 0 ? @"" : [TGPhoneUtils formatPhone:account.phoneNumber forceInternational:true];
        [self addSubview:_subtitleLabel];

        if (active)
        {
            _checkView = [[UIImageView alloc] initWithImage:presentation.images.collectionMenuCheckImage];
            _checkView.userInteractionEnabled = false;
            [self addSubview:_checkView];
            self.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitSelected;
        }

        self.accessibilityLabel = _subtitleLabel.text.length == 0 ? _titleLabel.text : [[NSString alloc] initWithFormat:@"%@, %@", _titleLabel.text, _subtitleLabel.text];
    }
    return self;
}

- (instancetype)initAddRowWithPresentation:(TGPresentation *)presentation
{
    self = [self initWithPresentation:presentation];
    if (self != nil)
    {
        _addIconView = [[UIImageView alloc] initWithImage:presentation.images.collectionMenuAddImage];
        _addIconView.contentMode = UIViewContentModeCenter;
        _addIconView.userInteractionEnabled = false;
        [self addSubview:_addIconView];

        _titleLabel.font = TGSystemFontOfSize(16.0f);
        _titleLabel.textColor = presentation.pallete.collectionMenuAccentColor;
        _titleLabel.text = TGLocalized(@"Accounts.AddAccount");
        self.accessibilityLabel = _titleLabel.text;
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    _highlightView.hidden = !highlighted;
}

- (void)setSeparatorHidden:(bool)hidden
{
    _separatorView.hidden = hidden;
}

- (void)setAvatarImage:(UIImage *)image
{
    if (image != nil)
        [_avatarView loadImage:image];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    CGFloat separatorHeight = 1.0f / MAX(1.0f, [UIScreen mainScreen].scale);
    CGFloat iconX = 14.0f;
    CGFloat textX = iconX + TGAccountSwitcherPanelAvatarSize + 12.0f;
    CGFloat rightInset = 14.0f;

    _highlightView.frame = bounds;

    CGRect iconFrame = CGRectMake(iconX, CGFloor((bounds.size.height - TGAccountSwitcherPanelAvatarSize) / 2.0f), TGAccountSwitcherPanelAvatarSize, TGAccountSwitcherPanelAvatarSize);
    _avatarView.frame = iconFrame;
    _addIconView.frame = iconFrame;

    if (_checkView != nil)
    {
        CGSize checkSize = _checkView.image.size;
        _checkView.frame = CGRectMake(bounds.size.width - rightInset - checkSize.width, CGFloor((bounds.size.height - checkSize.height) / 2.0f), checkSize.width, checkSize.height);
        rightInset += checkSize.width + 10.0f;
    }

    CGFloat textWidth = MAX(0.0f, bounds.size.width - textX - rightInset);
    if (_subtitleLabel != nil)
    {
        _titleLabel.frame = CGRectMake(textX, 10.0f, textWidth, 21.0f);
        _subtitleLabel.frame = CGRectMake(textX, 31.0f, textWidth, 18.0f);
    }
    else
    {
        _titleLabel.frame = CGRectMake(textX, CGFloor((bounds.size.height - 21.0f) / 2.0f), textWidth, 21.0f);
    }

    _separatorView.frame = CGRectMake(textX, bounds.size.height - separatorHeight, bounds.size.width - textX, separatorHeight);
}

@end

@interface TGAccountSwitcherPanel () <UIGestureRecognizerDelegate>
{
    TGPresentation *_presentation;
    UIControl *_dimView;
    UIView *_cardView;
    UIScrollView *_contentView;
    NSArray *_rows;
    UIPanGestureRecognizer *_panRecognizer;
    bool _dismissing;
}

@end

@implementation TGAccountSwitcherPanel

+ (TGAccountSwitcherPanel *)presentInView:(UIView *)view
{
    if (view == nil)
        return nil;

    for (UIView *subview in view.subviews)
    {
        if ([subview isKindOfClass:[TGAccountSwitcherPanel class]])
            return (TGAccountSwitcherPanel *)subview;
    }

    [[TGAccountSwitcher instance] refreshActiveAccount];

    TGAccountSwitcherPanel *panel = [[TGAccountSwitcherPanel alloc] initWithFrame:view.bounds];
    [view addSubview:panel];
    [panel layoutIfNeeded];
    [panel animateIn];
    return panel;
}

+ (UIButton *)cancelAddingAccountButtonWithTarget:(id)target action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.titleLabel.font = TGSystemFontOfSize(17.0f);
    [button setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
    [button setTitleColor:TGAccentColor() forState:UIControlStateNormal];
    [button setTitleColor:[TGAccentColor() colorWithAlphaComponent:0.4f] forState:UIControlStateHighlighted];
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 8.0f, 0.0f, 8.0f);
    [button sizeToFit];
    button.frame = CGRectMake(0.0f, 0.0f, MAX(44.0f, button.frame.size.width), 44.0f);
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _presentation = [TGPresentation current];

        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.backgroundColor = [UIColor clearColor];

        _dimView = [[UIControl alloc] initWithFrame:self.bounds];
        _dimView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
        _dimView.isAccessibilityElement = true;
        _dimView.accessibilityLabel = TGLocalized(@"Common.Close");
        _dimView.accessibilityTraits = UIAccessibilityTraitButton;
        [_dimView addTarget:self action:@selector(dimPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_dimView];

        _cardView = [[UIView alloc] init];
        _cardView.backgroundColor = [UIColor clearColor];
        [self addSubview:_cardView];

        _contentView = [[UIScrollView alloc] init];
        _contentView.backgroundColor = _presentation.pallete.collectionMenuCellBackgroundColor;
        _contentView.layer.cornerRadius = TGAccountSwitcherPanelCornerRadius;
        _contentView.clipsToBounds = true;
        _contentView.alwaysBounceVertical = false;
        _contentView.showsHorizontalScrollIndicator = false;
        [_cardView addSubview:_contentView];

        _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
        _panRecognizer.delegate = self;
        [_cardView addGestureRecognizer:_panRecognizer];

        [self reloadRows];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountsDidChange:) name:TGAccountSwitcherAccountsDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)accountsDidChange:(NSNotification *)__unused notification
{
    if (_dismissing)
        return;
    [self reloadRows];
    [self setNeedsLayout];
}

- (void)reloadRows
{
    for (UIView *row in _rows)
        [row removeFromSuperview];

    TGAccountManager *manager = [TGAccountManager instance];
    TGAccountRecord *activeAccount = [manager activeAccount];

    NSMutableArray *accounts = [[NSMutableArray alloc] init];
    if (activeAccount.userId != 0)
        [accounts addObject:activeAccount];
    for (TGAccountRecord *account in [manager authorizedAccounts])
    {
        if (![account.accountId isEqualToString:activeAccount.accountId])
            [accounts addObject:account];
    }

    NSMutableArray *rows = [[NSMutableArray alloc] init];
    for (TGAccountRecord *account in accounts)
    {
        TGAccountSwitcherPanelRow *row = [[TGAccountSwitcherPanelRow alloc] initWithAccount:account active:[account.accountId isEqualToString:activeAccount.accountId] presentation:_presentation];
        [row addTarget:self action:@selector(rowPressed:) forControlEvents:UIControlEventTouchUpInside];
        [rows addObject:row];
        [self loadAvatarForRow:row];
    }

    TGAccountSwitcherPanelRow *addRow = [[TGAccountSwitcherPanelRow alloc] initAddRowWithPresentation:_presentation];
    [addRow addTarget:self action:@selector(addPressed) forControlEvents:UIControlEventTouchUpInside];
    [addRow setSeparatorHidden:true];
    [rows addObject:addRow];

    for (UIView *row in rows)
        [_contentView addSubview:row];
    _rows = rows;
}

- (void)loadAvatarForRow:(TGAccountSwitcherPanelRow *)row
{
    NSString *path = [[TGAccountManager instance] avatarPathForAccount:row.account];
    if (path == nil)
        return;

    __weak TGAccountSwitcherPanelRow *weakRow = row;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        if (![[NSFileManager defaultManager] fileExistsAtPath:path])
            return;

        UIImage *image = TGAccountSwitcherPanelCircularImage(path, TGAccountSwitcherPanelAvatarSize);
        if (image == nil)
            return;

        dispatch_async(dispatch_get_main_queue(), ^
        {
            [weakRow setAvatarImage:image];
        });
    });
}

- (CGFloat)topInset
{
    CGRect statusBarFrame = [self convertRect:[UIApplication sharedApplication].statusBarFrame fromView:nil];
    CGRect intersection = CGRectIntersection(statusBarFrame, self.bounds);
    if (CGRectIsNull(intersection) || intersection.size.width < 1.0f || intersection.size.height < 1.0f)
        return 0.0f;
    return MAX(0.0f, CGRectGetMaxY(intersection) - self.bounds.origin.y);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    _dimView.frame = bounds;

    CGFloat top = [self topInset] + TGAccountSwitcherPanelSideInset;
    CGFloat width = MIN(bounds.size.width - TGAccountSwitcherPanelSideInset * 2.0f, TGAccountSwitcherPanelMaxWidth);
    CGFloat contentHeight = _rows.count * TGAccountSwitcherPanelRowHeight;
    CGFloat height = MIN(contentHeight, MAX(TGAccountSwitcherPanelRowHeight, bounds.size.height - top - TGAccountSwitcherPanelSideInset));

    CGAffineTransform transform = _cardView.transform;
    _cardView.transform = CGAffineTransformIdentity;
    _cardView.frame = CGRectMake(CGFloor((bounds.size.width - width) / 2.0f), top, width, height);
    OGPlatformApplyRoundedViewShadow(_cardView, [UIColor blackColor], 0.25f, 10.0f, CGSizeMake(0.0f, 3.0f), TGAccountSwitcherPanelCornerRadius);
    _cardView.transform = transform;

    _contentView.frame = CGRectMake(0.0f, 0.0f, width, height);
    _contentView.contentSize = CGSizeMake(width, contentHeight);
    _contentView.scrollEnabled = contentHeight > height;

    CGFloat y = 0.0f;
    for (UIView *row in _rows)
    {
        row.frame = CGRectMake(0.0f, y, width, TGAccountSwitcherPanelRowHeight);
        y += TGAccountSwitcherPanelRowHeight;
    }
}

- (CGFloat)hiddenOffset
{
    return -(_cardView.center.y + _cardView.bounds.size.height / 2.0f + 16.0f);
}

- (void)animateIn
{
    _dimView.alpha = 0.0f;
    _cardView.transform = CGAffineTransformMakeTranslation(0.0f, [self hiddenOffset]);

    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^
    {
        _dimView.alpha = 1.0f;
        _cardView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)dismissAnimated:(bool)animated completion:(void (^)(void))completion
{
    if (_dismissing)
        return;
    _dismissing = true;
    self.userInteractionEnabled = false;

    if (!animated)
    {
        [self removeFromSuperview];
        if (completion != nil)
            completion();
        return;
    }

    [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState animations:^
    {
        _dimView.alpha = 0.0f;
        _cardView.transform = CGAffineTransformMakeTranslation(0.0f, [self hiddenOffset]);
    } completion:^(__unused BOOL finished)
    {
        [self removeFromSuperview];
        if (completion != nil)
            completion();
    }];
}

- (void)dimPressed
{
    [self dismissAnimated:true completion:nil];
}

- (void)rowPressed:(TGAccountSwitcherPanelRow *)row
{
    TGAccountRecord *account = row.account;
    TGAccountRecord *activeAccount = [[TGAccountManager instance] activeAccount];
    if (account == nil || [account.accountId isEqualToString:activeAccount.accountId])
    {
        [self dismissAnimated:true completion:nil];
        return;
    }

    [self dismissAnimated:false completion:^
    {
        [[TGAccountSwitcher instance] switchToAccount:account];
    }];
}

- (void)addPressed
{
    [self dismissAnimated:false completion:^
    {
        [[TGAccountSwitcher instance] addAccount];
    }];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer != _panRecognizer)
        return true;
    if (_contentView.scrollEnabled)
        return false;
    CGPoint velocity = [_panRecognizer velocityInView:self];
    return velocity.y < 0.0f && ABS(velocity.y) > ABS(velocity.x);
}

- (void)panGesture:(UIPanGestureRecognizer *)recognizer
{
    CGFloat offset = MIN(0.0f, [recognizer translationInView:self].y);
    CGFloat hiddenOffset = [self hiddenOffset];

    switch (recognizer.state)
    {
        case UIGestureRecognizerStateChanged:
        {
            _cardView.transform = CGAffineTransformMakeTranslation(0.0f, offset);
            _dimView.alpha = MAX(0.0f, 1.0f - offset / hiddenOffset);
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            CGFloat velocity = [recognizer velocityInView:self].y;
            if (recognizer.state == UIGestureRecognizerStateEnded && (velocity < -300.0f || offset < hiddenOffset / 3.0f))
            {
                [self dismissAnimated:true completion:nil];
            }
            else
            {
                [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^
                {
                    _cardView.transform = CGAffineTransformIdentity;
                    _dimView.alpha = 1.0f;
                } completion:nil];
            }
            break;
        }
        default:
            break;
    }
}

- (BOOL)accessibilityPerformEscape
{
    [self dismissAnimated:true completion:nil];
    return true;
}

@end
