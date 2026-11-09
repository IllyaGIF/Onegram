#import <UIKit/UIKit.h>

@interface TGProfileGridView : UIScrollView

@property (nonatomic) NSUInteger columns;
@property (nonatomic) CGFloat tileAspect;
@property (nonatomic) CGFloat spacing;
@property (nonatomic) UIEdgeInsets gridInsets;
@property (nonatomic) NSUInteger itemCount;
@property (nonatomic, copy) UIView *(^tileFactory)(void);
@property (nonatomic, copy) void (^configureTile)(UIView *tile, NSUInteger index);
@property (nonatomic, copy) void (^tileSelected)(NSUInteger index);
@property (nonatomic, copy) void (^nearEnd)(void);

- (void)reloadData;
- (void)reloadTileAtIndex:(NSUInteger)index;

@end
