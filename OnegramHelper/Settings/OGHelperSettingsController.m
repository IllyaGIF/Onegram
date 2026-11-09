#import "OGHelperSettingsController.h"

#import "OGHelperLogPanel.h"
#import "OGHelperSettingsStrings.h"
#import "OGHelperTimerTarget.h"
#import "../OGHelperProtocol.h"
#import "../../OnegramRuntime/OGDiagnostics.h"
#import "../../OnegramRuntime/OGLogCatalog.h"

#ifndef ONEGRAM_DIAGNOSTICS_DEFAULT
#error ONEGRAM_DIAGNOSTICS_DEFAULT must be provided by build.sh
#endif

static NSString *const OGHelperSettingsEntryKey = @"OGLogEntry";
static const NSTimeInterval OGHelperSettingsRefreshInterval = 2.0;

@interface PSListController (OGHelperSettingsTableDelegate)
- (void)reloadSpecifier:(PSSpecifier *)specifier;
- (UIView *)view;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath;
@end

@interface OGHelperSettingsController () <OGHelperTimerReceiver>
{
    NSArray *_entries;
    bool _loading;
    NSMutableArray *_sectionRows;
    NSNumber *_onegramBuildDefault;
    NSDateFormatter *_timeFormatter;
    NSDateFormatter *_dateFormatter;
    NSTimer *_refreshTimer;
    NSString *_signature;
}

@end

@implementation OGHelperSettingsController

- (NSBundle *)settingsBundle
{
    return [NSBundle bundleForClass:[OGHelperSettingsController class]];
}

- (NSString *)string:(NSString *)key
{
    return OGHelperSettingsString([self settingsBundle], key);
}

- (void)dealloc
{
    [_refreshTimer invalidate];
}

- (NSArray *)specifiers
{
    if (_refreshTimer == nil)
        _refreshTimer = [OGHelperTimerTarget scheduledTimerWithInterval:OGHelperSettingsRefreshInterval target:self];
    if (_specifiers == nil)
        _specifiers = [self buildSpecifiers];
    return _specifiers;
}

- (bool)isOnScreen
{
    if (![self respondsToSelector:@selector(view)])
        return true;
    return [self view].window != nil;
}

- (void)refreshTimerFired:(NSTimer *)__unused timer
{
    if (_entries != nil && [self isOnScreen])
        [self startLoadingEntries];
}

- (NSString *)signatureForEntries:(NSArray *)entries
{
    NSMutableString *signature = [[NSMutableString alloc] initWithFormat:@"%d%d", [[self onegramDiagnostics:nil] boolValue] ? 1 : 0, [[self helperDiagnostics:nil] boolValue] ? 1 : 0];
    for (OGLogEntry *entry in entries)
        [signature appendFormat:@"|%@:%llu:%.0f", entry.path, entry.size, entry.modificationDate.timeIntervalSince1970];
    return signature;
}

- (void)addGroupNamed:(NSString *)name footer:(NSString *)footer toSpecifiers:(NSMutableArray *)specifiers
{
    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:name target:nil set:NULL get:NULL detail:Nil cell:OGPreferencesGroupCell edit:Nil];
    if (footer != nil)
        [group setProperty:footer forKey:@"footerText"];
    [specifiers addObject:group];
    [_sectionRows addObject:[NSMutableArray array]];
}

- (void)addRow:(PSSpecifier *)row toSpecifiers:(NSMutableArray *)specifiers
{
    [specifiers addObject:row];
    [[_sectionRows lastObject] addObject:row];
}

- (void)addStaticText:(NSString *)text toSpecifiers:(NSMutableArray *)specifiers
{
    [self addRow:[PSSpecifier preferenceSpecifierNamed:text target:nil set:NULL get:NULL detail:Nil cell:OGPreferencesStaticTextCell edit:Nil] toSpecifiers:specifiers];
}

- (NSMutableArray *)buildSpecifiers
{
    NSMutableArray *specifiers = [[NSMutableArray alloc] init];
    _sectionRows = [[NSMutableArray alloc] init];

    [self addGroupNamed:[self string:@"Settings.DebugGroup"] footer:[self string:@"Settings.DebugFooter"] toSpecifiers:specifiers];
    [self addRow:[PSSpecifier preferenceSpecifierNamed:[self string:@"Settings.Onegram"] target:self set:@selector(setOnegramDiagnostics:specifier:) get:@selector(onegramDiagnostics:) detail:Nil cell:OGPreferencesSwitchCell edit:Nil] toSpecifiers:specifiers];
    [self addRow:[PSSpecifier preferenceSpecifierNamed:[self string:@"Settings.Helper"] target:self set:@selector(setHelperDiagnostics:specifier:) get:@selector(helperDiagnostics:) detail:Nil cell:OGPreferencesSwitchCell edit:Nil] toSpecifiers:specifiers];

    if (_entries == nil)
    {
        [self addGroupNamed:[self string:@"Settings.Logs"] footer:nil toSpecifiers:specifiers];
        [self addStaticText:[self string:@"Settings.Loading"] toSpecifiers:specifiers];
        [self startLoadingEntries];
        return specifiers;
    }

    if (_entries.count == 0)
    {
        [self addGroupNamed:[self string:@"Settings.Logs"] footer:[self string:@"Settings.LogsFooter"] toSpecifiers:specifiers];
        [self addStaticText:[self string:@"Settings.NoLogs"] toSpecifiers:specifiers];
        return specifiers;
    }

    NSArray *groups = [NSArray arrayWithObjects:
        [NSArray arrayWithObjects:[NSNumber numberWithInt:OGLogSourceOnegram], @"Settings.LogsOnegram", nil],
        [NSArray arrayWithObjects:[NSNumber numberWithInt:OGLogSourceHelper], @"Settings.LogsHelper", nil],
        [NSArray arrayWithObjects:[NSNumber numberWithInt:OGLogSourceSystem], @"Settings.LogsSystem", nil],
        nil];
    NSUInteger groupIndex = 0;
    for (NSArray *group in groups)
    {
        OGLogSource source = (OGLogSource)[[group objectAtIndex:0] intValue];
        bool added = false;
        for (OGLogEntry *entry in _entries)
        {
            if (entry.source != source)
                continue;
            if (!added)
            {
                bool lastGroup = groupIndex == groups.count - 1;
                [self addGroupNamed:[self string:[group objectAtIndex:1]] footer:lastGroup ? [self string:@"Settings.LogsFooter"] : nil toSpecifiers:specifiers];
                added = true;
            }
            PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:entry.name target:self set:NULL get:@selector(logEntryValue:) detail:Nil cell:OGPreferencesLinkCell edit:Nil];
            [row setProperty:entry forKey:OGHelperSettingsEntryKey];
            [self addRow:row toSpecifiers:specifiers];
        }
        groupIndex++;
    }
    return specifiers;
}

- (void)startLoadingEntries
{
    if (_loading)
        return;
    _loading = true;
    [self performSelectorInBackground:@selector(loadEntries) withObject:nil];
}

- (void)loadEntries
{
    @autoreleasepool
    {
        NSArray *entries = [OGLogCatalog entriesWithDocumentsPaths:[OGLogCatalog installedApplicationDocumentsPaths]];
        [self performSelectorOnMainThread:@selector(entriesLoaded:) withObject:entries waitUntilDone:false];
    }
}

- (void)entriesLoaded:(NSArray *)entries
{
    _loading = false;
    NSString *signature = [self signatureForEntries:entries];
    if (_entries != nil && [signature isEqualToString:_signature])
        return;
    _signature = signature;
    _entries = entries;
    _specifiers = [self buildSpecifiers];
    [self reloadSpecifiers];
}

- (OGLogEntry *)entryAtIndexPath:(NSIndexPath *)indexPath
{
    if ((NSUInteger)indexPath.section >= _sectionRows.count)
        return nil;
    NSArray *rows = [_sectionRows objectAtIndex:(NSUInteger)indexPath.section];
    if ((NSUInteger)indexPath.row >= rows.count)
        return nil;
    id entry = [[rows objectAtIndex:(NSUInteger)indexPath.row] propertyForKey:OGHelperSettingsEntryKey];
    return [entry isKindOfClass:[OGLogEntry class]] ? entry : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    if ([self entryAtIndexPath:indexPath] != nil)
    {
        cell.textLabel.textColor = [UIColor colorWithRed:0.22f green:0.33f blue:0.53f alpha:1.0f];
        cell.userInteractionEnabled = true;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self entryAtIndexPath:indexPath] != nil)
        return indexPath;
    if ([PSListController instancesRespondToSelector:@selector(tableView:willSelectRowAtIndexPath:)])
        return [super tableView:tableView willSelectRowAtIndexPath:indexPath];
    return indexPath;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self entryAtIndexPath:indexPath] != nil)
        return true;
    if ([PSListController instancesRespondToSelector:@selector(tableView:shouldHighlightRowAtIndexPath:)])
        return [super tableView:tableView shouldHighlightRowAtIndexPath:indexPath];
    return true;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    OGLogEntry *entry = [self entryAtIndexPath:indexPath];
    if (entry == nil)
    {
        [super tableView:tableView didSelectRowAtIndexPath:indexPath];
        return;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:true];
    [OGHelperLogPanel presentEntry:entry bundle:[self settingsBundle] fromController:self];
}

- (NSString *)logEntryValue:(PSSpecifier *)specifier
{
    OGLogEntry *entry = [specifier propertyForKey:OGHelperSettingsEntryKey];
    if (![entry isKindOfClass:[OGLogEntry class]])
        return nil;
    if (_timeFormatter == nil)
    {
        _timeFormatter = [[NSDateFormatter alloc] init];
        _timeFormatter.dateFormat = @"HH:mm";
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateFormat = @"dd.MM.yy";
    }
    NSDateFormatter *dayFormatter = [[NSDateFormatter alloc] init];
    dayFormatter.dateFormat = @"yyyyMMdd";
    bool today = entry.modificationDate != nil && [[dayFormatter stringFromDate:entry.modificationDate] isEqualToString:[dayFormatter stringFromDate:[NSDate date]]];
    NSString *date = entry.modificationDate == nil ? @"" : [(today ? _timeFormatter : _dateFormatter) stringFromDate:entry.modificationDate];
    NSString *size;
    if (entry.size >= 1024 * 1024)
        size = [NSString stringWithFormat:[self string:@"Size.Megabytes"], (double)entry.size / (1024.0 * 1024.0)];
    else if (entry.size >= 1024)
        size = [NSString stringWithFormat:[self string:@"Size.Kilobytes"], (double)entry.size / 1024.0];
    else
        size = [NSString stringWithFormat:[self string:@"Size.Bytes"], entry.size];
    return date.length == 0 ? size : [NSString stringWithFormat:@"%@ · %@", date, size];
}

- (bool)onegramBuildDefault
{
    if (_onegramBuildDefault != nil)
        return [_onegramBuildDefault boolValue];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray *candidates = [[NSMutableArray alloc] initWithObjects:@"/Applications/Onegram.app/Info.plist", @"/var/jb/Applications/Onegram.app/Info.plist", nil];
    for (NSString *root in [NSArray arrayWithObjects:@"/var/containers/Bundle/Application", @"/var/mobile/Applications", nil])
    {
        for (NSString *container in [fileManager contentsOfDirectoryAtPath:root error:NULL])
        {
            NSString *containerPath = [root stringByAppendingPathComponent:container];
            for (NSString *name in [fileManager contentsOfDirectoryAtPath:containerPath error:NULL])
            {
                if ([[name pathExtension] isEqualToString:@"app"])
                    [candidates addObject:[[containerPath stringByAppendingPathComponent:name] stringByAppendingPathComponent:@"Info.plist"]];
            }
        }
    }

    bool value = ONEGRAM_DIAGNOSTICS_DEFAULT;
    for (NSString *path in candidates)
    {
        NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:path];
        if (![[info objectForKey:@"CFBundleIdentifier"] isEqual:@OGHelperApplicationBundleIdentifier])
            continue;
        id diagnostics = [info objectForKey:@"OGOnegramBuildDiagnostics"];
        if ([diagnostics isKindOfClass:[NSNumber class]])
        {
            value = [diagnostics boolValue];
            break;
        }
    }
    _onegramBuildDefault = [NSNumber numberWithBool:value];
    return value;
}

- (NSNumber *)onegramDiagnostics:(PSSpecifier *)__unused specifier
{
    return [NSNumber numberWithBool:OGDiagnosticsResolve(OGDiagnosticsComponentOnegram, [self onegramBuildDefault])];
}

- (NSNumber *)helperDiagnostics:(PSSpecifier *)__unused specifier
{
    return [NSNumber numberWithBool:OGDiagnosticsResolve(OGDiagnosticsComponentHelper, ONEGRAM_DIAGNOSTICS_DEFAULT)];
}

- (void)storeDiagnostics:(id)value component:(OGDiagnosticsComponent)component specifier:(PSSpecifier *)specifier
{
    if (!OGDiagnosticsSetOverride(component, [value boolValue]) && [self respondsToSelector:@selector(reloadSpecifier:)])
        [self reloadSpecifier:specifier];
}

- (void)setOnegramDiagnostics:(id)value specifier:(PSSpecifier *)specifier
{
    [self storeDiagnostics:value component:OGDiagnosticsComponentOnegram specifier:specifier];
}

- (void)setHelperDiagnostics:(id)value specifier:(PSSpecifier *)specifier
{
    [self storeDiagnostics:value component:OGDiagnosticsComponentHelper specifier:specifier];
}

@end
