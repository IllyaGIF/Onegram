#import "TLaccount_WallPapers.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"


@implementation TLaccount_WallPapers


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

@implementation TLaccount_WallPapers$account_wallPapers : TLaccount_WallPapers


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xcdc3858c;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x22679dd3;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLaccount_WallPapers$account_wallPapers *object = [[TLaccount_WallPapers$account_wallPapers alloc] init];
    object.n_hash = metaObject->getInt64((int32_t)0xc152e470);
    object.wallpapers = metaObject->getArray((int32_t)0xa9a3c91e);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypePrimitiveInt64;
        value.primitive.int64Value = self.n_hash;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xc152e470, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeVector;
        value.nativeObject = self.wallpapers;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0xa9a3c91e, value));
    }
}


@end

@implementation TLaccount_WallPapers$account_wallPapersNotModified : TLaccount_WallPapers


- (int32_t)TLconstructorSignature
{
    return (int32_t)0x1c199183;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xf9be2933;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    TLaccount_WallPapers$account_wallPapersNotModified *object = [[TLaccount_WallPapers$account_wallPapersNotModified alloc] init];
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}


@end
