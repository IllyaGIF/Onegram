#import "TLWallPaperSettings.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"


@implementation TLWallPaperSettings


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

@implementation TLWallPaperSettings$wallPaperSettings : TLWallPaperSettings


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x372efcd0;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x1f1ea79e;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLWallPaperSettings$wallPaperSettings *object = [[TLWallPaperSettings$wallPaperSettings alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.background_color = metaObject->getInt32((int32_t)0xa4317d18);
    object.second_background_color = metaObject->getInt32((int32_t)0x1d1adbe4);
    object.third_background_color = metaObject->getInt32((int32_t)0x8cf4bc59);
    object.fourth_background_color = metaObject->getInt32((int32_t)0x312f211a);
    object.intensity = metaObject->getInt32((int32_t)0x7c594696);
    object.rotation = metaObject->getInt32((int32_t)0x48401951);
    object.emoticon = metaObject->getString((int32_t)0x9458ad3a);
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
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.background_color;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xa4317d18, value));
    }
    if (self.flags & (1 << 4))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.second_background_color;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x1d1adbe4, value));
    }
    if (self.flags & (1 << 5))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.third_background_color;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8cf4bc59, value));
    }
    if (self.flags & (1 << 6))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.fourth_background_color;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x312f211a, value));
    }
    if (self.flags & (1 << 3))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.intensity;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x7c594696, value));
    }
    if (self.flags & (1 << 4))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.rotation;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x48401951, value));
    }
    if (self.flags & (1 << 7))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.emoticon;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9458ad3a, value));
    }
}


@end
