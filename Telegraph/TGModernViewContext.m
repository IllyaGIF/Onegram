#import "TGModernViewContext.h"
#import <libkern/OSAtomic.h>
#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

@implementation TGPollMessageViewState

- (instancetype)initWithSelectedOptions:(NSArray *)selectedOptions voting:(bool)voting
{
    self = [super init];
    if (self != nil)
    {
        _selectedOptions = [selectedOptions copy] ?: @[];
        _voting = voting;
    }
    return self;
}

@end

@interface TGModernViewContext ()
{
    OSSpinLock _lock;
    NSMutableDictionary *_richMessageExpandedKeys;
    NSMutableDictionary *_pollStates;
}
@end

@implementation TGModernViewContext

- (bool)isFocusedOnMessage:(int32_t)__unused messageId peerId:(int64_t)__unused peerId
{
    return false;
}

- (bool)isMediaVisibleInMessage:(int32_t)__unused messageId peerId:(int64_t)__unused peerId
{
    return true;
}

- (bool)isMessageChecked:(int32_t)__unused messageId peerId:(int64_t)__unused peerId
{
    return false;
}

- (bool)isGroupChecked:(int64_t)__unused groupedId
{
    return false;
}

- (bool)isSecretMessageViewed:(int32_t)__unused messageId
{
    return false;
}

- (bool)isSecretMessageScreenshotted:(int32_t)__unused messageId
{
    return false;
}

- (NSTimeInterval)secretMessageViewDate:(int32_t)__unused messageId
{
    return 0.0;
}

- (NSSet *)richMessageExpandedKeysForMessageId:(int32_t)messageId peerId:(int64_t)peerId
{
    NSString *key = [[NSString alloc] initWithFormat:@"%lld:%d", peerId, messageId];
    NSSet *keys = nil;
    OSSpinLockLock(&_lock);
    keys = _richMessageExpandedKeys[key];
    OSSpinLockUnlock(&_lock);
    return keys ?: [NSSet set];
}

- (void)setRichMessageExpandedKeys:(NSSet *)keys forMessageId:(int32_t)messageId peerId:(int64_t)peerId
{
    NSString *key = [[NSString alloc] initWithFormat:@"%lld:%d", peerId, messageId];
    OSSpinLockLock(&_lock);
    if (_richMessageExpandedKeys == nil)
        _richMessageExpandedKeys = [[NSMutableDictionary alloc] init];
    if (keys.count == 0)
        [_richMessageExpandedKeys removeObjectForKey:key];
    else
        _richMessageExpandedKeys[key] = [keys copy];
    OSSpinLockUnlock(&_lock);
}

- (TGPollMessageViewState *)pollStateForMessageId:(int32_t)messageId peerId:(int64_t)peerId
{
    NSString *key = [[NSString alloc] initWithFormat:@"%lld:%d", peerId, messageId];
    TGPollMessageViewState *state = nil;
    OSSpinLockLock(&_lock);
    state = _pollStates[key];
    OSSpinLockUnlock(&_lock);
    return state;
}

- (void)setPollState:(TGPollMessageViewState *)state forMessageId:(int32_t)messageId peerId:(int64_t)peerId
{
    NSString *key = [[NSString alloc] initWithFormat:@"%lld:%d", peerId, messageId];
    OSSpinLockLock(&_lock);
    if (_pollStates == nil)
        _pollStates = [[NSMutableDictionary alloc] init];
    if (state == nil || (state.selectedOptions.count == 0 && !state.voting))
        [_pollStates removeObjectForKey:key];
    else
        _pollStates[key] = state;
    OSSpinLockUnlock(&_lock);
}

- (bool)isMessageUnread:(TGMessage *)message {
    if (message.outgoing && !_outgoingMessagesAreAlwaysRead) {
        return [_conversationForUnreadCalculations isMessageUnread:message];
    } else {
        return false;
    }
}

- (bool)isByAdmin:(TGMessage *)message {
    bool isByAdmin = false;
    OSSpinLockLock(&_lock);
    isByAdmin = [_adminIds containsObject:@(message.fromUid)];
    OSSpinLockUnlock(&_lock);
    return isByAdmin;
}

- (void)setAdminIds:(NSSet *)adminIds
{
    OSSpinLockLock(&_lock);
    _adminIds = adminIds;
    OSSpinLockUnlock(&_lock);
}

@end
