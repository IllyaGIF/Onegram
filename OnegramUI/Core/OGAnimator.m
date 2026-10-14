#import "OGAnimator.h"

@implementation OGAnimator
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(OGAnimationBlock)animations
{
    [self animateWithDuration:duration curve:UIViewAnimationCurveEaseInOut animations:animations];
}

+ (void)animateWithDuration:(NSTimeInterval)duration curve:(UIViewAnimationCurve)curve animations:(OGAnimationBlock)animations
{
    if (animations == nil)
        return;
    if (duration <= 0.0)
    {
        animations();
        return;
    }
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:duration];
    [UIView setAnimationCurve:curve];
    animations();
    [UIView commitAnimations];
}

+ (void)setFrame:(CGRect)frame forView:(UIView *)view duration:(NSTimeInterval)duration
{
    if (view == nil)
        return;
    [self animateWithDuration:duration animations:^{ view.frame = frame; }];
}

+ (void)setAlpha:(CGFloat)alpha forView:(UIView *)view duration:(NSTimeInterval)duration
{
    if (view == nil)
        return;
    [self animateWithDuration:duration animations:^{ view.alpha = alpha; }];
}

+ (void)setTransform:(CGAffineTransform)transform forView:(UIView *)view duration:(NSTimeInterval)duration
{
    if (view == nil)
        return;
    [self animateWithDuration:duration animations:^{ view.transform = transform; }];
}
@end
