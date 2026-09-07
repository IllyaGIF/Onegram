#import <UIKit/UIKit.h>

@class TGMenuSheetPallete;

@interface TGAttachmentMenuCell : PSUICollectionViewCell
{
    UIImageView *_cornersView;
}

@property (nonatomic, strong) TGMenuSheetPallete *pallete;

@end

extern const CGFloat TGAttachmentMenuCellCornerRadius;
