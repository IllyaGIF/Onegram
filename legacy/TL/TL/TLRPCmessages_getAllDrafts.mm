#import "TLRPCmessages_getAllDrafts.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLUpdates.h"

@implementation TLRPCmessages_getAllDrafts


- (Class)responseClass
{
    return [TLUpdates class];
}

- (int)impliedResponseSignature
{
    return 0;
}

- (int)layerVersion
{
    return 53;
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

@implementation TLRPCmessages_getAllDrafts$messages_getAllDrafts : TLRPCmessages_getAllDrafts


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x6a3f8d65;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x7c339028;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TLRPCmessages_getAllDrafts$messages_getAllDrafts *object = [[TLRPCmessages_getAllDrafts$messages_getAllDrafts alloc] init];
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

