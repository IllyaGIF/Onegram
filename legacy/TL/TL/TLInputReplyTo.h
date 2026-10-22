#ifndef TG_LEGACY_TL_TLINPUTREPLYTO_H
#define TG_LEGACY_TL_TLINPUTREPLYTO_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputPeer;

@interface TLInputReplyTo : NSObject <TLObject>


@end

@interface TLInputReplyTo$inputReplyToMessage : TLInputReplyTo

@property (nonatomic) int32_t flags;
@property (nonatomic) int32_t reply_to_msg_id;
@property (nonatomic) int32_t top_msg_id;
@property (nonatomic, retain) TLInputPeer *reply_to_peer_id;
@property (nonatomic, retain) NSString *quote_text;
@property (nonatomic, retain) NSArray *quote_entities;
@property (nonatomic) int32_t quote_offset;
@property (nonatomic, retain) TLInputPeer *monoforum_peer_id;
@property (nonatomic) int32_t todo_item_id;
@property (nonatomic, retain) NSData *poll_option;

@end

#endif
