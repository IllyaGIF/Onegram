#ifndef TG_LEGACY_TL_TLRPCMESSAGES_READSAVEDHISTORY_H
#define TG_LEGACY_TL_TLRPCMESSAGES_READSAVEDHISTORY_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputPeer;

@interface TLRPCmessages_readSavedHistory : TLMetaRpc

@property (nonatomic, retain) TLInputPeer *parent_peer;
@property (nonatomic, retain) TLInputPeer *peer;
@property (nonatomic) int32_t max_id;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCmessages_readSavedHistory$messages_readSavedHistory : TLRPCmessages_readSavedHistory


@end

#endif
