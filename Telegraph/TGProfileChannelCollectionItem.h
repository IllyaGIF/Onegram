#import "TGCollectionItem.h"

@class TGConversation;

@interface TGProfileChannelCollectionItem : TGCollectionItem

@property (nonatomic, strong) TGConversation *channel;
@property (nonatomic, copy) void (^pressed)(TGConversation *channel);

@end
