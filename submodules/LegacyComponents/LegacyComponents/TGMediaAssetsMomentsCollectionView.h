#import <UIKit/UIKit.h>

@class TGMediaAssetsMomentsSectionHeader;
@class TGMediaAssetsMomentsSectionHeaderView;

@protocol TGMediaAssetsMomentsCollectionViewDelegate <PSUICollectionViewDelegateFlowLayout>

- (void)collectionView:(PSUICollectionView *)collectionView setupSectionHeaderView:(TGMediaAssetsMomentsSectionHeaderView *)sectionHeaderView forSectionHeader:(TGMediaAssetsMomentsSectionHeader *)sectionHeader;

@end

@interface TGMediaAssetsMomentsCollectionView : PSUICollectionView

@end
