#import "TGMediaSelectionContext.h"
#import <UIKit/UIKit.h>

@interface TGMediaPickerSelectionGestureRecognizer : NSObject

@property (nonatomic, copy) bool (^isItemSelected)(NSIndexPath *);
@property (nonatomic, copy) void (^toggleItemSelection)(NSIndexPath *);

- (instancetype)initForCollectionView:(PSUICollectionView *)collectionView;
- (void)cancel;

@end
