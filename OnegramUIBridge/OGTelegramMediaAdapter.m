#import "OGTelegramMediaAdapter.h"
#import "Models/OGMediaItem.h"

static OGTelegramMediaAdapterMapper OGTelegramMediaAdapterCurrentMapper = nil;

@implementation OGTelegramMediaAdapter
+ (void)setMapper:(OGTelegramMediaAdapterMapper)mapper
{
    @synchronized(self)
    {
        OGTelegramMediaAdapterCurrentMapper = [mapper copy];
    }
}

+ (OGMediaItem *)itemFromTelegramObject:(id)object
{
    if (object == nil)
        return nil;
    OGTelegramMediaAdapterMapper mapper = nil;
    @synchronized(self)
    {
        mapper = OGTelegramMediaAdapterCurrentMapper;
    }
    if (mapper == nil)
        return nil;
    return mapper(object);
}
@end
