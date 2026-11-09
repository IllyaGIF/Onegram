#import "OGMediaFetchSession.h"

@class TGDocumentMediaAttachment;
@class TGVideoMediaAttachment;

@interface OGMediaFetchDescriptor (Telegraph)

+ (instancetype)descriptorForDocument:(TGDocumentMediaAttachment *)document publishPath:(NSString **)publishPath;
+ (instancetype)descriptorForVideoUrl:(NSString *)url originInfo:(TGMediaOriginInfo *)originInfo publishPath:(NSString **)publishPath;
+ (instancetype)descriptorForVideoAttachment:(TGVideoMediaAttachment *)video publishPath:(NSString **)publishPath;
+ (instancetype)descriptorForStreamingVideoAttachment:(TGVideoMediaAttachment *)video publishPath:(NSString **)publishPath;

+ (NSString *)storeDirectoryForDocument:(TGDocumentMediaAttachment *)document;
+ (NSString *)streamMimeTypeForDocument:(TGDocumentMediaAttachment *)document pathExtension:(NSString **)pathExtension;
+ (bool)isStreamableDocument:(TGDocumentMediaAttachment *)document;
+ (bool)isStreamableVideoAttachment:(TGVideoMediaAttachment *)video;
+ (bool)isDecodableVideoCodec:(NSString *)codec;
+ (bool)isDecodableOriginalOfVideoAttachment:(TGVideoMediaAttachment *)video;

@end
