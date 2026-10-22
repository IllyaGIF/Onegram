#ifndef TG_LEGACY_TL_TLRPCMESSAGES_HIDEPEERSETTINGSBAR_H
#define TG_LEGACY_TL_TLRPCMESSAGES_HIDEPEERSETTINGSBAR_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputPeer;

@interface TLRPCmessages_hidePeerSettingsBar : TLMetaRpc

@property (nonatomic, retain) TLInputPeer *peer;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCmessages_hidePeerSettingsBar$messages_hidePeerSettingsBar : TLRPCmessages_hidePeerSettingsBar


@end

#endif
