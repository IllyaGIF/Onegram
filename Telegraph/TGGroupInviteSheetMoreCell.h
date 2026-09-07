#import <UIKit/UIKit.h>

@class TGPresentation;

@interface TGGroupInviteSheetMoreCell : PSUICollectionViewCell

@property (nonatomic, strong) TGPresentation *presentation;
- (void)setCount:(NSUInteger)count;

@end
