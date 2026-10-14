#import "TGOnegramCoreController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGTelegramNetworking.h"
#import "TGCollectionItem.h"
#import "TGCollectionItemView.h"
#import "TGHeaderCollectionItem.h"
#import "TGVariantCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGPowerServersController.h"

#import "../OnegramDante/PowerSubscriptions.h"

#import <QuartzCore/QuartzCore.h>

static const CGFloat TGOnegramCoreModeRowHeight = 52.0f;
static const CGFloat TGOnegramCoreModeTagHeight = 30.0f;
static const CGFloat TGOnegramCoreModeTagSpacing = 8.0f;
static const CGFloat TGOnegramCoreModeHorizontalInset = 15.0f;
static const CGFloat TGOnegramCoreModeTitleInset = 6.0f;
static const CGFloat TGOnegramCoreModeMaximumFontSize = 14.0f;
static const CGFloat TGOnegramCoreModeMinimumFontSize = 10.0f;

@interface TGOnegramCoreModeCollectionItemView : TGCollectionItemView
{
    NSArray *_buttons;
    NSUInteger _selectedIndex;
}

@property (nonatomic, copy) void (^selectionChanged)(NSUInteger index);

- (void)setTitles:(NSArray *)titles;
- (void)setSelectedIndex:(NSUInteger)selectedIndex;

@end

@implementation TGOnegramCoreModeCollectionItemView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _buttons = @[];
        _selectedIndex = NSNotFound;
    }
    return self;
}

- (void)setTitles:(NSArray *)titles
{
    for (UIButton *button in _buttons)
        [button removeFromSuperview];

    NSMutableArray *buttons = [[NSMutableArray alloc] initWithCapacity:titles.count];
    for (NSString *title in titles)
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.exclusiveTouch = true;
        button.layer.cornerRadius = TGOnegramCoreModeTagHeight / 2.0f;
        button.layer.borderWidth = 1.0f;
        button.titleLabel.lineBreakMode = NSLineBreakByClipping;
        [button setTitle:title forState:UIControlStateNormal];
        [button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];
        [buttons addObject:button];
    }
    _buttons = buttons;
    [self updateButtonAppearance];
    [self setNeedsLayout];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
    _selectedIndex = selectedIndex;
    [self updateButtonAppearance];
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    [self updateButtonAppearance];
}

- (void)updateButtonAppearance
{
    UIColor *accentColor = self.presentation.pallete.collectionMenuAccentColor;
    UIColor *backgroundColor = self.presentation.pallete.collectionMenuCellBackgroundColor;
    if (accentColor == nil || backgroundColor == nil)
        return;

    [_buttons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger index, __unused BOOL *stop)
    {
        bool selected = index == _selectedIndex;
        button.selected = selected;
        button.backgroundColor = selected ? accentColor : [UIColor clearColor];
        button.layer.borderColor = accentColor.CGColor;
        [button setTitleColor:selected ? backgroundColor : accentColor forState:UIControlStateNormal];
        [button setTitleColor:[(selected ? backgroundColor : accentColor) colorWithAlphaComponent:0.5f] forState:UIControlStateHighlighted];
    }];
}

- (void)buttonPressed:(UIButton *)button
{
    NSUInteger index = [_buttons indexOfObject:button];
    if (index == NSNotFound || index == _selectedIndex)
        return;

    if (_selectionChanged != nil)
        _selectionChanged(index);
}

- (UIFont *)fittingFontForTagWidth:(CGFloat)tagWidth
{
    CGFloat availableWidth = tagWidth - TGOnegramCoreModeTitleInset * 2.0f;
    for (CGFloat fontSize = TGOnegramCoreModeMaximumFontSize; fontSize > TGOnegramCoreModeMinimumFontSize; fontSize -= 0.5f)
    {
        UIFont *font = TGMediumSystemFontOfSize(fontSize);
        bool fits = true;
        for (UIButton *button in _buttons)
        {
            if ([[button titleForState:UIControlStateNormal] sizeWithFont:font].width > availableWidth)
            {
                fits = false;
                break;
            }
        }
        if (fits)
            return font;
    }
    return TGMediumSystemFontOfSize(TGOnegramCoreModeMinimumFontSize);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    NSUInteger count = _buttons.count;
    if (count == 0)
        return;

    CGRect contentFrame = [self classicIOS6GroupedFrame];
    CGFloat originX = contentFrame.origin.x + TGOnegramCoreModeHorizontalInset + ([TGPresentation classicIOS6Style] ? 0.0f : self.safeAreaInset.left);
    CGFloat maxX = CGRectGetMaxX(contentFrame) - TGOnegramCoreModeHorizontalInset - ([TGPresentation classicIOS6Style] ? 0.0f : self.safeAreaInset.right);
    CGFloat tagWidth = CGFloor((maxX - originX - TGOnegramCoreModeTagSpacing * (count - 1)) / count);
    CGFloat originY = CGFloor((self.bounds.size.height - TGOnegramCoreModeTagHeight) / 2.0f);
    UIFont *font = [self fittingFontForTagWidth:tagWidth];

    [_buttons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger index, __unused BOOL *stop)
    {
        button.titleLabel.font = font;
        button.frame = CGRectMake(originX + (tagWidth + TGOnegramCoreModeTagSpacing) * index, originY, tagWidth, TGOnegramCoreModeTagHeight);
    }];
}

@end

@interface TGOnegramCoreModeCollectionItem : TGCollectionItem

@property (nonatomic, strong) NSArray *titles;
@property (nonatomic) NSUInteger selectedIndex;
@property (nonatomic, copy) void (^selectionChanged)(NSUInteger index);

@end

@implementation TGOnegramCoreModeCollectionItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.selectable = false;
        self.highlightable = false;
        _selectedIndex = NSNotFound;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGOnegramCoreModeCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, TGOnegramCoreModeRowHeight);
}

- (void)bindView:(TGCollectionItemView *)view
{
    [super bindView:view];

    TGOnegramCoreModeCollectionItemView *modeView = (TGOnegramCoreModeCollectionItemView *)view;
    [modeView setTitles:_titles];
    [modeView setSelectedIndex:_selectedIndex];
    __weak TGOnegramCoreModeCollectionItem *weakSelf = self;
    modeView.selectionChanged = ^(NSUInteger index)
    {
        __strong TGOnegramCoreModeCollectionItem *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf->_selectionChanged != nil)
            strongSelf->_selectionChanged(index);
    };
}

- (void)unbindView
{
    ((TGOnegramCoreModeCollectionItemView *)self.boundView).selectionChanged = nil;
    [super unbindView];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
    _selectedIndex = selectedIndex;
    [(TGOnegramCoreModeCollectionItemView *)self.boundView setSelectedIndex:selectedIndex];
}

@end

static NSArray *TGOnegramCoreModes(void)
{
    return @[@(OGOnegramCoreModeNone), @(OGOnegramCoreModeWebSocket), @(OGOnegramCoreModeDanteWARP), @(OGOnegramCoreModeDantePower)];
}

static bool TGOnegramCoreModeUsesTunnel(OGOnegramCoreMode mode)
{
    return mode == OGOnegramCoreModeDanteWARP || mode == OGOnegramCoreModeDantePower;
}

@interface TGOnegramCoreController ()
{
    TGOnegramCoreModeCollectionItem *_modeItem;
    TGCommentCollectionItem *_modeInfoItem;
    TGCollectionMenuSection *_modeSection;

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

        _modeItem = [[TGOnegramCoreModeCollectionItem alloc] init];
        _modeItem.titles = @[TGLocalized(@"OnegramCore.Mode.Off"), TGLocalized(@"OnegramCore.Mode.WebSocket"), TGLocalized(@"OnegramCore.Mode.WARP"), TGLocalized(@"OnegramCore.Mode.Power")];
        __weak TGOnegramCoreController *weakSelf = self;
        _modeItem.selectionChanged = ^(NSUInteger index)
        {
            __strong TGOnegramCoreController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf selectMode:(OGOnegramCoreMode)[TGOnegramCoreModes()[index] integerValue]];
        };
        _modeInfoItem = [[TGCommentCollectionItem alloc] initWithText:@""];
        _modeSection = [[TGCollectionMenuSection alloc] initWithItems:@[[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramCore.ModeHeader")], _modeItem, _modeInfoItem]];

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

        UIEdgeInsets insets = _modeSection.insets;
        insets.top = 32.0f;
        _modeSection.insets = insets;

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

    _modeItem.selectedIndex = [TGOnegramCoreModes() indexOfObject:@(mode)];
    switch (mode)
    {
        case OGOnegramCoreModeWebSocket:
            _modeInfoItem.text = TGLocalized(@"OnegramCore.WebSocketInfo");
            break;
        case OGOnegramCoreModeDanteWARP:
            _modeInfoItem.text = TGLocalized(@"OnegramCore.WarpInfo");
            break;
        case OGOnegramCoreModeDantePower:
            _modeInfoItem.text = TGLocalized(@"OnegramCore.PowerInfo");
            break;
        default:
            _modeInfoItem.text = TGLocalized(@"OnegramCore.OffInfo");
            break;
    }

    NSMutableArray *sections = [[NSMutableArray alloc] initWithObjects:_modeSection, nil];
    if (mode != OGOnegramCoreModeNone)
    {
        _statusItem.variant = [TGOnegramCoreController statusText];
        NSMutableArray *statusItems = [[NSMutableArray alloc] initWithObjects:_statusItem, nil];
        if (TGOnegramCoreModeUsesTunnel(mode))
            [statusItems addObject:_reconnectItem];
        NSError *error = proxy.lastError;
        if (proxy.state == OGOnegramCoreStateFailed && error.localizedDescription.length != 0)
        {
            _errorItem.text = error.localizedDescription;
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
    if (!TGOnegramCoreModeUsesTunnel(mode))
        return TGLocalized(@"OnegramCore.On");

    switch (proxy.state)
    {
        case OGOnegramCoreStateConnected:
            return TGLocalized(@"OnegramCore.Connected");
        case OGOnegramCoreStateFailed:
            return TGLocalized(@"OnegramCore.Failed");
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

@end
