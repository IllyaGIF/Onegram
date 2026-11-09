#import "TLMetaRpc.h"

@interface TLRPCaccount_getAuthorizationForm : TLMetaRpc

@property (nonatomic) int64_t bot_id;
@property (nonatomic, retain) NSString *scope;
@property (nonatomic, retain) NSString *public_key;

@end
