#import "../OnegramPlatform/OGPlatformMedia.h"
#import "TGModernConversationCompanion.h"
#import "../OnegramRuntime/OGRuntime.h"
#import "../OnegramRuntime/OGStartupDiagnostics.h"

#include <mach/mach.h>
#include <pthread.h>
#import <objc/runtime.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGBotContextResultAttachment.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGViaUserAttachment.h"

#import "TGModernConversationController.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "TGDatabase.h"
#import "TGTelegramNetworking.h"
#import "TGAppDelegate.h"
#import "TGInterfaceManager.h"

#import "TGMessageModernConversationItem.h"
#import "TGMessageViewModel.h"

#import "TGModernConversationViewContext.h"
#import "TGModernTemporaryView.h"

#import "TGModernViewStorage.h"
#import "TGModernImageView.h"
#import "TGModernImageViewModel.h"
#import "TGModernViewContext.h"
#import "TGModernConversationViewLayout.h"
#import "TGModernDateHeaderView.h"
#import "TGModernUnreadHeaderView.h"

#import "TGModernConversationGenericEmptyListView.h"

#import "TGIndexSet.h"

#import "TGApplication.h"
#import "TGWallpaperManager.h"

#import "TGTelegraph.h"

#import "TGDownloadMessagesSignal.h"

#import "TGUpdateStateRequestBuilder.h"

#import "TGInstagramMediaIdSignal.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGGenericPeerPlaylistSignals.h"

#import "TGGenericModernConversationCompanion.h"

#import "TGChannelManagementSignals.h"
#import "TGAccountSignals.h"

#import <libkern/OSAtomic.h>

#import "TGCustomAlertView.h"
#import "TGCustomActionSheet.h"
#import "TGOpenInMenu.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGMenuSheetController.h"
#import "TGAdminLogConversationCompanion.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGAlphacode.h"
#import "TGEmojiSuggestions.h"

#import "TGLegacyComponentsContext.h"
#import "TGMessageViewedContentProperty.h"

#import "TGLiveLocationSignals.h"

#import "TGReportPeerOtherTextController.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"

@interface TGModernConversationController (IOS6ReactionTap)
- (void)_ios6SendReaction:(NSString *)reaction messageId:(int32_t)messageId;
@end

@interface TGGenericModernConversationCompanion (IOS6MediaAvailabilityRefresh)
- (TGMessageModernConversationItem *)_updateMediaStatusData:(TGMessageModernConversationItem *)item;
@end

@interface TGModernConversationCompanionReference : NSObject
@property (nonatomic, weak) TGModernConversationCompanion *value;
@end

@implementation TGModernConversationCompanionReference
@end

@interface TGModernConversationCompanionControllerReference : NSObject
@property (nonatomic, weak) TGModernConversationController *value;
@end

@implementation TGModernConversationCompanionControllerReference
@end

static TGModernConversationController *TGIOS4ResolveModernConversationController(TGModernConversationCompanionControllerReference *reference)
{
    if (reference == nil)
        return nil;
    @synchronized (reference)
    {
        TGModernConversationController *controller = reference.value;
        return controller;
    }
}

static TGModernConversationCompanion *TGIOS4ResolveModernConversationCompanion(TGModernConversationCompanionReference *reference)
{
    if (reference == nil)
        return nil;
    @synchronized (reference)
    {
        return reference.value;
    }
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
#define NEEDS_DISPATCH_RETAIN_RELEASE 0
#else
#define NEEDS_DISPATCH_RETAIN_RELEASE 1
#endif

static OSSpinLock _messagesViewedLock = 0;
static NSMutableDictionary *messagesViewedByPeerId() {
    static NSMutableDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = [[NSMutableDictionary alloc] init];
    });
    return dict;
}

static void markMessagesAsSeen(int64_t peerId, NSArray *messageIds) {
    OSSpinLockLock(&_messagesViewedLock);
    NSMutableSet *set = messagesViewedByPeerId()[@(peerId)];
    if (set == nil) {
        set = [[NSMutableSet alloc] init];
    }
    [set addObjectsFromArray:messageIds];
    OSSpinLockUnlock(&_messagesViewedLock);
}

static SQueue *_messageQueue = nil;

#if defined(ONEGRAM_DIAGNOSTICS)
static double TGModernConversationCompanionThreadTime(void)
{
    thread_basic_info_data_t basicInfo;
    mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
    if (thread_info(pthread_mach_thread_np(pthread_self()), THREAD_BASIC_INFO, (thread_info_t)&basicInfo, &count) != KERN_SUCCESS)
        return 0.0;
    return (double)basicInfo.user_time.seconds + (double)basicInfo.user_time.microseconds / 1000000.0 + (double)basicInfo.system_time.seconds + (double)basicInfo.system_time.microseconds / 1000000.0;
}
#endif

static SQueue *messageQueue()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        _messageQueue = [[SQueue alloc] init];
    });
    
    return _messageQueue;
}

static bool isMessageQueue()
{
    return [messageQueue() isCurrentQueue];
}

static bool TGIsInternalTelegramLink(NSString *urlString)
{
    if (![urlString isKindOfClass:[NSString class]] || urlString.length == 0)
        return false;

    NSURL *url = [NSURL URLWithString:urlString];
    if (url.scheme.length == 0)
        url = [NSURL URLWithString:[@"https://" stringByAppendingString:urlString]];

    NSString *host = [url.host lowercaseString];
    return [host isEqualToString:@"t.me"] || [host isEqualToString:@"telegram.me"];
}

static void dispatchOnMessageQueue(dispatch_block_t block, bool synchronous)
{
    if (synchronous)
        [messageQueue() dispatchSync:block];
    else
        [messageQueue() dispatch:block];
}

@interface TGModernConversationCompanion ()
{
    bool _hasStarted;
    
    TGModernViewStorage *_tempViewStorage;
    void *_tempMemory;
    NSIndexSet *_tempVisibleItemsIndices;
    
    CGFloat _controllerWidthForItemCalculation;
#if defined(ONEGRAM_ARMV6)
    bool _initialItemsPreparationPending;
    uint64_t _initialItemsPreparationGeneration;
    volatile int32_t _controllerBindingGeneration;
#endif
#if defined(ONEGRAM_DIAGNOSTICS)
    double _diagnosticLayoutThreadTime;
#endif
    
    volatile bool _historyAboveReadAheadAllowed;
    
    dispatch_semaphore_t _sendMessageSemaphore;
    
    int32_t _initialPositionedMessageId;
    int64_t _initialPositionedPeerId;
    TGInitialScrollPosition _initialScrollPosition;
    CGFloat _initialScrollOffset;
    
    TGMessageRange _unreadMessageRange;
    
    NSMutableDictionary *_checkedMessages;
    
    std::map<int32_t, int> _messageFlags;
    std::map<int32_t, NSTimeInterval> _messageViewDate;
    
    TGMessageModernConversationItem * (*_updateMediaStatusDataImpl)(id, SEL, TGMessageModernConversationItem *);
    
    bool _controllerShowingEmptyState;
    
    NSMutableDictionary *_downloadingMessages;
    NSMutableDictionary *_downloadingWebpages;
    NSMutableDictionary *_downloadedMessages;
    bool _allowMessageDownloads;
    
    bool _askedForSecretPages;
    
    std::set<int32_t> _messageViewsRequested;
    std::set<int32_t> _visibleMessageIdsForDownloads;
    NSMutableDictionary *_pendingAutomaticDownloads;
    NSMutableArray *_messageViewsRequestedBuffer;
    STimer *_messageViewsRequestedBufferTimer;
    
    SSignalQueue *_mediaUploadQueue;
    TGModernConversationCompanionReference *_ios4LifetimeReference;
    TGModernConversationCompanionControllerReference *_ios4ControllerReference;
}

@end

static NSMutableSet *TGUnsupportedMessageRequestKeys(void)
{
    static NSMutableSet *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        keys = [[NSMutableSet alloc] init];
    });
    return keys;
}

static NSString *TGUnsupportedMessageRequestKey(int64_t peerId, int32_t messageId)
{
    return [[NSString alloc] initWithFormat:@"%d:%lld:%d", TGTelegraphInstance.clientUserId, peerId, messageId];
}

static bool TGUnsupportedMessageRequestBegin(int64_t peerId, int32_t messageId)
{
    NSMutableSet *keys = TGUnsupportedMessageRequestKeys();
    NSString *key = TGUnsupportedMessageRequestKey(peerId, messageId);
    @synchronized (keys)
    {
        if ([keys containsObject:key])
            return false;
        [keys addObject:key];
        return true;
    }
}

static void TGUnsupportedMessageRequestFailed(int64_t peerId, int32_t messageId)
{
    NSMutableSet *keys = TGUnsupportedMessageRequestKeys();
    @synchronized (keys)
    {
        [keys removeObject:TGUnsupportedMessageRequestKey(peerId, messageId)];
    }
}

@implementation TGModernConversationCompanion

+ (void)reloadForAccountSwitch
{
    OSSpinLockLock(&_messagesViewedLock);
    [messagesViewedByPeerId() removeAllObjects];
    OSSpinLockUnlock(&_messagesViewedLock);

    NSMutableSet *keys = TGUnsupportedMessageRequestKeys();
    @synchronized (keys)
    {
        [keys removeAllObjects];
    }
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _ios4LifetimeReference = [[TGModernConversationCompanionReference alloc] init];
        _ios4LifetimeReference.value = self;
        _ios4ControllerReference = [[TGModernConversationCompanionControllerReference alloc] init];
        _useInitialSnapshot = true;
        _actionHandle = [[ASHandle alloc] initWithDelegate:self];
        
        _items = [[NSMutableArray alloc] init];
        _tempViewStorage = [[TGModernViewStorage alloc] init];
        _checkedMessages = [[NSMutableDictionary alloc] init];
        
        TGModernConversationViewContext *viewContext = [[TGModernConversationViewContext alloc] init];
        viewContext.companion = self;
        viewContext.companionHandle = _actionHandle;
        viewContext.viewStatusEnabled = true;
        viewContext.autoplayAnimations = TGAppDelegateInstance.autoPlayAnimations && !OGPlatformMediaDownloadsRequireUserAction();
        viewContext.playingAudioMessageStatus = [[[TGTelegraphInstance musicPlayer] playingStatus] deliverOn:[SQueue mainQueue]];
        
        _callbackInProgress = [[SVariable alloc] init];
        [_callbackInProgress set:[SSignal single:nil]];
        viewContext.callbackInProgress = [SSignal never];
        
        TGModernConversationCompanionReference *weakViewContext = _ios4LifetimeReference;
        TGModernConversationCompanionReference *weakSelf = _ios4LifetimeReference;
        viewContext.playAudioMessageId = ^(int32_t mid)
        {
            TGModernConversationCompanion *viewContextCompanion = TGIOS4ResolveModernConversationCompanion(weakViewContext);
            TGModernViewContext *strongViewContext = viewContextCompanion.viewContext;
            if (strongViewContext != nil) {
                TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
                if (strongSelf == nil)
                    return;
                
                TGMessage *message = nil;
                bool messageFromVisibleItems = false;
                
                for (TGMessageModernConversationItem *item in [strongSelf.controller _currentItems]) {
                    if (item->_message.mid == mid && item->_message.cid == strongViewContext.conversation.conversationId) {
                        message = item->_message;
                        messageFromVisibleItems = true;
                        break;
                    }
                }
                
                if (message == nil)
                    message = [TGDatabaseInstance() loadMessageWithMid:mid peerId:strongViewContext.conversation.conversationId];
                
                if ([strongSelf isKindOfClass:[TGAdminLogConversationCompanion class]]) {
                    for (TGMessageModernConversationItem *item in [strongSelf.controller _currentItems]) {
                        if (item->_message.mid == mid) {
                            message = item->_message;
                            messageFromVisibleItems = true;
                            break;
                        }
                    }
                }
                
                TGModernConversationController *controller = strongSelf.controller;
                if ([controller maybeShowDiscardRecordingAlert])
                    return;
                
                if (message == nil && mid >= migratedMessageIdOffset) {
                    if (strongSelf != nil && ((TGGenericModernConversationCompanion *)strongSelf)->_attachedConversationId != 0) {
                        message = [TGDatabaseInstance() loadMessageWithMid:mid - migratedMessageIdOffset peerId:((TGGenericModernConversationCompanion *)strongSelf)->_attachedConversationId];
                    }
                }
                if (message != nil)
                {
                    bool isVoice = false;
                    bool foundDocumentAudio = false;
                    bool foundRoundVideo = false;
                    bool hasInlineBotAttribution = false;
                    for (id attachment in message.mediaAttachments) {
                        if ([attachment isKindOfClass:[TGViaUserAttachment class]] || [attachment isKindOfClass:[TGBotContextResultAttachment class]]) {
                            hasInlineBotAttribution = true;
                            break;
                        }
                    }
                    for (id attachment in message.mediaAttachments) {
                        if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]]) {
                            for (id attribute in ((TGDocumentMediaAttachment *)attachment).attributes) {
                                if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]]) {
                                    isVoice = ((TGDocumentAttributeAudio *)attribute).isVoice;
                                    foundDocumentAudio = true;
                                    break;
                                }
                            }
                            if (foundDocumentAudio)
                                break;
                        }
                    }
                    if (!foundDocumentAudio) {
                        for (id attachment in message.mediaAttachments) {
                            if ([attachment isKindOfClass:[TGAudioMediaAttachment class]]) {
                                isVoice = true;
                                break;
                            } else if ([attachment isKindOfClass:[TGVideoMediaAttachment class]]) {
                            if (((TGVideoMediaAttachment *)attachment).roundMessage) {
                                isVoice = true;
                                foundRoundVideo = true;
                            }
                            } else if ([attachment isKindOfClass:[TGWebPageMediaAttachment class]]) {
                                TGWebPageMediaAttachment *webPage = (TGWebPageMediaAttachment *)attachment;
                                if (webPage.document.isRoundVideo)
                                    isVoice = true;
                            }
                        }
                    }
                    bool playAsSingleInlineGif = foundRoundVideo && hasInlineBotAttribution;
                    if (playAsSingleInlineGif || [strongSelf isKindOfClass:[TGAdminLogConversationCompanion class]]) {
                        TGUser *author = [TGDatabaseInstance() loadUser:(int32_t)message.fromUid];
                        TGMusicPlayerItem *item = [TGMusicPlayerItem itemWithMessage:message author:author];
                        [TGTelegraphInstance.musicPlayer setPlaylist:[TGGenericPeerPlaylistSignals playlistForItem:item voice:isVoice] initialItemKey:item.key metadata:[strongSelf playlistMetadata:isVoice]];
                    } else {
                        [TGTelegraphInstance.musicPlayer setPlaylist:[TGGenericPeerPlaylistSignals playlistForPeerId:message.cid important:TGMessageSortKeySpace(message.sortKey) == TGMessageSpaceImportant atMessageId:message.mid voice:isVoice] initialItemKey:@(message.mid) metadata:[strongSelf playlistMetadata:isVoice]];
                    }
                }
            }
        };
        viewContext.pauseAudioMessage = ^
        {
            [[TGTelegraphInstance musicPlayer] controlPause];
        };
        viewContext.resumeAudioMessage = ^
        {
            TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
            if (strongSelf == nil)
                return;
            
            TGModernConversationController *controller = strongSelf.controller;
            if ([controller maybeShowDiscardRecordingAlert])
                return;
            
            [[TGTelegraphInstance musicPlayer] controlPlay];
        };
        viewContext.replySwipeInteraction = ^void (int32_t mid, bool ended) {
            TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
            if (strongSelf == nil)
                return;
            
            [strongSelf.controller _updateItemForReplySwipeInteraction:mid ended:ended];
        };
        viewContext.replySwipeGrouped = ^void (int32_t mid, int64_t groupedId, CGFloat offset, bool ended)
        {
            TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
            if (strongSelf == nil)
                return;
            
            [strongSelf.controller _updateGroupedItemsForReplySwipeInteraction:mid groupedId:groupedId offset:offset ended:ended];
        };
        viewContext.canReplyToMessageId = ^bool(int32_t mid) {
            TGModernConversationCompanion *viewContextCompanion = TGIOS4ResolveModernConversationCompanion(weakViewContext);
            TGModernViewContext *strongViewContext = viewContextCompanion.viewContext;
            if (strongViewContext != nil)
            {
                TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:mid peerId:strongViewContext.conversation.conversationId];
                TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
                if (strongSelf == nil)
                    return false;
                
                TGActionMediaAttachment *actionInfo = message.actionInfo;
                bool canReply = true;
                if (![strongSelf allowMessageForwarding]) {
                    canReply = actionInfo == nil;
                }
                
                if (actionInfo != nil && actionInfo.actionType != TGMessageActionPhoneCall)
                    return false;
                
                if (canReply && [strongSelf allowReplies] && message.cid == [strongSelf requestPeerId] && (message.mid < TGMessageLocalMidBaseline || ![strongSelf allowMessageForwarding])) {
                    return true;
                }
                
                return false;
            }
            return false;
        };
        
        viewContext.liveLocationRemaining = ^SSignal *(int32_t mid)
        {
            TGModernConversationCompanion *viewContextCompanion = TGIOS4ResolveModernConversationCompanion(weakViewContext);
            TGModernViewContext *strongViewContext = viewContextCompanion.viewContext;
            if (strongViewContext != nil)
            {
                TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:mid peerId:strongViewContext.conversation.conversationId];
                return [TGLiveLocationSignals remainingTimeForMessage:message];
            }
            return [SSignal fail:nil];
        };
        
        _viewContext = viewContext;
        _uploadingEditMessages = [[NSMutableDictionary alloc] init];
        _downloadingMessages = [[NSMutableDictionary alloc] init];
        _downloadingWebpages = [[NSMutableDictionary alloc] init];
        _downloadedMessages = [[NSMutableDictionary alloc] init];
        
        _messageViewsRequestedBufferTimer = [[STimer alloc] initWithTimeout:0.5 repeat:false completion:^{
            TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
            if (strongSelf != nil) {
                [strongSelf consumeRequestedMessages];
            }
        } queue:[TGModernConversationCompanion messageQueue]];
        
        _mediaUploadQueue = [[SSignalQueue alloc] init];
    }
    return self;
}

- (TGModernConversationController *)controller
{
    return TGIOS4ResolveModernConversationController(_ios4ControllerReference);
}

- (void)setController:(TGModernConversationController *)controller
{
    @synchronized (_ios4ControllerReference)
    {
        _ios4ControllerReference.value = controller;
    }
}

- (void)dealloc
{
    [_actionHandle reset];
    ((TGModernConversationViewContext *)_viewContext).companion = nil;
    @synchronized (_ios4ControllerReference)
    {
        _ios4ControllerReference.value = nil;
    }
    @synchronized (_ios4LifetimeReference)
    {
        _ios4LifetimeReference.value = nil;
    }
    [ActionStageInstance() removeWatcher:self];
    
#if NEEDS_DISPATCH_RETAIN_RELEASE
    if (_sendMessageSemaphore != nil)
        dispatch_release(_sendMessageSemaphore);
#endif
    _sendMessageSemaphore = nil;
    
    if (_tempMemory != NULL)
    {
        free(_tempMemory);
        _tempMemory = nil;
    }
    
    NSDictionary *downloadingMessages = _downloadingMessages;
    NSDictionary *downloadingWebpages = _downloadingWebpages;
    STimer *messageViewsRequestedBufferTimer = _messageViewsRequestedBufferTimer;
    [TGModernConversationCompanion dispatchOnMessageQueue:^
    {
        [messageViewsRequestedBufferTimer invalidate];
        
        [downloadingMessages enumerateKeysAndObjectsUsingBlock:^(__unused id key, id<SDisposable> disposable, __unused BOOL *stop)
        {
            [disposable dispose];
        }];
        
        [downloadingWebpages enumerateKeysAndObjectsUsingBlock:^(__unused id key, id<SDisposable> disposable, __unused BOOL *stop)
        {
            [disposable dispose];
        }];
    }];
}

+ (void)warmupResources
{
}

+ (bool)isMessageQueue
{
    return isMessageQueue();
}

+ (SQueue *)messageQueue
{
    return messageQueue();
}

+ (void)dispatchOnMessageQueue:(dispatch_block_t)block
{
    dispatchOnMessageQueue(block, false);
}

- (void)lockSendMessageSemaphore
{
    return;
}

- (void)unlockSendMessageSemaphore
{
    if (_sendMessageSemaphore != nil)
        dispatch_semaphore_signal(_sendMessageSemaphore);
}

- (void)setInitialMessagePositioning:(int32_t)initialPositionedMessageId initialPositionedPeerId:(int64_t)initialPositionedPeerId position:(TGInitialScrollPosition)position offset:(CGFloat)offset
{
    _initialPositionedMessageId = initialPositionedMessageId;
    _initialPositionedPeerId = initialPositionedPeerId;
    _initialScrollPosition = position;
    _initialScrollOffset = offset;
}

- (int32_t)initialPositioningMessageId
{
    return _initialPositionedMessageId;
}

- (int64_t)initialPositioningPeerId
{
    return _initialPositionedPeerId;
}

- (TGInitialScrollPosition)initialPositioningScrollPosition
{
    return _initialScrollPosition;
}

- (CGFloat)initialPositioningScrollOffset {
    return _initialScrollOffset;
}

- (void)setUnreadMessageRange:(TGMessageRange)unreadMessageRange
{
    _unreadMessageRange = unreadMessageRange;
}

- (TGMessageRange)unreadMessageRange
{
    return _unreadMessageRange;
}

- (CGFloat)initialPositioningOverflowForScrollPosition:(TGInitialScrollPosition)scrollPosition
{
    if (scrollPosition == TGInitialScrollPositionTop)
        return 28.0f;
    
    return 1.0f;
}

- (void)bindController:(TGModernConversationController *)controller
{
#if defined(ONEGRAM_DIAGNOSTICS)
    NSTimeInterval bindStart = OGStartupDiagnosticsTime();
    OGPlatformDiagnosticLog(@"CHAT_BIND_BEGIN kind=%@ since_main_ms=%.0f", NSStringFromClass([self class]), bindStart * 1000.0);
#endif
#if defined(ONEGRAM_ARMV6)
    OSAtomicIncrement32Barrier(&_controllerBindingGeneration);
    _initialItemsPreparationPending = false;
#endif
    self.controller = controller;
    
    _viewContext.presentation = self.controller.presentation;
#if defined(ONEGRAM_ARMV6)
    _controllerWidthForItemCalculation = [controller referenceViewSizeForOrientation:controller.interfaceOrientation].width;
#endif
    
    [self loadInitialState];
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [self subscribeToUpdates];
    }];
#if defined(ONEGRAM_DIAGNOSTICS)
    OGPlatformDiagnosticLog(@"CHAT_BIND_END kind=%@ duration_ms=%.0f since_main_ms=%.0f", NSStringFromClass([self class]), (OGStartupDiagnosticsTime() - bindStart) * 1000.0, OGStartupDiagnosticsTime() * 1000.0);
#endif
}

#if defined(ONEGRAM_ARMV6)
- (bool)initialItemsPreparationPending
{
    return _initialItemsPreparationPending;
}
#endif

- (void)_ensureReferenceMethod
{
}

- (void)unbindController
{
#if defined(ONEGRAM_ARMV6)
    OSAtomicIncrement32Barrier(&_controllerBindingGeneration);
    _initialItemsPreparationPending = false;
#endif
    [_actionHandle reset];
    @synchronized (_ios4LifetimeReference)
    {
        _ios4LifetimeReference.value = nil;
    }
    self.controller = nil;
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [self _ensureReferenceMethod];
    }];
    
    [TGModernConversationCompanion dispatchOnMessageQueue:^
    {
        [self _ensureReferenceMethod];
    }];
}

- (void)loadInitialState
{
    TGModernConversationController *controller = self.controller;
    [controller setConversationHeader:[self _conversationHeader]];
    [self _updateInputPanel];
}

- (void)subscribeToUpdates
{
    [ActionStageInstance() watchForPath:@"/webpages" watcher:self];
}

- (void)_controllerWillAppearAnimated:(bool)animated firstTime:(bool)firstTime
{
    if (firstTime)
    {
        if (false && self.useInitialSnapshot && animated && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            [self _createInitialSnapshot];
        } else {
#if defined(ONEGRAM_ARMV6)
            if (!_initialItemsPreparationPending)
#endif
            for (TGMessageModernConversationItem *item in [_items copy])
            {
                [self _updateImportantMediaStatusDataInplace:item];
            }
            
            TGModernConversationController *controller = self.controller;
            [controller setInitialSnapshot:NULL backgroundView:nil viewStorage:_tempViewStorage topEdge:0.0f displayScrollDownButton:false];
        }
        
        [TGModernConversationCompanion dispatchOnMessageQueue:^
        {
            [self _updateMediaStatusDataForItemsInIndexSet:_tempVisibleItemsIndices animated:false forceforceCheckDownload:false];
        }];
    }
}

- (void)_controllerDidAppear:(bool)firstTime
{
    TGModernConversationController *controller = self.controller;
    if (firstTime)
    {
#if TARGET_IPHONE_SIMULATOR
#endif
        
        [_tempViewStorage allowResurrectionForOperations:^
        {
            [controller setInitialSnapshot:NULL backgroundView:nil viewStorage:_tempViewStorage topEdge:0.0f displayScrollDownButton:false];
        }];
        
        if (_tempMemory != NULL)
        {
            free(_tempMemory);
            _tempMemory = nil;
        }
        
        _tempViewStorage = nil;
        
        [TGModernConversationCompanion dispatchOnMessageQueue:^
        {
            [self _updateMediaStatusDataForCurrentItems];
            
            _allowMessageDownloads = true;
            [self _itemsUpdated];
        }];
    }
}

- (void)_controllerAvatarPressed
{
}

- (void)_dismissController
{
    [[TGInterfaceManager instance] dismissConversation];
}

- (void)_setControllerWidthForItemCalculation:(CGFloat)width
{
    _controllerWidthForItemCalculation = width;
}

- (void)_loadControllerPrimaryTitlePanel
{
}

- (TGModernConversationEmptyListPlaceholderView *)_conversationEmptyListPlaceholder
{
    TGModernConversationGenericEmptyListView *placeholder = [[TGModernConversationGenericEmptyListView alloc] initWithFrame:CGRectZero presentation:_viewContext.presentation];
    
    return placeholder;
}

- (TGModernConversationInputPanel *)_conversationGenericInputPanel
{
    return nil;
}

- (TGModernConversationInputPanel *)_conversationEmptyListInputPanel
{
    return nil;
}

- (void)_updateInputPanel
{
    TGModernConversationController *controller = self.controller;
    if (_controllerShowingEmptyState)
        [controller setDefaultInputPanel:[self _conversationEmptyListInputPanel]];
    else
        [controller setDefaultInputPanel:[self _conversationGenericInputPanel]];
}

- (UIView *)_conversationHeader
{
    return nil;
}

- (UIView *)_controllerInputTextPanelAccessoryView
{
    return nil;
}

- (void)updateControllerInputText:(NSString *)__unused inputText entities:(NSArray *)__unused entities messageEditingContext:(TGMessageEditingContext *)__unused messageEditingContext
{
}

- (void)controllerDidUpdateTypingActivity
{
}

- (void)controllerDidCancelTypingActivity
{
}

- (void)controllerDidChangeInputText:(NSString *)__unused inputText
{
}

- (void)controllerWantsToSendTextMessage:(NSString *)__unused text entities:(NSArray *)__unused entities asReplyToMessageId:(int32_t)__unused replyMessageId withAttachedMessages:(NSArray *)__unused withAttachedMessages completeGroups:(NSSet *)__unused completeGroups disableLinkPreviews:(bool)__unused disableLinkPreviews botContextResult:(TGBotContextResultAttachment *)__unused botContextResult botReplyMarkup:(id)__unused botReplyMarkup
{
}

- (void)controllerWantsToSendMapWithLatitude:(double)__unused latitude longitude:(double)__unused longitude venue:(TGVenueAttachment *)__unused venue period:(int32_t)__unused period asReplyToMessageId:(int32_t)__unused replyMessageId botContextResult:(TGBotContextResultAttachment *)__unused botContextResult botReplyMarkup:(TGBotReplyMarkup *)__unused botReplyMarkup
{
}

- (NSURL *)fileUrlForDocumentMedia:(TGDocumentMediaAttachment *)__unused documentMedia
{
    return nil;
}

- (NSDictionary *)imageDescriptionFromImage:(UIImage *)__unused image stickers:(NSArray *)__unused stickers caption:(NSString *)__unused caption entities:(NSArray *)__unused entities optionalAssetUrl:(NSString *)__unused assetUrl allowRemoteCache:(bool)__unused allowRemoteCache timer:(int32_t)__unused timer
{
    return nil;
}

- (NSDictionary *)imageDescriptionFromBingSearchResult:(TGBingSearchResultItem *)__unused item caption:(NSString *)__unused caption entities:(NSArray *)__unused entities
{
    return nil;
}

- (NSDictionary *)imageDescriptionFromExternalImageSearchResult:(TGExternalImageSearchResult *)__unused item text:(NSString *)__unused text entities:(NSArray *)__unused entities botContextResult:(TGBotContextResultAttachment *)__unused botContextResult {
    return nil;
}

- (NSDictionary *)documentDescriptionFromGiphySearchResult:(TGGiphySearchResultItem *)__unused item caption:(NSString *)__unused caption entities:(NSArray *)__unused entities
{
    return nil;
}

- (NSDictionary *)documentDescriptionFromExternalGifSearchResult:(TGExternalGifSearchResult *)__unused item text:(NSString *)__unused text entities:(NSArray *)__unused entities botContextResult:(TGBotContextResultAttachment *)__unused botContextResult {
    return nil;
}

- (NSDictionary *)documentDescriptionFromBotContextResult:(TGBotContextResult *)__unused result text:(NSString *)__unused text entities:(NSArray *)__unused entities botContextResult:(TGBotContextResultAttachment *)__unused botContextResult {
    return nil;
}

- (NSDictionary *)imageDescriptionFromMediaAsset:(TGMediaAsset *)__unused asset previewImage:(UIImage *)__unused previewImage document:(bool)__unused document fileName:(NSString *)__unused fileName caption:(NSString *)__unused caption entities:(NSArray *)__unused entities allowRemoteCache:(bool)__unused allowRemoteCache
{
    return nil;
}

- (NSDictionary *)videoDescriptionFromMediaAsset:(TGMediaAsset *)__unused asset previewImage:(UIImage *)__unused previewImage dimensions:(CGSize)__unused dimensions duration:(NSTimeInterval)__unused duration adjustments:(TGVideoEditAdjustments *)__unused adjustments document:(bool)__unused document fileName:(NSString *)__unused fileName stickers:(NSArray *)__unused stickers caption:(NSString *)__unused caption entities:(NSArray *)__unused entities timer:(int32_t)__unused timer
{
    return nil;
}

- (NSDictionary *)videoDescriptionFromVideoURL:(NSURL *)__unused videoURL previewImage:(UIImage *)__unused previewImage dimensions:(CGSize)__unused dimensions duration:(NSTimeInterval)__unused duration adjustments:(TGVideoEditAdjustments *)__unused adjustments stickers:(NSArray *)__unused stickers caption:(NSString *)__unused caption entities:(NSArray *)__unused entities roundMessage:(bool)__unused roundMessage liveUploadData:(id)__unused liveUploadData  timer:(int32_t)__unused timer
{
    return nil;
}

- (NSDictionary *)documentDescriptionFromICloudDriveItem:(TGICloudItem *)__unused item
{
    return nil;
}

- (NSDictionary *)documentDescriptionFromDropboxItem:(TGDropboxItem *)__unused item
{
    return nil;
}

- (NSDictionary *)imageDescriptionFromInternalSearchImageResult:(TGWebSearchInternalImageResult *)__unused item caption:(NSString *)__unused caption entities:(NSArray *)__unused entities
{
    return nil;
}

- (NSDictionary *)documentDescriptionFromInternalSearchResult:(TGWebSearchInternalGifResult *)__unused item caption:(NSString *)__unused caption entities:(NSArray *)__unused entities
{
    return nil;
}

- (NSDictionary *)documentDescriptionFromRemoteDocument:(TGDocumentMediaAttachment *)__unused document caption:(NSString *)__unused caption entities:(NSArray *)__unused entities {
    return nil;
}

- (NSDictionary *)documentDescriptionFromFileAtTempUrl:(NSURL *)__unused url fileName:(NSString *)__unused fileName mimeType:(NSString *)__unused mimeType isAnimation:(bool)__unused isAnimation caption:(NSString *)__unused caption entities:(NSArray *)__unused entities
{
    return nil;
}

- (void)controllerWantsToSendImagesWithDescriptions:(NSArray *)__unused imageDescriptions asReplyToMessageId:(int32_t)__unused replyMessageId botReplyMarkup:(TGBotReplyMarkup *)__unused botReplyMarkup
{
}

- (void)controllerWantsToSendLocalVideoWithTempFilePath:(NSString *)__unused tempVideoFilePath fileSize:(int32_t)__unused fileSize previewImage:(UIImage *)__unused previewImage duration:(NSTimeInterval)__unused duration dimensions:(CGSize)__unused dimenstions caption:(NSString *)__unused caption entities:(NSArray *)__unused entities assetUrl:(NSString *)__unused assetUrl liveUploadData:(TGLiveUploadActorData *)__unused liveUploadData asReplyToMessageId:(int32_t)__unused replyMessageId botReplyMarkup:(TGBotReplyMarkup *)__unused botReplyMarkup
{
}

- (TGVideoMediaAttachment *)serverCachedAssetWithId:(NSString *)__unused assetId
{
    return nil;
}

- (void)controllerWantsToSendDocumentWithTempFileUrl:(NSURL *)__unused tempFileUrl fileName:(NSString *)__unused fileName mimeType:(NSString *)__unused mimeType asReplyToMessageId:(int32_t)__unused replyMessageId
{
}

- (void)controllerWantsToSendDocumentsWithDescriptions:(NSArray *)__unused descriptions asReplyToMessageId:(int32_t)__unused replyMessageId
{
}

- (void)controllerWantsToSendRemoteDocument:(TGDocumentMediaAttachment *)__unused document asReplyToMessageId:(int32_t)__unused replyMessageId text:(NSString *)__unused text entities:(NSArray *)__unused entities botContextResult:(TGBotContextResultAttachment *)__unused botContextResult botReplyMarkup:(TGBotReplyMarkup *)__unused botReplyMarkup
{
}

- (void)controllerWantsToSendRemoteImage:(TGImageMediaAttachment *)__unused image text:(NSString *)__unused text entities:(NSArray *)__unused entities asReplyToMessageId:(int32_t)__unused replyMessageId botContextResult:(TGBotContextResultAttachment *)__unused botContextResult botReplyMarkup:(TGBotReplyMarkup *)__unused botReplyMarkup {
}

- (void)controllerWantsToSendCloudDocumentsWithDescriptions:(NSArray *)__unused descriptions asReplyToMessageId:(int32_t)__unused replyMessageId
{
}

- (void)controllerWantsToSendLocalAudioWithDataItem:(TGDataItem *)__unused dataItem duration:(NSTimeInterval)__unused duration liveData:(TGLiveUploadActorData *)__unused liveData waveform:(TGAudioWaveform *)__unused waveform asReplyToMessageId:(int32_t)__unused replyMessageId botReplyMarkup:(TGBotReplyMarkup *)__unused botReplyMarkup
{
}

- (void)controllerWantsToSendRemoteVideoWithMedia:(TGVideoMediaAttachment *)__unused media asReplyToMessageId:(int32_t)__unused replyMessageId text:(NSString *)__unused text entities:(NSArray *)__unused entities botContextResult:(TGBotContextResultAttachment *)__unused botContextResult botReplyMarkup:(TGBotReplyMarkup *)__unused botReplyMarkup
{
}

- (void)controllerWantsToSendContact:(TGUser *)__unused contactUser asReplyToMessageId:(int32_t)__unused replyMessageId botContextResult:(TGBotContextResultAttachment *)__unused botContextResult botReplyMarkup:(TGBotReplyMarkup *)__unused botReplyMarkup
{
}

- (void)controllerWantsToSendGame:(TGGameMediaAttachment *)__unused gameMedia asReplyToMessageId:(int32_t)__unused replyMessageId botContextResult:(TGBotContextResultAttachment *)__unused botContextResult botReplyMarkup:(TGBotReplyMarkup *)__unused botReplyMarkup {
    
}

- (void)controllerWantsToResendMessages:(NSArray *)__unused messageIds
{
}

- (void)controllerWantsToForwardMessages:(NSArray *)__unused messageIndices
{
}

- (void)controllerWantsToCreateContact:(int32_t)__unused uid firstName:(NSString *)__unused firstName lastName:(NSString *)__unused lastName phoneNumber:(NSString *)__unused phoneNumber attachment:(TGContactMediaAttachment *)__unused attachment
{
}

- (void)controllerWantsToAddContactToExisting:(int32_t)__unused uid phoneNumber:(NSString *)__unused phoneNumber attachment:(TGContactMediaAttachment *)__unused attachment
{
}

- (void)controllerWantsToApplyLocalization:(NSString *)__unused filePath
{
}

- (void)controllerClearedConversation
{
}

- (void)systemClearedConversation
{
}

- (void)controllerDeletedMessages:(NSArray *)__unused messageIds forEveryone:(bool)__unused forEveryone completion:(void (^)())__unused completion
{
}

- (void)controllerCanReadHistoryUpdated
{
}

- (void)controllerCanRegroupUnreadIncomingMessages
{
}

- (void)controllerRequestedNavigationToConversationWithUser:(int32_t)__unused uid
{
}

- (bool)controllerShouldStoreCapturedAssets
{
    return true;
}

- (bool)controllerShouldCacheServerAssets
{
    return true;
}

- (bool)controllerShouldLiveUploadVideo
{
    return true;
}

- (bool)imageDownloadsShouldAutosavePhotos
{
    return false;
}

- (bool)shouldAutomaticallyDownloadPhotos
{
    return false;
}

- (bool)shouldAutomaticallyDownloadAnimations
{
    return false;
}

- (bool)shouldAutomaticallyDownloadAudios
{
    return false;
}

- (bool)shouldAutomaticallyDownloadVideoMessages
{
    return false;
}

- (bool)shouldAutomaticallyDownloadVideos
{
    return false;
}

- (bool)shouldAutomaticallyDownloadVideoOfSize:(int32_t)size
{
    return size <= TGAppDelegateInstance.autoDownloadPreferences.maximumVideoSize * 1024 * 1024;
}

- (bool)shouldAutomaticallyDownloadDocuments
{
    return false;
}

- (bool)shouldAutomaticallyDownloadDocumentOfSize:(int32_t)__unused size
{
    return size <= TGAppDelegateInstance.autoDownloadPreferences.maximumDocumentSize * 1024 * 1024;
}

- (bool)allowMessageForwarding
{
    return true;
}

- (bool)allowMessageExternalSharing
{
    return true;
}

- (bool)allowReplies {
    return true;
}

- (bool)allowMessageEntities {
    return true;
}

- (bool)allowCaptionEntities {
    return true;
}

- (bool)allowExternalContent {
    return true;
}

- (bool)allowContactSharing
{
    return true;
}

- (bool)allowVenueSharing
{
    return true;
}

- (bool)allowCaptionedMedia
{
    return true;
}

- (bool)allowCaptionedDocuments
{
    return true;
}

- (bool)allowVideoMessages
{
    return true;
}

- (bool)allowSelfDescructingMedia
{
    return false;
}

- (bool)allowLiveLocations
{
    return iosMajorVersion() >= 8;
}

- (bool)allowMediaGrouping
{
    return true;
}

- (bool)encryptUploads
{
    return false;
}

- (bool)canPostMessages
{
    return true;
}

- (NSDictionary *)userActivityData
{
    return nil;
}

- (TGApplicationFeaturePeerType)applicationFeaturePeerType
{
    return TGApplicationFeaturePeerPrivate;
}

#pragma mark -

- (void)updateControllerEmptyState:(bool)force
{
    [TGModernConversationCompanion dispatchOnMessageQueue:^
    {
        [self _updateControllerEmptyState:_items.count == 0 force:force];
    }];
}

- (void)_updateControllerEmptyState:(bool)empty force:(bool)force
{
    TGDispatchOnMainThread(^
    {
        if (_controllerShowingEmptyState != empty || force)
        {
            _controllerShowingEmptyState = empty;
            
            TGModernConversationController *controller = self.controller;
            
            if (_controllerShowingEmptyState)
                [controller setEmptyListPlaceholder:[self _conversationEmptyListPlaceholder]];
            else
                [controller setEmptyListPlaceholder:nil];

            if (_controllerShowingEmptyState)
                [controller setDefaultInputPanel:[self _conversationEmptyListInputPanel]];
            else
                [controller setDefaultInputPanel:[self _conversationGenericInputPanel]];
        }
    });
}

- (void)clearCheckedMessages
{
    [_checkedMessages removeAllObjects];
}

- (void)setMessageChecked:(TGMessageIndex *)messageIndex checked:(bool)checked
{
    if (messageIndex.messageId != 0)
    {
        NSMutableSet *mids = _checkedMessages[@(messageIndex.peerId)];
        if (mids == nil && checked) {
            mids = [[NSMutableSet alloc] init];
            _checkedMessages[@(messageIndex.peerId)] = mids;
        }
        
        if (checked)
            [mids addObject:@(messageIndex.messageId)];
        else
            [mids removeObject:@(messageIndex.messageId)];
        
        if (mids.count == 0)
            [_checkedMessages removeObjectForKey:@(messageIndex.messageId)];
    }
}

- (NSInteger)checkedMessageCount
{
    NSInteger totalCount = 0;
    for (NSSet *set in _checkedMessages.allValues)
    {
        totalCount += set.count;
    }
    return totalCount;
}

- (NSArray *)checkedMessageIndices
{
    NSMutableArray *checkedMessageIndices = [[NSMutableArray alloc] init];
    for (NSNumber *peerId in [_checkedMessages allKeys]) {
        for (NSNumber *mid in [_checkedMessages[peerId] allObjects]) {
            [checkedMessageIndices addObject:[TGMessageIndex indexWithPeerId:peerId.longLongValue messageId:mid.intValue]];
        }
    }
    return checkedMessageIndices;
}

- (TGUser *)checkedMessageModerateUser {
    return nil;
}

- (bool)_isMessageChecked:(TGMessageIndex *)messageIndex
{
    if (messageIndex.peerId == 0) {
        for (NSNumber *peerId in [_checkedMessages allKeys]) {
            if ([_checkedMessages[peerId] containsObject:@(messageIndex.messageId)])
                return true;
        }
        return false;
    }
    return [_checkedMessages[@(messageIndex.peerId)] containsObject:@(messageIndex.messageId)];
}

- (bool)_isGroupChecked:(int64_t)groupedId
{
    NSMutableArray *messageIndices = [[NSMutableArray alloc] init];
    for (TGMessageModernConversationItem *item in [self.controller _currentItems])
    {
        if (item->_message.groupedId == groupedId)
        {
            [messageIndices addObject:[TGMessageIndex indexWithPeerId:item->_message.fromUid messageId:item->_message.mid]];
            if (messageIndices.count == 10)
                break;
        }
    }
    
    bool allChecked = true;
    for (TGMessageIndex *messageIndex in messageIndices)
    {
        if (![self _isMessageChecked:messageIndex])
        {
            allChecked = false;
            break;
        }
    }
    
    return allChecked;
}

- (void)_setMessageFlags:(int32_t)messageId flags:(int)flags
{
    TGDispatchOnMainThread(^
    {
        _messageFlags[messageId] = _messageFlags[messageId] | flags;
        
        TGModernConversationController *controller = self.controller;
        [controller updateMessageAttributes:messageId];
    });
}

- (void)_setMessageViewDate:(int32_t)messageId viewDate:(NSTimeInterval)viewDate
{
    TGDispatchOnMainThread(^
    {
        _messageViewDate[messageId] = viewDate;
        
        TGModernConversationController *controller = self.controller;
        [controller updateMessageAttributes:messageId];
    });
}

- (void)_setMessageFlagsAndViewDate:(int32_t)messageId flags:(int)flags viewDate:(NSTimeInterval)viewDate
{
    TGDispatchOnMainThread(^
    {
        _messageFlags[messageId] = _messageFlags[messageId] | flags;
        _messageViewDate[messageId] = viewDate;
        
        TGModernConversationController *controller = self.controller;
        [controller updateMessageAttributes:messageId];
    });
}

- (bool)_isSecretMessageViewed:(int32_t)messageId
{
    auto it = _messageFlags.find(messageId);
    if (it != _messageFlags.end())
        return it->second & TGSecretMessageFlagViewed;
    return false;
}

- (bool)_isSecretMessageScreenshotted:(int32_t)messageId
{
    auto it = _messageFlags.find(messageId);
    if (it != _messageFlags.end())
        return it->second & TGSecretMessageFlagScreenshot;
    return false;
}

- (NSTimeInterval)_secretMessageViewDate:(int32_t)messageId
{
    auto it = _messageViewDate.find(messageId);
    if (it != _messageViewDate.end())
        return it->second;
    return 0.0;
}

#pragma mark -

- (NSString *)title
{
    return nil;
}

- (void)_setTitle:(NSString *)title
{
    TGDispatchOnMainThread(^
    {
        TGModernConversationController *controller = self.controller;
        [controller setTitle:title];
    });
}

- (void)_setAvatarConversationId:(int64_t)conversationId title:(NSString *)title icon:(UIImage *)icon
{
    TGDispatchOnMainThread(^
    {
        TGModernConversationController *controller = self.controller;
        [controller setAvatarConversationId:conversationId title:title icon:icon];
    });
}

- (void)_setAvatarConversationIds:(NSArray *)conversationIds titles:(NSArray *)titles
{
    TGDispatchOnMainThread(^
    {
        TGModernConversationController *controller = self.controller;
        [controller setAvatarConversationIds:conversationIds titles:titles];
    });
}

- (void)_setAvatarConversationId:(int64_t)conversationId firstName:(NSString *)firstName lastName:(NSString *)lastName
{
    TGDispatchOnMainThread(^
    {
        TGModernConversationController *controller = self.controller;
        [controller setAvatarConversationId:conversationId firstName:firstName lastName:lastName];
    });
}

- (void)_setAvatarUrl:(NSString *)avatarUrl
{
    TGDispatchOnMainThread(^
    {
        TGModernConversationController *controller = self.controller;
        [controller setAvatarUrl:avatarUrl];
    });
}

- (void)_setAvatarUrls:(NSArray *)avatarUrls
{
    TGDispatchOnMainThread(^
    {
        TGModernConversationController *controller = self.controller;
        [controller setAvatarUrls:avatarUrls];
    });
}

- (void)_setTitleIcons:(NSArray *)titleIcons
{
    TGDispatchOnMainThread(^
    {
        TGModernConversationController *controller = self.controller;
        [controller setTitleIcons:titleIcons];
    });
}

- (void)_setStatus:(NSString *)status accentColored:(bool)accentColored allowAnimation:(bool)allowAnimation toggleMode:(TGModernConversationControllerTitleToggle)toggleMode
{
    TGDispatchOnMainThread(^
    {
        TGModernConversationController *controller = self.controller;
        [controller setStatus:status accentColored:accentColored allowAnimation:allowAnimation toggleMode:toggleMode];
    });
}

- (void)_setTitle:(NSString *)title andStatus:(NSString *)status accentColored:(bool)accentColored allowAnimatioon:(bool)allowAnimation toggleMode:(TGModernConversationControllerTitleToggle)toggleMode
{
    TGDispatchOnMainThread(^
    {
        TGModernConversationController *controller = self.controller;
        [controller setTitle:title];
        [controller setStatus:status accentColored:accentColored allowAnimation:allowAnimation toggleMode:toggleMode];
    });
}

- (void)_setTypingStatus:(NSString *)typingStatus activity:(int)activity
{
    TGDispatchOnMainThread(^
    {
        TGModernConversationController *controller = self.controller;
        [controller setTypingStatus:typingStatus activity:activity];
    });
}

#define TG_AUTOMATIC_CONTEXT true

+ (CGContextRef)_createSnapshotContext:(CGSize)screenSize memoryToRelease:(void **)memoryToRelease
{
    if (TG_AUTOMATIC_CONTEXT)
    {
        CGFloat contextScale = TGIsRetina() ? 2.0f : 1.0f;
        UIGraphicsBeginImageContextWithOptions(screenSize, false, contextScale);
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGContextTranslateCTM(context, screenSize.width / 2.0f, screenSize.height / 2.0f);
        CGContextRotateCTM(context, (CGFloat)M_PI);
        CGContextTranslateCTM(context, -screenSize.width / 2.0f, -screenSize.height / 2.0f);
        
        return context;
    }
    else
    {
        CGSize contextSize = screenSize;
        if (TGIsRetina())
        {
            contextSize.width *= 2.0f;
            contextSize.height *= 2.0f;
        }
        
        size_t bytesPerRow = 4 * (int)contextSize.width;
        bytesPerRow = (bytesPerRow + 15) & ~15;
        
        static void *memory = NULL;
        if (memoryToRelease != NULL)
        {
            memory = malloc((int)(bytesPerRow * contextSize.height));
           *memoryToRelease = memory;
        }
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
        
        CGContextRef context = CGBitmapContextCreate(memory,
                                                     (int)contextSize.width,
                                                     (int)contextSize.height,
                                                     8,
                                                     bytesPerRow,
                                                     colorSpace,
                                                     bitmapInfo);
        CGColorSpaceRelease(colorSpace);
        
        if (TGIsRetina())
            CGContextScaleCTM(context, 2.0, 2.0f);
        
        UIGraphicsPushContext(context);
        
        CGContextTranslateCTM(context, screenSize.width / 2.0f, screenSize.height / 2.0f);
        CGContextRotateCTM(context, (float)M_PI);
        CGContextScaleCTM(context, 1.0f, -1.0f);
        CGContextTranslateCTM(context, -screenSize.width / 2.0f, -screenSize.height / 2.0f);
        
        return context;
    }
}

+ (CGImageRef)createSnapshotFromContextAndRelease:(CGContextRef)context
{
    if (TG_AUTOMATIC_CONTEXT)
    {
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return CGImageRetain(image.CGImage);
    }
    else
    {
        UIGraphicsPopContext();
        
        CGImageRef contextImageRef = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
        
        return contextImageRef;
    }
}

- (void)_createInitialSnapshot
{
#undef TG_TIMESTAMP_DEFINE
#define TG_TIMESTAMP_DEFINE(x)
#undef TG_TIMESTAMP_MEASURE
#define TG_TIMESTAMP_MEASURE(x)
    
    TG_TIMESTAMP_DEFINE(_createInitialSnapshot);
    
    const bool useViews = false;
    
    TGModernConversationController *controller = self.controller;
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:controller.interfaceOrientation];
    if (![self _controllerShouldHideInputTextByDefault] || [controller customInputPanel] != nil) {
        screenSize.height -= 45;
    }
    
    if (_tempMemory != NULL)
    {
        free(_tempMemory);
        _tempMemory = NULL;
    }
    
    CGContextRef context = NULL;
    
    if (!useViews)
    {
        context = [TGModernConversationCompanion _createSnapshotContext:screenSize memoryToRelease:&_tempMemory];
        
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
        CGContextSetAllowsFontSubpixelQuantization(context, false);
        CGContextSetShouldSubpixelQuantizeFonts(context, false);
        CGContextSetAllowsFontSubpixelPositioning(context, true);
        CGContextSetShouldSubpixelPositionFonts(context, true);
#else
        CGContextSetShouldAntialias(context, true);
        CGContextSetShouldSmoothFonts(context, true);
#endif
    }
    
    TG_TIMESTAMP_MEASURE(_createInitialSnapshot);
    
    if (context != NULL || useViews)
    {
        TGModernTemporaryView *backgroundViewContainer = [[TGModernTemporaryView alloc] init];
        backgroundViewContainer.viewStorage = _tempViewStorage;
        backgroundViewContainer.userInteractionEnabled = false;
        
        NSMutableArray *boundItems = [[NSMutableArray alloc] init];
        
        int scrollItemIndex = -1;
        if (_initialPositionedMessageId != 0)
        {
            int index = -1;
            for (TGMessageModernConversationItem *item in [controller _currentItems])
            {
                index++;
                if (item->_message.mid == _initialPositionedMessageId)
                {
                    scrollItemIndex = index;
                    break;
                }
            }
        }
        
        CGFloat topContentInset = controller.controllerInset.top;
        CGFloat contentHeight = 0.0f;
        
        std::vector<TGDecorationViewAttrubutes> visibleDecorationViewAttributes;
        NSArray *visibleItemsAttributes = [TGModernConversationViewLayout layoutAttributesForItems:[controller _currentItems] containerWidth:screenSize.width maxHeight:scrollItemIndex == -1 ? screenSize.height : FLT_MAX dateOffset:(int)[[TGTelegramNetworking instance] timeOffset] decorationViewAttributes:&visibleDecorationViewAttributes contentHeight:&contentHeight unreadMessageRange:_unreadMessageRange viewStorage:nil cachedGroupedLayouts:nil];
        
        CGFloat contentOffsetY = 0.0f;
        if (scrollItemIndex != -1)
        {
            for (PSUICollectionViewLayoutAttributes *attributes in visibleItemsAttributes)
            {
                int index = (int)attributes.indexPath.row;
                if (index == scrollItemIndex)
                {
                    switch (_initialScrollPosition)
                    {
                        case TGInitialScrollPositionTop:
                            contentOffsetY = CGRectGetMaxY(attributes.frame) + topContentInset - screenSize.height + [self initialPositioningOverflowForScrollPosition:_initialScrollPosition];
                            break;
                        case TGInitialScrollPositionCenter:
                        {
                            CGFloat visibleHeight = screenSize.height - topContentInset;
                            contentOffsetY = CGFloor(CGRectGetMidY(attributes.frame) - visibleHeight / 2.0f);
                            break;
                        }
                        case TGInitialScrollPositionBottom:
                            contentOffsetY = attributes.frame.origin.y - [self initialPositioningOverflowForScrollPosition:_initialScrollPosition];
                            break;
                        default:
                            break;
                    }
                    
                    break;
                }
            }
            
            contentOffsetY += _initialScrollOffset;
            
            if (contentOffsetY > contentHeight + topContentInset - screenSize.height)
                contentOffsetY = contentHeight + topContentInset - screenSize.height;
            if (contentOffsetY < 0.0f)
                contentOffsetY = 0.0f;
        }
        
        if (contentOffsetY < 0.0f + FLT_EPSILON && _initialPositionedMessageId != 0)
        {
            _initialPositionedMessageId = 0;
            scrollItemIndex = -1;
            [self setUnreadMessageRange:TGMessageRangeEmpty()];
            
            visibleDecorationViewAttributes.clear();
            visibleItemsAttributes = [TGModernConversationViewLayout layoutAttributesForItems:[controller _currentItems] containerWidth:screenSize.width maxHeight:scrollItemIndex == -1 ? screenSize.height : FLT_MAX dateOffset:(int)[[TGTelegramNetworking instance] timeOffset] decorationViewAttributes:&visibleDecorationViewAttributes contentHeight:&contentHeight unreadMessageRange:_unreadMessageRange viewStorage:nil cachedGroupedLayouts:nil];
        }
        
        TG_TIMESTAMP_MEASURE(_createInitialSnapshot);
        
        CGFloat topEdge = 0.0f;
        
        NSMutableIndexSet *visibleIndices = [[NSMutableIndexSet alloc] init];
        
        CGRect visibleBounds = CGRectMake(0.0f, contentOffsetY, screenSize.width, screenSize.height);
        for (PSUICollectionViewLayoutAttributes *attributes in visibleItemsAttributes)
        {
            int index = (int)attributes.indexPath.row;
            
            TGMessageModernConversationItem *item = [controller _currentItems][index];
            CGRect itemFrame = attributes.frame;
            
            if (!CGRectIntersectsRect(visibleBounds, itemFrame))
                continue;
            
            [self _updateImportantMediaStatusDataInplace:item];
            
            [visibleIndices addIndex:index];
            
            CGFloat currentVerticalPosition = screenSize.height - itemFrame.origin.y - itemFrame.size.height + contentOffsetY;
            topEdge = MAX(topEdge, screenSize.height - currentVerticalPosition);
            
            if (useViews)
            {
                [item.viewModel bindViewToContainer:backgroundViewContainer viewStorage:_tempViewStorage];
                [item.viewModel _offsetBoundViews:CGSizeMake(0.0f, currentVerticalPosition)];
                if ([item.viewModel isKindOfClass:[TGMessageViewModel class]])
                {
                    TGMessageViewModel *messageViewModel = (TGMessageViewModel *)item.viewModel;
                    if (messageViewModel.needsRelativeBoundsUpdates)
                        [messageViewModel relativeBoundsUpdated:CGRectMake(0.0f, -currentVerticalPosition, screenSize.width, screenSize.height)];
                }
            }
            else
            {
                CGContextTranslateCTM(context, itemFrame.origin.x, currentVerticalPosition);
                [item drawInContext:context];
                CGContextTranslateCTM(context, -itemFrame.origin.x, -currentVerticalPosition);
                
                [item bindSpecialViewsToContainer:backgroundViewContainer viewStorage:_tempViewStorage atItemPosition:CGPointMake(0, currentVerticalPosition)];
            }
            
            [boundItems addObject:item];
        }
        
        for (auto it = visibleDecorationViewAttributes.begin(); it != visibleDecorationViewAttributes.end(); it++)
        {
            if (!CGRectIntersectsRect(visibleBounds, it->frame))
                continue;
        
            CGFloat currentVerticalPosition = screenSize.height - it->frame.origin.y - it->frame.size.height + contentOffsetY;
            topEdge = MAX(topEdge, screenSize.height - currentVerticalPosition);
            
            if (it->index == INT_MIN && !useViews)
            {
                CGContextTranslateCTM(context, 0.0f, currentVerticalPosition);
                
                if (it->index != INT_MIN)
                {
                    [TGModernDateHeaderView drawDate:it->index forContainerWidth:screenSize.width inContext:context andBindBackgroundToContainer:backgroundViewContainer atPosition:CGPointMake(0, currentVerticalPosition) presentation:_viewContext.presentation];
                }
                else
                {
                    [TGModernUnreadHeaderView drawHeaderForContainerWidth:screenSize.width inContext:context andBindBackgroundToContainer:backgroundViewContainer atPosition:CGPointMake(0, currentVerticalPosition) presentation:_viewContext.presentation];
                }
                
                CGContextTranslateCTM(context, 0.0f, -currentVerticalPosition);
            }
            else if (it->index != INT_MIN)
            {
                TGModernDateHeaderView *headerView = [[TGModernDateHeaderView alloc] initWithFrame:CGRectMake(0.0f, currentVerticalPosition, screenSize.width, it->frame.size.height) presentation:_viewContext.presentation];
                headerView.transform = CGAffineTransformMakeRotation((CGFloat)(M_PI));
                [headerView setDate:it->index];
                [backgroundViewContainer addSubview:headerView];
            }
        }
        
        TG_TIMESTAMP_MEASURE(_createInitialSnapshot);
        
        backgroundViewContainer.boundItems = boundItems;

        CGImageRef contextImageRef = NULL;
        if (useViews)
        {
            static CGImageRef emptyImage = NULL;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^
            {
                emptyImage = CGImageRetain(TGScaleImageToPixelSize([UIImage imageNamed:@"Transparent.png"], CGSizeMake(2, 2)).CGImage);
            });
            contextImageRef = CGImageRetain(emptyImage);
        }
        else
            contextImageRef = [TGModernConversationCompanion createSnapshotFromContextAndRelease:context];
        
        [controller setInitialSnapshot:contextImageRef backgroundView:backgroundViewContainer viewStorage:nil topEdge:topEdge + 45.0f displayScrollDownButton:contentOffsetY >= 200.0f ];
        
        CGImageRelease(contextImageRef);
        
        TG_TIMESTAMP_MEASURE(_createInitialSnapshot);
        
        _tempVisibleItemsIndices = visibleIndices;
    }
    else
        [controller setInitialSnapshot:NULL backgroundView:nil viewStorage:nil topEdge:0.0f displayScrollDownButton:false];
}

#pragma mark -

- (void)_historyItemsPreparedForMessages:(NSArray *)__unused messages intent:(TGModernConversationAddMessageIntent)__unused intent
{
}

- (void)_updateMessageItemsWithData:(NSArray *)__unused items
{
}

- (void)_updateMediaStatusDataForCurrentItems
{
    [self _updateMediaStatusDataForItemsInIndexSet:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _items.count)] animated:false forceforceCheckDownload:false];
}

- (void)_updateMediaStatusDataForItemsWithMessageIdsInSet:(NSMutableSet *)messageIds
{
    if (messageIds.count == 0)
        return;
    
#ifdef DEBUG
    NSAssert([TGModernConversationCompanion isMessageQueue], @"Should be on message queue");
#endif
    
    NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
    
    NSInteger index = -1;
    for (TGMessageModernConversationItem *item in _items)
    {
        index++;
        
        if ([messageIds containsObject:@(item->_message.mid)])
            [indexSet addIndex:index];
    }
    
    if (indexSet.count != 0)
        [self _updateMediaStatusDataForItemsInIndexSet:indexSet animated:false forceforceCheckDownload:false];
}

- (void)_updateMediaStatusDataForItemsInIndexSet:(NSIndexSet *)indexSet animated:(bool)animated forceforceCheckDownload:(bool)forceCheckDownload
{
    if (indexSet.count == 0)
        return;
    
#ifdef DEBUG
    NSAssert([TGModernConversationCompanion isMessageQueue], @"Should be on message queue");
#endif
    
    if (_updateMediaStatusDataImpl == nil)
        _updateMediaStatusDataImpl = (TGMessageModernConversationItem * (*)(id, SEL, TGMessageModernConversationItem *))[self methodForSelector:@selector(_updateMediaStatusData:)];
    SEL selector = @selector(_updateMediaStatusData:);
    
    NSMutableArray *updatedItems = nil;
    NSMutableArray *updatedDelayAvailability = nil;
    NSMutableArray *atIndices = nil;
    
    NSMutableArray *highPriorityDownloads = [[NSMutableArray alloc] init];
    NSMutableArray *regularDownloads = [[NSMutableArray alloc] init];
    NSMutableArray *requestMessages = [[NSMutableArray alloc] init];
    
    bool automaticDownloadsAllowed = !OGPlatformMediaDownloadsRequireUserAction();
    bool automaticallyDownloadPhotos = automaticDownloadsAllowed && [self shouldAutomaticallyDownloadPhotos];
    bool automaticallyDownloadAudios = automaticDownloadsAllowed && [self shouldAutomaticallyDownloadAudios];
    bool automaticallyDownloadAnimations = automaticDownloadsAllowed && [self shouldAutomaticallyDownloadAnimations];
    bool automaticallyDownloadVideos = automaticDownloadsAllowed && [self shouldAutomaticallyDownloadVideos];
    bool automaticallyDownloadDocuments = automaticDownloadsAllowed && [self shouldAutomaticallyDownloadDocuments];
    bool automaticallyDownloadVideoMessages = automaticDownloadsAllowed && [self shouldAutomaticallyDownloadVideoMessages];
    
    if (_updateMediaStatusDataImpl != NULL)
    {
        int indexCount = (int)indexSet.count;
        NSUInteger indices[indexCount];
        [indexSet getIndexes:indices maxCount:indexSet.count inIndexRange:nil];
        NSInteger itemCount = (NSInteger)_items.count;
        
        for (int i = 0; i < indexCount; i++)
        {
            if ((NSInteger)indices[i] > itemCount - 1) {
                continue;
            }
            
            TGMessageModernConversationItem *previousItem = _items[indices[i]];
            TGMessageModernConversationItem *updatedItem = _updateMediaStatusDataImpl(self, selector, previousItem);
            
            TGMessageModernConversationItem *checkItem = updatedItem == nil ? previousItem : updatedItem;
            bool downloadMessage = false;
            
            for (TGMediaAttachment *attachment in checkItem->_message.mediaAttachments)
            {
                switch (attachment.type)
                {
                    case TGImageMediaAttachmentType:
                    {
                        if (automaticallyDownloadPhotos) {
                            downloadMessage = true;
                        }
                        
                        CGSize size = CGSizeZero;
                        NSString *imageUrl = [((TGImageMediaAttachment *)attachment).imageInfo closestImageUrlWithSize:CGSizeMake(1136.0f, 1136.0f) resultingSize:&size pickLargest:true];
                        if (size.width <= 90.0f + FLT_EPSILON || size.height <= 90.0f + FLT_EPSILON) {
                            imageUrl = [((TGImageMediaAttachment *)attachment).imageInfo imageUrlForSizeLargerThanSize:CGSizeMake(1136.0f, 1136.0f) actualSize:nil];
                        }
                        
                        if ([imageUrl hasPrefix:@"http"]) {
                            downloadMessage = false;
                        }
                        
                        break;
                    }
                    case TGVideoMediaAttachmentType:
                    {
                        TGVideoMediaAttachment *video = (TGVideoMediaAttachment *)attachment;
                        if (video.roundMessage) {
                            downloadMessage = automaticallyDownloadVideoMessages;
                        } else {
                            int32_t fileSize = 0;
                            [video.videoInfo urlWithQuality:0 actualQuality:NULL actualSize:&fileSize];
                            downloadMessage = automaticallyDownloadVideos && [self shouldAutomaticallyDownloadVideoOfSize:fileSize];
                        }
                        break;
                    }
                    case TGAudioMediaAttachmentType:
                    {
                        if (automaticallyDownloadAudios) {
                            downloadMessage = true;
                        }
                        break;
                    }
                    case TGDocumentMediaAttachmentType:
                    case TGWebPageMediaAttachmentType:
                    case TGGameAttachmentType:
                    {
                        TGDocumentMediaAttachment *document = nil;
                        TGImageMediaAttachment *image = nil;
                        
                        if (attachment.type == TGDocumentMediaAttachmentType) {
                            document = (TGDocumentMediaAttachment *)attachment;
                        } else if (attachment.type == TGWebPageMediaAttachmentType) {
                            document = ((TGWebPageMediaAttachment *)attachment).document;
                            image = ((TGWebPageMediaAttachment *)attachment).photo;
                        } else if (attachment.type == TGGameAttachmentType) {
                            document = ((TGGameMediaAttachment *)attachment).document;
                            image = ((TGGameMediaAttachment *)attachment).photo;
                        }
                        
                        if (document != nil) {
                            int32_t downloadSize = document.size;
                            bool isVoice = false;
                            bool isRoundVideo = false;
                            bool isAnimated = ([[document.mimeType lowercaseString] isEqualToString:@"image/gif"] || [[document.mimeType lowercaseString] isEqualToString:@"video/mp4"]) && ([document isAnimated] || (TGPeerIdIsSecretChat([self requestPeerId]) && checkItem->_message.layer < 45));
                            for (id attribute in document.attributes) {
                                if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]]) {
                                    isVoice = ((TGDocumentAttributeAudio *)attribute).isVoice;
                                    break;
                                } else if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]]) {
                                    isRoundVideo = ((TGDocumentAttributeVideo *)attribute).isRoundMessage;
                                    break;
                                }
                            }
                            
                            if (isVoice) {
                                downloadMessage = automaticallyDownloadAudios;
                            } else if (isRoundVideo) {
                                downloadMessage = automaticallyDownloadVideoMessages;
                            } else if (isAnimated) {
                                bool isCoub = false;
                                if ([attachment isKindOfClass:[TGWebPageMediaAttachment class]]) {
                                    TGWebPageMediaAttachment *webAttachment = (TGWebPageMediaAttachment *)attachment;
                                    if ([webAttachment.url rangeOfString:@"coub.com/"].location != NSNotFound)
                                        isCoub = true;
                                }
                                CGFloat sizeLimitMb = isCoub ? 3.0f : 1.6f;
                                if ((automaticallyDownloadAnimations || attachment.type == TGGameAttachmentType) && downloadSize < sizeLimitMb * 1024 * 1024) {
                                    bool hasSize = [document.thumbnailInfo imageUrlForLargestSize:NULL] != nil;
                                    for (id attribute in document.attributes) {
                                        if ([attribute isKindOfClass:[TGDocumentAttributeImageSize class]]) {
                                            hasSize = true;
                                            break;
                                        } else if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]]) {
                                            hasSize = true;
                                            break;
                                        }
                                    }
                                    
                                    if (hasSize) {
                                        downloadMessage = true;
                                    }
                                }
                            } else {
                                downloadMessage = automaticallyDownloadDocuments && [self shouldAutomaticallyDownloadDocumentOfSize:downloadSize];
                            }
                        } else if (image != nil) {
                            if (automaticallyDownloadPhotos || attachment.type == TGGameAttachmentType) {
                                downloadMessage = true;
                            }
                        }
                        
                        break;
                    }
                    default:
                        break;
                }
            }
            
            downloadMessage = downloadMessage && automaticDownloadsAllowed;

            if (updatedItem != nil)
            {
                bool delayUpdateAvailability = false;
                if (!updatedItem->_mediaAvailabilityStatus && downloadMessage)
                {
                    delayUpdateAvailability = true;
                    if (!TGMessageRangeIsEmpty(_unreadMessageRange) && TGMessageRangeContains(_unreadMessageRange, updatedItem->_message.fromUid, updatedItem->_message.mid, (int)updatedItem->_message.date))
                        [highPriorityDownloads addObject:updatedItem->_message];
                    else
                        [regularDownloads addObject:updatedItem->_message];
                }
                
                [(NSMutableArray *)_items replaceObjectAtIndex:indices[i] withObject:updatedItem];
            
                if (updatedItems == nil) {
                    updatedItems = [[NSMutableArray alloc] init];
                }
                if (updatedDelayAvailability == nil) {
                    updatedDelayAvailability = [[NSMutableArray alloc] init];
                }
                if (atIndices == nil) {
                    atIndices = [[NSMutableArray alloc] init];
                }
                
                [updatedItems addObject:updatedItem];
                [updatedDelayAvailability addObject:@(delayUpdateAvailability)];
                [atIndices addObject:@(indices[i])];
            } else if (forceCheckDownload || !previousItem->_automaticMediaDownloadChecked) {
                if (!previousItem->_mediaAvailabilityStatus && downloadMessage)
                {
                    if (!TGMessageRangeIsEmpty(_unreadMessageRange) && TGMessageRangeContains(_unreadMessageRange, previousItem->_message.fromUid, previousItem->_message.mid, (int)previousItem->_message.date))
                        [highPriorityDownloads addObject:previousItem->_message];
                    else
                        [regularDownloads addObject:previousItem->_message];
                }
            }
            
            TGMessageModernConversationItem *messageItem = _items[indices[i]];
            messageItem->_automaticMediaDownloadChecked = true;
            if (messageItem->_message.mid < TGMessageLocalMidBaseline)
            {
                for (TGMediaAttachment *attachment in messageItem->_message.mediaAttachments)
                {
                    if (attachment.type == TGUnsupportedMediaAttachmentType)
                    {
                        [requestMessages addObject:[[NSNumber alloc] initWithInt:messageItem->_message.mid]];
                        break;
                    }
                }
            }
        }
    }
    
    if (updatedItems != nil)
    {
        [self _itemsUpdated];
        
        TGDispatchOnMainThread(^
        {
            TGModernConversationController *controller = self.controller;
            int index = -1;
            for (TGMessageModernConversationItem *messageItem in updatedItems)
            {
                index++;
                [controller updateItemAtIndex:[atIndices[index] unsignedIntegerValue] toItem:messageItem delayAvailability:[updatedDelayAvailability[index] boolValue]];
            }
        });
    }
    
    [self _updateProgressForItemsInIndexSet:indexSet animated:animated];
    
    if (highPriorityDownloads.count != 0 || regularDownloads.count != 0) {
        if (_pendingAutomaticDownloads == nil)
            _pendingAutomaticDownloads = [[NSMutableDictionary alloc] init];
        for (TGMessage *message in regularDownloads)
            _pendingAutomaticDownloads[@(message.mid)] = @[message, @false];
        for (TGMessage *message in highPriorityDownloads)
            _pendingAutomaticDownloads[@(message.mid)] = @[message, @true];
        [self _flushPendingAutomaticDownloads];
    }
    
    if (requestMessages.count != 0)
    {
        NSMutableArray *requestMids = [[NSMutableArray alloc] init];
        int64_t requestPeerId = [self requestPeerId];
        for (NSNumber *nMid in requestMessages)
        {
            if (TGUnsupportedMessageRequestBegin(requestPeerId, [nMid intValue]))
                [requestMids addObject:nMid];
        }
        
        if (requestMids.count != 0)
        {
            [ActionStageInstance() dispatchOnStageQueue:^
            {
                for (NSNumber *nMid in requestMids)
                {
                    NSString *action = [[NSString alloc] initWithFormat:@"/tg/downloadMessages/(%lld,%d)", [self requestPeerId], [nMid intValue]];
                    NSDictionary *options = @{@"mids": @[nMid], @"peerId": @([self requestPeerId]), @"accessHash": @([self requestAccessHash])};

                    [ActionStageInstance() requestActor:action options:options flags:0 watcher:self];
                    [ActionStageInstance() requestActor:action options:options flags:0 watcher:TGTelegraphInstance];
                }
            }];
        }
    }
}

- (void)_updateProgressForItemsInIndexSet:(NSIndexSet *)__unused indexSet initial:(bool)__unused initial animated:(bool)__unused animated
{
}

- (TGMessageModernConversationItem *)_updateMediaStatusData:(TGMessageModernConversationItem *)__unused item
{
    return nil;
}

- (void)_updateImportantMediaStatusDataInplace:(TGMessageModernConversationItem *)__unused item
{
}

#pragma mark -

- (void)loadMoreMessagesAbove
{
}

- (void)setHistoryAboveReadAheadAllowed:(bool)allowed
{
    _historyAboveReadAheadAllowed = allowed;
}

- (bool)historyAboveReadAheadAllowed
{
    return _historyAboveReadAheadAllowed;
}

- (bool)historyAboveMayBeAvailable
{
    return false;
}

- (void)loadMoreMessagesBelow
{
}

- (void)unloadMessagesAbove
{
}

- (void)unloadMessagesBelow
{
}

#pragma mark -

- (void)_performFastScrollDown:(bool)__unused becauseOfSendTextAction becauseOfNavigation:(bool)__unused becauseOfNavigation
{
}

- (void)_replaceMessages:(NSArray *)newMessages
{
    [self _replaceMessages:newMessages atMessageId:0 peerId:0 expandFrom:0 jump:false top:false messageIdForVisibleHoleDirection:0 scrollBackMessageId:0 animated:false];
}

- (void)_replaceMessages:(NSArray *)newMessages atMessageId:(int32_t)atMessageId peerId:(int64_t)peerId expandFrom:(int32_t)expandMessageId jump:(bool)jump top:(bool)top messageIdForVisibleHoleDirection:(int32_t)messageIdForVisibleHoleDirection scrollBackMessageId:(int32_t)scrollBackMessageId animated:(bool)animated
{
#if defined(ONEGRAM_ARMV6)
    if ([NSThread isMainThread])
    {
        NSArray *messages = [newMessages copy];
        _initialItemsPreparationPending = true;
        uint64_t generation = ++_initialItemsPreparationGeneration;
        int32_t bindingGeneration = OSAtomicAdd32Barrier(0, &_controllerBindingGeneration);
        TGModernConversationCompanionReference *reference = _ios4LifetimeReference;
#if defined(ONEGRAM_DIAGNOSTICS)
        NSTimeInterval preparationStart = OGStartupDiagnosticsTime();
#endif
        [TGModernConversationCompanion dispatchOnMessageQueue:^
        {
            TGModernConversationCompanion *companion = TGIOS4ResolveModernConversationCompanion(reference);
            if (companion == nil || companion.controller == nil || OSAtomicAdd32Barrier(0, &companion->_controllerBindingGeneration) != bindingGeneration)
                return;
            [companion _replaceMessages:messages atMessageId:atMessageId peerId:peerId expandFrom:expandMessageId jump:jump top:top messageIdForVisibleHoleDirection:messageIdForVisibleHoleDirection scrollBackMessageId:scrollBackMessageId animated:animated];
            dispatch_async(dispatch_get_main_queue(), ^
            {
                TGModernConversationCompanion *current = TGIOS4ResolveModernConversationCompanion(reference);
                if (current == nil || OSAtomicAdd32Barrier(0, &current->_controllerBindingGeneration) != bindingGeneration || current->_initialItemsPreparationGeneration != generation)
                    return;
                current->_initialItemsPreparationPending = false;
                [current controllerCanReadHistoryUpdated];
#if defined(ONEGRAM_DIAGNOSTICS)
                if (current.controller != nil)
                    OGPlatformDiagnosticLog(@"CHAT_PREPARED messages=%lu duration_ms=%.0f since_main_ms=%.0f", (unsigned long)messages.count, (OGStartupDiagnosticsTime() - preparationStart) * 1000.0, OGStartupDiagnosticsTime() * 1000.0);
#endif
            });
        }];
        return;
    }
#endif
#if defined(ONEGRAM_ARMV6)
    int32_t bindingGeneration = OSAtomicAdd32Barrier(0, &_controllerBindingGeneration);
#endif
    [(NSMutableArray *)_items removeAllObjects];
    
    for (TGMessage *message in newMessages)
    {
        TGMessage *finalMessage = message;
        
        if ([self skipServiceMessages]) {
            if (finalMessage.actionInfo != nil)
                continue;
        }
        
        if (finalMessage.mid >= TGMessageLocalMidEditBaseline && finalMessage.date == INT32_MAX) {
            int32_t originalMid = finalMessage.mid - TGMessageLocalMidEditBaseline;
            
            TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:originalMid peerId:finalMessage.cid];
            if (message != nil) {
                _uploadingEditMessages[@(originalMid)] = finalMessage;
                TGMessage *editedMessage = [self _editedMessage:message withMediaMessage:finalMessage];
                [self updateMessagesLive:@{ @(originalMid): editedMessage } animated:true];
            } else {
                if (TGPeerIdIsChannel(finalMessage.cid)) {
                    [TGDatabaseInstance() addMessagesToChannel:finalMessage.cid messages:nil deleteMessages:@[@(finalMessage.mid)] unimportantGroups:nil addedHoles:nil removedHoles:nil removedUnimportantHoles:nil updatedMessageSortKeys:nil returnGroups:false keepUnreadCounters:true skipFeedUpdate:true changedMessages:nil];
                } else {
                    [TGDatabaseInstance() transactionRemoveMessages:@{ @(finalMessage.cid): @[@(finalMessage.mid)] } updateConversationDatas:nil];
                }
            }
            continue;
        }
        
        if (_uploadingEditMessages[@(finalMessage.mid)] != nil)
            finalMessage = [self _editedMessage:finalMessage withMediaMessage:_uploadingEditMessages[@(finalMessage.mid)]];
        
        TGMessageModernConversationItem *messageItem = [[TGMessageModernConversationItem alloc] initWithMessage:finalMessage context:_viewContext];
        [(NSMutableArray *)_items addObject:messageItem];
    }
    
    [self _updateMessageItemsWithData:_items];
    if (![NSThread isMainThread])
        [self _prepareLayoutForItemsAtIndices:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _items.count)]];
    [self _itemsUpdated];
    
    NSArray *itemsCopy = [[NSArray alloc] initWithArray:_items];
    
    TGDispatchOnMainThread(^
    {
#if defined(ONEGRAM_ARMV6)
        if (OSAtomicAdd32Barrier(0, &_controllerBindingGeneration) != bindingGeneration)
            return;
#endif
        TGModernConversationController *controller = self.controller;
        if (atMessageId != 0) {
            [controller replaceItems:itemsCopy positionAtMessageId:atMessageId peerId:peerId expandAt:expandMessageId jump:jump top:top messageIdForVisibleHoleDirection:messageIdForVisibleHoleDirection scrollBackMessageId:scrollBackMessageId animated:animated];
        } else {
            [controller replaceItems:itemsCopy messageIdForVisibleHoleDirection:messageIdForVisibleHoleDirection];
        }
    });
    
    [self _updateControllerEmptyState:_items.count == 0 force:false];
    
    [TGModernConversationCompanion dispatchOnMessageQueue:^{
        [self _updateMediaStatusDataForCurrentItems];
    }];
}

- (void)_replaceMessagesWithFastScroll:(NSArray *)newMessages intent:(TGModernConversationAddMessageIntent)intent scrollToMessageId:(int32_t)scrollToMessageId peerId:(int64_t)peerId scrollBackMessageId:(int32_t)scrollBackMessageId animated:(bool)animated
{
    [TGModernConversationCompanion dispatchOnMessageQueue:^
    {
        [(NSMutableArray *)_items removeAllObjects];
        
        for (TGMessage *message in newMessages)
        {
            if ([self skipServiceMessages]) {
                if (message.actionInfo != nil)
                    continue;
            }
            
            TGMessageModernConversationItem *messageItem = [[TGMessageModernConversationItem alloc] initWithMessage:message context:_viewContext];
            [(NSMutableArray *)_items addObject:messageItem];
        }
        
        [self _updateMessageItemsWithData:_items];
        [self _prepareLayoutForItemsAtIndices:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _items.count)]];
        
        NSArray *itemsCopy = [[NSArray alloc] initWithArray:_items];
        
        TGDispatchOnMainThread(^
        {
            TGModernConversationInsertItemIntent insertIntent = TGModernConversationInsertItemIntentGeneric;
            switch (intent)
            {
                case TGModernConversationAddMessageIntentSendTextMessage:
                    insertIntent = TGModernConversationInsertItemIntentSendTextMessage;
                    break;
                case TGModernConversationAddMessageIntentSendOtherMessage:
                    insertIntent = TGModernConversationInsertItemIntentSendOtherMessage;
                    break;
                default:
                    break;
            }
            
            TGModernConversationController *controller = self.controller;
            if (insertIntent == TGModernConversationInsertItemIntentSendTextMessage)
                [controller setEnableSendButton:true];
            [controller replaceItemsWithFastScroll:itemsCopy intent:insertIntent scrollToMessageId:scrollToMessageId peerId:peerId scrollBackMessageId:scrollBackMessageId animated:animated];
            
            [controller setEnableBelowHistoryRequests:false];
            [controller setEnableAboveHistoryRequests:true];
        });
        
        [self _updateMediaStatusDataForCurrentItems];
        [self _updateControllerEmptyState:_items.count == 0 force:false];
        [self _itemsUpdated];
    }];
}

- (TGMessage *)_editedMessage:(TGMessage *)message withMediaMessage:(TGMessage *)mediaMessage
{
    TGMessage *editedMessage = [message copy];
    editedMessage.groupedId = message.groupedId;
    editedMessage.text = mediaMessage.text;
    editedMessage.entities = mediaMessage.entities;
    
    NSMutableArray *savedAttachments = [[NSMutableArray alloc] init];
    for (TGMediaAttachment *attachment in message.mediaAttachments)
    {
        if (attachment.type != TGImageMediaAttachmentType && attachment.type != TGVideoMediaAttachmentType && attachment.type != TGDocumentMediaAttachmentType)
            [savedAttachments addObject:attachment];
    }
    
    NSMutableArray *addedAttachments = [[NSMutableArray alloc] init];
    for (TGMediaAttachment *attachment in mediaMessage.mediaAttachments)
    {
        if (attachment.type == TGImageMediaAttachmentType || attachment.type == TGVideoMediaAttachmentType || attachment.type == TGDocumentMediaAttachmentType)
            [addedAttachments addObject:attachment];
    }
    
    NSMutableArray *finalAttachments = savedAttachments;
    [finalAttachments addObjectsFromArray:addedAttachments];
    
    editedMessage.mediaAttachments = finalAttachments;
    
    return editedMessage;
}

- (void)_prepareLayoutForItemsAtIndices:(NSIndexSet *)indices
{
    CGFloat containerWidth = _controllerWidthForItemCalculation;
    if (indices.count == 0 || containerWidth <= FLT_EPSILON)
        return;
    
    int dateOffset = (int)[[TGTelegramNetworking instance] timeOffset];
    TGMessageRange unreadMessageRange = _unreadMessageRange;
    NSUInteger itemCount = _items.count;
    NSMutableArray *ranges = [[NSMutableArray alloc] init];
    NSUInteger rangeStart = [indices firstIndex];
    while (rangeStart != NSNotFound && rangeStart < itemCount)
    {
        NSUInteger rangeEnd = rangeStart;
        NSUInteger nextIndex = [indices indexGreaterThanIndex:rangeEnd];
        while (nextIndex != NSNotFound && nextIndex == rangeEnd + 1 && nextIndex < itemCount)
        {
            rangeEnd = nextIndex;
            nextIndex = [indices indexGreaterThanIndex:rangeEnd];
        }
        
        [ranges addObject:[_items subarrayWithRange:NSMakeRange(rangeStart, rangeEnd - rangeStart + 1)]];
        
        rangeStart = nextIndex;
    }
    
#if defined(ONEGRAM_DIAGNOSTICS)
    __block double layoutThreadTime = 0.0;
#endif
    OGRuntimePerformOnLatencyLane(OGRuntimeLatencyLaneLayout, ^
    {
#if defined(ONEGRAM_DIAGNOSTICS)
        double startThreadTime = TGModernConversationCompanionThreadTime();
#endif
        for (NSArray *rangeItems in ranges)
        {
            [TGModernConversationViewLayout prepareItems:rangeItems containerWidth:containerWidth dateOffset:dateOffset unreadMessageRange:unreadMessageRange];
        }
#if defined(ONEGRAM_DIAGNOSTICS)
        layoutThreadTime = TGModernConversationCompanionThreadTime() - startThreadTime;
#endif
    });
#if defined(ONEGRAM_DIAGNOSTICS)
    _diagnosticLayoutThreadTime = layoutThreadTime;
#endif
}

static const NSUInteger TGModernConversationStreamedInsertionFirstChunk = 12;
static const NSUInteger TGModernConversationStreamedInsertionChunk = 22;

- (void)_streamInsertionOfItems:(NSArray *)insertItems atIndices:(NSIndexSet *)insertAtIndices animated:(bool)animated intent:(TGModernConversationInsertItemIntent)insertIntent
{
    NSUInteger total = insertItems.count;
    NSUInteger *indices = (NSUInteger *)malloc(sizeof(NSUInteger) * total);
    if (indices == NULL)
    {
        [self _prepareLayoutForItemsAtIndices:insertAtIndices];
        TGDispatchOnMainThread(^
        {
            [self.controller insertItems:insertItems atIndices:insertAtIndices animated:animated intent:insertIntent removeAtIndices:nil];
        });
        return;
    }
    [insertAtIndices getIndexes:indices maxCount:total inIndexRange:NULL];
    
    NSUInteger itemCount = _items.count;
    NSUInteger position = 0;
    NSUInteger chunkSize = TGModernConversationStreamedInsertionFirstChunk;
    while (position < total)
    {
        NSUInteger length = MIN(chunkSize, total - position);
        NSMutableIndexSet *chunkIndices = [[NSMutableIndexSet alloc] init];
        for (NSUInteger index = position; index < position + length; index++)
            [chunkIndices addIndex:indices[index]];
        NSArray *chunkItems = [insertItems subarrayWithRange:NSMakeRange(position, length)];
        
        NSMutableIndexSet *layoutIndices = [[NSMutableIndexSet alloc] initWithIndexSet:chunkIndices];
        NSUInteger lastIndex = chunkIndices.lastIndex;
        if (lastIndex + 1 < itemCount && position + length < total && indices[position + length] == lastIndex + 1)
            [layoutIndices addIndex:lastIndex + 1];
#if defined(ONEGRAM_DIAGNOSTICS)
        CFAbsoluteTime chunkStartTime = CFAbsoluteTimeGetCurrent();
        double chunkStartThreadTime = TGModernConversationCompanionThreadTime();
#endif
        [self _prepareLayoutForItemsAtIndices:layoutIndices];
        
#if defined(ONEGRAM_DIAGNOSTICS)
        OGPlatformDiagnosticLog(@"HISTORY chunk ready count=%d offset=%d total=%d ms=%.0f cpu=%.0f queueCpu=%.0f", (int)length, (int)position, (int)total, (CFAbsoluteTimeGetCurrent() - chunkStartTime) * 1000.0, _diagnosticLayoutThreadTime * 1000.0, (TGModernConversationCompanionThreadTime() - chunkStartThreadTime) * 1000.0);
#endif
        TGDispatchOnMainThread(^
        {
            [self.controller insertItems:chunkItems atIndices:chunkIndices animated:animated intent:insertIntent removeAtIndices:nil];
        });
        
        position += length;
        chunkSize = TGModernConversationStreamedInsertionChunk;
    }
    
    free(indices);
}

- (void)_addMessages:(NSArray *)addedMessages animated:(bool)animated intent:(TGModernConversationAddMessageIntent)intent
{
    [self _addMessages:addedMessages animated:animated intent:intent deletedMessages:nil];
}

- (void)_addMessages:(NSArray *)addedMessages animated:(bool)animated intent:(TGModernConversationAddMessageIntent)intent deletedMessages:(NSArray *)deletedMessages
{
    dispatch_block_t addMessagesBlock = ^
    {
        NSMutableDictionary *removedMidsByPeerId = [[NSMutableDictionary alloc] init];
        for (id nMessage in deletedMessages)
        {
            int64_t peerId = 0;
            int32_t mid = 0;
            if ([nMessage isKindOfClass:[NSNumber class]]) {
                mid = [((NSNumber *)nMessage) intValue];
            } else if ([nMessage isKindOfClass:[TGMessageIndex class]]) {
                peerId = ((TGMessageIndex *)nMessage).peerId;
                mid = ((TGMessageIndex *)nMessage).messageId;
            }
            
            NSMutableSet *removedMids = removedMidsByPeerId[@(peerId)];
            if (removedMids == nil) {
                removedMids = [[NSMutableSet alloc] init];
                removedMidsByPeerId[@(peerId)] = removedMids;
            }
            [removedMids addObject:@(mid)];
        }
        
        NSMutableIndexSet *deletedIndexSet = [[NSMutableIndexSet alloc] init];
        int index = -1;
        for (TGMessageModernConversationItem *item in _items)
        {
            index++;
            
            if ([removedMidsByPeerId[@0] containsObject:@(item->_message.mid)] || [removedMidsByPeerId[@(item->_message.fromUid)] containsObject:@(item->_message.mid)])
            {
                [deletedIndexSet addIndex:index];
            }
        }
        
        [(NSMutableArray *)_items removeObjectsAtIndexes:deletedIndexSet];
        
        NSMutableDictionary *existingMidsByPeerId = [[NSMutableDictionary alloc] init];
        for (TGMessageModernConversationItem *messageItem in _items)
        {
            int64_t peerId = messageItem->_message.fromUid;
            int32_t mid = messageItem->_message.mid;
            
            NSMutableSet *existingMids = existingMidsByPeerId[@(peerId)];
            if (existingMids == nil) {
                existingMids = [[NSMutableSet alloc] init];
                existingMidsByPeerId[@(peerId)] = existingMids;
            }
            [existingMids addObject:@(mid)];
        }
        
        TGMutableArrayWithIndices *insertArray = [[TGMutableArrayWithIndices alloc] initWithArray:(NSMutableArray *)_items];
        NSMutableArray *duplicateDiscussionUpdatedItems = [[NSMutableArray alloc] init];
        
        bool hasOldestItem = false;
        int oldestItemDate = 0;
        int32_t oldestItemMid = 0;
        for (TGMessageModernConversationItem *messageItem in _items)
        {
            TGMessage *itemMessage = messageItem->_message;
            if (itemMessage == nil)
                continue;
            int itemDate = (int)itemMessage.date;
            int32_t itemMid = itemMessage.mid;
            if (!hasOldestItem || itemDate < oldestItemDate || (itemDate == oldestItemDate && itemMid < oldestItemMid))
            {
                hasOldestItem = true;
                oldestItemDate = itemDate;
                oldestItemMid = itemMid;
            }
        }
        
        for (TGMessage *message in addedMessages)
        {
            TGMessage *finalMessage = message;
            if ([existingMidsByPeerId[@(finalMessage.fromUid)] containsObject:@(finalMessage.mid)])
            {
                TGMessageDiscussionContentProperty *incomingDiscussion = nil;
                id incomingProperty = finalMessage.contentProperties[@"ios6Discussion"];
                if ([incomingProperty isKindOfClass:[TGMessageDiscussionContentProperty class]])
                    incomingDiscussion = incomingProperty;

                if (incomingDiscussion != nil)
                {
                    NSUInteger existingIndex = NSNotFound;
                    TGMessageModernConversationItem *existingItem = nil;
                    for (NSUInteger i = 0; i < _items.count; i++)
                    {
                        TGMessageModernConversationItem *candidate = _items[i];
                        if (candidate->_message.mid == finalMessage.mid && candidate->_message.cid == finalMessage.cid)
                        {
                            existingIndex = i;
                            existingItem = candidate;
                            break;
                        }
                    }

                    if (existingItem != nil && existingIndex != NSNotFound)
                    {
                        TGMessageDiscussionContentProperty *oldDiscussion = nil;
                        id oldProperty = existingItem->_message.contentProperties[@"ios6Discussion"];
                        if ([oldProperty isKindOfClass:[TGMessageDiscussionContentProperty class]])
                            oldDiscussion = oldProperty;

                        bool discussionChanged = oldDiscussion == nil ||
                            oldDiscussion.comments != incomingDiscussion.comments ||
                            oldDiscussion.replies != incomingDiscussion.replies ||
                            oldDiscussion.channelId != incomingDiscussion.channelId ||
                            oldDiscussion.maxId != incomingDiscussion.maxId ||
                            oldDiscussion.readMaxId != incomingDiscussion.readMaxId ||
                            !TGObjectCompare(oldDiscussion.recentRepliers, incomingDiscussion.recentRepliers);

                        if (discussionChanged)
                        {
                            TGMessage *mergedMessage = [existingItem->_message copy];
                            NSMutableDictionary *properties = existingItem->_message.contentProperties != nil ?
                                [existingItem->_message.contentProperties mutableCopy] : [[NSMutableDictionary alloc] init];
                            properties[@"ios6Discussion"] = incomingDiscussion;
                            mergedMessage.contentProperties = properties;

                            TGMessageModernConversationItem *updatedItem = [existingItem deepCopy];
                            updatedItem->_message = mergedMessage;
                            [(NSMutableArray *)_items replaceObjectAtIndex:existingIndex withObject:updatedItem];

                            [duplicateDiscussionUpdatedItems addObject:updatedItem];

                        }
                    }
                }
                continue;
            }
            
            if ([self skipServiceMessages]) {
                if (finalMessage.actionInfo != nil)
                    continue;
            }
            
            NSMutableSet *existingMids = existingMidsByPeerId[@(finalMessage.fromUid)];
            if (existingMids == nil) {
                existingMids = [[NSMutableSet alloc] init];
                existingMidsByPeerId[@(finalMessage.fromUid)] = existingMids;
            }
            [existingMids addObject:@(finalMessage.mid)];
            
            if (finalMessage.mid >= TGMessageLocalMidEditBaseline && finalMessage.date == INT32_MAX) {
                 int32_t originalMid = finalMessage.mid - TGMessageLocalMidEditBaseline;
                
                TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:originalMid peerId:finalMessage.cid];
                if (message != nil) {
                    _uploadingEditMessages[@(originalMid)] = finalMessage;
                    TGMessage *editedMessage = [self _editedMessage:message withMediaMessage:finalMessage];
                    [self updateMessagesLive:@{ @(originalMid): editedMessage } animated:true];
                } else {
                    if (TGPeerIdIsChannel(finalMessage.cid)) {
                        [TGDatabaseInstance() addMessagesToChannel:finalMessage.cid messages:nil deleteMessages:@[@(finalMessage.mid)] unimportantGroups:nil addedHoles:nil removedHoles:nil removedUnimportantHoles:nil updatedMessageSortKeys:nil returnGroups:false keepUnreadCounters:true skipFeedUpdate:true changedMessages:nil];
                    } else {
                        [TGDatabaseInstance() transactionRemoveMessages:@{ @(finalMessage.cid): @[@(finalMessage.mid)] } updateConversationDatas:nil];
                    }
                }
                continue;
            }
            
            int date = (int)finalMessage.date;
            int32_t mid = finalMessage.mid;
            bool inserted = false;
            
            if (_uploadingEditMessages[@(finalMessage.mid)] != nil)
            {
                finalMessage = [self _editedMessage:finalMessage withMediaMessage:_uploadingEditMessages[@(finalMessage.mid)]];
            }
            
            bool olderThanAllItems = !hasOldestItem || !(oldestItemDate < date || (oldestItemDate == date && oldestItemMid < mid));
            if (!olderThanAllItems)
            {
                int index = -1;
                for (TGMessageModernConversationItem *messageItem in _items)
                {
                    index++;
                    
                    if (messageItem->_message == nil)
                        continue;
                    
                    int itemDate = (int)messageItem->_message.date;
                    int32_t itemMid = messageItem->_message.mid;
                    bool passes = itemMid < mid;
                    if (itemDate < date || (itemDate == date && passes))
                    {
                        [insertArray insertObject:[[TGMessageModernConversationItem alloc] initWithMessage:finalMessage context:_viewContext] atIndex:index];
                        inserted = true;
                        break;
                    }
                }
            }
            if (!inserted) {
                [insertArray insertObject:[[TGMessageModernConversationItem alloc] initWithMessage:finalMessage context:_viewContext] atIndex:_items.count];
            }
            if (finalMessage != nil)
            {
                int insertedDate = (int)finalMessage.date;
                int32_t insertedMid = finalMessage.mid;
                if (!hasOldestItem || insertedDate < oldestItemDate || (insertedDate == oldestItemDate && insertedMid < oldestItemMid))
                {
                    hasOldestItem = true;
                    oldestItemDate = insertedDate;
                    oldestItemMid = insertedMid;
                }
            }
        }
        
        NSIndexSet *insertAtIndices = nil;
        NSArray *insertItems = [insertArray objectsForInsertOperations:&insertAtIndices];
        
        [self _updateMessageItemsWithData:insertItems];
        [self _historyItemsPreparedForMessages:addedMessages intent:intent];
        
        TGModernConversationInsertItemIntent insertIntent = TGModernConversationInsertItemIntentGeneric;
        switch (intent)
        {
            case TGModernConversationAddMessageIntentLoadMoreMessagesAbove:
                insertIntent = TGModernConversationInsertItemIntentLoadMoreMessagesAbove;
                break;
            case TGModernConversationAddMessageIntentLoadMoreMessagesBelow:
                insertIntent = TGModernConversationInsertItemIntentLoadMoreMessagesBelow;
                break;
            case TGModernConversationAddMessageIntentSendTextMessage:
                insertIntent = TGModernConversationInsertItemIntentSendTextMessage;
                break;
            case TGModernConversationAddMessageIntentSendOtherMessage:
                insertIntent = TGModernConversationInsertItemIntentSendOtherMessage;
                break;
            default:
                break;
        }
        
        bool streamInsertion = intent == TGModernConversationAddMessageIntentLoadMoreMessagesAbove && deletedIndexSet.count == 0 && duplicateDiscussionUpdatedItems.count == 0 && insertItems.count > TGModernConversationStreamedInsertionFirstChunk && ![NSThread isMainThread];
        if (streamInsertion)
        {
            [self _streamInsertionOfItems:insertItems atIndices:insertAtIndices animated:animated intent:insertIntent];
        }
        else
        {
            [self _prepareLayoutForItemsAtIndices:insertAtIndices];
        }
        
        TGDispatchOnMainThread(^
        {
            TGModernConversationController *controller = self.controller;
            
            if (!streamInsertion)
                [controller insertItems:insertItems atIndices:insertAtIndices animated:animated intent:insertIntent removeAtIndices:deletedIndexSet];

            for (TGMessageModernConversationItem *updatedItem in duplicateDiscussionUpdatedItems)
            {
                NSUInteger finalIndex = [_items indexOfObjectIdenticalTo:updatedItem];
                if (finalIndex != NSNotFound)
                {
                    [controller updateItemAtIndex:(int)finalIndex
                                          toItem:updatedItem
                               delayAvailability:false];
                }
            }

            if (intent == TGModernConversationAddMessageIntentSendTextMessage)
                [controller setEnableSendButton:true];
        });
        
        [self _updateMediaStatusDataForItemsInIndexSet:insertAtIndices animated:false forceforceCheckDownload:false];
        [self _updateControllerEmptyState:_items.count == 0 force:false];
        [self _itemsUpdated];
    };
    
    bool latencyCritical = intent == TGModernConversationAddMessageIntentLoadMoreMessagesAbove || intent == TGModernConversationAddMessageIntentLoadMoreMessagesBelow;
    [TGModernConversationCompanion dispatchOnMessageQueue:latencyCritical ? OGRuntimeLatencyCriticalBlock(addMessagesBlock) : addMessagesBlock];
}

- (void)_deleteMessages:(NSArray *)messages animated:(bool)animated
{    
    [TGModernConversationCompanion dispatchOnMessageQueue:^
    {
        NSMutableArray *messageIds = [[NSMutableArray alloc] init];
        NSMutableDictionary *removedMidsByPeerId = [[NSMutableDictionary alloc] init];
        for (id nMessage in messages)
        {
            int64_t peerId = 0;
            int32_t mid = 0;
            if ([nMessage isKindOfClass:[NSNumber class]]) {
                mid = [((NSNumber *)nMessage) intValue];
            } else if ([nMessage isKindOfClass:[TGMessageIndex class]]) {
                peerId = ((TGMessageIndex *)nMessage).peerId;
                mid = ((TGMessageIndex *)nMessage).messageId;
            }
            
            NSMutableSet *removedMids = removedMidsByPeerId[@(peerId)];
            if (removedMids == nil) {
                removedMids = [[NSMutableSet alloc] init];
                removedMidsByPeerId[@(peerId)] = removedMids;
            }
            [removedMids addObject:@(mid)];
            
            [messageIds addObject:@(mid)];
        }
        
        NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
        int index = -1;
        for (TGMessageModernConversationItem *item in _items)
        {
            index++;
            
            if ([removedMidsByPeerId[@0] containsObject:@(item->_message.mid)] || [removedMidsByPeerId[@(item->_message.fromUid)] containsObject:@(item->_message.mid)])
            {
                [indexSet addIndex:index];
            }
        }
        
        [(NSMutableArray *)_items removeObjectsAtIndexes:indexSet];
        
        TGDispatchOnMainThread(^
        {
            TGModernConversationController *controller = self.controller;
            [controller _deleteItemsAtIndices:indexSet animated:animated animationFactor:1.0f];
            
            
            if (_checkedMessages.count != 0)
            {
                bool haveChanges = false;
                for (id nMessage in messages)
                {
                    int64_t peerId = 0;
                    int32_t mid = 0;
                    if ([nMessage isKindOfClass:[NSNumber class]]) {
                        mid = [((NSNumber *)nMessage) intValue];
                    } else if ([nMessage isKindOfClass:[TGMessageIndex class]]) {
                        peerId = ((TGMessageIndex *)nMessage).peerId;
                        mid = ((TGMessageIndex *)nMessage).messageId;
                    }
                    
                    if (peerId == 0) {
                        for (NSNumber *peerId in [_checkedMessages allKeys]) {
                            if ([_checkedMessages[peerId] containsObject:@(mid)]) {
                                NSMutableSet *mids = _checkedMessages[peerId];
                                [mids removeObject:@(mid)];
                                
                                if (mids.count == 0)
                                    [_checkedMessages removeObjectForKey:peerId];
                                
                                haveChanges = true;
                            }
                        }
                    } else if ([_checkedMessages[@(peerId)] containsObject:@(mid)]) {
                        NSMutableSet *mids = _checkedMessages[@(peerId)];
                        [mids removeObject:@(mid)];
                        
                        if (mids.count == 0)
                            [_checkedMessages removeObjectForKey:@(peerId)];
                        
                        haveChanges = true;
                    }
                }
                
                if (haveChanges)
                    [controller updateCheckedMessages];
            }
            
            [controller messagesDeleted:messageIds];
        });
        
        [self _updateControllerEmptyState:_items.count == 0 force:false];
        [self _itemsUpdated];
    }];
}

- (void)_updateMessageDelivered:(int32_t)previousMid
{
    [self _updateMessageDelivered:previousMid mid:0 date:0 message:nil pts:0];
}

- (void)_updateMessageDelivered:(int32_t)previousMid mid:(int32_t)mid date:(int32_t)date message:(TGMessage *)message pts:(int32_t)pts
{
    [TGModernConversationCompanion dispatchOnMessageQueue:^
    {
        if (mid != 0 && mid != previousMid)
        {
            int localIndex = -1;
            int scanIndex = -1;
            int64_t localPeerId = 0;
            for (TGMessageModernConversationItem *messageItem in _items)
            {
                scanIndex++;
                if (messageItem->_message.mid == previousMid)
                {
                    localIndex = scanIndex;
                    localPeerId = messageItem->_message.fromUid;
                    break;
                }
            }
            bool alreadyPresent = false;
            if (localIndex >= 0)
            {
                for (TGMessageModernConversationItem *messageItem in _items)
                {
                    if (messageItem->_message.mid == mid && messageItem->_message.fromUid == localPeerId)
                    {
                        alreadyPresent = true;
                        break;
                    }
                }
            }
            if (alreadyPresent)
            {
                TGMessageModernConversationItem *localItem = _items[(NSUInteger)localIndex];
                NSIndexSet *removedIndices = [NSIndexSet indexSetWithIndex:(NSUInteger)localIndex];
                [self _resetProgressForItemsInIndexSet:removedIndices];
                if (localItem->_message.deliveryState != TGMessageDeliveryStateDelivered && TGAppDelegateInstance.soundEnabled)
                    [TGAppDelegateInstance playSound:@"sent.caf" vibrate:false];
                [(NSMutableArray *)_items removeObjectAtIndex:(NSUInteger)localIndex];
                TGDispatchOnMainThread(^
                {
                    TGMessageIndex *previousMessageIndex = [TGMessageIndex indexWithPeerId:localPeerId messageId:previousMid];
                    TGMessageIndex *messageIndex = [TGMessageIndex indexWithPeerId:localPeerId messageId:mid];
                    if (_mediaHiddenMessageIndex.peerId == localPeerId && _mediaHiddenMessageIndex.messageId == previousMid)
                        _mediaHiddenMessageIndex = messageIndex;
                    bool selectionChanged = [self _isMessageChecked:previousMessageIndex];
                    if (selectionChanged)
                    {
                        [self setMessageChecked:previousMessageIndex checked:false];
                        [self setMessageChecked:messageIndex checked:true];
                    }
                    TGModernConversationController *controller = self.controller;
                    [controller _deleteItemsAtIndices:removedIndices animated:false animationFactor:1.0f];
                    if (selectionChanged)
                        [controller updateCheckedMessages];
                });
                [self _itemsUpdated];
                return;
            }
        }
        
        int index = -1;
        int foundIndex = -1;
        int64_t peerId = 0;
        for (TGMessageModernConversationItem *messageItem in _items)
        {
            index++;
            
            if (messageItem->_message.mid == previousMid)
            {
                peerId = messageItem->_message.fromUid;
                
                TGMessageModernConversationItem *updatedItem = [messageItem deepCopy];
                
                TGMessage *updatedMessage = updatedItem->_message;
                if (message != nil) {
                    updatedMessage.text = message.text;
                    updatedMessage.mediaAttachments = message.mediaAttachments;
                }
                
                if (mid != 0)
                    updatedMessage.mid = mid;
                if (date != 0)
                    updatedItem->_additionalDate = date;
                updatedMessage.pts = pts;
                updatedMessage.deliveryState = TGMessageDeliveryStateDelivered;
                [self _resetProgressForItemsInIndexSet:[NSIndexSet indexSetWithIndex:index]];
                
                if (date != 0) {
                    bool changesOrder = false;
                    if (index != 0) {
                        if (((TGMessageModernConversationItem *)_items[index - 1])->_message.date > date) {
                            changesOrder = true;
                        }
                    }
                    if (index != (int)_items.count - 1) {
                        if (((TGMessageModernConversationItem *)_items[index + 1])->_message.date < date) {
                            changesOrder = true;
                        }
                    }
                    if (!changesOrder) {
                        updatedMessage.date = date;
                    }
                }
                
                updatedItem->_message = updatedMessage;
                
                TGMessageModernConversationItem *statusItem = [self _updateMediaStatusData:updatedItem];
                bool updateMediaAvailability = false;
                if (statusItem != nil)
                {
                    updatedItem = statusItem;
                    updateMediaAvailability = true;
                }
                
                if (messageItem->_message.deliveryState != TGMessageDeliveryStateDelivered && TGAppDelegateInstance.soundEnabled)
                    [TGAppDelegateInstance playSound:@"sent.caf" vibrate:false];
                
                [(NSMutableArray *)_items replaceObjectAtIndex:index withObject:updatedItem];
                
                foundIndex = index;
                
                TGDispatchOnMainThread(^
                {
                    if (mid != 0 && (_mediaHiddenMessageIndex.peerId == peerId && _mediaHiddenMessageIndex.messageId == previousMid))
                        _mediaHiddenMessageIndex = [TGMessageIndex indexWithPeerId:peerId messageId:mid];
                    
                    TGModernConversationController *controller = self.controller;
                    [controller updateItemAtIndex:index toItem:updatedItem delayAvailability:false];
                });
                
                break;
            }
        }
        
        [self _itemsUpdated];
        
        if (foundIndex >= 0) {
            [self _updateMediaStatusDataForItemsInIndexSet:[NSIndexSet indexSetWithIndex:foundIndex] animated:false forceforceCheckDownload:true];
        }
        
        TGDispatchOnMainThread(^
        {
            TGMessageIndex *previousMessageIndex = [TGMessageIndex indexWithPeerId:peerId messageId:previousMid];
            TGMessageIndex *messageIndex = [TGMessageIndex indexWithPeerId:peerId messageId:mid];
            if (mid != 0 && [self _isMessageChecked:messageIndex])
            {
                [self setMessageChecked:previousMessageIndex checked:false];
                [self setMessageChecked:messageIndex checked:true];
            }
        });
    }];
}

- (void)_updateMessageDeliveryFailed:(int32_t)previousMid
{
    [TGModernConversationCompanion dispatchOnMessageQueue:^
    {
        int index = -1;
        for (TGMessageModernConversationItem *messageItem in _items)
        {
            index++;
            
            if (messageItem->_message.mid == previousMid)
            {
                TGMessageModernConversationItem *updatedItem = [messageItem deepCopy];
                updatedItem->_message.deliveryState = TGMessageDeliveryStateFailed;
                [(NSMutableArray *)_items replaceObjectAtIndex:index withObject:updatedItem];
                
                TGDispatchOnMainThread(^
                {
                    TGModernConversationController *controller = self.controller;
                    [controller updateItemAtIndex:index toItem:updatedItem delayAvailability:false];
                });
                
                break;
            }
        }
    }];
}

- (void)_downloadMediaInMessage:(TGMessage *)__unused message highPriority:(bool)__unused highPriority
{
}

- (void)_updateMessages:(NSDictionary *)messagesByIds
{
    [TGModernConversationCompanion dispatchOnMessageQueue:^
    {
        NSMutableArray *itemUpdates = [[NSMutableArray alloc] init];
        NSMutableIndexSet *progressResets = [[NSMutableIndexSet alloc] init];

        NSUInteger count = _items.count;
        for (NSUInteger index = 0; index < count; index++)
        {
            TGMessageModernConversationItem *messageItem = _items[index];
            
            TGMessage *previousMessage = messageItem->_message;
            TGMessage *updatedMessage = [messagesByIds[@(previousMessage.mid)] copy];
            if (updatedMessage != nil && ![updatedMessage isEqual:previousMessage])
            {
                int64_t previousMediaId = 0;
                for (TGMediaAttachment *attachment in previousMessage.mediaAttachments)
                {
                    if (attachment.type == TGImageMediaAttachmentType)
                        previousMediaId = ((TGImageMediaAttachment *)attachment).imageId;
                    else if (attachment.type == TGVideoMediaAttachmentType)
                        previousMediaId = ((TGVideoMediaAttachment *)attachment).videoId;
                    else if (attachment.type == TGDocumentMediaAttachmentType)
                        previousMediaId = ((TGDocumentMediaAttachment *)attachment).documentId;
                    else if (attachment.type == TGAudioMediaAttachmentType)
                        previousMediaId = ((TGAudioMediaAttachment *)attachment).audioId;
                }
                
                int64_t updatedMediaId = 0;
                for (TGMediaAttachment *attachment in updatedMessage.mediaAttachments)
                {
                    if (attachment.type == TGImageMediaAttachmentType)
                        updatedMediaId = ((TGImageMediaAttachment *)attachment).imageId;
                    else if (attachment.type == TGVideoMediaAttachmentType)
                        updatedMediaId = ((TGVideoMediaAttachment *)attachment).videoId;
                    else if (attachment.type == TGDocumentMediaAttachmentType)
                        updatedMediaId = ((TGDocumentMediaAttachment *)attachment).documentId;
                    else if (attachment.type == TGAudioMediaAttachmentType)
                        updatedMediaId = ((TGAudioMediaAttachment *)attachment).audioId;
                }
                
                updatedMessage.date = previousMessage.date;
                TGMessageModernConversationItem *updatedItem = [messageItem deepCopy];
                updatedItem->_message = updatedMessage;

                if ([self isKindOfClass:[TGGenericModernConversationCompanion class]])
                {
                    TGMessageModernConversationItem *statusItem = [(TGGenericModernConversationCompanion *)self _updateMediaStatusData:updatedItem];
                    if (statusItem != nil)
                        updatedItem = statusItem;
                }

                [(NSMutableArray *)_items replaceObjectAtIndex:index withObject:updatedItem];
                
                if (previousMediaId != updatedMediaId || previousMessage.mid != updatedMessage.mid || (previousMessage.deliveryState == TGMessageDeliveryStatePending && updatedMessage.deliveryState != TGMessageDeliveryStatePending))
                    [progressResets addIndex:index];

                [itemUpdates addObject:@(index)];
                [itemUpdates addObject:updatedItem];
            }
        }

        if (itemUpdates.count != 0)
        {
            if (progressResets.count != 0)
                [self _resetProgressForItemsInIndexSet:progressResets];
            
            TGDispatchOnMainThread(^
            {
                TGModernConversationController *controller = self.controller;
                
                int updatedItemsCount = (int)itemUpdates.count;
                for (int i = 0; i < updatedItemsCount; i += 2)
                {
                    [controller updateItemAtIndex:[itemUpdates[i + 0] intValue] toItem:itemUpdates[i + 1] delayAvailability:false];
                }
            });
            
            [self _itemsUpdated];
        }
    }];
}

- (void)updateMessagesLive:(NSDictionary *)__unused messageIdToMessage animated:(bool)__unused animated {
    
}

- (void)_resetProgressForItemsInIndexSet:(NSIndexSet *)__unused indexSet
{
}

#pragma mark -

- (NSString *)youtubeVideoIdFromText:(NSString *)text
{
    if ([text hasPrefix:@"http://www.youtube.com/watch?v="] || [text hasPrefix:@"https://www.youtube.com/watch?v="] || [text hasPrefix:@"http://m.youtube.com/watch?v="] || [text hasPrefix:@"https://m.youtube.com/watch?v="])
    {
        NSRange range1 = [text rangeOfString:@"?v="];
        bool match = true;
        for (NSInteger i = range1.location + range1.length; i < (NSInteger)text.length; i++)
        {
            unichar c = [text characterAtIndex:i];
            if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '=' || c == '&' || c == '#'))
            {
                match = false;
                break;
            }
        }
        
        if (match)
        {
            NSString *videoId = nil;
            NSRange ampRange = [text rangeOfString:@"&"];
            NSRange hashRange = [text rangeOfString:@"#"];
            if (ampRange.location != NSNotFound || hashRange.location != NSNotFound)
            {
                NSInteger location = MIN(ampRange.location, hashRange.location);
                videoId = [text substringWithRange:NSMakeRange(range1.location + range1.length, location - range1.location - range1.length)];
            }
            else
                videoId = [text substringFromIndex:range1.location + range1.length];
            
            if (videoId.length != 0)
                return videoId;
        }
    }
    else if ([text hasPrefix:@"http://youtu.be/"] || [text hasPrefix:@"https://youtu.be/"])
    {
        NSString *suffix = [text substringFromIndex:[text hasPrefix:@"http://youtu.be/"] ? @"http://youtu.be/".length : @"https://youtu.be/".length];
        for (int i = 0; i < (int)suffix.length; i++)
        {
            unichar c = [suffix characterAtIndex:i];
            if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '=' || c == '&' || c == '#'))
            {
                return nil;
            }
        }
    }
    
    return nil;
}

- (NSString *)twitterPostIdFromText:(NSString *)text
{
    bool isHttps = false;
    text = [text stringByReplacingOccurrencesOfString:@"mobile.twitter." withString:@"twitter."];
    if ([text hasPrefix:@"http://twitter.com/"] || (isHttps = [text hasPrefix:@"https://twitter.com/"]))
    {
        NSString *path = [text substringFromIndex:(isHttps ? @"https://twitter.com/" : @"http://twitter.com/").length];
        NSArray *components = [path componentsSeparatedByString:@"/"];
        if (components.count == 3 && [(NSString *)components[1] isEqualToString:@"status"])
            return (NSString *)components[2];
    }
    return nil;
}

- (NSString *)vkInternalUrlFromText:(NSString *)text
{
    NSString *pattern = @"https?:\\/\\/(vk\\.com\\/wall-?[0-9_-]+)\\/?";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
    if (match != nil)
        return [text substringWithRange:[match rangeAtIndex:1]];
    return nil;
}

- (bool)_presentOpenInMenuForUrlString:(NSString *)urlString
{
    if (urlString.length == 0)
        return false;

    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil)
        url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSString *scheme = [url.scheme lowercaseString];
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"])
        return false;
    if (![TGOpenInMenu hasThirdPartyAppsForURL:url])
        return false;

    TGModernConversationController *controller = self.controller;
    [controller endEditing];
    [TGOpenInMenu presentInParentController:controller menuController:nil title:TGLocalized(@"Map.OpenIn") url:url buttonTitle:nil buttonAction:nil sourceView:controller.view sourceRect:nil barButtonItem:nil];
    return true;
}

- (void)actionStageActionRequested:(NSString *)action options:(id)options
{
    if ([action isEqualToString:@"ios6ReactionTapped"])
    {
        int32_t messageId = [options[@"mid"] intValue];
        NSString *reaction = options[@"reaction"];
        bool remove = [options[@"remove"] boolValue];
        if (messageId > 0 && (remove || reaction.length != 0))
            [[self controller] _ios6SendReaction:remove ? nil : reaction messageId:messageId];
    }
    else if ([action isEqualToString:@"messageSelectionRequested"])
    {   
        TGModernConversationController *controller = self.controller;
        [controller highlightAndShowActionsMenuForMessage:[options[@"mid"] intValue] peerId:[options[@"peerId"] longLongValue] groupedId:[options[@"groupedId"] longLongValue]];
    }
    else if ([action isEqualToString:@"messageSelectionChanged"])
    {
        int64_t peerId = [options[@"peerId"] longLongValue];
        int32_t mid = [options[@"mid"] intValue];
        if (mid != 0)
        {
            [self setMessageChecked:[TGMessageIndex indexWithPeerId:peerId messageId:mid] checked:[options[@"selected"] boolValue]];
                
            TGModernConversationController *controller = self.controller;
            [controller updateCheckedMessages];
        }
    }
    else if ([action isEqualToString:@"messageGroupSelectionChanged"])
    {
        int64_t groupedId = [options[@"groupedId"] longLongValue];
        if (groupedId != 0)
        {
            NSMutableArray *messageIndices = [[NSMutableArray alloc] init];
            for (TGMessageModernConversationItem *item in [self.controller _currentItems])
            {
                if (item->_message.groupedId == groupedId)
                {
                    [messageIndices addObject:[TGMessageIndex indexWithPeerId:item->_message.fromUid messageId:item->_message.mid]];
                    if (messageIndices.count == 10)
                        break;
                }
            }
            
            for (TGMessageIndex *messageIndex in messageIndices) {
                [self setMessageChecked:[TGMessageIndex indexWithPeerId:messageIndex.peerId messageId:messageIndex.messageId] checked:[options[@"selected"] boolValue]];
            }
            
            TGModernConversationController *controller = self.controller;
            [controller updateCheckedMessages];
        }
    }
    else if ([action isEqualToString:@"openLinkWithOptionsRequested"])
    {
        TGModernConversationController *controller = self.controller;
        [controller showActionsMenuForLink:options[@"url"] webPage:options[@"webPage"]];
    }
    else if ([action isEqualToString:@"openLinkRequested"])
    {
        if ([options[@"url"] rangeOfString:@"/socks?"].location != NSNotFound || [options[@"url"] rangeOfString:@"/proxy?"].location != NSNotFound) {
            TGModernConversationController *controller = self.controller;
            [controller endEditing];
        }
        if ([options[@"url"] hasPrefix:@"tel:"])
        {
            NSString *rawPhone = [options[@"url"] substringFromIndex:4];
            rawPhone = [TGPhoneUtils cleanInternationalPhone:rawPhone forceInternational:false];
            
            void (^call)(void) = ^
            {
                [TGAppDelegateInstance performPhoneCall:[NSURL URLWithString:[@"tel:" stringByAppendingString:rawPhone]]];
            };
            
            if (iosMajorVersion() < 10 || (iosMajorVersion() == 10 && iosMinorVersion() < 3))
            {
                TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:[TGLegacyComponentsContext shared] dark:false];
                controller.dismissesByOutsideTap = true;
                controller.hasSwipeGesture = true;
                
                __weak TGMenuSheetController *weakController = controller;
                
                TGMenuSheetTitleItemView *titleItem = [[TGMenuSheetTitleItemView alloc] initWithTitle:nil subtitle:[TGPhoneUtils formatPhone:rawPhone forceInternational:false]];
            
                TGMenuSheetButtonItemView *phoneItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"UserInfo.PhoneCall") type:TGMenuSheetButtonTypeDefault action:^
                {
                    call();
                    __strong TGMenuSheetController *strongController = weakController;
                    if (strongController != nil)
                        [strongController dismissAnimated:true];
                }];
                
                TGMenuSheetButtonItemView *cancelItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel action:^
                {
                    __strong TGMenuSheetController *strongController = weakController;
                    if (strongController != nil)
                        [strongController dismissAnimated:true];
                }];
                
                [controller setItemViews:@[ titleItem, phoneItem, cancelItem ]];
                
                TGModernConversationController *conversationController = self.controller;
                controller.sourceRect = ^CGRect
                {
                    return CGRectZero;
                };
                [controller presentInViewController:conversationController sourceView:conversationController.view animated:true];
                
                [conversationController.view endEditing:true];
            }
            else
            {
                call();
            }
        }
        else
        {
            if (TGIsInternalTelegramLink(options[@"url"]))
            {
                NSURL *url = [NSURL URLWithString:options[@"url"]];
                if (url != nil)
                {
                    [(TGApplication *)[UIApplication sharedApplication] openURL:url forceNative:true keepStack:true];
                    return;
                }
            }

            if (![options[@"hidden"] boolValue] && [self _presentOpenInMenuForUrlString:options[@"url"]])
                return;

            NSString *youtubeVideoId = [self youtubeVideoIdFromText:options[@"url"]];
            if (youtubeVideoId.length != 0)
            {
                NSURL *clientUrl = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"youtube://watch?v=%@", youtubeVideoId]];
                if ([[UIApplication sharedApplication] canOpenURL:clientUrl])
                {
                    [[UIApplication sharedApplication] openURL:clientUrl];
                    return;
                }
            }
            
            NSString *twitterPostId = [self twitterPostIdFromText:options[@"url"]];
            if (twitterPostId.length != 0)
            {
                NSURL *clientUrl = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"twitter://status?id=%@", twitterPostId]];
                if ([[UIApplication sharedApplication] canOpenURL:clientUrl])
                {
                    [[UIApplication sharedApplication] openURL:clientUrl];
                    return;
                }
            } else if ([options[@"url"] rangeOfString:@"twitter.com/hashtag/"].location != NSNotFound)
            {
                NSRange prefixRange = [options[@"url"] rangeOfString:@"twitter.com/hashtag/"];
                NSString *hashtag = [options[@"url"] substringFromIndex:prefixRange.location + prefixRange.length];
                hashtag = [hashtag componentsSeparatedByString:@"/"].firstObject;
                if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://search?query=q"]])
                {
                    NSURL *clientUrl = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"twitter://search?query=%%23%@", hashtag]];
                    [[UIApplication sharedApplication] openURL:clientUrl];
                }
                else
                {
                    [(TGApplication *)[UIApplication sharedApplication] openURL:[NSURL URLWithString:options[@"url"]] forceNative:true];
                }
                return;
            } else if ([options[@"url"] rangeOfString:@"twitter.com/"].location != NSNotFound) {
                NSURL *url = [NSURL URLWithString:options[@"url"]];
                NSArray *components = [url.path componentsSeparatedByString:@"/"];
                NSString *bareHost = [url.host stringByReplacingOccurrencesOfString:@"www." withString:@""];
                bareHost = [url.host stringByReplacingOccurrencesOfString:@"mobile." withString:@""];
                NSArray *exceptions = @[ @"about", @"i", @"tags", @"tos", @"privacy", @"explore", @"directory", @"search", @"settings"];
                if (![bareHost hasPrefix:@"twitter.com"] || components.count < 2 || [exceptions containsObject:components[1]] || (components.count > 2 && ![components[2] hasPrefix:@"?"]) || ![[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://user?screen_name=name"]])
                {
                    [(TGApplication *)[UIApplication sharedApplication] openURL:[NSURL URLWithString:options[@"url"]] forceNative:true];
                }
                else
                {
                    NSString *mention = components[1];
                    NSURL *clientUrl = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"twitter://user?screen_name=%@", mention]];
                    [[UIApplication sharedApplication] openURL:clientUrl];
                }
                return;
            }
            
            NSString *instagramShortcode = [TGInstagramMediaIdSignal instagramShortcodeFromText:options[@"url"]];
            if (instagramShortcode.length != 0)
            {
                if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"instagram://media?id=1"]])
                {
                    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
                    [progressWindow show:true];
                    [[[[TGInstagramMediaIdSignal instagramMediaIdForShortcode:instagramShortcode] deliverOn:[SQueue mainQueue]] onDispose:^
                    {
                        [progressWindow dismiss:true];
                    }] startWithNext:^(NSString *mediaId)
                    {
                        NSURL *clientUrl = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"instagram://media?id=%@", mediaId]];
                        if ([[UIApplication sharedApplication] canOpenURL:clientUrl])
                        {
                            [[UIApplication sharedApplication] openURL:clientUrl];
                            return;
                        }
                    } error:^(__unused id error)
                    {
                        [(TGApplication *)[UIApplication sharedApplication] openURL:[NSURL URLWithString:options[@"url"]] forceNative:true];
                    } completed:nil];
                }
                else
                {
                    [(TGApplication *)[UIApplication sharedApplication] openURL:[NSURL URLWithString:options[@"url"]] forceNative:true];
                }
                return;
            } else if ([options[@"url"] rangeOfString:@"instagram.com/explore/tags/"].location != NSNotFound)
            {
                NSRange prefixRange = [options[@"url"] rangeOfString:@"instagram.com/explore/tags/"];
                NSString *hashtag = [options[@"url"] substringFromIndex:prefixRange.location + prefixRange.length];
                hashtag = [hashtag componentsSeparatedByString:@"/"].firstObject;
                if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"instagram://tag?name=tag"]])
                {
                    NSURL *clientUrl = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"instagram://tag?name=%@", hashtag]];
                    [[UIApplication sharedApplication] openURL:clientUrl];
                }
                else
                {
                    [(TGApplication *)[UIApplication sharedApplication] openURL:[NSURL URLWithString:options[@"url"]] forceNative:true];
                }
                return;
            } else if ([options[@"url"] rangeOfString:@"instagram.com/"].location != NSNotFound) {
                NSURL *url = [NSURL URLWithString:options[@"url"]];
                NSArray *components = [url.path componentsSeparatedByString:@"/"];
                NSString *bareHost = [url.host stringByReplacingOccurrencesOfString:@"www." withString:@""];
                NSArray *exceptions = @[ @"about", @"legal", @"explore", @"accounts", @"developer", @"explore", @"directory", @"privacy"];
                if (![bareHost hasPrefix:@"instagram.com"] || components.count < 2 || [exceptions containsObject:components[1]] || (components.count > 2 && ![components[2] hasPrefix:@"?"]) || ![[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"instagram://user?username=name"]])
                {
                    [(TGApplication *)[UIApplication sharedApplication] openURL:[NSURL URLWithString:options[@"url"]] forceNative:true];
                }
                else
                {
                    NSString *mention = components[1];
                    NSURL *clientUrl = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"instagram://user?username=%@", mention]];
                    [[UIApplication sharedApplication] openURL:clientUrl];
                }
                return;
            }
            
            NSString *vkUrl = [self vkInternalUrlFromText:options[@"url"]];
            if (vkUrl.length != 0)
            {
                NSURL *clientUrl = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"vk://%@", vkUrl]];
                if ([[UIApplication sharedApplication] canOpenURL:clientUrl])
                {
                    [[UIApplication sharedApplication] openURL:clientUrl];
                    return;
                }
            }
            
            if ([options[@"hidden"] boolValue]) {
                [TGCustomAlertView presentAlertWithTitle:nil message:[NSString stringWithFormat:TGLocalized(@"Generic.OpenHiddenLinkAlert"), options[@"url"]] cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"Common.OK") completionBlock:^(bool okButtonPressed) {
                    if (okButtonPressed) {
                        if ([self _presentOpenInMenuForUrlString:options[@"url"]])
                            return;
                        NSURL *url = [NSURL URLWithString:options[@"url"]];
                        if (url == nil) {
                            url = [NSURL URLWithString:[(NSString *)options[@"url"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                        }
                        [(TGApplication *)[UIApplication sharedApplication] openURL:url forceNative:true];
                    }
                }];
            } else {
                NSURL *url = [NSURL URLWithString:options[@"url"]];
                if (url == nil) {
                    url = [NSURL URLWithString:[(NSString *)options[@"url"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                }
                [(TGApplication *)[UIApplication sharedApplication] openURL:url forceNative:true keepStack:true];
            }
        }
    }
    else if ([action isEqualToString:@"openMediaRequested"])
    {
        if (options[@"mid"] != nil && _uploadingEditMessages[options[@"mid"]] != nil) {
            return;
        }
        
        TGModernConversationController *controller = self.controller;
        [controller openMediaFromMessage:[options[@"mid"] intValue] peerId:[options[@"peerId"] longLongValue] instant:[options[@"instant"] boolValue]];
        
        [TGAppDelegateInstance.rootController.dialogListController maybeDismissSearchResults];
    }
    else if ([action isEqualToString:@"openEmbedRequested"])
    {
        TGModernConversationController *controller = self.controller;
        TGWebPageMediaAttachment *webPage = options[@"webPage"];
        if ([self _presentOpenInMenuForUrlString:webPage.url])
        {
            [TGAppDelegateInstance.rootController.dialogListController maybeDismissSearchResults];
            return;
        }
        if ([webPage.embedType isEqualToString:@"application/x-shockwave-flash"])
            [(TGApplication *)[UIApplication sharedApplication] openURL:[NSURL URLWithString:webPage.url] forceNative:true];
        else
            [controller openEmbed:webPage forMessageId:[options[@"mid"] intValue] peerId:[options[@"peerId"] longLongValue]];
        
        [TGAppDelegateInstance.rootController.dialogListController maybeDismissSearchResults];
    }
    else if ([action isEqualToString:@"closeMediaRequested"])
    {
        TGModernConversationController *controller = self.controller;
        [controller closeMediaFromMessage:[options[@"mid"] intValue] peerId:0 instant:[options[@"instant"] boolValue]];
    }
    else if ([action isEqualToString:@"showUnsentMessageMenu"])
    {
        TGModernConversationController *controller = self.controller;
        [controller showActionsMenuForUnsentMessage:[options[@"mid"] intValue] edit:_uploadingEditMessages[options[@"mid"]] != nil];
    }
    else if ([action isEqualToString:@"stickerPackInfoRequested"])
    {
        TGModernConversationController *controller = self.controller;
        [controller openStickerPackForMessageId:[options[@"mid"] intValue] peerId:[options[@"peerId"] longLongValue]];
    }
    else if ([action isEqualToString:@"callRequested"])
    {
        if ([options[@"immediate"] boolValue])
            [self startVoiceCall];
    }
    else if ([action isEqualToString:@"locationPickerRequested"])
    {
        TGModernConversationController *controller = self.controller;
        [controller _displayLocationPicker];
    }
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/webpages"])
    {
        [TGModernConversationCompanion dispatchOnMessageQueue:^
        {
            [self _webPagesUpdated:resource localIdToWebPage:nil];
        }];
    }
}

- (void)actorMessageReceived:(NSString *)__unused path messageType:(NSString *)__unused messageType message:(id)__unused message
{
}

- (void)actorCompleted:(int)__unused status path:(NSString *)__unused path result:(id)__unused result
{
    if ([path hasPrefix:@"/tg/downloadMessages/"])
    {
        if (status != ASStatusSuccess)
        {
            NSRange openRange = [path rangeOfString:@"(" options:NSBackwardsSearch];
            NSRange closeRange = [path rangeOfString:@")" options:NSBackwardsSearch];
            if (openRange.location != NSNotFound && closeRange.location != NSNotFound && closeRange.location > openRange.location)
            {
                NSArray *components = [[path substringWithRange:NSMakeRange(openRange.location + 1, closeRange.location - openRange.location - 1)] componentsSeparatedByString:@","];
                if (components.count == 2)
                    TGUnsupportedMessageRequestFailed([components[0] longLongValue], [components[1] intValue]);
            }
        }
        else
        {
            [TGModernConversationCompanion dispatchOnMessageQueue:^
            {
                NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
                NSMutableArray *replacedItems = [[NSMutableArray alloc] init];
                
                [result[@"messagesByConversation"] enumerateKeysAndObjectsUsingBlock:^(__unused id key, NSArray *updatedMessages, __unused BOOL *stop)
                {
                    std::map<int, TGMessage *> updatedMessagesWithMids;
                    for (TGMessage *message in updatedMessages)
                    {
                        updatedMessagesWithMids[message.mid] = message;
                    }
                    
                    int index = -1;
                    for (TGMessageModernConversationItem *messageItem in _items)
                    {
                        index++;
                        auto it = updatedMessagesWithMids.find(messageItem->_message.mid);
                        if (it != updatedMessagesWithMids.end())
                        {
                            TGMessageModernConversationItem *updatedItem = [[TGMessageModernConversationItem alloc] initWithMessage:it->second context:_viewContext];
                            
                            [indexSet addIndex:index];
                            [replacedItems addObject:updatedItem];
                        }
                    }
                }];
                
                [(NSMutableArray *)_items replaceObjectsAtIndexes:indexSet withObjects:replacedItems];
                
                TGDispatchOnMainThread(^
                {
                    TGModernConversationController *controller = self.controller;
                    [controller replaceItems:replacedItems atIndices:indexSet];
                });
                
                [self _updateMediaStatusDataForItemsInIndexSet:indexSet animated:false forceforceCheckDownload:false];
                [self _itemsUpdated];
            }];
        }
    }
}

- (void)updateMediaAccessTimeForMessageId:(int32_t)__unused messageId
{
}

- (id)acquireAudioRecordingActivityHolder
{
    return nil;
}

- (id)acquireVideoMessageRecordingActivityHolder
{
    return nil;
}

- (id)acquireLocationPickingActivityHolder
{
    return nil;
}

- (void)serviceNotificationsForMessageIds:(NSArray *)__unused messageIds
{
}

- (void)markMessagesAsViewed:(NSArray *)__unused messageIds
{
}

- (NSArray *)recentMentionUserIds
{
    NSMutableArray *userIds = [[NSMutableArray alloc] init];
    NSMutableSet *existingIds = [[NSMutableSet alloc] init];
    for (TGMessageModernConversationItem *item in [self.controller _items]) {
        if (TGPeerIdIsUser(item->_message.fromUid)) {
            NSNumber *userId = @(item->_message.fromUid);
            if (![existingIds containsObject:userId]) {
                [existingIds addObject:userId];
                [userIds addObject:userId];
            }
        }
    }
    return userIds;
}

+ (NSArray *)mentionUsersForQuery:(NSString *)query memberUserIds:(NSArray *)memberUserIds recentUserIds:(NSArray *)recentUserIds contextBotIds:(NSArray *)contextBotIds includeSelf:(bool)includeSelf
{
    NSString *normalizedQuery = [query lowercaseString];
    NSMutableArray *queryTokens = [[NSMutableArray alloc] init];
    for (NSString *token in [normalizedQuery componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
        if (token.length != 0) {
            [queryTokens addObject:token];
        }
    }
    bool (^matchesUser)(TGUser *) = ^bool(TGUser *user) {
        if (user == nil || user.isDeleted || user.displayName.length == 0 || (!includeSelf && user.uid == TGTelegraphInstance.clientUserId)) {
            return false;
        }
        if (normalizedQuery.length == 0 || [[user.userName lowercaseString] hasPrefix:normalizedQuery]) {
            return true;
        }
        NSArray *nameTokens = [[user.displayName lowercaseString] componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]];
        for (NSString *queryToken in queryTokens) {
            bool matchesToken = false;
            for (NSString *nameToken in nameTokens) {
                if ([nameToken hasPrefix:queryToken]) {
                    matchesToken = true;
                    break;
                }
            }
            if (!matchesToken) {
                return false;
            }
        }
        return queryTokens.count != 0;
    };
    NSMutableSet *existingIds = [[NSMutableSet alloc] init];
    NSMutableArray *users = [[NSMutableArray alloc] init];
    for (NSNumber *userId in contextBotIds) {
        TGUser *user = [TGDatabaseInstance() loadUser:[userId intValue]];
        if (user.isContextBot && user.userName.length != 0 && matchesUser(user) && ![existingIds containsObject:userId]) {
            [existingIds addObject:userId];
            [users addObject:user];
        }
    }
    for (NSNumber *userId in recentUserIds) {
        if (![existingIds containsObject:userId]) {
            TGUser *user = [TGDatabaseInstance() loadUser:[userId intValue]];
            if (matchesUser(user)) {
                [existingIds addObject:userId];
                [users addObject:user];
            }
        }
    }
    NSMutableArray *remainingUsers = [[NSMutableArray alloc] init];
    for (NSNumber *userId in memberUserIds) {
        if (![existingIds containsObject:userId]) {
            TGUser *user = [TGDatabaseInstance() loadUser:[userId intValue]];
            if (matchesUser(user)) {
                [existingIds addObject:userId];
                [remainingUsers addObject:user];
            }
        }
    }
    [remainingUsers sortUsingComparator:^NSComparisonResult(TGUser *lhs, TGUser *rhs) {
        NSComparisonResult result = [lhs.displayName caseInsensitiveCompare:rhs.displayName];
        if (result == NSOrderedSame) {
            return lhs.uid < rhs.uid ? NSOrderedAscending : (lhs.uid > rhs.uid ? NSOrderedDescending : NSOrderedSame);
        }
        return result;
    }];
    [users addObjectsFromArray:remainingUsers];
    return users;
}

- (SSignal *)userListForMention:(NSString *)__unused mention canBeContextBot:(bool)__unused canBeContextBot includeSelf:(bool)__unused includeSelf
{
    return nil;
}

- (SSignal *)inlineResultForMentionText:(NSString *)__unused mention text:(NSString *)__unused text {
    return nil;
}

- (SSignal *)hashtagListForHashtag:(NSString *)__unused hashtag
{
    return nil;
}

- (SSignal *)commandListForCommand:(NSString *)__unused command
{
    return nil;
}

- (void)navigateToMessageId:(int32_t)__unused messageId scrollBackMessageId:(int32_t)__unused scrollBackMessageId forceUnseenMention:(bool)__unused forceUnseenMention animated:(bool)__unused animated
{
}

- (void)_itemsUpdated
{
    if (_allowMessageDownloads)
    {
        TGModernConversationCompanionReference *weakSelf = _ios4LifetimeReference;
        NSTimeInterval remoteTime = [[TGTelegramNetworking instance] globalTime];
        NSMutableSet *webPageIds = nil;
        
        NSUInteger itemsCount = _items.count;
        for (NSUInteger itemIndex = 0; itemIndex < itemsCount; itemIndex++)
        {
            TGMessageModernConversationItem *item = _items[itemIndex];
            int32_t messageId = item->_message.mid;
            int64_t messageCid = item->_message.cid;
            
            if (item->_message.mediaAttachments != nil)
            {
                for (TGMediaAttachment *attachment in item->_message.mediaAttachments)
                {
                    if (attachment.type == TGWebPageMediaAttachmentType)
                    {
                        TGWebPageMediaAttachment *webPage = (TGWebPageMediaAttachment *)attachment;
                        if (webPage.webPageLocalId != 0 && webPage.url.length != 0) {
                            TGWebPageMediaAttachment *cachedWebPage = [TGUpdateStateRequestBuilder webPageWithLink:webPage.url];
                            if (_downloadingWebpages[webPage.url] == nil)
                            {
                                if (cachedWebPage != nil) {
                                    [self _webPagesUpdated:@[cachedWebPage] localIdToWebPage:@{@(webPage.webPageLocalId) : cachedWebPage}];
                                } else {
                                    _downloadingWebpages[webPage.url] = [[TGUpdateStateRequestBuilder requestWebPageByText:webPage.url] startWithNext:^(TGWebPageMediaAttachment *updatedWebPage)
                                    {
                                        [TGModernConversationCompanion dispatchOnMessageQueue:^
                                        {
                                            TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
                                            if (strongSelf != nil && updatedWebPage != nil)
                                            {
                                                [strongSelf->_downloadingWebpages removeObjectForKey:webPage.url];
                                                [strongSelf _webPagesUpdated:@[updatedWebPage] localIdToWebPage:@{@(webPage.webPageLocalId): updatedWebPage}];
                                            }
                                        }];
                                    } error:^(__unused id error)
                                    {
                                        [TGDatabaseInstance() dispatchOnDatabaseThread:^{
                                            TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:messageId peerId:messageCid];
                                            if (message != nil) {
                                                message.mediaAttachments = @[];
                                                
                                                TGDatabaseUpdateMessageWithMessage *messageUpdate = [[TGDatabaseUpdateMessageWithMessage alloc] initWithPeerId:messageCid messageId:messageId message:message dispatchEdited:false];
                                                [TGDatabaseInstance() transactionUpdateMessages:@[messageUpdate] updateConversationDatas:nil];
                                            }
                                        } synchronous:false];
                                    } completed:nil];
                                }
                            }
                        } else if (webPage.webPageId != 0) {
                            NSNumber *nKey = @(webPage.webPageId);
                            [webPageIds addObject:nKey];
                            
                            if (webPage.pendingDate != 0 && webPage.url.length == 0)
                            {
                                NSTimeInterval delay = MAX(1.0, webPage.pendingDate - remoteTime);

                                if (_downloadedMessages[nKey] == nil && _downloadingMessages[nKey] == nil)
                                {
                                    TGWebPageMediaAttachment *cachedWebPage = [TGUpdateStateRequestBuilder webPageWithId:webPage.webPageId];
                                    if (cachedWebPage != nil)
                                        [self _webPagesUpdated:@[cachedWebPage] localIdToWebPage:nil];
                                    else
                                    {
                                        TGGenericModernConversationCompanion *genericSelf = (TGGenericModernConversationCompanion *)self;
                                        _downloadingMessages[nKey] = [[[TGDownloadMessagesSignal downloadMessages:@[[[TGDownloadMessage alloc] initWithPeerId:genericSelf->_conversationId accessHash:genericSelf->_accessHash messageId:item->_message.mid]]] delay:delay onQueue:[SQueue concurrentDefaultQueue]] startWithNext:^(NSArray *messages)
                                        {
                                            [TGModernConversationCompanion dispatchOnMessageQueue:^
                                            {
                                                TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
                                                if (strongSelf != nil)
                                                {
                                                    [strongSelf->_downloadingMessages removeObjectForKey:nKey];
                                                    [strongSelf _messagesDownloaded:messages];
                                                }
                                            }];
                                        } error:^(__unused id error)
                                        {
                                            [TGModernConversationCompanion dispatchOnMessageQueue:^
                                            {
                                                TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
                                                if (strongSelf != nil)
                                                {
                                                    [strongSelf->_downloadingMessages removeObjectForKey:nKey];
                                                    strongSelf->_downloadedMessages[nKey] = @1;
                                                }
                                            }];
                                        } completed:nil];
                                    }
                                }
                            }
                        }
                        
                        break;
                    }
                }
            }
        }
        
        for (NSNumber *nPageId in webPageIds)
        {
            id<SDisposable> disposable = _downloadingMessages[nPageId];
            if (disposable != nil)
            {
                [disposable dispose];
                [_downloadingMessages removeObjectForKey:nPageId];
            }
        }
    }
}

- (void)refreshItems:(void (^)(void))completion
{
    [TGModernConversationCompanion dispatchOnMessageQueue:^
    {
        for (TGMessageModernConversationItem *item in _items)
        {
            [item resetViewModel];
        }
     
        TGDispatchOnMainThread(completion);
    }];
}

- (void)updateMessageViews:(NSDictionary *)messageIdToViews markAsSeen:(bool)markAsSeen {
    [TGModernConversationCompanion dispatchOnMessageQueue:^{
        __strong TGModernConversationCompanion *strongSelf = self;
        if (strongSelf != nil) {
            NSMutableArray *updatedItems = [[NSMutableArray alloc] init];
            NSMutableArray *updatedItemIndices = [[NSMutableArray alloc] init];
            
            for (NSUInteger i = 0; i < strongSelf->_items.count; i++) {
                TGMessageModernConversationItem *item = strongSelf->_items[i];
                NSNumber *nViewCount = messageIdToViews[@(item->_message.mid)];
                if (nViewCount != nil) {
                    TGMessageModernConversationItem *updatedItem = [item deepCopy];
                    updatedItem->_message.viewCount = [[TGMessageViewCountContentProperty alloc] initWithViewCount:MAX(updatedItem->_message.viewCount.viewCount, [nViewCount intValue])];
                    [updatedItems addObject:updatedItem];
                    [updatedItemIndices addObject:@(i)];
                }
            }
            
            if (markAsSeen) {
                markMessagesAsSeen([strongSelf requestPeerId], messageIdToViews.allKeys);
            }
            
            TGDispatchOnMainThread(^
            {
                TGModernConversationController *controller = strongSelf.controller;
                
                int index = -1;
                for (NSNumber *nIndex in updatedItemIndices)
                {
                    index++;
                    [controller updateItemAtIndex:[nIndex intValue] toItem:updatedItems[index] delayAvailability:false];
                }
            });
        }
    }];
}

- (void)_messagesDownloaded:(NSArray *)messages
{
    NSMutableArray *webPages = [[NSMutableArray alloc] init];
    
    for (TGMessage *message in messages)
    {
        for (TGMediaAttachment *attachment in message.mediaAttachments)
        {
            if (attachment.type == TGWebPageMediaAttachmentType)
            {
                [webPages addObject:attachment];
                
                break;
            }
        }
    }
    
    if (webPages.count != 0)
        [self _webPagesUpdated:webPages localIdToWebPage:nil];
}

- (void)_webPagesUpdated:(NSArray *)webPages localIdToWebPage:(NSDictionary *)localIdToWebPage
{
    NSMutableArray *updatedItems = [[NSMutableArray alloc] init];
    NSMutableArray *atIndices = [[NSMutableArray alloc] init];
    
    NSInteger itemIndex = -1;
    for (TGMessageModernConversationItem *item in _items)
    {
        itemIndex++;
        
        NSInteger index = -1;
        for (TGMediaAttachment *attachment in item->_message.mediaAttachments)
        {
            index++;
            
            if (attachment.type == TGWebPageMediaAttachmentType)
            {
                int64_t webPageId = ((TGWebPageMediaAttachment *)attachment).webPageId;
                if (webPageId != 0) {
                    for (TGWebPageMediaAttachment *webPage in webPages)
                    {
                        if (webPage.webPageId == webPageId)
                        {
                            TGMessageModernConversationItem *updatedItem = [item copy];
                            updatedItem->_message = [updatedItem->_message copy];
                            NSMutableArray *attachments = [[NSMutableArray alloc] initWithArray:updatedItem->_message.mediaAttachments];
                            attachments[index] = webPage;
                            updatedItem->_message.mediaAttachments = attachments;
                            
                            int32_t messageId = item->_message.mid;
                            int64_t peerId = item->_message.cid;
                            
                            [TGDatabaseInstance() dispatchOnDatabaseThread:^{
                                TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:messageId peerId:peerId];
                                if (message != nil) {
                                    message.mediaAttachments = attachments;
                                    
                                    TGDatabaseUpdateMessageWithMessage *messageUpdate = [[TGDatabaseUpdateMessageWithMessage alloc] initWithPeerId:peerId messageId:messageId message:message dispatchEdited:false];
                                    [TGDatabaseInstance() transactionUpdateMessages:@[messageUpdate] updateConversationDatas:nil];
                                }
                            } synchronous:false];
                            
                            [updatedItems addObject:updatedItem];
                            [atIndices addObject:@(itemIndex)];
                            
                            break;
                        }
                    }
                } else if (((TGWebPageMediaAttachment *)attachment).webPageLocalId != 0) {
                    TGWebPageMediaAttachment *webPage = localIdToWebPage[@(((TGWebPageMediaAttachment *)attachment).webPageLocalId)];
                    if (webPage != nil)
                    {
                        TGMessageModernConversationItem *updatedItem = [item copy];
                        updatedItem->_message = [updatedItem->_message copy];
                        NSMutableArray *attachments = [[NSMutableArray alloc] initWithArray:updatedItem->_message.mediaAttachments];
                        attachments[index] = webPage;
                        updatedItem->_message.mediaAttachments = attachments;
                        
                        int32_t messageId = item->_message.mid;
                        int64_t peerId = item->_message.cid;
                        
                        [TGDatabaseInstance() dispatchOnDatabaseThread:^{
                            TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:messageId peerId:peerId];
                            if (message != nil) {
                                message.mediaAttachments = attachments;
                                
                                TGDatabaseUpdateMessageWithMessage *messageUpdate = [[TGDatabaseUpdateMessageWithMessage alloc] initWithPeerId:peerId messageId:messageId message:message dispatchEdited:false];
                                [TGDatabaseInstance() transactionUpdateMessages:@[messageUpdate] updateConversationDatas:nil];
                            }
                        } synchronous:false];
                        
                        [updatedItems addObject:updatedItem];
                        [atIndices addObject:@(itemIndex)];
                    }
                }
                
                break;
            }
        }
    }
    
    if (updatedItems.count != 0)
    {
        for (NSUInteger i = 0; i < updatedItems.count; i++)
        {
            [((NSMutableArray *)_items) replaceObjectAtIndex:[atIndices[i] unsignedIntegerValue] withObject:updatedItems[i]];
        }
        
        NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
        for (NSNumber *nIndex in atIndices) {
            [indexSet addIndex:[nIndex intValue]];
        }
        [self _updateMediaStatusDataForItemsInIndexSet:indexSet animated:false forceforceCheckDownload:true];
        
        TGDispatchOnMainThread(^
        {
            TGModernConversationController *controller = self.controller;
            int index = -1;
            for (TGMessageModernConversationItem *messageItem in updatedItems)
            {
                index++;
                [controller updateItemAtIndex:[atIndices[index] unsignedIntegerValue] toItem:messageItem delayAvailability:false];
            }
        });
    }
}

- (void)navigateToMessageSearch
{
}

- (bool)isASingleBotGroup
{
    return false;
}

- (bool)suppressesOutgoingUnreadContents {
    return false;
}

- (void)_controllerDidUpdateVisibleHoles:(NSArray *)__unused holes
{
}

- (void)_controllerDidUpdateVisibleMessageIds:(NSArray *)messageIds
{
    [TGModernConversationCompanion dispatchOnMessageQueue:^
    {
        _visibleMessageIdsForDownloads.clear();
        for (NSNumber *nMid in messageIds)
            _visibleMessageIdsForDownloads.insert([nMid intValue]);
        [self _flushPendingAutomaticDownloads];
    }];
}

- (void)_flushPendingAutomaticDownloads
{
    if (_pendingAutomaticDownloads.count == 0 || _visibleMessageIdsForDownloads.empty())
        return;

    static const NSInteger margin = 12;
    Class messageItemClass = [TGMessageModernConversationItem class];
    NSInteger count = (NSInteger)_items.count;
    NSInteger minVisibleIndex = NSIntegerMax;
    NSInteger maxVisibleIndex = -1;
    bool prune = _pendingAutomaticDownloads.count > 512;
    std::set<int32_t> loadedMessageIds;
    for (NSInteger index = 0; index < count; index++)
    {
        TGMessageModernConversationItem *item = _items[(NSUInteger)index];
        if (object_getClass(item) != messageItemClass && ![item isKindOfClass:messageItemClass])
            continue;
        int32_t mid = item->_message.mid;
        if (prune)
            loadedMessageIds.insert(mid);
        if (_visibleMessageIdsForDownloads.find(mid) != _visibleMessageIdsForDownloads.end())
        {
            minVisibleIndex = MIN(minVisibleIndex, index);
            maxVisibleIndex = MAX(maxVisibleIndex, index);
        }
    }

    if (prune)
    {
        NSMutableArray *staleKeys = [[NSMutableArray alloc] init];
        for (NSNumber *nMid in _pendingAutomaticDownloads)
        {
            if (loadedMessageIds.find([nMid intValue]) == loadedMessageIds.end())
                [staleKeys addObject:nMid];
        }
        [_pendingAutomaticDownloads removeObjectsForKeys:staleKeys];
    }

    if (maxVisibleIndex < 0)
        return;

    NSMutableArray *requests = [[NSMutableArray alloc] init];
    void (^collect)(NSInteger, bool) = ^(NSInteger index, bool visible)
    {
        if (index < 0 || index >= count)
            return;
        TGMessageModernConversationItem *item = _items[(NSUInteger)index];
        if (object_getClass(item) != messageItemClass && ![item isKindOfClass:messageItemClass])
            return;
        NSNumber *key = @(item->_message.mid);
        NSArray *entry = _pendingAutomaticDownloads[key];
        if (entry == nil)
            return;
        [_pendingAutomaticDownloads removeObjectForKey:key];
        [requests addObject:@[entry[0], @(visible || [entry[1] boolValue])]];
    };

    for (NSInteger index = minVisibleIndex; index <= maxVisibleIndex; index++)
        collect(index, true);
    for (NSInteger distance = 1; distance <= margin; distance++)
    {
        collect(minVisibleIndex - distance, false);
        collect(maxVisibleIndex + distance, false);
    }

    for (NSArray *request in requests)
        [self _downloadMediaInMessage:request[0] highPriority:[request[1] boolValue]];
}

- (void)_controllerDidUpdateVisibleUnseenMessageIds:(NSArray *)unseenMessageIds {
    [TGModernConversationCompanion dispatchOnMessageQueue:^{
        NSMutableArray *consumeIds = [[NSMutableArray alloc] init];
        
        for (NSNumber *nMid in unseenMessageIds) {
            if (_messageViewsRequested.find([nMid intValue]) == _messageViewsRequested.end()) {
                _messageViewsRequested.insert([nMid intValue]);
                [consumeIds addObject:nMid];
            }
        }
        
        if (consumeIds.count != 0) {
            if (_messageViewsRequestedBuffer == nil) {
                _messageViewsRequestedBuffer = [[NSMutableArray alloc] init];
            }
            
            [_messageViewsRequestedBuffer addObjectsFromArray:consumeIds];
        }
        
        [_messageViewsRequestedBufferTimer invalidate];
        [_messageViewsRequestedBufferTimer start];
    }];
}

- (void)_controllerDidUpdateVisibleUnseenMentionMessageIds:(NSArray *)unseenMentionMessageIds {
    [TGModernConversationCompanion dispatchOnMessageQueue:^{
        if (unseenMentionMessageIds.count != 0) {
            NSSet *idsSet = [[NSSet alloc] initWithArray:unseenMentionMessageIds];
            NSMutableArray *consumeIds = [[NSMutableArray alloc] init];
            
            int64_t peerId = ((TGGenericModernConversationCompanion *)self).conversationId;
            
            NSMutableArray *updateItemsAtIndices = [[NSMutableArray alloc] init];
            NSMutableArray *updateItemsWithItems = [[NSMutableArray alloc] init];
            
            for (NSUInteger index = 0; index < _items.count; index++)
            {
                TGMessageModernConversationItem *item = _items[index];
                
                if ([idsSet containsObject:@(item->_message.mid)])
                {
                    bool found = item->_message.contentProperties[@"contentsRead"] != nil;
                    if (item->_message.containsUnseenMention) {
                        found = false;
                    }
                    
                    if (!found)
                    {
                        NSMutableDictionary *contentProperties = [[NSMutableDictionary alloc] initWithDictionary:item->_message.contentProperties];
                        contentProperties[@"contentsRead"] = [[TGMessageViewedContentProperty alloc] init];
                        TGMessageModernConversationItem *updatedItem = [item deepCopy];
                        updatedItem->_message.contentProperties = contentProperties;
                        updatedItem->_message.containsUnseenMention = false;
                        ((NSMutableArray *)_items)[index] = updatedItem;
                        
                        [updateItemsAtIndices addObject:@(index)];
                        [updateItemsWithItems addObject:updatedItem];
                        
                        [consumeIds addObject:@(item->_message.mid)];
                    }
                }
            }
            
            TGDispatchOnMainThread(^{
                TGModernConversationController *controller = self.controller;
                for (NSUInteger i = 0; i < updateItemsWithItems.count; i++) {
                    [controller updateItemAtIndex:[updateItemsAtIndices[i] intValue] toItem:updateItemsWithItems[i] delayAvailability:false];
                }
            });
            
            [TGDatabaseInstance() transactionReadMessageContentsInteractive:@{@(peerId): consumeIds}];
        }
    }];
}

- (bool)_controllerShouldHideInputTextByDefault
{
    return false;
}

- (bool)canDeleteMessage:(TGMessage *)__unused message
{
    return true;
}

- (bool)canModerateMessage:(TGMessage *)__unused message {
    return false;
}

- (bool)canEditMessage:(TGMessage *)__unused message {
    return false;
}

- (bool)canPinMessage:(TGMessage *)__unused message {
    return false;
}

- (bool)canDeleteMessageForEveryone:(TGMessage *)__unused message {
    return false;
}

- (bool)isMessagePinned:(int32_t)__unused messageId {
    return false;
}

- (bool)canDeleteMessages
{
    return true;
}

- (bool)canDeleteAllMessages
{
    return true;
}
                                         
- (int64_t)requestPeerId {
    return 0;
}

- (int64_t)attachedPeerId {
    return 0;
}

- (int64_t)requestAccessHash {
    return 0;
}

- (void)_toggleBroadcastMode {
}

- (void)_toggleTitleMode {
}

- (void)consumeRequestedMessages {
    [TGModernConversationCompanion dispatchOnMessageQueue:^{
        NSArray *consumeIds = [[NSArray alloc] initWithArray:_messageViewsRequestedBuffer];
        [_messageViewsRequestedBuffer removeAllObjects];
        
        if (consumeIds.count != 0) {
            [[TGChannelManagementSignals consumeMessages:[self requestPeerId] accessHash:[self requestAccessHash] messageIds:consumeIds] startWithNext:^(NSDictionary *messageIdToViews) {
                [TGModernConversationCompanion dispatchOnMessageQueue:^{
                    __strong TGModernConversationCompanion *strongSelf = self;
                    if (strongSelf != nil) {
                        [strongSelf updateMessageViews:messageIdToViews markAsSeen:true];
                    }
                }];
            }];
        }
    }];
}

- (SSignal *)contextBotInfoForText:(NSString *)__unused text {
    return nil;
}

- (SSignalQueue *)mediaUploadQueue
{
    return _mediaUploadQueue;
}

- (id)playlistMetadata:(bool)__unused voice {
    return nil;
}

- (void)maybeAskForSecretWebpages {
    if (!TGAppDelegateInstance.allowSecretWebpages && !TGAppDelegateInstance.allowSecretWebpagesInitialized && !_askedForSecretPages) {
        _askedForSecretPages = true;
        TGModernConversationCompanionReference *weakSelf = _ios4LifetimeReference;
        TGDispatchOnMainThread(^{
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"Conversation.SecretLinkPreviewAlert") cancelButtonTitle:TGLocalized(@"Common.No") okButtonTitle:TGLocalized(@"Common.Yes") completionBlock:^(bool okButtonPressed) {
                TGAppDelegateInstance.allowSecretWebpagesInitialized = true;
                TGAppDelegateInstance.allowSecretWebpages = okButtonPressed;
                [TGAppDelegateInstance saveSettings];
                if (okButtonPressed) {
                    [TGModernConversationCompanion dispatchOnMessageQueue:^{
                        TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
                        [strongSelf _itemsUpdated];
                    }];
                    
                    TGDispatchOnMainThread(^{
                        TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
                        TGModernConversationController *controller = [strongSelf controller];
                        [controller updateWebpageLinks];
                    });
                }
            }];
        });
    }
}

- (void)maybeAskForInlineBots {
    if (!TGAppDelegateInstance.secretInlineBotsInitialized) {
        TGDispatchOnMainThread(^{
            TGAppDelegateInstance.secretInlineBotsInitialized = true;
            [TGAppDelegateInstance saveSettings];
            
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"Conversation.SecretChatContextBotAlert") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil disableKeyboardWorkaround:false];
        });
    }
}

- (SSignal *)editingContextForMessageWithId:(int32_t)__unused messageId {
    return [SSignal single:nil];
}

- (SSignal *)saveEditedMessageWithId:(int32_t)__unused messageId text:(NSString *)__unused text entities:(NSArray *)__unused entities disableLinkPreviews:(bool)__unused disableLinkPreviews {
    return [SSignal complete];
}

- (SSignal *)updatePinnedMessage:(int32_t)__unused messageId unpin:(bool)__unused unpin {
    return [SSignal complete];
}

- (bool)canCreateLinksToMessages {
    return false;
}

- (SSignal *)applyModerateMessageActions:(NSSet *)__unused actions messageIds:(NSArray *)__unused messageIds {
    return [SSignal fail:nil];
}

- (bool)canReportMessage:(TGMessage *)__unused message {
    return false;
}

- (void)reportMessageIndices:(NSArray *)messageIndices menuController:(TGMenuSheetController *)menuController {
    NSMutableArray *messageIds = [[NSMutableArray alloc] init];
    for (TGMessageIndex *index in messageIndices) {
        [messageIds addObject:@(index.messageId)];
    }
    
    TGModernConversationController *controller = self.controller;
    TGModernConversationCompanionReference *weakSelf = _ios4LifetimeReference;
    [[[TGCustomActionSheet alloc] initWithTitle:nil actions:@
    [
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"ReportPeer.ReasonSpam") action:@"spam"],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"ReportPeer.ReasonViolence") action:@"violence"],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"ReportPeer.ReasonPornography") action:@"pornography"],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"ReportPeer.ReasonCopyright") action:@"copyright"],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"ReportPeer.ReasonOther") action:@"other"],
     [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]] menuController:menuController advancedActionBlock:^(__unused TGMenuSheetController *controller, __unused id target, NSString *action) {
          TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
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
                      
                      [[[[TGAccountSignals reportMessages:[strongSelf requestPeerId] accessHash:[strongSelf requestAccessHash] messageIds:messageIds reason:reason otherText:otherText] deliverOn:[SQueue mainQueue]] onDispose:^{
                          TGDispatchOnMainThread(^{
                              [progressWindow dismiss:true];
                          });
                      }] startWithNext:nil error:^(__unused id error) {
                          [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"Login.UnknownError") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                      } completed:^{
                          TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
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
                      TGModernConversationCompanion *strongSelf = TGIOS4ResolveModernConversationCompanion(weakSelf);
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

- (void)_addedMessages:(NSArray *)__unused messages {
}

- (TGModernGalleryController *)galleryControllerForAvatar {
    return nil;
}

- (bool)canAddNewMessagesToTop {
    return true;
}

- (bool)isPeerAdmin {
    return false;
}

- (void)startVoiceCall {
}

- (bool)supportsCalls {
    return false;
}

- (bool)canAttachLinkPreviews {
    return true;
}

- (NSNumber *)inlineMediaRestrictionTimeout {
    return nil;
}

- (NSNumber *)mediaRestrictionTimeout {
    return nil;
}

- (NSNumber *)stickerRestrictionTimeout {
    return nil;
}

- (bool)messageSearchByUserAvailable {
    return false;
}

- (bool)messageSearchByDateAvailable {
    return false;
}

- (SSignal *)alphacodeListForQuery:(NSString *)query {
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        [subscriber putNext:[TGEmojiSuggestions suggestionsForQuery:query]];
        
        return nil;
    }] startOn:[SQueue concurrentDefaultQueue]];
}

- (void)performBotAutostart:(NSString *)__unused param {
}

- (bool)skipServiceMessages {
    return false;
}

@end
