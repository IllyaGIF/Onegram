#import "TGNotificationBackgroundView.h"

@interface TGNotificationBackgroundView ()
{
    UIView *_backgroundView;
}
@end

@implementation TGNotificationBackgroundView

- (UIView *)og_compat_fillingSubviewIn:(UIView *)container
{
    UIView *filler = [[UIView alloc] initWithFrame:CGRectZero];
    filler.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    filler.frame = self.bounds;
    [container addSubview:filler];
    return filler;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        CGFloat backgroundAlpha = 0.8f;
        
        #if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        if (iosMajorVersion() >= 8)
        {
            _blurEffectView = [self og_compat_fillingSubviewIn:self];
            _vibrantEffectView = [self og_compat_fillingSubviewIn:_blurEffectView];
            backgroundAlpha = 0.4f;
        }
        #endif

        _backgroundView = [[UIView alloc] initWithFrame:self.bounds];
        _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _backgroundView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:backgroundAlpha];
        [self addSubview:_backgroundView];
    }
    return self;
}

@end
