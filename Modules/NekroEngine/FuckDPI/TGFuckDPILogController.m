#import "TGFuckDPILogController.h"
#import "TGFuckDPILog.h"

@interface TGFuckDPILogController ()
{
    UITextView *_textView;
    NSTimer *_refreshTimer;
    UIBarButtonItem *_copyItem;
}
@end

@implementation TGFuckDPILogController

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
    self = [super init];
    if (self != nil)
    {
        self.title = @"Логи FuckDPI";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor blackColor];

    _textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _textView.backgroundColor = [UIColor colorWithRed:0.05f green:0.05f blue:0.05f alpha:1.0f];
    _textView.textColor = [UIColor colorWithRed:0.2f green:1.0f blue:0.3f alpha:1.0f];
    _textView.font = [UIFont fontWithName:@"Courier" size:12.0f] ?: [UIFont systemFontOfSize:12.0f];
    _textView.editable = NO;
    [self.view addSubview:_textView];

    UIBarButtonItem *clearItem = [[UIBarButtonItem alloc] initWithTitle:@"Очистить"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(clearPressed)];
    _copyItem = [[UIBarButtonItem alloc] initWithTitle:@"Копировать"
                                                 style:UIBarButtonItemStylePlain
                                                target:self
                                                action:@selector(copyPressed)];
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:clearItem, _copyItem, nil];
}

- (void)copyPressed
{
    NSArray *logs = FDPIGetLogs();
    NSString *combined = [logs componentsJoinedByString:@"\n"];
    if (combined.length == 0)
    {
        [self flashButtonTitle:@"Лог пуст"];
        return;
    }

    static const NSUInteger maximumLength = 3900;
    BOOL trimmed = combined.length > maximumLength;
    NSString *payload = trimmed ? [combined substringFromIndex:combined.length - maximumLength] : combined;

    [[UIPasteboard generalPasteboard] setString:payload];
    [self flashButtonTitle:trimmed ? @"Скопирован конец" : @"Скопировано"];
}

- (void)flashButtonTitle:(NSString *)title
{
    _copyItem.enabled = NO;
    _copyItem.title = title;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(restoreButtonTitle) object:nil];
    [self performSelector:@selector(restoreButtonTitle) withObject:nil afterDelay:1.5];
}

- (void)restoreButtonTitle
{
    _copyItem.title = @"Копировать";
    _copyItem.enabled = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadLogs];

    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                     target:self
                                                   selector:@selector(reloadLogs)
                                                   userInfo:nil
                                                    repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_refreshTimer invalidate];
    _refreshTimer = nil;
}

- (void)clearPressed
{
    FDPIClearLogs();
    _textView.text = @"[Логи очищены]\n";
}

- (void)reloadLogs
{
    NSArray *logs = FDPIGetLogs();
    if (logs.count == 0)
    {
        _textView.text = @"[Логи отсутствуют. Включите тумблер 'Взлом РКН' или 'Логирование']\n";
        return;
    }

    NSString *combined = [logs componentsJoinedByString:@"\n"];
    if (![_textView.text isEqualToString:combined])
    {
        _textView.text = combined;
        if (combined.length > 0)
        {
            NSRange range = NSMakeRange(combined.length - 1, 1);
            [_textView scrollRangeToVisible:range];
        }
    }
}

@end
