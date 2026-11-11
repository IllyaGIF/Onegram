#import "TGPaidMessagesSettingsController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGPresentation.h"
#import "TGDatabase.h"
#import "TGPaidMessagesSignals.h"
#import "TGSwitchCollectionItem.h"
#import "TGVariantCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGHeaderCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGOnegramSliderCollectionItem.h"
#import "TGPrivacyCustomShareListController.h"
#import "TGCustomAlertView.h"
#import "TGCustomActionSheet.h"
#import "TGShareMenu.h"
#import "TGSendMessageSignals.h"

static NSArray *TGPaidMessagesPriceSteps(int64_t maxStars, bool allowFree, int64_t current)
{
    static const int64_t steps[] = {1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100, 150, 200, 250, 300, 400, 500, 750, 1000, 1500, 2000, 2500, 3000, 4000, 5000, 7500, 10000, 15000, 20000, 25000, 50000, 100000};
    NSMutableArray *values = [[NSMutableArray alloc] init];
    if (allowFree)
        [values addObject:@0];
    for (size_t i = 0; i < sizeof(steps) / sizeof(steps[0]); i++)
    {
        if (steps[i] < maxStars)
            [values addObject:@(steps[i])];
    }
    [values addObject:@(maxStars)];
    if (current > 0 && current <= maxStars && ![values containsObject:@(current)])
    {
        [values addObject:@(current)];
        [values sortUsingSelector:@selector(compare:)];
    }
    return values;
}

@interface TGPaidMessagesSettingsController ()
{
    int64_t _channelId;
    bool _broadcast;
    bool _enabled;
    int64_t _stars;
    NSArray *_priceSteps;
    NSArray *_exceptionUserIds;

    TGSwitchCollectionItem *_enabledItem;
    TGCommentCollectionItem *_enabledCommentItem;
    TGOnegramSliderCollectionItem *_priceItem;
    TGCommentCollectionItem *_priceCommentItem;
    TGVariantCollectionItem *_exceptionsItem;
    TGButtonCollectionItem *_freeLinkItem;

    SMetaDisposable *_saveDisposable;
    SMetaDisposable *_loadDisposable;
    SMetaDisposable *_linkDisposable;
}

@end

@implementation TGPaidMessagesSettingsController

- (instancetype)initWithAccountStars:(int64_t)stars
{
    self = [self initWithChannelId:0 broadcast:false enabled:stars > 0 stars:stars];
    if (self != nil)
    {
        __weak TGPaidMessagesSettingsController *weakSelf = self;
        [_loadDisposable setDisposable:[[[TGPaidMessagesSignals freeExceptionUserIds] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *userIds)
        {
            __strong TGPaidMessagesSettingsController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_exceptionUserIds = userIds;
                [strongSelf updateExceptionsVariant];
            }
        }]];
    }
    return self;
}

- (instancetype)initWithChannelId:(int64_t)channelId broadcast:(bool)broadcast enabled:(bool)enabled stars:(int64_t)stars
{
    self = [super init];
    if (self != nil)
    {
        _channelId = channelId;
        _broadcast = broadcast;
        _enabled = enabled;
        _exceptionUserIds = @[];
        _saveDisposable = [[SMetaDisposable alloc] init];
        _loadDisposable = [[SMetaDisposable alloc] init];
        _linkDisposable = [[SMetaDisposable alloc] init];

        int64_t maxStars = MAX((int64_t)1, [TGPaidMessagesSignals maxStarsPerMessage]);
        int64_t initialStars = stars;
        if (initialStars <= 0 && !_broadcast)
            initialStars = MIN([TGPaidMessagesSignals defaultStarsPerMessage], maxStars);
        _stars = MIN(MAX(initialStars, (int64_t)(_broadcast ? 0 : 1)), maxStars);
        _priceSteps = TGPaidMessagesPriceSteps(maxStars, _broadcast, _stars);

        if (_channelId == 0)
            self.title = TGLocalized(@"PaidMessages.Settings.Title");
        else if (_broadcast)
            self.title = TGLocalized(@"PaidMessages.Settings.DirectTitle");
        else
            self.title = TGLocalized(@"PaidMessages.Settings.GroupTitle");

        __weak TGPaidMessagesSettingsController *weakSelf = self;

        NSString *enabledTitle = _broadcast ? TGLocalized(@"PaidMessages.Settings.DirectEnabled") : TGLocalized(@"PaidMessages.Settings.Charge");
        _enabledItem = [[TGSwitchCollectionItem alloc] initWithTitle:enabledTitle isOn:_enabled];
        _enabledItem.toggled = ^(bool value, __unused TGSwitchCollectionItem *item)
        {
            __strong TGPaidMessagesSettingsController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf setEnabled:value];
        };
        NSString *enabledComment = nil;
        if (_channelId == 0)
            enabledComment = TGLocalized(@"PaidMessages.Settings.ChargeInfo");
        else if (_broadcast)
            enabledComment = TGLocalized(@"PaidMessages.Settings.DirectInfo");
        else
            enabledComment = TGLocalized(@"PaidMessages.Settings.GroupInfo");
        _enabledCommentItem = [[TGCommentCollectionItem alloc] initWithFormattedText:enabledComment];

        NSInteger index = [_priceSteps indexOfObject:@(_stars)];
        _priceItem = [[TGOnegramSliderCollectionItem alloc] initWithTitle:TGLocalized(@"PaidMessages.Settings.Price") minimumValue:0 maximumValue:(NSInteger)_priceSteps.count - 1 value:index == NSNotFound ? 0 : index];
        _priceItem.valueFormatter = ^NSString *(NSInteger value)
        {
            __strong TGPaidMessagesSettingsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return @"";
            return [strongSelf priceStringForStars:[strongSelf starsForIndex:value]];
        };
        _priceItem.valueChanged = ^(NSInteger value)
        {
            __strong TGPaidMessagesSettingsController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_stars = [strongSelf starsForIndex:value];
                [strongSelf updatePriceComment];
            }
        };
        _priceItem.valueCommitted = ^(NSInteger value)
        {
            __strong TGPaidMessagesSettingsController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_stars = [strongSelf starsForIndex:value];
                [strongSelf updatePriceComment];
                [strongSelf commit];
            }
        };
        _priceCommentItem = [[TGCommentCollectionItem alloc] initWithText:@""];

        _exceptionsItem = [[TGVariantCollectionItem alloc] initWithTitle:TGLocalized(@"PaidMessages.Settings.Exceptions") variant:@"" action:@selector(exceptionsPressed)];
        _freeLinkItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"PaidMessages.Settings.FreeLink") action:@selector(freeLinkPressed)];
        _freeLinkItem.deselectAutomatically = true;

        [self updatePriceComment];
        [self updateExceptionsVariant];
        [self setupSections];
    }
    return self;
}

- (void)dealloc
{
    [_saveDisposable dispose];
    [_loadDisposable dispose];
    [_linkDisposable dispose];
}

- (int64_t)starsForIndex:(NSInteger)index
{
    if (_priceSteps.count == 0)
        return 0;
    NSInteger clamped = MAX((NSInteger)0, MIN(index, (NSInteger)_priceSteps.count - 1));
    return [_priceSteps[clamped] longLongValue];
}

- (NSString *)priceStringForStars:(int64_t)stars
{
    if (stars <= 0)
        return TGLocalized(@"PaidMessages.Settings.Free");
    return [TGPaidMessagesSignals starsString:stars];
}

- (void)updatePriceComment
{
    if (_stars <= 0)
    {
        _priceCommentItem.text = TGLocalized(@"PaidMessages.Settings.FreeInfo");
        return;
    }
    int32_t permille = [TGPaidMessagesSignals commissionPermille];
    NSString *percent = permille % 10 == 0 ? [[NSString alloc] initWithFormat:@"%d", (int)(permille / 10)] : [[NSString alloc] initWithFormat:@"%.1f", permille / 10.0];
    int64_t earned = _stars * permille / 1000;
    _priceCommentItem.text = [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.Settings.Earnings"), [TGPaidMessagesSignals starsString:earned], percent];
}

- (void)updateExceptionsVariant
{
    _exceptionsItem.variant = _exceptionUserIds.count == 0 ? TGLocalized(@"PaidMessages.Settings.ExceptionsNone") : [[NSString alloc] initWithFormat:@"%d", (int)_exceptionUserIds.count];
}

- (void)setupSections
{
    while (self.menuSections.sections.count != 0)
        [self.menuSections deleteSection:0];

    TGCollectionMenuSection *enabledSection = [[TGCollectionMenuSection alloc] initWithItems:@[_enabledItem, _enabledCommentItem]];
    UIEdgeInsets insets = enabledSection.insets;
    insets.top = 32.0f;
    enabledSection.insets = insets;
    [self.menuSections addSection:enabledSection];

    if (_enabled)
    {
        TGHeaderCollectionItem *priceHeader = [[TGHeaderCollectionItem alloc] initWithTitle:_broadcast ? TGLocalized(@"PaidMessages.Settings.DirectPriceHeader") : TGLocalized(@"PaidMessages.Settings.PriceHeader")];
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[priceHeader, _priceItem, _priceCommentItem]]];

        if (_channelId == 0)
        {
            [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[_exceptionsItem, [[TGCommentCollectionItem alloc] initWithFormattedText:TGLocalized(@"PaidMessages.Settings.ExceptionsInfo")]]]];
            [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[_freeLinkItem, [[TGCommentCollectionItem alloc] initWithFormattedText:TGLocalized(@"PaidMessages.Settings.FreeLinkInfo")]]]];
        }
    }

    [self.collectionView reloadData];
}

- (void)setEnabled:(bool)enabled
{
    if (_enabled == enabled)
        return;
    _enabled = enabled;
    [self setupSections];
    [self commit];
}

- (void)commit
{
    bool enabled = _enabled;
    int64_t stars = _enabled ? _stars : 0;
    SSignal *signal = nil;
    if (_channelId == 0)
        signal = [TGPaidMessagesSignals setChargeStarsForNonContacts:stars];
    else
        signal = [TGPaidMessagesSignals setChannelPrice:stars channelId:_channelId broadcastMessagesAllowed:_broadcast && enabled];

    __weak TGPaidMessagesSettingsController *weakSelf = self;
    [_saveDisposable setDisposable:[[signal deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error)
    {
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"PaidMessages.Settings.SaveFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    } completed:^
    {
        __strong TGPaidMessagesSettingsController *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf.settingsChanged != nil)
            strongSelf.settingsChanged(enabled, stars);
    }]];
}

- (void)exceptionsPressed
{
    __weak TGPaidMessagesSettingsController *weakSelf = self;
    [self.navigationController pushViewController:[[TGPrivacyCustomShareListController alloc] initWithTitle:TGLocalized(@"PaidMessages.Settings.Exceptions") contactSearchPlaceholder:TGLocalized(@"PaidMessages.Settings.ExceptionsPlaceholder") userIds:_exceptionUserIds dialogs:false userIdsChanged:^(NSArray *userIds)
    {
        __strong TGPaidMessagesSettingsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        NSArray *previous = strongSelf->_exceptionUserIds;
        strongSelf->_exceptionUserIds = userIds ?: @[];
        [strongSelf updateExceptionsVariant];
        [strongSelf->_loadDisposable setDisposable:[[[TGPaidMessagesSignals setFreeExceptionUserIds:strongSelf->_exceptionUserIds] deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error)
        {
            __strong TGPaidMessagesSettingsController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_exceptionUserIds = previous;
                [strongSelf updateExceptionsVariant];
            }
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"PaidMessages.Settings.SaveFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
        } completed:nil]];
    }] animated:true];
}

- (void)freeLinkPressed
{
    [self requestFreeLinkRevoke:false];
}

- (void)requestFreeLinkRevoke:(bool)revoke
{
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.2];
    __weak TGPaidMessagesSettingsController *weakSelf = self;
    [_linkDisposable setDisposable:[[[TGPaidMessagesSignals exportFreeLinkTemporary:false revoke:revoke] deliverOn:[SQueue mainQueue]] startWithNext:^(TGPaidMessagesFreeLink *link)
    {
        [progressWindow dismiss:true];
        __strong TGPaidMessagesSettingsController *strongSelf = weakSelf;
        if (strongSelf != nil && link.url.length != 0)
            [strongSelf presentFreeLink:link];
    } error:^(__unused id error)
    {
        [progressWindow dismiss:true];
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"PaidMessages.Settings.SaveFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    } completed:nil]];
}

- (void)presentFreeLink:(TGPaidMessagesFreeLink *)link
{
    NSString *url = link.url;
    __weak TGPaidMessagesSettingsController *weakSelf = self;
    NSArray *actions = @[
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"PaidMessages.Settings.FreeLinkCopy") action:@"copy"],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"PaidMessages.Settings.FreeLinkShare") action:@"share"],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"PaidMessages.Settings.FreeLinkRevoke") action:@"revoke" type:TGActionSheetActionTypeDestructive],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]
    ];
    TGCustomActionSheet *actionSheet = [[TGCustomActionSheet alloc] initWithTitle:url actions:actions actionBlock:^(__unused id target, NSString *action)
    {
        __strong TGPaidMessagesSettingsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        if ([action isEqualToString:@"copy"])
            [[UIPasteboard generalPasteboard] setString:url];
        else if ([action isEqualToString:@"share"])
            [strongSelf shareFreeLink:url];
        else if ([action isEqualToString:@"revoke"])
            [strongSelf requestFreeLinkRevoke:true];
    } target:self];
    [actionSheet showInView:self.view];
}

- (void)shareFreeLink:(NSString *)url
{
    __weak TGPaidMessagesSettingsController *weakSelf = self;
    CGRect (^sourceRect)(void) = ^CGRect
    {
        __strong TGPaidMessagesSettingsController *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_freeLinkItem.view == nil)
            return CGRectZero;
        return [strongSelf->_freeLinkItem.view convertRect:strongSelf->_freeLinkItem.view.bounds toView:strongSelf.view];
    };
    [TGShareMenu presentInParentController:self menuController:nil buttonTitle:TGLocalized(@"ShareMenu.CopyShareLink") buttonAction:^
    {
        [[UIPasteboard generalPasteboard] setString:url];
    } shareAction:^(NSArray *peerIds, NSString *caption)
    {
        [[TGShareSignals shareText:url toPeerIds:peerIds caption:caption] startWithNext:nil];
    } externalShareItemSignal:[SSignal single:[NSURL URLWithString:url]] sourceView:self.view sourceRect:sourceRect barButtonItem:nil];
}

@end
