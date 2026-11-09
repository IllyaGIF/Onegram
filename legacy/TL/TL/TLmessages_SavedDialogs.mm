#import "TLmessages_SavedDialogs.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"


@implementation TLmessages_SavedDialogs


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

@implementation TLmessages_SavedDialogs$messages_savedDialogs : TLmessages_SavedDialogs


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xf83ae221;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x586f90e0;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLmessages_SavedDialogs$messages_savedDialogs *object = [[TLmessages_SavedDialogs$messages_savedDialogs alloc] init];
    object.dialogs = metaObject->getArray((int32_t)0x708be67);
    object.messages = metaObject->getArray((int32_t)0x8c97b94f);
    object.chats = metaObject->getArray((int32_t)0x4240ad02);
    object.users = metaObject->getArray((int32_t)0x933e5ff3);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeVector;
        value.nativeObject = self.dialogs;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x708be67, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeVector;
        value.nativeObject = self.messages;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8c97b94f, value));
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

@implementation TLmessages_SavedDialogs$messages_savedDialogsSlice : TLmessages_SavedDialogs


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x44ba9dd9;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x1c4b899d;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLmessages_SavedDialogs$messages_savedDialogsSlice *object = [[TLmessages_SavedDialogs$messages_savedDialogsSlice alloc] init];
    object.count = metaObject->getInt32((int32_t)0x5fa6aa74);
    object.dialogs = metaObject->getArray((int32_t)0x708be67);
    object.messages = metaObject->getArray((int32_t)0x8c97b94f);
    object.chats = metaObject->getArray((int32_t)0x4240ad02);
    object.users = metaObject->getArray((int32_t)0x933e5ff3);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.count;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x5fa6aa74, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeVector;
        value.nativeObject = self.dialogs;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x708be67, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeVector;
        value.nativeObject = self.messages;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x8c97b94f, value));
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

@implementation TLmessages_SavedDialogs$messages_savedDialogsNotModified : TLmessages_SavedDialogs


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xc01f6fe8;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x1049b875;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLmessages_SavedDialogs$messages_savedDialogsNotModified *object = [[TLmessages_SavedDialogs$messages_savedDialogsNotModified alloc] init];
    object.count = metaObject->getInt32((int32_t)0x5fa6aa74);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt32;
        value.primitive.int32Value = self.count;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x5fa6aa74, value));
    }
}


@end
