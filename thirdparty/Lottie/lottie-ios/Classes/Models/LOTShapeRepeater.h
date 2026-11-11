#import "../OGLottieCompat.h"
//
//  LOTShapeRepeater.h
//  Lottie
//
//  Created by brandon_withrow on 7/28/17.
//  Copyright © 2017 Airbnb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LOTKeyframe.h"



@interface LOTShapeRepeater : NSObject

- (instancetype)initWithJSON:(NSDictionary *)jsonDictionary;

@property (nonatomic, readonly) NSString *keyname;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable copies;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable offset;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable anchorPoint;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable scale;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable position;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable rotation;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable startOpacity;
@property (nonatomic, readonly) LOTKeyframeGroup *_Nullable endOpacity;

@end


