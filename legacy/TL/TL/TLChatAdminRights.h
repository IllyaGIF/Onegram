#ifndef TG_LEGACY_TL_TLCHATADMINRIGHTS_H
#define TG_LEGACY_TL_TLCHATADMINRIGHTS_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"


@interface TLChatAdminRights : NSObject <TLObject>

@property (nonatomic) int32_t flags;

@end

@interface TLChatAdminRights$chatAdminRights : TLChatAdminRights


@end

#endif
