#import <UIKit/UIKit.h>
#import "UICollectionView+TGTransitioning.h"

@interface TGCollectionViewTransitionLayout : PSUICollectionViewLayout

@property (nonatomic, readonly) PSUICollectionViewLayout *currentLayout;
@property (nonatomic, readonly) PSUICollectionViewLayout *nextLayout;
@property (nonatomic) CGFloat transitionProgress;

- (instancetype)initWithCurrentLayout:(PSUICollectionViewLayout *)currentLayout nextLayout:(PSUICollectionViewLayout *)nextLayout;

@end

@interface TGTransitionLayout : TGCollectionViewTransitionLayout <TGTransitionAnimatorLayout>

@property (nonatomic) CGPoint toContentOffset;
@property (nonatomic, strong) void(^progressChanged)(CGFloat progress);
@property (nonatomic, strong) void(^transitionAlmostFinished)();

- (void)prepareForTransitionInCollectionView:(PSUICollectionView *)collectionView;

@end
