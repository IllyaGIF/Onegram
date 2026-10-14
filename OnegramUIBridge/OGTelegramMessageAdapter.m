#import "OGTelegramMessageAdapter.h"
#import "Models/OGMessageItem.h"

static OGTelegramMessageAdapterMapper OGTelegramMessageAdapterCurrentMapper = nil;

@implementation OGTelegramMessageAdapter
+ (void)setMapper:(OGTelegramMessageAdapterMapper)mapper
{
    @synchronized(self)
    {
        OGTelegramMessageAdapterCurrentMapper = [mapper copy];
    }
}

+ (OGMessageItem *)itemFromTelegramObject:(id)object
{
    if (object == nil)
        return nil;
    OGTelegramMessageAdapterMapper mapper = nil;
    @synchronized(self)
    {
        mapper = OGTelegramMessageAdapterCurrentMapper;
    }
    if (mapper == nil)
        return nil;
    return mapper(object);
}
@end
