#ifndef TG_LEGACY_TL_TLRPCMESSAGES_GETSAVEDHISTORY_H
#define TG_LEGACY_TL_TLRPCMESSAGES_GETSAVEDHISTORY_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputPeer;
@class TLmessages_Messages;

@interface TLRPCmessages_getSavedHistory : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLInputPeer *parent_peer;
@property (nonatomic, retain) TLInputPeer *peer;
@property (nonatomic) int32_t offset_id;
@property (nonatomic) int32_t offset_date;
@property (nonatomic) int32_t add_offset;
@property (nonatomic) int32_t limit;
@property (nonatomic) int32_t max_id;
@property (nonatomic) int32_t min_id;
@property (nonatomic) int64_t n_hash;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCmessages_getSavedHistory$messages_getSavedHistory : TLRPCmessages_getSavedHistory


@end

#endif
