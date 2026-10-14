#import "TLChat.h"

@interface TLChat$communityForbidden : TLChat

@property (nonatomic) int32_t flags;
@property (nonatomic) int64_t community_id;
@property (nonatomic) int64_t access_hash;
@property (nonatomic, strong) NSString *title;

@end
