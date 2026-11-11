#import "../../OGLottieCompat.h"
//
//  LOTStrokeRenderer.h
//  Lottie
//
//  Created by brandon_withrow on 7/17/17.
//  Copyright © 2017 Airbnb. All rights reserved.
//

#import "LOTRenderNode.h"
#import "LOTShapeStroke.h"

@interface LOTStrokeRenderer : LOTRenderNode

- (instancetype _Nonnull)initWithInputNode:(LOTAnimatorNode *_Nullable)inputNode
                                shapeStroke:(LOTShapeStroke *_Nonnull)stroke;


@end
