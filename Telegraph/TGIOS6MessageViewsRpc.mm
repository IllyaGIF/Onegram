#import "TGIOS6MessageViewsRpc.h"

#import "TLMetaClassStore.h"
#import "TLInputPeer.h"
#import "NSInputStream+TL.h"
#import "NSOutputStream+TL.h"
#import "TLMessage$modernMessage.h"

static NSError *TGIOS6MessageViewsError(NSInteger code, NSString *description)
{
    return [[NSError alloc] initWithDomain:@"TGIOS6MessageViews" code:code userInfo:@{NSLocalizedDescriptionKey: description}];
}

static NSArray *TGIOS6MessageViewsReadObjectVector(NSInputStream *is, __autoreleasing NSError **error)
{
    bool failed = false;
    int32_t vectorSignature = [is readInt32:&failed];
    if (failed || vectorSignature != (int32_t)0x1cb5c415)
    {
        if (error != NULL)
            *error = TGIOS6MessageViewsError(1, @"Invalid TL vector");
        return nil;
    }

    int32_t count = [is readInt32:&failed];
    if (failed || count < 0 || count > 100000)
    {
        if (error != NULL)
            *error = TGIOS6MessageViewsError(2, @"Invalid TL vector count");
        return nil;
    }

    NSMutableArray *objects = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)count];
    for (int32_t i = 0; i < count; i++)
    {
        int32_t signature = [is readInt32:&failed];
        if (failed)
        {
            if (error != NULL)
                *error = TGIOS6MessageViewsError(3, @"Unexpected end of TL vector");
            return nil;
        }

        id object = TLMetaClassStore::constructObject(is, signature, nil, nil, error);
        if (error != NULL && *error != nil)
            return nil;
        if (object != nil)
            [objects addObject:object];
    }
    return objects;
}

@implementation TGIOS6MessageViewsRpc

- (int32_t)TLconstructorSignature { return (int32_t)0x5784d3e1; }
- (int32_t)TLconstructorName { return -1; }
- (Class)responseClass { return [NSDictionary class]; }
- (int)impliedResponseSignature { return 0; }
- (int)layerVersion { return 181; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }

- (void)TLserialize:(NSOutputStream *)os
{
    TLMetaClassStore::serializeObject(os, self.peer, true);
    [os writeInt32:(int32_t)0x1cb5c415];
    [os writeInt32:(int32_t)self.messageIds.count];
    for (NSNumber *messageId in self.messageIds)
        [os writeInt32:[messageId intValue]];
    [os writeInt32:self.increment ? (int32_t)0x997275b5 : (int32_t)0xbc799737];
}

+ (NSDictionary *)parseResponseFromStream:(NSInputStream *)is signature:(int32_t)signature error:(__autoreleasing NSError **)error
{
    if (signature != (int32_t)0xb6c4f543)
    {
        if (error != NULL)
            *error = TGIOS6MessageViewsError(4, [[NSString alloc] initWithFormat:@"Unexpected messages.MessageViews 0x%08x", signature]);
        return nil;
    }

    bool failed = false;
    int32_t vectorSignature = [is readInt32:&failed];
    int32_t count = failed ? 0 : [is readInt32:&failed];
    if (failed || vectorSignature != (int32_t)0x1cb5c415 || count < 0 || count > 100000)
    {
        if (error != NULL)
            *error = TGIOS6MessageViewsError(5, @"Invalid MessageViews vector");
        return nil;
    }

    NSMutableArray *views = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)count];
    for (int32_t i = 0; i < count; i++)
    {
        int32_t viewsSignature = [is readInt32:&failed];
        int32_t flags = failed ? 0 : [is readInt32:&failed];
        if (failed || viewsSignature != (int32_t)0x455b853d)
        {
            if (error != NULL)
                *error = TGIOS6MessageViewsError(6, [[NSString alloc] initWithFormat:@"Unexpected MessageViews 0x%08x", viewsSignature]);
            return nil;
        }

        NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
        if (flags & (1 << 0))
            item[@"views"] = @([is readInt32:&failed]);
        if (flags & (1 << 1))
            item[@"forwards"] = @([is readInt32:&failed]);
        if (failed)
        {
            if (error != NULL)
                *error = TGIOS6MessageViewsError(7, @"Unexpected end of MessageViews");
            return nil;
        }
        if (flags & (1 << 2))
        {
            NSDictionary *replies = [TLMessage$modernMessage readMessageRepliesFromStream:is error:error];
            if (error != NULL && *error != nil)
                return nil;
            if (replies != nil)
                item[@"replies"] = replies;
        }
        [views addObject:item];
    }

    NSArray *chats = TGIOS6MessageViewsReadObjectVector(is, error);
    if (chats == nil)
        return nil;
    NSArray *users = TGIOS6MessageViewsReadObjectVector(is, error);
    if (users == nil)
        return nil;

    return @{
        @"views": views,
        @"chats": chats,
        @"users": users
    };
}

@end
