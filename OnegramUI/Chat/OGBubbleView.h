#import "../Base/OGView.h"
#import "../Core/OGState.h"
@interface OGBubbleView : OGView
@property (nonatomic) OGMessageAlignment alignment;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) BOOL drawsTail;
@end
