#import <UIKit/UIKit.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGPeerStories;
@class TGStoryItem;
@class TLInputFile;

typedef enum {
    TGStoryPrivacyEveryone = 0,
    TGStoryPrivacyContacts = 1,
    TGStoryPrivacyCloseFriends = 2
} TGStoryPrivacy;

@interface TGStoriesPage : NSObject

@property (nonatomic, readonly) int32_t totalCount;
@property (nonatomic, strong, readonly) NSArray *stories;
@property (nonatomic, strong, readonly) NSArray *pinnedToTopIds;

- (instancetype)initWithTotalCount:(int32_t)totalCount stories:(NSArray *)stories pinnedToTopIds:(NSArray *)pinnedToTopIds;

@end

@interface TGAllStoriesResult : NSObject

@property (nonatomic, readonly) bool notModified;
@property (nonatomic, readonly) bool hasMore;
@property (nonatomic, strong, readonly) NSString *state;
@property (nonatomic, strong, readonly) NSArray *peerStories;

- (instancetype)initWithNotModified:(bool)notModified hasMore:(bool)hasMore state:(NSString *)state peerStories:(NSArray *)peerStories;

@end

@interface TGStoryViewer : NSObject

@property (nonatomic, readonly) int64_t userId;
@property (nonatomic, readonly) int32_t date;
@property (nonatomic, readonly) bool hasReaction;
@property (nonatomic, strong, readonly) NSString *reaction;
@property (nonatomic, readonly) bool blocked;

- (instancetype)initWithUserId:(int64_t)userId date:(int32_t)date hasReaction:(bool)hasReaction reaction:(NSString *)reaction blocked:(bool)blocked;

@end

@interface TGStoryViewersPage : NSObject

@property (nonatomic, readonly) int32_t count;
@property (nonatomic, readonly) int32_t viewsCount;
@property (nonatomic, readonly) int32_t reactionsCount;
@property (nonatomic, strong, readonly) NSArray *viewers;
@property (nonatomic, strong, readonly) NSString *nextOffset;

- (instancetype)initWithCount:(int32_t)count viewsCount:(int32_t)viewsCount reactionsCount:(int32_t)reactionsCount viewers:(NSArray *)viewers nextOffset:(NSString *)nextOffset;

@end

@interface TGStoriesSignals : NSObject

+ (id)inputPeerForPeerId:(int64_t)peerId;
+ (id)inputUserForUserId:(int64_t)userId;
+ (SSignal *)thumbnailForStory:(TGStoryItem *)story size:(CGSize)size;
+ (void)processUsers:(NSArray *)users chats:(NSArray *)chats;

+ (SSignal *)peerStories:(int64_t)peerId;
+ (SSignal *)pinnedStories:(int64_t)peerId offsetId:(int32_t)offsetId limit:(int32_t)limit;
+ (SSignal *)storiesArchiveWithOffsetId:(int32_t)offsetId limit:(int32_t)limit;
+ (SSignal *)storiesWithPeerId:(int64_t)peerId storyIds:(NSArray *)storyIds;
+ (SSignal *)allStoriesWithState:(NSString *)state next:(bool)next hidden:(bool)hidden;

+ (SSignal *)readStories:(int64_t)peerId maxId:(int32_t)maxId;
+ (SSignal *)incrementViews:(int64_t)peerId storyIds:(NSArray *)storyIds;
+ (SSignal *)deleteStories:(int64_t)peerId storyIds:(NSArray *)storyIds;
+ (SSignal *)setStories:(int64_t)peerId storyIds:(NSArray *)storyIds pinned:(bool)pinned;

+ (SSignal *)sendReaction:(NSString *)reaction toStory:(TGStoryItem *)story;
+ (SSignal *)viewersForStory:(TGStoryItem *)story offset:(NSString *)offset limit:(int32_t)limit;
+ (SSignal *)availableReactions;

+ (SSignal *)canSendStory:(int64_t)peerId;
+ (SSignal *)sendPhotoStoryWithFile:(TLInputFile *)file peerId:(int64_t)peerId caption:(NSString *)caption privacy:(TGStoryPrivacy)privacy period:(int32_t)period pinned:(bool)pinned;
+ (SSignal *)sendVideoStoryWithFile:(TLInputFile *)file thumbnail:(TLInputFile *)thumbnail duration:(NSTimeInterval)duration dimensions:(CGSize)dimensions peerId:(int64_t)peerId caption:(NSString *)caption privacy:(TGStoryPrivacy)privacy period:(int32_t)period pinned:(bool)pinned;

@end
