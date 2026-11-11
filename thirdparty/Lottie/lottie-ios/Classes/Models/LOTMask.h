#import "../OGLottieCompat.h"
//
//  LOTMask.h
//  LottieAnimator
//
//  Created by Brandon Withrow on 12/14/15.
//  Copyright © 2015 Brandon Withrow. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LOTKeyframe.h"

typedef enum : NSUInteger {
  LOTMaskModeAdd,
  LOTMaskModeSubtract,
  LOTMaskModeIntersect,
  LOTMaskModeUnknown
} LOTMaskMode;

@interface LOTMask : NSObject

- (instancetype _Nonnull)initWithJSON:(NSDictionary * _Nonnull)jsonDictionary;

@property (nonatomic, readonly) BOOL closed;
@property (nonatomic, readonly) BOOL inverted;
@property (nonatomic, readonly) LOTMaskMode maskMode;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable maskPath;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable opacity;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable expansion;
@end
