#import "TLChatFull.h"

@interface TLChatFull$communityFull : TLChatFull

@property (nonatomic) int32_t flags;
@property (nonatomic) int64_t community_id;
@property (nonatomic, strong) NSString *about;
@property (nonatomic, strong) NSArray *linked_peers;
@property (nonatomic) int32_t admins_count;
@property (nonatomic) int32_t kicked_count;
@property (nonatomic) int32_t peer_link_requests_pending;

@end
