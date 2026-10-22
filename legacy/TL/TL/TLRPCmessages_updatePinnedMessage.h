#ifndef TG_LEGACY_TL_TLRPCMESSAGES_UPDATEPINNEDMESSAGE_H
#define TG_LEGACY_TL_TLRPCMESSAGES_UPDATEPINNEDMESSAGE_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputPeer;
@class TLUpdates;

@interface TLRPCmessages_updatePinnedMessage : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLInputPeer *peer;
@property (nonatomic) int32_t n_id;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCmessages_updatePinnedMessage$messages_updatePinnedMessage : TLRPCmessages_updatePinnedMessage


@end

#endif
