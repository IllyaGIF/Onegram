#import "TGPaymentAlertView.h"

@interface TGPaymentAlertView () {
    UIView *_dimView;
    UIImageView *_backgroundView;
}

@end

@implementation TGPaymentAlertView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _dimView = [[UIView alloc] init];
        _dimView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
        [_dimView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dimViewTapped:)]];
        _dimView.alpha = 0.0f;
        [self addSubview:_dimView];
    }
    return self;
}

- (void)animateAppear {
    _dimView.alpha = 0.0f;
    _backgroundView.alpha = 0.0f;
    _backgroundView.transform = CGAffineTransformMakeScale(0.94f, 0.94f);
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^ {
        _dimView.alpha = 1.0f;
        _backgroundView.alpha = 1.0f;
        _backgroundView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)animateDismiss:(void (^)())completion {
    [UIView animateWithDuration:0.2 animations:^ {
        _dimView.alpha = 0.0f;
        _backgroundView.transform = CGAffineTransformMakeScale(0.9f, 0.9f);
        _backgroundView.alpha = 0.0f;
    } completion:^(__unused BOOL finished) {
        if (completion)
            completion();
    }];
}

- (void)dismissPressed {
    [self animateDismiss:^{
        if (_dismiss)
            _dismiss();
    }];
}

- (void)dimViewTapped:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self dismissPressed];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _dimView.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height);
    
    
}

@end
