#ifndef TG_LEGACY_TL_TLRPCMESSAGES_EDITCHATDEFAULTBANNEDRIGHTS_H
#define TG_LEGACY_TL_TLRPCMESSAGES_EDITCHATDEFAULTBANNEDRIGHTS_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLChatBannedRights;
@class TLInputPeer;
@class TLUpdates;

@interface TLRPCmessages_editChatDefaultBannedRights : TLMetaRpc

@property (nonatomic, retain) TLInputPeer *peer;
@property (nonatomic, retain) TLChatBannedRights *banned_rights;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCmessages_editChatDefaultBannedRights$messages_editChatDefaultBannedRights : TLRPCmessages_editChatDefaultBannedRights


@end

#endif
