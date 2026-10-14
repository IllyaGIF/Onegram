#import "OGTelegramDialogAdapter.h"
#import "Models/OGDialogItem.h"

static OGTelegramDialogAdapterMapper OGTelegramDialogAdapterCurrentMapper = nil;

@implementation OGTelegramDialogAdapter
+ (void)setMapper:(OGTelegramDialogAdapterMapper)mapper
{
    @synchronized(self)
    {
        OGTelegramDialogAdapterCurrentMapper = [mapper copy];
    }
}

+ (OGDialogItem *)itemFromTelegramObject:(id)object
{
    if (object == nil)
        return nil;
    OGTelegramDialogAdapterMapper mapper = nil;
    @synchronized(self)
    {
        mapper = OGTelegramDialogAdapterCurrentMapper;
    }
    if (mapper == nil)
        return nil;
    return mapper(object);
}
@end
