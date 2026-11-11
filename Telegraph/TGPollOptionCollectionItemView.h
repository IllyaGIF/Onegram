#import "TGCollectionMultilineInputItemView.h"

@interface TGPollOptionCollectionItemView : TGCollectionMultilineInputItemView

@property (nonatomic, copy) void (^deletePressed)(void);
@property (nonatomic, copy) void (^correctPressed)(void);

- (void)setQuiz:(bool)quiz correct:(bool)correct canDelete:(bool)canDelete;

@end
