#import "TGChannelDirectMessagesController.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"

#import "TGDatabase.h"
#import "TGInterfaceManager.h"
#import "TGPresentation.h"
#import "TGChannelDirectMessagesSignals.h"

static const int32_t TGChannelDirectMessagesThreadsPageSize = 50;
static const CGFloat TGChannelDirectMessagesRowHeight = 62.0f;
static const CGFloat TGChannelDirectMessagesAvatarSize = 40.0f;

static NSString *TGChannelDirectMessagesMediaDescription(TGMessage *message)
{
    for (id attachment in message.mediaAttachments)
    {
        if ([attachment isKindOfClass:[TGImageMediaAttachment class]])
            return TGLocalized(@"Message.Photo");
        if ([attachment isKindOfClass:[TGVideoMediaAttachment class]])
            return ((TGVideoMediaAttachment *)attachment).roundMessage ? TGLocalized(@"Message.VideoMessage") : TGLocalized(@"Message.Video");
        if ([attachment isKindOfClass:[TGAudioMediaAttachment class]])
            return TGLocalized(@"Message.Audio");
        if ([attachment isKindOfClass:[TGLocationMediaAttachment class]])
            return TGLocalized(@"Message.Location");
        if ([attachment isKindOfClass:[TGContactMediaAttachment class]])
            return TGLocalized(@"Message.Contact");
        if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]])
        {
            TGDocumentMediaAttachment *document = (TGDocumentMediaAttachment *)attachment;
            if ([document isSticker])
                return TGLocalized(@"Message.Sticker");
            if ([document isVoice])
                return TGLocalized(@"Message.Audio");
            if ([document isRoundVideo])
                return TGLocalized(@"Message.VideoMessage");
            if ([document isAnimated])
                return TGLocalized(@"Message.Animation");
            return TGLocalized(@"Message.File");
        }
    }
    return nil;
}

static NSString *TGChannelDirectMessagesPreviewText(TGMessage *message)
{
    if (message == nil)
        return @"";

    NSString *body = [[message.text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
    body = [body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (body.length == 0)
        body = TGChannelDirectMessagesMediaDescription(message) ?: @"";

    if (message.outgoing && body.length != 0)
        return [[NSString alloc] initWithFormat:@"%@: %@", TGLocalized(@"DialogList.You"), body];
    return body;
}

static NSUInteger TGChannelDirectMessagesIndexOfThread(NSArray *threads, int64_t peerId)
{
    for (NSUInteger index = 0; index < threads.count; index++)
    {
        if (((TGChannelDirectMessagesThread *)threads[index]).peerId == peerId)
            return index;
    }
    return NSNotFound;
}

static NSArray *TGChannelDirectMessagesMessagesFromResource(id resource)
{
    id object = [resource isKindOfClass:[SGraphObjectNode class]] ? ((SGraphObjectNode *)resource).object : resource;
    if ([object isKindOfClass:[NSArray class]])
        return object;

    if (![object isKindOfClass:[NSDictionary class]])
        return @[];

    NSMutableArray *messages = [[NSMutableArray alloc] init];
    NSArray *added = object[@"added"];
    if ([added isKindOfClass:[NSArray class]])
        [messages addObjectsFromArray:added];
    NSDictionary *updated = object[@"updated"];
    if ([updated isKindOfClass:[NSDictionary class]])
        [messages addObjectsFromArray:updated.allValues];
    return messages;
}

@interface TGChannelDirectMessagesThreadCell : UITableViewCell
{
    TGLetteredAvatarView *_avatarView;
    UILabel *_titleLabel;
    UILabel *_previewLabel;
    UILabel *_dateLabel;
    UIImageView *_badgeView;
    UILabel *_badgeLabel;
}

- (void)setThread:(TGChannelDirectMessagesThread *)thread presentation:(TGPresentation *)presentation;

@end

@implementation TGChannelDirectMessagesThreadCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, TGChannelDirectMessagesAvatarSize, TGChannelDirectMessagesAvatarSize)];
        [_avatarView setSingleFontSize:18.0f doubleFontSize:18.0f useBoldFont:false];
        [self.contentView addSubview:_avatarView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
        [self.contentView addSubview:_titleLabel];

        _previewLabel = [[UILabel alloc] init];
        _previewLabel.backgroundColor = [UIColor clearColor];
        _previewLabel.font = [UIFont systemFontOfSize:14.0f];
        _previewLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_previewLabel];

        _dateLabel = [[UILabel alloc] init];
        _dateLabel.backgroundColor = [UIColor clearColor];
        _dateLabel.font = [UIFont systemFontOfSize:13.0f];
        _dateLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_dateLabel];

        _badgeView = [[UIImageView alloc] init];
        [self.contentView addSubview:_badgeView];

        _badgeLabel = [[UILabel alloc] init];
        _badgeLabel.backgroundColor = [UIColor clearColor];
        _badgeLabel.font = [UIFont systemFontOfSize:14.0f];
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_badgeLabel];

        self.selectedBackgroundView = [[UIView alloc] init];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [_avatarView prepareForReuse];
}

- (void)setThread:(TGChannelDirectMessagesThread *)thread presentation:(TGPresentation *)presentation
{
    TGPresentationPallete *pallete = presentation.pallete;
    self.backgroundColor = pallete.backgroundColor;
    self.selectedBackgroundView.backgroundColor = pallete.selectionColor;
    _titleLabel.textColor = pallete.textColor;
    _previewLabel.textColor = pallete.secondaryTextColor;
    _dateLabel.textColor = pallete.secondaryTextColor;
    _badgeLabel.textColor = pallete.dialogBadgeTextColor;
    _badgeView.image = presentation.images.dialogBadgeImage;

    CGSize avatarSize = CGSizeMake(TGChannelDirectMessagesAvatarSize, TGChannelDirectMessagesAvatarSize);
    NSString *avatarFilter = [[NSString alloc] initWithFormat:@"circle:%dx%d", (int)avatarSize.width, (int)avatarSize.height];
    UIImage *placeholder = [presentation.images avatarPlaceholderWithDiameter:avatarSize.width];
    TGUser *user = TGPeerIdIsUser(thread.peerId) ? [TGDatabaseInstance() loadUser:thread.peerId] : nil;
    if (user != nil)
    {
        _titleLabel.text = user.displayName;
        if (user.photoUrlSmall.length != 0)
            [_avatarView loadImage:user.photoFullUrlSmall filter:avatarFilter placeholder:placeholder];
        else
            [_avatarView loadUserPlaceholderWithSize:avatarSize uid:user.uid firstName:user.firstName lastName:user.lastName placeholder:placeholder];
    }
    else
    {
        TGConversation *peer = [TGDatabaseInstance() loadConversationWithId:thread.peerId];
        _titleLabel.text = peer.chatTitle;
        if (peer.chatPhotoSmall.length != 0)
            [_avatarView loadImage:peer.chatPhotoFullSmall filter:avatarFilter placeholder:placeholder];
        else
            [_avatarView loadGroupPlaceholderWithSize:avatarSize conversationId:thread.peerId title:peer.chatTitle placeholder:placeholder];
    }

    _previewLabel.text = TGChannelDirectMessagesPreviewText(thread.topMessage);
    _dateLabel.text = thread.topMessage == nil ? nil : [TGDateUtils stringForMessageListDate:(int)thread.topMessage.date];

    bool hasBadge = thread.unreadCount > 0 || thread.unreadMark;
    _badgeView.hidden = !hasBadge;
    _badgeLabel.hidden = !hasBadge;
    if (thread.unreadCount <= 0)
        _badgeLabel.text = nil;
    else if (thread.unreadCount < 1000)
        _badgeLabel.text = [[NSString alloc] initWithFormat:@"%d", thread.unreadCount];
    else
        _badgeLabel.text = [[NSString alloc] initWithFormat:@"%dK", thread.unreadCount / 1000];

    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = self.contentView.bounds.size.width;
    CGFloat left = 62.0f;
    CGFloat right = width - 10.0f;

    _avatarView.frame = CGRectMake(11.0f, 11.0f, TGChannelDirectMessagesAvatarSize, TGChannelDirectMessagesAvatarSize);

    CGFloat titleRight = right;
    if (_dateLabel.text.length != 0)
    {
        CGFloat dateWidth = CGCeil([_dateLabel.text sizeWithFont:_dateLabel.font].width);
        _dateLabel.frame = CGRectMake(right - dateWidth, 9.0f, dateWidth, 18.0f);
        titleRight = _dateLabel.frame.origin.x - 6.0f;
    }
    else
        _dateLabel.frame = CGRectZero;

    CGFloat previewRight = right;
    if (!_badgeView.hidden)
    {
        CGFloat textWidth = _badgeLabel.text.length == 0 ? 0.0f : CGCeil([_badgeLabel.text sizeWithFont:_badgeLabel.font].width);
        CGFloat badgeWidth = MAX(20.0f, textWidth + 11.0f);
        _badgeView.frame = CGRectMake(right - badgeWidth, 34.0f, badgeWidth, 20.0f);
        _badgeLabel.frame = CGRectMake(_badgeView.frame.origin.x, 35.0f, badgeWidth, 18.0f);
        previewRight = _badgeView.frame.origin.x - 6.0f;
    }

    _titleLabel.frame = CGRectMake(left, 7.0f, MAX(0.0f, titleRight - left), 21.0f);
    _previewLabel.frame = CGRectMake(left, 33.0f, MAX(0.0f, previewRight - left), 20.0f);
}

@end

@interface TGChannelDirectMessagesControllerReference : NSObject

@property (nonatomic, weak) TGChannelDirectMessagesController *value;

@end

@implementation TGChannelDirectMessagesControllerReference

@end

static TGChannelDirectMessagesController *TGChannelDirectMessagesResolveController(TGChannelDirectMessagesControllerReference *reference)
{
    TGChannelDirectMessagesController *result = nil;
    @synchronized (reference)
    {
        result = reference.value;
    }
    return result;
}

@interface TGChannelDirectMessagesController () <UITableViewDelegate, UITableViewDataSource, ASWatcher>
{
    TGConversation *_monoforum;
    TGChannelDirectMessagesControllerReference *_lifetimeReference;
    TGPresentation *_presentation;
    id<SDisposable> _presentationDisposable;
    SMetaDisposable *_requestDisposable;

    UITableView *_tableView;
    UILabel *_placeholderLabel;

    NSArray *_threads;
    bool _hasMore;
    bool _loading;
    bool _failed;
    bool _refreshScheduled;
    int _requestGeneration;
}

@property (nonatomic, strong) ASHandle *actionHandle;

@end

@implementation TGChannelDirectMessagesController

- (instancetype)initWithMonoforum:(TGConversation *)monoforum
{
    self = [super init];
    if (self != nil)
    {
        _monoforum = monoforum;
        _threads = @[];
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        _requestDisposable = [[SMetaDisposable alloc] init];
        _lifetimeReference = [[TGChannelDirectMessagesControllerReference alloc] init];
        _lifetimeReference.value = self;
        _presentation = [TGPresentation current];

        self.title = TGLocalized(@"Channel.DirectMessages.Title");
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Back") style:UIBarButtonItemStylePlain target:nil action:nil];

        TGChannelDirectMessagesControllerReference *reference = _lifetimeReference;
        _presentationDisposable = [[[TGPresentation signal] deliverOn:[SQueue mainQueue]] startWithNext:^(TGPresentation *presentation)
        {
            TGChannelDirectMessagesController *strongSelf = TGChannelDirectMessagesResolveController(reference);
            if (strongSelf != nil)
                [strongSelf _applyPresentation:presentation];
        }];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    @synchronized (_lifetimeReference)
    {
        _lifetimeReference.value = nil;
    }
    [_requestDisposable dispose];
    [_presentationDisposable dispose];
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
}

- (int64_t)monoforumPeerId
{
    return _monoforum.conversationId;
}

- (void)loadView
{
    [super loadView];

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    if (iosMajorVersion() >= 11)
        _tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.rowHeight = TGChannelDirectMessagesRowHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.tableFooterView = [[UIView alloc] init];
    [self.view addSubview:_tableView];

    _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 90.0f, self.view.bounds.size.width - 40.0f, 60.0f)];
    _placeholderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _placeholderLabel.backgroundColor = [UIColor clearColor];
    _placeholderLabel.textAlignment = NSTextAlignmentCenter;
    _placeholderLabel.font = [UIFont systemFontOfSize:14.0f];
    _placeholderLabel.numberOfLines = 2;
    [self.view addSubview:_placeholderLabel];

    [self _applyPresentation:_presentation];
    [self _updatePlaceholder];

    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    int64_t peerId = _monoforum.conversationId;
    [ActionStageInstance() removeWatcher:self];
    [ActionStageInstance() watchForPaths:@[
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/messages", peerId],
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/importantMessages", peerId],
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/unimportantMessages", peerId],
        [[NSString alloc] initWithFormat:@"/messagesEditedInConversation/(%lld)", peerId],
        [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/messagesDeleted", peerId]
    ] watcher:self];

    [self _reloadThreads];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [ActionStageInstance() removeWatcher:self];
    [super viewWillDisappear:animated];
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];

    if (_tableView == nil)
        return;

    UIEdgeInsets inset = self.controllerInset;
    CGPoint contentOffset = _tableView.contentOffset;
    _tableView.contentInset = inset;
    _tableView.scrollIndicatorInsets = self.controllerScrollInset;

    if (!UIEdgeInsetsEqualToEdgeInsets(previousInset, UIEdgeInsetsZero))
        contentOffset.y = MAX(-inset.top, contentOffset.y + previousInset.top - inset.top);
    else
        contentOffset.y = -inset.top;
    [_tableView setContentOffset:contentOffset animated:false];
}

- (void)_applyPresentation:(TGPresentation *)presentation
{
    if (presentation == nil)
        return;

    _presentation = presentation;
    if (_tableView == nil)
        return;

    TGPresentationPallete *pallete = presentation.pallete;
    self.view.backgroundColor = pallete.backgroundColor;
    _tableView.backgroundColor = pallete.backgroundColor;
    _tableView.separatorColor = pallete.separatorColor;
    _placeholderLabel.textColor = pallete.secondaryTextColor;
    [_tableView reloadData];
}

- (void)_updatePlaceholder
{
    _placeholderLabel.hidden = _threads.count != 0;
    if (_loading)
        _placeholderLabel.text = TGLocalized(@"Channel.DirectMessages.Loading");
    else if (_failed)
        _placeholderLabel.text = TGLocalized(@"Channel.DirectMessages.LoadFailed");
    else
        _placeholderLabel.text = TGLocalized(@"Channel.DirectMessages.Empty");
}

- (void)_requestThreadsAfter:(TGChannelDirectMessagesThread *)lastThread
{
    int generation = ++_requestGeneration;
    bool replace = lastThread == nil;
    _loading = true;
    _failed = false;
    [self _updatePlaceholder];

    TGChannelDirectMessagesControllerReference *reference = _lifetimeReference;
    SSignal *signal = [[TGChannelDirectMessagesSignals threadsForMonoforum:_monoforum after:lastThread limit:TGChannelDirectMessagesThreadsPageSize] deliverOn:[SQueue mainQueue]];
    [_requestDisposable setDisposable:[signal startWithNext:^(TGChannelDirectMessagesThreadsPage *page)
    {
        TGChannelDirectMessagesController *strongSelf = TGChannelDirectMessagesResolveController(reference);
        if (strongSelf != nil && strongSelf->_requestGeneration == generation)
            [strongSelf _applyPage:page replace:replace];
    } error:^(__unused id error)
    {
        TGChannelDirectMessagesController *strongSelf = TGChannelDirectMessagesResolveController(reference);
        if (strongSelf == nil || strongSelf->_requestGeneration != generation)
            return;
        strongSelf->_loading = false;
        strongSelf->_failed = true;
        [strongSelf _updatePlaceholder];
    } completed:nil]];
}

- (void)_reloadThreads
{
    [self _requestThreadsAfter:nil];
}

- (void)_loadMoreThreads
{
    if (_loading || !_hasMore)
        return;

    for (TGChannelDirectMessagesThread *thread in _threads.reverseObjectEnumerator)
    {
        if (thread.topMessage != nil)
        {
            [self _requestThreadsAfter:thread];
            return;
        }
    }
    _hasMore = false;
}

- (void)_applyPage:(TGChannelDirectMessagesThreadsPage *)page replace:(bool)replace
{
    _loading = false;

    if (replace)
    {
        _threads = page.threads;
        _hasMore = page.hasMore;
    }
    else
    {
        NSMutableArray *threads = [[NSMutableArray alloc] initWithArray:_threads];
        for (TGChannelDirectMessagesThread *thread in page.threads)
        {
            if (TGChannelDirectMessagesIndexOfThread(threads, thread.peerId) == NSNotFound)
                [threads addObject:thread];
        }
        _hasMore = page.hasMore && threads.count > _threads.count;
        _threads = threads;
    }

    [self _updatePlaceholder];
    [_tableView reloadData];
}

- (void)_scheduleRefresh
{
    if (_refreshScheduled)
        return;

    _refreshScheduled = true;
    TGChannelDirectMessagesControllerReference *reference = _lifetimeReference;
    TGDispatchAfter(0.35, dispatch_get_main_queue(), ^
    {
        TGChannelDirectMessagesController *strongSelf = TGChannelDirectMessagesResolveController(reference);
        if (strongSelf == nil)
            return;
        strongSelf->_refreshScheduled = false;
        if (strongSelf.isViewLoaded && strongSelf.view.window != nil)
            [strongSelf _reloadThreads];
    });
}

- (void)_applyLiveMessages:(NSArray *)messages
{
    NSMutableArray *threads = [[NSMutableArray alloc] initWithArray:_threads];
    bool changed = false;
    bool needsRefresh = false;

    for (TGMessage *message in messages)
    {
        if (![message isKindOfClass:[TGMessage class]] || message.cid != _monoforum.conversationId || message.savedPeerId == 0)
            continue;

        NSUInteger index = TGChannelDirectMessagesIndexOfThread(threads, message.savedPeerId);
        if (index == NSNotFound)
        {
            needsRefresh = true;
            continue;
        }

        TGChannelDirectMessagesThread *thread = threads[index];
        TGChannelDirectMessagesThread *updatedThread = [thread threadByApplyingMessage:message];
        if (updatedThread == thread)
            continue;

        [threads removeObjectAtIndex:index];
        [threads insertObject:updatedThread atIndex:updatedThread.topMessageId != thread.topMessageId ? 0 : index];
        changed = true;
    }

    if (changed)
    {
        _threads = threads;
        [self _updatePlaceholder];
        [_tableView reloadData];
    }

    if (needsRefresh)
        [self _scheduleRefresh];
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path hasSuffix:@"/messagesDeleted"])
    {
        TGDispatchOnMainThread(^
        {
            [self _scheduleRefresh];
        });
        return;
    }

    NSArray *messages = TGChannelDirectMessagesMessagesFromResource(resource);
    if (messages.count == 0)
        return;

    TGDispatchOnMainThread(^
    {
        [self _applyLiveMessages:messages];
    });
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)__unused section
{
    return (NSInteger)_threads.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"TGChannelDirectMessagesThreadCell";
    TGChannelDirectMessagesThreadCell *cell = (TGChannelDirectMessagesThreadCell *)[tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil)
        cell = [[TGChannelDirectMessagesThreadCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];

    if ((NSUInteger)indexPath.row < _threads.count)
        [cell setThread:_threads[indexPath.row] presentation:_presentation];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:true];
    if ((NSUInteger)indexPath.row >= _threads.count)
        return;

    TGChannelDirectMessagesThread *thread = _threads[indexPath.row];
    NSMutableArray *threads = [[NSMutableArray alloc] initWithArray:_threads];
    threads[indexPath.row] = [thread threadByReadingInboxUpTo:thread.topMessageId];
    _threads = threads;
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];

    TGNavigationController *navigationController = [self.navigationController isKindOfClass:[TGNavigationController class]] ? (TGNavigationController *)self.navigationController : nil;
    [[TGInterfaceManager instance] navigateToConversationWithId:_monoforum.conversationId conversation:_monoforum performActions:@{@"monoforumPeerId": @(thread.peerId)} atMessage:nil clearStack:false openKeyboard:false canOpenKeyboardWhileInTransition:false navigationController:navigationController selectChat:false animated:true];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.contentOffset.y + scrollView.bounds.size.height > scrollView.contentSize.height - TGChannelDirectMessagesRowHeight * 3.0f)
        [self _loadMoreThreads];
}

@end
