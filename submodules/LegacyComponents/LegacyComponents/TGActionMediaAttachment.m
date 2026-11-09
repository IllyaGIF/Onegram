#import "TGActionMediaAttachment.h"

#import "TGImageMediaAttachment.h"

static const int32_t TGActionMediaAttachmentVersion2Magic = 0x7a3cf002;

static int64_t TGActionMediaAttachmentReadId(NSInputStream *is, bool wideIds, int *dataLength)
{
    if (wideIds)
    {
        int64_t value = 0;
        [is read:(uint8_t *)&value maxLength:8];
        *dataLength -= 8;
        return value;
    }
    int32_t value = 0;
    [is read:(uint8_t *)&value maxLength:4];
    *dataLength -= 4;
    return value;
}

@implementation TGActionMediaAttachment

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGActionMediaAttachmentType;
    }
    return self;
}

- (void)serialize:(NSMutableData *)data
{
    int32_t magic = TGActionMediaAttachmentVersion2Magic;
    [data appendBytes:&magic length:4];
    
    int dataLengthPtr = (int)data.length;
    int zero = 0;
    [data appendBytes:&zero length:4];
    
    int actionType = _actionType;
    [data appendBytes:&actionType length:4];
    
    if (actionType == TGMessageActionChatAddMember || actionType == TGMessageActionChatDeleteMember)
    {
        int64_t uid = [[_actionData objectForKey:@"uid"] longLongValue];
        [data appendBytes:&uid length:8];
        NSArray *uids = _actionData[@"uids"];
        int32_t uidsCount = (int32_t)uids.count;
        [data appendBytes:&uidsCount length:4];
        for (NSNumber *nUid in uids) {
            int64_t listUid = [nUid longLongValue];
            [data appendBytes:&listUid length:8];
        }
    }
    else if (actionType == TGMessageActionJoinedByLink)
    {
        int64_t invitedBy = [[_actionData objectForKey:@"invitedBy"] longLongValue];
        [data appendBytes:&invitedBy length:8];
        uint8_t joinedByRequest = [[_actionData objectForKey:@"joinedByRequest"] boolValue] ? 1 : 0;
        [data appendBytes:&joinedByRequest length:1];
    }
    else if (actionType == TGMessageActionChatEditTitle)
    {
        NSString *title = [_actionData objectForKey:@"title"];
        NSData *titleData = [title dataUsingEncoding:NSUTF8StringEncoding];
        int length = (int)titleData.length;
        [data appendBytes:&length length:4];
        [data appendData:titleData];
    }
    else if (actionType == TGMessageActionCreateChat)
    {
        NSString *title = [_actionData objectForKey:@"title"];
        NSData *titleData = [title dataUsingEncoding:NSUTF8StringEncoding];
        int length = (int)titleData.length;
        [data appendBytes:&length length:4];
        [data appendData:titleData];
        
        NSArray *uids = [_actionData objectForKey:@"uids"];
        int count = (int)uids.count;
        [data appendBytes:&count length:4];
        for (NSNumber *nUid in uids)
        {
            int64_t uid = [nUid longLongValue];
            [data appendBytes:&uid length:8];
        }
    }
    else if (actionType == TGMessageActionCreateBroadcastList)
    {
        NSString *title = [_actionData objectForKey:@"title"];
        NSData *titleData = [title dataUsingEncoding:NSUTF8StringEncoding];
        int length = (int)titleData.length;
        [data appendBytes:&length length:4];
        [data appendData:titleData];
        
        NSArray *uids = [_actionData objectForKey:@"uids"];
        int count = (int)uids.count;
        [data appendBytes:&count length:4];
        for (NSNumber *nUid in uids)
        {
            int64_t uid = [nUid longLongValue];
            [data appendBytes:&uid length:8];
        }
    }
    else if (actionType == TGMessageActionChatEditPhoto)
    {
        TGImageMediaAttachment *photo = [_actionData objectForKey:@"photo"];
        if (photo != nil)
        {
            [photo serialize:data];
        }
    }
    else if (actionType == TGMessageActionContactRequest)
    {
        int hasPhone = [[_actionData objectForKey:@"hasPhone"] boolValue] ? 1 : 0;
        [data appendBytes:&hasPhone length:4];
    }
    else if (actionType == TGMessageActionAcceptContactRequest)
    {
    }
    else if (actionType == TGMessageActionContactRegistered)
    {
    }
    else if (actionType == TGMessageActionUserChangedPhoto)
    {
        TGImageMediaAttachment *photo = [_actionData objectForKey:@"photo"];
        if (photo != nil)
        {
            [photo serialize:data];
        }
    }
    else if (actionType == TGMessageActionEncryptedChatRequest)
    {
    }
    else if (actionType == TGMessageActionEncryptedChatAccept)
    {
        
    }
    else if (actionType == TGMessageActionEncryptedChatDecline)
    {
        
    }
    else if (actionType == TGMessageActionEncryptedChatMessageLifetime)
    {
        int32_t messageLifetime = [_actionData[@"messageLifetime"] intValue];
        [data appendBytes:&messageLifetime length:4];
    }
    else if (actionType == TGMessageActionEncryptedChatScreenshot)
    {   
    }
    else if (actionType == TGMessageActionChannelCreated)
    {
        NSString *title = [_actionData objectForKey:@"title"];
        NSData *titleData = [title dataUsingEncoding:NSUTF8StringEncoding];
        int length = (int)titleData.length;
        [data appendBytes:&length length:4];
        [data appendData:titleData];
    }
    else if (actionType == TGMessageActionChannelCommentsStatusChanged) {
        uint8_t enabled = [_actionData[@"enabled"] boolValue];
        [data appendBytes:&enabled length:1];
    } else if (actionType == TGMessageActionChannelInviter) {
        int64_t inviter = [_actionData[@"uid"] longLongValue];
        [data appendBytes:&inviter length:8];
    } else if (actionType == TGMessageActionGroupMigratedTo) {
        int64_t channelId = [_actionData[@"channelId"] longLongValue];
        [data appendBytes:&channelId length:8];
    } else if (actionType == TGMessageActionGroupDeactivated) {
        
    } else if (actionType == TGMessageActionGroupActivated) {
        
    } else if (actionType == TGMessageActionChannelMigratedFrom) {
        NSString *title = [_actionData objectForKey:@"title"];
        NSData *titleData = [title dataUsingEncoding:NSUTF8StringEncoding];
        int length = (int)titleData.length;
        [data appendBytes:&length length:4];
        [data appendData:titleData];
        
        int64_t groupId = [_actionData[@"groupId"] longLongValue];
        [data appendBytes:&groupId length:8];
    } else if (actionType == TGMessageActionPinnedMessage) {
    } else if (actionType == TGMessageActionClearChat) {
    } else if (actionType == TGMessageActionGameScore) {
        int32_t gameId = [_actionData[@"gameId"] intValue];
        [data appendBytes:&gameId length:4];
        int32_t score = [_actionData[@"score"] intValue];
        [data appendBytes:&score length:4];
    } else if (actionType == TGMessageActionPhoneCall) {
        int64_t callId = [_actionData[@"callId"] longLongValue];
        [data appendBytes:&callId length:8];
        int32_t reason = [_actionData[@"reason"] intValue];
        [data appendBytes:&reason length:4];
        int32_t duration = [_actionData[@"duration"] intValue];
        [data appendBytes:&duration length:4];
    } else if (actionType == TGMessageActionPaymentSent) {
        NSString *curreny = _actionData[@"currency"];
        NSData *currencyBytes = [curreny dataUsingEncoding:NSUTF8StringEncoding];
        int32_t currencyLength = (int32_t)currencyBytes.length;
        [data appendBytes:&currencyLength length:4];
        [data appendData:currencyBytes];
        int32_t totalAmount = [_actionData[@"totalAmount"] intValue];
        [data appendBytes:&totalAmount length:4];
    } else if (actionType == TGMessageActionText) {
        NSString *text = _actionData[@"text"];
        NSData *textBytes = [text dataUsingEncoding:NSUTF8StringEncoding];
        int32_t textLength = (int32_t)textBytes.length;
        [data appendBytes:&textLength length:4];
        [data appendData:textBytes];
    } else if (actionType == TGMessageActionBotAllowed) {
        NSString *domain = _actionData[@"domain"];
        NSData *domainBytes = [domain dataUsingEncoding:NSUTF8StringEncoding];
        int32_t domainLength = (int32_t)domainBytes.length;
        [data appendBytes:&domainLength length:4];
        [data appendData:domainBytes];
    } else if (actionType == TGMessageActionSecureValuesSent) {
        NSString *values = _actionData[@"values"];
        NSData *valuesBytes = [values dataUsingEncoding:NSUTF8StringEncoding];
        int32_t valuesLength = (int32_t)valuesBytes.length;
        [data appendBytes:&valuesLength length:4];
        [data appendData:valuesBytes];
    } else if (actionType == TGMessageActionCommunityChanged) {
        int64_t communityId = [_actionData[@"communityId"] longLongValue];
        [data appendBytes:&communityId length:8];
    } else if (actionType == TGMessageActionStarGift || actionType == TGMessageActionStarGiftUnique || actionType == TGMessageActionStarGiftPurchaseOffer || actionType == TGMessageActionStarGiftPurchaseOfferDeclined) {
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:_actionData ?: @{}];
        int32_t length = (int32_t)archive.length;
        [data appendBytes:&length length:4];
        [data appendData:archive];
    }

    int dataLength = (int)data.length - dataLengthPtr - 4;
    [data replaceBytesInRange:NSMakeRange(dataLengthPtr, 4) withBytes:&dataLength];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int32_t header = 0;
    [is read:(uint8_t *)&header maxLength:4];
    
    int dataLength = 0;
    bool wideIds = false;
    if (header == TGActionMediaAttachmentVersion2Magic)
    {
        wideIds = true;
        [is read:(uint8_t *)&dataLength maxLength:4];
    }
    else
    {
        dataLength = header;
    }
    
    TGActionMediaAttachment *actionAttachment = [[TGActionMediaAttachment alloc] init];
    
    int actionType = 0;
    [is read:(uint8_t *)&actionType maxLength:4];
    dataLength -= 4;
    actionAttachment.actionType = (TGMessageAction)actionType;
    
    if (actionType == TGMessageActionChatAddMember || actionType == TGMessageActionChatDeleteMember)
    {
        int64_t uid = TGActionMediaAttachmentReadId(is, wideIds, &dataLength);
        
        NSMutableArray *uids = [[NSMutableArray alloc] init];
        if (dataLength >= 4) {
            int32_t uidsCount = 0;
            [is read:(uint8_t *)&uidsCount maxLength:4];
            dataLength -= 4;
            
            for (int32_t i = 0; dataLength > 0 && i < uidsCount; i++) {
                [uids addObject:@(TGActionMediaAttachmentReadId(is, wideIds, &dataLength))];
            }
        }
        
        if (uids.count != 0) {
            actionAttachment.actionData = @{@"uid": @(uid), @"uids": uids};
        } else {
            actionAttachment.actionData = @{@"uid": @(uid)};
        }
    }
    else if (actionType == TGMessageActionJoinedByLink)
    {
        int64_t invitedBy = TGActionMediaAttachmentReadId(is, wideIds, &dataLength);
        bool joinedByRequest = false;
        if (wideIds)
        {
            uint8_t joinedByRequestValue = 0;
            [is read:&joinedByRequestValue maxLength:1];
            joinedByRequest = joinedByRequestValue != 0;
        }
        actionAttachment.actionData = joinedByRequest ? @{@"invitedBy": @(invitedBy), @"joinedByRequest": @true} : @{@"invitedBy": @(invitedBy)};
    }
    else if (actionType == TGMessageActionChatEditTitle)
    {
        int length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        uint8_t *titleBytes = malloc(length);
        [is read:titleBytes maxLength:length];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        actionAttachment.actionData = [NSDictionary dictionaryWithObject:(title == nil ? @"" : title) forKey:@"title"];
    }
    else if (actionType == TGMessageActionCreateChat)
    {
        int length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        uint8_t *titleBytes = malloc(length);
        [is read:titleBytes maxLength:length];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        
        int count = 0;
        [is read:(uint8_t *)&count maxLength:4];
        NSMutableArray *uids = [[NSMutableArray alloc] initWithCapacity:count];
        for (int i = 0; i < count; i++)
        {
            int64_t uid = TGActionMediaAttachmentReadId(is, wideIds, &dataLength);
            if (uid != 0)
                [uids addObject:@(uid)];
        }
        
        actionAttachment.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:(title == nil ? @"" : title), @"title", uids, @"uids", nil];
    }
    else if (actionType == TGMessageActionCreateBroadcastList)
    {
        int length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        uint8_t *titleBytes = malloc(length);
        [is read:titleBytes maxLength:length];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        
        int count = 0;
        [is read:(uint8_t *)&count maxLength:4];
        NSMutableArray *uids = [[NSMutableArray alloc] initWithCapacity:count];
        for (int i = 0; i < count; i++)
        {
            int64_t uid = TGActionMediaAttachmentReadId(is, wideIds, &dataLength);
            if (uid != 0)
                [uids addObject:@(uid)];
        }
        
        actionAttachment.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:(title == nil ? @"" : title), @"title", uids, @"uids", nil];
    }
    else if (actionType == TGMessageActionChatEditPhoto)
    {
        TGImageMediaAttachment *photo = (TGImageMediaAttachment *)[[[TGImageMediaAttachment alloc] init] parseMediaAttachment:is];
        if (photo != nil)
            actionAttachment.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:photo, @"photo", nil];
    }
    else if (actionType == TGMessageActionContactRequest)
    {
        int hasPhone = 0;
        [is read:(uint8_t *)&hasPhone maxLength:4];
        actionAttachment.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithBool:hasPhone != 0], @"hasPhone", nil];
    }
    else if (actionType == TGMessageActionAcceptContactRequest)
    {
    }
    else if (actionType == TGMessageActionContactRegistered)
    {
    }
    else if (actionType == TGMessageActionUserChangedPhoto)
    {
        TGImageMediaAttachment *photo = (TGImageMediaAttachment *)[[[TGImageMediaAttachment alloc] init] parseMediaAttachment:is];
        if (photo != nil)
            actionAttachment.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:photo, @"photo", nil];
    }
    else if (actionType == TGMessageActionEncryptedChatRequest)
    {
    }
    else if (actionType == TGMessageActionEncryptedChatAccept)
    {
    }
    else if (actionType == TGMessageActionEncryptedChatDecline)
    {   
    }
    else if (actionType == TGMessageActionEncryptedChatMessageLifetime)
    {
        int32_t messageLifetime = 0;
        [is read:(uint8_t *)&messageLifetime maxLength:4];
        actionAttachment.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:messageLifetime], @"messageLifetime", nil];
    }
    else if (actionType == TGMessageActionEncryptedChatScreenshot)
    {
    }
    else if (actionType == TGMessageActionChannelCreated)
    {
        int length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        uint8_t *titleBytes = malloc(length);
        [is read:titleBytes maxLength:length];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        actionAttachment.actionData = [NSDictionary dictionaryWithObject:(title == nil ? @"" : title) forKey:@"title"];
    }
    else if (actionType == TGMessageActionChannelCommentsStatusChanged) {
        uint8_t enabled = 0;
        [is read:(uint8_t *)&enabled maxLength:1];
        actionAttachment.actionData = @{@"enabled": @(enabled != 0)};
    } else if (actionType == TGMessageActionChannelInviter) {
        int64_t uid = TGActionMediaAttachmentReadId(is, wideIds, &dataLength);
        actionAttachment.actionData = @{@"uid": @(uid)};
    } else if (actionType == TGMessageActionGroupMigratedTo) {
        int64_t channelId = wideIds ? TGActionMediaAttachmentReadId(is, true, &dataLength) : (int64_t)(uint32_t)TGActionMediaAttachmentReadId(is, false, &dataLength);
        actionAttachment.actionData = @{@"channelId": @(channelId)};
    } else if (actionType == TGMessageActionChannelMigratedFrom) {
        int length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        uint8_t *titleBytes = malloc(length);
        [is read:titleBytes maxLength:length];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        
        int64_t groupId = TGActionMediaAttachmentReadId(is, wideIds, &dataLength);
        
        actionAttachment.actionData = @{@"groupId": @(groupId), @"title": title};
    } else if (actionType == TGMessageActionPinnedMessage) {
    } else if (actionType == TGMessageActionClearChat) {
    } else if (actionType == TGMessageActionGameScore) {
        int gameId = 0;
        [is read:(uint8_t *)&gameId maxLength:4];
        int score = 0;
        [is read:(uint8_t *)&score maxLength:4];
        actionAttachment.actionData = @{@"gameId": @(gameId), @"score": @(score)};
    } else if (actionType == TGMessageActionPhoneCall) {
        int64_t callId = 0;
        [is read:(uint8_t *)&callId maxLength:8];
        int32_t reason = 0;
        [is read:(uint8_t *)&reason maxLength:4];
        int32_t duration = 0;
        [is read:(uint8_t *)&duration maxLength:4];
        actionAttachment.actionData = @{@"callId": @(callId), @"reason": @(reason), @"duration": @(duration)};
    } else if (actionType == TGMessageActionPaymentSent) {
        int32_t currencyLength = 0;
        [is read:(uint8_t *)&currencyLength maxLength:4];
        uint8_t *titleBytes = malloc(currencyLength);
        [is read:titleBytes maxLength:currencyLength];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:currencyLength encoding:NSUTF8StringEncoding freeWhenDone:true];
        int32_t totalAmount = 0;
        [is read:(uint8_t *)&totalAmount maxLength:4];
        actionAttachment.actionData = @{@"currency": title, @"totalAmount": @(totalAmount)};
    } else if (actionType == TGMessageActionText) {
        int32_t textLength = 0;
        [is read:(uint8_t *)&textLength maxLength:4];
        uint8_t *titleBytes = malloc(textLength);
        [is read:titleBytes maxLength:textLength];
        NSString *title = [[NSString alloc] initWithBytesNoCopy:titleBytes length:textLength encoding:NSUTF8StringEncoding freeWhenDone:true];
        actionAttachment.actionData = @{@"text": title};
    } else if (actionType == TGMessageActionBotAllowed) {
        int32_t domainLength = 0;
        [is read:(uint8_t *)&domainLength maxLength:4];
        uint8_t *domainBytes = malloc(domainLength);
        [is read:domainBytes maxLength:domainLength];
        NSString *domain = [[NSString alloc] initWithBytesNoCopy:domainBytes length:domainLength encoding:NSUTF8StringEncoding freeWhenDone:true];
        if (domain == nil)
            domain = @"";
        actionAttachment.actionData = @{@"domain": domain};
    } else if (actionType == TGMessageActionSecureValuesSent) {
        int32_t valuesLength = 0;
        [is read:(uint8_t *)&valuesLength maxLength:4];
        uint8_t *valuesBytes = malloc(valuesLength);
        [is read:valuesBytes maxLength:valuesLength];
        NSString *values = [[NSString alloc] initWithBytesNoCopy:valuesBytes length:valuesLength encoding:NSUTF8StringEncoding freeWhenDone:true];
        if (values == nil)
            values = @"";
        actionAttachment.actionData = @{@"values": values};
    } else if (actionType == TGMessageActionCommunityChanged) {
        int64_t communityId = 0;
        [is read:(uint8_t *)&communityId maxLength:8];
        actionAttachment.actionData = @{@"communityId": @(communityId)};
    } else if (actionType == TGMessageActionStarGift || actionType == TGMessageActionStarGiftUnique || actionType == TGMessageActionStarGiftPurchaseOffer || actionType == TGMessageActionStarGiftPurchaseOfferDeclined) {
        int32_t length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        if (length > 0 && length <= 4 * 1024 * 1024 && length <= dataLength - 4)
        {
            NSMutableData *archive = [[NSMutableData alloc] initWithLength:(NSUInteger)length];
            NSInteger totalRead = 0;
            while (totalRead < length)
            {
                NSInteger count = [is read:(uint8_t *)archive.mutableBytes + totalRead maxLength:(NSUInteger)(length - totalRead)];
                if (count <= 0)
                    break;
                totalRead += count;
            }
            if (totalRead == length)
            {
                @try
                {
                    id fields = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
                    if ([fields isKindOfClass:[NSDictionary class]])
                        actionAttachment.actionData = fields;
                }
                @catch (NSException *exception)
                {
                    actionAttachment.actionData = nil;
                }
            }
        }
    }
    
    return actionAttachment;
}

@end
