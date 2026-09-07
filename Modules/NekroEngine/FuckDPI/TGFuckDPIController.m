#import "TGFuckDPIController.h"
#import "TGRouteCoordinator.h"
#import "TGFuckDPILog.h"
#import "TGFuckDPILogController.h"
#import "TGFuckDPIProfilesController.h"
#import "TGWarpProfileStore.h"
#import "TGNekroCommand.h"

static NSString *const kFuckDPILoggingEnabledKey = @"FuckDPILoggingEnabled_v5";
static NSString *const kFuckDPISelectedProfileKey = @"FuckDPISelectedProfileIndex_v5";

@interface TGFuckDPIController () <UIAlertViewDelegate>
{
    UISwitch *_enabledSwitch;
    UISwitch *_loggingSwitch;
    UILabel *_statusLabel;
    UIActivityIndicatorView *_activityIndicator;
    TGRouteCoordinator *_coordinator;
    NSString *_currentStatusText;
    UIColor *_currentStatusColor;
    BOOL _supported;
    BOOL _osUnsupported;
}
@end

@implementation TGFuckDPIController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (instancetype)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self != nil)
    {
        self.title = @"FuckDPI";
        _coordinator = [[TGRouteCoordinator alloc] init];
        _supported = [TGRouteCoordinator isSupported];
        _osUnsupported = ![TGNekroCommand isOSSupported];
        _currentStatusText = _supported ? @"Выключено" : [TGRouteCoordinator unsupportedReason];
        _currentStatusColor = [UIColor grayColor];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.94f alpha:1.0f];

    __unsafe_unretained TGFuckDPIController *weakSelf = self;
    _coordinator.stateChanged = ^(TGRouteState state, NSString *message)
    {
        [weakSelf updateForState:state message:message];
    };

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(routeStateChanged:)
                                                 name:TGRouteStateChangedNotification
                                               object:nil];
}

- (void)routeStateChanged:(NSNotification *)notification
{
    NSNumber *state = [notification.userInfo objectForKey:@"state"];
    NSString *message = [notification.userInfo objectForKey:@"message"];
    if (state != nil)
        [self updateForState:(TGRouteState)[state intValue] message:message];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    TGNekroAvailability availability = [TGNekroCommand availability];
    NSLog(@"[FuckDPI] settings helper path=%@ availability=%d os=%@",
          [TGNekroCommand enginePath], (int)availability, [TGNekroCommand osVersionDescription]);
    _supported = [TGRouteCoordinator isSupported];
    _osUnsupported = ![TGNekroCommand isOSSupported];
    _currentStatusText = _supported ? (_currentStatusText ?: @"Выключено") : [TGRouteCoordinator unsupportedReason];
    [_coordinator refreshState];
    [self.tableView reloadData];
}

- (NSInteger)profileSection
{
    return _supported ? 1 : NSNotFound;
}

- (NSInteger)diagnosticsSection
{
    return _supported ? 2 : NSNotFound;
}

- (NSInteger)restrictionSection
{
    return _osUnsupported ? (_supported ? 3 : 1) : NSNotFound;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (_supported ? 3 : 1) + (_osUnsupported ? 1 : 0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == [self restrictionSection])
        return 1;
    if (section == [self diagnosticsSection])
        return 2;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) return @"ОБХОД БЛОКИРОВОК";
    if (section == [self profileSection]) return @"ПРОФИЛЬ WARP / AWG";
    if (section == [self diagnosticsSection]) return @"ДИАГНОСТИКА";
    if (section == [self restrictionSection]) return @"ОГРАНИЧЕНИЕ ПО ВЕРСИИ iOS";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
    {
        if (_supported)
            return @"Onegram проверит WARP/AWG-профили и выберет рабочий маршрут только для сетей Telegram.";
        if (_osUnsupported)
            return @"Оригинальный FuckDPI рассчитан на iOS 5–6. На iOS 7–10 запуск можно разрешить экспериментально внизу экрана.";
        return @"Нужен jailbreak, /usr/libexec/fuckdpid и root launchd bridge. После новой сборки снова запустите tools/install_fuckdpi_helper_on_device.sh на устройстве от root.";
    }
    if (section == [self profileSection])
        return @"Можно выбрать конкретный профиль или оставить Автовыбор.";
    if (section == [self diagnosticsSection])
        return @"Логирование записывает поиск маршрута и работу WARP/AWG в Documents/fuckdpi.log.";
    if (section == [self restrictionSection])
    {
        return [TGNekroCommand unsupportedOSOverrideEnabled]
            ? [NSString stringWithFormat:@"Экспериментальный запуск разрешён на %@. Если сеть пропадёт, выключите FuckDPI и верните ограничение.", [TGNekroCommand osVersionDescription]]
            : [NSString stringWithFormat:@"Туннель и низкоуровневая маршрутизация исходного клиента проверены только на iOS 5–6. На %@ запуск по умолчанию заблокирован.", [TGNekroCommand osVersionDescription]];
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        static NSString *identifier = @"FuckDPIMainSwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            _enabledSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
            [_enabledSwitch addTarget:self action:@selector(enabledChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = _enabledSwitch;
            _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        }
        cell.textLabel.text = @"FuckDPI";
        cell.textLabel.font = [UIFont systemFontOfSize:17.0f];
        _enabledSwitch.enabled = _supported;
        cell.detailTextLabel.text = _currentStatusText ?: @"Выключено";
        cell.detailTextLabel.textColor = _currentStatusColor ?: [UIColor grayColor];
        _statusLabel = cell.detailTextLabel;
        return cell;
    }

    if (indexPath.section == [self profileSection])
    {
        static NSString *identifier = @"FuckDPIProfileSelectCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.textLabel.text = @"Выбор профиля";
        NSInteger selected = [[NSUserDefaults standardUserDefaults] integerForKey:kFuckDPISelectedProfileKey];
        NSArray *profiles = [TGWarpProfileStore availableProfileNames];
        NSString *name = @"Автовыбор";
        if (selected > 0 && selected - 1 < (NSInteger)[profiles count])
            name = [profiles objectAtIndex:(NSUInteger)(selected - 1)];
        cell.detailTextLabel.text = name;
        cell.detailTextLabel.textColor = [UIColor grayColor];
        return cell;
    }

    if (indexPath.section == [self diagnosticsSection])
    {
        if (indexPath.row == 0)
        {
            static NSString *identifier = @"FuckDPILogSwitchCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
            if (cell == nil)
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                _loggingSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
                _loggingSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:kFuckDPILoggingEnabledKey];
                [_loggingSwitch addTarget:self action:@selector(loggingChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = _loggingSwitch;
            }
            cell.textLabel.text = @"Логирование";
            return cell;
        }

        static NSString *identifier = @"FuckDPILogViewerCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.textLabel.text = @"Просмотр логов";
        cell.textLabel.textColor = [UIColor colorWithRed:0.0f green:0.478f blue:1.0f alpha:1.0f];
        return cell;
    }

    static NSString *identifier = @"FuckDPIRestrictionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    BOOL overridden = [TGNekroCommand unsupportedOSOverrideEnabled];
    cell.textLabel.text = overridden ? @"Вернуть ограничение" : @"Разрешить экспериментально";
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.textLabel.textColor = overridden ? [UIColor colorWithRed:0.0f green:0.478f blue:1.0f alpha:1.0f]
                                          : [UIColor colorWithRed:0.78f green:0.16f blue:0.16f alpha:1.0f];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == [self profileSection])
    {
        TGFuckDPIProfilesController *controller = [[TGFuckDPIProfilesController alloc] init];
        __unsafe_unretained TGFuckDPIController *weakSelf = self;
        controller.profileChanged = ^(NSInteger newIndex, NSString *newProfileName)
        {
            [weakSelf.tableView reloadData];
        };
        [self.navigationController pushViewController:controller animated:YES];
        return;
    }

    if (indexPath.section == [self diagnosticsSection] && indexPath.row == 1)
    {
        [self.navigationController pushViewController:[[TGFuckDPILogController alloc] init] animated:YES];
        return;
    }

    if (indexPath.section == [self restrictionSection])
    {
        if ([TGNekroCommand unsupportedOSOverrideEnabled])
        {
            [self applyRestrictionOverride:NO];
            return;
        }

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Разрешить FuckDPI?"
                                                       message:@"На iOS 7–10 этот низкоуровневый туннель исходным клиентом не был проверен. Возможны потеря сети или перезагрузка устройства."
                                                      delegate:self
                                             cancelButtonTitle:@"Отмена"
                                             otherButtonTitles:@"Разрешить", nil];
        [alert show];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != alertView.cancelButtonIndex)
        [self applyRestrictionOverride:YES];
}

- (void)applyRestrictionOverride:(BOOL)enabled
{
    if (!enabled)
        [_coordinator disable];
    [TGNekroCommand setUnsupportedOSOverrideEnabled:enabled];
    _supported = [TGRouteCoordinator isSupported];
    _currentStatusText = _supported ? @"Выключено" : [TGRouteCoordinator unsupportedReason];
    _currentStatusColor = [UIColor grayColor];
    [self.tableView reloadData];
    [_coordinator refreshState];
}

- (void)enabledChanged:(UISwitch *)sender
{
    FDPILog(@"FuckDPI switch: %s", sender.on ? "ON" : "OFF");
    sender.enabled = NO;
    if (sender.on)
        [_coordinator enable];
    else
        [_coordinator disable];
    [self performSelector:@selector(unstickSwitch) withObject:nil afterDelay:120.0];
}

- (void)unstickSwitch
{
    if (!_enabledSwitch.enabled)
        [_coordinator refreshState];
}

- (void)loggingChanged:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:kFuckDPILoggingEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    FDPILog(@"Logging: %s", sender.on ? "ON" : "OFF");
}

- (void)updateForState:(TGRouteState)state message:(NSString *)message
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{ [self updateForState:state message:message]; });
        return;
    }

    BOOL busy = state == TGRouteStateSearching || state == TGRouteStateConnecting;
    BOOL connected = state == TGRouteStateConnected;
    _enabledSwitch.enabled = _supported && !busy;
    _enabledSwitch.on = connected || busy;
    _currentStatusText = message ?: @"Выключено";
    _currentStatusColor = connected ? [UIColor colorWithRed:0.12f green:0.58f blue:0.24f alpha:1.0f]
                                    : (state == TGRouteStateFailed ? [UIColor colorWithRed:0.78f green:0.16f blue:0.16f alpha:1.0f] : [UIColor grayColor]);
    _statusLabel.text = _currentStatusText;
    _statusLabel.textColor = _currentStatusColor;

    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    if (cell != nil)
    {
        if (busy)
        {
            [_activityIndicator startAnimating];
            cell.accessoryView = _activityIndicator;
        }
        else
        {
            [_activityIndicator stopAnimating];
            cell.accessoryView = _enabledSwitch;
        }
    }
}

@end
