#import "TLauth_SentCode.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"


@implementation TLauth_SentCode


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

@implementation TLauth_SentCode$auth_sentCodeMeta : TLauth_SentCode


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x9e7cd5b6;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xe2c5dc1d;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TLauth_SentCode$auth_sentCodeMeta *object = [[TLauth_SentCode$auth_sentCodeMeta alloc] init];
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

