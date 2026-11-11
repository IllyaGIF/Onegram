#import "TGCollectionMultilineInputItem.h"

@interface TGPollOptionCollectionItem : TGCollectionMultilineInputItem

@property (nonatomic) bool quiz;
@property (nonatomic) bool correct;
@property (nonatomic) bool canDelete;
@property (nonatomic, copy) void (^deletePressed)(void);
@property (nonatomic, copy) void (^correctPressed)(void);

@end
