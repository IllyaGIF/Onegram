#import "OGTelegramCallAdapter.h"
#import "Models/OGCallItem.h"

static OGTelegramCallAdapterMapper OGTelegramCallAdapterCurrentMapper = nil;

@implementation OGTelegramCallAdapter
+ (void)setMapper:(OGTelegramCallAdapterMapper)mapper
{
    @synchronized(self)
    {
        OGTelegramCallAdapterCurrentMapper = [mapper copy];
    }
}

+ (OGCallItem *)itemFromTelegramObject:(id)object
{
    if (object == nil)
        return nil;
    OGTelegramCallAdapterMapper mapper = nil;
    @synchronized(self)
    {
        mapper = OGTelegramCallAdapterCurrentMapper;
    }
    if (mapper == nil)
        return nil;
    return mapper(object);
}
@end
