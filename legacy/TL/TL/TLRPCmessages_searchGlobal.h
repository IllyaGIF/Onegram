#ifndef TG_LEGACY_TL_TLRPCMESSAGES_SEARCHGLOBAL_H
#define TG_LEGACY_TL_TLRPCMESSAGES_SEARCHGLOBAL_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputChannel;
@class TLInputPeer;
@class TLMessagesFilter;
@class TLmessages_Messages;

@interface TLRPCmessages_searchGlobal : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic) int32_t folder_id;
@property (nonatomic, retain) TLInputChannel *community;
@property (nonatomic, retain) NSString *q;
@property (nonatomic, retain) TLMessagesFilter *filter;
@property (nonatomic) int32_t min_date;
@property (nonatomic) int32_t max_date;
@property (nonatomic) int32_t offset_rate;
@property (nonatomic, retain) TLInputPeer *offset_peer;
@property (nonatomic) int32_t offset_id;
@property (nonatomic) int32_t limit;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCmessages_searchGlobal$messages_searchGlobal : TLRPCmessages_searchGlobal


@end

#endif
