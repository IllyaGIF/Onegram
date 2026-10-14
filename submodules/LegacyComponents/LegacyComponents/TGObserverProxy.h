#import <Foundation/Foundation.h>

@interface TGObserverProxy : NSObject

@property (nonatomic) NSUInteger numberOfRunLoopPassesToDelayTargetNotifications;

- (instancetype)initWithKeyboardFrameTarget:(id)target targetSelector:(SEL)targetSelector;

- (instancetype)initWithTarget:(id)target targetSelector:(SEL)targetSelector name:(NSString *)name;
- (instancetype)initWithTarget:(id)target targetSelector:(SEL)targetSelector name:(NSString *)name object:(id)object;

@end
