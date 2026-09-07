/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGTLSerialization.h"
#import "IOS6NotificationProbe.h"

#import "TL/TLMetaScheme.h"
#import "TLMetaClassStore.h"
#import "TLMetaSchemeData.h"

#import "TLMessageContainer.h"
#import "TLFutureSalts.h"
#import "TLRpcResult.h"

#import "NSInputStream+TL.h"
#import "NSOutputStream+TL.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTDatacenterAddress.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTDatacenterSaltInfo.h"

#import "TLMsgsAck$msgs_ack_manual.h"

#import "TLDcOption$modernDcOption.h"

@interface TGTLSerializationEnvironment : NSObject <TLSerializationEnvironment>

@property (nonatomic, copy) int32_t (^responseParsingBlock)(int64_t, bool *);

@end

@implementation TGTLSerializationEnvironment

- (instancetype)initWithResponseParsingBlock:(int32_t (^)(int64_t, bool *))responseParsingBlock
{
    self = [super init];
    if (self != nil)
    {
        self.responseParsingBlock = responseParsingBlock;
    }
    return self;
}

- (TLSerializationContext *)serializationContextForRpcResult:(int64_t)requestMessageId
{
    if (_responseParsingBlock != nil)
    {
        bool found = false;
        int32_t signature = _responseParsingBlock(requestMessageId, &found);
        if (found)
        {
            TLSerializationContext *context = [[TLSerializationContext alloc] init];
            context.impliedSignature = signature;
            return context;
        }
    }
    
    return nil;
}

@end

@interface TGTLSerialization ()

@end

static void TGLogTLParseError(id error)
{
    if (![error isKindOfClass:[NSError class]])
    {
        IOS6NotificationProbe(@"PARSER", @"tl_error class=%@", NSStringFromClass([error class]));
        TGLog(@"TL parse error class=%@", NSStringFromClass([error class]));
        return;
    }

    NSError *typedError = (NSError *)error;
    IOS6NotificationProbe(@"PARSER", @"tl_error domain=%@ code=%ld", typedError.domain ?: @"TL", (long)typedError.code);
    TGLog(@"TL parse error domain=%@ code=%ld description=%@", typedError.domain ?: @"TL", (long)typedError.code, typedError.localizedDescription ?: @"");
}

@implementation TGTLSerialization

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {

            TLRegisterClasses();

            TLMetaClassStore::registerObjectClass([[TLMessageContainer$msg_container alloc] init]);
            TLMetaClassStore::registerObjectClass([[TLFutureSalts$future_salts alloc] init]);

            TLScheme *metaScheme = TLgetMetaScheme();
            
            TLMetaClassStore::mergeScheme(metaScheme);
        });
    }
    return self;
}

+ (NSData *)serializeMessage:(id)message
{
    NSOutputStream *os = [[NSOutputStream alloc] initToMemory];
    [os open];
    TLMetaClassStore::serializeObject(os, message, true);
    NSData *data = [os currentBytes];
    [os close];
    
    return data;
}

- (id)parseMessage:(NSData *)data
{
    NSInputStream *is = [[NSInputStream alloc] initWithData:data];
    [is open];
    
    bool readError = false;
    int32_t topSignature = [is readInt32:&readError];
    if (readError)
    {
        [is close];
        return nil;
    }
    
    __autoreleasing NSError *error = nil;
    id topObject = TLMetaClassStore::constructObject(is, topSignature, nil, nil, &error);
    if (error != nil)
        TGLogTLParseError(error);
    
    [is close];
    
    return topObject;
}

static NSArray *TGIOS6ReadObjectVector(NSInputStream *is, NSError **error)
{
    bool failed = false;
    int32_t vectorSignature = [is readInt32:&failed];
    if (failed || vectorSignature != (int32_t)0x1cb5c415)
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:@"TGIOS6Discussion" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid TL vector"}];
        return nil;
    }

    int32_t count = [is readInt32:&failed];
    if (failed || count < 0 || count > 100000)
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:@"TGIOS6Discussion" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid TL vector count"}];
        return nil;
    }

    NSMutableArray *objects = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)count];
    for (int32_t i = 0; i < count; i++)
    {
        int32_t signature = [is readInt32:&failed];
        if (failed)
            break;

        id object = TLMetaClassStore::constructObject(is, signature, nil, nil, error);
        if (error != NULL && *error != nil)
            return nil;
        if (object != nil)
            [objects addObject:object];
    }

    if (failed)
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:@"TGIOS6Discussion" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Unexpected end of TL vector"}];
        return nil;
    }
    return objects;
}

static NSDictionary *TGIOS6ParseDiscussionMessage(NSInputStream *is, int32_t topSignature, NSError **error)
{
    if (topSignature != (int32_t)0xa6341782)
        return nil;

    bool failed = false;
    int32_t flags = [is readInt32:&failed];
    if (failed)
        return nil;

    NSArray *messages = TGIOS6ReadObjectVector(is, error);
    if (messages == nil)
        return nil;

    int32_t maxId = 0;
    int32_t readInboxMaxId = 0;
    int32_t readOutboxMaxId = 0;
    if (flags & (1 << 0))
        maxId = [is readInt32:&failed];
    if (flags & (1 << 1))
        readInboxMaxId = [is readInt32:&failed];
    if (flags & (1 << 2))
        readOutboxMaxId = [is readInt32:&failed];
    int32_t unreadCount = [is readInt32:&failed];
    if (failed)
        return nil;

    NSArray *chats = TGIOS6ReadObjectVector(is, error);
    if (chats == nil)
        return nil;
    NSArray *users = TGIOS6ReadObjectVector(is, error);
    if (users == nil)
        return nil;

    NSLog(@"COMMENTS discussion.parse flags=0x%08x messages=%d chats=%d users=%d max=%d unread=%d",
          flags, (int)messages.count, (int)chats.count, (int)users.count, maxId, unreadCount);

    return @{
        @"messages": messages,
        @"chats": chats,
        @"users": users,
        @"maxId": @(maxId),
        @"readInboxMaxId": @(readInboxMaxId),
        @"readOutboxMaxId": @(readOutboxMaxId),
        @"unreadCount": @(unreadCount)
    };
}

+ (id)parseResponse:(NSData *)data request:(TLMetaRpc *)request
{
    NSInputStream *is = [[NSInputStream alloc] initWithData:data];
    [is open];
    
    bool readError = false;
    int32_t topSignature = [is readInt32:&readError];
    if (readError)
    {
        [is close];
        return nil;
    }

    if ([NSStringFromClass([request class]) isEqualToString:@"TGIOS6GetDiscussionMessageRpc"])
    {
        __autoreleasing NSError *discussionError = nil;
        NSDictionary *discussion = TGIOS6ParseDiscussionMessage(is, topSignature, &discussionError);
        if (discussion != nil)
        {
            [is close];
            return discussion;
        }
        if (discussionError != nil)
        {
            TGLogTLParseError(discussionError);
            NSLog(@"COMMENTS discussion.parse.error top=0x%08x description=%@", topSignature, discussionError.localizedDescription ?: @"");
            [is close];
            return nil;
        }
    }
    
    __autoreleasing NSError *error = nil;
    TLSerializationContext *context = [[TLSerializationContext alloc] init];
    context.impliedSignature = request.impliedResponseSignature;
    id topObject = TLMetaClassStore::constructObject(is, topSignature, nil, context, &error);
    if (error != nil)
    {
        TGLogTLParseError(error);
        NSLog(@"TLRESPONSE top=0x%08x request=%@ implied=0x%08x description=%@", topSignature, NSStringFromClass([request class]), request.impliedResponseSignature, error.localizedDescription ?: @"");
    }
    
    [is close];
    
    return topObject;
}

+ (NSArray *)parseProfileSavedMusicResponse:(NSData *)data
{
    if (data.length < 8)
        return nil;

    NSInputStream *is = [[NSInputStream alloc] initWithData:data];
    [is open];

    bool failed = false;
    int32_t signature = [is readInt32:&failed];
    if (failed)
    {
        [is close];
        return nil;
    }

    if (signature == (int32_t)0xe3878aa4)
    {
        int32_t count = [is readInt32:&failed];
        [is close];
        return failed ? nil : @[];
    }

    if (signature != (int32_t)0x34a2f297)
    {
        [is close];
        TGLog(@"PROFILEMUSIC layer213 unexpected response=0x%08x bytes=%lu", signature, (unsigned long)data.length);
        return nil;
    }

    int32_t totalCount = [is readInt32:&failed];
    int32_t vectorSignature = [is readInt32:&failed];
    int32_t vectorCount = [is readInt32:&failed];
    if (failed || vectorSignature != TL_UNIVERSAL_VECTOR_CONSTRUCTOR || vectorCount < 0 || vectorCount > 10000)
    {
        [is close];
        TGLog(@"PROFILEMUSIC layer213 invalid vector sig=0x%08x count=%d total=%d", vectorSignature, vectorCount, totalCount);
        return nil;
    }

    NSMutableArray *documents = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)vectorCount];
    for (int32_t i = 0; i < vectorCount; i++)
    {
        int32_t documentSignature = [is readInt32:&failed];
        if (failed)
            break;

        __autoreleasing NSError *error = nil;
        id document = TLMetaClassStore::constructObject(is, documentSignature, nil, nil, &error);
        if (document == nil || error != nil)
        {
            if (error != nil)
                TGLogTLParseError(error);
            TGLog(@"PROFILEMUSIC layer213 document parse failed index=%d sig=0x%08x", i, documentSignature);
            failed = true;
            break;
        }

        if ([document isKindOfClass:[TLDocument class]])
            [documents addObject:document];
    }

    [is close];

    if (failed)
        return nil;

    return documents;
}

- (MTExportAuthorizationResponseParser)exportAuthorization:(int32_t)datacenterId data:(__autoreleasing NSData **)data
{
    TLRPCauth_exportAuthorization$auth_exportAuthorization *exportAuthorization = [[TLRPCauth_exportAuthorization$auth_exportAuthorization alloc] init];
    exportAuthorization.dc_id = datacenterId;
    
    if (data)
        *data = [TGTLSerialization serializeMessage:exportAuthorization];
    
    return ^id (NSData *response)
    {
        NSInputStream *is = [[NSInputStream alloc] initWithData:response];
        [is open];
        bool failed = false;
        int32_t signature = [is readInt32:&failed];
        if (!failed && signature == (int32_t)0xb434e2b8)
        {
            int64_t authorizationId = [is readInt64:&failed];
            NSData *authorizationBytes = failed ? nil : [is readBytes:&failed];
            [is close];
            if (!failed && authorizationBytes != nil)
            {
                TGLog(@"AUTH exportedAuthorization modern id=%lld bytes=%d", authorizationId, (int)authorizationBytes.length);
                return [[MTExportedAuthorizationData alloc] initWithAuthorizationBytes:authorizationBytes authorizationId:authorizationId];
            }
            TGLog(@"AUTH exportedAuthorization modern parse failed");
            return nil;
        }
        [is close];
        
        id result = [self parseMessage:response];
        if ([result isKindOfClass:[TLauth_ExportedAuthorization class]])
        {
            return [[MTExportedAuthorizationData alloc] initWithAuthorizationBytes:((TLauth_ExportedAuthorization *)result).bytes authorizationId:((TLauth_ExportedAuthorization *)result).n_id];
        }
        return nil;
    };
}

- (NSData *)importAuthorization:(int64_t)authId bytes:(NSData *)bytes
{
    NSOutputStream *os = [[NSOutputStream alloc] initToMemory];
    [os open];
    [os writeInt32:(int32_t)0xa57a7dad];
    [os writeInt64:authId];
    [os writeBytes:bytes ?: [NSData data]];
    NSData *result = [os currentBytes];
    [os close];
    TGLog(@"AUTH importAuthorization modern id=%lld bytes=%d", authId, (int)bytes.length);
    return result;
}

- (MTRequestDatacenterAddressListParser)requestDatacenterAddressWithData:(__autoreleasing NSData **)data
{
    NSData *getConfigData = [TGTLSerialization serializeMessage:[[TLRPChelp_getConfig$help_getConfig alloc] init]];
    if (data)
        *data = getConfigData;
    
    return ^MTDatacenterAddressListData *(NSData *response)
    {
        id result = [self parseMessage:response];
        if ([result isKindOfClass:[TLConfig class]])
        {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            
            for (TLDcOption$modernDcOption *dcOption in ((TLConfig *)result).dc_options)
            {
                NSMutableArray *array = dict[@(dcOption.n_id)];
                if (array == nil) {
                    array = [[NSMutableArray alloc] init];
                    dict[@(dcOption.n_id)] = array;
                }
                
                MTDatacenterAddress *address = [[MTDatacenterAddress alloc] initWithIp:dcOption.ip_address port:(uint16_t)dcOption.port preferForMedia:dcOption.flags & (1 << 1) restrictToTcp:dcOption.flags & (1 << 2) cdn:dcOption.flags & (1 << 3)  preferForProxy:dcOption.flags & (1 << 4) secret:dcOption.secret];
                [array addObject:address];
            }
            
            return [[MTDatacenterAddressListData alloc] initWithAddressList:dict];
        }
        return nil;
    };
}

- (MTRequestNoopParser)requestNoop:(__autoreleasing NSData **)data
{
    NSData *testData = [TGTLSerialization serializeMessage:[[TLRPChelp_test$help_test alloc] init]];
    if (data)
        *data = testData;
    
    return ^id (NSData *response)
    {
        __unused id result = [self parseMessage:response];
        return @(result != nil);
    };
}

- (NSUInteger)currentLayer
{
    return 181;
}

@end
