#import <UIKit/UIKit.h>

@interface TGMessageReactionsLayout : NSObject

@property (nonatomic, readonly) CGSize size;

+ (instancetype)layoutWithItemSizes:(NSArray *)itemSizes maximumWidth:(CGFloat)maximumWidth trailingWidth:(CGFloat)trailingWidth trailingHeight:(CGFloat)trailingHeight itemSpacing:(CGFloat)itemSpacing lineSpacing:(CGFloat)lineSpacing trailingSpacing:(CGFloat)trailingSpacing;

- (CGRect)frameForItemAtIndex:(NSUInteger)index;

@end
