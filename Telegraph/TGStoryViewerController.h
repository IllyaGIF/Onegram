#import "../submodules/LegacyComponents/LegacyComponents/TGViewController.h"

@class TGPeerStories;

@interface TGStoryViewerController : TGViewController

@property (nonatomic) bool marksStoriesAsRead;
@property (nonatomic, copy) void (^storiesDeleted)(int64_t peerId, NSArray *storyIds);
@property (nonatomic, copy) void (^storyPinnedChanged)(int64_t peerId, int32_t storyId, bool pinned);

- (instancetype)initWithPeerStories:(NSArray *)peerStoriesList peerIndex:(NSUInteger)peerIndex storyIndex:(NSUInteger)storyIndex;

+ (void)presentActiveStoriesForPeerId:(int64_t)peerId fromController:(UIViewController *)controller;
+ (void)presentStoryWithPeerId:(int64_t)peerId storyId:(int32_t)storyId fromController:(UIViewController *)controller;
+ (void)presentActiveStoriesList:(NSArray *)peerStoriesList peerIndex:(NSUInteger)peerIndex fromController:(UIViewController *)controller;

@end
