#import "TLDialog.h"

@interface TLDialog$dialogCommunity : TLDialog

@property (nonatomic) int64_t community_id;
@property (nonatomic, strong) TLPeerNotifySettings *notify_settings;

@property (nonatomic, readonly) bool pinned;

@end
