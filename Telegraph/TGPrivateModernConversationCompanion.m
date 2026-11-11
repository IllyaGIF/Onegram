#import "TGPrivateModernConversationCompanion.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGLegacyComponentsContext.h"

#import "TGDatabase.h"
#import "TGDialogListCompanion.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"

#import "TGAppDelegate.h"
#import "TGTelegraph.h"

#import "TGInterfaceManager.h"
#import "TGTelegraphUserInfoController.h"

#import "TGModernConversationController.h"
#import "TGModernConversationActionInputPanel.h"
#import "TGModernConversationPrivateTitlePanel.h"
#import "TGModernConversationContactLinkTitlePanel.h"
#import "TGLiveLocationTitlePanel.h"
#import "TGPinnedMessageTitlePanel.h"

#import "TGModernConversationTitleIcon.h"

#import "TGModernConversationTitleView.h"
#import "TGRichMessageInlineImageStore.h"
#import "TGPresentationAssets.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGBotUserInfoController.h"

#import "TGBotSignals.h"
#import "TGPeerInfoSignals.h"

#import "TGBotConversationHeaderView.h"

#import "TGModernViewContext.h"

#import "TGServiceSignals.h"

#import "TGMessageModernConversationItem.h"

#import "TGCustomActionSheet.h"
#import "TGCustomAlertView.h"

#import "TGRecentContextBotsSignal.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryController.h"
#import "TGUserAvatarGalleryModel.h"

#import "TGTelegramNetworking.h"

#import "TGGroupManagementSignals.h"

#import "TGCloudStorageConversationEmptyView.h"

#import "TGUserSignal.h"
#import "TGAccountSignals.h"
#import "TGLiveLocationSignals.h"

#import "TGLiveLocationManager.h"

#import "TGPresentation.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLocationViewController.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGMenuSheetController.h"

#import "TLRPCmessages_search.h"
#import "TGMessage+Telegraph.h"
#import "TGUserDataRequestBuilder.h"
#import "../OnegramRuntime/OGRemoteClock.h"
#import "TGPaidMessagesSignals.h"
#import "TGPaidMessagesFeeTitlePanel.h"

static const int32_t OGPrivatePinnedFilterSignature = 0x1bb00451;
static const int32_t OGPrivatePinnedFilterNoName = -1;

@interface OGPrivatePinnedSearchFilter : TLMessagesFilter
@end

@implementation OGPrivatePinnedSearchFilter

- (int32_t)TLconstructorSignature
{
    return OGPrivatePinnedFilterSignature;
}

- (int32_t)TLconstructorName
{
    return OGPrivatePinnedFilterNoName;
}

- (void)TLserialize:(NSOutputStream *)__unused os
{
}

@end

static TGMessage *OGPrivatePinnedTargetOfServiceMessage(TGMessage *serviceMessage)
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

static NSComparisonResult OGPrivatePinnedNewestFirst(TGMessage *left, TGMessage *right)
{
    int32_t leftDate = [left actualDate];
    int32_t rightDate = [right actualDate];
    if (leftDate != rightDate)
        return leftDate > rightDate ? NSOrderedAscending : NSOrderedDescending;
    return left.mid > right.mid ? NSOrderedAscending : NSOrderedDescending;
}

static void OGPrivatePinnedAppendDistinct(NSMutableArray *destination, NSMutableSet *knownIds, NSArray *source)
{
    for (TGMessage *candidate in source)
    {
        if (candidate.mid == 0 || [knownIds containsObject:@(candidate.mid)])
            continue;
        [knownIds addObject:@(candidate.mid)];
        [destination addObject:candidate];
    }
}

static NSString *OGPrivatePinnedMenuLabel(TGMessage *message)
{
    NSString *raw = message.text.length != 0 ? message.text : message.caption;
    NSString *label = [[raw componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
    while ([label rangeOfString:@"  "].location != NSNotFound)
        label = [label stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    label = [label stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return label.length == 0 ? TGLocalized(@"Conversation.PinnedMessage") : label;
}

static NSString *OGPrivatePinnedClassicButtonTitle(NSUInteger slot, NSString *label)
{
    NSString *numbered = [NSString stringWithFormat:@"%d. %@", (int)slot + 1, label];
    if (numbered.length <= 24)
        return numbered;
    NSRange keep = [numbered rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, 23)];
    return [[numbered substringWithRange:keep] stringByAppendingString:@"…"];
}

static NSString *OGPrivatePinnedPageTitle(NSUInteger from, NSUInteger to, bool backward)
{
    NSString *format = backward ? @"‹ %d–%d" : @"%d–%d ›";
    return [NSString stringWithFormat:format, (int)from + 1, (int)to];
}

static TGMenuSheetButtonItemView *OGPrivatePinnedSheetButton(NSString *title, void (^action)(void))
{
    return [[TGMenuSheetButtonItemView alloc] initWithTitle:title type:TGMenuSheetButtonTypeDefault action:action];
}

static NSArray *OGPrivateDecodePinnedResult(TLmessages_Messages *result)
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

static TGMenuSheetController *OGPrivateMakeSheet(void)
{
    TGMenuSheetController *sheet = [[TGMenuSheetController alloc] initWithContext:[TGLegacyComponentsContext shared] dark:false];
    sheet.dismissesByOutsideTap = true;
    sheet.narrowInLandscape = true;
    return sheet;
}

typedef enum {
    TGPhoneSharingStatusUnknown = 0,
    TGPhoneSharingStatusNotShared = 1,
    TGPhoneSharingStatusMyShared = 2
} TGPhoneSharingStatus;

static NSMutableDictionary *dismissedContactLinkPanelsByUserId()
{
    static NSMutableDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        dict = [[NSMutableDictionary alloc] init];
    });
    return dict;
}

@interface TGPrivateModernConversationCompanion () <TGModernConversationContactLinkTitlePanelDelegate>
{
    NSString *_initialActivity;
    SMetaDisposable *_paidMessagesPriceDisposable;
    SMetaDisposable *_paidMessagesFeeDisposable;
    int64_t _paidMessagesFeeStars;
    
    
    bool _isLoadingFirstMessages;
    
    bool _hasUnblockPanel;
    bool _hasOutgoingMessages;
    bool _hasIncomingMessages;
    
    bool _supportsCalls;
    bool _callsPrivate;
    
    bool _isBlocked;
    bool _isContact;
    
    bool _isMuted;
    
    NSMutableDictionary *_defaultNotificationSettings;
    NSMutableDictionary *_userNotificationSettings;
    
    NSArray *_additionalTitleIcons;
    bool _showsPremiumBadge;
    int64_t _emojiStatusDocumentId;
    UIImage *_emojiStatusImage;
    SMetaDisposable *_emojiStatusDisposable;
    
    TGPhoneSharingStatus _phoneSharingStatus;
    
    TGBotConversationHeaderView *_botHeaderView;
    
    bool _isBot;
    id<SDisposable> _botInfoDisposable;
    TGBotInfo *_botInfo;
    
    TGModernConversationActionInputPanel *_unblockPanel;
    TGModernConversationActionInputPanel *_botStartPanel;
    bool _botStartPanelDismissed;
    
    SMetaDisposable *_botStartDisposable;
    
    TGModernConversationTitlePanel *_primaryPanel;
    
    SVariable *_linkPanelVariable;
    
    NSArray *_liveLocations;
    NSArray *_pinnedMessageList;
    TGPinnedMessageTitlePanel *_pinnedBanner;
    bool _pinnedBannerDismissed;
    
    bool _shouldReportSpam;
    id<SDisposable> _shouldReportSpamDisposable;
    id<SDisposable> _liveLocationDisposable;
    id<SDisposable> _pinnedFetchDisposable;
    id<SDisposable> _updatedPeerSettingsDisposable;
    id<SDisposable> _updatedCachedDataDisposable;
    id<SDisposable> _cachedDataDisposable;
}

@end

@implementation TGPrivateModernConversationCompanion

+ (void)reloadForAccountSwitch
{
    [dismissedContactLinkPanelsByUserId() removeAllObjects];
}

- (instancetype)initWithConversation:(TGConversation *)conversation activity:(NSString *)activity mayHaveUnreadMessages:(bool)mayHaveUnreadMessages
{
    return [self initWithConversation:conversation uid:conversation.conversationId activity:activity mayHaveUnreadMessages:mayHaveUnreadMessages];
}

- (instancetype)initWithConversation:(TGConversation *)conversation uid:(int64_t)uid activity:(NSString *)activity mayHaveUnreadMessages:(bool)mayHaveUnreadMessages
{
    _linkPanelVariable = [[SVariable alloc] init];
    self = [super initWithConversation:conversation mayHaveUnreadMessages:mayHaveUnreadMessages];
    if (self != nil)
    {
        _uid = uid;
        _initialActivity = activity;
        _pinnedMessageList = @[];
        [_linkPanelVariable set:[SSignal single:nil]];
        
        __weak TGPrivateModernConversationCompanion *weakSelf = self;
        _shouldReportSpamDisposable = [[[TGDatabaseInstance() shouldReportSpamForPeerId:_conversationId] ignoreRepeated] startWithNext:^(NSNumber *nValue) {
            __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
            if (strongSelf != nil) {
                strongSelf->_shouldReportSpam = [nValue boolValue];
                [strongSelf _updateContactLinkPanel];
            }
        } error:nil completed:nil];
        
        SSignal *combinedSignal = [[SSignal combineSignals:@[[self liveLocationSignal], [TGDatabaseInstance() unpinnedLiveLocationForPeerId:_conversationId]] withInitialStates:@[@[], @0]] map:^id(NSArray *result)
        {
            bool hasOwn = false;
            bool isUnpinned = false;
            int32_t lastUnpinnedMessageId = [[result lastObject] intValue];
            for (TGLiveLocation *liveLocation in result.firstObject)
            {
                if (liveLocation.hasOwnSession)
                    hasOwn = true;
                if (liveLocation.message.mid == lastUnpinnedMessageId)
                    isUnpinned = true;
            }
            
            return hasOwn || !isUnpinned ? result.firstObject : nil;
        }];
        
        if ([self supportsLiveLocations])
        {
            _liveLocationDisposable = [[combinedSignal deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *next)
            {
                __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    strongSelf->_liveLocations = next;
                    [strongSelf _updateContactLinkPanel];
                }
            }];
        }
        
        _updatedPeerSettingsDisposable = [[TGAccountSignals updatedShouldReportSpamForPeer:_conversationId accessHash:_accessHash] startWithNext:nil];
        
        _cachedDataDisposable = [[[TGDatabaseInstance() userCachedData:_uid] deliverOn:[SQueue mainQueue]] startWithNext:^(TGCachedUserData *data) {
            __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
            if (strongSelf != nil) {
                if (strongSelf->_supportsCalls != data.supportsCalls) {
                    strongSelf->_supportsCalls = data.supportsCalls;
                    [strongSelf _createOrUpdatePrimaryTitlePanel:false];
                }
                
                strongSelf->_callsPrivate = data.callsPrivate;
            }
        }];
    }
    return self;
}

- (void)dealloc
{
    [self.actionHandle reset];
    [_botInfoDisposable dispose];
    [_botStartDisposable dispose];
    [_shouldReportSpamDisposable dispose];
    [_updatedPeerSettingsDisposable dispose];
    [_liveLocationDisposable dispose];
    [_pinnedFetchDisposable dispose];
    [_paidMessagesPriceDisposable dispose];
    [_paidMessagesFeeDisposable dispose];
    [_emojiStatusDisposable dispose];
}

- (void)setAdditionalTitleIcons:(NSArray *)additionalTitleIcons
{
    TGDispatchOnMainThread(^
    {
        _additionalTitleIcons = additionalTitleIcons;
        [self _updateTitleIcons];
    });
}

- (bool)shouldDisplayContactLinkPanel
{
    if (_conversationId == [TGTelegraphInstance serviceUserUid] || _conversationId == [TGTelegraphInstance voipSupportUserUid] || _conversationId == TGTelegraphInstance.clientUserId)
        return false;
    return true;
}

- (void)_updateTitleIcons
{
    TGDispatchOnMainThread(^
    {
        NSMutableArray *icons = [[NSMutableArray alloc] initWithArray:_additionalTitleIcons];
        
        UIImage *badgeImage = _emojiStatusDocumentId != 0 ? _emojiStatusImage : (_showsPremiumBadge ? [TGPresentationAssets premiumBadgeIcon:14.0f] : nil);
        if (badgeImage != nil)
        {
            CGFloat muteCenterY = 7.0f + self.controller.presentation.images.chatTitleMutedIcon.size.height / 2.0f;
            TGModernConversationTitleIcon *badgeIcon = [[TGModernConversationTitleIcon alloc] init];
            badgeIcon.bounds = CGRectMake(0.0f, 0.0f, badgeImage.size.width + 4.0f, badgeImage.size.height);
            badgeIcon.offsetWeight = 0.5f;
            badgeIcon.imageOffset = CGPointMake(4.0f, CGFloor(muteCenterY - badgeImage.size.height / 2.0f));
            badgeIcon.image = badgeImage;
            badgeIcon.iconPosition = TGModernConversationTitleIconPositionAfterTitle;
            [icons addObject:badgeIcon];
        }
        
        if (_isMuted)
        {
            TGModernConversationTitleIcon *muteIcon = [[TGModernConversationTitleIcon alloc] init];
            muteIcon.bounds = CGRectMake(0.0f, 0.0f, 16, 16);
            muteIcon.offsetWeight = 0.5f;
            muteIcon.imageOffset = CGPointMake(4.0f, 7.0f);
            
            muteIcon.image = self.controller.presentation.images.chatTitleMutedIcon;
            muteIcon.iconPosition = TGModernConversationTitleIconPositionAfterTitle;
            
            [icons addObject:muteIcon];
        }
        
        [self _setTitleIcons:icons];
    });
}

- (void)_updateUserBadge:(TGUser *)user
{
    if (![NSThread isMainThread])
    {
        TGDispatchOnMainThread(^
        {
            [self _updateUserBadge:user];
        });
        return;
    }
    bool showsPremiumBadge = user.isPremium && !user.isVerified && _uid != TGTelegraphInstance.clientUserId;
    int64_t emojiStatusDocumentId = user.isVerified || _uid == TGTelegraphInstance.clientUserId ? 0 : user.emojiStatusDocumentId;
    if (showsPremiumBadge == _showsPremiumBadge && emojiStatusDocumentId == _emojiStatusDocumentId)
        return;
    _showsPremiumBadge = showsPremiumBadge;
    if (emojiStatusDocumentId != _emojiStatusDocumentId)
    {
        _emojiStatusDocumentId = emojiStatusDocumentId;
        _emojiStatusImage = nil;
        if (_emojiStatusDisposable == nil)
            _emojiStatusDisposable = [[SMetaDisposable alloc] init];
        [_emojiStatusDisposable setDisposable:nil];
        if (emojiStatusDocumentId != 0)
        {
            UIImage *cachedImage = [TGRichMessageInlineImageStore imageForKey:[TGRichMessageInlineImageStore customEmojiKey:emojiStatusDocumentId]];
            if (cachedImage != nil)
                _emojiStatusImage = [self _titleEmojiStatusImage:cachedImage];
            else
            {
                __weak TGPrivateModernConversationCompanion *weakSelf = self;
                [_emojiStatusDisposable setDisposable:[[[TGRichMessageInlineImageStore customEmojiImageSignal:emojiStatusDocumentId] deliverOn:[SQueue mainQueue]] startWithNext:^(UIImage *image)
                {
                    __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
                    if (strongSelf == nil || strongSelf->_emojiStatusDocumentId != emojiStatusDocumentId || ![image isKindOfClass:[UIImage class]])
                        return;
                    strongSelf->_emojiStatusImage = [strongSelf _titleEmojiStatusImage:image];
                    [strongSelf _updateTitleIcons];
                }]];
            }
        }
    }
    [self _updateTitleIcons];
}

- (UIImage *)_titleEmojiStatusImage:(UIImage *)image
{
    CGFloat side = 20.0f;
    CGSize fitted = TGFitSize(image.size, CGSizeMake(side, side));
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), false, 0.0f);
    [image drawInRect:CGRectMake(CGFloor((side - fitted.width) / 2.0f), CGFloor((side - fitted.height) / 2.0f), fitted.width, fitted.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (void)_updateUserMute:(bool)isMuted
{
    TGDispatchOnMainThread(^
    {
        if (_isMuted != isMuted)
        {
            _isMuted = isMuted;
            [self _createOrUpdatePrimaryTitlePanel:false];
            [self _updateTitleIcons];
        }
    });
}

- (void)_updatePhoneSharingStatusFromUserLink:(int)userLink
{
    TGDispatchOnMainThread(^
    {
        TGPhoneSharingStatus phoneSharingStatus = TGPhoneSharingStatusUnknown;
        if (userLink & TGUserLinkKnown)
        {
            if (userLink & (TGUserLinkForeignHasPhone | TGUserLinkForeignMutual | TGUserLinkMyRequested))
                phoneSharingStatus = TGPhoneSharingStatusMyShared;
            else
                phoneSharingStatus = TGPhoneSharingStatusNotShared;
        }
        
        if (phoneSharingStatus != _phoneSharingStatus)
        {
            _phoneSharingStatus = phoneSharingStatus;
            [self _updateContactLinkPanel];
        }
    });
}

- (void)og_presentSheet:(TGMenuSheetController *)sheet anchoredAt:(UIView *)anchor
{
    __weak TGPrivateModernConversationCompanion *weakOwner = self;
    __weak UIView *weakAnchor = anchor;
    sheet.sourceRect = ^CGRect
    {
        TGPrivateModernConversationCompanion *owner = weakOwner;
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
        return OGPrivatePinnedNewestFirst(left, right);
    }];
    
    for (TGMessage *candidate in newestFirst)
    {
        TGMessage *target = OGPrivatePinnedTargetOfServiceMessage(candidate);
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
    [self _updateContactLinkPanel];
}

- (void)og_foldPinnedMessages:(NSArray *)messages
{
    if (messages.count == 0)
        return;
    
    TGDispatchOnMainThread(^
    {
        NSMutableArray *folded = [[NSMutableArray alloc] init];
        NSMutableSet *knownIds = [[NSMutableSet alloc] init];
        OGPrivatePinnedAppendDistinct(folded, knownIds, messages);
        OGPrivatePinnedAppendDistinct(folded, knownIds, _pinnedMessageList);
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
        OGPrivatePinnedAppendDistinct(adopted, knownIds, messages);
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
    
    __weak TGPrivateModernConversationCompanion *weakOwner = self;
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
        NSString *label = OGPrivatePinnedMenuLabel(pinned);
        void (^choose)(void) = ^
        {
            [weakSheet dismissAnimated:true];
            [weakOwner og_jumpToPinnedMessage:pinned];
        };
        
        if (classicSheet)
            [rows addObject:OGPrivatePinnedSheetButton(OGPrivatePinnedClassicButtonTitle(slot, label), choose)];
        else
            [rows addObject:[[TGPinnedMessageMenuItemView alloc] initWithTitle:label index:slot action:choose]];
    }
    
    if (firstShown > 0)
    {
        NSUInteger backStart = firstShown >= perPage ? firstShown - perPage : 0;
        NSUInteger backEnd = MIN(backStart + perPage, total);
        [rows addObject:OGPrivatePinnedSheetButton(OGPrivatePinnedPageTitle(backStart, backEnd, true), ^{ openPage(backStart); })];
    }
    
    if (pastLast < total)
    {
        NSUInteger forwardEnd = MIN(pastLast + perPage, total);
        [rows addObject:OGPrivatePinnedSheetButton(OGPrivatePinnedPageTitle(pastLast, forwardEnd, false), ^{ openPage(pastLast); })];
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
    TGMenuSheetController *sheet = OGPrivateMakeSheet();
    sheet.maxHeight = MIN(420.0f, self.controller.view.bounds.size.height - 44.0f);
    [self og_fillPinnedSheet:sheet fromOffset:0 animated:false];
    [self og_presentSheet:sheet anchoredAt:panel];
}

- (SSignal *)_requestPinnedMessages
{
    TLRPCmessages_search *query = [[TLRPCmessages_search alloc] init];
    query.peer = [TGTelegraphInstance createInputPeerForConversation:_conversationId accessHash:_accessHash];
    query.q = @"";
    query.filter = [[OGPrivatePinnedSearchFilter alloc] init];
    query.min_date = query.max_date = 0;
    query.offset = query.max_id = 0;
    query.limit = 50;
    query.flags = 0;
    
    int64_t peerId = _conversationId;
    return [[[[TGTelegramNetworking instance] requestSignal:query] map:^id(TLmessages_Messages *result)
    {
        return OGPrivateDecodePinnedResult(result);
    }] catch:^SSignal *(id error)
    {
        TGLog(@"TRACE pinned.search.error peer=%lld filter=inputMessagesFilterPinned scope=private error=%@", peerId, error);
        return [SSignal single:[NSNull null]];
    }];
}

- (void)og_reloadPinnedMessages
{
    [_pinnedFetchDisposable dispose];
    __weak TGPrivateModernConversationCompanion *weakOwner = self;
    _pinnedFetchDisposable = [[[self _requestPinnedMessages] deliverOn:[SQueue mainQueue]] startWithNext:^(id payload)
    {
        TGPrivateModernConversationCompanion *owner = weakOwner;
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

- (TGPinnedMessageTitlePanel *)og_bannerForPinnedMessage:(TGMessage *)message reusing:(TGModernConversationTitlePanel *)existing
{
    TGPinnedMessageTitlePanel *banner = nil;
    if ([existing isKindOfClass:[TGPinnedMessageTitlePanel class]] && ((TGPinnedMessageTitlePanel *)existing).message.mid == message.mid)
    {
        banner = (TGPinnedMessageTitlePanel *)existing;
        [banner updateMessage:message];
    }
    else
    {
        banner = [[TGPinnedMessageTitlePanel alloc] initWithMessage:message];
        __weak TGPrivateModernConversationCompanion *weakOwner = self;
        __weak TGPinnedMessageTitlePanel *weakBanner = banner;
        banner.tapped = ^
        {
            TGPrivateModernConversationCompanion *owner = weakOwner;
            if (owner == nil)
                return;
            if (owner->_pinnedMessageList.count > 1)
                [owner og_showPinnedSheetFromPanel:weakBanner];
            else
                [owner og_jumpToPinnedMessage:owner->_pinnedMessageList.firstObject];
        };
        banner.dismiss = ^
        {
            TGPrivateModernConversationCompanion *owner = weakOwner;
            if (owner == nil)
                return;
            owner->_pinnedBannerDismissed = true;
            [owner _updateContactLinkPanel];
        };
    }
    _pinnedBanner = banner;
    [_pinnedBanner setMessageCount:_pinnedMessageList.count];
    return banner;
}

- (void)_updateContactLinkPanel
{
    TGDispatchOnMainThread(^
    {
        if (![self shouldDisplayContactLinkPanel] && _paidMessagesFeeStars <= 0 && _liveLocations.count == 0 && (_pinnedMessageList.count == 0 || _pinnedBannerDismissed))
        {
            [_linkPanelVariable set:[SSignal single:nil]];
            return;
        }
        
        TGModernConversationTitlePanel *panel = _primaryPanel;
        TGUser *user = [TGDatabaseInstance() loadUser:_uid];
        
        if (_paidMessagesFeeStars > 0)
        {
            TGPaidMessagesFeeTitlePanel *feePanel = nil;
            if (![panel isKindOfClass:[TGPaidMessagesFeeTitlePanel class]])
            {
                feePanel = [[TGPaidMessagesFeeTitlePanel alloc] init];
                __weak TGPrivateModernConversationCompanion *weakSelf = self;
                feePanel.removeFeePressed = ^
                {
                    __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
                    if (strongSelf != nil)
                        [strongSelf _removePaidMessagesFeePressed];
                };
                panel = feePanel;
            }
            else
                feePanel = (TGPaidMessagesFeeTitlePanel *)panel;
            [feePanel setUserName:user.displayFirstName stars:_paidMessagesFeeStars];
        }
        else if (_liveLocations.count > 0)
        {
            TGLiveLocationTitlePanel *locationPanel = nil;
            if (![panel isKindOfClass:[TGLiveLocationTitlePanel class]])
            {
                locationPanel = [[TGLiveLocationTitlePanel alloc] init];
                __weak TGPrivateModernConversationCompanion *weakSelf = self;
                __weak TGLiveLocationTitlePanel *weakPanel = locationPanel;
                locationPanel.tapped = ^
                {
                    __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
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
                    __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    [strongSelf.controller endEditing];
                    
                    bool hasOwn = false;
                    TGLiveLocation *liveLocationToUnpin = nil;
                    for (TGLiveLocation *liveLocation in strongSelf->_liveLocations)
                    {
                        if (liveLocation.hasOwnSession)
                        {
                            hasOwn = true;
                            break;
                        }
                        else
                        {
                            liveLocationToUnpin = liveLocation;
                        }
                    }
                    
                    if (hasOwn)
                    {
                        TGMenuSheetController *sheet = OGPrivateMakeSheet();
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
                        [TGDatabaseInstance() storeUnpinnedLiveLocation:liveLocationToUnpin.message.mid forPeerId:[liveLocationToUnpin peerId]];
                    }
                };
            }
            else
            {
                locationPanel = (TGLiveLocationTitlePanel *)panel;
            }
            [locationPanel setLiveLocations:_liveLocations];
            panel = locationPanel;
        }
        else if (_pinnedMessageList.count > 0 && !_pinnedBannerDismissed)
        {
            panel = [self og_bannerForPinnedMessage:_pinnedMessageList.firstObject reusing:panel];
        }
        else if (!_isContact && user.phoneNumber.length != 0)
        {
            NSMutableDictionary *dict = dismissedContactLinkPanelsByUserId()[@(TGTelegraphInstance.clientUserId)];
            if (dict == nil)
            {
                dict = [[NSMutableDictionary alloc] init];
                dismissedContactLinkPanelsByUserId()[@(TGTelegraphInstance.clientUserId)] = dict;
            }
            if (![dict[[[NSString alloc] initWithFormat:@"%" PRId64 "_%@", _uid, @"add"]] boolValue])
            {
                TGModernConversationContactLinkTitlePanel *linkPanel = nil;
                if (![panel isKindOfClass:[TGModernConversationContactLinkTitlePanel class]])
                {
                    linkPanel = [[TGModernConversationContactLinkTitlePanel alloc] init];
                    linkPanel.delegate = self;
                    panel = linkPanel;
                }
                else
                {
                    linkPanel = (TGModernConversationContactLinkTitlePanel *)panel;
                }
                
                [linkPanel setShareContact:false addContact:true reportSpam:_shouldReportSpam && !_isBot];
            }
        }
        else if (_shouldReportSpam) {
            NSMutableDictionary *dict = dismissedContactLinkPanelsByUserId()[@(TGTelegraphInstance.clientUserId)];
            if (dict == nil)
            {
                dict = [[NSMutableDictionary alloc] init];
                dismissedContactLinkPanelsByUserId()[@(TGTelegraphInstance.clientUserId)] = dict;
            }
            if (![dict[[[NSString alloc] initWithFormat:@"%" PRId64 "_%@", _uid, @"add"]] boolValue])
            {
                TGModernConversationContactLinkTitlePanel *linkPanel = nil;
                if (![panel isKindOfClass:[TGModernConversationContactLinkTitlePanel class]])
                {
                    linkPanel = [[TGModernConversationContactLinkTitlePanel alloc] init];
                    linkPanel.delegate = self;
                    panel = linkPanel;
                }
                else
                {
                    linkPanel = (TGModernConversationContactLinkTitlePanel *)panel;
                }
                
                [linkPanel setShareContact:false addContact:false reportSpam:_shouldReportSpam];
            }
        } else {
            panel = nil;
        }
        
        _primaryPanel = panel;
        
        [_linkPanelVariable set:[SSignal single:_primaryPanel]];
    });
}

- (void)contactLinkTitlePanelShareContactPressed:(TGModernConversationContactLinkTitlePanel *)panel
{
    [self contactLinkTitlePanelDismissed:panel];
    
    [self shareVCard];
}

- (void)contactLinkTitlePanelAddContactPressed:(TGModernConversationContactLinkTitlePanel *)__unused panel
{
    TGUser *contact = [TGDatabaseInstance() loadUser:_uid];
    TGDispatchOnMainThread(^
    {
        if (contact != nil)
        {
            TGModernConversationController *controller = self.controller;
            [controller showAddContactMenu:contact];
        }
    });
}

- (void)contactLinkTitlePanelBlockContactPressed:(TGModernConversationContactLinkTitlePanel *)__unused panel {
    TGModernConversationController *controller = self.controller;
    
    int64_t conversationId = _conversationId;
    TGCustomActionSheet *actionSheet = [[TGCustomActionSheet alloc] initWithTitle:TGLocalized(@"Conversation.ReportSpamConfirmation") actions:@[[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Conversation.ReportSpam") action:@"reportSpam" type:TGActionSheetActionTypeDestructive],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]
    ] actionBlock:^(TGModernConversationController *controller, NSString *action) {
        if ([action isEqualToString:@"reportSpam"]) {
            TGUser *user = [TGDatabaseInstance() loadUser:conversationId];
            SMetaDisposable *metaDisposable = [[SMetaDisposable alloc] init];
            id<SDisposable> disposable = [[[TGServiceSignals reportSpam:conversationId accessHash:user.phoneNumberHash] onDispose:^{
                [TGTelegraphInstance.disposeOnLogout remove:metaDisposable];
            }] startWithNext:nil];
            [metaDisposable setDisposable:disposable];
            [TGTelegraphInstance.disposeOnLogout add:metaDisposable];
            
            [TGAppDelegateInstance.rootController.dialogListController.dialogListCompanion deleteItem:[[TGConversation alloc] initWithConversationId:_conversationId unreadCount:0 serviceUnreadCount:0] animated:false];
            
            [controller.navigationController popToRootViewControllerAnimated:true];
        }
    } target:controller];
    
    if (TGAppDelegateInstance.rootController.currentSizeClass == UIUserInterfaceSizeClassRegular) {
        [actionSheet showFromRect:[controller.view convertRect:panel.bounds fromView:panel] inView:controller.view animated:true];
    } else {
        [actionSheet showInView:controller.view];
    }
}

- (void)contactLinkTitlePanelDismissed:(TGModernConversationContactLinkTitlePanel *)panel
{
    TGDispatchOnMainThread(^
    {
        NSMutableDictionary *dict = dismissedContactLinkPanelsByUserId()[@(TGTelegraphInstance.clientUserId)];
        if (dict == nil)
        {
            dict = [[NSMutableDictionary alloc] init];
            dismissedContactLinkPanelsByUserId()[@(TGTelegraphInstance.clientUserId)] = dict;
        }
        dict[[[NSString alloc] initWithFormat:@"%" PRId64 "_%@", _uid, panel.shareContact ? @"share" : @"add"]] = @(true);
        
        TGModernConversationController *controller = self.controller;
        [controller setSecondaryTitlePanel:nil];
        
        if (_shouldReportSpam) {
            _shouldReportSpam = false;
            [TGDatabaseInstance() hideReportSpamForPeerId:_conversationId];
        }
    });
}

#pragma mark -

- (void)_controllerWillAppearAnimated:(bool)animated firstTime:(bool)firstTime
{
    [super _controllerWillAppearAnimated:animated firstTime:firstTime];
    
    if (firstTime)
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/blockedUsers/(%" PRId64 ",cached)", _uid] options:@{@"uid": @(_uid)} watcher:self];
            [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/completeUsers/(%" PRId64 ",cached)", _uid] options:@{@"uid": @(_uid)} watcher:TGTelegraphInstance];
        }];
        
        [TGDatabaseInstance() dispatchOnDatabaseThread:^
        {
            bool outdated = false;
            int userLink = [TGDatabaseInstance() loadUserLink:_uid outdated:&outdated];
            [self _updatePhoneSharingStatusFromUserLink:userLink];
        } synchronous:false];
    }
}

#pragma mark -

- (void)_controllerAvatarPressed
{
    __weak TGPrivateModernConversationCompanion *weakSelf = self;
    void (^shareVCard)() = ^
    {
        __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            [strongSelf shareVCard];
            TGProgressWindow *progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            [progressWindow show:false];
            [progressWindow dismissWithSuccess];
        }
    };
    
    TGModernConversationController *controller = self.controller;
    
    if (controller.currentSizeClass == UIUserInterfaceSizeClassCompact)
    {
        TGUser *user = [TGDatabaseInstance() loadUser:_uid];
        
        TGCollectionMenuController *userInfoController = nil;
        
        if (user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot)
        {
            __weak TGPrivateModernConversationCompanion *weakSelf = self;
            userInfoController = [[TGBotUserInfoController alloc] initWithUid:_uid sendCommand:^(NSString *command)
            {
                __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    [strongSelf controllerWantsToSendTextMessage:command entities:nil asReplyToMessageId:0 withAttachedMessages:nil completeGroups:nil disableLinkPreviews:false botContextResult:nil botReplyMarkup:nil];
                }
            }];
        }
        else
        {
            userInfoController = [[TGTelegraphUserInfoController alloc] initWithUid:_uid];
            ((TGTelegraphUserInfoController *)userInfoController).shareVCard = shareVCard;
        }
        
        [controller.navigationController pushViewController:userInfoController animated:true];
    }
    else
    {
        if (controller != nil)
        {
            TGUser *user = [TGDatabaseInstance() loadUser:_uid];
            
            TGCollectionMenuController *userInfoController = nil;
            
            if (user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot)
            {
                __weak TGPrivateModernConversationCompanion *weakSelf = self;
                userInfoController = [[TGBotUserInfoController alloc] initWithUid:_uid sendCommand:^(NSString *command)
                {
                    __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
                    if (strongSelf != nil)
                    {
                        [strongSelf controllerWantsToSendTextMessage:command entities:nil asReplyToMessageId:0 withAttachedMessages:nil completeGroups:nil disableLinkPreviews:false botContextResult:nil botReplyMarkup:nil];
                    }
                }];
            }
            else
            {
                userInfoController = [[TGTelegraphUserInfoController alloc] initWithUid:_uid withoutCompose:true];
                ((TGTelegraphUserInfoController *)userInfoController).shareVCard = shareVCard;
            }
            
            TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[userInfoController] navigationBarClass:[TGWhiteNavigationBar class]];
            navigationController.presentationStyle = TGNavigationControllerPresentationStyleRootInPopover;
            TGPopoverController *popoverController = [[TGPopoverController alloc] initWithContentViewController:navigationController];
            navigationController.parentPopoverController = popoverController;
            navigationController.detachFromPresentingControllerInCompactMode = true;
            [popoverController setContentSize:CGSizeMake(320.0f, 528.0f)];

            controller.associatedPopoverController = popoverController;
            [popoverController presentPopoverFromBarButtonItem:controller.navigationItem.rightBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:true];
            userInfoController.collectionView.contentOffset = CGPointMake(0.0f, -userInfoController.collectionView.contentInset.top);
        }
    }
}

- (NSString *)stringForTitle:(TGUser *)user
{
    if (user.uid == TGTelegraphInstance.clientUserId) {
        return TGLocalized(@"Conversation.SavedMessages");
    }
    
    if (user.uid == [TGTelegraphInstance serviceUserUid])
        return @"Telegram";
    
    if (user.uid == [TGTelegraphInstance voipSupportUserUid])
        return @"VoIP Support";
    
    return user.displayName;
}

- (NSString *)statusStringForUser:(TGUser *)user accentColored:(bool *)accentColored
{
    if (_conversationId == TGTelegraphInstance.clientUserId) {
        return nil;
    } else {
        if (user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot)
            return TGLocalized(@"Bot.GenericBotStatus");
        
        if (user.uid == [TGTelegraphInstance serviceUserUid])
            return TGLocalized(@"Core.ServiceUserStatus");
        
        if (user.presence.online)
        {
            if (accentColored != NULL)
                *accentColored = true;
            return TGLocalized(@"Presence.online");
        }
        else if (user.presence.lastSeen != 0)
            return [TGDateUtils stringForRelativeLastSeen:user.presence.lastSeen];
        
        return TGLocalized(@"Presence.offline");
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

- (NSString *)title
{
    TGUser *user = [TGDatabaseInstance() loadUser:_uid];
    return [self stringForTitle:user];
}

- (void)loadInitialState
{
    TGUser *user = [TGDatabaseInstance() loadUser:_uid];
    if (user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot)
        _isBot = true;
    if (_isBot) {
        self.viewContext.outgoingMessagesAreAlwaysRead = true;
    }
    _isContact = [TGDatabaseInstance() uidIsRemoteContact:_uid];
    
    self.viewContext.isSavedMessages = _uid == TGTelegraphInstance.clientUserId;
    self.viewContext.commandsEnabled = _isBot;
    self.viewContext.isBot = _isBot;
    
    _isLoadingFirstMessages = true;
    [super loadInitialState];
    _isLoadingFirstMessages = false;
    
    [self _setTitle:[self stringForTitle:user]];
    [self _updateUserBadge:user];
    [self _setAvatarConversationId:_uid firstName:user.firstName lastName:user.lastName];
    [self _setAvatarUrl:user.photoFullUrlSmall];
    bool accentColored = false;
    NSString *statusString = [self statusStringForUser:user accentColored:&accentColored];
    [self _setStatus:statusString accentColored:accentColored allowAnimation:false toggleMode:TGModernConversationControllerTitleToggleNone];
    
    if (_initialActivity != nil)
        [self _setTypingStatus:[self stringForActivity:_initialActivity] activity:[self activityTypeForActivity:_initialActivity]];
    
    if (_isBot)
    {
        __weak TGPrivateModernConversationCompanion *weakSelf = self;
        _botInfoDisposable = [[[TGBotSignals botInfoForUserId:_uid] deliverOn:[SQueue mainQueue]] startWithNext:^(TGBotInfo *botInfo)
        {
            __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_botInfo = botInfo;
                TGModernConversationController *controller = strongSelf.controller;
                if (strongSelf->_botHeaderView == nil)
                    [controller setConversationHeader:[strongSelf _conversationHeader]];
            }
        }];
        
        TGDispatchOnMainThread(^
        {
            TGModernConversationController *controller = self.controller;
            [controller setHasBots:true];
        });
    }
    
    [self _updateContactLinkPanel];
}

- (bool)_supportsPaidMessages
{
    return !_isBot && _uid != TGTelegraphInstance.clientUserId && TGPeerIdIsUser(_conversationId);
}

- (int64_t)paidMessagesPricePeerId
{
    return [self _supportsPaidMessages] ? _uid : 0;
}

- (void)paidMessagesPriceChanged:(int64_t)stars
{
    [self setPaidMessageStars:[self _supportsPaidMessages] ? stars : 0];
}

- (void)_refreshPaidMessagesPrice
{
    if (![self _supportsPaidMessages])
        return;
    if ([TGPaidMessagesSignals hasCachedPriceForPeerId:_uid])
        [self setPaidMessageStars:[TGPaidMessagesSignals cachedPriceForPeerId:_uid]];
    if (_paidMessagesPriceDisposable == nil)
        _paidMessagesPriceDisposable = [[SMetaDisposable alloc] init];
    __weak TGPrivateModernConversationCompanion *weakSelf = self;
    [_paidMessagesPriceDisposable setDisposable:[[TGPaidMessagesSignals priceForUserId:_uid] startWithNext:^(NSNumber *stars)
    {
        __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf paidMessagesPriceChanged:[stars longLongValue]];
    } error:nil completed:nil]];
}

- (void)_refreshPaidMessagesFee
{
    if (![self _supportsPaidMessages])
        return;
    if (_paidMessagesFeeDisposable == nil)
        _paidMessagesFeeDisposable = [[SMetaDisposable alloc] init];
    __weak TGPrivateModernConversationCompanion *weakSelf = self;
    [_paidMessagesFeeDisposable setDisposable:[[[TGPaidMessagesSignals chargedStarsFromUserId:_uid] deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *stars)
    {
        __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf->_paidMessagesFeeStars != [stars longLongValue])
        {
            strongSelf->_paidMessagesFeeStars = [stars longLongValue];
            [strongSelf _updateContactLinkPanel];
        }
    } error:nil completed:nil]];
}

- (void)_removePaidMessagesFeePressed
{
    int64_t uid = _uid;
    TGUser *user = [TGDatabaseInstance() loadUser:uid];
    NSString *userName = user.displayFirstName ?: @"";
    __weak TGPrivateModernConversationCompanion *weakSelf = self;
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.2];
    [_paidMessagesFeeDisposable setDisposable:[[[[TGPaidMessagesSignals revenueFromUserId:uid] catch:^SSignal *(__unused id error)
    {
        return [SSignal single:@0];
    }] deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *revenue)
    {
        [progressWindow dismiss:true];
        __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
        TGModernConversationController *controller = strongSelf.controller;
        if (strongSelf == nil || controller == nil)
            return;
        int64_t earned = [revenue longLongValue];
        NSString *title = [[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.RemoveFeeConfirm"), userName];
        NSMutableArray *actions = [[NSMutableArray alloc] init];
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"PaidMessages.RemoveFee") action:@"remove"]];
        if (earned > 0)
            [actions addObject:[[TGActionSheetAction alloc] initWithTitle:[[NSString alloc] initWithFormat:TGLocalized(@"PaidMessages.RemoveFeeRefund"), [TGPaidMessagesSignals starsString:earned]] action:@"refund"]];
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];
        TGCustomActionSheet *actionSheet = [[TGCustomActionSheet alloc] initWithTitle:title actions:actions actionBlock:^(__unused id target, NSString *action)
        {
            if ([action isEqualToString:@"remove"] || [action isEqualToString:@"refund"])
                [weakSelf _commitRemovePaidMessagesFeeWithRefund:[action isEqualToString:@"refund"]];
        } target:controller];
        [actionSheet showInView:controller.view];
    } error:nil completed:nil]];
}

- (void)_commitRemovePaidMessagesFeeWithRefund:(bool)refund
{
    __weak TGPrivateModernConversationCompanion *weakSelf = self;
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.2];
    [_paidMessagesFeeDisposable setDisposable:[[[TGPaidMessagesSignals setFeeRemoved:true forUserId:_uid refundCharged:refund] deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error)
    {
        [progressWindow dismiss:true];
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"PaidMessages.Settings.SaveFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    } completed:^
    {
        [progressWindow dismissWithSuccess];
        __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_paidMessagesFeeStars = 0;
            [strongSelf _updateContactLinkPanel];
        }
    }]];
}

- (void)_controllerDidAppear:(bool)firstTime {
    [super _controllerDidAppear:firstTime];
    [self og_collectPinnedFromVisibleItems];
    [self og_reloadPinnedMessages];
    
    if (firstTime) {
        [self _refreshPaidMessagesPrice];
        [self _refreshPaidMessagesFee];
        if (_botAutostartPayload != nil) {
            [self requestBotStart];
        }
    }
}

#pragma mark -

- (TGModernConversationEmptyListPlaceholderView *)_conversationEmptyListPlaceholder
{
    if (_isBot) {
        return nil;
    } else {
        if (_conversationId == TGTelegraphInstance.clientUserId) {
            return [[TGCloudStorageConversationEmptyView alloc] initWithFrame:CGRectZero presentation:self.viewContext.presentation];
        } else {
            return [super _conversationEmptyListPlaceholder];
        }
    }
}

- (TGModernConversationInputPanel *)_conversationEmptyListInputPanel
{
    if (_unblockPanel != nil)
        return _unblockPanel;
    
    if (_isBot)
    {
        if (_botStartPanel == nil && !_botStartPanelDismissed)
        {
            TGModernConversationController *controller = self.controller;
            _botStartPanel = [[TGModernConversationActionInputPanel alloc] init];
            [_botStartPanel setActionWithTitle:TGLocalized(@"Bot.Start") action:@"botstart" color:self.controller.presentation.pallete.accentColor];
            _botStartPanel.companionHandle = self.actionHandle;
            _botStartPanel.delegate = controller;
        }
        return _botStartPanel;
    }
    else
        return _unblockPanel;
}

- (TGModernConversationInputPanel *)_conversationGenericInputPanel
{
    if (_unblockPanel != nil)
        return _unblockPanel;
    
    if (_isBot && _botStartPayload != nil && !_botStartPanelDismissed)
    {
        if (_botStartPanel == nil)
        {
            TGModernConversationController *controller = self.controller;
            _botStartPanel = [[TGModernConversationActionInputPanel alloc] init];
            [_botStartPanel setActionWithTitle:TGLocalized(@"Bot.Start") action:@"botstart" color:self.controller.presentation.pallete.accentColor];
            _botStartPanel.companionHandle = self.actionHandle;
            _botStartPanel.delegate = controller;
        }
        return _botStartPanel;
    }
    return nil;
}

- (UIView *)_conversationHeader
{
    if (_botInfo != nil && _botInfo.botDescription.length != 0)
    {
        if (_botHeaderView == nil)
        {
            _botHeaderView = [[TGBotConversationHeaderView alloc] initWithContext:self.viewContext botInfo:_botInfo];
            [_botHeaderView sizeToFit];
        }
        return _botHeaderView;
    }
    return nil;
}

- (bool)imageDownloadsShouldAutosavePhotos
{
    TGAutoDownloadMode mode = _isContact ? TGAutoDownloadModeCellularContacts : TGAutoDownloadModeCellularPrivateChats;
    return (TGAppDelegateInstance.autoSavePhotosMode & mode) != 0;
}

- (bool)shouldAutomaticallyDownloadPhotos
{
    TGAutoDownloadChat chat = _isContact ? TGAutoDownloadChatContact : TGAutoDownloadChatOtherPrivateChat;
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadPhotoInChat:chat networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadAnimations
{
    TGAutoDownloadChat chat = _isContact ? TGAutoDownloadChatContact : TGAutoDownloadChatOtherPrivateChat;
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadGifInChat:chat networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadAudios
{
    TGAutoDownloadChat chat = _isContact ? TGAutoDownloadChatContact : TGAutoDownloadChatOtherPrivateChat;
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadVoiceMessageInChat:chat networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadVideoMessages
{
    TGAutoDownloadChat chat = _isContact ? TGAutoDownloadChatContact : TGAutoDownloadChatOtherPrivateChat;
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadVideoMessageInChat:chat networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadVideos
{
    TGAutoDownloadChat chat = _isContact ? TGAutoDownloadChatContact : TGAutoDownloadChatOtherPrivateChat;
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadVideoInChat:chat networkType:TGTelegraphInstance.networkTypeManager.networkType];
}

- (bool)shouldAutomaticallyDownloadDocuments
{
    TGAutoDownloadChat chat = _isContact ? TGAutoDownloadChatContact : TGAutoDownloadChatOtherPrivateChat;
    return [TGAppDelegateInstance.autoDownloadPreferences shouldDownloadDocumentInChat:chat networkType:TGTelegraphInstance.networkTypeManager.networkType];
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
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%" PRId64 ")/typing", _conversationId],
        [[NSString alloc] initWithFormat:@"/tg/userLink/(%" PRId64 ")", _uid],
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/messageFlagChanges", _conversationId],
        [[NSString alloc] initWithFormat:@"/tg/conversation/messageViewDateChanges"],
        [[NSString alloc] initWithFormat:@"/tg/peerSettings/(%" PRId64 ")", TGPeerIdNotificationDefaultsPrivate],
        @"/tg/blockedUsers",
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/pinnedMessagesChanged", _conversationId]
    ] watcher:self];

    [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/peerSettings/(%" PRId64 ")", _uid] watcher:self];
    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%" PRId64 ",cachedOnly)", _uid] options:@{@"peerId": @(_uid)} watcher:self];
    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%lld,cachedOnly)", TGPeerIdNotificationDefaultsPrivate] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:TGPeerIdNotificationDefaultsPrivate] forKey:@"peerId"] watcher:self];
    
    [super subscribeToUpdates];
}

#pragma mark -

- (void)_createOrUpdatePrimaryTitlePanel:(bool)createIfNeeded
{
    TGModernConversationController *controller = self.controller;
    
    TGModernConversationPrivateTitlePanel *privateTitlePanel = nil;
    if ([[controller primaryTitlePanel] isKindOfClass:[TGModernConversationPrivateTitlePanel class]])
        privateTitlePanel = (TGModernConversationPrivateTitlePanel *)[controller primaryTitlePanel];
    else
    {
        if (createIfNeeded)
        {
            privateTitlePanel = [[TGModernConversationPrivateTitlePanel alloc] init];
            privateTitlePanel.companionHandle = self.actionHandle;
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
    
    [actions addObject:@{@"title": TGLocalized(@"Conversation.Call"), @"icon": presentation.images.chatTitleCallIcon, @"action": @"call"}];
    
    [actions addObject:@{@"title": TGLocalized(@"Conversation.Info"), @"icon": presentation.images.chatTitleInfoIcon, @"action": @"info"}];
    [privateTitlePanel setPresentation:presentation];
    [privateTitlePanel setButtonsWithTitlesAndActions:[self _titlePanelActionsWithPluginActions:actions]];

    [controller setPrimaryTitlePanel:privateTitlePanel];
}

- (void)_loadControllerPrimaryTitlePanel
{
    [self _createOrUpdatePrimaryTitlePanel:true];
}

- (void)_setTypingStatus:(NSString *)typingStatus activity:(int)activity
{
    if (TGTelegraphInstance.clientUserId == [self conversationId])
        return;
    
    [super _setTypingStatus:typingStatus activity:activity];
}

- (void)controllerDidUpdateTypingActivity
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if (_conversationId == TGTelegraphInstance.clientUserId) {
            return;
        }
        
        if ((![TGDatabaseInstance() uidIsRemoteContact:_uid] || [TGDatabaseInstance() loadUser:_uid].presence.online || [TGDatabaseInstance() loadUser:_uid].presence.lastSeen <= 0))
        {
            [[TGTelegraphInstance activityManagerForConversationId:_conversationId accessHash:[self requestAccessHash]] addActivityWithType:@"typing" priority:10 timeout:5.0];
        }
    }];
}

- (void)controllerDidCancelTypingActivity
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [[TGTelegraphInstance activityManagerForConversationId:_conversationId accessHash:[self requestAccessHash]] removeActivityWithType:@"typing"];
    }];
}

- (void)requestUserBlocked:(bool)blocked
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        _hasUnblockPanel = blocked;
        
        static int actionId = 0;
        [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/changePeerBlockedStatus/(cb%d)", actionId++] options:@{@"peerId": @(_uid), @"block": @(blocked)} watcher:TGTelegraphInstance];
        
        if (!blocked && _isBot)
        {
            TGDispatchOnMainThread(^
            {
                [self requestBotStart];
            });
        }
    }];
    
    [self updateUserBlocked:blocked];
}

- (void)requestBotStart
{
    if (_botStartPayload != nil || _botAutostartPayload != nil)
    {
        TGDispatchOnMainThread(^
        {
            [_botStartPanel setActivity:true];
            if (_botStartDisposable == nil)
                _botStartDisposable = [[SMetaDisposable alloc] init];
            __weak TGPrivateModernConversationCompanion *weakSelf = self;
            [_botStartDisposable setDisposable:[[[[TGBotSignals botStartForUserId:_uid payload:_botStartPayload == nil ? _botAutostartPayload : _botStartPayload] deliverOn:[SQueue mainQueue]] onDispose:^
            {
                TGDispatchOnMainThread(^
                {
                    __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
                    if (strongSelf != nil)
                    {
                        [strongSelf->_botStartPanel setActivity:false];
                    }
                });
            }] startWithNext:nil completed:^
            {
                __strong TGPrivateModernConversationCompanion *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    strongSelf->_botStartPanel = nil;
                    strongSelf->_botStartPanelDismissed = true;
                    [strongSelf _updateInputPanel];
                }
            }]];
            
            _botAutostartPayload = nil;
        });
    }
    else
    {
        [self controllerWantsToSendTextMessage:@"/start" entities:nil asReplyToMessageId:0 withAttachedMessages:nil completeGroups:nil disableLinkPreviews:false botContextResult:nil botReplyMarkup:nil];
    }
}

- (void)updateUserBlocked:(bool)blocked
{
    if (_hasUnblockPanel != blocked)
    {
        _hasUnblockPanel = blocked;
        
        ASHandle *actionHandle = self.actionHandle;
        TGDispatchOnMainThread(^
        {
            _isBlocked = blocked;
            [self _createOrUpdatePrimaryTitlePanel:false];
            
            TGModernConversationController *controller = self.controller;
            if (blocked)
            {
                if (_unblockPanel == nil)
                {
                    _unblockPanel = [[TGModernConversationActionInputPanel alloc] init];
                    [_unblockPanel setActionWithTitle:_isBot ? TGLocalized(@"Bot.Unblock") : TGLocalized(@"Conversation.Unblock") action:@"unblock"];
                    _unblockPanel.delegate = controller;
                    _unblockPanel.companionHandle = actionHandle;
                }
            }
            else
                _unblockPanel = nil;
                
            [self _updateInputPanel];
        });
    }
}

- (NSDictionary *)userActivityData
{
    NSMutableDictionary *peerDict = [[NSMutableDictionary alloc] init];
    peerDict[@"type"] = @"user";
    peerDict[@"id"] = @(_conversationId);
    TGUser *user = [TGDatabaseInstance() loadUser:_conversationId];
    if (user.userName.length != 0)
        peerDict[@"username"] = user.userName;
    return @{@"user_id": @(TGTelegraphInstance.clientUserId), @"peer": peerDict};
}

- (TGApplicationFeaturePeerType)applicationFeaturePeerType
{
    return TGApplicationFeaturePeerPrivate;
}

#pragma mark -

- (void)requestUserMute:(bool)mute
{
    NSNumber *muteUntil = mute ? @(INT32_MAX) : @0;
    _userNotificationSettings[@"muteUntil"] = muteUntil;
    
    [self _updateNotifcationSettings];
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        static int actionId = 0;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%" PRId64 ")/(conversationController%d)", _conversationId, actionId++] options:@{@"peerId": @(_conversationId), @"muteUntil": muteUntil} watcher:TGTelegraphInstance];
    }];
}

#pragma mark -

- (void)actionStageActionRequested:(NSString *)action options:(id)options
{
    if ([action isEqualToString:@"actionPanelAction"])
    {
        NSString *panelAction = options[@"action"];
        if ([panelAction isEqualToString:@"unblock"])
            [self requestUserBlocked:false];
        else if ([panelAction isEqualToString:@"botstart"])
            [self requestBotStart];
        
        [TGAppDelegateInstance.rootController.dialogListController maybeDismissSearchResults];
    }
    else if ([action isEqualToString:@"titlePanelAction"])
    {
        NSString *panelAction = options[@"action"];
        
        if ([panelAction isEqualToString:@"block"]) {
            [self requestUserBlocked:true];
        }
        else if ([panelAction isEqualToString:@"unblock"]) {
            [self requestUserBlocked:false];
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
        else if ([panelAction isEqualToString:@"call"]) {
            [self startVoiceCall];
            [self.controller hideTitlePanel];
            
            [TGAppDelegateInstance.rootController.dialogListController maybeDismissSearchResults];
        }
        else if ([panelAction isEqualToString:@"mute"]) {
            [self requestUserMute:true];
        }
        else if ([panelAction isEqualToString:@"unmute"]) {
            [self requestUserMute:false];
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

    if ([path isEqualToString:[NSString stringWithFormat:@"/tg/conversation/(%lld)/messages", _conversationId]])
    {
        NSArray *messages = ((SGraphObjectNode *)resource).object;
        [self og_foldPinnedMessages:[self og_latestPinnedFromMessages:messages]];
    }

    if ([path isEqualToString:@"/tg/userdatachanges"] || [path isEqualToString:@"/tg/userpresencechanges"])
    {
        NSArray *users = ((SGraphObjectNode *)resource).object;
        
        for (TGUser *user in users)
        {
            if (user.uid == _uid)
            {
                bool accentColored = false;
                NSString *statusString = [self statusStringForUser:user accentColored:&accentColored];
                [self _setTitle:[self stringForTitle:user] andStatus:statusString accentColored:accentColored allowAnimatioon:true toggleMode:TGModernConversationControllerTitleToggleNone];
                [self _updateUserBadge:user];
                [self _setAvatarConversationId:_uid firstName:user.firstName lastName:user.lastName];
                [self _setAvatarUrl:user.photoFullUrlSmall];
                
                break;
            }
        }
    }
    else if ([path isEqualToString:@"/as/updateRelativeTimestamps"])
    {
        TGUser *user = [TGDatabaseInstance() loadUser:_uid];
        
        bool accentColored = false;
        NSString *statusString = [self statusStringForUser:user accentColored:&accentColored];
        [self _setTitle:[self stringForTitle:user] andStatus:statusString accentColored:accentColored allowAnimatioon:false toggleMode:TGModernConversationControllerTitleToggleNone];
        [self _setAvatarConversationId:_uid firstName:user.firstName lastName:user.lastName];
        [self _setAvatarUrl:user.photoFullUrlSmall];
    }
    else if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/typing", _conversationId]])
    {
        if (_uid != TGTelegraphInstance.clientUserId)
        {
            NSDictionary *userActivities = ((SGraphObjectNode *)resource).object;
            if (userActivities.count == 0)
                [self _setTypingStatus:nil activity:0];
            else
            {
                NSString *activity = userActivities[userActivities.allKeys.firstObject];
                [self _setTypingStatus:[self stringForActivity:activity] activity:[self activityTypeForActivity:activity]];
            }
        }
    }
    else if ([path hasPrefix:@"/tg/blockedUsers"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if ([path hasPrefix:@"/tg/contactlist"])
    {
        bool isContact = [TGDatabaseInstance() uidIsRemoteContact:_uid];
        TGDispatchOnMainThread(^
        {
            if (_isContact != isContact)
            {
                _isContact = isContact;
                
                [self _createOrUpdatePrimaryTitlePanel:false];
                [self _updateContactLinkPanel];
            }
        });
    }
    else if ([path hasPrefix:@"/tg/peerSettings/"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if ([path hasPrefix:@"/tg/userLink/"])
    {
        int userLink = [(NSNumber *)((SGraphObjectNode *)resource).object intValue];
        TGDispatchOnMainThread(^
        {
            [self _updatePhoneSharingStatusFromUserLink:userLink];
        });
    }
    else if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/messageFlagChanges", _conversationId]])
    {
        TGDispatchOnMainThread(^
        {
            [(NSMutableDictionary *)resource enumerateKeysAndObjectsUsingBlock:^(NSNumber *nMessageId, NSNumber *nFlags, __unused BOOL *stop)
            {
                [self _setMessageFlags:(int32_t)[nMessageId intValue] flags:[nFlags intValue]];
            }];
        });
    }
    else if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/messageViewDateChanges"]])
    {
        TGDispatchOnMainThread(^
        {
            [(NSMutableDictionary *)resource enumerateKeysAndObjectsUsingBlock:^(NSNumber *nMessageId, NSNumber *nViewDate, __unused BOOL *stop)
            {
                [self _setMessageViewDate:(int32_t)[nMessageId intValue] viewDate:[nViewDate doubleValue]];
            }];
        });
    }
    else if ([path isEqualToString:@"/tg/calls/enabled"])
    {
        bool enabled = [((SGraphObjectNode *)resource).object boolValue];
        
        TGDispatchOnMainThread(^
        {
            if (enabled)
                _updatedCachedDataDisposable = [[TGUserSignal updatedUserCachedDataWithUserId:_uid] startWithNext:nil];
            else
                _supportsCalls = false;
            [self _createOrUpdatePrimaryTitlePanel:false];
        });
    }
    
    [super actionStageResourceDispatched:path resource:resource arguments:arguments];
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/blockedUsers"])
    {
        id blockedResult = ((SGraphObjectNode *)result).object;
        
        bool blocked = false;
        
        if ([blockedResult respondsToSelector:@selector(boolValue)])
            blocked = [blockedResult boolValue];
        else if ([blockedResult isKindOfClass:[NSArray class]])
        {
            for (TGUser *user in blockedResult)
            {
                if (user.uid == _uid)
                {
                    blocked = true;
                    break;
                }
            }
        }
        
        [self updateUserBlocked:blocked];
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/peerSettings/(%" PRId64 "", TGPeerIdNotificationDefaultsPrivate]])
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
            _userNotificationSettings = [((SGraphObjectNode *)result).object mutableCopy];
            [self _updateNotifcationSettings];
        });
    }
    
    [super actorCompleted:status path:path result:result];
}

- (void)_updateNotifcationSettings
{
    NSNumber *muteUntil = _userNotificationSettings[@"muteUntil"];
    if (muteUntil == nil)
        muteUntil = _defaultNotificationSettings[@"muteUntil"];
    
    bool isMuted = true;
    if (muteUntil.intValue <= OGRemoteClockTime())
        isMuted = false;
    
    [self _updateUserMute:isMuted];
}

- (bool)allowReplies
{
    return true;
}

- (bool)allowPollSending
{
    return _isBot;
}

- (bool)allowSelfDescructingMedia
{
    TGUser *user = [TGDatabaseInstance() loadUser:_uid];
    if (user.kind != TGUserKindGeneric)
        return false;
    
    return _uid != TGTelegraphInstance.clientUserId;
}

- (bool)isASingleBotGroup
{
    return _isBot;
}

- (SSignal *)commandListForCommand:(NSString *)command
{
    if (_isBot)
    {
        TGUser *user = [TGDatabaseInstance() loadUser:_uid];
        if (user == nil)
            return nil;
        
        NSString *normalizedCommand = [command lowercaseString];
        if ([normalizedCommand hasPrefix:@"/"])
            normalizedCommand = [normalizedCommand substringFromIndex:1];
        return [[TGBotSignals botInfoForUserId:_uid] map:^id(TGBotInfo *botInfo)
        {
            NSMutableArray *commands = [[NSMutableArray alloc] init];
            for (TGBotComandInfo *commandInfo in botInfo.commandList)
            {
                if (normalizedCommand.length == 0 || [[commandInfo.command lowercaseString] hasPrefix:normalizedCommand])
                    [commands addObject:commandInfo];
            }
            if (commands.count == 1 && [[((TGBotComandInfo *)commands[0]).command lowercaseString] isEqualToString:normalizedCommand])
                [commands removeAllObjects];
            return @[@[user, commands]];
        }];
    }
    return nil;
}


- (void)standaloneSendBotStartPayload:(NSString *)payload
{
    _botStartPayload = payload;
    [self requestBotStart];
}

- (void)_itemsUpdated {
    [super _itemsUpdated];
    
    if (!_hasOutgoingMessages || !_hasIncomingMessages) {
        bool foundOutgoing = false;
        bool foundIncoming = false;
        
        for (TGMessageModernConversationItem *item in _items) {
            if (item->_message.outgoing) {
                foundOutgoing = true;
                if (foundIncoming) {
                    break;
                }
            } else if (item->_message.mid < TGMessageLocalMidBaseline) {
                foundIncoming = true;
                if (foundOutgoing) {
                    break;
                }
            }
        }
        
        if (foundIncoming != _hasIncomingMessages || foundOutgoing != _hasOutgoingMessages) {
            TGDispatchOnMainThread(^{
                _hasOutgoingMessages = foundOutgoing;
                _hasIncomingMessages = foundIncoming;
                
                if (!_isLoadingFirstMessages) {
                    [self _updateContactLinkPanel];
                }
            });
        }
    }
}

- (SSignal *)userListForMention:(NSString *)mention canBeContextBot:(bool)canBeContextBot includeSelf:(bool)__unused includeSelf {
    return [[canBeContextBot ? [TGRecentContextBotsSignal recentBots] : [SSignal single:@[]] mapToSignal:^SSignal *(NSArray *userIds) {
        return [TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id{
            NSString *normalizedMention = [mention lowercaseString];
            NSMutableArray *users = [[NSMutableArray alloc] init];
            for (NSNumber *nUserId in userIds) {
                TGUser *user = [TGDatabaseInstance() loadUser:[nUserId longLongValue]];
                if (user != nil && (normalizedMention.length == 0 || [[user.userName lowercaseString] hasPrefix:normalizedMention])) {
                    [users addObject:user];
                }
            }
            return users;
        }];
    }] deliverOn:[SQueue mainQueue]];
}

- (void)_addedMessages:(NSArray *)messages {
    [super _addedMessages:messages];
    
    if (self.botContextPeerId != nil) {
        for (TGMessage *message in messages) {
            if (message.mid >= TGMessageLocalMidEditBaseline && message.date == INT32_MAX)
                continue;
            
            TGBotReplyMarkup *replyMarkup = message.replyMarkup;
            if (replyMarkup.isInline) {
                for (TGBotReplyMarkupRow *row in replyMarkup.rows) {
                    for (TGBotReplyMarkupButton *button in row.buttons) {
                        if ([button.action isKindOfClass:[TGBotReplyMarkupButtonActionSwitchInline class]]) {
                            NSString *query = ((TGBotReplyMarkupButtonActionSwitchInline *)button.action).query;
                            TGUser *user = [TGDatabaseInstance() loadUser:_conversationId];
                            if (user.userName.length != 0) {
                                NSNumber *botContextPeerId = self.botContextPeerId;
                                TGDispatchOnMainThread(^{
                                    if (botContextPeerId != nil) {
                                        [[TGInterfaceManager instance] navigateToConversationWithId:[botContextPeerId longLongValue] conversation:nil performActions:@{@"replaceInitialText": [[NSString alloc] initWithFormat:@"@%@ %@", user.userName, query]} atMessage:nil clearStack:true openKeyboard:true canOpenKeyboardWhileInTransition:false animated:true];
                                    }
                                });
                                
                                self.botContextPeerId = nil;
                            }
                        }
                    }
                }
            }
        }
    }
}

- (SSignal *)primaryTitlePanel {
    return _linkPanelVariable.signal;
}

- (TGModernGalleryController *)galleryControllerForAvatar
{
    TGUser *user = [TGDatabaseInstance() loadUser:_uid];
    if (user.photoUrlSmall.length == 0)
        return nil;
    
    TGModernGalleryController *modernGallery = [[TGModernGalleryController alloc] initWithContext:[TGLegacyComponentsContext shared]];
    
    modernGallery.model = [[TGUserAvatarGalleryModel alloc] initWithPeerId:_uid currentAvatarLegacyThumbnailImageUri:user.photoFullUrlSmall currentAvatarLegacyImageUri:user.photoFullUrlBig currentAvatarImageSize:CGSizeMake(640.0f, 640.0f)];
    
    return modernGallery;
}

- (void)startVoiceCall {
    if (_callsPrivate) {
        TGUser *user = [TGDatabaseInstance() loadUser:_uid];
        [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"Call.ConnectionErrorTitle") message:[NSString stringWithFormat:TGLocalized(@"Call.PrivacyErrorMessage"), user.displayFirstName] cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    }
    else {
        [[TGInterfaceManager instance] presentCallOptionsForPeerId:_uid inView:self.controller.view];
    }
}

- (bool)supportsCalls {
    return _supportsCalls;
}

- (int)messageLifetime
{
    return 0;
}

- (TGMessageModernConversationItem *)_updateMediaStatusData:(TGMessageModernConversationItem *)item
{
    if (item->_message.mediaAttachments.count != 0)
    {
        bool canBeRead = false;
        for (TGMediaAttachment *attachment in item->_message.mediaAttachments)
        {
            switch (attachment.type)
            {
                case TGImageMediaAttachmentType:
                case TGVideoMediaAttachmentType:
                    if (attachment.type == TGVideoMediaAttachmentType && ((TGVideoMediaAttachment *)attachment).roundMessage)
                        canBeRead = true;
                    else
                        canBeRead = item->_message.messageLifetime > 0 && item->_message.messageLifetime <= 60;
                    break;
                case TGAudioMediaAttachmentType:
                    canBeRead = true;
                    break;
                case TGDocumentMediaAttachmentType:
                    for (id attribute in ((TGDocumentMediaAttachment *)attachment).attributes) {
                        if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]]) {
                            canBeRead = ((TGDocumentAttributeAudio *)attribute).isVoice;
                            break;
                        }
                    }
                    break;
                default:
                    break;
            }
        }
        if (canBeRead) {
            int flags = [TGDatabaseInstance() secretMessageFlags:item->_message.mid];
            NSTimeInterval viewDate = [TGDatabaseInstance() messageCountdownLocalTime:item->_message.mid enqueueIfNotQueued:false initiatedCountdown:NULL];
            
            if (flags != 0 || ABS(viewDate - DBL_EPSILON) > 0.0)
                [self _setMessageFlagsAndViewDate:item->_message.mid flags:flags viewDate:viewDate];
        }
    }
    
    return [super _updateMediaStatusData:item];
}

- (void)markMessagesAsViewed:(NSArray *)messageIds
{
    [TGDatabaseInstance() dispatchOnDatabaseThread:^
     {
         NSMutableArray *readMessageIds = [[NSMutableArray alloc] init];
         
         for (NSNumber *nMessageId in messageIds)
         {
             TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:[nMessageId intValue] peerId:_conversationId];
             if (!message.outgoing && message.messageLifetime > 0 && message.messageLifetime <= 60 && message.layer >= 17)
             {
                 bool initiatedCountdown = false;
                 [TGDatabaseInstance() messageCountdownLocalTime:[nMessageId intValue] enqueueIfNotQueued:true initiatedCountdown:&initiatedCountdown];
                 if (initiatedCountdown)
                     [readMessageIds addObject:nMessageId];
             }
         }
         
         if (readMessageIds.count != 0)
         {
             [ActionStageInstance() requestActor:@"/tg/service/synchronizeserviceactions/(settings)" options:nil watcher:TGTelegraphInstance];
         }
     } synchronous:false];
}

- (bool)supportsLiveLocations
{
    return true;
}

- (void)performBotAutostart:(NSString *)param {
    _botAutostartPayload = param;
    if (_botAutostartPayload != nil) {
        [self requestBotStart];
    }
}

- (bool)canReportMessage:(TGMessage *)message {
    if (!_isBot) {
        return false;
    }
    
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

@end
