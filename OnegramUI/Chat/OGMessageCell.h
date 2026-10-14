#import "../Base/OGView.h"
#import "../Core/OGState.h"
@class OGBubbleView;
@class OGMessageContentView;
@class OGMessageMetaView;
@interface OGMessageCell : OGView
@property (nonatomic, retain, readonly) OGBubbleView *bubbleView;
@property (nonatomic, retain) OGMessageContentView *contentView;
@property (nonatomic, retain, readonly) OGMessageMetaView *metaView;
@property (nonatomic) OGMessageAlignment alignment;
@property (nonatomic) UIEdgeInsets bubbleInsets;
@property (nonatomic) UIEdgeInsets contentInsets;
@end
