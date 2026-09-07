#import <UIKit/UIKit.h>

#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryController.h"

@class TGSharedMediaSectionHeaderView;
@class TGSharedMediaSectionHeader;

@protocol TGSharedMediaCollectionViewDelegate <PSUICollectionViewDelegateFlowLayout>

- (void)collectionView:(PSUICollectionView *)collectionView setupSectionHeaderView:(TGSharedMediaSectionHeaderView *)sectionHeaderView forSectionHeader:(TGSharedMediaSectionHeader *)sectionHeader;

@end

@interface TGSharedMediaCollectionView : PSUICollectionView <TGModernGalleryTransitionHostScrollView>

@end
