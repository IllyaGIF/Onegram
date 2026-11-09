#import "TLPageListOrderedItem.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLRichText.h"

@implementation TLPageListOrderedItem


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

@implementation TLPageListOrderedItem$pageListOrderedItemText : TLPageListOrderedItem


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x15031189;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x6e157512;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLPageListOrderedItem$pageListOrderedItemText *object = [[TLPageListOrderedItem$pageListOrderedItemText alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.num = metaObject->getString((int32_t)0x8d554573);
    object.text = metaObject->getObject((int32_t)0x94f1580d);
    object.value = metaObject->getInt32((int32_t)0xf348b8d4);
    object.n_type = metaObject->getString((int32_t)0x9211ab0a);
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
    if (self.flags & (1 << 2))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.num;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8d554573, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.text;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x94f1580d, value));
    }
    if (self.flags & (1 << 3))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.value;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xf348b8d4, value));
    }
    if (self.flags & (1 << 4))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.n_type;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9211ab0a, value));
    }
}


@end

@implementation TLPageListOrderedItem$pageListOrderedItemBlocks : TLPageListOrderedItem


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x8ff2d5f0;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xa0648b6f;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLPageListOrderedItem$pageListOrderedItemBlocks *object = [[TLPageListOrderedItem$pageListOrderedItemBlocks alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.num = metaObject->getString((int32_t)0x8d554573);
    object.blocks = metaObject->getArray((int32_t)0x277ee766);
    object.value = metaObject->getInt32((int32_t)0xf348b8d4);
    object.n_type = metaObject->getString((int32_t)0x9211ab0a);
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
    if (self.flags & (1 << 2))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.num;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8d554573, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeVector;
        value.nativeObject = self.blocks;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x277ee766, value));
    }
    if (self.flags & (1 << 3))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.value;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xf348b8d4, value));
    }
    if (self.flags & (1 << 4))
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.n_type;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x9211ab0a, value));
    }
}


@end
