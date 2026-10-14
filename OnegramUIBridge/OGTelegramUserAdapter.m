#import "OGTelegramUserAdapter.h"
#import "Models/OGUserItem.h"

static OGTelegramUserAdapterMapper OGTelegramUserAdapterCurrentMapper = nil;

@implementation OGTelegramUserAdapter
+ (void)setMapper:(OGTelegramUserAdapterMapper)mapper
{
    @synchronized(self)
    {
        OGTelegramUserAdapterCurrentMapper = [mapper copy];
    }
}

+ (OGUserItem *)itemFromTelegramObject:(id)object
{
    if (object == nil)
        return nil;
    OGTelegramUserAdapterMapper mapper = nil;
    @synchronized(self)
    {
        mapper = OGTelegramUserAdapterCurrentMapper;
    }
    if (mapper == nil)
        return nil;
    return mapper(object);
}
@end
