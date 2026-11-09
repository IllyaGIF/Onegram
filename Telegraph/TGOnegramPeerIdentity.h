#import "TGUserInfoUsernameCollectionItem.h"

@interface TGOnegramCopyValueCollectionItem : TGUserInfoUsernameCollectionItem
@end

#ifdef __cplusplus
extern "C" {
#endif

NSString *TGOnegramDisplayPeerId(int64_t peerId);
NSArray *TGOnegramPeerIdentityItems(int64_t peerId, NSString *photoUrl);

#ifdef __cplusplus
}
#endif
