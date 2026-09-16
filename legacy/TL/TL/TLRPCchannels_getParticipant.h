#ifndef TG_LEGACY_TL_TLRPCCHANNELS_GETPARTICIPANT_H
#define TG_LEGACY_TL_TLRPCCHANNELS_GETPARTICIPANT_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputChannel;
@class TLInputPeer;
@class TLchannels_ChannelParticipant;

@interface TLRPCchannels_getParticipant : TLMetaRpc

@property (nonatomic, retain) TLInputChannel *channel;
@property (nonatomic, retain) TLInputPeer *participant;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCchannels_getParticipant$channels_getParticipant : TLRPCchannels_getParticipant


@end

#endif
