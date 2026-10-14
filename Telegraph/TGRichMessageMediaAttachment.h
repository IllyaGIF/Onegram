#import "../submodules/LegacyComponents/LegacyComponents/TGMediaAttachment.h"

#import "TGRichMessage.h"

#define TGRichMessageMediaAttachmentType ((int)0x7a1c5e03)

@interface TGRichMessageMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding>

@property (nonatomic, strong, readonly) TGRichMessage *richMessage;

- (instancetype)initWithRichMessage:(TGRichMessage *)richMessage;

@end
