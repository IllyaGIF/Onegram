#import "TGReplyHeaderLocationModel.h"

#import "TGSharedLocationSignals.h"

#import "TGSharedMediaSignals.h"
#import "TGSharedMediaUtils.h"

#import "TGSignalImageViewModel.h"

#import "TGPresentation.h"

@interface TGReplyHeaderLocationModel ()
{
}

@end

@implementation TGReplyHeaderLocationModel

- (instancetype)initWithPeer:(id)peer latitude:(double)__unused latitude longitude:(double)__unused longitude period:(int32_t)period incoming:(bool)incoming system:(bool)system presentation:(TGPresentation *)presentation
{
    self = [super initWithPeer:peer incoming:incoming text:period > 0 ? TGLocalized(@"Message.LiveLocation") : TGLocalized(@"Message.Location") truncateTextInTheMiddle:false textColor:incoming ? presentation.pallete.chatIncomingSubtextColor : presentation.pallete.chatOutgoingSubtextColor leftInset:0.0f system:system presentation:presentation];
    if (self != nil)
    {
    }
    return self;
}


@end
