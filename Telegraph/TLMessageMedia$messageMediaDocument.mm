#import "TLMessageMedia$messageMediaDocument.h"

#import "TLMetaClassStore.h"


static id OGCompatReadNextObject(NSInputStream *is, id<TLSerializationEnvironment> environment, NSError **error)
{
    int32_t objectSignature = [is readInt32];
    return TLMetaClassStore::constructObject(is, objectSignature, environment, nil, error);
}

static bool OGCompatFailed(NSError **error)
{
    return error != nil && *error != nil;
}

@implementation TLMessageMedia$messageMediaDocument

- (int32_t)TLconstructorName {
    return -1;
}

- (int32_t)TLconstructorSignature {
    return 0;
}

- (void)TLserialize:(NSOutputStream *)__unused os
{
    assert(false);
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLMessageMedia$messageMediaDocument *result = [[TLMessageMedia$messageMediaDocument alloc] init];
    
    int32_t flags = [is readInt32];
    result.flags = flags;
    bool layer181 = signature == (int32_t)0x4cf4d72d;
    bool layer189 = signature == (int32_t)0x52d8ccd9;
    
    if (flags & (1 << 0)) {
        result.document = OGCompatReadNextObject(is, environment, error);
        if (OGCompatFailed(error))
            return nil;
    }
    
    if (flags & (1 << 1)) {
        [is readString];
    }
    
    if (layer181 && (flags & (1 << 5))) {
        id document = OGCompatReadNextObject(is, environment, error);
        if (OGCompatFailed(error))
            return nil;
        if (document != nil)
            result.alt_documents = @[document];
    }
    
    if (layer189 && (flags & (1 << 5))) {
        if ([is readInt32] != (int32_t)0x1cb5c415)
            return nil;
        int32_t count = [is readInt32];
        if (count < 0)
            return nil;
        NSMutableArray *documents = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)count];
        for (int32_t i = 0; i < count; i++) {
            id document = OGCompatReadNextObject(is, environment, error);
            if (OGCompatFailed(error))
                return nil;
            if (document != nil)
                [documents addObject:document];
        }
        result.alt_documents = documents;
    }
    
    if (layer189 && (flags & (1 << 9))) {
        OGCompatReadNextObject(is, environment, error);
        if (OGCompatFailed(error))
            return nil;
    }
    
    if (layer189 && (flags & (1 << 10))) {
        [is readInt32];
    }
    
    if (flags & (1 << 2)) {
        result.ttl_seconds = [is readInt32];
    }
    
    return result;
}

@end
