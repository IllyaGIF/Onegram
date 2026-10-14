#import "TLBotInlineMessage.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"


@implementation TLBotInlineMessage


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

@implementation TLBotInlineMessage$botInlineMessageMeta : TLBotInlineMessage


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x7303dd9c;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x707d30ef;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TLBotInlineMessage$botInlineMessageMeta *object = [[TLBotInlineMessage$botInlineMessageMeta alloc] init];
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

