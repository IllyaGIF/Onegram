#import "OGTelegramGroupAdapter.h"
#import "Models/OGMemberItem.h"

static OGTelegramGroupAdapterMapper OGTelegramGroupAdapterCurrentMapper = nil;

@implementation OGTelegramGroupAdapter
+ (void)setMapper:(OGTelegramGroupAdapterMapper)mapper
{
    @synchronized(self)
    {
        OGTelegramGroupAdapterCurrentMapper = [mapper copy];
    }
}

+ (OGMemberItem *)itemFromTelegramObject:(id)object
{
    if (object == nil)
        return nil;
    OGTelegramGroupAdapterMapper mapper = nil;
    @synchronized(self)
    {
        mapper = OGTelegramGroupAdapterCurrentMapper;
    }
    if (mapper == nil)
        return nil;
    return mapper(object);
}
@end
