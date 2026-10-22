#ifndef TG_LEGACY_TL_TLRPCCHANNELS_EXPORTMESSAGELINK_H
#define TG_LEGACY_TL_TLRPCCHANNELS_EXPORTMESSAGELINK_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLExportedMessageLink;
@class TLInputChannel;

@interface TLRPCchannels_exportMessageLink : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLInputChannel *channel;
@property (nonatomic) int32_t n_id;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCchannels_exportMessageLink$channels_exportMessageLink : TLRPCchannels_exportMessageLink


@end

#endif
