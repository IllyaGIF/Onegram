#import <UIKit/UIKit.h>

@class TGPhotoStickersSectionHeader;
@class TGPhotoStickersSectionHeaderView;

@protocol TGPhotoStickersCollectionViewDelegate <PSUICollectionViewDelegateFlowLayout>

- (void)collectionView:(PSUICollectionView *)collectionView setupSectionHeaderView:(TGPhotoStickersSectionHeaderView *)sectionHeaderView forSectionHeader:(TGPhotoStickersSectionHeader *)sectionHeader;

@end

@interface TGPhotoStickersCollectionView : PSUICollectionView

@property (nonatomic, weak) UIView *headersParentView;
@property (nonatomic, strong) UIColor *headerTextColor;

@end
