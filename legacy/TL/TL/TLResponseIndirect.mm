#import "TLResponseIndirect.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"


@implementation TLResponseIndirect


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

@implementation TLResponseIndirect$responseIndirect : TLResponseIndirect


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x2194f56e;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x81ee5457;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TLResponseIndirect$responseIndirect *object = [[TLResponseIndirect$responseIndirect alloc] init];
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

