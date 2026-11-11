#import <Foundation/Foundation.h>

@class TGDocumentMediaAttachment;

#ifdef __cplusplus
extern "C" {
#endif

NSString *TGCustomEmojiThumbnailUri(TGDocumentMediaAttachment *document);
void TGCustomEmojiRegisterThumbnailUri(int64_t documentId, NSString *thumbnailUri);
void TGCustomEmojiLoadThumbnail(int64_t documentId, void (^completion)(NSString *thumbnailUri));

#ifdef __cplusplus
}
#endif
