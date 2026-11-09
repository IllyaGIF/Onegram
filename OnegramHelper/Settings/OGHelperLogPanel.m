#import "OGHelperLogPanel.h"

#import "../../OnegramRuntime/OGLogCatalog.h"
#import "OGHelperSettingsStrings.h"
#import "OGHelperTimerTarget.h"

#include <sys/stat.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 30200
typedef enum {
    UIGestureRecognizerStatePossible,
    UIGestureRecognizerStateBegan,
    UIGestureRecognizerStateChanged,
    UIGestureRecognizerStateEnded,
    UIGestureRecognizerStateCancelled,
    UIGestureRecognizerStateFailed
} UIGestureRecognizerState;

@interface UIView (OGHelperGestureRecognizers)
- (void)addGestureRecognizer:(id)gestureRecognizer;
@end

@interface UIPinchGestureRecognizer : NSObject
- (id)initWithTarget:(id)target action:(SEL)action;
- (UIGestureRecognizerState)state;
- (CGFloat)scale;
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 50000
@interface UIViewController (OGHelperModalPresentation)
- (void)presentViewController:(UIViewController *)viewController animated:(BOOL)animated completion:(id)completion;
- (void)dismissViewControllerAnimated:(BOOL)animated completion:(id)completion;
@end
#endif

static NSString *const OGHelperLogPanelPreferencesDomain = @"dev.IllyaGIF.Onegram.helper";
static NSString *const OGHelperLogPanelFontSizeKey = @"LogFontSize";
static const CGFloat OGHelperLogPanelDefaultFontSize = 11.0f;
static const CGFloat OGHelperLogPanelMinimumFontSize = 6.0f;
static const CGFloat OGHelperLogPanelMaximumFontSize = 32.0f;
static const NSUInteger OGHelperLogPanelDisplayLimit = 32 * 1024;
static const CGFloat OGHelperLogPanelBarHeight = 44.0f;
static const NSTimeInterval OGHelperLogPanelRefreshInterval = 1.0;
static const CGFloat OGHelperLogPanelFollowThreshold = 40.0f;

static bool OGHelperLogPanelFileState(NSString *path, unsigned long long *size, time_t *modification)
{
    struct stat info;
    if (stat(path.fileSystemRepresentation, &info) != 0)
        return false;
    *size = (unsigned long long)info.st_size;
    *modification = info.st_mtime;
    return true;
}

static CGFloat OGHelperLogPanelStoredFontSize(void)
{
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)OGHelperLogPanelFontSizeKey, (__bridge CFStringRef)OGHelperLogPanelPreferencesDomain);
    CGFloat size = OGHelperLogPanelDefaultFontSize;
    if (value != NULL)
    {
        if (CFGetTypeID(value) == CFNumberGetTypeID())
        {
            double stored = 0.0;
            if (CFNumberGetValue((CFNumberRef)value, kCFNumberDoubleType, &stored))
                size = (CGFloat)stored;
        }
        CFRelease(value);
    }
    return MAX(OGHelperLogPanelMinimumFontSize, MIN(OGHelperLogPanelMaximumFontSize, size));
}

static void OGHelperLogPanelStoreFontSize(CGFloat size)
{
    double stored = (double)size;
    CFNumberRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &stored);
    CFPreferencesSetAppValue((__bridge CFStringRef)OGHelperLogPanelFontSizeKey, value, (__bridge CFStringRef)OGHelperLogPanelPreferencesDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)OGHelperLogPanelPreferencesDomain);
    CFRelease(value);
}

static NSString *OGHelperLogPanelByteCount(unsigned long long bytes, NSBundle *bundle)
{
    if (bytes >= 1024 * 1024)
        return [NSString stringWithFormat:OGHelperSettingsString(bundle, @"Size.Megabytes"), (double)bytes / (1024.0 * 1024.0)];
    if (bytes >= 1024)
        return [NSString stringWithFormat:OGHelperSettingsString(bundle, @"Size.Kilobytes"), (double)bytes / 1024.0];
    return [NSString stringWithFormat:OGHelperSettingsString(bundle, @"Size.Bytes"), bytes];
}

@interface OGHelperLogPanelController : UIViewController
{
    OGHelperLogPanel *_panel;
}

- (instancetype)initWithPanel:(OGHelperLogPanel *)panel;

@end

@interface OGHelperLogPanel () <OGHelperTimerReceiver>
{
    OGLogEntry *_entry;
    NSBundle *_bundle;
    UINavigationBar *_navigationBar;
    UINavigationItem *_navigationItem;
    UIBarButtonItem *_copyItem;
    UITextView *_textView;
    UIToolbar *_toolbar;
    UILabel *_fontSizeLabel;
    CGFloat _fontSize;
    CGFloat _pinchInitialFontSize;
    bool _copying;
    bool _reloading;
    bool _displayed;
    bool _displayedFileExists;
    bool _pendingFollow;
    unsigned long long _displayedSize;
    time_t _displayedModification;
    NSTimer *_refreshTimer;
    UIViewController *_presentingController;
}

@end

@implementation OGHelperLogPanel

- (instancetype)initWithEntry:(OGLogEntry *)entry bundle:(NSBundle *)bundle
{
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self != nil)
    {
        _entry = entry;
        _bundle = bundle;
        _fontSize = OGHelperLogPanelStoredFontSize();
        self.backgroundColor = [UIColor whiteColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        _textView = [[UITextView alloc] initWithFrame:CGRectZero];
        _textView.editable = false;
        _textView.dataDetectorTypes = UIDataDetectorTypeNone;
        _textView.textColor = [UIColor blackColor];
        _textView.backgroundColor = [UIColor whiteColor];
        _textView.text = OGHelperSettingsString(bundle, @"Viewer.Loading");
        [self addSubview:_textView];
        [self applyFontSize];

        _navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
        _navigationItem = [[UINavigationItem alloc] initWithTitle:entry.name];
        _navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:OGHelperSettingsString(bundle, @"Viewer.Done") style:UIBarButtonItemStyleDone target:self action:@selector(donePressed)];
        _copyItem = [[UIBarButtonItem alloc] initWithTitle:OGHelperSettingsString(bundle, @"Viewer.Copy") style:UIBarButtonItemStyleBordered target:self action:@selector(copyPressed)];
        _copyItem.enabled = false;
        _navigationItem.rightBarButtonItem = _copyItem;
        [_navigationBar pushNavigationItem:_navigationItem animated:false];
        [self addSubview:_navigationBar];

        _fontSizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 140.0f, 30.0f)];
        _fontSizeLabel.backgroundColor = [UIColor clearColor];
        #if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
        _fontSizeLabel.textAlignment = NSTextAlignmentCenter;
#else
        _fontSizeLabel.textAlignment = UITextAlignmentCenter;
#endif
        _fontSizeLabel.font = [UIFont systemFontOfSize:13.0f];
        _fontSizeLabel.adjustsFontSizeToFitWidth = true;
        [self updateFontSizeLabel];

        _toolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
        UIBarButtonItem *smaller = [[UIBarButtonItem alloc] initWithTitle:OGHelperSettingsString(bundle, @"Viewer.Smaller") style:UIBarButtonItemStyleBordered target:self action:@selector(smallerPressed)];
        UIBarButtonItem *larger = [[UIBarButtonItem alloc] initWithTitle:OGHelperSettingsString(bundle, @"Viewer.Larger") style:UIBarButtonItemStyleBordered target:self action:@selector(largerPressed)];
        UIBarButtonItem *flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
        UIBarButtonItem *flexibleTrailing = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
        UIBarButtonItem *label = [[UIBarButtonItem alloc] initWithCustomView:_fontSizeLabel];
        _toolbar.items = [NSArray arrayWithObjects:smaller, flexible, label, flexibleTrailing, larger, nil];
        [self addSubview:_toolbar];

        Class pinchClass = NSClassFromString(@"UIPinchGestureRecognizer");
        if (pinchClass != Nil && [_textView respondsToSelector:@selector(addGestureRecognizer:)])
            [_textView addGestureRecognizer:[[pinchClass alloc] initWithTarget:self action:@selector(pinchRecognized:)]];

        [self reloadDisplayText];
        _refreshTimer = [OGHelperTimerTarget scheduledTimerWithInterval:OGHelperLogPanelRefreshInterval target:self];
    }
    return self;
}

- (void)dealloc
{
    [_refreshTimer invalidate];
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    if (newWindow == nil && self.window != nil)
    {
        [_refreshTimer invalidate];
        _refreshTimer = nil;
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window != nil && _pendingFollow)
        [self performSelector:@selector(followEndIfNeeded) withObject:nil afterDelay:0];
}

- (void)reloadDisplayText
{
    if (_reloading)
        return;
    _reloading = true;
    [self performSelectorInBackground:@selector(loadDisplayText) withObject:nil];
}

- (void)refreshTimerFired:(NSTimer *)__unused timer
{
    if (!_displayed || _reloading)
        return;
    unsigned long long size = 0;
    time_t modification = 0;
    bool exists = OGHelperLogPanelFileState(_entry.path, &size, &modification);
    if (exists == _displayedFileExists && (!exists || (size == _displayedSize && modification == _displayedModification)))
        return;
    [self reloadDisplayText];
}

+ (void)presentEntry:(OGLogEntry *)entry bundle:(NSBundle *)bundle fromController:(PSViewController *)controller
{
    OGHelperLogPanel *panel = [[OGHelperLogPanel alloc] initWithEntry:entry bundle:bundle];
    UIViewController *presenter = nil;
    id candidate = controller;
    if (![candidate isKindOfClass:[UIViewController class]])
        candidate = [controller rootController];
    if ([candidate isKindOfClass:[UIViewController class]])
        presenter = candidate;

    if (presenter != nil)
    {
        OGHelperLogPanelController *panelController = [[OGHelperLogPanelController alloc] initWithPanel:panel];
        panel->_presentingController = panelController;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 30200
        if ([panelController respondsToSelector:@selector(setModalPresentationStyle:)])
            panelController.modalPresentationStyle = UIModalPresentationFullScreen;
#endif
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 50000
        if (![presenter respondsToSelector:@selector(presentViewController:animated:completion:)])
        {
            [presenter presentModalViewController:panelController animated:true];
            return;
        }
#endif
        [presenter presentViewController:panelController animated:true completion:nil];
        return;
    }

    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (window == nil)
        return;
    CGRect bounds = window.bounds;
    panel.frame = CGRectOffset(bounds, 0.0f, bounds.size.height);
    [window addSubview:panel];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    panel.frame = bounds;
    [UIView commitAnimations];
}

- (UIEdgeInsets)chromeInsets
{
    UIEdgeInsets insets = UIEdgeInsetsZero;
    UIWindow *window = self.window;
    UIApplication *application = [UIApplication sharedApplication];
    if (window != nil && !application.statusBarHidden)
    {
        CGRect statusBar = [window convertRect:application.statusBarFrame fromWindow:nil];
        CGRect frame = [self convertRect:self.bounds toView:window];
        if (CGRectIntersectsRect(statusBar, frame))
        {
            CGRect overlap = [self convertRect:CGRectIntersection(statusBar, frame) fromView:window];
            insets.top = MAX(0.0f, CGRectGetMaxY(overlap));
        }
    }
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if ([self respondsToSelector:@selector(safeAreaInsets)])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
        UIEdgeInsets safeArea = self.safeAreaInsets;
#pragma clang diagnostic pop
        insets.top = MAX(insets.top, safeArea.top);
        insets.bottom = MAX(insets.bottom, safeArea.bottom);
        insets.left = safeArea.left;
        insets.right = safeArea.right;
    }
#endif
    return insets;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    UIEdgeInsets insets = [self chromeInsets];
    CGFloat navigationHeight = OGHelperLogPanelBarHeight;
    CGFloat toolbarHeight = OGHelperLogPanelBarHeight;

    _navigationBar.frame = CGRectMake(0.0f, insets.top, bounds.size.width, navigationHeight);
    _toolbar.frame = CGRectMake(0.0f, bounds.size.height - insets.bottom - toolbarHeight, bounds.size.width, toolbarHeight + insets.bottom);
    CGFloat textTop = CGRectGetMaxY(_navigationBar.frame);
    _textView.frame = CGRectMake(insets.left, textTop, bounds.size.width - insets.left - insets.right, MAX(0.0f, _toolbar.frame.origin.y - textTop));
    if (_pendingFollow && self.window != nil && _textView.bounds.size.width > 0.0f && _textView.bounds.size.height > 0.0f)
        [self performSelector:@selector(followEndIfNeeded) withObject:nil afterDelay:0];
}

- (void)loadDisplayText
{
    @autoreleasepool
    {
        unsigned long long size = 0;
        time_t modification = 0;
        bool exists = OGHelperLogPanelFileState(_entry.path, &size, &modification);
        bool truncated = false;
        NSString *text = [OGLogCatalog textAtPath:_entry.path maximumLength:OGHelperLogPanelDisplayLimit truncated:&truncated];
        NSString *display = text;
        if (text == nil)
            display = OGHelperSettingsString(_bundle, @"Viewer.Unreadable");
        else if (truncated)
            display = [[NSString stringWithFormat:OGHelperSettingsString(_bundle, @"Viewer.Truncated"), OGHelperLogPanelByteCount(OGHelperLogPanelDisplayLimit, _bundle), OGHelperLogPanelByteCount(size, _bundle)] stringByAppendingFormat:@"\n\n%@", text];
        NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:display, @"text", [NSNumber numberWithBool:text != nil], @"readable", [NSNumber numberWithBool:exists], @"exists", [NSNumber numberWithUnsignedLongLong:size], @"size", [NSNumber numberWithDouble:(double)modification], @"modification", nil];
        [self performSelectorOnMainThread:@selector(displayTextLoaded:) withObject:result waitUntilDone:false];
    }
}

- (bool)textViewFollowsEnd
{
    CGFloat visibleBottom = _textView.contentOffset.y + _textView.bounds.size.height;
    return visibleBottom >= _textView.contentSize.height - OGHelperLogPanelFollowThreshold;
}

- (void)followEndIfNeeded
{
    if (!_pendingFollow || self.window == nil || _textView.bounds.size.width <= 0.0f || _textView.bounds.size.height <= 0.0f)
        return;
    _pendingFollow = false;
    [_textView setNeedsLayout];
    [_textView layoutIfNeeded];
    if (_textView.text.length != 0)
        [_textView scrollRangeToVisible:NSMakeRange(_textView.text.length - 1, 1)];
    [_textView setNeedsDisplay];
}

- (void)displayTextLoaded:(NSDictionary *)result
{
    bool follow = !_displayed || [self textViewFollowsEnd];
    CGPoint offset = _textView.contentOffset;
    NSString *text = [result objectForKey:@"text"];
    _reloading = false;
    _displayed = true;
    _displayedFileExists = [[result objectForKey:@"exists"] boolValue];
    _displayedSize = [[result objectForKey:@"size"] unsignedLongLongValue];
    _displayedModification = (time_t)[[result objectForKey:@"modification"] doubleValue];
    _textView.text = text;
    if (!_copying)
        _copyItem.enabled = [[result objectForKey:@"readable"] boolValue];
    [_textView setNeedsLayout];
    [_textView setNeedsDisplay];
    if (follow && text.length != 0)
    {
        _pendingFollow = true;
        if (self.window != nil)
            [self performSelector:@selector(followEndIfNeeded) withObject:nil afterDelay:0];
    }
    else
    {
        _pendingFollow = false;
        [_textView setContentOffset:offset animated:false];
    }
}

- (void)applyFontSize
{
    _textView.font = [UIFont fontWithName:@"Menlo-Regular" size:_fontSize] ?: [UIFont fontWithName:@"Courier" size:_fontSize] ?: [UIFont systemFontOfSize:_fontSize];
}

- (void)updateFontSizeLabel
{
    _fontSizeLabel.text = [NSString stringWithFormat:OGHelperSettingsString(_bundle, @"Viewer.FontSize"), (int)_fontSize];
}

- (void)setFontSize:(CGFloat)fontSize persist:(bool)persist
{
    CGFloat clamped = (CGFloat)floor(MAX(OGHelperLogPanelMinimumFontSize, MIN(OGHelperLogPanelMaximumFontSize, fontSize)) + 0.5);
    if (clamped != _fontSize)
    {
        _fontSize = clamped;
        [self applyFontSize];
        [self updateFontSizeLabel];
    }
    if (persist)
        OGHelperLogPanelStoreFontSize(_fontSize);
}

- (void)smallerPressed
{
    [self setFontSize:_fontSize - 1.0f persist:true];
}

- (void)largerPressed
{
    [self setFontSize:_fontSize + 1.0f persist:true];
}

- (void)pinchRecognized:(UIPinchGestureRecognizer *)recognizer
{
    UIGestureRecognizerState state = recognizer.state;
    if (state == UIGestureRecognizerStateBegan)
        _pinchInitialFontSize = _fontSize;
    else if (state == UIGestureRecognizerStateChanged)
        [self setFontSize:_pinchInitialFontSize * recognizer.scale persist:false];
    else if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled)
        [self setFontSize:_fontSize persist:true];
}

- (void)copyPressed
{
    if (_copying)
        return;
    _copying = true;
    _copyItem.enabled = false;
    [self performSelectorInBackground:@selector(loadFullText) withObject:nil];
}

- (void)loadFullText
{
    @autoreleasepool
    {
        NSString *text = [OGLogCatalog fullTextAtPath:_entry.path];
        [self performSelectorOnMainThread:@selector(fullTextLoaded:) withObject:text waitUntilDone:false];
    }
}

- (void)fullTextLoaded:(NSString *)text
{
    _copying = false;
    _copyItem.enabled = true;
    if (text == nil)
    {
        _copyItem.title = OGHelperSettingsString(_bundle, @"Viewer.CopyFailed");
        return;
    }
    [UIPasteboard generalPasteboard].string = text;
    _copyItem.title = OGHelperSettingsString(_bundle, @"Viewer.Copied");
}

- (void)donePressed
{
    UIViewController *presentingController = _presentingController;
    _presentingController = nil;
    if (presentingController != nil)
    {
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 50000
        if (![presentingController respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
        {
            [presentingController dismissModalViewControllerAnimated:true];
            return;
        }
#endif
        [presentingController dismissViewControllerAnimated:true completion:nil];
        return;
    }
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(dismissAnimationDidStop)];
    self.frame = CGRectOffset(self.frame, 0.0f, self.bounds.size.height);
    [UIView commitAnimations];
}

- (void)dismissAnimationDidStop
{
    [self removeFromSuperview];
}

@end

@implementation OGHelperLogPanelController

- (instancetype)initWithPanel:(OGHelperLogPanel *)panel
{
    self = [super initWithNibName:nil bundle:nil];
    if (self != nil)
        _panel = panel;
    return self;
}

- (void)loadView
{
    self.view = _panel;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)__unused interfaceOrientation
{
    return true;
}

@end
