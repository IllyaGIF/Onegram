#import "../../OGLottieCompat.h"
//
//  LOTValueInterpolator.h
//  Pods
//
//  Created by brandon_withrow on 7/10/17.
//
//

#import <Foundation/Foundation.h>
#import "LOTKeyframe.h"
#import "LOTValueDelegate.h"



@interface LOTValueInterpolator : NSObject

- (instancetype)initWithKeyframes:(OG_COMPAT_GENERIC(NSArray, LOTKeyframe *) *)keyframes;

@property (nonatomic, unsafe_unretained) LOTKeyframe *leadingKeyframe;
@property (nonatomic, unsafe_unretained) LOTKeyframe *trailingKeyframe;
@property (nonatomic, readonly) BOOL hasDelegateOverride;

- (void)setValueDelegate:(id<LOTValueDelegate> _Nonnull)delegate;

- (BOOL)hasUpdateForFrame:(NSNumber *)frame;
- (CGFloat)progressForFrame:(NSNumber *)frame;

@end


