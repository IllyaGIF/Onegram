#import <UIKit/UIKit.h>

typedef enum {
    TGStoryRingStateNone = 0,
    TGStoryRingStateUnread = 1,
    TGStoryRingStateRead = 2
} TGStoryRingState;

@interface TGStoryRingView : UIView

@property (nonatomic) TGStoryRingState state;
@property (nonatomic) CGFloat lineWidth;

- (void)layoutAroundFrame:(CGRect)frame spacing:(CGFloat)spacing;

@end

UIImage *TGStoryRingImage(CGFloat diameter, CGFloat lineWidth, TGStoryRingState state);
