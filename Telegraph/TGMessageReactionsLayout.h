#import <UIKit/UIKit.h>

#import "TGModernButtonViewModel.h"

@class TGPresentation;
@class TGMessage;
@class TGModernViewContext;
@class TGModernViewStorage;
@class TGModernViewModel;
@class TGMessageReactionsLayout;

typedef enum {
    TGMessageReactionsStyleIncoming,
    TGMessageReactionsStyleOutgoing,
    TGMessageReactionsStyleService
} TGMessageReactionsStyle;

typedef struct {
    CGFloat itemSpacing;
    CGFloat lineSpacing;
    CGFloat topSpacing;
    CGFloat timeSpacing;
    CGFloat timeRowSpacing;
    CGFloat leadingOffset;
} TGMessageReactionsMetrics;

TGMessageReactionsMetrics TGMessageReactionsCurrentMetrics(void);

@interface TGMessageReactionItem : NSObject

@property (nonatomic, readonly) NSString *reaction;
@property (nonatomic, readonly) int64_t customEmojiId;
@property (nonatomic, readonly) bool paid;
@property (nonatomic, readonly) NSInteger count;
@property (nonatomic, readonly) bool chosen;

+ (NSArray *)itemsWithSummary:(NSString *)summary chosenReaction:(NSString *)chosenReaction;
+ (NSString *)keyForReaction:(NSString *)reaction;

@end

@interface TGMessageReactionButtonModel : TGModernButtonViewModel

@property (nonatomic, readonly) TGMessageReactionItem *item;

- (instancetype)initWithItem:(TGMessageReactionItem *)item style:(TGMessageReactionsStyle)style presentation:(TGPresentation *)presentation pressed:(void (^)(TGMessageReactionItem *item))pressed;

@end

@interface TGMessageReactionsLayout : NSObject

@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGRect trailingFrame;

+ (instancetype)layoutWithItemSizes:(NSArray *)itemSizes maximumWidth:(CGFloat)maximumWidth trailingWidth:(CGFloat)trailingWidth trailingHeight:(CGFloat)trailingHeight itemSpacing:(CGFloat)itemSpacing lineSpacing:(CGFloat)lineSpacing trailingSpacing:(CGFloat)trailingSpacing trailingLineSpacing:(CGFloat)trailingLineSpacing;

- (CGRect)frameForItemAtIndex:(NSUInteger)index;

@end

@interface TGMessageReactionsModel : NSObject

@property (nonatomic, readonly) NSArray *buttons;
@property (nonatomic) int32_t messageId;

+ (NSString *)summaryForMessage:(TGMessage *)message;
+ (NSString *)chosenReactionForMessage:(TGMessage *)message;

- (instancetype)initWithContext:(TGModernViewContext *)context style:(TGMessageReactionsStyle)style;

- (bool)updateWithMessage:(TGMessage *)message parent:(TGModernViewModel *)parent viewStorage:(TGModernViewStorage *)viewStorage container:(UIView *)container;
- (bool)updateWithSummary:(NSString *)summary chosenReaction:(NSString *)chosenReaction parent:(TGModernViewModel *)parent viewStorage:(TGModernViewStorage *)viewStorage container:(UIView *)container;
- (void)bringToFrontInContainer:(UIView *)container;
- (void)moveToFrontInParent:(TGModernViewModel *)parent viewStorage:(TGModernViewStorage *)viewStorage container:(UIView *)container;

- (TGMessageReactionsLayout *)layoutWithMaximumWidth:(CGFloat)maximumWidth trailingWidth:(CGFloat)trailingWidth trailingHeight:(CGFloat)trailingHeight;
- (void)applyLayout:(TGMessageReactionsLayout *)layout origin:(CGPoint)origin;

@end
