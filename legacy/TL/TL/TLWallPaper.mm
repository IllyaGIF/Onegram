#import "TLWallPaper.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLDocument.h"
#import "TLWallPaperSettings.h"

@implementation TLWallPaper


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

@implementation TLWallPaper$wallPaper : TLWallPaper


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xa437c3ed;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x29cac8ce;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLWallPaper$wallPaper *object = [[TLWallPaper$wallPaper alloc] init];
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.access_hash = metaObject->getInt64((int32_t)0x8f305224);
    object.slug = metaObject->getString((int32_t)0x72835c9d);
    object.document = metaObject->getObject((int32_t)0xf1465b5f);
    object.settings = metaObject->getObject((int32_t)0xb494353e);
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
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.flags;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x81915c23, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.access_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8f305224, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.slug;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x72835c9d, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.document;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xf1465b5f, value));
    }
    if (self.flags & (1 << 2))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.settings;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb494353e, value));
    }
}


@end

@implementation TLWallPaper$wallPaperSolid : TLWallPaper


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x63117f24;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x77a94375;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLWallPaper$wallPaperSolid *object = [[TLWallPaper$wallPaperSolid alloc] init];
    object.n_id = metaObject->getInt32((int32_t)0x7a5601fb);
    object.title = metaObject->getString((int32_t)0xcdebf414);
    object.bg_color = metaObject->getInt32((int32_t)0xa262f32b);
    object.color = metaObject->getInt32((int32_t)0xaee6bad0);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.n_id;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x7a5601fb, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.title;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xcdebf414, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.bg_color;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xa262f32b, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.color;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xaee6bad0, value));
    }
}


@end

@implementation TLWallPaper$wallPaperNoFile : TLWallPaper


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xe0804116;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xb1fc5ee8;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLWallPaper$wallPaperNoFile *object = [[TLWallPaper$wallPaperNoFile alloc] init];
    object.n_id = metaObject->getInt64((int32_t)0x7a5601fb);
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.settings = metaObject->getObject((int32_t)0xb494353e);
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
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.flags;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x81915c23, value));
    }
    if (self.flags & (1 << 2))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.settings;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xb494353e, value));
    }
}


@end
