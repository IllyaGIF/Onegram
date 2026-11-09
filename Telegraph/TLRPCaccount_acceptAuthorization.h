#import "TLMetaRpc.h"

@class TLSecureCredentialsEncrypted;

@interface TLRPCaccount_acceptAuthorization : TLMetaRpc

@property (nonatomic) int64_t bot_id;
@property (nonatomic, retain) NSString *scope;
@property (nonatomic, retain) NSString *public_key;
@property (nonatomic, retain) NSArray *value_hashes;
@property (nonatomic, retain) TLSecureCredentialsEncrypted *credentials;

@end
