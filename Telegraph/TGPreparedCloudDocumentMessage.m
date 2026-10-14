#import "TGPreparedCloudDocumentMessage.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

static NSURL *TGCloudDocumentURLFromData(NSData *data)
{
    SEL selector = NSSelectorFromString(@"URLByResolvingBookmarkData:options:relativeToURL:bookmarkDataIsStale:error:");
    if ([[NSURL class] respondsToSelector:selector])
    {
        BOOL stale = false;
        id (*function)(id, SEL, NSData *, NSUInteger, NSURL *, BOOL *, NSError **) = (id (*)(id, SEL, NSData *, NSUInteger, NSURL *, BOOL *, NSError **))[[NSURL class] methodForSelector:selector];
        if (function != NULL)
        {
            NSURL *url = function([NSURL class], selector, data, 0, nil, &stale, NULL);
            if (url != nil)
                return url;
        }
    }
    NSString *value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *prefix = @"onegram-url:";
    if ([value hasPrefix:prefix])
        return [NSURL URLWithString:[value substringFromIndex:prefix.length]];
    return nil;
}

static NSData *TGCloudDocumentDataFromURL(NSURL *url)
{
    SEL selector = NSSelectorFromString(@"bookmarkDataWithOptions:includingResourceValuesForKeys:relativeToURL:error:");
    if ([url respondsToSelector:selector])
    {
        id (*function)(id, SEL, NSUInteger, NSArray *, NSURL *, NSError **) = (id (*)(id, SEL, NSUInteger, NSArray *, NSURL *, NSError **))[url methodForSelector:selector];
        if (function != NULL)
        {
            NSData *data = function(url, selector, 1UL << 10, nil, nil, NULL);
            if (data != nil)
                return data;
        }
    }
    NSString *value = [@"onegram-url:" stringByAppendingString:url.absoluteString ?: @""];
    return [value dataUsingEncoding:NSUTF8StringEncoding];
}

@implementation TGPreparedCloudDocumentMessage

- (instancetype)initWithDocumentUrl:(NSURL *)documentUrl localDocumentId:(int64_t)localDocumentId mimeType:(NSString *)mimeType size:(int)size thumbnailInfo:(TGImageInfo *)thumbnailInfo attributes:(NSArray *)attributes replyMessage:(TGMessage *)replyMessage replyMarkup:(TGReplyMarkupAttachment *)replyMarkup
{
    self = [super init];
    if (self != nil)
    {
        _documentUrl = documentUrl;
        _localDocumentId = localDocumentId;
        _attributes = attributes;
        _mimeType = mimeType;
        _size = size;
        _thumbnailInfo = thumbnailInfo;
        self.replyMessage = replyMessage;
        self.replyMarkup = replyMarkup;
    }
    return self;
}

- (TGMessage *)message
{
    TGMessage *message = [[TGMessage alloc] init];
    message.mid = self.mid;
    message.date = self.date;
    message.isBroadcast = self.isBroadcast;
    message.messageLifetime = self.messageLifetime;
    
    NSMutableArray *attachments = [[NSMutableArray alloc] init];
    
    TGDocumentMediaAttachment *documentAttachment = [[TGDocumentMediaAttachment alloc] init];
    documentAttachment.localDocumentId = _localDocumentId;
    documentAttachment.size = _size;
    documentAttachment.attributes = _attributes;
    documentAttachment.mimeType = _mimeType;
    documentAttachment.thumbnailInfo = _thumbnailInfo;
    
    [attachments addObject:documentAttachment];
    
    if (self.replyMessage != nil)
    {
        TGReplyMessageMediaAttachment *replyMedia = [[TGReplyMessageMediaAttachment alloc] init];
        replyMedia.replyMessageId = self.replyMessage.mid;
        replyMedia.replyMessage = self.replyMessage;
        [attachments addObject:replyMedia];
    }
    
    if (self.replyMarkup != nil) {
        [attachments addObject:self.replyMarkup];
    }
    
    message.mediaAttachments = attachments;
    message.contentProperties = @{@"cloudDocumentUrl": [[TGCloudDocumentUrlBookmark alloc] initWithDocumentUrl:_documentUrl]};
    
    return message;
}

@end

@implementation TGCloudDocumentUrlBookmark

- (instancetype)initWithDocumentUrl:(NSURL *)documentUrl
{
    self = [super init];
    if (self != nil)
    {
        _documentUrl = documentUrl;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    NSData *bookmarkData = [coder decodeDataCorCKey:[@"bookmarkData" UTF8String]];
    
    return [self initWithDocumentUrl:TGCloudDocumentURLFromData(bookmarkData)];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    NSData *bookmarkData = TGCloudDocumentDataFromURL(_documentUrl);
    [coder encodeData:bookmarkData forCKey:[@"bookmarkData" UTF8String]];
}

@end
