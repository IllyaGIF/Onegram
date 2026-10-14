#import "TLRPCcontacts_getContactIDs.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "NSArray_int.h"

@implementation TLRPCcontacts_getContactIDs


- (Class)responseClass
{
    return [NSArray class];
}

- (int)impliedResponseSignature
{
    return (int)0xa03855ae;
}

- (int)layerVersion
{
    return 8;
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

@implementation TLRPCcontacts_getContactIDs$contacts_getContactIDs : TLRPCcontacts_getContactIDs


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x13dc911d;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x444b3c08;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TLRPCcontacts_getContactIDs$contacts_getContactIDs *object = [[TLRPCcontacts_getContactIDs$contacts_getContactIDs alloc] init];
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

