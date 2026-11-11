#import "TGCollectionMenuController.h"

@class TGStoryItem;

@interface TGStoryViewersController : TGCollectionMenuController

@property (nonatomic, copy) void (^dismissed)(void);

- (instancetype)initWithStory:(TGStoryItem *)story;

@end
