#import <UIKit/UIKit.h>

@interface TGDraggableCollectionView : PSUICollectionView

@property (nonatomic, assign) bool draggable;
@property (nonatomic, assign) UIEdgeInsets scrollingTriggerEdgeInsets;
@property (nonatomic, assign) CGFloat scrollingSpeed;

@property (nonatomic, weak) UIView *draggedViewSuperview;

@end

@protocol TGDraggableCollectionViewDataSource <PSUICollectionViewDataSource>
@optional

- (void)collectionView:(PSUICollectionView *)collectionView itemAtIndexPath:(NSIndexPath *)sourceIndexPath willMoveToIndexPath:(NSIndexPath *)destinationIndexPath;
- (void)collectionView:(PSUICollectionView *)collectionView itemAtIndexPath:(NSIndexPath *)sourceIndexPath didMoveToIndexPath:(NSIndexPath *)destinationIndexPath;

- (bool)collectionView:(PSUICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)sourceIndexPath;
- (bool)collectionView:(PSUICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;

@end
