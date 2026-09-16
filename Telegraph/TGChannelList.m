#import "TGChannelList.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGChannelStateSignals.h"
#import "TGUpdateStateRequestBuilder.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

@interface TGChannelList () {
    NSMutableArray *_channels;
    
    NSMutableDictionary *_channelStateDisposables;
    
    NSMutableSet *_uncommitedPeerIds;
    NSMutableDictionary *_removedChannels;
}

@end

@implementation TGChannelList

- (instancetype)initWithChannels:(NSArray *)channels {
    self = [super init];
    if (self != nil) {
        _channelStateDisposables = [[NSMutableDictionary alloc] init];
        _uncommitedPeerIds = [[NSMutableSet alloc] init];
        _removedChannels = [[NSMutableDictionary alloc] init];

        _channels = [[NSMutableArray alloc] init];
        for (TGConversation *conversation in channels) {
            if (!conversation.leftChat && !conversation.kickedFromChat && conversation.kind == TGConversationKindPersistentChannel)
                [_channels addObject:conversation];
        }
        [_channels sortUsingComparator:^NSComparisonResult(TGConversation *lhs, TGConversation *rhs) {
            int result = TGConversationSortKeyCompare(lhs.variantSortKey, rhs.variantSortKey);
            if (result > 0) {
                return NSOrderedAscending;
            } else if (result < 0) {
                return NSOrderedDescending;
            } else {
                return NSOrderedSame;
            }
        }];
    }
    return self;
}

- (void)dealloc {
    for (id<SDisposable> disposable in _channelStateDisposables.allValues) {
        [disposable dispose];
    }
}

- (NSArray *)channels {
    return [[NSArray alloc] initWithArray:_channels];
}

- (bool)updateChannel:(TGConversation *)conversation {
    NSNumber *peerId = @(conversation.conversationId);

    for (NSUInteger i = 0; i < _channels.count; i++) {
        TGConversation *currentChannel = _channels[i];
        if (currentChannel.conversationId == conversation.conversationId) {
            [_channels removeObjectAtIndex:i];
            break;
        }
    }

    if (conversation.leftChat || conversation.kickedFromChat || conversation.kind != TGConversationKindPersistentChannel) {
        TGConversation *deletedConversation = [conversation copy];
        deletedConversation.isDeleted = true;
        _removedChannels[peerId] = deletedConversation;
        [_uncommitedPeerIds addObject:peerId];
        return true;
    }

    [_removedChannels removeObjectForKey:peerId];

    bool inserted = false;
    for (NSUInteger i = 0; i < _channels.count; i++) {
        TGConversation *currentChannel = _channels[i];
        if (TGConversationSortKeyCompare(conversation.variantSortKey, currentChannel.variantSortKey) > 0) {
            [_channels insertObject:conversation atIndex:i];
            inserted = true;
            break;
        }
    }

    if (!inserted)
        [_channels addObject:conversation];

    [_uncommitedPeerIds addObject:peerId];

    return true;
}

- (void)commitUpdatedChannels {
    if (_uncommitedPeerIds.count == 0)
        return;

    NSSet *peerIds = [_uncommitedPeerIds copy];
    [_uncommitedPeerIds removeAllObjects];

    NSMutableArray *channels = [[NSMutableArray alloc] initWithCapacity:peerIds.count];
    for (TGConversation *conversation in _channels) {
        if ([peerIds containsObject:@(conversation.conversationId)])
            [channels addObject:conversation];
    }

    for (NSNumber *peerId in peerIds) {
        TGConversation *removedConversation = _removedChannels[peerId];
        if (removedConversation != nil) {
            [channels addObject:removedConversation];
            [_removedChannels removeObjectForKey:peerId];
        }
    }

    if (channels.count != 0)
        [ActionStageInstance() dispatchResource:@"/tg/conversations" resource:[[SGraphObjectNode alloc] initWithObject:channels]];
}

@end
