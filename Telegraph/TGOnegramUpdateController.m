#import "TGOnegramUpdateController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGAppDelegate.h"
#import "TGRootController.h"
#import "TGCustomAlertView.h"
#import "TGOnegramUpdater.h"

static NSString *const TGOnegramUpdateDismissedVersionKey = @"TGOnegramUpdateDismissedVersion";
static const NSUInteger TGOnegramUpdateNotesLimit = 1500;
static bool TGOnegramUpdateLaunchPromptArmed = false;
static NSString *TGOnegramUpdatePromptedVersion = nil;

static NSString *TGOnegramUpdateErrorText(TGOnegramUpdaterError error)
{
    switch (error)
    {
        case TGOnegramUpdaterErrorNone:
            return nil;
        case TGOnegramUpdaterErrorNetwork:
            return TGLocalized(@"OnegramUpdate.Error.Network");
        case TGOnegramUpdaterErrorCertificate:
            return TGLocalized(@"OnegramUpdate.Error.Certificate");
        case TGOnegramUpdaterErrorRelease:
            return TGLocalized(@"OnegramUpdate.Error.Release");
        case TGOnegramUpdaterErrorChecksum:
            return TGLocalized(@"OnegramUpdate.Error.Checksum");
        case TGOnegramUpdaterErrorArchive:
            return TGLocalized(@"OnegramUpdate.Error.Archive");
        case TGOnegramUpdaterErrorPackage:
            return TGLocalized(@"OnegramUpdate.Error.Package");
        case TGOnegramUpdaterErrorStorage:
            return TGLocalized(@"OnegramUpdate.Error.Storage");
        case TGOnegramUpdaterErrorNotWritable:
            return TGLocalized(@"OnegramUpdate.InPlaceUnavailable");
        case TGOnegramUpdaterErrorInstall:
            return TGLocalized(@"OnegramUpdate.Error.Install");
    }
    return nil;
}

@interface TGOnegramUpdateController ()
{
    TGOnegramUpdaterState _builtState;
    TGOnegramActionCollectionItem *_progressItem;
    bool _updaterRebuildScheduled;
}

@end

@implementation TGOnegramUpdateController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (NSString *)statusVariant
{
    TGOnegramUpdater *updater = [TGOnegramUpdater sharedUpdater];
    if ([updater hasNewerRelease])
        return updater.latestRelease.version;
    return [TGOnegramUpdater currentVersion];
}

+ (void)startAutomaticCheck
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(launchUpdaterStateChanged:) name:TGOnegramUpdaterStateChangedNotification object:nil];
        [center addObserver:self selector:@selector(launchUpdaterStateChanged:) name:UIApplicationDidBecomeActiveNotification object:nil];
    });
    TGOnegramUpdateLaunchPromptArmed = true;
    TGOnegramUpdater *updater = [TGOnegramUpdater sharedUpdater];
    if (updater.state == TGOnegramUpdaterStateIdle)
        [updater checkForUpdates];
    else if (updater.state == TGOnegramUpdaterStateAvailable)
        [self launchUpdaterStateChanged:nil];
    else
        [updater checkForUpdatesIfNeeded];
}

+ (void)launchUpdaterStateChanged:(NSNotification *)__unused notification
{
    TGOnegramUpdater *updater = [TGOnegramUpdater sharedUpdater];
    if (!TGOnegramUpdateLaunchPromptArmed || updater.state == TGOnegramUpdaterStateChecking)
        return;
    bool available = updater.state == TGOnegramUpdaterStateAvailable && [updater hasNewerRelease];
    if (available && [UIApplication sharedApplication].applicationState != UIApplicationStateActive)
        return;
    TGOnegramUpdateLaunchPromptArmed = false;

    if (!available)
        return;
    NSString *version = updater.latestRelease.version;
    if ([TGOnegramUpdatePromptedVersion isEqualToString:version] || [[[NSUserDefaults standardUserDefaults] objectForKey:TGOnegramUpdateDismissedVersionKey] isEqual:version])
        return;
    TGOnegramUpdatePromptedVersion = version;

    [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"OnegramUpdate.AlertTitle") message:[NSString stringWithFormat:TGLocalized(@"OnegramUpdate.AlertText"), version] cancelButtonTitle:TGLocalized(@"OnegramUpdate.Later") okButtonTitle:TGLocalized(@"OnegramUpdate.Update") completionBlock:^(bool okButtonPressed)
    {
        if (!okButtonPressed)
        {
            [[NSUserDefaults standardUserDefaults] setObject:version forKey:TGOnegramUpdateDismissedVersionKey];
            return;
        }
        [TGAppDelegateInstance.rootController pushContentController:[[TGOnegramUpdateController alloc] init]];
        TGOnegramUpdater *currentUpdater = [TGOnegramUpdater sharedUpdater];
        if ([currentUpdater canInstall])
            [currentUpdater installLatestRelease];
    }];
}

- (instancetype)init
{
    self = [super initWithTitle:TGLocalized(@"OnegramUpdate.Title")];
    if (self != nil)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updaterStateChanged:) name:TGOnegramUpdaterStateChangedNotification object:nil];
    return self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    TGOnegramUpdater *updater = [TGOnegramUpdater sharedUpdater];
    if (updater.state == TGOnegramUpdaterStateIdle)
        [updater checkForUpdates];
}

- (void)updaterStateChanged:(NSNotification *)__unused notification
{
    TGOnegramUpdater *updater = [TGOnegramUpdater sharedUpdater];
    if (updater.state == _builtState && _progressItem != nil)
    {
        _progressItem.variant = [self progressText];
        return;
    }
    if (_updaterRebuildScheduled)
        return;
    _updaterRebuildScheduled = true;
    __weak TGOnegramUpdateController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^
    {
        __strong TGOnegramUpdateController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_updaterRebuildScheduled = false;
        [strongSelf rebuild];
    });
}

- (NSString *)progressText
{
    return [NSString stringWithFormat:@"%d%%", (int)([TGOnegramUpdater sharedUpdater].progress * 100.0f)];
}

- (TGOnegramActionCollectionItem *)infoItemWithTitle:(NSString *)title variant:(NSString *)variant
{
    TGOnegramActionCollectionItem *item = [self actionWithTitle:title variant:variant pressed:nil];
    item.hideArrow = true;
    item.selectable = false;
    return item;
}

- (NSString *)versionFooter
{
    TGOnegramUpdater *updater = [TGOnegramUpdater sharedUpdater];
    switch (updater.state)
    {
        case TGOnegramUpdaterStateFailed:
            return TGOnegramUpdateErrorText(updater.error);
        case TGOnegramUpdaterStateUpToDate:
            return TGLocalized(@"OnegramUpdate.UpToDate");
        case TGOnegramUpdaterStateDownloading:
        case TGOnegramUpdaterStateInstalling:
            return TGLocalized(@"OnegramUpdate.InstallingInfo");
        case TGOnegramUpdaterStateInstalled:
            return TGLocalized(@"OnegramUpdate.RestartInfo");
        case TGOnegramUpdaterStateAvailable:
            if (![updater canInstall])
                return TGLocalized(@"OnegramUpdate.InPlaceUnavailable");
            if ([updater usesSystemInstaller])
                return TGLocalized(@"OnegramUpdate.SystemInstallInfo");
            break;
        default:
            break;
    }
    if (updater.lastCheckDate == nil)
        return nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [NSString stringWithFormat:TGLocalized(@"OnegramUpdate.LastCheck"), [formatter stringFromDate:updater.lastCheckDate]];
}

- (NSArray *)buildSections
{
    TGOnegramUpdater *updater = [TGOnegramUpdater sharedUpdater];
    TGOnegramRelease *release = updater.latestRelease;
    TGOnegramUpdaterState state = updater.state;
    __weak TGOnegramUpdateController *weakSelf = self;

    _builtState = state;
    _progressItem = nil;

    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *installed = [build isKindOfClass:[NSString class]] && build.length != 0 ? [NSString stringWithFormat:@"%@ (%@)", [TGOnegramUpdater currentVersion], build] : [TGOnegramUpdater currentVersion];
    NSString *latest = release.version;
    if (latest == nil)
        latest = state == TGOnegramUpdaterStateChecking ? TGLocalized(@"OnegramUpdate.Checking") : @"—";

    NSMutableArray *sections = [[NSMutableArray alloc] init];
    [sections addObject:[self sectionWithHeader:nil items:@[
        [self infoItemWithTitle:TGLocalized(@"OnegramUpdate.Installed") variant:installed],
        [self infoItemWithTitle:TGLocalized(@"OnegramUpdate.Latest") variant:latest]
    ] footer:[self versionFooter]]];

    NSMutableArray *actions = [[NSMutableArray alloc] init];
    if (state == TGOnegramUpdaterStateDownloading || state == TGOnegramUpdaterStateInstalling)
    {
        _progressItem = [self infoItemWithTitle:TGLocalized(state == TGOnegramUpdaterStateDownloading ? @"OnegramUpdate.Downloading" : @"OnegramUpdate.Installing") variant:[self progressText]];
        [actions addObject:_progressItem];
        if ([updater canCancel])
        {
            [actions addObject:[self actionWithTitle:TGLocalized(@"OnegramUpdate.Cancel") variant:nil pressed:^
            {
                [[TGOnegramUpdater sharedUpdater] cancel];
            }]];
        }
    }
    else if (state == TGOnegramUpdaterStateInstalled)
    {
        [actions addObject:[self actionWithTitle:TGLocalized(@"OnegramUpdate.Restart") variant:nil pressed:^
        {
            [weakSelf restartPressed];
        }]];
    }
    else
    {
        if ([updater hasNewerRelease])
        {
            if ([updater canInstall])
            {
                [actions addObject:[self actionWithTitle:[NSString stringWithFormat:TGLocalized(@"OnegramUpdate.Install"), release.version] variant:nil pressed:^
                {
                    [[TGOnegramUpdater sharedUpdater] installLatestRelease];
                }]];
            }
            if (![updater canInstall] || (state == TGOnegramUpdaterStateFailed && updater.error == TGOnegramUpdaterErrorInstall))
            {
                NSURL *pageURL = release.pageURL;
                [actions addObject:[self actionWithTitle:TGLocalized(@"OnegramUpdate.OpenRelease") variant:nil pressed:^
                {
                    [[UIApplication sharedApplication] openURL:pageURL];
                }]];
            }
        }

        TGOnegramActionCollectionItem *checkItem = [self actionWithTitle:TGLocalized(@"OnegramUpdate.Check") variant:state == TGOnegramUpdaterStateChecking ? TGLocalized(@"OnegramUpdate.Checking") : nil pressed:^
        {
            [[TGOnegramUpdater sharedUpdater] checkForUpdates];
        }];
        checkItem.enabled = state != TGOnegramUpdaterStateChecking;
        [actions addObject:checkItem];
    }
    [sections addObject:[self sectionWithHeader:nil items:actions footer:nil]];

    if ([updater hasNewerRelease] && release.notes.length != 0)
    {
        NSString *notes = [release.notes stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (notes.length > TGOnegramUpdateNotesLimit)
            notes = [[notes substringToIndex:TGOnegramUpdateNotesLimit] stringByAppendingString:@"…"];
        [sections addObject:[self sectionWithHeader:release.title items:@[] footer:notes]];
    }

    return sections;
}

- (void)restartPressed
{
    [[NSUserDefaults standardUserDefaults] synchronize];
    exit(0);
}

@end
