#import "TGSafariViewController.h"
#import "TGApplication.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
static void OGCompatOpenExternally(NSURL *url)
{
    UIApplication *app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(nativeOpenURL:)])
        [(TGApplication *)app nativeOpenURL:url];
    else
        [app openURL:url];
}

@implementation SFSafariViewController

- (instancetype)initWithURL:(NSURL *)URL entersReaderIfAvailable:(BOOL)__unused entersReaderIfAvailable
{
    if ((self = [super init]))
        OGCompatOpenExternally(URL);
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL
{
    return [self initWithURL:URL entersReaderIfAvailable:false];
}

- (NSArray *)previewActionItems
{
    return @[];
}

@end
#endif


@implementation TGSafariViewController

- (NSArray *)previewActionItems {
    if (self.externalPreviewActionItems != nil)
        return self.externalPreviewActionItems();
    
    return [super previewActionItems];
}

@end
