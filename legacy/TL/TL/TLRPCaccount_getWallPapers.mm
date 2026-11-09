#import "TLRPCaccount_getWallPapers.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLaccount_WallPapers.h"

@implementation TLRPCaccount_getWallPapers


- (Class)responseClass
{
    return [TLaccount_WallPapers class];
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

@implementation TLRPCaccount_getWallPapers$account_getWallPapers : TLRPCaccount_getWallPapers


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x7967d36;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xc4047dc6;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPCaccount_getWallPapers$account_getWallPapers *object = [[TLRPCaccount_getWallPapers$account_getWallPapers alloc] init];
    object.n_hash = metaObject->getInt64((int32_t)0xc152e470);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.n_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xc152e470, value));
    }
}


@end
