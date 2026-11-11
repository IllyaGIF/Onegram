#import "TGCollectionMenuController.h"

@class TGPreparedPollMessage;

@interface TGCreatePollController : TGCollectionMenuController

@property (nonatomic, copy) void (^completion)(TGPreparedPollMessage *pollMessage);

- (instancetype)initWithAllowPublicVoters:(bool)allowPublicVoters quiz:(bool)quiz;

@end
