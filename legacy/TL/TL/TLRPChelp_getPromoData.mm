#import "TLRPChelp_getPromoData.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLhelp_PromoData.h"

@implementation TLRPChelp_getPromoData


- (Class)responseClass
{
    return [TLhelp_PromoData class];
}

- (int)impliedResponseSignature
{
    return 0;
}

- (int)layerVersion
{
    return 228;
}

- (int32_t)TLconstructorSignature
{
    return 0;
}

- (int32_t)TLconstructorName
{
    return 0;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    return nil;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

@implementation TLRPChelp_getPromoData$help_getPromoData : TLRPChelp_getPromoData


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xc0977421;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x8ade739c;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TLRPChelp_getPromoData$help_getPromoData *object = [[TLRPChelp_getPromoData$help_getPromoData alloc] init];
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

