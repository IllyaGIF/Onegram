#import "TGSpringAnimation.h"

@implementation TGSpringAnimation

+ (CAKeyframeAnimation *)animationWithKeypath:(NSString *)__unused keypath duration:(CFTimeInterval)duration usingSpringWithDamping:(CGFloat)usingSpringWithDamping initialSpringVelocity:(CGFloat)initialSpringVelocity fromPosition:(CGPoint)fromPosition toPosition:(CGPoint)toPosition
{
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    animation.values = [self animationValuesFromPosition:fromPosition toPosition:toPosition duration:duration usingSpringDamping:usingSpringWithDamping initialSpringVelocity:initialSpringVelocity];
    animation.fillMode = kCAFillModeForwards;
    animation.removedOnCompletion = true;
    animation.duration = duration;
    
    return animation;
}
        

+ (NSArray *)animationValuesFromPosition:(CGPoint)fromPosition toPosition:(CGPoint)toPosition duration:(NSTimeInterval)duration usingSpringDamping:(CGFloat)usingSpringDamping initialSpringVelocity:(CGFloat)initialSpringVelocity
{
    NSMutableArray *values = [[NSMutableArray alloc] init];
    
    CGPoint distance = CGPointMake(toPosition.x - fromPosition.x, toPosition.y - fromPosition.y);
    
    for (NSTimeInterval t = 0.0f; t < duration; t += 1.0f / 60.0f)
    {
        CGFloat animationValue = [self animationValue:(CGFloat)t usingSpringWithDamping:usingSpringDamping initialSpringVelocity:initialSpringVelocity];
        CGPoint value = CGPointMake(toPosition.x - distance.x * animationValue, toPosition.y - distance.y * animationValue);
        [values addObject:[NSValue valueWithCGPoint:value]];
    }
    
    return values;
}

+ (CGFloat)animationValue:(CGFloat)x usingSpringWithDamping:(CGFloat)usingSpringWithDamping initialSpringVelocity:(CGFloat)initialSpringVelocity
{
    return (CGFloat)(CGPow((CGFloat)M_E, -usingSpringWithDamping * x) * cos(initialSpringVelocity * x));
}


@end
