#import <UIKit/UIKit.h>
#import "LegacyComponentsIos6Compat.h"
#import "SSignalKitCompat/SSignalKit.h"

@protocol TGTransitionAnimatorLayout <NSObject>

- (void)collectionViewAlmostCompleteTransitioning:(PSUICollectionView *)collectionView;
- (void)collectionViewDidCompleteTransitioning:(PSUICollectionView *)collectionView completed:(bool)completed finish:(bool)finish;

@end

@interface PSUICollectionView (TGTransitioning)

@property (nonatomic, readonly) bool isTransitionInProgress;

- (UICollectionViewTransitionLayout *)transitionToCollectionViewLayout:(PSUICollectionViewLayout *)layout duration:(NSTimeInterval)duration completion:(UICollectionViewLayoutInteractiveTransitionCompletion)completion;
- (CGPoint)toContentOffsetForLayout:(UICollectionViewTransitionLayout *)layout indexPath:(NSIndexPath *)indexPath toSize:(CGSize)toSize toContentInset:(UIEdgeInsets)toContentInset;

- (SSignal *)noOngoingTransitionSignal;

@end
