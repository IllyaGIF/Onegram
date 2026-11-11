#import "TGMusicPlayerItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGBotContextExternalResult.h"
#import "TGBotContextMediaResult.h"

@interface TGMusicPlayerItem () {
    bool _isVoice;
}

@end

@implementation TGMusicPlayerItem

+ (instancetype)og_compat_itemForMessage:(TGMessage *)message author:(TGUser *)author media:(id)media performer:(NSString *)performer title:(NSString *)title duration:(int32_t)duration voice:(bool)voice
{
    TGMusicPlayerItem *item = [[TGMusicPlayerItem alloc] initWithKey:@(message.mid) media:media peerId:message.cid author:author date:(int32_t)message.date performer:performer title:title duration:duration];
    item->_peerId = message.fromUid;
    item->_isVoice = voice;
    return item;
}

+ (instancetype)itemWithMessage:(TGMessage *)message author:(TGUser *)author
{
    TGDocumentMediaAttachment *document = nil;
    TGAudioMediaAttachment *voiceAttachment = nil;
    TGVideoMediaAttachment *roundAttachment = nil;
    
    for (id attachment in message.mediaAttachments)
    {
        if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]])
        {
            TGDocumentMediaAttachment *candidate = attachment;
            for (id attribute in candidate.attributes)
            {
                if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]])
                {
                    document = candidate;
                    break;
                }
            }
            if (document != nil)
                break;
        } else if ([attachment isKindOfClass:[TGAudioMediaAttachment class]]) {
            voiceAttachment = attachment;
        } else if ([attachment isKindOfClass:[TGWebPageMediaAttachment class]]) {
            TGWebPageMediaAttachment *webPage = attachment;
            document = webPage.document;
            if (document.originInfo == nil)
                document.originInfo = [TGMediaOriginInfo mediaOriginInfoWithFileReference:nil fileReferences:nil url:webPage.url];
            break;
        } else if ([attachment isKindOfClass:[TGVideoMediaAttachment class]] && ((TGVideoMediaAttachment *)attachment).roundMessage) {
            roundAttachment = attachment;
        }
    }
    
    if (document != nil) {
        if (document.originInfo == nil)
            document.originInfo = [TGMediaOriginInfo mediaOriginInfoWithFileReference:nil fileReferences:nil cid:message.cid mid:message.mid];
        
        for (id attribute in document.attributes)
        {
            if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]])
            {
                TGDocumentAttributeAudio *audio = attribute;
                return [self og_compat_itemForMessage:message author:author media:document performer:audio.performer title:audio.title duration:audio.duration voice:audio.isVoice];
            }
            else if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]] && ((TGDocumentAttributeVideo *)attribute).isRoundMessage)
            {
                return [self og_compat_itemForMessage:message author:author media:document performer:nil title:nil duration:((TGDocumentAttributeVideo *)attribute).duration voice:true];
            }
        }
    }
    
    if (voiceAttachment != nil)
        return [self og_compat_itemForMessage:message author:author media:voiceAttachment performer:nil title:nil duration:voiceAttachment.duration voice:true];
    
    if (roundAttachment != nil) {
        if (roundAttachment.originInfo == nil)
            roundAttachment.originInfo = [TGMediaOriginInfo mediaOriginInfoWithFileReference:nil fileReferences:nil cid:message.cid mid:message.mid];
        return [self og_compat_itemForMessage:message author:author media:roundAttachment performer:nil title:nil duration:roundAttachment.duration voice:true];
    }
    
    return nil;
}

+ (instancetype)itemWithBotContextResult:(TGBotContextResult *)result {
    if ([result isKindOfClass:[TGBotContextMediaResult class]]) {
        TGDocumentMediaAttachment *document = ((TGBotContextMediaResult *)result).document;
        if (document != nil) {
            for (id attribute in document.attributes) {
                if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]]) {
                    TGDocumentAttributeAudio *audio = attribute;
                    TGMusicPlayerItem *item = [[TGMusicPlayerItem alloc] initWithKey:result.resultId media:document peerId:0 author:nil date:0 performer:audio.performer title:audio.title duration:audio.duration];
                    item->_isVoice = ((TGDocumentAttributeAudio *)attribute).isVoice;
                    return item;
                }
            }
        }
    } else if ([result isKindOfClass:[TGBotContextExternalResult class]]) {
        TGBotContextExternalResult *externalResult = (TGBotContextExternalResult *)result;
        NSArray *contentTypes = @[
            @"audio/mpeg",
            @"audio/ogg",
            @"audio/aac"
        ];
        if (([externalResult.type isEqualToString:@"audio"] || [externalResult.type isEqualToString:@"voice"]) && externalResult.content.mimeType != nil && [contentTypes containsObject:externalResult.content.mimeType]) {
            TGMusicPlayerItem *item  = [[TGMusicPlayerItem alloc] initWithKey:result.resultId media:result peerId:0 author:nil date:0 performer:externalResult.pageDescription title:externalResult.title duration:externalResult.duration];
            item->_isVoice = false;
            return item;
        }
    }

    return nil;
}

+ (instancetype)itemWithInstantDocument:(TGDocumentMediaAttachment *)document {
    for (id attribute in document.attributes)
    {
        if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]])
        {
            TGDocumentAttributeAudio *audio = attribute;
            TGMusicPlayerItem *item = [[TGMusicPlayerItem alloc] initWithKey:@(document.documentId) media:document peerId:0 author:nil date:0 performer:audio.performer title:audio.title duration:audio.duration];
            item->_isVoice = audio.isVoice;
            return item;
        }
    }
    return nil;
}

- (instancetype)initWithKey:(id<NSObject, NSCopying>)key media:(id)media peerId:(int64_t)peerId author:(TGUser *)author date:(int32_t)date performer:(NSString *)performer title:(NSString *)title duration:(int32_t)duration
{
    self = [super init];
    if (self != nil)
    {
        _key = key;
        _media = media;
        _conversationId = peerId;
        _author = author;
        _date = date;
        _performer = performer;
        _title = title;
        _duration = duration;
    }
    return self;
}

- (bool)isVoice {
    return _isVoice;
}

- (bool)isVideo {
    return [self.media isKindOfClass:[TGVideoMediaAttachment class]] || ([self.media isKindOfClass:[TGDocumentMediaAttachment class]] && ((TGDocumentMediaAttachment *)self.media).isRoundVideo);
}

- (TGImageInfo *)thumbnailInfo {
    if ([self.media isKindOfClass:[TGVideoMediaAttachment class]])
        return ((TGVideoMediaAttachment *)self.media).thumbnailInfo;
    return nil;
}

@end
