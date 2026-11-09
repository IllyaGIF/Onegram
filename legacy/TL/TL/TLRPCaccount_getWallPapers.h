#ifndef TG_LEGACY_TL_TLRPCACCOUNT_GETWALLPAPERS_H
#define TG_LEGACY_TL_TLRPCACCOUNT_GETWALLPAPERS_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLaccount_WallPapers;

@interface TLRPCaccount_getWallPapers : TLMetaRpc

@property (nonatomic) int64_t n_hash;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCaccount_getWallPapers$account_getWallPapers : TLRPCaccount_getWallPapers


@end

#endif
