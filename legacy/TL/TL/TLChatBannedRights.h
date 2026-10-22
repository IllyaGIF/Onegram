#ifndef TG_LEGACY_TL_TLCHATBANNEDRIGHTS_H
#define TG_LEGACY_TL_TLCHATBANNEDRIGHTS_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"


@interface TLChatBannedRights : NSObject <TLObject>

@property (nonatomic) int32_t flags;
@property (nonatomic) int32_t until_date;

@end

@interface TLChatBannedRights$chatBannedRights : TLChatBannedRights


@end

#endif
