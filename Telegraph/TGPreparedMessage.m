/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGPreparedMessage.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMessage.h"

@implementation TGPreparedMessage

- (int32_t)replyMessageId
{
    if (_replyMessage.mid != 0)
        return _replyMessage.mid;
    return _forumTopicId > 1 ? _forumTopicId : 0;
}

- (void)applyForumTopicToMessage:(TGMessage *)message
{
    if (_forumTopicId == 0)
        return;
    NSMutableDictionary *properties = message.contentProperties != nil ? [message.contentProperties mutableCopy] : [[NSMutableDictionary alloc] init];
    properties[@"ios6ForumTopicId"] = [[TGMessageForumTopicContentProperty alloc] initWithTopicId:_forumTopicId];
    message.contentProperties = properties;
}

- (TGMessage *)message
{
    return nil;
}

@end
