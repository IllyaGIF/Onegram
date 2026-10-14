#import <UIKit/UIKit.h>

@interface TGGifKeyboardBalancedLayout : PSUICollectionViewLayout

@property (nonatomic) CGFloat preferredRowSize;

@property (nonatomic) CGSize headerReferenceSize;

@property (nonatomic) CGSize footerReferenceSize;

@property (nonatomic) UIEdgeInsets sectionInset;

@property (nonatomic) CGFloat minimumLineSpacing;

@property (nonatomic) CGFloat minimumInteritemSpacing;

@property (nonatomic) UICollectionViewScrollDirection scrollDirection;

- (CGSize)standaloneContentSize:(CGSize)viewportSize;

@end

@protocol TGGifKeyboardBalancedLayoutDelegate <NSObject>

@required

- (CGSize)collectionView:(PSUICollectionView *)collectionView layout:(TGGifKeyboardBalancedLayout *)collectionViewLayout preferredSizeForItemAtIndexPath:(NSIndexPath *)indexPath;

@end