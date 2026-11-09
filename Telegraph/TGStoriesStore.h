#import <Foundation/Foundation.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGPeerStories;
@class TGStoryItem;

extern NSString *const TGStoriesStoreDidChangeNotification;

@interface TGStoriesStore : NSObject

+ (TGStoriesStore *)instance;

- (NSArray *)orderedPeerStories;
- (TGPeerStories *)peerStoriesForPeerId:(int64_t)peerId;

- (void)refreshIfNeeded;
- (void)refresh;
- (SSignal *)peerStoriesSignal:(int64_t)peerId;

- (void)setPeerStories:(TGPeerStories *)peerStories;
- (void)addStories:(NSArray *)stories forPeerId:(int64_t)peerId;
- (void)removeStoryIds:(NSArray *)storyIds forPeerId:(int64_t)peerId;
- (void)markStory:(TGStoryItem *)story seenForPeerId:(int64_t)peerId;

@end
