#import "../Base/OGView.h"
#import "../Core/OGState.h"
@class OGLabel;
@class OGCheckmarkView;
@interface OGMessageMetaView : OGView
@property (nonatomic, retain, readonly) OGLabel *timeLabel;
@property (nonatomic, retain, readonly) OGLabel *viewsLabel;
@property (nonatomic, retain, readonly) OGCheckmarkView *checkmarkView;
@property (nonatomic, copy) NSString *timeText;
@property (nonatomic, copy) NSString *viewsText;
@property (nonatomic) OGDeliveryState deliveryState;
@property (nonatomic) BOOL outgoing;
@end
