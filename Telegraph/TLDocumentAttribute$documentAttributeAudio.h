#import "TLDocumentAttribute.h"


@interface TLDocumentAttribute$documentAttributeAudio : TLDocumentAttribute

@property (nonatomic) int32_t flags;
@property (nonatomic) bool is_voice;
@property (nonatomic) int32_t duration;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *performer;
@property (nonatomic, strong) NSData *waveform;

@end
