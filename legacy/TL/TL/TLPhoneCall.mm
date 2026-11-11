#import "TLPhoneCall.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLPhoneCallProtocol.h"
#import "TLPhoneCallDiscardReason.h"
#import "TLPhoneConnection.h"

struct OGCompatCallHeader
{
    int32_t flags;
    int64_t callId;
    int64_t accessHash;
    int32_t date;
    int64_t adminId;
    int64_t participantId;
    TLPhoneCallProtocol *protocol;
};

static OGCompatCallHeader OGCompatReadCallHeader(std::tr1::shared_ptr<TLMetaObject> metaObject)
{
    OGCompatCallHeader header;
    header.flags = metaObject->getInt32((int32_t)0x81915c23);
    header.callId = metaObject->getInt64((int32_t)0x7a5601fb);
    header.accessHash = metaObject->getInt64((int32_t)0x8f305224);
    header.date = metaObject->getInt32((int32_t)0xb76958ba);
    header.adminId = metaObject->getInt64((int32_t)0xdf3d1ee7);
    header.participantId = metaObject->getInt64((int32_t)0x9abadf01);
    header.protocol = metaObject->getObject((int32_t)0xd45aa5f2);
    return header;
}

static NSArray *OGCompatConnectionVector(std::tr1::shared_ptr<TLMetaObject> metaObject)
{
    if (!metaObject || !metaObject->values)
        return nil;
    
    for (std::vector<TLConstructedValue>::iterator it = metaObject->values->begin(); it != metaObject->values->end(); ++it)
    {
        if (it->type != TLConstructedValueTypeVector || ![it->nativeObject isKindOfClass:[NSArray class]])
            continue;
        
        for (id item in (NSArray *)it->nativeObject)
        {
            if ([item isKindOfClass:[TLPhoneConnection class]])
                return (NSArray *)it->nativeObject;
        }
    }
    
    return nil;
}

@implementation TLPhoneCall


- (int32_t)TLconstructorSignature
{
    return 0;
}

- (int32_t)TLconstructorName
{
    return 0;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    OGCompatCallHeader header = OGCompatReadCallHeader(metaObject);
    
    NSData *gAHash = metaObject->getBytes((int32_t)0xb39b1140);
    if (gAHash != nil)
    {
        TLPhoneCall$phoneCallRequested *requested = [[TLPhoneCall$phoneCallRequested alloc] init];
        requested.flags = header.flags;
        requested.n_id = header.callId;
        requested.access_hash = header.accessHash;
        requested.date = header.date;
        requested.admin_id = header.adminId;
        requested.participant_id = header.participantId;
        requested.g_a_hash = gAHash;
        requested.protocol = header.protocol;
        return requested;
    }
    
    NSData *gB = metaObject->getBytes((int32_t)0x5643e234);
    if (gB != nil)
    {
        TLPhoneCall$phoneCallAccepted *accepted = [[TLPhoneCall$phoneCallAccepted alloc] init];
        accepted.flags = header.flags;
        accepted.n_id = header.callId;
        accepted.access_hash = header.accessHash;
        accepted.date = header.date;
        accepted.admin_id = header.adminId;
        accepted.participant_id = header.participantId;
        accepted.g_b = gB;
        accepted.protocol = header.protocol;
        return accepted;
    }
    
    NSData *gAOrB = metaObject->getBytes((int32_t)0x817dfd4a);
    if (gAOrB != nil)
    {
        TLPhoneCall$phoneCall *established = [[TLPhoneCall$phoneCall alloc] init];
        established.flags = header.flags;
        established.n_id = header.callId;
        established.access_hash = header.accessHash;
        established.date = header.date;
        established.admin_id = header.adminId;
        established.participant_id = header.participantId;
        established.g_a_or_b = gAOrB;
        established.key_fingerprint = metaObject->getInt64((int32_t)0x3633de43);
        established.protocol = header.protocol;
        established.connection = metaObject->getObject((int32_t)0xb5b12f84);
        established.alternative_connections = metaObject->getArray((int32_t)0x39153642);
        established.connections = OGCompatConnectionVector(metaObject);
        established.start_date = metaObject->getInt32((int32_t)0x1c46df41);
        return established;
    }
    
    id reason = metaObject->getObject((int32_t)0x3405f57);
    int32_t duration = metaObject->getInt32((int32_t)0xac00f752);
    if (reason != nil || duration != 0 || (header.flags & 0xf) != 0)
    {
        TLPhoneCall$phoneCallDiscardedMeta *discarded = [[TLPhoneCall$phoneCallDiscardedMeta alloc] init];
        discarded.flags = header.flags;
        discarded.n_id = header.callId;
        discarded.reason = reason;
        discarded.duration = duration;
        return discarded;
    }
    
    TLPhoneCall$phoneCallWaitingMeta *waiting = [[TLPhoneCall$phoneCallWaitingMeta alloc] init];
    waiting.flags = header.flags;
    waiting.n_id = header.callId;
    waiting.access_hash = header.accessHash;
    waiting.date = header.date;
    waiting.admin_id = header.adminId;
    waiting.participant_id = header.participantId;
    waiting.protocol = header.protocol;
    waiting.receive_date = metaObject->getInt32((int32_t)0xeedcab88);
    return waiting;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

@implementation TLPhoneCall$phoneCallEmpty : TLPhoneCall


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x5366c915;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xc76344fc;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLPhoneCall$phoneCallEmpty *object = [[TLPhoneCall$phoneCallEmpty alloc] init];
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.n_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x7a5601fb, value));
    }
}


@end

@implementation TLPhoneCall$phoneCallWaitingMeta : TLPhoneCall


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xc5226f17;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xdc7555ab;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLPhoneCall$phoneCallWaitingMeta *object = [[TLPhoneCall$phoneCallWaitingMeta alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    object.access_hash = metaObject->getInt64((int32_t)0x8f305224);
    object.date = metaObject->getInt32((int32_t)0xb76958ba);
    object.admin_id = metaObject->getInt64((int32_t)0xdf3d1ee7);
    object.participant_id = metaObject->getInt64((int32_t)0x9abadf01);
    object.protocol = metaObject->getObject((int32_t)0xd45aa5f2);
    object.receive_date = metaObject->getInt32((int32_t)0xeedcab88);
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
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.n_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x7a5601fb, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.access_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8f305224, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.date;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb76958ba, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.admin_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xdf3d1ee7, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.participant_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9abadf01, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.protocol;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xd45aa5f2, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.receive_date;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xeedcab88, value));
    }
}


@end

@implementation TLPhoneCall$phoneCallRequested : TLPhoneCall


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x14b0ed0c;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x9627ce57;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLPhoneCall$phoneCallRequested *object = [[TLPhoneCall$phoneCallRequested alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    object.access_hash = metaObject->getInt64((int32_t)0x8f305224);
    object.date = metaObject->getInt32((int32_t)0xb76958ba);
    object.admin_id = metaObject->getInt64((int32_t)0xdf3d1ee7);
    object.participant_id = metaObject->getInt64((int32_t)0x9abadf01);
    object.g_a_hash = metaObject->getBytes((int32_t)0xb39b1140);
    object.protocol = metaObject->getObject((int32_t)0xd45aa5f2);
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
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.n_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x7a5601fb, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.access_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8f305224, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.date;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb76958ba, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.admin_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xdf3d1ee7, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.participant_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9abadf01, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeBytes;
        value.nativeObject = self.g_a_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb39b1140, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.protocol;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xd45aa5f2, value));
    }
}


@end

@implementation TLPhoneCall$phoneCallDiscardedMeta : TLPhoneCall


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xc9d59add;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xf01017df;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLPhoneCall$phoneCallDiscardedMeta *object = [[TLPhoneCall$phoneCallDiscardedMeta alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    object.reason = metaObject->getObject((int32_t)0x3405f57);
    object.duration = metaObject->getInt32((int32_t)0xac00f752);
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
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.n_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x7a5601fb, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.reason;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x3405f57, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.duration;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xac00f752, value));
    }
}


@end

@implementation TLPhoneCall$phoneCallAccepted : TLPhoneCall


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x3660c311;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xd149f2bd;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLPhoneCall$phoneCallAccepted *object = [[TLPhoneCall$phoneCallAccepted alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    object.access_hash = metaObject->getInt64((int32_t)0x8f305224);
    object.date = metaObject->getInt32((int32_t)0xb76958ba);
    object.admin_id = metaObject->getInt64((int32_t)0xdf3d1ee7);
    object.participant_id = metaObject->getInt64((int32_t)0x9abadf01);
    object.g_b = metaObject->getBytes((int32_t)0x5643e234);
    object.protocol = metaObject->getObject((int32_t)0xd45aa5f2);
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
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.n_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x7a5601fb, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.access_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8f305224, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.date;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb76958ba, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.admin_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xdf3d1ee7, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.participant_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9abadf01, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeBytes;
        value.nativeObject = self.g_b;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x5643e234, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.protocol;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xd45aa5f2, value));
    }
}


@end

@implementation TLPhoneCall$phoneCall : TLPhoneCall


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x30535af5;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xc9908a15;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLPhoneCall$phoneCall *object = [[TLPhoneCall$phoneCall alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    object.access_hash = metaObject->getInt64((int32_t)0x8f305224);
    object.date = metaObject->getInt32((int32_t)0xb76958ba);
    object.admin_id = metaObject->getInt64((int32_t)0xdf3d1ee7);
    object.participant_id = metaObject->getInt64((int32_t)0x9abadf01);
    object.g_a_or_b = metaObject->getBytes((int32_t)0x817dfd4a);
    object.key_fingerprint = metaObject->getInt64((int32_t)0x3633de43);
    object.protocol = metaObject->getObject((int32_t)0xd45aa5f2);
    object.connection = metaObject->getObject((int32_t)0xb5b12f84);
    object.alternative_connections = metaObject->getArray((int32_t)0x39153642);
    object.connections = OGCompatConnectionVector(metaObject);
    object.start_date = metaObject->getInt32((int32_t)0x1c46df41);
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
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.n_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x7a5601fb, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.access_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8f305224, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.date;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb76958ba, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.admin_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xdf3d1ee7, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.participant_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9abadf01, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeBytes;
        value.nativeObject = self.g_a_or_b;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x817dfd4a, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.key_fingerprint;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x3633de43, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.protocol;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xd45aa5f2, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.connection;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb5b12f84, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeVector;
        value.nativeObject = self.alternative_connections;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x39153642, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.start_date;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x1c46df41, value));
    }
}


@end
