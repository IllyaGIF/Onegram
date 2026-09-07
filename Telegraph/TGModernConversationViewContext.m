#import "TGModernConversationViewContext.h"

#import "TGModernConversationCompanion.h"

@interface TGModernConversationViewContextCompanionReference : NSObject
@property (nonatomic, weak) TGModernConversationCompanion *value;
@end

@implementation TGModernConversationViewContextCompanionReference
@end

@interface TGModernConversationViewContext ()
{
    TGModernConversationViewContextCompanionReference *_ios4CompanionReference;
}
@end

@implementation TGModernConversationViewContext

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        _ios4CompanionReference = [[TGModernConversationViewContextCompanionReference alloc] init];
    return self;
}

- (TGModernConversationCompanion *)companion
{
    @synchronized (_ios4CompanionReference)
    {
        TGModernConversationCompanion *companion = _ios4CompanionReference.value;
        return companion;
    }
}

- (void)setCompanion:(TGModernConversationCompanion *)companion
{
    @synchronized (_ios4CompanionReference)
    {
        _ios4CompanionReference.value = companion;
    }
}

- (bool)isFocusedOnMessage:(int32_t)messageId peerId:(int64_t)peerId
{
    TGModernConversationCompanion *companion = self.companion;
    TGMessageIndex *messageIndex = [companion focusedOnMessageIndex];
    return messageIndex.peerId == peerId && messageIndex.messageId == messageId;
}

- (bool)isMediaVisibleInMessage:(int32_t)messageId peerId:(int64_t)peerId
{
    TGModernConversationCompanion *companion = self.companion;
    TGMessageIndex *messageIndex = [companion mediaHiddenMessageIndex];
    return messageIndex.peerId != peerId || messageIndex.messageId != messageId;
}

- (bool)isMessageChecked:(int32_t)messageId peerId:(int64_t)peerId
{
    TGModernConversationCompanion *companion = self.companion;
    return [companion _isMessageChecked:[TGMessageIndex indexWithPeerId:peerId messageId:messageId]];
}

- (bool)isGroupChecked:(int64_t)groupedId
{
    TGModernConversationCompanion *companion = self.companion;
    return [companion _isGroupChecked:groupedId];
}

- (bool)isSecretMessageViewed:(int32_t)messageId
{
    TGModernConversationCompanion *companion = self.companion;
    return [companion _isSecretMessageViewed:messageId];
}

- (bool)isSecretMessageScreenshotted:(int32_t)messageId
{
    TGModernConversationCompanion *companion = self.companion;
    return [companion _isSecretMessageScreenshotted:messageId];
}

- (NSTimeInterval)secretMessageViewDate:(int32_t)messageId
{
    TGModernConversationCompanion *companion = self.companion;
    return [companion _secretMessageViewDate:messageId];
}

@end
