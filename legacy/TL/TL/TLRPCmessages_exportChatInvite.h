#ifndef TG_LEGACY_TL_TLRPCMESSAGES_EXPORTCHATINVITE_H
#define TG_LEGACY_TL_TLRPCMESSAGES_EXPORTCHATINVITE_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLExportedChatInvite;
@class TLInputPeer;
@class TLStarsSubscriptionPricing;

@interface TLRPCmessages_exportChatInvite : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLInputPeer *peer;
@property (nonatomic) int32_t expire_date;
@property (nonatomic) int32_t usage_limit;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) TLStarsSubscriptionPricing *subscription_pricing;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCmessages_exportChatInvite$messages_exportChatInvite : TLRPCmessages_exportChatInvite


@end

#endif
