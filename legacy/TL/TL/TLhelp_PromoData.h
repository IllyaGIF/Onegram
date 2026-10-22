#ifndef TG_LEGACY_TL_TLHELP_PROMODATA_H
#define TG_LEGACY_TL_TLHELP_PROMODATA_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLPeer;
@class TLPendingSuggestion;

@interface TLhelp_PromoData : NSObject <TLObject>


@end

@interface TLhelp_PromoData$help_promoDataEmpty : TLhelp_PromoData

@property (nonatomic) int32_t expires;

@end

@interface TLhelp_PromoData$help_promoData : TLhelp_PromoData

@property (nonatomic) int32_t flags;
@property (nonatomic) int32_t expires;
@property (nonatomic, retain) TLPeer *peer;
@property (nonatomic, retain) NSString *psa_type;
@property (nonatomic, retain) NSString *psa_message;
@property (nonatomic, retain) NSArray *pending_suggestions;
@property (nonatomic, retain) NSArray *dismissed_suggestions;
@property (nonatomic, retain) TLPendingSuggestion *custom_pending_suggestion;
@property (nonatomic, retain) NSArray *chats;
@property (nonatomic, retain) NSArray *users;

@end

#endif
