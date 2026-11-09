#import <UIKit/UIKit.h>

@interface TGMessageSelectionGestureRecognizer : UIGestureRecognizer

@property (nonatomic) NSTimeInterval minimumPressDuration;
@property (nonatomic) CGFloat allowableMovement;
@property (nonatomic) BOOL beginsWithVerticalDrag;

@end
