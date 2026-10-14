#import "TLWebPage$webPageExternal.h"

#import "TLMetaClassStore.h"


@implementation TLWebPage$webPageExternal

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLWebPage$webPageExternal serialization not supported");
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLWebPage$webPageExternal *result = [[TLWebPage$webPageExternal alloc] init];
    
    int32_t flags = [is readInt32];
    
    result.flags = flags;
    
    result.url = [is readString];
    result.display_url = [is readString];
    
    if (flags & (1 << 0)) {
        result.type = [is readString];
    }
    
    if (flags & (1 << 1)) {
        result.title = [is readString];
    }
    
    if (flags & (1 << 2)) {
        result.n_description = [is readString];
    }
    
    if (flags & (1 << 3)) {
        result.thumb_url = [is readString];
    }
    
    if (flags & (1 << 4)) {
        result.contentUrl = [is readString];
    }
    
    if (flags & (1 << 4)) {
        result.contentType = [is readString];
    }
    
    if (flags & (1 << 5)) {
        result.w = [is readInt32];
        result.h = [is readInt32];
    }
    
    if (flags & (1 << 6)) {
        result.duration = [is readInt32];
    }
    
    return result;
}

@end
