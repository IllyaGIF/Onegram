#import "TGDocumentDownloadActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/ASQueue.h"

#import "TL/TLMetaScheme.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

#import "TGGenericModernConversationCompanion.h"
#import "TGFileDownloadActor.h"


#import "TGAppDelegate.h"

#import "TGDocumentHttpFileReference.h"

#import "TGRemoteHttpLocationSignal.h"

#import "TGTelegramNetworking.h"
#import "OGMediaFetchDescriptor+Telegraph.h"

@interface TGDocumentDownloadActor ()
{
    TGDocumentMediaAttachment *_documentAttachment;
    NSString *_storeFilePath;
    SDisposableSet *_disposables;
}

@end

@implementation TGDocumentDownloadActor

- (instancetype)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
        _disposables = [[SDisposableSet alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    [_disposables dispose];
}

+ (NSString *)genericPath
{
    return @"/tg/media/document/@";
}

- (void)prepare:(NSDictionary *)options
{
    [super prepare:options];
    
    self.requestQueueName = @"documentDownload";
}

- (void)execute:(NSDictionary *)options
{
    TGDocumentMediaAttachment *documentAttachment = options[@"documentAttachment"];
    _documentAttachment = documentAttachment;
    
    if (documentAttachment != nil)
    {
        NSString *storeFilePath = nil;
        OGMediaFetchDescriptor *descriptor = [OGMediaFetchDescriptor descriptorForDocument:documentAttachment publishPath:&storeFilePath];
        if (descriptor != nil)
        {
            _storeFilePath = storeFilePath;
            NSMutableDictionary *multiPartOptions = [[NSMutableDictionary alloc] initWithDictionary:@{
                @"identifier": @(descriptor.identifier),
                @"fileLocation": descriptor.location,
                @"encryptedSize": @(descriptor.size),
                @"decryptedSize": @(descriptor.decryptedSize),
                @"storeFilePath": storeFilePath,
                @"tempStoreFilePath": descriptor.storePath,
                @"datacenterId": @(descriptor.datacenterId),
                @"encryptionArgs": descriptor.encryptionKey != nil ? @{@"key": descriptor.encryptionKey, @"iv": descriptor.encryptionIv} : @{},
                @"mediaTypeTag": @(descriptor.mediaTypeTag)
            }];
            if (descriptor.originInfo != nil)
                multiPartOptions[@"originInfo"] = descriptor.originInfo;
            
            [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/multipart-file/(document:%" PRId64 ":%d:%@)", documentAttachment.documentId, documentAttachment.datacenterId, documentAttachment.documentUri.length != 0 ? documentAttachment.documentUri : @""] options:multiPartOptions watcher:self];
        }
        else
            [ActionStageInstance() actionFailed:self.path reason:-1];
    }
    else
    {
        [ActionStageInstance() actionFailed:self.path reason:-1];
    }
}

- (void)cancel
{
    [ActionStageInstance() removeWatcher:self];
    
    [_disposables dispose];
    
    [super cancel];
}

- (void)actorMessageReceived:(NSString *)path messageType:(NSString *)messageType message:(id)message
{
    if ([path hasPrefix:@"/tg/multipart-file/"])
    {
        if ([messageType isEqualToString:@"progress"])
        {
            [ActionStageInstance() dispatchMessageToWatchers:self.path messageType:messageType message:message];
        }
    }
}

+ (ASQueue *)previewGenerationQueue
{
    static ASQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ASQueue alloc] initWithName:"org.telegram.documentDownloadPreviewGeneration"];
    });
    
    return queue;
}

- (bool)fileIsImage
{
    NSArray *imageFileExtensions = @[@"gif", @"png", @"jpg", @"jpeg"];
    NSArray *imageMimeTypes = @[@"image/gif"];
    
    NSString *extension = [_documentAttachment.fileName pathExtension];
    for (NSString *sampleExtension in imageFileExtensions)
    {
        if ([[extension lowercaseString] isEqualToString:sampleExtension])
            return true;
    }
    
    for (NSString *sampleMimeType in imageMimeTypes)
    {
        if ([_documentAttachment.mimeType isEqualToString:sampleMimeType])
            return true;
    }
    
    return false;
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)__unused result
{
    if ([path hasPrefix:@"/tg/multipart-file/"])
    {
        if (status == ASStatusSuccess)
        {
            NSString *thumbnailUri = [_documentAttachment.thumbnailInfo imageUrlForLargestSize:NULL];
            
            if (thumbnailUri != nil)
            {
                
                [ActionStageInstance() actionCompleted:self.path result:nil];
                
                {
                    [ActionStageInstance() dispatchResource:[[NSString alloc] initWithFormat:@"/as/media/imageThumbnailUpdated"] resource:thumbnailUri];
                }
            }
            else
                [ActionStageInstance() actionCompleted:self.path result:nil];
        }
        else
        {
            [ActionStageInstance() actionFailed:self.path reason:-1];
        }
    }
}

@end
