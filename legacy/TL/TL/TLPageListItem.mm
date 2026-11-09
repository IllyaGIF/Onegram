#import "TLPageListItem.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLRichText.h"

@implementation TLPageListItem


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

@implementation TLPageListItem$pageListItemText : TLPageListItem


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x2f58683c;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x1908c612;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLPageListItem$pageListItemText *object = [[TLPageListItem$pageListItemText alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.text = metaObject->getObject((int32_t)0x94f1580d);
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
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = self.text;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x94f1580d, value));
    }
}


@end

@implementation TLPageListItem$pageListItemBlocks : TLPageListItem


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x63ca67aa;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xf0bb87f5;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLPageListItem$pageListItemBlocks *object = [[TLPageListItem$pageListItemBlocks alloc] init];
    object.flags = metaObject->getInt32((int32_t)0x81915c23);
    object.blocks = metaObject->getArray((int32_t)0x277ee766);
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
        value.type = TLConstructedValueTypeVector;
        value.nativeObject = self.blocks;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x277ee766, value));
    }
}


@end
