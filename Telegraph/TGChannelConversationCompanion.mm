#import "TGChannelConversationCompanion.h"
#import "../OnegramRuntime/OGRuntime.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGLegacyComponentsContext.h"


#import "TGCommon.h"

#import "TGAppDelegate.h"
#import "TGInterfaceManager.h"
#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "TGDatabase.h"
#import "TGTelegraph.h"
#import "TGAppDelegate.h"
#import "TGDialogListCompanion.h"

#import "TGChannelManagementSignals.h"
#import "TGChannelStateSignals.h"
#import "TGChannelDirectMessagesSignals.h"

#import "TGModernConversationController.h"
#import "TGMessageModernConversationItem.h"

#import "TGModernConversationGroupTitlePanel.h"
#import "TGUpdateStateRequestBuilder.h"

#import "TGChannelInfoController.h"
#import "TGChannelGroupInfoController.h"

#import "TGModernViewContext.h"

#import "TGModernConversationActionInputPanel.h"
#import "TGShareMenu.h"

#import "TGTelegramNetworking.h"

#import "TGCustomAlertView.h"

#import "TGModernConversationTitleIcon.h"

#import "TGModernConversationTitleView.h"

#import <libkern/OSAtomic.h>

#import "TGMigratedChannelConversationHeaderView.h"

#import "TGGroupedUserOnlineSignals.h"

#import "TGDownloadMessagesSignal.h"

#import "TGPinnedMessageTitlePanel.h"
#import "TGLiveLocationTitlePanel.h"

#import "TLRPCmessages_search.h"
#import "TGMessage+Telegraph.h"
#import "TGUserDataRequestBuilder.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGAccountSignals.h"

#import "TGModernConversationContactLinkTitlePanel.h"
#import "TGModernConversationRestrictedInputPanel.h"

#import "TGServiceSignals.h"
#import "TGRecentContextBotsSignal.h"
#import "TGCustomActionSheet.h"

#import "TGReportPeerOtherTextController.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryController.h"
#import "TGGroupAvatarGalleryModel.h"

#import "TGGroupManagementSignals.h"

#import "TGChannelBanController.h"

#import "TGPresentation.h"
#import "../OnegramRuntime/OGRemoteClock.h"
#import "TGPaidMessagesSignals.h"

static const int32_t OGChannelPinnedFilterSignature = 0x1bb00451;
static const int32_t OGChannelPinnedFilterNoName = -1;

@interface OGChannelPinnedSearchFilter : TLMessagesFilter
@end

@implementation OGChannelPinnedSearchFilter

- (int32_t)TLconstructorSignature
{
    return OGChannelPinnedFilterSignature;
}

- (int32_t)TLconstructorName
{
    return OGChannelPinnedFilterNoName;
}

- (void)TLserialize:(NSOutputStream *)__unused os
{
}

@end

static TGMessage *OGChannelPinnedTargetOfServiceMessage(TGMessage *serviceMessage)
{
    TGMessage *quoted = nil;
    bool pinsSomething = false;
    for (id media in serviceMessage.mediaAttachments)
    {
        if ([media isKindOfClass:[TGReplyMessageMediaAttachment class]])
            quoted = ((TGReplyMessageMediaAttachment *)media).replyMessage;
        else if ([media isKindOfClass:[TGActionMediaAttachment class]] && ((TGActionMediaAttachment *)media).actionType == TGMessageActionPinnedMessage)
            pinsSomething = true;
    }
    return pinsSomething ? quoted : nil;
}

static NSComparisonResult OGChannelPinnedNewestFirst(TGMessage *left, TGMessage *right)
{
    int32_t leftDate = [left actualDate];
    int32_t rightDate = [right actualDate];
    if (leftDate != rightDate)
        return leftDate > rightDate ? NSOrderedAscending : NSOrderedDescending;
    return left.mid > right.mid ? NSOrderedAscending : NSOrderedDescending;
}

static void OGChannelPinnedAppendDistinct(NSMutableArray *destination, NSMutableSet *knownIds, NSArray *source)
{
    for (TGMessage *candidate in source)
    {
        if (candidate.mid == 0 || [knownIds containsObject:@(candidate.mid)])
            continue;
        [knownIds addObject:@(candidate.mid)];
        [destination addObject:candidate];
    }
}

static NSString *OGChannelPinnedMenuLabel(TGMessage *message)
{
    NSString *raw = message.text.length != 0 ? message.text : message.caption;
    NSString *label = [[raw componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
    while ([label rangeOfString:@"  "].location != NSNotFound)
        label = [label stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    label = [label stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return label.length == 0 ? TGLocalized(@"Conversation.PinnedMessage") : label;
}

static NSString *OGChannelPinnedClassicButtonTitle(NSUInteger slot, NSString *label)
{
    NSString *numbered = [NSString stringWithFormat:@"%d. %@", (int)slot + 1, label];
    if (numbered.length <= 24)
        return numbered;
    NSRange keep = [numbered rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, 23)];
    return [[numbered substringWithRange:keep] stringByAppendingString:@"…"];
}

static NSString *OGChannelPinnedPageTitle(NSUInteger from, NSUInteger to, bool backward)
{
    NSString *format = backward ? @"‹ %d–%d" : @"%d–%d ›";
    return [NSString stringWithFormat:format, (int)from + 1, (int)to];
}

static TGMenuSheetButtonItemView *OGChannelPinnedSheetButton(NSString *title, void (^action)(void))
{
    return [[TGMenuSheetButtonItemView alloc] initWithTitle:title type:TGMenuSheetButtonTypeDefault action:action];
}

static NSArray *OGChannelDecodePinnedResult(TLmessages_Messages *result)
{
    [TGUserDataRequestBuilder executeUserDataUpdate:result.users];
    NSMutableArray *decoded = [[NSMutableArray alloc] init];
    for (TLMessage *messageDesc in result.messages)
    {
        TGMessage *decodedMessage = [[TGMessage alloc] initWithTelegraphMessageDesc:messageDesc];
        if (decodedMessage.mid != 0)
            [decoded addObject:decodedMessage];
    }
    return decoded;
}

static id OGChannelVisiblePinnedMessage(NSArray *values, int32_t dismissedId)
{
    id listState = values[1];
    TGMessage *candidate = nil;
    if ([listState isKindOfClass:[NSArray class]])
        candidate = [(NSArray *)listState firstObject];
    else if ([values[0] isKindOfClass:[TGMessage class]])
        candidate = values[0];
    if (candidate == nil || (candidate.mid != 0 && candidate.mid == dismissedId))
        return [NSNull null];
    return candidate;
}

static NSArray *OGChannelRemoteMessagesFromResult(NSDictionary *result)
{
    return [result objectForKey:@"messages"];
}

static NSArray *OGChannelHoleListFromResult(NSDictionary *result)
{
    id hole = result[@"hole"];
    return hole == nil ? nil : @[hole];
}

static NSMutableArray *OGChannelCombineChanges(NSArray *primary, NSArray *unimportant, int32_t displayVariant)
{
    NSMutableArray *combined = [[NSMutableArray alloc] init];
    [combined addObjectsFromArray:primary];
    if (displayVariant == TGChannelDisplayVariantAll)
        [combined addObjectsFromArray:unimportant];
    return combined;
}

static NSArray *OGChannelStaleLocalIds(NSArray *remoteMessages, NSArray *localMessages)
{
    NSMutableSet *remoteIds = [[NSMutableSet alloc] init];
    int32_t lowestRemoteId = 0;
    for (TGMessage *remote in remoteMessages)
    {
        if (remote.mid == 0)
            continue;
        [remoteIds addObject:@(remote.mid)];
        if (lowestRemoteId == 0 || lowestRemoteId > remote.mid)
            lowestRemoteId = remote.mid;
    }
    
    NSMutableArray *stale = [[NSMutableArray alloc] init];
    if (lowestRemoteId == 0)
        return stale;
    for (TGMessage *local in localMessages)
    {
        if (local.mid >= lowestRemoteId && ![remoteIds containsObject:@(local.mid)])
            [stale addObject:@(local.mid)];
    }
    return stale;
}

static TGMenuSheetController *OGChannelMakeSheet(void)
{
    TGMenuSheetController *sheet = [[TGMenuSheetController alloc] initWithContext:[TGLegacyComponentsContext shared] dark:false];
    sheet.dismissesByOutsideTap = true;
    sheet.narrowInLandscape = true;
    return sheet;
}

@interface OGChannelCompanionAnchor : NSObject
@property (nonatomic, weak) TGChannelConversationCompanion *value;
@end

@implementation OGChannelCompanionAnchor
@end

static TGChannelConversationCompanion *OGChannelCompanionFromAnchor(OGChannelCompanionAnchor *reference)
{
    TGChannelConversationCompanion *result = nil;
    @synchronized (reference)
    {
        result = reference.value;
    }
    return result;
}

@interface TGChannelConversationCompanion () <TGModernConversationContactLinkTitlePanelDelegate> {
    NSDictionary *_initialUserActivities;
    
    TGConversation *_conversation;
    int32_t _displayVariant;
    int32_t _kind;
    bool _isCreator;
    TGChannelAdminRights *_adminRights;
    TGChannelBannedRights *_bannedRights;
    bool _isGroup;
    bool _isMuted;
    bool _isForbidden;
    
    NSMutableDictionary *_defaultNotificationSettings;
    NSMutableDictionary *_groupNotificationSettings;
    
    NSSet *_adminIds;
    int32_t _memberCount;
    
    bool _enableVisibleMessagesProcessing;
    
    SMetaDisposable *_requestingHoleDisposable;
    SMetaDisposable *_managedState;
    SMetaDisposable *_extendedDataDisposable;
    SMetaDisposable *_cachedDataDisposable;
    SMetaDisposable *_updatedAdminsDisposable;
    
    TGVisibleMessageHole *_requestingHole;
    bool _loadingHistoryAbove;
    bool _loadingHistoryBelow;
    NSUInteger _remoteGapEpoch;
#if defined(ONEGRAM_ARMV6)
    bool _initialHistoryPending;
    bool _hasAppearedOnce;
#endif
    
    bool _historyAbove;
    bool _historyBelow;
    
    NSArray *_visibleHoles;
    
    TGModernConversationActionInputPanel *_joinChannelPanel;
    TGModernConversationActionInputPanel *_mutePanel;
    TGModernConversationActionInputPanel *_deletePanel;
    TGModernConversationRestrictedInputPanel *_restrictedPanel;
    SMetaDisposable *_joinChannelDisposable;
    
    TGMessageGroup *_lastExpandedGroup;
    
    NSTimeInterval _lastTypingActivity;
    NSTimeInterval _lastReadScheduleTime;
    
    TGMigratedChannelConversationHeaderView *_migratedChannelHeaderView;
    
    TGConversationMigrationData *_migrationData;
    bool _migrationHistoryAbove;
    
    bool _hasBots;
    
    SVariable *_pinnedMessage;
    int32_t _immediatePinnedMessage;
    SVariable *_pinnedListVariable;
    NSArray *_pinnedMessageList;
    id<SDisposable> _pinnedFetchDisposable;
    int32_t _dismissedPinnedId;
    
    int32_t _invalidatedPts;
    bool _needsToValidatePts;
    id<SDisposable> _invalidatedPtsDisposable;
    
    bool _updatingInvalidatedMessages;
    SMetaDisposable *_updatingInvalidatedMessagesDisposable;
    
    SDisposableSet *_genericInfoDisposables;
    NSNumber *_messagesMuted;
    bool _shouldNotifyMembers;
    
    bool _signaturesEnabled;
    
    SMetaDisposable *_groupedUserStatusesDisposable;
    
    TGGroupedUserOnlineInfo *_groupedOnlineInfo;

    id<SDisposable> _updatedPeerSettingsDisposable;
    
    TGModernConversationContactLinkTitlePanel *_reportSpamPanel;
    TGPinnedMessageTitlePanel *_pinnedBanner;
    TGLiveLocationTitlePanel *_locationPanel;
    
    SVariable *_primaryPanel;
    OGChannelCompanionAnchor *_lifetimeAnchor;
}

@end

@implementation TGChannelConversationCompanion

- (void)_scheduleReadHistoryAfterAppear:(NSString *)reason
{
    NSTimeInterval now = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970;
    bool throttled = _lastReadScheduleTime > 0.0 && now - _lastReadScheduleTime < 1.0;
    if (throttled)
        return;
    _lastReadScheduleTime = now;
    
    [self scheduleReadHistory];
}

- (void)_controllerWillAppearAnimated:(bool)animated firstTime:(bool)firstTime
{
    [super _controllerWillAppearAnimated:animated firstTime:firstTime];
    [self _scheduleReadHistoryAfterAppear:firstTime ? @"firstWillAppear" : @"willAppear"];
}

- (void)updateBroadcasting
{
    bool shouldNotify = false;
    if (_messagesMuted != nil)
        shouldNotify = !(_messagesMuted.boolValue);
    else
        shouldNotify = !([_defaultNotificationSettings[@"messagesMuted"] boolValue]);
    
    _shouldNotifyMembers = shouldNotify;
    [self.controller setIsBroadcasting:shouldNotify];
}

- (void)og_presentSheet:(TGMenuSheetController *)sheet anchoredAt:(UIView *)anchor
{
    OGChannelCompanionAnchor *ownerAnchor = _lifetimeAnchor;
    __weak UIView *weakAnchor = anchor;
    sheet.sourceRect = ^CGRect
    {
        TGChannelConversationCompanion *owner = OGChannelCompanionFromAnchor(ownerAnchor);
        UIView *anchorView = weakAnchor;
        if (owner == nil || anchorView == nil)
            return CGRectZero;
        return [anchorView convertRect:anchorView.bounds toView:owner.controller.view];
    };
    sheet.permittedArrowDirections = UIPopoverArrowDirectionUp;
    [sheet presentInViewController:self.controller sourceView:self.controller.view animated:true];
}

- (NSArray *)og_latestPinnedFromMessages:(NSArray *)messages
{
    NSArray *newestFirst = [messages sortedArrayUsingComparator:^NSComparisonResult(TGMessage *left, TGMessage *right)
    {
        return OGChannelPinnedNewestFirst(left, right);
    }];
    
    for (TGMessage *candidate in newestFirst)
    {
        TGMessage *target = OGChannelPinnedTargetOfServiceMessage(candidate);
        if (target != nil && target.mid != 0)
            return @[target];
    }
    return @[];
}

- (void)og_applyPinnedMessages:(NSArray *)updated
{
    int32_t formerLeadId = ((TGMessage *)_pinnedMessageList.firstObject).mid;
    _pinnedMessageList = updated;
    if (((TGMessage *)_pinnedMessageList.firstObject).mid != formerLeadId)
        _dismissedPinnedId = 0;
    [_pinnedListVariable set:[SSignal single:_pinnedMessageList]];
}

- (void)og_foldPinnedMessages:(NSArray *)messages
{
    if (messages.count == 0)
        return;
    
    TGDispatchOnMainThread(^
    {
        NSMutableArray *folded = [[NSMutableArray alloc] init];
        NSMutableSet *knownIds = [[NSMutableSet alloc] init];
        OGChannelPinnedAppendDistinct(folded, knownIds, messages);
        OGChannelPinnedAppendDistinct(folded, knownIds, _pinnedMessageList);
        [self og_applyPinnedMessages:folded];
    });
}

- (void)og_adoptServerPinnedMessages:(NSArray *)messages
{
    TGDispatchOnMainThread(^
    {
        TGMessage *current = _pinnedMessageList.firstObject;
        NSMutableArray *adopted = [[NSMutableArray alloc] init];
        NSMutableSet *knownIds = [[NSMutableSet alloc] init];
        
        for (TGMessage *candidate in (current != nil ? messages : @[]))
        {
            if (candidate.mid == current.mid)
            {
                [adopted addObject:candidate];
                [knownIds addObject:@(candidate.mid)];
                break;
            }
        }
        OGChannelPinnedAppendDistinct(adopted, knownIds, messages);
        [self og_applyPinnedMessages:adopted];
    });
}

- (void)og_jumpToPinnedMessage:(TGMessage *)message
{
    int32_t targetId = message.mid;
    if (targetId == 0)
        return;
    [self navigateToMessageId:targetId scrollBackMessageId:0 forceUnseenMention:false animated:true];
}

- (void)og_fillPinnedSheet:(TGMenuSheetController *)sheet fromOffset:(NSUInteger)offset animated:(bool)animated
{
    bool classicSheet = [TGPresentation classicThemeStyle];
    const NSUInteger perPage = classicSheet ? 5 : 8;
    NSUInteger total = _pinnedMessageList.count;
    if (total == 0)
    {
        [sheet dismissAnimated:true];
        return;
    }
    
    NSUInteger firstShown = MIN(offset, ((total - 1) / perPage) * perPage);
    NSUInteger pastLast = MIN(firstShown + perPage, total);
    
    OGChannelCompanionAnchor *ownerAnchor = _lifetimeAnchor;
    __weak TGMenuSheetController *weakSheet = sheet;
    void (^openPage)(NSUInteger) = ^(NSUInteger target)
    {
        [OGChannelCompanionFromAnchor(ownerAnchor) og_fillPinnedSheet:weakSheet fromOffset:target animated:true];
    };
    
    NSMutableArray *rows = [[NSMutableArray alloc] init];
    if (!classicSheet)
        [rows addObject:[[TGPinnedMessagesMenuHeaderItemView alloc] initWithMessageCount:total]];
    
    for (NSUInteger slot = firstShown; slot < pastLast; slot++)
    {
        TGMessage *pinned = _pinnedMessageList[slot];
        NSString *label = OGChannelPinnedMenuLabel(pinned);
        void (^choose)(void) = ^
        {
            [weakSheet dismissAnimated:true];
            [OGChannelCompanionFromAnchor(ownerAnchor) og_jumpToPinnedMessage:pinned];
        };
        
        if (classicSheet)
            [rows addObject:OGChannelPinnedSheetButton(OGChannelPinnedClassicButtonTitle(slot, label), choose)];
        else
            [rows addObject:[[TGPinnedMessageMenuItemView alloc] initWithTitle:label index:slot action:choose]];
    }
    
    if (firstShown > 0)
    {
        NSUInteger backStart = firstShown >= perPage ? firstShown - perPage : 0;
        NSUInteger backEnd = MIN(backStart + perPage, total);
        [rows addObject:OGChannelPinnedSheetButton(OGChannelPinnedPageTitle(backStart, backEnd, true), ^{ openPage(backStart); })];
    }
    
    if (pastLast < total)
    {
        NSUInteger forwardEnd = MIN(pastLast + perPage, total);
        [rows addObject:OGChannelPinnedSheetButton(OGChannelPinnedPageTitle(pastLast, forwardEnd, false), ^{ openPage(pastLast); })];
    }
    
    if (animated)
        [sheet setItemViews:rows animated:true];
    else
        [sheet setItemViews:rows];
}

- (void)og_showPinnedSheetFromPanel:(TGPinnedMessageTitlePanel *)panel
{
    if (_pinnedMessageList.count == 0)
        return;
    
    [self.controller endEditing];
    TGMenuSheetController *sheet = OGChannelMakeSheet();
    sheet.maxHeight = MIN(420.0f, self.controller.view.bounds.size.height - 44.0f);
    [self og_fillPinnedSheet:sheet fromOffset:0 animated:false];
    [self og_presentSheet:sheet anchoredAt:panel];
}

- (SSignal *)_requestPinnedMessages
{
    TLRPCmessages_search *query = [[TLRPCmessages_search alloc] init];
    query.peer = [TGTelegraphInstance createInputPeerForConversation:_conversationId accessHash:_accessHash];
    query.q = @"";
    query.filter = [[OGChannelPinnedSearchFilter alloc] init];
    query.min_date = query.max_date = 0;
    query.offset = query.max_id = 0;
    query.limit = 50;
    query.flags = 0;
    
    int64_t peerId = _conversationId;
    return [[[[TGTelegramNetworking instance] requestSignal:query] map:^id(TLmessages_Messages *result)
    {
        return OGChannelDecodePinnedResult(result);
    }] catch:^SSignal *(id error)
    {
        TGLog(@"TRACE pinned.search.error peer=%lld filter=inputMessagesFilterPinned scope=channel error=%@", peerId, error);
        return [SSignal single:[NSNull null]];
    }];
}

- (void)og_reloadPinnedMessages
{
    [_pinnedFetchDisposable dispose];
    OGChannelCompanionAnchor *ownerAnchor = _lifetimeAnchor;
    _pinnedFetchDisposable = [[[self _requestPinnedMessages] deliverOn:[SQueue mainQueue]] startWithNext:^(id payload)
    {
        TGChannelConversationCompanion *owner = OGChannelCompanionFromAnchor(ownerAnchor);
        if (owner != nil && [payload isKindOfClass:[NSArray class]])
            [owner og_adoptServerPinnedMessages:payload];
    }];
}

- (void)og_collectPinnedFromVisibleItems
{
    NSMutableArray *visible = [[NSMutableArray alloc] init];
    for (TGMessageModernConversationItem *entry in [self.controller _items])
    {
        if ([entry isKindOfClass:[TGMessageModernConversationItem class]])
            [visible addObject:entry->_message];
    }
    [self og_foldPinnedMessages:[self og_latestPinnedFromMessages:visible]];
}

- (TGModernConversationTitlePanel *)og_pinnedPanelForMessage:(TGMessage *)message
{
    _immediatePinnedMessage = message.mid;
    if (message == nil)
    {
        [self.controller setSecondaryTitlePanel:nil animated:true];
        return nil;
    }
    
    NSUInteger shownCount = MAX((NSUInteger)1, _pinnedMessageList.count);
    if (_pinnedBanner.message == message)
    {
        [_pinnedBanner setMessageCount:shownCount];
        return _pinnedBanner;
    }
    
    TGPinnedMessageTitlePanel *banner = [[TGPinnedMessageTitlePanel alloc] initWithMessage:message];
    [banner setMessageCount:shownCount];
    
    OGChannelCompanionAnchor *ownerAnchor = _lifetimeAnchor;
    int64_t channelPeerId = _conversationId;
    banner.dismiss = ^{
        TGChannelConversationCompanion *owner = OGChannelCompanionFromAnchor(ownerAnchor);
        if (owner == nil)
            return;
        if (![owner canPinMessage:message])
        {
            owner->_dismissedPinnedId = message.mid;
            [owner->_pinnedListVariable set:[SSignal single:owner->_pinnedMessageList]];
            [TGDatabaseInstance() updateChannelPinnedMessageId:channelPeerId pinnedMessageId:message.mid hidden:@(true)];
            return;
        }
        [[[[owner updatePinnedMessage:message.mid unpin:true] deliverOn:[SQueue mainQueue]] onDispose:^{
        }] startWithNext:nil error:^(__unused id error) {
            NSString *errorText = TGLocalized(@"Login.UnknownError");
            [TGCustomAlertView presentAlertWithTitle:nil message:errorText cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
        } completed:^{
        }];
    };
    banner.tapped = ^{
        TGChannelConversationCompanion *owner = OGChannelCompanionFromAnchor(ownerAnchor);
        if (owner == nil)
            return;
        if (owner->_pinnedMessageList.count > 1)
            [owner og_showPinnedSheetFromPanel:owner->_pinnedBanner];
        else
            [owner og_jumpToPinnedMessage:message];
    };
    _pinnedBanner = banner;
    return banner;
}

- (instancetype)initWithConversation:(TGConversation *)conversation userActivities:(NSDictionary *)userActivities {
    if (self != nil) {
        _primaryPanel = [[SVariable alloc] init];
        [_primaryPanel set:[SSignal single:nil]];
        _pinnedListVariable = [[SVariable alloc] init];
        [_pinnedListVariable set:[SSignal single:[NSNull null]]];
    }
    
    self = [super initWithConversation:conversation mayHaveUnreadMessages:false];
    if (self != nil) {
        _lifetimeAnchor = [[OGChannelCompanionAnchor alloc] init];
        _lifetimeAnchor.value = self;
        _genericInfoDisposables = [[SDisposableSet alloc] init];
        
        _conversation = conversation;
        _pinnedMessageList = @[];
        
        _accessHash = conversation.accessHash;
        _isGroup = conversation.isChannelGroup;
        _displayVariant = conversation.displayVariant;
        _kind = conversation.kind;
        _isCreator = conversation.channelRole == TGChannelRoleCreator;
        _adminRights = conversation.channelAdminRights;
        _bannedRights = conversation.channelBannedRights;
        if (!_isGroup) {
            _displayVariant = TGChannelDisplayVariantImportant;
        } else {
            _displayVariant = TGChannelDisplayVariantAll;
        }
        
        _isForbidden = conversation.kickedFromChat;
        _signaturesEnabled = conversation.signaturesEnabled;
        [self setPaidMessageStars:[self _paidMessagesPriceForConversation:conversation]];
        
        OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
        _cachedDataDisposable = [[[TGDatabaseInstance() channelCachedData:_conversationId] deliverOn:[SQueue mainQueue]] startWithNext:^(TGCachedConversationData *data) {
            TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
            if (strongSelf != nil) {
                [strongSelf setMemberCount:data.memberCount];
                [strongSelf setMigrationData:data.migrationData];
                [strongSelf setHasBots:data.botInfos.count != 0];
            }
        }];
        
        _updatedAdminsDisposable = [[SMetaDisposable alloc] init];
        if (_isGroup && !conversation.isMonoforum) {
            [_updatedAdminsDisposable setDisposable:[[[TGChannelManagementSignals updatedChannelAdmins:_conversationId accessHash:_accessHash] deliverOn:[SQueue mainQueue]] startWithNext:^(NSSet *adminIds) {
                TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                if (strongSelf != nil) {
                    [strongSelf setAdminIds:adminIds];
                }
            }]];
        }
        
        _manualMessageManagement = true;
        _everyMessageNeedsAuthor = true;
        
        _initialUserActivities = userActivities;
        
        [_genericInfoDisposables add:[[[TGDatabaseInstance() channelShouldMuteMembers:_conversationId] deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *next) {
            TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
            if (strongSelf != nil) {
                strongSelf->_messagesMuted = next;
                if (!strongSelf->_isGroup && (strongSelf->_isCreator || strongSelf->_adminRights.canPostMessages)) {
                    TGModernConversationController *controller = strongSelf.controller;
                    [controller setCanBroadcast:true];
                    [strongSelf updateBroadcasting];
                    [controller setIsAlwaysBroadcasting:false];
                }
            }
        }]];
        
        if (_isGroup && !conversation.isMonoforum) {
            _groupedUserStatusesDisposable = [[SMetaDisposable alloc] init];
            
            int64_t conversationId = _conversationId;
            int64_t accessHash = _accessHash;
            
            SSignal *changedPrecondition = [[[TGDatabaseInstance() channelCachedData:conversationId] map:^id(TGCachedConversationData *cachedData) {
                return @(cachedData.memberCount != 0 && cachedData.memberCount <= 200);
            }] ignoreRepeated];
            
            
            SSignal *users = [changedPrecondition mapToSignal:^SSignal *(NSNumber *shouldCountOnlines) {
                if ([shouldCountOnlines boolValue]) {
                    SSignal *cachedUsers = [[[TGDatabaseInstance() channelCachedData:conversationId] map:^id (TGCachedConversationData *cachedData) {
                        NSMutableArray *users = [[NSMutableArray alloc] init];
                        for (TGCachedConversationMember *member in cachedData.generalMembers) {
                            TGUser *user = [TGDatabaseInstance() loadUser:member.uid];
                            if (user != nil) {
                                [users addObject:user];
                            }
                        }
                        return users;
                    }] take:1];
                    
                    return [cachedUsers then:[[TGChannelManagementSignals channelMembers:conversationId accessHash:accessHash offset:0 count:200] map:^id(NSDictionary *dict) {
                        [TGDatabaseInstance() updateChannelCachedData:conversation.conversationId block:^TGCachedConversationData *(TGCachedConversationData *data) {
                            if (data == nil) {
                                data = [[TGCachedConversationData alloc] init];
                            }
                            
                            NSMutableArray *sortedMemberDatas = [[NSMutableArray alloc] init];
                            NSDictionary *memberDatas = dict[@"memberDatas"];
                            for (TGUser *user in dict[@"users"]) {
                                TGCachedConversationMember *member = memberDatas[@(user.uid)];
                                if (member != nil) {
                                    [sortedMemberDatas addObject:member];
                                }
                            }
                            
                            return [data updateGeneralMembers:sortedMemberDatas];
                        }];
                        
                        return dict[@"users"];
                    }]];
                } else {
                    return [SSignal single:@[]];
                }
            }];
            
            SSignal *groupedInfo = [TGGroupedUserOnlineSignals groupedOnlineInfoForUserList:users];
            [_groupedUserStatusesDisposable setDisposable:[[groupedInfo deliverOn:[SQueue mainQueue]] startWithNext:^(TGGroupedUserOnlineInfo *groupedOnlineInfo) {
                TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                if (strongSelf != nil) {
                    strongSelf->_groupedOnlineInfo = groupedOnlineInfo;
                    [strongSelf updateStatus];
                }
            }]];
        }
        
        _pinnedMessage = [[SVariable alloc] init];
        int64_t conversationId = _conversationId;
        int64_t accessHash = _accessHash;
        
        _initialMayHaveUnreadMessages = _conversation.kind == TGConversationKindPersistentChannel && (_conversation.unreadCount != 0 || (_displayVariant == TGChannelDisplayVariantAll && _conversation.serviceUnreadCount != 0));
        
        SSignal *pinnedId = [[[TGDatabaseInstance() existingChannel:_conversationId] map:^id(TGConversation *conversation) {
            return @(conversation.pinnedMessageHidden ? 0 : conversation.pinnedMessageId);
        }] ignoreRepeated];
        
        [_pinnedMessage set:[pinnedId mapToSignal:^SSignal *(NSNumber *nPinnedMessageId) {
            int32_t pinnedMessageId = [nPinnedMessageId intValue];
            return [[TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id{
                if (pinnedMessageId == 0) {
                    return [SSignal single:[NSNull null]];
                } else {
                    TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:pinnedMessageId peerId:conversationId];
                    if (message != nil) {
                        return [SSignal single:message];
                    } else {
                        return [[TGDownloadMessagesSignal downloadMessages:@[[[TGDownloadMessage alloc] initWithPeerId:conversationId accessHash:accessHash messageId:pinnedMessageId]]] mapToSignal:^SSignal *(NSArray *messages) {
                            return [TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id{
                                for (TGMessage *message in messages) {
                                    if (message.mid == pinnedMessageId) {
                                        [TGDatabaseInstance() addMessagesToChannel:conversationId messages:@[message] deleteMessages:nil unimportantGroups:nil addedHoles:nil removedHoles:nil removedUnimportantHoles:nil updatedMessageSortKeys:nil returnGroups:false keepUnreadCounters:false skipFeedUpdate:true changedMessages:nil];
                                        return message;
                                    }
                                }
                                return [NSNull null];
                            }];
                        }];
                    }
                }
            }] switchToLatest];
        }]];

        SSignal *effectivePinnedMessage = [[SSignal combineSignals:@[_pinnedMessage.signal, _pinnedListVariable.signal]
                                                       withInitialStates:@[[NSNull null], [NSNull null]]] map:^id(NSArray *values)
        {
            TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
            if (strongSelf == nil)
                return [NSNull null];
            return OGChannelVisiblePinnedMessage(values, strongSelf->_dismissedPinnedId);
        }];

        SSignal *combinedPinnedMessageAndShouldReportSpam = [SSignal combineSignals:@
         [
          effectivePinnedMessage,
          [[TGDatabaseInstance() shouldReportSpamForPeerId:_conversationId] ignoreRepeated],
          [self liveLocationSignal]
        ] withInitialStates:@[[NSNull null], @false, @[]]];
        
        SSignal *panelSignal = [[combinedPinnedMessageAndShouldReportSpam deliverOn:[SQueue mainQueue]] map:^id(NSArray *pinnedMessageAndReportSpam) {
            TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
            TGModernConversationTitlePanel *resultPanel = nil;
            if (strongSelf != nil) {
                if ([pinnedMessageAndReportSpam[1] boolValue]) {
                    if (strongSelf->_reportSpamPanel == nil) {
                        TGModernConversationContactLinkTitlePanel *panel = [[TGModernConversationContactLinkTitlePanel alloc] init];
                        panel.delegate = strongSelf;
                        [panel setShareContact:false addContact:false reportSpam:true];
                        strongSelf->_reportSpamPanel = panel;
                    }
                    resultPanel = strongSelf->_reportSpamPanel;
                } else {
                    NSArray *liveLocations = (NSArray *)pinnedMessageAndReportSpam[2];
                    TGLiveLocation *ownLiveLocation = nil;
                    for (TGLiveLocation *liveLocation in liveLocations)
                    {
                        if (liveLocation.hasOwnSession)
                        {
                            ownLiveLocation = liveLocation;
                            break;
                        }
                    }
                    
                    if (!strongSelf->_isGroup && ownLiveLocation != nil)
                        liveLocations = @[ownLiveLocation];
                    
                    TGMessage *pinnedMessage = pinnedMessageAndReportSpam[0];
                    bool pinnedMessageIsLiveLocation = false;
                    if ([pinnedMessage isKindOfClass:[TGMessage class]])
                    {
                        int32_t currentTime = (int32_t)OGRemoteClockTime();
                        TGLocationMediaAttachment *location = pinnedMessage.locationAttachment;
                        if (location.period > 0 && currentTime < pinnedMessage.date + location.period)
                            pinnedMessageIsLiveLocation = true;
                    }
                    
                    if (ownLiveLocation != nil || pinnedMessageIsLiveLocation)
                    {
                        if (strongSelf->_locationPanel == nil)
                            strongSelf->_locationPanel = [[TGLiveLocationTitlePanel alloc] init];
                        
                        __weak TGLiveLocationTitlePanel *weakPanel = strongSelf->_locationPanel;
                        strongSelf->_locationPanel.tapped = ^
                        {
                            TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                            if (strongSelf == nil)
                                return;
                            
                            TGLiveLocation *liveLocationToOpen = nil;
                            int32_t latestLiveLocationDate = 0;
                            for (TGLiveLocation *liveLocation in liveLocations)
                            {
                                if (liveLocation.hasOwnSession)
                                {
                                    liveLocationToOpen = liveLocation;
                                    break;
                                }
                                
                                if ([liveLocation.message actualDate] > latestLiveLocationDate)
                                {
                                    liveLocationToOpen = liveLocation;
                                    latestLiveLocationDate = [liveLocation.message actualDate];
                                }
                            }
                            
                            [strongSelf.controller openLocationFromMessage:pinnedMessageIsLiveLocation ? pinnedMessage : liveLocationToOpen.message previewMode:false zoomToFitAll:liveLocations.count > 0];
                        };
                        strongSelf->_locationPanel.closed = ^
                        {
                            TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                            if (strongSelf == nil)
                                return;
                            
                            [strongSelf.controller endEditing];
                            
                            bool hasOwn = false;
                            for (TGLiveLocation *liveLocation in liveLocations)
                            {
                                if (liveLocation.hasOwnSession)
                                {
                                    hasOwn = true;
                                    break;
                                }
                            }
                            
                            if (hasOwn)
                            {
                                TGMenuSheetController *sheet = OGChannelMakeSheet();
                                __weak TGMenuSheetController *weakSheet = sheet;
                                TGMenuSheetButtonItemView *stopButton = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Map.StopLiveLocation") type:TGMenuSheetButtonTypeDestructive action:^
                                {
                                    TGMenuSheetController *openSheet = weakSheet;
                                    if (openSheet == nil)
                                        return;
                                    
                                    [openSheet dismissAnimated:true];
                                    [TGTelegraphInstance.liveLocationManager stopWithPeerId:strongSelf.conversationId];
                                }];
                                TGMenuSheetButtonItemView *cancelButton = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel action:^
                                {
                                    [weakSheet dismissAnimated:true];
                                }];
                                
                                [sheet setItemViews:@[stopButton, cancelButton]];
                                [strongSelf og_presentSheet:sheet anchoredAt:weakPanel];
                            }
                            else
                            {
                                [TGDatabaseInstance() updateChannelPinnedMessageId:conversationId pinnedMessageId:pinnedMessage.mid hidden:@(true)];
                            }
                        };
                        
                        [strongSelf->_locationPanel setLiveLocations:liveLocations];
                        resultPanel = strongSelf->_locationPanel;
                    }
                    else
                    {
                        TGMessage *message = [pinnedMessageAndReportSpam[0] isKindOfClass:[TGMessage class]] ? pinnedMessageAndReportSpam[0] : nil;
                        resultPanel = [strongSelf og_pinnedPanelForMessage:message];
                    }
                }
                
                return resultPanel;
            } else {
                return nil;
            }
        }];
        
        [_primaryPanel set:panelSignal];
        
        _updatedPeerSettingsDisposable = [[TGAccountSignals updatedShouldReportSpamForPeer:_conversationId accessHash:_accessHash] startWithNext:nil];
    }
    return self;
}

- (bool)_paidMessagesExemptForConversation:(TGConversation *)conversation
{
    return conversation.channelRole == TGChannelRoleCreator || conversation.channelAdminRights != nil;
}

- (int64_t)_paidMessagesPriceForConversation:(TGConversation *)conversation
{
    if (conversation == nil || !conversation.isChannelGroup || [self _paidMessagesExemptForConversation:conversation])
        return 0;
    return conversation.sendPaidMessagesStars;
}

- (void)paidMessagesPriceChanged:(int64_t)stars
{
    TGConversation *conversation = _conversation;
    if (conversation != nil && [self _paidMessagesExemptForConversation:conversation])
        stars = 0;
    [self setPaidMessageStars:stars];
}

- (void)dealloc {
    [self.actionHandle reset];
    @synchronized (_lifetimeAnchor)
    {
        _lifetimeAnchor.value = nil;
    }
    [_requestingHoleDisposable dispose];
    [_managedState dispose];
    [_extendedDataDisposable dispose];
    [_cachedDataDisposable dispose];
    [_updatedAdminsDisposable dispose];
    [_updatingInvalidatedMessagesDisposable dispose];
    [_genericInfoDisposables dispose];
    [_groupedUserStatusesDisposable dispose];
    [_updatedPeerSettingsDisposable dispose];
    [_pinnedFetchDisposable dispose];
}

- (void)setMemberCount:(int32_t)memberCount {
    if (_memberCount != memberCount) {
        _memberCount = memberCount;
        [self updateStatus];
    }
}

- (void)setMigrationData:(TGConversationMigrationData *)migrationData {
    [TGModernConversationCompanion dispatchOnMessageQueue:^{
        _migrationData = migrationData;
        _attachedConversationId = _migrationData.peerId;
        
        if (_migrationData != nil && !_migrationHistoryAbove) {
            _migrationHistoryAbove = true;
            if (!_loadingHistoryAbove) {
                TGDispatchOnMainThread(^{
                    [self loadMoreMessagesAbove];
                });
            }
        }
    }];
}

- (void)setHasBots:(bool)hasBots {
    hasBots = _isGroup && hasBots;
    TGDispatchOnMainThread(^{
        if (_hasBots != hasBots) {
            _hasBots = hasBots;
            
            self.viewContext.commandsEnabled = hasBots;
            TGModernConversationController *controller = self.controller;
            [controller setHasBots:_hasBots];
        }
    });
}

- (void)setAdminIds:(NSSet *)adminIds {
    if (![_adminIds isEqualToSet:adminIds]) {
        _adminIds = adminIds;
        
        [TGModernConversationCompanion dispatchOnMessageQueue:^
         {
             self.viewContext.adminIds = adminIds;
             
             NSMutableArray *updatedItems = [[NSMutableArray alloc] init];
             NSMutableArray *updatedIndices = [[NSMutableArray alloc] init];
             
             for (NSUInteger i = 0; i < _items.count; i++)
             {
                 TGMessageModernConversationItem *item = _items[i];
                 
                 bool byAdmin = [self.viewContext isByAdmin:item->_message];
                 if (item->_byAdmin != byAdmin)
                 {
                     item = [item copy];
                     [updatedItems addObject:item];
                     [updatedIndices addObject:@(i)];
                 }
             }
          
             if (updatedItems.count != 0)
             {
                 TGDispatchOnMainThread(^
                 {
                     TGModernConversationController *controller = self.controller;
                     int index = -1;
                     for (NSNumber *nIndex in updatedIndices)
                     {
                         index++;
                         [controller updateItemAtIndex:[nIndex intValue] toItem:updatedItems[index] delayAvailability:false animated:true animateTransition:false force:true];
                     }
                 });
             }
         }];
    }
}

- (void)_startManagedStateWhenReady {
#if defined(ONEGRAM_ARMV6)
    if (![NSThread isMainThread]) {
        OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
        OGPlatformDispatchOnMainThread(^{
            TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
            if (strongSelf != nil) {
                [strongSelf _startManagedStateWhenReady];
            }
        });
        return;
    }
    if (!_hasAppearedOnce || _initialHistoryPending) {
        return;
    }
#endif
    if (_managedState == nil) {
        _managedState = [[TGChannelStateSignals updatedChannel:_conversationId] startWithNext:nil];
    }
}

- (void)_markInitialHistoryPending {
#if defined(ONEGRAM_ARMV6)
    _initialHistoryPending = true;
#endif
}

- (void)_finishInitialLoadingOverlay {
    [self _markInitialHistoryResolved];
    OGPlatformDispatchOnMainThread(^{
        [self.controller setLoadingMessages:false];
    });
}

- (void)_markInitialHistoryResolved {
#if defined(ONEGRAM_ARMV6)
    OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
    OGPlatformDispatchOnMainThread(^{
        TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
        if (strongSelf != nil) {
            strongSelf->_initialHistoryPending = false;
            [strongSelf _startManagedStateWhenReady];
        }
    });
#endif
}

- (void)_controllerDidAppear:(bool)firstTime {
    [super _controllerDidAppear:firstTime];
    [self _scheduleReadHistoryAfterAppear:firstTime ? @"firstAppear" : @"appear"];
    [self og_collectPinnedFromVisibleItems];
    [self og_reloadPinnedMessages];
    
    if (firstTime) {
#if defined(ONEGRAM_ARMV6)
        _hasAppearedOnce = true;
#endif
        [self _startManagedStateWhenReady];
        
        _enableVisibleMessagesProcessing = true;
        
        _extendedDataDisposable = [[TGChannelManagementSignals updateChannelExtendedInfo:_conversationId accessHash:_accessHash updateUnread:false] startWithNext:nil];
        
        if (!_isGroup && _isForbidden) {
            [TGCustomAlertView presentAlertWithTitle:nil message:[NSString stringWithFormat:TGLocalized(@"ChannelInfo.ChannelForbidden"), _conversation.chatTitle] cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
        }
        
        if (_invalidatedPtsDisposable == nil) {
            OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
            _invalidatedPtsDisposable = [[TGDatabaseInstance() channelHistoryPtsForPeerId:_conversationId] startWithNext:^(NSNumber *nInvalidatedPts) {
                [TGModernConversationCompanion dispatchOnMessageQueue:^{
                    TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                    if (strongSelf != nil) {
                        [strongSelf setInvalidatedPts:[nInvalidatedPts intValue]];
                    }
                }];
            }];
        }
        
        [TGModernConversationCompanion dispatchOnMessageQueue:^{
            [self _updateVisibleHoles];
        }];
    }
}

- (void)_controllerAvatarPressed
{
    TGModernConversationController *controller = self.controller;
    TGCollectionMenuController *groupInfoController = nil;
    int64_t broadcastPeerId = _conversation.isMonoforum ? TGPeerIdFromChannelId(_conversation.linkedMonoforumId) : 0;
    if (broadcastPeerId != 0) {
        groupInfoController = [[TGChannelInfoController alloc] initWithPeerId:broadcastPeerId];
    } else if (_isGroup) {
        groupInfoController = [[TGChannelGroupInfoController alloc] initWithPeerId:_conversationId];
    } else {
        groupInfoController = [[TGChannelInfoController alloc] initWithPeerId:_conversationId];
    }
    
    if (controller.currentSizeClass == UIUserInterfaceSizeClassCompact) {
        [controller.navigationController pushViewController:groupInfoController animated:true];
    }
    else
    {
        if (controller != nil)
        {
            TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[groupInfoController] navigationBarClass:[TGWhiteNavigationBar class]];
            navigationController.presentationStyle = TGNavigationControllerPresentationStyleRootInPopover;
            TGPopoverController *popoverController = [[TGPopoverController alloc] initWithContentViewController:navigationController];
            navigationController.parentPopoverController = popoverController;
            navigationController.detachFromPresentingControllerInCompactMode = true;
            [popoverController setContentSize:CGSizeMake(320.0f, 528.0f)];
            
            controller.associatedPopoverController = popoverController;
            [popoverController presentPopoverFromBarButtonItem:controller.navigationItem.rightBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:true];
            groupInfoController.collectionView.contentOffset = CGPointMake(0.0f, -groupInfoController.collectionView.contentInset.top);
        }
    }
}

- (void)_createOrUpdatePrimaryTitlePanel:(bool)__unused createIfNeeded
{
    TGModernConversationController *controller = self.controller;
    
    TGModernConversationGroupTitlePanel *groupTitlePanel = nil;
    if ([[controller primaryTitlePanel] isKindOfClass:[TGModernConversationGroupTitlePanel class]])
        groupTitlePanel = (TGModernConversationGroupTitlePanel *)[controller primaryTitlePanel];
    else
    {
        if (createIfNeeded)
        {
            groupTitlePanel = [[TGModernConversationGroupTitlePanel alloc] init];
            groupTitlePanel.companionHandle = self.actionHandle;
        }
        else
            return;
    }
    
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    TGPresentation *presentation = self.controller.presentation;
    [actions addObject:@{@"title": TGLocalized(@"Conversation.Search"), @"icon": presentation.images.chatTitleSearchIcon, @"action": @"search"}];
    if (_isGroup && _conversation.username.length != 0) {
        [actions addObject:@{@"title": TGLocalized(@"ReportPeer.Report"), @"icon": presentation.images.chatTitleReportIcon, @"action": @"report"}];
    }
    if (_isMuted)
        [actions addObject:@{@"title": TGLocalized(@"Conversation.Unmute"), @"icon": presentation.images.chatTitleUnmuteIcon, @"action": @"unmute"}];
    else
        [actions addObject:@{@"title": TGLocalized(@"Conversation.Mute"), @"icon": presentation.images.chatTitleMuteIcon, @"action": @"mute"}];
    [actions addObject:@{@"title": TGLocalized(@"Conversation.Info"), @"icon": presentation.images.chatTitleInfoIcon, @"action": @"info"}];
    [groupTitlePanel setPresentation:presentation];
    [groupTitlePanel setButtonsWithTitlesAndActions:[self _titlePanelActionsWithPluginActions:actions]];
    
    [controller setPrimaryTitlePanel:groupTitlePanel];
}

- (void)_loadControllerPrimaryTitlePanel {
    [self _createOrUpdatePrimaryTitlePanel:true];
}

- (TGModernConversationInputPanel *)_conversationGenericInputPanel {
    TGPresentation *presentation = self.controller.presentation;
    if (_bannedRights != nil && _bannedRights.banSendMessages) {
        if (_restrictedPanel == nil) {
            _restrictedPanel = [[TGModernConversationRestrictedInputPanel alloc] init];
        }
        [_restrictedPanel setTimeout:_bannedRights.timeout];
        return _restrictedPanel;
    } else if (_isForbidden) {
        if (_deletePanel == nil) {
            TGModernConversationController *controller = self.controller;
            _deletePanel = [[TGModernConversationActionInputPanel alloc] init];
            [_deletePanel setActionWithTitle:TGLocalized(@"DialogList.DeleteConversationConfirmation") action:@"delete" color:presentation.pallete.accentColor icon:TGModernConversationActionInputPanelIconNone];
            _deletePanel.companionHandle = self.actionHandle;
            _deletePanel.delegate = controller;
        }
        return _deletePanel;
    } else if (_kind != TGConversationKindPersistentChannel && !_conversation.isMonoforum)
    {
        if (_joinChannelPanel == nil)
        {
            TGModernConversationController *controller = self.controller;
            _joinChannelPanel = [[TGModernConversationActionInputPanel alloc] init];
            [_joinChannelPanel setActionWithTitle:TGLocalized(@"Channel.JoinChannel") action:@"joinchannel" color:presentation.pallete.accentColor icon:TGModernConversationActionInputPanelIconJoin];
            _joinChannelPanel.companionHandle = self.actionHandle;
            _joinChannelPanel.delegate = controller;
        }
        return _joinChannelPanel;
    } else if (![self canPostMessages]) {
        if (_mutePanel == nil) {
            TGModernConversationController *controller = self.controller;
            _mutePanel = [[TGModernConversationActionInputPanel alloc] init];
            _mutePanel.companionHandle = self.actionHandle;
            _mutePanel.delegate = controller;
            [self _updateMutePanel];
        }
        return _mutePanel;
    }
    
    return nil;
}
               
- (void)_updateMutePanel {
    [_mutePanel setActionWithTitle:!_isMuted ? TGLocalized(@"Conversation.Mute") : TGLocalized(@"Conversation.Unmute") action:@"toggleMute" color:self.controller.presentation.pallete.accentColor icon:_isMuted ? TGModernConversationActionInputPanelIconUnmute : TGModernConversationActionInputPanelIconMute];
    [_mutePanel setSecondaryAction:_conversation.username.length != 0 ? @"share" : nil icon:TGModernConversationActionInputPanelIconShare];
}

- (void)_shareChannel {
    TGModernConversationController *controller = self.controller;
    if (controller == nil)
        return;
    
    __weak TGModernConversationController *weakController = controller;
    __weak TGModernConversationActionInputPanel *weakPanel = _mutePanel;
    CGRect (^sourceRect)(void) = ^CGRect {
        __strong TGModernConversationController *strongController = weakController;
        __strong TGModernConversationActionInputPanel *strongPanel = weakPanel;
        if (strongController == nil || strongPanel == nil)
            return CGRectZero;
        
        return [strongPanel convertRect:strongPanel.bounds toView:strongController.view];
    };
    
    [TGShareMenu presentChannelShareMenuInParentController:controller conversation:_conversation sourceView:controller.view sourceRect:sourceRect];
}

- (bool)canPostMessages {
    if (_isGroup) {
        return true;
    } else {
        return _isCreator || _adminRights.canPostMessages;
    }
}

- (void)_updateJoinPanel {
    TGModernConversationController *controller = self.controller;
    [controller setDefaultInputPanel:[self _conversationGenericInputPanel]];
}

- (void)actionStageActionRequested:(NSString *)action options:(id)options {
    if ([action isEqualToString:@"ios6OpenComments"]) {
        int32_t messageId = [options[@"mid"] intValue];
        int64_t discussionChannelId = [options[@"discussionChannelId"] longLongValue];
        [[TGInterfaceManager instance] navigateToCommentsForChannelConversation:_conversation
                                                                      messageId:messageId
                                                            discussionChannelId:discussionChannelId
                                                           navigationController:self.controller.navigationController];
        return;
    } else if ([action isEqualToString:@"titlePanelAction"]) {
        NSString *panelAction = options[@"action"];
        
        if ([panelAction isEqualToString:@"switchMode"]) {
            [self _toggleTitleMode];
        } else if ([panelAction isEqualToString:@"mute"]) {
            [self _commitEnableNotifications:false];
        } else if ([panelAction isEqualToString:@"unmute"]) {
            [self _commitEnableNotifications:true];
        } else if ([panelAction isEqualToString:@"edit"]) {
            [self.controller enterEditingMode];
        } else if ([panelAction isEqualToString:@"report"]) {
            [self reportChannelPressed];
        } else if ([panelAction isEqualToString:@"info"]) {
            [self _controllerAvatarPressed];
        } else if ([panelAction isEqualToString:@"search"]) {
            [self navigateToMessageSearch];
        }
    } else if ([action isEqualToString:@"openMessageGroup"]) {
    } else if ([action isEqualToString:@"actionPanelAction"]) {
        NSString *panelAction = options[@"action"];
        if ([panelAction isEqualToString:@"joinchannel"]) {
            [self requestJoinChannel];
            
            [TGAppDelegateInstance.rootController.dialogListController maybeDismissSearchResults];
        } else if ([panelAction isEqualToString:@"toggleMute"]) {
            [self _commitEnableNotifications:_isMuted];
        } else if ([panelAction isEqualToString:@"share"]) {
            [self _shareChannel];
        } else if ([panelAction isEqualToString:@"delete"]) {
            TGModernConversationController *controller = self.controller;
            
            [TGAppDelegateInstance.rootController.dialogListController.dialogListCompanion deleteItem:[[TGConversation alloc] initWithConversationId:_conversationId unreadCount:0 serviceUnreadCount:0] animated:false];
            
            if (controller.popoverController != nil) {
                dispatch_async(dispatch_get_main_queue(), ^ {
                    [controller.popoverController dismissPopoverAnimated:true];
                });
            }
            else {
                [controller.navigationController popToRootViewControllerAnimated:true];
            }
        }
    }

    [super actionStageActionRequested:action options:options];
}

- (void)_commitEnableNotifications:(bool)enable
{
    if (_isMuted != !enable) {
        _isMuted = !enable;
        
        [self _updateMutePanel];
        
        NSNumber *muteUntil = enable ? @0: @(INT32_MAX);
        _groupNotificationSettings[@"muteUntil"] = muteUntil;
        
        static int actionId = 0;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%" PRId64 ")/(channelControllerMute%d)", _conversationId, actionId++] options:@{@"peerId": @(_conversationId), @"accessHash": @(_accessHash), @"muteUntil": muteUntil} watcher:TGTelegraphInstance];
        
        [self _updateNotifcationSettings];
    }
}

- (void)_updateChannelMute
{
    TGDispatchOnMainThread(^
    {
        if (_isMuted)
        {
            TGModernConversationTitleIcon *muteIcon = [[TGModernConversationTitleIcon alloc] init];
            muteIcon.bounds = CGRectMake(0.0f, 0.0f, 16, 16);
            muteIcon.offsetWeight = 0.5f;
            muteIcon.imageOffset = CGPointMake(4.0f, 7.0f);
            
            muteIcon.image = self.controller.presentation.images.chatTitleMutedIcon;
            muteIcon.iconPosition = TGModernConversationTitleIconPositionAfterTitle;
            [self _setTitleIcons:@[muteIcon]];
        }
        else
            [self _setTitleIcons:nil];
        
        [self _createOrUpdatePrimaryTitlePanel:false];
    });
}

- (NSString *)title
{
    return [self titleForConversation:_conversation];
}

- (TGConversation *)conversation
{
    return _conversation;
}

- (TGConversation *)_identityConversationForConversation:(TGConversation *)conversation
{
    TGConversation *broadcast = [TGChannelDirectMessagesSignals broadcastChannelForMonoforum:conversation];
    return broadcast != nil ? broadcast : conversation;
}

- (void)applyAvatarForConversation:(TGConversation *)conversation
{
    TGConversation *identity = [self _identityConversationForConversation:conversation];
    [self _setAvatarConversationId:identity.conversationId title:identity.chatTitle icon:nil];
    [self _setAvatarUrl:identity.chatPhotoFullSmall];
}

- (void)loadInitialState {
    [super loadInitialState:false];
    
    TGModernConversationController *controller = self.controller;
    if (!_isGroup) {
        [controller setIsChannel:true];
    }
    
    [controller setConversationHeader:[self _conversationHeader]];
    
    self.viewContext.isPublicGroup = _conversation.isChannelGroup && _conversation.username.length != 0;
    
    if (!_isGroup) {
        if (_isCreator || _adminRights.canPostMessages) {
            [controller setCanBroadcast:true];
            [self updateBroadcasting];
            [controller setIsAlwaysBroadcasting:false];
        } else {
            [controller setCanBroadcast:false];
            [controller setIsBroadcasting:false];
            [controller setIsAlwaysBroadcasting:true];
        }
    }
    
    [controller setBannedStickers:_bannedRights.banSendStickers];
    [controller setBannedMedia:_bannedRights.banSendMedia];
    
    self.viewContext.conversation = _conversation;
    
    __block NSArray *topMessages = nil;
    __block NSArray *topMigrationMessages = nil;
    __block TGConversationMigrationData *migrationData = nil;
    __block int32_t missingPreloadedAreaAtMessageId = 0;
    __block int32_t messageIdForVisibleHoleDirection = 0;
    __block int32_t earliestUnreadMessageId = 0;
    NSUInteger initialChannelMessageCount = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone ? (OGRuntimeSingleCoreDevice() ? 10 : 20) : 28;
#if defined(ONEGRAM_ARMV6)
    initialChannelMessageCount = 12;
#endif
    
    [TGDatabaseInstance() dispatchOnDatabaseThread:^{
        __block TGMessageTransparentSortKey maxSortKey = TGMessageTransparentSortKeyUpperBound(_conversationId);
        
        bool canBeUnread = _conversation.kind == TGConversationKindPersistentChannel && (_conversation.unreadCount != 0 || (_displayVariant == TGChannelDisplayVariantAll && _conversation.serviceUnreadCount != 0));
        
        if (_preferredInitialPositionedMessageId != 0) {
            [TGDatabaseInstance() channelMessageExists:_conversationId messageId:_preferredInitialPositionedMessageId completion:^(bool exists, TGMessageSortKey key) {
                if (exists) {
                    if (TGMessageSortKeySpace(key) == TGMessageSpaceUnimportant) {
                        _displayVariant = TGChannelDisplayVariantAll;
                    }
                    maxSortKey = TGMessageTransparentSortKeyMake(_conversationId, TGMessageSortKeyTimestamp(key), TGMessageSortKeyMid(key), TGMessageSortKeySpace(key));
                    if (_initialScrollState == nil || _initialScrollState.messageId == 0) {
                        [self setInitialMessagePositioning:TGMessageSortKeyMid(key) initialPositionedPeerId:0 position:TGInitialScrollPositionCenter offset:0.0f];
                    }
                    messageIdForVisibleHoleDirection = TGMessageSortKeyMid(key);
                }
            }];
        } else if (canBeUnread) {
            if ([TGChannelManagementSignals _containsPreloadedHistoryForPeerId:_conversationId aroundMessageId:_conversation.maxReadMessageId]) {
                [TGDatabaseInstance() nextChannelIncomingMessageKey:_conversationId messageId:_conversation.maxReadMessageId + 1 completion:^(bool exists, TGMessageSortKey key) {
                    if (exists) {
                        maxSortKey = TGMessageTransparentSortKeyMake(_conversationId, TGMessageSortKeyTimestamp(key), TGMessageSortKeyMid(key), TGMessageSortKeySpace(key));
                        [self setInitialMessagePositioning:TGMessageSortKeyMid(key) initialPositionedPeerId:0 position:TGInitialScrollPositionTop offset:[self.controller initialUnreadOffset]];
                        
                        TGMessageRange unreadRange = TGMessageRangeEmpty();
                        
                        unreadRange.firstDate = TGMessageSortKeyTimestamp(key);
                        unreadRange.lastDate = INT32_MAX;
                        unreadRange.firstMessageId = TGMessageSortKeyMid(key);
                        unreadRange.lastMessageId = INT32_MAX;
                        
                        self.unreadMessageRange = unreadRange;
                        
                        messageIdForVisibleHoleDirection = TGMessageSortKeyMid(key);
                    }
                }];
            } else {
                missingPreloadedAreaAtMessageId = _conversation.maxReadMessageId;
            }
        }
        
        TGCachedConversationData *cachedData = [TGDatabaseInstance() _channelCachedDataSync:_conversationId];
        migrationData = cachedData.migrationData;
        _hasBots = _isGroup && cachedData.botInfos.count != 0;
        
        if (missingPreloadedAreaAtMessageId == 0) {
            [TGDatabaseInstance() channelMessages:_conversationId maxTransparentSortKey:maxSortKey count:(int)initialChannelMessageCount important:_displayVariant == TGChannelDisplayVariantImportant mode:TGChannelHistoryRequestAround completion:^(NSArray *messages, bool hasLater) {
                topMessages = messages;
                _historyBelow = hasLater;
            }];
            
            
            if (topMessages.count < initialChannelMessageCount && migrationData != nil) {
                [TGDatabaseInstance() loadMessagesFromConversation:migrationData.peerId maxMid:migrationData.maxMessageId maxDate:TGMessageTransparentSortKeyTimestamp(maxSortKey) maxLocalMid:0 atMessageId:0 limit:(int)initialChannelMessageCount extraUnread:false completion:^(NSArray *messages, __unused bool historyExistsBelow) {
                    NSMutableArray *updatedMessages = [[NSMutableArray alloc] init];
                    
                    for (TGMessage *message in messages) {
                        if (message.mid < TGMessageLocalMidBaseline) {
                            message.mid += migratedMessageIdOffset;
                            [updatedMessages addObject:message];
                        }
                    }
                    
                    topMigrationMessages = updatedMessages;
                }];
            }
        }
    } synchronous:true];
    _historyAbove = topMessages.count != 0;
    _migrationData = migrationData;
    _attachedConversationId = _migrationData.peerId;
    _migrationHistoryAbove = topMigrationMessages.count != 0;
    self.viewContext.commandsEnabled = _hasBots;
    
    if (missingPreloadedAreaAtMessageId == 0) {
        [self _replaceMessages:[topMessages arrayByAddingObjectsFromArray:topMigrationMessages] atMessageId:0 peerId:0 expandFrom:0 jump:false top:false messageIdForVisibleHoleDirection:messageIdForVisibleHoleDirection scrollBackMessageId:0 animated:false];
        if (earliestUnreadMessageId != 0) {
            [controller pushEarliestUnreadMessageId:earliestUnreadMessageId];
        }
        
        if (topMessages.count < initialChannelMessageCount) {
            int64_t conversationId = _conversationId;
            int64_t accessHash = _accessHash;
            bool showInitialLoading = topMessages.count == 0;
            OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
            __block bool receivedResult = false;
            
            if (showInitialLoading) {
                [self _markInitialHistoryPending];
                [controller setLoadingMessages:true];
            }
            
            [[TGChannelManagementSignals preloadedHistoryTailForPeerId:conversationId accessHash:accessHash] startWithNext:^(NSDictionary *dict) {
                receivedResult = true;
                TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                if (strongSelf == nil) {
                    return;
                }
                
                NSArray *remoteMessages = OGChannelRemoteMessagesFromResult(dict);
                if (remoteMessages.count == 0) {
                    if (showInitialLoading) {
                        [strongSelf _finishInitialLoadingOverlay];
                    }
                    return;
                }
                
                NSArray *removedImportantHoles = OGChannelHoleListFromResult(dict);
                NSArray *removedUnimportantHoles = removedImportantHoles;
                
                [TGDatabaseInstance() addMessagesToChannel:conversationId messages:remoteMessages deleteMessages:nil unimportantGroups:dict[@"unimportantGroups"] addedHoles:nil removedHoles:removedImportantHoles removedUnimportantHoles:removedUnimportantHoles updatedMessageSortKeys:nil returnGroups:false keepUnreadCounters:false skipFeedUpdate:true changedMessages:^(__unused NSArray *addedMessages, __unused NSArray *removedMessages, __unused NSDictionary *updatedMessages, __unused NSArray *addedUnimportantHoles, __unused NSArray *removedUnimportantHoles) {
                    [TGModernConversationCompanion dispatchOnMessageQueue:^{
                        TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                        if (strongSelf == nil) {
                            return;
                        }
                        
                        strongSelf->_historyAbove = true;
                        [strongSelf reloadVariantAtSortKey:TGMessageTransparentSortKeyUpperBound(conversationId) group:nil jump:false top:false messageIdForVisibleHoleDirection:0 scrollBackMessageId:0 animated:false];
                    }];
                }];
            } error:^(__unused id error) {
                TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                if (showInitialLoading) {
                    [strongSelf _finishInitialLoadingOverlay];
                }
            } completed:^{
                if (!receivedResult && showInitialLoading) {
                    [OGChannelCompanionFromAnchor(companionAnchor) _finishInitialLoadingOverlay];
                }
            }];
        }
        
        if (_accessHash != 0 && TGPeerIdIsChannel(_conversationId) && topMessages.count >= initialChannelMessageCount) {
            int64_t conversationId = _conversationId;
            int64_t accessHash = _accessHash;
            OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
            NSArray *localTopMessages = [topMessages copy];
            
            SDisposableSet *tailRefreshDisposable = [[SDisposableSet alloc] init];
            [[TGTelegraphInstance disposeOnLogout] add:tailRefreshDisposable];
            
            id<SDisposable> tailRefreshInnerDisposable = [[TGChannelManagementSignals preloadedHistoryTailForPeerId:conversationId accessHash:accessHash] startWithNext:^(NSDictionary *dict) {
                NSArray *remoteMessages = OGChannelRemoteMessagesFromResult(dict);
                if (remoteMessages.count == 0) {
                    return;
                }
                
                NSArray *deletedMessageIds = OGChannelStaleLocalIds(remoteMessages, localTopMessages);
                if (deletedMessageIds.count == 0) {
                    return;
                }
                
                [TGDatabaseInstance() dispatchOnDatabaseThread:^{
                    [TGDatabaseInstance() addMessagesToChannel:conversationId messages:remoteMessages deleteMessages:deletedMessageIds unimportantGroups:nil addedHoles:nil removedHoles:nil removedUnimportantHoles:nil updatedMessageSortKeys:nil returnGroups:false keepUnreadCounters:false skipFeedUpdate:false changedMessages:^(__unused NSArray *addedMessages, NSArray *removedMessages, NSDictionary *updatedMessages, __unused NSArray *addedUnimportantHoles, __unused NSArray *removedUnimportantHoles) {
                        TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                        if (strongSelf == nil) {
                            return;
                        }
                        
                        NSDictionary *updatedPayload = updatedMessages == nil ? @{} : updatedMessages;
                        for (NSString *stream in @[@"importantMessages", @"unimportantMessages"]) {
                            NSMutableArray *removedForStream = [[NSMutableArray alloc] initWithArray:removedMessages];
                            [ActionStageInstance() dispatchResource:[NSString stringWithFormat:@"/tg/conversation/(%lld)/%@", conversationId, stream] resource:@{@"removed": removedForStream, @"added": @[], @"updated": updatedPayload}];
                        }
                    }];
                } synchronous:false];
            } error:^(__unused id error) {
                [TGTelegraphInstance.disposeOnLogout remove:tailRefreshDisposable];
                [tailRefreshDisposable dispose];
            } completed:^{
                [TGTelegraphInstance.disposeOnLogout remove:tailRefreshDisposable];
                [tailRefreshDisposable dispose];
            }];
            [tailRefreshDisposable add:tailRefreshInnerDisposable];
        }
    } else {
        self.useInitialSnapshot = false;
    }
    
    [self _setTitle:[self titleForConversation:_conversation] andStatus:_isGroup ? TGLocalized(@"Group.Status") : TGLocalized(@"Channel.Status") accentColored:false allowAnimatioon:false toggleMode:[self currentToggleMode]];
    [self updateStatus];
    [self applyAvatarForConversation:_conversation];
    
    if (_initialUserActivities.count != 0) {
        [self _setTypingStatus:[self stringForUserActivities:_initialUserActivities] activity:[self activityTypeForActivities:_initialUserActivities]];
    }
    
    [controller setHasBots:_hasBots];
    
    if (missingPreloadedAreaAtMessageId != 0) {
        [self _markInitialHistoryPending];
        [controller setLoadingMessages:true];
        
        if (_requestingHoleDisposable == nil) {
            _requestingHoleDisposable = [[SMetaDisposable alloc] init];
        }
        
        OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
        [_requestingHoleDisposable setDisposable:[[TGChannelManagementSignals preloadedHistoryForPeerId:_conversationId accessHash:_accessHash aroundMessageId:missingPreloadedAreaAtMessageId] startWithNext:^(NSDictionary *dict) {
            TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
            if (strongSelf != nil) {
                NSArray *removedImportantHoles = nil;
                NSArray *removedUnimportantHoles = nil;
                
                removedImportantHoles = dict[@"hole"] == nil ? nil : @[dict[@"hole"]];
                removedUnimportantHoles = dict[@"hole"] == nil ? nil : @[dict[@"hole"]];
                
                [TGDatabaseInstance() addMessagesToChannel:strongSelf->_conversationId messages:dict[@"messages"] deleteMessages:nil unimportantGroups:dict[@"unimportantGroups"] addedHoles:nil removedHoles:removedImportantHoles removedUnimportantHoles:removedUnimportantHoles updatedMessageSortKeys:nil returnGroups:false keepUnreadCounters:false skipFeedUpdate:true changedMessages:^(__unused NSArray *addedMessages, __unused NSArray *removedMessages, __unused NSDictionary *updatedMessages, __unused NSArray *addedUnimportantHoles, __unused NSArray *removedUnimportantHoles) {
                    __block TGMessageTransparentSortKey messageKey = TGMessageTransparentSortKeyUpperBound(strongSelf->_conversationId);
                    [TGDatabaseInstance() dispatchOnDatabaseThread:^{
                        [TGDatabaseInstance() channelMessageExists:strongSelf->_conversationId messageId:missingPreloadedAreaAtMessageId completion:^(bool exists, TGMessageSortKey key) {
                            if (exists) {
                                messageKey = TGMessageTransparentSortKeyMake(TGMessageSortKeyPeerId(key), TGMessageSortKeyTimestamp(key), TGMessageSortKeyMid(key), TGMessageSortKeySpace(key));
                            }
                        }];
                    } synchronous:true];
                    
                    [TGModernConversationCompanion dispatchOnMessageQueue:^{
                        TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                        if (strongSelf != nil) {
                            
                            TGDispatchOnMainThread(^{
                                TGMessageRange unreadRange = TGMessageRangeEmpty();
                                
                                unreadRange.firstDate = TGMessageTransparentSortKeyTimestamp(messageKey);
                                unreadRange.lastDate = INT32_MAX;
                                unreadRange.firstMessageId = TGMessageTransparentSortKeyMid(messageKey) + 1;
                                unreadRange.lastMessageId = INT32_MAX;
                                
                                strongSelf.unreadMessageRange = unreadRange;
                                
                                messageIdForVisibleHoleDirection = TGMessageTransparentSortKeyMid(messageKey) + 1;
                                
                                TGModernConversationController *controller = strongSelf.controller;
                                if (earliestUnreadMessageId != 0) {
                                    [controller pushEarliestUnreadMessageId:earliestUnreadMessageId];
                                }
                            });
                            
                            [strongSelf reloadVariantAtSortKey:messageKey group:nil jump:false top:true messageIdForVisibleHoleDirection:messageIdForVisibleHoleDirection scrollBackMessageId:0 animated:false];
                        }
                    }];
                }];
            }
        }]];
    }
}

- (TGModernConversationControllerTitleToggle)currentToggleMode {
    return TGModernConversationControllerTitleToggleNone;
}

- (void)updateStatus {
    NSString *text = _isGroup ? TGLocalized(@"Group.Status") : TGLocalized(@"Channel.Status");
    if (_conversation.isMonoforum) {
        text = TGLocalized(@"Channel.DirectMessages.Status");
    } else if (_isForbidden) {
        text = _isGroup ? TGLocalized(@"Conversation.StatusKickedFromGroup") : TGLocalized(@"Conversation.StatusKickedFromChannel");
    } else if (_isGroup && _groupedOnlineInfo != nil) {
        text = [self stringForMemberCount:_memberCount onlineCount:(int)_groupedOnlineInfo.onlineCount];
    } else if (_memberCount != 0) {
        text = _isGroup ? [self stringForMemberCount:_memberCount] : [self stringForSubscriberCount:_memberCount];
    }
    
    [self _setStatus:text accentColored:false allowAnimation:false toggleMode:[self currentToggleMode]];
}

- (id)stringForMemberCount:(int)memberCount onlineCount:(int)onlineCount
{
    if (onlineCount <= 1)
        return [self stringForMemberCount:memberCount];
    else
    {
        NSString *firstPart = [[NSString alloc] initWithFormat:@"%@, ", [self stringForMemberCount:memberCount]];
        NSString *secondPart = [self stringForOnlineCount:onlineCount];
        NSString *combinedString = [firstPart stringByAppendingString:secondPart];
        
        
        return combinedString;
        
    }
}

- (NSString *)stringForOnlineCount:(int)onlineCount
{
    return [effectiveLocalization() getPluralized:@"Conversation.StatusOnline" count:(int32_t)onlineCount];
}

- (NSString *)stringForMemberCount:(int)memberCount
{
    return [effectiveLocalization() getPluralized:@"Conversation.StatusMembers" count:(int32_t)memberCount];
}

- (NSString *)stringForSubscriberCount:(int)subscriberCount
{
    return [effectiveLocalization() getPluralized:@"Conversation.StatusSubscribers" count:(int32_t)subscriberCount];
}

- (void)reloadVariantAtSortKey:(TGMessageTransparentSortKey)sortKey group:(TGMessageGroup *)group jump:(bool)jump top:(bool)top messageIdForVisibleHoleDirection:(int32_t)messageIdForVisibleHoleDirection scrollBackMessageId:(int32_t)scrollBackMessageId animated:(bool)animated {
    TGDispatchOnMainThread(^{
        [self updateStatus];
    });
    
    [TGModernConversationCompanion dispatchOnMessageQueue:^{
        _enableVisibleMessagesProcessing = true;
        _visibleHoles = nil;
        [_requestingHoleDisposable setDisposable:nil];
        _requestingHole = nil;
        _loadingHistoryAbove = false;
        _historyAbove = false;
        _loadingHistoryBelow = false;
        _historyBelow = false;
        _migrationHistoryAbove = false;
        
        [self _updateControllerHistoryRequestsFlags];
        
        [TGDatabaseInstance() dispatchOnDatabaseThread:^{
            __block TGMessageTransparentSortKey updatedSortKey = sortKey;
            
            if (group != nil) {
                [TGDatabaseInstance() channelEarlierMessage:_conversationId messageId:group.maxId timestamp:group.maxTimestamp important:true completion:^(bool exists, TGMessageSortKey key) {
                    if (exists) {
                        updatedSortKey = TGMessageTransparentSortKeyMake(_conversationId, TGMessageSortKeyTimestamp(key), TGMessageSortKeyMid(key), TGMessageSortKeySpace(key));
                    }
                }];
            } else if (_displayVariant == TGChannelDisplayVariantImportant && TGMessageTransparentSortKeySpace(sortKey) == TGMessageSpaceUnimportant) {
                [TGDatabaseInstance() channelEarlierMessage:_conversationId messageId:TGMessageTransparentSortKeyMid(sortKey) timestamp:TGMessageTransparentSortKeyTimestamp(sortKey) important:true completion:^(bool exists, TGMessageSortKey key) {
                    if (exists) {
                        updatedSortKey = TGMessageTransparentSortKeyMake(_conversationId, TGMessageSortKeyTimestamp(key), TGMessageSortKeyMid(key), TGMessageSortKeySpace(key));
                    }
                }];
            }
            
            int reloadMessageCount = 60;
#if defined(ONEGRAM_ARMV6)
            reloadMessageCount = 32;
#endif
            [TGDatabaseInstance() channelMessages:_conversationId maxTransparentSortKey:updatedSortKey count:reloadMessageCount important:_displayVariant == TGChannelDisplayVariantImportant mode:TGChannelHistoryRequestAround completion:^(NSArray *messages, bool hasLater) {
                [TGModernConversationCompanion dispatchOnMessageQueue:^{
                    _historyAbove = messages.count != 0;
                    _historyBelow = hasLater;
                    _migrationHistoryAbove = _migrationData.peerId != 0;
                    
                    int32_t atMessageId = 0;
                    for (TGMessage *message in messages) {
                        if (TGMessageTransparentSortKeyCompare(message.transparentSortKey, updatedSortKey) <= 0) {
                            atMessageId = message.mid;
                            break;
                        }
                    }
                    
                    [self _replaceMessages:messages atMessageId:atMessageId peerId:0 expandFrom:-group.maxId jump:jump top:top messageIdForVisibleHoleDirection:messageIdForVisibleHoleDirection scrollBackMessageId:scrollBackMessageId animated:animated];
                    [self _updateControllerHistoryRequestsFlags];
                    
                    [self _markInitialHistoryResolved];
                    TGDispatchOnMainThread(^{
                        TGModernConversationController *controller = self.controller;
                        [controller setLoadingMessages:false];
                    });
                }];
            }];
        } synchronous:false];
    }];
}

- (bool)imageDownloadsShouldAutosavePhotos
{
    TGAutoDownloadMode mode = _isGroup ? TGAutoDownloadModeCellularGroups: TGAutoDownloadModeCellularChannels;
    return (TGAppDelegateInstance.autoSavePhotosMode & mode) != 0;
}

- (bool)shouldAutomaticallyDownloadPhotos
{
    TGAutoDownloadChat chat = _isGroup ? TGAutoDownloadChatGroup : TGAutoDownloadChatChannel;
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadPhotoInChat:chat networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadAnimations
{
    TGAutoDownloadChat chat = _isGroup ? TGAutoDownloadChatGroup : TGAutoDownloadChatChannel;
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadGifInChat:chat networkType:TGTelegraphInstance.networkTypeManager.networkType];
}
- (bool)shouldAutomaticallyDownloadAudios
{
    TGAutoDownloadChat chat = _isGroup ? TGAutoDownloadChatGroup : TGAutoDownloadChatChannel;
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadVoiceMessageInChat:chat networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadVideoMessages
{
    TGAutoDownloadChat chat = _isGroup ? TGAutoDownloadChatGroup : TGAutoDownloadChatChannel;
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadVideoMessageInChat:chat networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadVideos
{
    TGAutoDownloadChat chat = _isGroup ? TGAutoDownloadChatGroup : TGAutoDownloadChatChannel;
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadVideoInChat:chat networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadDocuments
{
    TGAutoDownloadChat chat = _isGroup ? TGAutoDownloadChatGroup : TGAutoDownloadChatChannel;
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadDocumentInChat:chat networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (NSString *)_sendMessagePathForMessageId:(int32_t)mid {
    return [[NSString alloc] initWithFormat:@"/tg/sendCommonMessage/(%@)/(%d)", [self _conversationIdPathComponent], mid];
}

- (NSString *)_sendMessagePathPrefix {
    return [[NSString alloc] initWithFormat:@"/tg/sendCommonMessage/(%@)/", [self _conversationIdPathComponent]];
}

- (NSDictionary *)_optionsForMessageActions {
    bool postAsChannel = !_isGroup;
    return @{@"conversationId": @(_conversationId), @"accessHash": @(_accessHash), @"asChannel": @(postAsChannel), @"sendActivity": @(_isGroup), @"notifyMembers": @(_shouldNotifyMembers)};
}

- (void)_setupOutgoingMessage:(TGMessage *)message {
    [super _setupOutgoingMessage:message];
    
    if (_isGroup) {
        message.sortKey = TGMessageSortKeyMake(_conversationId, TGMessageSpaceUnimportant, (int32_t)message.date, message.mid);
    }
    
    if (!_isGroup && (_adminRights.canPostMessages)) {
        if (message.viewCount == nil) {
            message.viewCount = [[TGMessageViewCountContentProperty alloc] initWithViewCount:1];
        }
    }
}

- (void)subscribeToUpdates
{
    [ActionStageInstance() watchForPaths:@[
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/typing", _conversationId],
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/conversation", _conversationId],
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/importantMessages", _conversationId],
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/unimportantMessages", _conversationId],
        [[NSString alloc] initWithFormat:@"/tg/peerSettings/(%lld)", _conversationId],
        [[NSString alloc] initWithFormat:@"/tg/peerSettings/(%" PRId64 ")", TGPeerIdNotificationDefaultsGroup],
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/pinnedMessagesChanged", _conversationId]
    ] watcher:self];
    
    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%" PRId64 ",cachedOnly)", _conversationId] options:@{@"peerId": @(_conversationId), @"accessHash": @(_accessHash)} watcher:self];
    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%lld,cachedOnly)", TGPeerIdNotificationDefaultsGroup] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:TGPeerIdNotificationDefaultsGroup] forKey:@"peerId"] watcher:self];

    [super subscribeToUpdates];
}

- (void)_controllerDidUpdateVisibleHoles:(NSArray *)holes {
    [TGModernConversationCompanion dispatchOnMessageQueue:^{
        _visibleHoles = holes;
        
        [self _updateVisibleHoles];
    }];
}

- (void)_updateVisibleHoles {
    if (_enableVisibleMessagesProcessing && _visibleHoles.count != 0 && _requestingHole == nil) {
        TGVisibleMessageHole *maxHole = _visibleHoles[0];
        
        [self _requestHole:maxHole];
    }
}

- (bool)historyAboveMayBeAvailable {
    return _historyAbove || _migrationHistoryAbove;
}

- (void)loadMoreMessagesAbove {
    TGModernConversationController *controller = self.controller;
    [controller setEnableAboveHistoryRequests:false];
    
    [TGModernConversationCompanion dispatchOnMessageQueue:^{
        [self _requestHistoryAboveIncludingMessages:nil];
    }];
}

- (void)_historyItemsPreparedForMessages:(NSArray *)messages intent:(TGModernConversationAddMessageIntent)intent {
    [super _historyItemsPreparedForMessages:messages intent:intent];
    if (intent == TGModernConversationAddMessageIntentLoadMoreMessagesAbove && messages.count != 0 && _historyAbove && !_loadingHistoryAbove && [self historyAboveReadAheadAllowed])
        [self _requestHistoryAboveIncludingMessages:messages];
    else if (intent == TGModernConversationAddMessageIntentLoadMoreMessagesBelow && messages.count != 0 && _historyBelow && !_loadingHistoryBelow && [self historyBelowReadAheadAllowed])
        [self _requestHistoryBelowIncludingMessages:messages];
}

- (void)_fetchRemoteGapAboveOldestId:(int32_t)oldestMessageId date:(int32_t)oldestMessageDate {
    TGMessageHole *gap = [[TGMessageHole alloc] initWithMinId:1 minTimestamp:1 maxId:oldestMessageId - 1 maxTimestamp:oldestMessageDate];
    if (_requestingHoleDisposable == nil) {
        _requestingHoleDisposable = [[SMetaDisposable alloc] init];
    }
    int64_t conversationId = _conversationId;
    int32_t displayVariant = _displayVariant;
    int64_t accessHash = _accessHash;
    NSUInteger epoch = ++_remoteGapEpoch;
    OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
    
    const int64_t remoteGapDelay = 12 * NSEC_PER_SEC;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, remoteGapDelay), dispatch_get_main_queue(), ^{
        [TGModernConversationCompanion dispatchOnMessageQueue:^{
            TGChannelConversationCompanion *owner = OGChannelCompanionFromAnchor(companionAnchor);
            if (owner == nil || owner->_remoteGapEpoch != epoch || !owner->_loadingHistoryAbove)
                return;
            [owner->_requestingHoleDisposable setDisposable:nil];
            owner->_requestingHoleDisposable = nil;
            owner->_loadingHistoryAbove = false;
            owner->_historyAbove = false;
            [owner _updateControllerHistoryRequestsFlags];
        }];
    });
    
    SSignal *gapSignal = [TGChannelManagementSignals channelMessageHoleForPeerId:conversationId accessHash:accessHash hole:gap direction:TGChannelHistoryHoleDirectionEarlier important:displayVariant == TGChannelDisplayVariantImportant];
    [_requestingHoleDisposable setDisposable:[gapSignal startWithNext:^(NSDictionary *dict) {
        NSArray *removedImportantHoles = OGChannelHoleListFromResult(dict);
        NSArray *removedUnimportantHoles = removedImportantHoles;
        
        [TGDatabaseInstance() addMessagesToChannel:conversationId messages:dict[@"messages"] deleteMessages:nil unimportantGroups:dict[@"unimportantGroups"] addedHoles:nil removedHoles:removedImportantHoles removedUnimportantHoles:removedUnimportantHoles updatedMessageSortKeys:nil returnGroups:displayVariant == TGChannelDisplayVariantImportant keepUnreadCounters:false skipFeedUpdate:false changedMessages:^(NSArray *addedMessages, NSArray *removedMessages, NSDictionary *updatedMessages, NSArray *addedUnimportantHoles, NSArray *removedUnimportantHoles) {
            [TGModernConversationCompanion dispatchOnMessageQueue:^{
                TGChannelConversationCompanion *owner = OGChannelCompanionFromAnchor(companionAnchor);
                if (owner == nil || owner->_remoteGapEpoch != epoch)
                    return;
                owner->_requestingHoleDisposable = nil;
                NSMutableArray *resultRemovedMessages = OGChannelCombineChanges(removedMessages, removedUnimportantHoles, owner->_displayVariant);
                NSMutableArray *resultAddedMessages = OGChannelCombineChanges(addedMessages, addedUnimportantHoles, owner->_displayVariant);
                
                owner->_loadingHistoryAbove = false;
                owner->_historyAbove = resultAddedMessages.count != 0;
                if (resultAddedMessages.count + resultRemovedMessages.count != 0) {
                    [owner _addMessages:resultAddedMessages animated:false intent:TGModernConversationAddMessageIntentLoadMoreMessagesAbove deletedMessages:resultRemovedMessages];
                }
                [owner _updateMessages:updatedMessages];
                [owner _updateControllerHistoryRequestsFlags];
            }];
        }];
    } error:^(__unused id error) {
        [TGModernConversationCompanion dispatchOnMessageQueue:^{
            TGChannelConversationCompanion *owner = OGChannelCompanionFromAnchor(companionAnchor);
            if (owner == nil || owner->_remoteGapEpoch != epoch)
                return;
            owner->_requestingHoleDisposable = nil;
            owner->_loadingHistoryAbove = false;
            owner->_historyAbove = false;
            [owner _updateControllerHistoryRequestsFlags];
        }];
    } completed:nil]];
}

- (void)_requestHistoryAboveIncludingMessages:(NSArray *)includedMessages {
    int count = 100;
    
    if (!_loadingHistoryAbove) {
        if (_historyAbove) {
            __block TGMessageTransparentSortKey maxKey = TGMessageTransparentSortKeyUpperBound(_conversationId);
            __block bool migratedFound = false;
            __block bool messagesFound = false;
            __block int32_t oldestMessageId = 0;
            __block int32_t oldestMessageDate = 0;
            int64_t conversationId = _conversationId;
            void (^considerMessage)(TGMessage *) = ^(TGMessage *message) {
                if (message.cid == conversationId) {
                    TGMessageTransparentSortKey itemKey = message.transparentSortKey;
                    itemKey = TGMessageTransparentSortKeyMake(TGMessageTransparentSortKeyPeerId(itemKey), TGMessageTransparentSortKeyTimestamp(itemKey), TGMessageTransparentSortKeyMid(itemKey) - 1, TGMessageTransparentSortKeySpace(itemKey));
                    if (TGMessageTransparentSortKeyCompare(maxKey, itemKey) > 0) {
                        maxKey = itemKey;
                    }
                    if (message.mid > 0 && (oldestMessageId == 0 || message.mid < oldestMessageId)) {
                        oldestMessageId = message.mid;
                        oldestMessageDate = (int32_t)message.date;
                    }
                    messagesFound = true;
                } else {
                    migratedFound = message.cid != 0;
                }
            };
            for (TGMessageModernConversationItem *item in _items) {
                considerMessage(item->_message);
            }
            for (TGMessage *message in includedMessages) {
                considerMessage(message);
            }
            
            if (!messagesFound && migratedFound) {
                self->_loadingHistoryAbove = false;
                self->_historyAbove = false;
                [self _updateControllerHistoryRequestsFlags];
            } else {
                OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
                _loadingHistoryAbove = true;
                [TGDatabaseInstance() channelMessages:_conversationId maxTransparentSortKey:maxKey count:count important:_displayVariant == TGChannelDisplayVariantImportant mode:TGChannelHistoryRequestEarlier completion:^(NSArray *messages, __unused bool hasLater) {
                    [TGModernConversationCompanion dispatchOnMessageQueue:^{
                        TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                        if (strongSelf != nil) {
                            if (messages.count == 0) {
                                if (oldestMessageId > 1) {
                                    [strongSelf _fetchRemoteGapAboveOldestId:oldestMessageId date:oldestMessageDate];
                                    return;
                                } else {
                                    strongSelf->_loadingHistoryAbove = false;
                                    strongSelf->_historyAbove = false;
                                }
                            } else {
                                strongSelf->_loadingHistoryAbove = false;
                                strongSelf->_historyAbove = true;
                            }
                            if (messages.count != 0) {
                                [strongSelf _addMessages:messages animated:false intent:TGModernConversationAddMessageIntentLoadMoreMessagesAbove];
                            }
                            [strongSelf _updateControllerHistoryRequestsFlags];
                        }
                    }];
                }];
            }
        } else if (_migrationData != nil && _migrationHistoryAbove) {
            OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
            _loadingHistoryAbove = true;
            
            int32_t maxTimestamp = INT32_MAX;
            int32_t maxMid = _migrationData.maxMessageId;
            
            for (TGMessageModernConversationItem *item in _items) {
                maxTimestamp = MIN(maxTimestamp, (int32_t)item->_message.date);
                if (!(item->_message.cid == _conversationId || item->_message.cid == 0)) {
                    maxMid = MIN(maxMid, item->_message.mid - migratedMessageIdOffset);
                }
            }
            
            [TGDatabaseInstance() loadMessagesFromConversation:_migrationData.peerId maxMid:maxMid maxDate:maxTimestamp maxLocalMid:0 atMessageId:0 limit:count extraUnread:false completion:^(NSArray *messages, __unused bool historyExistsBelow) {
                int peerMinMid = [TGDatabaseInstance() loadPeerMinMid:_migrationData.peerId];
                
                [TGModernConversationCompanion dispatchOnMessageQueue:^{
                    TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                    if (strongSelf != nil) {
                        bool cachedMessagesAbove = false;
                        if (messages.count != 0) {
                            cachedMessagesAbove = true;
                        }
                        
                        NSMutableArray *updatedMessages = [[NSMutableArray alloc] init];
                        
                        for (TGMessage *message in messages) {
                            if (message.mid < TGMessageLocalMidBaseline) {
                                message.mid += migratedMessageIdOffset;
                                [updatedMessages addObject:message];
                            }
                        }
                        
                        if (messages.count != 0) {
                            [strongSelf _addMessages:updatedMessages animated:false intent:TGModernConversationAddMessageIntentLoadMoreMessagesAbove];
                        }
                        
                        if (cachedMessagesAbove || peerMinMid != 0) {
                            strongSelf->_loadingHistoryAbove = false;
                            strongSelf->_migrationHistoryAbove = cachedMessagesAbove;
                            
                            [strongSelf _updateControllerHistoryRequestsFlags];
                        } else {
                            NSMutableDictionary *options = [[NSMutableDictionary alloc] initWithDictionary:@{@"maxMid": @(maxMid), @"offset": @(0)}];
                            
                            options[@"conversationId"] = @(_migrationData.peerId);
                            
                            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%lld)/asyncHistory/(%d)", _migrationData.peerId, maxMid] options:options watcher:strongSelf];
                        }
                    }
                }];
            }];
        }
    } else {
        [self _updateControllerHistoryRequestsFlags];
    }
}

- (void)loadMoreMessagesBelow {
    TGModernConversationController *controller = self.controller;
    [controller setEnableBelowHistoryRequests:false];
    
    [TGModernConversationCompanion dispatchOnMessageQueue:^{
        [self _requestHistoryBelowIncludingMessages:nil];
    }];
}

- (void)_requestHistoryBelowIncludingMessages:(NSArray *)includedMessages {
    int count = 100;
#ifdef DEBUG
    count = 10;
#endif
    
    if (_loadingHistoryBelow) {
        [self _updateControllerHistoryRequestsFlags];
        return;
    }
    
    if (!_historyBelow)
        return;
    
    TGMessageTransparentSortKey minKey = TGMessageTransparentSortKeyLowerBound(_conversationId);
    for (TGMessageModernConversationItem *item in _items) {
        TGMessageTransparentSortKey itemKey = item->_message.transparentSortKey;
        if (TGMessageTransparentSortKeyCompare(minKey, itemKey) < 0) {
            minKey = itemKey;
        }
    }
    for (TGMessage *message in includedMessages) {
        TGMessageTransparentSortKey messageKey = message.transparentSortKey;
        if (TGMessageTransparentSortKeyCompare(minKey, messageKey) < 0) {
            minKey = messageKey;
        }
    }
    
    OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
    _loadingHistoryBelow = true;
    [TGDatabaseInstance() channelMessages:_conversationId maxTransparentSortKey:minKey count:count important:_displayVariant == TGChannelDisplayVariantImportant mode:TGChannelHistoryRequestLater completion:^(NSArray *messages, __unused bool hasLater) {
        [TGModernConversationCompanion dispatchOnMessageQueue:^{
            TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
            if (strongSelf != nil) {
                strongSelf->_loadingHistoryBelow = false;
                strongSelf->_historyBelow = messages.count != 0;
                if (messages.count != 0) {
                    [strongSelf _addMessages:messages animated:false intent:TGModernConversationAddMessageIntentLoadMoreMessagesBelow];
                }
                [strongSelf _updateControllerHistoryRequestsFlags];
            }
        }];
    }];
}

- (void)_requestHole:(TGVisibleMessageHole *)hole {
    _requestingHole = hole;
    if (_requestingHoleDisposable == nil) {
        _requestingHoleDisposable = [[SMetaDisposable alloc] init];
    }

    int64_t conversationId = _conversationId;
    int32_t displayVariant = _displayVariant;
    
    
    OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
    [_requestingHoleDisposable setDisposable:[[TGChannelManagementSignals channelMessageHoleForPeerId:_conversationId accessHash:_accessHash hole:hole.hole direction:hole.direction == TGVisibleMessageHoleDirectionEarlier ? TGChannelHistoryHoleDirectionEarlier : TGChannelHistoryHoleDirectionLater important:_displayVariant == TGChannelDisplayVariantImportant] startWithNext:^(NSDictionary *dict) {
        
        NSArray *removedImportantHoles = nil;
        NSArray *removedUnimportantHoles = nil;
        
        removedImportantHoles = dict[@"hole"] == nil ? nil : @[dict[@"hole"]];
        removedUnimportantHoles = dict[@"hole"] == nil ? nil : @[dict[@"hole"]];
        
        [TGDatabaseInstance() addMessagesToChannel:conversationId messages:dict[@"messages"] deleteMessages:nil unimportantGroups:dict[@"unimportantGroups"] addedHoles:nil removedHoles:removedImportantHoles removedUnimportantHoles:removedUnimportantHoles updatedMessageSortKeys:nil returnGroups:displayVariant == TGChannelDisplayVariantImportant keepUnreadCounters:false skipFeedUpdate:false changedMessages:^(NSArray *addedMessages, NSArray *removedMessages, NSDictionary *updatedMessages, NSArray *addedUnimportantHoles, NSArray *removedUnimportantHoles) {
                [TGModernConversationCompanion dispatchOnMessageQueue:^{
                    TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                    if (strongSelf != nil) {
                        
                        NSMutableArray *resultRemovedMessages = OGChannelCombineChanges(removedMessages, removedUnimportantHoles, strongSelf->_displayVariant);
                        NSMutableArray *resultAddedMessages = OGChannelCombineChanges(addedMessages, addedUnimportantHoles, strongSelf->_displayVariant);
                        
                        [strongSelf _addMessages:resultAddedMessages animated:false intent:hole.direction == TGVisibleMessageHoleDirectionEarlier ? TGModernConversationAddMessageIntentLoadMoreMessagesAbove : TGModernConversationAddMessageIntentLoadMoreMessagesBelow deletedMessages:resultRemovedMessages];
                        
                        [strongSelf _updateMessages:updatedMessages];
                        
                        strongSelf->_requestingHole = nil;
                        [strongSelf _updateControllerHistoryRequestsFlags];
                    }
                }];
            }];
    } error:^(__unused id error) {
        
    } completed:nil]];
}

- (void)_updateControllerHistoryRequestsFlags {
    NSAssert([TGModernConversationCompanion isMessageQueue], @"[TGModernConversationCompanion isMessageQueue]");
    
    bool enableAboveRequests = _historyAbove || _migrationHistoryAbove;
    if (_loadingHistoryAbove) {
        enableAboveRequests = false;
    }
    
    bool enableBelowRequests = _historyBelow;
    if (_loadingHistoryBelow) {
        enableBelowRequests = false;
    }
    
    TGDispatchOnMainThread(^{
        TGModernConversationController *controller = self.controller;
        [controller setEnableAboveHistoryRequests:enableAboveRequests];
        [controller setEnableBelowHistoryRequests:enableBelowRequests];
    });
}

- (NSString *)titleForConversation:(TGConversation *)conversation {
    return [self _identityConversationForConversation:conversation].chatTitle;
}

- (NSString *)stringForActivity:(NSString *)activity
{
    if ([activity isEqualToString:@"recordingAudio"])
        return TGLocalized(@"Activity.RecordingAudio");
    else if ([activity isEqualToString:@"recordingVideoMessage"])
        return TGLocalized(@"Activity.RecordingVideoMessage");
    else if ([activity isEqualToString:@"uploadingPhoto"])
        return TGLocalized(@"Activity.UploadingPhoto");
    else if ([activity isEqualToString:@"uploadingVideo"])
        return TGLocalized(@"Activity.UploadingVideo");
    else if ([activity isEqualToString:@"uploadingDocument"])
        return TGLocalized(@"Activity.UploadingDocument");
    else if ([activity isEqualToString:@"pickingLocation"])
        return nil;
    else if ([activity isEqualToString:@"playingGame"])
        return TGLocalized(@"Activity.PlayingGame");
    
    return TGLocalized(@"Conversation.typing");
}

- (int)activityTypeForActivity:(NSString *)activity
{
    if ([activity isEqualToString:@"recordingAudio"])
        return TGModernConversationTitleViewActivityAudioRecording;
    else if ([activity isEqualToString:@"recordingVideoMessage"])
        return TGModernConversationTitleViewActivityVideoMessageRecording;
    else if ([activity isEqualToString:@"uploadingPhoto"])
        return TGModernConversationTitleViewActivityUploading;
    else if ([activity isEqualToString:@"uploadingVideo"])
        return TGModernConversationTitleViewActivityUploading;
    else if ([activity isEqualToString:@"uploadingDocument"])
        return TGModernConversationTitleViewActivityUploading;
    else if ([activity isEqualToString:@"pickingLocation"])
        return 0;
    else if ([activity isEqualToString:@"playingGame"])
        return TGModernConversationTitleViewActivityPlaying;
    
    return TGModernConversationTitleViewActivityTyping;
}

- (NSString *)stringForUserActivities:(NSDictionary *)activities
{
    if (activities.count != 0)
    {
        NSMutableString *typingString = [[NSMutableString alloc] init];
        
        for (NSNumber *nUid in activities)
        {
            TGUser *user = [TGDatabaseInstance() loadUser:[nUid longLongValue]];
            if (user != nil)
            {
                if (typingString.length != 0)
                    [typingString appendString:@", "];
                [typingString appendString:user.displayFirstName];
            }
        }
        
        return typingString;
    }
    
    return nil;
}

- (int)activityTypeForActivities:(NSDictionary *)activities
{
    if (activities.count == 1)
    {
        return [self activityTypeForActivity:activities.allValues.firstObject];
    }
    else if (activities.count != 0)
    {
        return TGModernConversationTitleViewActivityTyping;
    }
    
    return 0;
}

- (void)_updateNotifcationSettings
{
    NSNumber *muteUntil = _groupNotificationSettings[@"muteUntil"];
    if (muteUntil == nil)
        muteUntil = _defaultNotificationSettings[@"muteUntil"];
    
    if (muteUntil.intValue <= OGRemoteClockTime())
        _isMuted = false;
    else
        _isMuted = true;
    
    [self _updateMutePanel];
    
    [self _updateChannelMute];
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)result {
    if ([path hasPrefix:[NSString stringWithFormat:@"/tg/peerSettings/(%" PRId64 "", TGPeerIdNotificationDefaultsGroup]])
    {
        TGDispatchOnMainThread(^
        {
            _defaultNotificationSettings = [((SGraphObjectNode *)result).object mutableCopy];
            [self _updateNotifcationSettings];
            [self updateBroadcasting];
        });
    }
    else if ([path hasPrefix:@"/tg/peerSettings/"])
    {
        if (status == ASStatusSuccess)
        {
            TGDispatchOnMainThread(^
            {
                _groupNotificationSettings = [((SGraphObjectNode *)result).object mutableCopy];
                [self _updateNotifcationSettings];
            });
        }
    } else if ([path rangeOfString:@"/asyncHistory/"].location != NSNotFound) {
        [TGModernConversationCompanion dispatchOnMessageQueue:^{
            NSArray *messages = result;
            
            NSMutableArray *updatedMessages = [[NSMutableArray alloc] init];
            
            for (TGMessage *message in messages) {
                if (message.mid < TGMessageLocalMidBaseline) {
                    
                    TGMessage *updatedMessage = [message copy];
                    updatedMessage.mid += migratedMessageIdOffset;
                    [updatedMessages addObject:updatedMessage];
                }
            }
            
            if (messages.count != 0) {
                [self _addMessages:updatedMessages animated:false intent:TGModernConversationAddMessageIntentLoadMoreMessagesAbove];
            }
            
            _loadingHistoryAbove = false;
            _migrationHistoryAbove = updatedMessages.count != 0;
            
            [self _updateControllerHistoryRequestsFlags];
        }];
        return;
    }
    
    [super actorCompleted:status path:path result:result];
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)arguments {
    if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/pinnedMessagesChanged", _conversationId]])
    {
        TGDispatchOnMainThread(^{
            [self og_reloadPinnedMessages];
        });
    }

    if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/typing", _conversationId]])
    {
        NSDictionary *userActivities = ((SGraphObjectNode *)resource).object;
        if (userActivities.count != 0)
            [self _setTypingStatus:[self stringForUserActivities:userActivities] activity:[self activityTypeForActivities:userActivities]];
        else
            [self _setTypingStatus:nil activity:0];
    }
    else if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/conversation", _conversationId]]) {
        TGConversation *conversation = ((SGraphObjectNode *)resource).object;
        _conversation = conversation;
        _signaturesEnabled = conversation.signaturesEnabled;
        [self setPaidMessageStars:[self _paidMessagesPriceForConversation:conversation]];
        
        TGDispatchOnMainThread(^{
            bool importantFlagsUpdated = _isCreator != (conversation.channelRole == TGChannelRoleCreator) || !TGObjectCompare(_adminRights, conversation.channelAdminRights) || !TGObjectCompare(_bannedRights, conversation.channelBannedRights) || _kind != conversation.kind || _isForbidden != conversation.kickedFromChat;
            
            _kind = conversation.kind;
            _isCreator = conversation.channelRole == TGChannelRoleCreator;
            _adminRights = conversation.channelAdminRights;
            _bannedRights = conversation.channelBannedRights;
            
            if (!_isGroup && _isForbidden != conversation.kickedFromChat && conversation.kickedFromChat) {
                [TGCustomAlertView presentAlertWithTitle:nil message:[NSString stringWithFormat:TGLocalized(@"ChannelInfo.ChannelForbidden"), conversation.chatTitle] cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            }
            
            _isForbidden = conversation.kickedFromChat;
            
            TGModernConversationController *controller = self.controller;
            if (!_isGroup) {
                if (_isCreator || _adminRights.canPostMessages) {
                    [controller setCanBroadcast:true];
                    [self updateBroadcasting];
                    [controller setIsAlwaysBroadcasting:false];
                } else {
                    [controller setCanBroadcast:false];
                    [controller setIsBroadcasting:false];
                    [controller setIsAlwaysBroadcasting:true];
                }
            }
            
            [self _updateMutePanel];
            
            if (importantFlagsUpdated) {
                [self _updateJoinPanel];
                [controller setBannedStickers:_bannedRights.banSendStickers];
                [controller setBannedMedia:_bannedRights.banSendMedia];
            }
            
            [self _setTitle:[self titleForConversation:conversation] andStatus:_isGroup ? TGLocalized(@"Group.Status") : TGLocalized(@"Channel.Status") accentColored:false allowAnimatioon:false toggleMode:[self currentToggleMode]];
            [self updateStatus];
            [self applyAvatarForConversation:conversation];
        });
    } else if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/importantMessages", _conversationId]]) {
        [TGModernConversationCompanion dispatchOnMessageQueue:^{
            if (_displayVariant == TGChannelDisplayVariantImportant) {
                if (((NSArray *)resource[@"removed"]).count != 0) {
                    [self _deleteMessages:resource[@"removed"] animated:true];
                }
                if (((NSArray *)resource[@"added"]).count != 0) {
                    [self og_foldPinnedMessages:[self og_latestPinnedFromMessages:resource[@"added"]]];
                    [super actionStageResourceDispatched:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/messages", _conversationId] resource:[[SGraphObjectNode alloc] initWithObject:resource[@"added"]] arguments:@{@"treatIncomingAsUnread": @true}];
                }
                if (((NSDictionary *)resource[@"updated"]).count != 0) {
                    [self _updateMessages:resource[@"updated"]];
                    __block bool hadGroups = false;
                    [(NSDictionary *)resource[@"updated"] enumerateKeysAndObjectsUsingBlock:^(__unused id key, TGMessage *message, BOOL *stop) {
                        if (message.group != nil) {
                            if (stop) {
                                hadGroups = true;
                               *stop = true;
                            }
                        }
                    }];
                    
                    if (hadGroups) {
                        [self scheduleReadHistory];
                    }
                }
            }
        }];
    } else if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/unimportantMessages", _conversationId]]) {
        [TGModernConversationCompanion dispatchOnMessageQueue:^{
            if (_displayVariant == TGChannelDisplayVariantAll) {
                if (((NSArray *)resource[@"removed"]).count != 0) {
                    [self _deleteMessages:resource[@"removed"] animated:true];
                }
                if (((NSArray *)resource[@"added"]).count != 0) {
                    [self og_foldPinnedMessages:[self og_latestPinnedFromMessages:resource[@"added"]]];
                    [super actionStageResourceDispatched:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/messages", _conversationId] resource:[[SGraphObjectNode alloc] initWithObject:resource[@"added"]] arguments:@{@"treatIncomingAsUnread": @true}];
                }
                if (((NSDictionary *)resource[@"updated"]).count != 0) {
                    [self _updateMessages:resource[@"updated"]];
                }
            }
        }];
    } else if ([path hasPrefix:@"/tg/peerSettings/"]) {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    
    [super actionStageResourceDispatched:path resource:resource arguments:arguments];
}

- (void)requestJoinChannel {
    if (_joinChannelDisposable == nil) {
        _joinChannelDisposable = [[SMetaDisposable alloc] init];
    }
    
    [_joinChannelPanel setActivity:true];
    
    OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
    [_joinChannelDisposable setDisposable:[[[TGChannelManagementSignals joinTemporaryChannel:_conversationId] deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error) {
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"GroupInfo.InvitationLinkGroupFull") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
        
        TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
        if (strongSelf != nil)
            [strongSelf->_joinChannelPanel setActivity:false];
    } completed:nil]];
}

- (bool)allowReplies {
    return (_kind == TGConversationKindPersistentChannel || _conversation.isMonoforum) && (_isGroup || _isCreator || _adminRights.canPostMessages);
}

- (int64_t)messageAuthorPeerId {
    if (_isGroup || _signaturesEnabled) {
        return TGTelegraphInstance.clientUserId;
    }
    
    return _conversationId;
}

- (bool)canDeleteMessage:(TGMessage *)message {
    if (_bannedRights.banSendMessages) {
        return false;
    }
    
    if (!_isGroup) {
        if (TGMessageSortKeySpace(message.sortKey) == TGMessageSpaceImportant) {
            if (_isCreator || _adminRights.canDeleteMessages || message.outgoing) {
                return true;
            } else {
                return false;
            }
        }
    }
    
    if (message.fromUid == _conversationId) {
        return _isCreator || _adminRights.canDeleteMessages;
    } else {
        if (message.outgoing || (_isCreator || _adminRights.canDeleteMessages)) {
            return true;
        }
    }
    return false;
}

- (bool)canModerateMessage:(TGMessage *)message {
    if (message.cid != _conversationId) {
        return false;
    }
    
    if (TGMessageSortKeySpace(message.sortKey) == TGMessageSpaceImportant) {
        return false;
    }
    
    if (message.actionInfo != nil) {
        return false;
    }
    
    if (message.outgoing) {
        return false;
    }
    
    if (message.mid >= TGMessageLocalMidBaseline) {
        return false;
    }
    
    if (_isCreator || _adminRights.canBanUsers) {
        return true;
    }
    
    return false;
}

- (TGUser *)checkedMessageModerateUser {
    NSArray *messageIndices = [self checkedMessageIndices];
    if (messageIndices.count > 20) {
        return nil;
    }
    
    NSNumber *sharedAuthorId = nil;
    
    for (TGMessageIndex *messageIndex in messageIndices) {
        int32_t messageId = messageIndex.messageId;
        TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:messageId peerId:_conversationId];
        if (message == nil || ![self canModerateMessage:message]) {
            return nil;
        }
        
        if (sharedAuthorId == nil) {
            sharedAuthorId = @(message.fromUid);
        } else if ([sharedAuthorId longLongValue] != message.fromUid) {
            return nil;
        }
    }
    
    if (sharedAuthorId != nil) {
        return [TGDatabaseInstance() loadUser:[sharedAuthorId longLongValue]];
    }
    
    return nil;
}

- (bool)canPinMessage:(TGMessage *)message {
    if (message.mid >= TGMessageLocalMidBaseline) {
        return false;
    }
    
    if (message.actionInfo != nil) {
        return false;
    }
    
    if (message.cid != _conversationId) {
        return false;
    }
    
    if (_isCreator || _adminRights.canPinMessages || (!_conversation.isChannelGroup && _adminRights.canEditMessages)) {
        return true;
    }
    
    return false;
}

- (bool)isMessagePinned:(int32_t)messageId {
    return messageId != 0 && messageId == _immediatePinnedMessage;
}

- (bool)canEditMessage:(TGMessage *)message {
    if (_bannedRights.banSendMessages) {
        return false;
    }
    
    if (_conversation.kind != TGConversationKindPersistentChannel) {
        return false;
    }
    
    if (message.mid >= TGMessageLocalMidBaseline || message.deliveryState == TGMessageDeliveryStateFailed || _uploadingEditMessages[@(message.mid + TGMessageLocalMidEditBaseline)] != nil) {
        return false;
    }
    
    bool editable = true;
    bool hasEditableContent = message.text.length != 0;
    for (id attachment in message.mediaAttachments) {
        if ([attachment isKindOfClass:[TGBotContextResultAttachment class]]) {
            editable = false;
            break;
        } else if ([attachment isKindOfClass:[TGImageMediaAttachment class]]) {
            hasEditableContent = true;
        } else if ([attachment isKindOfClass:[TGVideoMediaAttachment class]] && !((TGVideoMediaAttachment *)attachment).roundMessage) {
            hasEditableContent = true;
        } else if ([attachment isKindOfClass:[TGForwardedMessageMediaAttachment class]]) {
            editable = false;
            break;
        } else if ([attachment isKindOfClass:[TGViaUserAttachment class]]) {
            editable = false;
            break;
        } else if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]]) {
            hasEditableContent = ![((TGDocumentMediaAttachment *)attachment) isSticker];
            break;
        } else if ([attachment isKindOfClass:[TGLocationMediaAttachment class]]) {
            editable = false;
        }
    }
    
    if (!editable || !hasEditableContent) {
        return false;
    }
    
    int32_t maxChannelMessageEditTime = 60 * 60 * 24 * 2;
    NSData *data = [TGDatabaseInstance() customProperty:@"maxChannelMessageEditTime"];
    if (data.length >= 4) {
        [data getBytes:&maxChannelMessageEditTime length:4];
    }
    
    if ([TGTelegramNetworking instance].approximateRemoteTime > message.date + maxChannelMessageEditTime) {
        return false;
    }
    
    if (TGMessageSortKeySpace(message.sortKey) == TGMessageSpaceImportant) {
        if (_isCreator || message.outgoing || _adminRights.canEditMessages) {
            return true;
        }
    } else {
        if (message.outgoing) {
            return true;
        }
    }
    return false;
}

- (bool)canDeleteMessages {
    if (_bannedRights.banSendMessages) {
        return false;
    }
    
    return _isCreator || _adminRights.canDeleteMessages;
}

- (bool)canDeleteAllMessages {
    return _isGroup && _conversation.username.length == 0;
}

- (int64_t)requestPeerId {
    return _conversationId;
}

- (int64_t)requestAccessHash {
    return _accessHash;
}

- (void)_toggleBroadcastMode {
    _shouldNotifyMembers = !_shouldNotifyMembers;
    [TGDatabaseInstance() setChannelShouldMuteMembers:_conversationId value:!_shouldNotifyMembers];
}

- (void)_toggleTitleMode {
    TGMessageTransparentSortKey sortKey = TGMessageTransparentSortKeyUpperBound(_conversationId);
    TGModernConversationController *controller = self.controller;
    TGMessage *maxMessage = [controller latestVisibleMessage];
    if (maxMessage != nil) {
        sortKey = maxMessage.transparentSortKey;
    }
    
    _lastExpandedGroup = nil;
    
    if (_displayVariant != _conversation.displayVariant && _displayVariant == TGChannelDisplayVariantImportant) {
        _conversation = [_conversation copy];
        _conversation.displayVariant = _displayVariant;
        _signaturesEnabled = _conversation.signaturesEnabled;
        [TGDatabaseInstance() updateChannelDisplayVariant:_conversationId displayVariant:_displayVariant];
    }
    
    [self reloadVariantAtSortKey:sortKey group:nil jump:false top:false messageIdForVisibleHoleDirection:0 scrollBackMessageId:0 animated:true];
}

- (void)navigateToMessageId:(int32_t)messageId scrollBackMessageId:(int32_t)scrollBackMessageId forceUnseenMention:(bool)forceUnseenMention animated:(bool)animated {
    [self navigateToMessageId:messageId scrollBackMessageId:scrollBackMessageId forceUnseenMention:forceUnseenMention animated:animated forceLoad:false];
}

- (void)navigateToMessageId:(int32_t)messageId scrollBackMessageId:(int32_t)scrollBackMessageId forceUnseenMention:(bool)forceUnseenMention animated:(bool)animated forceLoad:(bool)forceLoad
{
    OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
    [TGModernConversationCompanion dispatchOnMessageQueue:^
    {
        if ([self attachedPeerId] != 0 && scrollBackMessageId >= migratedMessageIdOffset) {
            return;
        }
        
        NSMutableArray *updatedIndices = [[NSMutableArray alloc] init];
        NSMutableArray *updatedItems = [[NSMutableArray alloc] init];
        
        bool found = false;
        for (NSUInteger i = 0; i < _items.count; i++)
        {
            TGMessageModernConversationItem *item = _items[i];
            
            if (item->_message.mid == messageId)
            {
                if (forceUnseenMention && !item->_message.containsUnseenMention) {
                    item = [item deepCopy];
                    item->_message.containsUnseenMention = true;
                    ((NSMutableArray *)_items)[i] = item;
                    
                    [updatedIndices addObject:@(i)];
                    [updatedItems addObject:item];
                }
                found = true;
                break;
            }
        }
        
        int32_t sourceMid = scrollBackMessageId;
        
        if (found && !forceLoad)
        {
            TGDispatchOnMainThread(^
            {
                TGModernConversationController *controller = self.controller;
                int index = -1;
                for (NSNumber *nIndex in updatedIndices)
                {
                    index++;
                    [controller updateItemAtIndex:[nIndex intValue] toItem:updatedItems[index] delayAvailability:false];
                }
                [controller scrollToMessage:messageId peerId:0 sourceMessageId:sourceMid animated:animated];
            });
        }
        else
        {
            int64_t conversationId = _conversationId;
            [[TGChannelManagementSignals preloadedHistoryForPeerId:_conversationId accessHash:_accessHash aroundMessageId:messageId] startWithNext:^(NSDictionary *dict) {
                NSArray *removedImportantHoles = nil;
                NSArray *removedUnimportantHoles = nil;
                
                removedImportantHoles = dict[@"hole"] == nil ? nil : @[dict[@"hole"]];
                removedUnimportantHoles = dict[@"hole"] == nil ? nil : @[dict[@"hole"]];
                
                __block TGMessageTransparentSortKey sortKey = TGMessageTransparentSortKeyUpperBound(conversationId);
                __block bool keyExists = false;
                
                [TGDatabaseInstance() dispatchOnDatabaseThread:^{
                    [TGDatabaseInstance() channelMessageExists:conversationId messageId:messageId completion:^(bool exists, TGMessageSortKey key) {
                        if (exists) {
                            keyExists = true;
                            sortKey = TGMessageTransparentSortKeyMake(conversationId, TGMessageSortKeyTimestamp(key), TGMessageSortKeyMid(key), TGMessageSortKeySpace(key));
                        }
                    }];
                } synchronous:true];
                
                if (!keyExists) {
                    for (TGMessage *message in dict[@"messages"]) {
                        if (message.mid == messageId) {
                            sortKey = message.transparentSortKey;
                            keyExists = true;
                            break;
                        }
                    }
                }
                
                if (!keyExists)
                    return;
                
                [TGDatabaseInstance() addMessagesToChannel:conversationId messages:dict[@"messages"] deleteMessages:nil unimportantGroups:dict[@"unimportantGroups"] addedHoles:nil removedHoles:removedImportantHoles removedUnimportantHoles:removedUnimportantHoles updatedMessageSortKeys:nil returnGroups:false keepUnreadCounters:false skipFeedUpdate:true changedMessages:^(__unused NSArray *addedMessages, __unused NSArray *removedMessages, __unused NSDictionary *updatedMessages, __unused NSArray *addedUnimportantHoles, __unused NSArray *removedUnimportantHoles) {
                    [TGModernConversationCompanion dispatchOnMessageQueue:^{
                        TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                        if (strongSelf != nil) {
                            if (TGMessageTransparentSortKeySpace(sortKey) == TGMessageSpaceUnimportant && strongSelf->_displayVariant != TGChannelDisplayVariantAll) {
                            }
                            [strongSelf reloadVariantAtSortKey:sortKey group:nil jump:true top:false messageIdForVisibleHoleDirection:TGMessageTransparentSortKeyMid(sortKey) scrollBackMessageId:scrollBackMessageId animated:true];
                        }
                    }];
                }];
            }];
        }
    }];
}

- (void)controllerDidUpdateTypingActivity
{
    if (_isGroup) {
        [ActionStageInstance() dispatchOnStageQueue:^ {
            CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
            if (ABS(currentTime - _lastTypingActivity) >= 4.0) {
                _lastTypingActivity = currentTime;
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/activity/(typing)", _conversationId] options:@{@"accessHash": @(_accessHash)} watcher:self];
            }
        }];
    }
}

- (void)controllerDidCancelTypingActivity
{
}

- (UIView *)_conversationHeader
{
    return nil;
}

- (SSignal *)userListForMention:(NSString *)mention canBeContextBot:(bool)canBeContextBot includeSelf:(bool)includeSelf
{
    bool isGroup = _isGroup;
    int64_t conversationId = _conversationId;
    NSArray *recentUserIds = isGroup ? [self recentMentionUserIds] : @[];
    SSignal *remoteMemberIds = [SSignal single:@[]];
    if (isGroup) {
        TLChannelParticipantsFilter *filter = nil;
        if (mention.length == 0) {
            filter = [[TLChannelParticipantsFilter$channelParticipantsRecent alloc] init];
        } else {
            TLChannelParticipantsFilter$channelParticipantsSearch *searchFilter = [[TLChannelParticipantsFilter$channelParticipantsSearch alloc] init];
            searchFilter.q = mention;
            filter = searchFilter;
        }
        SSignal *request = [[TGChannelManagementSignals channelMembers:conversationId accessHash:_accessHash filter:filter offset:0 count:200] mapToSignal:^SSignal *(NSDictionary *dict) {
            return [TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id {
                NSMutableArray *userIds = [[NSMutableArray alloc] init];
                NSMutableArray *members = [[NSMutableArray alloc] init];
                NSDictionary *memberDatas = dict[@"memberDatas"];
                for (TGUser *user in dict[@"users"]) {
                    [userIds addObject:@(user.uid)];
                    TGCachedConversationMember *member = memberDatas[@(user.uid)];
                    if (member != nil) {
                        [members addObject:member];
                    }
                }
                if (mention.length == 0 && dict[@"users"] != nil) {
                    [TGDatabaseInstance() updateChannelCachedData:conversationId block:^TGCachedConversationData *(TGCachedConversationData *data) {
                        if (data == nil) {
                            data = [[TGCachedConversationData alloc] init];
                        }
                        return [data updateGeneralMembers:members];
                    }];
                }
                return userIds;
            }];
        }];
        if (mention.length != 0) {
            request = [[[SSignal complete] delay:0.2 onQueue:[SQueue mainQueue]] then:request];
        }
        remoteMemberIds = [remoteMemberIds then:[request catch:^SSignal *(__unused id error) {
            return [SSignal complete];
        }]];
    }
    SSignal *contextBots = canBeContextBot ? [TGRecentContextBotsSignal recentBots] : [SSignal single:@[]];
    SSignal *cachedMembers = isGroup ? [[TGDatabaseInstance() channelCachedData:conversationId] map:^id(TGCachedConversationData *data) {
        return data == nil ? [[TGCachedConversationData alloc] init] : data;
    }] : [SSignal single:[[TGCachedConversationData alloc] init]];
    return [[[SSignal combineSignals:@[cachedMembers, contextBots, remoteMemberIds]] mapToSignal:^SSignal *(NSArray *result) {
        TGCachedConversationData *cachedData = result[0];
        NSMutableArray *memberUserIds = [[NSMutableArray alloc] init];
        for (TGCachedConversationMember *member in cachedData.generalMembers) {
            [memberUserIds addObject:@(member.uid)];
        }
        [memberUserIds addObjectsFromArray:result[2]];
        return [TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id {
            return [TGModernConversationCompanion mentionUsersForQuery:mention memberUserIds:memberUserIds recentUserIds:recentUserIds contextBotIds:result[1] includeSelf:includeSelf];
        }];
    }] deliverOn:[SQueue mainQueue]];
}

- (SSignal *)commandListForCommand:(NSString *)command
{
    return [[[TGDatabaseInstance() channelCachedData:_conversationId] mapToSignal:^SSignal *(TGCachedConversationData *cachedData) {
        if (cachedData.botInfos.count != 0) {
            NSString *normalizedCommand = [command lowercaseString];
            if ([normalizedCommand hasPrefix:@"/"])
                normalizedCommand = [normalizedCommand substringFromIndex:1];
            
            NSMutableArray *botUsers = [[NSMutableArray alloc] init];
            NSMutableArray *botInfoSignals = [[NSMutableArray alloc] init];
            NSMutableArray *initialStates = [[NSMutableArray alloc] init];
            for (NSNumber *nUid in [cachedData.botInfos allKeys])
            {
                TGUser *user = [TGDatabaseInstance() loadUser:[nUid longLongValue]];
                if (user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot)
                {
                    [botUsers addObject:user];
                    [botInfoSignals addObject:[[SSignal single:cachedData.botInfos[nUid]] map:^id(TGBotInfo *botInfo) {
                        NSMutableArray *commands = [[NSMutableArray alloc] init];
                        for (TGBotComandInfo *commandInfo in botInfo.commandList) {
                            if (normalizedCommand.length == 0 || [[commandInfo.command lowercaseString] hasPrefix:normalizedCommand]) {
                                [commands addObject:commandInfo];
                            }
                        }
                        return commands;
                    }]];
                    [initialStates addObject:@[]];
                }
            }
            
            return [[SSignal combineSignals:botInfoSignals withInitialStates:initialStates] map:^id(NSArray *commandLists) {
                NSMutableArray *commands = [[NSMutableArray alloc] init];
                NSUInteger index = 0;
                for (NSArray *commandList in commandLists) {
                    [commands addObject:@[botUsers[index], commandList]];
                    index++;
                }
                
                return commands;
            }];
        } else {
            return [SSignal single:@[]];
        }
    }] deliverOn:[SQueue mainQueue]];
}

- (int64_t)attachedPeerId {
    return _migrationData.peerId;
}

- (void)setInvalidatedPts:(int32_t)invalidatedPts {
#ifdef DEBUG
#endif
    
    [TGModernConversationCompanion dispatchOnMessageQueue:^{
        if (_invalidatedPts != invalidatedPts) {
            _invalidatedPts = invalidatedPts;
            
            [self _validatePts];
        }
    }];
}

- (void)_validatePts {
    if (_invalidatedPts == 0) {
        return;
    }
    
    if (_updatingInvalidatedMessages) {
        _needsToValidatePts = true;
    } else {
        _needsToValidatePts = false;
        
        NSMutableArray *invalidatedMessageRanges = [[NSMutableArray alloc] init];
        int32_t minPts = 1;
        
        for (TGMessageModernConversationItem *item in _items) {
            if (item->_message.cid == _conversationId && item->_message.mid < TGMessageLocalMidBaseline) {
                if (item->_message.hole != nil || item->_message.group != nil) {
                    TLMessageRange$messageRange *lastRange = invalidatedMessageRanges.lastObject;
                    if (lastRange != nil && lastRange.max_id != 0) {
                        TLMessageRange$messageRange *nextRange = [[TLMessageRange$messageRange alloc] init];
                        nextRange.min_id = 0;
                        nextRange.max_id = 0;
                        [invalidatedMessageRanges addObject:nextRange];
                    }
                } else if (item->_message.mid > 0) {
                    if (item->_message.pts < _invalidatedPts) {
                        int32_t messagePts = MAX(1, item->_message.pts);
                        minPts = minPts == 1 ? messagePts : MIN(messagePts, minPts);
                        
                        TLMessageRange$messageRange *lastRange = invalidatedMessageRanges.lastObject;
                        if (lastRange == nil) {
                            lastRange = [[TLMessageRange$messageRange alloc] init];
                            lastRange.min_id = 0;
                            lastRange.max_id = 0;
                            [invalidatedMessageRanges addObject:lastRange];
                        }
                        
                        if (lastRange.max_id == 0) {
                            lastRange.min_id = item->_message.mid;
                            lastRange.max_id = item->_message.mid;
                        } else {
                            lastRange.min_id = MIN(lastRange.min_id, item->_message.mid);
                        }
                    }
                }
            }
        }
        
        if (invalidatedMessageRanges.count != 0) {
            TLMessageRange$messageRange *lastRange = invalidatedMessageRanges.lastObject;
            if (lastRange.max_id == 0) {
                [invalidatedMessageRanges removeLastObject];
            }
        }
        
        if (invalidatedMessageRanges.count != 0) {
            TGLog(@"Will invalidate message ranges to pts %d:", _invalidatedPts);
            
            _updatingInvalidatedMessages = true;
            
            if (_updatingInvalidatedMessagesDisposable == nil) {
                _updatingInvalidatedMessagesDisposable = [[SMetaDisposable alloc] init];
            }
            
            OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
            int32_t validPts = _invalidatedPts;
            [_updatingInvalidatedMessagesDisposable setDisposable:[[TGChannelStateSignals validateMessageRanges:_conversationId pts:minPts validPts:validPts messageRanges:invalidatedMessageRanges] startWithNext:nil completed:^{
                [TGModernConversationCompanion dispatchOnMessageQueue:^{
                    TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                    if (strongSelf != nil) {
                                        [strongSelf _messageRangesValidated:invalidatedMessageRanges pts:validPts];
                        
                        strongSelf->_updatingInvalidatedMessages = false;
                        
                        if (strongSelf->_needsToValidatePts) {
                            [strongSelf _validatePts];
                        }
                    }
                }];
            }]];
        }
    }
}

- (void)_messageRangesValidated:(NSArray *)messageRanges pts:(int32_t)pts {
    NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
    for (TLMessageRange *range in messageRanges) {
        [indexSet addIndexesInRange:NSMakeRange(range.min_id, range.max_id - range.min_id + 1)];
    }
    for (NSUInteger i = 0; i < _items.count; i++) {
        TGMessageModernConversationItem *item = _items[i];
        
        if ([indexSet containsIndex:item->_message.mid]) {
            item = [item deepCopy];
            item->_message.pts = pts;
            [((NSMutableArray *)_items) replaceObjectAtIndex:i withObject:item];
        }
    }
}

- (void)_itemsUpdated {
    [TGModernConversationCompanion dispatchOnMessageQueue:^{
        [super _itemsUpdated];
        
        [self _validatePts];
    }];
}

- (void)_performFastScrollDown:(bool)becauseOfSendTextAction becauseOfNavigation:(bool)becauseOfNavigation
{
    [TGDatabaseInstance() dispatchOnDatabaseThread:^
    {
        [TGDatabaseInstance() channelMessages:_conversationId maxTransparentSortKey:TGMessageTransparentSortKeyUpperBound(_conversationId) count:20 important:_displayVariant == TGChannelDisplayVariantImportant mode:TGChannelHistoryRequestEarlier completion:^(NSArray *messages, bool hasLater) {
            
            _historyBelow = hasLater;
            
            NSMutableArray *sortedTopMessages = [[NSMutableArray alloc] initWithArray:messages];
            [sortedTopMessages sortUsingComparator:^NSComparisonResult(TGMessage *message1, TGMessage *message2)
            {
                NSTimeInterval date1 = message1.date;
                NSTimeInterval date2 = message2.date;
                
                if (ABS(date1 - date2) < DBL_EPSILON)
                {
                    if (message1.mid > message2.mid)
                        return NSOrderedAscending;
                    else
                        return NSOrderedDescending;
                }
                
                return date1 > date2 ? NSOrderedAscending : NSOrderedDescending;
            }];
            
            [TGModernConversationCompanion dispatchOnMessageQueue:^
            {
                _historyBelow = false;
                _historyAbove = true;
                if (_migrationData.peerId != 0) {
                    _migrationHistoryAbove = true;
                }
                
                [self _replaceMessagesWithFastScroll:sortedTopMessages intent:becauseOfNavigation ? TGModernConversationAddMessageIntentGeneric : (becauseOfSendTextAction ? TGModernConversationAddMessageIntentSendTextMessage : TGModernConversationAddMessageIntentSendOtherMessage) scrollToMessageId:0 peerId:0 scrollBackMessageId:0 animated:!becauseOfNavigation];
            }];
        }];
    } synchronous:false];
}

- (bool)shouldFastScrollDown {
    return _historyBelow;
}

- (bool)canAddNewMessagesToTop {
    return !_historyBelow;
}

- (SSignal *)editingContextForMessageWithId:(int32_t)messageId {
    return [[TGChannelManagementSignals messageEditData:_conversationId accessHash:_accessHash messageId:messageId] catch:^SSignal *(__unused id error) {
        return [SSignal single:nil];
    }];
}

- (SSignal *)saveEditedMessageWithId:(int32_t)messageId text:(NSString *)text entities:(NSArray *)entities disableLinkPreviews:(bool)disableLinkPreviews {
    OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
    int64_t peerId = _conversationId;
    SSignal *notModified = [[TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id{
        TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:messageId peerId:peerId];
        NSString *messageText = message.text;
        for (id attachment in message.mediaAttachments) {
            if ([attachment isKindOfClass:[TGImageMediaAttachment class]]) {
                messageText = ((TGImageMediaAttachment *)attachment).caption;
            } else if ([attachment isKindOfClass:[TGVideoMediaAttachment class]]) {
                messageText = ((TGVideoMediaAttachment *)attachment).caption;
            } else if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]]) {
                messageText = ((TGDocumentMediaAttachment *)attachment).caption;
            }
        }
        
        if (TGStringCompare(text, messageText) && !disableLinkPreviews) {
            return [SSignal complete];
        } else {
            return [SSignal fail:nil];
        }
    }] switchToLatest];
    
    notModified = [SSignal fail:nil];
    
    return [notModified catch:^SSignal *(__unused id error) {
        return [[[[TGGroupManagementSignals editMessage:_conversationId accessHash:_accessHash messageId:messageId text:text entities:entities disableLinksPreview:disableLinkPreviews media:nil] mapToSignal:^SSignal *(TGMessage *updatedMessage) {
            TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
            if (strongSelf != nil) {
                TGMessage *message = updatedMessage;
                if (message == nil) {
                    return [SSignal fail:nil];
                } else {
                    return [SSignal single:message];
                }
            }
            
            return [SSignal complete];
        }] deliverOn:[TGModernConversationCompanion messageQueue]] onNext:^(TGMessage *message) {
            TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
            if (strongSelf != nil) {
                [strongSelf updateMessagesLive:@{@(message.mid): message} animated:false];
            }
        }];
    }];
}

- (SSignal *)updatePinnedMessage:(int32_t)messageId unpin:(bool)unpin {
    SSignal *askSignal = [SSignal single:@true];
    bool isChannelGroup = _isGroup;
    
    if (unpin) {
        askSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"Conversation.UnpinMessageAlert") cancelButtonTitle:TGLocalized(@"Common.No") okButtonTitle:TGLocalized(@"Common.Yes") completionBlock:^(bool okButtonPressed) {
                [subscriber putNext:@(okButtonPressed)];
                [subscriber putCompletion];
            }];
            
            return [[SBlockDisposable alloc] initWithBlock:^{
            }];
        }];
    } else {
        askSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
            if (_isGroup)
            {
                TGCustomAlertView *alertView = [TGCustomAlertView presentAlertWithTitle:nil message:isChannelGroup ? TGLocalized(@"Conversation.PinMessageAlertGroup") : TGLocalized(@"Conversation.PinMessageAlertGroup") cancelButtonTitle:TGLocalized(@"Conversation.PinMessageAlert.OnlyPin") okButtonTitle:TGLocalized(@"Common.OK") completionBlock:^(bool okButtonPressed) {
                    [subscriber putNext:@(okButtonPressed)];
                    [subscriber putCompletion];
                }];
                alertView.noActionOnDimTap = true;
            }
            else
            {
                [subscriber putNext:@(true)];
                [subscriber putCompletion];
            }
            
            return [[SBlockDisposable alloc] initWithBlock:^{
            }];
        }];
    }
    
    return [[askSignal deliverOn:[SQueue mainQueue]] mapToSignal:^SSignal *(NSNumber *update) {
        if ([update boolValue] || !unpin) {
            return [SSignal defer:^SSignal *{
                TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
                [progressWindow showWithDelay:0.2];
                
                return [[[[TGChannelManagementSignals updatePinnedMessage:_conversationId accessHash:_accessHash messageId:messageId unpin:unpin notify:[update boolValue]] catch:^SSignal *(id error) {
                    NSString *errorType = [[TGTelegramNetworking instance] extractNetworkErrorType:error];
                    if ([errorType isEqualToString:@"CHAT_NOT_MODIFIED"]) {
                        return [SSignal complete];
                    }
                    return [SSignal fail:nil];
                }] timeout:5.0 onQueue:[SQueue concurrentDefaultQueue] orSignal:[SSignal fail:@"timeout"]] onDispose:^{
                    TGDispatchOnMainThread(^{
                        [progressWindow dismiss:true];
                    });
                }];
            }];
        } else {
            return [SSignal complete];
        }
    }];
}

- (bool)canCreateLinksToMessages {
    return _conversation.username.length != 0;
}

- (SSignal *)applyModerateMessageActions:(NSSet *)actions messageIds:(NSArray *)messageIds {
    if (messageIds.count == 0)
        return [SSignal fail:nil];
    
    NSMutableArray *signals = [[NSMutableArray alloc] init];
    
    TGMessage *anyMessage = [TGDatabaseInstance() loadMessageWithMid:[messageIds[0] intValue] peerId:_conversationId];
    if (anyMessage == nil) {
        return [SSignal fail:nil];
    }
    
    if ([actions containsObject:@(TGMessageModerateActionDeleteAll)]) {
        TGUser *user = [TGDatabaseInstance() loadUser:anyMessage.fromUid];
        if (user != nil) {
            [signals addObject:[[TGChannelManagementSignals removeAllUserMessages:_conversationId accessHash:_accessHash user:user] catch:^SSignal *(__unused id error) {
                return [SSignal complete];
            }]];
        }
    } else if ([actions containsObject:@(TGMessageModerateActionDelete)]) {
        SSignal *signal = [SSignal defer:^SSignal *{
            [self _deleteMessages:messageIds animated:true];
            [self controllerDeletedMessages:messageIds forEveryone:false completion:nil];
            return [SSignal complete];
        }];
        [signals addObject:signal];
    }
    
    if ([actions containsObject:@(TGMessageModerateActionReport)]) {
        TGUser *user = [TGDatabaseInstance() loadUser:anyMessage.fromUid];
        if (user != nil) {
            SSignal *signal = [[TGChannelManagementSignals reportUserSpam:_conversationId accessHash:_accessHash user:user messageIds:messageIds] catch:^SSignal *(__unused id error) {
                return [SSignal complete];
            }];
            [signals addObject:signal];
        }
    }
    
    if ([actions containsObject:@(TGMessageModerateActionBan)]) {
        TGUser *user = [TGDatabaseInstance() loadUser:anyMessage.fromUid];
        if (user != nil) {
            TGChannelBannedRights *rights = [[TGChannelBannedRights alloc] initWithBanReadMessages:true banSendMessages:true banSendMedia:true banSendStickers:true banSendGifs:false banSendGames:false banSendInline:false banEmbedLinks:true timeout:INT32_MAX];
            SSignal *signal = [[[TGChannelManagementSignals updateChannelBannedRightsAndGetMembership:_conversationId accessHash:_accessHash user:user rights:rights] onNext:^(TGCachedConversationMember *resultMember) {
                [TGDatabaseInstance() updateChannelCachedData:_conversationId block:^TGCachedConversationData *(TGCachedConversationData *data) {
                    if (data == nil) {
                        data = [[TGCachedConversationData alloc] init];
                    }
                    
                    return [data updateMemberBannedRights:user.uid rights:rights timestamp:resultMember != nil ? resultMember.timestamp : (int32_t)OGRemoteClockTime() isMember:resultMember != nil kickedById:TGTelegraphInstance.clientUserId];
                }];
            }] catch:^SSignal *(__unused id error) {
                return [SSignal complete];
            }];
            [signals addObject:signal];
        }
    }
    
    return [SSignal combineSignals:signals];
}

- (bool)canReportMessage:(TGMessage *)message {
    if (message.cid != _conversationId) {
        return false;
    }
    
    if (message.actionInfo != nil) {
        return false;
    }
    
    if (!message.outgoing) {
        return true;
    }
    return false;
}

- (void)contactLinkTitlePanelBlockContactPressed:(TGModernConversationContactLinkTitlePanel *)__unused panel {
    SMetaDisposable *metaDisposable = [[SMetaDisposable alloc] init];
    id<SDisposable> disposable = [[[TGServiceSignals reportSpam:_conversationId accessHash:_accessHash] onDispose:^{
        [TGTelegraphInstance.disposeOnLogout remove:metaDisposable];
    }] startWithNext:nil];
    [metaDisposable setDisposable:disposable];
    [TGTelegraphInstance.disposeOnLogout add:metaDisposable];
    
    [TGAppDelegateInstance.rootController.dialogListController.dialogListCompanion deleteItem:[[TGConversation alloc] initWithConversationId:_conversationId unreadCount:0 serviceUnreadCount:0] animated:false];
    
    TGModernConversationController *controller = self.controller;
    [controller.navigationController popToRootViewControllerAnimated:true];
}

- (void)contactLinkTitlePanelDismissed:(TGModernConversationContactLinkTitlePanel *)__unused panel {
    [TGDatabaseInstance() hideReportSpamForPeerId:_conversationId];
}

- (void)reportChannelPressed {
    TGModernConversationController *controller = self.controller;
    OGChannelCompanionAnchor *companionAnchor = _lifetimeAnchor;
    [[[TGCustomActionSheet alloc] initWithTitle:nil actions:@[
    [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"ReportPeer.ReasonSpam") action:@"spam"],
    [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"ReportPeer.ReasonViolence") action:@"violence"],
    [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"ReportPeer.ReasonPornography") action:@"pornography"],
    [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"ReportPeer.ReasonCopyright") action:@"copyright"],
    [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"ReportPeer.ReasonOther") action:@"other"],
    [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]] actionBlock:^(__unused id target, NSString *action) {
        TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
        if (strongSelf != nil) {
            if (![action isEqualToString:@"cancel"]) {
                TGReportPeerReason reason = TGReportPeerReasonSpam;
                if ([action isEqualToString:@"spam"]) {
                    reason = TGReportPeerReasonSpam;
                } else if ([action isEqualToString:@"violence"]) {
                    reason = TGReportPeerReasonViolence;
                } else if ([action isEqualToString:@"pornography"]) {
                    reason = TGReportPeerReasonPornography;
                } else if ([action isEqualToString:@"copyright"]) {
                    reason = TGReportPeerReasonCopyright;
                } else if ([action isEqualToString:@"other"]) {
                    reason = TGReportPeerReasonOther;
                }
                
                void (^reportBlock)(NSString *) = ^(NSString *otherText) {
                    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
                    [progressWindow showWithDelay:0.1];
                    
                    [[[[TGAccountSignals reportPeer:strongSelf->_conversation.conversationId accessHash:strongSelf->_conversation.accessHash reason:reason otherText:otherText] deliverOn:[SQueue mainQueue]] onDispose:^{
                        TGDispatchOnMainThread(^{
                            [progressWindow dismiss:true];
                        });
                    }] startWithNext:nil error:^(__unused id error) {
                        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"Login.UnknownError") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                    } completed:^{
                        TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                        if (strongSelf != nil) {
                            TGModernConversationController *controller = strongSelf.controller;
                            [controller dismissViewControllerAnimated:true completion:nil];
                        }
                        
                        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"ReportPeer.AlertSuccess") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                    }];
                };
                
                if (reason == TGReportPeerReasonOther) {
                    TGReportPeerOtherTextController *controller = [[TGReportPeerOtherTextController alloc] initWithCompletion:^(NSString *text) {
                        if (text.length != 0) {
                            reportBlock(text);
                        }
                    }];
                    TGChannelConversationCompanion *strongSelf = OGChannelCompanionFromAnchor(companionAnchor);
                    if (strongSelf != nil) {
                        TGModernConversationController *myController = strongSelf.controller;
                        [myController presentViewController:[TGNavigationController navigationControllerWithControllers:@[controller]] animated:true completion:nil];
                    }
                } else {
                    reportBlock(nil);
                }
            }
        }
    } target:self] showInView:controller.view];
}

- (void)updateMessagesLive:(NSDictionary *)messageIdToMessage animated:(bool)animated {
    [super updateMessagesLive:messageIdToMessage animated:animated];
    
    TGDispatchOnMainThread(^{
        if (_pinnedBanner != nil && messageIdToMessage[@(_pinnedBanner.message.mid)] != nil){
            TGMessage *message = messageIdToMessage[@(_pinnedBanner.message.mid)];
            [_pinnedBanner updateMessage:message];
        }
    });
}

- (SSignal *)primaryTitlePanel {
    return _primaryPanel.signal;
}

- (TGModernGalleryController *)galleryControllerForAvatar
{
    if (_conversation.chatPhotoFullSmall.length == 0)
        return nil;
    
    TGModernGalleryController *modernGallery = [[TGModernGalleryController alloc] initWithContext:[TGLegacyComponentsContext shared]];
    modernGallery.model = [[TGGroupAvatarGalleryModel alloc] initWithPeerId:_conversationId accessHash:_accessHash messageId:0 legacyThumbnailUrl:_conversation.chatPhotoFullSmall legacyUrl:_conversation.chatPhotoFullBig imageSize:CGSizeMake(640.0f, 640.0f)];
    
    return modernGallery;
}

- (id)acquireAudioRecordingActivityHolder {
    if (_isGroup) {
        return [super acquireAudioRecordingActivityHolder];
    }
    return nil;
}

- (id)acquireVideoMessageRecordingActivityHolder {
    if (_isGroup) {
        return [super acquireVideoMessageRecordingActivityHolder];
    }
    return nil;
}

- (bool)canSendMedia {
    return !_bannedRights.banSendMedia;
}

- (bool)canSendGifs {
    return !_bannedRights.banSendGifs;
}

- (bool)canSendGames {
    return !_bannedRights.banSendGames;
}

- (bool)canSendInline {
    return !_bannedRights.banSendInline;
}

- (bool)canSendStickers {
    return !_bannedRights.banSendStickers;
}

- (bool)canAttachLinkPreviews {
    return !_bannedRights.banEmbedLinks;
}

- (bool)allowLiveLocations {
    return [super allowLiveLocations] && [self canPostMessages];
}

- (bool)allowPollSending {
    return [self canPostMessages] && [self canSendMedia];
}

- (bool)allowPublicPollVoters {
    return _isGroup;
}

- (bool)useOnlyLocalLiveLocations {
    return !_conversation.isChannelGroup;
}

- (NSNumber *)inlineMediaRestrictionTimeout {
    if (_bannedRights != nil && _bannedRights.banSendInline) {
        return @(_bannedRights.timeout);
    }
    return nil;
}

- (NSNumber *)mediaRestrictionTimeout {
    if (_bannedRights != nil && _bannedRights.banSendMedia) {
        return @(_bannedRights.timeout);
    }
    return nil;
}

- (NSNumber *)stickerRestrictionTimeout {
    if (_bannedRights != nil && _bannedRights.banSendStickers) {
        return @(_bannedRights.timeout);
    }
    return nil;
}

- (bool)messageSearchByUserAvailable {
    return _isGroup;
}

- (bool)suppressesOutgoingUnreadContents {
    return !_isGroup;
}

@end
