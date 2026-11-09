#import "TGMessageSelectionGestureRecognizer.h"
#import "TGModernConversationCollectionViewInstantPreviewRecognizer.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDoubleTapGestureRecognizer.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGTimerTarget.h"
#import <math.h>
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#import <UIKit/UIGestureRecognizerSubclass.h>
#endif

@implementation TGMessageSelectionGestureRecognizer
{
    CGPoint _initialLocation;
    NSTimer *_holdTimer;
}

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self != nil)
    {
        _minimumPressDuration = 0.4;
        _allowableMovement = 8;
        self.cancelsTouchesInView = true;
    }
    return self;
}

- (void)dealloc
{
    [_holdTimer invalidate];
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)other
{
    return ![other isKindOfClass:[TGDoubleTapGestureRecognizer class]] && ![other isKindOfClass:[TGModernConversationCollectionViewInstantPreviewRecognizer class]];
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)other
{
    return ![other isKindOfClass:[TGModernConversationCollectionViewInstantPreviewRecognizer class]];
}

- (void)reset
{
    [_holdTimer invalidate];
    _holdTimer = nil;
    [super reset];
}

- (void)beginSelection
{
    _holdTimer = nil;
    if (self.state != UIGestureRecognizerStatePossible)
        return;
    id<UIGestureRecognizerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(gestureRecognizerShouldBegin:)] && ![delegate gestureRecognizerShouldBegin:self])
    {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }
    self.state = UIGestureRecognizerStateBegan;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    if (touches.count != 1 || self.numberOfTouches > 1 || _holdTimer != nil || self.state != UIGestureRecognizerStatePossible)
    {
        [_holdTimer invalidate];
        _holdTimer = nil;
        self.state = self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged ? UIGestureRecognizerStateCancelled : UIGestureRecognizerStateFailed;
        return;
    }
    _initialLocation = [[touches anyObject] locationInView:self.view];
    _holdTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(beginSelection) interval:MAX(0.1, _minimumPressDuration) repeat:false];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged)
    {
        self.state = UIGestureRecognizerStateChanged;
        return;
    }
    if (self.state != UIGestureRecognizerStatePossible)
        return;
    CGPoint location = [[touches anyObject] locationInView:self.view];
    CGFloat dx = location.x - _initialLocation.x;
    CGFloat dy = location.y - _initialLocation.y;
    if (dx * dx + dy * dy > _allowableMovement * _allowableMovement)
    {
        [_holdTimer invalidate];
        _holdTimer = nil;
        if (_beginsWithVerticalDrag && fabs(dy) > fabs(dx) * 1.5f && fabs(dy) >= 12.0f)
            [self beginSelection];
        else if (!_beginsWithVerticalDrag || fabs(dx) > fabs(dy) || fabs(dy) >= 12.0f)
            self.state = UIGestureRecognizerStateFailed;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    [_holdTimer invalidate];
    _holdTimer = nil;
    self.state = self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged ? UIGestureRecognizerStateEnded : UIGestureRecognizerStateFailed;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    [_holdTimer invalidate];
    _holdTimer = nil;
    self.state = self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged ? UIGestureRecognizerStateCancelled : UIGestureRecognizerStateFailed;
}

@end
