#import "../../OnegramRuntime/OGStartupDiagnostics.h"
#import "TGDialogListController.h"
#import "TGCommon.h"
#import "OGPlatformUIKit.h"
#import "../../OnegramPlatform/OGPlatformDispatch.h"
#import "../../OnegramPlatform/OGPlatformVersion.h"
#import "../../OnegramPlatform/OGMemoryCache.h"
#import "../../OnegramRuntime/OGRuntime.h"
#include <inttypes.h>
#import "../../OnegramUI/Lists/OGDialogListDiff.h"
#import "../../OnegramRuntime/OGPluginAvailability.h"
#if OG_PLUGINS_AVAILABLE
#import "../../OnegramPlugins/OGPluginUI.h"
#endif

#import "../../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGDialogListCompanion.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGSearchDisplayMixin.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGListsTableView.h"

#import "../../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

#import "TGDialogListItem.h"

#import "TGDialogListCell.h"
#import "../../submodules/LegacyComponents/LegacyComponents/TGFont.h"
#import "../../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"
#import "TGDialogListSearchCell.h"
#import "TGFlatActionCell.h"

#import "TGActionTableView.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGSearchBar.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGObserverProxy.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#import "../../submodules/LegacyComponents/LegacyComponents/TGModernBarButton.h"

#import "TGDialogListBroadcastsMenuCell.h"

#import "TGGlobalMessageSearchSignals.h"
#import "TGRecentPeersSignals.h"
#import "TGDownloadMessagesSignal.h"

#import "TGLockIconView.h"

#import "TGDatabase.h"
#import "TGAppDelegate.h"

#import "TGDialogListTitleContainer.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGHashtagPanelCell.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGMenuView.h"

#import "TGInterfaceManager.h"

#import "TGModernConversationController.h"
#import "TGGenericModernConversationCompanion.h"
#import "TGFeedConversationCompanion.h"

#import "TGCustomActionSheet.h"
#import "TGActionSheet.h"
#import "../../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGChannelManagementSignals.h"
#import "TGFeedManagementSignals.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGKeyCommandController.h"

#import "TGDialogListRecentPeers.h"
#import "TGDialogListRecentPeersCell.h"

#import "TGChatActionsController.h"
#import "TGPreviewMenu.h"
#import "../../submodules/LegacyComponents/LegacyComponents/TGItemPreviewController.h"
#import "../../submodules/LegacyComponents/LegacyComponents/TGItemMenuSheetPreviewView.h"
#import "TGPreviewConversationItemView.h"
#import "../../submodules/LegacyComponents/LegacyComponents/TGMenuSheetButtonItemView.h"
#import "TGModernConversationTitlePanel.h"

#import "TGCreateContactController.h"

#import "TGCustomAlertView.h"

#include <map>
#include <set>
#include <math.h>

#import "TGGroupManagementSignals.h"

#import "TGTelegraph.h"
#import "TGSynchronizationStateSignal.h"
#import "TGStoriesStore.h"
#import "TGStoryItem.h"
#import "TGStoryRingView.h"
#import "TGStoryViewerController.h"
#import "../../Telegraph/TGUserDataRequestBuilder.h"
#import "../TL/TLRPCusers_getUsers.h"

#import "TGLocalizationSignals.h"
#import "TGSuggestedLocalizationController.h"
#import "TGLocalizationSelectionController.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGTooltipView.h"
#import "../../submodules/LegacyComponents/LegacyComponents/TGDateUtils.h"

#import "TGProxySetupController.h"
#import "../../submodules/MtProtoKit/MTProtoKit/MTProtoKit.h"
#import "TGTelegramNetworking.h"

#import "TGLegacyComponentsContext.h"

#import "TGCreateFeedController.h"

#import "TGOnegramCoreController.h"
#import "TGOnegramSettings.h"
#import "TGSnowflakesView.h"


#import "TGPresentation.h"
#import "../../OnegramUI/Core/OGDialogListAppearance.h"
#import "TGCommunitySheetView.h"
#import "../../Telegraph/TLUser$modernUser.h"
#import "../../Telegraph/TGEmojiStatusView.h"
#import "TGDocumentMediaAttachment+Telegraph.h"
#import "../../legacy/TL/TLMetaRpc.h"
#import "../../legacy/TL/NSOutputStream+TL.h"
#import "../TL/TLInputPeer.h"
#import "../TL/TLInputDialogPeer.h"
#import "../TL/TLRPCmessages_getPeerDialogs.h"
#import "../TL/TLmessages_PeerDialogs.h"
#import "../../Telegraph/TGTelegraphDialogListCompanion.h"
#import "../../Telegraph/TGDialogFilter.h"
#import "../../Telegraph/TGDialogFilterSignals.h"
#import "../../Telegraph/TGDialogFiltersController.h"
#import "../../Telegraph/TGDialogFilterEditController.h"


#include <mach/mach_time.h>
#include <pthread.h>

enum
{
    TGDialogListCostFullReload = 0,
    TGDialogListCostItemsChanged,
    TGDialogListCostConversationUpdates,
    TGDialogListCostFlush,
    TGDialogListCostReloadData,
    TGDialogListCostCell,
    TGDialogListCostHeight,
    TGDialogListCostHydration,
    TGDialogListCostPresentation,
    TGDialogListCostAvatarPrefetch,
    TGDialogListCostFolderTabs,
    TGDialogListCostTitle,
    TGDialogListCostKindCount
};

static const char *const TGDialogListCostNames[TGDialogListCostKindCount] = { "reload", "changed", "conversations", "flush", "reloadData", "cell", "height", "hydrate", "presentation", "avatars", "folderTabs", "title" };
static uint64_t TGDialogListCostTicks[TGDialogListCostKindCount];
static uint32_t TGDialogListCostCalls[TGDialogListCostKindCount];
static int TGDialogListCostCurrentKind = -1;
static uint64_t TGDialogListCostSegmentStart = 0;
static uint64_t TGDialogListCostWindowStart = 0;

static double TGDialogListCostMilliseconds(uint64_t ticks)
{
    static double scale = 0.0;
    if (scale == 0.0)
    {
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        scale = (double)timebase.numer / (double)timebase.denom / 1000000.0;
    }
    return (double)ticks * scale;
}

static void TGDialogListCostReportIfNeeded(uint64_t now)
{
    if (TGDialogListCostWindowStart == 0)
    {
        TGDialogListCostWindowStart = now;
        return;
    }
    double windowMilliseconds = TGDialogListCostMilliseconds(now - TGDialogListCostWindowStart);
    if (windowMilliseconds < 5000.0)
        return;

    NSMutableString *line = [[NSMutableString alloc] initWithFormat:@"DIALOGCOST window_ms=%.0f", windowMilliseconds];
    double total = 0.0;
    for (int kind = 0; kind < TGDialogListCostKindCount; kind++)
    {
        if (TGDialogListCostCalls[kind] == 0)
            continue;
        double milliseconds = TGDialogListCostMilliseconds(TGDialogListCostTicks[kind]);
        total += milliseconds;
        [line appendFormat:@" %s=%.0f/%u", TGDialogListCostNames[kind], milliseconds, TGDialogListCostCalls[kind]];
    }
    if (total >= 1.0)
        OGPlatformDiagnosticLog(@"%@ total=%.0f", line, total);
    memset(TGDialogListCostTicks, 0, sizeof(TGDialogListCostTicks));
    memset(TGDialogListCostCalls, 0, sizeof(TGDialogListCostCalls));
    TGDialogListCostWindowStart = now;
}

struct TGDialogListCostScope
{
    int previousKind;
    bool active;

    explicit TGDialogListCostScope(int kind)
    {
        active = OGDiagnosticsEnabled() && pthread_main_np() != 0;
        previousKind = -1;
        if (!active)
            return;
        uint64_t now = mach_absolute_time();
        if (TGDialogListCostCurrentKind >= 0)
            TGDialogListCostTicks[TGDialogListCostCurrentKind] += now - TGDialogListCostSegmentStart;
        previousKind = TGDialogListCostCurrentKind;
        TGDialogListCostCurrentKind = kind;
        TGDialogListCostSegmentStart = now;
        TGDialogListCostCalls[kind]++;
    }

    ~TGDialogListCostScope()
    {
        if (!active)
            return;
        uint64_t now = mach_absolute_time();
        TGDialogListCostTicks[TGDialogListCostCurrentKind] += now - TGDialogListCostSegmentStart;
        TGDialogListCostCurrentKind = previousKind;
        TGDialogListCostSegmentStart = now;
        if (previousKind < 0)
            TGDialogListCostReportIfNeeded(now);
    }

private:
    TGDialogListCostScope(const TGDialogListCostScope &);
    TGDialogListCostScope &operator=(const TGDialogListCostScope &);
};

#define TG_DIALOG_LIST_COST(kind) TGDialogListCostScope dialogListCostScope(kind)

static CGFloat TGDialogListSearchBarHeight(void)
{
    return [TGPresentation brandedIOS6Style] ? [TGPresentation brandedIOS6DialogListAppearance].searchBarHeight : [TGSearchBar searchBarBaseHeight];
}

static dispatch_queue_t TGDialogListRenderPreheatQueue(void)
{
    return OGRuntimeQueueForPriority(OGRuntimePriorityUtility);
}

static const NSUInteger TGDialogListReloadAvatarPrefetchLimit = 16;
static const CFAbsoluteTime TGDialogListSingleCoreUIUpdateInterval = 0.25;
static const CFAbsoluteTime TGDialogListSingleCoreUIUpdateMaxInterval = 0.8;

static int64_t TGDialogListItemPeerId(id item)
{
    if ([item isKindOfClass:[TGConversation class]])
        return ((TGConversation *)item).conversationId;
    if ([item isKindOfClass:[TGFeed class]])
        return ((TGFeed *)item).conversationId;
    return 0;
}

static id TGDialogListDiffKey(id item, int64_t peerId)
{
    if ([item isKindOfClass:[TGFeed class]])
        return @[@1, @(peerId)];
    return @(peerId);
}

static NSMutableDictionary *TGDialogListItemIndices(NSArray *items)
{
    NSMutableDictionary *indices = [[NSMutableDictionary alloc] initWithCapacity:items.count];
    for (NSUInteger i = 0; i < items.count; i++)
    {
        int64_t peerId = TGDialogListItemPeerId(items[i]);
        if (peerId != 0 && indices[@(peerId)] == nil)
            indices[@(peerId)] = @(i);
    }
    return indices;
}

static NSUInteger TGDialogListHydrationBatchLimit(void)
{
    switch (devicePerformanceClass())
    {
        case TGPerformanceClassConstrained: return 8;
        case TGPerformanceClassBalanced: return 24;
        case TGPerformanceClassFast: return 48;
        case TGPerformanceClassHigh: return 100;
    }
    return 8;
}

static bool TGDialogListSingleCoreDevice(void)
{
    static bool singleCore = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        singleCore = cpuCoreCount() <= 1;
    });
    return singleCore;
}

static NSString *TGDialogListBrandedStatusText(TGConversation *conversation)
{
    if (![TGPresentation brandedIOS6Style] || conversation == nil)
        return nil;
    if (conversation.conversationId == TGTelegraphInstance.clientUserId)
        return nil;
    if (conversation.isChannel || TGPeerIdIsChannel(conversation.conversationId))
        return nil;
    if (TGPeerIdIsGroup(conversation.conversationId))
        return nil;
    if (conversation.conversationId <= 0)
        return nil;

    NSDictionary *dialogListData = conversation.dialogListData;
    NSNumber *onlineValue = dialogListData[@"presenceOnline"];
    NSNumber *lastSeenValue = dialogListData[@"presenceLastSeen"];
    if ([dialogListData[@"isBot"] boolValue])
        return nil;
    if (onlineValue != nil && lastSeenValue != nil)
    {
        if ([onlineValue boolValue])
            return TGLocalized(@"Presence.online");
        int lastSeen = [lastSeenValue intValue];
        if (lastSeen == -1)
            return TGLocalized(@"LastSeen.ALongTimeAgo");
        if (lastSeen != 0)
            return [TGDateUtils stringForRelativeLastSeen:lastSeen];
        return nil;
    }

    return nil;
}

static bool TGDialogListConversationDisplayEqual(TGConversation *lhs, TGConversation *rhs)
{
    if (lhs == rhs)
        return lhs != nil;
    if (lhs == nil || rhs == nil)
        return false;
    if (lhs.unpinnedDate != rhs.unpinnedDate || lhs.pinnedToTop != rhs.pinnedToTop || lhs.unreadMark != rhs.unreadMark || lhs.isAd != rhs.isAd || lhs.hasExplicitContent != rhs.hasExplicitContent || lhs.isChannelGroup != rhs.isChannelGroup || lhs.isChannel != rhs.isChannel || lhs.messageFlags != rhs.messageFlags || TGConversationSortKeyMid(lhs.variantSortKey) != TGConversationSortKeyMid(rhs.variantSortKey))
        return false;
    if (!TGObjectCompare(lhs.feedId, rhs.feedId))
        return false;
    if (![lhs isEqualToConversation:rhs])
        return false;
    NSDictionary *lhsData = lhs.dialogListData;
    NSDictionary *rhsData = rhs.dialogListData;
    return lhsData == rhsData || [lhsData isEqualToDictionary:rhsData];
}

static bool TGDialogListPreviewMessageUnread(TGConversation *conversation)
{
    if (conversation == nil)
        return false;

    if (!TGPeerIdIsChannel(conversation.conversationId))
        return conversation.unread;

    int32_t mid = TGConversationSortKeyMid(conversation.variantSortKey);
    if (conversation.outgoing)
    {
        if (!conversation.isChannelGroup && conversation.deliveryState == TGMessageDeliveryStateDelivered)
            return false;
        return mid >= TGMessageLocalMidBaseline || mid > conversation.maxOutgoingReadMessageId;
    }

    if (mid >= TGMessageLocalMidBaseline)
        return false;
    return mid > conversation.maxReadMessageId;
}

static UIBarButtonItem *TGDialogListBrandedBarButtonItem(NSString *title, id target, SEL action, bool leading)
{
    OGDialogListAppearance *appearance = [TGPresentation brandedIOS6DialogListAppearance];
    CGFloat horizontalInset = appearance.navigationButtonHorizontalInset;
    return [TGPresentation brandedIOS6BarButtonItemWithTitle:title target:target action:action offset:UIOffsetMake(leading ? horizontalInset : -horizontalInset, appearance.navigationButtonVerticalOffset)];
}

static CGFloat TGDialogListBrandedFolderButtonWidth(OGDialogListAppearance *appearance, NSString *title)
{
    return MAX(appearance.folderButtonMinimumWidth, (CGFloat)ceil([title sizeWithFont:appearance.folderButtonFont].width) + appearance.folderButtonHorizontalPadding * 2.0f);
}

@interface TGTelegraphDialogListCompanion (OGCompatFoldersInternal)
- (void)initializeDialogListData:(TGConversation *)conversation customUser:(TGUser *)customUser selfUser:(TGUser *)selfUser;
- (void)ios6MarkFolderOnlyHydrationPeerIds:(NSArray *)peerIds;
@end

@interface TGGroupManagementSignals (OGCompatFolderHydration)
+ (SSignal *)processedDialogs:(TLmessages_PeerDialogs *)result peerId:(int64_t)peerId;
@end

@interface OGCompatGetDialogFiltersRequest : TLMetaRpc
@end

@implementation OGCompatGetDialogFiltersRequest
- (Class)responseClass { return [NSObject class]; }
- (int)impliedResponseSignature { return 0; }
- (int)layerVersion { return 181; }
- (int32_t)TLconstructorSignature { return (int32_t)0xefd48c89; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error { return nil; }
@end

static const CGFloat TGDialogListTitleEmojiStatusSize = 18.0f;

static NSTimeInterval TGDialogListOwnUserRefreshInterval(TGUser *user)
{
    static const NSTimeInterval statusSetInterval = 5.0 * 60.0;
    static const NSTimeInterval statusUnsetInterval = 30.0;
    return user.emojiStatusDocumentId != 0 ? statusSetInterval : statusUnsetInterval;
}

static bool OGCompatDialogListClassicDarkStyle(TGPresentation *presentation)
{
    return [TGPresentation classicThemeStyle] && presentation.pallete.isDark;
}

static UIColor *OGDialogListHeaderTitleColor(TGPresentation *presentation)
{
    if ([TGPresentation brandedIOS6Style])
        return [TGPresentation brandedIOS6NavigationTitleColor];
    if ([TGPresentation classicThemeStyle])
        return [UIColor whiteColor];
    return presentation.pallete.navigationTitleColor;
}

static UIFont *TGDialogListNavigationTitleFont(void)
{
    return [TGPresentation brandedIOS6Style] ? [TGPresentation brandedIOS6NavigationTitleFont] : TGBoldSystemFontOfSize(17.0f);
}

static UIColor *OGDialogListHeaderSubtitleColor(TGPresentation *presentation)
{
    if (![TGPresentation classicThemeStyle])
        return presentation.pallete.navigationSubtitleColor;
    return presentation.pallete.isDark ? presentation.pallete.navigationSubtitleColor : UIColorRGB(0xdbe6ee);
}

static UIColor *TGDialogListNavigationShadowColor(TGPresentation *presentation, CGFloat alpha)
{
    if (![TGPresentation classicThemeStyle])
        return [UIColor clearColor];
    if ([TGPresentation brandedIOS6Style])
        return [TGPresentation brandedIOS6NavigationTitleShadowColor];
    return OGCompatDialogListClassicDarkStyle(presentation) ? UIColorRGBA(0x000000, alpha) : UIColorRGBA(0x1f3446, alpha);
}
#import "TGPreviewPresentationHelper.h"
#import "../../OnegramRuntime/OGRemoteClock.h"

static bool _debugDoNotJump = false;

static int64_t lastAppearedConversationId = 0;
static NSString *const OGCompatArchiveHeaderItem = @"OGCompatArchiveHeaderItem";
static NSString *const OGCompatNewChatListGesturesKey = @"TGIOS6NewChatListGestures";
static NSString *const OGCompatNewChatListGesturesChangedNotification = @"TGIOS6NewChatListGesturesChanged";

static UIImage *OGCompatCenteredScaledBarIcon(UIImage *image, CGFloat scale)
{
    if (image == nil)
        return nil;

    CGSize full = image.size;
    CGSize shrunk = CGSizeMake(floorf(full.width * scale), floorf(full.height * scale));
    CGPoint origin = CGPointMake(floorf((full.width - shrunk.width) / 2.0f), floorf((full.height - shrunk.height) / 2.0f));

    UIGraphicsBeginImageContextWithOptions(full, false, image.scale);
    [image drawInRect:(CGRect){origin, shrunk}];
    UIImage *composed = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return composed;
}

#pragma mark -

@interface UITableViewCell (TG)

- (void)_beginSwiping;

@end

@class TGDialogListController;

@interface TGDialogListControllerReference : NSObject
{
    NSCondition *_condition;
    __weak TGDialogListController *_value;
    NSUInteger _activeCallbacks;
}

- (void)setValue:(TGDialogListController *)value;
- (void)withValue:(void (^)(void *value))block;
- (void)invalidate;

@end

@implementation TGDialogListControllerReference

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        _condition = [[NSCondition alloc] init];
    return self;
}

- (void)setValue:(TGDialogListController *)value
{
    [_condition lock];
    _value = value;
    [_condition unlock];
}

- (void)withValue:(void (^)(void *value))block
{
    if (block == nil)
        return;

    void *value = NULL;
    [_condition lock];
    __attribute__((objc_precise_lifetime)) __strong TGDialogListController *currentValue = _value;
    if (currentValue != nil)
    {
        _activeCallbacks++;
        value = (__bridge void *)currentValue;
    }
    [_condition unlock];

    if (value != NULL)
    {
        @try
        {
            block(value);
        }
        @finally
        {
            [_condition lock];
            if (_activeCallbacks != 0)
                _activeCallbacks--;
            if (_activeCallbacks == 0)
                [_condition broadcast];
            [_condition unlock];
        }
    }
}

- (void)invalidate
{
    [_condition lock];
    _value = nil;
    while (_activeCallbacks != 0)
        [_condition wait];
    [_condition unlock];
}

@end

typedef enum {
    TGDialogListCellContextList = 0,
    TGDialogListCellContextSearch = 1,
    TGDialogListCellContextCommunity = 2
} TGDialogListCellContext;

@interface TGDialogListController () <TGViewControllerNavigationBarAppearance, UITableViewDelegate, UITableViewDataSource, TGSearchDisplayMixinDelegate, TGCreateContactControllerDelegate, TGKeyCommandResponder, UIGestureRecognizerDelegate, TGCommunitySheetViewDataSource>
{
    std::map<int64_t, NSString *> _usersTypingInConversation;
    
    int64_t _scrollingToConversationId;
    int64_t _scheduledScrollToConversationId;
    int64_t _scheduledHighlightAnimationConversationId;
    
    UIView *_headerBackgroundView;
    TGSnowflakesView *_snowflakesView;
    bool _snowflakesOnScreen;
    
    NSArray *_reusableSectionHeaders;
    
    SMetaDisposable *_searchDisposable;
    NSString *_searchResultsQuery;
    
    SMetaDisposable *_recentSearchResultsDisposable;
    
    SVariable *_atTopPromise;
    bool _atTopValue;
    SPipe *_visibleConversationsPipe;
    
    bool _didSelectMessage;
    bool _didSelectGlobalResult;
    bool _ogSearchPullArmed;
    
    TGMenuContainerView *_menuContainerView;
    
    bool _checked3dTouch;
    
    TGItemPreviewHandle *_custom3dTouchHandle;
    bool _reloadWithAnimations;
    
    TGSuggestedLocalization *_suggestedLocalization;
    bool _displayedSuggestedLocalization;
    id<SDisposable> _suggestedLocalizationCodeDisposable;
    bool _isOnScreen;
    
    __weak TGTooltipContainerView *_recordTooltipContainerView;
    bool _displaySavedMessagesTooltip;
    bool _displayProxyIssuesTooltip;
    
    UIView *_titlePanelWrappingView;
    TGModernConversationTitlePanel *_currentTitlePanel;
    TGModernConversationTitlePanel *_primaryTitlePanel;
    
    UIButton *_dimView;
    UIView *_keyboardSnapshotView;
    
    
    TGDialogListState _state;
    
    bool _needsUpdate;
    TGDialogListControllerReference *_ogLifetimeReference;
    bool _ogArchiveExpanded;
    bool _ogArchiveItemsLoadRequested;
    UIView *_ogRefreshContainerView;
    UIView *_ogRefreshBadgeView;
    CAShapeLayer *_ogRefreshProgressLayer;
    UIActivityIndicatorView *_ogRefreshActivityIndicator;
    bool _ogRefreshing;
    bool _ogRefreshSawActivity;
    NSUInteger _ogRefreshGeneration;
    CFAbsoluteTime _ogRefreshStartTime;
    SMetaDisposable *_ogRefreshDisposable;
    NSArray *_ogDialogFilters;
    NSArray *_ogSourceDialogFilters;
    NSArray *_ogFolderTagFilters;
    int32_t _ogSelectedDialogFilterId;
    SMetaDisposable *_ogDialogFiltersDisposable;
    SMetaDisposable *_ogDialogFilterActionDisposable;
    SMetaDisposable *_ogFolderPeerHydrationDisposable;
    NSMutableArray *_ogFolderPeerHydrationQueue;
    bool _ogFolderPeerHydrationActive;
    bool _ogFolderPeerHydrationReconcileScheduled;
    int _ogFolderPeerHydrationLoaded;
    int _ogFolderPeerHydrationFailed;
    NSUInteger _ogFolderPeerHydrationBatchSize;
    NSMutableDictionary *_ogFolderPeerHydrationRetryCounts;
    NSTimeInterval _ogDialogFiltersLastRefreshTime;
    int _ogDialogFiltersAuthorizationRetryCount;
    bool _ogDialogFiltersAuthorizationRetryScheduled;
    int _ogDialogFiltersNetworkRetryCount;
    bool _ogDialogFiltersNetworkRetryScheduled;
    bool _ogDialogFiltersRequestInFlight;
    UIScrollView *_ogFolderTabsScrollView;
    UIView *_ogFolderTabsView;
    UIView *_ogListHeaderView;
    UIView *_ogPlayerHostView;
    CGFloat _ogPlayerHeight;
    int64_t _ogDialogFiltersAccountId;
    NSUInteger _ogDialogFiltersRestoreGeneration;
    UIView *_ogFolderTabsSeparatorView;
    UILabel *_ogFolderEmptyLabel;
    UIPanGestureRecognizer *_ogFolderPanGestureRecognizer;
    UILongPressGestureRecognizer *_ogChatActionsLongPressRecognizer;
    UIView *_ogFolderSwipeContainerView;
    UIImageView *_ogFolderSwipeSourceView;
    UIImageView *_ogFolderSwipeTargetView;
    UIView *_ogFolderSwipeIndicatorView;
    CGFloat _ogFolderSwipeSourceTabsOffset;
    CGFloat _ogFolderSwipeTargetTabsOffset;
    NSInteger _ogFolderSwipeSourceIndex;
    NSInteger _ogFolderSwipeTargetIndex;
    int32_t _ogFolderSwipeSourceFilterId;
    int32_t _ogFolderSwipeTargetFilterId;
    CGPoint _ogFolderSwipeSourceContentOffset;
    CGRect _ogFolderSwipeContentFrame;
    CGRect _ogFolderSwipeSourceIndicatorFrame;
    CGRect _ogFolderSwipeTargetIndicatorFrame;
    CGFloat _ogFolderSwipeTargetOffset;
    bool _ogFolderSwipeActive;
    bool _ogFolderSwipeFinishing;
    NSArray *_ogAllDialogItems;
    NSTimeInterval _ogAllDialogItemsLastRefreshTime;
    bool _ogAllDialogItemsLoading;
    bool _ogFolderCanonicalCacheReady;
    int32_t _ogFolderLocalSourceCursorDate;
    bool _ogFolderLocalSourceExhausted;
    bool _ogFolderLocalSourceContinuationScheduled;
    int32_t _ogFolderLocalSourceGeneration;
    bool _ogFolderPeerLocalLookupInFlight;
    NSMutableSet *_ogFolderPeerLocalLookupAttempted;
    bool _ogLazyLoadScheduled;
    NSArray *_ogVisibleListCache;
    int32_t _ogVisibleListCacheFilterId;
    NSArray *_dialogListDisplayedItems;
    NSString *_ogFolderTabsStateKey;
    bool _ogFolderTabsUpdatePending;
    NSMutableDictionary *_ogDialogSnapshotHydrationPending;
    bool _ogDialogSnapshotHydrationInFlight;
    TGUser *_dialogListSelfUserSnapshot;
    bool _dialogListSelfUserSnapshotResolved;
    bool _dialogListSelfUserSnapshotLoading;
    NSMutableArray *_dialogListSelfUserSnapshotWaiters;
    NSTimeInterval _ownUserRefreshTimestamp;
    bool _ownUserRefreshPending;
    bool _titleEmojiStatusLoadScheduled;
    bool _dialogListFastScrolling;
    int _dialogListFastScrollDirection;
    CGFloat _dialogListLastScrollOffset;
    bool _dialogListVisibleRefreshPending;
    NSMutableArray *_dialogListCoalescedModel;
    NSMutableArray *_dialogListCoalescedAllDialogItems;
    bool _dialogListCoalescedAllDialogItemsDirty;
    bool _dialogListCoalescedHasFullReload;
    bool _dialogListCoalescingUIUpdates;
    bool _dialogListCoalescedReloadPending;
    bool _dialogListCoalescedReloadAnimated;
    bool _dialogListApplyingCoalescedUpdates;
    bool _dialogListRateLimitFlushScheduled;
    CFAbsoluteTime _dialogListLastUIUpdateTime;
    CFAbsoluteTime _dialogListLastFullReloadDuration;
    bool _dialogListOffscreenReloadPending;
    bool _dialogListHiddenCoalesced;
    bool _dialogListAppearingFlush;
    bool _dialogListHiddenFlushScheduled;
    OGMemoryCache *_dialogListPrefetchedAvatarKeys;
    OGMemoryCache *_dialogListPreheatedRenderKeys;
    NSMutableDictionary *_dialogListPreheatedConversations;
    NSArray *_dialogListPreheatContext;
    NSUInteger _dialogListFullPreheatGeneration;
    bool _barButtonItemsApplied;
    NSUInteger _barButtonItemsState;
    TGPresentationPallete *_barButtonItemsPallete;
}

@property (nonatomic, strong) TGSearchBar *searchBar;
@property (nonatomic, strong) UIView *searchTopBackgroundView;
@property (nonatomic, strong) TGSearchDisplayMixin *searchMixin;
@property (nonatomic) bool searchControllerWasLoaded;

@property (nonatomic, strong) TGListsTableView *tableView;
@property (nonatomic) bool editingMode;
@property (nonatomic) CGFloat draggingStartOffset;

@property (nonatomic, strong) NSMutableArray *listModel;

@property (nonatomic, strong) NSArray *searchResultsSections;
@property (nonatomic, strong) NSArray *recentSearchResultsSections;

@property (nonatomic) bool isLoading;

@property (nonatomic, strong) TGDialogListTitleContainer *titleContainer;
@property (nonatomic, strong) UILabel *titleStatusLabel;
@property (nonatomic, strong) UILabel *titleStatusSubtitleLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) TGLockIconView *titleLockIconView;
@property (nonatomic, strong) TGEmojiStatusView *titleEmojiStatusView;

@property (nonatomic, strong) TGActivityIndicatorView *titleStatusIndicator;

@property (nonatomic, strong) UIView *emptyListContainer;

@property (nonatomic, strong) TGObserverProxy *significantTimeChangeProxy;
@property (nonatomic, strong) TGObserverProxy *didEnterBackgroundProxy;
@property (nonatomic, strong) TGObserverProxy *willEnterForegroundProxy;

@property (nonatomic, copy) void (^deleteConversation)(int64_t);
@property (nonatomic, copy) void (^toggleMuteConversation)(int64_t, bool);
@property (nonatomic, copy) void (^togglePinConversation)(int64_t, bool);
@property (nonatomic, copy) void (^toggleGroupConversation)(int64_t, bool);
@property (nonatomic, copy) void (^toggleReadConversation)(int64_t, bool);
@property (nonatomic, copy) void (^archiveToggleHandler)(int64_t, bool);
@property (nonatomic, copy) void (^openCommunity)(int64_t);

- (void)og_synchronizeDialogStateForce:(bool)force;
- (void)og_scheduleFolderPeerHydrationReconciliation;
- (void)og_authorizationReady:(NSNotification *)notification;
- (void)og_restoreDialogFilters;
- (void)dialogListPresentationUpdated;
- (void)og_applyStoredDialogFilters:(NSData *)data accountId:(int64_t)accountId;
- (void)og_storeDialogFilters;
- (void)og_setDialogFilters:(NSArray *)filters;
- (void)og_applyDialogFilters:(NSArray *)filters accountId:(int64_t)accountId;
- (CGFloat)onegramSearchHeaderHeight;
- (NSString *)onegramDialogListTitle;
- (bool)og_newChatListGesturesEnabled;
- (void)og_updateNewChatListGesturesState;
- (void)og_newChatListGesturesChanged:(NSNotification *)notification;
- (NSInteger)og_selectedDialogFilterIndex;
- (bool)dialogListShouldCoalesceUIUpdates;
- (void)dialogListBeginRateLimitedUIUpdate;
- (NSArray *)dialogListDisplayedItems;
- (void)dialogListRefreshVisibleCellsAnimated:(bool)animated;
- (void)dialogListCommitDisplayedItems;
- (void)dialogListCoalesceFullReload:(NSArray *)items;
- (bool)dialogListApplyDisplayedItems:(NSArray *)items animated:(bool)animated;
- (void)dialogListCoalesceConversationUpdates:(NSDictionary *)dict;
- (void)dialogListCoalesceItemsChanged:(NSArray *)insertedIndices insertedItems:(NSArray *)insertedItems updatedIndices:(NSArray *)updatedIndices updatedItems:(NSArray *)updatedItems removedIndices:(NSArray *)removedIndices;
- (void)dialogListFlushCoalescedUpdates;
- (void)dialogListApplyCoalescedUpdates;
- (void)og_selectDialogFilterAtIndex:(NSInteger)index;
- (void)og_storeSelectedDialogFilterId;
- (void)og_completeDialogFilterSelectionAtIndex:(NSInteger)index;
- (CGRect)og_folderSwipeTabsRect;
- (CGRect)og_folderSwipeContentRect;
- (UIImage *)og_folderSwipeSnapshotForRect:(CGRect)rect;
- (void)og_beginFolderSwipeToIndex:(NSInteger)targetIndex translation:(CGPoint)translation;
- (void)og_updateFolderSwipeWithTranslation:(CGPoint)translation;
- (void)og_finishFolderSwipeCommit:(bool)commit velocity:(CGPoint)velocity;
- (void)og_cancelFolderSwipeImmediately;
- (UIView *)og_folderSwipeIndicatorForButton:(UIButton *)button;
- (CGFloat)og_folderTabsOffsetRevealingButton:(UIButton *)button fromOffset:(CGFloat)offset;
- (CGFloat)og_folderSwipeTargetContentOffsetForSourceOffset:(CGFloat)sourceOffset;
- (void)og_applyFolderSwipeTranslation:(CGFloat)x;
- (void)og_restoreFolderSwipeSource;
- (void)og_teardownFolderSwipe;
- (void)og_folderPanGesture:(UIPanGestureRecognizer *)recognizer;
- (void)og_chatActionsLongPress:(UILongPressGestureRecognizer *)recognizer;
- (void)og_folderTabLongPress:(UILongPressGestureRecognizer *)recognizer;
- (void)og_presentAddToFolderForConversation:(TGConversation *)conversation fromRect:(CGRect)sourceRect;
- (void)og_removeConversation:(TGConversation *)conversation fromDialogFilterId:(int32_t)filterId;
- (NSString *)dialogListAvatarFilter;
- (void)og_scheduleCompleteDialogHydrationAndAvatarPrefetch;

@end

NSString *authorNameYou = @"  __TGLocalized__YOU";

static const CGFloat TGDialogListArchiveHeaderHeight = 54.0f;

@interface TGDialogListArchiveHeaderCell : UITableViewCell
{
    UIImageView *_brandedBackgroundView;
    UIView *_container;
    UIImageView *_badgeBackgroundView;
    UILabel *_badgeLabel;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UILabel *_arrowLabel;
    TGPresentation *_presentation;
    bool _branded;
}

- (void)setPresentation:(TGPresentation *)presentation branded:(bool)branded;
- (void)setArchivedCount:(NSUInteger)archivedCount unreadCount:(int)unreadCount expanded:(bool)expanded;

@end

@implementation TGDialogListArchiveHeaderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        self.selectionStyle = UITableViewCellSelectionStyleGray;
        self.accessoryType = UITableViewCellAccessoryNone;

        _container = [[UIView alloc] init];
        _container.backgroundColor = UIColorRGB(0xf3f8fc);
        _container.layer.cornerRadius = 7.0f;
        _container.layer.borderWidth = TGIsRetina() ? 0.5f : 1.0f;
        _container.layer.borderColor = UIColorRGB(0xd8e8f4).CGColor;
        [self.contentView addSubview:_container];

        _badgeBackgroundView = [[UIImageView alloc] initWithImage:TGCircleImage(26.0f, UIColorRGB(0x4a90d9))];
        _badgeBackgroundView.frame = CGRectMake(12.0f, 8.0f, 26.0f, 26.0f);
        [_container addSubview:_badgeBackgroundView];

        _badgeLabel = [[UILabel alloc] initWithFrame:_badgeBackgroundView.frame];
        _badgeLabel.backgroundColor = [UIColor clearColor];
        _badgeLabel.textColor = [UIColor whiteColor];
        _badgeLabel.font = TGBoldSystemFontOfSize(17.0f);
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.text = @"A";
        [_container addSubview:_badgeLabel];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.text = @"Archived Chats";
        _titleLabel.font = TGBoldSystemFontOfSize(16.0f);
        _titleLabel.textColor = UIColorRGB(0x2f6ea5);
        [_container addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.font = TGSystemFontOfSize(12.0f);
        _subtitleLabel.textColor = UIColorRGB(0x7d8b96);
        [_container addSubview:_subtitleLabel];

        _arrowLabel = [[UILabel alloc] init];
        _arrowLabel.backgroundColor = [UIColor clearColor];
        _arrowLabel.textAlignment = NSTextAlignmentCenter;
        _arrowLabel.textColor = UIColorRGB(0x7d8b96);
        _arrowLabel.font = TGBoldSystemFontOfSize(18.0f);
        [_container addSubview:_arrowLabel];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation branded:(bool)branded
{
    if (_presentation == presentation && _branded == branded)
        return;
    _presentation = presentation;
    _branded = branded;

    UIImage *backgroundImage = branded ? [TGPresentation brandedIOS6DialogCellBackgroundImageForHeight:TGDialogListArchiveHeaderHeight] : nil;
    if (backgroundImage != nil)
    {
        if (_brandedBackgroundView == nil)
        {
            _brandedBackgroundView = [[UIImageView alloc] init];
            _brandedBackgroundView.opaque = true;
            _brandedBackgroundView.userInteractionEnabled = false;
        }
        _brandedBackgroundView.image = backgroundImage;
        self.backgroundView = _brandedBackgroundView;
        self.backgroundColor = [TGPresentation brandedIOS6DialogCellBackgroundColor];
        self.contentView.backgroundColor = [UIColor clearColor];
    }
    else
    {
        if (_brandedBackgroundView != nil && self.backgroundView == _brandedBackgroundView)
            self.backgroundView = nil;
        self.backgroundColor = presentation.pallete.backgroundColor;
        self.contentView.backgroundColor = presentation.pallete.backgroundColor;
    }
}

- (void)setArchivedCount:(NSUInteger)archivedCount unreadCount:(int)unreadCount expanded:(bool)expanded
{
    NSString *subtitle = unreadCount > 0 ? [NSString stringWithFormat:@"%d unread", unreadCount] : [NSString stringWithFormat:@"%d chats", (int)archivedCount];
    if (![_subtitleLabel.text isEqualToString:subtitle])
        _subtitleLabel.text = subtitle;
    NSString *arrow = expanded ? @"v" : @">";
    if (![_arrowLabel.text isEqualToString:arrow])
        _arrowLabel.text = arrow;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = MAX(1.0f, self.contentView.bounds.size.width - 16.0f);
    _container.frame = CGRectMake(8.0f, 6.0f, width, 42.0f);
    _titleLabel.frame = CGRectMake(48.0f, 5.0f, width - 96.0f, 19.0f);
    _subtitleLabel.frame = CGRectMake(48.0f, 24.0f, width - 96.0f, 15.0f);
    _arrowLabel.frame = CGRectMake(width - 38.0f, 0.0f, 30.0f, 42.0f);
}

@end

@implementation TGDialogListController

+ (void)setLastAppearedConversationId:(int64_t)conversationId
{
    lastAppearedConversationId = conversationId;
}

+ (void)setDebugDoNotJump:(bool)debugDoNotJump
{
    _debugDoNotJump = debugDoNotJump;
}

+ (bool)debugDoNotJump
{
    return _debugDoNotJump;
}

- (id)initWithCompanion:(TGDialogListCompanion *)companion
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        self.automaticallyManageScrollViewInsets = true;
        self.ignoreKeyboardWhenAdjustingScrollViewInsets = !TGIsPad();

        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _atTopPromise = [[SVariable alloc] init];
        _atTopValue = true;
        [_atTopPromise set:[SSignal single:@true]];
        
        _visibleConversationsPipe = [[SPipe alloc] init];
        
        __weak TGDialogListController *weakSelf = self;
        
        _listModel = [[NSMutableArray alloc] init];
        _ogLifetimeReference = [[TGDialogListControllerReference alloc] init];
        [_ogLifetimeReference setValue:self];
        _ogDialogFilters = @[];
        _ogSourceDialogFilters = @[];
        _ogAllDialogItems = @[];
        _ogFolderLocalSourceCursorDate = INT32_MAX;
        _ogFolderPeerLocalLookupAttempted = [[NSMutableSet alloc] init];
        _ogVisibleListCacheFilterId = INT32_MIN;
        _dialogListDisplayedItems = @[];
        _ogSelectedDialogFilterId = companion.forwardMode ? 0 : (int32_t)[[NSUserDefaults standardUserDefaults] integerForKey:@"TGIOS6SelectedDialogFilterId"];
        _ogDialogFiltersDisposable = [[SMetaDisposable alloc] init];
        _ogDialogFilterActionDisposable = [[SMetaDisposable alloc] init];
        _ogFolderPeerHydrationDisposable = [[SMetaDisposable alloc] init];
        _ogFolderPeerHydrationQueue = [[NSMutableArray alloc] init];
        _ogFolderPeerHydrationRetryCounts = [[NSMutableDictionary alloc] init];
        _ogDialogSnapshotHydrationPending = [[NSMutableDictionary alloc] init];
        _dialogListSelfUserSnapshotWaiters = [[NSMutableArray alloc] init];
        
        _reusableSectionHeaders = [[NSArray alloc] initWithObjects:[[NSMutableArray alloc] init], [[NSMutableArray alloc] init], nil];
        
        _dialogListCompanion = companion;
        [self og_restoreDialogFilters];
        _dialogListCompanion.dialogListController = self;
        
        _significantTimeChangeProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(significantTimeChange:) name:UIApplicationSignificantTimeChangeNotification];
        _didEnterBackgroundProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification];
        _willEnterForegroundProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(og_clearChatCacheRequested:) name:@"TGIOS6ClearChatListCacheRequested" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(og_dialogFiltersUpdated:) name:@"TGIOS6DialogFiltersUpdated" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dialogFiltersDidChange:) name:TGDialogFiltersDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(og_authorizationReady:) name:TGAuthorizationReadyNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(og_newChatListGesturesChanged:) name:OGCompatNewChatListGesturesChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onegramSettingsChanged:) name:TGOnegramSettingsDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storiesStoreChanged:) name:TGStoriesStoreDidChangeNotification object:nil];
        
        _doNotHideSearchAutomatically = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
        
        self.deleteConversation = ^(int64_t peerId) {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                NSIndexPath *indexPath = [strongSelf indexPathForConversationId:peerId];
                if (indexPath != nil) {
                    [(TGDialogListCell *)[strongSelf->_tableView cellForRowAtIndexPath:indexPath] setEditingConrolsExpanded:false animated:true];
                    [strongSelf tableView:strongSelf->_tableView commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:indexPath];
                }
            }
        };
        self.toggleMuteConversation = ^(int64_t peerId, bool mute) {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                NSIndexPath *indexPath = [strongSelf indexPathForConversationId:peerId];
                if (indexPath != nil) {
                    TGConversation *conversation = (TGConversation *)[strongSelf og_dialogListItemAtIndexPath:indexPath];
                    NSDictionary *dialogListData = conversation.dialogListData;
                    [(TGDialogListCell *)[strongSelf->_tableView cellForRowAtIndexPath:indexPath] setEditingConrolsExpanded:false animated:true];
                    if ([[dialogListData objectForKey:@"mute"] boolValue] != mute) {
                        static int actionId = 0;
                        int muteUntil = !mute ? 0 : INT32_MAX;
                        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%" PRId64 ")/(dialogListMute%d)", conversation.conversationId, actionId++] options:@{@"peerId": @(conversation.conversationId), @"accessHash": @(conversation.accessHash), @"muteUntil": @(muteUntil)} watcher:TGTelegraphInstance];
                    }
                }
            }
        };
        self.togglePinConversation = ^(int64_t peerId, bool pin) {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                NSIndexPath *indexPath = [strongSelf indexPathForConversationId:peerId];
                if (indexPath != nil) {
                    TGConversation *conversation = (TGConversation *)[strongSelf og_dialogListItemAtIndexPath:indexPath];
                    if (conversation.pinnedToTop != pin) {
                        if (pin) {
                            int32_t maxPinnedChats = 5;
                            NSData *data = [TGDatabaseInstance() customProperty:@"maxPinnedChats"];
                            if (data.length == 4) {
                                [data getBytes:&maxPinnedChats length:4];
                                maxPinnedChats = MAX(maxPinnedChats, 5);
                            }
                            NSInteger pinnedCount = 0;
                            NSInteger secretPinnedCount = 0;
                            for (TGConversation *conversation in strongSelf->_listModel) {
                                if (conversation.pinnedToTop) {
                                    if (TGPeerIdIsSecretChat(conversation.conversationId)) {
                                        secretPinnedCount++;
                                    } else {
                                        pinnedCount++;
                                    }
                                }
                            }
                            
                            [(TGDialogListCell *)[strongSelf->_tableView cellForRowAtIndexPath:indexPath] setEditingConrolsExpanded:false animated:true];
                            if ((TGPeerIdIsSecretChat(peerId) && secretPinnedCount >= maxPinnedChats) || (!TGPeerIdIsSecretChat(peerId) && pinnedCount >= maxPinnedChats)) {
                                [TGCustomAlertView presentAlertWithTitle:nil message:[NSString stringWithFormat: TGLocalized(@"DialogList.PinLimitError"), [NSString stringWithFormat:@"%d", maxPinnedChats]] cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                            } else {
                                strongSelf->_reloadWithAnimations = true;
                                [[[TGGroupManagementSignals updatePinnedState:conversation.conversationId pinned:true] onDispose:^{
                                }] startWithNext:nil];
                                if (strongSelf->_tableView.contentOffset.y > FLT_EPSILON) {
                                    [strongSelf scrollToTopRequested];
                                }
                            }
                        } else {
                            strongSelf->_reloadWithAnimations = true;
                            [(TGDialogListCell *)[strongSelf->_tableView cellForRowAtIndexPath:indexPath] setEditingConrolsExpanded:false animated:true];
                            [[[TGGroupManagementSignals updatePinnedState:conversation.conversationId pinned:false] onDispose:^{
                            }] startWithNext:nil];
                        }
                    }
                }
            }
        };
        self.openCommunity = ^(int64_t peerId) {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf openCommunityForConversationId:peerId];
        };
        self.archiveToggleHandler = ^(int64_t peerId, bool archived) {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            NSIndexPath *indexPath = [strongSelf indexPathForConversationId:peerId];
            TGConversation *conversation = indexPath == nil ? nil : (TGConversation *)[strongSelf og_dialogListItemAtIndexPath:indexPath];
            if (![conversation isKindOfClass:[TGConversation class]] || conversation.isArchived == archived)
                return;

            [(TGDialogListCell *)[strongSelf->_tableView cellForRowAtIndexPath:indexPath] setEditingConrolsExpanded:false animated:true];
            [TGTelegraphInstance doSetConversationArchived:peerId accessHash:conversation.accessHash archived:archived completion:nil];
            conversation.isArchived = archived;
            [TGDatabaseInstance() setConversationsArchiveState:@{@(peerId): @(archived)}];
            [strongSelf updateBarButtonItemsAnimated:false];
            [strongSelf reloadData:false];
        };
        self.toggleGroupConversation = ^(int64_t peerId, bool group)
        {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                NSIndexPath *indexPath = [strongSelf indexPathForConversationId:peerId];
                if (indexPath != nil) {
                    TGConversation *conversation = (TGConversation *)[strongSelf og_dialogListItemAtIndexPath:indexPath];
                    bool grouped = conversation.feedId.intValue != 0;
                    if (grouped != group) {
                        if ([TGDatabaseInstance() loadFeed:1] != nil)
                        {
                            [ActionStageInstance() dispatchResource:@"/tg/conversationsGrouped/(animated)" resource:[[SGraphObjectNode alloc] initWithObject:@[conversation]]];
                            
                            if (group) {
                                [[TGFeedManagementSignals groupChannelWithPeerId:conversation.conversationId feedId:1] startWithNext:nil];
                            } else {
                                [[TGFeedManagementSignals ungroupChannelWithPeerId:conversation.conversationId] startWithNext:nil];
                            }
                        }
                        else
                        {
                            TGCreateFeedController *controller = [[TGCreateFeedController alloc] initWithConversation:conversation];
                            [strongSelf.navigationController pushViewController:controller animated:true];
                        }
                    }
                    [(TGDialogListCell *)[strongSelf->_tableView cellForRowAtIndexPath:indexPath] setEditingConrolsExpanded:false animated:true];
                }
            }
        };
        self.toggleReadConversation = ^(int64_t peerId, bool read)
        {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                NSIndexPath *indexPath = [strongSelf indexPathForConversationId:peerId];
                if (indexPath != nil) {
                    TGConversation *conversation = (TGConversation *)[strongSelf og_dialogListItemAtIndexPath:indexPath];
                    bool isRead = !conversation.unreadMark && conversation.unreadCount == 0 && conversation.serviceUnreadCount == 0 && conversation.unreadMentionCount == 0;
                    if (read != isRead)
                    {
                        if (read)
                        {
                            [TGDatabaseInstance() transactionReadHistoryForPeerIds:@[[[TGReadPeerMessagesRequest alloc] initWithPeerId:peerId maxMessageIndex:nil date:0 length:0 unread:false]]];
                            
                            if (conversation.unreadMentionCount > 0)
                                [[TGDownloadMessagesSignal clearUnseenMentions:conversation.conversationId] startWithNext:nil];
                        }
                        else
                        {
                            [TGDatabaseInstance() transactionReadHistoryForPeerIds:@[[[TGReadPeerMessagesRequest alloc] initWithPeerId:peerId maxMessageIndex:nil date:0 length:0 unread:true]]];
                        }
                    }
                }
            }
        };
        
        _suggestedLocalizationCodeDisposable = [[[[SSignal complete] delay:2.0 onQueue:[SQueue mainQueue]] then:[[[TGDatabaseInstance() suggestedLocalizationCode] mapToSignal:^SSignal *(NSString *code) {
            if (code.length == 0 || [code isEqualToString:@"en"] || [code isEqualToString:currentNativeLocalization().code]) {
                return [SSignal single:nil];
            } else {
                NSData *data = [TGDatabaseInstance() customProperty:@"checkedLocalization"];
                if (data.length != 0) {
                    return [SSignal single:nil];
                } else {
                    return [TGLocalizationSignals suggestedLocalizationData:code];
                }
            }
        }] deliverOn:[SQueue mainQueue]]] startWithNext:^(TGSuggestedLocalization *result) {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil && [result isKindOfClass:[TGSuggestedLocalization class]]) {
                strongSelf->_suggestedLocalization = result;
                if (result != nil && strongSelf->_isOnScreen && !strongSelf->_displayedSuggestedLocalization) {
                    strongSelf->_displayedSuggestedLocalization = true;
                    [strongSelf displaySuggestedLocalization];
                }
            }
        }];
    }
    return self;
}

- (void)dealloc
{
    if (_dialogListFastScrolling)
    {
        _dialogListFastScrolling = false;
        OGRuntimeEndInteraction();
    }
    [_ogLifetimeReference invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"TGIOS6ClearChatListCacheRequested" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"TGIOS6DialogFiltersUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGDialogFiltersDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGAuthorizationReadyNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:OGCompatNewChatListGesturesChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGOnegramSettingsDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGStoriesStoreDidChangeNotification object:nil];
    [_ogDialogFiltersDisposable dispose];
    [_ogDialogFilterActionDisposable dispose];
    [_ogFolderPeerHydrationDisposable dispose];
    [_ogRefreshDisposable dispose];
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    
    _dialogListCompanion.dialogListController = nil;
    
    [self doUnloadView];
    
    [_searchDisposable dispose];
    [_recentSearchResultsDisposable dispose];
    [_suggestedLocalizationCodeDisposable dispose];
}

- (SSignal *)atTopSignal {
    return _atTopPromise.signal;
}

- (SSignal *)visibleUnreadDialogsCountSignal {
    SSignal *update = [SSignal defer:^SSignal *
    {
        int32_t count = 0;
        for (TGDialogListCell *cell in _tableView.visibleCells)
        {
            if (cell.unreadMark || cell.unreadCount > 0 || cell.serviceUnreadCount > 0)
                count++;
        }
        return [SSignal single:@(count)];
    }];
    
    return [[self atTopSignal] mapToSignal:^SSignal *(NSNumber *atTop)
    {
        if (atTop) {
            return [update then:[_visibleConversationsPipe.signalProducer() mapToSignal:^SSignal *(__unused id value)
            {
                return update;
            }]];
        }
        else
        {
            return [SSignal single:@0];
        }
    }];
}

- (int64_t)currentVisibleUnreadConversation {
    if (_scrollingToConversationId != 0)
        return _scrollingToConversationId;
    
    NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:[self.view convertPoint:CGPointMake(0.0f, CGRectGetMidY(_tableView.frame)) toView:_tableView]];
    TGConversation *conversation = nil;
    id item = [self og_dialogListItemAtIndexPath:indexPath];
    if ([item isKindOfClass:[TGConversation class]])
        conversation = item;
    return conversation.conversationId;
}

- (void)scrollToConversationWithId:(int64_t)conversationId {
    NSIndexPath *indexPath = [self indexPathForConversationId:conversationId];
    if (indexPath != nil) {
        _scheduledScrollToConversationId = 0;
        _scheduledHighlightAnimationConversationId = 0;
        
        TGDialogListCell *cell = [_tableView cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:[TGDialogListCell class]])
            [cell animateHighlight];
        else
            _scheduledHighlightAnimationConversationId = conversationId;
        
        [_tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:true];
        _scrollingToConversationId = conversationId;
    } else if (_scheduledScrollToConversationId == 0) {
        if (_canLoadMore) {
            _scheduledScrollToConversationId = conversationId;
            [_dialogListCompanion loadMoreItems:1000];
        }
    }
}

- (void)openCommunityForConversationId:(int64_t)conversationId
{
    NSIndexPath *indexPath = [self indexPathForConversationId:conversationId];
    if (indexPath == nil)
        return;

    TGConversation *conversation = (TGConversation *)[self og_dialogListItemAtIndexPath:indexPath];
    if (![conversation isKindOfClass:[TGConversation class]] || conversation.linkedCommunityId == 0)
        return;

    [(TGDialogListCell *)[_tableView cellForRowAtIndexPath:indexPath] setEditingConrolsExpanded:false animated:true];

    TGCommunitySheetView *sheetView = [[TGCommunitySheetView alloc] initWithConversation:conversation presentation:_presentation dataSource:self];
    __weak TGDialogListController *weakSelf = self;
    sheetView.conversationSelected = ^(TGConversation *selectedConversation, bool joined)
    {
        __strong TGDialogListController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf openCommunityConversation:selectedConversation joined:joined];
    };

    UIView *hostView = self.navigationController.view != nil ? self.navigationController.view : self.view;
    [sheetView showInView:hostView];
}

- (CGFloat)dialogListConversationRowHeight
{
    return [TGPresentation brandedIOS6Style] ? [TGPresentation brandedIOS6DialogListAppearance].rowHeight : 76.0f;
}

- (void)applyConversationTableSeparators:(UITableView *)tableView
{
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if (iosMajorVersion() >= 7 && !OGCompatDialogListClassicDarkStyle(_presentation))
    {
        tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        tableView.separatorColor = _presentation.pallete.separatorColor;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        tableView.separatorInset = UIEdgeInsetsMake(0.0f, 80.0f, 0.0f, 0.0f);
#endif
    }
}

- (void)applyConversationCellBackground:(TGDialogListCell *)cell
{
    if (iosMajorVersion() < 7)
        cell.backgroundColor = [cell preferredBackgroundColor];
}

- (void)communitySheetView:(TGCommunitySheetView *)__unused sheetView tableView:(UITableView *)__unused tableView willDisplayCell:(UITableViewCell *)cell
{
    if ([cell isKindOfClass:[TGDialogListCell class]])
        [self applyConversationCellBackground:(TGDialogListCell *)cell];
}

- (void)communitySheetView:(TGCommunitySheetView *)__unused sheetView configureTableView:(UITableView *)tableView
{
    tableView.backgroundColor = _presentation.pallete.backgroundColor;
    tableView.rowHeight = [self dialogListConversationRowHeight];
    [self applyConversationTableSeparators:tableView];
}

- (SSignal *)communitySheetView:(TGCommunitySheetView *)__unused sheetView displayConversations:(NSArray *)conversations
{
    if (![_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]])
        return [SSignal single:conversations];

    NSMutableDictionary *listConversations = [[NSMutableDictionary alloc] init];
    for (NSArray *items in @[_ogAllDialogItems ?: @[], _listModel ?: @[]])
    {
        for (id item in items)
        {
            if ([item isKindOfClass:[TGConversation class]])
                listConversations[@(((TGConversation *)item).conversationId)] = item;
        }
    }

    NSMutableArray *sources = [[NSMutableArray alloc] initWithCapacity:conversations.count];
    for (TGConversation *conversation in conversations)
    {
        bool joined = !conversation.leftChat && !conversation.kickedFromChat;
        TGConversation *listConversation = joined ? listConversations[@(conversation.conversationId)] : nil;
        if (listConversation == nil)
            [sources addObject:[NSNull null]];
        else
            [sources addObject:listConversation.dialogListData.count != 0 ? listConversation : [listConversation copy]];
    }

    TGTelegraphDialogListCompanion *dialogListCompanion = (TGTelegraphDialogListCompanion *)_dialogListCompanion;
    int64_t clientUserId = TGTelegraphInstance.clientUserId;
    return [[SSignal defer:^SSignal *
    {
        TGUser *selfUser = clientUserId == 0 ? nil : [TGDatabaseInstance() loadUser:clientUserId];
        NSMutableArray *displayConversations = [[NSMutableArray alloc] initWithCapacity:conversations.count];
        [conversations enumerateObjectsUsingBlock:^(TGConversation *conversation, NSUInteger index, __unused BOOL *stop)
        {
            TGConversation *display = [sources[index] isKindOfClass:[TGConversation class]] ? sources[index] : nil;
            if (display == nil)
            {
                bool joined = !conversation.leftChat && !conversation.kickedFromChat;
                TGConversation *stored = joined ? [TGDatabaseInstance() loadConversationWithId:conversation.conversationId] : nil;
                display = [(stored != nil ? stored : conversation) copy];
            }
            if (display.dialogListData.count == 0)
                [dialogListCompanion initializeDialogListData:display customUser:nil selfUser:selfUser];
            [displayConversations addObject:display];
        }];
        return [SSignal single:displayConversations];
    }] startOn:[SQueue concurrentDefaultQueue]];
}

- (UITableViewCell *)communitySheetView:(TGCommunitySheetView *)__unused sheetView tableView:(UITableView *)tableView cellForConversation:(TGConversation *)conversation
{
    static NSString *CommunityCellIdentifier = @"CMC";
    TGDialogListCell *cell = [tableView dequeueReusableCellWithIdentifier:CommunityCellIdentifier];
    if (cell == nil)
    {
        cell = [[TGDialogListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CommunityCellIdentifier assetsSource:[_dialogListCompanion dialogListCellAssetsSource]];
        cell.watcherHandle = _actionHandle;
        cell.enableEditing = false;
    }

    cell.presentation = _presentation;
    cell.disableActions = true;
    [self prepareCell:cell forConversation:conversation animated:false context:TGDialogListCellContextCommunity];
    return cell;
}

- (void)openCommunityConversation:(TGConversation *)conversation joined:(bool)joined
{
    if (joined)
    {
        [[TGInterfaceManager instance] navigateToConversationWithId:conversation.conversationId conversation:nil];
        return;
    }

    conversation.kind = TGConversationKindTemporaryChannel;
    [[[[TGChannelManagementSignals addChannel:conversation] deliverOn:[SQueue mainQueue]] takeLast] startWithNext:^(TGConversation *next)
    {
        [[TGInterfaceManager instance] navigateToConversationWithId:conversation.conversationId conversation:next];
    }];
}

- (NSIndexPath *)indexPathForConversationId:(int64_t)conversationId {
    NSUInteger index = 0;
    for (id item in [self dialogListDisplayedItems]) {
        if ([item isKindOfClass:[TGConversation class]] && ((TGConversation *)item).conversationId == conversationId) {
            return [NSIndexPath indexPathForRow:index inSection:1];
        }
        index++;
    }
    return nil;
}

- (void)_loadStatusViews
{
    if (_titleStatusLabel == nil)
    {
        _titleStatusLabel = [[UILabel alloc] init];
        _titleStatusLabel.clipsToBounds = false;
        _titleStatusLabel.backgroundColor = [UIColor clearColor];
        _titleStatusLabel.textColor = OGDialogListHeaderTitleColor(_presentation);
        _titleStatusLabel.shadowColor = TGDialogListNavigationShadowColor(_presentation, 0.9f);
        _titleStatusLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
        _titleStatusLabel.font = TGBoldSystemFontOfSize(16.0f);
        [_titleContainer addSubview:_titleStatusLabel];
        
        _titleStatusSubtitleLabel = [[UILabel alloc] init];
        _titleStatusSubtitleLabel.clipsToBounds = false;
        _titleStatusSubtitleLabel.backgroundColor = [UIColor clearColor];
        _titleStatusSubtitleLabel.textColor = OGDialogListHeaderSubtitleColor(_presentation);
        _titleStatusSubtitleLabel.shadowColor = TGDialogListNavigationShadowColor(_presentation, 0.72f);
        _titleStatusSubtitleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
        _titleStatusSubtitleLabel.font = TGSystemFontOfSize(12.0f);
        _titleStatusSubtitleLabel.hidden = true;
        [_titleContainer addSubview:_titleStatusSubtitleLabel];
        
        _titleStatusIndicator = [[TGActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _titleStatusIndicator.color = _presentation.pallete.navigationSpinnerColor;
        [_titleContainer addSubview:_titleStatusIndicator];
    }
}

- (UIBarButtonItem *)editingControl
{
    if (![_dialogListCompanion showListEditingControl])
        return nil;
    
    if (!_editingMode)
    {
        return [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Edit") style:UIBarButtonItemStylePlain target:self action:@selector(editButtonPressed)];
    }
    else
    {
        return [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Done") style:UIBarButtonItemStyleDone target:self action:@selector(doneButtonPressed)];
    }
}

- (UIBarButtonItem *)og_archiveBarButtonItem
{
    if (_ogSelectedDialogFilterId != 0)
        return nil;
    if ([TGOnegramSettings boolForKey:TGOnegramSettingGeneralHideArchive] && !_ogArchiveExpanded)
        return nil;

    if ([TGPresentation brandedIOS6Style])
        return TGDialogListBrandedBarButtonItem(_ogArchiveExpanded ? @"Chats" : @"Archive", self, @selector(archiveButtonPressed:), true);
    if ([TGPresentation classicThemeStyle])
        return [[UIBarButtonItem alloc] initWithTitle:(_ogArchiveExpanded ? @"Chats" : @"Archive") style:UIBarButtonItemStyleBordered target:self action:@selector(archiveButtonPressed:)];

    UIColor *tint = self.presentation.pallete.navigationButtonColor;
    UIButton *toggle = [UIButton buttonWithType:UIButtonTypeCustom];
    toggle.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    toggle.titleLabel.font = TGSystemFontOfSize(17.0f);
    toggle.frame = CGRectMake(0.0f, 0.0f, 70.0f, 44.0f);
    [toggle setTitle:(_ogArchiveExpanded ? @"Chats" : @"Archive") forState:UIControlStateNormal];
    [toggle setTitleColor:tint forState:UIControlStateNormal];
    [toggle setTitleColor:[tint colorWithAlphaComponent:0.4f] forState:UIControlStateHighlighted];
    [toggle addTarget:self action:@selector(archiveButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    return [[UIBarButtonItem alloc] initWithCustomView:toggle];
}

- (UIBarButtonItem *)controllerLeftBarButtonItem
{
    return [self og_archiveBarButtonItem];
}

- (void)scrollToTopRequested
{
    if (_ogArchiveExpanded)
    {
        _ogArchiveExpanded = false;
        [self updateBarButtonItemsAnimated:false];
        [self reloadData:false];
        if ([self dialogListDisplayedItems].count != 0)
            [_tableView setContentOffset:CGPointMake(0.0f, -_tableView.contentInset.top) animated:false];
        return;
    }

    [self scrollToTop];
}

- (void)scrollToTop
{
    [_tableView scrollToTop];
}

- (void)titleStateUpdated:(NSString *)text state:(TGDialogListState)state
{
    TG_DIALOG_LIST_COST(TGDialogListCostTitle);
    _state = state;
    
    if (text == nil)
    {
        _titleStatusLabel.hidden = true;
        _titleStatusIndicator.hidden = true;
        _titleStatusSubtitleLabel.hidden = true;
        _titleLabel.hidden = false;
        _titleLockIconView.hidden = false;
        
        [_titleStatusIndicator stopAnimating];
    }
    else
    {
        [self _loadStatusViews];
        
        _titleStatusLabel.hidden = false;
        _titleStatusIndicator.hidden = false;
        _titleLabel.hidden = true;
        _titleLockIconView.hidden = true;
                
        _titleStatusLabel.text = text;
        [_titleStatusLabel sizeToFit];
        
        [self _layoutTitleViews:self.interfaceOrientation];
        
        if (!_titleStatusIndicator.isAnimating)
            [_titleStatusIndicator startAnimating];
    }
    
    if (state == TGDialogListStateHasProxyIssues) {
        if ([self isVisible] && !_searchMixin.isActive) {
            [self displayProxyTooltip];
        } else {
            _displayProxyIssuesTooltip = true;
        }
    } else {
        _displayProxyIssuesTooltip = false;
    }
    if (self == TGAppDelegateInstance.rootController.dialogListController)
    {
        OGStartupDiagnosticsUIState(state == TGDialogListStateNormal, _isOnScreen);
        if (state == TGDialogListStateNormal && _isOnScreen && [self isVisible])
            OGDiagnosticsTimingAfterFrame("cold_start", _tableView, true, false);
    }

}

- (bool)isVisible
{
    return self.navigationController.topViewController == TGAppDelegateInstance.rootController.mainTabsController && [TGAppDelegateInstance.rootController.mainTabsController logicalSelectedIndex] == 2;
}

- (void)updateDatabasePassword
{
    _titleLockIconView.alpha = [TGDatabaseInstance() isPasswordSet:NULL] ? 1.0f : 0.0f;
    if (_titleLockIconView.isLocked != [TGAppDelegateInstance isManuallyLocked])
        [_titleLockIconView setIsLocked:[TGAppDelegateInstance isManuallyLocked] animated:false];
    [self _layoutTitleViews:self.interfaceOrientation];
}

- (void)userTypingInConversationUpdated:(int64_t)conversationId typingString:(NSString *)typingString
{
    bool updated = false;
    
    if (typingString.length != 0)
    {
        std::map<int64_t, NSString *>::iterator conversationIt = _usersTypingInConversation.find(conversationId);
        
        if (conversationIt == _usersTypingInConversation.end())
        {
            updated = true;
            _usersTypingInConversation.insert(std::pair<int64_t, NSString *>(conversationId, typingString));
        }
        else
        {
            if (![conversationIt->second isEqualToString:typingString])
            {
                updated = true;
                _usersTypingInConversation[conversationId] = typingString;
            }
        }
    }
    else if (typingString.length == 0 && _usersTypingInConversation.find(conversationId) != _usersTypingInConversation.end())
    {
        updated = true;
        _usersTypingInConversation.erase(conversationId);
    }
    
    if (updated)
    {
        Class dialogListCellClass = [TGDialogListCell class];
        for (UITableViewCell *cell in [_tableView visibleCells])
        {
            if ([cell isKindOfClass:dialogListCellClass])
            {
                TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
                if (dialogCell.conversationId == conversationId)
                {
                    [dialogCell setTypingString:typingString animated:true];
                    
                    break;
                }
            }
        }
    }
}

- (NSArray *)controllerRightBarButtonItems
{
    if ([TGPresentation brandedIOS6Style])
        return @[ TGDialogListBrandedBarButtonItem(_editingMode ? @"Done" : @"Edit", self, _editingMode ? @selector(doneButtonPressed) : @selector(editButtonPressed), false) ];
    if (_editingMode)
        return nil;
    
    NSMutableArray *items = [[NSMutableArray alloc] init];
    UIBarButtonItem *compose = nil;
    if ([TGPresentation classicThemeStyle])
    {
        UIImage *composeGlyph = TGTintedImage([UIImage imageNamed:@"ModernNavigationComposeButtonIcon.png"], [UIColor whiteColor]);
        composeGlyph = OGCompatCenteredScaledBarIcon(composeGlyph, 0.70f);
        compose = [[UIBarButtonItem alloc] initWithImage:composeGlyph style:UIBarButtonItemStyleBordered target:self action:@selector(composeMessageButtonPressed:)];
    }
    else if (iosMajorVersion() < 7)
    {
        TGModernBarButton *composeControl = [[TGModernBarButton alloc] initWithImage:TGTintedImage([UIImage imageNamed:@"ModernNavigationComposeButtonIcon.png"], self.presentation.pallete.navigationButtonColor)];
        composeControl.portraitAdjustment = CGPointMake(-7, -5);
        composeControl.landscapeAdjustment = CGPointMake(-7, -4);
        [composeControl addTarget:self action:@selector(composeMessageButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        compose = [[UIBarButtonItem alloc] initWithCustomView:composeControl];
    }
    else
    {
        UIButton *composeControl = [UIButton buttonWithType:UIButtonTypeCustom];
        composeControl.frame = CGRectMake(0.0f, 0.0f, 44.0f, 44.0f);
        composeControl.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        UIImage *composeGlyph = TGTintedImage([UIImage imageNamed:@"ModernNavigationComposeButtonIcon.png"], self.presentation.pallete.navigationButtonColor);
        [composeControl setImage:composeGlyph forState:UIControlStateNormal];
        composeControl.imageEdgeInsets = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 2.0f);
        [composeControl addTarget:self action:@selector(composeMessageButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        compose = [[UIBarButtonItem alloc] initWithCustomView:composeControl];
    }
    
    [items addObject:compose];
    
    return items;
}

- (UIBarStyle)requiredNavigationBarStyle
{
    return UIBarStyleDefault;
}

- (void)_layoutTitleViews:(UIInterfaceOrientation)orientation
{
    CGFloat portraitOffset = 0.0f;
    CGFloat landscapeOffset = 0.0f;
    CGFloat indicatorOffset = 0.0f;
    if (iosMajorVersion() >= 7)
    {
        portraitOffset = 1.0f;
        landscapeOffset = 0.0f;
        indicatorOffset = -1.0f;
    }
    else
    {
        portraitOffset = -1.0f;
        landscapeOffset = 1.0f;
        indicatorOffset = 0.0f;
    }
    if ([TGPresentation brandedIOS6Style])
    {
        CGFloat brandedTitleOffset = [TGPresentation brandedIOS6DialogListAppearance].navigationTitleVerticalOffset;
        portraitOffset += brandedTitleOffset;
        landscapeOffset += brandedTitleOffset;
    }
    
    CGRect titleLabelFrame = _titleLabel.frame;
    titleLabelFrame.origin = CGPointMake(CGFloor((_titleContainer.frame.size.width - titleLabelFrame.size.width) / 2.0f), CGFloor((_titleContainer.frame.size.height - titleLabelFrame.size.height) / 2.0f) + (UIInterfaceOrientationIsPortrait(orientation) ? portraitOffset : landscapeOffset));
    if (_titleLockIconView.alpha > FLT_EPSILON)
        titleLabelFrame.origin.x -= 4.0f;
    _titleLockIconView.frame = CGRectMake(CGRectGetMaxX(titleLabelFrame) + 6.0f, titleLabelFrame.origin.y + 4.0f, _titleLockIconView.frame.size.width, _titleLockIconView.frame.size.height);
    _titleLabel.frame = titleLabelFrame;
    if (_titleEmojiStatusView.displaysStatus)
        _titleEmojiStatusView.frame = CGRectMake(CGRectGetMaxX(titleLabelFrame) + 4.0f, CGFloor((_titleContainer.frame.size.height - TGDialogListTitleEmojiStatusSize) / 2.0f), TGDialogListTitleEmojiStatusSize, TGDialogListTitleEmojiStatusSize);
    
    if (_titleStatusLabel != nil)
    {
        CGRect titleStatusLabelFrame = _titleStatusLabel.frame;
        titleStatusLabelFrame.origin = CGPointMake(CGFloor((_titleContainer.frame.size.width - titleStatusLabelFrame.size.width) / 2.0f) + 16.0f, CGFloor((_titleContainer.frame.size.height - titleStatusLabelFrame.size.height) / 2.0f) + (UIInterfaceOrientationIsPortrait(orientation) ? portraitOffset : landscapeOffset));
        if (!_titleStatusSubtitleLabel.hidden) {
            titleStatusLabelFrame.origin.y -= 7.0f;
            if (UIInterfaceOrientationIsLandscape(orientation)) {
                titleStatusLabelFrame.origin.y -= 2.0f;
            }
        }
        _titleStatusLabel.frame = titleStatusLabelFrame;
        
        CGRect titleStatusSubtitleLabelFrame = _titleStatusSubtitleLabel.frame;
        titleStatusSubtitleLabelFrame.origin = CGPointMake(CGFloor((_titleContainer.frame.size.width - titleStatusSubtitleLabelFrame.size.width) / 2.0f), CGRectGetMaxY(titleStatusLabelFrame) - 1.0f);
        _titleStatusSubtitleLabel.frame = titleStatusSubtitleLabelFrame;

        CGRect titleIndicatorFrame = _titleStatusIndicator.frame;
        titleIndicatorFrame.origin = CGPointMake(titleStatusLabelFrame.origin.x - titleIndicatorFrame.size.width - 4.0f, titleStatusLabelFrame.origin.y  + indicatorOffset);
        _titleStatusIndicator.frame = titleIndicatorFrame;
    }
    
    if (_titlePanelWrappingView != nil)
    {
        CGRect titleWrapperFrame = CGRectMake(0.0f, self.controllerInset.top - self.explicitTableInset.top, self.view.frame.size.width, _titlePanelWrappingView.frame.size.height);
        CGRect titlePanelFrame = CGRectMake(0.0f, 0.0f, titleWrapperFrame.size.width, _primaryTitlePanel.frame.size.height);
        _titlePanelWrappingView.frame = titleWrapperFrame;
        _primaryTitlePanel.frame = titlePanelFrame;
    }
}

- (void)loadView
{
    [super loadView];
    
    OGPlatformHideAccessibilityElements(self.view);
    
    NSString *dialogListTitle = [TGOnegramSettings integerForKey:TGOnegramSettingChatListTitleMode] == 0 && OGPlatformUsesConstrainedBackgroundExecution() ? TGStartupLocalized(@"DialogList.Title") : [self onegramDialogListTitle];
    [self setTitleText:dialogListTitle];
    
    _titleContainer = [[TGDialogListTitleContainer alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 2.0f, 2.0f)];
    [self setTitleView:_titleContainer];
    
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.textColor = OGDialogListHeaderTitleColor(self.presentation);
    _titleLabel.shadowColor = TGDialogListNavigationShadowColor(self.presentation, 0.9f);
    _titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
    _titleLabel.font = TGDialogListNavigationTitleFont();
    _titleLabel.text = dialogListTitle;
    [_titleLabel sizeToFit];
    [_titleContainer addSubview:_titleLabel];

    _titleEmojiStatusView = [[TGEmojiStatusView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, TGDialogListTitleEmojiStatusSize, TGDialogListTitleEmojiStatusSize)];
    __weak TGDialogListController *weakController = self;
    _titleEmojiStatusView.displayChanged = ^
    {
        __strong TGDialogListController *strongController = weakController;
        [strongController _layoutTitleViews:strongController.interfaceOrientation];
    };
    [_titleContainer addSubview:_titleEmojiStatusView];
    [self loadCachedOwnEmojiStatus];
    
    _titleLockIconView = [[TGLockIconView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 2.0f, 2.0f)];
    _titleLockIconView.presentation = self.presentation;
    _titleLockIconView.alpha = [TGDatabaseInstance() isPasswordSet:NULL] ? 1.0f : 0.0f;
    [_titleLockIconView setIsLocked:[TGAppDelegateInstance isManuallyLocked] animated:false];
    __weak TGDialogListController *weakSelf = self;
    _titleContainer.tappped = ^
    {
        __strong TGDialogListController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            if (strongSelf->_titleStatusSubtitleLabel != nil && !strongSelf->_titleStatusSubtitleLabel.hidden) {
                [strongSelf openProxySettings];
            } else if (strongSelf->_titleLockIconView.alpha > FLT_EPSILON) {
                [TGAppDelegateInstance setIsManuallyLocked:![TGAppDelegateInstance isManuallyLocked]];
                [strongSelf->_titleLockIconView setIsLocked:[TGAppDelegateInstance isManuallyLocked] animated:true];
            }
        }
    };
    [_titleContainer addSubview:_titleLockIconView];
    
    [self _layoutTitleViews:self.interfaceOrientation];
    
    [self updateBarButtonItemsAnimated:false];
    
    self.view.backgroundColor = _presentation.pallete.backgroundColor;
    
    _headerBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.controllerInset.top)];
    _headerBackgroundView.backgroundColor = _presentation.pallete.backgroundColor;
    [self.view addSubview:_headerBackgroundView];
    
    CGRect tableFrame = self.view.bounds;
    _tableView = [[TGListsTableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
    if (iosMajorVersion() >= 11)
        _tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.opaque = true;
    _tableView.backgroundColor = _presentation.pallete.backgroundColor;
    ((TGListsTableView *)_tableView).onHitTest = ^(CGPoint point) {
        __strong TGDialogListController *strongSelf = weakSelf;
        if (strongSelf != nil) {
            for (NSIndexPath *indexPath in [strongSelf->_tableView indexPathsForVisibleRows]) {
                TGDialogListCell *cell = (TGDialogListCell *)[strongSelf->_tableView cellForRowAtIndexPath:indexPath];
                if ([cell isKindOfClass:[TGDialogListCell class]]) {
                    if ([cell isEditingControlsExpanded]) {
                        CGRect rect = [cell convertRect:cell.bounds toView:strongSelf->_tableView];
                        if (!CGRectContainsPoint(rect, point) && ![cell isEditingControlsTracking]) {
                            [cell setEditingConrolsExpanded:false animated:true];
                        }
                    }
                }
            }
        }
    };
    

    [(TGListsTableView *)_tableView adjustBehaviour];
    
    _tableView.showsVerticalScrollIndicator = true;
    
    if (!_dialogListCompanion.feedChannels)
    {
        NSString *searchPlaceholderKey = self.customSearchPlaceholder ?: @"DialogList.SearchLabel";
        NSString *startupSearchPlaceholder = OGPlatformUsesConstrainedBackgroundExecution() && self.customSearchPlaceholder == nil ? TGStartupLocalized(searchPlaceholderKey) : nil;
        _searchBar = [[TGSearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, TGDialogListSearchBarHeight()) style:TGSearchBarStyleLightPlain initialPlaceholder:startupSearchPlaceholder];
        _searchBar.pallete = self.presentation.searchBarPallete;
        _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _searchBar.safeAreaInset = [self controllerSafeAreaInset];
        if ([TGPresentation brandedIOS6Style])
            _searchBar.textFieldInsets = [TGPresentation brandedIOS6DialogListAppearance].searchFieldInsets;
        
        _searchTopBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, -320.0f, self.view.frame.size.width, 320.0f)];
        _searchTopBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_tableView insertSubview:_searchTopBackgroundView atIndex:0];
        
        _searchMixin = [[TGSearchDisplayMixin alloc] init];
        _searchMixin.searchBar = _searchBar;
        _searchMixin.delegate = self;
        
        _tableView.tableHeaderView = [TGOnegramSettings boolForKey:TGOnegramSettingChatListHideSearch] ? nil : _searchBar;
        
        _searchBar.placeholder = startupSearchPlaceholder != nil ? startupSearchPlaceholder : TGLocalized(searchPlaceholderKey);
    }
    
    [self applyConversationTableSeparators:_tableView];
    
    _tableView.alwaysBounceVertical = true;
    _tableView.bounces = true;
    
    _tableView.tableFooterView = [[UIView alloc] init];
    
    [self setTableHidden:_listModel.count == 0];
    
    [self resetInitialOffset];
    
    [self.view addSubview:_tableView];
#if OG_PLUGINS_AVAILABLE
    OGPluginUIChatListSurfacesUpdate(self, _tableView);
#endif

    _ogFolderPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(og_folderPanGesture:)];
    _ogFolderPanGestureRecognizer.delegate = self;
    _ogFolderPanGestureRecognizer.maximumNumberOfTouches = 1;
    _ogFolderPanGestureRecognizer.cancelsTouchesInView = false;
    [self.view addGestureRecognizer:_ogFolderPanGestureRecognizer];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 32000
    if ([_tableView respondsToSelector:@selector(panGestureRecognizer)])
        [_tableView.panGestureRecognizer requireGestureRecognizerToFail:_ogFolderPanGestureRecognizer];
#endif

    _ogChatActionsLongPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(og_chatActionsLongPress:)];
    _ogChatActionsLongPressRecognizer.minimumPressDuration = 0.45;
    _ogChatActionsLongPressRecognizer.cancelsTouchesInView = true;
    [_tableView addGestureRecognizer:_ogChatActionsLongPressRecognizer];

    [self og_updateNewChatListGesturesState];

    _ogListHeaderView = [[UIView alloc] initWithFrame:CGRectZero];
    _ogListHeaderView.backgroundColor = [UIColor clearColor];
    _ogListHeaderView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _ogPlayerHostView = [[UIView alloc] initWithFrame:CGRectZero];
    _ogPlayerHostView.clipsToBounds = true;
    [_ogListHeaderView addSubview:_ogPlayerHostView];
    _ogFolderTabsView = [[UIView alloc] initWithFrame:CGRectZero];
    [_ogListHeaderView addSubview:_ogFolderTabsView];
    _ogFolderTabsView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _ogFolderTabsView.backgroundColor = [self og_folderTabsBackgroundColor];
    _ogFolderTabsView.hidden = false;
    _ogFolderTabsScrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _ogFolderTabsScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _ogFolderTabsScrollView.backgroundColor = [UIColor clearColor];
    _ogFolderTabsScrollView.showsHorizontalScrollIndicator = false;
    _ogFolderTabsScrollView.showsVerticalScrollIndicator = false;
    _ogFolderTabsScrollView.alwaysBounceHorizontal = false;
    [_ogFolderTabsView addSubview:_ogFolderTabsScrollView];

    _ogFolderTabsSeparatorView = [[UIView alloc] initWithFrame:CGRectZero];
    _ogFolderTabsSeparatorView.backgroundColor = [TGPresentation brandedIOS6Style] ? [TGPresentation brandedIOS6DialogListAppearance].folderTabsSeparatorColor : ([TGPresentation classicThemeStyle] ? (OGCompatDialogListClassicDarkStyle(self.presentation) ? self.presentation.pallete.barSeparatorColor : UIColorRGB(0xc8c8c8)) : self.presentation.pallete.separatorColor);
    [_ogFolderTabsView addSubview:_ogFolderTabsSeparatorView];

    _ogFolderEmptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _ogFolderEmptyLabel.backgroundColor = [UIColor clearColor];
    _ogFolderEmptyLabel.textAlignment = NSTextAlignmentCenter;
    _ogFolderEmptyLabel.textColor = [TGPresentation brandedIOS6Style] ? [TGPresentation brandedIOS6DialogListAppearance].folderEmptyColor : ([TGPresentation classicThemeStyle] ? (OGCompatDialogListClassicDarkStyle(self.presentation) ? self.presentation.pallete.secondaryTextColor : UIColorRGB(0x8e8e93)) : self.presentation.pallete.secondaryTextColor);
    _ogFolderEmptyLabel.font = TGSystemFontOfSize(15.0f);
    _ogFolderEmptyLabel.text = @"Нет чатов";
    _ogFolderEmptyLabel.hidden = true;
    _ogFolderEmptyLabel.userInteractionEnabled = false;
    [self.view addSubview:_ogFolderEmptyLabel];
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];

    _ogFolderTabsStateKey = nil;
    _ogFolderTabsUpdatePending = false;
    [self og_updateFolderTabs];
    [self og_layoutFolderTabs];
}

- (void)doUnloadView
{
    [self og_cancelFolderSwipeImmediately];
    [self og_endRefreshAnimated:false];
    _ogRefreshContainerView = nil;
    _ogRefreshBadgeView = nil;
    _ogRefreshProgressLayer = nil;
    _ogRefreshActivityIndicator = nil;

    if (_ogFolderPanGestureRecognizer != nil)
    {
        _ogFolderPanGestureRecognizer.delegate = nil;
        [_ogFolderPanGestureRecognizer.view removeGestureRecognizer:_ogFolderPanGestureRecognizer];
        _ogFolderPanGestureRecognizer = nil;
    }

    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    _tableView = nil;
    
    _searchBar = nil;
    _ogFolderTabsScrollView = nil;
    _ogFolderTabsView = nil;
    _ogFolderTabsSeparatorView = nil;
    _ogFolderEmptyLabel = nil;
    _ogFolderTabsStateKey = nil;
    _ogFolderTabsUpdatePending = false;
    _ogChatActionsLongPressRecognizer = nil;
    
    _searchMixin.delegate = nil;
    [_searchMixin unload];
}

- (void)viewDidUnload
{
    [self doUnloadView];
    
    [super viewDidUnload];
}

- (void)resetInitialOffset
{
    if (!_doNotHideSearchAutomatically)
    {
        _tableView.contentOffset = CGPointMake(0.0f, -_tableView.contentInset.top + [self onegramSearchHeaderHeight] + self.explicitTableInset.top);
        _ogSearchPullArmed = false;
    }
}

- (void)loadCachedOwnEmojiStatus
{
    int64_t clientUserId = TGTelegraphInstance.clientUserId;
    if (clientUserId == 0 || _titleEmojiStatusLoadScheduled)
        return;

    _titleEmojiStatusLoadScheduled = true;
    TGDialogListControllerReference *reference = _ogLifetimeReference;
    OGRuntimeDispatch(OGRuntimePriorityUtility, ^
    {
        TGUser *user = [TGDatabaseInstance() loadUser:clientUserId];
        OGPlatformDispatchOnMainThread(^
        {
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                controller->_titleEmojiStatusLoadScheduled = false;
                if (!controller->_dialogListSelfUserSnapshotResolved && user != nil)
                {
                    controller->_dialogListSelfUserSnapshot = user;
                    controller->_dialogListSelfUserSnapshotResolved = true;
                }
                controller->_titleEmojiStatusView.documentId = user.emojiStatusDocumentId;
            }];
        });
    });
}

- (void)refreshOwnUserIfStale
{
    int64_t clientUserId = TGTelegraphInstance.clientUserId;
    if (clientUserId == 0 || _ownUserRefreshPending)
        return;

    TGTelegramNetworking *networking = OGPlatformUsesConstrainedBackgroundExecution() ? [TGTelegramNetworking maybeInstance] : [TGTelegramNetworking instance];
    if (networking == nil)
        return;

    _ownUserRefreshPending = true;
    TGDialogListControllerReference *reference = _ogLifetimeReference;
    NSTimeInterval lastRefreshTime = _ownUserRefreshTimestamp;
    OGRuntimeDispatch(OGRuntimePriorityUtility, ^
    {
        TGUser *cachedUser = [TGDatabaseInstance() loadUser:clientUserId];
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        bool shouldRefresh = lastRefreshTime <= 0.0 || now - lastRefreshTime >= TGDialogListOwnUserRefreshInterval(cachedUser);
        OGPlatformDispatchOnMainThread(^
        {
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                if (!controller->_dialogListSelfUserSnapshotResolved && cachedUser != nil)
                {
                    controller->_dialogListSelfUserSnapshot = cachedUser;
                    controller->_dialogListSelfUserSnapshotResolved = true;
                }

                TLInputUser *inputUser = shouldRefresh ? [TGTelegraphInstance createInputUserForUid:clientUserId] : nil;
                if (inputUser == nil)
                {
                    controller->_ownUserRefreshPending = false;
                    return;
                }

                controller->_ownUserRefreshTimestamp = now;
                [controller requestOwnUser:inputUser networking:networking];
            }];
        });
    });
}

- (void)requestOwnUser:(TLInputUser *)inputUser networking:(TGTelegramNetworking *)networking
{
    TLRPCusers_getUsers$users_getUsers *getUsers = [[TLRPCusers_getUsers$users_getUsers alloc] init];
    getUsers.n_id = @[ inputUser ];
    TGDialogListControllerReference *reference = _ogLifetimeReference;
    [networking performRpc:getUsers completionBlock:^(id response, __unused int64_t responseTime, MTRpcError *error)
    {
        if (error == nil && [response isKindOfClass:[NSArray class]])
            [TGUserDataRequestBuilder executeUserDataUpdate:response];

        OGPlatformDispatchOnMainThread(^
        {
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                controller->_ownUserRefreshPending = false;
                controller->_dialogListSelfUserSnapshot = nil;
                controller->_dialogListSelfUserSnapshotResolved = false;
                [controller loadCachedOwnEmojiStatus];
            }];
        });
    } progressBlock:nil requiresCompletion:true requestClass:TGRequestClassGeneric];
}

- (bool)storiesEnabledInList
{
    return TGOnegramModernInterfaceEnabled() && ![_dialogListCompanion forwardMode] && !_dialogListCompanion.privacyMode;
}

- (int)storyRingStateForPeerId:(int64_t)peerId
{
    if (![self storiesEnabledInList] || peerId == TGTelegraphInstance.clientUserId || !(TGPeerIdIsUser(peerId) || TGPeerIdIsChannel(peerId)))
        return TGStoryRingStateNone;
    TGPeerStories *peerStories = [[TGStoriesStore instance] peerStoriesForPeerId:peerId];
    if (peerStories.stories.count == 0)
        return TGStoryRingStateNone;
    return [peerStories hasUnread] ? TGStoryRingStateUnread : TGStoryRingStateRead;
}

- (void)storiesStoreChanged:(NSNotification *)__unused notification
{
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
            ((TGDialogListCell *)cell).storyRingState = [self storyRingStateForPeerId:((TGDialogListCell *)cell).conversationId];
    }
}

- (void)openStoriesForPeerId:(int64_t)peerId
{
    NSArray *peerStoriesList = [[TGStoriesStore instance] orderedPeerStories];
    NSMutableArray *others = [[NSMutableArray alloc] init];
    NSUInteger index = NSNotFound;
    for (TGPeerStories *peerStories in peerStoriesList)
    {
        if (peerStories.peerId == TGTelegraphInstance.clientUserId)
            continue;
        if (peerStories.peerId == peerId)
            index = others.count;
        [others addObject:peerStories];
    }
    if (index == NSNotFound)
        [TGStoryViewerController presentActiveStoriesForPeerId:peerId fromController:self];
    else
        [TGStoryViewerController presentActiveStoriesList:others peerIndex:index fromController:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
#if OG_PLUGINS_AVAILABLE
    OGPluginUIChatListSurfacesVisibility(self, YES);
    OGPluginUIChatListSurfacesUpdate(self, _tableView);
#endif
    if ([self storiesEnabledInList])
        [[TGStoriesStore instance] refreshIfNeeded];
    if (_dialogListHiddenCoalesced)
    {
        _dialogListAppearingFlush = true;
        [self dialogListFlushCoalescedUpdates];
        _dialogListAppearingFlush = false;
    }
    [self dialogListFlushOffscreenReload];
    _snowflakesOnScreen = true;
    [self updateSnowflakesAnimated:animated];
    if ([TGPresentation brandedIOS6Style] && [self.navigationController.navigationBar isKindOfClass:[TGNavigationBar class]])
    {
        TGNavigationBar *navigationBar = (TGNavigationBar *)self.navigationController.navigationBar;
        navigationBar.musicPlayerLayout = TGNavigationBarMusicPlayerLayoutStandard;
        navigationBar.musicPlayerHostView = _ogPlayerHostView;
    }
    [self og_layoutFolderTabs];
    [self refreshOwnUserIfStale];
    [self loadCachedOwnEmojiStatus];
    [self og_synchronizeDialogStateForce:false];
    
    
    [self check3DTouch];
    
    if ([_dialogListCompanion openedConversationId] == 0 || !TGIsPad())
    {
        if (lastAppearedConversationId != 0 && !_debugDoNotJump && !_dialogListCompanion.forwardMode && !_dialogListCompanion.privacyMode)
        {
            int64_t conversationId = lastAppearedConversationId;
            lastAppearedConversationId = 0;
            
            if (animated && !_searchMixin.isActive)
            {
                bool found = false;
                
                int index = -1;
                NSArray *displayedRows = [self dialogListDisplayedItems];
                for (TGConversation *conversation in displayedRows)
                {
                    index++;
                    
                    if (![conversation isKindOfClass:[TGConversation class]])
                        continue;
                    
                    if (conversation.conversationId == conversationId && conversationId != 0)
                    {
                        UITableViewScrollPosition scrollPosition = UITableViewScrollPositionNone;
                        
                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:1];
                        if (index >= 0 && index < [_tableView numberOfRowsInSection:1])
                        {
                            CGRect rowRectInView = [_tableView convertRect:[_tableView rectForRowAtIndexPath:indexPath] toView:self.view];
                            if (rowRectInView.origin.y + rowRectInView.size.height > self.view.frame.size.height - self.controllerInset.bottom)
                                scrollPosition = UITableViewScrollPositionBottom;
                            else if (rowRectInView.origin.y < self.controllerInset.top)
                                scrollPosition = UITableViewScrollPositionTop;
                        }
                        else
                        {
                            break;
                        }
                        
                        if (_searchMixin.isActive)
                            scrollPosition = UITableViewScrollPositionNone;
                        
                        [_tableView selectRowAtIndexPath:indexPath animated:false scrollPosition:scrollPosition];
                        
                        found = true;
                        
                        break;
                    }
                }
            }
            else
            {
                if ([_tableView indexPathForSelectedRow] != nil)
                    [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:animated];
            }
        }
        
        if ([_tableView indexPathForSelectedRow] != nil)
            [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:animated];
    }
    
    if (_searchMixin.isActive)
    {
        [_searchMixin controllerLayoutUpdated:[TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation]];
        
        UITableView *searchTableView = _searchMixin.searchResultsTableView;
        
        if ([searchTableView indexPathForSelectedRow] != nil)
            [searchTableView deselectRowAtIndexPath:[searchTableView indexPathForSelectedRow] animated:true];
    }
    
    [self _performSizeChangesWithDuration:0.0f size:_tableView.frame.size];
}

- (void)dialogListFlushOffscreenReload
{
    if (!_dialogListOffscreenReloadPending || _tableView == nil)
        return;
    _dialogListOffscreenReloadPending = false;
    [_tableView layoutIfNeeded];
    if ([self og_visibleListModel].count != 0 && _tableView.indexPathsForVisibleRows.count == 0)
        [_tableView setContentOffset:CGPointMake(0.0f, -_tableView.contentInset.top) animated:false];
    [self dialogListPrimeVisibleRenderCache];
}

- (void)dialogListLogVisibleCellState:(NSString *)reason
{
    OGPlatformDispatchOnMainThreadAfter(0.5, ^
    {
        CGPoint contentOffset = _tableView.contentOffset;
        OGPlatformDiagnosticLog(@"DIALOGVIEW reason=%@ offset=%.0f rows=%d visible=%d", reason, contentOffset.y, (int)[_tableView numberOfRowsInSection:1], (int)_tableView.visibleCells.count);
        for (UITableViewCell *cell in _tableView.visibleCells)
        {
            NSIndexPath *indexPath = [_tableView indexPathForCell:cell];
            id item = indexPath != nil ? [self og_dialogListItemAtIndexPath:indexPath] : nil;
            NSString *itemDescription = item == nil ? @"nil" : ([item isKindOfClass:[TGConversation class]] ? [[NSString alloc] initWithFormat:@"conv:%lld:%d", ((TGConversation *)item).conversationId, (int)((TGConversation *)item).dialogListData.count] : NSStringFromClass([item class]));
            if ([cell isKindOfClass:[TGDialogListCell class]])
                OGPlatformDiagnosticLog(@"DIALOGVIEW row=%d item=%@ %@", indexPath != nil ? (int)indexPath.row : -1, itemDescription, [(TGDialogListCell *)cell diagnosticState]);
            else
                OGPlatformDiagnosticLog(@"DIALOGVIEW row=%d item=%@ cell=%@ frame=%.0f,%.0f,%.0f,%.0f h=%d a=%.2f", indexPath != nil ? (int)indexPath.row : -1, itemDescription, NSStringFromClass([cell class]), cell.frame.origin.x, cell.frame.origin.y, cell.frame.size.width, cell.frame.size.height, cell.hidden ? 1 : 0, cell.alpha);
        }
    });
}

- (void)viewDidAppear:(BOOL)animated
{
    if (OGDiagnosticsEnabled())
        [self dialogListLogVisibleCellState:@"appear"];
    [self dialogListFlushOffscreenReload];
#if OG_PLUGINS_AVAILABLE
    OGPluginUIChatListSurfacesVisibility(self, YES);
    OGPluginUIChatListSurfacesUpdate(self, _tableView);
#endif
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
    });
    
    [_dialogListCompanion wakeUp];
    
    for (id cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
            [(TGDialogListCell *)cell restartAnimations:false];
    }
    
    _didSelectMessage = false;
    _didSelectGlobalResult = false;
    
    bool displayingTooltip = false;
    if (_titleLockIconView.alpha > FLT_EPSILON && !_dialogListCompanion.forwardMode && !_dialogListCompanion.privacyMode)
    {
        NSString *key = @"Passcode_didShowChatListTooltip";
        if (![[[NSUserDefaults standardUserDefaults] objectForKey:key] boolValue])
        {
            [[NSUserDefaults standardUserDefaults] setObject:@true forKey:key];
            
            if (_menuContainerView == nil)
            {
                _menuContainerView = [[TGMenuContainerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.navigationController.view.frame.size.width, self.navigationController.view.frame.size.height)];
                _menuContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [self.navigationController.view addSubview:_menuContainerView];
                
                NSMutableArray *actions = [[NSMutableArray alloc] init];
                [actions addObject:[[NSDictionary alloc] initWithObjectsAndKeys:TGLocalized(@"DialogList.PasscodeLockHelp"), @"title", nil]];
                
                [_menuContainerView.menuView setButtonsAndActions:actions watcherHandle:nil];
                [_menuContainerView.menuView sizeToFit];
                _menuContainerView.menuView.userInteractionEnabled = false;
                CGRect titleLockIconViewFrame = [_titleLockIconView convertRect:_titleLockIconView.bounds toView:_menuContainerView];
                titleLockIconViewFrame.origin.y += 6.0f;
                titleLockIconViewFrame.origin.x += 4.0f;
                titleLockIconViewFrame.size.height += titleLockIconViewFrame.origin.y;
                titleLockIconViewFrame.origin.y = 0;
                [_menuContainerView showMenuFromRect:titleLockIconViewFrame animated:false];
                displayingTooltip = true;
            }
        }
    }
    
    if (!displayingTooltip)
    {
        if (_displaySavedMessagesTooltip)
        {
            _displaySavedMessagesTooltip = false;
            [self displaySettingsTooltip:TGLocalized(@"DialogList.SavedMessagesTooltip")];
            [[NSUserDefaults standardUserDefaults] setObject:@true forKey:@"TG_displayedSavedMessagesTooltip_v0"];
        } else if (_displayProxyIssuesTooltip) {
            _displayProxyIssuesTooltip = false;
            [self displayProxyTooltip];
        }
    }
    
    [super viewDidAppear:animated];
    
    _isOnScreen = true;
    if (self == TGAppDelegateInstance.rootController.dialogListController)
    {
        OGStartupDiagnosticsUIState(_state == TGDialogListStateNormal, true);
        if (_state == TGDialogListStateNormal && [self isVisible])
            OGDiagnosticsTimingAfterFrame("cold_start", _tableView, true, false);
    }
    if (_suggestedLocalization != nil && !_displayedSuggestedLocalization) {
        _displayedSuggestedLocalization = true;
        [self displaySuggestedLocalization];
    }
}

- (void)requestSavedMessagesTooltip
{
    if (![[[NSUserDefaults standardUserDefaults] objectForKey:@"TG_displayedSavedMessagesTooltip_v0"] boolValue])
        _displaySavedMessagesTooltip = true;
}

- (void)viewWillDisappear:(BOOL)animated
{
#if OG_PLUGINS_AVAILABLE
    OGPluginUIChatListSurfacesVisibility(self, NO);
#endif
    if (_dialogListFastScrolling)
        [self dialogListSetFastScrolling:false];
    if (iosMajorVersion() >= 7)
        [_searchMixin resignResponderIfAny];
    
    _snowflakesOnScreen = false;
    [self updateSnowflakesAnimated:animated];
    
    if ([self.navigationController.navigationBar isKindOfClass:[TGNavigationBar class]])
    {
        TGNavigationBar *navigationBar = (TGNavigationBar *)self.navigationController.navigationBar;
        if (navigationBar.musicPlayerHostView == _ogPlayerHostView)
            navigationBar.musicPlayerHostView = nil;
    }
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    _isOnScreen = false;
    if (self == TGAppDelegateInstance.rootController.dialogListController)
        OGStartupDiagnosticsUIState(_state == TGDialogListStateNormal, false);
    if (animated)
    {
        for (NSIndexPath *indexPath in _tableView.indexPathsForVisibleRows)
        {
            UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPath];
            
            if ([cell isKindOfClass:[TGDialogListCell class]])
            {
                TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
                [dialogCell dismissEditingControls:false];
                [dialogCell stopAnimations];
            }
        }
        
        if (_searchMixin.isActive && !_didSelectMessage && !_didSelectGlobalResult)
            [_searchMixin setIsActive:false animated:false];
    }
    
    if (_recordTooltipContainerView != nil) {
        [_recordTooltipContainerView removeFromSuperview];
        _recordTooltipContainerView = nil;
    }
    
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (BOOL)shouldAutorotate
{
    return true;
}

- (void)setAdditionalNavigationBarHeight:(CGFloat)height
{
    if (![TGPresentation brandedIOS6Style])
    {
        [super setAdditionalNavigationBarHeight:height];
        return;
    }
    bool changed = ABS(_ogPlayerHeight - height) > FLT_EPSILON;
    _ogPlayerHeight = height;
    [super setAdditionalNavigationBarHeight:0.0f];
    [self og_layoutFolderTabs];
    if (changed && _tableView != nil)
    {
        CGPoint offset = _tableView.contentOffset;
        [_tableView beginUpdates];
        [_tableView endUpdates];
        _tableView.contentOffset = offset;
    }
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    if (self.navigationBarShouldBeHidden)
    {
        [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top) animated:false];
    }
    
    if (_searchMixin != nil)
        [_searchMixin controllerInsetUpdated:self.controllerInset];
    
    _headerBackgroundView.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.controllerInset.top);
    
    _searchBar.safeAreaInset = self.controllerSafeAreaInset;
    [self updateSafeAreaInset];
    
    if (_searchMixin.isActive)
    {
        TGDialogListRecentPeersCell *cell = [_searchMixin.searchResultsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        if ([cell isKindOfClass:[TGDialogListRecentPeersCell class]])
            cell.safeAreaInset = self.controllerSafeAreaInset;
    }
    
    [super controllerInsetUpdated:previousInset];
    [self og_layoutFolderTabs];
    
    [self _performSizeChangesWithDuration:0.0 size:_tableView.frame.size];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    [self _layoutTitleViews:toInterfaceOrientation];
    
    if (_searchMixin != nil)
        [_searchMixin controllerLayoutUpdated:[TGViewController screenSizeForInterfaceOrientation:toInterfaceOrientation]];
    
    if (_emptyListContainer != nil)
    {
        _emptyListContainer.frame = CGRectMake(CGFloor((self.view.frame.size.width - 250) / 2), CGFloor((self.view.frame.size.height - _emptyListContainer.frame.size.height) / 2), _emptyListContainer.frame.size.width, _emptyListContainer.frame.size.height);
    }
}

- (void)significantTimeChange:(NSNotification *)__unused notification
{
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
            [dialogCell resetView:true];
        }
    }
}

- (void)didEnterBackground:(NSNotification *)__unused notification
{
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
            [dialogCell stopAnimations];
        }
    }
}

- (void)willEnterForeground:(NSNotification *)__unused notification
{
    [self og_synchronizeDialogStateForce:true];
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
            [dialogCell restartAnimations:true];
        }
    }
}

#pragma mark - List management

- (void)reloadData:(bool)animateFrameTransitions
{
    TG_DIALOG_LIST_COST(TGDialogListCostReloadData);
    if ([self dialogListShouldCoalesceUIUpdates])
    {
        _dialogListCoalescedReloadPending = true;
        if (self == TGAppDelegateInstance.rootController.dialogListController)
            OGStartupDiagnosticsUIWorkPending(true);
        if (animateFrameTransitions)
            _dialogListCoalescedReloadAnimated = true;
        return;
    }

    _ogVisibleListCache = nil;
    _ogVisibleListCacheFilterId = INT32_MIN;
    [self dialogListCommitDisplayedItems];
    NSMutableDictionary *temporaryImageCache = [[NSMutableDictionary alloc] init];
    int64_t peerIdWithActiveEditingControls = 0;
    bool activeEditingControlsToLeft = false;
    NSMutableDictionary *framesBeforeUpdate = nil;
    if (animateFrameTransitions) {
        framesBeforeUpdate = [[NSMutableDictionary alloc] init];
    }
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
            
            framesBeforeUpdate[@(dialogCell.conversationId)] = [NSValue valueWithCGRect:dialogCell.frame];
            if ([dialogCell isEditingControlsExpanded]) {
                peerIdWithActiveEditingControls = dialogCell.conversationId;
                activeEditingControlsToLeft = [dialogCell isEditingControlsExpandedToLeft];
            }
            [((TGDialogListCell *)cell) collectCachedPhotos:temporaryImageCache];
        }
    }
    [[TGRemoteImageView sharedCache] addTemporaryCachedImagesSource:temporaryImageCache autoremove:true];
    [_tableView reloadData];
    [self updateSearchBarBackground];
    if (peerIdWithActiveEditingControls != 0 || animateFrameTransitions) {
        for (NSIndexPath *indexPath in _tableView.indexPathsForVisibleRows)
        {
            TGDialogListCell *dialogCell = (TGDialogListCell *)[_tableView cellForRowAtIndexPath:indexPath];
            if ([dialogCell isKindOfClass:[TGDialogListCell class]])
            {
                if (peerIdWithActiveEditingControls != 0 && dialogCell.conversationId == peerIdWithActiveEditingControls) {
                    [dialogCell setEditingConrolsExpanded:true toLeft:activeEditingControlsToLeft animated:false];
                }
                if (animateFrameTransitions) {
                    NSValue *nFrame = framesBeforeUpdate[@(dialogCell.conversationId)];
                    if (nFrame != nil) {
                        CGFloat offset = dialogCell.frame.origin.y - [nFrame CGRectValue].origin.y;
                        if (ABS(offset) > FLT_EPSILON) {
                            #if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
                            if (iosMajorVersion() >= 9) {
                                CASpringAnimation *springAnimation = [CASpringAnimation animationWithKeyPath:@"transform.translation.y"];
                                springAnimation.mass = 3.0f;
                                springAnimation.stiffness = 1000.0f;
                                springAnimation.damping = 500.0f;
                                springAnimation.initialVelocity = 0.0f;
                                springAnimation.duration = 0.5;
                                springAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
                                springAnimation.removedOnCompletion = true;
                                springAnimation.additive = true;
                                [springAnimation setFromValue:@(-offset)];
                                [springAnimation setToValue:@(0.0f)];
                                springAnimation.speed = 2.0f;
                                [dialogCell.layer addAnimation:springAnimation forKey:@"animateTransformAdditive"];
                            } else
#endif
                            {
                                CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
                                [animation setFromValue:@(-offset)];
                                [animation setToValue:@(0.0f)];
                                [animation setDuration:0.2];
                                [animation setRemovedOnCompletion:true];
                                [animation setAdditive:true];
                                [dialogCell.layer addAnimation:animation forKey:@"animateTransformAdditive"];
                            }
                        }
                    }
                }
            }
        }
    }
    
    [self og_layoutFolderTabs];
    [self og_updateFolderTabs];
    [self og_updateFolderEmptyLabel];
    _visibleConversationsPipe.sink(@true);
}

- (void)resetState
{
    [self setTableHidden:true];
    
    
    [_emptyListContainer removeFromSuperview];
    _emptyListContainer = nil;
}

- (void)og_scheduleLazyLoadMoreItems:(int)limit
{
    if (_ogLazyLoadScheduled || _isLoading || !_canLoadMore || _ogArchiveExpanded)
        return;

    _ogLazyLoadScheduled = true;
    _isLoading = true;
    OGPlatformDispatchOnMainThread(^
    {
        _ogLazyLoadScheduled = false;
        if (!_canLoadMore || _ogArchiveExpanded || _dialogListCompanion == nil)
        {
            _isLoading = false;
            return;
        }

        [_dialogListCompanion loadMoreItems:limit];
    });
}

- (void)dialogListFullyReloaded:(NSArray *)items
{
    TG_DIALOG_LIST_COST(TGDialogListCostFullReload);
    [self dialogListBeginRateLimitedUIUpdate];
    if ([self dialogListShouldCoalesceUIUpdates])
    {
        [self dialogListCoalesceFullReload:items];
        if (self == TGAppDelegateInstance.rootController.dialogListController)
            OGStartupDiagnosticsUIWorkPending(true);
        return;
    }

    CFAbsoluteTime fullReloadStart = CFAbsoluteTimeGetCurrent();

    if (_listModel.count == 0)
        [self resetInitialOffset];

    _isLoading = false;
    
    int64_t selectedConversation = INT64_MAX;
    NSIndexPath *selectedIndexPath = [_tableView indexPathForSelectedRow];
    if (selectedIndexPath != nil)
    {
        TGConversation *conversation = (TGConversation *)[self og_dialogListItemAtIndexPath:selectedIndexPath];
        if ([conversation isKindOfClass:[TGConversation class]])
            selectedConversation = conversation.conversationId;
    }
    
    [_listModel removeAllObjects];
    [_listModel addObjectsFromArray:items];

    [self og_scheduleCompleteDialogHydrationAndAvatarPrefetch];
    _ogVisibleListCache = nil;
    _ogVisibleListCacheFilterId = INT32_MIN;
    [self og_scheduleFolderPeerHydrationReconciliation];
    if (_ogArchiveExpanded && [self og_archivedConversationCount] == 0)
        _ogArchiveExpanded = false;
    [self og_logArchiveDiagnostics:@"reload"];

    if (_ogSelectedDialogFilterId != 0 && [self og_selectedDialogFilter] == nil && _ogDialogFilters.count == 0)
    {
        _ogSelectedDialogFilterId = 0;
        [self og_storeSelectedDialogFilterId];
        _ogVisibleListCache = nil;
        _ogVisibleListCacheFilterId = INT32_MIN;
    }

    NSArray *onegramVisibleItems = [self og_visibleListModel];
    if (onegramVisibleItems.count == 0 && _listModel.count != 0 && _ogSelectedDialogFilterId == 0)
    {
        _ogArchiveExpanded = false;
        _ogVisibleListCache = nil;
        _ogVisibleListCacheFilterId = INT32_MIN;
        onegramVisibleItems = [self og_visibleListModel];
    }

    bool appliedIncrementally = !_reloadWithAnimations && _dialogListDisplayedItems.count != 0 && [self dialogListApplyDisplayedItems:onegramVisibleItems animated:false];
    if (appliedIncrementally)
    {
        [self og_layoutFolderTabs];
        [self og_updateFolderTabs];
    }
    else
        [self reloadData:_reloadWithAnimations];
    if (_tableView != nil)
    {
        _tableView.hidden = false;
        _tableView.alpha = 1.0f;
        _tableView.transform = CGAffineTransformIdentity;
        if (_tableView.window == nil)
            _dialogListOffscreenReloadPending = true;
        else
        {
            [_tableView layoutIfNeeded];
            if (onegramVisibleItems.count != 0 && _tableView.indexPathsForVisibleRows.count == 0)
                [_tableView setContentOffset:CGPointMake(0.0f, -_tableView.contentInset.top) animated:false];
        }
    }
    _dialogListLastFullReloadDuration = CFAbsoluteTimeGetCurrent() - fullReloadStart;
    if ([self og_foldersAllowed] && _ogDialogFilters.count == 0 && TGTelegraphInstance.clientUserId != 0 && TGTelegraphInstance.clientIsActivated)
        [self og_synchronizeDialogStateForce:false];
    TGDialogListControllerReference *renderReference = _ogLifetimeReference;
    TGDispatchAfter(0.01, dispatch_get_main_queue(), ^
    {
        [renderReference withValue:^(void *value)
        {
            TGDialogListController *controller = (__bridge TGDialogListController *)value;
            if (!controller->_dialogListOffscreenReloadPending)
                [controller dialogListPrimeVisibleRenderCache];
            if (OGPlatformUsesConstrainedBackgroundExecution() && controller->_listModel.count != 0 && controller->_ogAllDialogItems.count == 0 && !controller->_ogAllDialogItemsLoading)
                [controller og_refreshAllDialogItems:false];
        }];
    });
    [self updateBarButtonItemsAnimated:false];
    _reloadWithAnimations = false;
    
    if (selectedConversation != INT64_MAX && selectedConversation != 0)
    {
        int index = -1;
        NSArray *displayedRows = [self dialogListDisplayedItems];
        for (id item in displayedRows)
        {
            index++;
            
            if (![item isKindOfClass:[TGConversation class]])
                continue;
            
            TGConversation *conversation = (TGConversation *)item;
            int64_t conversationId = conversation.conversationId;
            if (conversationId == selectedConversation)
            {
                [_tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:1] animated:false scrollPosition:UITableViewScrollPositionNone];
                
                break;
            }
        }
    }
    
    _visibleConversationsPipe.sink(@true);
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
    });
    
    [self updateEmptyListContainer];
    
    bool folderPreloadActive = [_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]] && [(TGTelegraphDialogListCompanion *)_dialogListCompanion ios6FolderPreloadActive];
    NSUInteger visibleFolderItems = [self dialogListDisplayedItems].count;
    bool selectedFilterNeedsHistory = _ogSelectedDialogFilterId == 0 || [self og_selectedDialogFilterNeedsHistoryScan];
    if (_ogSelectedDialogFilterId != 0 && selectedFilterNeedsHistory && !_ogFolderLocalSourceExhausted && !_ogAllDialogItemsLoading && visibleFolderItems < 8)
    {
        [self og_refreshAllDialogItems:false];
    }
    else if (selectedFilterNeedsHistory && !folderPreloadActive && !_ogArchiveExpanded && _canLoadMore && !_isLoading && visibleFolderItems < 8 && _listModel.count != 0)
    {
        [self og_scheduleLazyLoadMoreItems:15];
    }
    
    if (_scheduledScrollToConversationId != 0)
    {
        if (!_searchMixin.isActive)
            [self scrollToConversationWithId:_scheduledScrollToConversationId];
        else
            _scheduledScrollToConversationId = 0;
    }
    [self dialogListPresentationUpdated];

}

- (void)updateEmptyListContainer
{
    if (_listModel.count == 0 && _emptyListContainer == nil)
    {
        _emptyListContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 250, 0)];
        [self.view insertSubview:_emptyListContainer aboveSubview:_tableView];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textColor = UIColorRGB(0x999999);
        titleLabel.font = TGSystemFontOfSize(20);
        titleLabel.text = TGLocalized(@"DialogList.NoMessagesTitle");
        [titleLabel sizeToFit];
        titleLabel.frame = CGRectOffset(titleLabel.frame, CGFloor((_emptyListContainer.frame.size.width - titleLabel.frame.size.width) / 2), 0.0f);
        [_emptyListContainer addSubview:titleLabel];
        
        UILabel *textLabel = [[UILabel alloc] init];
        textLabel.textAlignment = NSTextAlignmentCenter;
        textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        textLabel.numberOfLines = 0;
        textLabel.backgroundColor = [UIColor clearColor];
        textLabel.textColor = UIColorRGB(0x999999);
        textLabel.font = TGSystemFontOfSize(15);
        textLabel.text = TGLocalized(@"DialogList.NoMessagesText");
        CGSize textLabelSize = [textLabel sizeThatFits:CGSizeMake(300, 1000)];
        textLabel.frame = CGRectMake(CGFloor((_emptyListContainer.frame.size.width - textLabelSize.width) / 2), titleLabel.frame.origin.y + titleLabel.frame.size.height + 14, textLabelSize.width, textLabelSize.height);
        [_emptyListContainer addSubview:textLabel];
        
        CGFloat containerHeight = textLabel.frame.origin.y + textLabel.frame.size.height;
        
        _emptyListContainer.frame = CGRectMake(CGFloor((self.view.frame.size.width - 250) / 2), CGFloor((self.view.frame.size.height - containerHeight) / 2), _emptyListContainer.frame.size.width, containerHeight);
    }
    else if (_emptyListContainer != nil && _listModel.count != 0)
    {
        [_emptyListContainer removeFromSuperview];
        _emptyListContainer = nil;
    }
    
    [self setTableHidden:_listModel.count == 0];

    if (_emptyListContainer != nil)
        _emptyListContainer.hidden = ![_dialogListCompanion shouldDisplayEmptyListPlaceholder];
}

- (void)setTableHidden:(bool)__unused tableHidden
{
    self.view.backgroundColor = _presentation.pallete.backgroundColor;
}

- (void)updateConversations:(NSDictionary *)dict {
    TG_DIALOG_LIST_COST(TGDialogListCostConversationUpdates);
    [self dialogListBeginRateLimitedUIUpdate];
    if ([self dialogListShouldCoalesceUIUpdates])
    {
        [self dialogListCoalesceConversationUpdates:dict];
        if (self == TGAppDelegateInstance.rootController.dialogListController)
            OGStartupDiagnosticsUIWorkPending(true);
        return;
    }

    _ogVisibleListCache = nil;
    _ogVisibleListCacheFilterId = INT32_MIN;
    NSUInteger archivedTotalPrior = [self og_archivedConversationCount];
    for (NSUInteger i = 0; i < _listModel.count; i++) {
        TGConversation *conv = ((TGConversation *)_listModel[i]);
        TGConversation *conversation = dict[@(conv.conversationId)];
        if (conversation != nil) {
            [_listModel replaceObjectAtIndex:i withObject:conversation];
        }
    }
    if (_ogAllDialogItems.count != 0)
    {
        NSMutableArray *allDialogItems = [_ogAllDialogItems mutableCopy];
        for (NSInteger i = (NSInteger)allDialogItems.count - 1; i >= 0; i--)
        {
            id item = allDialogItems[(NSUInteger)i];
            if (![item isKindOfClass:[TGConversation class]])
                continue;
            TGConversation *conversation = dict[@(((TGConversation *)item).conversationId)];
            if (conversation == nil)
                continue;
            if (conversation.isDeleted || conversation.isDeactivated || conversation.leftChat || conversation.kickedFromChat)
                [allDialogItems removeObjectAtIndex:(NSUInteger)i];
            else
                [allDialogItems replaceObjectAtIndex:(NSUInteger)i withObject:conversation];
        }
        _ogAllDialogItems = allDialogItems;
    }
    NSUInteger archivedTotalNow = [self og_archivedConversationCount];
    if (archivedTotalPrior != archivedTotalNow)
    {
        if (_ogArchiveExpanded && archivedTotalNow == 0)
            _ogArchiveExpanded = false;
        [self updateBarButtonItemsAnimated:false];
        [self reloadData:false];
        _visibleConversationsPipe.sink(@true);
        [self updateSearchBarBackground];
        [self dialogListPresentationUpdated];
        return;
    }
    
    if (_ogSelectedDialogFilterId != 0)
    {
        _ogVisibleListCache = nil;
        _ogVisibleListCacheFilterId = INT32_MIN;
        [self reloadData:false];
        [self og_updateFolderTabs];
    }
    else
    {
        for (TGDialogListCell *cell in _tableView.visibleCells) {
            if ([cell isKindOfClass:[TGDialogListCell class]]) {
                id<TGDialogListItem> conversation = dict[@(cell.conversationId)];
                if ([conversation isKindOfClass:[TGConversation class]]) {
                    [self prepareCell:cell forConversation:(TGConversation *)conversation animated:true context:TGDialogListCellContextList];
                } else if ([conversation isKindOfClass:[TGFeed class]]) {
                    [self prepareCell:cell forFeed:(TGFeed *)conversation animated:true];
                }
            }
        }
        [self og_updateFolderTabs];
    }
    
    [self og_scheduleFolderPeerHydrationReconciliation];
    _visibleConversationsPipe.sink(@true);
    [self dialogListPresentationUpdated];

}

- (void)dialogListItemsChanged:(NSArray *)insertedIndices insertedItems:(NSArray *)insertedItems updatedIndices:(NSArray *)updatedIndices updatedItems:(NSArray *)updatedItems removedIndices:(NSArray *)removedIndices
{
    TG_DIALOG_LIST_COST(TGDialogListCostItemsChanged);
    [self dialogListBeginRateLimitedUIUpdate];
    if ([self dialogListShouldCoalesceUIUpdates])
    {
        [self dialogListCoalesceItemsChanged:insertedIndices insertedItems:insertedItems updatedIndices:updatedIndices updatedItems:updatedItems removedIndices:removedIndices];
        if (self == TGAppDelegateInstance.rootController.dialogListController)
            OGStartupDiagnosticsUIWorkPending(true);
        return;
    }

    NSArray *previousVisibleItems = [[self og_visibleListModel] copy];
    int countBefore = (int)_listModel.count;
    NSMutableSet *removedPeerIds = [[NSMutableSet alloc] init];

    NSMutableIndexSet *removalPositions = [[NSMutableIndexSet alloc] init];
    for (NSNumber *nRemovedIndex in removedIndices)
    {
        NSInteger removedIndex = [nRemovedIndex integerValue];
        if (removedIndex >= 0 && removedIndex < (NSInteger)_listModel.count)
        {
            id item = _listModel[(NSUInteger)removedIndex];
            if ([item isKindOfClass:[TGConversation class]])
                [removedPeerIds addObject:@(((TGConversation *)item).conversationId)];
            [removalPositions addIndex:(NSUInteger)removedIndex];
        }
    }

    if (removalPositions.count != 0)
        [_listModel removeObjectsAtIndexes:removalPositions];

    NSMutableDictionary *modelIndices = TGDialogListItemIndices(_listModel);
    NSUInteger updateCount = MIN(updatedIndices.count, updatedItems.count);
    for (NSUInteger updateIndex = 0; updateIndex < updateCount; updateIndex++)
    {
        id updatedItem = updatedItems[updateIndex];
        NSInteger modelIndex = [updatedIndices[updateIndex] integerValue];
        int64_t updatedPeerId = 0;
        if ([updatedItem isKindOfClass:[TGConversation class]])
            updatedPeerId = ((TGConversation *)updatedItem).conversationId;
        else if ([updatedItem isKindOfClass:[TGFeed class]])
            updatedPeerId = ((TGFeed *)updatedItem).conversationId;

        bool indexMatches = modelIndex >= 0 && modelIndex < (NSInteger)_listModel.count;
        if (indexMatches && updatedPeerId != 0)
        {
            id currentItem = _listModel[(NSUInteger)modelIndex];
            int64_t currentPeerId = 0;
            if ([currentItem isKindOfClass:[TGConversation class]])
                currentPeerId = ((TGConversation *)currentItem).conversationId;
            else if ([currentItem isKindOfClass:[TGFeed class]])
                currentPeerId = ((TGFeed *)currentItem).conversationId;
            indexMatches = currentPeerId == updatedPeerId;
        }

        if (!indexMatches && updatedPeerId != 0)
        {
            NSNumber *index = modelIndices[@(updatedPeerId)];
            modelIndex = index == nil ? NSNotFound : index.integerValue;
        }

        if (modelIndex != NSNotFound && modelIndex >= 0 && modelIndex < (NSInteger)_listModel.count)
            [_listModel replaceObjectAtIndex:(NSUInteger)modelIndex withObject:updatedItem];
    }

    NSUInteger insertionCount = MIN(insertedIndices.count, insertedItems.count);
    NSMutableIndexSet *insertionPositions = [[NSMutableIndexSet alloc] init];
    NSMutableArray *insertionObjects = [[NSMutableArray alloc] initWithCapacity:insertionCount];
    NSMutableDictionary *insertionsByIndex = [[NSMutableDictionary alloc] initWithCapacity:insertionCount];
    for (NSUInteger i = 0; i < insertionCount; i++)
    {
        NSInteger index = [insertedIndices[i] integerValue];
        if (index >= 0)
            insertionsByIndex[@(index)] = insertedItems[i];
    }
    NSArray *orderedInsertionIndices = [insertionsByIndex.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSNumber *index in orderedInsertionIndices)
    {
        NSUInteger position = index.unsignedIntegerValue;
        if (position > _listModel.count + insertionObjects.count)
            continue;
        [insertionPositions addIndex:position];
        [insertionObjects addObject:insertionsByIndex[index]];
    }
    if (insertionObjects.count != 0)
        [_listModel insertObjects:insertionObjects atIndexes:insertionPositions];

    if (_ogAllDialogItems.count != 0 && (removedPeerIds.count != 0 || updatedItems.count != 0 || insertedItems.count != 0))
    {
        NSMutableArray *allDialogItems = [_ogAllDialogItems mutableCopy];
        NSMutableDictionary *updatesByPeerId = [[NSMutableDictionary alloc] initWithCapacity:updatedItems.count];
        for (id updatedItem in updatedItems)
        {
            if ([updatedItem isKindOfClass:[TGConversation class]])
            {
                NSNumber *peerId = @(((TGConversation *)updatedItem).conversationId);
                if (updatesByPeerId[peerId] == nil)
                    updatesByPeerId[peerId] = updatedItem;
            }
        }
        NSMutableSet *allPeerIds = [[NSMutableSet alloc] initWithCapacity:allDialogItems.count];
        for (NSInteger i = (NSInteger)allDialogItems.count - 1; i >= 0; i--)
        {
            id item = allDialogItems[(NSUInteger)i];
            if (![item isKindOfClass:[TGConversation class]])
                continue;
            NSNumber *peerId = @(((TGConversation *)item).conversationId);
            if ([removedPeerIds containsObject:peerId])
            {
                [allDialogItems removeObjectAtIndex:(NSUInteger)i];
                continue;
            }
            TGConversation *updatedConversation = updatesByPeerId[peerId];
            if (updatedConversation != nil)
            {
                if (updatedConversation.isDeleted || updatedConversation.isDeactivated || updatedConversation.leftChat || updatedConversation.kickedFromChat)
                {
                    [allDialogItems removeObjectAtIndex:(NSUInteger)i];
                    continue;
                }
                [allDialogItems replaceObjectAtIndex:(NSUInteger)i withObject:updatedConversation];
            }
            [allPeerIds addObject:peerId];
        }
        for (TGConversation *insertedConversation in insertedItems)
        {
            if (![insertedConversation isKindOfClass:[TGConversation class]] || insertedConversation.isDeleted || insertedConversation.isDeactivated || insertedConversation.leftChat || insertedConversation.kickedFromChat)
                continue;
            NSNumber *peerId = @(insertedConversation.conversationId);
            if (![allPeerIds containsObject:peerId])
            {
                [allPeerIds addObject:peerId];
                [allDialogItems addObject:insertedConversation];
            }
        }
        _ogAllDialogItems = allDialogItems;
    }

    _ogVisibleListCache = nil;
    _ogVisibleListCacheFilterId = INT32_MIN;
    NSArray *currentVisibleItems = [self og_visibleListModel];

    bool stableVisibleOrder = insertedIndices.count == 0 && removedIndices.count == 0 && previousVisibleItems.count == currentVisibleItems.count;
    if (stableVisibleOrder)
    {
        for (NSUInteger i = 0; i < currentVisibleItems.count; i++)
        {
            id previousItem = previousVisibleItems[i];
            id currentItem = currentVisibleItems[i];
            int64_t previousPeerId = 0;
            int64_t currentPeerId = 0;

            if ([previousItem isKindOfClass:[TGConversation class]])
                previousPeerId = ((TGConversation *)previousItem).conversationId;
            else if ([previousItem isKindOfClass:[TGFeed class]])
                previousPeerId = ((TGFeed *)previousItem).conversationId;

            if ([currentItem isKindOfClass:[TGConversation class]])
                currentPeerId = ((TGConversation *)currentItem).conversationId;
            else if ([currentItem isKindOfClass:[TGFeed class]])
                currentPeerId = ((TGFeed *)currentItem).conversationId;

            if (previousPeerId != currentPeerId || (previousPeerId == 0 && previousItem != currentItem && ![previousItem isEqual:currentItem]))
            {
                stableVisibleOrder = false;
                break;
            }
        }
    }

    if (stableVisibleOrder)
    {
        if (TGDialogListSingleCoreDevice() && _dialogListFastScrolling)
        {
            _dialogListVisibleRefreshPending = true;
        }
        else
        {
            [self dialogListRefreshVisibleCellsAnimated:true];
        }
        [self og_updateFolderTabs];
    }
    else
    {
        if (![self dialogListApplyDisplayedItems:currentVisibleItems animated:false])
            [self reloadData:false];
        [self og_updateFolderTabs];
    }

    [self og_scheduleFolderPeerHydrationReconciliation];
    _visibleConversationsPipe.sink(@true);

    if ((countBefore == 0) != (_listModel.count == 0))
    {
        [self updateEmptyListContainer];

        if (_listModel.count == 0)
            [self setupEditingMode:false setupTable:true];
    }

    [self updateSearchBarBackground];
    [self dialogListPresentationUpdated];
}

- (void)updateSearchBarBackground {
    bool firstRowPinned = false;
    NSArray *displayedRows = [self dialogListDisplayedItems];
    if (displayedRows.count != 0 && [displayedRows[0] isKindOfClass:[TGConversation class]]) {
        TGConversation *firstDialog = displayedRows[0];
        firstRowPinned = firstDialog.pinnedToTop || firstDialog.isAd || (_dialogListCompanion.forwardMode && firstDialog.conversationId == TGTelegraphInstance.clientUserId);
    }
    UIColor *backgroundColor = [TGPresentation brandedIOS6Style] ? [TGPresentation brandedIOS6SearchBarBackdropColorForSize:_searchBar.bounds.size] : (firstRowPinned ? _presentation.pallete.barBackgroundColor : _presentation.pallete.backgroundColor);
    if (!TGObjectCompare(_searchBar.backgroundColor, backgroundColor)) {
        _searchBar.backgroundColor = backgroundColor;
        _searchTopBackgroundView.backgroundColor = backgroundColor;
    }
    _searchBar.highContrast = firstRowPinned;
}

- (void)selectConversationWithId:(int64_t)conversationId
{
    bool found = false;
    
    NSArray *displayedRows = [self dialogListDisplayedItems];
    int index = -1;
    for (TGConversation *conversation in displayedRows)
    {
        index++;
        if (![conversation isKindOfClass:[TGConversation class]])
            continue;
        
        if (conversation.conversationId == conversationId && conversationId != 0)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:1];
            if (indexPath.section >= [_tableView numberOfSections] || indexPath.row >= [_tableView numberOfRowsInSection:indexPath.section])
            {
                TGLog(@"DIALOGS select.skip invalid index peer=%lld row=%d visible=%d rows=%d", conversationId, index, (int)displayedRows.count, indexPath.section < [_tableView numberOfSections] ? (int)[_tableView numberOfRowsInSection:indexPath.section] : -1);
                break;
            }
            
            UITableViewScrollPosition scrollPosition = UITableViewScrollPositionNone;
            
            CGRect rowRectInView = [_tableView convertRect:[_tableView rectForRowAtIndexPath:indexPath] toView:self.view];
            if (rowRectInView.origin.y + rowRectInView.size.height > self.view.frame.size.height - self.controllerInset.bottom)
                scrollPosition = UITableViewScrollPositionBottom;
            else if (rowRectInView.origin.y < self.controllerInset.top)
                scrollPosition = UITableViewScrollPositionTop;
            
            if (_searchMixin.isActive)
                scrollPosition = UITableViewScrollPositionNone;
            
            [_tableView selectRowAtIndexPath:indexPath animated:false scrollPosition:scrollPosition];
            
            found = true;
            
            break;
        }
    }
    
    if (!found && [_tableView indexPathForSelectedRow] != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:false];
}

- (void)dialogListRequestSelfUserSnapshot:(void (^)(TGUser *user))completion
{
    if (_dialogListSelfUserSnapshotResolved)
    {
        if (completion != nil)
            completion(_dialogListSelfUserSnapshot);
        return;
    }

    if (completion != nil)
        [_dialogListSelfUserSnapshotWaiters addObject:[completion copy]];
    if (_dialogListSelfUserSnapshotLoading)
        return;

    int64_t clientUserId = TGTelegraphInstance.clientUserId;
    if (clientUserId == 0)
    {
        _dialogListSelfUserSnapshotResolved = true;
        NSArray *waiters = [_dialogListSelfUserSnapshotWaiters copy];
        [_dialogListSelfUserSnapshotWaiters removeAllObjects];
        for (void (^waiter)(TGUser *) in waiters)
            waiter(nil);
        return;
    }

    _dialogListSelfUserSnapshotLoading = true;
    TGDialogListControllerReference *reference = _ogLifetimeReference;
    OGRuntimeDispatch(OGRuntimePriorityUtility, ^
    {
        TGUser *user = [TGDatabaseInstance() loadUser:clientUserId];
        OGPlatformDispatchOnMainThread(^
        {
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                controller->_dialogListSelfUserSnapshot = user;
                controller->_dialogListSelfUserSnapshotResolved = true;
                controller->_dialogListSelfUserSnapshotLoading = false;
                NSArray *waiters = [controller->_dialogListSelfUserSnapshotWaiters copy];
                [controller->_dialogListSelfUserSnapshotWaiters removeAllObjects];
                for (void (^waiter)(TGUser *) in waiters)
                    waiter(user);
            }];
        });
    });
}

- (void)searchResultsReloaded:(NSDictionary *)items searchString:(NSString *)searchString
{
    NSMutableArray *searchResultsSections = [[NSMutableArray alloc] init];
    
    if ([(NSArray *)items[@"hashtags"] count] != 0)
    {
        [searchResultsSections addObject:@{@"items": items[@"hashtags"], @"type": @"hashtags"}];
    }
    
    NSString *savedMessagesString = [TGLocalized(@"DialogList.SavedMessages") lowercaseString];
    NSString *query = [searchString lowercaseString];
    bool inhibitSavedMessages = self.dialogListCompanion.showGroupsOnly || self.dialogListCompanion.showPrivateOnly || self.dialogListCompanion.showGroupsAndChannelsOnly;
    bool addSavedMessages = !inhibitSavedMessages && [savedMessagesString hasPrefix:query];
    int64_t ownUid = TGTelegraphInstance.clientUserId;
    TGUser *ownUser = _dialogListSelfUserSnapshot;
    NSMutableArray *dialogs = [(NSArray *)items[@"dialogs"] mutableCopy];

    if (addSavedMessages && dialogs.count != 0)
    {
        for (NSInteger i = (NSInteger)dialogs.count - 1; i >= 0; i--)
        {
            id item = dialogs[(NSUInteger)i];
            if (![item isKindOfClass:[TGUser class]] || ((TGUser *)item).uid != ownUid)
                continue;
            ownUser = item;
            _dialogListSelfUserSnapshot = ownUser;
            _dialogListSelfUserSnapshotResolved = true;
            [dialogs removeObjectAtIndex:(NSUInteger)i];
        }
    }

    if (addSavedMessages && ownUser == nil && !_dialogListSelfUserSnapshotResolved)
    {
        NSDictionary *deferredItems = [items copy];
        NSString *deferredSearchString = [searchString copy];
        __weak TGDialogListController *weakSelf = self;
        [self dialogListRequestSelfUserSnapshot:^(__unused TGUser *user)
        {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil && [strongSelf->_searchResultsQuery isEqualToString:deferredSearchString])
                [strongSelf searchResultsReloaded:deferredItems searchString:deferredSearchString];
        }];
        addSavedMessages = false;
    }

    if (dialogs.count != 0)
    {
        if (addSavedMessages && ownUser != nil)
            [dialogs insertObject:ownUser atIndex:0];
        [searchResultsSections addObject:@{@"title": TGLocalized(@"DialogList.SearchSectionDialogs"), @"items": [self filteredDialogs:dialogs], @"type": @"dialogs"}];
    }
    else if (addSavedMessages && ownUser != nil)
    {
        [searchResultsSections addObject:@{@"title": TGLocalized(@"DialogList.SearchSectionDialogs"), @"items": @[ownUser], @"type": @"dialogs"}];
    }
    
    if ([(NSArray *)items[@"global"] count] != 0)
    {
        [searchResultsSections addObject:@{@"title": TGLocalized(@"DialogList.SearchSectionGlobal"), @"items": [self filteredDialogs:items[@"global"]], @"type": @"global"}];
    }
    
    if (!inhibitSavedMessages && [(NSArray *)items[@"messages"] count] != 0)
    {
        [searchResultsSections addObject:@{@"title": TGLocalized(@"DialogList.SearchSectionMessages"), @"items": items[@"messages"], @"type": @"messages"}];
    }
    
    if (!inhibitSavedMessages && [TGPhoneUtils maybePhone:searchString])
    {
        [searchResultsSections addObject:@{@"title": TGLocalized(@"Contacts.PhoneNumber"), @"items": @[ searchString ], @"type": @"phonenumber"}];
    }
    
    _searchResultsSections = searchResultsSections;
    _searchResultsQuery = searchString;
    
    [_searchMixin reloadSearchResults];
    
    [_searchMixin setSearchResultsTableViewHidden:searchString.length == 0];
}

#pragma mark - Interface logic

- (void)updateBarButtonItemsAnimated:(bool)animated
{
    NSUInteger state = ([TGPresentation brandedIOS6Style] ? 1u : 0u) | ([TGPresentation classicThemeStyle] ? 2u : 0u) | (_editingMode ? 4u : 0u) | (_ogArchiveExpanded ? 8u : 0u) | (_ogSelectedDialogFilterId != 0 ? 16u : 0u);
    TGPresentationPallete *pallete = self.presentation.pallete;
    if (_barButtonItemsApplied && _barButtonItemsState == state && _barButtonItemsPallete == pallete)
    {
#if OG_PLUGINS_AVAILABLE
        OGPluginUIChatListSurfacesUpdate(self, _tableView);
#endif
        return;
    }
    _barButtonItemsApplied = true;
    _barButtonItemsState = state;
    _barButtonItemsPallete = pallete;
    [self setLeftBarButtonItem:[self controllerLeftBarButtonItem] animated:animated];
    NSArray *rightItems = [self controllerRightBarButtonItems];
#if OG_PLUGINS_AVAILABLE
    rightItems = OGPluginUIChatListSurfacesRightBarItems(self, rightItems);
#endif
    [self setRightBarButtonItems:rightItems animated:animated];
#if OG_PLUGINS_AVAILABLE
    OGPluginUIChatListSurfacesUpdate(self, _tableView);
#endif
}

- (void)onegramRefreshChatListSurfaceHeader
{
#if OG_PLUGINS_AVAILABLE
    [self setRightBarButtonItems:OGPluginUIChatListSurfacesRightBarItems(self, [self controllerRightBarButtonItems]) animated:false];
#endif
}

- (void)editButtonPressed
{
    [self setupEditingMode:!_editingMode];
    
    [self updateBarButtonItemsAnimated:true];
}

- (void)doneButtonPressed
{
    [self setupEditingMode:!_editingMode];
    
    [self updateBarButtonItemsAnimated:false];
    
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            [(TGDialogListCell *)cell dismissEditingControls:true];
        }
    }
}

- (void)setupEditingMode:(bool)editing
{
    [self setupEditingMode:editing setupTable:true];
}

- (void)setupEditingMode:(bool)editing setupTable:(bool)setupTable
{
    _editingMode = editing;
    if (setupTable) {
        [_tableView setEditing:editing animated:true];
        
        if (iosMajorVersion() >= 7) {
            [UIView animateWithDuration:0.3 animations:^{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
                _tableView.separatorInset = UIEdgeInsetsMake(0.0f, (editing ? 38.0f : 0.0f) + 80.0f, 0.0f, 0.0f);
#endif
            }];
        }
    }
    
    if (!editing)
        [self selectCurrentConversation];
}

- (void)dismissEditingControls
{
    if (_editingMode && !_tableView.editing)
        [self setupEditingMode:false setupTable:false];
}

- (void)composeMessageButtonPressed:(id)__unused sender
{
    [_dialogListCompanion composeMessageAndOpenSearch:false];
}

- (void)clearChatCacheButtonPressed
{
    [TGDatabaseInstance() setCustomProperty:@"dialogListLoaded" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"dialogListRemoteOffset" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"dialogListHash" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"ios6ArchivePeerIdsComplete" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"ios6DialogListCacheVersion" value:nil];
    
    _ogArchiveExpanded = false;
    _ogArchiveItemsLoadRequested = false;
    
    [self updateBarButtonItemsAnimated:false];
    [_dialogListCompanion clearChatListCacheAndReload];
}

- (void)og_clearChatCacheRequested:(NSNotification *)__unused notification
{
    [self clearChatCacheButtonPressed];
}

- (void)archiveButtonPressed:(id)__unused sender
{
    _ogArchiveExpanded = !_ogArchiveExpanded;
    if (_ogArchiveExpanded && (!_ogArchiveItemsLoadRequested || [self og_archivedConversationCount] == 0))
    {
        _ogArchiveItemsLoadRequested = true;
        [_dialogListCompanion loadArchiveItems];
    }
    [self og_logArchiveDiagnostics:@"nav.tap"];
    [self updateBarButtonItemsAnimated:false];
    [self og_layoutFolderTabs];
    [self og_updateFolderTabs];
    [self reloadData:false];
    if ([self dialogListDisplayedItems].count != 0)
        [_tableView setContentOffset:CGPointMake(0.0f, -_tableView.contentInset.top) animated:false];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    static bool canSelect = true;
    if (canSelect)
    {
        canSelect = false;
        OGPlatformDispatchAfterCurrentMainRunLoop(^
        {
            canSelect = true;
        });
    }
    else
        return;
    
    if (TGIsPad())
        [self.view endEditing:true];
    
    if (tableView == _tableView)
    {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if (cell.selectionStyle != UITableViewCellSelectionStyleNone)
        {
            TGConversation *conversation = nil;
            id item = [self og_dialogListItemAtIndexPath:indexPath];
            if ([item isKindOfClass:[TGConversation class]] || [item isKindOfClass:[TGFeed class]])
                conversation = item;
            
            if (conversation != nil)
            {
                [_dialogListCompanion conversationSelected:conversation];
            }
            
            if (_dialogListCompanion.forwardMode || _dialogListCompanion.privacyMode || _dialogListCompanion.showPrivateOnly || _dialogListCompanion.showGroupsAndChannelsOnly)
                [_tableView deselectRowAtIndexPath:indexPath animated:true];
        }
    }
    else
    {
        id result = [_searchResultsSections[indexPath.section][@"items"] objectAtIndex:indexPath.row];
        NSString *type = _searchResultsSections[indexPath.section][@"type"];
        
        if ([result isKindOfClass:[TGConversation class]])
        {
            [_searchDisposable setDisposable:nil];
            TGConversation *conversation = (TGConversation *)result;
            if ([conversation.additionalProperties objectForKey:@"searchMessageId"] != nil)
            {
                _didSelectMessage = true;
                [_dialogListCompanion searchResultSelectedConversation:(TGConversation *)result atMessageId:[[conversation.additionalProperties objectForKey:@"searchMessageId"] intValue]];
            }
            else
            {
                [_searchDisposable setDisposable:nil];
                [TGGlobalMessageSearchSignals addRecentPeerResult:((TGConversation *)result).conversationId];
                [_dialogListCompanion searchResultSelectedConversation:(TGConversation *)result];
            }
            [tableView deselectRowAtIndexPath:indexPath animated:true];
            
            if (![type isEqualToString:@"recent"])
                _didSelectGlobalResult = true;
        }
        else if ([result isKindOfClass:[TGUser class]])
        {
            [_searchDisposable setDisposable:nil];
            [_dialogListCompanion searchResultSelectedUser:(TGUser *)result];
            [TGGlobalMessageSearchSignals addRecentPeerResult:((TGUser *)result).uid];
            [tableView deselectRowAtIndexPath:indexPath animated:true];
            
            if (![type isEqualToString:@"recent"])
                _didSelectGlobalResult = true;
        }
        else if ([result isKindOfClass:[TGMessage class]])
        {
            _didSelectMessage = true;
            [_dialogListCompanion searchResultSelectedMessage:(TGMessage *)result];
        }
        else if ([_searchResultsSections[indexPath.section][@"type"] isEqualToString:@"phonenumber"])
        {
            TGCreateContactController *createContactController = [[TGCreateContactController alloc] initWithFirstName:@" " lastName:nil phoneNumber:[TGPhoneUtils formatPhone:[TGPhoneUtils cleanPhone:result] forceInternational:true] attachment:nil];
            createContactController.delegate = self;
            
            TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[createContactController]];
            
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
            {
                navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
                navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
            }
            
            [self presentViewController:navigationController animated:true completion:^{
                _searchBar.text = @"";
                [_searchMixin setIsActive:false animated:false];
            }];
        }
        else if ([result respondsToSelector:@selector(characterAtIndex:)])
        {
            [_searchBar setText:[@"#" stringByAppendingString:result]];
        }
    }
    
    if (_dialogListCompanion.forwardMode)
        [tableView deselectRowAtIndexPath:indexPath animated:true];
}

- (void)maybeDismissSearchResults
{
    if (_searchMixin.isActive && _didSelectGlobalResult)
        [_searchMixin setIsActive:false animated:false];
}

#pragma mark - Table logic

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (tableView == _tableView)
        return 2;
    
        return _searchResultsSections.count;
}

- (bool)og_isArchiveHeaderItem:(id)item
{
    return [item isKindOfClass:[NSString class]] && [(NSString *)item isEqualToString:OGCompatArchiveHeaderItem];
}

- (NSString *)og_archiveSampleForConversation:(TGConversation *)conversation
{
    NSString *title = conversation.chatTitle.length == 0 ? conversation.dialogListData[@"title"] : conversation.chatTitle;
    if (title.length > 32)
        title = [[title substringToIndex:32] stringByAppendingString:@"..."];
    
    return [[NSString alloc] initWithFormat:@"%lld%@:%@", conversation.conversationId, conversation.isArchived ? @"F" : @"", title ?: @""];
}

- (NSArray *)og_archiveLimitedSamples:(NSArray *)samples
{
    if (samples.count <= 20)
        return samples;
    
    NSMutableArray *cappedSamples = [[NSMutableArray alloc] initWithCapacity:21];
    for (NSUInteger i = 0; i < 20; i++)
        [cappedSamples addObject:samples[i]];
    [cappedSamples addObject:[[NSString alloc] initWithFormat:@"...+%d", (int)(samples.count - 20)]];
    return cappedSamples;
}

- (void)og_logArchiveDiagnostics:(NSString *)reason
{
    (void)reason;
}

- (bool)og_isArchivedConversation:(id)item
{
    if (![item isKindOfClass:[TGConversation class]])
        return false;
    
    TGConversation *conversation = (TGConversation *)item;
    return conversation.pinnedDate == 0 && conversation.isArchived;
}

- (bool)og_newChatListGesturesEnabled
{
    if (!OGPlatformCachedBoolDefault(OGCompatNewChatListGesturesKey))
        return false;

    return [self og_foldersAllowed] && !_dialogListCompanion.forwardMode && !_dialogListCompanion.feedChannels;
}

- (void)og_updateNewChatListGesturesState
{
    bool enabled = [self og_newChatListGesturesEnabled];
    _ogFolderPanGestureRecognizer.enabled = enabled;
    _ogChatActionsLongPressRecognizer.enabled = enabled;

    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
            [(TGDialogListCell *)cell setSwipeActionsEnabled:!enabled];
    }
}

- (NSString *)onegramDialogListTitle
{
    NSInteger mode = [TGOnegramSettings integerForKey:TGOnegramSettingChatListTitleMode];
    if (mode == 3)
    {
        NSString *custom = [TGOnegramSettings stringForKey:TGOnegramSettingChatListCustomTitle];
        if (custom.length != 0)
            return custom;
    }
    else if (mode == 1 || mode == 2)
    {
        TGUser *user = TGTelegraphInstance.clientUserId == 0 ? nil : [TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId];
        if (mode == 1 && user.userName.length != 0)
            return [@"@" stringByAppendingString:user.userName];
        if (mode == 2 && user.firstName.length != 0)
            return user.firstName;
        if (mode == 2 && user.displayName.length != 0)
            return user.displayName;
    }
    return TGLocalized(@"DialogList.Title");
}

- (void)onegramApplyTitle
{
    if (_titleLabel == nil)
        return;
    NSString *title = [self onegramDialogListTitle];
    [self setTitleText:title];
    _titleLabel.text = title;
    [_titleLabel sizeToFit];
    [self _layoutTitleViews:self.interfaceOrientation];
}

- (void)updateSnowflakesAnimated:(bool)animated
{
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (!_snowflakesOnScreen || navigationBar == nil || !TGSnowflakesVisibleForPallete(_presentation.pallete))
    {
        [_snowflakesView setActive:false animated:animated];
        return;
    }
    if (_snowflakesView == nil)
    {
        _snowflakesView = [[TGSnowflakesView alloc] initWithFrame:navigationBar.bounds];
        _snowflakesView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _snowflakesView.alpha = 0.0f;
    }
    if (_snowflakesView.superview != navigationBar)
    {
        _snowflakesView.frame = navigationBar.bounds;
        [navigationBar addSubview:_snowflakesView];
    }
    else
        [navigationBar bringSubviewToFront:_snowflakesView];
    _snowflakesView.color = [TGPresentation brandedIOS6Style] ? [TGPresentation brandedIOS6NavigationTitleColor] : _presentation.pallete.navigationTitleColor;
    [_snowflakesView setActive:true animated:animated];
}

- (void)onegramSettingsChanged:(NSNotification *)notification
{
    NSString *key = notification.userInfo[TGOnegramSettingsChangedKey];
    if ([key isEqualToString:TGOnegramSettingAppearanceSnowfall])
        [self updateSnowflakesAnimated:false];
    if ([key isEqualToString:TGOnegramSettingGeneralHideArchive])
    {
        [self updateBarButtonItemsAnimated:false];
    }
    else if ([key isEqualToString:TGOnegramSettingChatListTitleMode] || [key isEqualToString:TGOnegramSettingChatListCustomTitle])
    {
        [self onegramApplyTitle];
    }
    else if ([key isEqualToString:TGOnegramSettingChatListHideSearch])
    {
        if (_searchBar != nil && _tableView != nil && !_isDisplayingSearch)
        {
            _tableView.tableHeaderView = [TGOnegramSettings boolForKey:TGOnegramSettingChatListHideSearch] ? nil : _searchBar;
            [self resetInitialOffset];
        }
    }
    else if ([key isEqualToString:TGOnegramSettingChatListHideAllChatsTab])
    {
        [self og_setDialogFilters:_ogSourceDialogFilters];
        [self og_updateFolderTabs];
        [self og_layoutFolderTabs];
        [self reloadData:false];
    }
    else if ([key isEqualToString:TGOnegramSettingChatListCompact] || [key isEqualToString:TGOnegramSettingGeneralFilterZalgo] || [key isEqualToString:TGOnegramSettingGeneralExactNumbers] || [key isEqualToString:TGOnegramSettingAppearanceAvatarRoundness] || [key isEqualToString:TGOnegramSettingGeneralShowSeconds] || [key isEqualToString:TGOnegramSettingGeneralTimeZoneManual] || [key isEqualToString:TGOnegramSettingGeneralTimeZoneOffset] || [key isEqualToString:TGOnegramSettingGeneralDisableUnarchiveSwipe])
    {
        [self reloadData:false];
    }
}

- (void)og_newChatListGesturesChanged:(NSNotification *)__unused notification
{
    [self og_updateNewChatListGesturesState];
    [self reloadData:false];
}

- (NSInteger)og_selectedDialogFilterIndex
{
    NSInteger index = 0;
    for (NSDictionary *filter in _ogDialogFilters)
    {
        if ([filter[@"id"] intValue] == _ogSelectedDialogFilterId)
            return index;
        index++;
    }
    return NSNotFound;
}

- (void)og_completeDialogFilterSelectionAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_ogDialogFilters.count)
        return;

    NSDictionary *filter = _ogDialogFilters[index];
    int32_t filterId = [filter[@"id"] intValue];
    if (filterId != _ogSelectedDialogFilterId)
        return;

    [self og_storeSelectedDialogFilterId];

    if (filterId != 0 && [_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]])
    {
        TGDialogListController *controller = self;
        if (cpuCoreCount() > 1)
        {
            [self og_refreshAllDialogItems:false];
        }
        else
        {
            int32_t selectedFilterId = filterId;
            OGPlatformDispatchOnMainThreadAfter(0.25, ^
            {
                if (controller->_ogSelectedDialogFilterId == selectedFilterId)
                    [controller og_refreshAllDialogItems:false];
            });
        }
        OGPlatformDispatchOnMainThreadAfter(0.75, ^
        {
            if (controller->_ogSelectedDialogFilterId == 0)
                return;

            [controller og_hydrateExplicitFolderPeers];
            if ([controller->_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]])
                [(TGTelegraphDialogListCompanion *)controller->_dialogListCompanion ios6PreloadAllDialogsForFolders];
        });
    }
}

- (void)og_selectDialogFilterAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_ogDialogFilters.count || _ogFolderSwipeActive || _ogFolderSwipeFinishing)
        return;

    NSDictionary *filter = _ogDialogFilters[index];
    int32_t filterId = [filter[@"id"] intValue];
    if (filterId == _ogSelectedDialogFilterId)
        return;

    _ogArchiveExpanded = false;
    _ogSelectedDialogFilterId = filterId;
    _ogVisibleListCache = nil;
    _ogVisibleListCacheFilterId = INT32_MIN;

    [self reloadData:false];
    [self updateBarButtonItemsAnimated:false];
    [self resetInitialOffset];
    [self og_completeDialogFilterSelectionAtIndex:index];
}

- (CGRect)og_folderSwipeTabsRect
{
    if (_ogFolderTabsView == nil || _ogFolderTabsView.hidden || _ogFolderTabsView.bounds.size.height < FLT_EPSILON)
        return CGRectZero;

    CGRect rect = [_ogFolderTabsView convertRect:_ogFolderTabsView.bounds toView:self.view];
    return CGRectIntersection(rect, self.view.bounds);
}

- (CGRect)og_folderSwipeContentRect
{
    if (_tableView == nil)
        return CGRectZero;

    CGRect tableRect = [_tableView.superview convertRect:_tableView.frame toView:self.view];
    CGRect tabsRect = [self og_folderSwipeTabsRect];
    CGFloat top = CGRectGetMinY(tableRect);
    if (!CGRectIsEmpty(tabsRect))
        top = MAX(top, CGRectGetMaxY(tabsRect));
    if ([TGPresentation brandedIOS6Style] && _ogPlayerHeight > FLT_EPSILON && _ogListHeaderView.superview != nil)
    {
        CGRect playerRect = CGRectIntersection([_ogPlayerHostView convertRect:_ogPlayerHostView.bounds toView:self.view], self.view.bounds);
        if (!CGRectIsEmpty(playerRect))
            top = MAX(top, CGRectGetMaxY(playerRect));
    }

    CGRect rect = CGRectMake(CGRectGetMinX(tableRect), top, CGRectGetWidth(tableRect), CGRectGetMaxY(tableRect) - top);
    return CGRectIntersection(rect, self.view.bounds);
}

- (UIImage *)og_folderSwipeSnapshotForRect:(CGRect)rect
{
    if (CGRectIsEmpty(rect) || rect.size.width < 1.0f || rect.size.height < 1.0f)
        return nil;

    UIGraphicsBeginImageContextWithOptions(rect.size, true, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, -rect.origin.x, -rect.origin.y);
    [self.view.layer renderInContext:context];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIView *)og_folderSwipeIndicatorForButton:(UIButton *)button
{
    UIView *indicator = [button viewWithTag:6199];
    return indicator.superview == button ? indicator : nil;
}

- (CGFloat)og_folderTabsOffsetRevealingButton:(UIButton *)button fromOffset:(CGFloat)offset
{
    CGFloat inset = [TGPresentation brandedIOS6Style] ? 13.0f : 16.0f;
    CGRect rect = CGRectInset(button.frame, -inset, 0.0f);
    CGFloat visibleWidth = _ogFolderTabsScrollView.bounds.size.width;
    if (CGRectGetMinX(rect) < offset)
        offset = CGRectGetMinX(rect);
    else if (CGRectGetMaxX(rect) > offset + visibleWidth)
        offset = CGRectGetMaxX(rect) - visibleWidth;
    CGFloat maxOffset = MAX(0.0f, _ogFolderTabsScrollView.contentSize.width - visibleWidth);
    return MAX(0.0f, MIN(maxOffset, offset));
}

- (CGFloat)og_folderSwipeTargetContentOffsetForSourceOffset:(CGFloat)sourceOffset
{
    CGFloat minOffset = -_tableView.contentInset.top;
    if ([_tableView numberOfSections] < 2)
        return minOffset;
    CGFloat pinnedHeaderOffset = [_tableView rectForHeaderInSection:1].origin.y - _tableView.contentInset.top;
    return MAX(minOffset, MIN(sourceOffset, pinnedHeaderOffset));
}

- (void)og_beginFolderSwipeToIndex:(NSInteger)targetIndex translation:(CGPoint)translation
{
    if (_ogFolderSwipeActive || _ogFolderSwipeFinishing || targetIndex < 0 || targetIndex >= (NSInteger)_ogDialogFilters.count)
        return;

    NSInteger sourceIndex = [self og_selectedDialogFilterIndex];
    if (sourceIndex == NSNotFound || sourceIndex == targetIndex)
        return;

    int32_t sourceFilterId = [_ogDialogFilters[sourceIndex][@"id"] intValue];
    int32_t targetFilterId = [_ogDialogFilters[targetIndex][@"id"] intValue];
    if (sourceFilterId == targetFilterId)
        return;

    UIButton *sourceButton = (UIButton *)[_ogFolderTabsScrollView viewWithTag:6100 + sourceIndex];
    UIButton *targetButton = (UIButton *)[_ogFolderTabsScrollView viewWithTag:6100 + targetIndex];
    if (![sourceButton isKindOfClass:[UIButton class]] || ![targetButton isKindOfClass:[UIButton class]])
        return;

    CGRect contentRect = [self og_folderSwipeContentRect];
    if (CGRectIsEmpty(contentRect))
        return;

    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]] && [(TGDialogListCell *)cell isEditingControlsExpanded])
            [(TGDialogListCell *)cell setEditingConrolsExpanded:false animated:false];
    }

    UIImage *sourceImage = [self og_folderSwipeSnapshotForRect:contentRect];
    if (sourceImage == nil)
        return;

    _ogFolderSwipeActive = true;
    _ogFolderSwipeSourceIndex = sourceIndex;
    _ogFolderSwipeTargetIndex = targetIndex;
    _ogFolderSwipeSourceFilterId = sourceFilterId;
    _ogFolderSwipeTargetFilterId = targetFilterId;
    _ogFolderSwipeSourceContentOffset = _tableView.contentOffset;
    _ogFolderSwipeContentFrame = contentRect;
    _ogFolderSwipeSourceTabsOffset = _ogFolderTabsScrollView.contentOffset.x;
    _ogFolderSwipeTargetTabsOffset = [self og_folderTabsOffsetRevealingButton:targetButton fromOffset:_ogFolderSwipeSourceTabsOffset];

    _tableView.scrollEnabled = false;
    _ogChatActionsLongPressRecognizer.enabled = false;
    _ogArchiveExpanded = false;

    _ogSelectedDialogFilterId = targetFilterId;
    _ogVisibleListCache = nil;
    _ogVisibleListCacheFilterId = INT32_MIN;
    [self reloadData:false];
    [_tableView layoutIfNeeded];
    [_tableView setContentOffset:CGPointMake(_ogFolderSwipeSourceContentOffset.x, [self og_folderSwipeTargetContentOffsetForSourceOffset:_ogFolderSwipeSourceContentOffset.y]) animated:false];
    [_tableView layoutIfNeeded];
    [self og_updateFolderEmptyLabel];
    UIImage *targetImage = [self og_folderSwipeSnapshotForRect:contentRect];

    _ogFolderSwipeContainerView = [[UIView alloc] initWithFrame:contentRect];
    _ogFolderSwipeContainerView.clipsToBounds = true;
    _ogFolderSwipeContainerView.userInteractionEnabled = false;
    _ogFolderSwipeContainerView.backgroundColor = _tableView.backgroundColor;

    _ogFolderSwipeSourceView = [[UIImageView alloc] initWithImage:sourceImage];
    _ogFolderSwipeSourceView.frame = _ogFolderSwipeContainerView.bounds;
    [_ogFolderSwipeContainerView addSubview:_ogFolderSwipeSourceView];

    _ogFolderSwipeTargetView = [[UIImageView alloc] initWithImage:targetImage];
    _ogFolderSwipeTargetView.frame = _ogFolderSwipeContainerView.bounds;
    [_ogFolderSwipeContainerView addSubview:_ogFolderSwipeTargetView];

    [self.view addSubview:_ogFolderSwipeContainerView];

    UIView *sourceIndicator = [self og_folderSwipeIndicatorForButton:sourceButton];
    if (sourceIndicator != nil)
    {
        _ogFolderSwipeSourceIndicatorFrame = [sourceButton convertRect:sourceIndicator.frame toView:_ogFolderTabsScrollView];
        _ogFolderSwipeTargetIndicatorFrame = [targetButton convertRect:CGRectMake(sourceIndicator.frame.origin.x, sourceIndicator.frame.origin.y, MAX(0.0f, targetButton.bounds.size.width - sourceIndicator.frame.origin.x * 2.0f), sourceIndicator.frame.size.height) toView:_ogFolderTabsScrollView];
        _ogFolderSwipeIndicatorView = [[UIView alloc] initWithFrame:_ogFolderSwipeSourceIndicatorFrame];
        _ogFolderSwipeIndicatorView.backgroundColor = sourceIndicator.backgroundColor;
        _ogFolderSwipeIndicatorView.userInteractionEnabled = false;
        sourceIndicator.hidden = true;
        [_ogFolderTabsScrollView addSubview:_ogFolderSwipeIndicatorView];
    }

    CGFloat direction = targetIndex > sourceIndex ? 1.0f : -1.0f;
    if (TGIsRTL())
        direction = -direction;
    _ogFolderSwipeTargetOffset = direction * contentRect.size.width;

    [self og_updateFolderSwipeWithTranslation:translation];
}

- (void)og_applyFolderSwipeTranslation:(CGFloat)x
{
    CGFloat width = _ogFolderSwipeContentFrame.size.width;
    CGRect bounds = _ogFolderSwipeContainerView.bounds;
    _ogFolderSwipeSourceView.frame = CGRectOffset(bounds, x, 0.0f);
    _ogFolderSwipeTargetView.frame = CGRectOffset(bounds, _ogFolderSwipeTargetOffset + x, 0.0f);

    CGFloat expectedTranslation = -_ogFolderSwipeTargetOffset;
    CGFloat progress = width < 1.0f ? 0.0f : MAX(0.0f, MIN(1.0f, x / expectedTranslation));
    CGRect fromFrame = _ogFolderSwipeSourceIndicatorFrame;
    CGRect toFrame = _ogFolderSwipeTargetIndicatorFrame;
    _ogFolderSwipeIndicatorView.frame = CGRectMake(fromFrame.origin.x + (toFrame.origin.x - fromFrame.origin.x) * progress,
                                                     fromFrame.origin.y + (toFrame.origin.y - fromFrame.origin.y) * progress,
                                                     fromFrame.size.width + (toFrame.size.width - fromFrame.size.width) * progress,
                                                     fromFrame.size.height + (toFrame.size.height - fromFrame.size.height) * progress);
    _ogFolderTabsScrollView.contentOffset = CGPointMake(_ogFolderSwipeSourceTabsOffset + (_ogFolderSwipeTargetTabsOffset - _ogFolderSwipeSourceTabsOffset) * progress, _ogFolderTabsScrollView.contentOffset.y);
}

- (void)og_updateFolderSwipeWithTranslation:(CGPoint)translation
{
    if (!_ogFolderSwipeActive || _ogFolderSwipeFinishing || _ogFolderSwipeContainerView == nil)
        return;

    CGFloat width = _ogFolderSwipeContentFrame.size.width;
    if (width < 1.0f)
        return;

    CGFloat expectedTranslation = -_ogFolderSwipeTargetOffset;
    CGFloat x = translation.x;
    if (x * expectedTranslation < 0.0f)
        x *= 0.22f;
    x = MAX(-width, MIN(width, x));

    [self og_applyFolderSwipeTranslation:x];
}

- (void)og_restoreFolderSwipeSource
{
    _ogSelectedDialogFilterId = _ogFolderSwipeSourceFilterId;
    _ogVisibleListCache = nil;
    _ogVisibleListCacheFilterId = INT32_MIN;
    [self reloadData:false];
    [_tableView layoutIfNeeded];
    [_tableView setContentOffset:_ogFolderSwipeSourceContentOffset animated:false];
}

- (void)og_teardownFolderSwipe
{
    [_ogFolderSwipeContainerView removeFromSuperview];
    _ogFolderSwipeContainerView = nil;
    _ogFolderSwipeSourceView = nil;
    _ogFolderSwipeTargetView = nil;
    [_ogFolderSwipeIndicatorView removeFromSuperview];
    _ogFolderSwipeIndicatorView = nil;

    _ogFolderSwipeActive = false;
    _ogFolderSwipeFinishing = false;
    _tableView.scrollEnabled = true;
    [self og_updateNewChatListGesturesState];
    _ogFolderTabsStateKey = nil;
    [self og_updateFolderTabs];
    [self og_updateFolderEmptyLabel];
}

- (void)og_finishFolderSwipeCommit:(bool)commit velocity:(CGPoint)velocity
{
    if (!_ogFolderSwipeActive || _ogFolderSwipeFinishing)
        return;

    _ogFolderSwipeFinishing = true;

    CGFloat width = _ogFolderSwipeContentFrame.size.width;
    CGFloat currentTranslation = _ogFolderSwipeSourceView.frame.origin.x;
    CGFloat finalTranslation = commit ? -_ogFolderSwipeTargetOffset : 0.0f;
    CGFloat distance = ABS(finalTranslation - currentTranslation);
    CGFloat velocityMagnitude = ABS(velocity.x);
    NSTimeInterval duration = width < 1.0f ? 0.0 : MAX(0.08, MIN(0.20, 0.08 + 0.12 * distance / width));
    if (velocityMagnitude > 1.0f)
        duration = MIN(duration, MAX(0.08, MIN(0.18, distance / velocityMagnitude)));

    TGDialogListController *controller = self;
    [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:^
    {
        [controller og_applyFolderSwipeTranslation:finalTranslation];
    } completion:^(__unused BOOL finished)
    {
        if (!controller->_ogFolderSwipeFinishing)
            return;

        NSInteger targetIndex = controller->_ogFolderSwipeTargetIndex;
        bool targetStillValid = targetIndex >= 0 && targetIndex < (NSInteger)controller->_ogDialogFilters.count && [controller->_ogDialogFilters[targetIndex][@"id"] intValue] == controller->_ogFolderSwipeTargetFilterId && controller->_ogSelectedDialogFilterId == controller->_ogFolderSwipeTargetFilterId;

        if (commit && targetStillValid)
        {
            [controller og_teardownFolderSwipe];
            [controller updateBarButtonItemsAnimated:false];
            [controller og_completeDialogFilterSelectionAtIndex:targetIndex];
        }
        else
        {
            [controller og_restoreFolderSwipeSource];
            [controller og_teardownFolderSwipe];
        }
    }];
}

- (void)og_cancelFolderSwipeImmediately
{
    if (!_ogFolderSwipeActive && !_ogFolderSwipeFinishing)
        return;

    [_ogFolderSwipeSourceView.layer removeAllAnimations];
    [_ogFolderSwipeTargetView.layer removeAllAnimations];
    [_ogFolderSwipeIndicatorView.layer removeAllAnimations];
    [_ogFolderTabsScrollView.layer removeAllAnimations];

    [self og_restoreFolderSwipeSource];
    [self og_teardownFolderSwipe];
}

- (void)og_folderPanGesture:(UIPanGestureRecognizer *)recognizer
{
    if (![self og_newChatListGesturesEnabled] || _isDisplayingSearch || _ogArchiveExpanded || _ogDialogFilters.count <= 1)
    {
        if (_ogFolderSwipeActive)
            [self og_finishFolderSwipeCommit:false velocity:CGPointZero];
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateBegan)
    {
        CGPoint velocity = [recognizer velocityInView:self.view];
        CGFloat logicalVelocityX = TGIsRTL() ? -velocity.x : velocity.x;
        NSInteger currentIndex = [self og_selectedDialogFilterIndex];
        if (currentIndex == NSNotFound)
            currentIndex = 0;
        NSInteger targetIndex = currentIndex + (logicalVelocityX < 0.0f ? 1 : -1);
        [self og_beginFolderSwipeToIndex:targetIndex translation:[recognizer translationInView:self.view]];
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateChanged)
    {
        [self og_updateFolderSwipeWithTranslation:[recognizer translationInView:self.view]];
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateEnded)
    {
        if (!_ogFolderSwipeActive)
            return;

        CGPoint translation = [recognizer translationInView:self.view];
        CGPoint velocity = [recognizer velocityInView:self.view];
        CGFloat expectedTranslation = -_ogFolderSwipeTargetOffset;
        bool movingTowardTarget = translation.x * expectedTranslation > 0.0f;
        bool velocityTowardTarget = velocity.x * expectedTranslation > 0.0f;
        CGFloat width = MAX(1.0f, _ogFolderSwipeContentFrame.size.width);
        CGFloat progress = ABS(translation.x) / width;
        CGFloat projectedProgress = ABS(translation.x + velocity.x * 0.16f) / width;
        bool commit = movingTowardTarget && (progress >= 0.30f || projectedProgress >= 0.48f || (velocityTowardTarget && ABS(velocity.x) >= 520.0f));

        [self og_finishFolderSwipeCommit:commit velocity:velocity];
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed)
        [self og_finishFolderSwipeCommit:false velocity:CGPointZero];
}

- (void)og_presentActionsForConversation:(TGConversation *)conversation fromRect:(CGRect)sourceRect
{
    if (![conversation isKindOfClass:[TGConversation class]] || conversation.conversationId == 0)
        return;

    NSDictionary *dialogListData = conversation.dialogListData;
    int savedMessagesMode = [dialogListData[@"isSavedMessages"] intValue];
    if (savedMessagesMode == 2 || conversation.isAd)
        return;

    bool isSavedMessages = savedMessagesMode != 0;
    bool isEncrypted = [dialogListData[@"isEncrypted"] boolValue];
    bool muted = [dialogListData[@"mute"] boolValue];
    bool pinned = conversation.pinnedToTop;
    bool archived = conversation.isArchived;
    bool read = !conversation.unreadMark && conversation.unreadCount == 0 && conversation.serviceUnreadCount == 0 && conversation.unreadMentionCount == 0;
    int64_t peerId = conversation.conversationId;

    NSMutableArray *actions = [[NSMutableArray alloc] init];
    if (!isSavedMessages)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(read ? @"DialogList.Unread" : @"DialogList.Read") action:@"read" type:TGActionSheetActionTypeGeneric]];

    if (!_dialogListCompanion.feedChannels)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(pinned ? @"DialogList.Unpin" : @"DialogList.Pin") action:@"pin" type:TGActionSheetActionTypeGeneric]];

    if (!isEncrypted && !isSavedMessages)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(muted ? @"Conversation.Unmute" : @"Conversation.Mute") action:@"mute" type:TGActionSheetActionTypeGeneric]];

    int32_t removeFilterId = 0;
    if ([self canAddPeerIdToDialogFilter:peerId] && !isEncrypted && ![conversation isEncrypted])
    {
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"DialogFilters.AddToFolder") action:@"addToFolder" type:TGActionSheetActionTypeGeneric]];
        NSDictionary *selectedFilter = _ogSelectedDialogFilterId == 0 ? nil : [self og_selectedDialogFilter];
        if (selectedFilter != nil && ![selectedFilter[@"default"] boolValue] && [self og_conversation:conversation matchesDialogFilter:selectedFilter])
        {
            removeFilterId = [selectedFilter[@"id"] intValue];
            [actions addObject:[[TGActionSheetAction alloc] initWithTitle:[NSString stringWithFormat:TGLocalized(@"DialogFilters.RemoveFromFolder"), selectedFilter[@"title"]] action:@"removeFromFolder" type:TGActionSheetActionTypeGeneric]];
        }
    }

    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(archived ? @"DialogList.Unarchive" : @"DialogList.Archive") action:@"archive" type:TGActionSheetActionTypeGeneric]];
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Delete") action:@"delete" type:TGActionSheetActionTypeDestructive]];
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];

    __weak TGDialogListController *weakSelf = self;
    TGCustomActionSheet *sheet = [[TGCustomActionSheet alloc] initWithTitle:nil actions:actions actionBlock:^(__unused id target, NSString *action)
    {
        __strong TGDialogListController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;

        if ([action isEqualToString:@"read"] && strongSelf.toggleReadConversation != nil)
            strongSelf.toggleReadConversation(peerId, !read);
        else if ([action isEqualToString:@"pin"] && strongSelf.togglePinConversation != nil)
            strongSelf.togglePinConversation(peerId, !pinned);
        else if ([action isEqualToString:@"mute"] && strongSelf.toggleMuteConversation != nil)
            strongSelf.toggleMuteConversation(peerId, !muted);
        else if ([action isEqualToString:@"archive"] && strongSelf.archiveToggleHandler != nil)
            strongSelf.archiveToggleHandler(peerId, !archived);
        else if ([action isEqualToString:@"delete"] && strongSelf.deleteConversation != nil)
            strongSelf.deleteConversation(peerId);
        else if ([action isEqualToString:@"addToFolder"])
            [strongSelf og_presentAddToFolderForConversation:conversation fromRect:sourceRect];
        else if ([action isEqualToString:@"removeFromFolder"])
            [strongSelf og_removeConversation:conversation fromDialogFilterId:removeFilterId];
    } target:self];

    if (!TGIsPad())
        [sheet showInView:self.navigationController.view];
    else
        [sheet showFromRect:sourceRect inView:self.view animated:true];
}

- (void)og_chatActionsLongPress:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan || ![self og_newChatListGesturesEnabled] || _isDisplayingSearch)
        return;

    CGPoint point = [recognizer locationInView:_tableView];
    NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:point];
    if (indexPath == nil || indexPath.section != 1)
        return;

    id item = [self og_dialogListItemAtIndexPath:indexPath];
    if (![item isKindOfClass:[TGConversation class]] || [self og_isArchiveHeaderItem:item])
        return;

    UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPath];
    CGRect sourceRect = cell == nil ? CGRectMake(point.x, point.y, 1.0f, 1.0f) : [_tableView convertRect:cell.frame toView:self.view];
    [self og_presentActionsForConversation:(TGConversation *)item fromRect:sourceRect];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == _ogFolderPanGestureRecognizer)
    {
        if (![self og_newChatListGesturesEnabled] || _isDisplayingSearch || _ogArchiveExpanded || _ogDialogFilters.count <= 1 || _ogFolderSwipeActive || _ogFolderSwipeFinishing)
            return NO;

        CGPoint velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self.view];
        CGFloat horizontalVelocity = ABS(velocity.x);
        CGFloat verticalVelocity = ABS(velocity.y);
        if (horizontalVelocity < 15.0f || horizontalVelocity < verticalVelocity * 1.08f)
            return NO;

        NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:[gestureRecognizer locationInView:_tableView]];
        UITableViewCell *cell = indexPath == nil ? nil : [_tableView cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
            if ([dialogCell isEditingControlsTracking] || [dialogCell isEditingControlsExpanded] || (velocity.x > 0.0f && dialogCell.linkedCommunityId != 0 && dialogCell.enableEditing && !dialogCell.isAd && dialogCell.isSavedMessages != 2))
                return NO;
        }

        CGFloat logicalVelocityX = TGIsRTL() ? -velocity.x : velocity.x;
        NSInteger currentIndex = [self og_selectedDialogFilterIndex];
        if (currentIndex == NSNotFound)
            currentIndex = 0;
        NSInteger targetIndex = currentIndex + (logicalVelocityX < 0.0f ? 1 : -1);
        if (targetIndex < 0 || targetIndex >= (NSInteger)_ogDialogFilters.count)
            return NO;
    }

    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if (gestureRecognizer == _ogFolderPanGestureRecognizer)
    {
        if (![self og_newChatListGesturesEnabled] || _isDisplayingSearch || _ogArchiveExpanded || _ogDialogFilters.count <= 1)
            return NO;

        CGPoint point = [touch locationInView:self.view];
        if (_tableView == nil || !CGRectContainsPoint(_tableView.frame, point))
            return NO;
    }

    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == _ogFolderPanGestureRecognizer || otherGestureRecognizer == _ogFolderPanGestureRecognizer)
        return NO;

    return NO;
}

- (bool)og_foldersAllowed
{
    return !_dialogListCompanion.privacyMode &&
        !_dialogListCompanion.showPrivateOnly &&
        !_dialogListCompanion.showGroupsAndChannelsOnly &&
        !_dialogListCompanion.showGroupsOnly &&
        !_dialogListCompanion.botStartMode;
}

- (CGFloat)og_folderTabsHeight
{
    if (![self og_foldersAllowed] || _isDisplayingSearch || _ogArchiveExpanded || _ogDialogFilters.count <= 1)
        return 0.0f;
    return [TGPresentation brandedIOS6Style] ? [TGPresentation brandedIOS6DialogListAppearance].folderTabsHeight : 38.0f;
}

- (int64_t)og_peerIdForInputPeer:(id)peer
{
    if ([peer isKindOfClass:[TLInputPeer$inputPeerSelf class]])
        return TGTelegraphInstance.clientUserId;
    if ([peer isKindOfClass:[TLInputPeer$inputPeerUser class]])
        return ((TLInputPeer$inputPeerUser *)peer).user_id;
    if ([peer isKindOfClass:[TLInputPeer$inputPeerChat class]])
        return TGPeerIdFromGroupId(((TLInputPeer$inputPeerChat *)peer).chat_id);
    if ([peer isKindOfClass:[TLInputPeer$inputPeerChannel class]])
        return TGPeerIdFromChannelId(((TLInputPeer$inputPeerChannel *)peer).channel_id);
    return 0;
}

- (NSSet *)og_peerIdSetForInputPeers:(NSArray *)peers
{
    NSMutableSet *result = [[NSMutableSet alloc] init];
    for (id peer in peers)
    {
        int64_t peerId = [self og_peerIdForInputPeer:peer];
        if (peerId != 0)
            [result addObject:@(peerId)];
    }
    return result;
}

- (NSArray *)og_peerIdArrayForInputPeers:(NSArray *)peers
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (id peer in peers)
    {
        int64_t peerId = [self og_peerIdForInputPeer:peer];
        if (peerId != 0)
            [result addObject:@(peerId)];
    }
    return result;
}

- (void)og_continueDialogListDataHydration
{
    TG_DIALOG_LIST_COST(TGDialogListCostHydration);
    if (_ogDialogSnapshotHydrationInFlight || _ogDialogSnapshotHydrationPending.count == 0)
        return;
    if ([self dialogListShouldCoalesceUIUpdates])
        return;
    if (![_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]])
    {
        [_ogDialogSnapshotHydrationPending removeAllObjects];
        return;
    }

    NSUInteger batchLimit = MIN((NSUInteger)24, TGDialogListHydrationBatchLimit());
    NSArray *keys = _ogDialogSnapshotHydrationPending.allKeys;
    NSUInteger count = MIN(batchLimit, keys.count);
    NSMutableArray *batch = [[NSMutableArray alloc] initWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++)
    {
        NSNumber *key = keys[i];
        NSDictionary *entry = _ogDialogSnapshotHydrationPending[key];
        if (entry != nil)
            [batch addObject:entry];
        [_ogDialogSnapshotHydrationPending removeObjectForKey:key];
    }
    if (batch.count == 0)
        return;

    _ogDialogSnapshotHydrationInFlight = true;
    TGTelegraphDialogListCompanion *dialogListCompanion = (TGTelegraphDialogListCompanion *)_dialogListCompanion;
    TGDialogListControllerReference *reference = _ogLifetimeReference;
    int64_t clientUserId = TGTelegraphInstance.clientUserId;
    OGRuntimeDispatch(OGRuntimePriorityUtility, ^
    {
        TGUser *selfUser = clientUserId == 0 ? nil : [TGDatabaseInstance() loadUser:clientUserId];
        NSMutableArray *hydratedEntries = [[NSMutableArray alloc] initWithCapacity:batch.count];
        for (NSDictionary *entry in batch)
        {
            TGConversation *source = entry[@"source"];
            TGConversation *snapshot = entry[@"snapshot"];
            [dialogListCompanion initializeDialogListData:snapshot customUser:nil selfUser:selfUser];
            if (source != nil && snapshot.dialogListData.count != 0)
                [hydratedEntries addObject:@{@"source": source, @"data": snapshot.dialogListData}];
        }

        OGPlatformDispatchOnMainThread(^
        {
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                controller->_ogDialogSnapshotHydrationInFlight = false;
                if (!controller->_dialogListSelfUserSnapshotResolved && selfUser != nil)
                {
                    controller->_dialogListSelfUserSnapshot = selfUser;
                    controller->_dialogListSelfUserSnapshotResolved = true;
                }

                bool updated = false;
                NSMutableSet *currentSources = [[NSMutableSet alloc] initWithCapacity:controller->_listModel.count + controller->_ogAllDialogItems.count];
                for (id item in controller->_listModel)
                    [currentSources addObject:[NSValue valueWithNonretainedObject:item]];
                for (id item in controller->_ogAllDialogItems)
                    [currentSources addObject:[NSValue valueWithNonretainedObject:item]];
                for (NSDictionary *entry in hydratedEntries)
                {
                    TGConversation *source = entry[@"source"];
                    NSDictionary *data = entry[@"data"];
                    bool sourceIsCurrent = [currentSources containsObject:[NSValue valueWithNonretainedObject:source]];

                    if (sourceIsCurrent && source.dialogListData.count == 0)
                    {
                        source.dialogListData = data;
                        updated = true;
                    }
                }

                if (updated)
                {
                    NSString *avatarFilter = [controller dialogListAvatarFilter];
                    for (NSDictionary *entry in hydratedEntries)
                    {
                        TGConversation *source = entry[@"source"];
                        [controller dialogListPrefetchAvatarUrl:source.dialogListData[@"avatarUrl"] filter:avatarFilter];
                    }
                    controller->_ogVisibleListCache = nil;
                    controller->_ogVisibleListCacheFilterId = INT32_MIN;
                    if ([controller dialogListShouldCoalesceUIUpdates])
                        controller->_dialogListVisibleRefreshPending = true;
                    else
                        [controller dialogListRefreshVisibleCells];
                    [controller og_updateFolderTabs];
                }

                [controller og_continueDialogListDataHydration];
            }];
        });
    });
}

- (void)og_ensureDialogListDataForConversation:(TGConversation *)conversation
{
    if (conversation == nil || conversation.dialogListData.count != 0)
        return;

    NSNumber *peerKey = @(conversation.conversationId);
    NSDictionary *pendingEntry = _ogDialogSnapshotHydrationPending[peerKey];
    if (pendingEntry == nil || pendingEntry[@"source"] != conversation)
        _ogDialogSnapshotHydrationPending[peerKey] = @{@"source": conversation, @"snapshot": [conversation copy]};
    [self og_continueDialogListDataHydration];
}

- (int)dialogListSnapshotUnreadCountForPeerId:(int64_t)peerId
{
    for (id item in _listModel)
    {
        if ([item isKindOfClass:[TGConversation class]] && ((TGConversation *)item).conversationId == peerId)
            return ((TGConversation *)item).unreadCount;
    }
    for (id item in _ogAllDialogItems)
    {
        if ([item isKindOfClass:[TGConversation class]] && ((TGConversation *)item).conversationId == peerId)
            return ((TGConversation *)item).unreadCount;
    }
    return 0;
}

- (void)og_preloadRuntimeStateForConversations:(NSArray *)items
{
    if (items.count == 0)
        return;

    std::set<int64_t> userIds;
    userIds.insert(TGTelegraphInstance.clientUserId);
    NSMutableSet *mutePeerIds = [[NSMutableSet alloc] init];
    NSMutableSet *customPropertyPeerIds = [[NSMutableSet alloc] init];

    for (id item in items)
    {
        if (![item isKindOfClass:[TGConversation class]])
            continue;

        TGConversation *conversation = (TGConversation *)item;
        int64_t peerId = conversation.conversationId;
        [customPropertyPeerIds addObject:@(peerId)];

        if (conversation.fromUid > 0)
            userIds.insert(conversation.fromUid);

        int64_t mutePeerId = peerId;
        if (conversation.isEncrypted)
        {
            if (conversation.chatParticipants.chatParticipantUids.count != 0)
            {
                int64_t uid = [conversation.chatParticipants.chatParticipantUids[0] longLongValue];
                if (uid != 0)
                {
                    userIds.insert(uid);
                    mutePeerId = uid;
                }
            }
        }
        else if (!conversation.isChat && peerId > 0)
        {
            userIds.insert(peerId);
        }

        [mutePeerIds addObject:@(mutePeerId)];
    }

    if (!userIds.empty())
    {
        std::vector<int64_t> userIdVector(userIds.begin(), userIds.end());
        [TGDatabaseInstance() loadUsers:userIdVector];
    }

    std::vector<int64_t> contactUids;
    [TGDatabaseInstance() loadRemoteContactUids:contactUids];
    [TGDatabaseInstance() preloadPeerMuteStates:mutePeerIds.allObjects];
    [TGDatabaseInstance() preloadConversationCustomProperties:customPropertyPeerIds.allObjects];
}

- (bool)og_selectedDialogFilterNeedsHistoryScan
{
    NSDictionary *filter = [self og_selectedDialogFilter];
    if (filter == nil || [filter[@"id"] intValue] == 0)
        return false;
    return ([filter[@"flags"] intValue] & 0x1f) != 0;
}

- (void)og_scheduleFolderLocalSourceContinuation
{
    if (_ogFolderLocalSourceContinuationScheduled || _ogFolderLocalSourceExhausted || _ogAllDialogItemsLoading || _ogSelectedDialogFilterId == 0)
        return;

    _ogFolderLocalSourceContinuationScheduled = true;
    TGDialogListControllerReference *reference = _ogLifetimeReference;
    NSTimeInterval delay = OGPlatformUsesConstrainedBackgroundExecution() ? 0.18 : 0.06;
    OGPlatformDispatchOnMainThreadAfter(delay, ^
    {
        [reference withValue:^(void *value)
        {
            TGDialogListController *controller = (__bridge TGDialogListController *)value;
            controller->_ogFolderLocalSourceContinuationScheduled = false;
            if (controller->_dialogListFastScrolling)
            {
                [controller og_scheduleFolderLocalSourceContinuation];
                return;
            }
            NSDictionary *filter = [controller og_selectedDialogFilter];
            if (filter == nil || [filter[@"id"] intValue] == 0)
                return;
            if (!controller->_ogFolderLocalSourceExhausted)
                [controller og_refreshAllDialogItems:false];
        }];
    });
}

- (void)og_refreshAllDialogItems:(bool)force
{
    if (![self og_foldersAllowed] || _ogAllDialogItemsLoading)
        return;

    if (_ogSelectedDialogFilterId == 0)
        return;
    if (![self og_selectedDialogFilterNeedsHistoryScan])
    {
        _ogFolderLocalSourceExhausted = true;
        return;
    }

    bool mainCacheReady = [TGDatabaseInstance() customProperty:@"dialogListLoaded"].length != 0;
    bool archiveCacheReady = [TGDatabaseInstance() customProperty:@"ios6ArchivePeerIdsComplete"].length == 1;
    bool canonicalCacheReady = mainCacheReady && archiveCacheReady;
    if (!canonicalCacheReady)
    {
        _ogFolderCanonicalCacheReady = false;
        _ogFolderLocalSourceExhausted = true;
        _ogFolderLocalSourceContinuationScheduled = false;
        return;
    }

    if (!_ogFolderCanonicalCacheReady)
    {
        _ogFolderCanonicalCacheReady = true;
        _ogFolderLocalSourceGeneration++;
        _ogFolderLocalSourceCursorDate = INT32_MAX;
        _ogFolderLocalSourceExhausted = false;
        _ogFolderLocalSourceContinuationScheduled = false;
    }

    if (force)
    {
        _ogFolderLocalSourceGeneration++;
        _ogFolderLocalSourceCursorDate = INT32_MAX;
        _ogFolderLocalSourceExhausted = false;
        _ogFolderLocalSourceContinuationScheduled = false;
    }

    if (cpuCoreCount() == 1 && !_isOnScreen && self.navigationController != nil && self.navigationController.topViewController != self)
        return;

    if (!force && _ogFolderLocalSourceExhausted)
    {
        return;
    }

    if (_dialogListFastScrolling)
    {
        [self og_scheduleFolderLocalSourceContinuation];
        return;
    }

    NSMutableArray *excludePeerIds = [[NSMutableArray alloc] init];
    NSMutableSet *seenPeerIds = [[NSMutableSet alloc] init];
    for (id item in _listModel)
    {
        if (![item isKindOfClass:[TGConversation class]])
            continue;
        NSNumber *peerId = @(((TGConversation *)item).conversationId);
        if (![seenPeerIds containsObject:peerId])
        {
            [seenPeerIds addObject:peerId];
            [excludePeerIds addObject:peerId];
        }
    }
    for (id item in _ogAllDialogItems)
    {
        if (![item isKindOfClass:[TGConversation class]])
            continue;
        NSNumber *peerId = @(((TGConversation *)item).conversationId);
        if (![seenPeerIds containsObject:peerId])
        {
            [seenPeerIds addObject:peerId];
            [excludePeerIds addObject:peerId];
        }
    }

    int pageLimit = OGPlatformUsesConstrainedBackgroundExecution() ? 32 : 128;
    int32_t requestDate = _ogFolderLocalSourceCursorDate;
    int32_t generation = _ogFolderLocalSourceGeneration;
    _ogAllDialogItemsLoading = true;
    _ogAllDialogItemsLastRefreshTime = CFAbsoluteTimeGetCurrent();

    TGDialogListControllerReference *reference = _ogLifetimeReference;
    TGTelegraphDialogListCompanion *dialogListCompanion = [_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]] ? (TGTelegraphDialogListCompanion *)_dialogListCompanion : nil;
    [TGDatabaseInstance() loadConversationListFromDate:requestDate limit:pageLimit excludeConversationIds:excludePeerIds folderId:-1 completion:^(NSArray *result, bool loadedAllRegular)
    {
        NSArray *page = [result isKindOfClass:[NSArray class]] ? result : @[];
        if (dialogListCompanion != nil && page.count != 0)
        {
            [self og_preloadRuntimeStateForConversations:page];
            TGUser *selfUser = [TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId];
            for (TGConversation *conversation in page)
            {
                if ([conversation isKindOfClass:[TGConversation class]] && conversation.dialogListData.count == 0)
                    [dialogListCompanion initializeDialogListData:conversation customUser:nil selfUser:selfUser];
            }
        }

        int32_t oldestRegularDate = INT32_MAX;
        for (TGConversation *conversation in page)
        {
            if (![conversation isKindOfClass:[TGConversation class]] || conversation.pinnedDate != 0)
                continue;
            if (conversation.date < oldestRegularDate)
                oldestRegularDate = conversation.date;
        }

        int32_t nextCursor = requestDate;
        if (oldestRegularDate != INT32_MAX)
            nextCursor = oldestRegularDate >= INT32_MAX - 1 ? INT32_MAX : oldestRegularDate + 1;
        bool exhausted = page.count == 0 || (loadedAllRegular && page.count < (NSUInteger)pageLimit);

        OGPlatformDispatchOnMainThread(^
        {
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                if (generation != controller->_ogFolderLocalSourceGeneration)
                    return;

                controller->_ogAllDialogItemsLoading = false;
                if (nextCursor < controller->_ogFolderLocalSourceCursorDate || controller->_ogFolderLocalSourceCursorDate == INT32_MAX)
                    controller->_ogFolderLocalSourceCursorDate = nextCursor;
                controller->_ogFolderLocalSourceExhausted = exhausted;

                NSMutableDictionary *existingIndexByPeerId = [[NSMutableDictionary alloc] init];
                NSMutableArray *allItems = [[NSMutableArray alloc] initWithArray:controller->_ogAllDialogItems == nil ? @[] : controller->_ogAllDialogItems];
                for (NSUInteger i = 0; i < allItems.count; i++)
                {
                    id item = allItems[i];
                    if ([item isKindOfClass:[TGConversation class]])
                        existingIndexByPeerId[@(((TGConversation *)item).conversationId)] = @(i);
                }

                int addedCount = 0;
                for (TGConversation *conversation in page)
                {
                    if (![conversation isKindOfClass:[TGConversation class]] || conversation.isDeleted || conversation.isDeactivated || conversation.leftChat || conversation.kickedFromChat)
                        continue;
                    NSNumber *peerId = @(conversation.conversationId);
                    NSNumber *indexValue = existingIndexByPeerId[peerId];
                    if (indexValue != nil)
                    {
                        [allItems replaceObjectAtIndex:[indexValue unsignedIntegerValue] withObject:conversation];
                    }
                    else
                    {
                        existingIndexByPeerId[peerId] = @(allItems.count);
                        [allItems addObject:conversation];
                        addedCount++;
                    }
                }
                controller->_ogAllDialogItems = allItems;
                controller->_ogVisibleListCache = nil;
                controller->_ogVisibleListCacheFilterId = INT32_MIN;


                if (page.count != 0)
                {
                    [controller reloadData:false];
                    [controller og_updateFolderTabs];
                }

                NSUInteger visibleCount = [controller og_visibleListModel].count;
                if (!controller->_ogFolderLocalSourceExhausted)
                {
                    [controller og_scheduleFolderLocalSourceContinuation];
                }
                else if (controller->_ogFolderLocalSourceExhausted && visibleCount < 8 && controller->_canLoadMore && !controller->_isLoading)
                {
                    [controller og_scheduleLazyLoadMoreItems:20];
                }
                [controller og_updateFolderEmptyLabel];
            }];
        });
    }];
}

- (NSArray *)og_folderSourceItems
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSMutableSet *seen = [[NSMutableSet alloc] init];
    for (id item in _listModel)
    {
        if (![item isKindOfClass:[TGConversation class]])
            continue;
        TGConversation *conversation = (TGConversation *)item;
        if (conversation.isDeleted || conversation.isDeactivated || conversation.leftChat || conversation.kickedFromChat)
            continue;
        NSNumber *key = @(conversation.conversationId);
        if (![seen containsObject:key])
        {
            [seen addObject:key];
            [result addObject:conversation];
        }
    }
    for (id item in _ogAllDialogItems)
    {
        if (![item isKindOfClass:[TGConversation class]])
            continue;
        TGConversation *conversation = (TGConversation *)item;
        if (conversation.isDeleted || conversation.isDeactivated || conversation.leftChat || conversation.kickedFromChat)
            continue;
        NSNumber *key = @(conversation.conversationId);
        if (![seen containsObject:key])
        {
            [seen addObject:key];
            [result addObject:conversation];
        }
    }
    [result sortUsingComparator:^NSComparisonResult(TGConversation *lhs, TGConversation *rhs)
    {
        if (TGPeerIdIsAd(lhs.conversationId))
            return TGPeerIdIsAd(rhs.conversationId) ? NSOrderedSame : NSOrderedAscending;
        if (TGPeerIdIsAd(rhs.conversationId))
            return NSOrderedDescending;
        if (lhs.pinnedDate != 0 || rhs.pinnedDate != 0)
        {
            if (lhs.pinnedDate == 0)
                return NSOrderedDescending;
            if (rhs.pinnedDate == 0)
                return NSOrderedAscending;
            if (lhs.pinnedDate > rhs.pinnedDate)
                return NSOrderedAscending;
            if (lhs.pinnedDate < rhs.pinnedDate)
                return NSOrderedDescending;
        }
        if (lhs.date > rhs.date)
            return NSOrderedAscending;
        if (lhs.date < rhs.date)
            return NSOrderedDescending;
        if (lhs.conversationId > rhs.conversationId)
            return NSOrderedAscending;
        if (lhs.conversationId < rhs.conversationId)
            return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return result;
}

- (NSDictionary *)og_storedInputPeer:(TLInputPeer *)peer
{
    if ([peer isKindOfClass:[TLInputPeer$inputPeerSelf class]])
        return @{ @"type": @"self" };
    if ([peer isKindOfClass:[TLInputPeer$inputPeerUser class]])
    {
        TLInputPeer$inputPeerUser *user = (TLInputPeer$inputPeerUser *)peer;
        return @{ @"type": @"user", @"id": @(user.user_id), @"accessHash": @(user.access_hash) };
    }
    if ([peer isKindOfClass:[TLInputPeer$inputPeerChat class]])
        return @{ @"type": @"chat", @"id": @(((TLInputPeer$inputPeerChat *)peer).chat_id) };
    if ([peer isKindOfClass:[TLInputPeer$inputPeerChannel class]])
    {
        TLInputPeer$inputPeerChannel *channel = (TLInputPeer$inputPeerChannel *)peer;
        return @{ @"type": @"channel", @"id": @(channel.channel_id), @"accessHash": @(channel.access_hash) };
    }
    return nil;
}

- (TLInputPeer *)og_inputPeerFromStoredValue:(NSDictionary *)value
{
    if (![value isKindOfClass:[NSDictionary class]])
        return nil;
    NSString *type = value[@"type"];
    if (![type isKindOfClass:[NSString class]])
        return nil;
    if ([type isEqualToString:@"self"])
        return [[TLInputPeer$inputPeerSelf alloc] init];
    if (![value[@"id"] isKindOfClass:[NSNumber class]])
        return nil;
    if ([type isEqualToString:@"chat"])
    {
        TLInputPeer$inputPeerChat *peer = [[TLInputPeer$inputPeerChat alloc] init];
        peer.chat_id = [value[@"id"] longLongValue];
        return peer;
    }
    if (![value[@"accessHash"] isKindOfClass:[NSNumber class]])
        return nil;
    if ([type isEqualToString:@"user"])
    {
        TLInputPeer$inputPeerUser *peer = [[TLInputPeer$inputPeerUser alloc] init];
        peer.user_id = [value[@"id"] longLongValue];
        peer.access_hash = [value[@"accessHash"] longLongValue];
        return peer;
    }
    if ([type isEqualToString:@"channel"])
    {
        TLInputPeer$inputPeerChannel *peer = [[TLInputPeer$inputPeerChannel alloc] init];
        peer.channel_id = [value[@"id"] longLongValue];
        peer.access_hash = [value[@"accessHash"] longLongValue];
        return peer;
    }
    return nil;
}

- (void)og_setDialogFilters:(NSArray *)filters
{
    _ogSourceDialogFilters = filters ?: @[];
    _ogFolderTagFilters = nil;
    NSArray *displayed = _ogSourceDialogFilters;
    if ([TGOnegramSettings boolForKey:TGOnegramSettingChatListHideAllChatsTab])
    {
        NSMutableArray *folders = [[NSMutableArray alloc] init];
        for (NSDictionary *filter in _ogSourceDialogFilters)
        {
            if (![filter[@"default"] boolValue])
                [folders addObject:filter];
        }
        if (folders.count >= 2)
            displayed = folders;
    }
    _ogDialogFilters = displayed;
    bool selectedExists = false;
    for (NSDictionary *filter in _ogDialogFilters)
        selectedExists = selectedExists || [filter[@"id"] intValue] == _ogSelectedDialogFilterId;
    if (!selectedExists && _ogDialogFilters.count != 0)
    {
        _ogSelectedDialogFilterId = [_ogDialogFilters[0][@"id"] intValue];
        [self og_storeSelectedDialogFilterId];
    }
    _ogVisibleListCache = nil;
    _ogVisibleListCacheFilterId = INT32_MIN;
}

- (void)og_storeDialogFilters
{
    int64_t accountId = TGTelegraphInstance.clientUserId;
    if (accountId == 0 || accountId != _ogDialogFiltersAccountId)
        return;
    NSMutableArray *filters = [[NSMutableArray alloc] init];
    for (NSDictionary *filter in _ogSourceDialogFilters)
    {
        NSMutableDictionary *stored = [filter mutableCopy];
        for (NSString *key in @[@"pinned", @"include", @"exclude"])
            stored[key] = [filter[key] allObjects];
        NSMutableArray *peers = [[NSMutableArray alloc] init];
        for (TLInputPeer *peer in [filter[@"inputPeers"] allValues])
        {
            NSDictionary *value = [self og_storedInputPeer:peer];
            if (value != nil)
                [peers addObject:value];
        }
        stored[@"inputPeers"] = peers;
        [filters addObject:stored];
    }
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:@{ @"version": @1, @"accountId": @(accountId), @"filters": filters } format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
    if (data != nil)
        [TGDatabaseInstance() setCustomProperty:[NSString stringWithFormat:@"ios6DialogFilters.%lld", accountId] value:data];
}

- (void)dialogListPresentationUpdated
{
    TG_DIALOG_LIST_COST(TGDialogListCostPresentation);
    if (self != TGAppDelegateInstance.rootController.dialogListController)
        return;
    if (!OGRuntimeFirstFrameCompleted() && (_listModel.count != 0 || !_canLoadMore))
    {
        OGPlatformDispatchAfterCurrentMainRunLoop(^
        {
            OGRuntimeCompleteFirstFrame();
        });
    }
    OGStartupDiagnosticsDialogsPresented(_listModel.count, !_canLoadMore);
}

- (void)og_restoreDialogFilters
{
    int64_t accountId = TGTelegraphInstance.clientUserId;
    if (accountId == 0 || accountId == _ogDialogFiltersAccountId || ![self og_foldersAllowed])
        return;
    _ogDialogFiltersAccountId = accountId;
    [self og_setDialogFilters:[self og_normalizeDialogFilters:@[]]];
    _ogVisibleListCache = nil;
    _ogVisibleListCacheFilterId = INT32_MIN;
    NSUInteger generation = ++_ogDialogFiltersRestoreGeneration;
    TGDialogListControllerReference *reference = _ogLifetimeReference;
    [TGDatabaseInstance() customProperty:[NSString stringWithFormat:@"ios6DialogFilters.%lld", accountId] completion:^(NSData *data)
    {
        OGPlatformDispatchOnMainThread(^
        {
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                if (controller->_ogDialogFiltersRestoreGeneration == generation && controller->_ogDialogFiltersAccountId == accountId)
                    [controller og_applyStoredDialogFilters:data accountId:accountId];
            }];
        });
    }];
}

- (void)og_applyStoredDialogFilters:(NSData *)data accountId:(int64_t)accountId
{
    id stored = data.length == 0 ? nil : [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
    if ([stored isKindOfClass:[NSDictionary class]] && [stored[@"version"] isKindOfClass:[NSNumber class]] && [stored[@"version"] intValue] == 1 && [stored[@"accountId"] isKindOfClass:[NSNumber class]] && [stored[@"accountId"] intValue] == accountId && [stored[@"filters"] isKindOfClass:[NSArray class]])
    {
        NSMutableArray *filters = [[NSMutableArray alloc] init];
        bool valid = true;
        for (id value in stored[@"filters"])
        {
            if (![value isKindOfClass:[NSDictionary class]]) { valid = false; break; }
            NSMutableDictionary *filter = [value mutableCopy];
            for (NSString *key in @[@"id", @"flags", @"default", @"chatlist"])
                valid = valid && [filter[key] isKindOfClass:[NSNumber class]];
            valid = valid && [filter[@"title"] isKindOfClass:[NSString class]];
            for (NSString *key in @[@"pinned", @"pinnedOrder", @"include", @"exclude"])
            {
                if (![filter[key] isKindOfClass:[NSArray class]]) { valid = false; break; }
                for (id peerId in filter[key])
                    valid = valid && [peerId isKindOfClass:[NSNumber class]];
            }
            valid = valid && [filter[@"inputPeers"] isKindOfClass:[NSArray class]];
            if (!valid)
                break;
            for (NSString *key in @[@"pinned", @"include", @"exclude"])
                filter[key] = [NSSet setWithArray:filter[key]];
            NSMutableDictionary *peers = [[NSMutableDictionary alloc] init];
            for (id peerValue in filter[@"inputPeers"])
            {
                TLInputPeer *peer = [self og_inputPeerFromStoredValue:peerValue];
                int64_t peerId = [self og_peerIdForInputPeer:peer];
                if (peerId == 0) { valid = false; break; }
                peers[@(peerId)] = peer;
            }
            if (!valid)
                break;
            filter[@"inputPeers"] = peers;
            [filters addObject:filter];
        }
        if (valid && filters.count != 0)
            [self og_setDialogFilters:filters];
    }
    _ogVisibleListCache = nil;
    _ogVisibleListCacheFilterId = INT32_MIN;
    bool selectedExists = false;
    for (NSDictionary *filter in _ogDialogFilters)
        selectedExists = selectedExists || [filter[@"id"] intValue] == _ogSelectedDialogFilterId;
    if (!selectedExists)
    {
        _ogSelectedDialogFilterId = 0;
        [self og_storeSelectedDialogFilterId];
    }
    if (self.isViewLoaded)
    {
        [self og_updateFolderTabs];
        [self og_layoutFolderTabs];
        [self reloadData:false];
    }
}

- (NSArray *)og_normalizeDialogFilters:(NSArray *)filters
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    bool hasDefault = false;
    for (id filter in filters)
    {
        bool defaultFilter = false;
        bool chatlist = false;
        int32_t filterId = 0;
        int32_t flags = 0;
        NSString *title = nil;
        NSArray *pinnedPeers = nil;
        NSArray *includePeers = nil;
        NSArray *excludePeers = nil;
        int32_t color = TGDialogFilterNoColor;
        NSString *emoticon = nil;
        @try
        {
            defaultFilter = [[filter valueForKey:@"defaultFilter"] boolValue];
            chatlist = [[filter valueForKey:@"chatlist"] boolValue];
            filterId = [[filter valueForKey:@"filterId"] intValue];
            flags = [[filter valueForKey:@"flags"] intValue];
            title = [filter valueForKey:@"title"];
            pinnedPeers = [filter valueForKey:@"pinnedPeers"];
            includePeers = [filter valueForKey:@"includePeers"];
            excludePeers = [filter valueForKey:@"excludePeers"];
            color = [[filter valueForKey:@"color"] intValue];
            emoticon = [filter valueForKey:@"emoticon"];
        }
        @catch (__unused NSException *exception)
        {
            continue;
        }

        if (defaultFilter)
        {
            hasDefault = true;
            filterId = 0;
            title = TGLocalized(@"DialogList.Title");
        }
        if (![title isKindOfClass:[NSString class]] || title.length == 0)
            title = filterId == 0 ? TGLocalized(@"DialogList.Title") : @"Папка";

        NSArray *normalizedPinnedPeers = [pinnedPeers isKindOfClass:[NSArray class]] ? pinnedPeers : @[];
        NSArray *normalizedIncludePeers = [includePeers isKindOfClass:[NSArray class]] ? includePeers : @[];
        NSMutableDictionary *inputPeersById = [[NSMutableDictionary alloc] init];
        for (TLInputPeer *inputPeer in normalizedPinnedPeers)
        {
            int64_t peerId = [self og_peerIdForInputPeer:inputPeer];
            if (peerId != 0)
                inputPeersById[@(peerId)] = inputPeer;
        }
        for (TLInputPeer *inputPeer in normalizedIncludePeers)
        {
            int64_t peerId = [self og_peerIdForInputPeer:inputPeer];
            if (peerId != 0)
                inputPeersById[@(peerId)] = inputPeer;
        }

        NSDictionary *normalized = @{
            @"id": @(filterId),
            @"flags": @(flags),
            @"title": title,
            @"default": @(defaultFilter),
            @"chatlist": @(chatlist),
            @"pinned": [self og_peerIdSetForInputPeers:normalizedPinnedPeers],
            @"pinnedOrder": [self og_peerIdArrayForInputPeers:normalizedPinnedPeers],
            @"include": [self og_peerIdSetForInputPeers:normalizedIncludePeers],
            @"exclude": [self og_peerIdSetForInputPeers:[excludePeers isKindOfClass:[NSArray class]] ? excludePeers : @[]],
            @"inputPeers": inputPeersById,
            @"color": @(defaultFilter ? TGDialogFilterNoColor : [TGDialogFilterSignals effectiveColorForFilterId:filterId serverColor:color]),
            @"emoticon": [emoticon isKindOfClass:[NSString class]] ? emoticon : @""
        };
        [result addObject:normalized];
    }

    if (!hasDefault)
    {
        NSDictionary *defaultFilter = @{
            @"id": @0,
            @"flags": @0,
            @"title": TGLocalized(@"DialogList.Title"),
            @"default": @(YES),
            @"chatlist": @(NO),
            @"pinned": [NSSet set],
            @"pinnedOrder": @[],
            @"include": [NSSet set],
            @"exclude": [NSSet set],
            @"inputPeers": @{}
        };
        [result insertObject:defaultFilter atIndex:0];
    }
    return result;
}

- (void)og_scheduleFolderPeerHydrationReconciliation
{
    if (_ogFolderPeerHydrationReconcileScheduled || _ogDialogFilters.count == 0 || ![self og_foldersAllowed])
        return;
    if (TGTelegraphInstance.clientUserId == 0 || !TGTelegraphInstance.clientIsActivated)
        return;

    _ogFolderPeerHydrationReconcileScheduled = true;
    TGDialogListControllerReference *reference = _ogLifetimeReference;
    OGPlatformDispatchOnMainThreadAfter(0.35, ^
    {
        [reference withValue:^(void *value)
        {
            TGDialogListController *controller = (__bridge TGDialogListController *)value;
            controller->_ogFolderPeerHydrationReconcileScheduled = false;
            if (controller->_dialogListFastScrolling)
            {
                [controller og_scheduleFolderPeerHydrationReconciliation];
                return;
            }
            [controller og_hydrateExplicitFolderPeers];
        }];
    });
}

- (void)og_mergeFolderPeerIdsFromDatabase:(NSArray *)peerIds completion:(void (^)(void))completion
{
    if (peerIds.count == 0)
    {
        if (completion != nil)
            completion();
        return;
    }

    TGDialogListControllerReference *reference = _ogLifetimeReference;
    TGTelegraphDialogListCompanion *dialogListCompanion = [_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]] ? (TGTelegraphDialogListCompanion *)_dialogListCompanion : nil;
    int64_t clientUserId = TGTelegraphInstance.clientUserId;
    [TGDatabaseInstance() loadDialogListConversationsWithPeerIds:peerIds selfUserId:clientUserId completion:^(NSArray *conversations)
    {
        OGRuntimeDispatch(OGRuntimePriorityUtility, ^
        {
            NSMutableArray *loaded = [[NSMutableArray alloc] init];
            for (TGConversation *conversation in conversations)
            {
                if (conversation.isDeleted || conversation.isDeactivated || conversation.leftChat || conversation.kickedFromChat)
                    continue;
                [loaded addObject:conversation];
            }

            if (dialogListCompanion != nil && loaded.count != 0)
            {
                TGUser *selfUser = clientUserId == 0 ? nil : [TGDatabaseInstance() loadUser:clientUserId];
                for (TGConversation *conversation in loaded)
                {
                    if (conversation.dialogListData.count == 0)
                        [dialogListCompanion initializeDialogListData:conversation customUser:nil selfUser:selfUser];
                }
            }

            OGPlatformDispatchOnMainThread(^
            {
                [reference withValue:^(void *value)
                {
                    TGDialogListController *controller = (__bridge TGDialogListController *)value;
                    bool changed = false;
                    bool coalescing = [controller dialogListShouldCoalesceUIUpdates];
                    if (coalescing)
                    {
                        [controller dialogListEnsureCoalescedModel];
                        [controller dialogListEnsureCoalescedAllDialogItems];
                    }
                    NSMutableArray *listModel = coalescing ? controller->_dialogListCoalescedModel : controller->_listModel;
                    NSArray *sourceAllItems = coalescing ? controller->_dialogListCoalescedAllDialogItems : controller->_ogAllDialogItems;
                    NSMutableDictionary *allIndexByPeerId = [[NSMutableDictionary alloc] init];
                    NSMutableArray *allItems = [[NSMutableArray alloc] initWithArray:sourceAllItems ?: @[]];
                    for (NSUInteger i = 0; i < allItems.count; i++)
                    {
                        id item = allItems[i];
                        if ([item isKindOfClass:[TGConversation class]])
                            allIndexByPeerId[@(((TGConversation *)item).conversationId)] = @(i);
                    }

                    NSMutableDictionary *listIndices = TGDialogListItemIndices(listModel);
                    for (TGConversation *conversation in loaded)
                    {
                        NSNumber *peerId = @(conversation.conversationId);
                        NSNumber *listIndex = listIndices[peerId];
                        bool replacedInList = listIndex != nil;
                        if (replacedInList)
                        {
                            [listModel replaceObjectAtIndex:listIndex.unsignedIntegerValue withObject:conversation];
                            changed = true;
                        }

                        NSNumber *indexValue = allIndexByPeerId[peerId];
                        if (indexValue != nil)
                        {
                            [allItems replaceObjectAtIndex:[indexValue unsignedIntegerValue] withObject:conversation];
                            changed = true;
                        }
                        else if (!replacedInList)
                        {
                            allIndexByPeerId[peerId] = @(allItems.count);
                            [allItems addObject:conversation];
                            changed = true;
                        }
                    }

                    if (changed)
                    {
                        if (coalescing)
                        {
                            controller->_dialogListCoalescedAllDialogItems = allItems;
                            controller->_dialogListCoalescedReloadPending = true;
                            controller->_dialogListVisibleRefreshPending = true;
                        }
                        else
                        {
                            controller->_ogAllDialogItems = allItems;
                            controller->_ogVisibleListCache = nil;
                            controller->_ogVisibleListCacheFilterId = INT32_MIN;
                            [controller reloadData:false];
                            [controller og_updateFolderTabs];
                            [controller og_updateFolderEmptyLabel];
                        }
                    }

                    if (completion != nil)
                        completion();
                }];
            });
        });
    }];
}

- (void)og_continueFolderPeerHydration
{
    if (!_ogFolderPeerHydrationActive)
        return;

    if (_ogFolderPeerHydrationQueue.count == 0)
    {
        _ogFolderPeerHydrationActive = false;
        TGDialogListControllerReference *reference = _ogLifetimeReference;
        OGPlatformDispatchOnMainThreadAfter(0.35, ^
        {
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                [controller og_refreshAllDialogItems:false];
            }];
        });
        return;
    }

    NSUInteger batchLimit = MAX((NSUInteger)1, _ogFolderPeerHydrationBatchSize);
    NSUInteger batchCount = MIN(batchLimit, _ogFolderPeerHydrationQueue.count);
    NSArray *batch = [_ogFolderPeerHydrationQueue subarrayWithRange:NSMakeRange(0, batchCount)];
    [_ogFolderPeerHydrationQueue removeObjectsInRange:NSMakeRange(0, batchCount)];
    NSMutableArray *batchPeerIds = [[NSMutableArray alloc] initWithCapacity:batch.count];
    for (TLInputPeer *inputPeer in batch)
    {
        int64_t peerId = [self og_peerIdForInputPeer:inputPeer];
        if (peerId != 0)
            [batchPeerIds addObject:@(peerId)];
    }

    NSMutableArray *inputDialogPeers = [[NSMutableArray alloc] initWithCapacity:batch.count];
    for (TLInputPeer *inputPeer in batch)
    {
        TLInputDialogPeer$inputDialogPeer *inputDialogPeer = [[TLInputDialogPeer$inputDialogPeer alloc] init];
        inputDialogPeer.peer = inputPeer;
        [inputDialogPeers addObject:inputDialogPeer];
    }

    TLRPCmessages_getPeerDialogs$messages_getPeerDialogs *request = [[TLRPCmessages_getPeerDialogs$messages_getPeerDialogs alloc] init];
    request.peers = inputDialogPeers;

    TGTelegraphDialogListCompanion *companion = [_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]] ? (TGTelegraphDialogListCompanion *)_dialogListCompanion : nil;
    [companion ios6MarkFolderOnlyHydrationPeerIds:batchPeerIds];

    TGDialogListControllerReference *reference = _ogLifetimeReference;
    __block NSArray *resolvedBatchPeerIds = @[];
    SSignal *signal = [[[TGTelegramNetworking readyInstance] mapToSignal:^SSignal *(TGTelegramNetworking *networking)
    {
        return [networking requestSignal:request];
    }] mapToSignal:^SSignal *(TLmessages_PeerDialogs *result)
    {
        NSMutableArray *resolved = [[NSMutableArray alloc] init];
        for (TLDialog *baseDialog in result.dialogs)
        {
            if (![baseDialog isKindOfClass:[TLDialog$dialogMeta class]])
                continue;
            TLDialog$dialogMeta *dialog = (TLDialog$dialogMeta *)baseDialog;
            if (dialog.top_message == 0)
                continue;
            if ([dialog.peer isKindOfClass:[TLPeer$peerUser class]])
                [resolved addObject:@(((TLPeer$peerUser *)dialog.peer).user_id)];
            else if ([dialog.peer isKindOfClass:[TLPeer$peerChat class]])
                [resolved addObject:@(TGPeerIdFromGroupId((int32_t)((TLPeer$peerChat *)dialog.peer).chat_id))];
            else if ([dialog.peer isKindOfClass:[TLPeer$peerChannel class]])
                [resolved addObject:@(TGPeerIdFromChannelId((int32_t)((TLPeer$peerChannel *)dialog.peer).channel_id))];
        }
        return [[TGGroupManagementSignals processedDialogs:result peerId:0] then:[SSignal single:resolved]];
    }];

    [_ogFolderPeerHydrationDisposable setDisposable:[[signal startOn:[SQueue wrapConcurrentNativeQueue:[ActionStageInstance() globalStageDispatchQueue]]] startWithNext:^(NSArray *peerIds)
    {
        if ([peerIds isKindOfClass:[NSArray class]])
            resolvedBatchPeerIds = [peerIds copy];
    } error:^(id error)
    {
        OGPlatformDispatchOnMainThread(^{
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                NSString *errorType = [[TGTelegramNetworking instance] extractNetworkErrorType:error];
                NSTimeInterval retryDelay = 0.15;
                if (batch.count > 1)
                {
                    controller->_ogFolderPeerHydrationBatchSize = MAX((NSUInteger)1, batch.count / 2);
                    for (NSInteger i = (NSInteger)batch.count - 1; i >= 0; i--)
                        [controller->_ogFolderPeerHydrationQueue insertObject:batch[(NSUInteger)i] atIndex:0];
                }
                else if (batch.count == 1)
                {
                    TLInputPeer *inputPeer = batch[0];
                    int64_t peerId = [controller og_peerIdForInputPeer:inputPeer];
                    NSNumber *peerKey = @(peerId);
                    int retryCount = [controller->_ogFolderPeerHydrationRetryCounts[peerKey] intValue] + 1;
                    controller->_ogFolderPeerHydrationRetryCounts[peerKey] = @(retryCount);
                    bool transient = [errorType hasPrefix:@"FLOOD_WAIT_"] || [errorType hasPrefix:@"INTERNAL"] || [errorType hasPrefix:@"TIMEOUT"] || [errorType hasPrefix:@"NETWORK"];
                    if (transient && retryCount < 3)
                    {
                        [controller->_ogFolderPeerHydrationQueue addObject:inputPeer];
                        retryDelay = [errorType hasPrefix:@"FLOOD_WAIT_"] ? 2.0 : 0.75;
                    }
                    else
                    {
                        controller->_ogFolderPeerHydrationFailed++;
                    }
                }
                NSLog(@"FOLDERS hydrate error batch=%d type=%@", (int)batch.count, errorType);
                OGPlatformDispatchOnMainThreadAfter(retryDelay, ^
                {
                    [reference withValue:^(void *delayedValue)
                    {
                        TGDialogListController *delayedController = (__bridge TGDialogListController *)delayedValue;
                        [delayedController og_continueFolderPeerHydration];
                    }];
                });
            }];
        });
    } completed:^
    {
        OGPlatformDispatchOnMainThread(^
        {
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                [controller og_mergeFolderPeerIdsFromDatabase:resolvedBatchPeerIds completion:^
                {
                    controller->_ogFolderPeerHydrationLoaded += (int)batch.count;
                    NSUInteger maximumBatchSize = TGDialogListHydrationBatchLimit();
                    if (controller->_ogFolderPeerHydrationBatchSize < maximumBatchSize)
                        controller->_ogFolderPeerHydrationBatchSize = MIN(maximumBatchSize, controller->_ogFolderPeerHydrationBatchSize + 2);
                    OGPlatformDispatchOnMainThread(^
                    {
                        [reference withValue:^(void *delayedValue)
                        {
                            TGDialogListController *delayedController = (__bridge TGDialogListController *)delayedValue;
                            [delayedController og_continueFolderPeerHydration];
                        }];
                    });
                }];
            }];
        });
    }]];
}

- (void)og_hydrateExplicitFolderPeers
{
    if (_ogFolderPeerHydrationActive || _ogFolderPeerLocalLookupInFlight)
        return;

    NSMutableDictionary *inputPeersById = [[NSMutableDictionary alloc] init];
    for (NSDictionary *filter in _ogDialogFilters)
    {
        NSDictionary *filterPeers = filter[@"inputPeers"];
        if ([filterPeers isKindOfClass:[NSDictionary class]])
            [inputPeersById addEntriesFromDictionary:filterPeers];
    }
    if (inputPeersById.count == 0)
        return;

    NSArray *sourceItems = [self og_folderSourceItems];
    NSMutableDictionary *sourceByPeerId = [[NSMutableDictionary alloc] init];
    for (id item in sourceItems)
    {
        if ([item isKindOfClass:[TGConversation class]])
            sourceByPeerId[@(((TGConversation *)item).conversationId)] = item;
    }

    NSMutableArray *localLookupPeerIds = [[NSMutableArray alloc] init];
    for (NSNumber *peerId in inputPeersById)
    {
        if (sourceByPeerId[peerId] == nil && ![_ogFolderPeerLocalLookupAttempted containsObject:peerId])
        {
            [_ogFolderPeerLocalLookupAttempted addObject:peerId];
            [localLookupPeerIds addObject:peerId];
        }
    }

    if (localLookupPeerIds.count != 0)
    {
        _ogFolderPeerLocalLookupInFlight = true;
        TGDialogListControllerReference *reference = _ogLifetimeReference;
        [self og_mergeFolderPeerIdsFromDatabase:localLookupPeerIds completion:^
        {
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                controller->_ogFolderPeerLocalLookupInFlight = false;
                [controller og_hydrateExplicitFolderPeers];
            }];
        }];
        return;
    }

    sourceItems = [self og_folderSourceItems];
    [sourceByPeerId removeAllObjects];
    for (id item in sourceItems)
    {
        if ([item isKindOfClass:[TGConversation class]])
            sourceByPeerId[@(((TGConversation *)item).conversationId)] = item;
    }

    NSMutableDictionary *missingPeersById = [[NSMutableDictionary alloc] init];
    [inputPeersById enumerateKeysAndObjectsUsingBlock:^(NSNumber *peerKey, TLInputPeer *inputPeer, __unused BOOL *stop)
    {
        TGConversation *conversation = sourceByPeerId[peerKey];
        bool incomplete = conversation == nil || conversation.dialogListData.count == 0 || [conversation.dialogListData[@"title"] length] == 0;
        if (conversation != nil && TGPeerIdIsChannel(conversation.conversationId) && conversation.accessHash == 0)
            incomplete = true;
        if (incomplete && inputPeer != nil && ![inputPeer isKindOfClass:[TLInputPeer$inputPeerEmpty class]])
            missingPeersById[peerKey] = inputPeer;
    }];

    if (missingPeersById.count == 0)
        return;

    [_ogFolderPeerHydrationQueue removeAllObjects];
    [_ogFolderPeerHydrationQueue addObjectsFromArray:missingPeersById.allValues];
    [_ogFolderPeerHydrationRetryCounts removeAllObjects];
    _ogFolderPeerHydrationBatchSize = TGDialogListHydrationBatchLimit();
    _ogFolderPeerHydrationLoaded = 0;
    _ogFolderPeerHydrationFailed = 0;
    _ogFolderPeerHydrationActive = true;
    [self og_continueFolderPeerHydration];
}

- (NSDictionary *)og_selectedDialogFilter
{
    for (NSDictionary *filter in _ogDialogFilters)
    {
        if ([filter[@"id"] intValue] == _ogSelectedDialogFilterId)
            return filter;
    }
    return nil;
}

- (bool)og_conversationIsUnread:(TGConversation *)conversation
{
    return conversation.unreadMark || conversation.unreadCount > 0 || conversation.serviceUnreadCount > 0;
}

- (bool)og_conversation:(TGConversation *)conversation matchesDialogFilter:(NSDictionary *)filter
{
    if (conversation == nil || filter == nil)
        return false;

    int64_t peerId = conversation.conversationId;
    NSNumber *peerKey = @(peerId);
    NSSet *exclude = filter[@"exclude"];
    NSSet *include = filter[@"include"];
    NSSet *pinned = filter[@"pinned"];

    if ([exclude containsObject:peerKey])
        return false;
    if ([include containsObject:peerKey] || [pinned containsObject:peerKey])
        return true;

    if (peerId == TGTelegraphInstance.clientUserId)
        return false;

    int32_t flags = [filter[@"flags"] intValue];
    NSDictionary *snapshot = conversation.dialogListData;
    bool matchesType = false;
    if (TGPeerIdIsChannel(peerId) || conversation.isChannel)
    {
        bool isChannelGroup = conversation.isChannelGroup;
        matchesType = isChannelGroup ? ((flags & (1 << 2)) != 0) : ((flags & (1 << 3)) != 0);
    }
    else if (TGPeerIdIsGroup(peerId))
    {
        matchesType = (flags & (1 << 2)) != 0;
    }
    else if (TGPeerIdIsUser(peerId))
    {
        if (snapshot.count == 0)
            return false;
        bool isBot = [snapshot[@"isBot"] boolValue];
        if (isBot)
            matchesType = (flags & (1 << 4)) != 0;
        else
        {
            bool isContact = [snapshot[@"isContact"] boolValue];
            matchesType = isContact ? ((flags & (1 << 0)) != 0) : ((flags & (1 << 1)) != 0);
        }
    }
    else if ([conversation isEncrypted])
    {
        if (snapshot.count == 0)
            return false;
        bool isContact = [snapshot[@"isContact"] boolValue];
        matchesType = isContact ? ((flags & (1 << 0)) != 0) : ((flags & (1 << 1)) != 0);
    }
    else if (conversation.isBroadcast)
    {
        matchesType = (flags & (1 << 3)) != 0;
    }

    if (!matchesType)
        return false;
    if (flags & (1 << 11))
    {
        NSNumber *mute = snapshot[@"mute"];
        if (mute == nil || [mute boolValue])
            return false;
    }
    if ((flags & (1 << 12)) && ![self og_conversationIsUnread:conversation])
        return false;
    if ((flags & (1 << 13)) && conversation.isArchived)
        return false;
    return true;
}

- (NSArray *)og_visibleItemsForDialogFilter:(NSDictionary *)filter
{
    if (filter == nil || [filter[@"id"] intValue] == 0)
    {
        NSArray *sourceItems = _listModel;
        NSMutableArray *regularRows = [[NSMutableArray alloc] init];
        NSMutableArray *archivedRows = [[NSMutableArray alloc] init];
        for (id item in sourceItems)
        {
            if ([self og_isArchivedConversation:item])
                [archivedRows addObject:item];
            else
                [regularRows addObject:item];
        }
        return _ogArchiveExpanded ? archivedRows : regularRows;
    }

    NSArray *sourceItems = [self og_folderSourceItems];
    NSMutableDictionary *itemsByPeerId = [[NSMutableDictionary alloc] init];
    NSMutableArray *matchingItems = [[NSMutableArray alloc] init];
    for (id item in sourceItems)
    {
        if (![item isKindOfClass:[TGConversation class]])
            continue;
        TGConversation *conversation = (TGConversation *)item;
        [self og_ensureDialogListDataForConversation:conversation];
        if ([self og_conversation:conversation matchesDialogFilter:filter])
        {
            [matchingItems addObject:conversation];
            itemsByPeerId[@(conversation.conversationId)] = conversation;
        }
    }

    [matchingItems sortUsingComparator:^NSComparisonResult(TGConversation *lhs, TGConversation *rhs)
    {
        if (lhs.date > rhs.date)
            return NSOrderedAscending;
        if (lhs.date < rhs.date)
            return NSOrderedDescending;
        if (lhs.conversationId > rhs.conversationId)
            return NSOrderedAscending;
        if (lhs.conversationId < rhs.conversationId)
            return NSOrderedDescending;
        return NSOrderedSame;
    }];

    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSMutableSet *added = [[NSMutableSet alloc] init];
    for (NSNumber *peerId in filter[@"pinnedOrder"])
    {
        id item = itemsByPeerId[peerId];
        if (item != nil)
        {
            [result addObject:item];
            [added addObject:peerId];
        }
    }
    for (TGConversation *conversation in matchingItems)
    {
        NSNumber *peerId = @(conversation.conversationId);
        if (![added containsObject:peerId])
            [result addObject:conversation];
    }
    return result;
}

- (int)og_unreadCountForDialogFilter:(NSDictionary *)filter sourceItems:(NSArray *)sourceItems
{
    int count = 0;
    if ([filter[@"id"] intValue] == 0)
    {
        for (id item in sourceItems)
        {
            if (![item isKindOfClass:[TGConversation class]])
                continue;
            TGConversation *conversation = (TGConversation *)item;
            if (![self og_conversationIsUnread:conversation] || [self og_isArchivedConversation:item])
                continue;
            [self og_ensureDialogListDataForConversation:conversation];
            NSNumber *mute = conversation.dialogListData[@"mute"];
            if (mute != nil && ![mute boolValue])
                count++;
        }
        return count;
    }
    for (id item in sourceItems)
    {
        if (![item isKindOfClass:[TGConversation class]])
            continue;
        TGConversation *conversation = (TGConversation *)item;
        if (![self og_conversationIsUnread:conversation])
            continue;
        [self og_ensureDialogListDataForConversation:conversation];
        NSNumber *mute = conversation.dialogListData[@"mute"];
        if (mute == nil || [mute boolValue])
            continue;
        if ([self og_conversation:conversation matchesDialogFilter:filter])
            count++;
    }
    return count;
}

- (int)og_unreadCountForDialogFilter:(NSDictionary *)filter
{
    return [self og_unreadCountForDialogFilter:filter sourceItems:[self og_folderSourceItems]];
}

- (void)og_synchronizeDialogStateForce:(bool)force
{
    if (![self og_foldersAllowed] || TGTelegraphInstance.clientUserId == 0 || !TGTelegraphInstance.clientIsActivated)
        return;
    if (OGPlatformUsesConstrainedBackgroundExecution() && [TGTelegramNetworking maybeInstance] == nil)
        return;

    if (force)
    {
        _ogDialogFiltersLastRefreshTime = 0.0;
        _ogAllDialogItemsLastRefreshTime = 0.0;
    }

    [self og_reloadDialogFilters:force];
    [self og_refreshAllDialogItems:force];
    [self og_hydrateExplicitFolderPeers];
    if ([_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]])
        [(TGTelegraphDialogListCompanion *)_dialogListCompanion ios6PreloadAllDialogsForFolders];
}

- (void)ios6SynchronizeDialogState
{
    [self og_synchronizeDialogStateForce:false];
}

- (void)og_authorizationReady:(NSNotification *)__unused notification
{
    if (_ogDialogFiltersAccountId != TGTelegraphInstance.clientUserId)
    {
        [_ogDialogFiltersDisposable setDisposable:nil];
        _ogDialogFiltersRequestInFlight = false;
        _ogDialogFiltersLastRefreshTime = 0.0;
    }
    _ogDialogFiltersAuthorizationRetryCount = 0;
    _ogDialogFiltersAuthorizationRetryScheduled = false;
    _ogDialogFiltersNetworkRetryCount = 0;
    _ogDialogFiltersNetworkRetryScheduled = false;
    [self og_restoreDialogFilters];
    [self refreshOwnUserIfStale];
    [self loadCachedOwnEmojiStatus];
    [self og_synchronizeDialogStateForce:false];
}

- (void)og_reloadDialogFilters:(bool)force
{
    if (![self og_foldersAllowed])
        return;
    if (TGTelegraphInstance.clientUserId == 0 || !TGTelegraphInstance.clientIsActivated)
    {
        return;
    }
    _ogDialogFiltersAuthorizationRetryCount = 0;
    _ogDialogFiltersAuthorizationRetryScheduled = false;

    if (cpuCoreCount() == 1 && !_isOnScreen && self.navigationController != nil && self.navigationController.topViewController != self)
        return;

    TGTelegramNetworking *networking = OGPlatformUsesConstrainedBackgroundExecution() ? [TGTelegramNetworking maybeInstance] : [TGTelegramNetworking instance];
    if (networking == nil)
        return;
    if (_ogDialogFiltersRequestInFlight)
        return;

    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    NSTimeInterval minimumInterval = force ? 5.0 : 60.0;
    if (_ogDialogFiltersLastRefreshTime > 0.0 && now - _ogDialogFiltersLastRefreshTime < minimumInterval)
        return;
    _ogDialogFiltersLastRefreshTime = now;
    _ogDialogFiltersRequestInFlight = true;

    int64_t accountId = TGTelegraphInstance.clientUserId;
    OGCompatGetDialogFiltersRequest *request = [[OGCompatGetDialogFiltersRequest alloc] init];
    TGDialogListControllerReference *reference = _ogLifetimeReference;
    [_ogDialogFiltersDisposable setDisposable:[[[networking requestSignal:request] mapToSignal:^SSignal *(id response)
    {
        id filters = response;
        if (![filters isKindOfClass:[NSArray class]])
        {
            @try { filters = [response valueForKey:@"filters"]; } @catch (__unused NSException *exception) { filters = nil; }
        }
        if (![filters isKindOfClass:[NSArray class]])
            return [SSignal fail:@"INVALID_DIALOG_FILTERS_RESPONSE"];
        for (id filter in filters)
        {
            if (![filter respondsToSelector:@selector(filterId)] || ![filter respondsToSelector:@selector(defaultFilter)] || ![filter respondsToSelector:@selector(flags)])
                return [SSignal fail:@"INVALID_DIALOG_FILTERS_RESPONSE"];
        }
        if (filters != response && [response respondsToSelector:@selector(flags)])
            [TGDialogFilterSignals storeServerTagsEnabled:([[response valueForKey:@"flags"] intValue] & 1) != 0];
        return [SSignal single:filters];
    }] startWithNext:^(NSArray *filters)
    {
        OGPlatformDispatchOnMainThread(^{
            [reference withValue:^(void *value)
            {
                __strong TGDialogListController *strongSelf = (__bridge TGDialogListController *)value;

                if (accountId != TGTelegraphInstance.clientUserId)
                    return;
                strongSelf->_ogDialogFiltersNetworkRetryCount = 0;
                strongSelf->_ogDialogFiltersNetworkRetryScheduled = false;
                [strongSelf og_applyDialogFilters:filters accountId:accountId];
            }];
        });
    } error:^(id error)
    {
        OGPlatformDispatchOnMainThread(^{
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                if (accountId != TGTelegraphInstance.clientUserId)
                    return;
                controller->_ogDialogFiltersRequestInFlight = false;
                NSString *errorType = [error isKindOfClass:[NSString class]] ? error : [networking extractNetworkErrorType:error];
                controller->_ogDialogFiltersLastRefreshTime = 0.0;
                NSLog(@"FOLDERS error type=%@", errorType);
                if (!controller->_ogDialogFiltersNetworkRetryScheduled && TGTelegraphInstance.clientUserId != 0 && TGTelegraphInstance.clientIsActivated)
                {
                    controller->_ogDialogFiltersNetworkRetryScheduled = true;
                    int retryCount = MIN(controller->_ogDialogFiltersNetworkRetryCount, 5);
                    controller->_ogDialogFiltersNetworkRetryCount++;
                    NSTimeInterval delay = MIN(8.0, 0.5 * (1 << retryCount));
                    TGDialogListControllerReference *retryReference = controller->_ogLifetimeReference;
                    OGPlatformDispatchOnMainThreadAfter(delay, ^
                    {
                        [retryReference withValue:^(void *retryValue)
                        {
                            TGDialogListController *retryController = (__bridge TGDialogListController *)retryValue;
                            retryController->_ogDialogFiltersNetworkRetryScheduled = false;
                            [retryController og_reloadDialogFilters:true];
                        }];
                    });
                }
            }];
        });
    } completed:^
    {
        OGPlatformDispatchOnMainThread(^
        {
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                if (accountId == TGTelegraphInstance.clientUserId)
                    controller->_ogDialogFiltersRequestInFlight = false;
            }];
        });
    }]];
}

- (void)og_applyDialogFilters:(NSArray *)filters accountId:(int64_t)accountId
{
    _ogDialogFiltersRestoreGeneration++;
    _ogDialogFiltersAccountId = accountId;
    [self og_setDialogFilters:[self og_normalizeDialogFilters:filters]];
    [self og_storeDialogFilters];
    _ogVisibleListCache = nil;
    _ogVisibleListCacheFilterId = INT32_MIN;
    bool selectedExists = false;
    for (NSDictionary *filter in _ogDialogFilters)
    {
        if ([filter[@"id"] intValue] == _ogSelectedDialogFilterId)
        {
            selectedExists = true;
            break;
        }
    }
    if (!selectedExists)
    {
        _ogSelectedDialogFilterId = 0;
        [self og_storeSelectedDialogFilterId];
    }

    [self og_updateFolderTabs];
    [self og_layoutFolderTabs];
    [self reloadData:false];
    [self og_refreshAllDialogItems:true];
    [self og_hydrateExplicitFolderPeers];
    if ([_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]])
        [(TGTelegraphDialogListCompanion *)_dialogListCompanion ios6PreloadAllDialogsForFolders];
}

- (void)og_dialogFiltersUpdated:(NSNotification *)__unused notification
{
    _ogDialogFiltersLastRefreshTime = 0.0;
    [self og_reloadDialogFilters:true];
}

- (void)dialogFiltersDidChange:(NSNotification *)notification
{
    _ogFolderTagFilters = nil;
    if (![self og_foldersAllowed] || TGTelegraphInstance.clientUserId == 0)
        return;
    NSArray *filters = notification.userInfo[@"filters"];
    if ([filters isKindOfClass:[NSArray class]])
    {
        _ogDialogFiltersLastRefreshTime = CFAbsoluteTimeGetCurrent();
        [self og_applyDialogFilters:filters accountId:TGTelegraphInstance.clientUserId];
    }
    else if (self.isViewLoaded)
        [self reloadData:false];
}

- (NSArray *)og_folderTagsForConversation:(TGConversation *)conversation
{
    if (conversation == nil || ![self og_foldersAllowed])
        return nil;
    if (_ogFolderTagFilters == nil)
    {
        NSMutableArray *tagFilters = [[NSMutableArray alloc] init];
        if ([TGDialogFilterSignals tagsVisible])
        {
            for (NSDictionary *filter in _ogSourceDialogFilters)
            {
                int32_t color = [filter[@"color"] intValue];
                NSString *title = filter[@"title"];
                if ([filter[@"default"] boolValue] || filter[@"color"] == nil || color < 0 || title.length == 0)
                    continue;
                UIColor *tagColor = [TGDialogFilter colorForIndex:color];
                if (tagColor != nil)
                    [tagFilters addObject:@{@"filter": filter, @"tag": @{@"title": title, @"color": tagColor}}];
            }
        }
        _ogFolderTagFilters = tagFilters;
    }
    if (_ogFolderTagFilters.count == 0)
        return nil;
    NSMutableArray *tags = nil;
    for (NSDictionary *entry in _ogFolderTagFilters)
    {
        NSDictionary *filter = entry[@"filter"];
        if ([filter[@"id"] intValue] == _ogSelectedDialogFilterId)
            continue;
        if (![self og_conversation:conversation matchesDialogFilter:filter])
            continue;
        if (tags == nil)
            tags = [[NSMutableArray alloc] init];
        [tags addObject:entry[@"tag"]];
    }
    return tags;
}

- (NSArray *)dialogFilterConversations
{
    return [self og_folderSourceItems];
}

- (bool)dialogFilter:(TGDialogFilter *)filter matchesConversation:(TGConversation *)conversation
{
    if (filter == nil || conversation == nil)
        return false;
    if (filter.defaultFilter)
        return !conversation.isArchived;
    NSDictionary *normalized = [[self og_normalizeDialogFilters:@[filter]] lastObject];
    return [self og_conversation:conversation matchesDialogFilter:normalized];
}

- (void)og_loadDialogFilters:(void (^)(TGDialogFiltersState *state))completion
{
    void (^block)(TGDialogFiltersState *) = [completion copy];
    [_ogDialogFilterActionDisposable setDisposable:[[TGDialogFiltersController signalWithProgress:[TGDialogFilterSignals filters]] startWithNext:^(TGDialogFiltersState *state)
    {
        if (block)
            block(state);
    } error:^(id error)
    {
        [TGDialogFiltersController presentError:error];
    } completed:nil]];
}

- (void)og_saveDialogFilter:(TGDialogFilter *)filter
{
    [_ogDialogFilterActionDisposable setDisposable:[[TGDialogFiltersController signalWithProgress:[TGDialogFilterSignals saveFilter:filter]] startWithNext:nil error:^(id error)
    {
        [TGDialogFiltersController presentError:error];
    } completed:nil]];
}

- (TGDialogFilter *)og_dialogFilterWithId:(int32_t)filterId inState:(TGDialogFiltersState *)state
{
    for (TGDialogFilter *filter in state.filters)
    {
        if (filter.filterId == filterId && !filter.defaultFilter)
            return filter;
    }
    return nil;
}

- (NSArray *)og_conversationsForDialogFilter:(NSDictionary *)filter
{
    bool isDefault = [filter[@"default"] boolValue] || [filter[@"id"] intValue] == 0;
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (TGConversation *conversation in [self og_folderSourceItems])
    {
        if (conversation.isAd || [conversation.dialogListData[@"isSavedMessages"] intValue] == 2)
            continue;
        if (isDefault ? [self og_isArchivedConversation:conversation] : ![self og_conversation:conversation matchesDialogFilter:filter])
            continue;
        [result addObject:conversation];
    }
    return result;
}

- (void)og_markConversationsAsRead:(NSArray *)conversations
{
    NSMutableArray *requests = [[NSMutableArray alloc] init];
    for (TGConversation *conversation in conversations)
    {
        [requests addObject:[[TGReadPeerMessagesRequest alloc] initWithPeerId:conversation.conversationId maxMessageIndex:nil date:0 length:0 unread:false]];
        if (conversation.unreadMentionCount > 0)
            [[TGDownloadMessagesSignal clearUnseenMentions:conversation.conversationId] startWithNext:nil];
    }
    if (requests.count != 0)
        [TGDatabaseInstance() transactionReadHistoryForPeerIds:requests];
}

- (void)og_setConversations:(NSArray *)conversations muted:(bool)muted
{
    static int actionId = 0;
    for (TGConversation *conversation in conversations)
    {
        if ([conversation.dialogListData[@"mute"] boolValue] == muted)
            continue;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%" PRId64 ")/(dialogFilterMute%d)", conversation.conversationId, actionId++] options:@{@"peerId": @(conversation.conversationId), @"accessHash": @(conversation.accessHash), @"muteUntil": @(muted ? INT32_MAX : 0)} watcher:TGTelegraphInstance];
    }
}

- (void)og_folderTabLongPress:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan || _isDisplayingSearch || _ogFolderSwipeActive || _ogFolderSwipeFinishing)
        return;
    NSInteger index = recognizer.view.tag - 6100;
    if (index < 0 || index >= (NSInteger)_ogDialogFilters.count)
        return;
    NSDictionary *filter = _ogDialogFilters[index];
    int32_t filterId = [filter[@"id"] intValue];
    bool isDefault = [filter[@"default"] boolValue] || filterId == 0;
    CGRect sourceRect = [recognizer.view convertRect:recognizer.view.bounds toView:self.view];

    NSArray *conversations = [self og_conversationsForDialogFilter:filter];
    NSMutableArray *unreadConversations = [[NSMutableArray alloc] init];
    NSMutableArray *mutableConversations = [[NSMutableArray alloc] init];
    bool allMuted = true;
    for (TGConversation *conversation in conversations)
    {
        if ([self og_conversationIsUnread:conversation])
            [unreadConversations addObject:conversation];
        [self og_ensureDialogListDataForConversation:conversation];
        NSDictionary *dialogListData = conversation.dialogListData;
        if ([dialogListData[@"isSavedMessages"] intValue] != 0 || [dialogListData[@"isEncrypted"] boolValue] || conversation.isEncrypted)
            continue;
        [mutableConversations addObject:conversation];
        if (![dialogListData[@"mute"] boolValue])
            allMuted = false;
    }
    bool hasUserFolders = false;
    for (NSDictionary *item in _ogSourceDialogFilters)
        hasUserFolders = hasUserFolders || ![item[@"default"] boolValue];

    NSMutableArray *actions = [[NSMutableArray alloc] init];
    if (hasUserFolders)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"DialogFilters.Reorder") action:@"reorder" type:TGActionSheetActionTypeGeneric]];
    if (!isDefault)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"DialogFilters.ConfigureFolder") action:@"edit" type:TGActionSheetActionTypeGeneric]];
    else
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"DialogFilters.EditFolders") action:@"editFolders" type:TGActionSheetActionTypeGeneric]];
    if (!isDefault && mutableConversations.count != 0)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(allMuted ? @"DialogFilters.UnmuteAll" : @"DialogFilters.MuteAll") action:@"mute" type:TGActionSheetActionTypeGeneric]];
    if (unreadConversations.count != 0)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"DialogFilters.ReadAll") action:@"read" type:TGActionSheetActionTypeGeneric]];
    if (!isDefault)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"DialogFilters.DeleteFolder") action:@"delete" type:TGActionSheetActionTypeDestructive]];
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];

    __weak TGDialogListController *weakSelf = self;
    [TGDialogFiltersController presentActionSheetWithTitle:isDefault ? nil : filter[@"title"] actions:actions controller:self sourceRect:sourceRect actionBlock:^(NSString *action)
    {
        __strong TGDialogListController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        if ([action isEqualToString:@"reorder"] || [action isEqualToString:@"editFolders"])
        {
            TGDialogFiltersController *controller = [[TGDialogFiltersController alloc] init];
            controller.startsReordering = [action isEqualToString:@"reorder"];
            [strongSelf.navigationController pushViewController:controller animated:true];
            return;
        }
        if ([action isEqualToString:@"read"])
        {
            [strongSelf og_markConversationsAsRead:unreadConversations];
            return;
        }
        if ([action isEqualToString:@"mute"])
        {
            [strongSelf og_setConversations:mutableConversations muted:!allMuted];
            return;
        }
        if (![action isEqualToString:@"edit"] && ![action isEqualToString:@"delete"])
            return;
        [strongSelf og_loadDialogFilters:^(TGDialogFiltersState *state)
        {
            __strong TGDialogListController *listController = weakSelf;
            if (listController == nil)
                return;
            TGDialogFilter *dialogFilter = [listController og_dialogFilterWithId:filterId inState:state];
            if (dialogFilter == nil)
                return;
            if ([action isEqualToString:@"delete"])
            {
                [TGDialogFiltersController deleteFilter:dialogFilter controller:listController completion:nil];
                return;
            }
            [listController.navigationController pushViewController:[[TGDialogFilterEditController alloc] initWithFilter:dialogFilter allFilters:state.filters] animated:true];
        }];
    }];
}

- (bool)canAddPeerIdToDialogFilter:(int64_t)peerId
{
    return peerId != 0 && !TGPeerIdIsSecretChat(peerId) && !TGPeerIdIsAd(peerId) && !TGPeerIdIsFeed(peerId) && [self og_foldersAllowed] && !_dialogListCompanion.forwardMode && !_dialogListCompanion.feedChannels && TGTelegraphInstance.clientUserId != 0;
}

- (void)presentAddToDialogFilterForPeerId:(int64_t)peerId
{
    if (![self canAddPeerIdToDialogFilter:peerId])
        return;
    TGConversation *conversation = nil;
    for (TGConversation *item in [self og_folderSourceItems])
    {
        if (item.conversationId == peerId)
        {
            conversation = item;
            break;
        }
    }
    if (conversation == nil)
        conversation = [TGDatabaseInstance() loadConversationWithId:peerId];
    if (conversation == nil || conversation.isEncrypted)
        return;
    [self og_presentAddToFolderForConversation:conversation fromRect:CGRectZero];
}

- (void)og_presentAddToFolderForConversation:(TGConversation *)conversation fromRect:(CGRect)sourceRect
{
    int64_t peerId = conversation.conversationId;
    __weak TGDialogListController *weakSelf = self;
    [self og_loadDialogFilters:^(TGDialogFiltersState *state)
    {
        __strong TGDialogListController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        NSMutableArray *candidates = [[NSMutableArray alloc] init];
        NSUInteger userFolders = 0;
        for (TGDialogFilter *filter in state.filters)
        {
            if (filter.defaultFilter)
                continue;
            userFolders++;
            if (![strongSelf dialogFilter:filter matchesConversation:conversation])
                [candidates addObject:filter];
        }
        NSMutableArray *actions = [[NSMutableArray alloc] init];
        for (TGDialogFilter *filter in candidates)
            [actions addObject:[[TGActionSheetAction alloc] initWithTitle:filter.title action:[NSString stringWithFormat:@"%d", (int)filter.filterId] type:TGActionSheetActionTypeGeneric]];
        if (userFolders < [TGDialogFilterSignals folderLimit])
            [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"DialogFilters.NewFolder") action:@"new" type:TGActionSheetActionTypeGeneric]];
        if (actions.count == 0)
        {
            [TGDialogFiltersController presentError:@"DIALOG_FILTERS_TOO_MUCH"];
            return;
        }
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];
        [TGDialogFiltersController presentActionSheetWithTitle:TGLocalized(@"DialogFilters.AddToFolder") actions:actions controller:strongSelf sourceRect:sourceRect actionBlock:^(NSString *action)
        {
            __strong TGDialogListController *listController = weakSelf;
            if (listController == nil || [action isEqualToString:@"cancel"])
                return;
            if ([action isEqualToString:@"new"])
            {
                TGDialogFilterEditController *controller = [[TGDialogFilterEditController alloc] initWithFilter:nil allFilters:state.filters];
                controller.initialIncludedPeerIds = @[@(peerId)];
                [listController.navigationController pushViewController:controller animated:true];
                return;
            }
            TGDialogFilter *filter = [[listController og_dialogFilterWithId:(int32_t)[action intValue] inState:state] copy];
            if (filter == nil)
                return;
            [filter removeExcludedPeerId:peerId];
            if (![listController dialogFilter:filter matchesConversation:conversation])
            {
                if ([filter includedPeerIds].count >= [TGDialogFilterSignals chatsPerFolderLimit])
                {
                    [TGDialogFiltersController presentError:@"FILTER_INCLUDE_TOO_MUCH"];
                    return;
                }
                [filter addIncludedPeerId:peerId];
            }
            [listController og_saveDialogFilter:filter];
        }];
    }];
}

- (void)og_removeConversation:(TGConversation *)conversation fromDialogFilterId:(int32_t)filterId
{
    int64_t peerId = conversation.conversationId;
    __weak TGDialogListController *weakSelf = self;
    [self og_loadDialogFilters:^(TGDialogFiltersState *state)
    {
        __strong TGDialogListController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        TGDialogFilter *filter = [[strongSelf og_dialogFilterWithId:filterId inState:state] copy];
        if (filter == nil)
            return;
        [filter removeIncludedPeerId:peerId];
        if ([strongSelf dialogFilter:filter matchesConversation:conversation])
        {
            if (filter.chatlist)
            {
                [TGDialogFiltersController presentError:@"CHATLIST_EXCLUDE_INVALID"];
                return;
            }
            if (filter.excludePeerIds.count >= [TGDialogFilterSignals chatsPerFolderLimit])
            {
                [TGDialogFiltersController presentError:@"FILTER_EXCLUDE_TOO_MUCH"];
                return;
            }
            [filter addExcludedPeerId:peerId];
        }
        if ((filter.flags & TGDialogFilterIncludeCategoriesMask) == 0 && [filter includedPeerIds].count == 0)
        {
            [TGDialogFiltersController presentError:@"FILTER_INCLUDE_EMPTY"];
            return;
        }
        [strongSelf og_saveDialogFilter:filter];
    }];
}

- (void)og_folderTabPressed:(UIButton *)button
{
    NSInteger index = button.tag - 6100;
    [self og_selectDialogFilterAtIndex:index];
}

- (void)og_updateFolderTabs
{
    TG_DIALOG_LIST_COST(TGDialogListCostFolderTabs);
    if (_ogFolderTabsScrollView == nil)
        return;
    if (_ogFolderSwipeActive || _ogFolderSwipeFinishing || (cpuCoreCount() == 1 && _tableView != nil && (_tableView.dragging || _tableView.tracking || _tableView.decelerating)))
    {
        _ogFolderTabsUpdatePending = true;
        return;
    }
    _ogFolderTabsUpdatePending = false;

    bool brandedStyle = [TGPresentation brandedIOS6Style];
    bool classicStyle = [TGPresentation classicThemeStyle];
    bool classicDarkStyle = OGCompatDialogListClassicDarkStyle(self.presentation);
    OGDialogListAppearance *brandedAppearance = brandedStyle ? [TGPresentation brandedIOS6DialogListAppearance] : nil;
    _ogFolderTabsView.backgroundColor = [self og_folderTabsBackgroundColor];
    _ogFolderTabsScrollView.backgroundColor = [UIColor clearColor];
    _ogFolderTabsSeparatorView.backgroundColor = brandedStyle ? brandedAppearance.folderTabsSeparatorColor : (classicStyle ? (classicDarkStyle ? self.presentation.pallete.barSeparatorColor : UIColorRGB(0xc8c8c8)) : self.presentation.pallete.separatorColor);
    _ogFolderEmptyLabel.textColor = brandedStyle ? brandedAppearance.folderEmptyColor : (classicStyle ? (classicDarkStyle ? self.presentation.pallete.secondaryTextColor : UIColorRGB(0x8e8e93)) : self.presentation.pallete.secondaryTextColor);

    NSArray *folderSourceItems = brandedStyle ? nil : [self og_folderSourceItems];
    NSMutableArray *unreadCounts = brandedStyle ? nil : [[NSMutableArray alloc] initWithCapacity:_ogDialogFilters.count];
    NSMutableString *stateKey = [[NSMutableString alloc] initWithFormat:@"%d|%d|%d|%d|%.0f|%p", brandedStyle ? 1 : 0, classicStyle ? 1 : 0, classicDarkStyle ? 1 : 0, _ogSelectedDialogFilterId, self.view.bounds.size.width, brandedAppearance];
    for (NSDictionary *filter in _ogDialogFilters)
    {
        if (brandedStyle)
            [stateKey appendFormat:@"|%d:%@", [filter[@"id"] intValue], filter[@"title"]];
        else
        {
            int unread = [self og_unreadCountForDialogFilter:filter sourceItems:folderSourceItems];
            [unreadCounts addObject:@(unread)];
            [stateKey appendFormat:@"|%d:%d:%@", [filter[@"id"] intValue], unread, filter[@"title"]];
        }
    }

    if ([_ogFolderTabsStateKey isEqualToString:stateKey])
    {
        [self og_updateFolderEmptyLabel];
        return;
    }
    _ogFolderTabsStateKey = [stateKey copy];

    for (UIView *view in [_ogFolderTabsScrollView.subviews copy])
        [view removeFromSuperview];

    UIFont *font = brandedStyle ? brandedAppearance.folderButtonFont : TGBoldSystemFontOfSize(13.0f);
    CGFloat brandedInset = brandedAppearance.folderTabsInset;
    CGFloat brandedTrailingInset = brandedAppearance.folderTabsTrailingInset;
    CGFloat brandedSpacing = brandedAppearance.folderTabsSpacing;
    CGFloat brandedContentHeight = MAX(0.0f, brandedAppearance.folderTabsHeight - 1.0f);
    if (brandedStyle && _ogDialogFilters.count > 1)
    {
        CGFloat totalWidth = 0.0f;
        for (NSDictionary *filter in _ogDialogFilters)
            totalWidth += TGDialogListBrandedFolderButtonWidth(brandedAppearance, filter[@"title"]);
        CGFloat availableSpacing = self.view.bounds.size.width - brandedInset - brandedTrailingInset - totalWidth;
        if (availableSpacing >= 0.0f)
            brandedSpacing = availableSpacing / (_ogDialogFilters.count - 1);
    }
    CGFloat x = brandedStyle ? brandedInset : 8.0f;
    NSInteger index = 0;
    UIButton *selectedButton = nil;
    for (NSDictionary *filter in _ogDialogFilters)
    {
        NSString *title = filter[@"title"];
        int unread = brandedStyle ? 0 : [unreadCounts[index] intValue];
        NSString *badgeText = unread > 999 ? @"999+" : (unread > 0 ? [NSString stringWithFormat:@"%d", unread] : nil);
        CGSize titleSize = [title sizeWithFont:font];
        CGFloat badgeWidth = brandedStyle || badgeText.length == 0 ? 0.0f : MAX(18.0f, [badgeText sizeWithFont:TGBoldSystemFontOfSize(11.0f)].width + 10.0f);
        bool selected = [filter[@"id"] intValue] == _ogSelectedDialogFilterId;
        CGFloat width = brandedStyle ? TGDialogListBrandedFolderButtonWidth(brandedAppearance, title) : MAX(64.0f, titleSize.width + 24.0f + (badgeWidth > 0.0f ? badgeWidth + 5.0f : 0.0f));
        CGFloat brandedButtonHeight = brandedAppearance.folderButtonHeight;
        CGFloat brandedButtonY = brandedAppearance.folderButtonTopInset;

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = 6100 + index;
        button.frame = brandedStyle ? CGRectMake(x, brandedButtonY, width, brandedButtonHeight) : CGRectMake(x, 0.0f, width, 37.0f);
        button.titleLabel.font = font;
        [button setTitle:title forState:UIControlStateNormal];
        if (brandedStyle)
        {
            UIImage *normalImage = [TGPresentation brandedIOS6DialogFolderButtonImageForWidth:width highlighted:false selected:selected];
            UIImage *highlightedImage = [TGPresentation brandedIOS6DialogFolderButtonImageForWidth:width highlighted:true selected:selected];
            CGFloat imageOutset = normalImage != nil ? MAX(0.0f, normalImage.size.height - brandedButtonHeight) : 0.0f;
            CGRect buttonFrame = button.frame;
            buttonFrame.size.height += imageOutset;
            button.frame = buttonFrame;
            [button setBackgroundImage:normalImage forState:UIControlStateNormal];
            [button setBackgroundImage:highlightedImage forState:UIControlStateHighlighted];
            [button setTitleColor:brandedAppearance.folderButtonTitleColor forState:UIControlStateNormal];
            [button setTitleColor:brandedAppearance.folderButtonHighlightedTitleColor forState:UIControlStateHighlighted];
            [button setTitleShadowColor:brandedAppearance.folderButtonShadowColor forState:UIControlStateNormal];
            [button setTitleShadowColor:brandedAppearance.folderButtonHighlightedShadowColor forState:UIControlStateHighlighted];
            button.titleLabel.shadowOffset = brandedAppearance.folderButtonShadowOffset;
            button.contentEdgeInsets = UIEdgeInsetsMake(0.0f, brandedAppearance.folderButtonHorizontalPadding, brandedAppearance.folderButtonTitleBottomInset + imageOutset, brandedAppearance.folderButtonHorizontalPadding);
        }
        else
        {
            UIColor *accent = classicStyle ? UIColorRGB(0x2b78c5) : self.presentation.pallete.accentColor;
            UIColor *normalTitleColor = classicStyle ? (classicDarkStyle ? self.presentation.pallete.secondaryTextColor : UIColorRGB(0x555d66)) : self.presentation.pallete.textColor;
            [button setTitleColor:selected ? accent : normalTitleColor forState:UIControlStateNormal];
            [button setTitleColor:[accent colorWithAlphaComponent:0.55f] forState:UIControlStateHighlighted];
            if (badgeWidth > 0.0f)
            {
                button.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, badgeWidth + 5.0f);
                UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(width - badgeWidth - 8.0f, 9.0f, badgeWidth, 18.0f)];
                badge.backgroundColor = selected ? accent : (classicStyle ? (classicDarkStyle ? self.presentation.pallete.dialogBadgeMutedColor : UIColorRGB(0xa7afb7)) : self.presentation.pallete.secondaryTextColor);
                badge.textColor = selected && !classicStyle ? self.presentation.pallete.accentContrastColor : [UIColor whiteColor];
                badge.textAlignment = NSTextAlignmentCenter;
                badge.font = TGBoldSystemFontOfSize(11.0f);
                badge.text = badgeText;
                badge.layer.cornerRadius = 9.0f;
                badge.clipsToBounds = true;
                badge.userInteractionEnabled = false;
                [button addSubview:badge];
            }
            if (selected)
            {
                UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(5.0f, 34.0f, width - 10.0f, 3.0f)];
                indicator.tag = 6199;
                indicator.backgroundColor = accent;
                indicator.userInteractionEnabled = false;
                [button addSubview:indicator];
            }
        }
        if (selected)
            selectedButton = button;
        [button addTarget:self action:@selector(og_folderTabPressed:) forControlEvents:UIControlEventTouchUpInside];
        if (!_dialogListCompanion.forwardMode)
        {
            UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(og_folderTabLongPress:)];
            longPressRecognizer.minimumPressDuration = 0.45;
            [button addGestureRecognizer:longPressRecognizer];
        }
        [_ogFolderTabsScrollView addSubview:button];
        x += width;
        if (index + 1 < (NSInteger)_ogDialogFilters.count)
            x += brandedStyle ? brandedSpacing : 2.0f;
        index++;
    }
    CGFloat contentHeight = brandedStyle ? brandedContentHeight : 37.0f;
    CGFloat trailingInset = brandedStyle ? brandedTrailingInset : 6.0f;
    _ogFolderTabsScrollView.contentSize = CGSizeMake(MAX(self.view.bounds.size.width, x + trailingInset), contentHeight);
    if (selectedButton != nil && [self og_folderTabsHeight] > 0.0f)
        [_ogFolderTabsScrollView scrollRectToVisible:CGRectInset(selectedButton.frame, brandedStyle ? -13.0f : -16.0f, 0.0f) animated:false];
    [self og_updateFolderEmptyLabel];
}

- (UIColor *)og_folderTabsBackgroundColor
{
    if ([TGPresentation brandedIOS6Style])
        return [TGPresentation brandedIOS6DialogListHeaderColorForSize:_ogFolderTabsView.bounds.size];
    if ([TGPresentation classicThemeStyle])
        return OGCompatDialogListClassicDarkStyle(self.presentation) ? self.presentation.pallete.backgroundColor : UIColorRGB(0xf7f7f7);
    return self.presentation.pallete.backgroundColor;
}

- (void)og_layoutFolderTabs
{
    if (_tableView == nil || _ogFolderTabsView == nil)
        return;

    CGFloat height = [self og_folderTabsHeight];
    CGFloat width = _tableView.bounds.size.width;
    CGFloat playerHeight = [TGPresentation brandedIOS6Style] ? _ogPlayerHeight : 0.0f;
    CGRect headerFrame = _ogListHeaderView.frame;
    headerFrame.size = CGSizeMake(width, height + playerHeight);
    _ogListHeaderView.frame = headerFrame;
    if (_ogFolderTabsView.superview != _ogListHeaderView)
        [_ogListHeaderView addSubview:_ogFolderTabsView];
    _ogPlayerHostView.frame = CGRectMake(0.0f, height, width, playerHeight);
    if ([TGPresentation brandedIOS6Style])
    {
        TGNavigationBar *navigationBar = [self.navigationController.navigationBar isKindOfClass:[TGNavigationBar class]] ? (TGNavigationBar *)self.navigationController.navigationBar : nil;
        if (navigationBar.musicPlayerHostView == _ogPlayerHostView)
            navigationBar.musicPlayerHostView = _ogPlayerHostView;
    }
    _ogFolderTabsView.hidden = height < FLT_EPSILON;
    _ogFolderTabsView.frame = CGRectMake(0.0f, 0.0f, width, height);
    _ogFolderTabsView.backgroundColor = [self og_folderTabsBackgroundColor];
    _ogFolderTabsScrollView.frame = CGRectMake(0.0f, 0.0f, width, MAX(0.0f, height - 1.0f));
    _ogFolderTabsSeparatorView.frame = CGRectMake(0.0f, MAX(0.0f, height - 1.0f), width, height > 0.0f ? 1.0f : 0.0f);
    [self og_updateFolderEmptyLabel];
}

- (void)og_updateFolderEmptyLabel
{
    if (_ogFolderEmptyLabel == nil)
        return;
    bool folderContentLoading = _ogAllDialogItemsLoading || !_ogFolderLocalSourceExhausted || _ogFolderPeerHydrationActive || _ogFolderPeerLocalLookupInFlight || ([self og_selectedDialogFilterNeedsHistoryScan] && _canLoadMore);
    bool show = _ogSelectedDialogFilterId != 0 && [self og_visibleListModel].count == 0 && !_isLoading && !folderContentLoading && !_isDisplayingSearch && _ogFolderSwipeContainerView == nil;
    _ogFolderEmptyLabel.hidden = !show;
    if (show)
    {
        CGFloat top = self.controllerInset.top + [self og_folderTabsHeight] + _ogPlayerHeight;
        _ogFolderEmptyLabel.frame = CGRectMake(20.0f, top + 40.0f, self.view.bounds.size.width - 40.0f, 44.0f);
        [self.view bringSubviewToFront:_ogFolderEmptyLabel];
    }
}

- (NSArray *)dialogListDisplayedItems
{
    if (_dialogListDisplayedItems == nil)
        [self dialogListCommitDisplayedItems];
    return _dialogListDisplayedItems ?: @[];
}

- (void)dialogListCommitDisplayedItems
{
    _dialogListDisplayedItems = [[self og_visibleListModel] copy] ?: @[];
}

- (void)og_storeSelectedDialogFilterId
{
    if (!_dialogListCompanion.forwardMode)
        [[NSUserDefaults standardUserDefaults] setInteger:_ogSelectedDialogFilterId forKey:@"TGIOS6SelectedDialogFilterId"];
}

- (NSArray *)og_visibleListModel
{
    if (![self og_foldersAllowed] || (_dialogListCompanion.forwardMode && _ogSelectedDialogFilterId == 0))
        return _listModel;
    if (_ogVisibleListCache != nil && _ogVisibleListCacheFilterId == _ogSelectedDialogFilterId)
        return _ogVisibleListCache;
    NSArray *result = [self og_visibleItemsForDialogFilter:[self og_selectedDialogFilter]];
    _ogVisibleListCache = [result copy] ?: @[];
    _ogVisibleListCacheFilterId = _ogSelectedDialogFilterId;
    return _ogVisibleListCache;
}

- (id)og_dialogListItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *displayedRows = [self dialogListDisplayedItems];
    if (indexPath.row >= 0 && indexPath.row < (NSInteger)displayedRows.count)
        return displayedRows[indexPath.row];
    
    return nil;
}

- (NSUInteger)og_archivedConversationCount
{
    NSUInteger count = 0;
    for (id item in _listModel)
    {
        if ([self og_isArchivedConversation:item])
            count++;
    }
    return count;
}

- (int)og_archivedUnreadCount
{
    int count = 0;
    for (id item in _listModel)
    {
        if ([self og_isArchivedConversation:item])
        {
            TGConversation *conversation = (TGConversation *)item;
            [self og_ensureDialogListDataForConversation:conversation];
            if (![conversation.dialogListData[@"mute"] boolValue])
                count += conversation.unreadCount + MAX(0, conversation.serviceUnreadCount);
        }
    }
    return count;
}

- (UITableViewCell *)og_archiveHeaderCellForTableView:(UITableView *)tableView
{
    static NSString *ArchiveHeaderCellIdentifier = @"OGArchiveHeaderCell";
    TGDialogListArchiveHeaderCell *cell = (TGDialogListArchiveHeaderCell *)[tableView dequeueReusableCellWithIdentifier:ArchiveHeaderCellIdentifier];
    if (cell == nil)
        cell = [[TGDialogListArchiveHeaderCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ArchiveHeaderCellIdentifier];

    [cell setPresentation:_presentation branded:[TGPresentation brandedIOS6Style]];
    [cell setArchivedCount:[self og_archivedConversationCount] unreadCount:[self og_archivedUnreadCount] expanded:_ogArchiveExpanded];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == _tableView)
    {
        if (section == 0)
            return (TGIsPad() && _dialogListCompanion.showBroadcastsMenu) ? 1 : 0;
        
        return [self dialogListDisplayedItems].count;
    }
    else
        return [(NSArray *)_searchResultsSections[section][@"items"] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TG_DIALOG_LIST_COST(TGDialogListCostHeight);
    if (tableView == _tableView)
    {
        if (indexPath.section == 0)
            return [TGPresentation brandedIOS6Style] ? 49.0f : 45.0f;
        
        id item = [self og_dialogListItemAtIndexPath:indexPath];
        if ([self og_isArchiveHeaderItem:item])
            return TGDialogListArchiveHeaderHeight;
        if (item != nil)
            return [self dialogListConversationRowHeight];
        
        return 0;
    }
    else
    {
        id result = [_searchResultsSections[indexPath.section][@"items"] objectAtIndex:indexPath.row];
        if ([result isKindOfClass:[TGDialogListRecentPeers class]]) {
            return [TGDialogListRecentPeersCell heightForWidth:self.view.frame.size.width count:((TGDialogListRecentPeers *)result).peers.count expanded:false ];
        } else if ([result isKindOfClass:[NSString class]]) {
            return 48.0f;
        }
        
        if ([_searchResultsSections[indexPath.section][@"type"] isEqualToString:@"messages"])
            return 76.0f;
        else if ([_searchResultsSections[indexPath.section][@"type"] isEqualToString:@"hashtags"])
            return 43.0f;
        return 51.0f;
    }
}

- (void)prepareCell:(TGDialogListCell *)cell forFeed:(TGFeed *)feed animated:(bool)animated
{
    cell.preparedPreview = nil;
    if (cell.reuseTag != (intptr_t)feed || cell.unreadCount != feed.unreadCount || (feed.serviceUnreadCount != -1 && cell.unreadCount != feed.serviceUnreadCount))
    {
        cell.conversationId = feed.conversationId;
        cell.reuseTag = (intptr_t)feed;
        cell.preparedConversation = nil;
        cell.date = feed.messageDate;
        cell.pinnedToTop = feed.pinnedToTop;
        
        cell.titleText = TGLocalized(@"DialogList.Feed");
        cell.isGroupChat = true;
        cell.authorName = feed.chatTitles.firstObject;
        
        cell.messageText = feed.text;
        cell.messageAttachments = feed.media;
        
        cell.isFeed = true;
        cell.feedChatIds = feed.chatIds;
        cell.feedChatTitles = feed.chatTitles;
        cell.feedAvatarUrls = feed.chatPhotosSmall;
        cell.isVerified = false;
        cell.isPremium = false;
        cell.emojiStatusDocumentId = 0;
        
        cell.unreadCount = feed.serviceUnreadCount != -1 ? feed.serviceUnreadCount : feed.unreadCount;
        
        [cell resetView:animated];
    }
}

- (void)prepareCell:(TGDialogListCell *)cell forConversation:(TGConversation *)conversation animated:(bool)animated context:(TGDialogListCellContext)context
{
    bool isSearch = context == TGDialogListCellContextSearch;
    bool showsListState = context == TGDialogListCellContextList;
    NSDictionary *currentDialogListData = conversation.dialogListData;
    bool shouldBeVerified = [currentDialogListData[@"isVerified"] boolValue];
    int currentIsSavedMessages = [currentDialogListData[@"isSavedMessages"] intValue];
    bool shouldBePremium = [currentDialogListData[@"isPremium"] boolValue] && !currentIsSavedMessages;
    int64_t shouldEmojiStatusDocumentId = currentIsSavedMessages ? 0 : [currentDialogListData[@"emojiStatusDocumentId"] longLongValue];
    NSString *statusText = TGDialogListBrandedStatusText(conversation);
    bool statusChanged = cell.statusText != statusText && ![cell.statusText isEqualToString:statusText];
    NSDictionary *preparedPreview = currentDialogListData[@"preparedPreview"];
    bool previewChanged = cell.preparedPreview != preparedPreview && ![cell.preparedPreview isEqual:preparedPreview];

    if (cell.reuseTag != (intptr_t)conversation && TGDialogListConversationDisplayEqual(cell.preparedConversation, conversation))
    {
        cell.reuseTag = (intptr_t)conversation;
        cell.preparedConversation = conversation;
    }

    if (cell.reuseTag != (intptr_t)conversation || cell.conversationId != conversation.conversationId || cell.linkedCommunityId != (showsListState ? conversation.linkedCommunityId : 0) || cell.unreadCount != conversation.unreadCount || cell.serviceUnreadCount != conversation.serviceUnreadCount || cell.unreadMentionCount != conversation.unreadMentionCount || cell.isAd != conversation.isAd || cell.isVerified != shouldBeVerified || cell.isPremium != shouldBePremium || cell.emojiStatusDocumentId != shouldEmojiStatusDocumentId || statusChanged || previewChanged)
    {
        cell.reuseTag = (intptr_t)conversation;
        cell.preparedConversation = conversation;
        cell.conversationId = conversation.conversationId;
        cell.statusText = statusText;
        cell.preparedPreview = preparedPreview;
    
        cell.date = conversation.unpinnedDate;
        cell.pinnedToTop = showsListState && conversation.pinnedToTop && !_dialogListCompanion.feedChannels;
        cell.isArchived = conversation.isArchived;
        cell.isAd = conversation.isAd;
        cell.groupedInFeed = conversation.feedId.intValue != 0;
        cell.isFeedChannels = _dialogListCompanion.feedChannels;
        
        if (conversation.deliveryError)
            cell.deliveryState = TGMessageDeliveryStateFailed;
        else
            cell.deliveryState = conversation.deliveryState;
        
        NSDictionary *dialogListData = currentDialogListData;
        
        int isSavedMessages = currentIsSavedMessages;
        cell.isSavedMessages = isSavedMessages;
        cell.titleText = isSavedMessages ? TGLocalized(@"DialogList.SavedMessages") : TGOnegramDisplayText([dialogListData objectForKey:@"title"]);
        cell.titleLetters = [dialogListData objectForKey:@"titleLetters"];
        
        cell.isBroadcast = [dialogListData[@"isBroadcast"] boolValue];
        
        cell.isChannel = TGPeerIdIsChannel(conversation.conversationId);
        cell.isChannelGroup = conversation.isChannelGroup;
        cell.linkedCommunityId = showsListState ? conversation.linkedCommunityId : 0;
        cell.isVerified = shouldBeVerified;
        cell.isPremium = shouldBePremium;
        cell.emojiStatusDocumentId = shouldEmojiStatusDocumentId;
        cell.draft = isSearch ? nil : dialogListData[@"draft"];
        cell.hasExplicitContent = conversation.hasExplicitContent;
        
        cell.isEncrypted = [dialogListData[@"isEncrypted"] boolValue];
        cell.encryptionStatus = [dialogListData[@"encryptionStatus"] intValue];
        cell.encryptedUserId = [dialogListData[@"encryptedUserId"] longLongValue];
        cell.encryptionOutgoing = [dialogListData[@"encryptionOutgoing"] boolValue];
        cell.encryptionFirstName = dialogListData[@"encryptionFirstName"];
        
        NSString *authorName = [dialogListData objectForKey:@"authorName"];
        NSNumber *nIsChat = [dialogListData objectForKey:@"isChat"];
        
        if (nIsChat != nil && [nIsChat boolValue])
        {
            NSArray *chatAvatarUrls = [dialogListData objectForKey:@"chatAvatarUrls"];
            cell.groupChatAvatarCount = (int)chatAvatarUrls.count;
            cell.groupChatAvatarUrls = chatAvatarUrls;
            cell.isGroupChat = true;
            cell.avatarUrl = [dialogListData objectForKey:@"avatarUrl"];
        }
        else
        {
            cell.avatarUrl = [dialogListData objectForKey:@"avatarUrl"];
            cell.isGroupChat = false;

        }
        cell.authorName = [authorName isEqualToString:authorNameYou] ? TGLocalized(@"DialogList.You") : TGOnegramDisplayText(authorName);
        cell.authorIsSelf = [dialogListData[@"authorIsSelf"] boolValue];

        cell.isMuted = [[dialogListData objectForKey:@"mute"] boolValue];

        cell.unread = TGDialogListPreviewMessageUnread(conversation);
        
        cell.unreadMark = conversation.unreadMark;
        
        if (!isSearch)
        {
            if ([_dialogListCompanion isConversationOpened:conversation.conversationId])
            {
                cell.unreadCount = 0;
                cell.serviceUnreadCount = 0;
                cell.unreadMentionCount = conversation.unreadMentionCount;
            }
            else
            {
                cell.unreadCount = conversation.unreadCount;
                cell.serviceUnreadCount = conversation.serviceUnreadCount;
                cell.unreadMentionCount = conversation.unreadMentionCount;
                if (conversation.unreadMentionCount == 1 && (conversation.unreadCount + conversation.serviceUnreadCount) == 1) {
                    if ([TGMessage containsUnseenMention:conversation.messageFlags]) {
                        cell.unreadCount = 0;
                        cell.serviceUnreadCount = 0;
                    }
                }
            }
        }
        cell.outgoing = conversation.outgoing;
        
        cell.messageText = TGOnegramDisplayText(conversation.text);
        cell.messageAttachments = conversation.media;
        cell.users = [dialogListData objectForKey:@"users"];
        
        [cell resetView:animated];
    }
    
    if (!isSearch)
    {
        std::map<int64_t, NSString *>::iterator typingIt = _usersTypingInConversation.find(conversation.conversationId);
        if (typingIt == _usersTypingInConversation.end())
            [cell setTypingString:nil];
        else
            [cell setTypingString:typingIt->second];
    }
    
    cell.folderTags = showsListState ? [self og_folderTagsForConversation:conversation] : nil;
    [cell setSwipeActionsEnabled:!showsListState || ![self og_newChatListGesturesEnabled]];
    [cell restartAnimations:false];
}

- (bool)isLastCell:(NSIndexPath *)indexPath {
    id item = [self og_dialogListItemAtIndexPath:indexPath];
    if (![item isKindOfClass:[TGConversation class]])
        return true;
    
    bool isLastCell = false;
    TGConversation *conversation = (TGConversation *)item;
    NSArray *displayedRows = [self dialogListDisplayedItems];
    if (indexPath.row + 1 < (NSInteger)displayedRows.count && [displayedRows[indexPath.row + 1] isKindOfClass:[TGConversation class]]) {
        TGConversation *followingDialog = displayedRows[indexPath.row + 1];
        isLastCell = (followingDialog.pinnedToTop || followingDialog.isAd || [self og_isArchivedConversation:followingDialog]) != (conversation.pinnedToTop || conversation.isAd || [self og_isArchivedConversation:conversation]);
    } else {
        isLastCell = true;
    }
    return isLastCell;
}

- (void)updateIsLastCell {
    for (NSIndexPath *indexPath in _tableView.indexPathsForVisibleRows) {
        TGDialogListCell *cell = (TGDialogListCell *)[_tableView cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:[TGDialogListCell class]]) {
            [cell setIsLastCell:[self isLastCell:indexPath]];
        }
    }
}

- (void)updateSafeAreaInset
{
    UIEdgeInsets safeAreaInset = [self calculatedSafeAreaInset];
    
    for (UIView *view in _searchMixin.searchResultsTableView.subviews)
    {
        if (view.tag >= 1000)
        {
            UIView *sectionLabel = [view viewWithTag:100];
            sectionLabel.frame =  CGRectMake(14.0f + safeAreaInset.left, 6.0f, sectionLabel.frame.size.width, sectionLabel.frame.size.height);
            
            UIView *clearButton = [view viewWithTag:200];
            clearButton.frame = CGRectMake(clearButton.superview.frame.size.width - clearButton.frame.size.width - safeAreaInset.right, 0.0f, clearButton.frame.size.width, 28.0f);
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TG_DIALOG_LIST_COST(TGDialogListCostCell);
    TGUser *user = nil;
    TGConversation *conversation = nil;
    TGMessage *message = nil;
    NSString *hashtag = nil;
    bool isGlobalSearch = false;
    bool isMessageSearch = false;
    
    if (tableView == _tableView)
    {
        if (indexPath.section == 0)
        {
            static NSString *TGDialogListBroadcastsMenuCellIdentifier = @"TGDialogListBroadcastsMenuCell";
            TGDialogListBroadcastsMenuCell *cell = (TGDialogListBroadcastsMenuCell *)[tableView dequeueReusableCellWithIdentifier:TGDialogListBroadcastsMenuCellIdentifier];
            if (cell == nil)
            {
                cell = [[TGDialogListBroadcastsMenuCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGDialogListBroadcastsMenuCellIdentifier];
                
                __weak TGDialogListController *weakSelf = self;
                cell.broadcastListsPressed = ^
                {
                    __strong TGDialogListController *strongSelf = weakSelf;
                    [strongSelf.dialogListCompanion navigateToBroadcastLists];
                };
                
                cell.newGroupPressed = ^
                {
                    __strong TGDialogListController *strongSelf = weakSelf;
                    [strongSelf.dialogListCompanion navigateToNewGroup];
                };
            }
            
            return cell;
        }
        else
        {
            id item = [self og_dialogListItemAtIndexPath:indexPath];
            if ([self og_isArchiveHeaderItem:item])
                return [self og_archiveHeaderCellForTableView:tableView];
            if ([item isKindOfClass:[TGConversation class]])
                conversation = item;
            else if ([item isKindOfClass:[TGFeed class]])
                conversation = item;
        }
    }
    else
    {
        id result = [_searchResultsSections[indexPath.section][@"items"] objectAtIndex:indexPath.row];
        if ([_searchResultsSections[indexPath.section][@"type"] isEqualToString:@"phonenumber"] && [result isKindOfClass:[NSString class]]) {
            TGFlatActionCell *actionCell = (TGFlatActionCell *)[tableView dequeueReusableCellWithIdentifier:@"TGFlatActionCell"];
            actionCell.presentation = self.presentation;
            if (actionCell == nil)
                actionCell = [[TGFlatActionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TGFlatActionCell"];
            
            [actionCell setPhoneNumber:[TGPhoneUtils cleanPhone:(NSString *)result]];
            
            return actionCell;
        }
        if ([result isKindOfClass:[TGDialogListRecentPeers class]]) {
            TGDialogListRecentPeersCell *cell = (TGDialogListRecentPeersCell *)[tableView dequeueReusableCellWithIdentifier:@"TGDialogListRecentPeersCell"];
            if (cell == nil) {
                cell = [[TGDialogListRecentPeersCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TGDialogListRecentPeersCell"];
                __weak TGDialogListController *weakSelf = self;
                cell.peerSelected = ^(id peer) {
                    __strong TGDialogListController *strongSelf = weakSelf;
                    if (strongSelf != nil) {
                        if ([peer isKindOfClass:[TGUser class]]) {
                            [strongSelf.dialogListCompanion searchResultSelectedUser:peer];
                        } else if ([peer isKindOfClass:[TGConversation class]]) {
                            [strongSelf.dialogListCompanion searchResultSelectedConversation:peer];
                        }
                    }
                };
                
                cell.peerLongTap = ^(id peer) {
                    __strong TGDialogListController *strongSelf = weakSelf;
                    if (strongSelf != nil) {
                        [[[TGCustomActionSheet alloc] initWithTitle:nil actions:@[
                            [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Delete") action:@"delete" type:TGActionSheetActionTypeDestructive],
                            [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel],
                        ] actionBlock:^(__unused id target, NSString *action) {
                            if ([action isEqualToString:@"delete"]) {
                                int64_t peerId = 0;
                                int64_t accessHash = 0;
                                if ([peer isKindOfClass:[TGUser class]]) {
                                    peerId = ((TGUser *)peer).uid;
                                    accessHash = ((TGUser *)peer).phoneNumberHash;
                                } else if ([peer isKindOfClass:[TGConversation class]]) {
                                    peerId = ((TGConversation *)peer).conversationId;
                                    accessHash = ((TGConversation *)peer).accessHash;
                                }
                                if (peerId != 0) {
                                    [[[TGRecentPeersSignals resetGenericPeerRating:peerId accessHash:accessHash] timeout:5.0 onQueue:[SQueue concurrentDefaultQueue] orSignal:[SSignal fail:nil]] startWithNext:nil];
                                }
                            }
                        } target:strongSelf] showInView:strongSelf.view];
                    }
                };
            }
            cell.presentation = self.presentation;
            cell.safeAreaInset = self.controllerSafeAreaInset;
            
            NSMutableDictionary *unreadCounts = [[NSMutableDictionary alloc] init];
            for (id item in ((TGDialogListRecentPeers *)result).peers)
            {
                int64_t peerId = 0;
                if ([item isKindOfClass:[TGConversation class]])
                    peerId = ((TGConversation *)item).conversationId;
                else if ([item isKindOfClass:[TGUser class]])
                    peerId = ((TGUser *)item).uid;
                
                if (peerId != 0)
                    unreadCounts[@(peerId)] = @([self dialogListSnapshotUnreadCountForPeerId:peerId]);
            }
            
            [cell setRecentPeers:result unreadCounts:unreadCounts];
            return cell;
        } else if ([result isKindOfClass:[TGConversation class]]) {
            conversation = result;
            isMessageSearch = [_searchResultsSections[indexPath.section][@"type"] isEqualToString:@"messages"];
            isGlobalSearch = [_searchResultsSections[indexPath.section][@"type"] isEqualToString:@"global"];
        }
        else if ([result isKindOfClass:[TGUser class]])
        {
            user = result;
            isGlobalSearch = [_searchResultsSections[indexPath.section][@"type"] isEqualToString:@"global"];
        }
        else if ([result isKindOfClass:[TGMessage class]])
            message = result;
        else
            hashtag = result;
    }
    
    if (tableView == _tableView)
    {
        if (conversation != nil)
        {
            if ([conversation isKindOfClass:[TGConversation class]])
            {
                [self og_ensureDialogListDataForConversation:conversation];
                if (OGDiagnosticsEnabled() && (conversation.dialogListData.count == 0 || [conversation.dialogListData[@"title"] length] == 0))
                    OGPlatformDiagnosticLog(@"DIALOGCELL incomplete row=%d peer=%lld data=%d title=%d archived=%d pinned=%d", (int)indexPath.row, conversation.conversationId, (int)conversation.dialogListData.count, (int)[conversation.dialogListData[@"title"] length], conversation.isArchived ? 1 : 0, conversation.pinnedDate != 0 ? 1 : 0);
                static NSString *MessageCellIdentifier = @"MC";
                TGDialogListCell *cell = [tableView dequeueReusableCellWithIdentifier:MessageCellIdentifier];
                
                if (cell == nil)
                {
                    cell = [[TGDialogListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:MessageCellIdentifier assetsSource:[_dialogListCompanion dialogListCellAssetsSource]];
                    cell.deleteConversation = self.deleteConversation;
                    cell.toggleMuteConversation = self.toggleMuteConversation;
                    cell.togglePinConversation = self.togglePinConversation;
                    cell.toggleGroupConversation = self.toggleGroupConversation;
                    cell.toggleReadConversation = self.toggleReadConversation;
                    cell.archiveToggleHandler = self.archiveToggleHandler;
                    cell.openCommunity = self.openCommunity;
                    cell.watcherHandle = _actionHandle;
                    cell.enableEditing = ![_dialogListCompanion forwardMode] && !_dialogListCompanion.privacyMode;
                    __weak TGDialogListController *weakStoriesSelf = self;
                    cell.openStories = ^(int64_t peerId)
                    {
                        __strong TGDialogListController *strongSelf = weakStoriesSelf;
                        [strongSelf openStoriesForPeerId:peerId];
                    };
                }
                
                cell.presentation = _presentation;
                [cell setFastScrolling:_dialogListFastScrolling];
                [self prepareCell:cell forConversation:conversation animated:false context:TGDialogListCellContextList];
                cell.storyRingState = [self storyRingStateForPeerId:conversation.conversationId];
                [cell setIsLastCell:[self isLastCell:indexPath]];
                
                return cell;
            }
            else
            {
                static NSString *FeedCellIdentifier = @"FC";
                TGDialogListCell *cell = [tableView dequeueReusableCellWithIdentifier:FeedCellIdentifier];
                
                if (cell == nil)
                {
                    cell = [[TGDialogListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:FeedCellIdentifier assetsSource:[_dialogListCompanion dialogListCellAssetsSource]];
                    cell.deleteConversation = self.deleteConversation;
                    cell.togglePinConversation = self.togglePinConversation;
                    cell.archiveToggleHandler = self.archiveToggleHandler;
                    cell.openCommunity = self.openCommunity;
                    cell.watcherHandle = _actionHandle;
                }
                
                cell.presentation = _presentation;
                [cell setFastScrolling:_dialogListFastScrolling];
                [self prepareCell:cell forFeed:(TGFeed *)conversation animated:false];
                [cell setSwipeActionsEnabled:![self og_newChatListGesturesEnabled]];
                [cell setIsLastCell:[self isLastCell:indexPath]];
                
                return cell;
            }
        }
        
        static NSString *PlaceholderCellIdentifier = @"LC";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:PlaceholderCellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PlaceholderCellIdentifier];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            cell.contentView.backgroundColor = [UIColor clearColor];
            
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            spinner.tag = 10000;
            spinner.frame = CGRectMake(0, 0, 24, 24);
            spinner.center = cell.center;
            spinner.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
            [cell.contentView addSubview:spinner];
        }
        UIActivityIndicatorView *spinner = (UIActivityIndicatorView *)[cell viewWithTag:10000];
        if (_canLoadMore)
        {
            spinner.hidden = false;
            [spinner startAnimating];
        }
        else
        {
            spinner.hidden = true;
            [spinner stopAnimating];
        }
        return cell;
    }
    else
    {
        if ((conversation != nil || user != nil) && !isMessageSearch)
        {
            static NSString *SearchCellIdentifier = @"UC";
            TGDialogListSearchCell *cell = [tableView dequeueReusableCellWithIdentifier:SearchCellIdentifier];
            if (cell == nil)
            {
                cell = [[TGDialogListSearchCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SearchCellIdentifier assetsSource:[_dialogListCompanion dialogListCellAssetsSource]];
            }
            cell.presentation = self.presentation;
            cell.isEncrypted = false;
            cell.encryptedUserId = 0;
            cell.isChat = false;
            cell.isVerified = false;
            cell.isPremium = false;
            cell.emojiStatusDocumentId = 0;
            cell.isSavedMessages = false;
            
            int64_t previousCellConversationId = cell.conversationId;
            
            if (conversation != nil)
            {
                NSDictionary *dialogListData = conversation.dialogListData;
                
                cell.isSavedMessages = [dialogListData[@"isSavedMessages"] intValue];
                cell.isEncrypted = [dialogListData[@"isEncrypted"] boolValue];
                
                if (cell.isSavedMessages)
                {
                    cell.titleTextFirst = TGLocalized(@"DialogList.SavedMessages");
                    cell.titleTextSecond = nil;
                }
                else
                {
                    if (cell.isEncrypted)
                    {
                        cell.titleTextFirst = dialogListData[@"firstName"];
                        cell.titleTextSecond = dialogListData[@"lastName"];
                    }
                    else
                    {
                        cell.titleTextFirst = [dialogListData objectForKey:@"title"];
                        cell.titleTextSecond = nil;
                    }
                }
                
                cell.isVerified = [dialogListData[@"isVerified"] boolValue] || conversation.isVerified;
                cell.isPremium = [dialogListData[@"isPremium"] boolValue] && !cell.isSavedMessages;
                cell.emojiStatusDocumentId = cell.isSavedMessages ? 0 : [dialogListData[@"emojiStatusDocumentId"] longLongValue];
                cell.hasExplicitContent = conversation.hasExplicitContent;
                
                NSNumber *nIsChat = [dialogListData objectForKey:@"isChat"];
                if (nIsChat != nil && [nIsChat boolValue])
                    cell.isChat = true;
                
                cell.avatarUrl = [dialogListData objectForKey:@"avatarUrl"];
                
                NSString *type = nil;
                if ([dialogListData[@"isChannelGroup"] boolValue] || TGPeerIdIsGroup(conversation.conversationId))
                {
                    if (conversation.chatParticipantCount > 0)
                    {
                        type = [effectiveLocalization() getPluralized:@"Conversation.StatusMembers" count:conversation.chatParticipantCount];
                    }
                    else if ([dialogListData[@"isChannelGroup"] boolValue])
                    {
                        SSignal *signal = [[[TGDatabaseInstance() channelCachedData:conversation.conversationId] take:1] mapToSignal:^SSignal *(TGCachedConversationData *data)
                        {
                            if (data.memberCount != 0)
                            {
                                return [SSignal single:@(data.memberCount)];
                            }
                            else
                            {
                                return [[TGChannelManagementSignals updateChannelExtendedInfo:conversation.conversationId accessHash:conversation.accessHash updateUnread:false] then:[[[TGDatabaseInstance() channelCachedData:conversation.conversationId] take:1] map:^id(TGCachedConversationData *data)
                                {
                                    return @(data.memberCount);
                                }]];
                            }
                        }];
                        
                        if (previousCellConversationId != conversation.conversationId)
                        {
                            __weak TGDialogListSearchCell *weakCell = cell;
                            [cell.channelDisposable setDisposable:[[signal deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *memberCount)
                            {
                                __strong TGDialogListSearchCell *strongCell = weakCell;
                                if (strongCell != nil) {
                                    NSString *subtitle = [effectiveLocalization() getPluralized:@"Conversation.StatusMembers" count:memberCount.intValue];
                                    
                                    if (isGlobalSearch && conversation.username.length != 0){
                                        NSString *string = [[NSString alloc] initWithFormat:@"@%@", conversation.username];
                                        if (subtitle.length > 0)
                                            string = [NSString stringWithFormat:TGLocalized(@"DialogList.SearchSubtitleFormat"), string, subtitle];
                                        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:string attributes:@{NSFontAttributeName: TGSystemFontOfSize(14.0f)}];
                                        [attributedString addAttribute:NSForegroundColorAttributeName value:self.presentation.pallete.secondaryTextColor range:NSMakeRange(0, string.length)];
                                        if (_searchResultsQuery.length != 0)
                                        {
                                            NSRange range = [[string lowercaseString] rangeOfString:[_searchResultsQuery lowercaseString]];
                                            if (range.location != NSNotFound && range.location < conversation.username.length + 1)
                                            {
                                                if (range.location == 1)
                                                {
                                                    range.location = 0;
                                                    range.length++;
                                                }
                                                [attributedString addAttribute:NSForegroundColorAttributeName value:self.presentation.pallete.accentColor range:range];
                                            }
                                        }
                                        strongCell.attributedSubtitleText = attributedString;
                                    } else {
                                        NSDictionary *attributes = @{NSFontAttributeName: TGSystemFontOfSize(14.0f), NSForegroundColorAttributeName: self.presentation.pallete.secondaryTextColor};
                                        if (subtitle.length > 0)
                                            strongCell.attributedSubtitleText = [[NSAttributedString alloc] initWithString:subtitle attributes:attributes];
                                        else
                                            strongCell.attributedSubtitleText = nil;
                                    }
                                    
                                    [strongCell resetView:false];
                                }
                            }]];
                        }
                    }
                }
                else if ([dialogListData[@"isChannel"] boolValue])
                {
                    if (conversation.chatParticipantCount > 0)
                    {
                        type = [effectiveLocalization() getPluralized:@"Conversation.StatusSubscribers" count:conversation.chatParticipantCount];
                    }
                }
                
                if (isGlobalSearch && conversation.username.length != 0){
                    NSString *string = [[NSString alloc] initWithFormat:@"@%@", conversation.username];
                    if (type.length > 0)
                        string = [NSString stringWithFormat:TGLocalized(@"DialogList.SearchSubtitleFormat"), string, type];
                    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:string attributes:@{NSFontAttributeName: TGSystemFontOfSize(14.0f)}];
                    [attributedString addAttribute:NSForegroundColorAttributeName value:self.presentation.pallete.secondaryTextColor range:NSMakeRange(0, string.length)];
                    if (_searchResultsQuery.length != 0)
                    {
                        NSRange range = [[string lowercaseString] rangeOfString:[_searchResultsQuery lowercaseString]];
                        if (range.location != NSNotFound && range.location < conversation.username.length + 1)
                        {
                            if (range.location == 1)
                            {
                                range.location = 0;
                                range.length++;
                            }
                            [attributedString addAttribute:NSForegroundColorAttributeName value:self.presentation.pallete.accentColor range:range];
                        }
                    }
                    cell.attributedSubtitleText = attributedString;
                } else {
                    if (previousCellConversationId != conversation.conversationId)
                    {
                        NSDictionary *attributes = @{NSFontAttributeName: TGSystemFontOfSize(14.0f), NSForegroundColorAttributeName: self.presentation.pallete.secondaryTextColor};
                        if (type.length > 0)
                            cell.attributedSubtitleText = [[NSAttributedString alloc] initWithString:type attributes:attributes];
                        else
                            cell.attributedSubtitleText = nil;
                    }
                }
                
                cell.conversationId = conversation.conversationId;
                cell.encryptedUserId = [dialogListData[@"encryptedUserId"] longLongValue];
                
                if (TGPeerIdIsChannel(conversation.conversationId)) {
                    cell.unreadCount = conversation.kind == TGConversationKindPersistentChannel ? conversation.unreadCount : 0;
                } else {
                    cell.unreadCount = conversation.unreadCount;
                }
            }
            else if (user != nil)
            {
                cell.isChat = false;
                
                bool isSavedMessages = user.uid == TGTelegraphInstance.clientUserId;
                cell.isSavedMessages = isSavedMessages;
                cell.isVerified = user.isVerified;
                cell.isPremium = user.isPremium && !isSavedMessages;
                cell.emojiStatusDocumentId = isSavedMessages ? 0 : user.emojiStatusDocumentId;
                if (isSavedMessages)
                {
                    cell.titleTextFirst = TGLocalized(@"DialogList.SavedMessages");
                    cell.titleTextSecond = nil;
                }
                else
                {
                    cell.avatarUrl = user.photoFullUrlSmall;
                    if (user.firstName.length == 0)
                    {
                        cell.titleTextFirst = user.lastName;
                        cell.titleTextSecond = nil;
                    }
                    else
                    {
                        cell.titleTextFirst = user.firstName;
                        cell.titleTextSecond = user.lastName;
                    }
                }

                if (isGlobalSearch)
                {
                    NSString *string = [[NSString alloc] initWithFormat:@"@%@", user.userName];
                    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:string attributes:@{NSFontAttributeName: TGSystemFontOfSize(14.0f)}];
                    [attributedString addAttribute:NSForegroundColorAttributeName value:self.presentation.pallete.secondaryTextColor range:NSMakeRange(0, string.length)];
                    if (_searchResultsQuery.length != 0)
                    {
                        NSRange range = [[string lowercaseString] rangeOfString:[_searchResultsQuery lowercaseString]];
                        if (range.location != NSNotFound && range.location < user.userName.length + 1)
                        {
                            if (range.location == 1)
                            {
                                range.location = 0;
                                range.length++;
                            }
                            [attributedString addAttribute:NSForegroundColorAttributeName value:self.presentation.pallete.accentColor range:range];
                        }
                    }
                    cell.attributedSubtitleText = attributedString;
                }
                else {
                    cell.attributedSubtitleText = nil;
                }
                
                cell.unreadCount = conversation.unreadCount;
                
                cell.conversationId = user.uid;
            }
            
            [cell resetView:false];
            return cell;
        }
        else if (conversation != nil)
        {
            static NSString *MessageCellIdentifier = @"MC";
            TGDialogListCell *cell = [tableView dequeueReusableCellWithIdentifier:MessageCellIdentifier];
            
            if (cell == nil)
            {
                if (cell == nil)
                {
                    cell = [[TGDialogListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:MessageCellIdentifier assetsSource:[_dialogListCompanion dialogListCellAssetsSource]];
                    cell.watcherHandle = _actionHandle;
                    cell.enableEditing = false;
                }
            }
            
            cell.presentation = _presentation;
            cell.disableActions = true;
            [self prepareCell:cell forConversation:conversation animated:false context:TGDialogListCellContextSearch];
            
            return cell;
        }
        else if (hashtag != nil)
        {
            TGHashtagPanelCell *cell = [tableView dequeueReusableCellWithIdentifier:TGHashtagPanelCellKind];
            if (cell == nil)
            {
                cell = [[TGHashtagPanelCell alloc] initWithStyle:TGModernConversationAssociatedInputPanelDefaultStyle];
                [cell setDisplaySeparator:true];
            }
            [cell setPallete:self.presentation.associatedInputPanelPallete];
            [cell setHashtag:hashtag];
            
            return cell;
        }
    }
    
    return nil;
}

- (bool)dialogListHiddenFromUser
{
    if (_dialogListAppearingFlush || _dialogListApplyingCoalescedUpdates || TGIsPad() || ![self isViewLoaded])
        return false;
    if (self.view.window == nil)
        return true;
    UINavigationController *navigationController = self.navigationController;
    if (navigationController == nil)
        return false;
    UIViewController *topController = navigationController.topViewController;
    return topController != self && topController != self.parentViewController;
}

- (bool)dialogListShouldCoalesceUIUpdates
{
    if (_dialogListFastScrolling)
        return true;
    if (!TGDialogListSingleCoreDevice())
        return false;
    if (_dialogListCoalescingUIUpdates)
        return true;
    if ([self dialogListHiddenFromUser])
    {
        _dialogListHiddenCoalesced = true;
        return true;
    }
    if (_dialogListHiddenCoalesced && !_dialogListApplyingCoalescedUpdates)
    {
        if (!_dialogListHiddenFlushScheduled)
        {
            _dialogListHiddenFlushScheduled = true;
            TGDialogListControllerReference *reference = _ogLifetimeReference;
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [reference withValue:^(void *value)
                {
                    TGDialogListController *controller = (__bridge TGDialogListController *)value;
                    controller->_dialogListHiddenFlushScheduled = false;
                    [controller dialogListFlushCoalescedUpdates];
                }];
            });
        }
        return true;
    }
    return false;
}

- (void)dialogListBeginRateLimitedUIUpdate
{
    if (!TGDialogListSingleCoreDevice() || _dialogListApplyingCoalescedUpdates || _dialogListFastScrolling || _dialogListCoalescingUIUpdates)
        return;

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime elapsed = now - _dialogListLastUIUpdateTime;
    CFAbsoluteTime interval = MIN(TGDialogListSingleCoreUIUpdateMaxInterval, MAX(TGDialogListSingleCoreUIUpdateInterval, _dialogListLastFullReloadDuration * (OGRuntimeStartupPhaseCompleted() ? 1.0 : 2.0)));
    if (elapsed < 0.0 || elapsed >= interval)
    {
        _dialogListLastUIUpdateTime = now;
        return;
    }

    _dialogListCoalescingUIUpdates = true;
    if (_dialogListRateLimitFlushScheduled)
        return;

    _dialogListRateLimitFlushScheduled = true;
    TGDialogListControllerReference *reference = _ogLifetimeReference;
    OGPlatformDispatchOnMainThreadAfter(interval - elapsed, ^
    {
        [reference withValue:^(void *value)
        {
            TGDialogListController *controller = (__bridge TGDialogListController *)value;
            controller->_dialogListRateLimitFlushScheduled = false;
            if (controller->_dialogListFastScrolling)
                return;

            controller->_dialogListLastUIUpdateTime = CFAbsoluteTimeGetCurrent();
            [controller dialogListFlushCoalescedUpdates];
            [controller og_continueDialogListDataHydration];
        }];
    });
}

- (void)dialogListEnsureCoalescedModel
{
    if (_dialogListCoalescedModel == nil)
        _dialogListCoalescedModel = [_listModel mutableCopy];
}

- (void)dialogListEnsureCoalescedAllDialogItems
{
    if (_dialogListCoalescedAllDialogItemsDirty)
        return;

    _dialogListCoalescedAllDialogItemsDirty = true;
    _dialogListCoalescedAllDialogItems = [[NSMutableArray alloc] initWithArray:_ogAllDialogItems == nil ? @[] : _ogAllDialogItems];
}

- (void)dialogListCoalesceFullReload:(NSArray *)items
{
    _dialogListCoalescedModel = [[NSMutableArray alloc] initWithArray:items == nil ? @[] : items];
    _dialogListCoalescedAllDialogItems = nil;
    _dialogListCoalescedAllDialogItemsDirty = false;
    _dialogListCoalescedHasFullReload = true;
    _dialogListCoalescedReloadPending = true;
    _dialogListVisibleRefreshPending = true;
}

- (void)dialogListCoalesceConversationUpdates:(NSDictionary *)dict
{
    if (dict.count == 0)
        return;

    [self dialogListEnsureCoalescedModel];
    for (NSUInteger i = 0; i < _dialogListCoalescedModel.count; i++)
    {
        id item = _dialogListCoalescedModel[i];
        int64_t peerId = 0;
        if ([item isKindOfClass:[TGConversation class]])
            peerId = ((TGConversation *)item).conversationId;
        else if ([item isKindOfClass:[TGFeed class]])
            peerId = ((TGFeed *)item).conversationId;
        if (peerId == 0)
            continue;
        id updatedItem = dict[@(peerId)];
        if (updatedItem != nil)
            [_dialogListCoalescedModel replaceObjectAtIndex:i withObject:updatedItem];
    }

    if (_ogAllDialogItems.count != 0 || _dialogListCoalescedAllDialogItemsDirty)
    {
        [self dialogListEnsureCoalescedAllDialogItems];
        for (NSInteger i = (NSInteger)_dialogListCoalescedAllDialogItems.count - 1; i >= 0; i--)
        {
            id item = _dialogListCoalescedAllDialogItems[(NSUInteger)i];
            if (![item isKindOfClass:[TGConversation class]])
                continue;
            TGConversation *updatedConversation = dict[@(((TGConversation *)item).conversationId)];
            if (updatedConversation == nil)
                continue;
            if (updatedConversation.isDeleted || updatedConversation.isDeactivated || updatedConversation.leftChat || updatedConversation.kickedFromChat)
                [_dialogListCoalescedAllDialogItems removeObjectAtIndex:(NSUInteger)i];
            else
                [_dialogListCoalescedAllDialogItems replaceObjectAtIndex:(NSUInteger)i withObject:updatedConversation];
        }
    }

    _dialogListVisibleRefreshPending = true;
}

- (void)dialogListCoalesceItemsChanged:(NSArray *)insertedIndices insertedItems:(NSArray *)insertedItems updatedIndices:(NSArray *)updatedIndices updatedItems:(NSArray *)updatedItems removedIndices:(NSArray *)removedIndices
{
    [self dialogListEnsureCoalescedModel];
    NSMutableSet *removedPeerIds = [[NSMutableSet alloc] init];

    NSMutableIndexSet *removalPositions = [[NSMutableIndexSet alloc] init];
    for (NSNumber *nRemovedIndex in removedIndices)
    {
        NSInteger removedIndex = [nRemovedIndex integerValue];
        if (removedIndex >= 0 && removedIndex < (NSInteger)_dialogListCoalescedModel.count)
        {
            id item = _dialogListCoalescedModel[(NSUInteger)removedIndex];
            if ([item isKindOfClass:[TGConversation class]])
                [removedPeerIds addObject:@(((TGConversation *)item).conversationId)];
            [removalPositions addIndex:(NSUInteger)removedIndex];
        }
    }

    if (removalPositions.count != 0)
        [_dialogListCoalescedModel removeObjectsAtIndexes:removalPositions];

    NSMutableDictionary *modelIndices = TGDialogListItemIndices(_dialogListCoalescedModel);
    NSUInteger updateCount = MIN(updatedIndices.count, updatedItems.count);
    for (NSUInteger i = 0; i < updateCount; i++)
    {
        NSInteger updatedIndex = [updatedIndices[i] integerValue];
        id updatedItem = updatedItems[i];
        int64_t updatedPeerId = 0;
        if ([updatedItem isKindOfClass:[TGConversation class]])
            updatedPeerId = ((TGConversation *)updatedItem).conversationId;
        else if ([updatedItem isKindOfClass:[TGFeed class]])
            updatedPeerId = ((TGFeed *)updatedItem).conversationId;

        bool indexMatches = updatedIndex >= 0 && updatedIndex < (NSInteger)_dialogListCoalescedModel.count;
        if (indexMatches && updatedPeerId != 0)
        {
            id currentItem = _dialogListCoalescedModel[(NSUInteger)updatedIndex];
            int64_t currentPeerId = 0;
            if ([currentItem isKindOfClass:[TGConversation class]])
                currentPeerId = ((TGConversation *)currentItem).conversationId;
            else if ([currentItem isKindOfClass:[TGFeed class]])
                currentPeerId = ((TGFeed *)currentItem).conversationId;
            indexMatches = currentPeerId == updatedPeerId;
        }

        if (!indexMatches && updatedPeerId != 0)
        {
            NSNumber *index = modelIndices[@(updatedPeerId)];
            updatedIndex = index == nil ? NSNotFound : index.integerValue;
        }

        if (updatedIndex != NSNotFound && updatedIndex >= 0 && updatedIndex < (NSInteger)_dialogListCoalescedModel.count)
            [_dialogListCoalescedModel replaceObjectAtIndex:(NSUInteger)updatedIndex withObject:updatedItem];
    }

    NSUInteger insertionCount = MIN(insertedIndices.count, insertedItems.count);
    NSMutableIndexSet *insertionPositions = [[NSMutableIndexSet alloc] init];
    NSMutableArray *insertionObjects = [[NSMutableArray alloc] initWithCapacity:insertionCount];
    NSMutableDictionary *insertionsByIndex = [[NSMutableDictionary alloc] initWithCapacity:insertionCount];
    for (NSUInteger i = 0; i < insertionCount; i++)
    {
        NSInteger index = [insertedIndices[i] integerValue];
        if (index >= 0)
            insertionsByIndex[@(index)] = insertedItems[i];
    }
    NSArray *orderedInsertionIndices = [insertionsByIndex.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSNumber *index in orderedInsertionIndices)
    {
        NSUInteger position = index.unsignedIntegerValue;
        if (position > _dialogListCoalescedModel.count + insertionObjects.count)
            continue;
        [insertionPositions addIndex:position];
        [insertionObjects addObject:insertionsByIndex[index]];
    }
    if (insertionObjects.count != 0)
        [_dialogListCoalescedModel insertObjects:insertionObjects atIndexes:insertionPositions];

    if (_ogAllDialogItems.count != 0 || _dialogListCoalescedAllDialogItemsDirty)
    {
        [self dialogListEnsureCoalescedAllDialogItems];
        NSMutableDictionary *updatesByPeerId = [[NSMutableDictionary alloc] initWithCapacity:updatedItems.count];
        for (id updatedItem in updatedItems)
        {
            if ([updatedItem isKindOfClass:[TGConversation class]])
            {
                NSNumber *peerId = @(((TGConversation *)updatedItem).conversationId);
                if (updatesByPeerId[peerId] == nil)
                    updatesByPeerId[peerId] = updatedItem;
            }
        }
        NSMutableSet *allPeerIds = [[NSMutableSet alloc] initWithCapacity:_dialogListCoalescedAllDialogItems.count];
        for (NSInteger i = (NSInteger)_dialogListCoalescedAllDialogItems.count - 1; i >= 0; i--)
        {
            id item = _dialogListCoalescedAllDialogItems[(NSUInteger)i];
            if (![item isKindOfClass:[TGConversation class]])
                continue;
            NSNumber *peerId = @(((TGConversation *)item).conversationId);
            if ([removedPeerIds containsObject:peerId])
            {
                [_dialogListCoalescedAllDialogItems removeObjectAtIndex:(NSUInteger)i];
                continue;
            }
            TGConversation *updatedConversation = updatesByPeerId[peerId];
            if (updatedConversation != nil)
            {
                if (updatedConversation.isDeleted || updatedConversation.isDeactivated || updatedConversation.leftChat || updatedConversation.kickedFromChat)
                {
                    [_dialogListCoalescedAllDialogItems removeObjectAtIndex:(NSUInteger)i];
                    continue;
                }
                [_dialogListCoalescedAllDialogItems replaceObjectAtIndex:(NSUInteger)i withObject:updatedConversation];
            }
            [allPeerIds addObject:peerId];
        }
        for (TGConversation *insertedConversation in insertedItems)
        {
            if (![insertedConversation isKindOfClass:[TGConversation class]] || insertedConversation.isDeleted || insertedConversation.isDeactivated || insertedConversation.leftChat || insertedConversation.kickedFromChat)
                continue;
            NSNumber *peerId = @(insertedConversation.conversationId);
            if (![allPeerIds containsObject:peerId])
            {
                [allPeerIds addObject:peerId];
                [_dialogListCoalescedAllDialogItems addObject:insertedConversation];
            }
        }
    }

    if (insertedIndices.count != 0 || removedIndices.count != 0)
        _dialogListCoalescedReloadPending = true;
    _dialogListVisibleRefreshPending = true;
}

- (bool)dialogListVisibleItems:(NSArray *)lhs haveSameOrderAs:(NSArray *)rhs
{
    if (lhs.count != rhs.count)
        return false;

    for (NSUInteger i = 0; i < lhs.count; i++)
    {
        id lhsItem = lhs[i];
        id rhsItem = rhs[i];
        int64_t lhsPeerId = 0;
        int64_t rhsPeerId = 0;

        if ([lhsItem isKindOfClass:[TGConversation class]])
            lhsPeerId = ((TGConversation *)lhsItem).conversationId;
        else if ([lhsItem isKindOfClass:[TGFeed class]])
            lhsPeerId = ((TGFeed *)lhsItem).conversationId;

        if ([rhsItem isKindOfClass:[TGConversation class]])
            rhsPeerId = ((TGConversation *)rhsItem).conversationId;
        else if ([rhsItem isKindOfClass:[TGFeed class]])
            rhsPeerId = ((TGFeed *)rhsItem).conversationId;

        if (lhsPeerId != rhsPeerId || (lhsPeerId == 0 && lhsItem != rhsItem && ![lhsItem isEqual:rhsItem]))
            return false;
    }

    return true;
}

- (void)dialogListFlushCoalescedUpdates
{
    TG_DIALOG_LIST_COST(TGDialogListCostFlush);
    if (_dialogListFastScrolling)
        return;
    if (TGDialogListSingleCoreDevice() && [self dialogListHiddenFromUser])
    {
        _dialogListHiddenCoalesced = true;
        return;
    }
    _dialogListHiddenCoalesced = false;

    _dialogListCoalescingUIUpdates = false;
    _dialogListApplyingCoalescedUpdates = true;
    [self dialogListApplyCoalescedUpdates];
    _dialogListApplyingCoalescedUpdates = false;
    if (self == TGAppDelegateInstance.rootController.dialogListController) {
        bool pending = _dialogListCoalescedModel != nil || _dialogListCoalescedReloadPending || _dialogListVisibleRefreshPending;
        OGStartupDiagnosticsUIWorkPending(pending);
        if (!pending)
            [self dialogListPresentationUpdated];
    }
}

- (bool)dialogListApplyDisplayedItems:(NSArray *)items animated:(bool)animated
{
    NSArray *previous = [self dialogListDisplayedItems];
    if (_tableView == nil || _tableView.window == nil || [_tableView numberOfSections] != 2 || [_tableView numberOfRowsInSection:1] != (NSInteger)previous.count)
        return false;
    if ([self dialogListVisibleItems:previous haveSameOrderAs:items])
    {
        _dialogListDisplayedItems = [items copy];
        [self dialogListRefreshVisibleCells];
        [self og_updateFolderEmptyLabel];
        return true;
    }
    NSMutableDictionary *oldIndices = [[NSMutableDictionary alloc] initWithCapacity:previous.count];
    NSMutableArray *oldKeys = [[NSMutableArray alloc] initWithCapacity:previous.count];
    NSMutableArray *newKeys = [[NSMutableArray alloc] initWithCapacity:items.count];
    NSMutableSet *newKeySet = [[NSMutableSet alloc] initWithCapacity:items.count];
    for (NSUInteger i = 0; i < previous.count; i++)
    {
        id item = previous[i];
        int64_t peerId = TGDialogListItemPeerId(item);
        id key = peerId != 0 ? TGDialogListDiffKey(item, peerId) : ([self og_isArchiveHeaderItem:item] ? @"archive" : nil);
        if (key == nil || oldIndices[key] != nil)
            return false;
        oldIndices[key] = @(i);
        [oldKeys addObject:key];
    }
    NSMutableArray *commonKeys = [[NSMutableArray alloc] initWithCapacity:MIN(previous.count, items.count)];
    NSMutableArray *commonPositions = [[NSMutableArray alloc] initWithCapacity:MIN(previous.count, items.count)];
    for (id item in items)
    {
        int64_t peerId = TGDialogListItemPeerId(item);
        id key = peerId != 0 ? TGDialogListDiffKey(item, peerId) : ([self og_isArchiveHeaderItem:item] ? @"archive" : nil);
        if (key == nil || [newKeySet containsObject:key])
            return false;
        [newKeySet addObject:key];
        [newKeys addObject:key];
        NSNumber *index = oldIndices[key];
        if (index != nil)
        {
            [commonKeys addObject:key];
            [commonPositions addObject:index];
        }
    }
    NSUInteger count = commonKeys.count;
    if (count > SIZE_MAX / sizeof(size_t))
        return false;
    size_t *positions = count == 0 ? NULL : (size_t *)malloc(count * sizeof(size_t));
    bool *keep = count == 0 ? NULL : (bool *)calloc(count, sizeof(bool));
    if (count != 0 && (positions == NULL || keep == NULL))
    {
        free(positions);
        free(keep);
        return false;
    }
    for (NSUInteger i = 0; i < count; i++)
        positions[i] = [commonPositions[i] unsignedIntegerValue];
    bool computed = OGDialogListStableSubsequence(positions, count, keep);
    NSMutableSet *stableKeys = [[NSMutableSet alloc] initWithCapacity:count];
    if (computed)
    {
        for (NSUInteger i = 0; i < count; i++)
        {
            if (keep[i])
                [stableKeys addObject:commonKeys[i]];
        }
    }
    free(positions);
    free(keep);
    if (!computed)
        return false;
    NSMutableArray *removed = [[NSMutableArray alloc] init];
    NSMutableArray *inserted = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < oldKeys.count; i++)
    {
        if (![stableKeys containsObject:oldKeys[i]])
            [removed addObject:[NSIndexPath indexPathForRow:i inSection:1]];
    }
    for (NSUInteger i = 0; i < newKeys.count; i++)
    {
        if (![stableKeys containsObject:newKeys[i]])
            [inserted addObject:[NSIndexPath indexPathForRow:i inSection:1]];
    }
    if (removed.count + inserted.count > MAX((NSUInteger)48, items.count / 3))
        return false;
    NSMutableDictionary *temporaryImages = [[NSMutableDictionary alloc] init];
    int64_t editingPeerId = 0;
    bool editingToLeft = false;
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
            [dialogCell collectCachedPhotos:temporaryImages];
            if ([dialogCell isEditingControlsExpanded])
            {
                editingPeerId = dialogCell.conversationId;
                editingToLeft = [dialogCell isEditingControlsExpandedToLeft];
            }
        }
    }
    [[TGRemoteImageView sharedCache] addTemporaryCachedImagesSource:temporaryImages autoremove:true];
    _dialogListDisplayedItems = [items copy];
    if (removed.count != 0 || inserted.count != 0)
    {
        UITableViewRowAnimation animation = animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone;
        __weak TGDialogListController *weakSelf = self;
        SEL completionSelector = NSSelectorFromString(@"setCompletionBlock:");
        bool hasCompletion = [CATransaction respondsToSelector:completionSelector];
        [CATransaction begin];
        if (hasCompletion)
        {
            void (*setCompletion)(id, SEL, void (^)(void)) = (void (*)(id, SEL, void (^)(void)))[CATransaction methodForSelector:completionSelector];
            if (setCompletion != NULL)
                setCompletion([CATransaction class], completionSelector, ^
                {
                    __strong TGDialogListController *strongSelf = weakSelf;
                    [strongSelf dialogListRepairVisibleRows];
                });
            else
                hasCompletion = false;
        }
        [_tableView beginUpdates];
        if (removed.count != 0)
            [_tableView deleteRowsAtIndexPaths:removed withRowAnimation:animation];
        if (inserted.count != 0)
            [_tableView insertRowsAtIndexPaths:inserted withRowAnimation:animation];
        [_tableView endUpdates];
        [CATransaction commit];
        if (!hasCompletion)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                __strong TGDialogListController *strongSelf = weakSelf;
                [strongSelf dialogListRepairVisibleRows];
            });
        }
    }
    [self dialogListRefreshVisibleCells];
    if (editingPeerId != 0)
    {
        for (UITableViewCell *cell in _tableView.visibleCells)
        {
            if ([cell isKindOfClass:[TGDialogListCell class]] && ((TGDialogListCell *)cell).conversationId == editingPeerId)
                [(TGDialogListCell *)cell setEditingConrolsExpanded:true toLeft:editingToLeft animated:false];
        }
    }
    [self og_updateFolderEmptyLabel];
    return true;
}

- (void)dialogListApplyCoalescedUpdates
{
    NSMutableArray *coalescedModel = _dialogListCoalescedModel;
    NSMutableArray *coalescedAllDialogItems = _dialogListCoalescedAllDialogItems;
    bool allDialogItemsDirty = _dialogListCoalescedAllDialogItemsDirty;
    bool hasFullReload = _dialogListCoalescedHasFullReload;
    bool reloadPending = _dialogListCoalescedReloadPending;
    bool reloadAnimated = _dialogListCoalescedReloadAnimated;
    bool visibleRefreshPending = _dialogListVisibleRefreshPending;

    _dialogListCoalescedModel = nil;
    _dialogListCoalescedAllDialogItems = nil;
    _dialogListCoalescedAllDialogItemsDirty = false;
    _dialogListCoalescedHasFullReload = false;
    _dialogListCoalescedReloadPending = false;
    _dialogListCoalescedReloadAnimated = false;
    _dialogListVisibleRefreshPending = false;

    if (allDialogItemsDirty)
        _ogAllDialogItems = [coalescedAllDialogItems copy];

    if (hasFullReload)
    {
        [self dialogListFullyReloaded:coalescedModel == nil ? @[] : coalescedModel];
        return;
    }

    if (coalescedModel == nil)
    {
        if (reloadPending)
            [self reloadData:reloadAnimated];
        else if (visibleRefreshPending)
            [self dialogListRefreshVisibleCells];
        return;
    }

    NSArray *previousVisibleItems = [[self og_visibleListModel] copy];
    NSUInteger archivedTotalPrior = [self og_archivedConversationCount];
    int countBefore = (int)_listModel.count;

    [_listModel removeAllObjects];
    [_listModel addObjectsFromArray:coalescedModel];
    _ogVisibleListCache = nil;
    _ogVisibleListCacheFilterId = INT32_MIN;

    NSUInteger archivedTotalNow = [self og_archivedConversationCount];
    if (archivedTotalPrior != archivedTotalNow)
    {
        if (_ogArchiveExpanded && archivedTotalNow == 0)
            _ogArchiveExpanded = false;
        [self updateBarButtonItemsAnimated:false];
        reloadPending = true;
    }

    NSArray *currentVisibleItems = [self og_visibleListModel];
    if (![self dialogListVisibleItems:previousVisibleItems haveSameOrderAs:currentVisibleItems])
        reloadPending = true;

    if (reloadPending)
    {
        if (![self dialogListApplyDisplayedItems:currentVisibleItems animated:reloadAnimated])
            [self reloadData:reloadAnimated];
    }
    else if (visibleRefreshPending)
        [self dialogListRefreshVisibleCells];

    [self og_updateFolderTabs];
    [self og_scheduleFolderPeerHydrationReconciliation];
    _visibleConversationsPipe.sink(@true);

    if ((countBefore == 0) != (_listModel.count == 0))
    {
        [self updateEmptyListContainer];
        if (_listModel.count == 0)
            [self setupEditingMode:false setupTable:true];
    }

    [self updateSearchBarBackground];
}

- (void)dialogListRepairVisibleRows
{
    UITableView *tableView = _tableView;
    if (tableView == nil || tableView.window == nil || [tableView numberOfSections] != 2 || [tableView numberOfRowsInSection:1] != (NSInteger)[self dialogListDisplayedItems].count)
        return;
    [tableView layoutIfNeeded];
    bool needsReload = false;
    for (NSIndexPath *indexPath in [tableView indexPathsForVisibleRows])
    {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if (cell == nil || cell.superview == nil || !CGRectEqualToRect(cell.frame, [tableView rectForRowAtIndexPath:indexPath]))
        {
            needsReload = true;
            break;
        }
        if (cell.hidden)
            cell.hidden = false;
        if (cell.alpha < 1.0f)
            cell.alpha = 1.0f;
    }
    if (needsReload)
    {
        [tableView reloadData];
        [self og_layoutFolderTabs];
    }
}

- (void)dialogListRefreshVisibleCells
{
    [self dialogListRefreshVisibleCellsAnimated:false];
}

- (void)dialogListRefreshVisibleCellsAnimated:(bool)animated
{
    NSArray *items = [self og_visibleListModel];
    NSArray *displayedItems = [self dialogListDisplayedItems];
    if (items != displayedItems && ![self dialogListVisibleItems:displayedItems haveSameOrderAs:items])
    {
        [self reloadData:false];
        return;
    }
    _dialogListDisplayedItems = [items copy];
    items = _dialogListDisplayedItems;

    for (TGDialogListCell *cell in _tableView.visibleCells)
    {
        if (![cell isKindOfClass:[TGDialogListCell class]])
            continue;
        NSIndexPath *indexPath = [_tableView indexPathForCell:cell];
        if (indexPath == nil || indexPath.section != 1 || indexPath.row >= items.count)
            continue;
        id item = items[indexPath.row];
        int64_t peerId = [item isKindOfClass:[TGConversation class]] ? ((TGConversation *)item).conversationId : ([item isKindOfClass:[TGFeed class]] ? ((TGFeed *)item).conversationId : 0);
        if (peerId != cell.conversationId)
        {
            [self reloadData:false];
            return;
        }
        if ([item isKindOfClass:[TGConversation class]])
            [self prepareCell:cell forConversation:item animated:animated context:TGDialogListCellContextList];
        else if ([item isKindOfClass:[TGFeed class]])
            [self prepareCell:cell forFeed:item animated:animated];
    }
    [self updateIsLastCell];
    [self updateSearchBarBackground];
}

- (void)dialogListSetFastScrolling:(bool)fastScrolling
{
    if (_dialogListFastScrolling == fastScrolling)
        return;

    _dialogListFastScrolling = fastScrolling;
    if (fastScrolling)
    {
        if (TGDialogListSingleCoreDevice())
            _dialogListCoalescingUIUpdates = true;
        OGRuntimeBeginInteraction();
    }
    else
    {
        OGRuntimeEndInteraction();
    }
    NSArray *visibleCells = _tableView.visibleCells;
    for (UITableViewCell *cell in visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
            [(TGDialogListCell *)cell setFastScrolling:fastScrolling];
    }

    if (!fastScrolling && TGDialogListSingleCoreDevice())
    {
        NSUInteger index = 0;
        for (UITableViewCell *cell in visibleCells)
        {
            if (![cell isKindOfClass:[TGDialogListCell class]])
                continue;
            NSTimeInterval delay = 0.008 * (NSTimeInterval)index++;
            OGPlatformDispatchOnMainThreadAfter(delay, ^
            {
                if (!_dialogListFastScrolling && cell.window != nil)
                    [(TGDialogListCell *)cell resumeDeferredContent];
            });
        }
        OGPlatformDispatchOnMainThreadAfter(0.06, ^
        {
            if (_dialogListFastScrolling)
                return;
            [self dialogListFlushCoalescedUpdates];
            [self og_continueDialogListDataHydration];
        });
        return;
    }

    if (!fastScrolling)
    {
        for (UITableViewCell *cell in visibleCells)
        {
            if ([cell isKindOfClass:[TGDialogListCell class]])
                [(TGDialogListCell *)cell resumeDeferredContent];
        }
        [self dialogListFlushCoalescedUpdates];
        [self og_continueDialogListDataHydration];
    }
}

- (bool)dialogListIsFastScrolling
{
    return _dialogListFastScrolling;
}

- (bool)dialogListOnScreen
{
    return _isOnScreen;
}

- (void)dialogListPrefetchAvatarUrl:(NSString *)url filter:(NSString *)filter
{
    TG_DIALOG_LIST_COST(TGDialogListCostAvatarPrefetch);
    if (url.length == 0 || filter.length == 0)
        return;

    NSString *filteredUrl = [TGRemoteImageView cacheKeyForUrl:url filter:filter];
    TGCache *cache = [TGRemoteImageView sharedCache];
    UIImage *cachedImage = [cache cachedImage:filteredUrl availability:TGCacheMemory];
    bool rounded = [filter isEqualToString:@"scale:50x50"] || [filter isEqualToString:@"scale:52x52"];
    CGFloat avatarSize = [filter isEqualToString:@"scale:50x50"] ? 50.0f : 52.0f;
    CGFloat radius = avatarSize == 50.0f ? 8.0f : 7.0f;
    if (cachedImage != nil)
    {
        if (rounded)
            OGRuntimeDispatchPreload(@[@"avatar", filteredUrl], ^
            {
                [TGLetteredAvatarView prewarmImage:cachedImage cornerRadius:radius boundsSize:CGSizeMake(avatarSize, avatarSize)];
            });
        return;
    }

    if (_dialogListPrefetchedAvatarKeys == nil)
        _dialogListPrefetchedAvatarKeys = [[OGMemoryCache alloc] initWithCountLimit:192 costLimit:96 * 1024];
    NSNumber *pendingUntil = [_dialogListPrefetchedAvatarKeys objectForKey:filteredUrl];
    CFTimeInterval now = CACurrentMediaTime();
    if (pendingUntil.doubleValue > now)
        return;
    [_dialogListPrefetchedAvatarKeys setObject:@(now + 3.0) forKey:filteredUrl cost:128 + filteredUrl.length * sizeof(unichar)];

    __weak TGDialogListController *weakSelf = self;
    [cache prefetchRenderedAvatar:filteredUrl completion:^(UIImage *renderedImage)
    {
        OGPlatformDispatchOnMainThread(^
        {
            if (renderedImage != nil)
            {
                if (rounded)
                    OGRuntimeDispatchPreload(@[@"avatar", filteredUrl], ^
                    {
                        [TGLetteredAvatarView prewarmImage:renderedImage cornerRadius:radius boundsSize:CGSizeMake(avatarSize, avatarSize)];
                    });
                return;
            }
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            if (strongSelf->_dialogListFastScrolling && TGDialogListSingleCoreDevice())
                [strongSelf->_dialogListPrefetchedAvatarKeys removeObjectForKey:filteredUrl];
            else
                [strongSelf dialogListPrefetchAvatarSourceUrl:url filter:filter];
        });
    }];
}

- (void)dialogListPrefetchAvatarSourceUrl:(NSString *)url filter:(NSString *)filter
{
    NSString *trimmedUrl = [TGRemoteImageView cacheKeyForUrl:url filter:nil];
    NSString *filteredUrl = [TGRemoteImageView cacheKeyForUrl:url filter:filter];
    TGCache *cache = [TGRemoteImageView sharedCache];
    bool rounded = [filter isEqualToString:@"scale:50x50"] || [filter isEqualToString:@"scale:52x52"];
    CGFloat avatarSize = [filter isEqualToString:@"scale:50x50"] ? 50.0f : 52.0f;
    CGFloat radius = avatarSize == 50.0f ? 8.0f : 7.0f;

    if (OGPlatformUsesConstrainedBackgroundExecution() || TGDialogListSingleCoreDevice())
    {
        [TGRemoteImageView preloadImage:url filter:filter blurIfRemote:false cache:cache allowThumbnailCache:false watcher:self];
        return;
    }

    dispatch_async(TGDialogListRenderPreheatQueue(), ^
    {
        @autoreleasepool
        {
            UIImage *filteredImage = [cache cachedImage:filteredUrl availability:TGCacheDisk];
            if (filteredImage != nil)
            {
                if (rounded)
                    [TGLetteredAvatarView prewarmImage:filteredImage cornerRadius:radius boundsSize:CGSizeMake(avatarSize, avatarSize)];
                [cache cacheImage:filteredImage withData:nil url:filteredUrl availability:TGCacheMemory];
                return;
            }

            UIImage *sourceImage = [cache cachedImage:trimmedUrl availability:TGCacheDisk];
            if (sourceImage == nil)
                return;

            TGImageProcessor processor = [TGRemoteImageView imageProcessorForName:filter];
            UIImage *processedImage = processor != nil ? processor(sourceImage) : sourceImage;
            if (processedImage != nil)
            {
                if (rounded)
                    [TGLetteredAvatarView prewarmImage:processedImage cornerRadius:radius boundsSize:CGSizeMake(avatarSize, avatarSize)];
                [cache cacheImage:processedImage withData:nil url:filteredUrl availability:TGCacheMemory];
            }
        }
    });
}

- (NSString *)dialogListAvatarFilter
{
    CGFloat avatarSize = [TGPresentation brandedIOS6Style] ? 50.0f : ([TGPresentation classicThemeStyle] ? 52.0f : 62.0f);
    return [TGPresentation classicThemeStyle] ? [NSString stringWithFormat:@"scale:%dx%d", (int)avatarSize, (int)avatarSize] : [NSString stringWithFormat:@"circle:%dx%d", (int)avatarSize, (int)avatarSize];
}

- (void)og_scheduleCompleteDialogHydrationAndAvatarPrefetch
{
    if (!OGPlatformUsesConstrainedBackgroundExecution() || _listModel.count == 0)
        return;

    NSString *avatarFilter = [self dialogListAvatarFilter];
    NSUInteger avatarPrefetchRemaining = TGDialogListReloadAvatarPrefetchLimit;
    for (id item in _listModel)
    {
        if (![item isKindOfClass:[TGConversation class]])
            continue;

        TGConversation *conversation = (TGConversation *)item;
        if (conversation.dialogListData.count == 0)
            [self og_ensureDialogListDataForConversation:conversation];
        else if (avatarPrefetchRemaining != 0)
        {
            avatarPrefetchRemaining--;
            [self dialogListPrefetchAvatarUrl:conversation.dialogListData[@"avatarUrl"] filter:avatarFilter];
        }
    }
}

- (void)dialogListPreheatConversation:(TGConversation *)conversation width:(CGFloat)width
{
    if (conversation == nil || _presentation == nil || width <= 0.0f || conversation.dialogListData.count == 0)
        return;

    NSArray *preheatContext = @[_presentation, @(width), @([TGPresentation brandedIOS6Style]), @([TGPresentation classicThemeStyle]), @(TGCurrentEmojiRenderMode()), @([TGDialogListCell renderCacheGeneration])];
    if (_dialogListPreheatedConversations == nil)
        _dialogListPreheatedConversations = [[NSMutableDictionary alloc] init];
    if (![_dialogListPreheatContext isEqualToArray:preheatContext] || _dialogListPreheatedConversations.count > 1024)
    {
        _dialogListPreheatContext = preheatContext;
        [_dialogListPreheatedConversations removeAllObjects];
    }
    NSNumber *preheatPeerKey = @(conversation.conversationId);
    if (_dialogListPreheatedConversations[preheatPeerKey] == conversation)
        return;
    _dialogListPreheatedConversations[preheatPeerKey] = conversation;

    if (_dialogListPreheatedRenderKeys == nil)
        _dialogListPreheatedRenderKeys = [[OGMemoryCache alloc] initWithCountLimit:512 costLimit:OGMemoryCacheBudget(2 * 1024 * 1024)];
    NSDictionary *data = conversation.dialogListData;
    int isSavedMessages = [data[@"isSavedMessages"] intValue];
    NSString *title = isSavedMessages ? TGLocalized(@"DialogList.SavedMessages") : data[@"title"];
    NSDictionary *preview = data[@"preparedPreview"];
    NSString *message = preview != nil ? preview[@"text"] : conversation.text;
    NSString *author = data[@"authorName"];
    if ([author isEqualToString:authorNameYou])
        author = TGLocalized(@"DialogList.You");
    bool hideAuthor = preview != nil ? [preview[@"hideAuthor"] boolValue] : (![data[@"isChat"] boolValue] || (conversation.isChannel && !conversation.isChannelGroup));
    if (hideAuthor)
        author = nil;
    NSString *status = TGDialogListBrandedStatusText(conversation);
    bool unread = TGDialogListPreviewMessageUnread(conversation);
    int unreadCount = conversation.unreadCount;
    int serviceUnreadCount = conversation.serviceUnreadCount;
    if ([_dialogListCompanion isConversationOpened:conversation.conversationId])
    {
        unreadCount = 0;
        serviceUnreadCount = 0;
    }
    else if (conversation.unreadMentionCount == 1 && unreadCount + serviceUnreadCount == 1 && [TGMessage containsUnseenMention:conversation.messageFlags])
    {
        unreadCount = 0;
        serviceUnreadCount = 0;
    }
    TGDatabaseMessageDraft *draft = data[@"draft"];
    bool hasDraft = draft != nil && ![draft isEmpty];
    if (hasDraft && unreadCount + serviceUnreadCount == 0)
    {
        message = draft.text;
        author = TGLocalized(@"DialogList.Draft");
    }
    bool branded = [TGPresentation brandedIOS6Style];
    bool classic = [TGPresentation classicThemeStyle];
    bool encrypted = [data[@"isEncrypted"] boolValue];
    bool muted = [data[@"mute"] boolValue];
    bool verified = [data[@"isVerified"] boolValue];
    bool premium = [data[@"isPremium"] boolValue] && !isSavedMessages;
    bool emojiStatus = [data[@"emojiStatusDocumentId"] longLongValue] != 0 && !isSavedMessages;
    bool pinned = conversation.pinnedToTop && !_dialogListCompanion.feedChannels;
    bool unreadMark = conversation.unreadMark;
    int mentions = conversation.unreadMentionCount;
    TGMessageDeliveryState delivery = conversation.deliveryError ? TGMessageDeliveryStateFailed : conversation.deliveryState;
    bool showsDeliveryStatus = conversation.outgoing && (!hasDraft || unreadCount + serviceUnreadCount != 0) && !isSavedMessages && (delivery == TGMessageDeliveryStatePending || (!branded && delivery == TGMessageDeliveryStateDelivered));
    NSString *dateText = conversation.unpinnedDate == 0 || isSavedMessages == 2 ? nil : [TGDateUtils stringForMessageListDate:(int)conversation.unpinnedDate relativeToDate:(int)OGRemoteClockTime()];
    if (conversation.isAd)
        dateText = TGLocalized(@"DialogList.AdLabel");
    CGFloat communityInset = conversation.linkedCommunityId == 0 ? 0.0f : [TGDialogListCell communityContentInsetForContainerWidth:width];
    CGFloat renderWidth = MAX(0.0f, width - communityInset);
    TGPresentation *presentation = _presentation;
    title = [title copy];
    message = [message copy];
    author = [author copy];
    status = [status copy];
    dateText = [dateText copy];
    TGEmojiRenderMode emojiMode = TGCurrentEmojiRenderMode();
    NSArray *key = @[presentation, @(renderWidth), @(emojiMode), @(branded), @(classic), title ?: @"", message ?: @"", author ?: @"", status ?: @"", dateText ?: @"", @(unread), @(unreadCount), @(serviceUnreadCount), @(unreadMark), @(mentions), @(pinned), @(muted), @(verified), @(premium), @(emojiStatus), @(encrypted), @(delivery), @(showsDeliveryStatus)];
    NSNumber *preparedGeneration = [_dialogListPreheatedRenderKeys objectForKey:key];
    if (preparedGeneration != nil && preparedGeneration.unsignedLongLongValue == [TGDialogListCell renderCacheGeneration])
        return;
    OGMemoryCache *prepared = _dialogListPreheatedRenderKeys;
    OGRuntimeDispatchPreload(@[@"dialog", _ogLifetimeReference, @(conversation.conversationId)], ^
    {
        [TGDialogListCell prewarmTitleText:title messageText:message authorName:author statusText:status width:renderWidth presentation:presentation unread:unread unreadCount:unreadCount serviceUnreadCount:serviceUnreadCount unreadMark:unreadMark unreadMentionCount:mentions pinned:pinned muted:muted verified:verified premium:premium emojiStatus:emojiStatus deliveryState:delivery dateText:dateText encrypted:encrypted showsDeliveryStatus:showsDeliveryStatus branded:branded classic:classic];
        if (emojiMode == TGCurrentEmojiRenderMode())
            [prepared setObject:@([TGDialogListCell renderCacheGeneration]) forKey:key cost:512 + (title.length + message.length + author.length + status.length + dateText.length) * sizeof(unichar)];
    });
}

- (void)dialogListPrefetchAroundIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath == nil || indexPath.section == 0)
        return;

    NSString *filter = [self dialogListAvatarFilter];
    NSInteger count = (NSInteger)[self dialogListDisplayedItems].count;
    NSInteger backCount = 6;
    NSInteger forwardCount = 32;
    if (_dialogListFastScrolling)
    {
        NSInteger lookAhead = TGDialogListSingleCoreDevice() ? 3 : 6;
        if (_dialogListFastScrollDirection < 0)
        {
            backCount = lookAhead;
            forwardCount = 0;
        }
        else
        {
            backCount = 0;
            forwardCount = lookAhead;
        }
    }
    else
    {
        switch (devicePerformanceClass())
        {
            case TGPerformanceClassConstrained: backCount = 2; forwardCount = 10; break;
            case TGPerformanceClassBalanced: backCount = 4; forwardCount = 24; break;
            case TGPerformanceClassFast: backCount = 6; forwardCount = 32; break;
            case TGPerformanceClassHigh: backCount = 8; forwardCount = 48; break;
        }
    }
    NSInteger start = MAX(0, indexPath.row - backCount);
    NSInteger end = MIN(count - 1, indexPath.row + forwardCount);
    if (end < start)
        return;

    for (NSInteger row = start; row <= end; row++)
    {
        id item = [self og_dialogListItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:indexPath.section]];
        if ([item isKindOfClass:[TGConversation class]])
        {
            TGConversation *conversation = (TGConversation *)item;
            [self dialogListPreheatConversation:conversation width:_tableView.bounds.size.width];
            [self dialogListPrefetchAvatarUrl:conversation.dialogListData[@"avatarUrl"] filter:filter];
        }
        else if ([item isKindOfClass:[TGFeed class]])
        {
            NSInteger limit = MIN((NSInteger)((TGFeed *)item).chatPhotosSmall.count, 4);
            for (NSInteger i = 0; i < limit; i++)
                [self dialogListPrefetchAvatarUrl:((TGFeed *)item).chatPhotosSmall[i] filter:@"circle:29x29"];
        }
    }
}


- (void)dialogListPrimeVisibleRenderCache
{
    if (_tableView == nil || [self dialogListDisplayedItems].count == 0)
        return;

    NSArray *visibleIndexPaths = [_tableView indexPathsForVisibleRows];
    if (visibleIndexPaths.count == 0)
    {
        [self dialogListPrefetchAroundIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
        return;
    }

    NSIndexPath *first = [visibleIndexPaths objectAtIndex:0];
    NSIndexPath *last = visibleIndexPaths.lastObject;
    [self dialogListPrefetchAroundIndexPath:first];
    if (![last isEqual:first])
        [self dialogListPrefetchAroundIndexPath:last];
    [self dialogListScheduleFullPreheat];
}

- (void)dialogListScheduleFullPreheat
{
    _dialogListFullPreheatGeneration++;
    [self dialogListContinueFullPreheat:_dialogListFullPreheatGeneration offset:0];
}

- (void)dialogListContinueFullPreheat:(NSUInteger)generation offset:(NSUInteger)offset
{
    if (generation != _dialogListFullPreheatGeneration || _tableView == nil || _tableView.window == nil)
        return;

    TGDialogListControllerReference *reference = _ogLifetimeReference;
    if (_dialogListFastScrolling)
    {
        TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
        {
            [reference withValue:^(void *value)
            {
                [(__bridge TGDialogListController *)value dialogListContinueFullPreheat:generation offset:offset];
            }];
        });
        return;
    }

    NSArray *items = [self dialogListDisplayedItems];
    NSUInteger limit = MIN(items.count, (NSUInteger)200);
    NSUInteger end = MIN(limit, offset + 6);
    CGFloat width = _tableView.bounds.size.width;
    for (NSUInteger index = offset; index < end; index++)
    {
        id item = items[index];
        if ([item isKindOfClass:[TGConversation class]])
            [self dialogListPreheatConversation:(TGConversation *)item width:width];
    }
    if (end >= limit)
        return;

    TGDispatchAfter(0.016, dispatch_get_main_queue(), ^
    {
        [reference withValue:^(void *value)
        {
            [(__bridge TGDialogListController *)value dialogListContinueFullPreheat:generation offset:end];
        }];
    });
}

#pragma mark -

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        int listCount = (int)[self dialogListDisplayedItems].count;
        bool folderPreloadActive = [_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]] && [(TGTelegraphDialogListCompanion *)_dialogListCompanion ios6FolderPreloadActive];
        bool nearBottom = listCount != 0 && (listCount < 10 || indexPath.row >= listCount - 10);
        bool constrainedFastScroll = OGPlatformUsesConstrainedBackgroundExecution() && TGDialogListSingleCoreDevice() && _dialogListFastScrolling;
        bool selectedFilterNeedsHistory = _ogSelectedDialogFilterId == 0 || [self og_selectedDialogFilterNeedsHistoryScan];
        bool localFolderSourcePending = _ogSelectedDialogFilterId != 0 && selectedFilterNeedsHistory && !_ogFolderLocalSourceExhausted;
        if (!constrainedFastScroll && nearBottom && localFolderSourcePending && !_ogAllDialogItemsLoading)
        {
            [self og_refreshAllDialogItems:false];
        }
        else if (!constrainedFastScroll && selectedFilterNeedsHistory && !localFolderSourcePending && !folderPreloadActive && !_ogArchiveExpanded && _canLoadMore && !_isLoading && nearBottom)
        {
            [self og_scheduleLazyLoadMoreItems:15];
        }
        
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
            [dialogCell setFastScrolling:_dialogListFastScrolling];
            [self dialogListPrefetchAroundIndexPath:indexPath];
            
            if (dialogCell.conversationId == _scheduledHighlightAnimationConversationId)
            {
                _scheduledHighlightAnimationConversationId = 0;
                [dialogCell animateHighlight];
            }
            
            [self applyConversationCellBackground:dialogCell];
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        if (indexPath.section == 0)
            return false;
        
        id displayedRow = [self og_dialogListItemAtIndexPath:indexPath];
        if ([displayedRow isKindOfClass:[TGFeed class]]) {
            return true;
        }
        if ([displayedRow isKindOfClass:[TGConversation class]]) {
            TGConversation *item = displayedRow;
            if (item.isAd) {
                return false;
            }
            if ([self og_isArchiveHeaderItem:displayedRow]) {
                return false;
            }
            return true;
        } else {
            return false;
        }
    }
    else
    {
        id result = [_searchResultsSections[indexPath.section][@"items"] objectAtIndex:indexPath.row];
        if ([result isKindOfClass:[TGDialogListRecentPeers class]]) {
            return false;
        }
        
        if ([_searchResultsSections[indexPath.section][@"type"] isEqualToString:@"recent"])
            return true;
    }
        
    return false;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    if (tableView == _tableView) {
        if (!tableView.editing) {
            return UITableViewCellEditingStyleNone;
        }
    }
    return UITableViewCellEditingStyleDelete;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_tableView != tableView) {
        id result = [_searchResultsSections[indexPath.section][@"items"] objectAtIndex:indexPath.row];
        if ([result isKindOfClass:[TGDialogListRecentPeers class]]) {
            return false;
        }
    }
    else
    {
        for (NSIndexPath *indexPath in [_tableView indexPathsForVisibleRows]) {
            TGDialogListCell *cell = (TGDialogListCell *)[_tableView cellForRowAtIndexPath:indexPath];
            if ([cell isKindOfClass:[TGDialogListCell class]]) {
                if ([cell isEditingControlsTracking]) {
                    return false;
                }
            }
        }
    }
    return true;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        id item = [self og_dialogListItemAtIndexPath:indexPath];
        return [item isKindOfClass:[TGConversation class]] || [item isKindOfClass:[TGFeed class]];
    }
    return true;
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    if (tableView == _tableView)
    {
        [self setupEditingMode:true setupTable:false];
        [self updateBarButtonItemsAnimated:true];
    }
}

#pragma mark -

- (UITableView *)createTableViewForSearchMixin:(TGSearchDisplayMixin *)__unused searchMixin
{
    UITableView *tableView = [[UITableView alloc] init];
    
    tableView.backgroundColor = self.presentation.pallete.backgroundColor;
    tableView.delegate = self;
    tableView.dataSource = self;
    
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    if (iosMajorVersion() >= 7) {
        tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        tableView.separatorColor = self.presentation.pallete.separatorColor;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        tableView.separatorInset = UIEdgeInsetsMake(0.0f, 80.0f, 0.0f, 0.0f);
#endif
    }
    
    if (tableView.tableFooterView == nil)
        tableView.tableFooterView = [[UIView alloc] init];
    
    return tableView;
}

- (UIView *)referenceViewForSearchResults
{
    return _tableView;
}

- (void)searchMixin:(TGSearchDisplayMixin *)__unused searchMixin hasChangedSearchQuery:(NSString *)searchQuery withScope:(int)__unused scope
{
    if (searchQuery.length == 0)
    {
        [_searchDisposable setDisposable:nil];
        _searchResultsSections = _recentSearchResultsSections;
        [_searchMixin reloadSearchResults];
        [_searchMixin setSearchResultsTableViewHidden:false];
    }
    else
    {
        if (_searchDisposable == nil)
            _searchDisposable = [[SMetaDisposable alloc] init];
        __weak TGDialogListController *weakSelf = self;
        _searchBar.delayActivity = false;
        _searchBar.showActivity = true;
        [_searchDisposable setDisposable:[[[TGGlobalMessageSearchSignals search:searchQuery includeMessages:!_dialogListCompanion.forwardMode itemMapping:^id(id item)
        {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil)
                return [strongSelf.dialogListCompanion processSearchResultItem:item];
            return nil;
        }] onDispose:^
        {
            TGDispatchOnMainThread(^
            {
                __strong TGDialogListController *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    strongSelf->_searchBar.showActivity = false;
                }
            });
        }] startWithNext:^(NSDictionary *result)
        {
            TGDispatchOnMainThread(^
            {
                __strong TGDialogListController *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    if ([searchQuery isEqualToString:strongSelf->_searchBar.text]) {
                        [strongSelf searchResultsReloaded:result searchString:searchQuery];
                    }
                }
            });
        } error:^(__unused id error)
        {
            TGDispatchOnMainThread(^
            {
                __strong TGDialogListController *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    strongSelf->_searchBar.showActivity = false;
                }
            });
        } completed:^
        {
            TGDispatchOnMainThread(^
            {
                __strong TGDialogListController *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    strongSelf->_searchBar.showActivity = false;
                }
            });
        }]];
    }
}

- (bool)filterDialog:(id)peer
{
    int64_t peerId = [peer isKindOfClass:[TGConversation class]] ? ((TGConversation *)peer).conversationId : ((TGUser *)peer).uid;
    if (!TGPeerIdIsUser(peerId) && self.dialogListCompanion.showPrivateOnly)
        return true;
    else if ((!TGPeerIdIsGroup(peerId) && !TGPeerIdIsChannel(peerId)) && self.dialogListCompanion.showGroupsAndChannelsOnly)
        return true;
    else if ([self.dialogListCompanion.excludedIds containsObject:@(peerId)])
        return true;
    
    return false;
}

- (NSArray *)filteredDialogs:(NSArray *)dialogs
{
    if (dialogs == nil)
        return @[];
    
    if (!self.dialogListCompanion.showPrivateOnly && !self.dialogListCompanion.showGroupsAndChannelsOnly && self.dialogListCompanion.excludedIds.count == 0)
        return dialogs;
    
    NSMutableArray *newDialogs = [[NSMutableArray alloc] init];
    for (id peer in dialogs)
    {
        if ([peer isKindOfClass:[TGDialogListRecentPeers class]])
        {
            TGDialogListRecentPeers *recentPeers = (TGDialogListRecentPeers *)peer;
            NSArray *newPeers = [self filteredDialogs:recentPeers.peers];
            if (newPeers.count > 0)
            {
                TGDialogListRecentPeers *newRecentPeers = [[TGDialogListRecentPeers alloc] initWithIdentifier:recentPeers.identifier title:recentPeers.title peers:newPeers];
                [newDialogs addObject:newRecentPeers];
            }
        }
        else
        {
            if (![self filterDialog:peer])
                [newDialogs addObject:peer];
        }
    }
    return newDialogs;
}

- (NSArray *)filteredSearchSections:(NSArray *)sections
{
    if (!self.dialogListCompanion.showPrivateOnly && !self.dialogListCompanion.showGroupsAndChannelsOnly && self.dialogListCompanion.excludedIds.count == 0)
        return sections;
    
    NSMutableArray *newSections = [[NSMutableArray alloc] init];
    for (NSDictionary *dict in sections) {
        NSArray *items = [self filteredDialogs:dict[@"items"]];
        NSMutableDictionary *newDict = [dict mutableCopy];
        newDict[@"items"] = items;
        
        [newSections addObject:newDict];
    }
    
    return newSections;
}

- (void)searchMixinWillActivate:(bool)animated
{
    _isDisplayingSearch = true;
    [self og_layoutFolderTabs];
    _tableView.scrollEnabled = false;
    
    _emptyListContainer.hidden = true;
    
    if (iosMajorVersion() >= 11)
    {
        if (animated)
            [self setNavigationBarHidden:true withAnimation:TGViewControllerNavigationBarAnimationSlideFar duration:0.3];
        else
            [self setNavigationBarHidden:true animated:false];
    }
    else
    {
        [self setNavigationBarHidden:true animated:animated];
    }
    [self setPrimaryTitlePanel:nil fade:true];
    
    if (_recentSearchResultsDisposable == nil)
        _recentSearchResultsDisposable = [[SMetaDisposable alloc] init];
    
    __weak TGDialogListController *weakSelf = self;
    SSignal *updatedRecentPeers = [[TGRecentPeersSignals updateRecentPeers] mapToSignal:^SSignal *(__unused id next) {
        return [SSignal complete];
    }];
    
    [_recentSearchResultsDisposable setDisposable:[[[SSignal mergeSignals:@[[TGGlobalMessageSearchSignals recentPeerResults:^id (id item, bool recent) {
        __strong TGDialogListController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            if (!recent && [item isKindOfClass:[TGConversation class]] && ((TGConversation *)item).conversationId == TGTelegraphInstance.clientUserId)
                return nil;

            return [strongSelf.dialogListCompanion processSearchResultItem:item];
        }
        return nil;
    } ratedPeers:true], updatedRecentPeers]] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *peerResults)
    {
        __strong TGDialogListController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            NSMutableArray *searchResultsSections = [[NSMutableArray alloc] init];
            
            if (peerResults.count != 0)
            {
                NSMutableArray *genericResuts = [[NSMutableArray alloc] init];
                for (id result in peerResults) {
                    if ([result isKindOfClass:[TGDialogListRecentPeers class]]) {
                        TGDialogListRecentPeers *recentPeers = result;
                        [searchResultsSections addObject:@{@"items": @[recentPeers], @"type": @"recent"}];
                    } else {
                        [genericResuts addObject:result];
                    }
                }
                if (genericResuts.count != 0) {
                    [searchResultsSections addObject:@{@"title": TGLocalized(@"DialogList.SearchSectionRecent"), @"items": genericResuts, @"type": @"recent"}];
                }
            }
            
            strongSelf->_recentSearchResultsSections = [strongSelf filteredSearchSections:searchResultsSections];
            
            if (strongSelf->_searchBar.text.length == 0) {
                strongSelf->_searchResultsSections = strongSelf->_recentSearchResultsSections;
                
                [strongSelf->_searchMixin reloadSearchResults];
                [strongSelf->_searchMixin setSearchResultsTableViewHidden:false animated:true];
            }
        }
    }]];
    
    [_searchMixin reloadSearchResults];
    [_searchMixin setSearchResultsTableViewHidden:false animated:true];
}

- (void)searchMixinWillDeactivate:(bool)animated
{
    _isDisplayingSearch = false;
    [self og_layoutFolderTabs];
    _tableView.scrollEnabled = true;
    
    _emptyListContainer.hidden = false;
    
    [_recentSearchResultsDisposable setDisposable:nil];
    
    [self setNavigationBarHidden:false animated:animated];
    [self setPrimaryTitlePanel:_currentTitlePanel fade:false];
    
    if (_displayProxyIssuesTooltip)
    {
        if ([self isVisible])
        {
            TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
            {
                _displayProxyIssuesTooltip = false;
                [self displayProxyTooltip];
            });
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{

    if (scrollView != _tableView)
        return;

    if (_dialogListFastScrolling)
    {
        CGFloat currentOffset = scrollView.contentOffset.y;
        CGFloat delta = currentOffset - _dialogListLastScrollOffset;
        if (ABS(delta) >= 1.0f)
            _dialogListFastScrollDirection = delta < 0.0f ? -1 : 1;
        _dialogListLastScrollOffset = currentOffset;
    }
    
    if ((scrollView.isDragging || scrollView.isTracking) && _scrollingToConversationId != 0)
        _scrollingToConversationId = 0;

    if ((scrollView.isDragging || scrollView.isTracking) && !_ogSearchPullArmed && !_searchMixin.isActive && !_doNotHideSearchAutomatically && _searchBar != nil)
    {
        CGFloat hiddenOffset = -_tableView.contentInset.top + [self onegramSearchHeaderHeight] + self.explicitTableInset.top;
        if (scrollView.contentOffset.y < hiddenOffset)
            scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, hiddenOffset);
    }
    
    if (!_ogRefreshing)
        [self og_updateRefreshPullWithOverscroll:[self og_refreshOverscroll]];

    bool atTop = scrollView.contentOffset.y <= -_tableView.tableHeaderView.frame.size.height + FLT_EPSILON;
    if (_atTopValue != atTop)
    {
        _atTopValue = atTop;
        [_atTopPromise set:[SSignal single:@(atTop)]];
    }

}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if (scrollView == _tableView)
    {
        _scrollingToConversationId = 0;
        [self dialogListSetFastScrolling:false];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{

    if (scrollView == _tableView && !decelerate)
    {
        if (OGDiagnosticsEnabled())
            [self dialogListLogVisibleCellState:@"drag"];
        [self dialogListSetFastScrolling:false];
        if (OGPlatformUsesConstrainedBackgroundExecution() && TGDialogListSingleCoreDevice())
        {
            OGPlatformDispatchOnMainThreadAfter(0.08, ^
            {
                if (!_dialogListFastScrolling)
                    [self dialogListPrimeVisibleRenderCache];
            });
        }
        else
        {
            [self dialogListPrimeVisibleRenderCache];
        }
        if (_ogFolderTabsUpdatePending)
            [self og_updateFolderTabs];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{

    if (scrollView == _tableView)
    {
        if (OGDiagnosticsEnabled())
            [self dialogListLogVisibleCellState:@"decelerate"];
        [self dialogListSetFastScrolling:false];
        if (OGPlatformUsesConstrainedBackgroundExecution() && TGDialogListSingleCoreDevice())
        {
            OGPlatformDispatchOnMainThreadAfter(0.08, ^
            {
                if (!_dialogListFastScrolling)
                    [self dialogListPrimeVisibleRenderCache];
            });
        }
        else
        {
            [self dialogListPrimeVisibleRenderCache];
        }
        if (_ogFolderTabsUpdatePending)
            [self og_updateFolderTabs];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{

    if (scrollView == _tableView)
    {
        _dialogListFastScrollDirection = 0;
        _dialogListLastScrollOffset = scrollView.contentOffset.y;
        [self dialogListSetFastScrolling:true];
        _draggingStartOffset = scrollView.contentOffset.y;
        CGFloat hiddenOffset = -_tableView.contentInset.top + [self onegramSearchHeaderHeight] + self.explicitTableInset.top;
        _ogSearchPullArmed = _searchBar != nil && scrollView.contentOffset.y <= hiddenOffset + 1.0f;
    }
    
    if (_searchMixin.isActive && scrollView == _searchMixin.searchResultsTableView)
        [_searchBar resignFirstResponder];

}

- (CGFloat)onegramSearchHeaderHeight
{
    return _searchBar != nil && _tableView.tableHeaderView == _searchBar ? TGDialogListSearchBarHeight() : 0.0f;
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)__unused velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (scrollView == _tableView)
    {
        bool refreshTriggered = [self og_refreshAvailable] && !_ogRefreshing && [self og_refreshOverscroll] >= [self og_refreshThreshold];
        if (refreshTriggered)
            [self og_beginRefresh];
        else if ([self og_archivePullAvailable] && scrollView.contentOffset.y < -_tableView.contentInset.top + self.explicitTableInset.top - 90.0f)
        {
            __weak TGDialogListController *weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^
            {
                __strong TGDialogListController *strongSelf = weakSelf;
                if (strongSelf != nil && !strongSelf->_ogArchiveExpanded)
                    [strongSelf archiveButtonPressed:nil];
            });
        }
        if (targetContentOffset != NULL)
        {
            CGFloat shownOffset = -_tableView.contentInset.top + self.explicitTableInset.top;
            CGFloat searchHeight = [self onegramSearchHeaderHeight];
            CGFloat hiddenOffset = shownOffset + searchHeight;

            if (!_ogSearchPullArmed && !_searchMixin.isActive && !_doNotHideSearchAutomatically && _searchBar != nil && targetContentOffset->y < hiddenOffset)
            {
                targetContentOffset->y = hiddenOffset;
            }
            else if (targetContentOffset->y > shownOffset - FLT_EPSILON && targetContentOffset->y < hiddenOffset + FLT_EPSILON)
            {
                if (_draggingStartOffset < shownOffset + searchHeight * 0.5f)
                {
                    if (targetContentOffset->y < shownOffset + searchHeight * 0.2f)
                        targetContentOffset->y = shownOffset;
                    else
                        targetContentOffset->y = hiddenOffset;
                }
                else
                {
                    if (targetContentOffset->y < shownOffset + searchHeight * 0.8f)
                        targetContentOffset->y = shownOffset;
                    else
                        targetContentOffset->y = hiddenOffset;
                }
            }
        }
    }
}

- (bool)og_archivePullAvailable
{
    return [TGOnegramSettings boolForKey:TGOnegramSettingGeneralHideArchive] && !_ogArchiveExpanded && _ogSelectedDialogFilterId == 0 && !_searchMixin.isActive && !_editingMode;
}

- (bool)og_refreshAvailable
{
    return _tableView != nil && [self og_foldersAllowed] && !_dialogListCompanion.forwardMode && !_dialogListCompanion.feedChannels && !_searchMixin.isActive && !_isDisplayingSearch && !_editingMode && !_ogFolderSwipeActive && !_ogFolderSwipeFinishing && TGTelegraphInstance.clientUserId != 0;
}

- (CGFloat)og_refreshOverscroll
{
    if (_tableView == nil)
        return 0.0f;
    CGFloat shownOffset = -_tableView.contentInset.top + self.explicitTableInset.top;
    return MAX(0.0f, shownOffset - _tableView.contentOffset.y);
}

- (CGFloat)og_refreshThreshold
{
    return [self og_archivePullAvailable] ? 130.0f : 70.0f;
}

- (void)og_loadRefreshViewsIfNeeded
{
    if (_ogRefreshContainerView != nil || _tableView == nil)
        return;

    CGFloat side = 36.0f;
    _ogRefreshContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    _ogRefreshContainerView.clipsToBounds = true;
    _ogRefreshContainerView.userInteractionEnabled = false;
    _ogRefreshContainerView.backgroundColor = [UIColor clearColor];
    _ogRefreshContainerView.hidden = true;
    [self.view insertSubview:_ogRefreshContainerView aboveSubview:_tableView];

    _ogRefreshBadgeView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, -side, side, side)];
    _ogRefreshBadgeView.layer.cornerRadius = side / 2.0f;
    _ogRefreshBadgeView.layer.borderWidth = TGScreenPixel;
    [_ogRefreshContainerView addSubview:_ogRefreshBadgeView];

    _ogRefreshProgressLayer = [CAShapeLayer layer];
    _ogRefreshProgressLayer.frame = CGRectMake(0.0f, 0.0f, side, side);
    _ogRefreshProgressLayer.fillColor = [UIColor clearColor].CGColor;
    _ogRefreshProgressLayer.lineWidth = 2.5f;
    _ogRefreshProgressLayer.lineCap = kCALineCapRound;
    [_ogRefreshBadgeView.layer addSublayer:_ogRefreshProgressLayer];

    _ogRefreshActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _ogRefreshActivityIndicator.hidesWhenStopped = true;
    _ogRefreshActivityIndicator.center = CGPointMake(side / 2.0f, side / 2.0f);
    [_ogRefreshBadgeView addSubview:_ogRefreshActivityIndicator];
}

- (void)og_updateRefreshAppearance
{
    TGPresentationPallete *pallete = self.presentation.pallete;
    _ogRefreshBadgeView.backgroundColor = pallete.collectionMenuCellBackgroundColor ?: pallete.backgroundColor;
    _ogRefreshBadgeView.layer.borderColor = (pallete.collectionMenuSeparatorColor ?: pallete.separatorColor).CGColor;
    _ogRefreshProgressLayer.strokeColor = pallete.accentColor.CGColor;
    _ogRefreshActivityIndicator.activityIndicatorViewStyle = pallete.isDark ? UIActivityIndicatorViewStyleWhite : UIActivityIndicatorViewStyleGray;
}

- (void)og_layoutRefreshContainer
{
    CGRect contentRect = [self og_folderSwipeContentRect];
    if (CGRectIsEmpty(contentRect))
        contentRect = CGRectMake(0.0f, self.controllerInset.top, self.view.bounds.size.width, MAX(0.0f, self.view.bounds.size.height - self.controllerInset.top));
    _ogRefreshContainerView.frame = contentRect;
}

- (void)og_setRefreshProgress:(CGFloat)progress
{
    CGFloat side = _ogRefreshBadgeView.bounds.size.width;
    CGFloat radius = 10.0f;
    CGFloat startAngle = -(CGFloat)M_PI_2;
    CGMutablePathRef path = CGPathCreateMutable();
    if (progress > FLT_EPSILON)
        CGPathAddArc(path, NULL, side / 2.0f, side / 2.0f, radius, startAngle, startAngle + (CGFloat)(M_PI * 2.0) * MIN(1.0f, progress), false);
    _ogRefreshProgressLayer.path = path;
    CGPathRelease(path);
}

- (void)og_updateRefreshPullWithOverscroll:(CGFloat)overscroll
{
    if (overscroll <= FLT_EPSILON || ![self og_refreshAvailable])
    {
        _ogRefreshContainerView.hidden = true;
        return;
    }

    [self og_loadRefreshViewsIfNeeded];
    if (_ogRefreshContainerView.hidden)
    {
        [self og_updateRefreshAppearance];
        [self og_layoutRefreshContainer];
        _ogRefreshContainerView.hidden = false;
    }

    CGFloat progress = MIN(1.0f, overscroll / [self og_refreshThreshold]);
    CGFloat side = _ogRefreshBadgeView.bounds.size.width;
    CGFloat restingY = 14.0f;
    [CATransaction begin];
    [CATransaction setDisableActions:true];
    _ogRefreshBadgeView.frame = CGRectMake(CGFloor((_ogRefreshContainerView.bounds.size.width - side) / 2.0f), -side + (side + restingY) * progress, side, side);
    _ogRefreshBadgeView.alpha = progress;
    [self og_setRefreshProgress:progress];
    [CATransaction commit];
}

- (void)og_beginRefresh
{
    [self og_loadRefreshViewsIfNeeded];
    if (_ogRefreshContainerView == nil)
        return;

    _ogRefreshing = true;
    _ogRefreshSawActivity = false;
    _ogRefreshStartTime = CFAbsoluteTimeGetCurrent();
    NSUInteger generation = ++_ogRefreshGeneration;

    [self og_updateRefreshAppearance];
    [self og_layoutRefreshContainer];
    _ogRefreshContainerView.hidden = false;
    CGFloat side = _ogRefreshBadgeView.bounds.size.width;
    _ogRefreshBadgeView.frame = CGRectMake(CGFloor((_ogRefreshContainerView.bounds.size.width - side) / 2.0f), 14.0f, side, side);
    _ogRefreshBadgeView.alpha = 1.0f;
    [self og_setRefreshProgress:0.0f];
    [_ogRefreshActivityIndicator startAnimating];

    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [ActionStageInstance() requestActor:@"/tg/service/updatestate" options:nil watcher:TGTelegraphInstance];
    }];

    if (_ogRefreshDisposable == nil)
        _ogRefreshDisposable = [[SMetaDisposable alloc] init];
    __weak TGDialogListController *weakSelf = self;
    [_ogRefreshDisposable setDisposable:[[[TGSynchronizationStateSignal synchronizationState] deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *value)
    {
        __strong TGDialogListController *strongSelf = weakSelf;
        if (strongSelf == nil || !strongSelf->_ogRefreshing || strongSelf->_ogRefreshGeneration != generation)
            return;
        if ((TGSynchronizationStateValue)[value intValue] != TGSynchronizationStateSynchronized)
            strongSelf->_ogRefreshSawActivity = true;
        else if (strongSelf->_ogRefreshSawActivity)
            [strongSelf og_completeRefreshForGeneration:generation];
    }]];

    TGDispatchAfter(1.2, dispatch_get_main_queue(), ^
    {
        __strong TGDialogListController *strongSelf = weakSelf;
        if (strongSelf != nil && !strongSelf->_ogRefreshSawActivity)
            [strongSelf og_completeRefreshForGeneration:generation];
    });
    TGDispatchAfter(20.0, dispatch_get_main_queue(), ^
    {
        [weakSelf og_completeRefreshForGeneration:generation];
    });
}

- (void)og_completeRefreshForGeneration:(NSUInteger)generation
{
    if (!_ogRefreshing || _ogRefreshGeneration != generation)
        return;

    NSTimeInterval remaining = 0.6 - (CFAbsoluteTimeGetCurrent() - _ogRefreshStartTime);
    if (remaining > 0.0)
    {
        __weak TGDialogListController *weakSelf = self;
        TGDispatchAfter(remaining, dispatch_get_main_queue(), ^
        {
            [weakSelf og_completeRefreshForGeneration:generation];
        });
        return;
    }

    [self og_endRefreshAnimated:true];
}

- (void)og_endRefreshAnimated:(bool)animated
{
    if (!_ogRefreshing)
        return;

    _ogRefreshing = false;
    _ogRefreshGeneration++;
    [_ogRefreshDisposable setDisposable:nil];

    UIView *badgeView = _ogRefreshBadgeView;
    UIView *containerView = _ogRefreshContainerView;
    UIActivityIndicatorView *activityIndicator = _ogRefreshActivityIndicator;
    void (^completion)(void) = ^
    {
        [activityIndicator stopAnimating];
        containerView.hidden = true;
        badgeView.alpha = 1.0f;
    };

    if (!animated || containerView.hidden)
    {
        completion();
        return;
    }

    [UIView animateWithDuration:0.2 animations:^
    {
        badgeView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        if (!_ogRefreshing)
            completion();
    }];
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)__unused scrollView {
    return !TGTelegraphInstance.callManager.hasActiveCall;
}

#pragma mark -

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)__unused controller
{
    [_searchBar setSelectedScopeButtonIndex:0];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)__unused controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [_dialogListCompanion beginSearch:searchString inMessages:false];
    
    return FALSE;
}

- (void)searchDisplayController:(UISearchDisplayController *)__unused controller willShowSearchResultsTableView:(UITableView *)__unused tableView
{
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    if (iosMajorVersion() >= 7) {
        tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        tableView.separatorColor = TGSeparatorColor();
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        tableView.separatorInset = UIEdgeInsetsMake(0.0f, 80.0f, 0.0f, 0.0f);
#endif
    }
    
    if (tableView.tableFooterView == nil)
        tableView.tableFooterView = [[UIView alloc] init];
    
    tableView.hidden = true;
}

- (void)searchDisplayController:(UISearchDisplayController *)__unused controller willHideSearchResultsTableView:(UITableView *)tableView
{
    tableView.hidden = false;
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)__unused controller shouldReloadTableForSearchScope:(NSInteger)searchOption
{
    [_dialogListCompanion beginSearch:_searchBar.text inMessages:searchOption];
    
    return false;
}

- (void)startSearch
{
    [(TGListsTableView *)_tableView setBlockContentOffset:true];
    [_searchBar becomeFirstResponder];
    TGDispatchAfter(0.1f, dispatch_get_main_queue(), ^
    {
        [(TGListsTableView *)_tableView setBlockContentOffset:false];
        _tableView.contentOffset = CGPointMake(0, -_tableView.contentInset.top);
    });
}

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"conversationMenuOpened"])
    {
        int64_t conversationId = [[options objectForKey:@"conversationId"] longLongValue];
        for (NSIndexPath *indexPath in _tableView.indexPathsForVisibleRows)
        {
            UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPath];
            
            if ([cell isKindOfClass:[TGDialogListCell class]])
            {
                TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
                if (dialogCell.conversationId != conversationId)
                {
                    [dialogCell dismissEditingControls:true];
                }
                
                [cell setSelected:false];
                [cell setHighlighted:false];
            }
        }
        
        if (_tableView.indexPathForSelectedRow != nil)
            [_tableView deselectRowAtIndexPath:_tableView.indexPathForSelectedRow animated:false];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)__unused editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        TGConversation *conversation = nil;
        id item = [self og_dialogListItemAtIndexPath:indexPath];
        if ([item isKindOfClass:[TGConversation class]] || [item isKindOfClass:[TGFeed class]])
            conversation = item;
        
        if (conversation != nil)
        {
            int64_t conversationIdToDelete = conversation.conversationId;
            
            NSMutableArray *actions = [[NSMutableArray alloc] init];
            
            bool isBot = [conversation.dialogListData[@"isBot"] boolValue];

            if ([conversation isKindOfClass:[TGFeed class]])
            {
                [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"DialogList.UngroupAllChannels") action:@"delete" type:TGActionSheetActionTypeDestructive]];
            }
            else if (conversation.conversationId > 0 && isBot)
            {
                [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"DialogList.DeleteBotConfirmation") action:@"clear" type:TGActionSheetActionTypeGeneric]];
                
                [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"DialogList.DeleteBotConversationConfirmation") action:@"delete" type:TGActionSheetActionTypeDestructive]];
            }
            else
            {
                if (!conversation.isChannel || (conversation.isChannelGroup && conversation.username.length == 0)) {
                    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"DialogList.ClearHistoryConfirmation") action:@"clear" type:TGActionSheetActionTypeGeneric]];
                }
                
                [actions addObject:[[TGActionSheetAction alloc] initWithTitle:(conversation.isBroadcast || !conversation.isChat) ? TGLocalized(@"Common.Delete") : TGLocalized(@"DialogList.DeleteConversationConfirmation") action:@"delete" type:TGActionSheetActionTypeDestructive]];
            }

            [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];
            
            __weak TGDialogListController *weakSelf = self;
            TGCustomActionSheet *sheet = [[TGCustomActionSheet alloc] initWithTitle:nil actions:actions actionBlock:^(__unused id target, NSString *action) {
                __strong TGDialogListController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (conversationIdToDelete == 0)
                    return;
                
                if ([action isEqualToString:@"delete"])
                {
                    if (conversationIdToDelete != 0)
                    {
                        for (TGConversation *conversation in strongSelf->_listModel)
                        {
                            if (conversation.conversationId == conversationIdToDelete)
                            {
                                [strongSelf->_dialogListCompanion deleteItem:conversation animated:true];
                                break;
                            }
                        }
                    }
                }
                else if ([action isEqualToString:@"clear"])
                {
                    for (TGConversation *conversation in strongSelf->_listModel)
                    {
                        if (conversation.conversationId == conversationIdToDelete)
                        {
                            [strongSelf->_dialogListCompanion clearItem:conversation animated:true];
                            break;
                        }
                    }
                }
            } target:self];
            
            if (!TGIsPad())
            {
                [sheet showInView:self.navigationController.view];
            }
            else
            {
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                [sheet showFromRect:[tableView convertRect:cell.frame toView:self.view] inView:self.view animated:true];
            }
        }
    }
    else
    {
        id result = [_searchResultsSections[indexPath.section][@"items"] objectAtIndex:indexPath.row];
        if (![result isKindOfClass:[TGDialogListRecentPeers class]]) {
            int64_t peerId = 0;
            if ([result isKindOfClass:[TGConversation class]])
                peerId = ((TGConversation *)result).conversationId;
            else if ([result isKindOfClass:[TGUser class]])
                peerId = ((TGUser *)result).uid;
            
            if (peerId != 0)
            {
                [TGGlobalMessageSearchSignals removeRecentPeerResult:peerId];
                NSMutableArray *updatedSearchResultsSections = [[NSMutableArray alloc] initWithArray:_searchResultsSections];
                NSMutableDictionary *updatedSection = [[NSMutableDictionary alloc] initWithDictionary:_searchResultsSections[indexPath.section]];
                NSMutableArray *updatedItems = [[NSMutableArray alloc] initWithArray:updatedSection[@"items"]];
                [updatedItems removeObjectAtIndex:indexPath.row];
                if (updatedItems.count == 0)
                {
                    [updatedSearchResultsSections removeObjectAtIndex:indexPath.section];
                    _searchResultsSections = updatedSearchResultsSections;
                    
                    [tableView beginUpdates];
                    [tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
                    [tableView endUpdates];
                }
                else
                {
                    updatedSection[@"items"] = updatedItems;
                    updatedSearchResultsSections[indexPath.section] = updatedSection;
                    _searchResultsSections = updatedSearchResultsSections;
                    
                    [tableView beginUpdates];
                    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                    [tableView endUpdates];
                }
            }
        }
    }
}

- (void)_commitDeleteChannel:(TGConversation *)conversation {
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow show:true];
    
    [[[[TGChannelManagementSignals deleteChannel:conversation.conversationId accessHash:conversation.accessHash] deliverOn:[SQueue mainQueue]] onDispose:^{
        TGDispatchOnMainThread(^{
            [progressWindow dismiss:true];
        });
    }] startWithNext:nil error:^(__unused id error) {
        [TGAppDelegateInstance.rootController.dialogListController.dialogListCompanion deleteItem:[[TGConversation alloc] initWithConversationId:conversation.conversationId unreadCount:0 serviceUnreadCount:0] animated:false];
    } completed:^{
        [TGAppDelegateInstance.rootController.dialogListController.dialogListCompanion deleteItem:[[TGConversation alloc] initWithConversationId:conversation.conversationId unreadCount:0 serviceUnreadCount:0] animated:false];
    }];
}

- (void)localizationUpdated
{
    [_searchBar localizationUpdated];
    _searchBar.placeholder = TGLocalized(self.customSearchPlaceholder ?: @"DialogList.SearchLabel");
    
    _barButtonItemsApplied = false;
    [self updateBarButtonItemsAnimated:false];
    
    [self setTitleText:[self onegramDialogListTitle]];
    
    _titleLabel.text = [self onegramDialogListTitle];
    [_titleLabel sizeToFit];
    [self _layoutTitleViews:self.interfaceOrientation];
    
    for (id cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            [(TGDialogListCell *)cell resetLocalization];
            ((TGDialogListCell *)cell).reuseTag = -1;
            ((TGDialogListCell *)cell).preparedConversation = nil;
        }
        else if ([cell isKindOfClass:[TGDialogListBroadcastsMenuCell class]])
        {
            [(TGDialogListBroadcastsMenuCell *)cell resetLocalization];
        }
    }
    
    [self reloadData:false];
    
    _visibleConversationsPipe.sink(@true);
}

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    if (tableView == _tableView && !tableView.editing)
    {
        if (_editingMode)
        {
            [self setupEditingMode:false setupTable:false];
            [self updateBarButtonItemsAnimated:true];
        }
        [self selectCurrentConversation];
    }
}

- (void)selectCurrentConversation
{
    int index = -1;
    for (id item in [self dialogListDisplayedItems])
    {
        index++;
        if (![item isKindOfClass:[TGConversation class]])
            continue;
        TGConversation *conversation = (TGConversation *)item;
        if ([_dialogListCompanion isConversationOpened:conversation.conversationId])
        {
            [_tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:1] animated:false scrollPosition:UITableViewScrollPositionNone];
            break;
        }
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (tableView == _tableView)
    {
        CGFloat folderTabsHeight = [self og_folderTabsHeight];
        CGFloat playerHeight = [TGPresentation brandedIOS6Style] ? _ogPlayerHeight : 0.0f;
#if OG_PLUGINS_AVAILABLE
        if (section == 1)
        {
            UIView *original = nil;
            if (folderTabsHeight + playerHeight > FLT_EPSILON && _ogListHeaderView != nil)
            {
                [self og_layoutFolderTabs];
                original = _ogListHeaderView;
            }
            return OGPluginUIChatListSurfacesSectionView(self, original, folderTabsHeight + playerHeight, tableView.bounds.size.width);
        }
#else
        if (section == 1 && folderTabsHeight + playerHeight > FLT_EPSILON && _ogListHeaderView != nil)
        {
            [self og_layoutFolderTabs];
            return _ogListHeaderView;
        }
#endif
        return nil;
    }
    
    if (_searchResultsSections[section][@"title"] == nil || [(NSArray *)_searchResultsSections[section][@"items"] count] == 0)
        return nil;
    
    bool clear = false;
    if ([_searchResultsSections[section][@"type"] isEqual:@"recent"]) {
        NSArray *items = _searchResultsSections[section][@"items"];
        if (items.count != 0 && [items[0] isKindOfClass:[TGDialogListRecentPeers class]]) {
            clear = false;
        } else {
            clear = true;
        }
    }
    
    UIView *view = [self generateSectionHeader:_searchResultsSections[section][@"title"] first:false wide:true clear:clear];
    view.tag = 1000 + section;
    return view;
}

- (UIView *)generateSectionHeader:(NSString *)title first:(bool)first wide:(bool)wide clear:(bool)clear
{
    UIView *sectionContainer = nil;
    
    NSMutableArray *reusableList = [_reusableSectionHeaders objectAtIndex:first ? 0 : 1];
    
    for (UIView *view in reusableList)
    {
        if (view.superview == nil)
        {
            sectionContainer = view;
            break;
        }
    }
    
    if (sectionContainer == nil)
    {
        sectionContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        
        sectionContainer.clipsToBounds = false;
        sectionContainer.opaque = false;
        
        UIView *sectionView = [[UIView alloc] initWithFrame:CGRectMake(0, first ? 0 : -1, 10, first ? 10 : 11)];
        sectionView.tag = 50;
        sectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        sectionView.backgroundColor = self.presentation.pallete.barBackgroundColor;
        [sectionContainer addSubview:sectionView];
        
        
        UILabel *sectionLabel = [[UILabel alloc] init];
        sectionLabel.tag = 100;
        sectionLabel.backgroundColor = sectionView.backgroundColor;
        sectionLabel.textColor = [UIColor blackColor];
        sectionLabel.numberOfLines = 1;
        
        [sectionContainer addSubview:sectionLabel];
        
        [reusableList addObject:sectionContainer];
        
        TGModernButton *clearButton = [[TGModernButton alloc] init];
        clearButton.tag = 200;
        clearButton.exclusiveTouch = true;
        [clearButton setTitle:TGLocalized(@"WebSearch.RecentSectionClear") forState:UIControlStateNormal];
        [clearButton setTitleColor:UIColorRGB(0x8e8e93)];
        clearButton.titleLabel.font = TGSystemFontOfSize(12);
        [clearButton sizeToFit];
        CGRect clearButtonFrame = CGRectMake(0, 0, clearButton.frame.size.width + 27.0f, 26.0f);
        clearButtonFrame.origin.x = sectionContainer.frame.size.width - clearButtonFrame.size.width;
        clearButton.frame = clearButtonFrame;
        [clearButton setTag:200];
        [clearButton addTarget:self action:@selector(clearRecentButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [sectionContainer addSubview:clearButton];
    }
    
    UIView *sectionView = [sectionContainer viewWithTag:50];
    sectionView.backgroundColor = self.presentation.pallete.sectionHeaderBackgroundColor;
    
    UILabel *sectionLabel = (UILabel *)[sectionContainer viewWithTag:100];
    sectionLabel.font = wide ? TGBoldSystemFontOfSize(12.0f) : TGBoldSystemFontOfSize(17);
    sectionLabel.text = [title uppercaseString];
    sectionLabel.backgroundColor = sectionView.backgroundColor;
    sectionLabel.textColor = self.presentation.pallete.sectionHeaderTextColor;
    [sectionLabel sizeToFit];
    if (wide)
    {
        sectionLabel.frame = CGRectMake(14.0f + self.controllerSafeAreaInset.left, 6.0f + TGScreenPixel, sectionLabel.frame.size.width, sectionLabel.frame.size.height);
    }
    else
    {
        sectionLabel.frame = CGRectMake(14.0f + self.controllerSafeAreaInset.left, TGScreenPixel, sectionLabel.frame.size.width, sectionLabel.frame.size.height);
    }
    
    TGModernButton *clearButton = (TGModernButton *)[sectionContainer viewWithTag:200];
    CGRect clearButtonFrame = clearButton.frame;
    clearButtonFrame.origin.x = sectionContainer.frame.size.width - clearButtonFrame.size.width - self.controllerSafeAreaInset.right;
    clearButton.frame = clearButtonFrame;
    clearButton.hidden = !clear;
    [clearButton setTitleColor:self.presentation.pallete.sectionHeaderTextColor];
    
    return sectionContainer;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (tableView == _tableView)
#if OG_PLUGINS_AVAILABLE
        return section == 1 ? [self og_folderTabsHeight] + ([TGPresentation brandedIOS6Style] ? _ogPlayerHeight : 0.0f) + OGPluginUIChatListSurfacesSectionHeight(self) : 0.0f;
#else
        return section == 1 ? [self og_folderTabsHeight] + ([TGPresentation brandedIOS6Style] ? _ogPlayerHeight : 0.0f) : 0.0f;
#endif
    
    if (((NSString *)_searchResultsSections[section][@"title"]).length == 0 || [(NSArray *)_searchResultsSections[section][@"items"] count] == 0)
        return 0.0f;
    
    return 28.0f;
}

- (void)clearRecentButtonPressed
{
    [TGGlobalMessageSearchSignals clearRecentResults];
    [_recentSearchResultsDisposable setDisposable:nil];

    NSMutableArray *updatedRecentSearchResultsSections = [[NSMutableArray alloc] init];
    for (NSDictionary *dict in _recentSearchResultsSections) {
        NSArray *items = dict[@"items"];
        if (items.count == 1 && [items[0] isKindOfClass:[TGDialogListRecentPeers class]]) {
            [updatedRecentSearchResultsSections addObject:dict];
        }
    }
    
    _recentSearchResultsSections = updatedRecentSearchResultsSections;
    _searchResultsSections = _recentSearchResultsSections;
    
    [_searchMixin reloadSearchResults];
}

- (void)updateSearchConversations:(NSArray *)conversations
{
    if (_searchResultsSections.count != 0)
    {
        NSMutableDictionary *updatedConversations = [[NSMutableDictionary alloc] init];
        for (TGConversation *conversation in conversations)
        {
            updatedConversations[@(conversation.conversationId)] = conversation;
        }
        
        NSMutableArray *updatedSearchResultsSections = [[NSMutableArray alloc] initWithArray:_searchResultsSections];
        NSInteger index = -1;
        for (NSDictionary *section in _searchResultsSections)
        {
            index++;
            
            NSInteger itemIndex = -1;
            NSMutableArray *updatedItems = nil;
            for (id item in section[@"items"])
            {
                itemIndex++;
                
                if ([item isKindOfClass:[TGConversation class]])
                {
                    TGConversation *conversation = item;
                    if (conversation.additionalProperties[@"searchMessageId"] == nil) {
                        TGConversation *updatedConversation = updatedConversations[@(conversation.conversationId)];
                        if (updatedConversation != nil)
                        {
                            if (updatedItems == nil)
                                updatedItems = [[NSMutableArray alloc] initWithArray:section[@"items"]];
                            
                            [updatedItems replaceObjectAtIndex:itemIndex withObject:updatedConversation];
                        }
                    }
                }
            }
            
            if (updatedItems != nil)
            {
                NSMutableDictionary *updatedSection = [[NSMutableDictionary alloc] initWithDictionary:section];
                updatedSection[@"items"] = updatedItems;
                updatedSearchResultsSections[index] = updatedSection;
            }
        }
        _searchResultsSections = updatedSearchResultsSections;
        
        for (id cell in _searchMixin.searchResultsTableView.visibleCells)
        {
            if ([cell isKindOfClass:[TGDialogListSearchCell class]])
            {
                TGDialogListSearchCell *searchCell = cell;
                TGConversation *updatedConversation = updatedConversations[@(searchCell.conversationId)];
                if (updatedConversation != nil)
                {
                    searchCell.unreadCount = updatedConversation.unreadCount;
                    [searchCell resetView:false];
                }
            }
            else if ([cell isKindOfClass:[TGDialogListRecentPeersCell class]])
            {
                NSMutableDictionary *unreadCounts = [[NSMutableDictionary alloc] init];
                for (NSNumber *conversationId in updatedConversations)
                {
                    unreadCounts[conversationId] = @([updatedConversations[conversationId] unreadCount]);
                }
                
                [(TGDialogListRecentPeersCell *)cell updateUnreadCounts:unreadCounts];
            }
        }
    }
}

- (void)check3DTouch {
    if (_checked3dTouch) {
        return;
    }
    _checked3dTouch = true;
    if (iosMajorVersion() >= 9 && !_dialogListCompanion.forwardMode && !_dialogListCompanion.privacyMode) {
        if (iosMajorVersion() >= 9 && self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) {
            [self registerForPreviewingWithDelegate:(id)self sourceView:self.view];
        }
        else if (!TGIsPad())
        {
            __weak TGDialogListController *weakSelf = self;
            _custom3dTouchHandle = [TGPreviewMenu setupPreviewControllerForView:self.view configurator:^TGItemPreviewController *(CGPoint gestureLocation)
            {
                __strong TGDialogListController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return nil;
                
                UIViewController *conversationController = [strongSelf previewingContext:nil viewControllerForLocation:gestureLocation];
                if (conversationController == nil)
                    return nil;
                
                TGItemMenuSheetPreviewView *previewView = [[TGItemMenuSheetPreviewView alloc] initWithContext:[TGLegacyComponentsContext shared] frame:CGRectZero];
                
                NSMutableArray *actionItems = [[NSMutableArray alloc] init];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
                NSArray *previewActions = [(id)conversationController previewActionItems];
                
                __weak TGItemMenuSheetPreviewView *weakPreviewView = previewView;
                void (^dismissBlock)(void) = ^
                {
                    __strong TGItemMenuSheetPreviewView *strongPreviewView = weakPreviewView;
                    if (strongPreviewView != nil)
                        [strongPreviewView performCommit];
                };
                
                for (id action in previewActions)
                {
                    if ([action isKindOfClass:[UIPreviewAction class]])
                    {
                        UIPreviewAction *previewAction = (UIPreviewAction *)action;
                        TGMenuSheetButtonItemView *itemView = [[TGMenuSheetButtonItemView alloc] initWithTitle:previewAction.title type:TGMenuSheetButtonTypeDefault action:^
                        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
                            previewAction.handler(previewAction, nil);
#pragma clang diagnostic pop
                            dismissBlock();
                        }];
                        [actionItems addObject:itemView];
                    }
                }
#endif
                
                TGPreviewConversationItemView *itemView = [[TGPreviewConversationItemView alloc] initWithConversationController:conversationController];
                [previewView setupWithMainItemViews:@[itemView] actionItemViews:actionItems];
                
                TGItemPreviewController *controller = [[TGItemPreviewController alloc] initWithContext:[TGLegacyComponentsContext shared] parentController:strongSelf previewView:previewView];
                controller.sourcePointForItem = ^CGPoint(__unused id item)
                {
                    return CGPointZero;
                };
                
                return controller;
            }];
            _custom3dTouchHandle.shouldBegin = ^bool(CGPoint point) {
                __strong TGDialogListController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return false;
                
                if (strongSelf->_searchMixin.isActive)
                {
                    CGPoint tablePoint = [strongSelf.view convertPoint:point toView:strongSelf->_searchMixin.searchResultsTableView];
                    for (UITableViewCell *cell in strongSelf->_searchMixin.searchResultsTableView.visibleCells) {
                        if ([cell isKindOfClass:[TGDialogListRecentPeersCell class]] && CGRectContainsPoint([cell convertRect:[(TGDialogListRecentPeersCell *)cell bounds] toView:strongSelf->_searchMixin.searchResultsTableView], tablePoint))
                        {
                            return false;
                        }
                    }
                }
                
                return true;
            };
            _custom3dTouchHandle.requiredPressDuration = 0.3;
        }
    }
}

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    if (self.presentedViewController != nil) {
        return nil;
    }
    if (self.tableView.isEditing) {
        return nil;
    }
    
    if (_searchMixin.isActive) {
        CGPoint tablePoint = [self.view convertPoint:location toView:_searchMixin.searchResultsTableView];
        for (UITableViewCell *cell in _searchMixin.searchResultsTableView.visibleCells) {
            if ([cell isKindOfClass:[TGDialogListRecentPeersCell class]] && CGRectContainsPoint([cell convertRect:[(TGDialogListRecentPeersCell *)cell bounds] toView:_searchMixin.searchResultsTableView], tablePoint) && _custom3dTouchHandle == nil) {
                CGRect cellFrame = CGRectZero;
                int64_t peerId = [(TGDialogListRecentPeersCell *)cell peerAtPoint:[self.view convertPoint:location toView:cell] frame:&cellFrame];
                if (peerId != 0) {
                    CGRect sourceFrame = [self.view convertRect:cellFrame fromView:cell];
                    previewingContext.sourceRect = CGRectInset(sourceFrame, 0.0f, 2.0f);
                    
                    TGDispatchAfter(0.1, dispatch_get_main_queue(), ^
                    {
                        [TGPreviewPresentationHelper stylePreviewActionSheet];
                    });
                    
                    TGModernConversationController *controller = [[TGInterfaceManager instance] configuredPreviewConversationControlerWithId:peerId];
                    controller.onViewDidAppear = ^
                    {
                        [TGPreviewPresentationHelper stylePreviewActionSheet];
                    };
                    return controller;
                }
            }
            
            if ([cell isKindOfClass:[TGDialogListSearchCell class]] && CGRectContainsPoint([cell convertRect:[(TGDialogListSearchCell *)cell textContentFrame] toView:_searchMixin.searchResultsTableView], tablePoint)) {
                if (((TGDialogListSearchCell *)cell).isEncrypted) {
                    return nil;
                }
                
                previewingContext.sourceRect = [self.view convertRect:CGRectInset(cell.frame, 0.0f, 2.0f) fromView:_searchMixin.searchResultsTableView];
                
                TGDispatchAfter(0.1, dispatch_get_main_queue(), ^
                {
                    [TGPreviewPresentationHelper stylePreviewActionSheet];
                });
                
                TGModernConversationController *controller = [[TGInterfaceManager instance] configuredPreviewConversationControlerWithId:((TGDialogListSearchCell *)cell).conversationId];
                controller.onViewDidAppear = ^
                {
                    [TGPreviewPresentationHelper stylePreviewActionSheet];
                };
                return controller;
            }
        }
    } else {
        CGPoint tablePoint = [self.view convertPoint:location toView:_tableView];
        for (UITableViewCell *cell in _tableView.visibleCells) {
            if ([cell isKindOfClass:[TGDialogListCell class]] && CGRectContainsPoint([cell convertRect:[(TGDialogListCell *)cell textContentFrame] toView:_tableView], tablePoint)) {
                TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
                if (dialogCell.isEncrypted)
                    return nil;
                
                previewingContext.sourceRect = [self.view convertRect:CGRectInset(cell.frame, 0.0f, 2.0f) fromView:_tableView];
                
                TGDispatchAfter(0.1, dispatch_get_main_queue(), ^
                {
                    [TGPreviewPresentationHelper stylePreviewActionSheet];
                });
                
                TGModernConversationController *controller = dialogCell.isFeed ? [[TGInterfaceManager instance] configuredPreviewFeedControllerWithId:TGFeedIdFromPeerId(dialogCell.conversationId)] : [[TGInterfaceManager instance] configuredPreviewConversationControlerWithId:dialogCell.conversationId];
                controller.onViewDidAppear = ^
                {
                    [TGPreviewPresentationHelper stylePreviewActionSheet];
                };
                return controller;
            }
        }
    }
    
    return nil;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)__unused previewingContext commitViewController:(UIViewController *)viewControllerToCommit {
    if ([viewControllerToCommit isKindOfClass:[TGModernConversationController class]]) {
        TGModernConversationCompanion *companion = ((TGModernConversationController *)viewControllerToCommit).companion;
        
        if ([companion isKindOfClass:[TGFeedConversationCompanion class]]) {
            TGFeedConversationCompanion *feedCompanion = (TGFeedConversationCompanion *)(((TGModernConversationController *)viewControllerToCommit).companion);
            if (feedCompanion.conversationId != 0) {
                [[TGInterfaceManager instance] navigateToChannelsFeed:TGFeedIdFromPeerId(feedCompanion.conversationId) animated:true];
            }
        } else if ([companion isKindOfClass:[TGGenericModernConversationCompanion class]]) {
            TGGenericModernConversationCompanion *genericCompanion = (TGGenericModernConversationCompanion *)(((TGModernConversationController *)viewControllerToCommit).companion);
            if (genericCompanion.conversationId != 0) {
                [[TGInterfaceManager instance] navigateToConversationWithId:genericCompanion.conversationId conversation:nil performActions:nil atMessage:nil clearStack:![_dialogListCompanion feedChannels] openKeyboard:false canOpenKeyboardWhileInTransition:false animated:true];
            }
        }
    }
}

- (void)_selectFirstConversation
{
    NSArray *displayedRows = [self dialogListDisplayedItems];
    if (displayedRows.count == 0)
        return;
    
    TGConversation *conversation = nil;
    for (id item in displayedRows)
    {
        if ([item isKindOfClass:[TGConversation class]])
        {
            conversation = item;
            break;
        }
    }
    if (conversation == nil)
        return;
    [[TGInterfaceManager instance] navigateToConversationWithId:conversation.conversationId conversation:conversation];
}

- (void)selectPreviousConversationUnread:(bool)unread
{
    if (_dialogListCompanion.openedConversationId == 0)
    {
        [self _selectFirstConversation];
        return;
    }
    
    TGConversation *previousConversation = nil;
    for (TGConversation *conversation in [self dialogListDisplayedItems])
    {
        if ([_dialogListCompanion isConversationOpened:conversation.conversationId])
        {
            if (previousConversation != nil)
                [[TGInterfaceManager instance] navigateToConversationWithId:previousConversation.conversationId conversation:previousConversation];
            break;
        }
        
        if (!unread || (conversation.unreadCount + conversation.serviceUnreadCount) > 0)
            previousConversation = conversation;
    }
}

- (void)selectNextConversationUnread:(bool)unread
{
    if (_dialogListCompanion.openedConversationId == 0)
    {
        [self _selectFirstConversation];
        return;
    }
    
    bool jumpToNext = false;
    for (TGConversation *conversation in [self dialogListDisplayedItems])
    {
        if (jumpToNext)
        {
            if (!unread || (conversation.unreadCount + conversation.serviceUnreadCount) > 0)
            {
                [[TGInterfaceManager instance] navigateToConversationWithId:conversation.conversationId conversation:conversation];
                break;
            }
        }
        else if ([_dialogListCompanion isConversationOpened:conversation.conversationId])
        {
            jumpToNext = true;
        }
    }
}

- (void)selectPreviousSearchItem
{
    if (_searchResultsSections.count == 0)
        return;
    
    UITableView *tableView = _searchMixin.searchResultsTableView;
    NSIndexPath *newIndexPath = tableView.indexPathForSelectedRow;
    
    if (_searchResultsSections == _recentSearchResultsSections)
    {
        NSArray *items = _recentSearchResultsSections.firstObject[@"items"];
        if (items.count == 0)
            return;
        
        if (newIndexPath == nil)
            newIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        else if (newIndexPath.row > 0)
            newIndexPath = [NSIndexPath indexPathForRow:newIndexPath.row - 1 inSection:0];
    }
    else
    {
        if (newIndexPath == nil)
        {
            newIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        }
        else if (newIndexPath.row > 0)
        {
            newIndexPath = [NSIndexPath indexPathForRow:newIndexPath.row - 1 inSection:newIndexPath.section];
        }
        else if (newIndexPath.section > 0)
        {
            if ([self tableView:tableView numberOfRowsInSection:newIndexPath.section - 1] > 0)
                newIndexPath = [NSIndexPath indexPathForRow:[self tableView:tableView numberOfRowsInSection:newIndexPath.section - 1] - 1 inSection:newIndexPath.section - 1];
        }
    }
    
    if (tableView.indexPathForSelectedRow != nil)
        [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow animated:false];
    
    if (newIndexPath != nil)
        [tableView selectRowAtIndexPath:newIndexPath animated:false scrollPosition:UITableViewScrollPositionBottom];
}

- (void)selectNextSearchItem
{
    if (_searchResultsSections.count == 0)
        return;
    
    UITableView *tableView = _searchMixin.searchResultsTableView;
    NSIndexPath *newIndexPath = tableView.indexPathForSelectedRow;
    
    if (_searchResultsSections == _recentSearchResultsSections)
    {
        NSArray *items = _searchResultsSections.firstObject[@"items"];
        if (items.count == 0)
            return;
        
        if (newIndexPath == nil)
            newIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        else if (newIndexPath.row < [self tableView:tableView numberOfRowsInSection:newIndexPath.section] - 1)
            newIndexPath = [NSIndexPath indexPathForRow:newIndexPath.row + 1 inSection:0];
    }
    else
    {
        if (newIndexPath == nil)
        {
            newIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        }
        else if (newIndexPath.row < [self tableView:tableView numberOfRowsInSection:newIndexPath.section] - 1)
        {
            newIndexPath = [NSIndexPath indexPathForRow:newIndexPath.row + 1 inSection:newIndexPath.section];
        }
        else if (newIndexPath.section < [self numberOfSectionsInTableView:tableView] - 1)
        {
            if ([self tableView:tableView numberOfRowsInSection:newIndexPath.section + 1] > 0)
                newIndexPath = [NSIndexPath indexPathForRow:0 inSection:newIndexPath.section + 1];
        }
    }
    
    if (tableView.indexPathForSelectedRow != nil)
        [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow animated:false];
    
    if (newIndexPath != nil)
        [tableView selectRowAtIndexPath:newIndexPath animated:false scrollPosition:UITableViewScrollPositionBottom];
}

- (void)openSelectedSearchItem
{
    if (_searchResultsSections.count == 0)
        return;

    NSArray *items = _searchResultsSections.firstObject[@"items"];
    if (items.count == 0)
        return;
    
    NSIndexPath *selectedIndexPath = _searchMixin.searchResultsTableView.indexPathForSelectedRow;
    if (selectedIndexPath == nil)
        selectedIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    
    [self tableView:_searchMixin.searchResultsTableView didSelectRowAtIndexPath:selectedIndexPath];
    
    [self.searchBar resignFirstResponder];
    [_searchMixin setIsActive:false animated:true];
}

- (void)processKeyCommand:(UIKeyCommand *)keyCommand
{
    if ([keyCommand.input isEqualToString:@"\r"])
    {
        [self openSelectedSearchItem];
    }
    else if ([keyCommand.input isEqualToString:UIKeyInputUpArrow])
    {
        if (keyCommand.modifierFlags != 0)
            [self selectPreviousConversationUnread:keyCommand.modifierFlags & UIKeyModifierShift];
        else
            [self selectPreviousSearchItem];
    }
    else if ([keyCommand.input isEqualToString:UIKeyInputDownArrow])
    {
        if (keyCommand.modifierFlags != 0)
            [self selectNextConversationUnread:keyCommand.modifierFlags & UIKeyModifierShift];
        else
            [self selectNextSearchItem];
    }
    else if ([keyCommand.input isEqualToString:@"N"])
    {
        [_dialogListCompanion composeMessageAndOpenSearch:true];
    }
    else if ([keyCommand.input isEqualToString:UIKeyInputEscape] || [keyCommand.input isEqualToString:@"\t"])
    {
        if (!self.searchBar.maybeCustomTextField.isFirstResponder)
        {
            [self.searchBar becomeFirstResponder];
        }
        else
        {
            [self.searchBar resignFirstResponder];
            [_searchMixin setIsActive:false animated:true];
        }
    }
}

- (NSArray *)availableKeyCommands
{
    NSMutableArray *keyCommands = [[NSMutableArray alloc] init];
    
    [keyCommands addObjectsFromArray:@
    [
     [TGKeyCommand keyCommandWithTitle:TGLocalized(@"KeyCommand.JumpToPreviousChat") input:UIKeyInputUpArrow modifierFlags:UIKeyModifierAlternate],
     [TGKeyCommand keyCommandWithTitle:TGLocalized(@"KeyCommand.JumpToNextChat")  input:UIKeyInputDownArrow modifierFlags:UIKeyModifierAlternate],
     [TGKeyCommand keyCommandWithTitle:TGLocalized(@"KeyCommand.JumpToPreviousUnreadChat") input:UIKeyInputUpArrow modifierFlags:UIKeyModifierAlternate | UIKeyModifierShift],
     [TGKeyCommand keyCommandWithTitle:TGLocalized(@"KeyCommand.JumpToNextUnreadChat")  input:UIKeyInputDownArrow modifierFlags:UIKeyModifierAlternate | UIKeyModifierShift],
     [TGKeyCommand keyCommandWithTitle:TGLocalized(@"KeyCommand.NewMessage") input:@"N" modifierFlags:UIKeyModifierCommand],
     [TGKeyCommand keyCommandWithTitle:nil input:UIKeyInputEscape modifierFlags:0],
     [TGKeyCommand keyCommandWithTitle:TGLocalized(@"KeyCommand.Find") input:@"\t" modifierFlags:0]
    ]];
    
    if (_searchBar.maybeCustomTextField.isFirstResponder)
    {
        [keyCommands addObject:[TGKeyCommand keyCommandWithTitle:nil input:@"\r" modifierFlags:0]];
        [keyCommands addObject:[TGKeyCommand keyCommandWithTitle:nil input:UIKeyInputUpArrow modifierFlags:0]];
        [keyCommands addObject:[TGKeyCommand keyCommandWithTitle:nil input:UIKeyInputDownArrow modifierFlags:0]];
    }
    
    return keyCommands;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
- (nullable NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == _tableView && indexPath.section == 1 && _editingMode) {
        __weak TGDialogListController *weakSelf = self;
        UITableViewRowAction *action = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:TGLocalized(@"Common.Delete") handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf performTableAction:action withIndexPath:indexPath];
            }
        }];
        action.backgroundColor = self.presentation.pallete.dialogEditDeleteColor;
        return @[action];
    } else if (tableView == _searchMixin.searchResultsTableView) {
        __weak TGDialogListController *weakSelf = self;
        UITableViewRowAction *action = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:TGLocalized(@"Common.Delete") handler:^(__unused UITableViewRowAction *action, NSIndexPath *indexPath) {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf tableView:tableView commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:indexPath];
            }
        }];
        action.backgroundColor = self.presentation.pallete.dialogEditDeleteColor;
        return @[action];
    } else {
        return nil;
    }
}

- (NSString *)tableView:(UITableView *)__unused tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return TGLocalized(@"Common.Delete");
}

- (void)performTableAction:(UITableViewRowAction *)action withIndexPath:(NSIndexPath *)indexPath {
    TGConversation *conversation = (TGConversation *)[self og_dialogListItemAtIndexPath:indexPath];
    if (![conversation isKindOfClass:[TGConversation class]])
        return;
    if ([action.title isEqualToString:TGLocalized(@"Common.Delete")]) {
        [self tableView:_tableView commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:indexPath];
    } else if ([action.title isEqualToString:TGLocalized(@"DialogList.Unpin")]) {
        if (conversation.pinnedToTop) {
            [[[TGGroupManagementSignals updatePinnedState:conversation.conversationId pinned:false] onDispose:^{
            }] startWithNext:nil];
            [self doneButtonPressed];
        }
    } else if ([action.title isEqualToString:TGLocalized(@"DialogList.Pin")]) {
        if (!conversation.pinnedToTop) {
            int32_t maxPinnedChats = 4;
            NSData *data = [TGDatabaseInstance() customProperty:@"maxPinnedChats"];
            if (data.length == 4) {
                [data getBytes:&maxPinnedChats length:4];
                maxPinnedChats = MAX(maxPinnedChats, 4);
            }
            NSInteger pinnedCount = 0;
            for (TGConversation *conversation in _listModel) {
                if (conversation.pinnedToTop) {
                    pinnedCount++;
                } else {
                    break;
                }
            }
            
            if (pinnedCount >= maxPinnedChats) {
                [TGCustomAlertView presentAlertWithTitle:nil message:[NSString stringWithFormat: TGLocalized(@"DialogList.PinLimitError"), [NSString stringWithFormat:@"%d", maxPinnedChats]] cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                [self doneButtonPressed];
            } else {
                [[[TGGroupManagementSignals updatePinnedState:conversation.conversationId pinned:true] onDispose:^{
                }] startWithNext:nil];
            }
        }
    }
}
#endif

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_ogSelectedDialogFilterId != 0)
        return false;
    if (tableView == _tableView) {
        if (indexPath.section != 0) {
            TGConversation *conversation = (TGConversation *)[self og_dialogListItemAtIndexPath:indexPath];
            return conversation.pinnedToTop;
        }
    }
    return false;
}

- (void)moveObjectAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    
    id object = [_listModel objectAtIndex:fromIndex];
    [_listModel removeObjectAtIndex:fromIndex];
    [_listModel insertObject:object atIndex:toIndex];
}

- (void)tableView:(UITableView *)__unused tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    [self moveObjectAtIndex:sourceIndexPath.row toIndex:destinationIndexPath.row];
    NSMutableArray *peerIds = [[NSMutableArray alloc] init];
    for (TGConversation *conversation in _listModel) {
        if (conversation.pinnedToTop) {
            [peerIds addObject:@(conversation.conversationId)];
        }
    }
    
    [_dialogListCompanion hintMoveConversationAtIndex:sourceIndexPath.row toIndex:destinationIndexPath.row];
    [TGDatabaseInstance() transactionUpdatePinnedConversations:peerIds synchronizePinnedConversations:true forceReplacePinnedConversations:true];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateIsLastCell];
    });
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    if (tableView == _tableView) {
        if (sourceIndexPath.section == 1) {
            if (proposedDestinationIndexPath.section == 1) {
                NSInteger minIndex = 0;
                NSInteger maxIndex = -1;
                for (TGConversation *conversation in _listModel) {
                    if (conversation.isAd) {
                        minIndex++;
                        maxIndex++;
                    } else if (conversation.pinnedToTop) {
                        maxIndex++;
                    } else {
                        break;
                    }
                }
                
                if (proposedDestinationIndexPath.row >= minIndex && (NSInteger)proposedDestinationIndexPath.row <= maxIndex) {
                    return proposedDestinationIndexPath;
                } else {
                    return [NSIndexPath indexPathForRow:MAX(maxIndex, minIndex) inSection:1];
                }
                
                return sourceIndexPath;
            } else {
                if (proposedDestinationIndexPath.section < 1) {
                    return [NSIndexPath indexPathForRow:0 inSection:1];
                } else {
                    NSInteger minIndex = 0;
                    NSInteger maxIndex = -1;
                    for (TGConversation *conversation in _listModel) {
                        if (conversation.isAd) {
                            minIndex++;
                            maxIndex++;
                        } else if (conversation.pinnedToTop) {
                            maxIndex++;
                        } else {
                            break;
                        }
                    }
                    return [NSIndexPath indexPathForRow:MAX(maxIndex, minIndex) inSection:1];
                }
            }
        }
    }
    return sourceIndexPath;
}

- (void)displaySuggestedLocalization {
    if (_suggestedLocalization != nil && !_dialogListCompanion.privacyMode && !_dialogListCompanion.botStartMode && !_dialogListCompanion.forwardMode) {
        [TGDatabaseInstance() setCustomProperty:@"checkedLocalization" value:[_suggestedLocalization.info.code dataUsingEncoding:NSUTF8StringEncoding]];
        
        __weak TGDialogListController *weakSelf = self;
        TGSuggestedLocalizationController *controller = [[TGSuggestedLocalizationController alloc] initWithSuggestedLocalization:_suggestedLocalization];
        controller.other = ^{
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                TGLocalizationSelectionController *selection = [[TGLocalizationSelectionController alloc] init];
                selection.presentation = strongSelf.presentation;
                [TGAppDelegateInstance.rootController pushContentController:selection];
            }
        };
        controller.appliedLanguage = ^{
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf displaySettingsTooltip:TGLocalized(@"DialogList.LanguageTooltip")];
            }
        };
        [TGAppDelegateInstance.window presentOverlayController:controller];
    }
}

- (void)displaySettingsTooltip:(NSString *)text {
    if (_recordTooltipContainerView == nil) {
        TGTooltipContainerView *tooltipContainerView = [[TGTooltipContainerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height)];
        _recordTooltipContainerView = tooltipContainerView;
        _recordTooltipContainerView.tooltipView.numberOfLines = 0;
        [self.navigationController.view addSubview:_recordTooltipContainerView];
        
        [_recordTooltipContainerView.tooltipView setText:text animated:false];
        _recordTooltipContainerView.tooltipView.sourceView = [((TGMainTabsController *)self.parentViewController) viewForRightmostTab];
        
        CGRect recordButtonFrame = [[((TGMainTabsController *)self.parentViewController) viewForRightmostTab] convertRect:[((TGMainTabsController *)self.parentViewController) viewForRightmostTab].bounds toView:_recordTooltipContainerView];
        recordButtonFrame.origin.y += 15.0f;
        [_recordTooltipContainerView showTooltipFromRect:recordButtonFrame animated:false];
    
        __weak TGTooltipContainerView *weakContainerView = _recordTooltipContainerView;
        [[[SSignal complete] delay:5.0 onQueue:[SQueue mainQueue]] startWithNext:nil completed:^{
            __strong TGTooltipContainerView *strongContainerView = weakContainerView;
            if (strongContainerView != nil)
                [strongContainerView hideTooltip];
        }];
    }
}

- (void)displayProxyTooltip {
    [self displaySettingsTooltip:TGLocalized(@"DialogList.ProxyConnectionIssuesTooltip")];
}

- (void)createContactControllerDidFinish:(TGCreateContactController *)__unused createContactController
{
    [self dismissViewControllerAnimated:true completion:nil];
}

- (void)openProxySettings {
    if ([[TGTelegramNetworking instance] onegramCoreMode] != OGOnegramCoreModeNone) {
        [TGOnegramCoreController presentFromViewController:self];
        return;
    }

    TGProxySetupController *controller = [[TGProxySetupController alloc] initModal:true];
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[controller]];
    [self presentViewController:navigationController animated:true completion:nil];
}

- (void)setCurrentTitlePanel:(TGModernConversationTitlePanel *)titlePanel
{
    _currentTitlePanel = titlePanel;
    if (!_searchMixin.isActive)
        [self setPrimaryTitlePanel:_currentTitlePanel fade:false];
}

- (void)setPrimaryTitlePanel:(TGModernConversationTitlePanel *)titlePanel fade:(bool)fade
{
    if (_primaryTitlePanel != titlePanel)
    {
        TGModernConversationTitlePanel *lastPanel = _primaryTitlePanel;
        [UIView animateWithDuration:0.09 delay:0.0 options:iosMajorVersion() < 7 ? 0 : (7 << 16) animations:^
        {
            lastPanel.frame = CGRectOffset(lastPanel.frame, 0.0f, -lastPanel.frame.size.height);
            
            if (titlePanel == nil)
            {
                [self setExplicitTableInset:UIEdgeInsetsZero];
                [self setExplicitScrollIndicatorInset:UIEdgeInsetsZero];
            }
            
            if (fade)
                lastPanel.alpha = 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished) {
                [lastPanel removeFromSuperview];
            }
        }];
    }
    
    _primaryTitlePanel = titlePanel;
    titlePanel.presentation = self.presentation;
    
    if (_primaryTitlePanel != nil && [self isViewLoaded])
    {
        if (_titlePanelWrappingView == nil)
        {
            _titlePanelWrappingView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.controllerInset.top - self.explicitTableInset.top, self.view.frame.size.width, 44.0f)];
            _titlePanelWrappingView.clipsToBounds = true;
            
            [self.view addSubview:_titlePanelWrappingView];
        }
        
        _titlePanelWrappingView.userInteractionEnabled = true;
        
        CGRect titlePanelWrappingFrame = _titlePanelWrappingView.frame;
        titlePanelWrappingFrame.size.height = MAX(44.0f, _primaryTitlePanel.frame.size.height);
        _titlePanelWrappingView.frame = titlePanelWrappingFrame;
        
        [_titlePanelWrappingView addSubview:_primaryTitlePanel];
        
        CGRect titlePanelFrame = CGRectMake(0.0f, 0.0f, _titlePanelWrappingView.frame.size.width, _primaryTitlePanel.frame.size.height);
        
        [_primaryTitlePanel.layer removeAllAnimations];
        
        _primaryTitlePanel.frame = CGRectOffset(titlePanelFrame, 0.0f, -titlePanelFrame.size.height);
        [UIView animateWithDuration:0.09 delay:0.0 options:iosMajorVersion() < 7 ? 0 : (7 << 16) animations:^
        {
            _primaryTitlePanel.frame = titlePanelFrame;
            [self setExplicitTableInset:UIEdgeInsetsMake(titlePanel.frame.size.height, 0.0f, 0.0f, 0.0f)];
            [self setExplicitScrollIndicatorInset:UIEdgeInsetsMake(titlePanel.frame.size.height, 0.0f, 0.0f, 0.0f)];
            
            if (_primaryTitlePanel.alpha < FLT_EPSILON)
                _primaryTitlePanel.alpha = 1.0f;
        } completion:nil];
    }
    else
    {
        _titlePanelWrappingView.userInteractionEnabled = false;
    }
}

- (void)_performSizeChangesWithDuration:(NSTimeInterval)duration size:(CGSize)size
{
    [self og_layoutFolderTabs];
    CGSize collectionViewSize = size;
    
    if (_titlePanelWrappingView != nil)
    {
        CGRect titleWrapperFrame = CGRectMake(0.0f, self.controllerInset.top - _currentTitlePanel.frame.size.height, collectionViewSize.width, _titlePanelWrappingView.frame.size.height);
        CGRect titlePanelFrame = CGRectMake(0.0f, 0.0f, titleWrapperFrame.size.width, _currentTitlePanel.frame.size.height);
        if (duration > DBL_EPSILON)
        {
            [UIView animateWithDuration:duration animations:^
             {
                 _titlePanelWrappingView.frame = titleWrapperFrame;
                 _currentTitlePanel.frame = titlePanelFrame;
             }];
        }
        else
        {
            _titlePanelWrappingView.frame = titleWrapperFrame;
            _currentTitlePanel.frame = titlePanelFrame;
        }
    }
}

- (void)dimViewPressed
{
    
}

- (void)setDimmed:(bool)dimmed animated:(bool)animated keyboardSnapshot:(UIView *)keyboardSnapshot restoringFocus:(bool)restoringFocus
{
    if (dimmed)
    {
        if (_keyboardSnapshotView != nil)
        {
            [_keyboardSnapshotView removeFromSuperview];
            _keyboardSnapshotView = nil;
        }
        
        if (_dimView == nil)
        {
            _dimView = [[UIButton alloc] init];
            _dimView.alpha = 0.0f;
            _dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _dimView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
            _dimView.frame = [self.navigationController.view bounds];
            [_dimView addTarget:self action:@selector(dimViewPressed) forControlEvents:UIControlEventTouchDown];
            
            [self.navigationController.view addSubview:_dimView];
        }
        else
        {
            [self.navigationController.view bringSubviewToFront:_dimView];
        }
        
        if (keyboardSnapshot != nil)
        {
            [TGAppDelegateInstance.rootController.mainTabsController setIgnoreKeyboardFrameChange:true restoringFocus:false];
            
            _keyboardSnapshotView = [keyboardSnapshot snapshotViewAfterScreenUpdates:false];
            _keyboardSnapshotView.frame = CGRectMake(0.0f, self.navigationController.view.frame.size.height - _keyboardSnapshotView.frame.size.height, _keyboardSnapshotView.frame.size.width, _keyboardSnapshotView.frame.size.height);
            [self.navigationController.view insertSubview:_keyboardSnapshotView belowSubview:_dimView];
        }
    }
    else
    {
        [TGAppDelegateInstance.rootController.mainTabsController setIgnoreKeyboardFrameChange:false restoringFocus:restoringFocus];
        
        if (!restoringFocus)
        {
            [UIView animateWithDuration:0.2 delay:0.0 options:7 << 16 animations:^
            {
                _keyboardSnapshotView.frame = CGRectOffset(_keyboardSnapshotView.frame, 0.0f, _keyboardSnapshotView.frame.size.height);
            } completion:nil];
        }
    }
    
    void (^changeBlock)(void) = ^
    {
        _dimView.alpha = dimmed ? 1.0f : 0.0f;
    };
    
    void (^completionBlock)(BOOL) = ^(__unused BOOL finished)
    {
        if (!dimmed && _keyboardSnapshotView != nil)
        {
            void (^block)(void) = ^
            {
                [_keyboardSnapshotView removeFromSuperview];
                _keyboardSnapshotView = nil;
            };
            
            TGDispatchAfter(0.45, dispatch_get_main_queue(), block);
        }
    };
    
    if (animated)
    {
        [UIView animateWithDuration:0.2f animations:changeBlock completion:completionBlock];
    }
    else
    {
        changeBlock();
        completionBlock(true);
    }
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    _needsUpdate = true;
    _ogFolderTabsStateKey = nil;
    TGNavigationBar *navigationBar = [self.navigationController.navigationBar isKindOfClass:[TGNavigationBar class]] ? (TGNavigationBar *)self.navigationController.navigationBar : nil;
    if (![TGPresentation brandedIOS6Style] && _ogPlayerHeight > FLT_EPSILON)
    {
        CGFloat height = _ogPlayerHeight;
        _ogPlayerHeight = 0.0f;
        if (navigationBar.musicPlayerHostView == _ogPlayerHostView)
            navigationBar.musicPlayerHostView = nil;
        [super setAdditionalNavigationBarHeight:height > 2.0f ? 37.0f : height];
    }
    else if ([TGPresentation brandedIOS6Style] && self.additionalNavigationBarHeight > FLT_EPSILON)
    {
        [self setAdditionalNavigationBarHeight:self.additionalNavigationBarHeight > 2.0f ? 44.0f : self.additionalNavigationBarHeight];
        if (_isOnScreen)
            navigationBar.musicPlayerHostView = _ogPlayerHostView;
    }

    if (self.isViewLoaded)
        self.view.backgroundColor = _presentation.pallete.backgroundColor;
    _headerBackgroundView.backgroundColor = _presentation.pallete.backgroundColor;
    [self updateSearchBarBackground];
    [self updateSnowflakesAnimated:false];
    
    _tableView.backgroundColor = _presentation.pallete.backgroundColor;
    
    [_searchBar setPallete:presentation.searchBarPallete];
    
    _titleLockIconView.presentation = self.presentation;
    bool classicThemeStyle = [TGPresentation classicThemeStyle];
    UIColor *classicTitleShadowColor = TGDialogListNavigationShadowColor(_presentation, 0.9f);
    UIColor *classicSubtitleShadowColor = TGDialogListNavigationShadowColor(_presentation, 0.72f);
    _titleLabel.textColor = OGDialogListHeaderTitleColor(self.presentation);
    _titleLabel.shadowColor = classicTitleShadowColor;
    _titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
    if (_titleLabel != nil && _titleLabel.font != TGDialogListNavigationTitleFont())
    {
        _titleLabel.font = TGDialogListNavigationTitleFont();
        [_titleLabel sizeToFit];
        [self _layoutTitleViews:self.interfaceOrientation];
    }
    _titleStatusLabel.textColor = OGDialogListHeaderTitleColor(_presentation);
    _titleStatusLabel.shadowColor = classicTitleShadowColor;
    _titleStatusLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
    _titleStatusSubtitleLabel.textColor = OGDialogListHeaderSubtitleColor(_presentation);
    _titleStatusSubtitleLabel.shadowColor = classicSubtitleShadowColor;
    _titleStatusSubtitleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
    _titleStatusIndicator.color = classicThemeStyle ? [UIColor whiteColor] : _presentation.pallete.navigationSpinnerColor;
    
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
            [(TGDialogListCell *)cell setPresentation:presentation];
    }
    
    for (UITableViewCell *cell in _searchMixin.searchResultsTableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListSearchCell class]])
            [(TGDialogListSearchCell *)cell setPresentation:presentation];
        else if ([cell isKindOfClass:[TGDialogListRecentPeersCell class]])
            [(TGDialogListRecentPeersCell *)cell setPresentation:presentation];
        else if ([cell isKindOfClass:[TGFlatActionCell class]])
            [(TGFlatActionCell *)cell setPresentation:presentation];
    }
    
    [self applyConversationTableSeparators:_tableView];
    
    _primaryTitlePanel.presentation = self.presentation;

    [self og_updateFolderTabs];
    [self og_layoutFolderTabs];
    
    [self updateBarButtonItemsAnimated:false];
}


@end
