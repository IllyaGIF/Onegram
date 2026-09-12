#import "TGDialogListController.h"

#import "../../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGDialogListCompanion.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGSearchDisplayMixin.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGListsTableView.h"

#import "../../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

#import "TGDialogListItem.h"

#import "TGDialogListCell.h"
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
#import "../../Telegraph/TGUserDataRequestBuilder.h"
#import "../TL/TLRPCusers_getUsers.h"

#import "TGLocalizationSignals.h"
#import "TGSuggestedLocalizationController.h"
#import "TGLocalizationSelectionController.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGTooltipView.h"

#import "TGProxySetupController.h"
#import "../../submodules/MtProtoKit/MTProtoKit/MTProtoKit.h"
#import "TGTelegramNetworking.h"

#import "TGLegacyComponentsContext.h"

#import "TGCreateFeedController.h"

#import "TGProxyBarButton.h"

#import "TGProxySignals.h"

#import "TGPresentation.h"
#import "../../Telegraph/TLUser$modernUser.h"
#import "TGDocumentMediaAttachment+Telegraph.h"
#import "../../legacy/TL/TLMetaRpc.h"
#import "../../legacy/TL/NSOutputStream+TL.h"
#import "../TL/TLInputPeer.h"
#import "../TL/TLInputDialogPeer.h"
#import "../TL/TLRPCmessages_getPeerDialogs.h"
#import "../TL/TLmessages_PeerDialogs.h"
#import "../../Telegraph/TGTelegraphDialogListCompanion.h"

@interface TGTelegraphDialogListCompanion (TGIOS6FoldersInternal)
- (void)initializeDialogListData:(TGConversation *)conversation customUser:(TGUser *)customUser selfUser:(TGUser *)selfUser;
@end

@interface TGGroupManagementSignals (TGIOS6FolderHydration)
+ (SSignal *)processedDialogs:(TLmessages_PeerDialogs *)result peerId:(int64_t)peerId;
@end

static const int32_t TGIOS6VectorConstructor = (int32_t)0x1cb5c415;

@interface TGIOS6GetCustomEmojiDocumentsRequest : TLMetaRpc
@property (nonatomic, strong) NSArray *documentIds;
@end

@implementation TGIOS6GetCustomEmojiDocumentsRequest
- (Class)responseClass { return [NSArray class]; }
- (int)impliedResponseSignature { return TGIOS6VectorConstructor; }
- (int)layerVersion { return 144; }
- (int32_t)TLconstructorSignature { return (int32_t)0xd9ab0f54; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values {}
- (void)TLserialize:(NSOutputStream *)os
{
    [os writeInt32:TGIOS6VectorConstructor];
    [os writeInt32:(int32_t)_documentIds.count];
    for (NSNumber *documentId in _documentIds)
        [os writeInt64:documentId.longLongValue];
}
- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error { return nil; }
@end

@interface TGIOS6GetDialogFiltersRequest : TLMetaRpc
@end

@implementation TGIOS6GetDialogFiltersRequest
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

extern "C" void TGIOS6LoadCustomEmojiThumbnail(int64_t documentId, void (^completion)(NSString *thumbnailUri))
{
    if (documentId == 0)
    {
        if (completion != nil)
            completion(nil);
        return;
    }

    static NSCache *cachedUris = nil;
    static NSMutableDictionary *inFlightCompletions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cachedUris = [[NSCache alloc] init];
        cachedUris.countLimit = 128;
        inFlightCompletions = [[NSMutableDictionary alloc] init];
    });

    NSNumber *documentKey = @(documentId);
    NSString *cachedUri = [cachedUris objectForKey:documentKey];
    if (cachedUri.length != 0)
    {
        if (completion != nil)
            completion(cachedUri);
        return;
    }

    @synchronized(inFlightCompletions)
    {
        if (completion != nil)
        {
            NSMutableArray *callbacks = inFlightCompletions[documentKey];
            if (callbacks != nil)
            {
                [callbacks addObject:[completion copy]];
                return;
            }
            inFlightCompletions[documentKey] = [NSMutableArray arrayWithObject:[completion copy]];
        }
        else if (inFlightCompletions[documentKey] != nil)
            return;
        else
            inFlightCompletions[documentKey] = [[NSMutableArray alloc] init];
    }

    TGIOS6GetCustomEmojiDocumentsRequest *request = [[TGIOS6GetCustomEmojiDocumentsRequest alloc] init];
    request.documentIds = @[ @(documentId) ];
    [[TGTelegramNetworking instance] performRpc:request completionBlock:^(id result, __unused int64_t responseTime, MTRpcError *error)
    {
        NSString *thumbnailUri = nil;
        if (error == nil && [result isKindOfClass:[NSArray class]])
        {
            for (id documentDesc in (NSArray *)result)
            {
                if (![documentDesc isKindOfClass:[TLDocument class]])
                    continue;
                TGDocumentMediaAttachment *document = [[TGDocumentMediaAttachment alloc] initWithTelegraphDocumentDesc:documentDesc];
                if (document.documentId == documentId)
                {
                    NSMutableString *uri = [[NSMutableString alloc] initWithString:@"sticker-preview://?"];
                    [uri appendFormat:@"documentId=%" PRId64, document.documentId];
                    [uri appendFormat:@"&accessHash=%" PRId64, document.accessHash];
                    [uri appendFormat:@"&datacenterId=%" PRId32, document.datacenterId];
                    TGMediaOriginInfo *originInfo = document.originInfo ?: [TGMediaOriginInfo mediaOriginInfoForDocumentAttachment:document];
                    if (originInfo != nil)
                        [uri appendFormat:@"&origin_info=%@", [originInfo stringRepresentation]];
                    NSString *legacyThumbnailUri = [document.thumbnailInfo imageUrlForLargestSize:NULL];
                    if (legacyThumbnailUri.length != 0)
                        [uri appendFormat:@"&legacyThumbnailUri=%@", [TGStringUtils stringByEscapingForURL:legacyThumbnailUri]];
                    [uri appendFormat:@"&fileName=%@", [TGStringUtils stringByEscapingForURL:[document safeFileName]]];
                    [uri appendFormat:@"&size=%d", document.size];
                    if (document.mimeType.length != 0)
                        [uri appendFormat:@"&mimeType=%@", [TGStringUtils stringByEscapingForURL:document.mimeType]];
                    [uri appendString:@"&width=40&height=40&highQuality=1"];
                    thumbnailUri = uri;
                    break;
                }
            }
        }

        if (thumbnailUri.length != 0)
            [cachedUris setObject:thumbnailUri forKey:documentKey];

        __block NSArray *callbacks = nil;
        @synchronized(inFlightCompletions)
        {
            callbacks = [inFlightCompletions[documentKey] copy];
            [inFlightCompletions removeObjectForKey:documentKey];
        }
        dispatch_async(dispatch_get_main_queue(), ^
        {
            for (void (^callback)(NSString *) in callbacks)
                callback(thumbnailUri);
        });
    } progressBlock:nil requiresCompletion:true requestClass:TGRequestClassGeneric];
}

static UIColor *TGDialogListNavigationTitleColor(TGPresentation *presentation)
{
    return presentation.pallete.navigationTitleColor;
}

static UIColor *TGDialogListNavigationSubtitleColor(TGPresentation *presentation)
{
    return presentation.pallete.navigationSubtitleColor;
}
#import "TGPreviewPresentationHelper.h"

static bool _debugDoNotJump = false;

static int64_t lastAppearedConversationId = 0;
static NSString *const TGIOS6ArchiveHeaderItem = @"TGIOS6ArchiveHeaderItem";
static NSString *const TGIOS6NewChatListGesturesKey = @"TGIOS6NewChatListGestures";
static NSString *const TGIOS6NewChatListGesturesChangedNotification = @"TGIOS6NewChatListGesturesChanged";

static UIImage *TGIOS6CenteredScaledBarIcon(UIImage *image, CGFloat scale)
{
    if (image == nil)
        return nil;

    UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale);
    CGSize size = CGSizeMake(floorf(image.size.width * scale), floorf(image.size.height * scale));
    CGRect rect = CGRectMake(floorf((image.size.width - size.width) / 2.0f), floorf((image.size.height - size.height) / 2.0f), size.width, size.height);
    [image drawInRect:rect];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
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

@interface TGDialogListController () <TGViewControllerNavigationBarAppearance, UITableViewDelegate, UITableViewDataSource, TGSearchDisplayMixinDelegate, TGCreateContactControllerDelegate, TGKeyCommandResponder, UIGestureRecognizerDelegate>
{
    std::map<int64_t, NSString *> _usersTypingInConversation;
    
    int64_t _scrollingToConversationId;
    int64_t _scheduledScrollToConversationId;
    int64_t _scheduledHighlightAnimationConversationId;
    
    UIView *_headerBackgroundView;
    
    NSArray *_reusableSectionHeaders;
    
    SMetaDisposable *_searchDisposable;
    NSString *_searchResultsQuery;
    
    SMetaDisposable *_recentSearchResultsDisposable;
    
    SVariable *_atTopPromise;
    SPipe *_visibleConversationsPipe;
    
    bool _didSelectMessage;
    bool _didSelectGlobalResult;
    bool _ios6SearchPullArmed;
    
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
    
    UIBarButtonItem *_proxyItem;
    TGProxyBarButton *_proxyButton;
    
    SMetaDisposable *_proxyStateDisposable;
    bool _hasAnyProxy;
    bool _hasSelectedProxy;
    bool _alwaysShowProxy;
    TGDialogListState _state;
    
    bool _needsUpdate;
    TGDialogListControllerReference *_ios6LifetimeReference;
    bool _ios6ArchiveExpanded;
    bool _ios6ArchiveRefreshRequested;
    bool _ios6ArchiveItemsLoadRequested;
    NSSet *_ios6ArchivePeerIds;
    NSArray *_ios6DialogFilters;
    int32_t _ios6SelectedDialogFilterId;
    SMetaDisposable *_ios6DialogFiltersDisposable;
    SMetaDisposable *_ios6FolderPeerHydrationDisposable;
    NSMutableArray *_ios6FolderPeerHydrationQueue;
    bool _ios6FolderPeerHydrationActive;
    int _ios6FolderPeerHydrationLoaded;
    int _ios6FolderPeerHydrationFailed;
    NSTimeInterval _ios6DialogFiltersLastRefreshTime;
    int _ios6DialogFiltersAuthorizationRetryCount;
    bool _ios6DialogFiltersAuthorizationRetryScheduled;
    UIScrollView *_ios6FolderTabsScrollView;
    UIView *_ios6FolderTabsView;
    UIView *_ios6FolderTabsSeparatorView;
    UILabel *_ios6FolderEmptyLabel;
    UIPanGestureRecognizer *_ios6FolderPanGestureRecognizer;
    UILongPressGestureRecognizer *_ios6ChatActionsLongPressRecognizer;
    UIImageView *_ios6FolderSwipeSourceView;
    UIImageView *_ios6FolderSwipeTabsView;
    UIView *_ios6FolderSwipeIndicatorView;
    NSInteger _ios6FolderSwipeSourceIndex;
    NSInteger _ios6FolderSwipeTargetIndex;
    int32_t _ios6FolderSwipeSourceFilterId;
    int32_t _ios6FolderSwipeTargetFilterId;
    CGPoint _ios6FolderSwipeSourceContentOffset;
    CGRect _ios6FolderSwipeContentFrame;
    CGRect _ios6FolderSwipeSourceIndicatorFrame;
    CGRect _ios6FolderSwipeTargetIndicatorFrame;
    CGFloat _ios6FolderSwipeTargetOffset;
    bool _ios6FolderSwipeActive;
    bool _ios6FolderSwipeFinishing;
    bool _ios6FolderSwipePreviousViewClipsToBounds;
    NSArray *_ios6AllDialogItems;
    NSTimeInterval _ios6AllDialogItemsLastRefreshTime;
    bool _ios6AllDialogItemsLoading;
    bool _ios6LazyLoadScheduled;
    NSArray *_ios6VisibleListCache;
    int32_t _ios6VisibleListCacheFilterId;
    NSString *_ios6FolderTabsStateKey;
    bool _ios6FolderTabsUpdatePending;
    NSTimeInterval _lastOwnEmojiStatusRefreshTime;
    bool _ownEmojiStatusRefreshInFlight;
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
@property (nonatomic, strong) TGRemoteImageView *titleEmojiStatusView;
@property (nonatomic) int64_t titleEmojiStatusDocumentId;

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
@property (nonatomic, copy) void (^toggleArchiveConversation)(int64_t, bool);

- (bool)ios6NewChatListGesturesEnabled;
- (void)ios6UpdateNewChatListGesturesState;
- (void)ios6NewChatListGesturesChanged:(NSNotification *)notification;
- (NSInteger)ios6SelectedDialogFilterIndex;
- (void)ios6SelectDialogFilterAtIndex:(NSInteger)index;
- (void)ios6CompleteDialogFilterSelectionAtIndex:(NSInteger)index;
- (CGRect)ios6FolderSwipeTabsRect;
- (CGRect)ios6FolderSwipeContentRect;
- (UIImage *)ios6FolderSwipeSnapshotForRect:(CGRect)rect;
- (void)ios6BeginFolderSwipeToIndex:(NSInteger)targetIndex translation:(CGPoint)translation;
- (void)ios6UpdateFolderSwipeWithTranslation:(CGPoint)translation;
- (void)ios6FinishFolderSwipeCommit:(bool)commit velocity:(CGPoint)velocity;
- (void)ios6CancelFolderSwipeImmediately;
- (void)ios6FolderPanGesture:(UIPanGestureRecognizer *)recognizer;
- (void)ios6ChatActionsLongPress:(UILongPressGestureRecognizer *)recognizer;

@end

NSString *authorNameYou = @"  __TGLocalized__YOU";

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
        [_atTopPromise set:[SSignal single:@true]];
        
        _visibleConversationsPipe = [[SPipe alloc] init];
        
        __weak TGDialogListController *weakSelf = self;
        
        _listModel = [[NSMutableArray alloc] init];
        _ios6LifetimeReference = [[TGDialogListControllerReference alloc] init];
        [_ios6LifetimeReference setValue:self];
        _ios6DialogFilters = @[];
        _ios6AllDialogItems = @[];
        _ios6VisibleListCacheFilterId = INT32_MIN;
        _ios6SelectedDialogFilterId = (int32_t)[[NSUserDefaults standardUserDefaults] integerForKey:@"TGIOS6SelectedDialogFilterId"];
        _ios6DialogFiltersDisposable = [[SMetaDisposable alloc] init];
        _ios6FolderPeerHydrationDisposable = [[SMetaDisposable alloc] init];
        _ios6FolderPeerHydrationQueue = [[NSMutableArray alloc] init];
        
        _reusableSectionHeaders = [[NSArray alloc] initWithObjects:[[NSMutableArray alloc] init], [[NSMutableArray alloc] init], nil];
        
        _dialogListCompanion = companion;
        _dialogListCompanion.dialogListController = self;
        
        _significantTimeChangeProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(significantTimeChange:) name:UIApplicationSignificantTimeChangeNotification];
        _didEnterBackgroundProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification];
        _willEnterForegroundProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ios6ArchivePeerIdsUpdated:) name:@"TGIOS6ArchivePeerIdsUpdated" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ios6ClearChatCacheRequested:) name:@"TGIOS6ClearChatListCacheRequested" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ios6DialogFiltersUpdated:) name:@"TGIOS6DialogFiltersUpdated" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ios6NewChatListGesturesChanged:) name:TGIOS6NewChatListGesturesChangedNotification object:nil];
        
        _doNotHideSearchAutomatically = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
        
        _proxyButton = [[TGProxyBarButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 44.0f, 44.0f)];
        _proxyButton.portraitAdjustment = CGPointMake(22, 12);
        _proxyButton.landscapeAdjustment = CGPointMake(22, 5);
        [_proxyButton addTarget:self action:@selector(openProxySettings) forControlEvents:UIControlEventTouchUpInside];
        _proxyItem = [[UIBarButtonItem alloc] initWithCustomView:_proxyButton];
        
        SSignal *currentSignal = [[TGProxySignals currentSignal] map:^id(id value) {
            if (value != nil)
                return value;
            else
                return [NSNull null];
        }];
        
        SSignal *blockedModeSignal = [[TGDatabaseInstance() customPropertySignal:@"blockedMode"] map:^NSNumber *(NSData *data)
        {
            int32_t value = 0;
            [data getBytes:&value];
            
            return @(value > 0);
        }];
        
        _proxyStateDisposable = [[SMetaDisposable alloc] init];
        [_proxyStateDisposable setDisposable:[[[SSignal combineSignals:@[[TGProxySignals listSignal], currentSignal, blockedModeSignal] withInitialStates:@[ @[], [NSNull null], @false ]] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *next)
        {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                bool hasAnyProxy = ((NSArray *)next[0]).count > 0;
                bool hasSelectedProxy = [(NSArray *)next[1] isKindOfClass:[TGProxyItem class]];
                bool alwaysShowProxy = [next[2] boolValue];
                
                strongSelf->_hasAnyProxy = hasAnyProxy;
                strongSelf->_hasSelectedProxy = hasSelectedProxy;
                strongSelf->_alwaysShowProxy = alwaysShowProxy;
                [strongSelf updateProxyButton];
            }
        }]];
        
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
                    TGConversation *conversation = (TGConversation *)[strongSelf ios6DialogListItemAtIndexPath:indexPath];
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
                    TGConversation *conversation = (TGConversation *)[strongSelf ios6DialogListItemAtIndexPath:indexPath];
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
        self.toggleArchiveConversation = ^(int64_t peerId, bool archived) {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            NSIndexPath *indexPath = [strongSelf indexPathForConversationId:peerId];
            TGConversation *conversation = indexPath == nil ? nil : (TGConversation *)[strongSelf ios6DialogListItemAtIndexPath:indexPath];
            if (![conversation isKindOfClass:[TGConversation class]] || conversation.isArchived == archived)
                return;

            [(TGDialogListCell *)[strongSelf->_tableView cellForRowAtIndexPath:indexPath] setEditingConrolsExpanded:false animated:true];
            [TGTelegraphInstance doSetConversationArchived:peerId accessHash:conversation.accessHash archived:archived completion:nil];
            conversation.isArchived = archived;
            [TGDatabaseInstance() setConversationArchived:peerId archived:archived];

            NSMutableSet *peerIds = [[NSMutableSet alloc] initWithSet:strongSelf->_ios6ArchivePeerIds ?: [NSSet set]];
            if (archived)
                [peerIds addObject:@(peerId)];
            else
                [peerIds removeObject:@(peerId)];
            strongSelf->_ios6ArchivePeerIds = peerIds;
            [TGDatabaseInstance() setCustomProperty:@"ios6ArchivePeerIds" value:[NSKeyedArchiver archivedDataWithRootObject:peerIds.allObjects]];
            [strongSelf updateBarButtonItemsAnimated:false];
            [strongSelf->_tableView reloadData];
        };
        self.toggleGroupConversation = ^(int64_t peerId, bool group)
        {
            __strong TGDialogListController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                NSIndexPath *indexPath = [strongSelf indexPathForConversationId:peerId];
                if (indexPath != nil) {
                    TGConversation *conversation = (TGConversation *)[strongSelf ios6DialogListItemAtIndexPath:indexPath];
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
                    TGConversation *conversation = (TGConversation *)[strongSelf ios6DialogListItemAtIndexPath:indexPath];
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
    [_ios6LifetimeReference invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"TGIOS6ArchivePeerIdsUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"TGIOS6ClearChatListCacheRequested" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"TGIOS6DialogFiltersUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGIOS6NewChatListGesturesChangedNotification object:nil];
    [_ios6DialogFiltersDisposable dispose];
    [_ios6FolderPeerHydrationDisposable dispose];
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    
    _dialogListCompanion.dialogListController = nil;
    
    [self doUnloadView];
    
    [_proxyStateDisposable dispose];
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
    id item = [self ios6DialogListItemAtIndexPath:indexPath];
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

- (NSIndexPath *)indexPathForConversationId:(int64_t)conversationId {
    NSUInteger index = 0;
    for (id item in [self ios6VisibleListModel]) {
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
        _titleStatusLabel.textColor = TGDialogListNavigationTitleColor(_presentation);
        _titleStatusLabel.shadowColor = [UIColor clearColor];
        _titleStatusLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
        _titleStatusLabel.font = TGBoldSystemFontOfSize(16.0f);
        [_titleContainer addSubview:_titleStatusLabel];
        
        _titleStatusSubtitleLabel = [[UILabel alloc] init];
        _titleStatusSubtitleLabel.clipsToBounds = false;
        _titleStatusSubtitleLabel.backgroundColor = [UIColor clearColor];
        _titleStatusSubtitleLabel.textColor = TGDialogListNavigationSubtitleColor(_presentation);
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

- (UIBarButtonItem *)ios6ArchiveBarButtonItem
{
    if (_ios6SelectedDialogFilterId != 0)
        return nil;

    if ([TGPresentation classicIOS6Style])
        return [[UIBarButtonItem alloc] initWithTitle:(_ios6ArchiveExpanded ? @"Chats" : @"Archive") style:UIBarButtonItemStyleBordered target:self action:@selector(archiveButtonPressed:)];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0.0f, 0.0f, 70.0f, 44.0f);
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.titleLabel.font = TGSystemFontOfSize(17.0f);
    [button setTitle:(_ios6ArchiveExpanded ? @"Chats" : @"Archive") forState:UIControlStateNormal];
    [button setTitleColor:self.presentation.pallete.navigationButtonColor forState:UIControlStateNormal];
    [button setTitleColor:[self.presentation.pallete.navigationButtonColor colorWithAlphaComponent:0.4f] forState:UIControlStateHighlighted];
    [button addTarget:self action:@selector(archiveButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    return [[UIBarButtonItem alloc] initWithCustomView:button];
}

- (UIBarButtonItem *)controllerLeftBarButtonItem
{
    return [self ios6ArchiveBarButtonItem];
}

- (void)scrollToTopRequested
{
    if (_ios6ArchiveExpanded)
    {
        _ios6ArchiveExpanded = false;
        [self updateBarButtonItemsAnimated:false];
        [_tableView reloadData];
        if ([self ios6VisibleListModel].count != 0)
            [_tableView setContentOffset:CGPointMake(0.0f, -_tableView.contentInset.top) animated:false];
        return;
    }

    [self scrollToTop];
    //if (!_searchMixin.isActive)
    //    [self.dialogListCompanion scrollToNextUnreadChat];
}

- (void)scrollToTop
{
    [_tableView scrollToTop];
}

- (void)titleStateUpdated:(NSString *)text state:(TGDialogListState)state
{
    _state = state;
    [self updateProxyButton];
    
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
}

- (bool)isVisible
{
    return self.navigationController.topViewController == TGAppDelegateInstance.rootController.mainTabsController && TGAppDelegateInstance.rootController.mainTabsController.selectedIndex == 2;
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
    if (_editingMode)
        return nil;
    
    NSMutableArray *items = [[NSMutableArray alloc] init];
    UIBarButtonItem *compose = nil;
    if ([TGPresentation classicIOS6Style])
    {
        UIImage *composeImage = TGTintedImage([UIImage imageNamed:@"ModernNavigationComposeButtonIcon.png"], [UIColor whiteColor]);
        composeImage = TGIOS6CenteredScaledBarIcon(composeImage, 0.70f);
        compose = [[UIBarButtonItem alloc] initWithImage:composeImage style:UIBarButtonItemStyleBordered target:self action:@selector(composeMessageButtonPressed:)];
    }
    else if (iosMajorVersion() < 7)
    {
        TGModernBarButton *composeButton = [[TGModernBarButton alloc] initWithImage:TGTintedImage([UIImage imageNamed:@"ModernNavigationComposeButtonIcon.png"], self.presentation.pallete.navigationButtonColor)];
        composeButton.portraitAdjustment = CGPointMake(-7, -5);
        composeButton.landscapeAdjustment = CGPointMake(-7, -4);
        [composeButton addTarget:self action:@selector(composeMessageButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        compose = [[UIBarButtonItem alloc] initWithCustomView:composeButton];
    }
    else
    {
        UIButton *composeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        composeButton.frame = CGRectMake(0.0f, 0.0f, 44.0f, 44.0f);
        composeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        UIImage *composeImage = TGTintedImage([UIImage imageNamed:@"ModernNavigationComposeButtonIcon.png"], self.presentation.pallete.navigationButtonColor);
        [composeButton setImage:composeImage forState:UIControlStateNormal];
        composeButton.imageEdgeInsets = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 2.0f);
        [composeButton addTarget:self action:@selector(composeMessageButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        compose = [[UIBarButtonItem alloc] initWithCustomView:composeButton];
    }
    
    [items addObject:compose];
    [items addObject:_proxyItem];
    
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
    
    CGRect titleLabelFrame = _titleLabel.frame;
    titleLabelFrame.origin = CGPointMake(CGFloor((_titleContainer.frame.size.width - titleLabelFrame.size.width) / 2.0f), CGFloor((_titleContainer.frame.size.height - titleLabelFrame.size.height) / 2.0f) + (UIInterfaceOrientationIsPortrait(orientation) ? portraitOffset : landscapeOffset));
    if (_titleLockIconView.alpha > FLT_EPSILON)
        titleLabelFrame.origin.x -= 4.0f;
    _titleLockIconView.frame = CGRectMake(CGRectGetMaxX(titleLabelFrame) + 6.0f, titleLabelFrame.origin.y + 4.0f, _titleLockIconView.frame.size.width, _titleLockIconView.frame.size.height);
    _titleLabel.frame = titleLabelFrame;
    if (!_titleEmojiStatusView.hidden)
        _titleEmojiStatusView.frame = CGRectMake(CGRectGetMaxX(titleLabelFrame) + 4.0f, floorf((self->_titleContainer.frame.size.height - 18.0f) / 2.0f), 18.0f, 18.0f);
    
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
    
    if (iosMajorVersion() >= 5)
        self.view.accessibilityElementsHidden = true;
    else
        self.view.isAccessibilityElement = false;
    
    [self setTitleText:TGLocalized(@"DialogList.Title")];
    
    _titleContainer = [[TGDialogListTitleContainer alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 2.0f, 2.0f)];
    [self setTitleView:_titleContainer];
    
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.textColor = TGDialogListNavigationTitleColor(self.presentation);
    _titleLabel.shadowColor = [UIColor clearColor];
    _titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
    _titleLabel.font = TGBoldSystemFontOfSize(17.0f);
    _titleLabel.text = TGLocalized(@"DialogList.Title");
    [_titleLabel sizeToFit];
    [_titleContainer addSubview:_titleLabel];

    _titleEmojiStatusView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 18.0f, 18.0f)];
    _titleEmojiStatusView.contentMode = UIViewContentModeScaleAspectFit;
    _titleEmojiStatusView.hidden = true;
    [_titleContainer addSubview:_titleEmojiStatusView];
    [self updateTitleEmojiStatus];
    
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
    
    //[self setExplicitTableInset:UIEdgeInsetsMake(-1.0f, 0.0f, 0.0f, 0.0f)];

    [(TGListsTableView *)_tableView adjustBehaviour];
    
    _tableView.showsVerticalScrollIndicator = true;
    
    if (!_dialogListCompanion.feedChannels)
    {
        _searchBar = [[TGSearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, [TGSearchBar searchBarBaseHeight]) style:TGSearchBarStyleLightPlain];
        _searchBar.pallete = self.presentation.searchBarPallete;
        _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _searchBar.safeAreaInset = [self controllerSafeAreaInset];
        
        _searchTopBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, -320.0f, self.view.frame.size.width, 320.0f)];
        _searchTopBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_tableView insertSubview:_searchTopBackgroundView atIndex:0];
        
        _searchMixin = [[TGSearchDisplayMixin alloc] init];
        _searchMixin.searchBar = _searchBar;
        _searchMixin.delegate = self;
        
        _tableView.tableHeaderView = _searchBar;
        
        _searchBar.placeholder = TGLocalized(self.customSearchPlaceholder ?: @"DialogList.SearchLabel");
    }
    
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    if (iosMajorVersion() >= 7) {
        _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        _tableView.separatorColor = _presentation.pallete.separatorColor;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        _tableView.separatorInset = UIEdgeInsetsMake(0.0f, 80.0f, 0.0f, 0.0f);
#endif
    }
    
    _tableView.alwaysBounceVertical = true;
    _tableView.bounces = true;
    
    _tableView.tableFooterView = [[UIView alloc] init];
    
    [self setTableHidden:_listModel.count == 0];
    
    [self resetInitialOffset];
    
    [self.view addSubview:_tableView];

    _ios6FolderPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(ios6FolderPanGesture:)];
    _ios6FolderPanGestureRecognizer.delegate = self;
    _ios6FolderPanGestureRecognizer.maximumNumberOfTouches = 1;
    _ios6FolderPanGestureRecognizer.cancelsTouchesInView = false;
    [self.view addGestureRecognizer:_ios6FolderPanGestureRecognizer];
    if ([_tableView respondsToSelector:@selector(panGestureRecognizer)])
        [_tableView.panGestureRecognizer requireGestureRecognizerToFail:_ios6FolderPanGestureRecognizer];

    _ios6ChatActionsLongPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(ios6ChatActionsLongPress:)];
    _ios6ChatActionsLongPressRecognizer.minimumPressDuration = 0.45;
    _ios6ChatActionsLongPressRecognizer.cancelsTouchesInView = true;
    [_tableView addGestureRecognizer:_ios6ChatActionsLongPressRecognizer];

    [self ios6UpdateNewChatListGesturesState];

    _ios6FolderTabsView = [[UIView alloc] initWithFrame:CGRectZero];
    _ios6FolderTabsView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _ios6FolderTabsView.backgroundColor = [TGPresentation classicIOS6Style] ? UIColorRGB(0xf7f7f7) : self.presentation.pallete.backgroundColor;
    _ios6FolderTabsView.hidden = false;
    _ios6FolderTabsScrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _ios6FolderTabsScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _ios6FolderTabsScrollView.backgroundColor = [UIColor clearColor];
    _ios6FolderTabsScrollView.showsHorizontalScrollIndicator = false;
    _ios6FolderTabsScrollView.showsVerticalScrollIndicator = false;
    _ios6FolderTabsScrollView.alwaysBounceHorizontal = false;
    [_ios6FolderTabsView addSubview:_ios6FolderTabsScrollView];

    _ios6FolderTabsSeparatorView = [[UIView alloc] initWithFrame:CGRectZero];
    _ios6FolderTabsSeparatorView.backgroundColor = [TGPresentation classicIOS6Style] ? UIColorRGB(0xc8c8c8) : self.presentation.pallete.separatorColor;
    [_ios6FolderTabsView addSubview:_ios6FolderTabsSeparatorView];

    _ios6FolderEmptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _ios6FolderEmptyLabel.backgroundColor = [UIColor clearColor];
    _ios6FolderEmptyLabel.textAlignment = NSTextAlignmentCenter;
    _ios6FolderEmptyLabel.textColor = [TGPresentation classicIOS6Style] ? UIColorRGB(0x8e8e93) : self.presentation.pallete.secondaryTextColor;
    _ios6FolderEmptyLabel.font = TGSystemFontOfSize(15.0f);
    _ios6FolderEmptyLabel.text = @"Нет чатов";
    _ios6FolderEmptyLabel.hidden = true;
    _ios6FolderEmptyLabel.userInteractionEnabled = false;
    [self.view addSubview:_ios6FolderEmptyLabel];
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];

    _ios6FolderTabsStateKey = nil;
    _ios6FolderTabsUpdatePending = false;
    [self ios6UpdateFolderTabs];
    [self ios6LayoutFolderTabs];
    [self ios6ReloadDialogFilters:false];
}

- (void)doUnloadView
{
    [self ios6CancelFolderSwipeImmediately];

    if (_ios6FolderPanGestureRecognizer != nil)
    {
        _ios6FolderPanGestureRecognizer.delegate = nil;
        [_ios6FolderPanGestureRecognizer.view removeGestureRecognizer:_ios6FolderPanGestureRecognizer];
        _ios6FolderPanGestureRecognizer = nil;
    }

    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    _tableView = nil;
    
    _searchBar = nil;
    _ios6FolderTabsScrollView = nil;
    _ios6FolderTabsView = nil;
    _ios6FolderTabsSeparatorView = nil;
    _ios6FolderEmptyLabel = nil;
    _ios6FolderTabsStateKey = nil;
    _ios6FolderTabsUpdatePending = false;
    _ios6ChatActionsLongPressRecognizer = nil;
    
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
        _tableView.contentOffset = CGPointMake(0.0f, -_tableView.contentInset.top + [TGSearchBar searchBarBaseHeight] + self.explicitTableInset.top);
        _ios6SearchPullArmed = false;
    }
}

- (void)updateTitleEmojiStatus
{
    TGUser *user = [TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId];
    int64_t documentId = user.emojiStatusDocumentId;
    if (documentId == 0)
    {
        _titleEmojiStatusDocumentId = 0;
        [_titleEmojiStatusView cancelLoading];
        _titleEmojiStatusView.hidden = true;
        [self _layoutTitleViews:self.interfaceOrientation];
        return;
    }
    _titleEmojiStatusDocumentId = documentId;
    [_titleEmojiStatusView cancelLoading];
    _titleEmojiStatusView.hidden = true;
    [self _layoutTitleViews:self.interfaceOrientation];
    __weak TGDialogListController *weakSelf = self;
    TGIOS6LoadCustomEmojiThumbnail(documentId, ^(NSString *thumbnailUri)
    {
        TGDialogListController *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_titleEmojiStatusDocumentId != documentId || thumbnailUri.length == 0)
            return;
        [strongSelf->_titleEmojiStatusView loadImage:thumbnailUri filter:nil placeholder:nil];
        strongSelf->_titleEmojiStatusView.hidden = false;
        [strongSelf _layoutTitleViews:strongSelf.interfaceOrientation];
    });
}

- (void)refreshOwnEmojiStatusIfNeeded
{
    int32_t clientUserId = TGTelegraphInstance.clientUserId;
    if (clientUserId == 0 || _ownEmojiStatusRefreshInFlight)
        return;

    TGUser *cachedUser = [TGDatabaseInstance() loadUser:clientUserId];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval refreshInterval = cachedUser.emojiStatusDocumentId == 0 ? 30.0 : 300.0;
    if (_lastOwnEmojiStatusRefreshTime > 0.0 && now - _lastOwnEmojiStatusRefreshTime < refreshInterval)
        return;

    _lastOwnEmojiStatusRefreshTime = now;
    _ownEmojiStatusRefreshInFlight = true;

    TLRPCusers_getUsers$users_getUsers *request = [[TLRPCusers_getUsers$users_getUsers alloc] init];
    request.n_id = @[ [TGTelegraphInstance createInputUserForUid:clientUserId] ];
    __weak TGDialogListController *weakSelf = self;
    [[TGTelegramNetworking instance] performRpc:request completionBlock:^(id result, __unused int64_t responseTime, MTRpcError *error)
    {
        if (error == nil && [result isKindOfClass:[NSArray class]])
            [TGUserDataRequestBuilder executeUserDataUpdate:(NSArray *)result];

        dispatch_async(dispatch_get_main_queue(), ^
        {
            TGDialogListController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            strongSelf->_ownEmojiStatusRefreshInFlight = false;
            [strongSelf updateTitleEmojiStatus];
        });
    } progressBlock:nil requiresCompletion:true requestClass:TGRequestClassGeneric];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self refreshOwnEmojiStatusIfNeeded];
    [self updateTitleEmojiStatus];
    [self ios6ReloadDialogFilters:false];
    [self ios6RefreshAllDialogItems:false];
    
    [self updateProxyButton];
    
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
                NSArray *visibleItems = [self ios6VisibleListModel];
                for (TGConversation *conversation in visibleItems)
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
                            CGRect convertRect = [_tableView convertRect:[_tableView rectForRowAtIndexPath:indexPath] toView:self.view];
                            if (convertRect.origin.y + convertRect.size.height > self.view.frame.size.height - self.controllerInset.bottom)
                                scrollPosition = UITableViewScrollPositionBottom;
                            else if (convertRect.origin.y < self.controllerInset.top)
                                scrollPosition = UITableViewScrollPositionTop;
                        }
                        else
                        {
                            TGLog(@"ARCHIVE viewWillAppear stale index row=%d rows=%d visible=%d", index, (int)[_tableView numberOfRowsInSection:1], (int)visibleItems.count);
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

- (void)viewDidAppear:(BOOL)animated
{
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
    if (iosMajorVersion() >= 7)
        [_searchMixin resignResponderIfAny];
    
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    _isOnScreen = false;
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
    [self ios6LayoutFolderTabs];
    
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
    [self ios6ReloadDialogFilters:true];
    [self ios6RefreshAllDialogItems:true];
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
    _ios6VisibleListCache = nil;
    _ios6VisibleListCacheFilterId = INT32_MIN;
    NSMutableDictionary *temporaryImageCache = [[NSMutableDictionary alloc] init];
    int64_t peerIdWithActiveEditingControls = 0;
    NSMutableDictionary *previousFrames = nil;
    if (animateFrameTransitions) {
        previousFrames = [[NSMutableDictionary alloc] init];
    }
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
            
            previousFrames[@(dialogCell.conversationId)] = [NSValue valueWithCGRect:dialogCell.frame];
            if ([dialogCell isEditingControlsExpanded]) {
                peerIdWithActiveEditingControls = dialogCell.conversationId;
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
                    [dialogCell setEditingConrolsExpanded:true animated:false];
                }
                if (animateFrameTransitions) {
                    NSValue *nFrame = previousFrames[@(dialogCell.conversationId)];
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
    
    [self ios6LayoutFolderTabs];
    [self ios6UpdateFolderTabs];
    [self ios6UpdateFolderEmptyLabel];
    _visibleConversationsPipe.sink(@true);
}

- (void)resetState
{
    [self setTableHidden:true];
    
    _hasSelectedProxy = false;
    
    [_emptyListContainer removeFromSuperview];
    _emptyListContainer = nil;
}

- (void)ios6ScheduleLazyLoadMoreItems:(int)limit
{
    if (_ios6LazyLoadScheduled || _isLoading || !_canLoadMore || _ios6ArchiveExpanded)
        return;

    _ios6LazyLoadScheduled = true;
    _isLoading = true;
    dispatch_async(dispatch_get_main_queue(), ^
    {
        _ios6LazyLoadScheduled = false;
        if (!_canLoadMore || _ios6ArchiveExpanded || _dialogListCompanion == nil)
        {
            _isLoading = false;
            return;
        }

        [_dialogListCompanion loadMoreItems:limit];
    });
}

- (void)dialogListFullyReloaded:(NSArray *)items
{
    [self ios6ReloadArchivePeerIds];
    
    if (_listModel.count == 0)
        [self resetInitialOffset];

    _isLoading = false;
    
    int64_t selectedConversation = INT64_MAX;
    NSIndexPath *selectedIndexPath = [_tableView indexPathForSelectedRow];
    if (selectedIndexPath != nil)
    {
        TGConversation *conversation = (TGConversation *)[self ios6DialogListItemAtIndexPath:selectedIndexPath];
        if ([conversation isKindOfClass:[TGConversation class]])
            selectedConversation = conversation.conversationId;
    }
    
    [_listModel removeAllObjects];
    [_listModel addObjectsFromArray:items];
    [self ios6ApplyArchivePeerIdsToListModel];
    if (_ios6ArchiveExpanded && [self ios6ArchivedConversationCount] == 0)
        _ios6ArchiveExpanded = false;
    [self ios6LogArchiveDiagnostics:@"reload"];
    
    [self reloadData:_reloadWithAnimations];
    [self updateBarButtonItemsAnimated:false];
    _reloadWithAnimations = false;
    
    if (selectedConversation != INT64_MAX && selectedConversation != 0)
    {
        int index = -1;
        NSArray *visibleItems = [self ios6VisibleListModel];
        for (id item in visibleItems)
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
        TGLog(@"Dialog list reloaded");
    });
    
    [self updateEmptyListContainer];
    
    bool ios6FolderPreloadActive = [_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]] && [(TGTelegraphDialogListCompanion *)_dialogListCompanion ios6FolderPreloadActive];
    if (!ios6FolderPreloadActive && !_ios6ArchiveExpanded && _canLoadMore && !_isLoading && [self ios6VisibleListModel].count < 8 && _listModel.count != 0)
    {
        TGLog(@"ARCHIVE lazy.fill normal visible=%d model=%d", (int)[self ios6VisibleListModel].count, (int)_listModel.count);
        [self ios6ScheduleLazyLoadMoreItems:15];
    }
    
    if (_scheduledScrollToConversationId != 0)
    {
        if (!_searchMixin.isActive)
            [self scrollToConversationWithId:_scheduledScrollToConversationId];
        else
            _scheduledScrollToConversationId = 0;
    }
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
    //_tableView.hidden = tableHidden;
    self.view.backgroundColor = _presentation.pallete.backgroundColor; //[_dialogListCompanion.dialogListCellAssetsSource dialogListBackgroundColor];
}

- (void)updateConversations:(NSDictionary *)dict {
    _ios6VisibleListCache = nil;
    _ios6VisibleListCacheFilterId = INT32_MIN;
    NSUInteger archivedCountBefore = [self ios6ArchivedConversationCount];
    for (NSUInteger i = 0; i < _listModel.count; i++) {
        TGConversation *conv = ((TGConversation *)_listModel[i]);
        TGConversation *conversation = dict[@(conv.conversationId)];
        if (conversation != nil) {
            [_listModel replaceObjectAtIndex:i withObject:conversation];
        }
    }
    [self ios6ApplyArchivePeerIdsToListModel];
    NSUInteger archivedCountAfter = [self ios6ArchivedConversationCount];
    if (archivedCountBefore != archivedCountAfter)
    {
        TGLog(@"ARCHIVE update.reload archivedBefore=%d archivedAfter=%d", (int)archivedCountBefore, (int)archivedCountAfter);
        if (_ios6ArchiveExpanded && archivedCountAfter == 0)
            _ios6ArchiveExpanded = false;
        [self updateBarButtonItemsAnimated:false];
        [_tableView reloadData];
        _visibleConversationsPipe.sink(@true);
        [self updateSearchBarBackground];
        return;
    }
    
    for (TGDialogListCell *cell in _tableView.visibleCells) {
        if ([cell isKindOfClass:[TGDialogListCell class]]) {
            id<TGDialogListItem> conversation = dict[@(cell.conversationId)];
            if ([conversation isKindOfClass:[TGConversation class]]) {
                [self prepareCell:cell forConversation:(TGConversation *)conversation animated:true isSearch:false];
            } else if ([conversation isKindOfClass:[TGFeed class]]) {
                [self prepareCell:cell forFeed:(TGFeed *)conversation animated:true];
            }
        }
    }
    
    _visibleConversationsPipe.sink(@true);
}

- (void)dialogListItemsChanged:(NSArray *)insertedIndices insertedItems:(NSArray *)__unused insertedItems updatedIndices:(NSArray *)updatedIndices updatedItems:(NSArray *)updatedItems removedIndices:(NSArray *)removedIndices
{
    NSArray *previousVisibleItems = [[self ios6VisibleListModel] copy];
    int countBefore = (int)_listModel.count;

    for (NSNumber *nRemovedIndex in removedIndices)
    {
        [_listModel removeObjectAtIndex:[nRemovedIndex intValue]];
    }

    int index = -1;
    for (NSNumber *nUpdatedIndex in updatedIndices)
    {
        index++;
        [_listModel replaceObjectAtIndex:[nUpdatedIndex intValue] withObject:[updatedItems objectAtIndex:index]];
    }

    _ios6VisibleListCache = nil;
    _ios6VisibleListCacheFilterId = INT32_MIN;
    NSArray *currentVisibleItems = [self ios6VisibleListModel];

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
        NSMutableDictionary *itemsByPeerId = [[NSMutableDictionary alloc] initWithCapacity:currentVisibleItems.count];
        for (id item in currentVisibleItems)
        {
            int64_t peerId = 0;
            if ([item isKindOfClass:[TGConversation class]])
                peerId = ((TGConversation *)item).conversationId;
            else if ([item isKindOfClass:[TGFeed class]])
                peerId = ((TGFeed *)item).conversationId;
            if (peerId != 0)
                itemsByPeerId[@(peerId)] = item;
        }

        for (TGDialogListCell *cell in _tableView.visibleCells)
        {
            if (![cell isKindOfClass:[TGDialogListCell class]])
                continue;

            id item = itemsByPeerId[@(cell.conversationId)];
            if ([item isKindOfClass:[TGConversation class]])
                [self prepareCell:cell forConversation:(TGConversation *)item animated:true isSearch:false];
            else if ([item isKindOfClass:[TGFeed class]])
                [self prepareCell:cell forFeed:(TGFeed *)item animated:true];
        }

        [self updateIsLastCell];
        [self ios6UpdateFolderTabs];
    }
    else
    {
        [_tableView reloadData];
        [self ios6UpdateFolderTabs];
    }

    _visibleConversationsPipe.sink(@true);

    if ((countBefore == 0) != (_listModel.count == 0))
    {
        [self updateEmptyListContainer];

        if (_listModel.count == 0)
            [self setupEditingMode:false setupTable:true];
    }

    [self updateSearchBarBackground];
}

- (void)updateSearchBarBackground {
    bool topIsPinned = false;
    NSArray *visibleItems = [self ios6VisibleListModel];
    if (visibleItems.count != 0 && [visibleItems[0] isKindOfClass:[TGConversation class]]) {
        TGConversation *topConversation = visibleItems[0];
        topIsPinned = topConversation.pinnedToTop || topConversation.isAd || (_dialogListCompanion.forwardMode && topConversation.conversationId == TGTelegraphInstance.clientUserId);
    }
    UIColor *backgroundColor = topIsPinned ? _presentation.pallete.barBackgroundColor : _presentation.pallete.backgroundColor;
    if (!TGObjectCompare(_searchBar.backgroundColor, backgroundColor)) {
        _searchBar.backgroundColor = backgroundColor;
        _searchTopBackgroundView.backgroundColor = backgroundColor;
    }
    _searchBar.highContrast = topIsPinned;
}

- (void)selectConversationWithId:(int64_t)conversationId
{
    bool found = false;
    
    NSArray *visibleItems = [self ios6VisibleListModel];
    int index = -1;
    for (TGConversation *conversation in visibleItems)
    {
        index++;
        if (![conversation isKindOfClass:[TGConversation class]])
            continue;
        
        if (conversation.conversationId == conversationId && conversationId != 0)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:1];
            if (indexPath.section >= [_tableView numberOfSections] || indexPath.row >= [_tableView numberOfRowsInSection:indexPath.section])
            {
                TGLog(@"DIALOGS select.skip invalid index peer=%lld row=%d visible=%d rows=%d", conversationId, index, (int)visibleItems.count, indexPath.section < [_tableView numberOfSections] ? (int)[_tableView numberOfRowsInSection:indexPath.section] : -1);
                break;
            }
            
            UITableViewScrollPosition scrollPosition = UITableViewScrollPositionNone;
            
            CGRect convertRect = [_tableView convertRect:[_tableView rectForRowAtIndexPath:indexPath] toView:self.view];
            if (convertRect.origin.y + convertRect.size.height > self.view.frame.size.height - self.controllerInset.bottom)
                scrollPosition = UITableViewScrollPositionBottom;
            else if (convertRect.origin.y < self.controllerInset.top)
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
    int32_t ownUid = TGTelegraphInstance.clientUserId;
    
    if ([(NSArray *)items[@"dialogs"] count] != 0)
    {
        NSMutableArray *dialogs = [(NSArray *)items[@"dialogs"] mutableCopy];
        if (addSavedMessages)
        {
            [dialogs enumerateObjectsUsingBlock:^(TGUser *user, NSUInteger index, BOOL *stop)
            {
                if (![user isKindOfClass:[TGUser class]])
                    return;
                
                if (user.uid == ownUid)
                {
                    [dialogs removeObjectAtIndex:index];
                    *stop = true;
                }
            }];

            [dialogs insertObject:[TGDatabaseInstance() loadUser:ownUid] atIndex:0];
        }
        [searchResultsSections addObject:@{@"title": TGLocalized(@"DialogList.SearchSectionDialogs"), @"items": [self filteredDialogs:dialogs], @"type": @"dialogs"}];
    }
    else if (addSavedMessages)
    {
        TGUser *ownUser = [TGDatabaseInstance() loadUser:ownUid];
        if (ownUser != nil) {
            NSArray *dialogs = @[ownUser];
            [searchResultsSections addObject:@{@"title": TGLocalized(@"DialogList.SearchSectionDialogs"), @"items": dialogs, @"type": @"dialogs"}];
        }
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
    [self setLeftBarButtonItem:[self controllerLeftBarButtonItem] animated:animated];
    [self setRightBarButtonItems:[self controllerRightBarButtonItems] animated:animated];
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
    TGLog(@"ARCHIVE cache.button clear chat list cache");
    [TGDatabaseInstance() setCustomProperty:@"dialogListLoaded" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"dialogListRemoteOffset" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"dialogListHash" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"ios6ArchivePeerIds" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"ios6ArchivePeerIdsComplete" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"ios6DialogListCacheVersion" value:nil];
    
    _ios6ArchiveExpanded = false;
    _ios6ArchiveRefreshRequested = false;
    _ios6ArchiveItemsLoadRequested = false;
    _ios6ArchivePeerIds = nil;
    
    [self updateBarButtonItemsAnimated:false];
    [_dialogListCompanion clearChatListCacheAndReload];
}

- (void)ios6ClearChatCacheRequested:(NSNotification *)__unused notification
{
    [self clearChatCacheButtonPressed];
}

- (void)archiveButtonPressed:(id)__unused sender
{
    [self ios6ReloadArchivePeerIds];
    
    _ios6ArchiveExpanded = !_ios6ArchiveExpanded;
    if (_ios6ArchiveExpanded && (!_ios6ArchiveItemsLoadRequested || [self ios6ArchivedConversationCount] == 0))
    {
        _ios6ArchiveItemsLoadRequested = true;
        TGLog(@"ARCHIVE nav.tap trigger lazy item load");
        [_dialogListCompanion loadArchiveItems];
    }
    TGLog(@"ARCHIVE nav.tap archiveMode=%d archived=%d unread=%d", _ios6ArchiveExpanded ? 1 : 0, (int)[self ios6ArchivedConversationCount], [self ios6ArchivedUnreadCount]);
    [self ios6LogArchiveDiagnostics:@"nav.tap"];
    [self updateBarButtonItemsAnimated:false];
    [self ios6LayoutFolderTabs];
    [self ios6UpdateFolderTabs];
    [_tableView reloadData];
    if ([self ios6VisibleListModel].count != 0)
        [_tableView setContentOffset:CGPointMake(0.0f, -_tableView.contentInset.top) animated:false];
}

- (void)ios6ArchivePeerIdsUpdated:(NSNotification *)__unused notification
{
    _ios6ArchiveRefreshRequested = false;
    [self ios6ReloadArchivePeerIds];
    [self ios6ApplyArchivePeerIdsToListModel];

    _ios6VisibleListCache = nil;
    _ios6VisibleListCacheFilterId = INT32_MIN;
    TGDialogListControllerReference *reference = _ios6LifetimeReference;
    TGDispatchAfter(0.30, dispatch_get_main_queue(), ^
    {
        [reference withValue:^(void *value)
        {
            TGDialogListController *controller = (__bridge TGDialogListController *)value;
            [controller ios6RefreshAllDialogItems:false];
        }];
    });

    TGLog(@"ARCHIVE peerIds.updated expanded=%d archived=%d unread=%d", _ios6ArchiveExpanded ? 1 : 0, (int)[self ios6ArchivedConversationCount], [self ios6ArchivedUnreadCount]);
    NSLog(@"FOLDERS archive.updated peers=%d local=%d selected=%d",
          (int)_ios6ArchivePeerIds.count, (int)_ios6AllDialogItems.count, _ios6SelectedDialogFilterId);
    [self ios6LogArchiveDiagnostics:@"peerIds.updated"];
    [self updateBarButtonItemsAnimated:false];
    [self ios6UpdateFolderTabs];
    [_tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    static bool canSelect = true;
    if (canSelect)
    {
        canSelect = false;
        dispatch_async(dispatch_get_main_queue(), ^
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
            id item = [self ios6DialogListItemAtIndexPath:indexPath];
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

- (bool)ios6IsArchiveHeaderItem:(id)item
{
    return [item isKindOfClass:[NSString class]] && [(NSString *)item isEqualToString:TGIOS6ArchiveHeaderItem];
}

- (void)ios6ReloadArchivePeerIds
{
    NSData *data = [TGDatabaseInstance() customProperty:@"ios6ArchivePeerIds"];
    NSSet *peerIds = nil;
    
    if (data.length != 0)
    {
        @try
        {
            NSArray *storedPeerIds = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            if ([storedPeerIds isKindOfClass:[NSArray class]])
                peerIds = [[NSSet alloc] initWithArray:storedPeerIds];
        }
        @catch (__unused NSException *exception)
        {
            TGLog(@"ARCHIVE peerIds.load failed");
        }
    }
    
    _ios6ArchivePeerIds = peerIds;
    
}

- (void)ios6ApplyArchivePeerIdsToListModel
{
    if (_ios6ArchivePeerIds == nil)
        return;
    for (id item in _listModel)
    {
        if (![item isKindOfClass:[TGConversation class]])
            continue;
        TGConversation *conversation = (TGConversation *)item;
        conversation.isArchived = conversation.pinnedDate == 0 && [_ios6ArchivePeerIds containsObject:@(conversation.conversationId)];
    }
}

- (NSString *)ios6ArchiveSampleForConversation:(TGConversation *)conversation
{
    NSString *title = conversation.chatTitle.length == 0 ? conversation.dialogListData[@"title"] : conversation.chatTitle;
    if (title.length > 32)
        title = [[title substringToIndex:32] stringByAppendingString:@"..."];
    
    return [[NSString alloc] initWithFormat:@"%lld%@:%@", conversation.conversationId, conversation.isArchived ? @"F" : @"", title ?: @""];
}

- (NSArray *)ios6ArchiveLimitedSamples:(NSArray *)samples
{
    if (samples.count <= 20)
        return samples;
    
    NSMutableArray *limitedSamples = [[NSMutableArray alloc] initWithCapacity:21];
    for (NSUInteger i = 0; i < 20; i++)
        [limitedSamples addObject:samples[i]];
    [limitedSamples addObject:[[NSString alloc] initWithFormat:@"...+%d", (int)(samples.count - 20)]];
    return limitedSamples;
}

- (void)ios6LogArchiveDiagnostics:(NSString *)reason
{
    (void)reason;
}

- (bool)ios6IsArchivedConversation:(id)item
{
    if (![item isKindOfClass:[TGConversation class]])
        return false;
    
    TGConversation *conversation = (TGConversation *)item;
    if (conversation.pinnedDate != 0)
        return false;
    if (conversation.isArchived)
        return true;
    
    return _ios6ArchivePeerIds != nil && [_ios6ArchivePeerIds containsObject:[[NSNumber alloc] initWithLongLong:conversation.conversationId]];
}

- (bool)ios6NewChatListGesturesEnabled
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:TGIOS6NewChatListGesturesKey])
        return false;

    return [self ios6FoldersAllowed] && !_dialogListCompanion.forwardMode && !_dialogListCompanion.feedChannels;
}

- (void)ios6UpdateNewChatListGesturesState
{
    bool enabled = [self ios6NewChatListGesturesEnabled];
    _ios6FolderPanGestureRecognizer.enabled = enabled;
    _ios6ChatActionsLongPressRecognizer.enabled = enabled;

    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
            [(TGDialogListCell *)cell setSwipeActionsEnabled:!enabled];
    }
}

- (void)ios6NewChatListGesturesChanged:(NSNotification *)__unused notification
{
    [self ios6UpdateNewChatListGesturesState];
    [self reloadData:false];
}

- (NSInteger)ios6SelectedDialogFilterIndex
{
    NSInteger index = 0;
    for (NSDictionary *filter in _ios6DialogFilters)
    {
        if ([filter[@"id"] intValue] == _ios6SelectedDialogFilterId)
            return index;
        index++;
    }
    return NSNotFound;
}

- (void)ios6CompleteDialogFilterSelectionAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_ios6DialogFilters.count)
        return;

    NSDictionary *filter = _ios6DialogFilters[index];
    int32_t filterId = [filter[@"id"] intValue];
    if (filterId != _ios6SelectedDialogFilterId)
        return;

    [[NSUserDefaults standardUserDefaults] setInteger:filterId forKey:@"TGIOS6SelectedDialogFilterId"];

    NSLog(@"FOLDERS select id=%d title=%@", filterId, filter[@"title"]);
    if (filterId != 0 && [_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]])
    {
        TGDialogListController *controller = self;
        if (cpuCoreCount() > 1)
        {
            [self ios6RefreshAllDialogItems:false];
        }
        else
        {
            int32_t selectedFilterId = filterId;
            TGDispatchAfter(0.25, dispatch_get_main_queue(), ^
            {
                if (controller->_ios6SelectedDialogFilterId == selectedFilterId)
                    [controller ios6RefreshAllDialogItems:false];
            });
        }
        TGDispatchAfter(0.75, dispatch_get_main_queue(), ^
        {
            if (controller->_ios6SelectedDialogFilterId == 0)
                return;

            [controller ios6HydrateExplicitFolderPeers];
            [(TGTelegraphDialogListCompanion *)controller->_dialogListCompanion ios6PreloadAllDialogsForFolders];
        });
    }
}

- (void)ios6SelectDialogFilterAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_ios6DialogFilters.count || _ios6FolderSwipeActive || _ios6FolderSwipeFinishing)
        return;

    NSDictionary *filter = _ios6DialogFilters[index];
    int32_t filterId = [filter[@"id"] intValue];
    if (filterId == _ios6SelectedDialogFilterId)
        return;

    _ios6ArchiveExpanded = false;
    _ios6SelectedDialogFilterId = filterId;
    _ios6VisibleListCache = nil;
    _ios6VisibleListCacheFilterId = INT32_MIN;

    [self reloadData:false];
    [self updateBarButtonItemsAnimated:false];
    [self resetInitialOffset];
    [self ios6CompleteDialogFilterSelectionAtIndex:index];
}

- (CGRect)ios6FolderSwipeTabsRect
{
    if (_ios6FolderTabsView == nil || _ios6FolderTabsView.hidden || _ios6FolderTabsView.bounds.size.height < FLT_EPSILON)
        return CGRectZero;

    CGRect rect = [_ios6FolderTabsView convertRect:_ios6FolderTabsView.bounds toView:self.view];
    return CGRectIntersection(rect, self.view.bounds);
}

- (CGRect)ios6FolderSwipeContentRect
{
    if (_tableView == nil)
        return CGRectZero;

    CGRect tableRect = [_tableView.superview convertRect:_tableView.frame toView:self.view];
    CGRect tabsRect = [self ios6FolderSwipeTabsRect];
    CGFloat top = CGRectGetMinY(tableRect);
    if (!CGRectIsEmpty(tabsRect))
        top = MAX(top, CGRectGetMaxY(tabsRect));

    CGRect rect = CGRectMake(CGRectGetMinX(tableRect), top, CGRectGetWidth(tableRect), CGRectGetMaxY(tableRect) - top);
    return CGRectIntersection(rect, self.view.bounds);
}

- (UIImage *)ios6FolderSwipeSnapshotForRect:(CGRect)rect
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

- (void)ios6BeginFolderSwipeToIndex:(NSInteger)targetIndex translation:(CGPoint)translation
{
    if (_ios6FolderSwipeActive || _ios6FolderSwipeFinishing || targetIndex < 0 || targetIndex >= (NSInteger)_ios6DialogFilters.count)
        return;

    NSInteger sourceIndex = [self ios6SelectedDialogFilterIndex];
    if (sourceIndex == NSNotFound || sourceIndex == targetIndex)
        return;

    NSDictionary *sourceFilter = _ios6DialogFilters[sourceIndex];
    NSDictionary *targetFilter = _ios6DialogFilters[targetIndex];
    int32_t sourceFilterId = [sourceFilter[@"id"] intValue];
    int32_t targetFilterId = [targetFilter[@"id"] intValue];
    if (sourceFilterId == targetFilterId)
        return;

    CGRect tabsRect = [self ios6FolderSwipeTabsRect];
    CGRect contentRect = [self ios6FolderSwipeContentRect];
    if (CGRectIsEmpty(tabsRect) || CGRectIsEmpty(contentRect))
        return;

    UIView *existingIndicator = [_ios6FolderTabsScrollView viewWithTag:6199];
    bool indicatorWasHidden = existingIndicator.hidden;
    existingIndicator.hidden = true;
    UIImage *tabsImage = [self ios6FolderSwipeSnapshotForRect:tabsRect];
    existingIndicator.hidden = indicatorWasHidden;
    UIImage *sourceImage = [self ios6FolderSwipeSnapshotForRect:contentRect];
    if (sourceImage == nil || tabsImage == nil)
        return;

    UIButton *sourceButton = (UIButton *)[_ios6FolderTabsScrollView viewWithTag:6100 + sourceIndex];
    UIButton *targetButton = (UIButton *)[_ios6FolderTabsScrollView viewWithTag:6100 + targetIndex];
    if (![sourceButton isKindOfClass:[UIButton class]] || ![targetButton isKindOfClass:[UIButton class]])
        return;

    CGRect sourceIndicatorFrame = [sourceButton convertRect:CGRectMake(5.0f, 34.0f, MAX(0.0f, sourceButton.bounds.size.width - 10.0f), 3.0f) toView:self.view];
    CGRect targetIndicatorFrame = [targetButton convertRect:CGRectMake(5.0f, 34.0f, MAX(0.0f, targetButton.bounds.size.width - 10.0f), 3.0f) toView:self.view];
    sourceIndicatorFrame = CGRectOffset(sourceIndicatorFrame, -tabsRect.origin.x, -tabsRect.origin.y);
    targetIndicatorFrame = CGRectOffset(targetIndicatorFrame, -tabsRect.origin.x, -tabsRect.origin.y);

    _ios6FolderSwipeSourceIndex = sourceIndex;
    _ios6FolderSwipeTargetIndex = targetIndex;
    _ios6FolderSwipeSourceFilterId = sourceFilterId;
    _ios6FolderSwipeTargetFilterId = targetFilterId;
    _ios6FolderSwipeSourceContentOffset = _tableView.contentOffset;
    _ios6FolderSwipeContentFrame = contentRect;
    _ios6FolderSwipeSourceIndicatorFrame = sourceIndicatorFrame;
    _ios6FolderSwipeTargetIndicatorFrame = targetIndicatorFrame;
    _ios6FolderSwipePreviousViewClipsToBounds = self.view.clipsToBounds;
    self.view.clipsToBounds = true;

    _ios6FolderSwipeSourceView = [[UIImageView alloc] initWithImage:sourceImage];
    _ios6FolderSwipeSourceView.frame = contentRect;
    _ios6FolderSwipeSourceView.userInteractionEnabled = false;
    [self.view addSubview:_ios6FolderSwipeSourceView];

    _ios6FolderSwipeTabsView = [[UIImageView alloc] initWithImage:tabsImage];
    _ios6FolderSwipeTabsView.frame = tabsRect;
    _ios6FolderSwipeTabsView.clipsToBounds = true;
    _ios6FolderSwipeTabsView.userInteractionEnabled = false;
    [self.view addSubview:_ios6FolderSwipeTabsView];

    bool classicStyle = [TGPresentation classicIOS6Style];
    _ios6FolderSwipeIndicatorView = [[UIView alloc] initWithFrame:sourceIndicatorFrame];
    _ios6FolderSwipeIndicatorView.backgroundColor = classicStyle ? UIColorRGB(0x2b78c5) : self.presentation.pallete.accentColor;
    _ios6FolderSwipeIndicatorView.userInteractionEnabled = false;
    [_ios6FolderSwipeTabsView addSubview:_ios6FolderSwipeIndicatorView];

    _ios6FolderSwipeActive = true;
    _tableView.scrollEnabled = false;
    _ios6ChatActionsLongPressRecognizer.enabled = false;
    _ios6FolderEmptyLabel.hidden = true;
    _ios6ArchiveExpanded = false;

    _ios6SelectedDialogFilterId = targetFilterId;
    _ios6VisibleListCache = nil;
    _ios6VisibleListCacheFilterId = INT32_MIN;
    [self reloadData:false];
    [self resetInitialOffset];

    CGFloat direction = targetIndex > sourceIndex ? 1.0f : -1.0f;
    if (TGIsRTL())
        direction = -direction;
    _ios6FolderSwipeTargetOffset = direction * contentRect.size.width;

    [self ios6UpdateFolderSwipeWithTranslation:translation];
}

- (void)ios6UpdateFolderSwipeWithTranslation:(CGPoint)translation
{
    if (!_ios6FolderSwipeActive || _ios6FolderSwipeFinishing || _ios6FolderSwipeSourceView == nil)
        return;

    CGFloat width = _ios6FolderSwipeContentFrame.size.width;
    if (width < 1.0f)
        return;

    CGFloat expectedTranslation = -_ios6FolderSwipeTargetOffset;
    CGFloat x = translation.x;
    if (x * expectedTranslation < 0.0f)
        x *= 0.22f;
    if (ABS(x) > width)
        x = x < 0.0f ? -width : width;

    CGRect sourceFrame = _ios6FolderSwipeContentFrame;
    sourceFrame.origin.x += x;
    _ios6FolderSwipeSourceView.frame = sourceFrame;
    _tableView.transform = CGAffineTransformMakeTranslation(_ios6FolderSwipeTargetOffset + x, 0.0f);

    CGFloat progress = MIN(1.0f, ABS(x) / width);
    CGRect fromFrame = _ios6FolderSwipeSourceIndicatorFrame;
    CGRect toFrame = _ios6FolderSwipeTargetIndicatorFrame;
    CGRect indicatorFrame = CGRectMake(fromFrame.origin.x + (toFrame.origin.x - fromFrame.origin.x) * progress,
                                       fromFrame.origin.y + (toFrame.origin.y - fromFrame.origin.y) * progress,
                                       fromFrame.size.width + (toFrame.size.width - fromFrame.size.width) * progress,
                                       fromFrame.size.height + (toFrame.size.height - fromFrame.size.height) * progress);
    _ios6FolderSwipeIndicatorView.frame = indicatorFrame;
}

- (void)ios6FinishFolderSwipeCommit:(bool)commit velocity:(CGPoint)velocity
{
    if (!_ios6FolderSwipeActive || _ios6FolderSwipeFinishing)
        return;

    _ios6FolderSwipeFinishing = true;

    CGFloat width = _ios6FolderSwipeContentFrame.size.width;
    CGFloat sourceX = _ios6FolderSwipeSourceView.frame.origin.x - _ios6FolderSwipeContentFrame.origin.x;
    CGFloat expectedTranslation = -_ios6FolderSwipeTargetOffset;
    CGFloat finalTranslation = commit ? expectedTranslation : 0.0f;
    CGFloat targetTranslation = commit ? 0.0f : _ios6FolderSwipeTargetOffset;
    CGFloat remaining = width < 1.0f ? 0.0f : ABS(finalTranslation - sourceX) / width;
    CGFloat velocityMagnitude = ABS(velocity.x);
    NSTimeInterval duration = MAX(0.08, MIN(0.20, 0.08 + 0.12 * remaining));
    if (velocityMagnitude > 1.0f && width > 1.0f)
        duration = MIN(duration, MAX(0.08, MIN(0.18, ABS(finalTranslation - sourceX) / velocityMagnitude)));

    CGRect finalSourceFrame = _ios6FolderSwipeContentFrame;
    finalSourceFrame.origin.x += finalTranslation;
    CGRect finalIndicatorFrame = commit ? _ios6FolderSwipeTargetIndicatorFrame : _ios6FolderSwipeSourceIndicatorFrame;

    TGDialogListController *controller = self;
    [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:^
    {
        controller->_ios6FolderSwipeSourceView.frame = finalSourceFrame;
        controller->_tableView.transform = CGAffineTransformMakeTranslation(targetTranslation, 0.0f);
        controller->_ios6FolderSwipeIndicatorView.frame = finalIndicatorFrame;
    } completion:^(__unused BOOL finished)
    {
        if (!controller->_ios6FolderSwipeFinishing)
            return;

        if (commit)
        {
            controller->_tableView.transform = CGAffineTransformIdentity;
            NSInteger targetIndex = controller->_ios6FolderSwipeTargetIndex;
            if (targetIndex >= 0 && targetIndex < (NSInteger)controller->_ios6DialogFilters.count &&
                [controller->_ios6DialogFilters[targetIndex][@"id"] intValue] == controller->_ios6FolderSwipeTargetFilterId &&
                controller->_ios6SelectedDialogFilterId == controller->_ios6FolderSwipeTargetFilterId)
            {
                [controller updateBarButtonItemsAnimated:false];
                [controller ios6CompleteDialogFilterSelectionAtIndex:targetIndex];
            }
            else
            {
                controller->_ios6SelectedDialogFilterId = controller->_ios6FolderSwipeSourceFilterId;
                controller->_ios6VisibleListCache = nil;
                controller->_ios6VisibleListCacheFilterId = INT32_MIN;
                [controller reloadData:false];
                [controller->_tableView setContentOffset:controller->_ios6FolderSwipeSourceContentOffset animated:false];
            }
        }
        else
        {
            controller->_ios6SelectedDialogFilterId = controller->_ios6FolderSwipeSourceFilterId;
            controller->_ios6VisibleListCache = nil;
            controller->_ios6VisibleListCacheFilterId = INT32_MIN;
            [controller reloadData:false];
            [controller->_tableView setContentOffset:controller->_ios6FolderSwipeSourceContentOffset animated:false];
            controller->_tableView.transform = CGAffineTransformIdentity;
        }

        [controller->_ios6FolderSwipeSourceView removeFromSuperview];
        controller->_ios6FolderSwipeSourceView = nil;
        [controller->_ios6FolderSwipeTabsView removeFromSuperview];
        controller->_ios6FolderSwipeTabsView = nil;
        controller->_ios6FolderSwipeIndicatorView = nil;
        controller.view.clipsToBounds = controller->_ios6FolderSwipePreviousViewClipsToBounds;
        controller->_ios6FolderSwipeActive = false;
        controller->_ios6FolderSwipeFinishing = false;
        controller->_tableView.scrollEnabled = true;
        [controller ios6UpdateNewChatListGesturesState];
        controller->_ios6FolderTabsStateKey = nil;
        [controller ios6UpdateFolderTabs];
        [controller ios6UpdateFolderEmptyLabel];
    }];
}

- (void)ios6CancelFolderSwipeImmediately
{
    if (!_ios6FolderSwipeActive && !_ios6FolderSwipeFinishing)
        return;

    [_ios6FolderSwipeSourceView.layer removeAllAnimations];
    [_tableView.layer removeAllAnimations];
    [_ios6FolderSwipeIndicatorView.layer removeAllAnimations];

    _ios6SelectedDialogFilterId = _ios6FolderSwipeSourceFilterId;
    _ios6VisibleListCache = nil;
    _ios6VisibleListCacheFilterId = INT32_MIN;
    _tableView.transform = CGAffineTransformIdentity;
    [self reloadData:false];
    [_tableView setContentOffset:_ios6FolderSwipeSourceContentOffset animated:false];

    [_ios6FolderSwipeSourceView removeFromSuperview];
    _ios6FolderSwipeSourceView = nil;
    [_ios6FolderSwipeTabsView removeFromSuperview];
    _ios6FolderSwipeTabsView = nil;
    _ios6FolderSwipeIndicatorView = nil;
    self.view.clipsToBounds = _ios6FolderSwipePreviousViewClipsToBounds;
    _ios6FolderSwipeActive = false;
    _ios6FolderSwipeFinishing = false;
    _tableView.scrollEnabled = true;
    [self ios6UpdateNewChatListGesturesState];
    _ios6FolderTabsStateKey = nil;
    [self ios6UpdateFolderTabs];
    [self ios6UpdateFolderEmptyLabel];
}

- (void)ios6FolderPanGesture:(UIPanGestureRecognizer *)recognizer
{
    if (![self ios6NewChatListGesturesEnabled] || _isDisplayingSearch || _ios6ArchiveExpanded || _ios6DialogFilters.count <= 1)
    {
        if (_ios6FolderSwipeActive)
            [self ios6FinishFolderSwipeCommit:false velocity:CGPointZero];
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateBegan)
    {
        CGPoint velocity = [recognizer velocityInView:self.view];
        CGFloat logicalVelocityX = TGIsRTL() ? -velocity.x : velocity.x;
        NSInteger currentIndex = [self ios6SelectedDialogFilterIndex];
        if (currentIndex == NSNotFound)
            currentIndex = 0;
        NSInteger targetIndex = currentIndex + (logicalVelocityX < 0.0f ? 1 : -1);
        [self ios6BeginFolderSwipeToIndex:targetIndex translation:[recognizer translationInView:self.view]];
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateChanged)
    {
        [self ios6UpdateFolderSwipeWithTranslation:[recognizer translationInView:self.view]];
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateEnded)
    {
        if (!_ios6FolderSwipeActive)
            return;

        CGPoint translation = [recognizer translationInView:self.view];
        CGPoint velocity = [recognizer velocityInView:self.view];
        CGFloat expectedTranslation = -_ios6FolderSwipeTargetOffset;
        bool movingTowardTarget = translation.x * expectedTranslation > 0.0f;
        bool velocityTowardTarget = velocity.x * expectedTranslation > 0.0f;
        CGFloat width = MAX(1.0f, _ios6FolderSwipeContentFrame.size.width);
        CGFloat progress = ABS(translation.x) / width;
        CGFloat projectedProgress = ABS(translation.x + velocity.x * 0.16f) / width;
        bool commit = movingTowardTarget && (progress >= 0.30f || projectedProgress >= 0.48f || (velocityTowardTarget && ABS(velocity.x) >= 520.0f));

        NSLog(@"GESTURES folder interactive current=%d target=%d progress=%.3f projected=%.3f vx=%.1f commit=%d",
            (int)_ios6FolderSwipeSourceIndex, (int)_ios6FolderSwipeTargetIndex, progress, projectedProgress, velocity.x, commit ? 1 : 0);
        [self ios6FinishFolderSwipeCommit:commit velocity:velocity];
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed)
        [self ios6FinishFolderSwipeCommit:false velocity:CGPointZero];
}

- (void)ios6PresentActionsForConversation:(TGConversation *)conversation fromRect:(CGRect)sourceRect
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
    bool archived = conversation.isArchived || [self ios6IsArchivedConversation:conversation];
    bool read = !conversation.unreadMark && conversation.unreadCount == 0 && conversation.serviceUnreadCount == 0 && conversation.unreadMentionCount == 0;
    int64_t peerId = conversation.conversationId;

    NSMutableArray *actions = [[NSMutableArray alloc] init];
    if (!isSavedMessages)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(read ? @"DialogList.Unread" : @"DialogList.Read") action:@"read" type:TGActionSheetActionTypeGeneric]];

    if (!_dialogListCompanion.feedChannels)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(pinned ? @"DialogList.Unpin" : @"DialogList.Pin") action:@"pin" type:TGActionSheetActionTypeGeneric]];

    if (!isEncrypted && !isSavedMessages)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(muted ? @"Conversation.Unmute" : @"Conversation.Mute") action:@"mute" type:TGActionSheetActionTypeGeneric]];

    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(archived ? @"DialogList.Unarchive" : @"DialogList.Archive") action:@"archive" type:TGActionSheetActionTypeGeneric]];
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Delete") action:@"delete" type:TGActionSheetActionTypeDestructive]];
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];

    if (iosMajorVersion() < 5)
    {
        TGActionSheet *sheet = [[TGActionSheet alloc] initWithTitle:nil actions:actions actionBlock:^(TGDialogListController *controller, NSString *action)
        {
            if (controller == nil)
                return;

            if ([action isEqualToString:@"read"] && controller.toggleReadConversation != nil)
                controller.toggleReadConversation(peerId, !read);
            else if ([action isEqualToString:@"pin"] && controller.togglePinConversation != nil)
                controller.togglePinConversation(peerId, !pinned);
            else if ([action isEqualToString:@"mute"] && controller.toggleMuteConversation != nil)
                controller.toggleMuteConversation(peerId, !muted);
            else if ([action isEqualToString:@"archive"] && controller.toggleArchiveConversation != nil)
                controller.toggleArchiveConversation(peerId, !archived);
            else if ([action isEqualToString:@"delete"] && controller.deleteConversation != nil)
                controller.deleteConversation(peerId);
        } target:self];

        UIView *view = self.navigationController.view != nil ? self.navigationController.view : self.view;
        [sheet showInView:view];
        return;
    }

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
        else if ([action isEqualToString:@"archive"] && strongSelf.toggleArchiveConversation != nil)
            strongSelf.toggleArchiveConversation(peerId, !archived);
        else if ([action isEqualToString:@"delete"] && strongSelf.deleteConversation != nil)
            strongSelf.deleteConversation(peerId);
    } target:self];

    if (!TGIsPad())
        [sheet showInView:self.navigationController.view];
    else
        [sheet showFromRect:sourceRect inView:self.view animated:true];
}

- (void)ios6ChatActionsLongPress:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan || ![self ios6NewChatListGesturesEnabled] || _isDisplayingSearch)
        return;

    CGPoint point = [recognizer locationInView:_tableView];
    NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:point];
    if (indexPath == nil || indexPath.section != 1)
        return;

    id item = [self ios6DialogListItemAtIndexPath:indexPath];
    if (![item isKindOfClass:[TGConversation class]] || [self ios6IsArchiveHeaderItem:item])
        return;

    UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPath];
    CGRect sourceRect = cell == nil ? CGRectMake(point.x, point.y, 1.0f, 1.0f) : [_tableView convertRect:cell.frame toView:self.view];
    [self ios6PresentActionsForConversation:(TGConversation *)item fromRect:sourceRect];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == _ios6FolderPanGestureRecognizer)
    {
        if (![self ios6NewChatListGesturesEnabled] || _isDisplayingSearch || _ios6ArchiveExpanded || _ios6DialogFilters.count <= 1 || _ios6FolderSwipeActive || _ios6FolderSwipeFinishing)
            return NO;

        CGPoint velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self.view];
        CGFloat horizontalVelocity = ABS(velocity.x);
        CGFloat verticalVelocity = ABS(velocity.y);
        if (horizontalVelocity < 15.0f || horizontalVelocity < verticalVelocity * 1.08f)
            return NO;

        CGFloat logicalVelocityX = TGIsRTL() ? -velocity.x : velocity.x;
        NSInteger currentIndex = [self ios6SelectedDialogFilterIndex];
        if (currentIndex == NSNotFound)
            currentIndex = 0;
        NSInteger targetIndex = currentIndex + (logicalVelocityX < 0.0f ? 1 : -1);
        if (targetIndex < 0 || targetIndex >= (NSInteger)_ios6DialogFilters.count)
            return NO;
    }

    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if (gestureRecognizer == _ios6FolderPanGestureRecognizer)
    {
        if (![self ios6NewChatListGesturesEnabled] || _isDisplayingSearch || _ios6ArchiveExpanded || _ios6DialogFilters.count <= 1)
            return NO;

        CGPoint point = [touch locationInView:self.view];
        if (_tableView == nil || !CGRectContainsPoint(_tableView.frame, point))
            return NO;
    }

    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == _ios6FolderPanGestureRecognizer || otherGestureRecognizer == _ios6FolderPanGestureRecognizer)
        return NO;

    return NO;
}

- (bool)ios6FoldersAllowed
{
    return !_dialogListCompanion.privacyMode &&
        !_dialogListCompanion.showPrivateOnly &&
        !_dialogListCompanion.showGroupsAndChannelsOnly &&
        !_dialogListCompanion.showGroupsOnly &&
        !_dialogListCompanion.botStartMode;
}

- (CGFloat)ios6FolderTabsHeight
{
    if (![self ios6FoldersAllowed] || _isDisplayingSearch || _ios6ArchiveExpanded || _ios6DialogFilters.count <= 1)
        return 0.0f;
    return 38.0f;
}

- (int64_t)ios6PeerIdForInputPeer:(id)peer
{
    if ([peer isKindOfClass:[TLInputPeer$inputPeerSelf class]])
        return TGTelegraphInstance.clientUserId;
    if ([peer isKindOfClass:[TLInputPeer$inputPeerUser class]])
    {
        int64_t modernUserId = ((TLInputPeer$inputPeerUser *)peer).user_id;
        return TGModernLegacyIdForModernId(modernUserId);
    }
    if ([peer isKindOfClass:[TLInputPeer$inputPeerChat class]])
        return TGPeerIdFromGroupId((int32_t)((TLInputPeer$inputPeerChat *)peer).chat_id);
    if ([peer isKindOfClass:[TLInputPeer$inputPeerChannel class]])
        return TGPeerIdFromChannelId((int32_t)((TLInputPeer$inputPeerChannel *)peer).channel_id);
    return 0;
}

- (NSSet *)ios6PeerIdSetForInputPeers:(NSArray *)peers
{
    NSMutableSet *result = [[NSMutableSet alloc] init];
    for (id peer in peers)
    {
        int64_t peerId = [self ios6PeerIdForInputPeer:peer];
        if (peerId != 0)
            [result addObject:@(peerId)];
    }
    return result;
}

- (NSArray *)ios6PeerIdArrayForInputPeers:(NSArray *)peers
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (id peer in peers)
    {
        int64_t peerId = [self ios6PeerIdForInputPeer:peer];
        if (peerId != 0)
            [result addObject:@(peerId)];
    }
    return result;
}

- (void)ios6EnsureDialogListDataForConversation:(TGConversation *)conversation
{
    if (conversation == nil)
        return;
    if (conversation.dialogListData.count != 0)
        return;
    if ([_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]])
    {
        TGUser *selfUser = [TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId];
        [(TGTelegraphDialogListCompanion *)_dialogListCompanion initializeDialogListData:conversation customUser:nil selfUser:selfUser];
    }
}

- (void)ios6RefreshAllDialogItems:(bool)force
{
    if (![self ios6FoldersAllowed] || _ios6AllDialogItemsLoading)
        return;
    if (cpuCoreCount() == 1 && !_isOnScreen && self.navigationController != nil && self.navigationController.topViewController != self)
        return;

    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    if (_ios6AllDialogItemsLastRefreshTime > 0.0)
    {
        NSTimeInterval minimumInterval = force ? 10.0 : 120.0;
        if (now - _ios6AllDialogItemsLastRefreshTime < minimumInterval)
            return;
    }

    _ios6AllDialogItemsLoading = true;
    _ios6AllDialogItemsLastRefreshTime = now;
    TGDialogListController *controller = self;
    TGTelegraphDialogListCompanion *dialogListCompanion = [_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]] ? (TGTelegraphDialogListCompanion *)_dialogListCompanion : nil;
    [TGDatabaseInstance() loadConversationListFromDate:INT32_MAX limit:0 excludeConversationIds:@[] folderId:-1 completion:^(NSArray *result, __unused bool loadedAllRegular)
    {
        if (dialogListCompanion != nil)
        {
            TGUser *selfUser = [TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId];
            for (TGConversation *conversation in result)
            {
                if ([conversation isKindOfClass:[TGConversation class]] && conversation.dialogListData.count == 0)
                    [dialogListCompanion initializeDialogListData:conversation customUser:nil selfUser:selfUser];
            }
        }

        TGDispatchOnMainThread(^
        {
            TGDialogListController *strongSelf = controller;
            strongSelf->_ios6AllDialogItemsLoading = false;
            strongSelf->_ios6AllDialogItems = [result isKindOfClass:[NSArray class]] ? result : @[];
            strongSelf->_ios6VisibleListCache = nil;
            strongSelf->_ios6VisibleListCacheFilterId = INT32_MIN;
            NSLog(@"FOLDERS source local=%d current=%d", (int)strongSelf->_ios6AllDialogItems.count, (int)strongSelf->_listModel.count);
            if (strongSelf->_ios6SelectedDialogFilterId != 0)
                [strongSelf reloadData:false];
            else
                [strongSelf ios6UpdateFolderTabs];
        });
    }];
}

- (NSArray *)ios6FolderSourceItems
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSMutableSet *seen = [[NSMutableSet alloc] init];
    for (id item in _listModel)
    {
        if (![item isKindOfClass:[TGConversation class]])
            continue;
        NSNumber *key = @(((TGConversation *)item).conversationId);
        if (![seen containsObject:key])
        {
            [seen addObject:key];
            [result addObject:item];
        }
    }
    for (id item in _ios6AllDialogItems)
    {
        if (![item isKindOfClass:[TGConversation class]])
            continue;
        NSNumber *key = @(((TGConversation *)item).conversationId);
        if (![seen containsObject:key])
        {
            [seen addObject:key];
            [result addObject:item];
        }
    }
    return result;
}

- (NSArray *)ios6NormalizeDialogFilters:(NSArray *)filters
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
            int64_t peerId = [self ios6PeerIdForInputPeer:inputPeer];
            if (peerId != 0)
                inputPeersById[@(peerId)] = inputPeer;
        }
        for (TLInputPeer *inputPeer in normalizedIncludePeers)
        {
            int64_t peerId = [self ios6PeerIdForInputPeer:inputPeer];
            if (peerId != 0)
                inputPeersById[@(peerId)] = inputPeer;
        }

        NSDictionary *normalized = @{
            @"id": @(filterId),
            @"flags": @(flags),
            @"title": title,
            @"default": @(defaultFilter),
            @"chatlist": @(chatlist),
            @"pinned": [self ios6PeerIdSetForInputPeers:normalizedPinnedPeers],
            @"pinnedOrder": [self ios6PeerIdArrayForInputPeers:normalizedPinnedPeers],
            @"include": [self ios6PeerIdSetForInputPeers:normalizedIncludePeers],
            @"exclude": [self ios6PeerIdSetForInputPeers:[excludePeers isKindOfClass:[NSArray class]] ? excludePeers : @[]],
            @"inputPeers": inputPeersById
        };
        [result addObject:normalized];
    }

    if (!hasDefault)
    {
        NSDictionary *defaultFilter = @{
            @"id": @0,
            @"flags": @0,
            @"title": TGLocalized(@"DialogList.Title"),
            @"default": @YES,
            @"chatlist": @NO,
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

- (void)ios6ContinueFolderPeerHydration
{
    if (!_ios6FolderPeerHydrationActive)
        return;

    if (_ios6FolderPeerHydrationQueue.count == 0)
    {
        _ios6FolderPeerHydrationActive = false;
        TGDialogListControllerReference *reference = _ios6LifetimeReference;
        TGDispatchAfter(0.35, dispatch_get_main_queue(), ^
        {
            [reference withValue:^(void *value)
            {
                TGDialogListController *controller = (__bridge TGDialogListController *)value;
                [controller ios6RefreshAllDialogItems:false];
            }];
        });
        return;
    }

    NSUInteger batchCount = MIN((NSUInteger)20, _ios6FolderPeerHydrationQueue.count);
    NSArray *batch = [_ios6FolderPeerHydrationQueue subarrayWithRange:NSMakeRange(0, batchCount)];
    [_ios6FolderPeerHydrationQueue removeObjectsInRange:NSMakeRange(0, batchCount)];

    NSMutableArray *inputDialogPeers = [[NSMutableArray alloc] initWithCapacity:batch.count];
    for (TLInputPeer *inputPeer in batch)
    {
        TLInputDialogPeer$inputDialogPeer *inputDialogPeer = [[TLInputDialogPeer$inputDialogPeer alloc] init];
        inputDialogPeer.peer = inputPeer;
        [inputDialogPeers addObject:inputDialogPeer];
    }

    TLRPCmessages_getPeerDialogs$messages_getPeerDialogs *request = [[TLRPCmessages_getPeerDialogs$messages_getPeerDialogs alloc] init];
    request.peers = inputDialogPeers;

    TGDialogListControllerReference *reference = _ios6LifetimeReference;
    SSignal *signal = [[[TGTelegramNetworking instance] requestSignal:request] mapToSignal:^SSignal *(TLmessages_PeerDialogs *result)
    {
        return [TGGroupManagementSignals processedDialogs:result peerId:0];
    }];

    [_ios6FolderPeerHydrationDisposable setDisposable:[[signal deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(id error)
    {
        [reference withValue:^(void *value)
        {
            TGDialogListController *controller = (__bridge TGDialogListController *)value;
            controller->_ios6FolderPeerHydrationFailed += (int)batch.count;
            NSString *errorType = [[TGTelegramNetworking instance] extractNetworkErrorType:error];
            NSLog(@"FOLDERS hydrate error batch=%d type=%@", (int)batch.count, errorType);
            TGDispatchAfter(0.05, dispatch_get_main_queue(), ^
            {
                [reference withValue:^(void *delayedValue)
                {
                    TGDialogListController *delayedController = (__bridge TGDialogListController *)delayedValue;
                    [delayedController ios6ContinueFolderPeerHydration];
                }];
            });
        }];
    } completed:^
    {
        [reference withValue:^(void *value)
        {
            TGDialogListController *controller = (__bridge TGDialogListController *)value;
            controller->_ios6FolderPeerHydrationLoaded += (int)batch.count;
            TGDispatchAfter(0.12, dispatch_get_main_queue(), ^
            {
                [reference withValue:^(void *delayedValue)
                {
                    TGDialogListController *delayedController = (__bridge TGDialogListController *)delayedValue;
                    [delayedController ios6ContinueFolderPeerHydration];
                }];
            });
        }];
    }]];
}

- (void)ios6HydrateExplicitFolderPeers
{
    if (_ios6FolderPeerHydrationActive || _ios6DialogFilters.count <= 1)
        return;

    NSMutableSet *availablePeerIds = [[NSMutableSet alloc] init];
    for (id item in [self ios6FolderSourceItems])
    {
        if ([item isKindOfClass:[TGConversation class]])
            [availablePeerIds addObject:@(((TGConversation *)item).conversationId)];
    }

    NSMutableDictionary *missingPeersById = [[NSMutableDictionary alloc] init];
    for (NSDictionary *filter in _ios6DialogFilters)
    {
        NSDictionary *inputPeers = filter[@"inputPeers"];
        if (![inputPeers isKindOfClass:[NSDictionary class]])
            continue;
        [inputPeers enumerateKeysAndObjectsUsingBlock:^(NSNumber *peerId, TLInputPeer *inputPeer, __unused BOOL *stop)
        {
            if (![availablePeerIds containsObject:peerId] && inputPeer != nil)
                missingPeersById[peerId] = inputPeer;
        }];
    }

    if (missingPeersById.count == 0)
    {
        return;
    }

    [_ios6FolderPeerHydrationQueue removeAllObjects];
    [_ios6FolderPeerHydrationQueue addObjectsFromArray:missingPeersById.allValues];
    _ios6FolderPeerHydrationLoaded = 0;
    _ios6FolderPeerHydrationFailed = 0;
    _ios6FolderPeerHydrationActive = true;
    [self ios6ContinueFolderPeerHydration];
}

- (NSDictionary *)ios6SelectedDialogFilter
{
    for (NSDictionary *filter in _ios6DialogFilters)
    {
        if ([filter[@"id"] intValue] == _ios6SelectedDialogFilterId)
            return filter;
    }
    return nil;
}

- (bool)ios6ConversationIsUnread:(TGConversation *)conversation
{
    return conversation.unreadMark || conversation.unreadCount > 0 || conversation.serviceUnreadCount > 0;
}

- (bool)ios6Conversation:(TGConversation *)conversation matchesDialogFilter:(NSDictionary *)filter
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

    int32_t flags = [filter[@"flags"] intValue];
    bool matchesType = false;
    if (TGPeerIdIsChannel(peerId) || conversation.isChannel)
    {
        bool isChannelGroup = conversation.isChannelGroup || [conversation.dialogListData[@"isChannelGroup"] boolValue];
        matchesType = isChannelGroup ? ((flags & (1 << 2)) != 0) : ((flags & (1 << 3)) != 0);
    }
    else if (TGPeerIdIsGroup(peerId))
    {
        matchesType = (flags & (1 << 2)) != 0;
    }
    else if (TGPeerIdIsUser(peerId))
    {
        bool isBot = [conversation.dialogListData[@"isBot"] boolValue];
        if (isBot)
            matchesType = (flags & (1 << 4)) != 0;
        else
        {
            bool isContact = [conversation.dialogListData[@"isContact"] boolValue];
            matchesType = isContact ? ((flags & (1 << 0)) != 0) : ((flags & (1 << 1)) != 0);
        }
    }
    else if ([conversation isEncrypted])
    {
        bool isContact = [conversation.dialogListData[@"isContact"] boolValue];
        matchesType = isContact ? ((flags & (1 << 0)) != 0) : ((flags & (1 << 1)) != 0);
    }
    else if (conversation.isBroadcast)
    {
        matchesType = (flags & (1 << 3)) != 0;
    }

    if (!matchesType)
        return false;
    if ((flags & (1 << 11)) && [conversation.dialogListData[@"mute"] boolValue])
        return false;
    if ((flags & (1 << 12)) && ![self ios6ConversationIsUnread:conversation])
        return false;
    bool archivedForFilter = conversation.isArchived || (_ios6ArchivePeerIds != nil && [_ios6ArchivePeerIds containsObject:@(conversation.conversationId)]);
    if ((flags & (1 << 13)) && archivedForFilter)
        return false;
    return true;
}

- (NSArray *)ios6VisibleItemsForDialogFilter:(NSDictionary *)filter
{
    if (filter == nil || [filter[@"id"] intValue] == 0)
    {
        NSMutableArray *normalItems = [[NSMutableArray alloc] init];
        NSMutableArray *archiveItems = [[NSMutableArray alloc] init];
        for (id item in _listModel)
        {
            if ([self ios6IsArchivedConversation:item])
                [archiveItems addObject:item];
            else
                [normalItems addObject:item];
        }
        return _ios6ArchiveExpanded ? archiveItems : normalItems;
    }

    NSMutableDictionary *itemsByPeerId = [[NSMutableDictionary alloc] init];
    NSMutableArray *matchingItems = [[NSMutableArray alloc] init];
    for (id item in [self ios6FolderSourceItems])
    {
        if (![item isKindOfClass:[TGConversation class]])
            continue;
        TGConversation *conversation = (TGConversation *)item;
        if ([self ios6Conversation:conversation matchesDialogFilter:filter])
        {
            [self ios6EnsureDialogListDataForConversation:conversation];
            [matchingItems addObject:conversation];
            itemsByPeerId[@(conversation.conversationId)] = conversation;
        }
    }

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

- (int)ios6UnreadCountForDialogFilter:(NSDictionary *)filter sourceItems:(NSArray *)sourceItems
{
    int count = 0;
    if ([filter[@"id"] intValue] == 0)
    {
        for (id item in _listModel)
        {
            if (![item isKindOfClass:[TGConversation class]] || [self ios6IsArchivedConversation:item])
                continue;
            TGConversation *conversation = (TGConversation *)item;
            [self ios6EnsureDialogListDataForConversation:conversation];
            if ([self ios6ConversationIsUnread:conversation] && ![conversation.dialogListData[@"mute"] boolValue])
                count++;
        }
        return count;
    }
    for (id item in sourceItems)
    {
        if (![item isKindOfClass:[TGConversation class]])
            continue;
        TGConversation *conversation = (TGConversation *)item;
        if ([self ios6Conversation:conversation matchesDialogFilter:filter])
        {
            [self ios6EnsureDialogListDataForConversation:conversation];
            if ([self ios6ConversationIsUnread:conversation] && ![conversation.dialogListData[@"mute"] boolValue])
                count++;
        }
    }
    return count;
}

- (int)ios6UnreadCountForDialogFilter:(NSDictionary *)filter
{
    return [self ios6UnreadCountForDialogFilter:filter sourceItems:[self ios6FolderSourceItems]];
}

- (void)ios6ReloadDialogFilters:(bool)force
{
    if (![self ios6FoldersAllowed])
        return;
    if (TGTelegraphInstance.clientUserId == 0 || !TGTelegraphInstance.clientIsActivated)
    {
        NSLog(@"FOLDERS skip request: authorization not active userId=%d activated=%d",
              TGTelegraphInstance.clientUserId, TGTelegraphInstance.clientIsActivated ? 1 : 0);
        if (!_ios6DialogFiltersAuthorizationRetryScheduled && _ios6DialogFiltersAuthorizationRetryCount < 60)
        {
            _ios6DialogFiltersAuthorizationRetryScheduled = true;
            _ios6DialogFiltersAuthorizationRetryCount++;
            TGDialogListController *controller = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
            {
                controller->_ios6DialogFiltersAuthorizationRetryScheduled = false;
                [controller ios6ReloadDialogFilters:true];
            });
        }
        return;
    }
    _ios6DialogFiltersAuthorizationRetryCount = 0;
    _ios6DialogFiltersAuthorizationRetryScheduled = false;

    if (cpuCoreCount() == 1 && !_isOnScreen && self.navigationController != nil && self.navigationController.topViewController != self)
        return;

    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    NSTimeInterval minimumInterval = force ? 5.0 : 60.0;
    if (_ios6DialogFiltersLastRefreshTime > 0.0 && now - _ios6DialogFiltersLastRefreshTime < minimumInterval)
        return;
    _ios6DialogFiltersLastRefreshTime = now;

    TGIOS6GetDialogFiltersRequest *request = [[TGIOS6GetDialogFiltersRequest alloc] init];
    NSLog(@"FOLDERS request");
    TGDialogListControllerReference *reference = _ios6LifetimeReference;
    [_ios6DialogFiltersDisposable setDisposable:[[[[TGTelegramNetworking instance] requestSignal:request] deliverOn:[SQueue mainQueue]] startWithNext:^(id response)
    {
        [reference withValue:^(void *value)
        {
            __strong TGDialogListController *strongSelf = (__bridge TGDialogListController *)value;

            NSArray *filters = nil;
        @try { filters = [response valueForKey:@"filters"]; } @catch (__unused NSException *exception) { }
        if (![filters isKindOfClass:[NSArray class]])
            filters = @[];

        strongSelf->_ios6DialogFilters = [strongSelf ios6NormalizeDialogFilters:filters];
        strongSelf->_ios6VisibleListCache = nil;
        strongSelf->_ios6VisibleListCacheFilterId = INT32_MIN;
        bool selectedExists = false;
        for (NSDictionary *filter in strongSelf->_ios6DialogFilters)
        {
            if ([filter[@"id"] intValue] == strongSelf->_ios6SelectedDialogFilterId)
            {
                selectedExists = true;
                break;
            }
        }
        if (!selectedExists)
        {
            strongSelf->_ios6SelectedDialogFilterId = 0;
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"TGIOS6SelectedDialogFilterId"];
        }

        NSLog(@"FOLDERS result count=%d selected=%d", (int)strongSelf->_ios6DialogFilters.count, strongSelf->_ios6SelectedDialogFilterId);
        [strongSelf ios6UpdateFolderTabs];
            [strongSelf ios6LayoutFolderTabs];
            [strongSelf reloadData:false];
        }];
    } error:^(id error)
    {
        [reference withValue:^(void *value)
        {
            TGDialogListController *controller = (__bridge TGDialogListController *)value;
            NSString *errorType = [[TGTelegramNetworking instance] extractNetworkErrorType:error];
            NSLog(@"FOLDERS error type=%@", errorType);
        }];
    } completed:nil]];
}

- (void)ios6DialogFiltersUpdated:(NSNotification *)__unused notification
{
    _ios6DialogFiltersLastRefreshTime = 0.0;
    [self ios6ReloadDialogFilters:true];
}

- (void)ios6FolderTabPressed:(UIButton *)button
{
    NSInteger index = button.tag - 6100;
    [self ios6SelectDialogFilterAtIndex:index];
}

- (void)ios6UpdateFolderTabs
{
    if (_ios6FolderTabsScrollView == nil)
        return;
    if (cpuCoreCount() == 1 && _tableView != nil && (_tableView.dragging || _tableView.tracking || _tableView.decelerating))
    {
        _ios6FolderTabsUpdatePending = true;
        return;
    }
    _ios6FolderTabsUpdatePending = false;

    bool classicStyle = [TGPresentation classicIOS6Style];
    _ios6FolderTabsView.backgroundColor = classicStyle ? UIColorRGB(0xf7f7f7) : self.presentation.pallete.backgroundColor;
    _ios6FolderTabsScrollView.backgroundColor = [UIColor clearColor];
    _ios6FolderTabsSeparatorView.backgroundColor = classicStyle ? UIColorRGB(0xc8c8c8) : self.presentation.pallete.separatorColor;
    _ios6FolderEmptyLabel.textColor = classicStyle ? UIColorRGB(0x8e8e93) : self.presentation.pallete.secondaryTextColor;

    NSArray *folderSourceItems = [self ios6FolderSourceItems];
    NSMutableArray *unreadCounts = [[NSMutableArray alloc] initWithCapacity:_ios6DialogFilters.count];
    NSMutableString *stateKey = [[NSMutableString alloc] initWithFormat:@"%d|%d|%.0f", classicStyle ? 1 : 0, _ios6SelectedDialogFilterId, self.view.bounds.size.width];
    for (NSDictionary *filter in _ios6DialogFilters)
    {
        int unread = [self ios6UnreadCountForDialogFilter:filter sourceItems:folderSourceItems];
        [unreadCounts addObject:@(unread)];
        [stateKey appendFormat:@"|%d:%d:%@", [filter[@"id"] intValue], unread, filter[@"title"]];
    }

    if ([_ios6FolderTabsStateKey isEqualToString:stateKey])
    {
        [self ios6UpdateFolderEmptyLabel];
        return;
    }
    _ios6FolderTabsStateKey = [stateKey copy];

    for (UIView *view in [_ios6FolderTabsScrollView.subviews copy])
        [view removeFromSuperview];

    CGFloat x = 8.0f;
    UIFont *font = TGBoldSystemFontOfSize(13.0f);
    NSInteger index = 0;
    UIButton *selectedButton = nil;
    for (NSDictionary *filter in _ios6DialogFilters)
    {
        NSString *title = filter[@"title"];
        int unread = [unreadCounts[index] intValue];
        NSString *badgeText = unread > 999 ? @"999+" : (unread > 0 ? [NSString stringWithFormat:@"%d", unread] : nil);
        CGSize titleSize = [title sizeWithFont:font];
        CGFloat badgeWidth = badgeText.length == 0 ? 0.0f : MAX(18.0f, [badgeText sizeWithFont:TGBoldSystemFontOfSize(11.0f)].width + 10.0f);
        CGFloat width = MAX(64.0f, titleSize.width + 24.0f + (badgeWidth > 0.0f ? badgeWidth + 5.0f : 0.0f));

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = 6100 + index;
        button.frame = CGRectMake(x, 0.0f, width, 37.0f);
        button.titleLabel.font = font;
        [button setTitle:title forState:UIControlStateNormal];
        bool selected = [filter[@"id"] intValue] == _ios6SelectedDialogFilterId;
        UIColor *accent = classicStyle ? UIColorRGB(0x2b78c5) : self.presentation.pallete.accentColor;
        UIColor *normalTitleColor = classicStyle ? UIColorRGB(0x555d66) : self.presentation.pallete.textColor;
        [button setTitleColor:selected ? accent : normalTitleColor forState:UIControlStateNormal];
        [button setTitleColor:[accent colorWithAlphaComponent:0.55f] forState:UIControlStateHighlighted];
        if (badgeWidth > 0.0f)
        {
            button.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, badgeWidth + 5.0f);
            UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(width - badgeWidth - 8.0f, 9.0f, badgeWidth, 18.0f)];
            badge.backgroundColor = selected ? accent : (classicStyle ? UIColorRGB(0xa7afb7) : self.presentation.pallete.secondaryTextColor);
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
            selectedButton = button;
        }
        [button addTarget:self action:@selector(ios6FolderTabPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_ios6FolderTabsScrollView addSubview:button];
        x += width + 2.0f;
        index++;
    }
    _ios6FolderTabsScrollView.contentSize = CGSizeMake(MAX(self.view.bounds.size.width, x + 6.0f), 37.0f);
    if (selectedButton != nil && [self ios6FolderTabsHeight] > 0.0f)
        [_ios6FolderTabsScrollView scrollRectToVisible:CGRectInset(selectedButton.frame, -16.0f, 0.0f) animated:false];
    [self ios6UpdateFolderEmptyLabel];
}

- (void)ios6LayoutFolderTabs
{
    if (_tableView == nil || _ios6FolderTabsView == nil)
        return;

    CGFloat height = [self ios6FolderTabsHeight];
    CGFloat width = _tableView.bounds.size.width;
    _ios6FolderTabsView.hidden = height < FLT_EPSILON;
    _ios6FolderTabsView.frame = CGRectMake(0.0f, 0.0f, width, height);
    _ios6FolderTabsScrollView.frame = CGRectMake(0.0f, 0.0f, width, MAX(0.0f, height - 1.0f));
    _ios6FolderTabsSeparatorView.frame = CGRectMake(0.0f, MAX(0.0f, height - 1.0f), width, height > 0.0f ? 1.0f : 0.0f);
    [self ios6UpdateFolderEmptyLabel];
}

- (void)ios6UpdateFolderEmptyLabel
{
    if (_ios6FolderEmptyLabel == nil)
        return;
    bool show = _ios6SelectedDialogFilterId != 0 && [self ios6VisibleListModel].count == 0 && !_isLoading && !_isDisplayingSearch;
    _ios6FolderEmptyLabel.hidden = !show;
    if (show)
    {
        CGFloat top = self.controllerInset.top + [self ios6FolderTabsHeight];
        _ios6FolderEmptyLabel.frame = CGRectMake(20.0f, top + 40.0f, self.view.bounds.size.width - 40.0f, 44.0f);
        [self.view bringSubviewToFront:_ios6FolderEmptyLabel];
    }
}

- (NSArray *)ios6VisibleListModel
{
    if (_dialogListCompanion.forwardMode || _dialogListCompanion.privacyMode || _dialogListCompanion.showPrivateOnly || _dialogListCompanion.showGroupsAndChannelsOnly)
        return _listModel;
    if (_ios6VisibleListCache != nil && _ios6VisibleListCacheFilterId == _ios6SelectedDialogFilterId)
        return _ios6VisibleListCache;
    NSArray *result = [self ios6VisibleItemsForDialogFilter:[self ios6SelectedDialogFilter]];
    _ios6VisibleListCache = result == nil ? @[] : result;
    _ios6VisibleListCacheFilterId = _ios6SelectedDialogFilterId;
    return _ios6VisibleListCache;
}

- (id)ios6DialogListItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *visibleItems = [self ios6VisibleListModel];
    if (indexPath.row >= 0 && indexPath.row < (NSInteger)visibleItems.count)
        return visibleItems[indexPath.row];
    
    return nil;
}

- (NSUInteger)ios6ArchivedConversationCount
{
    NSUInteger count = 0;
    for (id item in _listModel)
    {
        if ([self ios6IsArchivedConversation:item])
            count++;
    }
    return count;
}

- (int)ios6ArchivedUnreadCount
{
    int count = 0;
    for (id item in _listModel)
    {
        if ([self ios6IsArchivedConversation:item])
        {
            TGConversation *conversation = (TGConversation *)item;
            [self ios6EnsureDialogListDataForConversation:conversation];
            if (![conversation.dialogListData[@"mute"] boolValue])
                count += conversation.unreadCount + MAX(0, conversation.serviceUnreadCount);
        }
    }
    return count;
}

- (UITableViewCell *)ios6ArchiveHeaderCellForTableView:(UITableView *)tableView
{
    static NSString *ArchiveHeaderCellIdentifier = @"IOS6ArchiveHeaderCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ArchiveHeaderCellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ArchiveHeaderCellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    NSUInteger archivedCount = [self ios6ArchivedConversationCount];
    int unreadCount = [self ios6ArchivedUnreadCount];
    cell.textLabel.text = nil;
    cell.imageView.image = nil;
    cell.backgroundColor = _presentation.pallete.backgroundColor;
    cell.contentView.backgroundColor = _presentation.pallete.backgroundColor;
    
    static const NSInteger ContainerTag = 0x6a5101;
    UIView *oldContainer = [cell.contentView viewWithTag:ContainerTag];
    [oldContainer removeFromSuperview];
    
    CGFloat width = tableView.frame.size.width;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(8.0f, 6.0f, MAX(1.0f, width - 16.0f), 42.0f)];
    container.tag = ContainerTag;
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    container.backgroundColor = UIColorRGB(0xf3f8fc);
    container.layer.cornerRadius = 7.0f;
    container.layer.borderWidth = TGIsRetina() ? 0.5f : 1.0f;
    container.layer.borderColor = UIColorRGB(0xd8e8f4).CGColor;
    [cell.contentView addSubview:container];
    
    UILabel *badgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(12.0f, 8.0f, 26.0f, 26.0f)];
    badgeLabel.backgroundColor = UIColorRGB(0x4a90d9);
    badgeLabel.textColor = [UIColor whiteColor];
    badgeLabel.font = TGBoldSystemFontOfSize(17.0f);
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    badgeLabel.text = @"A";
    badgeLabel.layer.cornerRadius = 13.0f;
    badgeLabel.clipsToBounds = true;
    [container addSubview:badgeLabel];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(48.0f, 5.0f, container.frame.size.width - 96.0f, 19.0f)];
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.text = @"Archived Chats";
    titleLabel.font = TGBoldSystemFontOfSize(16.0f);
    titleLabel.textColor = UIColorRGB(0x2f6ea5);
    [container addSubview:titleLabel];
    
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(48.0f, 24.0f, container.frame.size.width - 96.0f, 15.0f)];
    subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    subtitleLabel.backgroundColor = [UIColor clearColor];
    subtitleLabel.text = unreadCount > 0 ? [NSString stringWithFormat:@"%d unread", unreadCount] : [NSString stringWithFormat:@"%d chats", (int)archivedCount];
    subtitleLabel.font = TGSystemFontOfSize(12.0f);
    subtitleLabel.textColor = UIColorRGB(0x7d8b96);
    [container addSubview:subtitleLabel];
    
    UILabel *arrowLabel = [[UILabel alloc] initWithFrame:CGRectMake(container.frame.size.width - 38.0f, 0.0f, 30.0f, 42.0f)];
    arrowLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    arrowLabel.backgroundColor = [UIColor clearColor];
    arrowLabel.textAlignment = NSTextAlignmentCenter;
    arrowLabel.textColor = UIColorRGB(0x7d8b96);
    arrowLabel.font = TGBoldSystemFontOfSize(18.0f);
    arrowLabel.text = _ios6ArchiveExpanded ? @"v" : @">";
    [container addSubview:arrowLabel];
    
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == _tableView)
    {
        if (section == 0)
            return (TGIsPad() && _dialogListCompanion.showBroadcastsMenu) ? 1 : 0;
        
        return [self ios6VisibleListModel].count;
    }
    else
        return [(NSArray *)_searchResultsSections[section][@"items"] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        if (indexPath.section == 0)
            return 45.0f;
        
        id item = [self ios6DialogListItemAtIndexPath:indexPath];
        if ([self ios6IsArchiveHeaderItem:item])
            return 54.0f;
        if (item != nil)
            return 76;
        
        return 0;
    }
    else
    {
        id result = [_searchResultsSections[indexPath.section][@"items"] objectAtIndex:indexPath.row];
        if ([result isKindOfClass:[TGDialogListRecentPeers class]]) {
            //TGDialogListRecentPeers *recentPeers = result;
            return [TGDialogListRecentPeersCell heightForWidth:self.view.frame.size.width count:((TGDialogListRecentPeers *)result).peers.count expanded:false /*recentPeers.identifier == nil ? false : [_expandedRecentPeerIdentifiers containsObject:recentPeers.identifier]*/];
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
    if (cell.reuseTag != (intptr_t)feed || cell.unreadCount != feed.unreadCount || (feed.serviceUnreadCount != -1 && cell.unreadCount != feed.serviceUnreadCount))
    {
        cell.conversationId = feed.conversationId;
        cell.reuseTag = (intptr_t)feed;
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
        
        cell.unreadCount = feed.serviceUnreadCount != -1 ? feed.serviceUnreadCount : feed.unreadCount;
        
        [cell resetView:animated];
    }
}

- (void)prepareCell:(TGDialogListCell *)cell forConversation:(TGConversation *)conversation animated:(bool)animated isSearch:(bool)isSearch
{
    NSDictionary *currentDialogListData = conversation.dialogListData;
    bool shouldBeVerified = [currentDialogListData[@"isVerified"] boolValue];
    int currentIsSavedMessages = [currentDialogListData[@"isSavedMessages"] intValue];
    bool shouldBePremium = [currentDialogListData[@"isPremium"] boolValue] && !currentIsSavedMessages;

    if (cell.reuseTag != (intptr_t)conversation || cell.conversationId != conversation.conversationId || cell.unreadCount != conversation.unreadCount || cell.serviceUnreadCount != conversation.serviceUnreadCount || cell.unreadMentionCount != conversation.unreadMentionCount || cell.isAd != conversation.isAd || cell.isVerified != shouldBeVerified || cell.isPremium != shouldBePremium)
    {
        cell.reuseTag = (intptr_t)conversation;
        cell.conversationId = conversation.conversationId;
    
        cell.date = conversation.unpinnedDate;
        cell.pinnedToTop = conversation.pinnedToTop && !_dialogListCompanion.feedChannels;
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
        cell.titleText = isSavedMessages ? TGLocalized(@"DialogList.SavedMessages") : [dialogListData objectForKey:@"title"];
        cell.titleLetters = [dialogListData objectForKey:@"titleLetters"];
        
        cell.isBroadcast = [dialogListData[@"isBroadcast"] boolValue];
        
        cell.isChannel = TGPeerIdIsChannel(conversation.conversationId);
        cell.isChannelGroup = conversation.isChannelGroup;
        cell.isVerified = shouldBeVerified;
        cell.isPremium = shouldBePremium;
        cell.draft = isSearch ? nil : dialogListData[@"draft"];
        cell.hasExplicitContent = conversation.hasExplicitContent;
        
        cell.isEncrypted = [dialogListData[@"isEncrypted"] boolValue];
        cell.encryptionStatus = [dialogListData[@"encryptionStatus"] intValue];
        cell.encryptedUserId = [dialogListData[@"encryptedUserId"] intValue];
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
        cell.authorName = [authorName isEqualToString:authorNameYou] ? TGLocalized(@"DialogList.You") : authorName;
        cell.authorIsSelf = [dialogListData[@"authorIsSelf"] boolValue];
        
        cell.isMuted = [[dialogListData objectForKey:@"mute"] boolValue];
        
        if (TGPeerIdIsChannel(conversation.conversationId)) {
            int32_t mid = TGConversationSortKeyMid(conversation.variantSortKey);
            cell.unread = mid >= TGMessageLocalMidBaseline || mid > conversation.maxOutgoingReadMessageId;
            
            if (!conversation.isChannelGroup && conversation.outgoing && conversation.deliveryState == TGMessageDeliveryStateDelivered) {
                cell.unread = false;
            }
        } else {
            if ([dialogListData[@"isBot"] boolValue]) {
                cell.unread = false;
            } else {
                cell.unread = conversation.unread;
            }
        }
        
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
        
        cell.messageText = conversation.text;
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
    
    [cell setSwipeActionsEnabled:isSearch || ![self ios6NewChatListGesturesEnabled]];
    [cell restartAnimations:false];
}

- (bool)isLastCell:(NSIndexPath *)indexPath {
    id item = [self ios6DialogListItemAtIndexPath:indexPath];
    if (![item isKindOfClass:[TGConversation class]])
        return true;
    
    bool isLastCell = false;
    TGConversation *conversation = (TGConversation *)item;
    NSArray *visibleItems = [self ios6VisibleListModel];
    if (indexPath.row + 1 < (NSInteger)visibleItems.count && [visibleItems[indexPath.row + 1] isKindOfClass:[TGConversation class]]) {
        TGConversation *nextConversation = visibleItems[indexPath.row + 1];
        isLastCell = (nextConversation.pinnedToTop || nextConversation.isAd || [self ios6IsArchivedConversation:nextConversation]) != (conversation.pinnedToTop || conversation.isAd || [self ios6IsArchivedConversation:conversation]);
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
            id item = [self ios6DialogListItemAtIndexPath:indexPath];
            if ([self ios6IsArchiveHeaderItem:item])
                return [self ios6ArchiveHeaderCellForTableView:tableView];
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
            //TGDialogListRecentPeers *recentPeers = result;
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
                    unreadCounts[@(peerId)] = @([TGDatabaseInstance() unreadCountForConversation:peerId]);
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
                    cell.toggleArchiveConversation = self.toggleArchiveConversation;
                    cell.watcherHandle = _actionHandle;
                    cell.enableEditing = ![_dialogListCompanion forwardMode] && !_dialogListCompanion.privacyMode;
                }
                
                cell.presentation = _presentation;
                [self prepareCell:cell forConversation:conversation animated:false isSearch:false];
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
                    cell.toggleArchiveConversation = self.toggleArchiveConversation;
                    cell.watcherHandle = _actionHandle;
                    //cell.enableEditing = ![_dialogListCompanion forwardMode] && !_dialogListCompanion.privacyMode;
                }
                
                cell.presentation = _presentation;
                [self prepareCell:cell forFeed:(TGFeed *)conversation animated:false];
                [cell setSwipeActionsEnabled:![self ios6NewChatListGesturesEnabled]];
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
                cell.encryptedUserId = [dialogListData[@"encryptedUserId"] intValue];
                
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
            [self prepareCell:cell forConversation:conversation animated:false isSearch:true];
            
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

#pragma mark -

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        int listCount = (int)[self ios6VisibleListModel].count;
        bool ios6FolderPreloadActive = [_dialogListCompanion isKindOfClass:[TGTelegraphDialogListCompanion class]] && [(TGTelegraphDialogListCompanion *)_dialogListCompanion ios6FolderPreloadActive];
        if (!ios6FolderPreloadActive && !_ios6ArchiveExpanded && _canLoadMore && !_isLoading && listCount != 0 && (listCount < 10 || indexPath.row >= listCount - 10))
        {
            TGLog(@"ARCHIVE lazy.load trigger row=%d visible=%d model=%d archive=%d", (int)indexPath.row, listCount, (int)_listModel.count, _ios6ArchiveExpanded ? 1 : 0);
            [self ios6ScheduleLazyLoadMoreItems:15];
        }
        
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
            
            if (dialogCell.conversationId == _scheduledHighlightAnimationConversationId)
            {
                _scheduledHighlightAnimationConversationId = 0;
                [dialogCell animateHighlight];
            }
            
            if (iosMajorVersion() < 7)
            {
                UIColor *backgroundColor = dialogCell.pinnedToTop || dialogCell.isAd || dialogCell.isSavedMessages == 2 ? self.presentation.pallete.dialogPinnedBackgroundColor : self.presentation.pallete.backgroundColor;
                cell.backgroundColor = backgroundColor;
            }
        }
    }
    else
    {
        
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        if (indexPath.section == 0)
            return false;
        
        id visibleItem = [self ios6DialogListItemAtIndexPath:indexPath];
        if ([visibleItem isKindOfClass:[TGFeed class]]) {
            return true;
        }
        if ([visibleItem isKindOfClass:[TGConversation class]]) {
            TGConversation *item = visibleItem;
            if (item.isAd) {
                return false;
            }
            if ([self ios6IsArchiveHeaderItem:visibleItem]) {
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
        id item = [self ios6DialogListItemAtIndexPath:indexPath];
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
    [self ios6LayoutFolderTabs];
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
    [self ios6LayoutFolderTabs];
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
    
    if ((scrollView.isDragging || scrollView.isTracking) && _scrollingToConversationId != 0)
        _scrollingToConversationId = 0;

    if ((scrollView.isDragging || scrollView.isTracking) && !_ios6SearchPullArmed && !_searchMixin.isActive && !_doNotHideSearchAutomatically && _searchBar != nil)
    {
        CGFloat hiddenOffset = -_tableView.contentInset.top + [TGSearchBar searchBarBaseHeight] + self.explicitTableInset.top;
        if (scrollView.contentOffset.y < hiddenOffset)
            scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, hiddenOffset);
    }
    
    bool atTop = scrollView.contentOffset.y <= -_tableView.tableHeaderView.frame.size.height + FLT_EPSILON;
    [_atTopPromise set:[SSignal single:@(atTop)]];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if (scrollView == _tableView)
        _scrollingToConversationId = 0;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (scrollView == _tableView && !decelerate && _ios6FolderTabsUpdatePending)
        [self ios6UpdateFolderTabs];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView == _tableView && _ios6FolderTabsUpdatePending)
        [self ios6UpdateFolderTabs];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (scrollView == _tableView)
    {
        _draggingStartOffset = scrollView.contentOffset.y;
        CGFloat hiddenOffset = -_tableView.contentInset.top + [TGSearchBar searchBarBaseHeight] + self.explicitTableInset.top;
        _ios6SearchPullArmed = _searchBar != nil && scrollView.contentOffset.y <= hiddenOffset + 1.0f;
    }
    
    if (_searchMixin.isActive && scrollView == _searchMixin.searchResultsTableView)
        [_searchBar resignFirstResponder];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)__unused velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (scrollView == _tableView)
    {
        if (targetContentOffset != NULL)
        {
            CGFloat shownOffset = -_tableView.contentInset.top + self.explicitTableInset.top;
            CGFloat searchHeight = [TGSearchBar searchBarBaseHeight];
            CGFloat hiddenOffset = shownOffset + searchHeight;

            if (!_ios6SearchPullArmed && !_searchMixin.isActive && !_doNotHideSearchAutomatically && _searchBar != nil && targetContentOffset->y < hiddenOffset)
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
        id item = [self ios6DialogListItemAtIndexPath:indexPath];
        if ([item isKindOfClass:[TGConversation class]] || [item isKindOfClass:[TGFeed class]])
            conversation = item;
        
        if (conversation != nil)
        {
            int64_t conversationIdToDelete = conversation.conversationId;
            
            NSMutableArray *actions = [[NSMutableArray alloc] init];
            
            TGUser *user = conversation.conversationId > 0 ? [TGDatabaseInstance() loadUser:(int)conversation.conversationId] : nil;

            if ([conversation isKindOfClass:[TGFeed class]])
            {
                [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"DialogList.UngroupAllChannels") action:@"delete" type:TGActionSheetActionTypeDestructive]];
            }
            else if (conversation.conversationId > 0 && (user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot))
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
        if ([result isKindOfClass:[TGDialogListRecentPeers class]]) {
        } else {
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
    
    [self setLeftBarButtonItem:[self controllerLeftBarButtonItem]];
    
    [self setTitleText:TGLocalized(@"DialogList.Title")];
    
    _titleLabel.text = TGLocalized(@"DialogList.Title");
    [_titleLabel sizeToFit];
    [self _layoutTitleViews:self.interfaceOrientation];
    
    for (id cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            [(TGDialogListCell *)cell resetLocalization];
            ((TGDialogListCell *)cell).reuseTag = -1;
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
    for (id item in [self ios6VisibleListModel])
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
        if (section == 1 && [self ios6FolderTabsHeight] > FLT_EPSILON)
        {
            [self ios6LayoutFolderTabs];
            return _ios6FolderTabsView;
        }
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
        
        /*CGFloat separatorHeight = TGScreenPixel;
        UIView *separatorView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, sectionView.frame.origin.y - (first ? separatorHeight : 0.0f), 10, separatorHeight)];
        separatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        separatorView.backgroundColor = TGSeparatorColor();
        [sectionContainer addSubview:separatorView];*/
        
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
        return section == 1 ? [self ios6FolderTabsHeight] : 0.0f;
    
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
                
                TGModernConversationController *controller = dialogCell.isFeed ? [[TGInterfaceManager instance] configuredPreviewFeedControllerWithId:TGAdminLogIdFromPeerId(dialogCell.conversationId)] : [[TGInterfaceManager instance] configuredPreviewConversationControlerWithId:dialogCell.conversationId];
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
                [[TGInterfaceManager instance] navigateToChannelsFeed:TGAdminLogIdFromPeerId(feedCompanion.conversationId) animated:true];
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
    NSArray *visibleItems = [self ios6VisibleListModel];
    if (visibleItems.count == 0)
        return;
    
    TGConversation *conversation = nil;
    for (id item in visibleItems)
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
    for (TGConversation *conversation in [self ios6VisibleListModel])
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
    for (TGConversation *conversation in [self ios6VisibleListModel])
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
    TGConversation *conversation = (TGConversation *)[self ios6DialogListItemAtIndexPath:indexPath];
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
    if (_ios6SelectedDialogFilterId != 0)
        return false;
    if (tableView == _tableView) {
        if (indexPath.section != 0) {
            TGConversation *conversation = (TGConversation *)[self ios6DialogListItemAtIndexPath:indexPath];
            return conversation.pinnedToTop;
        }
    }
    return false;
}

- (void)moveObjectAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if (fromIndex < toIndex) {
        //toIndex--;
    }
    
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
    NSString *text = TGLocalized(@"DialogList.ProxyConnectionIssuesTooltip");
    if (_recordTooltipContainerView == nil) {
        TGTooltipContainerView *tooltipContainerView = [[TGTooltipContainerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height)];
        _recordTooltipContainerView = tooltipContainerView;
        _recordTooltipContainerView.tooltipView.numberOfLines = 0;
        _recordTooltipContainerView.tooltipView.forceArrowOnTop = true;
        [self.navigationController.view addSubview:_recordTooltipContainerView];
        
        [_recordTooltipContainerView.tooltipView setText:text animated:false];
        _recordTooltipContainerView.tooltipView.sourceView = _proxyButton;
        
        CGRect recordButtonFrame = [_proxyButton convertRect:_proxyButton.bounds toView:_recordTooltipContainerView];
        recordButtonFrame.origin.y += 30.0f;
        recordButtonFrame.origin.x += 9.0f;
        [_recordTooltipContainerView showTooltipFromRect:recordButtonFrame animated:false];
        
        __weak TGTooltipContainerView *weakContainerView = _recordTooltipContainerView;
        [[[SSignal complete] delay:7.0 onQueue:[SQueue mainQueue]] startWithNext:nil completed:^{
            __strong TGTooltipContainerView *strongContainerView = weakContainerView;
            if (strongContainerView != nil)
                [strongContainerView hideTooltip];
        }];
    }
}

- (void)createContactControllerDidFinish:(TGCreateContactController *)__unused createContactController
{
    [self dismissViewControllerAnimated:true completion:nil];
}

- (void)openProxySettings {
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
    [self ios6LayoutFolderTabs];
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
    _ios6FolderTabsStateKey = nil;

    if (self.isViewLoaded)
        self.view.backgroundColor = _presentation.pallete.backgroundColor;
    _headerBackgroundView.backgroundColor = _presentation.pallete.backgroundColor;
    [self updateSearchBarBackground];
    
    [self updateProxyButton];
    _proxyButton.spinner = _presentation.images.dialogProxySpinner;
    
    _tableView.backgroundColor = _presentation.pallete.backgroundColor;
    
    [_searchBar setPallete:presentation.searchBarPallete];
    
    _titleLockIconView.presentation = self.presentation;
    _titleLabel.textColor = TGDialogListNavigationTitleColor(self.presentation);
    _titleLabel.shadowColor = [UIColor clearColor];
    _titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
    _titleStatusLabel.textColor = TGDialogListNavigationTitleColor(_presentation);
    _titleStatusLabel.shadowColor = [UIColor clearColor];
    _titleStatusLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
    _titleStatusSubtitleLabel.textColor = TGDialogListNavigationSubtitleColor(_presentation);
    _titleStatusIndicator.color = _presentation.pallete.navigationSpinnerColor;
    
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
    
    if (iosMajorVersion() >= 7)
        _tableView.separatorColor = _presentation.pallete.separatorColor;
    
    _primaryTitlePanel.presentation = self.presentation;

    [self ios6UpdateFolderTabs];
    [self ios6LayoutFolderTabs];
    
    [self updateBarButtonItemsAnimated:false];
}

- (void)updateProxyButton
{
    if (TGTelegraphInstance.clientUserId == 0)
        return;
    
    bool connecting = _state == TGDialogListStateConnecting;
    bool connectingToProxy = _state == TGDialogListStateConnectingToProxy || _state == TGDialogListStateHasProxyIssues;
    
    bool buttonHidden = true;
    bool spinning = false;
    
    UIImage *icon = self.presentation.images.dialogProxyConnectedIcon;
    if (connectingToProxy && _hasSelectedProxy)
    {
        buttonHidden = false;
        icon = self.presentation.images.dialogProxyShieldIcon;
        spinning = true;
    }
    else if (connecting && _hasAnyProxy)
    {
        buttonHidden = false;
        icon = self.presentation.images.dialogProxyConnectIcon;
    }
    else if (_state == TGDialogListStateNormal || _state == TGDialogListStateUpdating)
    {
        if (_alwaysShowProxy) {
            buttonHidden = !_hasAnyProxy;
            icon = _hasSelectedProxy ? self.presentation.images.dialogProxyConnectedIcon : self.presentation.images.dialogProxyConnectIcon;
        } else {
            buttonHidden = !_hasSelectedProxy;
        }
    }
    
    _proxyButton.hidden = buttonHidden;
    _proxyButton.icon = icon;
    
    [_proxyButton setSpinning:spinning];
}

@end
