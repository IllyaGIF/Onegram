#import <Foundation/Foundation.h>

@class TGConversation;

@interface TGChannelList : NSObject

- (instancetype)initWithChannels:(NSArray *)channels;

- (NSArray *)channels;
- (TGConversation *)channelWithId:(int64_t)peerId;
- (bool)updateChannel:(TGConversation *)conversation;
- (void)commitUpdatedChannels;

@end
