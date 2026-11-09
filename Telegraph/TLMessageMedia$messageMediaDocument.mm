#import "TLMessageMedia$messageMediaDocument.h"

#import "TLMetaClassStore.h"


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
    bool isLayer181MediaDocument = signature == (int32_t)0x4cf4d72d;
    result.flags = flags;
    
    if (flags & (1 << 0)) {
        int32_t signature = [is readInt32];
        result.document = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
        if (error != nil && *error != nil)
            return nil;
    }
    
    if (flags & (1 << 1)) {
        [is readString];
    }
    
    if (isLayer181MediaDocument && (flags & (1 << 5))) {
        int32_t signature = [is readInt32];
        id document = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
        if (error != nil && *error != nil)
            return nil;
        if (document != nil)
            result.alt_documents = @[document];
    }
    
    if (signature == (int32_t)0x52d8ccd9 && (flags & (1 << 5))) {
        int32_t vectorSignature = [is readInt32];
        if (vectorSignature != (int32_t)0x1cb5c415)
            return nil;
        int32_t count = [is readInt32];
        if (count < 0)
            return nil;
        NSMutableArray *documents = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)count];
        for (int32_t i = 0; i < count; i++) {
            int32_t documentSignature = [is readInt32];
            id document = TLMetaClassStore::constructObject(is, documentSignature, environment, nil, error);
            if (error != nil && *error != nil)
                return nil;
            if (document != nil)
                [documents addObject:document];
        }
        result.alt_documents = documents;
    }
    
    if (signature == (int32_t)0x52d8ccd9 && (flags & (1 << 9))) {
        int32_t signature = [is readInt32];
        TLMetaClassStore::constructObject(is, signature, environment, nil, error);
        if (error != nil && *error != nil)
            return nil;
    }
    
    if (signature == (int32_t)0x52d8ccd9 && (flags & (1 << 10))) {
        [is readInt32];
    }
    
    if (flags & (1 << 2)) {
        result.ttl_seconds = [is readInt32];
    }
    
    return result;
}

@end
