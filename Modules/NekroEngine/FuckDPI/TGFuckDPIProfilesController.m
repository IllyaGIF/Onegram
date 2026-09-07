#import "TGFuckDPIProfilesController.h"
#import "TGWarpProfileStore.h"
#import "TGNekroCommand.h"
#import "TGRouteCoordinator.h"
#import "TGFuckDPILog.h"

static NSString *const kFuckDPISelectedProfileKey = @"FuckDPISelectedProfileIndex_v5";

static NSString *const kGeneratedEndpoint = @"188.114.96.1:4500";

static NSArray *TGGeneratedKeys(void)
{
    return [NSArray arrayWithObjects:@"Address", @"PrivateKey", @"PublicKey", @"Endpoint", nil];
}

@interface TGFuckDPIProfilesController ()
{
    BOOL _generating;
}
- (UITableViewCell *)actionCellForRow:(NSInteger)row;
- (void)generateProfile;
- (void)restoreBundledProfiles;
- (NSDictionary *)parseRegisterOutput:(NSString *)output;
- (NSString *)confFromResponse:(NSDictionary *)response;
- (NSString *)selectedProfileName;
- (void)reselectProfileNamed:(NSString *)name;
- (void)showMessage:(NSString *)message;
@end

@implementation TGFuckDPIProfilesController

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
        self.title = @"Выбор профиля";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.94f alpha:1.0f];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
        return (NSInteger)[TGWarpProfileStore availableProfileNames].count + 1;
    return [TGWarpProfileStore hasHiddenProfiles] ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return section == 0 ? @"ДОСТУПНЫЕ ПРОФИЛИ WARP / AWG" : @"НОВЫЙ ПРОФИЛЬ";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
        return @"Выберите конкретный профиль WARP или 'Автовыбор' для автоматического поиска наибыстрейшего маршрута. Смахните профиль влево, чтобы убрать его из списка.";
    return @"Регистрирует новый аккаунт WARP и сохраняет его как отдельный профиль. Занимает до минуты: при неудаче прямой регистрации помощник пробует обходные прокси.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1)
        return [self actionCellForRow:indexPath.row];

    static NSString *identifier = @"ProfileCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }

    NSInteger currentSelected = [[NSUserDefaults standardUserDefaults] integerForKey:kFuckDPISelectedProfileKey];
    NSArray *profiles = [TGWarpProfileStore availableProfileNames];

    if (indexPath.row == 0)
    {
        cell.textLabel.text = @"⚡ Автовыбор (автоматический поиск)";
        cell.accessoryType = (currentSelected == 0) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    else
    {
        NSInteger profileIdx = indexPath.row - 1;
        if (profileIdx < (NSInteger)profiles.count)
        {
            cell.textLabel.text = [profiles objectAtIndex:(NSUInteger)profileIdx];
            cell.accessoryType = (currentSelected == (profileIdx + 1)) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        }
    }
    cell.textLabel.font = [UIFont systemFontOfSize:16.0f];
    return cell;
}

- (UITableViewCell *)actionCellForRow:(NSInteger)row
{
    static NSString *identifier = @"ProfileActionCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];

    cell.accessoryView = nil;
    cell.textLabel.font = [UIFont systemFontOfSize:16.0f];

    if (row == 0)
    {
        cell.textLabel.text = _generating ? @"Регистрация аккаунта…" : @"Сгенерировать новый конфиг";
        cell.textLabel.textColor = _generating
            ? [UIColor grayColor]
            : [UIColor colorWithRed:0.0f green:0.478f blue:1.0f alpha:1.0f];
        if (_generating)
        {
            UIActivityIndicatorView *spinner =
                [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            [spinner startAnimating];
            cell.accessoryView = spinner;
        }
    }
    else
    {
        cell.textLabel.text = @"Восстановить встроенные профили";
        cell.textLabel.textColor = [UIColor colorWithRed:0.0f green:0.478f blue:1.0f alpha:1.0f];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 1)
    {
        if (indexPath.row == 0)
            [self generateProfile];
        else
            [self restoreBundledProfiles];
        return;
    }

    NSInteger newIndex = indexPath.row;
    [[NSUserDefaults standardUserDefaults] setInteger:newIndex forKey:kFuckDPISelectedProfileKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSArray *profiles = [TGWarpProfileStore availableProfileNames];
    NSString *name = @"Автовыбор";
    if (newIndex > 0 && (newIndex - 1) < (NSInteger)profiles.count)
        name = [profiles objectAtIndex:(NSUInteger)(newIndex - 1)];

    [self.tableView reloadData];

    if (self.profileChanged)
        self.profileChanged(newIndex, name);
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section == 0 && indexPath.row > 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Удалить";
}

- (void)tableView:(UITableView *)tableView
        commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
         forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete) return;

    NSArray *profiles = [TGWarpProfileStore availableProfileNames];
    NSInteger profileIdx = indexPath.row - 1;
    if (profileIdx < 0 || profileIdx >= (NSInteger)profiles.count) return;

    NSString *name = [profiles objectAtIndex:(NSUInteger)profileIdx];
    NSString *wasSelected = [self selectedProfileName];
    if (![TGWarpProfileStore deleteProfileNamed:name]) return;

    [self reselectProfileNamed:([wasSelected isEqualToString:name] ? nil : wasSelected)];
    [tableView reloadData];
}

- (NSString *)selectedProfileName
{
    NSInteger selected = [[NSUserDefaults standardUserDefaults] integerForKey:kFuckDPISelectedProfileKey];
    NSArray *profiles = [TGWarpProfileStore availableProfileNames];
    if (selected <= 0 || (NSUInteger)(selected - 1) >= profiles.count) return nil;
    return [profiles objectAtIndex:(NSUInteger)(selected - 1)];
}

- (void)reselectProfileNamed:(NSString *)name
{
    [TGRouteCoordinator forgetRememberedRoute];

    NSUInteger index = name == nil ? NSNotFound : [[TGWarpProfileStore availableProfileNames] indexOfObject:name];
    NSInteger selection = index == NSNotFound ? 0 : (NSInteger)index + 1;

    [[NSUserDefaults standardUserDefaults] setInteger:selection forKey:kFuckDPISelectedProfileKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if (self.profileChanged)
        self.profileChanged(selection, selection == 0 ? @"Автовыбор" : name);
}

- (void)restoreBundledProfiles
{
    NSString *wasSelected = [self selectedProfileName];
    [TGWarpProfileStore restoreHiddenProfiles];
    [self reselectProfileNamed:wasSelected];
    [self.tableView reloadData];
}

- (void)generateProfile
{
    if (_generating) return;

    if (![TGRouteCoordinator isSupported])
    {
        [self showMessage:[NSString stringWithFormat:@"Регистрация недоступна: %@.",
                           [TGRouteCoordinator unsupportedReason]]];
        return;
    }

    _generating = YES;
    [self.tableView reloadData];

    NSString *wasSelected = [self selectedProfileName];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *output = nil;
        int rc = [TGNekroCommand run:[NSArray arrayWithObject:@"register"] output:&output];
        FDPILog(@"register: exit=%d\n%@", rc, output.length == 0 ? @"(no output)" : output);

        NSString *conf = nil;
        NSString *failure = nil;
        NSDictionary *response = [self parseRegisterOutput:output];

        if (response == nil)
            failure = @"Помощник не вернул ответ.";
        else if (![[response objectForKey:@"status"] isEqualToString:@"success"])
            failure = [response objectForKey:@"message"] ?: @"Регистрация не удалась.";
        else
        {
            conf = [self confFromResponse:response];
            if (conf == nil)
                failure = @"Не из чего собрать конфиг: нет встроенного профиля-шаблона.";
        }

        NSString *written = conf == nil ? nil : [TGWarpProfileStore writeGeneratedProfile:conf];
        if (written == nil && failure == nil)
            failure = @"Не удалось сохранить профиль.";

        dispatch_async(dispatch_get_main_queue(), ^{
            self->_generating = NO;
            if (written != nil)
            {
                [self reselectProfileNamed:wasSelected];
            }
            [self.tableView reloadData];
            if (failure != nil)
                [self showMessage:failure];
        });
    });
}

- (NSDictionary *)parseRegisterOutput:(NSString *)output
{
    if (output.length == 0) return nil;

    NSUInteger searchFrom = 0;
    while (searchFrom < output.length)
    {
        NSRange opening = [output rangeOfString:@"{"
                                        options:0
                                          range:NSMakeRange(searchFrom, output.length - searchFrom)];
        if (opening.location == NSNotFound)
            break;

        NSInteger depth = 0;
        BOOL insideString = NO;
        BOOL escaped = NO;
        for (NSUInteger i = opening.location; i < output.length; i++)
        {
            unichar c = [output characterAtIndex:i];
            if (escaped)            { escaped = NO; continue; }
            if (c == '\\')          { escaped = insideString; continue; }
            if (c == '"')           { insideString = !insideString; continue; }
            if (insideString)       continue;

            if (c == '{')
                depth++;
            else if (c == '}' && --depth == 0)
            {
                NSString *candidate = [output substringWithRange:NSMakeRange(opening.location, i - opening.location + 1)];
                id parsed = [NSJSONSerialization JSONObjectWithData:[candidate dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:0
                                                              error:NULL];
                if ([parsed isKindOfClass:[NSDictionary class]])
                    return parsed;
                break;
            }
        }

        searchFrom = opening.location + 1;
    }

    FDPILog(@"register: no JSON object in the output");
    return nil;
}

- (NSString *)confFromResponse:(NSDictionary *)response
{
    NSArray *profiles = [TGWarpProfileStore orderedProfiles];
    NSString *templateConf = nil;
    for (NSDictionary *profile in profiles)
    {
        if (![[profile objectForKey:TGWarpProfileGenerated] boolValue])
        {
            templateConf = [profile objectForKey:TGWarpProfileConf];
            break;
        }
    }
    if (templateConf == nil && profiles.count > 0)
        templateConf = [[profiles objectAtIndex:0] objectForKey:TGWarpProfileConf];
    if (templateConf == nil)
        return nil;

    NSString *ip4 = [response objectForKey:@"clientIp"] ?: @"172.16.0.2";
    NSString *ip6 = [response objectForKey:@"clientIp6"] ?: @"";
    NSString *address = ip6.length > 0
        ? [NSString stringWithFormat:@"%@/32, %@/128", ip4, ip6]
        : [NSString stringWithFormat:@"%@/32", ip4];

    NSDictionary *replacements = @{@"Address":    address,
                                   @"PrivateKey": [response objectForKey:@"priv"] ?: @"",
                                   @"PublicKey":  [response objectForKey:@"pub"] ?: @"",
                                   @"Endpoint":   kGeneratedEndpoint};

    NSMutableArray *out = [NSMutableArray array];
    NSCharacterSet *trim = [NSCharacterSet whitespaceCharacterSet];
    for (NSString *line in [templateConf componentsSeparatedByString:@"\n"])
    {
        NSRange equals = [line rangeOfString:@"="];
        NSString *replaced = nil;
        if (equals.location != NSNotFound)
        {
            NSString *key = [[line substringToIndex:equals.location] stringByTrimmingCharactersInSet:trim];
            for (NSString *candidate in TGGeneratedKeys())
            {
                if ([key caseInsensitiveCompare:candidate] != NSOrderedSame) continue;
                NSString *value = [replacements objectForKey:candidate];
                if (value.length > 0)
                    replaced = [NSString stringWithFormat:@"%@ = %@", key, value];
                break;
            }
        }
        [out addObject:replaced ?: line];
    }
    return [out componentsJoinedByString:@"\n"];
}

- (void)showMessage:(NSString *)message
{
    FDPILog(@"register: %@", message);
}

@end
