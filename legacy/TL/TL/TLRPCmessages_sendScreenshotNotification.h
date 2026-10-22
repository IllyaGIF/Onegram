#ifndef TG_LEGACY_TL_TLRPCMESSAGES_SENDSCREENSHOTNOTIFICATION_H
#define TG_LEGACY_TL_TLRPCMESSAGES_SENDSCREENSHOTNOTIFICATION_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputPeer;
@class TLInputReplyTo;
@class TLUpdates;

@interface TLRPCmessages_sendScreenshotNotification : TLMetaRpc

@property (nonatomic, retain) TLInputPeer *peer;
@property (nonatomic, retain) TLInputReplyTo *reply_to;
@property (nonatomic) int64_t random_id;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCmessages_sendScreenshotNotification$messages_sendScreenshotNotification : TLRPCmessages_sendScreenshotNotification


@end

#endif
