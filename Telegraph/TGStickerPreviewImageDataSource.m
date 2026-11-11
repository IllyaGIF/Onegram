#import "TGStickerPreviewImageDataSource.h"


#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGWorkerPool.h"
#import "TGWorkerTask.h"
#import "TGMediaPreviewTask.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageBlur.h"
#import "../submodules/LegacyComponents/LegacyComponents/UIImage+TG.h"

#import "TGMediaStoreContext.h"

#import "UIImage+WebP.h"

#import "TGSharedMediaUtils.h"

#import "TGAppDelegate.h"
#import "TGAnimatedStickerFrames.h"

static bool TGStickerPreviewIsAnimatedFile(NSDictionary *args)
{
    NSString *mimeType = [args[@"mimeType"] lowercaseString];
    NSString *extension = [[args[@"fileName"] pathExtension] lowercaseString];
    return [mimeType isEqualToString:@"video/webm"] || [mimeType isEqualToString:@"application/x-tgsticker"] || [extension isEqualToString:@"webm"] || [extension isEqualToString:@"tgs"];
}

static NSString *TGStickerPreviewThumbnailFileName(bool highQuality)
{
    return highQuality ? @"thumbnail-high-v2" : @"thumbnail";
}

static ASQueue *taskManagementQueue()
{
    static ASQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ASQueue alloc] initWithName:"org.telegram.stickerPreviewImageTaskManagementQueue"];
    });
    
    return queue;
}

static NSDictionary *OGCompatStickerArguments(NSString *uri);

static bool OGCompatStickerIsString(id value)
{
    return [value respondsToSelector:@selector(characterAtIndex:)];
}

static NSString *OGCompatStickerDocumentPath(NSString *directory, NSDictionary *arguments)
{
    return [directory stringByAppendingPathComponent:[arguments objectForKey:@"fileName"]];
}

static bool OGCompatStickerHasDocumentId(NSDictionary *args)
{
    return [args[@"documentId"] respondsToSelector:@selector(longLongValue)] || [args[@"localDocumentId"] respondsToSelector:@selector(longLongValue)];
}

static NSString *OGCompatStickerDirectory(NSDictionary *args)
{
    static NSString *root = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        root = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"files"];
    });

    int64_t remoteId = [args[@"documentId"] longLongValue];
    NSString *name = remoteId != 0 ? [NSString stringWithFormat:@"%" PRIx64 "", remoteId] : [NSString stringWithFormat:@"local%" PRIx64 "", (int64_t)[args[@"localDocumentId"] longLongValue]];
    return [root stringByAppendingPathComponent:name];
}

@implementation TGStickerPreviewImageDataSource

+ (void)load
{
    @autoreleasepool
    {
        [TGImageDataSource registerDataSource:[[self alloc] init]];
    }
}

+ (NSString *)uriPrefix
{
    return @"sticker-preview://?";
}

- (bool)canHandleUri:(NSString *)uri
{
    return [uri hasPrefix:@"sticker-preview://"];
}

- (bool)canHandleAttributeUri:(NSString *)uri
{
    return [uri hasPrefix:@"sticker-preview://"];
}

- (id)loadDataAsyncWithUri:(NSString *)uri progress:(void (^)(float))progress partialCompletion:(void (^)(TGDataResource *resource))__unused partialCompletion completion:(void (^)(TGDataResource *))completion
{
    TGMediaPreviewTask *previewTask = [[TGMediaPreviewTask alloc] init];
    
    [taskManagementQueue() dispatchOnQueue:^
     {
         TGWorkerTask *workerTask = [[TGWorkerTask alloc] initWithBlock:^(bool (^isCancelled)())
         {
             TGDataResource *result = [TGStickerPreviewImageDataSource _performLoad:uri isCancelled:isCancelled];
             
             if (result != nil && progress != nil)
                 progress(1.0f);
             
             if (isCancelled != nil && isCancelled())
                 return;
             
             if (completion != nil)
                 completion(result != nil ? result : [TGStickerPreviewImageDataSource resultForUnavailableImage]);
         }];
         
         void (^reportMissing)(void) = ^
         {
             if (completion != nil)
                 completion([TGStickerPreviewImageDataSource resultForUnavailableImage]);
         };

         if ([TGStickerPreviewImageDataSource _isDataLocallyAvailableForUri:uri])
         {
             [previewTask executeWithWorkerTask:workerTask threadPool:[TGSharedMediaUtils sharedMediaImageProcessingThreadPool]];
         }
         else if ([OGCompatStickerArguments(uri)[@"cacheOnly"] boolValue])
         {
             reportMissing();
         }
         else
         {
             NSDictionary *args = OGCompatStickerArguments(uri);
             
             bool hasLegacyThumbnailUri = OGCompatStickerIsString(args[@"legacyThumbnailUri"]);
             bool hasFullDocumentFallback = OGCompatStickerIsString(args[@"fileName"]);
             
             if (!OGCompatStickerHasDocumentId(args) || (!hasLegacyThumbnailUri && !hasFullDocumentFallback) || (![args[@"accessHash"] respondsToSelector:@selector(longLongValue)]) || (![args[@"datacenterId"] respondsToSelector:@selector(intValue)]))
             {
                 reportMissing();
             }
             else
             {
                 NSString *fileDirectory = OGCompatStickerDirectory(args);
                 
                 [[NSFileManager defaultManager] createDirectoryAtPath:fileDirectory withIntermediateDirectories:true attributes:nil error:nil];
                 
                 bool highQuality = [args[@"highQuality"] boolValue];
                 
                 NSString *filePath = [fileDirectory stringByAppendingPathComponent:TGStickerPreviewThumbnailFileName(highQuality)];
                 
                 int64_t identifier = [args[@"documentId"] longLongValue];
                 __weak TGMediaPreviewTask *weakPreviewTask = previewTask;
                 void (^reportProgress)(float) = ^(float value)
                 {
                     if (progress)
                         progress(value);
                 };
                 void (^reportUnavailable)(void) = reportMissing;
                 void (^decodeDownloadedFile)(void) = ^
                 {
                     [weakPreviewTask executeWithWorkerTask:workerTask threadPool:[TGSharedMediaUtils sharedMediaImageProcessingThreadPool]];
                 };
                 void (^downloadDocument)(void) = ^
                 {
                     TGMediaPreviewTask *strongPreviewTask = weakPreviewTask;
                     if (strongPreviewTask == nil)
                         return;
                     if (!hasFullDocumentFallback)
                     {
                         reportUnavailable();
                         return;
                     }

                     NSString *documentFilePath = OGCompatStickerDocumentPath(fileDirectory, args);
                     [strongPreviewTask executeWithTargetFilePath:documentFilePath document:[TGStickerPreviewImageDataSource documentForPreviewArguments:args] progress:reportProgress completion:^(bool success)
                     {
                         if (success)
                             decodeDownloadedFile();
                         else
                             reportUnavailable();
                     } workerTask:nil];
                 };

                 if (hasLegacyThumbnailUri)
                 {
                     [previewTask executeMultipartWithImageUri:args[@"legacyThumbnailUri"] identifier:identifier originInfo:[TGMediaOriginInfo mediaOriginInfoWithStringRepresentation:args[@"origin_info"]] targetFilePath:filePath progress:reportProgress completion:^(bool success)
                     {
                         if (success)
                             decodeDownloadedFile();
                         else
                             downloadDocument();
                     }];
                 }
                 else
                 {
                     downloadDocument();
                 }

             }
         }
     }];
    
    return previewTask;
}

+ (TGDocumentMediaAttachment *)documentForPreviewArguments:(NSDictionary *)args
{
    TGDocumentMediaAttachment *documentAttachment = [[TGDocumentMediaAttachment alloc] init];
    documentAttachment.attributes = [NSMutableArray arrayWithObject:[[TGDocumentAttributeFilename alloc] initWithFilename:args[@"fileName"]]];
    documentAttachment.documentId = [args[@"documentId"] longLongValue];
    documentAttachment.localDocumentId = [args[@"localDocumentId"] longLongValue];
    documentAttachment.accessHash = [args[@"accessHash"] longLongValue];
    documentAttachment.datacenterId = [args[@"datacenterId"] intValue];
    documentAttachment.size = [args[@"size"] intValue];
    documentAttachment.mimeType = args[@"mimeType"];
    documentAttachment.originInfo = [TGMediaOriginInfo mediaOriginInfoWithStringRepresentation:args[@"origin_info"]];
    return documentAttachment;
}

+ (bool)_isDataLocallyAvailableForUri:(NSString *)uri
{
    NSDictionary *args = OGCompatStickerArguments(uri);
    
    if (!OGCompatStickerHasDocumentId(args))
    {
        return false;
    }
    
    NSString *fileDirectory = OGCompatStickerDirectory(args);
    
    bool highQuality = [args[@"highQuality"] boolValue];
    
    NSString *filePath = [fileDirectory stringByAppendingPathComponent:TGStickerPreviewThumbnailFileName(highQuality)];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:NULL] || [[NSFileManager defaultManager] fileExistsAtPath:[filePath stringByAppendingString:@".cached.bin"] isDirectory:NULL])
        return true;

    if (OGCompatStickerIsString(args[@"fileName"]))
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:OGCompatStickerDocumentPath(fileDirectory, args) isDirectory:NULL])
            return true;
    }
    
    return false;
}

- (void)cancelTaskById:(id)taskId
{
    [taskManagementQueue() dispatchOnQueue:^
     {
         if ([taskId isKindOfClass:[TGMediaPreviewTask class]])
         {
             TGMediaPreviewTask *previewTask = taskId;
             [previewTask cancel];
         }
     }];
}

+ (TGDataResource *)resultForUnavailableImage
{
    return nil;
}

- (id)loadAttributeSyncForUri:(NSString *)__unused uri attribute:(NSString *)attribute
{
    if ([attribute isEqualToString:@"placeholder"])
    {
        return nil;
    }
    
    return nil;
}

- (TGDataResource *)loadDataSyncWithUri:(NSString *)uri canWait:(bool)canWait acceptPartialData:(bool)__unused acceptPartialData asyncTaskId:(__autoreleasing id *)__unused asyncTaskId progress:(void (^)(float))__unused progress partialCompletion:(void (^)(TGDataResource *))__unused partialCompletion completion:(void (^)(TGDataResource *))__unused completion
{
    if (uri == nil)
        return nil;
    
    UIImage *cachedImage = [[TGSharedMediaUtils inMemoryImageCache] imageForKey:uri];
    if (cachedImage != nil)
        return [[TGDataResource alloc] initWithImage:cachedImage decoded:true];
    
    if (!canWait)
        return nil;
        
    return [TGStickerPreviewImageDataSource _performLoad:uri isCancelled:nil];
}

+ (TGDataResource *)_performLoad:(NSString *)uri isCancelled:(bool (^)())isCancelled
{
    if (isCancelled && isCancelled())
        return nil;
    
    NSDictionary *args = OGCompatStickerArguments(uri);
    
    if (!OGCompatStickerHasDocumentId(args))
    {
        return false;
    }
    
    NSString *fileDirectory = OGCompatStickerDirectory(args);
    
    CGSize size = CGSizeMake([args[@"width"] intValue], [args[@"height"] intValue]);
    
    bool highQuality = [args[@"highQuality"] boolValue];
    
    NSString *filePath = [fileDirectory stringByAppendingPathComponent:TGStickerPreviewThumbnailFileName(highQuality)];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:NULL] && ![[NSFileManager defaultManager] fileExistsAtPath:[filePath stringByAppendingString:@".cached.bin"] isDirectory:NULL] && OGCompatStickerIsString(args[@"fileName"]))
    {
        NSString *documentFilePath = OGCompatStickerDocumentPath(fileDirectory, args);
        if ([[NSFileManager defaultManager] fileExistsAtPath:documentFilePath isDirectory:NULL])
            filePath = documentFilePath;
    }
    
    __block UIImage *image = nil;
    
    NSString *cachedFilePath = [filePath stringByAppendingString:@".cached.bin"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachedFilePath isDirectory:NULL])
    {
        image = [UIImage convertFromGZippedData:cachedFilePath size:size];
    }
    
    
    if (image == nil)
    {
        image = [[UIImage alloc] initWithContentsOfFile:filePath];
        if (image != nil)
        {
            image = TGScaleImageToPixelSize(image, TGFitSize(image.size, size));
        }
        else if (![[[filePath pathExtension] lowercaseString] isEqualToString:@"webm"] && ![[[filePath pathExtension] lowercaseString] isEqualToString:@"tgs"])
        {
            __autoreleasing NSData *compressedData = nil;
            image = [UIImage convertFromWebP:filePath compressedData:&compressedData error:nil];
            if (compressedData != nil)
                [compressedData writeToFile:cachedFilePath atomically:true];
        }
    }

    if (image == nil && TGStickerPreviewIsAnimatedFile(args) && OGCompatStickerIsString(args[@"fileName"]) && !(isCancelled && isCancelled()))
    {
        NSString *documentPath = [fileDirectory stringByAppendingPathComponent:args[@"fileName"]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:documentPath] && ![NSThread isMainThread])
        {
            NSString *key = [[NSString alloc] initWithFormat:@"preview-%@-%@", args[@"documentId"] ?: args[@"localDocumentId"], args[@"fileName"]];
            CGSize pixelSize = CGSizeMake(MAX(1.0f, size.width), MAX(1.0f, size.height));
            dispatch_sync(TGAnimatedStickerRenderQueue(), ^
            {
                TGAnimatedStickerFrames *frames = [TGAnimatedStickerFrames framesWithKey:key filePath:documentPath pixelSize:pixelSize];
                CGImageRef poster = [frames copyPosterImage];
                if (poster != NULL)
                {
                    image = [UIImage imageWithCGImage:poster];
                    CGImageRelease(poster);
                }
            });
        }
    }
    
    
    if (image != nil)
    {
        int contextWidth = (int)image.size.width;
        int contextHeight = (int)image.size.height;
        [[TGSharedMediaUtils inMemoryImageCache] setImageDataWithSize:image.size generator:^(uint8_t *memory, NSUInteger bytesPerRow)
        {
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little;
            
            CGContextRef context = CGBitmapContextCreate(memory, contextWidth, contextHeight, 8, bytesPerRow, colorSpace, bitmapInfo);
            
            CGContextTranslateCTM(context, contextWidth / 2.0f, contextHeight / 2.0f);
            CGContextScaleCTM(context, 1.0f, -1.0f);
            CGContextTranslateCTM(context, -contextWidth / 2.0f, -contextHeight / 2.0f);
            
            UIGraphicsPushContext(context);
            
            [image drawInRect:CGRectMake(0.0f, 0.0f, contextWidth, contextHeight) blendMode:kCGBlendModeCopy alpha:1.0f];
            
            UIGraphicsPopContext();
            CGColorSpaceRelease(colorSpace);
            CGContextRelease(context);
        } forKey:uri];
        
        
        return [[TGDataResource alloc] initWithImage:image decoded:true];
    }
    
    return nil;
}

@end

static NSDictionary *OGCompatStickerArguments(NSString *uri)
{
    return [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:[TGStickerPreviewImageDataSource uriPrefix].length]];
}

