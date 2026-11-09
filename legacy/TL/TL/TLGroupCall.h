#ifndef TG_LEGACY_TL_TLGROUPCALL_H
#define TG_LEGACY_TL_TLGROUPCALL_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLPeer;

@interface TLGroupCall : NSObject <TLObject>


@end

@interface TLGroupCall$groupCall : TLGroupCall

@property (nonatomic) int32_t flags;
@property (nonatomic) int64_t n_id;
@property (nonatomic) int64_t access_hash;
@property (nonatomic) int32_t participants_count;
@property (nonatomic, retain) NSString *title;
@property (nonatomic) int32_t stream_dc_id;
@property (nonatomic) int32_t record_start_date;
@property (nonatomic) int32_t schedule_date;
@property (nonatomic) int32_t unmuted_video_count;
@property (nonatomic) int32_t unmuted_video_limit;
@property (nonatomic) int32_t version;
@property (nonatomic, retain) NSString *invite_link;
@property (nonatomic) int64_t send_paid_messages_stars;
@property (nonatomic, retain) TLPeer *default_send_as;

@end

@interface TLGroupCall$groupCallDiscarded : TLGroupCall

@property (nonatomic) int64_t n_id;
@property (nonatomic) int64_t access_hash;
@property (nonatomic) int32_t duration;

@end

#endif
