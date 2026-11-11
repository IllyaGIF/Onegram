#import "TGGroupModernConversationCompanion.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGLegacyComponentsContext.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"

#import "TGAppDelegate.h"
#import "TGDatabase.h"
#import "TGTelegraph.h"
#import "TGTelegramNetworking.h"

#import "TGModernConversationController.h"
#import "TGModernConversationGroupTitlePanel.h"
#import "TGModernConversationActionInputPanel.h"

#import "TGModernConversationTitleIcon.h"

#import "TGGroupInfoController.h"

#import "TGDialogListCompanion.h"

#import "TGModernConversationTitleView.h"

#import "TGInterfaceManager.h"

#import "TGMessageModernConversationItem.h"

#import "TGBotSignals.h"
#import "TGRecentContextBotsSignal.h"

#import "TGModernViewContext.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryController.h"
#import "TGGroupAvatarGalleryModel.h"

#import "TGLiveLocationTitlePanel.h"

#import "TGPinnedMessageTitlePanel.h"
#import "TLRPCmessages_search.h"
#import "TGMessage+Telegraph.h"
#import "TGUserDataRequestBuilder.h"

#import "TGPresentation.h"
#import "../OnegramRuntime/OGRemoteClock.h"

static const int32_t OGGroupPinnedFilterSignature = 0x1bb00451;
static const int32_t OGGroupPinnedFilterNoName = -1;

@interface OGGroupPinnedSearchFilter : TLMessagesFilter
@end

@implementation OGGroupPinnedSearchFilter

- (int32_t)TLconstructorSignature
{
    return OGGroupPinnedFilterSignature;
}

- (int32_t)TLconstructorName
{
    return OGGroupPinnedFilterNoName;
}

- (void)TLserialize:(NSOutputStream *)__unused os
{
}

@end

static TGMessage *OGGroupPinnedTargetOfServiceMessage(TGMessage *serviceMessage)
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

static NSComparisonResult OGGroupPinnedNewestFirst(TGMessage *left, TGMessage *right)
{
    int32_t leftDate = [left actualDate];
    int32_t rightDate = [right actualDate];
    if (leftDate != rightDate)
        return leftDate > rightDate ? NSOrderedAscending : NSOrderedDescending;
    return left.mid > right.mid ? NSOrderedAscending : NSOrderedDescending;
}

static void OGGroupPinnedAppendDistinct(NSMutableArray *destination, NSMutableSet *knownIds, NSArray *source)
{
    for (TGMessage *candidate in source)
    {
        if (candidate.mid == 0 || [knownIds containsObject:@(candidate.mid)])
            continue;
        [knownIds addObject:@(candidate.mid)];
        [destination addObject:candidate];
    }
}

static NSString *OGGroupPinnedMenuLabel(TGMessage *message)
{
    NSString *raw = message.text.length != 0 ? message.text : message.caption;
    NSString *label = [[raw componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
    while ([label rangeOfString:@"  "].location != NSNotFound)
        label = [label stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    label = [label stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return label.length == 0 ? TGLocalized(@"Conversation.PinnedMessage") : label;
}

static NSString *OGGroupPinnedClassicButtonTitle(NSUInteger slot, NSString *label)
{
    NSString *numbered = [NSString stringWithFormat:@"%d. %@", (int)slot + 1, label];
    if (numbered.length <= 24)
        return numbered;
    NSRange keep = [numbered rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, 23)];
    return [[numbered substringWithRange:keep] stringByAppendingString:@"…"];
}

static NSString *OGGroupPinnedPageTitle(NSUInteger from, NSUInteger to, bool backward)
{
    NSString *format = backward ? @"‹ %d–%d" : @"%d–%d ›";
    return [NSString stringWithFormat:format, (int)from + 1, (int)to];
}

static TGMenuSheetButtonItemView *OGGroupPinnedSheetButton(NSString *title, void (^action)(void))
{
    return [[TGMenuSheetButtonItemView alloc] initWithTitle:title type:TGMenuSheetButtonTypeDefault action:action];
}

static NSArray *OGGroupDecodePinnedResult(TLmessages_Messages *result)
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

static TGMenuSheetController *OGGroupMakeSheet(void)
{
    TGMenuSheetController *sheet = [[TGMenuSheetController alloc] initWithContext:[TGLegacyComponentsContext shared] dark:false];
    sheet.dismissesByOutsideTap = true;
    sheet.narrowInLandscape = true;
    return sheet;
}

typedef enum {
    TGGroupParticipationStatusMember = 0,
    TGGroupParticipationStatusLeft = 1,
    TGGroupParticipationStatusKicked = 2,
    TGGroupParticipationStatusDeactivated = 3
} TGGroupParticipationStatus;

@interface TGGroupModernConversationCompanion ()
{
    NSDictionary *_initialUserActivities;
    
    TGConversation *_conversation;
    
    CFAbsoluteTime _lastTypingActivity;
    
    bool _hasLeavePanel;
    
    bool _isMuted;
    
    NSMutableDictionary *_defaultNotificationSettings;
    NSMutableDictionary *_groupNotificationSettings;
    
    bool _hasBots;
    bool _hasSingleBot;
    
    SVariable *_panelVariable;
    NSArray *_liveLocations;
    id<SDisposable> _liveLocationDisposable;

    NSArray *_pinnedMessageList;
    TGPinnedMessageTitlePanel *_pinnedBanner;
    id<SDisposable> _pinnedFetchDisposable;
    bool _pinnedBannerDismissed;
    
    TGModernConversationTitlePanel *_primaryPanel;
}

@end

@implementation TGGroupModernConversationCompanion

- (instancetype)initWithConversation:(TGConversation *)conversation userActivities:(NSDictionary *)userActivities mayHaveUnreadMessages:(bool)mayHaveUnreadMessages
{
    _panelVariable = [[SVariable alloc] init];
    self = [super initWithConversation:conversation mayHaveUnreadMessages:mayHaveUnreadMessages];
    if (self != nil)
    {
        [_panelVariable set:[SSignal single:nil]];
        
        _conversation = conversation;
        _pinnedMessageList = @[];
        _hasBots = [self conversationHasBots:conversation hasSingleBot:&_hasSingleBot];
        self.viewContext.commandsEnabled = _hasBots;
        _initialUserActivities = userActivities;
        
        _everyMessageNeedsAuthor = true;
        
        __weak TGGroupModernConversationCompanion *weakSelf = self;
        _liveLocationDisposable = [[self liveLocationSignal] startWithNext:^(NSArray *next)
        {
            __strong TGGroupModernConversationCompanion *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                TGLiveLocation *ownLiveLocation = nil;
                for (TGLiveLocation *liveLocation in next)
                {
                    if (liveLocation.hasOwnSession)
                    {
                        ownLiveLocation = liveLocation;
                        break;
                    }
                }
                strongSelf->_liveLocations = ownLiveLocation ? next : @[];
                [strongSelf _updateLiveLocationsPanel];
            }
        }];
    }
    return self;
}

- (void)dealloc
{
    [self.actionHandle reset];
    [_liveLocationDisposable dispose];
    [_pinnedFetchDisposable dispose];
}

- (SSignal *)primaryTitlePanel
{
    return _panelVariable.signal;
}

- (void)og_presentSheet:(TGMenuSheetController *)sheet anchoredAt:(UIView *)anchor
{
    __weak TGGroupModernConversationCompanion *weakOwner = self;
    __weak UIView *weakAnchor = anchor;
    sheet.sourceRect = ^CGRect
    {
        TGGroupModernConversationCompanion *owner = weakOwner;
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
        return OGGroupPinnedNewestFirst(left, right);
    }];
    
    for (TGMessage *candidate in newestFirst)
    {
        TGMessage *target = OGGroupPinnedTargetOfServiceMessage(candidate);
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
        _pinnedBannerDismissed = false;
    [self _updateLiveLocationsPanel];
}

- (void)og_foldPinnedMessages:(NSArray *)messages
{
    if (messages.count == 0)
        return;
    
    TGDispatchOnMainThread(^
    {
        NSMutableArray *folded = [[NSMutableArray alloc] init];
        NSMutableSet *knownIds = [[NSMutableSet alloc] init];
        OGGroupPinnedAppendDistinct(folded, knownIds, messages);
        OGGroupPinnedAppendDistinct(folded, knownIds, _pinnedMessageList);
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
        OGGroupPinnedAppendDistinct(adopted, knownIds, messages);
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
    
    __weak TGGroupModernConversationCompanion *weakOwner = self;
    __weak TGMenuSheetController *weakSheet = sheet;
    void (^openPage)(NSUInteger) = ^(NSUInteger target)
    {
        [weakOwner og_fillPinnedSheet:weakSheet fromOffset:target animated:true];
    };
    
    NSMutableArray *rows = [[NSMutableArray alloc] init];
    if (!classicSheet)
        [rows addObject:[[TGPinnedMessagesMenuHeaderItemView alloc] initWithMessageCount:total]];
    
    for (NSUInteger slot = firstShown; slot < pastLast; slot++)
    {
        TGMessage *pinned = _pinnedMessageList[slot];
        NSString *label = OGGroupPinnedMenuLabel(pinned);
        void (^choose)(void) = ^
        {
            [weakSheet dismissAnimated:true];
            [weakOwner og_jumpToPinnedMessage:pinned];
        };
        
        if (classicSheet)
            [rows addObject:OGGroupPinnedSheetButton(OGGroupPinnedClassicButtonTitle(slot, label), choose)];
        else
            [rows addObject:[[TGPinnedMessageMenuItemView alloc] initWithTitle:label index:slot action:choose]];
    }
    
    if (firstShown > 0)
    {
        NSUInteger backStart = firstShown >= perPage ? firstShown - perPage : 0;
        NSUInteger backEnd = MIN(backStart + perPage, total);
        [rows addObject:OGGroupPinnedSheetButton(OGGroupPinnedPageTitle(backStart, backEnd, true), ^{ openPage(backStart); })];
    }
    
    if (pastLast < total)
    {
        NSUInteger forwardEnd = MIN(pastLast + perPage, total);
        [rows addObject:OGGroupPinnedSheetButton(OGGroupPinnedPageTitle(pastLast, forwardEnd, false), ^{ openPage(pastLast); })];
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
    TGMenuSheetController *sheet = OGGroupMakeSheet();
    sheet.maxHeight = MIN(420.0f, self.controller.view.bounds.size.height - 44.0f);
    [self og_fillPinnedSheet:sheet fromOffset:0 animated:false];
    [self og_presentSheet:sheet anchoredAt:panel];
}

- (SSignal *)_requestPinnedMessages
{
    TLRPCmessages_search *query = [[TLRPCmessages_search alloc] init];
    query.peer = [TGTelegraphInstance createInputPeerForConversation:_conversationId accessHash:_conversation.accessHash];
    query.q = @"";
    query.filter = [[OGGroupPinnedSearchFilter alloc] init];
    query.min_date = query.max_date = 0;
    query.offset = query.max_id = 0;
    query.limit = 50;
    query.flags = 0;
    
    int64_t peerId = _conversationId;
    return [[[[TGTelegramNetworking instance] requestSignal:query] map:^id(TLmessages_Messages *result)
    {
        return OGGroupDecodePinnedResult(result);
    }] catch:^SSignal *(id error)
    {
        TGLog(@"TRACE pinned.search.error peer=%lld filter=inputMessagesFilterPinned error=%@", peerId, error);
        return [SSignal single:[NSNull null]];
    }];
}

- (void)og_reloadPinnedMessages
{
    [_pinnedFetchDisposable dispose];
    __weak TGGroupModernConversationCompanion *weakOwner = self;
    _pinnedFetchDisposable = [[[self _requestPinnedMessages] deliverOn:[SQueue mainQueue]] startWithNext:^(id payload)
    {
        TGGroupModernConversationCompanion *owner = weakOwner;
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

- (TGPinnedMessageTitlePanel *)og_bannerForPinnedMessage:(TGMessage *)message
{
    if (_pinnedBanner.message.mid != message.mid)
    {
        TGPinnedMessageTitlePanel *banner = [[TGPinnedMessageTitlePanel alloc] initWithMessage:message];
        __weak TGGroupModernConversationCompanion *weakOwner = self;
        __weak TGPinnedMessageTitlePanel *weakBanner = banner;
        banner.tapped = ^
        {
            TGGroupModernConversationCompanion *owner = weakOwner;
            if (owner == nil)
                return;
            if (owner->_pinnedMessageList.count > 1)
                [owner og_showPinnedSheetFromPanel:weakBanner];
            else
                [owner og_jumpToPinnedMessage:owner->_pinnedMessageList.firstObject];
        };
        banner.dismiss = ^
        {
            TGGroupModernConversationCompanion *owner = weakOwner;
            if (owner == nil)
                return;
            owner->_pinnedBannerDismissed = true;
            [owner _updateLiveLocationsPanel];
        };
        _pinnedBanner = banner;
    }
    else
        [_pinnedBanner updateMessage:message];
    [_pinnedBanner setMessageCount:_pinnedMessageList.count];
    return _pinnedBanner;
}

- (void)_updateLiveLocationsPanel
{
    TGDispatchOnMainThread(^
    {
        if (_liveLocations.count == 0)
        {
            TGMessage *leadMessage = _pinnedMessageList.firstObject;
            TGModernConversationTitlePanel *panel = (leadMessage != nil && !_pinnedBannerDismissed) ? [self og_bannerForPinnedMessage:leadMessage] : nil;
            _primaryPanel = panel;
            [_panelVariable set:[SSignal single:panel]];
            return;
        }
        
        TGModernConversationTitlePanel *panel = _primaryPanel;
        
        if (_liveLocations.count > 0)
        {
            TGLiveLocationTitlePanel *locationPanel = nil;
            if (![panel isKindOfClass:[TGLiveLocationTitlePanel class]])
            {
                locationPanel = [[TGLiveLocationTitlePanel alloc] init];
                __weak TGGroupModernConversationCompanion *weakSelf = self;
                __weak TGLiveLocationTitlePanel *weakPanel = locationPanel;
                locationPanel.tapped = ^
                {
                    __strong TGGroupModernConversationCompanion *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                                        
                    TGLiveLocation *liveLocationToOpen = nil;
                    int32_t latestLiveLocationDate = 0;
                    for (TGLiveLocation *liveLocation in strongSelf->_liveLocations)
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
                    
                    [strongSelf.controller openLocationFromMessage:liveLocationToOpen.message previewMode:false zoomToFitAll:strongSelf->_liveLocations.count > 0];
                };
                locationPanel.closed = ^
                {
                    __strong TGGroupModernConversationCompanion *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    [strongSelf.controller endEditing];
                    
                    TGMenuSheetController *sheet = OGGroupMakeSheet();
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
                };
            }
            else
            {
                locationPanel = (TGLiveLocationTitlePanel *)panel;
            }
            [locationPanel setLiveLocations:_liveLocations];
            panel = locationPanel;
        } else {
            panel = nil;
        }
        
        _primaryPanel = panel;
        
        [_panelVariable set:[SSignal single:_primaryPanel]];
    });
}

- (NSString *)stringForMemberCount:(int)memberCount
{
    return [effectiveLocalization() getPluralized:@"Conversation.StatusMembers" count:memberCount];
}

- (NSString *)stringForOnlineCount:(int)onlineCount
{
    return [effectiveLocalization() getPluralized:@"Conversation.StatusOnline" count:onlineCount];
}

- (id)stringForMemberCount:(int)memberCount onlineCount:(int)onlineCount participationStatus:(TGGroupParticipationStatus)participationStatus
{
    if (participationStatus == TGGroupParticipationStatusKicked)
        return TGLocalized(@"Conversation.StatusKickedFromGroup");
    else if (participationStatus == TGGroupParticipationStatusLeft)
        return TGLocalized(@"Conversation.StatusLeftGroup");
    else if (participationStatus == TGGroupParticipationStatusDeactivated)
        return TGLocalized(@"Group.Status");
    else
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
}

- (NSString *)stringForActivity:(NSString *)activity
{
    if ([activity isEqualToString:@"recordingAudio"])
        return TGLocalized(@"Activity.RecordingAudio");
    else if ([activity isEqualToString:@"uploadingAudio"])
        return TGLocalized(@"Activity.RecordingAudio");
    else if ([activity isEqualToString:@"recordingVideoMessage"])
        return TGLocalized(@"Activity.RecordingVideoMessage");
    else if ([activity isEqualToString:@"uploadingVideoMessage"])
        return TGLocalized(@"Activity.UploadingVideoMessage");
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

- (TGGroupParticipationStatus)participationStatusForConversation:(TGConversation *)conversation
{
    if (conversation.kickedFromChat)
        return TGGroupParticipationStatusKicked;
    else if (conversation.leftChat)
        return TGGroupParticipationStatusLeft;
    else if (conversation.isDeactivated)
        return TGGroupParticipationStatusDeactivated;
    
    return TGGroupParticipationStatusMember;
}

- (NSString *)title
{
    return _conversation.chatTitle;
}

- (void)loadInitialState
{
    [super loadInitialState];
    
    [self _setTitle:_conversation.chatTitle];
    [self _setAvatarConversationId:_conversationId title:_conversation.chatTitle icon:nil];
    [self _setAvatarUrl:_conversation.chatPhotoFullSmall];
    
    int onlineCount = 0;
    if (_conversation.chatParticipants != nil)
    {
        onlineCount = [TGDatabaseInstance() loadUsersOnlineCount:_conversation.chatParticipants.chatParticipantUids alwaysOnlineUid:TGTelegraphInstance.clientUserId];
    }
    [self _setStatus:[self stringForMemberCount:_conversation.chatParticipantCount onlineCount:onlineCount participationStatus:[self participationStatusForConversation:_conversation]] accentColored:false allowAnimation:false toggleMode:TGModernConversationControllerTitleToggleNone];
    
    if (_initialUserActivities.count != 0)
        [self _setTypingStatus:[self stringForUserActivities:_initialUserActivities] activity:[self activityTypeForActivities:_initialUserActivities]];
    
    TGModernConversationController *controller = self.controller;
    [controller setHasBots:_hasBots];
    
    [self updatePatricipationStatus:[self participationStatusForConversation:_conversation]];
}

- (void)_controllerWillAppearAnimated:(bool)animated firstTime:(bool)firstTime
{
    [super _controllerWillAppearAnimated:animated firstTime:firstTime];
}

- (void)_controllerDidAppear:(bool)firstTime
{
    [super _controllerDidAppear:firstTime];
    [self og_collectPinnedFromVisibleItems];
    [self og_reloadPinnedMessages];
    
    if (firstTime)
    {
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversationExtended/(%lld)", _conversationId] options:@{
            @"conversationId": @(_conversationId)
        } watcher:TGTelegraphInstance];
    }
}

- (void)_controllerAvatarPressed
{
    TGModernConversationController *controller = self.controller;
    if (controller.currentSizeClass == UIUserInterfaceSizeClassCompact)
    {
        TGGroupInfoController *groupInfoController = [[TGGroupInfoController alloc] initWithConversationId:_conversationId];
        
        [controller.navigationController pushViewController:groupInfoController animated:true];
    }
    else
    {
        if (controller != nil)
        {
            TGGroupInfoController *groupInfoController = [[TGGroupInfoController alloc] initWithConversationId:_conversationId];
            
            TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[groupInfoController] navigationBarClass:[TGWhiteNavigationBar class]];
            navigationController.presentationStyle = TGNavigationControllerPresentationStyleRootInPopover;
            navigationController.detachFromPresentingControllerInCompactMode = true;
            TGPopoverController *popoverController = [[TGPopoverController alloc] initWithContentViewController:navigationController];
            navigationController.parentPopoverController = popoverController;
            [popoverController setContentSize:CGSizeMake(320.0f, 528.0f)];
            
            controller.associatedPopoverController = popoverController;
            [popoverController presentPopoverFromBarButtonItem:controller.navigationItem.rightBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:true];
            groupInfoController.collectionView.contentOffset = CGPointMake(0.0f, -groupInfoController.collectionView.contentInset.top);
        }
    }
}

#pragma mark -

- (void)updatePatricipationStatus:(TGGroupParticipationStatus)participationStatus
{
    if (_hasLeavePanel != (participationStatus != TGGroupParticipationStatusMember))
    {
        _hasLeavePanel = (participationStatus != TGGroupParticipationStatusMember);
        
        ASHandle *actionHandle = self.actionHandle;
        TGDispatchOnMainThread(^
        {
            TGModernConversationController *controller = self.controller;
            if ((participationStatus != TGGroupParticipationStatusMember))
            {
                TGModernConversationActionInputPanel *unblockPanel = [[TGModernConversationActionInputPanel alloc] init];
                [unblockPanel setActionWithTitle:TGLocalized(@"ConversationProfile.LeaveDeleteAndExit") action:@"deleteAndExit"];
                unblockPanel.delegate = controller;
                unblockPanel.companionHandle = actionHandle;
                [controller setDefaultInputPanel:unblockPanel];
            }
            else
                [controller setDefaultInputPanel:nil];
        });
    }
}

- (void)_createOrUpdatePrimaryTitlePanel:(bool)createIfNeeded
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
    if (_isMuted)
        [actions addObject:@{@"title": TGLocalized(@"Conversation.Unmute"), @"icon": presentation.images.chatTitleUnmuteIcon, @"action": @"unmute"}];
    else
        [actions addObject:@{@"title": TGLocalized(@"Conversation.Mute"), @"icon": presentation.images.chatTitleMuteIcon, @"action": @"mute"}];
    [actions addObject:@{@"title": TGLocalized(@"Conversation.Info"), @"icon": presentation.images.chatTitleInfoIcon, @"action": @"info"}];
    [groupTitlePanel setPresentation:presentation];
    [groupTitlePanel setButtonsWithTitlesAndActions:[self _titlePanelActionsWithPluginActions:actions]];
    
    [controller setPrimaryTitlePanel:groupTitlePanel];
}

- (void)_loadControllerPrimaryTitlePanel
{
    [self _createOrUpdatePrimaryTitlePanel:true];
}

- (void)controllerDidUpdateTypingActivity
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
        if (ABS(currentTime - _lastTypingActivity) >= 4.0)
        {
            _lastTypingActivity = currentTime;
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/activity/(typing)", _conversationId] options:nil watcher:self];
        }
    }];
}

- (void)controllerDidCancelTypingActivity
{
}

- (NSDictionary *)userActivityData
{
    return @{@"user_id": @(TGTelegraphInstance.clientUserId), @"peer": @{@"type": @"group", @"id": @(-_conversationId)}};
}

- (TGApplicationFeaturePeerType)applicationFeaturePeerType
{
    if ([TGApplicationFeatures isGroupLarge:(NSUInteger)_conversation.chatParticipantCount])
        return TGApplicationFeaturePeerLargeGroup;
    else
        return TGApplicationFeaturePeerGroup;
}

#pragma mark -

- (bool)imageDownloadsShouldAutosavePhotos
{
    return (TGAppDelegateInstance.autoSavePhotosMode & TGAutoDownloadModeCellularGroups) != 0;
}

- (bool)shouldAutomaticallyDownloadPhotos
{
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadPhotoInChat:TGAutoDownloadChatGroup networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadAnimations
{
    TGAutoDownloadChat chat = TGAutoDownloadChatGroup;
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadGifInChat:chat networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadAudios
{
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadVoiceMessageInChat:TGAutoDownloadChatGroup networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadVideoMessages
{
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadVideoMessageInChat:TGAutoDownloadChatGroup networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadVideos
{
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadVideoInChat:TGAutoDownloadChatGroup networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadDocuments
{
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadDocumentInChat:TGAutoDownloadChatGroup networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (NSString *)_sendMessagePathForMessageId:(int32_t)mid
{
    return [[NSString alloc] initWithFormat:@"/tg/sendCommonMessage/(%@)/(%d)", [self _conversationIdPathComponent], mid];
}

- (NSString *)_sendMessagePathPrefix
{
    return [[NSString alloc] initWithFormat:@"/tg/sendCommonMessage/(%@)/", [self _conversationIdPathComponent]];
}

- (NSDictionary *)_optionsForMessageActions
{
    return @{@"conversationId": @(_conversationId)};
}

- (void)subscribeToUpdates
{
    [ActionStageInstance() watchForPaths:@[
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/typing", _conversationId],
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/conversation", _conversationId],
        [[NSString alloc] initWithFormat:@"/tg/peerSettings/(%" PRId64 ")", TGPeerIdNotificationDefaultsGroup],
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/pinnedMessagesChanged", _conversationId]
    ] watcher:self];
    
    [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/peerSettings/(%" PRId64 ")", _conversationId] watcher:self];
    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%" PRId64 ",cachedOnly)", _conversationId] options:@{@"peerId": @(_conversationId)} watcher:self];
    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%lld,cachedOnly)", TGPeerIdNotificationDefaultsGroup] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:TGPeerIdNotificationDefaultsGroup] forKey:@"peerId"] watcher:self];
    
    [super subscribeToUpdates];
}

#pragma mark -

- (void)requestGroupMute:(bool)mute
{
    NSNumber *muteUntil = mute ? @(INT32_MAX) : @0;
    _groupNotificationSettings[@"muteUntil"] = muteUntil;
    
    [self _updateNotifcationSettings];
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        static int actionId = 0;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%" PRId64 ")/(conversationController%d)", _conversation.conversationId, actionId++] options:@{@"peerId": @(_conversationId), @"muteUntil": muteUntil} watcher:TGTelegraphInstance];
    }];
}

- (void)_updateGroupMute:(bool)isMuted
{
    TGDispatchOnMainThread(^
    {
        if (_isMuted != isMuted)
        {
            _isMuted = isMuted;
            [self _createOrUpdatePrimaryTitlePanel:false];
            
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
        }
    });
}

#pragma mark -

- (void)actionStageActionRequested:(NSString *)action options:(id)options
{
    if ([action isEqualToString:@"titlePanelAction"])
    {
        NSString *panelAction = options[@"action"];
        
        if ([panelAction isEqualToString:@"mute"]) {
            [self requestGroupMute:true];
        }
        else if ([panelAction isEqualToString:@"unmute"]) {
            [self requestGroupMute:false];
        }
        else if ([panelAction isEqualToString:@"edit"]) {
            [self.controller enterEditingMode];
        }
        else if ([panelAction isEqualToString:@"info"]) {
            [self _controllerAvatarPressed];
        }
        else if ([panelAction isEqualToString:@"search"]) {
            [self navigateToMessageSearch];
        }
    }
    else if ([action isEqualToString:@"actionPanelAction"])
    {
        NSString *panelAction = options[@"action"];
        
        if ([panelAction isEqualToString:@"deleteAndExit"])
        {
            TGModernConversationController *controller = self.controller;
            
            UINavigationController *navigationController = controller.navigationController;
            NSUInteger index = [navigationController.viewControllers indexOfObject:controller];
            if (index != NSNotFound)
            {
                [TGAppDelegateInstance.rootController.dialogListController.dialogListCompanion deleteItem:[[TGConversation alloc] initWithConversationId:_conversationId unreadCount:0 serviceUnreadCount:0] animated:false];
                [self _dismissController];
            }
        }
    }
    else if ([action isEqualToString:@"openLinkRequested"])
    {
        if ([options[@"url"] hasPrefix:@"mention://"])
        {
            NSString *domain = [options[@"url"] substringFromIndex:@"mention://".length];
            
            for (NSNumber *nUid in _conversation.chatParticipants.chatParticipantUids)
            {
                TGUser *user = [TGDatabaseInstance() loadUser:[nUid longLongValue]];
                if (TGStringCompare(domain, user.userName))
                {
                    [[TGInterfaceManager instance] navigateToProfileOfUser:user.uid shareVCard:nil];
                    return;
                }
            }
        }
    }
    
    [super actionStageActionRequested:action options:options];
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)arguments
{
    if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/pinnedMessagesChanged", _conversationId]])
    {
        TGDispatchOnMainThread(^{
            [self og_reloadPinnedMessages];
        });
    }

    if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/messages", _conversationId]])
    {
        NSArray *messages = ((SGraphObjectNode *)resource).object;
        [self og_foldPinnedMessages:[self og_latestPinnedFromMessages:messages]];
    }
    
    if ([path isEqualToString:@"/tg/userdatachanges"] || [path isEqualToString:@"/tg/userpresencechanges"])
    {
        NSArray *users = ((SGraphObjectNode *)resource).object;
        
        bool needsUpdate = false;
        for (NSNumber *nUid in _conversation.chatParticipants.chatParticipantUids)
        {
            int64_t uid = [nUid longLongValue];
            for (TGUser *user in users)
            {
                if (user.uid == uid)
                {
                    needsUpdate = true;
                    break;
                }
            }
            
            if (needsUpdate)
                break;
        }
        
        if (needsUpdate)
        {
            int onlineCount = [TGDatabaseInstance() loadUsersOnlineCount:_conversation.chatParticipants.chatParticipantUids alwaysOnlineUid:TGTelegraphInstance.clientUserId];
            NSString *statusString = [self stringForMemberCount:_conversation.chatParticipantCount onlineCount:onlineCount participationStatus:[self participationStatusForConversation:_conversation]];
            [self _setStatus:statusString accentColored:false allowAnimation:false toggleMode:TGModernConversationControllerTitleToggleNone];
        }
    }
    else if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/typing", _conversationId]])
    {
        NSDictionary *userActivities = ((SGraphObjectNode *)resource).object;
        if (userActivities.count != 0)
            [self _setTypingStatus:[self stringForUserActivities:userActivities] activity:[self activityTypeForActivities:userActivities]];
        else
            [self _setTypingStatus:nil activity:0];
    }
    else if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/conversation", _conversationId]])
    {
        TGConversation *updatedConversation = ((SGraphObjectNode *)resource).object;
        
        if (!_conversation.isDeactivated && updatedConversation.isDeactivated && updatedConversation.migratedToChannelId != 0) {
            [ActionStageInstance() removeWatcher:self];
            
            TGDispatchOnMainThread(^{
                TGModernConversationController *controller = self.controller;
                if (controller.navigationController.topViewController == controller) {
                    __block TGProgressWindow *progressWindow = nil;
                    progressWindow = [[TGProgressWindow alloc] init];
                    [progressWindow show:true];
                    
                    __weak TGGroupModernConversationCompanion *weakSelf = self;
                    [[[[[[TGDatabaseInstance() existingChannel:TGPeerIdFromChannelId(updatedConversation.migratedToChannelId)] take:1] timeout:5.0 onQueue:[SQueue concurrentDefaultQueue] orSignal:[SSignal fail:nil]] deliverOn:[SQueue mainQueue]] onDispose:^{
                        TGDispatchOnMainThread(^{
                            [progressWindow dismiss:true];
                        });
                    }] startWithNext:^(TGConversation *next) {
                        TGDispatchOnMainThread(^{
                            [[TGInterfaceManager instance] navigateToConversationWithId:next.conversationId conversation:nil];
                        });
                    } error:^(__unused id error) {
                        __strong TGGroupModernConversationCompanion *strongSelf = weakSelf;
                        if (strongSelf != nil) {
                            TGModernConversationController *controller = strongSelf.controller;
                            [controller.navigationController popToRootViewControllerAnimated:true];
                        }
                    } completed:nil];
                }
            });
            
            return;
        }
        
        _conversation = updatedConversation;
        _hasBots = [self conversationHasBots:_conversation hasSingleBot:&_hasSingleBot];
        self.viewContext.commandsEnabled = _hasBots;
        bool hasBots = _hasBots;
        
        TGDispatchOnMainThread(^
        {
            TGModernConversationController *controller = self.controller;
            [controller setHasBots:hasBots];
        });
        
        [self _setTitle:_conversation.chatTitle];
        [self _setAvatarConversationId:_conversationId title:_conversation.chatTitle icon:nil];
        [self _setAvatarUrl:_conversation.chatPhotoFullSmall];
        int onlineCount = 0;
        if (_conversation.chatParticipants != nil)
        {
            onlineCount = [TGDatabaseInstance() loadUsersOnlineCount:_conversation.chatParticipants.chatParticipantUids alwaysOnlineUid:TGTelegraphInstance.clientUserId];
        }
        NSString *statusString = [self stringForMemberCount:_conversation.chatParticipantCount onlineCount:onlineCount participationStatus:[self participationStatusForConversation:_conversation]];
        [self _setStatus:statusString accentColored:false allowAnimation:false toggleMode:TGModernConversationControllerTitleToggleNone];
        
        [self updatePatricipationStatus:[self participationStatusForConversation:_conversation]];
    }
    else if ([path hasPrefix:@"/tg/peerSettings/"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    
    [super actionStageResourceDispatched:path resource:resource arguments:arguments];
}

- (bool)conversationHasBots:(TGConversation *)conversation hasSingleBot:(bool *)hasSingleBot
{
    bool hasBots = false;
    int count = 0;
    for (NSNumber *nUid in conversation.chatParticipants.chatParticipantUids)
    {
        TGUser *user = [TGDatabaseInstance() loadUser:[nUid longLongValue]];
        if (user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot)
        {
            count++;
            hasBots = true;
        }
    }
    if (hasSingleBot)
       *hasSingleBot = count == 1;
    return hasBots;
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:[NSString stringWithFormat:@"/tg/peerSettings/(%" PRId64 "", TGPeerIdNotificationDefaultsGroup]])
    {
        TGDispatchOnMainThread(^
        {
            _defaultNotificationSettings = [((SGraphObjectNode *)result).object mutableCopy];
            [self _updateNotifcationSettings];
        });
    }
    else if ([path hasPrefix:@"/tg/peerSettings/"])
    {
        TGDispatchOnMainThread(^
        {
            _groupNotificationSettings = [((SGraphObjectNode *)result).object mutableCopy];
            [self _updateNotifcationSettings];
        });
    }
    
    [super actorCompleted:status path:path result:result];
}

- (void)_updateNotifcationSettings
{
    NSNumber *muteUntil = _groupNotificationSettings[@"muteUntil"];
    if (muteUntil == nil)
        muteUntil = _defaultNotificationSettings[@"muteUntil"];
    
    bool isMuted = true;
    if (muteUntil.intValue <= OGRemoteClockTime())
        isMuted = false;
    
    [self _updateGroupMute:isMuted];
}

- (bool)allowReplies
{
    return true;
}

- (bool)allowPollSending
{
    return true;
}

- (SSignal *)userListForMention:(NSString *)mention canBeContextBot:(bool)canBeContextBot includeSelf:(bool)includeSelf
{
    NSArray *memberUserIds = [_conversation.chatParticipants.chatParticipantUids copy];
    NSArray *recentUserIds = [self recentMentionUserIds];
    SSignal *contextBots = canBeContextBot ? [TGRecentContextBotsSignal recentBots] : [SSignal single:@[]];
    return [[contextBots mapToSignal:^SSignal *(NSArray *contextBotIds) {
        return [TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id {
            return [TGModernConversationCompanion mentionUsersForQuery:mention memberUserIds:memberUserIds recentUserIds:recentUserIds contextBotIds:contextBotIds includeSelf:includeSelf];
        }];
    }] deliverOn:[SQueue mainQueue]];
}

- (SSignal *)commandListForCommand:(NSString *)command
{
    if (_hasBots)
    {
        NSString *normalizedCommand = [command lowercaseString];
        if ([normalizedCommand hasPrefix:@"/"])
            normalizedCommand = [normalizedCommand substringFromIndex:1];
        
        NSMutableArray *botUsers = [[NSMutableArray alloc] init];
        NSMutableArray *botInfoSignals = [[NSMutableArray alloc] init];
        NSMutableArray *initialStates = [[NSMutableArray alloc] init];
        for (NSNumber *nUid in _conversation.chatParticipants.chatParticipantUids)
        {
            TGUser *user = [TGDatabaseInstance() loadUser:[nUid longLongValue]];
            if (user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot)
            {
                [botUsers addObject:user];
                [botInfoSignals addObject:[[TGBotSignals botInfoForUserId:user.uid] map:^id(TGBotInfo *botInfo)
                {
                    NSMutableArray *commands = [[NSMutableArray alloc] init];
                    for (TGBotComandInfo *commandInfo in botInfo.commandList)
                    {
                        if (normalizedCommand.length == 0 || [[commandInfo.command lowercaseString] hasPrefix:normalizedCommand])
                            [commands addObject:commandInfo];
                    }
                    return commands;
                }]];
                [initialStates addObject:@[]];
            }
        }
        
        return [[SSignal combineSignals:botInfoSignals withInitialStates:initialStates] map:^id(NSArray *commandLists)
        {
            NSMutableArray *commands = [[NSMutableArray alloc] init];
            NSUInteger index = 0;
            for (NSArray *commandList in commandLists)
            {
                [commands addObject:@[botUsers[index], commandList]];
                index++;
            }
            
            return commands;
        }];
    }
    
    return nil;
}

- (bool)isASingleBotGroup
{
    return false;
}

- (TGModernGalleryController *)galleryControllerForAvatar
{
    if (_conversation.chatPhotoFullSmall.length == 0)
        return nil;
    
    TGModernGalleryController *modernGallery = [[TGModernGalleryController alloc] initWithContext:[TGLegacyComponentsContext shared]];
    modernGallery.model = [[TGGroupAvatarGalleryModel alloc] initWithPeerId:_conversationId accessHash:0 messageId:0 legacyThumbnailUrl:_conversation.chatPhotoFullSmall legacyUrl:_conversation.chatPhotoFullBig imageSize:CGSizeMake(640.0f, 640.0f)];
    
    return modernGallery;
}

- (bool)isPeerAdmin {
    return _conversation.isAdmin || _conversation.isCreator;
}

- (bool)messageSearchByUserAvailable {
    return true;
}

@end
