#ifndef TG_LEGACY_TL_TLRPCMESSAGES_EDITCHATABOUT_H
#define TG_LEGACY_TL_TLRPCMESSAGES_EDITCHATABOUT_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputPeer;

@interface TLRPCmessages_editChatAbout : TLMetaRpc

@property (nonatomic, retain) TLInputPeer *peer;
@property (nonatomic, retain) NSString *about;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCmessages_editChatAbout$messages_editChatAbout : TLRPCmessages_editChatAbout


@end

#endif
