#import "TGCustomEmojiThumbnail.h"

#include <inttypes.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "TGTelegramNetworking.h"
#import "TGDocumentMediaAttachment+Telegraph.h"
#import "../legacy/TL/TLMetaRpc.h"
#import "../legacy/TL/NSOutputStream+TL.h"
#import "../legacy/TL/TL/TLDocument.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"

static const int32_t TGCustomEmojiVectorConstructor = (int32_t)0x1cb5c415;

@interface TGCustomEmojiDocumentsRequest : TLMetaRpc

@property (nonatomic, strong) NSArray *documentIds;

@end

@implementation TGCustomEmojiDocumentsRequest

- (Class)responseClass { return [NSArray class]; }
- (int)impliedResponseSignature { return TGCustomEmojiVectorConstructor; }
- (int)layerVersion { return 144; }
- (int32_t)TLconstructorSignature { return (int32_t)0xd9ab0f54; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }

- (void)TLserialize:(NSOutputStream *)os
{
    [os writeInt32:TGCustomEmojiVectorConstructor];
    [os writeInt32:(int32_t)_documentIds.count];
    for (NSNumber *documentId in _documentIds)
        [os writeInt64:documentId.longLongValue];
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error { return nil; }

@end

static NSCache *TGCustomEmojiUriCache(void)
{
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.countLimit = 512;
    });
    return cache;
}

static NSMutableDictionary *TGCustomEmojiPendingCompletions(void)
{
    static NSMutableDictionary *pending = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        pending = [[NSMutableDictionary alloc] init];
    });
    return pending;
}

NSString *TGCustomEmojiThumbnailUri(TGDocumentMediaAttachment *document)
{
    if (document.documentId == 0)
        return nil;

    TGMediaOriginInfo *originInfo = document.originInfo ?: [TGMediaOriginInfo mediaOriginInfoForDocumentAttachment:document];
    NSString *legacyThumbnailUri = [document.thumbnailInfo imageUrlForLargestSize:NULL];

    NSMutableString *uri = [[NSMutableString alloc] initWithString:@"sticker-preview://?"];
    [uri appendFormat:@"documentId=%" PRId64, document.documentId];
    [uri appendFormat:@"&accessHash=%" PRId64, document.accessHash];
    [uri appendFormat:@"&datacenterId=%" PRId32, document.datacenterId];
    if (originInfo != nil)
        [uri appendFormat:@"&origin_info=%@", [originInfo stringRepresentation]];
    if (legacyThumbnailUri.length != 0)
        [uri appendFormat:@"&legacyThumbnailUri=%@", [TGStringUtils stringByEscapingForURL:legacyThumbnailUri]];
    [uri appendFormat:@"&fileName=%@", [TGStringUtils stringByEscapingForURL:[document safeFileName]]];
    [uri appendFormat:@"&size=%d", document.size];
    if (document.mimeType.length != 0)
        [uri appendFormat:@"&mimeType=%@", [TGStringUtils stringByEscapingForURL:document.mimeType]];
    [uri appendString:@"&width=40&height=40&highQuality=1"];
    return uri;
}

void TGCustomEmojiRegisterThumbnailUri(int64_t documentId, NSString *thumbnailUri)
{
    if (documentId != 0 && thumbnailUri.length != 0)
        [TGCustomEmojiUriCache() setObject:thumbnailUri forKey:@(documentId)];
}

void TGCustomEmojiLoadThumbnail(int64_t documentId, void (^completion)(NSString *thumbnailUri))
{
    if (documentId == 0)
    {
        if (completion != nil)
            completion(nil);
        return;
    }

    NSCache *cache = TGCustomEmojiUriCache();
    NSNumber *key = @(documentId);

    NSString *cachedUri = [cache objectForKey:key];
    if (cachedUri.length != 0)
    {
        if (completion != nil)
            completion(cachedUri);
        return;
    }

    TGTelegramNetworking *networking = OGPlatformUsesConstrainedBackgroundExecution() ? [TGTelegramNetworking maybeInstance] : [TGTelegramNetworking instance];
    if (networking == nil)
    {
        if (completion != nil)
            completion(nil);
        return;
    }

    NSMutableDictionary *pending = TGCustomEmojiPendingCompletions();
    bool alreadyRequested = false;
    @synchronized(pending)
    {
        NSMutableArray *waiting = pending[key];
        alreadyRequested = waiting != nil;
        if (completion != nil)
        {
            if (waiting == nil)
            {
                waiting = [[NSMutableArray alloc] init];
                pending[key] = waiting;
            }
            [waiting addObject:[completion copy]];
        }
        else if (waiting == nil)
            pending[key] = [[NSMutableArray alloc] init];
    }

    if (alreadyRequested)
        return;

    TGCustomEmojiDocumentsRequest *request = [[TGCustomEmojiDocumentsRequest alloc] init];
    request.documentIds = @[ key ];
    [networking performRpc:request completionBlock:^(id result, __unused int64_t responseTime, MTRpcError *error)
    {
        NSString *thumbnailUri = nil;
        if (error == nil && [result isKindOfClass:[NSArray class]])
        {
            for (id documentDesc in (NSArray *)result)
            {
                if (![documentDesc isKindOfClass:[TLDocument class]])
                    continue;
                TGDocumentMediaAttachment *document = [[TGDocumentMediaAttachment alloc] initWithTelegraphDocumentDesc:documentDesc];
                if (document.documentId == documentId)
                {
                    thumbnailUri = TGCustomEmojiThumbnailUri(document);
                    break;
                }
            }
        }

        if (thumbnailUri.length != 0)
            [cache setObject:thumbnailUri forKey:key];

        NSArray *callbacks = nil;
        @synchronized(pending)
        {
            callbacks = [pending[key] copy];
            [pending removeObjectForKey:key];
        }

        dispatch_async(dispatch_get_main_queue(), ^
        {
            for (void (^callback)(NSString *) in callbacks)
                callback(thumbnailUri);
        });
    } progressBlock:nil requiresCompletion:true requestClass:TGRequestClassGeneric];
}
