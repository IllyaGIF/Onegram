#import "TLRPClangpack_getLangPack.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"

#import "TLLangPackDifference.h"

@implementation TLRPClangpack_getLangPack


- (Class)responseClass
{
    return [TLLangPackDifference class];
}

- (int)impliedResponseSignature
{
    return (int)0xf385c1f6;
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

@implementation TLRPClangpack_getLangPack$langpack_getLangPack : TLRPClangpack_getLangPack


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xf2f2330a;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0x2810501d;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)metaObject
{
    TLRPClangpack_getLangPack$langpack_getLangPack *object = [[TLRPClangpack_getLangPack$langpack_getLangPack alloc] init];
    object.lang_pack = metaObject->getString((int32_t)0x7579bab3);
    object.lang_code = metaObject->getString((int32_t)0x2ccfcaf3);
    return object;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)values
{
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.lang_pack;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x7579bab3, value));
    }
    {
        TLConstructedValue value;
        value.type = TLConstructedValueTypeString;
        value.nativeObject = self.lang_code;
        values->insert(std::pair<int32_t, TLConstructedValue>((int32_t)0x2ccfcaf3, value));
    }
}


@end

