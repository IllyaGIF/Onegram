#import "TLRPCchannels_getFeed.h"

#import "TL/TLMetaScheme.h"
#import "TLMetaClassStore.h"

#import "TLmessages_FeedMessages.h"


@implementation TLRPCchannels_getFeed

- (int32_t)TLconstructorSignature
{
    return 0xb90f450;
}

- (int32_t)TLconstructorName
{
    return -1;
}

- (Class)responseClass
{
    return [TLmessages_FeedMessages class];
}

- (int)impliedResponseSignature
{
    return 0;
}

- (int)layerVersion
{
    return 74;
}

- (void)TLserialize:(NSOutputStream *)os
{
    [os writeInt32:self.flags];
    
    [os writeInt32:self.feed_id];
    
    if (self.flags & (1 << 0)) {
        TLMetaClassStore::serializeObject(os, self.offset_position, true);
    }
    
    [os writeInt32:self.add_offset];
    [os writeInt32:self.limit];
    
    if (self.flags & (1 << 1)) {
        TLMetaClassStore::serializeObject(os, self.max_position, true);
    }
    
    if (self.flags & (1 << 2)) {
        TLMetaClassStore::serializeObject(os, self.min_position, true);
    }
    
    [os writeInt32:self.n_hash];
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TGLog(@"***** TLRPCchannels_getFeed deserialization not supported");
    return nil;
}

@end
