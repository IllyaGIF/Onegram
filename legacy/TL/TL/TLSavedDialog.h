#ifndef TG_LEGACY_TL_TLSAVEDDIALOG_H
#define TG_LEGACY_TL_TLSAVEDDIALOG_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLPeer;
@class TLDraftMessage;

@interface TLSavedDialog : NSObject <TLObject>


@end

@interface TLSavedDialog$savedDialog : TLSavedDialog

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLPeer *peer;
@property (nonatomic) int32_t top_message;

@end

@interface TLSavedDialog$monoForumDialog : TLSavedDialog

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLPeer *peer;
@property (nonatomic) int32_t top_message;
@property (nonatomic) int32_t read_inbox_max_id;
@property (nonatomic) int32_t read_outbox_max_id;
@property (nonatomic) int32_t unread_count;
@property (nonatomic) int32_t unread_reactions_count;
@property (nonatomic, retain) TLDraftMessage *draft;

@end

#endif
