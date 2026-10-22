#import "TGOnegramCoreController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGTelegramNetworking.h"
#import "TGCollectionItem.h"
#import "TGCollectionItemView.h"
#import "TGHeaderCollectionItem.h"
#import "TGSwitchCollectionItem.h"
#import "TGVariantCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGPowerServersController.h"

#import "../OnegramDante/PowerSubscriptions.h"
#import "../OnegramPlatform/OGPlatformText.h"

static const CGFloat TGOnegramCoreMethodRowHeight = 58.0f;
static const CGFloat TGOnegramCoreMethodHorizontalInset = 15.0f;
static const CGFloat TGOnegramCoreMethodCheckSpacing = 10.0f;
static const CGFloat TGOnegramCoreMethodTitleTop = 9.0f;
static const CGFloat TGOnegramCoreMethodSubtitleTop = 32.0f;

@interface TGOnegramCoreMethodCollectionItemView : TGCollectionItemView
{
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIImageView *_checkView;
}

- (void)setTitle:(NSString *)title;
- (void)setSubtitle:(NSString *)subtitle;
- (void)setIsChecked:(bool)isChecked;

@end

@implementation TGOnegramCoreMethodCollectionItemView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        [self addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.font = TGSystemFontOfSize(13.0f);
        [self addSubview:_subtitleLabel];

        _checkView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 14.0f, 11.0f)];
        [self addSubview:_checkView];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];

    _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
    _subtitleLabel.textColor = presentation.pallete.collectionMenuVariantColor;
    _checkView.image = presentation.images.collectionMenuCheckImage;
    [self setNeedsLayout];
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
    [self setNeedsLayout];
}

- (void)setSubtitle:(NSString *)subtitle
{
    _subtitleLabel.text = subtitle;
    [self setNeedsLayout];
}

- (void)setIsChecked:(bool)isChecked
{
    _checkView.hidden = !isChecked;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    bool classic = [TGPresentation classicIOS6Style];
    CGRect contentFrame = [self classicIOS6GroupedFrame];
    CGFloat originX = contentFrame.origin.x + TGOnegramCoreMethodHorizontalInset + (classic ? 0.0f : self.safeAreaInset.left);
    CGFloat maxX = CGRectGetMaxX(contentFrame) - TGOnegramCoreMethodHorizontalInset - (classic ? 0.0f : self.safeAreaInset.right);

    CGSize checkSize = _checkView.frame.size;
    _checkView.frame = CGRectMake(maxX - checkSize.width, CGFloor((self.bounds.size.height - checkSize.height) / 2.0f), checkSize.width, checkSize.height);

    CGFloat labelWidth = MAX(0.0f, maxX - checkSize.width - TGOnegramCoreMethodCheckSpacing - originX);
    _titleLabel.frame = CGRectMake(originX, TGOnegramCoreMethodTitleTop, labelWidth, CGCeil(OGPlatformFontLineHeight(_titleLabel.font)));
    _subtitleLabel.frame = CGRectMake(originX, TGOnegramCoreMethodSubtitleTop, labelWidth, CGCeil(OGPlatformFontLineHeight(_subtitleLabel.font)));
}

@end

@interface TGOnegramCoreMethodCollectionItem : TGCollectionItem

@property (nonatomic, readonly) OGOnegramCoreMode mode;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *subtitle;
@property (nonatomic) bool isChecked;
@property (nonatomic, copy) void (^pressed)(OGOnegramCoreMode mode);

- (instancetype)initWithMode:(OGOnegramCoreMode)mode title:(NSString *)title subtitle:(NSString *)subtitle;

@end

@implementation TGOnegramCoreMethodCollectionItem

- (instancetype)initWithMode:(OGOnegramCoreMode)mode title:(NSString *)title subtitle:(NSString *)subtitle
{
    self = [super init];
    if (self != nil)
    {
        _mode = mode;
        _title = title;
        _subtitle = subtitle;
        self.deselectAutomatically = true;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGOnegramCoreMethodCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, TGOnegramCoreMethodRowHeight);
}

- (void)bindView:(TGCollectionItemView *)view
{
    [super bindView:view];

    TGOnegramCoreMethodCollectionItemView *methodView = (TGOnegramCoreMethodCollectionItemView *)view;
    [methodView setTitle:_title];
    [methodView setSubtitle:_subtitle];
    [methodView setIsChecked:_isChecked];
}

- (void)setIsChecked:(bool)isChecked
{
    _isChecked = isChecked;
    [(TGOnegramCoreMethodCollectionItemView *)self.boundView setIsChecked:isChecked];
}

- (void)itemSelected:(id)__unused actionTarget
{
    if (_pressed != nil)
        _pressed(_mode);
}

@end

static bool TGOnegramCoreModeUsesTunnel(OGOnegramCoreMode mode)
{
    return mode == OGOnegramCoreModeDanteWARP || mode == OGOnegramCoreModeDantePower;
}

static NSString *TGOnegramCoreModeInfo(OGOnegramCoreMode mode)
{
    switch (mode)
    {
        case OGOnegramCoreModeWebSocket:
            return TGLocalized(@"OnegramCore.WebSocketInfo");
        case OGOnegramCoreModeDanteWARP:
            return TGLocalized(@"OnegramCore.WarpInfo");
        case OGOnegramCoreModeDantePower:
            return TGLocalized(@"OnegramCore.PowerInfo");
        default:
            return TGLocalized(@"OnegramCore.OffInfo");
    }
}

@interface TGOnegramCoreController ()
{
    TGSwitchCollectionItem *_enabledItem;
    TGCommentCollectionItem *_enabledInfoItem;
    TGCollectionMenuSection *_enabledSection;

    NSArray *_methodItems;
    TGCommentCollectionItem *_methodInfoItem;
    TGCollectionMenuSection *_methodSection;

    TGVariantCollectionItem *_statusItem;
    TGButtonCollectionItem *_reconnectItem;
    TGCommentCollectionItem *_errorItem;
    TGCollectionMenuSection *_statusSection;

    TGVariantCollectionItem *_powerServersItem;
    TGCollectionMenuSection *_powerSection;
}
@end

@implementation TGOnegramCoreController

- (instancetype)init
{
    return [self initModal:false];
}

- (instancetype)initModal:(bool)modal
{
    self = [super init];
    if (self != nil)
    {
        [self setTitleText:TGLocalized(@"OnegramCore.Title")];

        if (modal)
            [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Done") style:UIBarButtonItemStyleDone target:self action:@selector(donePressed)]];

        __weak TGOnegramCoreController *weakSelf = self;
        _enabledItem = [[TGSwitchCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramCore.Title") isOn:false];
        _enabledItem.toggled = ^(bool value, __unused TGSwitchCollectionItem *item)
        {
            __strong TGOnegramCoreController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf selectMode:value ? [OGOnegramCore sharedCore].preferredMode : OGOnegramCoreModeNone];
        };
        _enabledInfoItem = [[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"OnegramCore.OffInfo")];
        _enabledSection = [[TGCollectionMenuSection alloc] initWithItems:@[]];

        _methodItems = @[
            [[TGOnegramCoreMethodCollectionItem alloc] initWithMode:OGOnegramCoreModeWebSocket title:TGLocalized(@"OnegramCore.Mode.WebSocket") subtitle:TGLocalized(@"OnegramCore.Mode.WebSocketSubtitle")],
            [[TGOnegramCoreMethodCollectionItem alloc] initWithMode:OGOnegramCoreModeDanteWARP title:TGLocalized(@"OnegramCore.Mode.WARP") subtitle:TGLocalized(@"OnegramCore.Mode.WARPSubtitle")],
            [[TGOnegramCoreMethodCollectionItem alloc] initWithMode:OGOnegramCoreModeDantePower title:TGLocalized(@"OnegramCore.Mode.Power") subtitle:TGLocalized(@"OnegramCore.Mode.PowerSubtitle")]
        ];
        for (TGOnegramCoreMethodCollectionItem *item in _methodItems)
        {
            item.pressed = ^(OGOnegramCoreMode mode)
            {
                __strong TGOnegramCoreController *strongSelf = weakSelf;
                if (strongSelf != nil && mode != [OGOnegramCore sharedCore].mode)
                    [strongSelf selectMode:mode];
            };
        }
        _methodInfoItem = [[TGCommentCollectionItem alloc] initWithText:@""];
        NSMutableArray *methodSectionItems = [[NSMutableArray alloc] initWithObjects:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramCore.ModeHeader")], nil];
        [methodSectionItems addObjectsFromArray:_methodItems];
        [methodSectionItems addObject:_methodInfoItem];
        _methodSection = [[TGCollectionMenuSection alloc] initWithItems:methodSectionItems];

        _statusItem = [[TGVariantCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramCore.Status") variant:@"" action:NULL];
        _statusItem.hideArrow = true;
        _statusItem.selectable = false;
        _statusItem.highlightable = false;
        _reconnectItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramCore.Reconnect") action:@selector(reconnectPressed)];
        _reconnectItem.deselectAutomatically = true;
        _errorItem = [[TGCommentCollectionItem alloc] initWithText:@""];
        _statusSection = [[TGCollectionMenuSection alloc] initWithItems:@[]];

        _powerServersItem = [[TGVariantCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramCore.PowerServers") variant:@"" action:@selector(powerServersPressed)];
        _powerServersItem.deselectAutomatically = true;
        _powerSection = [[TGCollectionMenuSection alloc] initWithItems:@[_powerServersItem]];

        UIEdgeInsets insets = _enabledSection.insets;
        insets.top = 32.0f;
        _enabledSection.insets = insets;

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(proxyChanged:) name:OGOnegramCoreDidChangeNotification object:nil];
        [center addObserver:self selector:@selector(proxyChanged:) name:PowerSubscriptionsDidChangeNotification object:nil];

        [self updateItems];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateItems];
}

- (void)proxyChanged:(NSNotification *)__unused notification
{
    [self updateItems];
}

- (void)updateItems
{
    OGOnegramCore *proxy = [OGOnegramCore sharedCore];
    OGOnegramCoreMode mode = proxy.mode;
    bool enabled = mode != OGOnegramCoreModeNone;

    [_enabledItem setIsOn:enabled animated:false];
    [_enabledSection replaceItems:enabled ? @[_enabledItem] : @[_enabledItem, _enabledInfoItem]];

    NSMutableArray *sections = [[NSMutableArray alloc] initWithObjects:_enabledSection, nil];
    if (enabled)
    {
        for (TGOnegramCoreMethodCollectionItem *item in _methodItems)
            item.isChecked = item.mode == mode;
        _methodInfoItem.text = TGOnegramCoreModeInfo(mode);
        [sections addObject:_methodSection];

        _statusItem.variant = [TGOnegramCoreController statusText];
        NSMutableArray *statusItems = [[NSMutableArray alloc] initWithObjects:_statusItem, nil];
        if (TGOnegramCoreModeUsesTunnel(mode))
            [statusItems addObject:_reconnectItem];
        NSError *error = proxy.lastError;
        if (proxy.state == OGOnegramCoreStateFailed && error.localizedDescription.length != 0)
        {
            _errorItem.text = mode == OGOnegramCoreModeWebSocket ? [[NSString alloc] initWithFormat:TGLocalized(@"OnegramCore.WebSocketFallback"), error.localizedDescription] : error.localizedDescription;
            [statusItems addObject:_errorItem];
        }
        [_statusSection replaceItems:statusItems];
        [sections addObject:_statusSection];
    }
    if (mode == OGOnegramCoreModeDantePower)
    {
        _powerServersItem.variant = [TGPowerServersController selectedServerTitle];
        [sections addObject:_powerSection];
    }

    while (self.menuSections.sections.count != 0)
        [self.menuSections deleteSection:0];
    for (TGCollectionMenuSection *section in sections)
        [self.menuSections addSection:section];
    [self.collectionView reloadData];
}

- (void)selectMode:(OGOnegramCoreMode)mode
{
    if (mode == OGOnegramCoreModeDantePower && [[PowerSubscriptions shared] allLines].count == 0)
    {
        [self updateItems];
        TGPowerServersController *controller = [[TGPowerServersController alloc] init];
        controller.enablesPowerAfterAddingServers = true;
        [self.navigationController pushViewController:controller animated:true];
        return;
    }

    [[TGTelegramNetworking instance] setOnegramCoreMode:mode];
    [self updateItems];
}

- (void)reconnectPressed
{
    [[OGOnegramCore sharedCore] reconnect];
}

- (void)powerServersPressed
{
    [self.navigationController pushViewController:[[TGPowerServersController alloc] init] animated:true];
}

- (void)donePressed
{
    [self dismissViewControllerAnimated:true completion:nil];
}

+ (void)presentFromViewController:(UIViewController *)viewController
{
    if (viewController == nil)
        return;

    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[[[TGOnegramCoreController alloc] initModal:true]]];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    TGPresentViewController(viewController, navigationController, true, nil);
}

+ (NSString *)statusText
{
    OGOnegramCore *proxy = [OGOnegramCore sharedCore];
    OGOnegramCoreMode mode = proxy.mode;
    if (mode == OGOnegramCoreModeNone)
        return TGLocalized(@"OnegramCore.Off");

    switch (proxy.state)
    {
        case OGOnegramCoreStateConnected:
            return TGLocalized(@"OnegramCore.Connected");
        case OGOnegramCoreStateFailed:
            return mode == OGOnegramCoreModeWebSocket ? TGLocalized(@"OnegramCore.WebSocketUnavailable") : TGLocalized(@"OnegramCore.Failed");
        default:
            return TGLocalized(@"OnegramCore.Connecting");
    }
}

+ (UIImage *)lockImageEnabled:(bool)enabled highlighted:(bool)highlighted
{
    CGSize size = CGSizeMake(32.0f, 32.0f);
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    UIColor *color = enabled ? TGAccentColor() : UIColorRGB(0x7f8c97);
    if (highlighted)
        color = [color colorWithAlphaComponent:0.55f];

    CGContextSetStrokeColorWithColor(contextRef, color.CGColor);
    CGContextSetFillColorWithColor(contextRef, color.CGColor);
    CGContextSetLineWidth(contextRef, 2.4f);
    CGContextSetLineCap(contextRef, kCGLineCapRound);
    CGContextSetLineJoin(contextRef, kCGLineJoinRound);

    if (enabled)
    {
        CGContextMoveToPoint(contextRef, 10.0f, 14.5f);
        CGContextAddLineToPoint(contextRef, 10.0f, 11.5f);
        CGContextAddCurveToPoint(contextRef, 10.0f, 7.5f, 13.0f, 5.5f, 16.0f, 5.5f);
        CGContextAddCurveToPoint(contextRef, 19.0f, 5.5f, 21.0f, 7.5f, 21.0f, 9.5f);
        CGContextStrokePath(contextRef);
    }
    else
    {
        CGContextMoveToPoint(contextRef, 10.0f, 14.5f);
        CGContextAddLineToPoint(contextRef, 10.0f, 11.5f);
        CGContextAddCurveToPoint(contextRef, 10.0f, 7.5f, 12.5f, 5.5f, 16.0f, 5.5f);
        CGContextAddCurveToPoint(contextRef, 19.5f, 5.5f, 22.0f, 7.5f, 22.0f, 11.5f);
        CGContextAddLineToPoint(contextRef, 22.0f, 14.5f);
        CGContextStrokePath(contextRef);
    }

    UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(7.0f, 13.0f, 18.0f, 14.0f) cornerRadius:3.0f];
    [body fill];

    CGContextSetFillColorWithColor(contextRef, [UIColor whiteColor].CGColor);
    CGContextFillEllipseInRect(contextRef, CGRectMake(14.5f, 17.0f, 3.0f, 3.0f));
    CGContextFillRect(contextRef, CGRectMake(15.25f, 19.0f, 1.5f, 4.0f));

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIButton *)lockButtonWithTarget:(id)target action:(SEL)action
{
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 44.0f, 44.0f)];
    button.adjustsImageWhenHighlighted = false;
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [self updateLockButton:button];
    return button;
}

+ (void)updateLockButton:(UIButton *)button
{
    if (button == nil)
        return;

    bool enabled = [OGOnegramCore sharedCore].mode != OGOnegramCoreModeNone;
    [button setImage:[self lockImageEnabled:enabled highlighted:false] forState:UIControlStateNormal];
    [button setImage:[self lockImageEnabled:enabled highlighted:true] forState:UIControlStateHighlighted];
    button.accessibilityLabel = @"Onegram Core";
    button.accessibilityValue = [self statusText];
}

@end
