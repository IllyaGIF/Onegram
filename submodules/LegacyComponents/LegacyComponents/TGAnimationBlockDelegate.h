#import "LegacyComponentsIos6Compat.h"
#import <QuartzCore/QuartzCore.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
#define OG_COMPAT_ANIMATION_DELEGATE_PROTOCOLS <CAAnimationDelegate>
#else
#define OG_COMPAT_ANIMATION_DELEGATE_PROTOCOLS
#endif

@interface TGAnimationBlockDelegate : NSObject OG_COMPAT_ANIMATION_DELEGATE_PROTOCOLS

@property (nonatomic) bool removeLayerOnCompletion;
@property (nonatomic) NSNumber *opacityOnCompletion;
@property (nonatomic, weak) CALayer *layer;
@property (nonatomic, copy) void (^completion)(BOOL finished);

- (instancetype)initWithLayer:(CALayer *)layer;

@end
