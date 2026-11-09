#ifndef TG_LEGACY_TL_TLRPCMESSAGES_GETSAVEDDIALOGS_H
#define TG_LEGACY_TL_TLRPCMESSAGES_GETSAVEDDIALOGS_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputPeer;
@class TLmessages_SavedDialogs;

@interface TLRPCmessages_getSavedDialogs : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLInputPeer *parent_peer;
@property (nonatomic) int32_t offset_date;
@property (nonatomic) int32_t offset_id;
@property (nonatomic, retain) TLInputPeer *offset_peer;
@property (nonatomic) int32_t limit;
@property (nonatomic) int64_t n_hash;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCmessages_getSavedDialogs$messages_getSavedDialogs : TLRPCmessages_getSavedDialogs


@end

#endif
