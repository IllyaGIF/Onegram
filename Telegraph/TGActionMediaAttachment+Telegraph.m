#import "TGActionMediaAttachment+Telegraph.h"

#import "TGImageMediaAttachment+Telegraph.h"

#import "TGCallDiscardReason.h"

#import "TLMessageAction$messageActionPhoneCall.h"
#import "TLMessageAction$messageActionChangeCommunity.h"
#import "TLMessage$modernMessageService.h"
#import "TGTLDynamic.h"
#import "TGStarGift.h"
#import "TGStoryItem.h"

@implementation TGActionMediaAttachment (Telegraph)

- (id)initWithTelegraphActionDesc:(TLMessageAction *)actionDesc
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGActionMediaAttachmentType;
        
        if ([actionDesc isKindOfClass:[TGStarGiftTLMessageAction class]])
        {
            TGTLDynamicObject *object = ((TGStarGiftTLMessageAction *)actionDesc).giftAction;
            TGStarGift *gift = [TGStarGift starGiftWithObject:[object objectField:@"gift"]];
            if (gift != nil)
            {
                if ([object isConstructor:@"messageActionStarGift"])
                    self.actionType = TGMessageActionStarGift;
                else if ([object isConstructor:@"messageActionStarGiftUnique"])
                    self.actionType = TGMessageActionStarGiftUnique;
                else if ([object isConstructor:@"messageActionStarGiftPurchaseOffer"])
                    self.actionType = TGMessageActionStarGiftPurchaseOffer;
                else if ([object isConstructor:@"messageActionStarGiftPurchaseOfferDeclined"])
                    self.actionType = TGMessageActionStarGiftPurchaseOfferDeclined;

                TGTLDynamicObject *price = [object objectField:@"price"];
                TGTLDynamicObject *resalePrice = [object objectField:@"resale_amount"];
                NSString *messageText = [[object objectField:@"message"] stringField:@"text"];
                self.actionData = @{
                    @"gift": gift,
                    @"actionKind": object.constructor,
                    @"message": messageText ?: @"",
                    @"nameHidden": @([object flag:@"name_hidden"]),
                    @"saved": @([object flag:@"saved"]),
                    @"converted": @([object flag:@"converted"]),
                    @"upgraded": @([object flag:@"upgraded"] || [object flag:@"upgrade"]),
                    @"transferred": @([object flag:@"transferred"]),
                    @"canUpgrade": @([object flag:@"can_upgrade"]),
                    @"refunded": @([object flag:@"refunded"]),
                    @"prepaidUpgrade": @([object flag:@"prepaid_upgrade"]),
                    @"upgradeSeparate": @([object flag:@"upgrade_separate"]),
                    @"auctionAcquired": @([object flag:@"auction_acquired"]),
                    @"assigned": @([object flag:@"assigned"]),
                    @"fromOffer": @([object flag:@"from_offer"]),
                    @"craft": @([object flag:@"craft"]),
                    @"accepted": @([object flag:@"accepted"]),
                    @"declined": @([object flag:@"declined"]),
                    @"expired": @([object flag:@"expired"]),
                    @"convertStars": @([object int64Field:@"convert_stars"]),
                    @"upgradeStars": @([object int64Field:@"upgrade_stars"]),
                    @"transferStars": @([object int64Field:@"transfer_stars"]),
                    @"savedId": @([object int64Field:@"saved_id"]),
                    @"upgradeMessageId": @([object int32Field:@"upgrade_msg_id"]),
                    @"giftMessageId": @([object int32Field:@"gift_msg_id"]),
                    @"giftNum": @([object int32Field:@"gift_num"]),
                    @"fromPeerId": @(TGStoryPeerIdFromObject([object objectField:@"from_id"])),
                    @"toPeerId": @(TGStoryPeerIdFromObject([object objectField:@"to_id"])),
                    @"ownerPeerId": @(TGStoryPeerIdFromObject([object objectField:@"peer"])),
                    @"priceStars": @([price int64Field:@"amount"]),
                    @"resaleStars": @([resalePrice int64Field:@"amount"]),
                    @"expiresAt": @([object int32Field:@"expires_at"]),
                    @"canExportAt": @([object int32Field:@"can_export_at"]),
                    @"canTransferAt": @([object int32Field:@"can_transfer_at"]),
                    @"canResellAt": @([object int32Field:@"can_resell_at"]),
                    @"canCraftAt": @([object int32Field:@"can_craft_at"]),
                    @"dropDetailsStars": @([object int64Field:@"drop_original_details_stars"]),
                    @"prepaidUpgradeHash": [object stringField:@"prepaid_upgrade_hash"] ?: @""
                };
            }
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChatAddUser class]])
        {
            TLMessageAction$messageActionChatAddUser *concreteAction = (TLMessageAction$messageActionChatAddUser *)actionDesc;
            self.actionType = TGMessageActionChatAddMember;
            self.actionData = @{@"uids": concreteAction.users};
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChatAddUserLegacy class]])
        {
            TLMessageAction$messageActionChatAddUserLegacy *concreteAction = (TLMessageAction$messageActionChatAddUserLegacy *)actionDesc;
            self.actionType = TGMessageActionChatAddMember;
            self.actionData = @{@"uids": @[@(concreteAction.user_id)]};
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChatDeleteUser class]])
        {
            TLMessageAction$messageActionChatDeleteUser *concreteAction = (TLMessageAction$messageActionChatDeleteUser *)actionDesc;
            self.actionType = TGMessageActionChatDeleteMember;
            self.actionData = [NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:concreteAction.user_id] forKey:@"uid"];
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChatEditTitle class]])
        {
            TLMessageAction$messageActionChatEditTitle *concreteAction = (TLMessageAction$messageActionChatEditTitle *)actionDesc;
            self.actionType = TGMessageActionChatEditTitle;
            self.actionData = [NSDictionary dictionaryWithObject:(concreteAction.title == nil ? @"" : concreteAction.title) forKey:@"title"];
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChatCreate class]])
        {
            TLMessageAction$messageActionChatCreate *concreteAction = (TLMessageAction$messageActionChatCreate *)actionDesc;
            self.actionType = TGMessageActionCreateChat;
            self.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:concreteAction.title, @"title", concreteAction.users, @"uids", nil];
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChatEditPhoto class]])
        {
            TLMessageAction$messageActionChatEditPhoto *concreteAction = (TLMessageAction$messageActionChatEditPhoto *)actionDesc;
            self.actionType = TGMessageActionChatEditPhoto;
            TGImageMediaAttachment *photo = [[TGImageMediaAttachment alloc] initWithTelegraphDesc:concreteAction.photo];
            self.actionData = [[NSDictionary alloc] initWithObjectsAndKeys: photo, @"photo", nil];
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChatDeletePhoto class]])
        {
            self.actionType = TGMessageActionChatEditPhoto;
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionSentRequest class]])
        {
            self.actionType = TGMessageActionContactRequest;
            self.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithBool:((TLMessageAction$messageActionSentRequest *)actionDesc).has_phone], @"hasPhone", nil];
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionAcceptRequest class]])
        {
            self.actionType = TGMessageActionAcceptContactRequest;
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChatJoinedByLink class]])
        {
            TLMessageAction$messageActionChatJoinedByLink *concreteAction = (TLMessageAction$messageActionChatJoinedByLink *)actionDesc;
            self.actionType = TGMessageActionJoinedByLink;
            self.actionData = @{ @"invitedBy": @(concreteAction.inviter_id) };
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChatJoinedByRequest class]])
        {
            self.actionType = TGMessageActionJoinedByLink;
            self.actionData = @{ @"invitedBy": @0, @"joinedByRequest": @true };
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChannelCreate class]])
        {
            TLMessageAction$messageActionChannelCreate *concreteAction = (TLMessageAction$messageActionChannelCreate *)actionDesc;
            self.actionType = TGMessageActionChannelCreated;
            self.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:concreteAction.title, @"title", nil];
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChannelToggleComments class]]) {
            TLMessageAction$messageActionChannelToggleComments *concreteAction = (TLMessageAction$messageActionChannelToggleComments *)actionDesc;
            self.actionType = TGMessageActionChannelCommentsStatusChanged;
            self.actionData = [[NSDictionary alloc] initWithObjectsAndKeys:@(concreteAction.enabled), @"enabled", nil];
        }
        else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChatMigrateTo class]]) {
            self.actionType = TGMessageActionGroupMigratedTo;
            self.actionData = @{@"channelId": @(((TLMessageAction$messageActionChatMigrateTo *)actionDesc).channel_id)};
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChatDeactivate class]]) {
            self.actionType = TGMessageActionGroupDeactivated;
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChatActivate class]]) {
            self.actionType = TGMessageActionGroupActivated;
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChannelMigrateFrom class]]) {
            self.actionType = TGMessageActionChannelMigratedFrom;
            self.actionData = @{@"groupId": @(((TLMessageAction$messageActionChannelMigrateFrom *)actionDesc).chat_id), @"title": ((TLMessageAction$messageActionChannelMigrateFrom *)actionDesc).title};
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionPinMessage class]]) {
            self.actionType = TGMessageActionPinnedMessage;
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionHistoryClear class]]) {
            self.actionType = TGMessageActionClearChat;
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionGameScore class]]) {
            self.actionType = TGMessageActionGameScore;
            self.actionData = @{@"gameId": @(((TLMessageAction$messageActionGameScore *)actionDesc).game_id), @"score": @(((TLMessageAction$messageActionGameScore *)actionDesc).score)};
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionPhoneCall class]]) {
            self.actionType = TGMessageActionPhoneCall;
            self.actionData = @{@"callId": @(((TLMessageAction$messageActionPhoneCall *)actionDesc).call_id), @"reason": @([TGCallDiscardReasonAdapter reasonForTLObject:((TLMessageAction$messageActionPhoneCall *)actionDesc).reason]), @"duration": @(((TLMessageAction$messageActionPhoneCall *)actionDesc).duration), };
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionPaymentSent class]]) {
            TLMessageAction$messageActionPaymentSent *action = (TLMessageAction$messageActionPaymentSent *)actionDesc;
            self.actionType = TGMessageActionPaymentSent;
            self.actionData = @{@"currency": action.currency, @"totalAmount": @(action.total_amount)};
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionScreenshotTaken class]]) {
            self.actionType = TGMessageActionEncryptedChatMessageScreenshot;
            self.actionData = @{};
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionCustomAction class]]) {
            self.actionType = TGMessageActionText;
            self.actionData = @{@"text": ((TLMessageAction$messageActionCustomAction *)actionDesc).message};
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionChangeCommunity class]]) {
            self.actionType = TGMessageActionCommunityChanged;
            self.actionData = @{@"communityId": @(((TLMessageAction$messageActionChangeCommunity *)actionDesc).community_id)};
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionPaidMessagesRefunded class]]) {
            TLMessageAction$messageActionPaidMessagesRefunded *action = (TLMessageAction$messageActionPaidMessagesRefunded *)actionDesc;
            self.actionType = TGMessageActionPaidMessagesRefunded;
            self.actionData = @{@"count": @(action.count), @"stars": @(action.stars)};
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionPaidMessagesPrice class]]) {
            TLMessageAction$messageActionPaidMessagesPrice *action = (TLMessageAction$messageActionPaidMessagesPrice *)actionDesc;
            self.actionType = TGMessageActionPaidMessagesPrice;
            self.actionData = @{@"stars": @(action.stars), @"broadcastMessagesAllowed": @((action.flags & (1 << 0)) != 0)};
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionNoPaidMessagesTokenUsed class]]) {
            self.actionType = TGMessageActionNoPaidMessagesTokenUsed;
            self.actionData = @{};
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionBotAllowed class]]) {
            self.actionType = TGMessageActionBotAllowed;
            self.actionData = @{@"domain": ((TLMessageAction$messageActionBotAllowed *)actionDesc).domain};
        } else if ([actionDesc isKindOfClass:[TLMessageAction$messageActionSecureValuesSent class]]) {
            self.actionType = TGMessageActionSecureValuesSent;
            NSString *values = @"";
            for (TLSecureValueType *type in ((TLMessageAction$messageActionSecureValuesSent *)actionDesc).types)
            {
                NSString *stringType = @"";
                if ([type isKindOfClass:[TLSecureValueType$secureValueTypePersonalDetails class]])
                    stringType = @"personal_details";
                else if ([type isKindOfClass:[TLSecureValueType$secureValueTypePassport class]])
                    stringType = @"passport";
                else if ([type isKindOfClass:[TLSecureValueType$secureValueTypeDriverLicense class]])
                    stringType = @"driver_license";
                else if ([type isKindOfClass:[TLSecureValueType$secureValueTypeIdentityCard class]])
                    stringType = @"identity_card";
                else if ([type isKindOfClass:[TLSecureValueType$secureValueTypeInternalPassport class]])
                    stringType = @"internal_passport";
                else if ([type isKindOfClass:[TLSecureValueType$secureValueTypeAddress class]])
                    stringType = @"address";
                else if ([type isKindOfClass:[TLSecureValueType$secureValueTypeUtilityBill class]])
                    stringType = @"utility_bill";
                else if ([type isKindOfClass:[TLSecureValueType$secureValueTypeBankStatement class]])
                    stringType = @"bank_statement";
                else if ([type isKindOfClass:[TLSecureValueType$secureValueTypeRentalAgreement class]])
                    stringType = @"rental_agreement";
                else if ([type isKindOfClass:[TLSecureValueType$secureValueTypePassportRegistration class]])
                    stringType = @"passport_registration";
                else if ([type isKindOfClass:[TLSecureValueType$secureValueTypeTemporaryRegistration class]])
                    stringType = @"temporary_registration";
                else if ([type isKindOfClass:[TLSecureValueType$secureValueTypePhone class]])
                    stringType = @"phone";
                else if ([type isKindOfClass:[TLSecureValueType$secureValueTypeEmail class]])
                    stringType = @"email";
                
                if (values.length == 0)
                    values = stringType;
                else
                    values = [values stringByAppendingFormat:@",%@", stringType];
            }
            self.actionData = @{@"values":values};
        }
    }
    return self;
}

@end
