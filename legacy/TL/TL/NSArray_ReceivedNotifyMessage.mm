#import "NSArray_ReceivedNotifyMessage.h"

#import "../NSInputStream+TL.h"
#import "../NSOutputStream+TL.h"


@implementation NSArray_ReceivedNotifyMessage


- (int32_t)TLconstructorSignature
{
    return (int32_t)0xa76738ed;
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

- (id)TLvectorConstruct
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [array TLtagConstructorName:(int32_t)0xa76738ed];
    return array;
}


@end

