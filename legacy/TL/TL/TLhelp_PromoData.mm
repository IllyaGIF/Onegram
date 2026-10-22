#import "TLhelp_PromoData.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLPeer.h"

@implementation TLhelp_PromoData


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

@implementation TLhelp_PromoData$help_promoDataEmpty : TLhelp_PromoData


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x98f6ac75;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xef297b1f;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLhelp_PromoData$help_promoDataEmpty *object = [[TLhelp_PromoData$help_promoDataEmpty alloc] init];
    object.expires = metaObject->getInt32((int32_t)0x4743fb6b);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.expires;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x4743fb6b, value));
    }
}


@end

@implementation TLhelp_PromoData$help_promoData : TLhelp_PromoData


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x8a4d87a;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x342f3742;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLhelp_PromoData$help_promoData *object = [[TLhelp_PromoData$help_promoData alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.expires = metaObject->getInt32((int32_t)0x4743fb6b);
    object.peer = metaObject->getObject((int32_t)0x9344c37d);
    object.psa_type = metaObject->getString((int32_t)0x92938dd4);
    object.psa_message = metaObject->getString((int32_t)0xbf2dfaa9);
    object.pending_suggestions = metaObject->getArray((int32_t)0xfae8fba3);
    object.dismissed_suggestions = metaObject->getArray((int32_t)0x516a9e2a);
    object.custom_pending_suggestion = metaObject->getObject((int32_t)0xa8690817);
    object.chats = metaObject->getArray((int32_t)0x4240ad02);
    object.users = metaObject->getArray((int32_t)0x933e5ff3);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.flags;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x81915c23, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.expires;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x4743fb6b, value));
    }
    if (self.flags & (1 << 3))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.peer;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9344c37d, value));
    }
    if (self.flags & (1 << 1))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.psa_type;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x92938dd4, value));
    }
    if (self.flags & (1 << 2))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.psa_message;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xbf2dfaa9, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeVector;
        value.nativeObject = self.pending_suggestions;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xfae8fba3, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeVector;
        value.nativeObject = self.dismissed_suggestions;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x516a9e2a, value));
    }
    if (self.flags & (1 << 4))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.custom_pending_suggestion;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xa8690817, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeVector;
        value.nativeObject = self.chats;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x4240ad02, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeVector;
        value.nativeObject = self.users;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x933e5ff3, value));
    }
}


@end
