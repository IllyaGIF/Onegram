#import "TGAccountSettingsController.h"
#import "TGOnegramCoreController.h"
#import "TGAccountSwitcherPanel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGLegacyComponentsContext.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"

#import "TGTimelineItem.h"
#import "TGTimelineUploadPhotoRequestBuilder.h"
#import "TGDeleteProfilePhotoActor.h"

#import "TGNotificationSettingsController.h"
#import "TGChatSettingsController.h"
#import "TGPrivacySettingsController.h"
#import "TGAuthSessionsController.h"

#import "TGAccountInfoCollectionItem.h"
#import "TGHeaderCollectionItem.h"
#import "TGDisclosureActionCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGWallpapersCollectionItem.h"
#import "TGVariantCollectionItem.h"
#import "TGSwitchCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGVersionCollectionItem.h"

#import "TGWallpaperListController.h"
#import "TGWallpaperManager.h"

#import "TGCustomAlertView.h"
#import "TGCustomActionSheet.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

#import "TGDatabase.h"
#import "TGTelegraph.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"
#import "../OnegramRuntime/OGRuntime.h"

#import "TGAppDelegate.h"
#import "TGInterfaceManager.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryController.h"
#import "TGProfileUserAvatarGalleryModel.h"
#import "TGProfileUserAvatarGalleryItem.h"

#import "TGSettingsController.h"
#import "TGForwardTargetController.h"

#import "TGUsernameController.h"

#import "TGCustomAlertView.h"

#import "TGAccountSettingsActor.h"

#import "TGChangePhoneNumberHelpController.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGMediaAvatarMenuMixin.h"
#import "TGWebSearchController.h"

#import "TGUserAboutSetupController.h"

#import "TGStickerPacksSettingsController.h"
#import "TGRecentCallsController.h"

#import "TGStickersSignals.h"
#import "TGUserSignal.h"
#import "TGProxySignals.h"
#import "TGPassportSignals.h"

#import "TGLocalizationSelectionController.h"
#import "TGEditProfileController.h"

#import "TGAppearanceController.h"
#import "TGPresentation.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGSettingsAppearance.h"
#import "../OnegramUI/Lists/OGSettingsCell.h"
#import "../legacy/TelegraphKit/TGCommon.h"
#import "TGProxySetupController.h"
#import "TGPassportRequestController.h"
#import "TGTelegramNetworking.h"

#import "TGTwoStepConfigSignal.h"

#import "TGMusicPlayer.h"
#import "TGMusicPlayerItem.h"
#import "TGMusicPlayerPlaylist.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDocumentMediaAttachment.h"

#import "TGLegacyComponentsContext.h"
#import <QuartzCore/QuartzCore.h>

@class TGIOS6LogFileSwipeGate;

@interface TGIOS6LogFileCell : UITableViewCell
{
    UIButton *_deleteButton;
    UIPanGestureRecognizer *_swipeRecognizer;
    TGIOS6LogFileSwipeGate *_swipeGate;
    CGFloat _swipeOffset;
    CGFloat _initialSwipeOffset;
}
@property (nonatomic, copy) void (^deleteRequested)(void);
- (void)closeSwipeAnimated:(bool)animated;
- (bool)swipeIsOpen;
- (bool)swipeRecognizerShouldBegin:(UIGestureRecognizer *)recognizer;
@end

@interface TGIOS6LogFileSwipeGate : NSObject <UIGestureRecognizerDelegate>
{
    __weak TGIOS6LogFileCell *_cell;
}
- (instancetype)initWithCell:(TGIOS6LogFileCell *)cell;
@end

@implementation TGIOS6LogFileSwipeGate

- (instancetype)initWithCell:(TGIOS6LogFileCell *)cell
{
    self = [super init];
    if (self != nil)
        _cell = cell;
    return self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer
{
    return [_cell swipeRecognizerShouldBegin:recognizer];
}

@end

@implementation TGIOS6LogFileCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier
{
    self = [super initWithStyle:style reuseIdentifier:identifier];
    if (self != nil) {
        self.clipsToBounds = true;
        _deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _deleteButton.backgroundColor = TGPresentation.current.pallete.dialogEditDeleteColor;
        _deleteButton.titleLabel.font = TGMediumSystemFontOfSize(15.0f);
        [_deleteButton setTitle:TGLocalized(@"Common.Delete") forState:UIControlStateNormal];
        [_deleteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_deleteButton addTarget:self action:@selector(deletePressed) forControlEvents:UIControlEventTouchUpInside];
        [self insertSubview:_deleteButton belowSubview:self.contentView];
        self.textLabel.backgroundColor = [UIColor clearColor];
        self.detailTextLabel.backgroundColor = [UIColor clearColor];
        _swipeGate = [[TGIOS6LogFileSwipeGate alloc] initWithCell:self];
        _swipeRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRecognized:)];
        _swipeRecognizer.delegate = _swipeGate;
        [self addGestureRecognizer:_swipeRecognizer];
    }
    return self;
}

- (CGFloat)deleteButtonWidth
{
    return MAX(80.0f, MIN(self.bounds.size.width * 0.45f, [_deleteButton.titleLabel.text sizeWithFont:_deleteButton.titleLabel.font].width + 24.0f));
}

- (void)layoutSubviews
{
    self.contentView.transform = CGAffineTransformIdentity;
    [super layoutSubviews];
    self.textLabel.backgroundColor = [UIColor clearColor];
    self.detailTextLabel.backgroundColor = [UIColor clearColor];
    _deleteButton.frame = CGRectMake(0.0f, 0.0f, MAX([self deleteButtonWidth], _swipeOffset), self.bounds.size.height);
    self.contentView.transform = CGAffineTransformMakeTranslation(_swipeOffset, 0.0f);
    _deleteButton.hidden = _swipeOffset <= 0.0f;
}

- (bool)swipeRecognizerShouldBegin:(UIGestureRecognizer *)recognizer
{
    if (recognizer != _swipeRecognizer || _deleteRequested == nil)
        return false;
    CGPoint velocity = [_swipeRecognizer velocityInView:self];
    return fabs(velocity.x) > fabs(velocity.y) && (velocity.x > 0.0f || _swipeOffset > 0.0f);
}

- (void)setSwipeOffset:(CGFloat)offset animated:(bool)animated
{
    _swipeOffset = MAX(0.0f, MIN(self.bounds.size.width, offset));
    if (animated)
        [UIView animateWithDuration:0.2 animations:^{ [self layoutSubviews]; }];
    else
        [self layoutSubviews];
}

- (void)swipeRecognized:(UIPanGestureRecognizer *)pan
{
    if (pan.state == UIGestureRecognizerStateBegan)
        _initialSwipeOffset = _swipeOffset;
    if (pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged) {
        [self setSwipeOffset:_initialSwipeOffset + [pan translationInView:self].x animated:false];
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        CGFloat velocity = [pan velocityInView:self].x;
        if (_swipeOffset >= self.bounds.size.width * 0.65f || (velocity > 950.0f && _swipeOffset > [self deleteButtonWidth])) {
            [self deletePressed];
        } else {
            bool reveal = velocity >= 0.0f && (_swipeOffset > 20.0f || velocity > 120.0f);
            [self setSwipeOffset:reveal ? [self deleteButtonWidth] : 0.0f animated:true];
        }
    } else if (pan.state == UIGestureRecognizerStateCancelled || pan.state == UIGestureRecognizerStateFailed) {
        [self setSwipeOffset:_initialSwipeOffset animated:true];
    }
}

- (void)deletePressed
{
    if (_deleteRequested != nil)
        _deleteRequested();
}

- (void)closeSwipeAnimated:(bool)animated
{
    [self setSwipeOffset:0.0f animated:animated];
}

- (bool)swipeIsOpen
{
    return _swipeOffset > 0.0f;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _deleteRequested = nil;
    [self closeSwipeAnimated:false];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected && _swipeOffset == 0.0f animated:animated];
}

@end

@interface TGIOS6LogsController : TGViewController <UITableViewDelegate, UITableViewDataSource>
{
    UITableView *_tableView;
    UIView *_bottomBar;
    UIView *_bottomSeparator;
    TGModernButton *_saveButton;
    UIBarButtonItem *_deleteAllItem;
    NSArray *_logFiles;
}
@end

@implementation TGIOS6LogsController

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        self.title = @"Логи";
        self.automaticallyManageScrollViewInsets = false;
        TGLogSetEnabled(true);
    }
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return true;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)loadView
{
    [super loadView];

    TGPresentationPallete *pallete = TGPresentation.current.pallete;
    self.view.backgroundColor = pallete.backgroundColor;

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundColor = pallete.backgroundColor;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.rowHeight = 58.0f;
    [self.view addSubview:_tableView];

    _bottomBar = [[UIView alloc] initWithFrame:CGRectZero];
    _bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _bottomBar.backgroundColor = pallete.barBackgroundColor;
    [self.view addSubview:_bottomBar];

    _bottomSeparator = [[UIView alloc] initWithFrame:CGRectZero];
    _bottomSeparator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _bottomSeparator.backgroundColor = pallete.barSeparatorColor;
    [_bottomBar addSubview:_bottomSeparator];

    _saveButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
    _saveButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _saveButton.modernHighlight = true;
    _saveButton.titleLabel.font = TGSystemFontOfSize(15.0f);
    [_saveButton setTitle:@"Сохранить последние 500 строк" forState:UIControlStateNormal];
    [_saveButton setTitleColor:pallete.accentColor forState:UIControlStateNormal];
    [_saveButton addTarget:self action:@selector(saveLiveLogPressed) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_saveButton];

    _deleteAllItem = [TGPresentation navigationBarButtonItemWithTitle:@"Удалить все" style:UIBarButtonItemStylePlain target:self action:@selector(deleteAllPressed)];
    [self setRightBarButtonItem:_deleteAllItem animated:false];

    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self layoutLogsViews];
    [self reloadLogFiles];
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    [self layoutLogsViews];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self layoutLogsViews];
}

- (void)layoutLogsViews
{
    if (![self isViewLoaded])
        return;

    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    UIEdgeInsets inset = self.controllerInset;
    CGFloat bottomBarHeight = 48.0f;
    CGFloat bottomY = MAX(inset.top, height - inset.bottom - bottomBarHeight);
    _bottomBar.hidden = false;

    _tableView.frame = CGRectMake(0.0f, inset.top, width, MAX(0.0f, bottomY - inset.top));
    _bottomBar.frame = CGRectMake(0.0f, bottomY, width, bottomBarHeight + inset.bottom);
    _bottomSeparator.frame = CGRectMake(0.0f, 0.0f, width, 1.0f);
    _saveButton.frame = CGRectMake(0.0f, 1.0f, width, bottomBarHeight - 1.0f);
}

- (void)reloadLogFiles
{
    NSMutableArray *allPaths = [[NSMutableArray alloc] init];
    NSMutableSet *knownPaths = [[NSMutableSet alloc] init];
    NSMutableArray *availablePaths = [[TGGetArchivedLogFilePaths() arrayByAddingObjectsFromArray:TGGetLogFilePaths(60)] mutableCopy];
    NSString *documentsPath = [TGAppDelegate documentsPath];
    for (NSString *name in @[@"ios6_diagnostic_breadcrumbs.log", @"ios6_last_crash.txt"])
    {
        NSString *path = [documentsPath stringByAppendingPathComponent:name];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            [availablePaths addObject:path];
    }
    for (NSString *path in availablePaths)
    {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        if (attributes == nil || [attributes fileSize] == 0)
            continue;
        if (![knownPaths containsObject:path])
        {
            [knownPaths addObject:path];
            [allPaths addObject:path];
        }
    }
    _logFiles = [allPaths sortedArrayUsingComparator:^NSComparisonResult(NSString *path1, NSString *path2)
    {
        NSDate *date1 = [[[NSFileManager defaultManager] attributesOfItemAtPath:path1 error:nil] objectForKey:NSFileModificationDate];
        NSDate *date2 = [[[NSFileManager defaultManager] attributesOfItemAtPath:path2 error:nil] objectForKey:NSFileModificationDate];
        if (date1 == nil && date2 == nil)
            return [path2 compare:path1];
        if (date1 == nil)
            return NSOrderedDescending;
        if (date2 == nil)
            return NSOrderedAscending;
        return [date2 compare:date1];
    }];
    [self updateDeleteAllItem];
    [_tableView reloadData];
}

- (void)updateDeleteAllItem
{
    bool enabled = _logFiles.count != 0;
    _deleteAllItem.enabled = enabled;
    if ([_deleteAllItem.customView isKindOfClass:[UIControl class]])
        ((UIControl *)_deleteAllItem.customView).enabled = enabled;
}

- (void)deleteAllPressed
{
    if (_logFiles.count == 0)
        return;

    TGCustomActionSheet *actionSheet = [[TGCustomActionSheet alloc] initWithTitle:nil actions:@[
        [[TGActionSheetAction alloc] initWithTitle:@"Удалить все логи" action:@"deleteAll" type:TGActionSheetActionTypeDestructive],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel],
    ] actionBlock:^(id target, NSString *action)
    {
        if ([action isEqualToString:@"deleteAll"])
            [(TGIOS6LogsController *)target deleteAllLogs];
    } target:self];
    [actionSheet showInView:self.view];
}

- (void)deleteAllLogs
{
    NSError *firstError = nil;
    for (NSString *path in _logFiles)
    {
        NSError *error = nil;
        if (!TGDeleteLogFile(path, &error) && firstError == nil)
            firstError = error;
    }
    [self reloadLogFiles];

    if (firstError != nil)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.title message:firstError.localizedDescription delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil];
        [alert show];
    }
}

- (NSString *)displaySizeForPath:(NSString *)path
{
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned long long size = [attributes[NSFileSize] unsignedLongLongValue];
    if (size >= 1024 * 1024)
        return [NSString stringWithFormat:@"%.1f MB", (double)size / (1024.0 * 1024.0)];
    if (size >= 1024)
        return [NSString stringWithFormat:@"%.1f KB", (double)size / 1024.0];
    return [NSString stringWithFormat:@"%llu B", size];
}

- (NSString *)displayDateForPath:(NSString *)path
{
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSDate *date = attributes[NSFileModificationDate];
    if (date == nil)
        return @"";

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"dd.MM.yyyy HH:mm:ss";
    return [formatter stringFromDate:date] ?: @"";
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)__unused section
{
    return _logFiles.count == 0 ? 1 : (NSInteger)_logFiles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"TGIOS6LogFileCell";
    TGIOS6LogFileCell *cell = (TGIOS6LogFileCell *)[tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil)
        cell = [[TGIOS6LogFileCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];

    TGPresentationPallete *pallete = TGPresentation.current.pallete;
    cell.backgroundColor = pallete.collectionMenuBackgroundColor;
    cell.contentView.backgroundColor = pallete.collectionMenuBackgroundColor;
    [cell closeSwipeAnimated:false];
    cell.deleteRequested = nil;
    cell.textLabel.textColor = pallete.textColor;
    cell.detailTextLabel.textColor = pallete.secondaryTextColor;

    if (_logFiles.count == 0)
    {
        cell.textLabel.text = TGLogAvailable() ? @"Логов пока нет" : @"Подробные логи выключены";
        cell.detailTextLabel.text = TGLogAvailable() ? @"Crash-логи появятся здесь автоматически" : @"В Release-сборке пишутся только crash-логи";
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    else
    {
        NSString *path = _logFiles[(NSUInteger)indexPath.row];
        cell.textLabel.text = [path lastPathComponent];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", [self displayDateForPath:path], [self displaySizeForPath:path]];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        __weak TGIOS6LogsController *weakSelf = self;
        cell.deleteRequested = ^{
            [weakSelf deleteLogAtPath:path];
        };
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:true];
    TGIOS6LogFileCell *cell = (TGIOS6LogFileCell *)[tableView cellForRowAtIndexPath:indexPath];
    if ([cell swipeIsOpen]) {
        [cell closeSwipeAnimated:true];
        return;
    }
    if (_logFiles.count == 0 || (NSUInteger)indexPath.row >= _logFiles.count)
        return;

    [self shareFileAtPath:_logFiles[(NSUInteger)indexPath.row]];
}

- (BOOL)tableView:(UITableView *)__unused tableView canEditRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return false;
}

- (void)deleteLogAtPath:(NSString *)path
{
    if (![_logFiles containsObject:path])
        return;
    NSError *error = nil;
    if (!TGDeleteLogFile(path, &error)) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.title message:error.localizedDescription delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil];
        [alert show];
    }
    [self reloadLogFiles];
}

- (void)saveLiveLogPressed
{
    NSError *error = nil;
    NSString *path = TGSaveCurrentLogLinesWithError(500, &error);
    if (path.length == 0)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Логи" message:error != nil ? error.localizedDescription : @"В текущих логах пока нет записей" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }

    [self reloadLogFiles];
    [self shareFileAtPath:path];
}

- (void)shareFileAtPath:(NSString *)path
{
    if (path.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path])
        return;

    NSArray *files = @[@{@"url": [NSURL fileURLWithPath:path]}];
    TGForwardTargetController *forwardController = [[TGForwardTargetController alloc] initWithDocumentFiles:files];
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[forwardController]];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [self presentViewController:navigationController animated:true completion:nil];
}

@end

@interface TGAccountSettingsController () <UIAlertViewDelegate>
{
    int32_t _uid;
    
    bool _editing;
    
    TGCollectionMenuSection *_logsSection;
    TGCollectionMenuSection *_onegramCoreSection;
    TGCollectionMenuSection *_headerSection;
    TGCollectionMenuSection *_settingsSection;
    TGCollectionMenuSection *_shortcutSection;
    
    SMetaDisposable *_proxyListDisposable;
    SMetaDisposable *_proxyStatusDisposable;
    TGCollectionMenuSection *_proxySection;
    TGVariantCollectionItem *_proxyItem;
    
    TGAccountInfoCollectionItem *_profileDataItem;
    TGButtonCollectionItem *_setProfilePhotoItem;
    TGButtonCollectionItem *_setUsernameItem;
    
    TGDisclosureActionCollectionItem *_logsItem;
    TGDisclosureActionCollectionItem *_onegramCoreItem;
    TGDisclosureActionCollectionItem *_switchAccountItem;
    TGDisclosureActionCollectionItem *_profileMusicItem;
    TGDocumentMediaAttachment *_profileMusicDocument;
    NSArray *_profileMusicDocuments;
    id<SDisposable> _profileMusicDisposable;
    id<SDisposable> _profileAboutDisposable;
    id<SDisposable> _profileAboutUpdateDisposable;
    TGDisclosureActionCollectionItem *_wallpapersItem;
    TGVariantCollectionItem *_languageItem;
    
    TGDisclosureActionCollectionItem *_notificationsItem;
    TGDisclosureActionCollectionItem *_privacySettingsItem;
    TGDisclosureActionCollectionItem *_chatSettingsItem;
    TGDisclosureActionCollectionItem *_devicesItem;
    TGDisclosureActionCollectionItem *_callSettingsItem;
    TGDisclosureActionCollectionItem *_savedMessagesItem;
    TGDisclosureActionCollectionItem *_stickerSettingsItem;
    TGDisclosureActionCollectionItem *_clearChatListCacheItem;
    TGDisclosureActionCollectionItem *_developerChannelItem;
    TGVersionCollectionItem *_versionItem;
    
    TGCollectionMenuSection *_otherSection;
    TGDisclosureActionCollectionItem *_passportItem;
    SMetaDisposable *_passportStatusDisposable;
    
    id<SDisposable> _stickerPacksDisposable;
    id<SDisposable> _updatedFeaturedStickerPacksDisposable;
    
    TGMediaAvatarMenuMixin *_avatarMixin;
    bool _initialContentPrepared;
}

@property (nonatomic, strong) TGProgressWindow *progressWindow;

@end

@implementation TGAccountSettingsController

static const CGFloat TGAccountSettingsBrandedDetailsTextScale = 1.2f;

- (UIColor *)collectionMenuBackgroundColor
{
    if ([TGPresentation brandedIOS6Style] && [OGTheme brandedTheme].settingsAppearance.screenBackgroundSurfaceStyle == nil)
        return UIColorRGB(0xdbe2ed);
    return [super collectionMenuBackgroundColor];
}

- (UIBarButtonItem *)editBarButtonItem
{
    return [TGPresentation navigationBarButtonItemWithTitle:TGLocalized(@"Common.Edit") style:UIBarButtonItemStylePlain target:self action:@selector(editButtonPressed)];
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    if ([self isViewLoaded])
        [self setRightBarButtonItem:[self editBarButtonItem] animated:false];
}

static NSString *TGAccountGroqApiKeyDefaultsKey(void)
{
    int32_t userId = TGTelegraphInstance.clientUserId;
    return userId != 0 ? [NSString stringWithFormat:@"TGGroqAPIKey.%d", userId] : @"TGGroqAPIKey";
}

- (id)initWithUid:(int32_t)uid
{
    self = [super init];
    if (self)
        _uid = uid;
    return self;
}

- (void)prepareInitialContentIfNeeded
{
    if (_initialContentPrepared)
        return;
    if (_uid == 0 && TGTelegraphInstance.clientUserId != 0)
        _uid = TGTelegraphInstance.clientUserId;
    _initialContentPrepared = true;
    _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];

    [ActionStageInstance() watchForPaths:@[
        @"/tg/userdatachanges",
        @"/tg/userpresencechanges",
        @"/tg/calls/enabled"
    ] watcher:self];


    _profileDataItem = [[TGAccountInfoCollectionItem alloc] init];
    _profileDataItem.brandedDetailsTextScale = TGAccountSettingsBrandedDetailsTextScale;
    _profileDataItem.hasDisclosureIndicator = ![TGPresentation brandedIOS6Style];
    _profileDataItem.selectable = true;
    _profileDataItem.highlightable = true;
    _profileDataItem.action = @selector(editButtonPressed);
    _profileDataItem.interfaceHandle = _actionHandle;

    _headerSection = [[TGCollectionMenuSection alloc] initWithItems:@[
        _profileDataItem
    ]];
    [self.menuSections addSection:_headerSection];

    _profileMusicItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:@"" action:@selector(profileMusicPressed)];
    _profileMusicItem.hideArrow = true;
    _profileMusicItem.brandedProfileMusic = true;
    _profileMusicItem.deselectAutomatically = true;

    _logsItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:@"Логи" action:@selector(logsPressed)];
    _logsItem.deselectAutomatically = true;

    _onegramCoreItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramCore.Title") action:@selector(onegramCorePressed)];
    _onegramCoreItem.deselectAutomatically = true;

    _switchAccountItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Accounts.SwitchAccount") action:@selector(switchAccountPressed)];
    _switchAccountItem.deselectAutomatically = true;

    _proxyItem = [[TGVariantCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.Proxy") action:@selector(proxyPressed)];
    _proxySection = [[TGCollectionMenuSection alloc] initWithItems:@[_proxyItem]];

    if ([TGPresentation brandedIOS6Style])
    {
        _logsSection = [[TGCollectionMenuSection alloc] initWithItems:@[_logsItem, _proxyItem, _onegramCoreItem, _switchAccountItem]];
        _logsSection.insets = UIEdgeInsetsMake(0.0f, 4.0f, 15.0f, 5.0f);
        [self.menuSections addSection:_logsSection];
    }
    else
    {
        _logsSection = [[TGCollectionMenuSection alloc] initWithItems:@[_logsItem, _switchAccountItem]];
        [self.menuSections addSection:_logsSection];
        _onegramCoreSection = [[TGCollectionMenuSection alloc] initWithItems:@[_onegramCoreItem]];
        [self.menuSections addSection:_onegramCoreSection];
    }

    _wallpapersItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.Appearance") action:@selector(wallpapersPressed)];
    _languageItem = [[TGVariantCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.AppLanguage") variant:TGLocalized(@"Localization.LanguageName") action:@selector(languagePressed)];

    NSMutableArray *settingsItems = [[NSMutableArray alloc] init];
    [settingsItems addObject:(_notificationsItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.NotificationsAndSounds") action:@selector(notificationsAndSoundsPressed)])];
    [settingsItems addObject:(_privacySettingsItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.PrivacySettings") action:@selector(privacySettingsPressed)])];
    [settingsItems addObject:(_chatSettingsItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.ChatSettings") action:@selector(chatSettingsPressed)])];
    [settingsItems addObject:(_devicesItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.Devices") action:@selector(devicesPressed)])];
    [settingsItems addObject:_wallpapersItem];
    [settingsItems addObject:_languageItem];

    NSMutableArray *shortcutItems = [[NSMutableArray alloc] init];
    [shortcutItems addObject:(_savedMessagesItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.SavedMessages") action:@selector(savedMessagesPressed)])];
    [shortcutItems addObject:(_stickerSettingsItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"ChatSettings.Stickers") action:@selector(stickerSettingsPressed)])];
    [shortcutItems addObject:(_clearChatListCacheItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:@"Clear Chat Cache" action:@selector(clearChatListCachePressed)])];

    _shortcutSection = [[TGCollectionMenuSection alloc] initWithItems:shortcutItems];
    if ([TGPresentation brandedIOS6Style])
        _shortcutSection.insets = UIEdgeInsetsMake(0.0f, 3.0f, 15.0f, 6.0f);
    [self.menuSections addSection:_shortcutSection];

    _settingsSection = [[TGCollectionMenuSection alloc] initWithItems:settingsItems];
    if ([TGPresentation brandedIOS6Style])
        _settingsSection.insets = UIEdgeInsetsMake(0.0f, 3.0f, 16.0f, 6.0f);
    [self.menuSections addSection:_settingsSection];

    [TGDatabaseInstance() customProperty:@"phoneCallsEnabled" completion:^(NSData *value)
    {
        TGDispatchOnMainThread(^
        {
            int32_t phoneCallsEnabled = false;
            if (value.length == 4) {
                [value getBytes:&phoneCallsEnabled];
            }
            [self updatePhoneCallsEnabled:phoneCallsEnabled];
        });
    }];

    _passportItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.Passport") action:@selector(passportPressed)];
    _otherSection =  [[TGCollectionMenuSection alloc] initWithItems:@[]];
    _otherSection.insets = UIEdgeInsetsZero;
    [self.menuSections addSection:_otherSection];

    if ([TGPresentation brandedIOS6Style])
        _headerSection.insets = UIEdgeInsetsMake(0.0f, 0.0f, 15.0f, 0.0f);

    SSignal *blockedModeSignal = [[TGDatabaseInstance() customPropertySignal:@"blockedMode"] map:^NSNumber *(NSData *data)
    {
        int32_t value = 0;
        [data getBytes:&value];

        return @(value);
    }];

    ASHandle *controllerHandle = _actionHandle;
    _proxyListDisposable = [[SMetaDisposable alloc] init];
    _proxyStatusDisposable = [[SMetaDisposable alloc] init];
    [_proxyListDisposable setDisposable:[[[SSignal combineSignals:@[[TGProxySignals listSignal], blockedModeSignal] withInitialStates:@[ @[], @false ]] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *next)
    {
        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
        if (strongSelf == nil)
            return;

        NSArray *list = next.firstObject;
        bool alwaysShowProxy = [next.lastObject boolValue];

        if ([TGPresentation brandedIOS6Style])
        {
            [strongSelf setupProxyStatus];
            return;
        }

        [strongSelf.menuSections beginRecordingChanges];
        if (list.count == 0 && !alwaysShowProxy)
        {
            NSUInteger sectionIndex = [strongSelf.menuSections.sections indexOfObject:strongSelf->_proxySection];
            if (sectionIndex != NSNotFound)
                [strongSelf.menuSections deleteSection:sectionIndex];

            [strongSelf->_proxyStatusDisposable setDisposable:nil];
        }
        else
        {
            NSUInteger sectionIndex = [strongSelf.menuSections.sections indexOfObject:strongSelf->_proxySection];
            if (sectionIndex == NSNotFound)
            {
                [strongSelf.menuSections insertSection:strongSelf->_proxySection atIndex:2];

                [strongSelf setupProxyStatus];
            }
        }
        [strongSelf.menuSections commitRecordedChanges:strongSelf.collectionView];
    }]];

    _developerChannelItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:@"Канал разраба" action:@selector(developerChannelPressed)];
    _developerChannelItem.deselectAutomatically = true;

    NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
    NSString *version = [bundleInfo objectForKey:@"CFBundleShortVersionString"];
    NSString *build = [bundleInfo objectForKey:@"CFBundleVersion"];
    NSString *versionText = [TGPresentation brandedIOS6Style] ? [NSString stringWithFormat:@"Onegram %@v concept by FEKLA DAVICHI", version ?: @""] : [NSString stringWithFormat:@"Onegram %@v build %@", version ?: @"", build ?: @""];
    _versionItem = [[TGVersionCollectionItem alloc] initWithVersion:versionText];

    TGCollectionMenuSection *infoSection = [[TGCollectionMenuSection alloc] initWithItems:@[
        _developerChannelItem,
        _versionItem
    ]];
    if ([TGPresentation brandedIOS6Style])
        infoSection.insets = UIEdgeInsetsMake(0.0f, 3.0f, 165.0f, 6.0f);
    [self.menuSections addSection:infoSection];

#ifdef INTERNAL_RELEASE
#endif

    [ActionStageInstance() watchForPath:@"/tg/loggedOut" watcher:self];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 32000
    UIMenuItem *copyPhoneItem = [[UIMenuItem alloc] initWithTitle:TGLocalized(@"Settings.CopyPhoneNumber") action:@selector(copyPhoneNumber:)];
    UIMenuItem *copyUsernameItem = [[UIMenuItem alloc] initWithTitle:TGLocalized(@"Settings.CopyUsername") action:@selector(copyUsername:)];
    [[UIMenuController sharedMenuController] setMenuItems:@[copyPhoneItem, copyUsernameItem]];
#endif
}

- (void)dealloc
{
    [_actionHandle reset];
    [_proxyListDisposable dispose];
    [_proxyStatusDisposable dispose];
    [_profileMusicDisposable dispose];
    [_profileAboutDisposable dispose];
    [_profileAboutUpdateDisposable dispose];
    [_passportStatusDisposable dispose];
    [_stickerPacksDisposable dispose];
    [_updatedFeaturedStickerPacksDisposable dispose];
    [ActionStageInstance() removeWatcher:self];
    [_progressWindow dismiss:true];
}

- (void)loadView
{
    if (_uid == 0 && TGTelegraphInstance.clientUserId != 0)
        _uid = TGTelegraphInstance.clientUserId;
    [self prepareInitialContentIfNeeded];
    [super loadView];

    if ([TGPresentation brandedIOS6Style])
        self.collectionView.showsVerticalScrollIndicator = false;
   
    _logsItem.icon = TGImageNamed(@"SettingsDataIcon.png");
    _proxyItem.icon = TGImageNamed(@"SettingsProxyIcon.png");
    _switchAccountItem.icon = TGImageNamed(@"SettingsAccountsIcon.png");
    _savedMessagesItem.icon = TGImageNamed(@"SettingsSavedMessagesIcon.png");
    _clearChatListCacheItem.icon = TGImageNamed(@"SettingsDataIcon.png");
    _notificationsItem.icon = TGImageNamed(@"SettingsNotificationsIcon.png");
    _privacySettingsItem.icon = TGImageNamed(@"SettingsPrivacyIcon.png");
    _chatSettingsItem.icon = TGImageNamed(@"SettingsDataIcon.png");
    _devicesItem.icon = TGImageNamed(@"ios6style/SettingsDevicesIcon.png");
    _wallpapersItem.icon = TGImageNamed(@"SettingsWallpaperIcon.png");
    _stickerSettingsItem.icon = TGImageNamed(@"SettingsStickersIcon.png");
    _languageItem.icon = TGImageNamed(@"SettingsLanguageIcon.png");
    _passportItem.icon = TGImageNamed(@"SettingsPassportIcon.png");
    _developerChannelItem.icon = TGImageNamed(@"SettingsSupportIcon.png");
    if (_callSettingsItem != nil)
        _callSettingsItem.icon = TGImageNamed(@"SettingsCallsIcon.png");

    if ([TGPresentation brandedIOS6Style])
    {
        _logsItem.brandedSettingsStyle = true;
        _logsItem.brandedSettingsIconName = @"SettingsFeklaLogs";
        _proxyItem.brandedSettingsStyle = true;
        _proxyItem.brandedSettingsIconName = @"SettingsFeklaProxy";
        _onegramCoreItem.brandedSettingsStyle = true;
        _onegramCoreItem.brandedSettingsIconName = @"SettingsFeklaOnegramCore";
        _switchAccountItem.brandedSettingsStyle = true;
        _switchAccountItem.brandedSettingsIconName = @"SettingsFeklaAccounts";
        _savedMessagesItem.brandedSettingsStyle = true;
        _savedMessagesItem.brandedSettingsIconName = @"SettingsFeklaFavourites";
        _stickerSettingsItem.brandedSettingsStyle = true;
        _stickerSettingsItem.brandedSettingsIconName = @"SettingsFeklaStickers";
        _clearChatListCacheItem.brandedSettingsStyle = true;
        _clearChatListCacheItem.brandedSettingsIconName = @"SettingsFeklaCache";
        _notificationsItem.brandedSettingsStyle = true;
        _notificationsItem.brandedSettingsIconName = @"SettingsFeklaNotifications";
        _privacySettingsItem.brandedSettingsStyle = true;
        _privacySettingsItem.brandedSettingsIconName = @"SettingsFeklaPrivacy";
        _chatSettingsItem.brandedSettingsStyle = true;
        _chatSettingsItem.brandedSettingsIconName = @"SettingsFeklaDataMemory";
        _devicesItem.brandedSettingsStyle = true;
        _devicesItem.brandedSettingsIconName = @"SettingsFeklaDevices";
        _wallpapersItem.brandedSettingsStyle = true;
        _wallpapersItem.brandedSettingsIconName = @"SettingsFeklaDecoration";
        _languageItem.brandedSettingsStyle = true;
        _languageItem.brandedSettingsIconName = @"SettingsFeklaLanguage";
        _developerChannelItem.brandedSettingsStyle = true;
        _developerChannelItem.brandedSettingsIconName = @"SettingsFeklaDeveloper";
    }
    
    _editing = false;
    
    if (OGPlatformUsesConstrainedBackgroundExecution())
    {
        ASHandle *settingsHandle = _actionHandle;
        int32_t settingsUid = _uid;
        OGRuntimeDispatch(OGRuntimePriorityUserInitiated, ^
        {
            TGUser *user = [TGDatabaseInstance() loadUser:settingsUid];
            TGCachedUserData *cachedUserData = [TGDatabaseInstance() _userCachedDataSync:settingsUid];
            TGDispatchOnMainThread(^
            {
                TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)settingsHandle.delegate;
                if (strongSelf == nil)
                    return;
                [strongSelf->_profileDataItem setUser:user animated:false];
                [strongSelf updateSubtitleWithPhoneNumber:user.phoneNumber username:user.userName];
                [strongSelf updateSuggestedSetProfilePhoto:user.photoUrlSmall.length == 0 setUsername:user.userName.length == 0];
                strongSelf->_profileDataItem.about = cachedUserData.about;
            });
        });
        if (_uid != 0)
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/users/(%d)", _uid] options:@{} flags:0 watcher:self];
    }
    else
    {
        TGUser *user = [TGDatabaseInstance() loadUser:_uid];
        [_profileDataItem setUser:user animated:false];
        [self updateSubtitleWithPhoneNumber:user.phoneNumber username:user.userName];
        [self updateSuggestedSetProfilePhoto:user.photoUrlSmall.length == 0 setUsername:user.userName.length == 0];

        TGCachedUserData *cachedUserData = [TGDatabaseInstance() _userCachedDataSync:_uid];
        _profileDataItem.about = cachedUserData.about;
        if (_uid != 0 && user == nil)
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/users/(%d)", _uid] options:@{} flags:0 watcher:self];
    }

    ASHandle *profileHandle = _actionHandle;
    _profileAboutDisposable = [[[TGDatabaseInstance() userCachedData:_uid] deliverOn:[SQueue mainQueue]] startWithNext:^(TGCachedUserData *data)
    {
        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)profileHandle.delegate;
        if (strongSelf != nil)
            strongSelf->_profileDataItem.about = data.about;
    }];
    _profileAboutUpdateDisposable = [[TGUserSignal updatedUserCachedDataWithUserId:_uid] startWithNext:nil];
    
    [self setTitleText:TGLocalized(@"Settings.Title")];
    
    [self setRightBarButtonItem:[self editBarButtonItem]];
    
    ASHandle *controllerHandle = _actionHandle;
    _stickerPacksDisposable = [[[[TGStickersSignals stickerPacks] startOn:[SQueue concurrentDefaultQueue]] deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *dict)
    {
        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
        if (strongSelf != nil && ((NSArray *)dict[@"packs"]).count != 0)
        {
            NSUInteger unreadFeaturedCount = ((NSArray *)dict[@"featuredPacksUnreadIds"]).count;
            [strongSelf->_stickerSettingsItem setBadge:unreadFeaturedCount == 0 ? nil : [NSString stringWithFormat:@"%d", (int)unreadFeaturedCount]];
        }
    }];

    _updatedFeaturedStickerPacksDisposable = [[[TGStickersSignals updatedFeaturedStickerPacks] startOn:[SQueue concurrentDefaultQueue]] startWithNext:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    ASHandle *controllerHandle = _actionHandle;
    
    _passportStatusDisposable = [[SMetaDisposable alloc] init];
    [_passportStatusDisposable setDisposable:[[[TGPassportSignals hasPassport] deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *next)
    {
        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
        if (strongSelf == nil)
            return;
        
        NSUInteger otherSectionIndex = [strongSelf.menuSections.sections indexOfObject:strongSelf->_otherSection];
        if (otherSectionIndex == NSNotFound)
            return;
        
        bool hasPassport = [next boolValue];
        NSUInteger indexOfPassportItem = [strongSelf.menuSections.sections[otherSectionIndex] indexOfItem:strongSelf->_passportItem];
        bool hasPassportItem = indexOfPassportItem != NSNotFound;
        
        if (hasPassport != hasPassportItem)
        {
            [strongSelf.menuSections beginRecordingChanges];
            if (hasPassport) {
                [strongSelf.menuSections insertItem:strongSelf->_passportItem toSection:otherSectionIndex atIndex:0];
            }
            else {
                [strongSelf.menuSections deleteItemFromSection:otherSectionIndex atIndex:indexOfPassportItem];
            }
            [strongSelf.menuSections commitRecordedChanges:strongSelf.collectionView];
        }
        
        UIEdgeInsets targetInsets = hasPassport ? UIEdgeInsetsMake(0.0f, 0.0f, 35.0f, 0.0f) : UIEdgeInsetsZero;
        if (!UIEdgeInsetsEqualToEdgeInsets(strongSelf->_otherSection.insets, targetInsets)) {
            strongSelf->_otherSection.insets = targetInsets;
            [UIView animateWithDuration:0.3 animations:^{
                [strongSelf.collectionView.collectionViewLayout invalidateLayout];
            }];
        }
    }]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (_uid == 0 && TGTelegraphInstance.clientUserId != 0)
        _uid = TGTelegraphInstance.clientUserId;
    if (OGPlatformUsesConstrainedBackgroundExecution())
    {
        ASHandle *settingsHandle = _actionHandle;
        int32_t settingsUid = _uid;
        OGRuntimeDispatch(OGRuntimePriorityUserInitiated, ^
        {
            TGUser *profileUser = settingsUid == 0 ? nil : [TGDatabaseInstance() loadUser:settingsUid];
            TGDispatchOnMainThread(^{
                TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)settingsHandle.delegate;
                if (strongSelf != nil && profileUser != nil)
                {
                    [strongSelf->_profileDataItem setUser:profileUser animated:false];
                    [strongSelf updateSubtitleWithPhoneNumber:profileUser.phoneNumber username:profileUser.userName];
                    [strongSelf updateSuggestedSetProfilePhoto:profileUser.photoUrlSmall.length == 0 setUsername:profileUser.userName.length == 0];
                }
            });
        });
        if (_uid != 0)
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/users/(%d)", _uid] options:@{} flags:0 watcher:self];
    }
    else
    {
        TGUser *profileUser = _uid == 0 ? nil : [TGDatabaseInstance() loadUser:_uid];
        if (profileUser != nil)
        {
            [_profileDataItem setUser:profileUser animated:false];
            [self updateSubtitleWithPhoneNumber:profileUser.phoneNumber username:profileUser.userName];
            [self updateSuggestedSetProfilePhoto:profileUser.photoUrlSmall.length == 0 setUsername:profileUser.userName.length == 0];
        }
        else if (_uid != 0)
        {
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/users/(%d)", _uid] options:@{} flags:0 watcher:self];
        }
    }

    [self _reloadOwnProfileMusic];

    [ActionStageInstance() dispatchOnStageQueue:^
    {
        NSArray *uploadActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/timeline/@/uploadPhoto/@" prefix:[[NSString alloc] initWithFormat:@"/tg/timeline/(%" PRId32 ")/uploadPhoto/", _uid] watcher:self];
        NSArray *deleteActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/timeline/@/deleteAvatar/@" prefix:[[NSString alloc] initWithFormat:@"/tg/timeline/(%" PRId32 ")/deleteAvatar/", _uid] watcher:self];
        if (uploadActions.count != 0)
        {
            TGTimelineUploadPhotoRequestBuilder *actor = (TGTimelineUploadPhotoRequestBuilder *)[ActionStageInstance() executingActorWithPath:uploadActions.lastObject];
            if (actor != nil)
            {
                TGDispatchOnMainThread(^
                {
                    [_profileDataItem setUpdatingAvatar:actor.currentPhoto hasUpdatingAvatar:true];
                    [_setProfilePhotoItem setEnabled:false];
                });
            }
        }
        else if (deleteActions.count != 0)
        {
            TGDeleteProfilePhotoActor *actor = (TGDeleteProfilePhotoActor *)[ActionStageInstance() executingActorWithPath:deleteActions.lastObject];
            if (actor != nil)
            {
                TGDispatchOnMainThread(^
                {
                    [_profileDataItem setUpdatingAvatar:nil hasUpdatingAvatar:true];
                    [_setProfilePhotoItem setEnabled:false];
                });
            }
        }
        
        if ([TGAccountSettingsActor accountSettingsFotCurrentStateId] == nil)
            [ActionStageInstance() requestActor:@"/accountSettings" options:@{} flags:0 watcher:self];
    }];
}

#pragma mark -

- (void)editButtonPressed
{
    TGEditProfileController *controller = [[TGEditProfileController alloc] init];
    [self.navigationController pushViewController:controller animated:true];
}

- (void)setUsernamePressed
{
    TGUsernameController *usernameController = [[TGUsernameController alloc] init];
    
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[usernameController]];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        navigationController.restrictLandscape = false;
    else
    {
        navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    [self presentViewController:navigationController animated:true completion:nil];
}

- (void)setupProxyStatus
{
    ASHandle *controllerHandle = _actionHandle;
    [_proxyStatusDisposable setDisposable:[[[TGProxySignals stateSignal] deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *next)
    {
        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
        if (strongSelf == nil)
            return;
        
        TGConnectionState state = (TGConnectionState)next.integerValue;
        
        NSString *string = TGLocalized(@"Settings.ProxyDisabled");
        switch (state) {
            case TGConnectionStateTimedOut:
            case TGConnectionStateConnecting:
            case TGConnectionStateUpdating:
            case TGConnectionStateWaitingForNetwork:
                string = TGLocalized(@"Settings.ProxyConnecting");
                break;
                
            case TGConnectionStateNormal:
                string = TGLocalized(@"Settings.ProxyConnected");
                break;
                
            default:
                string = TGLocalized(@"Settings.ProxyDisabled");
                break;
        }
        
        strongSelf->_proxyItem.variant = string;
    }]];
}

- (void)setProfilePhotoPressed
{
    ASHandle *controllerHandle = _actionHandle;
    _avatarMixin = [[TGMediaAvatarMenuMixin alloc] initWithContext:[TGLegacyComponentsContext shared] parentController:self hasDeleteButton:false personalPhoto:true saveEditedPhotos:TGAppDelegateInstance.saveEditedPhotos saveCapturedMedia:TGAppDelegateInstance.saveCapturedMedia];
    _avatarMixin.didFinishWithImage = ^(UIImage *image)
    {
        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
        if (strongSelf == nil)
            return;
        
        [strongSelf _updateProfileImage:image];
        strongSelf->_avatarMixin = nil;
    };
    _avatarMixin.didDismiss = ^
    {
        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
        if (strongSelf == nil)
            return;
        
        strongSelf->_avatarMixin = nil;        
    };
    _avatarMixin.requestSearchController = ^TGViewController *(TGMediaAssetsController *assetsController) {
        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
        if (strongSelf == nil)
            return nil;
        
        TGWebSearchController *searchController = [[TGWebSearchController alloc] initWithContext:[TGLegacyComponentsContext shared] forAvatarSelection:true embedded:true allowGrouping:false];
        searchController.presentation = strongSelf.presentation;
        
        __weak TGMediaAssetsController *weakAssetsController = assetsController;
        __weak TGWebSearchController *weakController = searchController;
        searchController.avatarCompletionBlock = ^(UIImage *image) {
            __strong TGMediaAssetsController *strongAssetsController = weakAssetsController;
            if (strongAssetsController.avatarCompletionBlock == nil)
                return;
            
            strongAssetsController.avatarCompletionBlock(image);
        };
        searchController.dismiss = ^
        {
            __strong TGWebSearchController *strongController = weakController;
            if (strongController == nil)
                return;
            
            [strongController dismissEmbeddedAnimated:true];
        };
        searchController.parentNavigationController = assetsController;
        [searchController presentEmbeddedInController:assetsController animated:true];
        
        return searchController;
    };
    _avatarMixin.sourceRect = ^CGRect
    {
        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
        if (strongSelf == nil)
            return CGRectZero;
        
        return [strongSelf frameForItem:strongSelf->_setProfilePhotoItem];
    };
    [_avatarMixin present];
}

- (CGRect)frameForItem:(TGCollectionItem *)item
{
    for (TGCollectionItemView *itemView in self.collectionView.visibleCells)
    {
        if (![itemView isKindOfClass:[TGCollectionItemView class]])
            continue;
        
        if (itemView.boundItem == item)
            return [itemView convertRect:itemView.bounds toView:self.view];
    }
    return CGRectZero;
}

- (void)_updateProfileImage:(UIImage *)image
{
    if (image == nil)
        return;
    
    if (MIN(image.size.width, image.size.height) < 160.0f)
        image = TGScaleImageToPixelSize(image, CGSizeMake(160, 160));

    NSData *imageData = UIImageJPEGRepresentation(image, 0.6f);
    if (imageData == nil)
        return;
    
    [(UIView *)[_profileDataItem visibleAvatarView] setHidden:false];
    
    TGUser *user = [TGDatabaseInstance() loadUser:_uid];
    [self updateSuggestedSetProfilePhoto:false setUsername:user.userName.length == 0];
    
    TGImageProcessor filter = [TGRemoteImageView imageProcessorForName:@"circle:64x64"];
    UIImage *avatarImage = filter(image);
    
    [_profileDataItem setUpdatingAvatar:avatarImage hasUpdatingAvatar:true];
    [_setProfilePhotoItem setEnabled:false];
    
    NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
    
    uint8_t fileId[32];
    arc4random_buf(&fileId, 32);
    
    NSMutableString *filePath = [[NSMutableString alloc] init];
    for (int i = 0; i < 32; i++)
    {
        [filePath appendFormat:@"%02x", fileId[i]];
    }
    
    NSString *tmpImagesPath = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"upload"];
    static NSFileManager *fileManager = nil;
    if (fileManager == nil)
        fileManager = [[NSFileManager alloc] init];
    NSError *error = nil;
    [fileManager createDirectoryAtPath:tmpImagesPath withIntermediateDirectories:true attributes:nil error:&error];
    NSString *absoluteFilePath = [tmpImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.bin", filePath]];
    [imageData writeToFile:absoluteFilePath atomically:true];
    
    [options setObject:filePath forKey:@"originalFileUrl"];
    
    [options setObject:avatarImage forKey:@"currentPhoto"];
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        NSString *action = [[NSString alloc] initWithFormat:@"/tg/timeline/(%" PRId32 ")/uploadPhoto/(%@)", _uid, filePath];
        [ActionStageInstance() requestActor:action options:options watcher:self];
        [ActionStageInstance() requestActor:action options:options watcher:TGTelegraphInstance];
    }];
}

- (void)_commitCancelAvatarUpdate
{
    [_profileDataItem setUpdatingAvatar:nil hasUpdatingAvatar:false];
    [_setProfilePhotoItem setEnabled:true];
    
    TGUser *user = [TGDatabaseInstance() loadUser:_uid];
    [self updateSuggestedSetProfilePhoto:user.photoUrlSmall.length == 0 setUsername:user.userName.length == 0];
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        NSArray *deleteActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/timeline/@/deleteAvatar/@" prefix:[[NSString alloc] initWithFormat:@"/tg/timeline/(%" PRId32 ")", _uid] watcher:self];
        NSArray *uploadActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/timeline/@/uploadPhoto/@" prefix:[[NSString alloc] initWithFormat:@"/tg/timeline/(%" PRId32 ")", _uid] watcher:self];
        
        for (NSString *action in deleteActions)
        {
            [ActionStageInstance() removeAllWatchersFromPath:action];
        }
        
        for (NSString *action in uploadActions)
        {
            [ActionStageInstance() removeAllWatchersFromPath:action];
        }
    }];
}

- (void)_commitDeleteAvatar
{
    [_profileDataItem setHasUpdatingAvatar:true];
    [_setProfilePhotoItem setEnabled:false];
    
    static int actionId = 0;
    
    NSDictionary *options = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:_uid], @"uid", nil];
    NSString *action = [[NSString alloc] initWithFormat:@"/tg/timeline/(%" PRId32 ")/deleteAvatar/(%d)", _uid, actionId++];
    [ActionStageInstance() requestActor:action options:options watcher:self];
    [ActionStageInstance() requestActor:action options:options watcher:TGTelegraphInstance];
}

- (void)updatePhoneCallsEnabled:(bool)enabled
{
    NSUInteger shortcutSectionIndex = [self.menuSections.sections indexOfObject:_shortcutSection];
    if (shortcutSectionIndex == NSNotFound)
        return;
    
    if (enabled && _callSettingsItem == nil) {
        _callSettingsItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"CallSettings.RecentCalls") action:@selector(callSettingsPressed)];
        if ([self isViewLoaded])
            _callSettingsItem.icon = TGImageNamed(@"SettingsCallsIcon.png");
        [self.menuSections insertItem:_callSettingsItem toSection:shortcutSectionIndex atIndex:1];
        [self.collectionView reloadData];
    } else if (!enabled && _callSettingsItem != nil) {
        [self.menuSections deleteItemFromSection:shortcutSectionIndex atIndex:1];
        _callSettingsItem = nil;
        [self.collectionView reloadData];
    }
}

- (void)updateSuggestedSetProfilePhoto:(bool)setProfilePhoto setUsername:(bool)setUsername
{
    bool changed = false;
    bool hasSetProfilePhoto = _setProfilePhotoItem != nil;
    if (setProfilePhoto && _setProfilePhotoItem == nil)
    {
        _setProfilePhotoItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.SetProfilePhoto") action:@selector(setProfilePhotoPressed)];
        _setProfilePhotoItem.deselectAutomatically = true;
        [self.menuSections insertItem:_setProfilePhotoItem toSection:0 atIndex:1];
        
        hasSetProfilePhoto = true;
        changed = true;
    }
    else if (!setProfilePhoto && _setProfilePhotoItem != nil)
    {
        [self.menuSections deleteItemFromSection:0 atIndex:1];
        _setProfilePhotoItem = nil;
        
        hasSetProfilePhoto = false;
        changed = true;
    }
    
    if (setUsername && _setUsernameItem == nil)
    {
        _setUsernameItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.SetUsername") action:@selector(setUsernamePressed)];
        [self.menuSections addItemToSection:0 item:_setUsernameItem];
        
        changed = true;
    }
    else if (!setUsername && _setUsernameItem != nil)
    {
        [self.menuSections deleteItemFromSection:0 atIndex:hasSetProfilePhoto ? 2 : 1];
        _setUsernameItem = nil;
        
        changed = true;
    }
    
    if (changed)
        [self.collectionView reloadData];
}

- (void)notificationsAndSoundsPressed
{
    [self.navigationController pushViewController:[[TGNotificationSettingsController alloc] init] animated:true];
}

- (void)privacySettingsPressed
{
    [self.navigationController pushViewController:[[TGPrivacySettingsController alloc] init] animated:true];
}

- (void)chatSettingsPressed
{
    [self.navigationController pushViewController:[[TGChatSettingsController alloc] init] animated:true];
}

- (void)savedMessagesPressed
{
    [[TGInterfaceManager instance] navigateToConversationWithId:TGTelegraphInstance.clientUserId conversation:nil performActions:nil atMessage:nil clearStack:false openKeyboard:false canOpenKeyboardWhileInTransition:false navigationController:nil selectChat:false animated:true];
}

- (void)callSettingsPressed
{
    TGRecentCallsController *controller = [[TGRecentCallsController alloc] initWithController:TGAppDelegateInstance.rootController.callsController];
    controller.presentation = self.presentation;
    [self.navigationController pushViewController:controller animated:true];
}

- (void)stickerSettingsPressed {
    [self.navigationController pushViewController:[[TGStickerPacksSettingsController alloc] initWithEditing:false masksMode:false] animated:true];
}

- (void)clearChatListCachePressed
{
    [TGDatabaseInstance() setCustomProperty:@"dialogListLoaded" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"dialogListRemoteOffset" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"dialogListHash" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"ios6DialogListCacheVersion" value:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TGIOS6ClearChatListCacheRequested" object:nil];
}

- (void)wallpapersPressed
{
    [self.navigationController pushViewController:[[TGAppearanceController alloc] init] animated:true];
}

- (void)devicesPressed
{
    [self.navigationController pushViewController:[[TGAuthSessionsController alloc] init] animated:true];
}

- (void)mySettingsPressed
{
    [self.navigationController pushViewController:[[TGSettingsController alloc] init] animated:true];
}

- (void)groqApiKeyPressed
{
    [TGCustomAlertView presentSecureTextInputAlertWithTitle:@"Groq API key" message:@"The key is stored only on this device and is sent directly to Groq." placeholder:@"gsk_..." text:[[NSUserDefaults standardUserDefaults] stringForKey:TGAccountGroqApiKeyDefaultsKey()] cancelButtonTitle:@"Cancel" okButtonTitle:@"Save" completionBlock:^(NSString *enteredKey)
    {
        NSString *key = [(enteredKey ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (key.length != 0)
            [[NSUserDefaults standardUserDefaults] setObject:key forKey:TGAccountGroqApiKeyDefaultsKey()];
        else
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:TGAccountGroqApiKeyDefaultsKey()];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];
}

static NSString *TGIOS6SettingsProfileMusicTitle(TGDocumentMediaAttachment *document)
{
    if (document == nil)
        return nil;

    NSString *title = nil;
    NSString *performer = nil;
    for (id attribute in document.attributes)
    {
        if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]])
        {
            TGDocumentAttributeAudio *audio = (TGDocumentAttributeAudio *)attribute;
            title = [audio.title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            performer = [audio.performer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            break;
        }
    }

    NSString *value = nil;
    if (performer.length != 0 && title.length != 0)
        value = [NSString stringWithFormat:@"%@ — %@", performer, title];
    else if (title.length != 0)
        value = title;
    else if (performer.length != 0)
        value = performer;
    else if (document.fileName.length != 0)
        value = document.fileName;
    else
        value = TGLocalized(@"Profile.Music");

    return value;
}

- (void)_setOwnProfileMusicDocument:(TGDocumentMediaAttachment *)document
{
    bool hadMusic = _profileMusicDocument != nil;
    bool hasMusic = document != nil;
    bool changed = _profileMusicDocument.documentId != document.documentId;
    _profileMusicDocument = document;

    NSUInteger sectionIndex = [self.menuSections.sections indexOfObject:_headerSection];
    if (sectionIndex == NSNotFound)
        return;

    NSUInteger itemIndex = [_headerSection.items indexOfObject:_profileMusicItem];

    if ([TGPresentation brandedIOS6Style])
    {
        _profileDataItem.profileMusicDocument = document;
        if (itemIndex != NSNotFound)
        {
            [self.menuSections beginRecordingChanges];
            [self.menuSections deleteItemFromSection:sectionIndex atIndex:itemIndex];
            [self.menuSections commitRecordedChanges:self.collectionView];
        }
        if (hadMusic != hasMusic || changed)
        {
            [self.collectionLayout invalidateLayout];
            [self.collectionView layoutSubviews];
        }
        return;
    }

    _profileDataItem.profileMusicDocument = nil;

    if (hasMusic)
        _profileMusicItem.title = TGIOS6SettingsProfileMusicTitle(document);

    if (!hadMusic && hasMusic && itemIndex == NSNotFound)
    {
        [self.menuSections beginRecordingChanges];
        [self.menuSections insertItem:_profileMusicItem toSection:sectionIndex atIndex:MIN((NSUInteger)1, _headerSection.items.count)];
        [self.menuSections commitRecordedChanges:self.collectionView];
    }
    else if (hadMusic && !hasMusic && itemIndex != NSNotFound)
    {
        [self.menuSections beginRecordingChanges];
        [self.menuSections deleteItemFromSection:sectionIndex atIndex:itemIndex];
        [self.menuSections commitRecordedChanges:self.collectionView];
    }
    else if (hasMusic && changed)
    {
        _profileMusicItem.title = TGIOS6SettingsProfileMusicTitle(document);
    }
}

- (void)_reloadOwnProfileMusic
{
    [_profileMusicDisposable dispose];

    ASHandle *controllerHandle = _actionHandle;
    _profileMusicDisposable = [[[[TGUserSignal profileSavedMusicWithUserId:_uid] deliverOn:[SQueue mainQueue]] take:1] startWithNext:^(id value)
    {
        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
        if (strongSelf == nil)
            return;

        NSArray *documents = [value isKindOfClass:[NSArray class]] ? value : @[];
        strongSelf->_profileMusicDocuments = documents;
        TGDocumentMediaAttachment *document = documents.count != 0 ? documents[0] : nil;
        [strongSelf _setOwnProfileMusicDocument:document];
    }];
}

- (void)_playProfileMusicDocument:(TGDocumentMediaAttachment *)document
{
    if (document == nil)
        return;

    TGMusicPlayerItem *item = [TGMusicPlayerItem itemWithInstantDocument:document];
    if (item == nil || item.isVoice)
        return;

    ASHandle *controllerHandle = _actionHandle;
    [[[[TGTelegraphInstance.musicPlayer playingStatus] take:1] deliverOn:[SQueue mainQueue]] startWithNext:^(TGMusicPlayerStatus *status)
    {
        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
        if (strongSelf == nil)
            return;

        if (status.item != nil && [status.item.key isEqual:item.key])
        {
            [TGTelegraphInstance.musicPlayer controlPlayPause];
            return;
        }

        NSMutableArray *items = [[NSMutableArray alloc] init];
        for (TGDocumentMediaAttachment *track in strongSelf->_profileMusicDocuments)
        {
            TGMusicPlayerItem *trackItem = [TGMusicPlayerItem itemWithInstantDocument:track];
            if (trackItem != nil && !trackItem.isVoice)
                [items addObject:trackItem];
        }
        if (items.count == 0)
            [items addObject:item];
        TGMusicPlayerPlaylist *playlist = [[TGMusicPlayerPlaylist alloc] initWithVoice:false items:items itemKeyAliases:@{} markItemAsViewed:nil];
        TGMusicPlayer *musicPlayer = TGTelegraphInstance.musicPlayer;
        [musicPlayer setPlaylist:[SSignal single:playlist] initialItemKey:item.key metadata:@{ @"profileMusicPeerId": @(strongSelf->_uid), @"profileSavedMusic": @true }];
    }];
}

- (void)profileMusicPressed
{
    [self _playProfileMusicDocument:_profileMusicDocument];
}

- (void)logsPressed
{
    TGIOS6LogsController *controller = [[TGIOS6LogsController alloc] init];
    [self.navigationController pushViewController:controller animated:true];
}

- (void)onegramCorePressed
{
    TGOnegramCoreController *controller = [[TGOnegramCoreController alloc] init];
    [self.navigationController pushViewController:controller animated:true];
}

- (void)switchAccountPressed
{
    UIView *containerView = TGAppDelegateInstance.rootController.view;
    if (containerView == nil)
        containerView = self.navigationController.view;
    [TGAccountSwitcherPanel presentInView:containerView];
}

- (void)developerChannelPressed
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://t.me/Onegramdev"]];
}

#pragma mark -

- (void)updateSubtitleWithPhoneNumber:(NSString *)phoneNumber username:(NSString *)username
{
    NSString *phone = phoneNumber.length == 0 ? @"" : [TGPhoneUtils formatPhone:phoneNumber forceInternational:true];
    NSString *finalUsername = username.length > 0 ? [NSString stringWithFormat:@"@%@", username] : @"";
    [_profileDataItem setPhoneNumber:phone];
    [_profileDataItem setUsername:finalUsername];
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/loggedOut"]) {
        TGDispatchOnMainThread(^{
            [_progressWindow dismiss:true];
            _progressWindow = nil;
        });
    }
    else if ([path isEqualToString:@"/tg/userdatachanges"] || [path isEqualToString:@"/tg/userpresencechanges"])
    {
        NSArray *users = ((SGraphObjectNode *)resource).object;
        
        for (TGUser *user in users)
        {
            if (user.uid == _uid)
            {
                TGDispatchOnMainThread(^
                {
                    [_profileDataItem setUser:user animated:true];
                    [self updateSubtitleWithPhoneNumber:user.phoneNumber username:user.userName];
                    [self updateSuggestedSetProfilePhoto:user.photoUrlSmall.length == 0 setUsername:user.userName.length == 0];
                });
                
                break;
            }
        }
    } else if ([path isEqualToString:@"/tg/calls/enabled"]) {
        bool enabled = [((SGraphObjectNode *)resource).object boolValue];
        TGDispatchOnMainThread(^{
            [self updatePhoneCallsEnabled:enabled];
        });
    }
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)result
{
    if ([path isEqualToString:[NSString stringWithFormat:@"/tg/users/(%d)", _uid]])
    {
        if (status == ASStatusSuccess)
        {
            TGDispatchOnMainThread(^
            {
                TGUser *user = [TGDatabaseInstance() loadUser:_uid];
                if (user != nil)
                {
                    [_profileDataItem setUser:user animated:false];
                    [self updateSubtitleWithPhoneNumber:user.phoneNumber username:user.userName];
                    [self updateSuggestedSetProfilePhoto:user.photoUrlSmall.length == 0 setUsername:user.userName.length == 0];
                }
            });
        }
    }
    else if ([path hasPrefix:@"/tg/changeUserName/"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [_profileDataItem setUpdatingFirstName:nil updatingLastName:nil];
            [_profileDataItem setUser:[TGDatabaseInstance() loadUser:_uid] animated:false];
        });
    }
    else if ([path hasPrefix:[[NSString alloc] initWithFormat:@"/tg/timeline/(%" PRId32 ")/uploadPhoto", _uid]] || [path hasPrefix:[[NSString alloc] initWithFormat:@"/tg/timeline/(%" PRId32 ")/deleteAvatar/", _uid]])
    {
        TGImageInfo *imageInfo = ((TGTimelineItem *)((SGraphObjectNode *)result).object).imageInfo;
        
        TGDispatchOnMainThread(^
        {
            [_setProfilePhotoItem setEnabled:true];
            
            if (status == ASStatusSuccess)
            {
                NSString *photoUrl = [imageInfo closestImageUrlWithSize:CGSizeMake(160, 160) resultingSize:NULL];
                
                if (photoUrl != nil)
                    [_profileDataItem copyUpdatingAvatarToCacheWithUri:photoUrl];
                
                [_profileDataItem resetUpdatingAvatar:photoUrl];
            }
            else
            {
                [_profileDataItem setUpdatingAvatar:nil hasUpdatingAvatar:false];
                
                [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"Login.UnknownError") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            }
        });
    }
    else if ([path isEqualToString:@"/tg/support/preferredPeer"])
    {
        TGUser *user = status == ASStatusSuccess ? [TGDatabaseInstance() loadUser:[result[@"uid"] intValue]] : nil;
        
        TGDispatchOnMainThread(^
        {
            [_progressWindow dismiss:true];
            
            if (user != nil)
            {
                [[TGInterfaceManager instance] navigateToConversationWithId:user.uid conversation:nil performActions:nil atMessage:nil clearStack:true openKeyboard:false canOpenKeyboardWhileInTransition:false animated:true];
            }
        });
    }
}

- (void)actionStageActionRequested:(NSString *)action options:(id)options
{
    if ([action isEqualToString:@"profileMusicTapped"])
    {
        TGDocumentMediaAttachment *document = [options isKindOfClass:[TGDocumentMediaAttachment class]] ? options : _profileMusicDocument;
        [self _playProfileMusicDocument:document];
    }
    else if ([action isEqualToString:@"avatarTapped"])
    {
        TGUser *user = [TGDatabaseInstance() loadUser:_uid];
        
        if ([_profileDataItem hasUpdatingAvatar])
        {
            TGCustomActionSheet *actionSheet = [[TGCustomActionSheet alloc] initWithTitle:nil actions:@[
                [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"GroupInfo.SetGroupPhotoStop") action:@"stop" type:TGActionSheetActionTypeDestructive],
                [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel],
            ] actionBlock:^(id target, NSString *action)
            {
                if ([action isEqualToString:@"stop"])
                {
                    [(TGAccountSettingsController *)target _commitCancelAvatarUpdate];
                }
            } target:self];
            [actionSheet showInView:self.view];
        }
        else if (user.photoUrlSmall.length == 0)
        {
            if (_setProfilePhotoItem.enabled)
                [self setProfilePhotoPressed];
        }
        else
        {
            if (!_editing)
            {
                TGRemoteImageView *avatarView = [_profileDataItem visibleAvatarView];
                
                if (user != nil && user.photoUrlBig != nil && avatarView.currentImage != nil)
                {
                    TGModernGalleryController *modernGallery = [[TGModernGalleryController alloc] initWithContext:[TGLegacyComponentsContext shared]];
                    
                    TGProfileUserAvatarGalleryModel *model = [[TGProfileUserAvatarGalleryModel alloc] initWithCurrentAvatarLegacyThumbnailImageUri:user.photoFullUrlSmall currentAvatarLegacyImageUri:user.photoFullUrlBig currentAvatarImageSize:CGSizeMake(640.0f, 640.0f)];
                    
                    ASHandle *controllerHandle = _actionHandle;
                    
                    model.deleteCurrentAvatar = ^
                    {
                        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
                        [strongSelf _commitDeleteAvatar];
                    };
                    
                    modernGallery.model = model;
                    
                    modernGallery.itemFocused = ^(id<TGModernGalleryItem> item)
                    {
                        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
                        if (strongSelf != nil)
                        {
                            if ([item isKindOfClass:[TGUserAvatarGalleryItem class]])
                            {
                                if (((TGUserAvatarGalleryItem *)item).isCurrent)
                                {
                                    ((UIView *)strongSelf->_profileDataItem.visibleAvatarView).hidden = true;
                                }
                                else
                                    ((UIView *)strongSelf->_profileDataItem.visibleAvatarView).hidden = false;
                            }
                        }
                    };
                    
                    modernGallery.beginTransitionIn = ^UIView *(id<TGModernGalleryItem> item, __unused TGModernGalleryItemView *itemView)
                    {
                        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
                        if (strongSelf != nil)
                        {
                            if ([item isKindOfClass:[TGUserAvatarGalleryItem class]])
                            {
                                if (((TGUserAvatarGalleryItem *)item).isCurrent)
                                {
                                    return strongSelf->_profileDataItem.visibleAvatarView;
                                }
                            }
                        }
                        
                        return nil;
                    };
                    
                    modernGallery.beginTransitionOut = ^UIView *(id<TGModernGalleryItem> item, __unused TGModernGalleryItemView *itemView)
                    {
                        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
                        if (strongSelf != nil)
                        {
                            if ([item isKindOfClass:[TGUserAvatarGalleryItem class]])
                            {
                                if (((TGUserAvatarGalleryItem *)item).isCurrent)
                                {
                                    return strongSelf->_profileDataItem.visibleAvatarView;
                                }
                            }
                        }
                        
                        return nil;
                    };
                    
                    modernGallery.completedTransitionOut = ^
                    {
                        TGAccountSettingsController *strongSelf = (TGAccountSettingsController *)controllerHandle.delegate;
                        if (strongSelf != nil)
                        {
                            ((UIView *)strongSelf->_profileDataItem.visibleAvatarView).hidden = false;
                        }
                    };
                    
                    TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:[[TGLegacyComponentsContext shared] makeOverlayWindowManager] parentController:self contentController:modernGallery];
                    controllerWindow.hidden = false;
                }
            }
            else
            {
                [self setProfilePhotoPressed];
            }
        }
    }
    else if ([action isEqualToString:@"deleteAvatar"])
    {
        [self _commitDeleteAvatar];
    }
}

- (void)passportPressed
{
    if (!TGIsPad())
        [TGViewController setInterfaceOrientation:UIInterfaceOrientationPortrait animated:true];
    
    TGPassportRequestController *controller = [[TGPassportRequestController alloc] initWithFormRequest:nil];
    [self.navigationController pushViewController:controller animated:true];
}

- (void)proxyPressed
{
    TGProxySetupController *controller = [[TGProxySetupController alloc] init];
    [self.navigationController pushViewController:controller animated:true];
}

- (void)localizationUpdated
{
    [self setTitleText:TGLocalized(@"Settings.Title")];
    
    [self setRightBarButtonItem:[self editBarButtonItem] animated:false];
    
    _savedMessagesItem.title = TGLocalized(@"Settings.SavedMessages");
    _clearChatListCacheItem.title = @"Clear Chat Cache";
    _notificationsItem.title = TGLocalized(@"Settings.NotificationsAndSounds");
    _privacySettingsItem.title = TGLocalized(@"Settings.PrivacySettings");
    _chatSettingsItem.title = TGLocalized(@"Settings.ChatSettings");
    
    _stickerSettingsItem.title = TGLocalized(@"ChatSettings.Stickers");
    
    _setProfilePhotoItem.title = TGLocalized(@"Settings.SetProfilePhoto");
    _setUsernameItem.title = TGLocalized(@"Settings.SetUsername");
    _wallpapersItem.title = TGLocalized(@"Settings.Appearance");
    _devicesItem.title = TGLocalized(@"Settings.Devices");
    _developerChannelItem.title = @"Канал разраба";
    _callSettingsItem.title = TGLocalized(@"CallSettings.RecentCalls");
    
    _languageItem.title = TGLocalized(@"Settings.AppLanguage");
    _languageItem.variant = TGLocalized(@"Localization.LanguageName");
    
    _proxyItem.title = TGLocalized(@"Settings.Proxy");
    _passportItem.title = TGLocalized(@"Settings.Passport");
    
    NSUInteger sectionIndex = [self.menuSections.sections indexOfObject:_proxySection];
    if (sectionIndex != NSNotFound)
        [self setupProxyStatus];
    
    [_profileDataItem localizationUpdated];
}
    
- (void)languagePressed {
    TGLocalizationSelectionController *controller = [[TGLocalizationSelectionController alloc] init];
    controller.presentation = self.presentation;
    [self.navigationController pushViewController:controller animated:true];
}

- (void)scrollToTopRequested
{
    [self.collectionView setContentOffset:CGPointMake(0.0f, -self.collectionView.contentInset.top) animated:true];
}

@end
