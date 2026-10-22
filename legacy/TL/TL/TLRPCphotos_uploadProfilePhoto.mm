#import "TLRPCphotos_uploadProfilePhoto.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLInputFile.h"
#import "TLInputUser.h"
#import "TLphotos_Photo.h"

@implementation TLRPCphotos_uploadProfilePhoto


- (Class)responseClass
{
    return [TLphotos_Photo class];
}

- (int)impliedResponseSignature
{
    return (int)0x20212ca8;
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

@implementation TLRPCphotos_uploadProfilePhoto$photos_uploadProfilePhoto : TLRPCphotos_uploadProfilePhoto


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x388a3b5;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xa5a4710;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPCphotos_uploadProfilePhoto$photos_uploadProfilePhoto *object = [[TLRPCphotos_uploadProfilePhoto$photos_uploadProfilePhoto alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.bot = metaObject->getObject((int32_t)0x5b476acc);
    object.file = metaObject->getObject((int32_t)0x3187ec9);
    object.video = metaObject->getObject((int32_t)0x2182fe3c);
    object.video_start_ts = metaObject->getDouble((int32_t)0xb3e89406);
    object.video_emoji_markup = metaObject->getObject((int32_t)0xfd2a65a4);
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
    if (self.flags & (1 << 5))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.bot;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x5b476acc, value));
    }
    if (self.flags & (1 << 0))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.file;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x3187ec9, value));
    }
    if (self.flags & (1 << 1))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.video;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x2182fe3c, value));
    }
    if (self.flags & (1 << 2))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveDouble;
        value.primitive.doubleValue = self.video_start_ts;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb3e89406, value));
    }
    if (self.flags & (1 << 4))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.video_emoji_markup;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xfd2a65a4, value));
    }
}


@end

