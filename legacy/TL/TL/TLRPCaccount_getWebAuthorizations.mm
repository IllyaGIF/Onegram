#import "TLRPCaccount_getWebAuthorizations.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLaccount_WebAuthorizations.h"

@implementation TLRPCaccount_getWebAuthorizations


- (Class)responseClass
{
    return [TLaccount_WebAuthorizations class];
}

- (int)impliedResponseSignature
{
    return (int)0xed56c9fc;
}

- (int)layerVersion
{
    return 76;
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

@implementation TLRPCaccount_getWebAuthorizations$account_getWebAuthorizations : TLRPCaccount_getWebAuthorizations


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x182e6d6f;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xb8b49554;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TLRPCaccount_getWebAuthorizations$account_getWebAuthorizations *object = [[TLRPCaccount_getWebAuthorizations$account_getWebAuthorizations alloc] init];
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end


