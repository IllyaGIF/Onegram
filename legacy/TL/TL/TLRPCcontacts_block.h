#ifndef TG_LEGACY_TL_TLRPCCONTACTS_BLOCK_H
#define TG_LEGACY_TL_TLRPCCONTACTS_BLOCK_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputPeer;

@interface TLRPCcontacts_block : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLInputPeer *n_id;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCcontacts_block$contacts_block : TLRPCcontacts_block


@end

#endif
