#import "TGPluginsController.h"

#if OG_PLUGINS_AVAILABLE

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../OnegramPlugins/OGPluginHost.h"
#import "../OnegramPlugins/OGPluginManager.h"
#import "../OnegramPlugins/OGPythonRuntime.h"

#import "TGCustomAlertView.h"
#import "TGCustomActionSheet.h"
#import "TGActionSheet.h"
#import "TGPluginHost.h"
#import "TGAppDelegate.h"
#import "TGPresentation.h"
#import "TGSwitchCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

static NSString *TGPluginsString(NSString *key)
{
    return TGLocalized([@"OnegramPlugins." stringByAppendingString:key]);
}

static NSString *TGPluginsText(id value)
{
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSString *TGPluginsSnippet(NSString *text, NSUInteger limit)
{
    static NSRegularExpression *markup = nil;
    static NSRegularExpression *spaces = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        markup = [NSRegularExpression regularExpressionWithPattern:@"\\*\\*|__|~~|`" options:0 error:NULL];
        spaces = [NSRegularExpression regularExpressionWithPattern:@"\\s+" options:0 error:NULL];
    });
    NSString *plain = [markup stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];
    plain = [spaces stringByReplacingMatchesInString:plain options:0 range:NSMakeRange(0, plain.length) withTemplate:@" "];
    plain = [plain stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (plain.length <= limit)
        return plain;
    NSRange range = [plain rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, limit)];
    NSString *cut = [[plain substringToIndex:range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [cut stringByAppendingString:@"\u2026"];
}

static NSString *TGPluginsInlineList(NSArray *items)
{
    NSMutableArray *parts = [[NSMutableArray alloc] init];
    for (NSString *entry in items)
    {
        NSString *item = [entry componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]][0];
        if (item.length == 0)
            continue;
        NSRange first = [item rangeOfComposedCharacterSequenceAtIndex:0];
        [parts addObject:[[[item substringWithRange:first] lowercaseString] stringByAppendingString:[item substringFromIndex:NSMaxRange(first)]]];
    }
    return [parts componentsJoinedByString:@", "];
}

static NSArray *TGPluginsCapabilities(id values)
{
    if (![values isKindOfClass:[NSArray class]])
        return @[];
    NSDictionary *keys = @{ @"network": @"CapabilityNetwork", @"subprocess": @"CapabilitySubprocess",
                            @"request_hooks": @"CapabilityRequestHooks", @"android_method_hooks": @"CapabilityAndroidHooks",
                            @"send_messages": @"CapabilitySendMessages", @"read_updates": @"CapabilityReadUpdates",
                            @"api_requests": @"CapabilityAPIRequests" };
    NSMutableArray *lines = [[NSMutableArray alloc] init];
    for (id value in values)
    {
        NSString *key = keys[TGPluginsText(value)];
        if (key != nil)
            [lines addObject:TGPluginsString(key)];
    }
    return lines;
}

static NSArray *TGPluginsLimitations(id values)
{
    if (![values isKindOfClass:[NSArray class]])
        return @[];
    NSMutableArray *lines = [[NSMutableArray alloc] init];
    for (id value in values)
    {
        if (![value isKindOfClass:[NSDictionary class]])
            continue;
        NSString *code = TGPluginsText(value[@"code"]);
        NSArray *details = [value[@"details"] isKindOfClass:[NSArray class]] ? value[@"details"] : @[];
        if ([code isEqualToString:@"unbridged_android_hooks"])
        {
            NSMutableArray *examples = [[NSMutableArray alloc] init];
            for (NSUInteger index = 0; index < MIN((NSUInteger)3, details.count); index++)
                [examples addObject:TGPluginsText(details[index])];
            NSString *entry = [NSString stringWithFormat:TGPluginsString(@"LimitationUnbridged"), (unsigned long)details.count];
            if (examples.count != 0)
                entry = [entry stringByAppendingFormat:@"\n%@", [examples componentsJoinedByString:@"\n"]];
            [lines addObject:entry];
        }
        else if ([code isEqualToString:@"interpreted_dex"])
            [lines addObject:TGPluginsString(@"LimitationDEX")];
        else if ([code isEqualToString:@"external_requirements"])
            [lines addObject:[NSString stringWithFormat:TGPluginsString(@"LimitationRequirements"), [details componentsJoinedByString:@", "]]];
    }
    return lines;
}

static NSString *TGPluginsReviewChanges(NSDictionary *plugin)
{
    NSDictionary *changes = [plugin[@"capability_changes"] isKindOfClass:[NSDictionary class]] ? plugin[@"capability_changes"] : @{};
    NSArray *added = TGPluginsCapabilities(changes[@"added"]);
    NSArray *removed = TGPluginsCapabilities(changes[@"removed"]);
    NSMutableArray *lines = [[NSMutableArray alloc] initWithObjects:TGPluginsString(@"ReviewExplanation"), nil];
    if (added.count != 0)
        [lines addObject:[NSString stringWithFormat:@"%@: %@", TGPluginsString(@"ReviewAdded"), [added componentsJoinedByString:@", "]]];
    if (removed.count != 0)
        [lines addObject:[NSString stringWithFormat:@"%@: %@", TGPluginsString(@"ReviewRemoved"), [removed componentsJoinedByString:@", "]]];
    if (added.count == 0 && removed.count == 0)
        [lines addObject:TGPluginsString(@"ReviewSameCapabilities")];
    return [lines componentsJoinedByString:@"\n"];
}

static NSString *TGPluginsErrorSummary(NSError *error)
{
    NSArray *lines = [error.localizedDescription componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in [lines reverseObjectEnumerator])
    {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length != 0)
            return trimmed;
    }
    return TGPluginsString(@"Failed");
}

static void TGPluginsReportError(NSError *error)
{
    [TGCustomAlertView presentAlertWithTitle:nil message:TGPluginsErrorSummary(error) cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
}

static bool TGPluginsIsSettledActivation(NSNotification *notification)
{
    if (![notification.userInfo[OGPluginsEventNameKey] isEqualToString:@"activation"])
        return false;
    NSDictionary *payload = notification.userInfo[OGPluginsEventPayloadKey];
    if (![payload isKindOfClass:[NSDictionary class]] || [payload[@"busy"] boolValue])
        return false;
    return [[OGPluginManager sharedManager] isRuntimeReady];
}

static void TGPluginsScheduleInterfaceRebuild(void)
{
    static bool scheduled = false;
    if (scheduled)
        return;
    scheduled = true;
    dispatch_async(dispatch_get_main_queue(), ^
    {
        scheduled = false;
        [TGAppDelegateInstance rebuildInterfaceApplyingChange:nil];
    });
}

static void TGPluginsCall(NSString *function, NSArray *arguments, void (^completion)(id result))
{
    void (^finish)(id) = [completion copy];
    [[OGPluginManager sharedManager] callFunction:function arguments:arguments completion:^(id result, NSError *error)
    {
        if (error != nil)
        {
            TGPluginsReportError(error);
            return;
        }
        if (finish != nil)
            finish(result);
    }];
}

static NSString *TGPluginsInstallMessage(NSDictionary *info, bool analyzed)
{
    NSMutableArray *lines = [[NSMutableArray alloc] init];
    [lines addObject:TGPluginsSnippet(TGPluginsText(info[@"name"]), 60)];
    NSMutableArray *byline = [[NSMutableArray alloc] init];
    if (TGPluginsText(info[@"author"]).length != 0)
        [byline addObject:TGPluginsSnippet(TGPluginsText(info[@"author"]), 40)];
    NSString *version = TGPluginsText(info[@"version"]);
    NSString *installed = TGPluginsText(info[@"installed_version"]);
    if (installed.length != 0)
        [byline addObject:[NSString stringWithFormat:TGPluginsString(@"InstallUpdate"), installed, version]];
    else if (version.length != 0)
        [byline addObject:version];
    if (byline.count != 0)
        [lines addObject:[byline componentsJoinedByString:@" \u00b7 "]];
    NSString *description = TGPluginsSnippet(TGPluginsText(info[@"description"]), 140);
    if (description.length != 0)
        [lines addObject:description];
    if (analyzed)
    {
        NSArray *capabilities = TGPluginsCapabilities(info[@"capabilities"]);
        [lines addObject:[NSString stringWithFormat:@"%@: %@", TGPluginsString(@"Capabilities"),
                          capabilities.count != 0 ? TGPluginsInlineList(capabilities) : TGPluginsString(@"NoneDetected")]];
        NSArray *limitations = TGPluginsLimitations(info[@"limitations"]);
        if (limitations.count != 0)
            [lines addObject:[NSString stringWithFormat:@"%@: %@", TGPluginsString(@"Limitations"), TGPluginsInlineList(limitations)]];
    }
    else
        [lines addObject:[NSString stringWithFormat:@"%@: %@", TGPluginsString(@"Capabilities"), TGPluginsString(@"Analyzing")]];
    NSArray *problems = [info[@"problems"] isKindOfClass:[NSArray class]] ? info[@"problems"] : @[];
    if (problems.count != 0)
        [lines addObject:[NSString stringWithFormat:@"%@: %@", TGPluginsString(@"Problems"), [problems componentsJoinedByString:@"; "]]];
    return [lines componentsJoinedByString:@"\n"];
}

static bool TGPluginsInstallAllowed(NSDictionary *info)
{
    if (TGPluginsText(info[@"analysis_error"]).length != 0)
        return false;
    NSArray *platformErrors = [info[@"platform_errors"] isKindOfClass:[NSArray class]] ? info[@"platform_errors"] : @[];
    return platformErrors.count == 0;
}

@interface TGPluginInstallPrompt : NSObject
{
    NSString *_stagedPath;
    NSDictionary *_inspection;
    __weak TGCustomAlertView *_alertView;
    TGProgressWindow *_progressWindow;
    bool _previewFinished;
    bool _finished;
}

- (instancetype)initWithStagedPath:(NSString *)stagedPath;
- (void)start;

@end

@implementation TGPluginInstallPrompt

- (instancetype)initWithStagedPath:(NSString *)stagedPath
{
    self = [super init];
    if (self != nil)
        _stagedPath = stagedPath;
    return self;
}

- (void)start
{
    _progressWindow = [[TGProgressWindow alloc] init];
    [_progressWindow showWithDelay:0.25];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
    {
        if (self->_previewFinished)
            return;
        self->_previewFinished = true;
        [self->_progressWindow dismiss:true];
        self->_progressWindow = nil;
        [self discard];
        OGPythonRuntimeLogThreadStacks(@"plugin install prompt timed out");
        [TGCustomAlertView presentAlertWithTitle:nil message:TGPluginsString(@"EngineBusy") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    });
    [[OGPluginManager sharedManager] callFunction:@"preview" arguments:@[_stagedPath] completion:^(id result, NSError *error)
    {
        if (self->_previewFinished)
            return;
        self->_previewFinished = true;
        [self->_progressWindow dismiss:true];
        self->_progressWindow = nil;
        if (error != nil || ![result isKindOfClass:[NSDictionary class]])
        {
            [self discard];
            TGPluginsReportError(error ?: [NSError errorWithDomain:@"TGPlugins" code:1 userInfo:@{NSLocalizedDescriptionKey: TGPluginsString(@"Failed")}]);
            return;
        }
        [self presentWithPreview:result];
        [[OGPluginManager sharedManager] callFunction:@"inspect" arguments:@[self->_stagedPath] completion:^(id inspection, NSError *inspectionError)
        {
            [self inspectionFinished:[inspection isKindOfClass:[NSDictionary class]] ? inspection : nil error:inspectionError];
        }];
    }];
}

- (void)presentWithPreview:(NSDictionary *)preview
{
    _alertView = [TGCustomAlertView presentAlertWithTitle:TGPluginsString(@"InstallTitle") message:TGPluginsInstallMessage(preview, false) cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGPluginsString(@"Install") completionBlock:^(bool okButtonPressed)
    {
        [self alertFinished:okButtonPressed];
    }];
    [self setInstallEnabled:false];
}

- (void)setInstallEnabled:(bool)enabled
{
    UIButton *button = _alertView.doneButton;
    button.enabled = enabled;
    button.alpha = enabled ? 1.0f : 0.4f;
}

- (void)inspectionFinished:(NSDictionary *)inspection error:(NSError *)error
{
    if (_finished)
        return;
    if (inspection == nil)
    {
        if (error != nil)
            TGPluginsReportError(error);
        return;
    }
    _inspection = inspection;
    [_alertView setMessage:TGPluginsInstallMessage(inspection, true)];
    [self setInstallEnabled:TGPluginsInstallAllowed(inspection)];
}

- (void)alertFinished:(bool)install
{
    _finished = true;
    if (!install || _inspection == nil)
    {
        [self discard];
        return;
    }
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow show:true];
    [[OGPluginManager sharedManager] callFunction:@"install" arguments:@[_stagedPath, @true, TGPluginsText(_inspection[@"sha256"])] completion:^(__unused id installedPlugin, NSError *error)
    {
        [self discard];
        if (error != nil)
        {
            [progressWindow dismiss:true];
            TGPluginsReportError(error);
        }
        else
            [progressWindow dismissWithSuccess];
    }];
}

- (void)discard
{
    [[NSFileManager defaultManager] removeItemAtPath:_stagedPath error:NULL];
}

@end

@interface TGPluginLogsController : TGViewController
{
    UITextView *_textView;
    NSString *_text;
}

@end

@implementation TGPluginLogsController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [self setTitleText:TGPluginsString(@"Logs")];
        [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGPluginsString(@"ClearLogs") style:UIBarButtonItemStylePlain target:self action:@selector(clearPressed)]];
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    TGPresentationPallete *pallete = TGPresentation.current.pallete;
    self.view.backgroundColor = pallete.collectionMenuBackgroundColor;
    _textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _textView.editable = false;
    _textView.backgroundColor = pallete.collectionMenuCellBackgroundColor;
    _textView.textColor = pallete.collectionMenuTextColor;
    _textView.font = [UIFont fontWithName:@"Courier" size:11.0f] ?: TGSystemFontOfSize(11.0f);
    _textView.text = _text;
    [self.view addSubview:_textView];
    [self reload];
}

- (void)reload
{
    __weak TGPluginLogsController *weakSelf = self;
    TGPluginsCall(@"logs", @[], ^(id result)
    {
        __strong TGPluginLogsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_text = TGPluginsText(result);
        strongSelf->_textView.text = strongSelf->_text;
        if (strongSelf->_text.length != 0)
            [strongSelf->_textView scrollRangeToVisible:NSMakeRange(strongSelf->_text.length - 1, 1)];
    });
}

- (void)clearPressed
{
    __weak TGPluginLogsController *weakSelf = self;
    TGPluginsCall(@"clear_logs", @[], ^(__unused id result)
    {
        [weakSelf reload];
    });
}

@end

@interface TGPluginDetailsController : TGOnegramSettingsController <TGInterfaceRebuildRestorable>
{
    NSDictionary *_plugin;
    id _observer;
}

- (instancetype)initWithPlugin:(NSDictionary *)plugin;

@end

@implementation TGPluginDetailsController

- (instancetype)initWithPlugin:(NSDictionary *)plugin
{
    self = [super initWithTitle:TGPluginsText(plugin[@"name"])];
    if (self != nil)
    {
        _plugin = plugin;
        __weak TGPluginDetailsController *weakSelf = self;
        _observer = [[NSNotificationCenter defaultCenter] addObserverForName:OGPluginsEventNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
        {
            __strong TGPluginDetailsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            if (TGPluginsIsSettledActivation(notification) && strongSelf.navigationController.topViewController == strongSelf)
                TGPluginsScheduleInterfaceRebuild();
            [strongSelf refresh];
        }];
        [self refresh];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:_observer];
}

- (UIViewController *)controllerForInterfaceRebuild
{
    TGPluginDetailsController *controller = [[TGPluginDetailsController alloc] initWithPlugin:_plugin];
    controller.presentation = [TGPresentation current];
    return controller;
}

- (NSString *)identifier
{
    return TGPluginsText(_plugin[@"id"]);
}

- (void)refresh
{
    __weak TGPluginDetailsController *weakSelf = self;
    TGPluginsCall(@"plugin", @[[self identifier]], ^(id result)
    {
        __strong TGPluginDetailsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        if (![result isKindOfClass:[NSDictionary class]])
        {
            [strongSelf.navigationController popViewControllerAnimated:true];
            return;
        }
        strongSelf->_plugin = result;
        [strongSelf rebuild];
    });
}

- (TGOnegramActionCollectionItem *)infoWithTitle:(NSString *)title value:(NSString *)value
{
    TGOnegramActionCollectionItem *item = [self actionWithTitle:title variant:value pressed:nil];
    item.selectable = false;
    item.highlightable = false;
    item.hideArrow = true;
    return item;
}

- (NSArray *)buildSections
{
    NSMutableArray *sections = [[NSMutableArray alloc] init];
    NSMutableArray *details = [[NSMutableArray alloc] init];
    if (TGPluginsText(_plugin[@"author"]).length != 0)
        [details addObject:[self infoWithTitle:TGPluginsString(@"Author") value:TGPluginsText(_plugin[@"author"])]];
    if (TGPluginsText(_plugin[@"version"]).length != 0)
        [details addObject:[self infoWithTitle:TGPluginsString(@"Version") value:TGPluginsText(_plugin[@"version"])]];
    [details addObject:[self infoWithTitle:TGPluginsString(@"Identifier") value:[self identifier]]];
    [sections addObject:[self sectionWithHeader:nil items:details footer:TGPluginsText(_plugin[@"description"])]];

    NSArray *capabilities = TGPluginsCapabilities(_plugin[@"capabilities"]);
    NSMutableArray *capabilityItems = [[NSMutableArray alloc] init];
    for (NSString *capability in capabilities)
        [capabilityItems addObject:[self infoWithTitle:capability value:@""]];
    if (capabilityItems.count == 0)
        [capabilityItems addObject:[self infoWithTitle:TGPluginsString(@"NoneDetected") value:@""]];
    [sections addObject:[self sectionWithHeader:TGPluginsString(@"Capabilities") items:capabilityItems footer:TGPluginsString(@"StaticAnalysisNote")]];

    NSArray *limitations = TGPluginsLimitations(_plugin[@"limitations"]);
    NSMutableArray *limitationLines = [[NSMutableArray alloc] initWithArray:limitations];
    NSDictionary *runtimeHooks = [_plugin[@"unbridged_hooks"] isKindOfClass:[NSDictionary class]] ? _plugin[@"unbridged_hooks"] : @{};
    NSUInteger runtimeCount = [runtimeHooks[@"count"] unsignedIntegerValue];
    if (runtimeCount != 0)
    {
        NSString *summary = [NSString stringWithFormat:TGPluginsString(@"RuntimeUnbridged"), (unsigned long)runtimeCount];
        NSArray *examples = [runtimeHooks[@"examples"] isKindOfClass:[NSArray class]] ? runtimeHooks[@"examples"] : @[];
        if (examples.count != 0)
            summary = [summary stringByAppendingFormat:@"\n%@", [examples componentsJoinedByString:@"\n"]];
        [limitationLines addObject:summary];
    }
    NSDictionary *expensive = [_plugin[@"expensive_request_interceptors"] isKindOfClass:[NSDictionary class]] ? _plugin[@"expensive_request_interceptors"] : @{};
    NSUInteger expensiveCount = [expensive[@"count"] unsignedIntegerValue];
    if (expensiveCount != 0)
        [limitationLines addObject:[NSString stringWithFormat:@"Python request predicates: %lu\n%@", (unsigned long)expensiveCount, TGPluginsText(expensive[@"warning"])]];
    if (limitationLines.count != 0)
    {
        NSString *footer = [[limitationLines componentsJoinedByString:@"\n\n"] stringByAppendingFormat:@"\n\n%@", TGPluginsString(@"LimitationsWarning")];
        [sections addObject:[self sectionWithHeader:TGPluginsString(@"Limitations") items:@[] footer:footer]];
    }

    NSDictionary *suspended = [_plugin[@"suspended_hooks"] isKindOfClass:[NSDictionary class]] ? _plugin[@"suspended_hooks"] : @{};
    NSArray *suspendedDetails = [suspended[@"details"] isKindOfClass:[NSArray class]] ? suspended[@"details"] : @[];
    if (suspendedDetails.count != 0)
    {
        NSMutableArray *lines = [[NSMutableArray alloc] init];
        for (NSDictionary *hook in suspendedDetails)
        {
            if (![hook isKindOfClass:[NSDictionary class]])
                continue;
            [lines addObject:[NSString stringWithFormat:TGPluginsString(@"SuspendedHookDetail"), TGPluginsText(hook[@"target"]), [hook[@"median_ms"] doubleValue]]];
        }
        [sections addObject:[self sectionWithHeader:TGPluginsString(@"SuspendedHooks") items:@[] footer:[lines componentsJoinedByString:@"\n"]]];
    }

    __weak TGPluginDetailsController *weakSelf = self;
    NSString *identifier = [self identifier];
    bool reviewRequired = [TGPluginsText(_plugin[@"state"]) isEqualToString:@"review"] || [_plugin[@"review_required"] boolValue];
    TGSwitchCollectionItem *enabledItem = [self switchWithTitle:TGPluginsString(@"Enabled") value:[_plugin[@"enabled"] boolValue] toggled:^(bool value)
    {
        TGPluginsCall(@"set_enabled", @[identifier, @(value)], ^(id result)
        {
            __strong TGPluginDetailsController *strongSelf = weakSelf;
            if (strongSelf != nil && [result isKindOfClass:[NSDictionary class]])
            {
                strongSelf->_plugin = result;
                [strongSelf rebuild];
            }
        });
    }];
    NSMutableArray *controls = [[NSMutableArray alloc] initWithObjects:enabledItem, nil];
    [controls addObject:[self switchWithTitle:TGPluginsString(@"AllowSlowRender") value:[_plugin[@"allow_slow_render"] boolValue] toggled:^(bool value)
    {
        TGPluginsCall(@"set_allow_slow_render", @[identifier, @(value)], ^(id result)
        {
            __strong TGPluginDetailsController *strongSelf = weakSelf;
            if (strongSelf != nil && [result isKindOfClass:[NSDictionary class]])
            {
                strongSelf->_plugin = result;
                [strongSelf rebuild];
            }
        });
    }]];
    if ([_plugin[@"has_settings"] boolValue] && [TGPluginsText(_plugin[@"state"]) isEqualToString:@"loaded"])
    {
        [controls addObject:[self actionWithTitle:TGPluginsString(@"Settings") variant:nil pressed:^
        {
            TGPluginsCall(@"open_settings", @[identifier], nil);
        }]];
    }
    if (reviewRequired)
    {
        [controls addObject:[self actionWithTitle:TGPluginsString(@"Approve") variant:nil pressed:^
        {
            TGPluginsCall(@"approve", @[identifier], ^(id result)
            {
                __strong TGPluginDetailsController *strongSelf = weakSelf;
                if (strongSelf != nil && [result isKindOfClass:[NSDictionary class]])
                {
                    strongSelf->_plugin = result;
                    [strongSelf rebuild];
                }
            });
        }]];
    }
    else
    {
        [controls addObject:[self actionWithTitle:TGPluginsString(@"Reload") variant:nil pressed:^
        {
            TGPluginsCall(@"reload", @[identifier], ^(id result)
            {
                __strong TGPluginDetailsController *strongSelf = weakSelf;
                if (strongSelf != nil && [result isKindOfClass:[NSDictionary class]])
                {
                    strongSelf->_plugin = result;
                    [strongSelf rebuild];
                }
            });
        }]];
    }
    NSString *error = TGPluginsText(_plugin[@"error"]);
    NSString *footer = reviewRequired ? TGPluginsReviewChanges(_plugin) : (error.length != 0 ? [NSString stringWithFormat:@"%@\n%@", TGPluginsString(@"LoadError"), error] : nil);
    if (reviewRequired && TGPluginsText(_plugin[@"inspection_error"]).length != 0)
        footer = [footer stringByAppendingFormat:@"\n\n%@: %@", TGPluginsString(@"InspectionError"), TGPluginsText(_plugin[@"inspection_error"])];
    [sections addObject:[self sectionWithHeader:nil items:controls footer:footer]];

    TGOnegramActionCollectionItem *deleteItem = [self actionWithTitle:TGPluginsString(@"Delete") variant:nil pressed:^
    {
        __strong TGPluginDetailsController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf confirmDelete];
    }];
    deleteItem.titleColor = TGPresentation.current.pallete.collectionMenuDestructiveColor;
    [sections addObject:[self sectionWithHeader:nil items:@[deleteItem] footer:nil]];
    return sections;
}

- (void)confirmDelete
{
    NSString *identifier = [self identifier];
    NSString *message = [NSString stringWithFormat:TGPluginsString(@"DeleteConfirm"), TGPluginsText(_plugin[@"name"])];
    __weak TGPluginDetailsController *weakSelf = self;
    [TGCustomAlertView presentAlertWithTitle:nil message:message cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGPluginsString(@"Delete") completionBlock:^(bool okButtonPressed)
    {
        if (!okButtonPressed)
            return;
        TGPluginsCall(@"delete", @[identifier], ^(__unused id result)
        {
            [weakSelf.navigationController popViewControllerAnimated:true];
        });
    }];
}

@end

@interface TGPluginsController () <TGInterfaceRebuildRestorable>
{
    NSDictionary *_engine;
    NSArray *_plugins;
    id _observer;
    bool _loading;
}

@end

@implementation TGPluginsController

+ (void)openPluginWithIdentifier:(NSString *)identifier
{
    void (^open)(NSDictionary *) = ^(NSDictionary *plugin)
    {
        TGViewController *presenter = [TGPluginHost presentingController];
        UINavigationController *navigation = presenter.navigationController;
        if (navigation == nil)
            return;
        TGPresentation *presentation = [TGPresentation current];
        TGPluginsController *plugins = [[TGPluginsController alloc] init];
        plugins.presentation = presentation;
        [navigation pushViewController:plugins animated:plugin == nil];
        if (plugin != nil)
        {
            TGPluginDetailsController *details = [[TGPluginDetailsController alloc] initWithPlugin:plugin];
            details.presentation = presentation;
            [navigation pushViewController:details animated:true];
        }
    };
    if (identifier.length == 0)
        open(nil);
    else
        TGPluginsCall(@"plugin", @[identifier], ^(id result)
        {
            if ([result isKindOfClass:[NSDictionary class]])
                open(result);
        });
}

- (instancetype)init
{
    self = [super initWithTitle:TGPluginsString(@"Title")];
    if (self != nil)
    {
        _plugins = @[];
        __weak TGPluginsController *weakSelf = self;
        _observer = [[NSNotificationCenter defaultCenter] addObserverForName:OGPluginsEventNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
        {
            __strong TGPluginsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            if (TGPluginsIsSettledActivation(notification) && strongSelf.navigationController.topViewController == strongSelf)
                TGPluginsScheduleInterfaceRebuild();
            [strongSelf reload];
        }];
        [self reload];
    }
    return self;
}

- (UIViewController *)controllerForInterfaceRebuild
{
    TGPluginsController *controller = [[TGPluginsController alloc] init];
    controller.presentation = [TGPresentation current];
    return controller;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:_observer];
}

- (void)reload
{
    if (_loading)
        return;
    _loading = true;
    __weak TGPluginsController *weakSelf = self;
    TGPluginsCall(@"engine", @[], ^(id engine)
    {
        TGPluginsCall(@"list_plugins", @[], ^(id plugins)
        {
            __strong TGPluginsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            strongSelf->_loading = false;
            strongSelf->_engine = [engine isKindOfClass:[NSDictionary class]] ? engine : nil;
            strongSelf->_plugins = [plugins isKindOfClass:[NSArray class]] ? plugins : @[];
            [strongSelf rebuild];
        });
    });
}

- (NSString *)stateForPlugin:(NSDictionary *)plugin
{
    if ([TGPluginsText(plugin[@"state"]) isEqualToString:@"review"] || [plugin[@"review_required"] boolValue])
        return TGPluginsString(@"StateReview");
    if (TGPluginsText(plugin[@"error"]).length != 0)
        return TGPluginsString(@"StateError");
    if (![plugin[@"enabled"] boolValue])
        return TGPluginsString(@"StateOff");
    if ([TGPluginsText(plugin[@"state"]) isEqualToString:@"loading"])
        return TGPluginsString(@"StateLoading");
    return TGPluginsText(plugin[@"version"]);
}

- (NSArray *)buildSections
{
    NSMutableArray *sections = [[NSMutableArray alloc] init];
    __weak TGPluginsController *weakSelf = self;
    void (^applyEngine)(id) = ^(id result)
    {
        __strong TGPluginsController *strongSelf = weakSelf;
        if (strongSelf != nil && [result isKindOfClass:[NSDictionary class]])
        {
            strongSelf->_engine = result;
            [strongSelf reload];
        }
    };
    TGSwitchCollectionItem *engineItem = [self switchWithTitle:TGPluginsString(@"Engine") value:[_engine[@"enabled"] boolValue] toggled:^(bool value)
    {
        TGPluginsCall(@"set_engine_enabled", @[@(value)], applyEngine);
    }];
    TGSwitchCollectionItem *developerItem = [self switchWithTitle:TGPluginsString(@"DeveloperMode") value:[_engine[@"developer_mode"] boolValue] toggled:^(bool value)
    {
        TGPluginsCall(@"set_developer_mode", @[@(value)], applyEngine);
    }];
    NSString *versions = _engine != nil ? [NSString stringWithFormat:TGPluginsString(@"EngineFooter"), TGPluginsText(_engine[@"sdk_version"]), TGPluginsText(_engine[@"app_version"])] : nil;
    [sections addObject:[self sectionWithHeader:nil items:@[engineItem, developerItem] footer:versions]];

    NSMutableArray *onegramItems = [[NSMutableArray alloc] init];
    NSMutableArray *exteraGramItems = [[NSMutableArray alloc] init];
    for (NSDictionary *plugin in _plugins)
    {
        if (![plugin isKindOfClass:[NSDictionary class]])
            continue;
        NSDictionary *captured = plugin;
        NSMutableArray *items = [TGPluginsText(plugin[@"platform"]) isEqualToString:@"onegram"] ? onegramItems : exteraGramItems;
        [items addObject:[self actionWithTitle:TGPluginsText(plugin[@"name"]) variant:[self stateForPlugin:plugin] pressed:^
        {
            __strong TGPluginsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            TGPluginDetailsController *controller = [[TGPluginDetailsController alloc] initWithPlugin:captured];
            controller.presentation = strongSelf.presentation;
            [strongSelf.navigationController pushViewController:controller animated:true];
        }]];
    }
    if (onegramItems.count != 0)
        [sections addObject:[self sectionWithHeader:TGPluginsString(@"OnegramSection") items:onegramItems footer:exteraGramItems.count == 0 ? TGPluginsString(@"InstallHint") : nil]];
    if (exteraGramItems.count != 0)
        [sections addObject:[self sectionWithHeader:TGPluginsString(@"ExteraGramSection") items:exteraGramItems footer:TGPluginsString(@"InstallHint")]];
    if (onegramItems.count == 0 && exteraGramItems.count == 0)
        [sections addObject:[self sectionWithHeader:TGPluginsString(@"Installed") items:@[] footer:TGPluginsString(@"Empty")]];

    TGOnegramActionCollectionItem *logsItem = [self actionWithTitle:TGPluginsString(@"Logs") variant:nil pressed:^
    {
        __strong TGPluginsController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf.navigationController pushViewController:[[TGPluginLogsController alloc] init] animated:true];
    }];
    [sections addObject:[self sectionWithHeader:nil items:@[logsItem] footer:nil]];
    return sections;
}

+ (bool)isPluginArchivePath:(NSString *)path fileName:(NSString *)fileName
{
    NSString *name = [(fileName.length != 0 ? fileName : [path lastPathComponent]) lowercaseString];
    for (NSString *suffix in @[@".plugin", @".elyx", @".eaf", @".elyx.zip", @".eaf.zip"])
    {
        if ([name hasSuffix:suffix])
            return true;
    }
    return false;
}

+ (void)presentMenuItems:(NSArray *)items ofType:(NSString *)menuType context:(NSDictionary *)context fromController:(UIViewController *)controller
{
    if (items.count == 0 || controller == nil)
        return;
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    for (NSUInteger index = 0; index < items.count; index++)
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGPluginsText(items[index][@"text"]) action:[[NSString alloc] initWithFormat:@"%lu", (unsigned long)index]]];
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];
    TGCustomActionSheet *actionSheet = [[TGCustomActionSheet alloc] initWithTitle:nil actions:actions actionBlock:^(__unused id target, NSString *action)
    {
        if ([action isEqualToString:@"cancel"])
            return;
        NSUInteger index = (NSUInteger)[action integerValue];
        if (index < items.count)
            [TGPluginHost performMenuItem:items[index] ofType:menuType context:context];
    } target:controller];
    [actionSheet showInView:controller.view];
}

+ (void)presentInstallPromptForPath:(NSString *)path fileName:(NSString *)fileName
{
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"plugin-install"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:true attributes:nil error:NULL];
    NSString *name = fileName.length != 0 ? fileName : [path lastPathComponent];
    NSString *staged = [directory stringByAppendingPathComponent:[name stringByReplacingOccurrencesOfString:@"/" withString:@"_"]];
    [[NSFileManager defaultManager] removeItemAtPath:staged error:NULL];
    NSError *copyError = nil;
    if (![[NSFileManager defaultManager] copyItemAtPath:path toPath:staged error:&copyError])
    {
        TGPluginsReportError(copyError);
        return;
    }
    [[[TGPluginInstallPrompt alloc] initWithStagedPath:staged] start];
}

@end

#endif
