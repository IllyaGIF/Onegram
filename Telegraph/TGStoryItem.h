#import <Foundation/Foundation.h>

@class TGTLDynamicObject;
@class TGImageMediaAttachment;
@class TGVideoMediaAttachment;
@class TGDocumentMediaAttachment;

typedef enum {
    TGStoryItemKindStory = 0,
    TGStoryItemKindSkipped = 1,
    TGStoryItemKindDeleted = 2
} TGStoryItemKind;

@interface TGStoryItem : NSObject

@property (nonatomic, readonly) TGStoryItemKind kind;
@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) int32_t storyId;
@property (nonatomic, readonly) int32_t date;
@property (nonatomic, readonly) int32_t expireDate;
@property (nonatomic, readonly) bool pinned;
@property (nonatomic, readonly) bool isPublic;
@property (nonatomic, readonly) bool closeFriends;
@property (nonatomic, readonly) bool contacts;
@property (nonatomic, readonly) bool selectedContacts;
@property (nonatomic, readonly) bool outgoing;
@property (nonatomic, readonly) bool noforwards;
@property (nonatomic, readonly) bool edited;
@property (nonatomic, readonly) bool min;
@property (nonatomic, strong, readonly) NSString *caption;
@property (nonatomic, strong, readonly) TGImageMediaAttachment *image;
@property (nonatomic, strong, readonly) TGVideoMediaAttachment *video;
@property (nonatomic, strong, readonly) TGDocumentMediaAttachment *videoDocument;
@property (nonatomic, readonly) int32_t viewsCount;
@property (nonatomic, readonly) bool hasViewsCount;
@property (nonatomic, readonly) NSTimeInterval videoDuration;

+ (TGStoryItem *)storyItemWithObject:(TGTLDynamicObject *)object peerId:(int64_t)peerId;

- (bool)hasMedia;
- (bool)isActiveAtTime:(NSTimeInterval)time;

@end

@interface TGPeerStories : NSObject

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) int32_t maxReadId;
@property (nonatomic, strong, readonly) NSArray *stories;

- (instancetype)initWithPeerId:(int64_t)peerId maxReadId:(int32_t)maxReadId stories:(NSArray *)stories;
+ (TGPeerStories *)peerStoriesWithObject:(TGTLDynamicObject *)object;

- (bool)hasUnread;
- (NSUInteger)firstUnreadIndex;
- (TGPeerStories *)peerStoriesWithMaxReadId:(int32_t)maxReadId;
- (TGPeerStories *)peerStoriesByMergingStories:(NSArray *)stories;

@end

int64_t TGStoryPeerIdFromObject(TGTLDynamicObject *peer);
