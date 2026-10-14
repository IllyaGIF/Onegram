#import <UIKit/UIKit.h>

typedef void (^OGAnimationBlock)(void);

@interface OGAnimator : NSObject
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(OGAnimationBlock)animations;
+ (void)animateWithDuration:(NSTimeInterval)duration curve:(UIViewAnimationCurve)curve animations:(OGAnimationBlock)animations;
+ (void)setFrame:(CGRect)frame forView:(UIView *)view duration:(NSTimeInterval)duration;
+ (void)setAlpha:(CGFloat)alpha forView:(UIView *)view duration:(NSTimeInterval)duration;
+ (void)setTransform:(CGAffineTransform)transform forView:(UIView *)view duration:(NSTimeInterval)duration;
@end
