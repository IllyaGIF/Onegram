#ifndef TG_LEGACY_TL_TLRPCCHANNELS_DELETEPARTICIPANTHISTORY_H
#define TG_LEGACY_TL_TLRPCCHANNELS_DELETEPARTICIPANTHISTORY_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputChannel;
@class TLInputPeer;
@class TLmessages_AffectedHistory;

@interface TLRPCchannels_deleteParticipantHistory : TLMetaRpc

@property (nonatomic, retain) TLInputChannel *channel;
@property (nonatomic, retain) TLInputPeer *participant;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCchannels_deleteParticipantHistory$channels_deleteParticipantHistory : TLRPCchannels_deleteParticipantHistory


@end

#endif
