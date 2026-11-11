#import "TGCollectionMenuController.h"

@class TGGroupInfoUserCollectionItem;

typedef enum {
    TGDialogFilterPeersModeInclude = 0,
    TGDialogFilterPeersModeExclude = 1,
    TGDialogFilterPeersModeChatlist = 2
} TGDialogFilterPeersMode;

@interface TGDialogFilterPeersController : TGCollectionMenuController

@property (nonatomic, copy) void (^completion)(int32_t categories, NSArray *peerIds);

- (instancetype)initWithMode:(TGDialogFilterPeersMode)mode categories:(int32_t)categories peerIds:(NSArray *)peerIds limit:(NSUInteger)limit;

+ (NSDictionary *)conversationsById;
+ (TGGroupInfoUserCollectionItem *)itemForPeerId:(int64_t)peerId conversations:(NSDictionary *)conversations;
+ (NSString *)titleForPeerId:(int64_t)peerId conversations:(NSDictionary *)conversations;
+ (bool)peerIdIsShareable:(int64_t)peerId conversations:(NSDictionary *)conversations;

@end
