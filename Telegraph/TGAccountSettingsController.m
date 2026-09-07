#import "TGAccountSettingsController.h"

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

#import "TGAccountInfoCollectionItem.h"
#import "TGHeaderCollectionItem.h"
#import "TGDisclosureActionCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGWallpapersCollectionItem.h"
#import "TGVariantCollectionItem.h"
#import "TGVersionCollectionItem.h"

#import "TGWallpaperListController.h"
#import "TGWallpaperManager.h"

#import "TGCustomAlertView.h"
#import "TGCustomActionSheet.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

#import "TGDatabase.h"
#import "TGTelegraph.h"

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
#import "../legacy/TelegraphKit/TGCommon.h"
#import "TGProxySetupController.h"
#import "TGPassportRequestController.h"
#import "../Modules/NekroEngine/FuckDPI/TGFuckDPIController.h"

#import "TGTwoStepConfigSignal.h"

#import "TGMusicPlayer.h"
#import "TGMusicPlayerItem.h"
#import "TGMusicPlayerPlaylist.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDocumentMediaAttachment.h"

#import "TGLegacyComponentsContext.h"
#import <QuartzCore/QuartzCore.h>

@interface TGIOS6LogsController : TGViewController
{
    UIView *_filterContainer;
    TGModernButton *_filterButton;
    UILabel *_filterTitleLabel;
    UILabel *_filterValueLabel;
    UILabel *_filterArrowLabel;
    UIScrollView *_filterMenu;
    NSMutableArray *_filterMenuButtons;
    NSString *_selectedFilter;
    bool _filterMenuVisible;
    UITextView *_textView;
    UIView *_bottomBar;
    UIView *_bottomSeparator;
    UIView *_buttonSeparator1;
    UIView *_buttonSeparator2;
    TGModernButton *_clearButton;
    TGModernButton *_copyButton;
    TGModernButton *_shareButton;
    NSTimer *_refreshTimer;
    NSString *_rawText;
    unsigned long long _lastCurrentSize;
    bool _readInProgress;
    bool _didInitialScroll;
}
@end

@implementation TGIOS6LogsController

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        self.title = @"Логи";
        _lastCurrentSize = (unsigned long long)-1;
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

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)loadView
{
    [super loadView];

    TGPresentationPallete *pallete = TGPresentation.current.pallete;
    self.view.backgroundColor = pallete.backgroundColor;

    _filterContainer = [[UIView alloc] initWithFrame:CGRectZero];
    _filterContainer.backgroundColor = pallete.collectionMenuBackgroundColor;
    [self.view addSubview:_filterContainer];

    _selectedFilter = @"Основное";
    _filterMenuVisible = false;

    _filterButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
    _filterButton.modernHighlight = true;
    [_filterButton addTarget:self action:@selector(filterButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_filterContainer addSubview:_filterButton];

    _filterTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _filterTitleLabel.backgroundColor = [UIColor clearColor];
    _filterTitleLabel.text = @"Фильтр";
    _filterTitleLabel.font = TGSystemFontOfSize(15.0f);
    _filterTitleLabel.textColor = pallete.textColor;
    [_filterContainer addSubview:_filterTitleLabel];

    _filterValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _filterValueLabel.backgroundColor = [UIColor clearColor];
    _filterValueLabel.text = _selectedFilter;
    _filterValueLabel.font = TGSystemFontOfSize(15.0f);
    _filterValueLabel.textColor = pallete.accentColor;
    _filterValueLabel.textAlignment = NSTextAlignmentRight;
    [_filterContainer addSubview:_filterValueLabel];

    _filterArrowLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _filterArrowLabel.backgroundColor = [UIColor clearColor];
    _filterArrowLabel.text = @"▾";
    _filterArrowLabel.font = TGSystemFontOfSize(15.0f);
    _filterArrowLabel.textColor = pallete.accentColor;
    _filterArrowLabel.textAlignment = NSTextAlignmentCenter;
    [_filterContainer addSubview:_filterArrowLabel];

    _filterMenu = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _filterMenu.backgroundColor = pallete.collectionMenuBackgroundColor;
    _filterMenu.clipsToBounds = true;
    _filterMenu.hidden = true;
    _filterMenu.alwaysBounceVertical = true;
    _filterMenu.showsVerticalScrollIndicator = true;
    _filterMenu.bounces = true;
    [self.view addSubview:_filterMenu];

    NSArray *filterNames = @[@"Основное", @"Ошибки", @"CRASH", @"AUTH", @"QR", @"CALL", @"WEBRTC", @"FOLDERS", @"FORUM", @"AUTHPERF", @"Сеть", @"Сырой лог"];
    _filterMenuButtons = [[NSMutableArray alloc] initWithCapacity:filterNames.count];
    for (NSUInteger index = 0; index < filterNames.count; index++)
    {
        NSString *name = filterNames[index];
        TGModernButton *button = [[TGModernButton alloc] initWithFrame:CGRectZero];
        button.modernHighlight = true;
        button.tag = (NSInteger)index;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        button.titleLabel.font = TGSystemFontOfSize(15.0f);
        [button setTitle:name forState:UIControlStateNormal];
        [button setTitleColor:(index == 0 ? pallete.accentColor : pallete.textColor) forState:UIControlStateNormal];
        [button addTarget:self action:@selector(filterOptionPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_filterMenu addSubview:button];
        [_filterMenuButtons addObject:button];

        if (index != filterNames.count - 1)
        {
            UIView *separator = [[UIView alloc] initWithFrame:CGRectZero];
            separator.tag = 1000 + (NSInteger)index;
            separator.backgroundColor = pallete.barSeparatorColor;
            [_filterMenu addSubview:separator];
        }
    }

    _textView = [[UITextView alloc] initWithFrame:CGRectZero];
    _textView.backgroundColor = pallete.backgroundColor;
    _textView.textColor = pallete.textColor;
    _textView.editable = false;
    _textView.alwaysBounceVertical = true;
    UIFont *font = [UIFont fontWithName:@"Courier" size:11.0f];
    _textView.font = font != nil ? font : [UIFont systemFontOfSize:11.0f];
    [self.view addSubview:_textView];

    _bottomBar = [[UIView alloc] initWithFrame:CGRectZero];
    _bottomBar.backgroundColor = pallete.barBackgroundColor;
    [self.view addSubview:_bottomBar];

    _bottomSeparator = [[UIView alloc] initWithFrame:CGRectZero];
    _bottomSeparator.backgroundColor = pallete.barSeparatorColor;
    [_bottomBar addSubview:_bottomSeparator];

    _buttonSeparator1 = [[UIView alloc] initWithFrame:CGRectZero];
    _buttonSeparator1.backgroundColor = pallete.barSeparatorColor;
    [_bottomBar addSubview:_buttonSeparator1];

    _buttonSeparator2 = [[UIView alloc] initWithFrame:CGRectZero];
    _buttonSeparator2.backgroundColor = pallete.barSeparatorColor;
    [_bottomBar addSubview:_buttonSeparator2];

    _clearButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
    _clearButton.modernHighlight = true;
    _clearButton.titleLabel.font = TGSystemFontOfSize(15.0f);
    [_clearButton setTitle:@"Очистить" forState:UIControlStateNormal];
    [_clearButton setTitleColor:pallete.destructiveColor forState:UIControlStateNormal];
    [_clearButton addTarget:self action:@selector(clearPressed) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_clearButton];

    _copyButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
    _copyButton.modernHighlight = true;
    _copyButton.titleLabel.font = TGSystemFontOfSize(15.0f);
    [_copyButton setTitle:@"Копировать" forState:UIControlStateNormal];
    [_copyButton setTitleColor:pallete.accentColor forState:UIControlStateNormal];
    [_copyButton addTarget:self action:@selector(copyPressed) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_copyButton];

    _shareButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
    _shareButton.modernHighlight = true;
    _shareButton.titleLabel.font = TGSystemFontOfSize(15.0f);
    [_shareButton setTitle:@"Поделиться" forState:UIControlStateNormal];
    [_shareButton setTitleColor:pallete.accentColor forState:UIControlStateNormal];
    [_shareButton addTarget:self action:@selector(sharePressed) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_shareButton];

    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    [self.view setNeedsLayout];
}

- (void)viewWillLayoutSubviews
{
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    UIEdgeInsets inset = self.controllerInset;
    CGFloat filterHeight = 44.0f;
    CGFloat bottomBarHeight = 46.0f;
    CGFloat top = inset.top;
    CGFloat bottom = inset.bottom;

    _filterContainer.frame = CGRectMake(0.0f, top, width, filterHeight);
    _filterButton.frame = _filterContainer.bounds;
    _filterTitleLabel.frame = CGRectMake(15.0f, 0.0f, 90.0f, filterHeight);
    _filterArrowLabel.frame = CGRectMake(MAX(0.0f, width - 31.0f), 0.0f, 16.0f, filterHeight);
    _filterValueLabel.frame = CGRectMake(105.0f, 0.0f, MAX(0.0f, width - 136.0f), filterHeight);

    CGFloat bottomY = MAX(top + filterHeight, height - bottom - bottomBarHeight);
    _bottomBar.frame = CGRectMake(0.0f, bottomY, width, bottomBarHeight + bottom);
    _bottomSeparator.frame = CGRectMake(0.0f, 0.0f, width, 1.0f);

    CGFloat buttonWidth = width / 3.0f;
    _clearButton.frame = CGRectMake(0.0f, 1.0f, buttonWidth, bottomBarHeight - 1.0f);
    _copyButton.frame = CGRectMake(buttonWidth, 1.0f, buttonWidth, bottomBarHeight - 1.0f);
    _shareButton.frame = CGRectMake(buttonWidth * 2.0f, 1.0f, width - buttonWidth * 2.0f, bottomBarHeight - 1.0f);
    _buttonSeparator1.frame = CGRectMake(buttonWidth, 9.0f, 1.0f, bottomBarHeight - 18.0f);
    _buttonSeparator2.frame = CGRectMake(buttonWidth * 2.0f, 9.0f, 1.0f, bottomBarHeight - 18.0f);

    CGFloat textTop = CGRectGetMaxY(_filterContainer.frame);
    _textView.frame = CGRectMake(0.0f, textTop, width, MAX(0.0f, bottomY - textTop));

    CGFloat menuRowHeight = 36.0f;
    CGFloat menuHeight = menuRowHeight * _filterMenuButtons.count;
    CGFloat maximumMenuHeight = MAX(0.0f, bottomY - textTop);
    menuHeight = MIN(menuHeight, maximumMenuHeight);
    _filterMenu.frame = CGRectMake(0.0f, textTop, width, _filterMenuVisible ? menuHeight : 0.0f);
    _filterMenu.contentSize = CGSizeMake(width, menuRowHeight * _filterMenuButtons.count);

    for (NSUInteger index = 0; index < _filterMenuButtons.count; index++)
    {
        TGModernButton *button = _filterMenuButtons[index];
        button.frame = CGRectMake(15.0f, menuRowHeight * index, MAX(0.0f, width - 30.0f), menuRowHeight);
        UIView *separator = [_filterMenu viewWithTag:1000 + (NSInteger)index];
        if (separator != nil)
            separator.frame = CGRectMake(15.0f, menuRowHeight * (index + 1) - 1.0f, MAX(0.0f, width - 15.0f), 1.0f);
    }
    [self.view bringSubviewToFront:_filterMenu];
    [self.view bringSubviewToFront:_filterContainer];
    [self.view bringSubviewToFront:_bottomBar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self refreshLogsForce:true];
    [_refreshTimer invalidate];
    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.8 target:self selector:@selector(refreshTimerTick) userInfo:nil repeats:true];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self setFilterMenuVisible:false animated:false];
    [_refreshTimer invalidate];
    _refreshTimer = nil;
}

- (void)dealloc
{
    [_refreshTimer invalidate];
}

- (unsigned long long)currentLogSize
{
    NSString *documentsPath = [TGAppDelegate documentsPath];
    NSString *path = [documentsPath stringByAppendingPathComponent:@"application-0.log"];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned long long size = [attributes[NSFileSize] unsignedLongLongValue];

    NSString *crashPath = [documentsPath stringByAppendingPathComponent:@"ios6_last_crash.txt"];
    NSDictionary *crashAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:crashPath error:nil];
    size ^= ([crashAttributes[NSFileSize] unsignedLongLongValue] << 1);
    return size;
}

- (NSString *)readLogTail
{
    const NSUInteger maximumBytes = 768 * 1024;
    NSUInteger remaining = maximumBytes;
    NSArray *paths = TGGetLogFilePaths(8);
    NSMutableArray *chunks = [[NSMutableArray alloc] init];

    for (NSString *path in paths)
    {
        if (remaining == 0)
            break;

        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        unsigned long long fileSize = [attributes[NSFileSize] unsignedLongLongValue];
        if (fileSize == 0)
            continue;

        NSUInteger readLength = (NSUInteger)MIN((unsigned long long)remaining, fileSize);
        unsigned long long startOffset = fileSize - readLength;

        NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
        if (handle == nil)
            continue;

        [handle seekToFileOffset:startOffset];
        NSData *data = [handle readDataToEndOfFile];
        [handle closeFile];

        if (startOffset != 0 && data.length != 0)
        {
            const uint8_t *bytes = data.bytes;
            NSUInteger skip = 0;
            while (skip < data.length && bytes[skip] != '\n')
                skip++;
            if (skip < data.length)
                skip++;
            if (skip != 0 && skip < data.length)
                data = [data subdataWithRange:NSMakeRange(skip, data.length - skip)];
        }

        NSString *chunk = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (chunk == nil)
            chunk = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
        if (chunk.length != 0)
        {
            if (![chunk hasSuffix:@"\n"])
                chunk = [chunk stringByAppendingString:@"\n"];
            [chunks insertObject:chunk atIndex:0];
        }

        remaining -= MIN(remaining, readLength);
    }

    NSString *crashPath = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"ios6_last_crash.txt"];
    NSString *crash = [NSString stringWithContentsOfFile:crashPath encoding:NSUTF8StringEncoding error:nil];
    if (crash.length != 0)
    {
        if (![crash hasSuffix:@"\n"])
            crash = [crash stringByAppendingString:@"\n"];
        [chunks insertObject:crash atIndex:0];
    }

    return [chunks componentsJoinedByString:@""];
}

- (bool)lineLooksLikeError:(NSString *)line
{
    if (line.length == 0)
        return false;

    NSString *lowerLine = [line lowercaseString];
    NSArray *errorTokens = @[
        @"error", @"exception", @"terminating", @"unrecognized selector",
        @"fatal", @"crash", @"assert", @"sigabrt", @"sigsegv", @"sigbus",
        @"sigill", @"sigfpe", @"failed", @"failure", @"timeout", @"timed out",
        @"_invalid", @"_not_active", @"unauthorized", @"forbidden", @"denied"
    ];
    for (NSString *token in errorTokens)
    {
        if ([lowerLine rangeOfString:token].location != NSNotFound)
            return true;
    }
    return false;
}

- (bool)lineIsImportant:(NSString *)line
{
    if (line.length == 0)
        return false;

    if ([line hasPrefix:@"IOS6"] || [line rangeOfString:@" IOS6" options:NSCaseInsensitiveSearch].location != NSNotFound)
        return true;
    if ([line rangeOfString:@"AUTHPERF" options:NSCaseInsensitiveSearch].location != NSNotFound)
        return true;
    if ([line rangeOfString:@"Starting with user id" options:NSCaseInsensitiveSearch].location != NSNotFound)
        return true;

    if ([self lineLooksLikeError:line])
        return true;

    NSArray *importantRpcNames = @[
        @"phone_requestCall", @"phone_acceptCall", @"phone_confirmCall",
        @"phone_discardCall", @"phone_receivedCall"
    ];
    for (NSString *rpcName in importantRpcNames)
    {
        if ([line rangeOfString:rpcName options:NSCaseInsensitiveSearch].location != NSNotFound)
            return true;
    }

    return false;
}

- (bool)lineIsNetworkDiagnostic:(NSString *)line
{
    if (line.length == 0)
        return false;

    NSArray *tokens = @[
        @"Connection time:", @"network state:", @"connection state:",
        @"connecting to ", @"disconnected from ", @"rpcError", @"timeout",
        @"timed out", @"network unavailable", @"interface:"
    ];
    for (NSString *token in tokens)
    {
        if ([line rangeOfString:token options:NSCaseInsensitiveSearch].location != NSNotFound)
            return true;
    }
    return false;
}

- (bool)lineIsCrashContext:(NSString *)line
{
    if (line.length == 0)
        return false;

    if ([line rangeOfString:@"CALL" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [line rangeOfString:@"WEBRTC" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [line rangeOfString:@"AUTH" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [line rangeOfString:@"CRASH" options:NSCaseInsensitiveSearch].location != NSNotFound)
        return true;

    if ([self lineLooksLikeError:line])
        return true;

    NSArray *tokens = @[
        @"phone_requestCall", @"phone_acceptCall", @"phone_confirmCall",
        @"phone_discardCall", @"phone_receivedCall", @"phone_sendSignalingData"
    ];
    for (NSString *token in tokens)
    {
        if ([line rangeOfString:token options:NSCaseInsensitiveSearch].location != NSNotFound)
            return true;
    }

    return false;
}

- (NSString *)crashDiagnosticText:(NSString *)text
{
    NSString *documentsPath = [TGAppDelegate documentsPath];
    NSString *previousPath = [documentsPath stringByAppendingPathComponent:@"application-1.log"];
    NSString *source = nil;

    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:previousPath error:nil];
    unsigned long long fileSize = [attributes[NSFileSize] unsignedLongLongValue];
    if (fileSize != 0)
    {
        const NSUInteger maximumBytes = 512 * 1024;
        NSUInteger readLength = (NSUInteger)MIN((unsigned long long)maximumBytes, fileSize);
        unsigned long long startOffset = fileSize - readLength;
        NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:previousPath];
        if (handle != nil)
        {
            [handle seekToFileOffset:startOffset];
            NSData *data = [handle readDataToEndOfFile];
            [handle closeFile];

            if (startOffset != 0 && data.length != 0)
            {
                const uint8_t *bytes = data.bytes;
                NSUInteger skip = 0;
                while (skip < data.length && bytes[skip] != '\n')
                    skip++;
                if (skip < data.length)
                    skip++;
                if (skip != 0 && skip < data.length)
                    data = [data subdataWithRange:NSMakeRange(skip, data.length - skip)];
            }

            source = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (source == nil)
                source = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
        }
    }
    if (source.length == 0)
        source = text ?: @"";

    NSArray *lines = [source componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *contextLines = [[NSMutableArray alloc] init];

    const NSUInteger maximumContextLines = 160;
    for (NSString *line in lines)
    {
        if (line.length == 0)
            continue;
        if ([self lineIsCrashContext:line])
        {
            [contextLines addObject:line];
            if (contextLines.count > maximumContextLines)
                [contextLines removeObjectAtIndex:0];
        }
    }

    NSMutableString *result = [[NSMutableString alloc] init];
    for (NSString *line in contextLines)
        [result appendFormat:@"%@\n", line];

    NSString *crashPath = [documentsPath stringByAppendingPathComponent:@"ios6_last_crash.txt"];
    NSString *crash = [NSString stringWithContentsOfFile:crashPath encoding:NSUTF8StringEncoding error:nil];
    if (crash.length != 0 && [crash rangeOfString:@"CRASH context-begin"].location != NSNotFound)
    {
        return crash;
    }
    if (crash.length != 0)
    {
        NSArray *crashLines = [crash componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for (NSString *line in crashLines)
        {
            if (line.length == 0)
                continue;
            if ([line hasPrefix:@"CRASH"])
                [result appendFormat:@"%@\n", line];
            else
                [result appendFormat:@"CRASH %@\n", line];
        }
    }

    return result;
}

- (NSString *)filteredText:(NSString *)text query:(NSString *)query
{
    NSString *filter = query.length != 0 ? query : @"Основное";
    if ([filter isEqualToString:@"Сырой лог"])
        return text ?: @"";
    if ([filter isEqualToString:@"CRASH"])
        return [self crashDiagnosticText:text];

    NSMutableString *result = [[NSMutableString alloc] init];
    NSArray *lines = [(text ?: @"") componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines)
    {
        bool matches = false;
        if ([filter isEqualToString:@"Основное"])
        {
            matches = [self lineIsImportant:line];
        }
        else if ([filter isEqualToString:@"Ошибки"])
        {
            matches = [self lineLooksLikeError:line];
        }
        else if ([filter isEqualToString:@"Сеть"])
        {
            matches = [self lineIsNetworkDiagnostic:line];
        }
        else
        {
            matches = [line rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound;
        }

        if (matches)
            [result appendFormat:@"%@\n", line];
    }
    return result;
}

- (void)applyDisplayedText:(NSString *)text
{
    bool nearBottom = !_didInitialScroll || (_textView.contentOffset.y + _textView.bounds.size.height >= _textView.contentSize.height - 50.0f);
    _textView.text = text ?: @"";

    if (nearBottom && _textView.text.length != 0)
    {
        [_textView scrollRangeToVisible:NSMakeRange(_textView.text.length - 1, 1)];
        _didInitialScroll = true;
    }
}

- (void)refreshTimerTick
{
    [self refreshLogsForce:false];
}

- (void)refreshLogsForce:(bool)force
{
    unsigned long long currentSize = [self currentLogSize];
    if (!force && currentSize == _lastCurrentSize)
        return;
    if (_readInProgress)
        return;

    _lastCurrentSize = currentSize;
    _readInProgress = true;
    NSString *query = [_selectedFilter copy] ?: @"Основное";

    __weak TGIOS6LogsController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        __strong TGIOS6LogsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;

        NSString *raw = [strongSelf readLogTail];
        NSString *filtered = [strongSelf filteredText:raw query:query];

        dispatch_async(dispatch_get_main_queue(), ^
        {
            __strong TGIOS6LogsController *innerSelf = weakSelf;
            if (innerSelf == nil)
                return;
            innerSelf->_readInProgress = false;
            innerSelf->_rawText = raw ?: @"";
            [innerSelf applyDisplayedText:filtered];
        });
    });
}

- (void)setFilterMenuVisible:(bool)visible animated:(bool)animated
{
    _filterMenuVisible = visible;
    _filterMenu.hidden = false;
    _filterArrowLabel.text = visible ? @"▴" : @"▾";

    void (^changes)(void) = ^
    {
        [self viewWillLayoutSubviews];
        _filterMenu.alpha = visible ? 1.0f : 0.0f;
        if (visible)
        {
            for (TGModernButton *button in _filterMenuButtons)
            {
                if ([[button titleForState:UIControlStateNormal] isEqualToString:_selectedFilter])
                {
                    [_filterMenu scrollRectToVisible:CGRectInset(button.frame, 0.0f, -4.0f) animated:false];
                    break;
                }
            }
        }
    };

    if (animated)
    {
        if (visible)
            _filterMenu.alpha = 0.0f;
        [UIView animateWithDuration:0.2 animations:changes completion:^(BOOL finished)
        {
            if (!_filterMenuVisible)
                _filterMenu.hidden = true;
        }];
    }
    else
    {
        changes();
        _filterMenu.hidden = !visible;
    }
}

- (void)filterButtonPressed
{
    [self setFilterMenuVisible:!_filterMenuVisible animated:true];
}

- (void)filterOptionPressed:(TGModernButton *)button
{
    NSString *filter = [button titleForState:UIControlStateNormal];
    if (filter.length == 0)
        filter = @"Основное";

    _selectedFilter = filter;
    _filterValueLabel.text = filter;
    TGPresentationPallete *pallete = TGPresentation.current.pallete;
    for (TGModernButton *menuButton in _filterMenuButtons)
        [menuButton setTitleColor:(menuButton == button ? pallete.accentColor : pallete.textColor) forState:UIControlStateNormal];
    [self setFilterMenuVisible:false animated:true];
    [self applyDisplayedText:[self filteredText:_rawText query:_selectedFilter]];
}

- (void)clearPressed
{
    TGLogClear();
    _lastCurrentSize = (unsigned long long)-1;
    _rawText = @"";
    [self applyDisplayedText:@""];
    [self refreshLogsForce:true];
}

- (void)copyPressed
{
    [UIPasteboard generalPasteboard].string = _textView.text ?: @"";
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Логи" message:@"Скопировано" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

- (void)sharePressed
{
    NSString *text = _textView.text ?: @"";
    if (text.length == 0)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Логи" message:@"Лог пуст" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Onegram-logs.txt"];
    NSError *error = nil;
    if (![text writeToFile:path atomically:true encoding:NSUTF8StringEncoding error:&error])
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Логи" message:@"Не удалось подготовить файл" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }

    NSArray *files = @[@{ @"url": [NSURL fileURLWithPath:path] }];
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
    TGCollectionMenuSection *_fuckDPISection;
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
    TGDisclosureActionCollectionItem *_fuckDPIItem;
    TGDisclosureActionCollectionItem *_profileMusicItem;
    TGDocumentMediaAttachment *_profileMusicDocument;
    NSArray *_profileMusicDocuments;
    id<SDisposable> _profileMusicDisposable;
    TGDisclosureActionCollectionItem *_wallpapersItem;
    TGVariantCollectionItem *_languageItem;
    
    TGDisclosureActionCollectionItem *_notificationsItem;
    TGDisclosureActionCollectionItem *_privacySettingsItem;
    TGDisclosureActionCollectionItem *_chatSettingsItem;
    TGDisclosureActionCollectionItem *_callSettingsItem;
    TGDisclosureActionCollectionItem *_savedMessagesItem;
    TGDisclosureActionCollectionItem *_stickerSettingsItem;
    TGDisclosureActionCollectionItem *_clearChatListCacheItem;
    TGDisclosureActionCollectionItem *_developerChannelItem;
    
    TGCollectionMenuSection *_otherSection;
    TGDisclosureActionCollectionItem *_passportItem;
    SMetaDisposable *_passportStatusDisposable;
    
    id<SDisposable> _stickerPacksDisposable;
    id<SDisposable> _updatedFeaturedStickerPacksDisposable;
    
    TGMediaAvatarMenuMixin *_avatarMixin;
}

@property (nonatomic, strong) TGProgressWindow *progressWindow;

@end

@implementation TGAccountSettingsController

static NSString *TGAccountGroqApiKeyDefaultsKey(void)
{
    int32_t userId = TGTelegraphInstance.clientUserId;
    return userId != 0 ? [NSString stringWithFormat:@"TGGroqAPIKey.%d", userId] : @"TGGroqAPIKey";
}

- (id)initWithUid:(int32_t)uid
{
    self = [super init];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        [ActionStageInstance() watchForPaths:@[
            @"/tg/userdatachanges",
            @"/tg/userpresencechanges",
            @"/tg/calls/enabled"
        ] watcher:self];
        
        _uid = uid;
        
        _profileDataItem = [[TGAccountInfoCollectionItem alloc] init];
        _profileDataItem.hasDisclosureIndicator = true;
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
        _profileMusicItem.deselectAutomatically = true;
        
        _logsItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:@"Логи" action:@selector(logsPressed)];
        _logsItem.deselectAutomatically = true;
        _logsSection = [[TGCollectionMenuSection alloc] initWithItems:@[_logsItem]];
        [self.menuSections addSection:_logsSection];

        _fuckDPIItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:@"FuckDPI" action:@selector(fuckDPIPressed)];
        _fuckDPIItem.deselectAutomatically = true;
        _fuckDPISection = [[TGCollectionMenuSection alloc] initWithItems:@[_fuckDPIItem]];
        [self.menuSections addSection:_fuckDPISection];
        
        _proxyItem = [[TGVariantCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.Proxy") action:@selector(proxyPressed)];
        _proxySection = [[TGCollectionMenuSection alloc] initWithItems:@[_proxyItem]];
        
        _wallpapersItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.Appearance") action:@selector(wallpapersPressed)];
        _languageItem = [[TGVariantCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.AppLanguage") variant:TGLocalized(@"Localization.LanguageName") action:@selector(languagePressed)];
        
        NSMutableArray *settingsItems = [[NSMutableArray alloc] init];
        [settingsItems addObject:(_notificationsItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.NotificationsAndSounds") action:@selector(notificationsAndSoundsPressed)])];
        [settingsItems addObject:(_privacySettingsItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.PrivacySettings") action:@selector(privacySettingsPressed)])];
        [settingsItems addObject:(_chatSettingsItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.ChatSettings") action:@selector(chatSettingsPressed)])];
        [settingsItems addObject:_wallpapersItem];
        [settingsItems addObject:_languageItem];
        
        NSMutableArray *shortcutItems = [[NSMutableArray alloc] init];
        [shortcutItems addObject:(_savedMessagesItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.SavedMessages") action:@selector(savedMessagesPressed)])];
        [shortcutItems addObject:(_stickerSettingsItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"ChatSettings.Stickers") action:@selector(stickerSettingsPressed)])];
        [shortcutItems addObject:(_clearChatListCacheItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:@"Clear Chat Cache" action:@selector(clearChatListCachePressed)])];
        
        _shortcutSection = [[TGCollectionMenuSection alloc] initWithItems:shortcutItems];
        [self.menuSections addSection:_shortcutSection];
        
        _settingsSection = [[TGCollectionMenuSection alloc] initWithItems:settingsItems];
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
        
        TGCollectionMenuSection *infoSection = [[TGCollectionMenuSection alloc] initWithItems:@[
            _developerChannelItem
        ]];
        [self.menuSections addSection:infoSection];
   
#ifdef INTERNAL_RELEASE
        //TGCollectionMenuSection *debugSection = [[TGCollectionMenuSection alloc] initWithItems:@[[[TGButtonCollectionItem alloc] initWithTitle:@"Debug Settings" action:@selector(mySettingsPressed)]]];
        //[self.menuSections addSection:debugSection];
#endif
        
        [ActionStageInstance() watchForPath:@"/tg/loggedOut" watcher:self];
        
        UIMenuItem *copyPhoneItem = [[UIMenuItem alloc] initWithTitle:TGLocalized(@"Settings.CopyPhoneNumber") action:@selector(copyPhoneNumber:)];
        UIMenuItem *copyUsernameItem = [[UIMenuItem alloc] initWithTitle:TGLocalized(@"Settings.CopyUsername") action:@selector(copyUsername:)];
        [[UIMenuController sharedMenuController] setMenuItems:@[copyPhoneItem, copyUsernameItem]];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [_proxyListDisposable dispose];
    [_proxyStatusDisposable dispose];
    [_profileMusicDisposable dispose];
    [_passportStatusDisposable dispose];
    [_stickerPacksDisposable dispose];
    [_updatedFeaturedStickerPacksDisposable dispose];
    [ActionStageInstance() removeWatcher:self];
    [_progressWindow dismiss:true];
}

- (void)loadView
{
    [super loadView];
   
    _logsItem.icon = TGImageNamed(@"SettingsDataIcon.png");
    _proxyItem.icon = TGImageNamed(@"SettingsProxyIcon.png");
    _savedMessagesItem.icon = TGImageNamed(@"SettingsSavedMessagesIcon.png");
    _clearChatListCacheItem.icon = TGImageNamed(@"SettingsDataIcon.png");
    _notificationsItem.icon = TGImageNamed(@"SettingsNotificationsIcon.png");
    _privacySettingsItem.icon = TGImageNamed(@"SettingsPrivacyIcon.png");
    _chatSettingsItem.icon = TGImageNamed(@"SettingsDataIcon.png");
    _wallpapersItem.icon = TGImageNamed(@"SettingsWallpaperIcon.png");
    _stickerSettingsItem.icon = TGImageNamed(@"SettingsStickersIcon.png");
    _languageItem.icon = TGImageNamed(@"SettingsLanguageIcon.png");
    _passportItem.icon = TGImageNamed(@"SettingsPassportIcon.png");
    _developerChannelItem.icon = TGImageNamed(@"SettingsSupportIcon.png");
    if (_callSettingsItem != nil)
        _callSettingsItem.icon = TGImageNamed(@"SettingsCallsIcon.png");
    
    _editing = false;
    
    TGUser *user = [TGDatabaseInstance() loadUser:_uid];
    
    [_profileDataItem setUser:user animated:false];
    [self updateSubtitleWithPhoneNumber:user.phoneNumber username:user.userName];
    [self updateSuggestedSetProfilePhoto:user.photoUrlSmall.length == 0 setUsername:user.userName.length == 0];
    
    [self setTitleText:TGLocalized(@"Settings.Title")];
    
    [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Edit") style:UIBarButtonItemStylePlain target:self action:@selector(editButtonPressed)]];
    
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
    TGLog(@"ARCHIVE account settings clear chat list cache");
    [TGDatabaseInstance() setCustomProperty:@"dialogListLoaded" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"dialogListRemoteOffset" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"dialogListHash" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"ios6ArchivePeerIds" value:nil];
    [TGDatabaseInstance() setCustomProperty:@"ios6DialogListCacheVersion" value:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TGIOS6ClearChatListCacheRequested" object:nil];
}

- (void)wallpapersPressed
{
    [self.navigationController pushViewController:[[TGAppearanceController alloc] init] animated:true];
}

- (void)mySettingsPressed
{
    [self.navigationController pushViewController:[[TGSettingsController alloc] init] animated:true];
}

- (void)groqApiKeyPressed
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Groq API key"
                                                    message:@"The key is stored only on this device and is sent directly to Groq."
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Save", nil];
    alert.alertViewStyle = UIAlertViewStyleSecureTextInput;
    UITextField *field = [alert textFieldAtIndex:0];
    field.placeholder = @"gsk_...";
    field.text = [[NSUserDefaults standardUserDefaults] stringForKey:TGAccountGroqApiKeyDefaultsKey()];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (![alertView.title isEqualToString:@"Groq API key"] || buttonIndex != 1)
        return;

    UITextField *field = [alertView textFieldAtIndex:0];
    NSString *key = [field.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (key.length != 0)
        [[NSUserDefaults standardUserDefaults] setObject:key forKey:TGAccountGroqApiKeyDefaultsKey()];
    else
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TGAccountGroqApiKeyDefaultsKey()];
    [[NSUserDefaults standardUserDefaults] synchronize];
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

    if (hasMusic)
        _profileMusicItem.title = TGIOS6SettingsProfileMusicTitle(document);

    NSUInteger sectionIndex = [self.menuSections.sections indexOfObject:_headerSection];
    if (sectionIndex == NSNotFound)
        return;

    NSUInteger itemIndex = [_headerSection.items indexOfObject:_profileMusicItem];
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
        // setTitle: updates the bound row in-place, no full settings reload.
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

- (void)profileMusicPressed
{
    TGDocumentMediaAttachment *document = _profileMusicDocument;
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
        if ([[UIDevice currentDevice].systemVersion intValue] < 6)
            TGLog(@"AUDIO profileMusic.player telegraph=%p player=%p class=%@ responds=%d", TGTelegraphInstance, musicPlayer, NSStringFromClass([musicPlayer class]), [musicPlayer respondsToSelector:@selector(setPlaylist:initialItemKey:metadata:)] ? 1 : 0);
        [musicPlayer setPlaylist:[SSignal single:playlist] initialItemKey:item.key metadata:@{ @"profileMusicPeerId": @(strongSelf->_uid), @"profileSavedMusic": @true }];
        if ([[UIDevice currentDevice].systemVersion intValue] < 6)
            TGLog(@"AUDIO profileMusic.setPlaylist.return player=%p", musicPlayer);
    }];
}

- (void)logsPressed
{
    TGIOS6LogsController *controller = [[TGIOS6LogsController alloc] init];
    [self.navigationController pushViewController:controller animated:true];
}

- (void)fuckDPIPressed
{
    TGFuckDPIController *controller = [[TGFuckDPIController alloc] init];
    [self.navigationController pushViewController:controller animated:true];
}

- (void)developerChannelPressed
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://t.me/herefansios"]];
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
    if ([path hasPrefix:@"/tg/changeUserName/"])
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

- (void)actionStageActionRequested:(NSString *)action options:(id)__unused options
{
    if ([action isEqualToString:@"avatarTapped"])
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
//    else if ([action isEqualToString:@"editingNameChanged"])
//    {
//        _accountEditingBarButtonItem.enabled = [_profileDataItem editingFirstName].length != 0;
//    }
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
    
    [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Edit") style:UIBarButtonItemStylePlain target:self action:@selector(editButtonPressed)] animated:false];
    
    _savedMessagesItem.title = TGLocalized(@"Settings.SavedMessages");
    _clearChatListCacheItem.title = @"Clear Chat Cache";
    _notificationsItem.title = TGLocalized(@"Settings.NotificationsAndSounds");
    _privacySettingsItem.title = TGLocalized(@"Settings.PrivacySettings");
    _chatSettingsItem.title = TGLocalized(@"Settings.ChatSettings");
    
    _stickerSettingsItem.title = TGLocalized(@"ChatSettings.Stickers");
    
    _setProfilePhotoItem.title = TGLocalized(@"Settings.SetProfilePhoto");
    _setUsernameItem.title = TGLocalized(@"Settings.SetUsername");
    _wallpapersItem.title = TGLocalized(@"Settings.Appearance");
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
