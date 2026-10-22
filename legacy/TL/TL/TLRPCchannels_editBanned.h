#ifndef TG_LEGACY_TL_TLRPCCHANNELS_EDITBANNED_H
#define TG_LEGACY_TL_TLRPCCHANNELS_EDITBANNED_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLChatBannedRights;
@class TLInputChannel;
@class TLInputPeer;
@class TLUpdates;

@interface TLRPCchannels_editBanned : TLMetaRpc

@property (nonatomic, retain) TLInputChannel *channel;
@property (nonatomic, retain) TLInputPeer *participant;
@property (nonatomic, retain) TLChatBannedRights *banned_rights;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCchannels_editBanned$channels_editBanned : TLRPCchannels_editBanned


@end

#endif
