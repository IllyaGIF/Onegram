#import "TGPowerServersController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGTelegramNetworking.h"
#import "TGCollectionItem.h"
#import "TGEditableCollectionItemView.h"
#import "TGHeaderCollectionItem.h"
#import "TGCheckCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGCommentCollectionItem.h"

#import "../OnegramDante/PowerConfig.h"
#import "../OnegramDante/PowerSubscriptions.h"

static const CGFloat TGPowerEntryRowHeight = 58.0f;
static const CGFloat TGPowerEntryCheckInset = 44.0f;
static const CGFloat TGPowerEntryPlainInset = 15.0f;

@interface TGPowerEntryCollectionItemView : TGEditableCollectionItemView
{
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIImageView *_checkView;
    bool _checkable;
    bool _subtitleIsError;
}

@property (nonatomic, copy) void (^removeRequested)(void);

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle subtitleIsError:(bool)subtitleIsError;
- (void)setCheckable:(bool)checkable checked:(bool)checked;

@end

@implementation TGPowerEntryCollectionItemView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.editingContentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.font = TGSystemFontOfSize(13.0f);
        _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.editingContentView addSubview:_subtitleLabel];

        _checkView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 14.0f, 11.0f)];
        [self.editingContentView addSubview:_checkView];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];

    _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
    _checkView.image = presentation.images.collectionMenuCheckImage;
    [self updateSubtitleColor];
}

- (void)updateSubtitleColor
{
    _subtitleLabel.textColor = _subtitleIsError ? self.presentation.pallete.collectionMenuDestructiveColor : self.presentation.pallete.collectionMenuVariantColor;
}

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle subtitleIsError:(bool)subtitleIsError
{
    _titleLabel.text = title;
    _subtitleLabel.text = subtitle;
    _subtitleIsError = subtitleIsError;
    [self updateSubtitleColor];
    [self setNeedsLayout];
}

- (void)setCheckable:(bool)checkable checked:(bool)checked
{
    _checkable = checkable;
    _checkView.hidden = !checkable || !checked;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    self.separatorInset = checkable ? TGPowerEntryCheckInset : TGPowerEntryPlainInset;
#endif
    [self setNeedsLayout];
}

- (void)deleteAction
{
    [super deleteAction];

    if (_removeRequested != nil)
        _removeRequested();
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat classicInset = [TGPresentation classicIOS6Style] ? 10.0f : 0.0f;
    CGFloat editingInset = self.enableEditing && self.showsDeleteIndicator ? 38.0f : 0.0f;
    CGFloat leftInset = (_checkable ? TGPowerEntryCheckInset : TGPowerEntryPlainInset) + classicInset + editingInset + self.safeAreaInset.left;
    CGFloat width = MAX(0.0f, self.editingContentView.frame.size.width - leftInset - TGPowerEntryPlainInset - classicInset - self.safeAreaInset.right);

    _titleLabel.frame = CGRectMake(leftInset, 9.0f, width, 22.0f);
    _subtitleLabel.frame = CGRectMake(leftInset, 32.0f, width, 17.0f);

    CGSize checkSize = _checkView.frame.size;
    _checkView.frame = CGRectMake(TGPowerEntryPlainInset + classicInset + editingInset + self.safeAreaInset.left, CGFloor((self.editingContentView.frame.size.height - checkSize.height) / 2.0f), checkSize.width, checkSize.height);
}

@end

@interface TGPowerEntryCollectionItem : TGCollectionItem

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;
@property (nonatomic) bool subtitleIsError;
@property (nonatomic) bool checkable;
@property (nonatomic) bool checked;
@property (nonatomic, copy) void (^pressed)(void);
@property (nonatomic, copy) void (^removeRequested)(void);

@end

@implementation TGPowerEntryCollectionItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.deselectAutomatically = true;
        self.selectable = false;
        self.highlightable = false;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGPowerEntryCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, TGPowerEntryRowHeight);
}

- (void)setPressed:(void (^)(void))pressed
{
    _pressed = [pressed copy];
    self.selectable = _pressed != nil;
    self.highlightable = _pressed != nil;
}

- (void)itemSelected:(id)__unused actionTarget
{
    if (_pressed != nil)
        _pressed();
}

- (void)bindView:(TGCollectionItemView *)view
{
    [super bindView:view];

    TGPowerEntryCollectionItemView *entryView = (TGPowerEntryCollectionItemView *)view;
    [entryView setTitle:_title subtitle:_subtitle subtitleIsError:_subtitleIsError];
    [entryView setCheckable:_checkable checked:_checked];
    entryView.enableEditing = _removeRequested != nil;
    __weak TGPowerEntryCollectionItem *weakSelf = self;
    entryView.removeRequested = ^
    {
        __strong TGPowerEntryCollectionItem *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf->_removeRequested != nil)
            strongSelf->_removeRequested();
    };
}

- (void)unbindView
{
    ((TGPowerEntryCollectionItemView *)self.boundView).removeRequested = nil;
    [super unbindView];
}

@end

@interface TGPowerImportController : TGViewController
{
    UITextView *_textView;
    UILabel *_hintLabel;
    UIBarButtonItem *_saveItem;
    bool _subscription;
}

@property (nonatomic, copy) void (^saved)(void);

- (instancetype)initForSubscription:(bool)subscription;

@end

@implementation TGPowerImportController

- (instancetype)initForSubscription:(bool)subscription
{
    self = [super init];
    if (self != nil)
    {
        _subscription = subscription;
        [self setTitleText:TGLocalized(subscription ? @"Power.AddSubscription" : @"Power.AddServers")];
        _saveItem = [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Save") style:UIBarButtonItemStyleDone target:self action:@selector(savePressed)];
        [self setRightBarButtonItem:_saveItem];
    }
    return self;
}

- (void)loadView
{
    [super loadView];

    TGPresentationPallete *pallete = TGPresentation.current.pallete;
    self.view.backgroundColor = pallete.backgroundColor;

    _hintLabel = [[UILabel alloc] init];
    _hintLabel.backgroundColor = [UIColor clearColor];
    _hintLabel.font = TGSystemFontOfSize(14.0f);
    _hintLabel.textColor = pallete.secondaryTextColor;
    _hintLabel.numberOfLines = 0;
    _hintLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _hintLabel.text = TGLocalized(_subscription ? @"Power.SubscriptionHint" : @"Power.ServersHint");
    [self.view addSubview:_hintLabel];

    _textView = [[UITextView alloc] init];
    _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _textView.backgroundColor = pallete.backgroundColor;
    _textView.textColor = pallete.textColor;
    _textView.font = TGSystemFontOfSize(16.0f);
    _textView.autocorrectionType = UITextAutocorrectionTypeNo;
    _textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _textView.keyboardType = _subscription ? UIKeyboardTypeURL : UIKeyboardTypeDefault;
    [self.view addSubview:_textView];

    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    [self layoutContent];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self layoutContent];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [_textView becomeFirstResponder];
}

- (void)layoutContent
{
    if (![self isViewLoaded])
        return;

    CGSize size = self.view.bounds.size;
    UIEdgeInsets inset = self.controllerInset;
    CGFloat hintWidth = MAX(0.0f, size.width - 30.0f);
    CGFloat hintHeight = CGCeil([_hintLabel.text sizeWithFont:_hintLabel.font constrainedToSize:CGSizeMake(hintWidth, 1000.0f) lineBreakMode:NSLineBreakByWordWrapping].height);
    _hintLabel.frame = CGRectMake(15.0f, inset.top + 10.0f, hintWidth, hintHeight);
    CGFloat textTop = CGRectGetMaxY(_hintLabel.frame) + 6.0f;
    _textView.frame = CGRectMake(0.0f, textTop, size.width, MAX(0.0f, size.height - inset.bottom - textTop));
}

- (void)setSaving:(bool)saving
{
    _saveItem.enabled = !saving;
    _textView.editable = !saving;
}

- (void)savePressed
{
    NSString *text = [_textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0)
        return;

    [self setSaving:true];
    [_textView resignFirstResponder];
    bool subscription = _subscription;
    __weak TGPowerImportController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        NSString *error = nil;
        PowerSubscriptions *store = [PowerSubscriptions shared];
        bool success = subscription ? [store addURL:text error:&error] != nil : [store addText:text error:&error];
        dispatch_async(dispatch_get_main_queue(), ^
        {
            __strong TGPowerImportController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            [strongSelf setSaving:false];
            if (success)
            {
                if (strongSelf->_saved != nil)
                    strongSelf->_saved();
                [strongSelf.navigationController popViewControllerAnimated:true];
            }
            else
            {
                [[[UIAlertView alloc] initWithTitle:nil message:error delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil] show];
            }
        });
    });
}

@end

@interface TGPowerServersController ()
{
    TGCheckCollectionItem *_automaticItem;
    TGButtonCollectionItem *_addServersItem;
    TGCollectionMenuSection *_serversSection;

    TGButtonCollectionItem *_addSubscriptionItem;
    TGButtonCollectionItem *_refreshItem;
    TGCollectionMenuSection *_subscriptionsSection;

    bool _refreshing;
}
@end

@implementation TGPowerServersController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [self setTitleText:TGLocalized(@"Power.Title")];

        _automaticItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramCore.PowerAutomatic") action:@selector(automaticPressed)];
        _automaticItem.deselectAutomatically = true;
        _addServersItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"Power.AddServers") action:@selector(addServersPressed)];
        _addServersItem.deselectAutomatically = true;
        _serversSection = [[TGCollectionMenuSection alloc] initWithItems:@[]];
        UIEdgeInsets insets = _serversSection.insets;
        insets.top = 32.0f;
        _serversSection.insets = insets;
        [self.menuSections addSection:_serversSection];

        _addSubscriptionItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"Power.AddSubscription") action:@selector(addSubscriptionPressed)];
        _addSubscriptionItem.deselectAutomatically = true;
        _refreshItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"Power.Refresh") action:@selector(refreshPressed)];
        _refreshItem.deselectAutomatically = true;
        _subscriptionsSection = [[TGCollectionMenuSection alloc] initWithItems:@[]];
        [self.menuSections addSection:_subscriptionsSection];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serversChanged:) name:PowerSubscriptionsDidChangeNotification object:nil];

        [self updateItems];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)serversChanged:(NSNotification *)__unused notification
{
    [self updateItems];
}

+ (NSString *)selectedServerTitle
{
    NSString *line = [PowerSubscriptions shared].selectedLine;
    PowerConfig *config = line == nil ? nil : [PowerConfig configFromURI:line];
    return config.name.length != 0 ? config.name : TGLocalized(@"OnegramCore.PowerAutomatic");
}

- (void)updateItems
{
    PowerSubscriptions *store = [PowerSubscriptions shared];
    NSArray *lines = [store allLines];
    NSSet *manualLines = [NSSet setWithArray:[store manualLines]];
    NSString *selectedLine = store.selectedLine;

    NSMutableArray *serverItems = [[NSMutableArray alloc] init];
    [serverItems addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"Power.Servers")]];
    if (lines.count != 0)
    {
        _automaticItem.isChecked = selectedLine == nil;
        [serverItems addObject:_automaticItem];
    }
    for (NSString *line in lines)
        [serverItems addObject:[self itemForServerLine:line selected:[line isEqualToString:selectedLine] manual:[manualLines containsObject:line]]];
    [serverItems addObject:_addServersItem];
    [serverItems addObject:[[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"Power.ServersInfo")]];
    [_serversSection replaceItems:serverItems];

    NSArray *subscriptions = [store subscriptions];
    NSMutableArray *subscriptionItems = [[NSMutableArray alloc] init];
    [subscriptionItems addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"Power.Subscriptions")]];
    [subscriptions enumerateObjectsUsingBlock:^(NSDictionary *subscription, NSUInteger index, __unused BOOL *stop)
    {
        [subscriptionItems addObject:[self itemForSubscription:subscription index:index]];
    }];
    [subscriptionItems addObject:_addSubscriptionItem];
    if (subscriptions.count != 0)
    {
        _refreshItem.title = TGLocalized(_refreshing ? @"Power.Refreshing" : @"Power.Refresh");
        _refreshItem.enabled = !_refreshing;
        [subscriptionItems addObject:_refreshItem];
    }
    [subscriptionItems addObject:[[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"Power.SubscriptionsInfo")]];
    [_subscriptionsSection replaceItems:subscriptionItems];

    [self.collectionView reloadData];
}

- (TGPowerEntryCollectionItem *)itemForServerLine:(NSString *)line selected:(bool)selected manual:(bool)manual
{
    PowerConfig *config = [PowerConfig configFromURI:line];
    NSString *unsupportedReason = config == nil ? TGLocalized(@"Power.InvalidServer") : [config unsupportedReason];

    TGPowerEntryCollectionItem *item = [[TGPowerEntryCollectionItem alloc] init];
    item.title = config.name.length != 0 ? config.name : line;
    item.subtitle = unsupportedReason ?: [config summary];
    item.subtitleIsError = unsupportedReason != nil;
    item.checkable = true;
    item.checked = selected;

    __weak TGPowerServersController *weakSelf = self;
    item.pressed = ^
    {
        __strong TGPowerServersController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf selectServerLine:line unsupportedReason:unsupportedReason];
    };
    if (manual)
    {
        item.removeRequested = ^
        {
            __strong TGPowerServersController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf removeServerLine:line];
        };
    }
    return item;
}

- (TGPowerEntryCollectionItem *)itemForSubscription:(NSDictionary *)subscription index:(NSUInteger)index
{
    NSString *urlString = [subscription objectForKey:@"url"];
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *host = url.host;
    NSString *lastError = [subscription objectForKey:@"lastError"];

    TGPowerEntryCollectionItem *item = [[TGPowerEntryCollectionItem alloc] init];
    item.title = host.length != 0 ? host : urlString;
    item.subtitle = lastError.length != 0 ? lastError : [[NSString alloc] initWithFormat:TGLocalized(@"Power.ServerCount"), [[subscription objectForKey:@"count"] intValue]];
    item.subtitleIsError = lastError.length != 0;

    __weak TGPowerServersController *weakSelf = self;
    item.removeRequested = ^
    {
        __strong TGPowerServersController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf removeSubscriptionAtIndex:index];
    };
    return item;
}

- (void)showMessage:(NSString *)message
{
    if (message.length == 0)
        return;
    [[[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil] show];
}

- (void)automaticPressed
{
    NSString *error = nil;
    if (![[PowerSubscriptions shared] selectLine:nil error:&error])
        [self showMessage:error];
    [self updateItems];
}

- (void)selectServerLine:(NSString *)line unsupportedReason:(NSString *)unsupportedReason
{
    if (unsupportedReason != nil)
    {
        [self showMessage:unsupportedReason];
        return;
    }

    NSString *error = nil;
    if (![[PowerSubscriptions shared] selectLine:line error:&error])
        [self showMessage:error];
    [self updateItems];
}

- (void)removeServerLine:(NSString *)line
{
    NSString *error = nil;
    if (![[PowerSubscriptions shared] removeManualLine:line error:&error])
        [self showMessage:error];
    [self updateItems];
}

- (void)removeSubscriptionAtIndex:(NSUInteger)index
{
    NSString *error = nil;
    if (![[PowerSubscriptions shared] removeAtIndex:index error:&error])
        [self showMessage:error];
    [self updateItems];
}

- (void)presentImportForSubscription:(bool)subscription
{
    TGPowerImportController *controller = [[TGPowerImportController alloc] initForSubscription:subscription];
    __weak TGPowerServersController *weakSelf = self;
    controller.saved = ^
    {
        __strong TGPowerServersController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf importFinished];
    };
    [self.navigationController pushViewController:controller animated:true];
}

- (void)importFinished
{
    [self updateItems];
    if (_enablesPowerAfterAddingServers && [[PowerSubscriptions shared] allLines].count != 0)
    {
        _enablesPowerAfterAddingServers = false;
        [[TGTelegramNetworking instance] setOnegramCoreMode:OGOnegramCoreModeDantePower];
    }
}

- (void)addServersPressed
{
    [self presentImportForSubscription:false];
}

- (void)addSubscriptionPressed
{
    [self presentImportForSubscription:true];
}

- (void)refreshPressed
{
    if (_refreshing)
        return;

    _refreshing = true;
    [self updateItems];
    __weak TGPowerServersController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        NSString *report = [[PowerSubscriptions shared] refreshAllNow];
        dispatch_async(dispatch_get_main_queue(), ^
        {
            __strong TGPowerServersController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            strongSelf->_refreshing = false;
            [strongSelf updateItems];
            [strongSelf showMessage:report];
        });
    });
}

@end
