#import "TLInputFileLocation.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"


static int64_t OGCompatUnsignedPeerId(int64_t peerId)
{
    return peerId < 0 ? (int64_t)(uint32_t)(int32_t)peerId : peerId;
}

static void OGCompatWriteThumbnailLocation(NSOutputStream *os, int64_t objectId, int64_t accessHash, NSData *fileReference, NSString *thumbSize)
{
    [os writeInt64:objectId];
    [os writeInt64:accessHash];
    [os writeBytes:fileReference ?: [NSData data]];
    [os writeString:thumbSize ?: @""];
}

@implementation TLInputFileLocation


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

@implementation TLInputFileLocation$inputFileLocation : TLInputFileLocation


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xdfdaabe1;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xcab26024;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLInputFileLocation$inputFileLocation *object = [[TLInputFileLocation$inputFileLocation alloc] init];
    object.volume_id = metaObject->getInt64((int32_t)0xdfa67416);
    object.local_id = metaObject->getInt32((int32_t)0x1a9ce92a);
    object.secret = metaObject->getInt64((int32_t)0x6706b4b7);
    object.file_reference = metaObject->getBytes((int32_t)0x8bad663c);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.volume_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xdfa67416, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.local_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x1a9ce92a, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.secret;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x6706b4b7, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeBytes;
        value.nativeObject = self.file_reference;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8bad663c, value));
    }
}


@end

@implementation TLInputFileLocation$inputPeerPhotoFileLocation : TLInputFileLocation


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x37257e99;
}

- (int32_t)TLconstructorName
{
    return -1;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    return nil;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}

- (void)TLserialize:(NSOutputStream *)os
{
    [os writeInt32:self.big ? 1 : 0];
    if (self.peer_type == 2)
    {
        [os writeInt32:(int32_t)0x35a95cb9];
        [os writeInt64:self.peer_id < 0 ? -self.peer_id : self.peer_id];
    }
    else
    {
        bool isChannel = self.peer_type == 3;
        [os writeInt32:isChannel ? (int32_t)0x27bcbbfc : (int32_t)0xdde8a54c];
        [os writeInt64:OGCompatUnsignedPeerId(self.peer_id)];
        [os writeInt64:self.access_hash];
    }
    [os writeInt64:self.photo_id];
}


@end

@implementation TLInputFileLocation$inputEncryptedFileLocation : TLInputFileLocation


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xf5235d55;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xeabc984c;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLInputFileLocation$inputEncryptedFileLocation *object = [[TLInputFileLocation$inputEncryptedFileLocation alloc] init];
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    object.access_hash = metaObject->getInt64((int32_t)0x8f305224);
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
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.access_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8f305224, value));
    }
}


@end

@implementation TLInputFileLocation$inputPhotoFileLocation : TLInputFileLocation


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x40181ffe;
}

- (int32_t)TLconstructorName
{
    return -1;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLInputFileLocation$inputPhotoFileLocation *object = [[TLInputFileLocation$inputPhotoFileLocation alloc] init];
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    object.access_hash = metaObject->getInt64((int32_t)0x8f305224);
    object.file_reference = metaObject->getBytes((int32_t)0x8bad663c);
    object.thumb_size = metaObject->getString((int32_t)0x9ef60cc0);
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
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.access_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8f305224, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeBytes;
        value.nativeObject = self.file_reference ?: [NSData data];
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8bad663c, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.thumb_size ?: @"";
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9ef60cc0, value));
    }
}

- (void)TLserialize:(NSOutputStream *)os
{
    OGCompatWriteThumbnailLocation(os, self.n_id, self.access_hash, self.file_reference, self.thumb_size);
}


@end

@implementation TLInputFileLocation$inputDocumentFileLocation : TLInputFileLocation


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xbad07584;
}

- (int32_t)TLconstructorName
{
    return -1;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLInputFileLocation$inputDocumentFileLocation *object = [[TLInputFileLocation$inputDocumentFileLocation alloc] init];
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    object.access_hash = metaObject->getInt64((int32_t)0x8f305224);
    object.file_reference = metaObject->getBytes((int32_t)0x8bad663c);
    object.thumb_size = metaObject->getString((int32_t)0x9ef60cc0);
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
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.access_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8f305224, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeBytes;
        value.nativeObject = self.file_reference ?: [NSData data];
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8bad663c, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.thumb_size ?: @"";
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9ef60cc0, value));
    }
}

- (void)TLserialize:(NSOutputStream *)os
{
    OGCompatWriteThumbnailLocation(os, self.n_id, self.access_hash, self.file_reference, self.thumb_size);
}


@end

@implementation TLInputFileLocation$inputSecureFileLocation : TLInputFileLocation


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xcbc7ee28;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x0da7ad9c;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLInputFileLocation$inputSecureFileLocation *object = [[TLInputFileLocation$inputSecureFileLocation alloc] init];
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    object.access_hash = metaObject->getInt64((int32_t)0x8f305224);
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
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.access_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8f305224, value));
    }
}


@end
