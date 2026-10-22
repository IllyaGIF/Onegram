#import "TLInputChatPhoto.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLInputFile.h"
#import "TLInputPhoto.h"

@implementation TLInputChatPhoto


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

@implementation TLInputChatPhoto$inputChatPhotoEmpty : TLInputChatPhoto


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x1ca48f57;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xa748307c;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TLInputChatPhoto$inputChatPhotoEmpty *object = [[TLInputChatPhoto$inputChatPhotoEmpty alloc] init];
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end

@implementation TLInputChatPhoto$inputChatUploadedPhoto : TLInputChatPhoto


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xbdcdaec0;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xfa544488;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLInputChatPhoto$inputChatUploadedPhoto *object = [[TLInputChatPhoto$inputChatUploadedPhoto alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
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
    if (self.flags & (1 << 3))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.video_emoji_markup;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xfd2a65a4, value));
    }
}


@end

@implementation TLInputChatPhoto$inputChatPhoto : TLInputChatPhoto


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x8953ad37;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x93b721ca;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLInputChatPhoto$inputChatPhoto *object = [[TLInputChatPhoto$inputChatPhoto alloc] init];
    object.n_id = metaObject->getObject((int32_t)0x7a5601fb);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.n_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x7a5601fb, value));
    }
}


@end

