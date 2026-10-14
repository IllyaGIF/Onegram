#import "TLRPCcontacts_resetSaved.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"


@implementation TLRPCcontacts_resetSaved


- (Class)responseClass
{
    return [NSNumber class];
}

- (int)impliedResponseSignature
{
    return 0;
}

- (int)layerVersion
{
    return 71;
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

@implementation TLRPCcontacts_resetSaved$contacts_resetSaved : TLRPCcontacts_resetSaved


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x879537f1;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xa4c6a25b;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TLRPCcontacts_resetSaved$contacts_resetSaved *object = [[TLRPCcontacts_resetSaved$contacts_resetSaved alloc] init];
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

