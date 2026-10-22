#ifndef TG_LEGACY_TL_TLRPCCONTACTS_UNBLOCK_H
#define TG_LEGACY_TL_TLRPCCONTACTS_UNBLOCK_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputPeer;

@interface TLRPCcontacts_unblock : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLInputPeer *n_id;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCcontacts_unblock$contacts_unblock : TLRPCcontacts_unblock


@end

#endif
