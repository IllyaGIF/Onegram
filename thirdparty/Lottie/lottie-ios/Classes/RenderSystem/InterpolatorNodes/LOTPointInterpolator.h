#import "../../LOTXcode46Compat.h"
//
//  LOTPointInterpolator.h
//  Lottie
//
//  Created by brandon_withrow on 7/12/17.
//  Copyright © 2017 Airbnb. All rights reserved.
//

#import "LOTValueInterpolator.h"
#import "LOTValueDelegate.h"



@interface LOTPointInterpolator : LOTValueInterpolator

- (CGPoint)pointValueForFrame:(NSNumber *)frame;

@property (nonatomic, unsafe_unretained) id<LOTPointValueDelegate> delegate;

@end


