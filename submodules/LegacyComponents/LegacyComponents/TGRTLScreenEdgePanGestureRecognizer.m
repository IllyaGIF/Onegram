#import "TGRTLScreenEdgePanGestureRecognizer.h"

#import "Freedom.h"

@implementation TGRTLScreenEdgePanGestureRecognizer

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    if (touch != nil) {
        static NSArray *disabledClassList = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSMutableArray *array = [[NSMutableArray alloc] init];
            for (NSString *name in @[@"TGModernConversationInputMicButton", @"TGModernConversationInputAttachButton"]) {
                Class className = NSClassFromString(name);
                if (className != nil) {
                    [array addObject:className];
                }
            }
            disabledClassList = array;
        });
        
        CGPoint location = [touch locationInView:self.view];
        UIView *targetView = [self.view hitTest:location withEvent:event];
        for (Class className in disabledClassList) {
            if ([targetView isKindOfClass:className]) {
                self.state = UIGestureRecognizerStateFailed;
                return;
            }
        }
    }
    
    [super touchesBegan:touches withEvent:event];
}

- (void)setState:(UIGestureRecognizerState)state {
    [super setState:state];
}

@end

