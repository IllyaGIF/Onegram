#import "TGMediaAttachment.h"

#define TGAudioMediaAttachmentType 0x3A0E7A32

@interface TGAudioMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser>

@property (nonatomic) int64_t audioId;
@property (nonatomic) int64_t accessHash;
@property (nonatomic) int32_t datacenterId;

@property (nonatomic) int64_t localAudioId;

@property (nonatomic) int32_t duration;
@property (nonatomic) int32_t fileSize;

@property (nonatomic, strong) NSString *audioUri;


@end
