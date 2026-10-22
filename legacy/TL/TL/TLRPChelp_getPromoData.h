#ifndef TG_LEGACY_TL_TLRPCHELP_GETPROMODATA_H
#define TG_LEGACY_TL_TLRPCHELP_GETPROMODATA_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLhelp_PromoData;

@interface TLRPChelp_getPromoData : TLMetaRpc


- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPChelp_getPromoData$help_getPromoData : TLRPChelp_getPromoData


@end

#endif
