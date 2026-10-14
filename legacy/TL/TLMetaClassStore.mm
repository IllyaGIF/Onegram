
#include "TLMetaClassStore.h"
#import "../../OnegramPlatform/OGPlatformDispatch.h"
#import "TLAuthorization.h"
#import "TLaccount_Authorizations.h"
#import "../../OnegramRuntime/OGRuntime.h"
#import <pthread.h>
#import <objc/runtime.h>

volatile int32_t TGTLParserCurrentSignature = 0;
volatile int32_t TGTLParserLastSignature = 0;
volatile int32_t TGTLParserVectorItemSignature = 0;
volatile int32_t TGTLParserVectorItemIndex = -1;
volatile int32_t TGTLParserVectorItemCount = 0;

static inline void CodexCooperateWithInteraction(int32_t index)
{
    if ((index & 3) != 3)
        return;
    if (!OGPlatformUsesConstrainedBackgroundExecution() && !OGRuntimeSingleCoreDevice())
        return;
    OGRuntimeCooperateWithInteraction();
}

class TGTLParserSignatureScope
{
private:
    int32_t _previousSignature;
    int32_t _signature;

public:
    explicit TGTLParserSignatureScope(int32_t signature) : _previousSignature(TGTLParserCurrentSignature), _signature(signature)
    {
        TGTLParserCurrentSignature = signature;
    }

    ~TGTLParserSignatureScope()
    {
        TGTLParserLastSignature = _signature;
        TGTLParserCurrentSignature = _previousSignature;
    }
};

#import "../../../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "NSData+GZip.h"
#import "NSInputStream+TL.h"

#import "TLCompressedObject.h"
#import "TLMessageContainer.h"
#import "TLRpcResult.h"
#import "TLRPCphone_sendSignalingData.h"
#import "TLRPCmessages_sendMessage_manual.h"
#import "../../../Telegraph/IOS6FeatureProbe.h"

#import "TLResPQ$resPQ_manual.h"
#import "TLMsgsAck$msgs_ack_manual.h"
#import "TLMessage$modernMessage.h"
#import "TLMessage$modernMessageService.h"
#import "TLMessage.h"
#import "TLWebPage_manual.h"
#import "TLWebPage.h"
#import "TLUser$modernUser.h"
#import "TLDcOption$modernDcOption.h"
#import "TLUpdates$modernUpdateShortMessage.h"
#import "TLUpdates$modernUpdateShortChatMessage.h"
#import "TLaccount_PasswordInputSettings_manual.h"
#import "TLmessages_Messages$modernChannelMessages.h"
#import "TLmessages_Messages.h"
#import "TLPeerSettings.h"
#import "TLBotInfo.h"
#import "TLBotCommand.h"
#import "TLReplyMarkup.h"
#import "TLKeyboardButton.h"
#import "TLKeyboardButtonRow.h"
#import "TLchannels_ChannelParticipants.h"
#import "TLchannels_ChannelParticipant.h"
#import "TLChannelParticipant.h"
#import "TLChannelAdminRights.h"
#import "TLUpdate.h"
#import "TLUpdate$updateChangePts.h"
#import "TLUpdates.h"
#import "TLUpdates$updateShortSentMessage.h"
#import "TLUpdates_ChannelDifference_manual.h"
#import "TLupdates_ChannelDifference.h"
#import "TLupdates_Difference.h"
#import "TLupdates_State.h"
#import "TLChat$channel.h"
#import "TLChatFull$channelFull.h"
#import "TLChat$chat.h"
#import "TLChatPhoto.h"
#import "TLChatParticipant.h"
#import "TLChatParticipants$chatParticipantsForbidden.h"
#import "TLWebPage$webPageExternal.h"
#import "TLMessages_BotResults$botResults.h"
#import "TLBotInlineMessage$botInlineMessageMediaAuto.h"
#import "TLBotInlineMessage$botInlineMessageText.h"
#import "TLBotInlineResult$botInlineResult.h"
#import "TLDocumentAttribute$documentAttributeAudio.h"
#import "TLDocument.h"
#import "TLDocumentAttribute.h"
#import "TLMessageAction.h"
#import "TLMessageEntity.h"
#import "TLMessageFwdHeader$messageFwdHeader.h"
#import "TLUserFull$userFull.h"
#import "TLUpdate$updateChannelTooLong.h"
#import "TLauth_SentCode$auth_sentCode.h"
#import "TLmessages_BotCallbackAnswer$botCallbackAnswer.h"
#import "TLBotInlineResult$botInlineMediaResult.h"
#import "TLBotInlineMessage$botInlineMessageMediaGeo.h"
#import "TLBotInlineMessage$botInlineMessageMediaVenue.h"
#import "TLBotInlineMessage$botInlineMessageMediaContact.h"
#import "TLDialog$dialog.h"
#import "TLDialog$dialogFeed.h"
#import "TLPeer.h"
#import "TLDialogPeer.h"
#import "TLImportedContact.h"
#import "TLDraftMessage$draftMessage.h"
#import "TLChatInvite$chatInvite.h"
#import "TLConfig$config.h"
#import "TLGame$game.h"
#import "TLPageBlock$pageBlockEmbed.h"
#import "TLPhoneCall.h"
#import "TLPhoneCall$phoneCallWaiting.h"
#import "TLUpdate$updateServiceNotification.h"
#import "TLPhoneCall$phoneCallDiscarded.h"
#import "TLPhoneConnection.h"
#import "TLUpdate$updatePinnedDialogs.h"
#import "TLMessageAction$messageActionPhoneCall.h"
#import "TLInvoice$invoice.h"
#import "TLMessageMedia$messageMediaInvoice.h"
#import "TLpayments_PaymentForm$payments_paymentForm.h"
#import "TLpayments_SavedInfo$payments_savedInfo.h"
#import "TLPaymentRequestedInfo$paymentRequestedInfo.h"
#import "TLPayments_PaymentCeceipt$payments_paymentReceipt.h"
#import "TLpayments_ValidatedRequestedInfo$payments_validatedRequestedInfo.h"
#import "TLLangPackStringPluralized.h"
#import "TLChat$channelForbidden.h"
#import "TLMessageMedia$messageMediaPhoto.h"
#import "TLMessageMedia$messageMediaDocument.h"
#import "TLMessageMedia.h"
#import "TLGeoPoint.h"
#import "TLPhoto.h"
#import "TLPhotoSize.h"
#import "TLContact.h"
#import "TLcontacts_Contacts.h"
#import "TLcontacts_Blocked.h"
#import "TLcontacts_ImportedContacts.h"
#import "TLmessages_Dialogs.h"
#import "TLDialog.h"
#import "TLPopularContact.h"
#import "TLchannelDifferenceTooLong.h"
#import "TLmessages_FeedMessages$messages_feedMessages.h"
#import "TLchannels_FeedSources$channels_feedSources.h"
#import "TLInputSingleMedia$inputSingleMedia.h"
#import "TLStickerSet$stickerSet.h"
#import "TLStickerSetCovered.h"
#import "TLmessages_AllStickers.h"
#import "TLmessages_FavedStickers.h"
#import "TLmessages_FeaturedStickers.h"
#import "TLmessages_FoundStickerSets.h"
#import "TLmessages_RecentStickers.h"
#import "TLmessages_StickerSet.h"
#import "TLmessages_StickerSetInstallResult.h"
#import "TLInputStickerSet.h"
#import "TLStickerPack.h"
#import "TLMaskCoords.h"
#import "TLauth_ExportedAuthorization.h"
#import "TLUpdate$updateReadFeed.h"
#import "TLhelp_ProxyData.h"
#import "TLhelp_TermsOfService$help_termsOfService.h"
#import "TLSecureValue$secureValue.h"
#import "TLInputSecureValue$inputSecureValue.h"
#import "TLaccount_AuthorizationForm$account_authorizationForm.h"
#import "TLPeerNotifySettings$peerNotifySettings.h"
#import "TLhelp_DeepLinkInfo$help_deepLinkInfo.h"
#import "TLhelp_AppUpdate$help_appUpdate.h"
#import "TLaccount_Password$account_password.h"
#import "TLaccount_PasswordSettings$account_passwordSettings.h"
#import "TLUserStatus.h"
#import "TLUserProfilePhoto.h"
#import "TLContactStatus.h"

#import "TLDocumentAttributeSticker.h"

#import "TLBool.h"

#import "TLauth_Authorization$auth_authorization.h"

#include <map>
#include <set>
#include <string>
#include <algorithm>
#include <string.h>
#include <ctype.h>

#include <zlib.h>
#include <pthread.h>

struct TLMetaTypeArgumentWithName : public TLMetaTypeArgument
{
    std::vector<char> name;
};

static std::tr1::unordered_map<int32_t, NSString *> hashToStringMap;

std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaConstructor> > TLMetaClassStore::constructorsBySignature;
std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaConstructor> > TLMetaClassStore::constructorsByName;
std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaType> > TLMetaClassStore::typesByName;
std::tr1::unordered_map<int32_t, TLMetaTypeArgument> TLMetaClassStore::vectorElementTypesByConstructor;

std::tr1::unordered_map<int32_t, id<TLObject> > TLMetaClassStore::objectClassesByConstructorNames;
std::tr1::unordered_map<int32_t, id<TLVector> > TLMetaClassStore::vectorClassesBySignature;

std::map<int32_t, TLManualObjectParser> TLMetaClassStore::manualObjectParsers;

#define TLLazyManualObjectParser(parserClass) TLManualObjectParser(#parserClass)

static id<TLObject> TLInstantiateManualObjectParser(const char *parserClassName)
{
    Class parserClass = parserClassName == NULL ? Nil : objc_getClass(parserClassName);
    if (parserClass == Nil)
    {
        NSLog(@"TL manual parser class missing name=%s", parserClassName == NULL ? "" : parserClassName);
        return nil;
    }
    return [[parserClass alloc] init];
}
std::map<int32_t, id<TLObject> > TLMetaClassStore::manualObjectSerializers;

static pthread_mutex_t *TGIOS3TLParserMutex()
{
    static pthread_mutex_t mutex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        pthread_mutexattr_t attributes;
        pthread_mutexattr_init(&attributes);
        pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&mutex, &attributes);
        pthread_mutexattr_destroy(&attributes);
    });
    return &mutex;
}

static dispatch_group_t TGTLObjectClassRegistrationGroup()
{
    static dispatch_group_t group = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        group = dispatch_group_create();
    });
    return group;
}

static volatile bool TGTLObjectClassRegistrationPending = false;

class TGTLClassRegistryGuard
{
public:
    TGTLClassRegistryGuard()
    {
        pthread_mutex_lock(TGIOS3TLParserMutex());
    }

    ~TGTLClassRegistryGuard()
    {
        pthread_mutex_unlock(TGIOS3TLParserMutex());
    }
};

static const char *TLMetaClassNameForKey(TLMetaClassEntry const *entries, uint32_t count, const char *classNames, int32_t key)
{
    uint32_t low = 0;
    uint32_t high = count;
    while (low < high)
    {
        uint32_t middle = low + (high - low) / 2;
        if (entries[middle].key < key)
            low = middle + 1;
        else
            high = middle;
    }
    if (low < count && entries[low].key == key)
        return classNames + entries[low].className;
    return NULL;
}

static id TLMetaClassInstantiate(TLMetaClassEntry const *entries, uint32_t count, const char *classNames, int32_t key)
{
    const char *className = TLMetaClassNameForKey(entries, count, classNames, key);
    if (className == NULL)
        return nil;
    id objectClass = objc_getClass(className);
    if (objectClass == nil)
        return nil;
    return [[objectClass alloc] init];
}

@interface TLCodexThreadContext : NSObject
{
@public
    int32_t currentManualSignature;
    NSString *currentManualParser;
    int32_t lastCompletedManualSignature;
    NSString *lastCompletedManualParser;
    NSString *currentVectorRole;
    TLupdates_State *lastReadUpdatesState;
}
@end

@implementation TLCodexThreadContext
@end

static pthread_key_t CodexThreadContextKey;
static pthread_once_t CodexThreadContextOnce = PTHREAD_ONCE_INIT;

static void CodexThreadContextDestroy(void *value)
{
    if (value != NULL)
    {
        TLCodexThreadContext *context = (__bridge_transfer TLCodexThreadContext *)value;
        (void)context;
    }
}

static void CodexThreadContextInitialize(void)
{
    pthread_key_create(&CodexThreadContextKey, CodexThreadContextDestroy);
}

static TLCodexThreadContext *CodexThreadContextGet(void)
{
    pthread_once(&CodexThreadContextOnce, CodexThreadContextInitialize);
    TLCodexThreadContext *context = (__bridge TLCodexThreadContext *)pthread_getspecific(CodexThreadContextKey);
    if (context == nil)
    {
        context = [[TLCodexThreadContext alloc] init];
        pthread_setspecific(CodexThreadContextKey, (__bridge_retained void *)context);
    }
    return context;
}

#define CodexCurrentManualSignature (CodexThreadContextGet()->currentManualSignature)
#define CodexCurrentManualParser (CodexThreadContextGet()->currentManualParser)
#define CodexLastCompletedManualSignature (CodexThreadContextGet()->lastCompletedManualSignature)
#define CodexLastCompletedManualParser (CodexThreadContextGet()->lastCompletedManualParser)
#define CodexCurrentVectorRole (CodexThreadContextGet()->currentVectorRole)
#define CodexLastReadUpdatesState (CodexThreadContextGet()->lastReadUpdatesState)

static void addHashToString(int32_t hash, NSString *string)
{
    std::tr1::unordered_map<int32_t, NSString *>::iterator it = hashToStringMap.find(hash);
    if (it != hashToStringMap.end() && [it->second isEqualToString:string])
        return;
    hashToStringMap[hash] = [string copy];
}

static NSString *stringForHash(int32_t hash)
{
    std::tr1::unordered_map<int32_t, NSString *>::iterator it = hashToStringMap.find(hash);
    if (it == hashToStringMap.end())
        return [NSString stringWithFormat:@"#%.8x", hash];
    return it->second;
}

static id<TLObject> CodexReadObject(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t signature = [is readInt32];
    return TLMetaClassStore::constructObject(is, signature, environment, nil, error);
}

static NSArray *CodexReadObjectVector(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error);

static int32_t CodexReadReplyHeaderCompat(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t signature = [is readInt32];
    if (signature == (int32_t)0xafbc09db || signature == (int32_t)0x1b97dd66 || signature == (int32_t)0x6917560b)
    {
        int32_t flags = [is readInt32];
        int32_t replyToMessageId = 0;
        if (flags & (1 << 4))
            replyToMessageId = [is readInt32];
        if (flags & (1 << 0))
            CodexReadObject(is, environment, error);
        if (flags & (1 << 5))
            CodexReadObject(is, environment, error);
        if (flags & (1 << 8))
            CodexReadObject(is, environment, error);
        if (flags & (1 << 1))
            [is readInt32];
        if (flags & (1 << 6))
            [is readString];
        if (flags & (1 << 7))
            CodexReadObjectVector(is, environment, error);
        if (flags & (1 << 10))
            [is readInt32];
        if ((signature == (int32_t)0x1b97dd66 || signature == (int32_t)0x6917560b) && (flags & (1 << 11)))
            [is readInt32];
        if (signature == (int32_t)0x1b97dd66 && (flags & (1 << 12)))
            [is readBytes];
        return replyToMessageId;
    }
    if (signature > 0 && signature < 10000000)
        return signature;
    TLMetaClassStore::constructObject(is, signature, environment, nil, error);
    return 0;
}

static NSArray *CodexReadObjectVectorWithMarker(NSInputStream *is, int32_t vectorMarker, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error);
static NSArray *CodexReadObjectVectorOrSingleWithMarker(NSInputStream *is, int32_t vectorMarker, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error);

static NSArray *CodexReadObjectVector(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t vectorMarker = [is readInt32];
    return CodexReadObjectVectorWithMarker(is, vectorMarker, environment, error);
}

static NSArray *CodexReadObjectVectorWithRole(NSInputStream *is, NSString *role, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    NSString *previousRole = CodexCurrentVectorRole;
    CodexCurrentVectorRole = role;
    NSArray *result = CodexReadObjectVector(is, environment, error);
    if (error != NULL && *error != nil)
    {
        NSString *description = (*error).localizedDescription ?: @"TL vector parse failed";
        *error = [NSError errorWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@: %@", role ?: @"vector", description]}];
    }
    CodexCurrentVectorRole = previousRole;
    return result;
}

static NSArray *CodexReadMaybeDoubleObjectVectorWithMarker(NSInputStream *is, int32_t vectorMarker, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    if (vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
    {
        int32_t nextMarker = [is readInt32];
        return CodexReadObjectVectorWithMarker(is, nextMarker, environment, error);
    }
    return CodexReadObjectVectorWithMarker(is, vectorMarker, environment, error);
}

static NSArray *CodexReadObjectVectorWithMarker(NSInputStream *is, int32_t vectorMarker, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t count = 0;
    if (vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
        count = [is readInt32];
    else if (vectorMarker >= 0 && vectorMarker <= 10000)
        count = vectorMarker;
    else
    {
        TLMetaClassStore::constructObject(is, vectorMarker, environment, nil, error);
        if (error != NULL && *error != nil)
        {
            *error = nil;
        }
        return @[];
    }
    
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)MAX(0, count)];
    for (int32_t i = 0; i < count; i++)
    {
        bool itemFailed = false;
        int32_t objectSignature = 0;
        @autoreleasepool
        {
            NSError *itemError = nil;
            objectSignature = [is readInt32];
            if (objectSignature == 0 && CodexCurrentManualSignature == (int32_t)0x8fd4c4d8)
            {
                continue;
            }
            id object = TLMetaClassStore::constructObject(is, objectSignature, environment, nil, &itemError);
            if (object != nil)
                [array addObject:object];
            if (itemError != nil)
            {
                itemFailed = true;
            }
        }
        if (itemFailed)
        {
            if (error != NULL)
            {
                NSString *description = [NSString stringWithFormat:@"Vector item %d/%d with signature %08x could not be parsed", i, count, objectSignature];
                *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: description}];
            }
            break;
        }
        CodexCooperateWithInteraction(i);
    }
    return array;
}

static NSArray *CodexReadStrictObjectVector(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    bool failed = false;
    int32_t vectorMarker = [is readInt32:&failed];
    if (failed || vectorMarker != TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
    {
        if (error != NULL)
        {
            NSString *description = failed ? @"Unexpected end of stream while reading vector constructor" : [NSString stringWithFormat:@"Expected vector constructor, got %08x", vectorMarker];
            *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: description}];
        }
        return nil;
    }

    int32_t count = [is readInt32:&failed];
    if (failed || count < 0 || count > 100000)
    {
        if (error != NULL)
        {
            NSString *description = failed ? @"Unexpected end of stream while reading vector count" : [NSString stringWithFormat:@"Invalid vector count %d", count];
            *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: description}];
        }
        return nil;
    }

    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)count];
    TGTLParserVectorItemCount = count;
    for (int32_t i = 0; i < count; i++)
    {
        int32_t objectSignature = [is readInt32:&failed];
        TGTLParserVectorItemIndex = i;
        TGTLParserVectorItemSignature = objectSignature;
        if (failed)
        {
            TGTLParserVectorItemIndex = -1;
            TGTLParserVectorItemCount = 0;
            TGTLParserVectorItemSignature = 0;
            if (error != NULL)
            {
                NSString *description = [NSString stringWithFormat:@"Unexpected end of stream at vector item %d/%d", i, count];
                *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: description}];
            }
            return nil;
        }

        NSError *itemError = nil;
        id object = TLMetaClassStore::constructObject(is, objectSignature, environment, nil, &itemError);
        if (itemError != nil || object == nil)
        {
            TGTLParserVectorItemIndex = -1;
            TGTLParserVectorItemCount = 0;
            TGTLParserVectorItemSignature = 0;
            if (error != NULL)
            {
                if (itemError != nil)
                    *error = itemError;
                else
                {
                    NSString *description = [NSString stringWithFormat:@"Vector item %d/%d with signature %08x produced no object", i, count, objectSignature];
                    *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: description}];
                }
            }
            return nil;
        }
        [array addObject:object];
        CodexCooperateWithInteraction(i);
    }
    TGTLParserVectorItemIndex = -1;
    TGTLParserVectorItemCount = 0;
    TGTLParserVectorItemSignature = 0;
    return array;
}

static NSArray *CodexReadStrictObjectVectorWithRole(NSInputStream *is, NSString *role, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    NSString *previousRole = CodexCurrentVectorRole;
    CodexCurrentVectorRole = role;
    NSArray *result = nil;
    @try
    {
        result = CodexReadStrictObjectVector(is, environment, error);
    }
    @finally
    {
        CodexCurrentVectorRole = previousRole;
    }
    if (error != NULL && *error != nil)
    {
        NSString *description = (*error).localizedDescription ?: @"TL vector parse failed";
        *error = [NSError errorWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@: %@", role ?: @"vector", description]}];
    }
    return result;
}

static NSArray *CodexReadObjectVectorOrSingle(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t vectorMarker = [is readInt32];
    return CodexReadObjectVectorOrSingleWithMarker(is, vectorMarker, environment, error);
}

static NSArray *CodexReadObjectVectorOrSingleWithMarker(NSInputStream *is, int32_t vectorMarker, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    if (vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR || (vectorMarker >= 0 && vectorMarker <= 10000))
        return CodexReadObjectVectorWithMarker(is, vectorMarker, environment, error);

    id object = TLMetaClassStore::constructObject(is, vectorMarker, environment, nil, error);
    if (object != nil)
    {
        return @[object];
    }
    return @[];
}

static void CodexSkipStringWithFirstWord(NSInputStream *is, int32_t firstWord)
{
    uint8_t firstByte = (uint8_t)(firstWord & 0xff);
    int32_t length = 0;
    int32_t alreadyConsumedDataBytes = 0;
    
    if (firstByte == 254)
    {
        length = ((firstWord >> 8) & 0xff) | ((firstWord >> 16) & 0xff) << 8 | ((firstWord >> 24) & 0xff) << 16;
        alreadyConsumedDataBytes = 0;
    }
    else
    {
        length = firstByte;
        alreadyConsumedDataBytes = MIN(length, 3);
    }
    
    int32_t remainingBytes = length - alreadyConsumedDataBytes;
    if (remainingBytes > 0)
    {
        uint8_t buffer[256];
        while (remainingBytes > 0)
        {
            int32_t chunk = MIN(remainingBytes, (int32_t)sizeof(buffer));
            [is read:buffer maxLength:(NSUInteger)chunk];
            remainingBytes -= chunk;
        }
    }
    
    int32_t totalPrefixBytes = firstByte == 254 ? 4 : 1;
    int32_t padding = (4 - ((totalPrefixBytes + length) % 4)) % 4;
    if (padding > 0 && (firstByte == 254 || length > 3))
    {
        uint8_t paddingBuffer[4];
        [is read:paddingBuffer maxLength:(NSUInteger)padding];
    }
}

static bool CodexLooksLikeStringFirstWord(int32_t firstWord)
{
    uint8_t firstByte = (uint8_t)(firstWord & 0xff);
    if (firstByte == 254)
        return true;
    if ((((uint32_t)firstWord) & 0xffff0000U) == 0x6a4a0000U)
        return true;
    return firstByte >= 4 && firstByte < 128;
}

static bool CodexLooksLikeTinyBareDocumentTailWord(int32_t word)
{
    return word == 0 || word == 1;
}

static bool CodexSkipBareDocumentAttributeTailWord(NSInputStream *is, int32_t signature)
{
    switch (signature)
    {
        case (int32_t)0x11b58939:
            return true;
        case (int32_t)0x9801d2f7:
            return true;
        case (int32_t)0x6c37c15c:
        {
            [is readInt32];
            [is readInt32];
            return true;
        }
        case (int32_t)0x15590068:
            [is readString];
            return true;
        default:
            return false;
    }
}

static NSArray *CodexReadInt64Vector(NSInputStream *is)
{
    int32_t vectorMarker = [is readInt32];
    int32_t count = 0;
    if (vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
        count = [is readInt32];
    else if (vectorMarker >= 0 && vectorMarker <= 10000)
        count = vectorMarker;
    else
    {
        return @[];
    }
    
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)MAX(0, count)];
    for (int32_t i = 0; i < count; i++)
        [array addObject:[[NSNumber alloc] initWithLongLong:[is readInt64]]];
    return array;
}

static NSArray *CodexReadInt32Vector(NSInputStream *is)
{
    int32_t vectorMarker = [is readInt32];
    int32_t count = 0;
    if (vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
        count = [is readInt32];
    else if (vectorMarker >= 0 && vectorMarker <= 10000)
        count = vectorMarker;
    else
    {
        return @[];
    }
    
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)MAX(0, count)];
    for (int32_t i = 0; i < count; i++)
        [array addObject:[[NSNumber alloc] initWithInt:[is readInt32]]];
    return array;
}

static void CodexSkipStringVector(NSInputStream *is)
{
    int32_t vectorMarker = [is readInt32];
    int32_t count = 0;
    if (vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
        count = [is readInt32];
    else if (vectorMarker >= 0 && vectorMarker <= 10000)
        count = vectorMarker;
    else
    {
        return;
    }
    for (int32_t i = 0; i < count; i++)
        [is readString];
}

static void CodexSkipBytesVector(NSInputStream *is)
{
    int32_t vectorMarker = [is readInt32];
    int32_t count = 0;
    if (vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
        count = [is readInt32];
    else if (vectorMarker >= 0 && vectorMarker <= 10000)
        count = vectorMarker;
    else
    {
        return;
    }
    for (int32_t i = 0; i < count; i++)
        [is readBytes];
}

@interface TLCodexModernPhotoParser : TLPhoto$photo
@end

@implementation TLCodexModernPhotoParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernPhotoParser *result = [[TLCodexModernPhotoParser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.n_id = [is readInt64];
    result.access_hash = [is readInt64];
    result.file_reference = [is readBytes];
    result.date = [is readInt32];
    result.sizes = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    if (flags & (1 << 1))
    {
        CodexReadObjectVector(is, environment, error);
        if (error != nil && *error != nil)
            return nil;
    }
    result.dc_id = [is readInt32];

    return result;
}

@end

static NSData *CodexDecodedStrippedThumbnail(NSData *data)
{
    static const uint8_t header[] =
    {
        0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01,
        0x00, 0x01, 0x00, 0x00, 0xff, 0xdb, 0x00, 0x43, 0x00, 0x28, 0x1c, 0x1e, 0x23, 0x1e, 0x19, 0x28,
        0x23, 0x21, 0x23, 0x2d, 0x2b, 0x28, 0x30, 0x3c, 0x64, 0x41, 0x3c, 0x37, 0x37, 0x3c, 0x7b, 0x58,
        0x5d, 0x49, 0x64, 0x91, 0x80, 0x99, 0x96, 0x8f, 0x80, 0x8c, 0x8a, 0xa0, 0xb4, 0xe6, 0xc3, 0xa0,
        0xaa, 0xda, 0xad, 0x8a, 0x8c, 0xc8, 0xff, 0xcb, 0xda, 0xee, 0xf5, 0xff, 0xff, 0xff, 0x9b, 0xc1,
        0xff, 0xff, 0xff, 0xfa, 0xff, 0xe6, 0xfd, 0xff, 0xf8, 0xff, 0xdb, 0x00, 0x43, 0x01, 0x2b, 0x2d,
        0x2d, 0x3c, 0x35, 0x3c, 0x76, 0x41, 0x41, 0x76, 0xf8, 0xa5, 0x8c, 0xa5, 0xf8, 0xf8, 0xf8, 0xf8,
        0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8,
        0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8,
        0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 0xff, 0xc0,
        0x00, 0x11, 0x08, 0x00, 0x00, 0x00, 0x00, 0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11,
        0x01, 0xff, 0xc4, 0x00, 0x1f, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
        0x0a, 0x0b, 0xff, 0xc4, 0x00, 0xb5, 0x10, 0x00, 0x02, 0x01, 0x03, 0x03, 0x02, 0x04, 0x03, 0x05,
        0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7d, 0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21,
        0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08, 0x23,
        0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0, 0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16, 0x17,
        0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a,
        0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a,
        0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a,
        0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99,
        0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7,
        0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5,
        0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf1,
        0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xff, 0xc4, 0x00, 0x1f, 0x01, 0x00, 0x03,
        0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
        0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0xff, 0xc4, 0x00, 0xb5, 0x11, 0x00,
        0x02, 0x01, 0x02, 0x04, 0x04, 0x03, 0x04, 0x07, 0x05, 0x04, 0x04, 0x00, 0x01, 0x02, 0x77, 0x00,
        0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71, 0x13,
        0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0, 0x15,
        0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34, 0xe1, 0x25, 0xf1, 0x17, 0x18, 0x19, 0x1a, 0x26, 0x27,
        0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
        0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
        0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88,
        0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6,
        0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4,
        0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe2,
        0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9,
        0xfa, 0xff, 0xda, 0x00, 0x0c, 0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3f, 0x00
    };
    static const uint8_t footer[] = {0xff, 0xd9};

    if (data == nil)
        return nil;

    CFIndex dataLength = CFDataGetLength((__bridge CFDataRef)data);
    if (dataLength < 3)
        return nil;

    const uint8_t *sourceBytes = CFDataGetBytePtr((__bridge CFDataRef)data);
    if (sourceBytes == NULL || sourceBytes[0] != 1)
        return nil;

    NSUInteger payloadLength = (NSUInteger)dataLength - 3;
    NSUInteger totalLength = sizeof(header) + payloadLength + sizeof(footer);
    NSMutableData *result = [[NSMutableData alloc] initWithLength:totalLength];
    uint8_t *resultBytes = (uint8_t *)result.mutableBytes;
    if (resultBytes == NULL)
        return nil;

    memcpy(resultBytes, header, sizeof(header));
    if (payloadLength != 0)
        memcpy(resultBytes + sizeof(header), sourceBytes + 3, payloadLength);
    memcpy(resultBytes + sizeof(header) + payloadLength, footer, sizeof(footer));

    resultBytes[164] = sourceBytes[1];
    resultBytes[166] = sourceBytes[2];
    return result;
}

@interface TLCodexModernPhotoSizeParser : TLPhotoSize$photoSizeEmpty
@end

@implementation TLCodexModernPhotoSizeParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0xde33b094)
    {
        int32_t flags = [is readInt32];
        NSString *type = [is readString];
        int32_t width = [is readInt32];
        int32_t height = [is readInt32];
        int32_t size = [is readInt32];
        if (flags & (1 << 0))
            [is readDouble];

        TLPhotoSize$photoSize *result = [[TLPhotoSize$photoSize alloc] init];
        result.type = type;
        result.w = width;
        result.h = height;
        result.size = size;
        return result;
    }
    
    if (signature == (int32_t)0xf85c413c)
    {
        [is readInt64];
        CodexReadInt32Vector(is);
        return [[TLPhotoSize$photoSizeEmpty alloc] init];
    }
    
    if (signature == (int32_t)0x0da082fe)
    {
        CodexReadObject(is, environment, error);
        if (error != nil && *error != nil)
            return nil;
        [is readInt64];
        CodexReadInt32Vector(is);
        return [[TLPhotoSize$photoSizeEmpty alloc] init];
    }
    
    NSString *type = [is readString];
    switch (signature)
    {
        case (int32_t)0x75c78e60:
        {
            TLPhotoSize$photoSize *result = [[TLPhotoSize$photoSize alloc] init];
            result.type = type;
            result.w = [is readInt32];
            result.h = [is readInt32];
            result.size = [is readInt32];

            return result;
        }
        case (int32_t)0x021e1ad6:
        {
            TLPhotoSize$photoCachedSize *result = [[TLPhotoSize$photoCachedSize alloc] init];
            result.type = type;
            result.w = [is readInt32];
            result.h = [is readInt32];
            result.bytes = [is readBytes];

            return result;
        }
        case (int32_t)0xe0b0bc2e:
        {
            NSData *strippedData = [is readBytes];
            NSData *decodedData = CodexDecodedStrippedThumbnail(strippedData);
            if (decodedData != nil)
            {
                const uint8_t *bytes = (const uint8_t *)strippedData.bytes;
                TLPhotoSize$photoCachedSize *result = [[TLPhotoSize$photoCachedSize alloc] init];
                result.type = type;
                result.w = MAX(1, (int)bytes[2]);
                result.h = MAX(1, (int)bytes[1]);
                result.bytes = decodedData;
                return result;
            }
            break;
        }
        case (int32_t)0xd8214d41:
            [is readBytes];
            break;
        case (int32_t)0xfa3efb95:
        {
            TLPhotoSize$photoSize *result = [[TLPhotoSize$photoSize alloc] init];
            result.type = type;
            result.w = [is readInt32];
            result.h = [is readInt32];
            int32_t vectorMarker = [is readInt32];
            int32_t count = 0;
            if (vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
                count = [is readInt32];
            else if (vectorMarker >= 0 && vectorMarker <= 10000)
                count = vectorMarker;
            for (int32_t i = 0; i < count; i++)
                result.size = [is readInt32];

            return result;
        }
        default:
            break;
    }
    TLPhotoSize$photoSizeEmpty *result = [[TLPhotoSize$photoSizeEmpty alloc] init];
    result.type = type;
    return result;
}

@end

@interface TLCodexModernImportedContactsParser : TLcontacts_ImportedContacts$contacts_importedContacts
@end

@implementation TLCodexModernImportedContactsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernImportedContactsParser *result = [[TLCodexModernImportedContactsParser alloc] init];
    result.imported = @[];
    result.popular_invites = @[];
    result.retry_contacts = @[];
    result.users = @[];
    if (error != NULL)
        *error = nil;
    return result;
}

@end

@interface TLCodexModernGeoPointSkipParser : NSObject <TLObject>
@end

@implementation TLCodexModernGeoPointSkipParser

- (int32_t)TLconstructorSignature
{
    return (int32_t)0xb2a2f663;
}

- (int32_t)TLconstructorName
{
    return 0;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    return nil;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    int32_t flags = [is readInt32];
    TLGeoPoint$geoPoint *result = [[TLGeoPoint$geoPoint alloc] init];
    result.n_long = [is readDouble];
    result.lat = [is readDouble];
    result.access_hash = [is readInt64];
    if (flags & (1 << 0))
        [is readInt32];
    return result;
}

@end

@interface TLCodexRichTextSkipParser : NSObject <TLObject>
@end

@implementation TLCodexRichTextSkipParser

- (int32_t)TLconstructorSignature
{
    return 0;
}

- (int32_t)TLconstructorName
{
    return 0;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    return nil;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    switch (signature)
    {
        case (int32_t)0xdc3d824f:
            break;
        case (int32_t)0x744694e0:
            [is readString];
            break;
        case (int32_t)0x6724abc4:
        case (int32_t)0xd912a59c:
        case (int32_t)0xc12622c4:
        case (int32_t)0x9bf8bb95:
        case (int32_t)0x6c3f19b9:
        case (int32_t)0xed6a8504:
        case (int32_t)0xc7fb5e01:
        case (int32_t)0x034b8621:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x3c2884c1:
            CodexReadObject(is, environment, error);
            [is readString];
            [is readInt64];
            break;
        case (int32_t)0xde5a0dd6:
        case (int32_t)0x1ccb966a:
        case (int32_t)0x35553762:
            CodexReadObject(is, environment, error);
            [is readString];
            break;
        case (int32_t)0x7e6260d7:
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x081ccf4f:
            [is readInt64];
            [is readInt32];
            [is readInt32];
            break;
        default:
            break;
    }
    return nil;
}

@end

@interface TLCodexModernConfigParser : TLConfig$config
@end

@implementation TLCodexModernConfigParser

- (int32_t)TLconstructorSignature
{
    return (int32_t)0xcc1a241e;
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLConfig$config *result = [[TLConfig$config alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.date = [is readInt32];
    result.expires = [is readInt32];
    TLBool *testMode = (TLBool *)CodexReadObject(is, environment, error);
    result.test_mode = [testMode respondsToSelector:@selector(boolValue)] ? [testMode boolValue] : false;
    result.this_dc = [is readInt32];
    result.dc_options = CodexReadObjectVector(is, environment, error);
    result.dc_txt_domain_name = [is readString];
    result.chat_size_max = [is readInt32];
    result.megagroup_size_max = [is readInt32];
    result.forwarded_count_max = [is readInt32];
    result.online_update_period_ms = [is readInt32];
    result.offline_blur_timeout_ms = [is readInt32];
    result.offline_idle_timeout_ms = [is readInt32];
    result.online_cloud_timeout_ms = [is readInt32];
    result.notify_cloud_delay_ms = [is readInt32];
    result.notify_default_delay_ms = [is readInt32];
    result.push_chat_period_ms = [is readInt32];
    result.push_chat_limit = [is readInt32];
    result.edit_time_limit = [is readInt32];
    result.revoke_time_limit = [is readInt32];
    result.revoke_pm_time_limit = [is readInt32];
    result.rating_e_decay = [is readInt32];
    result.stickers_recent_limit = [is readInt32];
    result.channels_read_media_period = [is readInt32];
    if (flags & (1 << 0))
        result.tmp_sessions = [is readInt32];
    result.call_receive_timeout_ms = [is readInt32];
    result.call_ring_timeout_ms = [is readInt32];
    result.call_connect_timeout_ms = [is readInt32];
    result.call_packet_timeout_ms = [is readInt32];
    result.me_url_prefix = [is readString];
    if (flags & (1 << 7))
        result.autoupdate_url_prefix = [is readString];
    if (flags & (1 << 9))
        result.gif_search_username = [is readString];
    if (flags & (1 << 10))
        result.venue_search_username = [is readString];
    if (flags & (1 << 11))
        result.img_search_username = [is readString];
    if (flags & (1 << 12))
        result.static_maps_provider = [is readString];
    result.caption_length_max = [is readInt32];
    result.message_length_max = [is readInt32];
    result.webfile_dc_id = [is readInt32];
    if (flags & (1 << 2))
    {
        result.suggested_lang_code = [is readString];
        result.lang_pack_version = [is readInt32];
        [is readInt32];
    }
    if (flags & (1 << 15))
        CodexReadObject(is, environment, error);
    if (flags & (1 << 16))
        [is readString];
    if (error != NULL && *error != nil)
        *error = nil;
    return result;
}

@end

@interface TLCodexAvailableReactionParser : TLAvailableReaction_manual
@end

@implementation TLCodexAvailableReactionParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLAvailableReaction_manual *result = [[TLAvailableReaction_manual alloc] init];
    int32_t flags = [is readInt32];
    result.inactive = (flags & (1 << 0)) != 0;
    result.premium = (flags & (1 << 2)) != 0;
    result.reaction = [is readString];
    [is readString];
    for (int i = 0; i < ((flags & (1 << 1)) != 0 ? 7 : 5); i++)
    {
        CodexReadObject(is, environment, error);
        if (error != NULL && *error != nil)
            return nil;
    }
    return result;
}

@end

@interface TLCodexAvailableReactionsParser : TLmessages_AvailableReactions_manual
@end

@implementation TLCodexAvailableReactionsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    [is readInt32];
    int32_t marker = [is readInt32];
    int32_t count = [is readInt32];
    if (marker != TL_UNIVERSAL_VECTOR_CONSTRUCTOR || count < 0 || count > 10000)
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:@"TLAvailableReactions" code:1 userInfo:nil];
        return nil;
    }

    TLmessages_AvailableReactions_manual *result = [[TLmessages_AvailableReactions_manual alloc] init];
    NSMutableArray *reactions = [[NSMutableArray alloc] init];
    NSMutableArray *emojis = [[NSMutableArray alloc] init];
    for (int32_t i = 0; i < count; i++)
    {
        id reaction = CodexReadObject(is, environment, error);
        if (error != NULL && *error != nil)
            return nil;
        if (![reaction isKindOfClass:[TLAvailableReaction_manual class]])
        {
            if (error != NULL)
                *error = [NSError errorWithDomain:@"TLAvailableReactions" code:2 userInfo:nil];
            return nil;
        }
        TLAvailableReaction_manual *availableReaction = reaction;
        [reactions addObject:availableReaction];
        if (!availableReaction.inactive && availableReaction.reaction.length != 0 && ![emojis containsObject:availableReaction.reaction])
            [emojis addObject:availableReaction.reaction];
    }
    result.reactions = reactions;
    result.activeEmojis = emojis;
    return result;
}

@end

@interface TLCodexIgnoredUpdate : TLUpdate
@property (nonatomic) int32_t ignoredSignature;
@end

@implementation TLCodexIgnoredUpdate

- (int32_t)TLconstructorSignature
{
    return _ignoredSignature;
}

- (int32_t)TLconstructorName
{
    return 0;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    return self;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}

@end

@interface TGDeviceAuthorizationParser : TLAuthorization$authorization
@end

@implementation TGDeviceAuthorizationParser
- (id<TLObject>)TLdeserialize:(NSInputStream *)stream signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    bool failed = false;
    TLAuthorization *result = [[TLAuthorization$authorization alloc] init];
    result.flags = [stream readInt32:&failed];
    result.n_hash = [stream readInt64:&failed];
    result.device_model = [stream readString:&failed];
    result.platform = [stream readString:&failed];
    result.system_version = [stream readString:&failed];
    result.api_id = [stream readInt32:&failed];
    result.app_name = [stream readString:&failed];
    result.app_version = [stream readString:&failed];
    result.date_created = [stream readInt32:&failed];
    result.date_active = [stream readInt32:&failed];
    result.ip = [stream readString:&failed];
    result.country = [stream readString:&failed];
    result.region = [stream readString:&failed];
    if (failed)
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid authorization"}];
        return nil;
    }
    return result;
}
@end

@interface TGDeviceAuthorizationsParser : TLaccount_Authorizations$account_authorizations
@end

@implementation TGDeviceAuthorizationsParser
- (id<TLObject>)TLdeserialize:(NSInputStream *)stream signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    bool failed = false;
    [stream readInt32:&failed];
    int32_t marker = [stream readInt32:&failed];
    int32_t count = [stream readInt32:&failed];
    if (failed || marker != TL_UNIVERSAL_VECTOR_CONSTRUCTOR || count < 0 || count > 10000)
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid authorizations vector"}];
        return nil;
    }
    NSMutableArray *sessions = [[NSMutableArray alloc] initWithCapacity:count];
    for (int32_t index = 0; index < count; index++)
    {
        int32_t objectSignature = [stream readInt32:&failed];
        id object = failed ? nil : TLMetaClassStore::constructObject(stream, objectSignature, environment, nil, error);
        if (![object isKindOfClass:[TLAuthorization class]])
        {
            if (error != NULL && *error == nil)
                *error = [NSError errorWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid authorization in vector"}];
            return nil;
        }
        [sessions addObject:object];
    }
    TLaccount_Authorizations *result = [[TLaccount_Authorizations$account_authorizations alloc] init];
    result.authorizations = sessions;
    return result;
}
@end

@interface TLCodexModernUpdateNewAuthorizationParser : TLUpdate$updateNewAuthorization
@end

@implementation TLCodexModernUpdateNewAuthorizationParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLUpdate$updateNewAuthorization *result = [[TLUpdate$updateNewAuthorization alloc] init];
    result.flags = [is readInt32];
    result.n_hash = [is readInt64];
    if (result.flags & (1 << 0))
    {
        result.date = [is readInt32];
        result.device = [is readString];
        result.location = [is readString];
    }
    return result;
}

@end

@interface TLCodexSkipObjectParser : NSObject <TLObject>
@end

@implementation TLCodexSkipObjectParser

- (int32_t)TLconstructorSignature
{
    return 0;
}

- (int32_t)TLconstructorName
{
    return 0;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    return nil;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    switch (signature)
    {
        case (int32_t)0x1cb5c415:
        {
            int32_t count = [is readInt32];
            for (int32_t i = 0; i < count; i++)
            {
                @try
                {
                    CodexReadObject(is, environment, error);
                }
                @catch (NSException *exception)
                {
                    NSString *message = [NSString stringWithFormat:@"index=%d/%d manual=0x%08x manualName=%@ parser=%@ exception=%@ reason=%@", i, count, CodexCurrentManualSignature, stringForHash(CodexCurrentManualSignature), CodexCurrentManualParser, exception.name, exception.reason];
                    if (error != NULL)
                    {
                        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
                        [userInfo setValue:message forKey:NSLocalizedDescriptionKey];
                        *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:userInfo];
                    }
                    break;
                }
                if (error != NULL && *error != nil)
                {
                    break;
                }
            }
            break;
        }
        case (int32_t)0xe8fd8014:
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0x711d692d:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 1))
                [is readInt32];
            break;
        }
        case (int32_t)0x75b3b798:
        {
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            if (error != NULL && *error != nil)
                return nil;
            TLCodexIgnoredUpdate *result = [[TLCodexIgnoredUpdate alloc] init];
            result.ignoredSignature = signature;
            return result;
        }
        case (int32_t)0x0ab4a819:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt64];
            [is readInt32];
            if (flags & (1 << 4))
                [is readInt32];
            if (flags & (1 << 1))
                [is readInt32];
            if (flags & (1 << 2))
                [is readInt32];
            if (flags & (1 << 3))
                [is readInt32];
            if (flags & (1 << 7))
                [is readInt32];
            if (flags & (1 << 8))
                [is readString];
            break;
        }
        case (int32_t)0xc01e857f:
        {
            int64_t userId = [is readInt64];
            TLSendMessageAction *action = (TLSendMessageAction *)CodexReadObject(is, environment, error);
            TLUpdate$updateUserTyping *result = [[TLUpdate$updateUserTyping alloc] init];
            result.user_id = TGModernLegacyIdForModernId(userId);
            result.action = action;
            return result;
        }
        case (int32_t)0x2a17bf5c:
        {
            int32_t flags = [is readInt32];
            int64_t userId = [is readInt64];
            if (flags & (1 << 0))
                [is readInt32];
            TLSendMessageAction *action = (TLSendMessageAction *)CodexReadObject(is, environment, error);
            TLUpdate$updateUserTyping *result = [[TLUpdate$updateUserTyping alloc] init];
            result.user_id = TGModernLegacyIdForModernId(userId);
            result.action = action;
            return result;
        }
        case (int32_t)0x83487af0:
        {
            int64_t chatId = [is readInt64];
            TLPeer *fromPeer = (TLPeer *)CodexReadObject(is, environment, error);
            TLSendMessageAction *action = (TLSendMessageAction *)CodexReadObject(is, environment, error);
            if (![fromPeer isKindOfClass:[TLPeer$peerUser class]])
                return nil;
            TLUpdate$updateChatUserTyping *result = [[TLUpdate$updateChatUserTyping alloc] init];
            result.chat_id = (int32_t)chatId;
            result.user_id = ((TLPeer$peerUser *)fromPeer).user_id;
            result.action = action;
            return result;
        }
        case (int32_t)0xc32d5b12:
            [is readInt64];
            CodexReadInt32Vector(is);
            [is readInt32];
            [is readInt32];
            break;
        case (int32_t)0x5e1b3cb8:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xd6b19546:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 0))
            {
                [is readInt64];
                [is readInt32];
            }
            TLCodexIgnoredUpdate *result = [[TLCodexIgnoredUpdate alloc] init];
            result.ignoredSignature = signature;
            return result;
        }
        case (int32_t)0xb390dc08:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt64];
            if (flags & (1 << 0))
                [is readString];
            if (flags & (1 << 1))
                [is readString];
            if (flags & (1 << 2))
                [is readInt64];
            if (flags & (1 << 3))
                [is readString];
            if (flags & (1 << 4))
                [is readInt32];
            break;
        }
        case (int32_t)0x51e6ee4f:
            [is readInt32];
            break;
        case (int32_t)0x14b24500:
        {
            [is readInt64];

            NSError *groupCallSkipError = nil;
            CodexReadObject(is, environment, &groupCallSkipError);
            break;
        }
        case (int32_t)0x7063c3db:
        {
            CodexReadObject(is, environment, error);
            [is readInt32];
            CodexReadInt64Vector(is);
            break;
        }
        case (int32_t)0xed85eab5:
        {
            int32_t flags = [is readInt32];
            TLPeer *peer = (TLPeer *)CodexReadObject(is, environment, error);
            NSArray *messages = CodexReadInt32Vector(is);
            int32_t pts = [is readInt32];
            int32_t ptsCount = [is readInt32];
            TLUpdate$updatePinnedMessagesCodex *result = [[TLUpdate$updatePinnedMessagesCodex alloc] init];
            result.flags = flags;
            result.peer = peer;
            result.messages = messages;
            result.pts = pts;
            result.pts_count = ptsCount;
            return result;
        }
        case (int32_t)0xd597650c:
        case (int32_t)0xefb2b617:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readInt64];
            [is readInt32];
            if (flags & (1 << 3))
                [is readString];
            if (flags & (1 << 4))
                [is readInt32];
            if (flags & (1 << 5))
                [is readInt32];
            if (flags & (1 << 7))
                [is readInt32];
            if (flags & (1 << 10))
                [is readInt32];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 16))
                [is readString];
            if (flags & (1 << 20))
                [is readInt64];
            if (flags & (1 << 21))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x1bf335b9:
            [is readInt32];
            [is readInt64];
            break;
        case (int32_t)0xfa0f3ca2:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 1))
                [is readInt32];
            if (flags & (1 << 0))
                CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0xfe198602:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            if (flags & (1 << 0))
                CodexReadInt32Vector(is);
            break;
        }
        case (int32_t)0x7d627683:
            CodexReadObject(is, environment, error);
            [is readInt32];
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x1824e40b:
            [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x904dd49c:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0xac21d3ce:
            CodexReadObject(is, environment, error);
            [is readInt32];
            [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0x09cb7759:
            CodexReadObject(is, environment, error);
            [is readInt32];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0x8ae5c97a:
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0x9ddb347c:
        case (int32_t)0x07df587c:
        {
            int32_t flags = [is readInt32];
            [is readString];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        }
        case (int32_t)0xa02a982e:
            [is readString];
            CodexReadObject(is, environment, error);
            CodexReadInt32Vector(is);
            [is readInt32];
            break;
        case (int32_t)0x1ea2fda7:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readInt64];
            [is readString];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 2))
                CodexReadObject(is, environment, error);
            [is readInt64];
            if (flags & (1 << 0))
                [is readBytes];
            break;
        }
        case (int32_t)0xa584b019:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x283bd312:
            [is readInt64];
            [is readString];
            [is readInt32];
            break;
        case (int32_t)0x8b725fce:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xe16459c3:
        {
            int32_t flags = [is readInt32];
            TLDialogPeer *peer = (TLDialogPeer *)CodexReadObject(is, environment, error);
            TLUpdate$updateDialogUnreadMark *result = [[TLUpdate$updateDialogUnreadMark alloc] init];
            result.flags = flags;
            result.peer = peer;
            return result;
        }
        case (int32_t)0xe56dbf05:
        {
            TLPeer *peer = (TLPeer *)CodexReadObject(is, environment, error);
            TLDialogPeer$dialogPeer *result = [[TLDialogPeer$dialogPeer alloc] init];
            result.peer = peer;
            return result;
        }
        case (int32_t)0x514519e2:
            [is readInt32];
            break;
        case (int32_t)0x77b0e372:
        case (int32_t)0xa4a79376:
            [is readInt64];
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0x9f812b08:
        {
            [is readInt32];
            [is readInt64];
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x683b2c52:
        {
            [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        }
        case (int32_t)0xdef143d0:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
                CodexReadInt32Vector(is);
            break;
        }
        case (int32_t)0xfb9c547a:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x9e84bc99:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            TLPeer *peer = (TLPeer *)CodexReadObject(is, environment, error);
            if (flags & (1 << 1))
                [is readInt32];
            int32_t maxId = [is readInt32];
            [is readInt32];
            int32_t pts = [is readInt32];
            int32_t ptsCount = [is readInt32];
            TLUpdate$updateReadHistoryInbox *result = [[TLUpdate$updateReadHistoryInbox alloc] init];
            result.peer = peer;
            result.max_id = maxId;
            result.pts = pts;
            result.pts_count = ptsCount;
            return result;
        }
        case (int32_t)0x2f2f21bf:
        {
            TLPeer *peer = (TLPeer *)CodexReadObject(is, environment, error);
            int32_t maxId = [is readInt32];
            int32_t pts = [is readInt32];
            int32_t ptsCount = [is readInt32];
            TLUpdate$updateReadHistoryOutbox *result = [[TLUpdate$updateReadHistoryOutbox alloc] init];
            result.peer = peer;
            result.max_id = maxId;
            result.pts = pts;
            result.pts_count = ptsCount;
            return result;
        }
        case (int32_t)0x0bb2d201:
            [is readInt32];
            CodexReadInt64Vector(is);
            break;
        case (int32_t)0x31c24808:
            [is readInt32];
            break;
        case (int32_t)0xb23fc698:
        {
            int64_t channelId = [is readInt64];
            int32_t availableMinId = [is readInt32];
            TLUpdate$updateChannelAvailableMessages *result = [[TLUpdate$updateChannelAvailableMessages alloc] init];
            result.channel_id = (int32_t)channelId;
            result.available_min_id = availableMinId;
            return result;
        }
        case (int32_t)0x9d2216e0:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xf2ebdb4e:
            CodexReadObject(is, environment, error);
            if (error != NULL && *error != nil)
                break;
            CodexReadObjectVector(is, environment, error);
            if (error != NULL && *error != nil)
                break;
            [is readInt32];
            break;
        case (int32_t)0x2a3dc7ac:
        case (int32_t)0xeba636fe:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            if (flags & (1 << 3)) [is readInt32];
            [is readInt32];
            if (flags & (1 << 7)) [is readInt32];
            if (flags & (1 << 11)) [is readString];
            if (flags & (1 << 13)) [is readInt64];
            if (flags & (1 << 6)) CodexReadObject(is, environment, error);
            if (flags & (1 << 14)) CodexReadObject(is, environment, error);
            if (signature == (int32_t)0x2a3dc7ac && (flags & (1 << 16))) [is readInt64];
            break;
        }
        case (int32_t)0x67753ac8:
        {
            int32_t flags = [is readInt32];
            [is readString];
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 1)) [is readInt32];
            break;
        }
        case (int32_t)0xdcb118b7:
            [is readString];
            CodexReadInt32Vector(is);
            break;
        case (int32_t)0xbb9bb9a5:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
                [is readInt32];
            break;
        }
        case (int32_t)0x1e297bfa:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xaca1657b:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x86e18161:
        {
            [is readInt64];
            int32_t flags = [is readInt32];
            [is readString];
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 4))
                [is readInt32];
            if (flags & (1 << 5))
                [is readInt32];
            break;
        }
        case (int32_t)0x6ca9c2e9:
            [is readString];
            [is readBytes];
            break;
        case (int32_t)0xfb4c496c:
        case (int32_t)0x30f443db:
        case (int32_t)0x39c67432:
        case (int32_t)0x8c0f91fb:
            break;
        case (int32_t)0x28373599:
            [is readInt64];
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x07b68920:
            [is readInt64];
            [is readInt32];
            break;
        case (int32_t)0xa477288f:
            CodexReadObject(is, environment, error);
            [is readInt32];
            CodexSkipBytesVector(is);
            [is readInt32];
            break;
        case (int32_t)0x140502d1:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x5bb98608:
        {
            int32_t flags = [is readInt32];
            int64_t channelId = [is readInt64];
            NSArray *messages = CodexReadInt32Vector(is);
            int32_t pts = [is readInt32];
            int32_t ptsCount = [is readInt32];
            TLUpdate$updatePinnedChannelMessagesCodex *result = [[TLUpdate$updatePinnedChannelMessagesCodex alloc] init];
            result.flags = flags;
            result.channel_id = channelId;
            result.messages = messages;
            result.pts = pts;
            result.pts_count = ptsCount;
            return result;
        }
        case (int32_t)0x4e80a379:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x48e246c2:
            [is readInt64];
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xdc58f31e:
            [is readInt64];
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xac072444:
            break;
        case (int32_t)0x50cc03d3:
        {
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x22c0f6d5:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 2))
                [is readString];
            if (flags & (1 << 3))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 4))
                [is readInt32];
            break;
        }
        case (int32_t)0x8c39793f:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 1))
                [is readString];
            if (flags & (1 << 2))
                [is readString];
            break;
        }
        case (int32_t)0xe46bcee4:
            [is readInt64];
            break;
        case (int32_t)0xc7b57ce6:
            [is readString];
            [is readString];
            break;
        case (int32_t)0x7533a588:
        case (int32_t)0x4258c205:
            break;
        case (int32_t)0xffadc913:
            [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            break;
        case (int32_t)0x16a4b93c:
        case (int32_t)0xedf164f1:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 18))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 17))
                CodexReadObject(is, environment, error);
            [is readInt32];
            if (flags & (1 << 0))
                [is readString];
            if (flags & (1 << 1))
                CodexReadObjectVector(is, environment, error);
            CodexReadObject(is, environment, error);
            if (flags & (1 << 14))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 2))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 3))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 15))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 19))
                CodexReadInt32Vector(is);
            if (signature == (int32_t)0x16a4b93c && (flags & (1 << 20)))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x79b26a24:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 18))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 17))
                CodexReadObject(is, environment, error);
            [is readInt32];
            if (flags & (1 << 0))
                [is readString];
            if (flags & (1 << 1))
                CodexReadObjectVector(is, environment, error);
            CodexReadObject(is, environment, error);
            if (flags & (1 << 14))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 2))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 3))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 15))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 19))
                CodexReadInt32Vector(is);
            if (flags & (1 << 20))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x68cb6283:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x9a35e999:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
                [is readInt32];
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x63c3dd0a:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 0))
                CodexReadInt32Vector(is);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x8d595cd6:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            if (flags & (1 << 2))
                [is readInt32];
            if (flags & (1 << 3))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 4))
                [is readInt32];
            if (flags & (1 << 0))
                CodexReadInt64Vector(is);
            break;
        }
        case (int32_t)0xb826e150:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 1))
                [is readString];
            if (flags & (1 << 2))
                [is readInt32];
            break;
        }
        case (int32_t)0x2e94c3e7:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x54b56617:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xcf6f6db8:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x31cad303:
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x01c641c2:
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0x7781fe18:
            [is readInt64];
            break;
        case (int32_t)0xbbb6b4a3:
            [is readInt64];
            [is readInt32];
            break;
        case (int32_t)0x74aee3e0:
            [is readInt64];
            break;
        case (int32_t)0x313a9547:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            CodexReadObject(is, environment, error);
            [is readInt64];
            if (flags & (1 << 0))
            {
                [is readInt32];
                [is readInt32];
            }
            [is readInt64];
            if (flags & (1 << 1))
            {
                [is readInt32];
                [is readInt32];
            }
            if (flags & (1 << 3))
                [is readInt64];
            if (flags & (1 << 4))
                [is readInt64];
            if (flags & (1 << 5))
                [is readString];
            if (flags & (1 << 6))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 8))
            {
                [is readInt32];
                [is readInt32];
            }
            if (flags & (1 << 9))
                [is readInt32];
            if (flags & (1 << 11))
            {
                [is readString];
                [is readInt32];
                [is readInt32];
                [is readInt32];
                [is readInt32];
            }
            if (flags & (1 << 12))
                [is readInt32];
            if (flags & (1 << 13))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x85f0a9cd:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readInt64];
            [is readString];
            [is readString];
            [is readInt32];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 1))
                [is readString];
            if (flags & (1 << 2))
                [is readString];
            CodexReadObjectVector(is, environment, error);
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 3))
                [is readString];
            if (flags & (1 << 4))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 5))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 8))
            {
                [is readInt64];
                [is readString];
                [is readInt64];
            }
            if (flags & (1 << 10))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 11))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 12))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 13))
                [is readInt32];
            if (flags & (1 << 16))
                [is readInt32];
            break;
        }
        case (int32_t)0x565251e2:
        {
            [is readInt32];
            [is readString];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x4e7085ea:
            [is readString];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x9f2504e4:
            [is readString];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xe0bff26c:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            [is readInt32];
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x36437737:
            [is readInt32];
            break;
        case (int32_t)0xdbce6389:
        case (int32_t)0xf08d516b:
        case (int32_t)0x78fbf3a8:
        case (int32_t)0xcef7e7a8:
            break;
        case (int32_t)0xaff56398:
            [is readInt32];
            [is readInt32];
            [is readInt32];
            break;
        case (int32_t)0x71f276c4:
            [is readInt32];
            break;
        case (int32_t)0x4d4bd46a:
            break;
        case (int32_t)0xb98cd696:
        case (int32_t)0x72c64955:
        case (int32_t)0xab339c00:
        case (int32_t)0x9f27d26e:
        case (int32_t)0xe477092e:
        case (int32_t)0xd3656499:
        case (int32_t)0xa2c0f695:
            break;
        case (int32_t)0x3458f9c8:
            CodexReadObject(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xfe333952:
            break;
        case (int32_t)0x771a4e66:
            [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt64];
            CodexReadObjectVector(is, environment, error);
            CodexReadInt64Vector(is);
            [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x972dabbf:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt64];
            if (flags & (1 << 0))
                [is readInt32];
            if (flags & (1 << 1))
            {
                [is readInt32];
                [is readString];
            }
            break;
        }
        case (int32_t)0x2eeed1c4:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
            {
                [is readInt64];
                [is readInt32];
                [is readInt64];
                CodexReadObject(is, environment, error);
            }
            [is readInt32];
            break;
        }
        case (int32_t)0x3aae0528:
            [is readInt32];
            [is readInt32];
            break;
        case (int32_t)0x0aa021e5:
            [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            break;
        case (int32_t)0x03d1ea4e:
        {
            [is readDouble];
            [is readDouble];
            [is readDouble];
            [is readDouble];
            [is readDouble];
            break;
        }
        case (int32_t)0xcfc9e002:
        {
            int32_t flags = [is readInt32];
            [is readDouble];
            [is readDouble];
            [is readDouble];
            [is readDouble];
            [is readDouble];
            if (flags & (1 << 0))
                [is readDouble];
            break;
        }
        case (int32_t)0x770416af:
            CodexReadObject(is, environment, error);
            [is readInt64];
            [is readInt32];
            break;
        case (int32_t)0xbe82db9c:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            [is readString];
            [is readString];
            [is readString];
            [is readString];
            [is readString];
            break;
        case (int32_t)0xb282217f:
            CodexReadObject(is, environment, error);
            [is readInt64];
            [is readString];
            break;
        case (int32_t)0xcad5452d:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x14455871:
        {
            [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x2271f2bf:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0x37381085:
            CodexReadObject(is, environment, error);
            [is readString];
            break;
        case (int32_t)0x49a6549c:
            CodexReadObject(is, environment, error);
            [is readString];
            [is readDouble];
            [is readInt32];
            break;
        case (int32_t)0x5787686d:
            CodexReadObject(is, environment, error);
            [is readString];
            break;
        case (int32_t)0xdf8b3b22:
        {
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            [is readString];
            [is readString];
            [is readString];
            [is readString];
            [is readString];
            break;
        }
        case (int32_t)0xa5d9abb8:
        {
            [is readString];
            [is readString];
            [is readString];
            [is readString];
            [is readString];
            [is readInt32];
            break;
        }
        case (int32_t)0xde4c5d93:
        {
            int32_t flags = [is readInt32];
            [is readString];
            if (flags & (1 << 0))
                [is readString];
            if (flags & (1 << 1))
                [is readString];
            if (flags & (1 << 2))
                [is readString];
            break;
        }
        case (int32_t)0xb0bdeac5:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readInt32];
            if (flags & (1 << 2))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x9083670b:
        {
            [is readInt32];
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xbd74cf49:
        {
            [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x59d78fc5:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 0))
                [is readString];
            break;
        }
        case (int32_t)0xde9eed1d:
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xe87acbc0:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xe2de7737:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 0))
                [is readString];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x6090d6d5:
            CodexReadObject(is, environment, error);
            [is readInt32];
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xbbab2643:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xcfcd0f13:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xaa5f789c:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 0))
                [is readString];
            break;
        }
        case (int32_t)0xa388a368:
            break;
        case (int32_t)0x2ed82995:
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x3de1dfed:
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x416c56e8:
            CodexReadObject(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x41df43fc:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 2))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 3))
                [is readInt32];
            if (flags & (1 << 11))
                [is readInt64];
            if (flags & (1 << 4))
                [is readInt64];
            if (flags & (1 << 6))
                [is readInt64];
            if (flags & (1 << 7))
                [is readInt32];
            if (flags & (1 << 8))
                [is readInt64];
            if (flags & (1 << 13))
                [is readInt32];
            if (flags & (1 << 14))
                [is readInt32];
            if (flags & (1 << 15))
                CodexReadInt32Vector(is);
            if (flags & (1 << 16))
                [is readString];
            if (flags & (1 << 18))
                [is readInt64];
            if (flags & (1 << 19))
                [is readInt32];
            if (flags & (1 << 20))
                [is readInt32];
            break;
        }
        case (int32_t)0x95f389b1:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 0))
                [is readString];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x69279795:
            [is readInt32];
            break;
        case (int32_t)0xf101aa7f:
            CodexReadObject(is, environment, error);
            [is readInt64];
            break;
        case (int32_t)0x2085c238:
            [is readString];
            break;
        case (int32_t)0x84aa3a9c:
            [is readString];
            break;
        case (int32_t)0x48aaae3c:
        case (int32_t)0x4a162433:
            [is readInt64];
            break;
        case (int32_t)0x1f01c757:
            [is readInt32];
            break;
        case (int32_t)0x2eb1b658:
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0x947a12df:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 0))
                [is readString];
            if (flags & (1 << 1))
            {
                CodexReadObjectVector(is, environment, error);
                [is readInt64];
            }
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 2))
                CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x9d6b13b0:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readString];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            [is readInt32];
            [is readInt64];
            break;
        }
        case (int32_t)0xa0ba4f17:
            break;
        case (int32_t)0x8a2932f3:
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x512fe446:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt64];
            [is readInt32];
            [is readInt64];
            [is readInt64];
            if (flags & (1 << 0))
            {
                [is readInt32];
                [is readInt64];
            }
            if (flags & (1 << 2))
                [is readInt64];
            if (flags & (1 << 3))
                [is readInt64];
            if (flags & (1 << 4))
                [is readInt32];
            if (flags & (1 << 5))
            {
                [is readInt32];
                [is readString];
            }
            break;
        }
        case (int32_t)0x99ea331d:
            [is readInt32];
            [is readInt64];
            break;
        case (int32_t)0x6b39f4ec:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x42b00348:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            [is readInt64];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 2))
                [is readInt32];
            break;
        }
        case (int32_t)0x7d5bd1f0:
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xd31bc45d:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xdb33dad0:
            break;
        case (int32_t)0xaef6abbc:
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x46c6e36f:
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x9f120418:
            [is readInt32];
            [is readInt32];
            break;
        case (int32_t)0xd072acb4:
            [is readString];
            [is readString];
            [is readString];
            break;
        case (int32_t)0xb4073647:
            [is readInt32];
            [is readString];
            break;
        case (int32_t)0xb54b5acf:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            if (flags & (1 << 1))
                [is readInt64];
            break;
        }
        case (int32_t)0xb9c0639a:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readInt64];
            [is readInt64];
            [is readInt32];
            CodexReadInt32Vector(is);
            if (flags & (1 << 0))
                [is readInt32];
            if (flags & (1 << 1))
                CodexReadInt32Vector(is);
            break;
        }
        case (int32_t)0x5da674b7:
            break;
        case (int32_t)0x95fcd1d6:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readInt64];
            [is readString];
            [is readString];
            [is readString];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            [is readInt64];
            break;
        }
        case (int32_t)0x2de11aae:
            break;
        case (int32_t)0xe7ff068a:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            if (flags & (1 << 0))
                [is readInt32];
            break;
        }
        case (int32_t)0x7184603b:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readInt64];
            [is readString];
            [is readString];
            [is readInt64];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            break;
        }
        case (int32_t)0x07141dbf:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            if (flags & (1 << 0))
                [is readInt32];
            break;
        }
        case (int32_t)0x929b619d:
            [is readInt64];
            break;
        case (int32_t)0xfa30a8c7:
            [is readInt64];
            [is readInt32];
            break;
        case (int32_t)0xee8c1e86:
            break;
        case (int32_t)0xf35aec28:
            [is readInt64];
            [is readInt64];
            break;
        case (int32_t)0x5b934f9d:
            CodexReadObject(is, environment, error);
            [is readInt32];
            [is readInt64];
            break;
        case (int32_t)0xcdbbcebb:
            [is readInt64];
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xbe382906:
        {
            [is readInt32];
            [is readInt64];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            int32_t vectorSignature = [is readInt32];
            if (vectorSignature == (int32_t)0x1cb5c415)
            {
                int32_t count = [is readInt32];
                for (int32_t i = 0; i < count; i++)
                    [is readInt64];
            }
            break;
        }
        case (int32_t)0x2cb51097:
            [is readInt64];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x3b6d152e:
        {
            TLUserFull$userFull *fullUser = (TLUserFull$userFull *)CodexReadObject(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            NSArray *users = CodexReadObjectVector(is, environment, error);
            if (fullUser.user == nil && users.count != 0)
                fullUser.user = [users objectAtIndex:0];
            return fullUser;
        }
        case (int32_t)0xb53e8b21:
            CodexReadObject(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x8c9a88ac:
            CodexReadObject(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xcc997720:
        case (int32_t)0xd2234ea0:
        case (int32_t)0x06cbe645:
        {
            TLUserFull$userFull *result = [[TLUserFull$userFull alloc] init];
            int32_t flags = [is readInt32];
            int32_t flags2 = [is readInt32];
            [is readInt64];
            result.flags = flags & ((1 << 0) | (1 << 1) | (1 << 2) | (1 << 3));
            if (flags & (1 << 1))
                result.about = [is readString];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 21))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 2))
                result.profile_photo = (TLPhoto *)CodexReadObject(is, environment, error);
            if (flags & (1 << 22))
                CodexReadObject(is, environment, error);
            result.notify_settings = (TLPeerNotifySettings *)CodexReadObject(is, environment, error);
            if (flags & (1 << 3))
                result.bot_info = (TLBotInfo *)CodexReadObject(is, environment, error);
            if (flags & (1 << 6))
                result.pinned_msg_id = [is readInt32];
            result.common_chats_count = [is readInt32];
            if (flags & (1 << 11))
                [is readInt32];
            if (flags & (1 << 14))
                [is readInt32];
            if (flags & (1 << 15))
            {
                if (signature == (int32_t)0x06cbe645)
                    CodexReadObject(is, environment, error);
                else
                    [is readString];
            }
            if (flags & (1 << 16))
                [is readString];
            if (flags & (1 << 17))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 18))
                CodexReadObject(is, environment, error);
            if (signature != (int32_t)0x06cbe645 && (flags & (1 << 19)))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 24))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 25))
                CodexReadObject(is, environment, error);
            if (flags2 & (1 << 0))
                CodexReadObject(is, environment, error);
            if (flags2 & (1 << 1))
                CodexReadObject(is, environment, error);
            if (flags2 & (1 << 2))
                CodexReadObject(is, environment, error);
            if (flags2 & (1 << 3))
                CodexReadObject(is, environment, error);
            if (flags2 & (1 << 4))
                CodexReadObject(is, environment, error);
            if (flags2 & (1 << 5))
                CodexReadObject(is, environment, error);
            if (flags2 & (1 << 6))
            {
                [is readInt64];
                [is readInt32];
            }
            if (flags2 & (1 << 8))
                [is readInt32];
            if (flags2 & (1 << 11))
                CodexReadObject(is, environment, error);
            if (flags2 & (1 << 12))
                CodexReadObject(is, environment, error);
            if (flags2 & (1 << 14))
                [is readInt64];
            if (flags2 & (1 << 15))
                CodexReadObject(is, environment, error);
            if (flags2 & (1 << 17))
                CodexReadObject(is, environment, error);
            if (flags2 & (1 << 18))
            {
                CodexReadObject(is, environment, error);
                [is readInt32];
            }
            if (flags2 & (1 << 20))
                CodexReadObject(is, environment, error);
            if (flags2 & (1 << 21))
            {
                result.saved_music = (TLDocument *)CodexReadObject(is, environment, error);
            }
            if (flags2 & (1 << 22))
                CodexReadObject(is, environment, error);
            if (flags2 & (1 << 25))
                [is readInt64];
            return result;
        }
        case (int32_t)0x6c8e1e06:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            break;
        }
        case (int32_t)0x120b1ab9:
        {
            [is readInt32];
            [is readInt32];
            break;
        }
        case (int32_t)0x8c92b098:
        {
            [is readInt32];
            [is readString];
            int32_t vectorMarker = [is readInt32];
            int32_t count = 0;
            if (vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
                count = [is readInt32];
            else if (vectorMarker >= 0 && vectorMarker <= 10000)
                count = vectorMarker;
            else
            {
                break;
            }
            for (int32_t i = 0; i < count; i++)
            {
                int32_t itemSignature = [is readInt32];
                if (itemSignature == (int32_t)0x120b1ab9)
                {
                    [is readInt32];
                    [is readInt32];
                }
                else
                {
                    TLMetaClassStore::constructObject(is, itemSignature, environment, nil, error);
                    if (error != nil && *error != nil)
                        break;
                }
            }
            break;
        }
        case (int32_t)0x5a0a066d:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readString];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xac5c1af7:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            [is readString];
            break;
        }
        case (int32_t)0x21108ff7:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 4))
                CodexReadInt64Vector(is);
            break;
        }
        case (int32_t)0xe519abab:
            [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0xc9b9e2b9:
        case (int32_t)0xc3f2f501:
            break;
        case (int32_t)0xcc4d9ecc:
            [is readInt32];
            [is readInt32];
            break;
        case (int32_t)0xef156a5c:
        {
            [is readInt32];
            [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x1b0e4f07:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readInt64];
            [is readInt64];
            if (flags & (1 << 0))
                [is readInt64];
            break;
        }
        case (int32_t)0x4b3e14d6:
        {
            int32_t flags = [is readInt32];
            [is readString];
            if (flags & (1 << 0))
                [is readInt64];
            if (flags & (1 << 2))
                [is readInt32];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 4))
                [is readString];
            if (flags & (1 << 5))
                [is readInt32];
            if (flags & (1 << 6))
                [is readInt64];
            break;
        }
        case (int32_t)0x8f34b2f5:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt64];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 2))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xfebe5491:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            if (flags & (1 << 1))
                [is readInt32];
            break;
        }
        case (int32_t)0x206ad49e:
        case (int32_t)0x1f0c1ad9:
            break;
        case (int32_t)0xdc6cfcf0:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xad628cc8:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
            {
                [is readInt32];
                [is readInt32];
            }
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 2))
                [is readInt32];
            break;
        }
        case (int32_t)0xee479c64:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xcba9a52f:
            [is readInt32];
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x49b92a26:
        {
            [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x221bb5e4:
            [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0xcae68768:
        case (int32_t)0xfd5e12bd:
            CodexReadObject(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x257e962b:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 0))
                [is readString];
            if (flags & (1 << 1))
                [is readInt32];
            [is readString];
            [is readInt64];
            break;
        }
        case (int32_t)0xeb983f8f:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 4))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 3))
                [is readInt32];
            if (flags & (1 << 0))
                [is readInt64];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 1))
                [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x4367daa0:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            if (flags & (1 << 1))
                [is readInt32];
            if (flags & (1 << 2))
                [is readInt64];
            if (flags & (1 << 4))
                [is readString];
            break;
        }
        case (int32_t)0xe175e66f:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            if (flags & (1 << 3))
                [is readString];
            if (flags & (1 << 4))
                [is readInt64];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 2))
                [is readInt32];
            break;
        }
        case (int32_t)0xb2539d54:
            [is readInt64];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            break;
        case (int32_t)0x9a9d77e0:
            [is readInt64];
            [is readInt64];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            break;
        case (int32_t)0x86f8613c:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 0))
                [is readString];
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0xc448415c:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 1))
                [is readInt32];
            break;
        }
        case (int32_t)0x9ae228e2:
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x4959427a:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 4))
                [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            [is readString];
            if (flags & (1 << 3))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 2))
                CodexReadInt32Vector(is);
            break;
        }
        case (int32_t)0xe7058e7f:
        case (int32_t)0x8a480e27:
            [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            break;
        case (int32_t)0x50cd067c:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x1f2bf4a:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xedf3add0:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x93037e20:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 0))
                [is readString];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0xb8ea86a9:
            [is readInt64];
            break;
        case (int32_t)0x26219a58:
            CodexReadInt32Vector(is);
            break;
        case (int32_t)0x767d61eb:
            CodexReadInt32Vector(is);
            CodexReadInt32Vector(is);
            CodexReadInt32Vector(is);
            break;
        case (int32_t)0xadec6ebe:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 2))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 3))
                [is readInt32];
            if (flags & (1 << 4))
                [is readInt32];
            break;
        }
        case (int32_t)0x2ba1f5ce:
            break;
        case (int32_t)0x00f8ed08:
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x64407ea7:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xf83ae221:
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x44ba9dd9:
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xc01f6fe8:
            [is readInt32];
            break;
        case (int32_t)0xcb6ff828:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
                [is readString];
            [is readInt32];
            break;
        }
        case (int32_t)0x889b59ef:
            break;
        case (int32_t)0x3259950a:
            CodexReadObjectVector(is, environment, error);
            [is readInt64];
            break;
        case (int32_t)0x3bb842ac:
            [is readInt32];
            break;
        case (int32_t)0x2aee9191:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 1))
                [is readString];
            [is readString];
            break;
        }
        case (int32_t)0x6f8b32aa:
        case (int32_t)0xc4e5921e:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 4))
                CodexReadObjectVector(is, environment, error);
            if (signature == (int32_t)0xc4e5921e && (flags & (1 << 6)))
                CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x0194cb3b:
            [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0x832175e0:
        {
            [is readInt32];
            [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x033ed001:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
                [is readString];
            if (flags & (1 << 1))
                [is readInt32];
            if (flags & (1 << 2))
                [is readString];
            break;
        }
        case (int32_t)0x17d7f87b:
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x09c469cd:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readString];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xb88cf373:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 4))
                CodexReadInt64Vector(is);
            if (flags & (1 << 6))
                CodexReadInt64Vector(is);
            break;
        }
        case (int32_t)0x1d998733:
            [is readInt64];
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x114ff30d:
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x628c9224:
            [is readInt32];
            [is readInt64];
            break;
        case (int32_t)0xb4ae666f:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readString];
            if (flags & (1 << 0))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 1))
                [is readString];
            [is readInt32];
            break;
        }
        case (int32_t)0xec43a2d1:
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x9a23af21:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            [is readString];
            if (flags & (1 << 0))
                CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x93c3e27e:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readString];
            if (flags & (1 << 0))
                [is readInt64];
            [is readInt64];
            if (flags & (1 << 1))
                [is readInt64];
            break;
        }
        case (int32_t)0xd1ed9a5b:
            break;
        case (int32_t)0xbddb616e:
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xb89bfccf:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 1))
            {
                [is readString];
                CodexReadObject(is, environment, error);
            }
            [is readInt64];
            break;
        }
        case (int32_t)0x95f2bfe4:
        case (int32_t)0xb457b375:
        case (int32_t)0x7b560a0b:
        case (int32_t)0x250dbaf8:
        case (int32_t)0xe92fd902:
        case (int32_t)0x60682812:
        case (int32_t)0xf9677aad:
            break;
        case (int32_t)0xd80da15d:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x0bd915c0:
        case (int32_t)0x5e0589f1:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            if (flags & (1 << 0))
                [is readString];
            [is readString];
            [is readInt64];
            break;
        }
        case (int32_t)0x13659eb0:
        {
            int32_t flags = [is readInt32];
            [is readString];
            CodexReadObject(is, environment, error);
            [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0)) [is readString];
            if (flags & (1 << 1)) [is readString];
            if (flags & (1 << 2)) CodexReadObject(is, environment, error);
            if (flags & (1 << 5)) { [is readInt32]; [is readString]; }
            if (flags & (1 << 7)) [is readBytes];
            if (flags & (1 << 8)) [is readInt32];
            if (flags & (1 << 9)) CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 12)) [is readInt32];
            if (flags & (1 << 13)) [is readInt32];
            if (flags & (1 << 14)) CodexReadObject(is, environment, error);
            if (flags & (1 << 15)) [is readInt32];
            if (flags & (1 << 16)) [is readInt32];
            if (flags & (1 << 17)) { CodexReadObject(is, environment, error); CodexReadObject(is, environment, error); }
            if (flags & (1 << 19)) [is readInt32];
            if (flags & (1 << 20)) [is readInt32];
            if (flags & (1 << 23)) { [is readInt32]; [is readInt32]; }
            break;
        }
        case (int32_t)0x6c9ce8ed:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 1))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 2))
                [is readString];
            if (flags & (1 << 4))
                [is readInt64];
            if (flags & (1 << 3))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 0))
                [is readString];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x6c207376:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            [is readDouble];
            break;
        }
        case (int32_t)0x1dab80b7:
        case (int32_t)0x394e7f21:
            [is readString];
            break;
        case (int32_t)0x5416d58:
            [is readInt32];
            [is readInt64];
            break;
        case (int32_t)0x2e6eab1a:
        {
            int32_t flags = [is readInt32];
            [is readString];
            CodexReadObject(is, environment, error);
            [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 3)) [is readString];
            if (flags & (1 << 4)) [is readString];
            if (flags & (1 << 5)) CodexReadObject(is, environment, error);
            if (flags & (1 << 6)) [is readString];
            break;
        }
        case (int32_t)0x94ce852a:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readInt32];
            if (flags & (1 << 2))
                [is readString];
            [is readString];
            [is readInt64];
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x54236209:
            [is readInt32];
            [is readInt32];
            [is readInt64];
            break;
        case (int32_t)0xdd0c66f2:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readInt32];
            if (flags & (1 << 0)) [is readInt32];
            if (flags & (1 << 1)) [is readInt32];
            if (flags & (1 << 2)) CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x19a13f71:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt32];
            [is readInt64];
            [is readInt32];
            if (flags & (1 << 0)) [is readInt32];
            [is readInt64];
            [is readInt64];
            break;
        }
        case (int32_t)0x98d5ea1d:
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xb4d5d859:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 0)) [is readString];
            break;
        }
        case (int32_t)0xf93cd45c:
            [is readInt64];
            [is readInt64];
            [is readString];
            break;
        case (int32_t)0x1e109708:
            [is readInt64];
            break;
        case (int32_t)0xe581e4e9:
            break;
        case (int32_t)0xb4f67e93:
            [is readInt64];
            break;
        case (int32_t)0xa0624cf7:
            [is readInt32];
            break;
        case (int32_t)0xc69708d3:
        {
            int32_t flags = [is readInt32];
            [is readBytes];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0)) [is readString];
            if (flags & (1 << 1)) [is readString];
            break;
        }
        case (int32_t)0xea32b4b1:
            break;
        case (int32_t)0xeb032884:
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xc387c04e:
            [is readInt32];
            break;
        case (int32_t)0xe7e82e12:
            [is readString];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            [is readString];
            break;
        case (int32_t)0x0e8e37e5:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 3))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
                [is readInt32];
            break;
        }
        case (int32_t)0x9325705a:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readString];
            if (flags & (1 << 0)) CodexReadObject(is, environment, error);
            if (flags & (1 << 1)) CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xc3987a3a:
            [is readInt64];
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x374fa7ad:
            break;
        case (int32_t)0xd5e58274:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x87e5dfe4:
            [is readString];
            break;
        case (int32_t)0x1a8afc7e:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0)) [is readInt64];
            break;
        }
        case (int32_t)0xee430c85:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 3))
                CodexReadObject(is, environment, error);
            [is readInt64];
            break;
        }
        case (int32_t)0x9d1dbd26:
            [is readInt64];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xda2ad647:
            [is readBytes];
            [is readInt64];
            [is readInt64];
            break;
        case (int32_t)0x59e65335:
            break;
        case (int32_t)0x44e56023:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt64];
            [is readInt32];
            CodexReadInt32Vector(is);
            if (flags & (1 << 0)) [is readInt32];
            break;
        }
        case (int32_t)0x90d7adfa:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xcff63ea9:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readInt64];
            [is readString];
            [is readString];
            if (flags & (1 << 1)) [is readInt64];
            if (flags & (1 << 4)) [is readString];
            if (flags & (1 << 2)) [is readInt32];
            if (flags & (1 << 3)) [is readInt64];
            if (flags & (1 << 5)) CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x9bad6414:
            [is readString];
            [is readInt64];
            [is readString];
            break;
        case (int32_t)0xc1f46103:
            break;
        case (int32_t)0x6c9d0efe:
            [is readInt64];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xf1d628ec:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x933ca597:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readString];
            [is readString];
            if (flags & (1 << 0)) [is readInt64];
            break;
        }
        case (int32_t)0x79eb8cb3:
        {
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            [is readInt64];
            break;
        }
        case (int32_t)0xbaf39d8b:
        {
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x7dbf8673:
        {
            int32_t flags = [is readInt32];
            [is readBytes];
            [is readString];
            [is readString];
            [is readString];
            if (flags & (1 << 1)) CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 6)) CodexReadObject(is, environment, error);
            if (flags & (1 << 14)) CodexReadObject(is, environment, error);
            if (flags & (1 << 13)) CodexReadObject(is, environment, error);
            [is readString];
            if (flags & (1 << 7)) [is readString];
            if (flags & (1 << 8)) [is readString];
            if (flags & (1 << 15)) { [is readInt32]; [is readInt32]; }
            break;
        }
        case (int32_t)0xffda656d:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0)) [is readInt32];
            if (flags & (1 << 1)) [is readInt32];
            if (flags & (1 << 2)) [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x1839490f:
            break;
        case (int32_t)0x31bd492d:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 0)) [is readString];
            break;
        }
        case (int32_t)0xc077ec01:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readString];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            if (flags & (1 << 1))
            {
                CodexReadObject(is, environment, error);
                CodexReadObject(is, environment, error);
            }
            break;
        }
        case (int32_t)0x9f071957:
        case (int32_t)0xb06fdbdf:
        case (int32_t)0xd08ce645:
        case (int32_t)0x481eadfa:
        case (int32_t)0x6fb4ad87:
            break;
        case (int32_t)0x768e3aad:
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x90c467d1:
            [is readInt64];
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xeafdf716:
            [is readInt64];
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x5f2d1df2:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 3)) [is readString];
            [is readInt32];
            [is readString];
            [is readInt64];
            [is readString];
            if (flags & (1 << 0)) [is readString];
            break;
        }
        case (int32_t)0xb81c7034:
        {
            [is readInt32];
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x367617d3:
        {
            [is readInt32];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            [is readInt32];
            break;
        }
        case (int32_t)0x43b46b20:
            [is readInt32];
            break;
        case (int32_t)0x7a1e11d1:
            [is readInt64];
            CodexReadInt64Vector(is);
            break;
        case (int32_t)0x7a9abda9:
        case (int32_t)0x80d26cc7:
            [is readString];
            [is readInt64];
            CodexSkipStringVector(is);
            break;
        case (int32_t)0x093bcf34:
            [is readString];
            [is readInt64];
            break;
        case (int32_t)0x881fb94b:
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xa26156c0:
            [is readInt64];
            [is readString];
            break;
        case (int32_t)0xc556a45d:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xd90d8dfe:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readString];
            if (flags & (1 << 3))
                CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0xcfb9d957:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            [is readString];
            if (flags & (1 << 1))
            {
                [is readInt32];
                [is readInt32];
            }
            break;
        }
        case (int32_t)0x5334759c:
            [is readString];
            CodexReadObjectVector(is, environment, error);
            CodexSkipStringVector(is);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x4345be73:
            [is readString];
            [is readString];
            break;
        case (int32_t)0x527d22eb:
        case (int32_t)0xbbf51685:
            break;
        case (int32_t)0x922e55a9:
        case (int32_t)0xdb909ec2:
        case (int32_t)0x96d074fd:
            [is readString];
            break;
        case (int32_t)0x2b96cd1b:
            [is readString];
            break;
        case (int32_t)0xe1bb0d61:
            [is readString];
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x3fc9053b:
            [is readString];
            break;
        case (int32_t)0x6ebdff91:
            [is readInt32];
            [is readString];
            [is readInt64];
            [is readString];
            [is readInt64];
            [is readString];
            break;
        case (int32_t)0xbac3a61a:
        case (int32_t)0x4b9e22a0:
            break;
        case (int32_t)0x71e4ea58:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0)) CodexReadObject(is, environment, error);
            if (flags & (1 << 1)) CodexReadObject(is, environment, error);
            if (flags & (1 << 2)) CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        }
        case (int32_t)0x98613ebf:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readString];
            [is readInt32];
            if (flags & (1 << 0)) [is readInt64];
            if (flags & (1 << 1)) [is readInt32];
            break;
        }
        case (int32_t)0x0a339f0b:
        {
            int32_t flags = [is readInt32];
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 1))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 4))
                CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0xdaad85b0:
        {
            int32_t flags = [is readInt32];
            CodexReadInt64Vector(is);
            if (flags & (1 << 1))
                CodexSkipStringVector(is);
            if (flags & (1 << 3))
                [is readString];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            break;
        }
        case (int32_t)0xc6991068:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            if (flags & (1 << 3))
                [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            CodexReadInt64Vector(is);
            [is readInt32];
            if (flags & (1 << 1))
                [is readString];
            [is readInt32];
            break;
        }
        case (int32_t)0x4ba3a95a:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 3))
                CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        }
        case (int32_t)0x3e0b5b6a:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 1))
                [is readInt32];
            [is readInt64];
            break;
        }
        case (int32_t)0xea29055d:
        {
            int32_t flags = [is readInt32];
            int64_t channelId = [is readInt64];
            if (flags & (1 << 0))
                [is readInt32];
            NSArray *messages = CodexReadInt32Vector(is);
            TLUpdate$updateChannelReadMessagesContents *result = [[TLUpdate$updateChannelReadMessagesContents alloc] init];
            result.channel_id = (int32_t)channelId;
            result.messages = messages;
            return result;
        }
        case (int32_t)0xf8227181:
        {
            int32_t flags = [is readInt32];
            NSArray *messages = CodexReadInt32Vector(is);
            int32_t pts = [is readInt32];
            int32_t ptsCount = [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            TLUpdate$updateReadMessagesContents *result = [[TLUpdate$updateReadMessagesContents alloc] init];
            result.messages = messages;
            result.pts = pts;
            result.pts_count = ptsCount;
            return result;
        }
        case (int32_t)0xebe07752:
        {
            int32_t flags = [is readInt32];
            TLPeer *peer = (TLPeer *)CodexReadObject(is, environment, error);
            if ([peer isKindOfClass:[TLPeer$peerUser class]])
            {
                TLUpdate$updateUserBlocked *result = [[TLUpdate$updateUserBlocked alloc] init];
                result.user_id = ((TLPeer$peerUser *)peer).user_id;
                result.blocked = (flags & (1 << 0)) != 0;
                return result;
            }
            return nil;
        }
        case (int32_t)0x20529438:
        {
            [is readInt64];
            break;
        }
        case (int32_t)0x635b4c09:
        {
            int64_t channelId = [is readInt64];
            TLUpdate$updateChannel *result = [[TLUpdate$updateChannel alloc] init];
            result.channel_id = (int32_t)channelId;
            return result;
        }
        case (int32_t)0x922e6e10:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            int64_t channelId = [is readInt64];
            int32_t maxId = [is readInt32];
            [is readInt32];
            [is readInt32];
            TLUpdate$updateReadChannelInbox *result = [[TLUpdate$updateReadChannelInbox alloc] init];
            result.channel_id = (int32_t)channelId;
            result.max_id = maxId;
            return result;
        }
        case (int32_t)0xf74e932b:
        {
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        }
        case (int32_t)0x9c974fdf:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            TLPeer *peer = (TLPeer *)CodexReadObject(is, environment, error);
            int32_t maxId = [is readInt32];
            [is readInt32];
            int32_t pts = [is readInt32];
            int32_t ptsCount = [is readInt32];
            TLUpdate$updateReadHistoryInbox *result = [[TLUpdate$updateReadHistoryInbox alloc] init];
            result.peer = peer;
            result.max_id = maxId;
            result.pts = pts;
            result.pts_count = ptsCount;
            return result;
        }
        case (int32_t)0xb75f99a9:
        {
            int64_t channelId = [is readInt64];
            int32_t maxId = [is readInt32];
            TLUpdate$updateReadChannelOutbox *result = [[TLUpdate$updateReadChannelOutbox alloc] init];
            result.channel_id = (int32_t)channelId;
            result.max_id = maxId;
            return result;
        }
        case (int32_t)0xf226ac08:
        {
            int64_t channelId = [is readInt64];
            int32_t messageId = [is readInt32];
            int32_t views = [is readInt32];
            TLUpdate$updateChannelMessageViews *result = [[TLUpdate$updateChannelMessageViews alloc] init];
            result.channel_id = (int32_t)channelId;
            result.n_id = messageId;
            result.views = views;
            return result;
        }
        case (int32_t)0x6f7863f4:
            break;
        case (int32_t)0x86fccf85:
        {
            [is readInt32];
            [is readInt64];
            break;
        }
        case (int32_t)0x74c34319:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readString];
            [is readInt64];
            [is readString];
            if (flags & (1 << 0))
                [is readString];
            break;
        }
        case (int32_t)0x50a04e45:
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x98657f0d:
        {
            int32_t flags = [is readInt32];
            int32_t firstMarker = [is readInt32];
            if (firstMarker != TL_UNIVERSAL_VECTOR_CONSTRUCTOR && (firstMarker < 0 || firstMarker > 10000))
            {
                CodexSkipStringWithFirstWord(is, firstMarker);
                firstMarker = [is readInt32];
            }
            CodexReadObjectVectorWithMarker(is, firstMarker, environment, error);
            CodexReadObjectVector(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 3))
                [is readInt32];
            break;
        }
        case (int32_t)0x1759c560:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
            {
                [is readString];
                [is readInt64];
            }
            break;
        }
        case (int32_t)0x8c88c923:
        {
            int32_t flags = [is readInt32];
            int64_t channelId = [is readInt64];
            if (flags & (1 << 0))
                [is readInt32];
            TLPeer *fromPeer = (TLPeer *)CodexReadObject(is, environment, error);
            TLSendMessageAction *action = (TLSendMessageAction *)CodexReadObject(is, environment, error);
            int32_t userId = 0;
            if ([fromPeer isKindOfClass:[TLPeer$peerUser class]])
                userId = ((TLPeer$peerUser *)fromPeer).user_id;
            if (userId == 0)
                return nil;
            TLUpdate$updateChatUserTyping *result = [[TLUpdate$updateChatUserTyping alloc] init];
            result.chat_id = (int32_t)channelId;
            result.user_id = userId;
            result.action = action;
            return result;
        }
        case (int32_t)0xb05ac6b1:
            break;
        case (int32_t)0x7c8fe7b6:
        {
            [is readInt32];
            [is readInt64];
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x39f23300:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xa8718dc5:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 1))
                [is readString];
            if (flags & (1 << 2))
                [is readString];
            if (flags & (1 << 4))
                [is readInt64];
            if (flags & (1 << 5))
            {
                [is readInt32];
                [is readInt32];
            }
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xf259a80b:
            [is readString];
            [is readInt64];
            [is readInt64];
            [is readString];
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x65a0fa4d:
        case (int32_t)0x031f9590:
            CodexReadObjectVector(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xef1751b5:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x804361ea:
            [is readInt64];
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x1e148390:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xbf4dea82:
            [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x76768bed:
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x16115a96:
            CodexReadObject(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xa44f3ef6:
            CodexReadObject(is, environment, error);
            [is readInt32];
            [is readInt32];
            [is readInt32];
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x25e073fc:
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xe4e88011:
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xb92fb6cd:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x9a8ae1e1:
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x5e068047:
            [is readString];
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x98dd8936:
            [is readString];
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x6f747657:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0xfffe1bac:
        case (int32_t)0x65427b82:
        case (int32_t)0xf888fa1a:
        case (int32_t)0x8b73e763:
        case (int32_t)0xf7e8d89b:
        case (int32_t)0xece9814b:
        case (int32_t)0x21461b5d:
        case (int32_t)0xf6a5f82f:
            break;
        case (int32_t)0xb8905fb2:
        case (int32_t)0xe4621141:
        case (int32_t)0x6b134e8e:
        case (int32_t)0x41c87565:
            CodexReadInt64Vector(is);
            break;
        case (int32_t)0x2dd14edc:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            [is readInt64];
            [is readInt64];
            [is readString];
            [is readString];
            if (flags & (1 << 4))
            {
                CodexReadObjectVector(is, environment, error);
                [is readInt32];
                [is readInt32];
            }
            if (flags & (1 << 8))
                [is readInt64];
            [is readInt32];
            [is readInt32];
            break;
        }
        case (int32_t)0x4f2b9479:
        {
            int32_t flags = [is readInt32];
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 1))
                CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0xa3d1cb80:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        }
        case (int32_t)0x8c79b63c:
        {
            [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x1b2286b8:
            [is readString];
            break;
        case (int32_t)0x8935fc73:
            [is readInt64];
            break;
        case (int32_t)0x79f5d419:
        case (int32_t)0x523da4eb:
        case (int32_t)0xeafc32bc:
            break;
        case (int32_t)0x52928bca:
            [is readInt32];
            break;
        case (int32_t)0x661d4037:
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xe9baa668:
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0x19360dc0:
        {
            NSArray *folderPeers = CodexReadObjectVector(is, environment, error);
            int32_t pts = [is readInt32];
            int32_t ptsCount = [is readInt32];
            TLUpdate$updateFolderPeers *result = [[TLUpdate$updateFolderPeers alloc] init];
            result.folder_peers = folderPeers;
            result.pts = pts;
            result.pts_count = ptsCount;
            return result;
        }
        case (int32_t)0x695c9e7c:
        {
            [is readInt64];
            [is readInt32];
            [is readInt32];
            TLCodexIgnoredUpdate *result = [[TLCodexIgnoredUpdate alloc] init];
            result.ignoredSignature = signature;
            return result;
        }
        case (int32_t)0x83d60fc2:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 1))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 0))
                [is readInt64];
            if (flags & (1 << 2))
                [is readInt32];
            if (flags & (1 << 3))
                [is readInt32];
            break;
        }
        case (int32_t)0x85dd99d1:
        {
            int32_t flags = [is readInt32];
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 3))
                [is readString];
            break;
        }
        case (int32_t)0x48a30254:
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xa03e5b85:
        case (int32_t)0x86b40b08:
        {
            int32_t flags = [is readInt32];
            if (signature == (int32_t)0x86b40b08 && (flags & (1 << 3)))
                [is readString];
            break;
        }
        case (int32_t)0x77608b83:
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0xa2fa4880:
        case (int32_t)0xb16a6c29:
        case (int32_t)0xfc796b3f:
        case (int32_t)0x50f41ccf:
        case (int32_t)0xafd93fbb:
            [is readString];
            break;
        case (int32_t)0x258aff05:
        case (int32_t)0xa0c0505c:
        case (int32_t)0x13767230:
            [is readString];
            [is readString];
            break;
        case (int32_t)0x35bbdb6b:
            [is readInt32];
            [is readString];
            [is readBytes];
            break;
        case (int32_t)0x93b9fbb5:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readString];
            if (flags & (1 << 1))
                CodexReadObjectVector(is, environment, error);
            break;
        }
        case (int32_t)0x10b78d29:
        {
            int32_t flags = [is readInt32];
            [is readString];
            if (flags & (1 << 0))
                [is readString];
            [is readString];
            [is readInt32];
            break;
        }
        case (int32_t)0xd02e7fd4:
        {
            int32_t flags = [is readInt32];
            [is readString];
            if (flags & (1 << 1))
                [is readString];
            [is readString];
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xbbc7515d:
            [is readInt32];
            [is readString];
            break;
        case (int32_t)0x308660c1:
            [is readString];
            [is readInt64];
            break;
        case (int32_t)0xe988037b:
            [is readString];
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x53d7bfd8:
            [is readString];
            [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0x5f3b8a00:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xc9f06e1b:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 3))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 4))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 2))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x339bef6c:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 3))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 2))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x3e81e078:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 1))
                [is readString];
            if (flags & (1 << 2))
                [is readString];
            break;
        }
        case (int32_t)0xc9662d05:
            [is readInt32];
            [is readString];
            [is readInt32];
            CodexReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0x6c37c15c:
            [is readInt32];
            [is readInt32];
            break;
        case (int32_t)0x11b58939:
        case (int32_t)0x9801d2f7:
            break;
        case (int32_t)0x17399fad:
        {
            int32_t flags = [is readInt32];
            [is readDouble];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 2))
                [is readInt32];
            if (flags & (1 << 4))
                [is readDouble];
            break;
        }
        case (int32_t)0x15590068:
            [is readString];
            break;
        case (int32_t)0xfd149899:
        {
            [is readInt32];
            [is readString];
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xd38ff1c2:
        {
            int32_t flags = [is readInt32];
            [is readDouble];
            [is readInt32];
            [is readInt32];
            if (flags & (1 << 2))
                [is readInt32];
            break;
        }
        case (int32_t)0xeeca5ce3:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readString];
            [is readString];
            if (flags & (1 << 1))
                [is readString];
            [is readString];
            [is readInt32];
            [is readInt32];
            [is readString];
            break;
        }
        case (int32_t)0x751f3146:
            [is readString];
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x58747131:
        {
            [is readInt64];
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 4))
                [is readInt32];
            if (flags & (1 << 5))
                [is readInt32];
            break;
        }
        case (int32_t)0xff16e2ca:
            CodexReadObject(is, environment, error);
            [is readBytes];
            break;
        case (int32_t)0x7adf2420:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 1))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 2))
                [is readInt32];
            if (flags & (1 << 3))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 4))
            {
                [is readString];
                CodexReadObjectVector(is, environment, error);
            }
            break;
        }
        case (int32_t)0x3b6ddad2:
            [is readInt32];
            [is readBytes];
            [is readInt32];
            break;
        case (int32_t)0x6a7e7366:
        {
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            if (error != NULL && *error != nil)
                return nil;
            TLCodexIgnoredUpdate *result = [[TLCodexIgnoredUpdate alloc] init];
            result.ignoredSignature = signature;
            return result;
        }
        case (int32_t)0xd9c6dc1a:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            [is readInt64];
            if (flags & (1 << 1))
                [is readInt32];
            [is readInt32];
            [is readString];
            if (flags & (1 << 2))
                CodexReadObjectVector(is, environment, error);
            if (flags & (1 << 3))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 4))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 6))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x20bcbba1:
        case (int32_t)0x4bbb8f01:
        {
            CodexReadObject(is, environment, error);
            if (error != NULL && *error != nil)
                return nil;
            TLCodexIgnoredUpdate *result = [[TLCodexIgnoredUpdate alloc] init];
            result.ignoredSignature = signature;
            return result;
        }
        case (int32_t)0x56dbfcf8:
        {
            CodexReadObject(is, environment, error);
            CodexReadInt32Vector(is);
            if (error != NULL && *error != nil)
                return nil;
            TLCodexIgnoredUpdate *result = [[TLCodexIgnoredUpdate alloc] init];
            result.ignoredSignature = signature;
            return result;
        }
        case (int32_t)0x6c0d8e23:
        {
            [is readInt32];
            [is readInt64];
            [is readBytes];
            [is readInt32];
            TLCodexIgnoredUpdate *result = [[TLCodexIgnoredUpdate alloc] init];
            result.ignoredSignature = signature;
            return result;
        }
        case (int32_t)0xbe376999:
        case (int32_t)0x2f65c8e4:
            [is readInt64];
            break;
        default:
            break;
    }
    return nil;
}

@end

@interface TLCodexPhoneConnectionParser : NSObject <TLObject>
@end

@implementation TLCodexPhoneConnectionParser

- (int32_t)TLconstructorSignature
{
    return 0;
}

- (int32_t)TLconstructorName
{
    return 0;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    return nil;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0x9cc123c7)
    {
        TLPhoneConnection$phoneConnection *result = [[TLPhoneConnection$phoneConnection alloc] init];
        result.flags = [is readInt32];
        result.n_id = [is readInt64];
        result.ip = [is readString];
        result.ipv6 = [is readString];
        result.port = [is readInt32];
        result.peer_tag = [is readBytes];
        if (error != NULL)
            *error = nil;
        return result;
    }
    
    if (signature == (int32_t)0x635fe375)
    {
        TLPhoneConnection$phoneConnectionWebrtc *result = [[TLPhoneConnection$phoneConnectionWebrtc alloc] init];
        result.flags = [is readInt32];
        result.n_id = [is readInt64];
        result.ip = [is readString];
        result.ipv6 = [is readString];
        result.port = [is readInt32];
        result.username = [is readString];
        result.password = [is readString];
        if (error != NULL)
            *error = nil;
        return result;
    }
    
    TGLog(@"CALL parse phoneConnection.unknown sig=0x%08x", signature);
    return nil;
}

@end

@interface TLCodexModernWebPageEmptyParser : TLWebPage$webPageEmpty
@end

@implementation TLCodexModernWebPageEmptyParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLCodexModernWebPageEmptyParser *result = [[TLCodexModernWebPageEmptyParser alloc] init];
    int32_t flags = [is readInt32];
    result.n_id = [is readInt64];
    if (flags & (1 << 0))
        [is readString];
    return result;
}

@end

@interface TLCodexModernWebPageParser : TLWebPage$webPage
@end

@implementation TLCodexModernWebPageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernWebPageParser *result = [[TLCodexModernWebPageParser alloc] init];
    int32_t flags = [is readInt32];
    [is readInt64];
    [is readString];
    [is readString];
    [is readInt32];
    if (flags & (1 << 0))
        [is readString];
    if (flags & (1 << 1))
        [is readString];
    if (flags & (1 << 2))
        [is readString];
    if (flags & (1 << 3))
        [is readString];
    if (flags & (1 << 4))
        CodexReadObject(is, environment, error);
    if (flags & (1 << 5))
    {
        [is readString];
        [is readString];
    }
    if (flags & (1 << 6))
    {
        [is readInt32];
        [is readInt32];
    }
    if (flags & (1 << 7))
        [is readInt32];
    if (flags & (1 << 8))
        [is readString];
    if (flags & (1 << 9))
        CodexReadObject(is, environment, error);
    if (flags & (1 << 10))
        CodexReadObject(is, environment, error);
    if (flags & (1 << 12))
        CodexReadObjectVector(is, environment, error);
    return result;
}

@end

@interface TLCodexModernMessageMediaUnsupportedParser : TLMessageMedia$messageMediaUnsupported
@end

@implementation TLCodexModernMessageMediaUnsupportedParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    switch (signature)
    {
        case (int32_t)0xf6a548d3:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readString];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 2))
                [is readInt32];
            [is readString];
            [is readInt64];
            [is readString];
            if (flags & (1 << 4))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0x3ded6320:
        case (int32_t)0x9f84f49e:
            break;
        case (int32_t)0x56e0d474:
        {
            TLMessageMedia$messageMediaGeo *result = [[TLMessageMedia$messageMediaGeo alloc] init];
            result.geo = (TLGeoPoint *)CodexReadObject(is, environment, error);

            if (error != NULL && *error != nil)
                return nil;

            return result;
        }
        case (int32_t)0x70322949:
        {
            TLMessageMedia$messageMediaContact *result = [[TLMessageMedia$messageMediaContact alloc] init];
            result.phone_number = [is readString];
            result.first_name = [is readString];
            result.last_name = [is readString];
            result.vcard = [is readString];

            int64_t modernUserId = [is readInt64];
            if (modernUserId > 0 && modernUserId <= 2147483647LL)
                result.user_id = (int32_t)modernUserId;
            else
                result.user_id = 0;

            return result;
        }
        case (int32_t)0x2ec0533f:
            CodexReadObject(is, environment, error);
            [is readString];
            [is readString];
            [is readString];
            [is readString];
            [is readString];
            break;
        case (int32_t)0xfdb19008:
            CodexReadObject(is, environment, error);
            break;
        case (int32_t)0x773f4e66:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xca5cab89:
        {
            [is readInt32];
            CodexReadObject(is, environment, error);
            break;
        }
        case (int32_t)0xaa073beb:
        {
            int32_t flags = [is readInt32];
            CodexReadInt64Vector(is);
            if (flags & (1 << 1))
                CodexSkipStringVector(is);
            if (flags & (1 << 3))
                [is readString];
            [is readInt32];
            if (flags & (1 << 4))
                [is readInt32];
            if (flags & (1 << 5))
                [is readInt64];
            [is readInt32];
            break;
        }
        case (int32_t)0xceaa3ea1:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            if (flags & (1 << 3))
                [is readInt32];
            [is readInt32];
            [is readInt32];
            [is readInt32];
            CodexReadInt64Vector(is);
            if (flags & (1 << 4))
                [is readInt32];
            if (flags & (1 << 5))
                [is readInt64];
            if (flags & (1 << 1))
                [is readString];
            [is readInt32];
            break;
        }
        case (int32_t)0xa8852491:
            [is readInt64];
            CodexReadObjectVector(is, environment, error);
            break;
        case (int32_t)0x8a53b014:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
                CodexReadObjectVector(is, environment, error);
            break;
        }
        default:
            break;
    }
    if (error != NULL && *error != nil)
        return nil;
    return [[TLMessageMedia$messageMediaUnsupported alloc] init];
}

@end

@interface TLCodexModernMessageMediaGeoLiveParser : TLMessageMedia$messageMediaGeoLive
@end

@implementation TLCodexModernMessageMediaGeoLiveParser

- (int32_t)TLconstructorSignature
{
    return (int32_t)0xb940c666;
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernMessageMediaGeoLiveParser *result = [[TLCodexModernMessageMediaGeoLiveParser alloc] init];
    int32_t flags = [is readInt32];
    result.geo = (TLGeoPoint *)CodexReadObject(is, environment, error);
    if (flags & (1 << 0))
        [is readInt32];
    result.period = [is readInt32];
    if (flags & (1 << 1))
        [is readInt32];
    return result;
}

@end

@interface TLCodexModernMessageMediaPhotoParser : TLMessageMedia$messageMediaPhoto
@end

@implementation TLCodexModernMessageMediaPhotoParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernMessageMediaPhotoParser *result = [[TLCodexModernMessageMediaPhotoParser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (flags & (1 << 0))
        result.photo = (TLPhoto *)CodexReadObject(is, environment, error);
    if (flags & (1 << 2))
        result.ttl_seconds = [is readInt32];
    if (flags & (1 << 4))
        CodexReadObject(is, environment, error);
    return result;
}

@end

@interface TLCodexModernMessageMediaDocumentParser : TLMessageMedia$messageMediaDocument
@end

@implementation TLCodexModernMessageMediaDocumentParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernMessageMediaDocumentParser *result = [[TLCodexModernMessageMediaDocumentParser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (flags & (1 << 0))
        result.document = (TLDocument *)CodexReadObject(is, environment, error);
    if (flags & (1 << 5))
    {
        int32_t marker = [is readInt32];
        CodexReadObjectVectorOrSingleWithMarker(is, marker, environment, error);
        if (error != nil && *error != nil)
            return nil;
    }
    if (flags & (1 << 9))
        CodexReadObject(is, environment, error);
    if (flags & (1 << 10))
        [is readInt32];
    if (flags & (1 << 2))
        result.ttl_seconds = [is readInt32];
    return result;
}

@end

@interface TLCodexModernMessageMediaWebPageParser : TLMessageMedia$messageMediaWebPage
@end

@implementation TLCodexModernMessageMediaWebPageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernMessageMediaWebPageParser *result = [[TLCodexModernMessageMediaWebPageParser alloc] init];
    [is readInt32];
    result.webpage = (TLWebPage *)CodexReadObject(is, environment, error);
    return result;
}

@end

@interface TLCodexModernMessageMediaDiceParser : TLMessageMedia$messageMediaUnsupported
@end

@implementation TLCodexModernMessageMediaDiceParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0x08cbec07)
    {
        int32_t flags = [is readInt32];
        [is readInt32];
        [is readString];
        if (flags & (1 << 0))
            CodexReadObject(is, environment, error);
    }
    else
    {
        [is readInt32];
        [is readString];
    }
    if (error != NULL && *error != nil)
        return nil;
    return [[TLMessageMedia$messageMediaUnsupported alloc] init];
}

@end

@interface TLCodexTextWithEntitiesValue : NSObject <TLObject>
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSArray *entities;
@end

@implementation TLCodexTextWithEntitiesValue
- (int32_t)TLconstructorSignature { return (int32_t)0x751f3146; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

@implementation TLCodexPollAnswerValue
- (int32_t)TLconstructorSignature { return (int32_t)0x4b7d786a; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

@implementation TLCodexPollValue
- (int32_t)TLconstructorSignature { return (int32_t)0x966e2dbf; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

@implementation TLCodexPollAnswerVotersValue
- (int32_t)TLconstructorSignature { return (int32_t)0x3645230a; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

@implementation TLCodexPollResultsValue
- (int32_t)TLconstructorSignature { return (int32_t)0xba7bb15e; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

static NSArray *CodexReadPollStringVector(NSInputStream *is, __autoreleasing NSError **error)
{
    bool failed = false;
    int32_t marker = [is readInt32:&failed];
    if (failed || marker != TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid poll string vector"}];
        return nil;
    }
    int32_t count = [is readInt32:&failed];
    if (failed || count < 0 || count > 10000)
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid poll string vector count"}];
        return nil;
    }
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)count];
    for (int32_t i = 0; i < count; i++)
    {
        NSString *value = [is readString];
        if (value == nil)
        {
            if (error != NULL)
                *error = [NSError errorWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid poll string vector item"}];
            return nil;
        }
        [result addObject:value];
    }
    return result;
}

@interface TLCodexTextWithEntitiesParser : NSObject <TLObject>
@end

@implementation TLCodexTextWithEntitiesParser
- (int32_t)TLconstructorSignature { return 0; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexTextWithEntitiesValue *result = [[TLCodexTextWithEntitiesValue alloc] init];
    result.text = [is readString];
    result.entities = CodexReadObjectVector(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    return result;
}
@end

static NSString *CodexPollText(id text)
{
    if ([text isKindOfClass:[NSString class]])
        return text;
    if ([text isKindOfClass:[TLCodexTextWithEntitiesValue class]])
        return ((TLCodexTextWithEntitiesValue *)text).text ?: @"";
    return @"";
}

@interface TLCodexPollAnswerParser : NSObject <TLObject>
@end

@implementation TLCodexPollAnswerParser
- (int32_t)TLconstructorSignature { return 0; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexPollAnswerValue *result = [[TLCodexPollAnswerValue alloc] init];
    if (signature == (int32_t)0x6ca9c2e9)
    {
        result.text = [is readString];
        result.option = [is readBytes];
        return result;
    }
    result.flags = [is readInt32];
    id text = CodexReadObject(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.text = CodexPollText(text);
    result.option = [is readBytes];
    if (result.flags & (1 << 0))
        result.media = CodexReadObject(is, environment, error);
    if (result.flags & (1 << 1))
    {
        result.addedBy = CodexReadObject(is, environment, error);
        result.date = [is readInt32];
    }
    if (error != NULL && *error != nil)
        return nil;
    return result;
}
@end

@interface TLCodexPollParser : NSObject <TLObject>
@end

@implementation TLCodexPollParser
- (int32_t)TLconstructorSignature { return 0; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexPollValue *result = [[TLCodexPollValue alloc] init];
    result.pollId = [is readInt64];
    result.flags = [is readInt32];
    if (signature == (int32_t)0x86e18161)
        result.question = [is readString];
    else
    {
        id question = CodexReadObject(is, environment, error);
        if (error != NULL && *error != nil)
            return nil;
        result.question = CodexPollText(question);
    }
    result.answers = CodexReadObjectVector(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    if (result.flags & (1 << 4))
        result.closePeriod = [is readInt32];
    if (result.flags & (1 << 5))
        result.closeDate = [is readInt32];
    if (signature == (int32_t)0x966e2dbf && (result.flags & (1 << 12)))
        result.countries = CodexReadPollStringVector(is, error);
    if (error != NULL && *error != nil)
        return nil;
    if (signature != (int32_t)0x86e18161)
        result.pollHash = [is readInt64];
    return result;
}
@end

@interface TLCodexPollAnswerVotersParser : NSObject <TLObject>
@end

@implementation TLCodexPollAnswerVotersParser
- (int32_t)TLconstructorSignature { return 0; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexPollAnswerVotersValue *result = [[TLCodexPollAnswerVotersValue alloc] init];
    result.flags = [is readInt32];
    result.option = [is readBytes];
    if (result.flags & (1 << 2))
    {
        result.voters = [is readInt32];
        result.recentVoters = CodexReadObjectVector(is, environment, error);
    }
    if (error != NULL && *error != nil)
        return nil;
    return result;
}
@end

@interface TLCodexPollResultsParser : NSObject <TLObject>
@end

@implementation TLCodexPollResultsParser
- (int32_t)TLconstructorSignature { return 0; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexPollResultsValue *result = [[TLCodexPollResultsValue alloc] init];
    result.flags = [is readInt32];
    if (result.flags & (1 << 1))
        result.results = CodexReadObjectVector(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    if (result.flags & (1 << 2))
        result.totalVoters = [is readInt32];
    if (result.flags & (1 << 3))
        result.recentVoters = CodexReadObjectVector(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    if (result.flags & (1 << 4))
    {
        result.solution = [is readString];
        result.solutionEntities = CodexReadObjectVector(is, environment, error);
    }
    if (error != NULL && *error != nil)
        return nil;
    if (signature == (int32_t)0xba7bb15e && (result.flags & (1 << 5)))
        result.solutionMedia = CodexReadObject(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    return result;
}
@end


@interface TLCodexModernMessageMediaPollParser : TLMessageMedia$messageMediaPollCodex
@end

@implementation TLCodexModernMessageMediaPollParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    int32_t first = [is readInt32];
    bool firstIsPoll = first == (int32_t)0x86e18161 || first == (int32_t)0xb8425be9 || first == (int32_t)0x966e2dbf;
    int32_t flags = 0;
    id poll = nil;
    if (firstIsPoll)
        poll = TLMetaClassStore::constructObject(is, first, environment, nil, error);
    else
    {
        flags = first;
        poll = CodexReadObject(is, environment, error);
    }
    if (error != NULL && *error != nil)
        return nil;
    id results = CodexReadObject(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    if (!firstIsPoll && (flags & (1 << 0)))
        CodexReadObject(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    if (![poll isKindOfClass:[TLCodexPollValue class]] || ![results isKindOfClass:[TLCodexPollResultsValue class]])
        return [[TLMessageMedia$messageMediaUnsupported alloc] init];
    TLMessageMedia$messageMediaPollCodex *result = [[TLMessageMedia$messageMediaPollCodex alloc] init];
    result.poll = poll;
    result.results = results;
    return result;
}

@end

@interface TLCodexUpdateMessagePollParser : TLUpdate$updateMessagePollCodex
@end

@implementation TLCodexUpdateMessagePollParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdate$updateMessagePollCodex *result = [[TLUpdate$updateMessagePollCodex alloc] init];
    int32_t flags = [is readInt32];
    if (flags & (1 << 1))
    {
        id peer = CodexReadObject(is, environment, error);
        if (error != NULL && *error != nil)
            return nil;
        if ([peer isKindOfClass:[TLPeer class]])
            result.peer = peer;
        result.msg_id = [is readInt32];
    }
    if (flags & (1 << 2))
        [is readInt32];
    result.poll_id = [is readInt64];
    if (flags & (1 << 0))
    {
        id poll = CodexReadObject(is, environment, error);
        if (error != NULL && *error != nil)
            return nil;
        if ([poll isKindOfClass:[TLCodexPollValue class]])
            result.poll = poll;
    }
    id results = CodexReadObject(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    if ([results isKindOfClass:[TLCodexPollResultsValue class]])
        result.results = results;
    return result;
}

@end

@interface TLCodexModernMessageEntityMentionNameParser : TLMessageEntity$messageEntityMentionName
@end

@implementation TLCodexModernMessageEntityMentionNameParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLCodexModernMessageEntityMentionNameParser *result = [[TLCodexModernMessageEntityMentionNameParser alloc] init];
    result.offset = [is readInt32];
    result.length = [is readInt32];
    result.user_id = TGModernLegacyIdForModernId([is readInt64]);
    return result;
}

@end

@interface TLCodexModernMessageEntityCustomEmojiParser : TLMessageEntity$messageEntityUnknown
@end

@implementation TLCodexModernMessageEntityCustomEmojiParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLCodexModernMessageEntityCustomEmojiParser *result = [[TLCodexModernMessageEntityCustomEmojiParser alloc] init];
    result.offset = [is readInt32];
    result.length = [is readInt32];
    [is readInt64];
    return result;
}

@end

@interface TLCodexModernMessageEntitySimpleParser : TLMessageEntity$messageEntityUnknown
@end

@implementation TLCodexModernMessageEntitySimpleParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLCodexModernMessageEntitySimpleParser *result = [[TLCodexModernMessageEntitySimpleParser alloc] init];
    if (signature == (int32_t)0xf1ccaaac || signature == (int32_t)0x904ac7c7)
        [is readInt32];
    result.offset = [is readInt32];
    result.length = [is readInt32];
    if (signature == (int32_t)0x904ac7c7)
        [is readInt32];
    if (signature == (int32_t)0x6c622f67 || signature == (int32_t)0xc6c1e5a7)
        [is readString];
    return result;
}

@end

@interface TLCodexDialogsParser : TLmessages_Dialogs
@end

@implementation TLCodexDialogsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLmessages_Dialogs *result = nil;
    if (signature == (int32_t)0x15ba6c40)
    {
        result = [[TLmessages_Dialogs$messages_dialogs alloc] init];
    }
    else if (signature == (int32_t)0x71e094f3)
    {
        bool failed = false;
        int32_t count = [is readInt32:&failed];
        if (failed || count < 0)
        {
            if (error != NULL)
            {
                NSString *description = failed ? @"Unexpected end of stream while reading dialogs count" : [NSString stringWithFormat:@"Invalid dialogs count %d", count];
                *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: description}];
            }
            return nil;
        }
        TLmessages_Dialogs$messages_dialogsSlice *slice = [[TLmessages_Dialogs$messages_dialogsSlice alloc] init];
        slice.count = count;
        result = slice;
    }
    else if (signature == (int32_t)0xf0e3e596 || signature == (int32_t)0x0200185b)
    {
        bool failed = false;
        int32_t count = [is readInt32:&failed];
        if (failed || count < 0)
        {
            if (error != NULL)
            {
                NSString *description = failed ? @"Unexpected end of stream while reading dialogs count" : [NSString stringWithFormat:@"Invalid dialogs count %d", count];
                *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: description}];
            }
            return nil;
        }
        TLmessages_Dialogs$messages_dialogsSlice *slice = [[TLmessages_Dialogs$messages_dialogsSlice alloc] init];
        slice.count = count;
        slice.dialogs = @[];
        slice.messages = @[];
        slice.chats = @[];
        slice.users = @[];
        return slice;
    }
    else
    {
        if (error != NULL)
        {
            NSString *description = [NSString stringWithFormat:@"Unsupported messages.Dialogs constructor %08x", signature];
            *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: description}];
        }
        return nil;
    }

    result.dialogs = CodexReadStrictObjectVectorWithRole(is, @"messages.dialogs.dialogs", environment, error);
    if (result.dialogs == nil)
        return nil;
    result.messages = CodexReadStrictObjectVectorWithRole(is, @"messages.dialogs.messages", environment, error);
    if (result.messages == nil)
        return nil;
    result.chats = CodexReadStrictObjectVectorWithRole(is, @"messages.dialogs.chats", environment, error);
    if (result.chats == nil)
        return nil;
    result.users = CodexReadStrictObjectVectorWithRole(is, @"messages.dialogs.users", environment, error);
    if (result.users == nil)
        return nil;

    return result;
}

@end

@interface TLCodexModernContactParser : TLContact$contact
@end

@implementation TLCodexModernContactParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernContactParser *result = [[TLCodexModernContactParser alloc] init];
    result.user_id = TGModernLegacyIdForModernId([is readInt64]);
    TLBool *mutual = (TLBool *)CodexReadObject(is, environment, error);
    result.mutual = [mutual boolValue];
    return result;
}

@end

@interface TLCodexModernContactsParser : TLcontacts_Contacts$contacts_contacts
@end

@implementation TLCodexModernContactsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernContactsParser *result = [[TLCodexModernContactsParser alloc] init];
    int32_t vectorMarker = [is readInt32];
    int32_t count = 0;
    if (vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
        count = [is readInt32];
    else if (vectorMarker >= 0 && vectorMarker <= 10000)
        count = vectorMarker;
    
    NSMutableArray *contacts = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)MAX(0, count)];
    bool hasUsersMarker = false;
    int32_t usersMarker = 0;
    for (int32_t i = 0; i < count; i++)
    {
        int32_t contactSignature = [is readInt32];
        if (contactSignature == TL_UNIVERSAL_VECTOR_CONSTRUCTOR || (contactSignature >= 0 && contactSignature <= 10000))
        {
            hasUsersMarker = true;
            usersMarker = contactSignature;
            break;
        }
        if (contactSignature == (int32_t)0x145ade0b)
        {
            TLContact$contact *contact = [[TLContact$contact alloc] init];
            contact.user_id = TGModernLegacyIdForModernId([is readInt64]);
            int32_t mutualSignature = [is readInt32];
            contact.mutual = mutualSignature == (int32_t)TL_BOOL_TRUE_CONSTRUCTOR;
            [contacts addObject:contact];
        }
        else
        {
            id contact = TLMetaClassStore::constructObject(is, contactSignature, environment, nil, error);
            if (error != nil && *error != nil)
                return nil;
            if (contact != nil)
                [contacts addObject:contact];
        }
    }
    
    result.contacts = contacts;
    if (hasUsersMarker)
    {
        result.saved_count = 0;
        result.users = CodexReadMaybeDoubleObjectVectorWithMarker(is, usersMarker, environment, error);
        return result;
    }
    int32_t nextMarker = [is readInt32];
    if (nextMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
    {
        result.saved_count = 0;
        result.users = CodexReadMaybeDoubleObjectVectorWithMarker(is, nextMarker, environment, error);
    }
    else
    {
        result.saved_count = nextMarker;
        int32_t usersMarker = [is readInt32];
        result.users = CodexReadMaybeDoubleObjectVectorWithMarker(is, usersMarker, environment, error);
    }
    return result;
}

@end

@interface TLCodexModernBlockedParser : TLcontacts_Blocked$contacts_blocked
@end

@implementation TLCodexModernBlockedParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLcontacts_Blocked$contacts_blocked *result = [[TLcontacts_Blocked$contacts_blocked alloc] init];
    if (signature == (int32_t)0xe1664194)
        [is readInt32];
    CodexReadObjectVector(is, environment, error);
    CodexReadObjectVector(is, environment, error);
    result.blocked = @[];
    result.users = CodexReadObjectVector(is, environment, error);
    return result;
}

@end

@interface TLCodexModernMessageFwdHeaderParser : TLMessageFwdHeader$messageFwdHeaderMeta
@end

@implementation TLCodexModernMessageFwdHeaderParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernMessageFwdHeaderParser *result = [[TLCodexModernMessageFwdHeaderParser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (flags & (1 << 0))
    {
        TLPeer *fromPeer = (TLPeer *)CodexReadObject(is, environment, error);
        if ([fromPeer isKindOfClass:[TLPeer$peerUser class]])
            result.from_id = ((TLPeer$peerUser *)fromPeer).user_id;
        else if ([fromPeer isKindOfClass:[TLPeer$peerChannel class]])
            result.channel_id = ((TLPeer$peerChannel *)fromPeer).channel_id;
        else if ([fromPeer isKindOfClass:[TLPeer$peerChat class]])
            result.from_id = ((TLPeer$peerChat *)fromPeer).chat_id;
    }
    if (flags & (1 << 5))
        [is readString];
    result.date = [is readInt32];
    if (flags & (1 << 2))
        result.channel_post = [is readInt32];
    if (flags & (1 << 3))
        result.post_author = [is readString];
    if (flags & (1 << 4))
    {
        result.saved_from_peer = (TLPeer *)CodexReadObject(is, environment, error);
        result.saved_from_msg_id = [is readInt32];
    }
    if (flags & (1 << 8))
        CodexReadObject(is, environment, error);
    if (flags & (1 << 9))
        [is readString];
    if (flags & (1 << 10))
        [is readInt32];
    if (flags & (1 << 6))
        [is readString];
    return result;
}

@end

@interface TLCodexMessageViewsResultParser : NSObject<TLObject>
@end

@implementation TLCodexMessageViewsResultParser

- (int32_t)TLconstructorSignature
{
    return (int32_t)0xb6c4f543;
}

- (int32_t)TLconstructorName
{
    return (int32_t)0xb6c4f543;
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    int32_t vectorMarker = [is readInt32];
    int32_t count = 0;
    if (vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
        count = [is readInt32];
    else if (vectorMarker >= 0 && vectorMarker <= 10000)
        count = vectorMarker;
    else
    {
        count = 0;
    }
    
    NSMutableArray *viewCounts = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)MAX(0, count)];
    for (int32_t i = 0; i < count; i++)
    {
        int32_t itemSignature = [is readInt32];
        int32_t views = 0;
        if (itemSignature == (int32_t)0x455b853d)
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                views = [is readInt32];
            if (flags & (1 << 1))
                [is readInt32];
            if (flags & (1 << 2))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 3))
                CodexReadObject(is, environment, error);
            if (error != nil && *error != nil)
            {
                TGLog(@"VIEWS failed nested field index=%d flags=0x%08x error=%@", i, flags, *error);
                *error = nil;
            }
        }
        else
            TGLog(@"VIEWS unknown MessageViews item sig=0x%08x index=%d", itemSignature, i);
        [viewCounts addObject:@(views)];
    }
    
    CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
    {
        TGLog(@"VIEWS failed chats vector error=%@", *error);
        *error = nil;
    }
    CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
    {
        TGLog(@"VIEWS failed users vector error=%@", *error);
        *error = nil;
    }
    
    return (id<TLObject>)viewCounts;
}

@end

@interface TLCodexModernMessagesParser : TLmessages_Messages$messages_messages
@end

@implementation TLCodexModernMessagesParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernMessagesParser *result = [[TLCodexModernMessagesParser alloc] init];
    result.messages = CodexReadStrictObjectVectorWithRole(is, @"messages.messages.messages", environment, error);
    if (error != nil && *error != nil)
    {
        return nil;
    }
    if (signature == (int32_t)0x1d73e7ea)
    {
        CodexReadStrictObjectVectorWithRole(is, @"messages.messages.topics", environment, error);
        if (error != nil && *error != nil)
        {
            return nil;
        }
    }
    result.chats = CodexReadStrictObjectVectorWithRole(is, @"messages.messages.chats", environment, error);
    if (error != nil && *error != nil)
    {
        return nil;
    }
    result.users = CodexReadStrictObjectVectorWithRole(is, @"messages.messages.users", environment, error);
    if (error != nil && *error != nil)
    {
        return nil;
    }
    
    return result;
}

@end

@interface TLCodexModernMessagesSliceParser : TLmessages_Messages$messages_messagesSlice
@end

@implementation TLCodexModernMessagesSliceParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernMessagesSliceParser *result = [[TLCodexModernMessagesSliceParser alloc] init];
    int32_t flags = [is readInt32];
    result.count = [is readInt32];
    if (flags & (1 << 0))
        [is readInt32];
    if (flags & (1 << 2))
        [is readInt32];
    if (signature == (int32_t)0x5f206716 && (flags & (1 << 3)))
    {
        CodexReadObject(is, environment, error);
        if (error != nil && *error != nil)
            return nil;
    }
    
    result.messages = CodexReadStrictObjectVectorWithRole(is, @"messagesSlice.messages", environment, error);
    if (error != nil && *error != nil)
    {
        return nil;
    }
    if (signature == (int32_t)0x5f206716)
    {
        CodexReadStrictObjectVectorWithRole(is, @"messagesSlice.topics", environment, error);
        if (error != nil && *error != nil)
        {
            return nil;
        }
    }
    result.chats = CodexReadStrictObjectVectorWithRole(is, @"messagesSlice.chats", environment, error);
    if (error != nil && *error != nil)
    {
        return nil;
    }
    result.users = CodexReadStrictObjectVectorWithRole(is, @"messagesSlice.users", environment, error);
    if (error != nil && *error != nil)
    {
        return nil;
    }
    
    return result;
}

@end

@interface TLCodexModernDraftMessageEmptyParser : TLDraftMessage$draftMessageEmpty
@end

@implementation TLCodexModernDraftMessageEmptyParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    int32_t flags = [is readInt32];
    if (flags & (1 << 0))
        [is readInt32];
    return [[TLDraftMessage$draftMessageEmpty alloc] init];
}

@end

@interface TLCodexModernInputPeerValue : NSObject <TLObject>
@property (nonatomic) int32_t signature;
@property (nonatomic) int64_t peerId;
@property (nonatomic) int64_t accessHash;
@property (nonatomic) int32_t messageId;
@property (nonatomic, strong) id sourcePeer;
@end

@implementation TLCodexModernInputPeerValue
- (int32_t)TLconstructorSignature { return _signature; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

static TLCodexModernInputPeerValue *CodexReadModernInputPeerValue(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t signature = [is readInt32];
    TLCodexModernInputPeerValue *result = [[TLCodexModernInputPeerValue alloc] init];
    result.signature = signature;
    switch (signature)
    {
        case (int32_t)0x7f3b18ea:
        case (int32_t)0x7da07ec9:
            break;
        case (int32_t)0x35a95cb9:
            result.peerId = [is readInt64];
            break;
        case (int32_t)0xdde8a54c:
        case (int32_t)0x27bcbbfc:
            result.peerId = [is readInt64];
            result.accessHash = [is readInt64];
            break;
        case (int32_t)0xa87b0a1c:
        case (int32_t)0xbd2a0840:
            result.sourcePeer = CodexReadModernInputPeerValue(is, environment, error);
            if (error != NULL && *error != nil)
                return nil;
            result.messageId = [is readInt32];
            result.peerId = [is readInt64];
            break;
        default:
        {
            id object = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
            if (error != NULL && *error != nil)
                return nil;
            result.sourcePeer = object;
            break;
        }
    }
    return result;
}

@interface TLCodexModernInputReplyToValue : NSObject <TLObject>
@property (nonatomic) int32_t signature;
@property (nonatomic) int32_t flags;
@property (nonatomic) int32_t replyToMessageId;
@property (nonatomic) int32_t topMessageId;
@property (nonatomic, strong) id replyToPeer;
@property (nonatomic, strong) NSString *quoteText;
@property (nonatomic, strong) NSArray *quoteEntities;
@property (nonatomic) int32_t quoteOffset;
@property (nonatomic, strong) id monoforumPeer;
@property (nonatomic) int32_t todoItemId;
@property (nonatomic, strong) NSData *pollOption;
@property (nonatomic) int32_t storyId;
@end

@implementation TLCodexModernInputReplyToValue
- (int32_t)TLconstructorSignature { return _signature; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

@interface TLCodexModernInputReplyToParser : NSObject <TLObject>
@end

@implementation TLCodexModernInputReplyToParser
- (int32_t)TLconstructorSignature { return 0; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernInputReplyToValue *result = [[TLCodexModernInputReplyToValue alloc] init];
    result.signature = signature;
    if (signature == (int32_t)0x5881323a)
    {
        result.replyToPeer = CodexReadModernInputPeerValue(is, environment, error);
        if (error != NULL && *error != nil)
            return nil;
        result.storyId = [is readInt32];
        return result;
    }
    if (signature == (int32_t)0x69d66c45)
    {
        result.monoforumPeer = CodexReadModernInputPeerValue(is, environment, error);
        if (error != NULL && *error != nil)
            return nil;
        return result;
    }
    result.flags = [is readInt32];
    result.replyToMessageId = [is readInt32];
    if (result.flags & (1 << 0))
        result.topMessageId = [is readInt32];
    if (result.flags & (1 << 1))
    {
        result.replyToPeer = CodexReadModernInputPeerValue(is, environment, error);
        if (error != NULL && *error != nil)
            return nil;
    }
    if (result.flags & (1 << 2))
        result.quoteText = [is readString];
    if (result.flags & (1 << 3))
    {
        result.quoteEntities = CodexReadObjectVector(is, environment, error);
        if (error != NULL && *error != nil)
            return nil;
    }
    if (result.flags & (1 << 4))
        result.quoteOffset = [is readInt32];
    if (signature != (int32_t)0x22c0f6d5 && (result.flags & (1 << 5)))
    {
        result.monoforumPeer = CodexReadModernInputPeerValue(is, environment, error);
        if (error != NULL && *error != nil)
            return nil;
    }
    if (signature != (int32_t)0x22c0f6d5 && (result.flags & (1 << 6)))
        result.todoItemId = [is readInt32];
    if (signature == (int32_t)0x3bd4b7c2 && (result.flags & (1 << 7)))
        result.pollOption = [is readBytes];
    return result;
}
@end

@interface TLCodexModernDraftMessageParser : TLDraftMessage$draftMessage
@end

@implementation TLCodexModernDraftMessageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLDraftMessage$draftMessage *result = [[TLDraftMessage$draftMessage alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (flags & (1 << 4))
        CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.message = [is readString];
    if (flags & (1 << 3))
        result.entities = CodexReadObjectVectorOrSingle(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    if (flags & (1 << 5))
        CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.date = [is readInt32];
    if (flags & (1 << 7))
        [is readInt64];
    bool hasSuggestedPost = signature == (int32_t)0x96eaa5eb || signature == (int32_t)0x60fe3294;
    bool hasRichMessage = signature == (int32_t)0x60fe3294;
    if (hasSuggestedPost && (flags & (1 << 8)))
        CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    if (hasRichMessage && (flags & (1 << 9)))
        CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    return result;
}

@end

@interface TLCodexModernUpdateDraftMessageParser : TLUpdate$updateDraftMessage
@end

@implementation TLCodexModernUpdateDraftMessageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdate$updateDraftMessage *result = [[TLUpdate$updateDraftMessage alloc] init];
    int32_t flags = [is readInt32];
    result.peer = (TLPeer *)CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    if (flags & (1 << 0))
        [is readInt32];
    if (signature == (int32_t)0xedfc111e && (flags & (1 << 1)))
        CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.draft = (TLDraftMessage *)CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    return result;
}

@end

@interface TLCodexModernChatParticipantParser : NSObject <TLObject>
@end

@implementation TLCodexModernChatParticipantParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLChatParticipant *result = nil;
    switch (signature)
    {
        case (int32_t)0xc02d4007:
        {
            TLChatParticipant$chatParticipant *participant = [[TLChatParticipant$chatParticipant alloc] init];
            participant.user_id = TGModernLegacyIdForModernId([is readInt64]);
            participant.inviter_id = TGModernLegacyIdForModernId([is readInt64]);
            participant.date = [is readInt32];
            result = participant;
            break;
        }
        case (int32_t)0xe46bcee4:
        {
            TLChatParticipant$chatParticipantCreator *participant = [[TLChatParticipant$chatParticipantCreator alloc] init];
            participant.user_id = TGModernLegacyIdForModernId([is readInt64]);
            result = participant;
            break;
        }
        case (int32_t)0xa0933f5b:
        {
            TLChatParticipant$chatParticipantAdmin *participant = [[TLChatParticipant$chatParticipantAdmin alloc] init];
            participant.user_id = TGModernLegacyIdForModernId([is readInt64]);
            participant.inviter_id = TGModernLegacyIdForModernId([is readInt64]);
            participant.date = [is readInt32];
            result = participant;
            break;
        }
    }
    return result;
}

@end

@interface TLCodexModernChannelParticipantParser : NSObject <TLObject>
@end

@implementation TLCodexModernChannelParticipantParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    int32_t flags = 0;
    TLChannelParticipant *result = nil;
    switch (signature)
    {
        case (int32_t)0xc00c07c0:
        {
            TLChannelParticipant$channelParticipant *participant = [[TLChannelParticipant$channelParticipant alloc] init];
            participant.user_id = TGModernLegacyIdForModernId([is readInt64]);
            participant.date = [is readInt32];
            result = participant;
            break;
        }
        case (int32_t)0x1bd54456:
        {
            flags = [is readInt32];
            TLChannelParticipant$channelParticipant *participant = [[TLChannelParticipant$channelParticipant alloc] init];
            participant.user_id = TGModernLegacyIdForModernId([is readInt64]);
            participant.date = [is readInt32];
            if (flags & (1 << 0)) [is readInt32];
            if (flags & (1 << 2)) [is readString];
            result = participant;
            break;
        }
        case (int32_t)0x35a8bfa7:
        {
            flags = [is readInt32];
            TLChannelParticipant$channelParticipantSelf *participant = [[TLChannelParticipant$channelParticipantSelf alloc] init];
            participant.user_id = TGModernLegacyIdForModernId([is readInt64]);
            participant.inviter_id = TGModernLegacyIdForModernId([is readInt64]);
            participant.date = [is readInt32];
            result = participant;
            break;
        }
        case (int32_t)0xa9478a1a:
        {
            flags = [is readInt32];
            TLChannelParticipant$channelParticipantSelf *participant = [[TLChannelParticipant$channelParticipantSelf alloc] init];
            participant.user_id = TGModernLegacyIdForModernId([is readInt64]);
            participant.inviter_id = TGModernLegacyIdForModernId([is readInt64]);
            participant.date = [is readInt32];
            if (flags & (1 << 1)) [is readInt32];
            if (flags & (1 << 2)) [is readString];
            result = participant;
            break;
        }
        case (int32_t)0x2fe601d3:
        {
            flags = [is readInt32];
            TLChannelParticipant$channelParticipantCreator *participant = [[TLChannelParticipant$channelParticipantCreator alloc] init];
            participant.user_id = TGModernLegacyIdForModernId([is readInt64]);
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0)) [is readString];
            result = participant;
            break;
        }
        case (int32_t)0x34c3bb53:
        {
            flags = [is readInt32];
            TLChannelParticipant$channelParticipantAdmin *participant = [[TLChannelParticipant$channelParticipantAdmin alloc] init];
            participant.flags = flags;
            participant.user_id = TGModernLegacyIdForModernId([is readInt64]);
            if (flags & (1 << 1))
                participant.inviter_id = TGModernLegacyIdForModernId([is readInt64]);
            participant.promoted_by = TGModernLegacyIdForModernId([is readInt64]);
            participant.date = [is readInt32];
            participant.admin_rights = (TLChannelAdminRights *)CodexReadObject(is, environment, error);
            if (flags & (1 << 2)) [is readString];
            result = participant;
            break;
        }
        case (int32_t)0x6df8014e:
        {
            flags = [is readInt32];
            TLChannelParticipant$channelParticipantBanned *participant = [[TLChannelParticipant$channelParticipantBanned alloc] init];
            participant.flags = flags;
            CodexReadObject(is, environment, error);
            participant.kicked_by = TGModernLegacyIdForModernId([is readInt64]);
            participant.date = [is readInt32];
            participant.banned_rights = (TLChannelBannedRights *)CodexReadObject(is, environment, error);
            result = participant;
            break;
        }
        case (int32_t)0xd5f0ad91:
        {
            flags = [is readInt32];
            TLChannelParticipant$channelParticipantBanned *participant = [[TLChannelParticipant$channelParticipantBanned alloc] init];
            participant.flags = flags;
            CodexReadObject(is, environment, error);
            participant.kicked_by = TGModernLegacyIdForModernId([is readInt64]);
            participant.date = [is readInt32];
            participant.banned_rights = (TLChannelBannedRights *)CodexReadObject(is, environment, error);
            if (flags & (1 << 2)) [is readString];
            result = participant;
            break;
        }
        case (int32_t)0x1b03f006:
        {
            CodexReadObject(is, environment, error);
            result = [[TLChannelParticipant alloc] init];
            break;
        }
    }
    if (error != nil && *error != nil)
        return nil;
    return result;
}

@end

@interface TLCodexModernChannelParticipantResultParser : TLchannels_ChannelParticipant$channels_channelParticipant
@end

@implementation TLCodexModernChannelParticipantResultParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLchannels_ChannelParticipant$channels_channelParticipant *result = [[TLchannels_ChannelParticipant$channels_channelParticipant alloc] init];
    result.participant = (TLChannelParticipant *)CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.chats = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.users = CodexReadObjectVector(is, environment, error);
    return result;
}

@end

@interface TLCodexModernChannelsParticipantsParser : TLchannels_ChannelParticipants$channels_channelParticipants
@end

@implementation TLCodexModernChannelsParticipantsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLchannels_ChannelParticipants$channels_channelParticipants *result = [[TLchannels_ChannelParticipants$channels_channelParticipants alloc] init];
    result.count = [is readInt32];
    result.participants = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.users = CodexReadObjectVector(is, environment, error);
    return result;
}

@end

@interface TLCodexModernMessageEmptyParser : TLMessage$messageEmpty
@end

@implementation TLCodexModernMessageEmptyParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLMessage$messageEmpty *result = [[TLMessage$messageEmpty alloc] init];
    int32_t flags = [is readInt32];
    result.n_id = [is readInt32];
    if (flags & (1 << 0))
        CodexReadObject(is, environment, error);
    return result;
}

@end

@interface TLCodexModernPeerSettingsParser : TLPeerSettings$peerSettings
@end

@implementation TLCodexModernPeerSettingsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLPeerSettings$peerSettings *result = [[TLPeerSettings$peerSettings alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (flags & (1 << 6))
        [is readInt32];
    if (flags & (1 << 9))
    {
        [is readString];
        [is readInt32];
    }
    if (flags & (1 << 13))
    {
        [is readInt64];
        [is readString];
    }
    if (flags & (1 << 14))
        [is readInt64];
    if (flags & (1 << 15))
        [is readString];
    if (flags & (1 << 16))
        [is readString];
    if (flags & (1 << 17))
        [is readInt32];
    if (flags & (1 << 18))
        [is readInt32];
    return result;
}

@end

@interface TLCodexInputGroupCallParser : NSObject <TLObject>
@end

@implementation TLCodexInputGroupCallParser

- (int32_t)TLconstructorSignature
{
    return (int32_t)0xd8aa840f;
}

- (int32_t)TLconstructorName
{
    return 0;
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    [is readInt64];
    [is readInt64];
    return nil;
}

@end

@interface TLCodexModernBotCommandParser : TLBotCommand$botCommand
@end

@implementation TLCodexModernBotCommandParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLBotCommand$botCommand *result = [[TLBotCommand$botCommand alloc] init];
    if (signature == (int32_t)0x9852d6d2)
        [is readInt32];
    result.command = [is readString];
    result.n_description = [is readString];
    return result;
}

@end

@interface TLCodexModernAllStickersParser : TLmessages_AllStickers$messages_allStickers
@end

@implementation TLCodexModernAllStickersParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0xe86602c3)
    {
        return [[TLmessages_AllStickers$messages_allStickersNotModified alloc] init];
    }
    
    TLmessages_AllStickers$messages_allStickers *result = [[TLmessages_AllStickers$messages_allStickers alloc] init];
    result.n_hash = (int32_t)[is readInt64];
    result.sets = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    return result;
}

@end

@interface TLCodexModernRecentStickersParser : TLmessages_RecentStickers$messages_recentStickers
@end

@implementation TLCodexModernRecentStickersParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0x0b17f890)
    {
        return [[TLmessages_RecentStickers$messages_recentStickersNotModified alloc] init];
    }
    
    TLmessages_RecentStickers$messages_recentStickers *result = [[TLmessages_RecentStickers$messages_recentStickers alloc] init];
    result.n_hash = (int32_t)[is readInt64];
    result.packs = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.stickers = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.dates = CodexReadInt32Vector(is);
    return result;
}

@end

@interface TLCodexModernFeaturedStickersParser : TLmessages_FeaturedStickers$messages_featuredStickers
@end

@implementation TLCodexModernFeaturedStickersParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0xc6dc0c66)
    {
        [is readInt32];
        return [[TLmessages_FeaturedStickers$messages_featuredStickersNotModified alloc] init];
    }
    
    TLmessages_FeaturedStickers$messages_featuredStickers *result = [[TLmessages_FeaturedStickers$messages_featuredStickers alloc] init];
    [is readInt32];
    result.n_hash = (int32_t)[is readInt64];
    [is readInt32];
    result.sets = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.unread = CodexReadInt64Vector(is);
    return result;
}

@end

@interface TLCodexModernFavedStickersParser : TLmessages_FavedStickers$messages_favedStickers
@end

@implementation TLCodexModernFavedStickersParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0x9e8fa6d3)
    {
        return [[TLmessages_FavedStickers$messages_favedStickersNotModified alloc] init];
    }
    
    TLmessages_FavedStickers$messages_favedStickers *result = [[TLmessages_FavedStickers$messages_favedStickers alloc] init];
    result.n_hash = (int32_t)[is readInt64];
    result.packs = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.stickers = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    return result;
}

@end

@interface TLCodexModernInputStickerSetParser : TLInputStickerSet
@end

@implementation TLCodexModernInputStickerSetParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    if (signature == (int32_t)0x9de7a269)
    {
        TLInputStickerSet$inputStickerSetID *result = [[TLInputStickerSet$inputStickerSetID alloc] init];
        result.n_id = [is readInt64];
        result.access_hash = [is readInt64];
        return result;
    }
    if (signature == (int32_t)0x861cc8a0)
    {
        TLInputStickerSet$inputStickerSetShortName *result = [[TLInputStickerSet$inputStickerSetShortName alloc] init];
        result.short_name = [is readString];
        return result;
    }
    if (signature == (int32_t)0xe67f520e)
        [is readString];
    
    return [[TLInputStickerSet$inputStickerSetEmpty alloc] init];
}

@end

@interface TLCodexModernDocumentAttributeStickerParser : TLDocumentAttributeSticker
@end

@implementation TLCodexModernDocumentAttributeStickerParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLDocumentAttributeSticker *result = [[TLDocumentAttributeSticker alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.alt = [is readString];
    result.stickerset = (TLInputStickerSet *)CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    if (flags & (1 << 0))
        result.mask_coords = (TLMaskCoords *)CodexReadObject(is, environment, error);
    return result;
}

@end

@interface TLCodexModernLangPackLanguageParser : TLLangPackLanguage
@end

@implementation TLCodexModernLangPackLanguageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLLangPackLanguage$langPackLanguage *result = [[TLLangPackLanguage$langPackLanguage alloc] init];
    int32_t flags = [is readInt32];
    result.name = [is readString];
    result.native_name = [is readString];
    result.lang_code = [is readString];
    if (flags & (1 << 1))
        [is readString];
    [is readString];
    [is readInt32];
    [is readInt32];
    [is readString];
    return result;
}

@end

@interface TLCodexModernStickerSetMetaParser : TLStickerSet$stickerSetMeta
@end

@implementation TLCodexModernStickerSetMetaParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLStickerSet$stickerSetMeta *result = [[TLStickerSet$stickerSetMeta alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (flags & (1 << 0))
        result.installed_date = [is readInt32];
    result.n_id = [is readInt64];
    result.access_hash = [is readInt64];
    result.title = [is readString];
    result.short_name = [is readString];
    if (flags & (1 << 4))
    {
        CodexReadObjectVector(is, environment, error);
        if (error != nil && *error != nil)
            return nil;
        [is readInt32];
        [is readInt32];
    }
    if (flags & (1 << 8))
        [is readInt64];
    result.count = [is readInt32];
    result.n_hash = [is readInt32];
    return result;
}

@end

@interface TLCodexModernStickerKeywordParser : NSObject <TLObject>
@end

@implementation TLCodexModernStickerKeywordParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    [is readInt64];
    CodexSkipStringVector(is);
    return nil;
}

@end

@interface TLCodexStickerPackParser : TLStickerPack$stickerPack
@end

@implementation TLCodexStickerPackParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLStickerPack$stickerPack *result = [[TLStickerPack$stickerPack alloc] init];
    result.emoticon = [is readString];
    result.documents = CodexReadInt64Vector(is);
    return result;
}

@end

@interface TLCodexModernStickerSetParser : TLmessages_StickerSet$messages_stickerSet
@end

@implementation TLCodexModernStickerSetParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0xd3f924eb)
    {
        return [[TLmessages_StickerSet alloc] init];
    }
    
    TLmessages_StickerSet$messages_stickerSet *result = [[TLmessages_StickerSet$messages_stickerSet alloc] init];
    result.set = (TLStickerSet *)CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.packs = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.documents = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    return result;
}

@end

@interface TLCodexModernStickerSetCoveredParser : TLStickerSetCovered$stickerSetMultiCovered
@end

@implementation TLCodexModernStickerSetCoveredParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0x6410a5d2)
    {
        TLStickerSetCovered$stickerSetCovered *result = [[TLStickerSetCovered$stickerSetCovered alloc] init];
        result.set = (TLStickerSet *)CodexReadObject(is, environment, error);
        result.cover = (TLDocument *)CodexReadObject(is, environment, error);
        return result;
    }

    TLStickerSetCovered$stickerSetMultiCovered *result = [[TLStickerSetCovered$stickerSetMultiCovered alloc] init];
    result.set = (TLStickerSet *)CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;

    if (signature == (int32_t)0x3407e51b)
    {
        result.covers = CodexReadObjectVector(is, environment, error);
    }
    else if (signature == (int32_t)0x40d13c0e)
    {
        CodexReadObjectVector(is, environment, error);
        CodexReadObjectVector(is, environment, error);
        result.covers = CodexReadObjectVector(is, environment, error);
    }
    else
    {
        result.covers = @[];
    }

    return result;
}

@end

@interface TLCodexModernStickerSetInstallResultParser : TLmessages_StickerSetInstallResult
@end

@implementation TLCodexModernStickerSetInstallResultParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0x38641628)
    {
        return [[TLmessages_StickerSetInstallResult$messages_stickerSetInstallResultSuccess alloc] init];
    }
    
    TLmessages_StickerSetInstallResult$messages_stickerSetInstallResultArchive *result = [[TLmessages_StickerSetInstallResult$messages_stickerSetInstallResultArchive alloc] init];
    result.sets = CodexReadObjectVector(is, environment, error);
    return result;
}

@end

@interface TLCodexModernFoundStickerSetsParser : TLmessages_FoundStickerSets$messages_foundStickerSets
@end

@implementation TLCodexModernFoundStickerSetsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0x0d54b65d)
    {
        return [[TLmessages_FoundStickerSets alloc] init];
    }
    
    TLmessages_FoundStickerSets$messages_foundStickerSets *result = [[TLmessages_FoundStickerSets$messages_foundStickerSets alloc] init];
    result.n_hash = [is readInt32];
    result.sets = CodexReadObjectVector(is, environment, error);
    return result;
}

@end

@interface TLCodexModernExportedAuthorizationParser : TLauth_ExportedAuthorization$auth_exportedAuthorization
@end

@implementation TLCodexModernExportedAuthorizationParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLauth_ExportedAuthorization$auth_exportedAuthorization *result = [[TLauth_ExportedAuthorization$auth_exportedAuthorization alloc] init];
    result.n_id = (int32_t)[is readInt64];
    result.bytes = [is readBytes];
    return result;
}

@end

@interface TLCodexModernBotInfoParser : TLBotInfo$botInfo
@end

@implementation TLCodexModernBotInfoParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLBotInfo$botInfo *result = [[TLBotInfo$botInfo alloc] init];
    int32_t flags = [is readInt32];
    if (flags & (1 << 0))
    {
        int64_t userId = [is readInt64];
        result.user_id = TGModernLegacyIdForModernId(userId);
    }
    if (flags & (1 << 1))
        result.n_description = [is readString];
    if (flags & (1 << 4))
        CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    if (flags & (1 << 5))
        CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    if (flags & (1 << 2))
        result.commands = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    if (flags & (1 << 3))
        CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    return result;
}

@end

@interface TLCodexPeerSettingsContainerParser : TLPeerSettings$peerSettings
@end

@implementation TLCodexPeerSettingsContainerParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLPeerSettings *settings = (TLPeerSettings *)CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    return settings != nil ? settings : [[TLPeerSettings$peerSettings alloc] init];
}

@end

@interface TLCodexForumTopic : NSObject <TLObject>
@property (nonatomic) int32_t flags;
@property (nonatomic) int32_t topicId;
@property (nonatomic) int32_t date;
@property (nonatomic, strong) NSString *title;
@property (nonatomic) int32_t iconColor;
@property (nonatomic) int64_t iconEmojiId;
@property (nonatomic) int32_t topMessage;
@property (nonatomic) int32_t readInboxMaxId;
@property (nonatomic) int32_t readOutboxMaxId;
@property (nonatomic) int32_t unreadCount;
@property (nonatomic) int32_t unreadMentionsCount;
@property (nonatomic) int32_t unreadReactionsCount;
@property (nonatomic) int32_t unreadPollVotesCount;
@property (nonatomic) bool deleted;
@end

@implementation TLCodexForumTopic
- (int32_t)TLconstructorSignature { return (int32_t)0xfcdad815; }
- (int32_t)TLconstructorName { return 0; }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

@interface TLCodexForumTopicParser : NSObject <TLObject>
@end

@implementation TLCodexForumTopicParser

- (int32_t)TLconstructorSignature
{
    return 0x71701da9;
}

- (int32_t)TLconstructorName
{
    return 0;
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexForumTopic *result = [[TLCodexForumTopic alloc] init];

    if (signature == (int32_t)0x023f109b)
    {
        result.topicId = [is readInt32];
        result.deleted = true;
        return result;
    }

    int32_t flags = [is readInt32];
    result.flags = flags;
    result.topicId = [is readInt32];
    result.date = [is readInt32];

    if (signature == (int32_t)0xfcdad815)
    {
        CodexReadObject(is, environment, error);
        if (error != nil && *error != nil)
            return nil;
    }

    result.title = [is readString];
    result.iconColor = [is readInt32];
    if (flags & (1 << 0))
        result.iconEmojiId = [is readInt64];

    result.topMessage = [is readInt32];
    result.readInboxMaxId = [is readInt32];
    result.readOutboxMaxId = [is readInt32];
    result.unreadCount = [is readInt32];
    result.unreadMentionsCount = [is readInt32];
    result.unreadReactionsCount = [is readInt32];
    if (signature == (int32_t)0xfcdad815)
        result.unreadPollVotesCount = [is readInt32];

    CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;

    CodexReadObject(is, environment, error);
    if (error != nil && *error != nil)
        return nil;

    if (flags & (1 << 4))
    {
        CodexReadObject(is, environment, error);
        if (error != nil && *error != nil)
            return nil;
    }

    return result;
}

@end

@interface TLCodexForumTopicsResult : TLmessages_Messages$messages_messagesSlice
@property (nonatomic, strong) NSArray *ios6_forumTopics;
@property (nonatomic) int32_t pts;
@property (nonatomic) bool orderByCreateDate;
@end

@implementation TLCodexForumTopicsResult
@end

@interface TLCodexForumTopicsParser : TLmessages_Messages
@end

@implementation TLCodexForumTopicsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexForumTopicsResult *result = [[TLCodexForumTopicsResult alloc] init];
    int32_t flags = [is readInt32];
    result.orderByCreateDate = (flags & (1 << 0)) != 0;
    result.count = [is readInt32];
    result.ios6_forumTopics = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.messages = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.chats = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.users = CodexReadObjectVector(is, environment, error);
    if (error != nil && *error != nil)
        return nil;
    result.pts = [is readInt32];
    return result;
}

@end

@interface TLCodexModernPrivacyRulesParser : TLaccount_PrivacyRules$account_privacyRules
@end

@implementation TLCodexModernPrivacyRulesParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLaccount_PrivacyRules$account_privacyRules *result = [[TLaccount_PrivacyRules$account_privacyRules alloc] init];
    result.rules = CodexReadObjectVectorWithRole(is, @"privacy.rules", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.chats = CodexReadObjectVectorWithRole(is, @"privacy.chats", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.users = CodexReadObjectVectorWithRole(is, @"privacy.users", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    return result;
}

@end

@interface TLCodexModernChannelMessagesParser : TLmessages_Messages$messages_channelMessages
@end

@implementation TLCodexModernChannelMessagesParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernChannelMessagesParser *result = [[TLCodexModernChannelMessagesParser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.pts = [is readInt32];
    result.count = [is readInt32];
    if (flags & (1 << 2))
        [is readInt32];
    
    result.messages = CodexReadStrictObjectVectorWithRole(is, @"channelMessages.messages", environment, error);
    if (error != nil && *error != nil)
    {
        return nil;
    }
    
    CodexReadStrictObjectVectorWithRole(is, @"channelMessages.topics", environment, error);
    if (error != nil && *error != nil)
    {
        return nil;
    }
    
    result.chats = CodexReadStrictObjectVectorWithRole(is, @"channelMessages.chats", environment, error);
    if (error != nil && *error != nil)
    {
        return nil;
    }
    
    result.users = CodexReadStrictObjectVectorWithRole(is, @"channelMessages.users", environment, error);
    if (error != nil && *error != nil)
    {
        return nil;
    }
    
    return result;
}

@end

@interface TLCodexModernMessageActionParser : TLMessageAction
@end

@implementation TLCodexModernMessageActionParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    switch (signature)
    {
        case (int32_t)0xb6aef7b0:
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x80e11a7f:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            if (flags & (1 << 0))
                [is readInt32];
            if (flags & (1 << 1))
                [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0xbd47cbad:
        {
            TLMessageAction$messageActionChatCreate *result = [[TLMessageAction$messageActionChatCreate alloc] init];
            result.title = [is readString];
            result.users = CodexReadInt64Vector(is);
            return result;
        }
        case (int32_t)0xb5a1ce5a:
        {
            TLMessageAction$messageActionChatEditTitle *result = [[TLMessageAction$messageActionChatEditTitle alloc] init];
            result.title = [is readString];
            return result;
        }
        case (int32_t)0x7fcb13a8:
        {
            TLMessageAction$messageActionChatEditPhoto *result = [[TLMessageAction$messageActionChatEditPhoto alloc] init];
            result.photo = (TLPhoto *)CodexReadObject(is, environment, error);
            return result;
        }
        case (int32_t)0x95e3fbef:
            return [[TLMessageAction$messageActionChatDeletePhoto alloc] init];
        case (int32_t)0x15cefd00:
        {
            TLMessageAction$messageActionChatAddUser *result = [[TLMessageAction$messageActionChatAddUser alloc] init];
            result.users = CodexReadInt64Vector(is);
            return result;
        }
        case (int32_t)0xa43f30cc:
        {
            TLMessageAction$messageActionChatDeleteUser *result = [[TLMessageAction$messageActionChatDeleteUser alloc] init];
            result.user_id = TGModernLegacyIdForModernId([is readInt64]);
            return result;
        }
        case (int32_t)0x31224c3:
        {
            TLMessageAction$messageActionChatJoinedByLink *result = [[TLMessageAction$messageActionChatJoinedByLink alloc] init];
            result.inviter_id = TGModernLegacyIdForModernId([is readInt64]);
            return result;
        }
        case (int32_t)0x95d2ac92:
        {
            TLMessageAction$messageActionChannelCreate *result = [[TLMessageAction$messageActionChannelCreate alloc] init];
            result.title = [is readString];
            return result;
        }
        case (int32_t)0xe1037f92:
        {
            TLMessageAction$messageActionChatMigrateTo *result = [[TLMessageAction$messageActionChatMigrateTo alloc] init];
            result.channel_id = (int32_t)[is readInt64];
            return result;
        }
        case (int32_t)0xea3948e9:
        {
            TLMessageAction$messageActionChannelMigrateFrom *result = [[TLMessageAction$messageActionChannelMigrateFrom alloc] init];
            result.title = [is readString];
            result.chat_id = (int32_t)[is readInt64];
            return result;
        }
        case (int32_t)0x94bd38ed:
            return [[TLMessageAction$messageActionPinMessage alloc] init];
        case (int32_t)0x9fbab604:
            return [[TLMessageAction$messageActionHistoryClear alloc] init];
        case (int32_t)0x92a72876:
        {
            TLMessageAction$messageActionGameScore *result = [[TLMessageAction$messageActionGameScore alloc] init];
            result.game_id = [is readInt64];
            result.score = [is readInt32];
            return result;
        }
        case (int32_t)0x3c134d7b:
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            if (flags & (1 << 0))
                [is readInt64];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0xcc02aa6d:
            [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x0d999256:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt32];
            if (flags & (1 << 0))
                [is readInt64];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0x8f31b327:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt64];
            [is readBytes];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 1))
                [is readString];
            CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0x96163f56:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt64];
            if (flags & (1 << 0))
                [is readString];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0x4792929b:
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xfae69f56:
            [is readString];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xc516d679:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                [is readString];
            if (flags & (1 << 2))
                CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0x1b287353:
            CodexReadObjectVector(is, environment, error);
            CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xd95c6154:
            CodexReadObjectVector(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x98e0d697:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x7a0d7f42:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 0))
                [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0x502f92f7:
            CodexReadObject(is, environment, error);
            CodexReadInt64Vector(is);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xb3a07661:
            CodexReadObject(is, environment, error);
            [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xaa786345:
            [is readString];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x47dd8079:
            [is readString];
            [is readString];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xb4c38cb5:
            [is readString];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xc83d6aec:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt64];
            [is readInt32];
            if (flags & (1 << 0))
            {
                [is readString];
                [is readInt64];
            }
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0xc0944820:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                [is readString];
            if (flags & (1 << 1))
                [is readInt64];
            if (flags & (1 << 2))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 3))
                CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0x57de635e:
            CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x31518e9b:
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x5060a3f4:
        {
            [is readInt32];
            CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0x678c2e09:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            [is readInt32];
            [is readString];
            if (flags & (1 << 2))
            {
                [is readString];
                [is readInt64];
            }
            if (flags & (1 << 3))
            {
                [is readString];
                [is readInt64];
            }
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0x332ba9ed:
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x2a9fadc5:
            [is readInt32];
            [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x93b31848:
            [is readInt32];
            CodexReadObjectVector(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x41b3e202:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            [is readString];
            [is readInt64];
            if (flags & (1 << 0))
                [is readBytes];
            CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0x45d5b021:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt64];
            [is readInt64];
            if (flags & (1 << 0))
            {
                [is readString];
                [is readInt64];
            }
            if (flags & (1 << 1))
                [is readString];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0xffa00ccc:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt64];
            [is readBytes];
            if (flags & (1 << 0))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 1))
                [is readString];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 4))
                [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0xc624b16e:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt64];
            if (flags & (1 << 0))
                [is readString];
            if (flags & (1 << 4))
                [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0xb91bbd3a:
            CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x48e91302:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt64];
            [is readInt32];
            if (flags & (1 << 0))
            {
                [is readString];
                [is readInt64];
            }
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0x31c48347:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            [is readInt32];
            [is readString];
            if (flags & (1 << 2))
            {
                [is readString];
                [is readInt64];
            }
            if (flags & (1 << 3))
            {
                [is readString];
                [is readInt64];
            }
            if (flags & (1 << 4))
                CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0xa80f51e4:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0))
                [is readInt64];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0x87e2f155:
            [is readInt32];
            [is readInt32];
            [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xb00c47a2:
            [is readInt32];
            [is readInt64];
            [is readString];
            CodexReadObject(is, environment, error);
            [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xea2c31d3:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 1))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 4))
                [is readInt64];
            if (flags & (1 << 5))
                [is readInt32];
            if (flags & (1 << 8))
                [is readInt64];
            if (flags & (1 << 11))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 12))
            {
                CodexReadObject(is, environment, error);
                [is readInt64];
            }
            if (flags & (1 << 14))
                [is readString];
            if (flags & (1 << 15))
                [is readInt32];
            if (flags & (1 << 18))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 19))
                [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0xe6c31522:
        {
            int32_t flags = [is readInt32];
            CodexReadObject(is, environment, error);
            if (flags & (1 << 3))
                [is readInt32];
            if (flags & (1 << 4))
                [is readInt64];
            if (flags & (1 << 6))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 7))
            {
                CodexReadObject(is, environment, error);
                [is readInt64];
            }
            if (flags & (1 << 8))
                CodexReadObject(is, environment, error);
            if (flags & (1 << 9))
                [is readInt32];
            if (flags & (1 << 10))
                [is readInt32];
            if (flags & (1 << 12))
                [is readInt64];
            if (flags & (1 << 15))
                [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0xac1f1fcd:
            [is readInt32];
            [is readInt64];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x84b88578:
            [is readInt32];
            [is readInt64];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x2ffe2f7a:
        {
            int32_t flags = [is readInt32];
            [is readInt64];
            if (flags & (1 << 2))
                [is readInt32];
            if (flags & (1 << 3))
                CodexReadObjectVector(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0xcc7c5c89:
            CodexReadInt32Vector(is);
            CodexReadInt32Vector(is);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xc7edbc83:
            CodexReadObjectVector(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xee7a1596:
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 2))
                [is readString];
            if (flags & (1 << 3))
                [is readInt32];
            if (flags & (1 << 4))
                CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0x95ddcf69:
            CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x69f916f8:
            [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xa8a3c699:
        {
            int32_t flags = [is readInt32];
            [is readString];
            [is readInt64];
            [is readString];
            [is readInt64];
            if (flags & (1 << 0))
                [is readString];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        }
        case (int32_t)0x2c8f2a25:
            CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x774278d4:
            [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            [is readInt32];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x73ada76b:
            [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xb07ed085:
        case (int32_t)0xe188503b:
            [is readInt64];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xbf7d6572:
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x3e2793ba:
            [is readInt32];
            CodexReadObject(is, environment, error);
            CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x9da1cd6c:
        case (int32_t)0x399674dc:
            CodexReadObject(is, environment, error);
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0x16605e3e:
            [is readInt64];
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xf3f25f76:
        case (int32_t)0xd7c0ff9c:
            return [[TLMessageAction$messageActionEmpty alloc] init];
        case (int32_t)0xebbca3cb:
        {
            TLMessageAction$messageActionChatJoinedByLink *result = [[TLMessageAction$messageActionChatJoinedByLink alloc] init];
            result.inviter_id = -2147483647 - 1;
            return result;
        }
        default:
            return [[TLMessageAction$messageActionEmpty alloc] init];
    }
}

@end

@interface TLCodexModernDocumentParser : TLDocument$document
@end

@implementation TLCodexModernDocumentParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexModernDocumentParser *result = [[TLCodexModernDocumentParser alloc] init];
    int32_t flags = [is readInt32];
    result.n_id = [is readInt64];
    result.access_hash = [is readInt64];
    result.file_reference = [is readBytes];
    result.date = [is readInt32];
    result.mime_type = [is readString];
    result.size = (int32_t)[is readInt64];
    
    if (flags & (1 << 0))
    {
        NSArray *thumbs = CodexReadObjectVector(is, environment, error);
        if (error != nil && *error != nil)
            return nil;

        TLPhotoSize *bestThumbnail = nil;
        int64_t bestThumbnailArea = -1;
        for (id thumbnail in thumbs)
        {
            if ([thumbnail isKindOfClass:[TLPhotoSize$photoCachedSize class]])
            {
                TLPhotoSize$photoCachedSize *cachedSize = (TLPhotoSize$photoCachedSize *)thumbnail;
                int64_t area = (int64_t)cachedSize.w * (int64_t)cachedSize.h;
                if (cachedSize.bytes.length != 0 && cachedSize.w > 0 && cachedSize.h > 0 && area > bestThumbnailArea)
                {
                    bestThumbnail = cachedSize;
                    bestThumbnailArea = area;
                }
            }
        }

        if (bestThumbnail == nil)
        {
            for (id thumbnail in thumbs)
            {
                if ([thumbnail isKindOfClass:[TLPhotoSize$photoSize class]])
                {
                    TLPhotoSize$photoSize *photoSize = (TLPhotoSize$photoSize *)thumbnail;
                    int64_t area = (int64_t)photoSize.w * (int64_t)photoSize.h;
                    if (photoSize.type.length != 0 && photoSize.w > 0 && photoSize.h > 0 && area > bestThumbnailArea)
                    {
                        bestThumbnail = photoSize;
                        bestThumbnailArea = area;
                    }
                }
            }
        }

        result.thumb = bestThumbnail;
    }
    
    if (flags & (1 << 1))
    {
        NSArray *videoThumbnails = CodexReadObjectVectorOrSingle(is, environment, error);
        if (error != nil && *error != nil)
            return nil;

        if (result.thumb == nil)
        {
            TLPhotoSize *bestVideoThumbnail = nil;
            int64_t bestVideoThumbnailArea = -1;
            for (id thumbnail in videoThumbnails)
            {
                if ([thumbnail isKindOfClass:[TLPhotoSize$photoSize class]])
                {
                    TLPhotoSize$photoSize *photoSize = (TLPhotoSize$photoSize *)thumbnail;
                    int64_t area = (int64_t)photoSize.w * (int64_t)photoSize.h;
                    if (photoSize.type.length != 0 && photoSize.w > 0 && photoSize.h > 0 && area > bestVideoThumbnailArea)
                    {
                        bestVideoThumbnail = photoSize;
                        bestVideoThumbnailArea = area;
                    }
                }
                else if ([thumbnail isKindOfClass:[TLPhotoSize$photoCachedSize class]])
                {
                    TLPhotoSize$photoCachedSize *cachedSize = (TLPhotoSize$photoCachedSize *)thumbnail;
                    int64_t area = (int64_t)cachedSize.w * (int64_t)cachedSize.h;
                    if (cachedSize.bytes.length != 0 && cachedSize.w > 0 && cachedSize.h > 0 && area > bestVideoThumbnailArea)
                    {
                        bestVideoThumbnail = cachedSize;
                        bestVideoThumbnailArea = area;
                    }
                }
            }
            result.thumb = bestVideoThumbnail;
        }
    }
    
    int32_t dcIdOrAttributesMarker = [is readInt32];
    if (dcIdOrAttributesMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
    {
        result.dc_id = 0;
        result.attributes = CodexReadObjectVectorWithMarker(is, dcIdOrAttributesMarker, environment, error);
    }
    else
    {
        result.dc_id = dcIdOrAttributesMarker;
        int32_t attributesMarker = [is readInt32];
        result.attributes = CodexReadObjectVectorOrSingleWithMarker(is, attributesMarker, environment, error);
        if ((error == nil || *error == nil) && attributesMarker == (int32_t)0xd38ff1c2)
        {
            for (int32_t i = 0; i < 3; i++)
            {
                int32_t tailWord = [is readInt32];
                if (CodexSkipBareDocumentAttributeTailWord(is, tailWord))
                {
                    continue;
                }
                else if (CodexLooksLikeStringFirstWord(tailWord))
                {
                    CodexSkipStringWithFirstWord(is, tailWord);
                }
                else if (CodexLooksLikeTinyBareDocumentTailWord(tailWord))
                {
                }
                else
                    break;
            }
        }
    }
    if (error != nil && *error != nil)
        return nil;
    
    return result;
}

@end

@interface TLCodexModernDocumentAttributeVideoParser : TLDocumentAttribute$documentAttributeVideo
@end

@implementation TLCodexModernDocumentAttributeVideoParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLCodexModernDocumentAttributeVideoParser *result = [[TLCodexModernDocumentAttributeVideoParser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.duration = (int32_t)[is readDouble];
    result.w = [is readInt32];
    result.h = [is readInt32];
    if (flags & (1 << 2))
        [is readInt32];
    if (flags & (1 << 4))
        [is readDouble];
    if (flags & (1 << 5))
        [is readString];
    return result;
}

@end

@interface TLCodexModernDocumentAttributeVideoD38Parser : TLDocumentAttribute$documentAttributeVideo
@end

@implementation TLCodexModernDocumentAttributeVideoD38Parser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLCodexModernDocumentAttributeVideoD38Parser *result = [[TLCodexModernDocumentAttributeVideoD38Parser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.duration = (int32_t)[is readDouble];
    result.w = [is readInt32];
    result.h = [is readInt32];
    if (flags & (1 << 2))
        [is readInt32];
    return result;
}

@end

@interface TLCodexModernDocumentAttributeFilenameParser : TLDocumentAttribute$documentAttributeFilename
@end

@implementation TLCodexModernDocumentAttributeFilenameParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLCodexModernDocumentAttributeFilenameParser *result = [[TLCodexModernDocumentAttributeFilenameParser alloc] init];
    result.file_name = [is readString];
    return result;
}

@end

@interface TLCodexModernUserProfilePhotoParser : TLUserProfilePhoto$userProfilePhoto
@end

@implementation TLCodexModernUserProfilePhotoParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLCodexModernUserProfilePhotoParser *result = [[TLCodexModernUserProfilePhotoParser alloc] init];
    int32_t flags = [is readInt32];
    result.photo_id = [is readInt64];
    NSData *strippedThumbnail = nil;
    if (flags & (1 << 1))
        strippedThumbnail = [is readBytes];
    result.dc_id = [is readInt32];
    if (OGPlatformUsesConstrainedBackgroundExecution() && strippedThumbnail.length != 0)
    {
        NSData *decodedThumbnail = CodexDecodedStrippedThumbnail(strippedThumbnail);
        UIImage *thumbnailImage = decodedThumbnail.length == 0 ? nil : [[UIImage alloc] initWithData:decodedThumbnail];
        if (thumbnailImage != nil)
            objc_setAssociatedObject(result, NSSelectorFromString(@"onegramStrippedAvatar"), thumbnailImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    return result;
}

@end

@interface TLCodexModernChatPhotoParser : TLChatPhoto$chatPhoto
@end

@implementation TLCodexModernChatPhotoParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLChatPhoto$chatPhoto *result = [[TLChatPhoto$chatPhoto alloc] init];
    if (signature == (int32_t)0x1c6e1c11)
    {
        int32_t flags = [is readInt32];
        result.photo_id = [is readInt64];
        NSData *strippedThumbnail = nil;
        if (flags & (1 << 1))
            strippedThumbnail = [is readBytes];
        result.dc_id = [is readInt32];
        if (OGPlatformUsesConstrainedBackgroundExecution() && strippedThumbnail.length != 0)
        {
            NSData *decodedThumbnail = CodexDecodedStrippedThumbnail(strippedThumbnail);
            UIImage *thumbnailImage = decodedThumbnail.length == 0 ? nil : [[UIImage alloc] initWithData:decodedThumbnail];
            if (thumbnailImage != nil)
                objc_setAssociatedObject(result, NSSelectorFromString(@"onegramStrippedAvatar"), thumbnailImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

    }
    return result;
}

@end

@interface TLCodexModernChatParser : TLChat$chat
@end

@implementation TLCodexModernChatParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLChat$chat *result = [[TLChat$chat alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.creator = (flags & (1 << 0));
    result.left = (flags & (1 << 2));
    result.deactivated = (flags & (1 << 5));
    int64_t chatId = [is readInt64];
    result.n_id = (int32_t)chatId;
    objc_setAssociatedObject(result, NSSelectorFromString(@"tg_ios6_apiChatId"), [NSNumber numberWithLongLong:chatId], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    result.title = [is readString];
    result.photo = (TLChatPhoto *)CodexReadObject(is, environment, error);
    result.participants_count = [is readInt32];
    result.date = [is readInt32];
    result.version = [is readInt32];
    if (flags & (1 << 6))
        result.migrated_to = (TLInputChannel *)CodexReadObject(is, environment, error);
    if (flags & (1 << 14))
        CodexReadObject(is, environment, error);
    if (flags & (1 << 18))
        CodexReadObject(is, environment, error);
    return result;
}

@end

@interface TLCodexModernChatForbiddenParser : TLChat$chatForbidden
@end

@implementation TLCodexModernChatForbiddenParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLChat$chatForbidden *result = [[TLChat$chatForbidden alloc] init];
    int64_t chatId = [is readInt64];
    result.n_id = (int32_t)chatId;
    objc_setAssociatedObject(result, NSSelectorFromString(@"tg_ios6_apiChatId"), [NSNumber numberWithLongLong:chatId], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    result.title = [is readString];
    return result;
}

@end

@interface TLCodexModernChatAdminRightsParser : TLChannelAdminRights$channelAdminRights
@end

@implementation TLCodexModernChatAdminRightsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLChannelAdminRights$channelAdminRights *result = [[TLChannelAdminRights$channelAdminRights alloc] init];
    result.flags = [is readInt32];
    return result;
}

@end

@interface TLCodexModernChannelParser : TLChat$channel
@end

@implementation TLCodexModernChannelParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLChat$channel *result = [[TLChat$channel alloc] init];
    result.name_color_id = -1;
    int32_t flags = [is readInt32];
    int32_t flags2 = [is readInt32];
    result.flags = flags;
    result.flags2 = flags2;
    int64_t channelId = [is readInt64];
    result.n_id = (int32_t)channelId;
    objc_setAssociatedObject(result, NSSelectorFromString(@"tg_ios6_apiChannelId"), [NSNumber numberWithLongLong:channelId], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (flags & (1 << 13))
        result.access_hash = [is readInt64];
    result.title = [is readString];
    if (flags & (1 << 6))
        result.username = [is readString];
    result.photo = (TLChatPhoto *)CodexReadObject(is, environment, error);
    result.date = [is readInt32];
    if (flags & (1 << 9))
        CodexReadObjectVector(is, environment, error);
    if (flags & (1 << 14))
        result.admin_rights = (TLChannelAdminRights *)CodexReadObject(is, environment, error);
    if (flags & (1 << 15))
        result.banned_rights = (TLChannelBannedRights *)CodexReadObject(is, environment, error);
    if (flags & (1 << 18))
        CodexReadObject(is, environment, error);
    if (flags & (1 << 17))
        result.participants_count = [is readInt32];
    if (flags2 & (1 << 0))
        CodexReadObjectVector(is, environment, error);
    if (flags2 & (1 << 4))
    {

        if (signature == (int32_t)0x1c32b11c || signature == (int32_t)0xd49f34c6)
            CodexReadObject(is, environment, error);
        else
            [is readInt32];
    }
    if (flags2 & (1 << 7))
    {
        int32_t colorSignature = [is readInt32];
        if (colorSignature == (int32_t)0xb54b5acf)
        {
            int32_t colorFlags = [is readInt32];
            if (colorFlags & (1 << 0))
                result.name_color_id = [is readInt32];
            if (colorFlags & (1 << 1))
                [is readInt64];
        }
        else
            TLMetaClassStore::constructObject(is, colorSignature, environment, nil, error);
    }
    if (flags2 & (1 << 8))
        CodexReadObject(is, environment, error);
    if (flags2 & (1 << 9))
        CodexReadObject(is, environment, error);
    if (flags2 & (1 << 10))
        [is readInt32];
    if (flags2 & (1 << 11))
        [is readInt32];
    if (flags2 & (1 << 13))
        [is readInt64];
    if (flags2 & (1 << 14))
        [is readInt64];
    if (flags2 & (1 << 18))
        [is readInt64];
    if (signature == (int32_t)0xd49f34c6 && (flags2 & (1 << 20)))
        result.linked_community_id = [is readInt64];
    return result;
}

@end

static NSDictionary *TLCodexReadChatReactionPolicy(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t signature = [is readInt32];
    if (signature == (int32_t)0xeafc32bc)
        return @{ @"mode": @"none", @"emojis": @[] };

    if (signature == (int32_t)0x52928bca)
    {
        [is readInt32];
        return @{ @"mode": @"all", @"emojis": @[] };
    }

    if (signature == (int32_t)0x661d4037)
    {
        int32_t marker = [is readInt32];
        int32_t count = marker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR ? [is readInt32] : 0;
        if (count < 0 || count > 256)
            count = 0;

        NSMutableArray *emojis = [[NSMutableArray alloc] init];
        for (int32_t i = 0; i < count; i++)
        {
            int32_t reactionSignature = [is readInt32];
            if (reactionSignature == (int32_t)0x1b2286b8)
            {
                NSString *emoji = [is readString];
                if (emoji.length != 0 && ![emojis containsObject:emoji])
                    [emojis addObject:emoji];
            }
            else if (reactionSignature == (int32_t)0x8935fc73)
                [is readInt64];
            else if (reactionSignature != (int32_t)0x79f5d419 && reactionSignature != (int32_t)0x523da4eb)
                TLMetaClassStore::constructObject(is, reactionSignature, environment, nil, error);
        }
        return @{ @"mode": @"some", @"emojis": emojis };
    }

    TLMetaClassStore::constructObject(is, signature, environment, nil, error);
    return nil;
}

static void TLCodexStoreChatReactionPolicy(id object, NSDictionary *policy)
{
    if (object != nil && policy != nil)
        objc_setAssociatedObject(object, NSSelectorFromString(@"tg_ios6_availableReactionPolicy"), policy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@interface TLCodexModernChannelFullParser : TLChatFull$chatFull
@end

@implementation TLCodexModernChannelFullParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    int32_t flags = [is readInt32];
    int32_t flags2 = 0;
    bool isModernChannelFull = signature == (int32_t)0xbbab348d || signature == (int32_t)0xa04e8d3a || signature == (int32_t)0xe4e0b29d;
    if (isModernChannelFull)
        flags2 = [is readInt32];

    int64_t channelId = [is readInt64];
    NSString *about = [is readString];

    if (!isModernChannelFull)
    {
        TLCodexModernChannelFullParser *result = [[TLCodexModernChannelFullParser alloc] init];
        result.n_id = (int32_t)channelId;
        objc_setAssociatedObject(result, NSSelectorFromString(@"tg_ios6_apiChannelId"), [NSNumber numberWithLongLong:channelId], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(result, NSSelectorFromString(@"tg_ios6_chatAbout"), about == nil ? @"" : about, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        result.participants = (TLChatParticipants *)CodexReadObject(is, environment, error);
        if (flags & (1 << 2))
            result.chat_photo = (TLPhoto *)CodexReadObject(is, environment, error);
        result.notify_settings = (TLPeerNotifySettings *)CodexReadObject(is, environment, error);
        if (flags & (1 << 13))
            result.exported_invite = (TLExportedChatInvite *)CodexReadObject(is, environment, error);
        if (flags & (1 << 3))
            result.bot_info = CodexReadObjectVector(is, environment, error);
        if (flags & (1 << 6)) [is readInt32];
        if (flags & (1 << 11)) [is readInt32];
        if (flags & (1 << 12)) CodexReadObject(is, environment, error);
        if (flags & (1 << 14)) [is readInt32];
        if (flags & (1 << 15)) CodexReadObject(is, environment, error);
        if (flags & (1 << 16)) [is readString];
        if (flags & (1 << 17)) { [is readInt32]; CodexReadInt64Vector(is); }
        if (flags & (1 << 18)) TLCodexStoreChatReactionPolicy(result, TLCodexReadChatReactionPolicy(is, environment, error));
        if (flags & (1 << 20)) [is readInt32];
        return result;
    }

    TLChatFull$channelFull *result = [[TLChatFull$channelFull alloc] init];
    result.flags = flags;
    result.canViewParticipants = (flags & (1 << 3)) != 0;
    result.can_set_username = (flags & (1 << 6)) != 0;
    result.can_set_stickers = (flags & (1 << 7)) != 0;
    result.n_id = (int32_t)channelId;
    result.about = about;
    objc_setAssociatedObject(result, NSSelectorFromString(@"tg_ios6_apiChannelId"), [NSNumber numberWithLongLong:channelId], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (flags & (1 << 0))
        result.participants_count = [is readInt32];
    if (flags & (1 << 1))
        result.admins_count = [is readInt32];
    if (flags & (1 << 2))
    {
        result.kicked_count = [is readInt32];
        result.banned_count = [is readInt32];
    }
    if (flags & (1 << 13))
        [is readInt32];

    result.read_inbox_max_id = [is readInt32];
    result.read_outbox_max_id = [is readInt32];
    result.unread_count = [is readInt32];
    result.chat_photo = (TLPhoto *)CodexReadObject(is, environment, error);
    result.notify_settings = (TLPeerNotifySettings *)CodexReadObject(is, environment, error);
    if (flags & (1 << 23))
        result.exported_invite = (TLExportedChatInvite *)CodexReadObject(is, environment, error);
    result.bot_info = CodexReadObjectVector(is, environment, error);

    if (flags & (1 << 4))
    {
        result.migrated_from_chat_id = (int32_t)[is readInt64];
        result.migrated_from_max_id = [is readInt32];
    }
    if (flags & (1 << 5))
        result.pinned_msg_id = [is readInt32];
    if (flags & (1 << 8))
        result.stickerset = (TLStickerSet *)CodexReadObject(is, environment, error);
    if (flags & (1 << 9))
        result.available_min_id = [is readInt32];
    if (flags & (1 << 11)) [is readInt32];
    if (flags & (1 << 14)) [is readInt64];
    if (flags & (1 << 15)) CodexReadObject(is, environment, error);
    if (flags & (1 << 17)) [is readInt32];
    if (flags & (1 << 18)) [is readInt32];
    if (flags & (1 << 12)) [is readInt32];
    [is readInt32];
    if (flags & (1 << 21)) CodexReadObject(is, environment, error);
    if (flags & (1 << 24)) [is readInt32];
    if (flags & (1 << 25)) CodexSkipStringVector(is);
    if (flags & (1 << 26)) CodexReadObject(is, environment, error);
    if (flags & (1 << 27)) [is readString];
    if (flags & (1 << 28)) { [is readInt32]; CodexReadInt64Vector(is); }
    if (flags & (1 << 29)) CodexReadObject(is, environment, error);
    if (flags & (1 << 30)) TLCodexStoreChatReactionPolicy(result, TLCodexReadChatReactionPolicy(is, environment, error));
    if (flags2 & (1 << 13)) [is readInt32];
    if (flags2 & (1 << 4)) CodexReadObject(is, environment, error);
    if (flags2 & (1 << 7)) CodexReadObject(is, environment, error);
    if (flags2 & (1 << 8)) [is readInt32];
    if (flags2 & (1 << 9)) [is readInt32];
    if (flags2 & (1 << 10)) CodexReadObject(is, environment, error);
    if (signature != (int32_t)0xbbab348d)
    {
        if (flags2 & (1 << 17)) CodexReadObject(is, environment, error);
        if (flags2 & (1 << 18)) [is readInt32];
        if (flags2 & (1 << 21)) [is readInt64];
        if (flags2 & (1 << 22)) CodexReadObject(is, environment, error);
        if (signature != (int32_t)0xe4e0b29d && (flags2 & (1 << 23))) [is readInt64];
    }
    return result;
}

@end

@interface TLCodexModernChannelForbiddenParser : TLChat$channelForbidden
@end

@implementation TLCodexModernChannelForbiddenParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLChat$channelForbidden *result = [[TLChat$channelForbidden alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    int64_t channelId = [is readInt64];
    result.n_id = (int32_t)channelId;
    objc_setAssociatedObject(result, NSSelectorFromString(@"tg_ios6_apiChannelId"), [NSNumber numberWithLongLong:channelId], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    result.access_hash = [is readInt64];
    result.title = [is readString];
    if (flags & (1 << 16))
        result.until_date = [is readInt32];
    return result;
}

@end

@interface TLCodexModernPeerUserParser : TLPeer$peerUser
@end

@implementation TLCodexModernPeerUserParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLPeer$peerUser *result = [[TLPeer$peerUser alloc] init];
    int64_t userId = [is readInt64];
    result.user_id = TGModernLegacyIdForModernId(userId);
    return result;
}

@end

@interface TLCodexModernPeerChatParser : TLPeer$peerChat
@end

@implementation TLCodexModernPeerChatParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLPeer$peerChat *result = [[TLPeer$peerChat alloc] init];
    int64_t chatId = [is readInt64];
    result.chat_id = (int32_t)chatId;
    return result;
}

@end

@interface TLCodexModernPeerChannelParser : TLPeer$peerChannel
@end

@implementation TLCodexModernPeerChannelParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLPeer$peerChannel *result = [[TLPeer$peerChannel alloc] init];
    int64_t channelId = [is readInt64];
    result.channel_id = (int32_t)channelId;
    return result;
}

@end

static bool CodexReadNotificationSound(NSInputStream *is, NSString *__autoreleasing *legacySound, __autoreleasing NSError **error)
{
    if (legacySound != NULL)
        *legacySound = nil;

    int32_t signature = [is readInt32];
    switch (signature)
    {
        case (int32_t)0x97e8bebe:
            if (legacySound != NULL)
                *legacySound = @"default";
            return true;
        case (int32_t)0x6f0c34df:
            if (legacySound != NULL)
                *legacySound = @"";
            return true;
        case (int32_t)0x830b9ae4:
        {
            [is readString];
            NSString *data = [is readString];
            if (legacySound != NULL)
                *legacySound = data;
            return true;
        }
        case (int32_t)0xff6c8049:
            [is readInt64];
            return true;
        default:
            if (error != NULL)
                *error = [NSError errorWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unknown NotificationSound constructor %08x", signature]}];
            return false;
    }
}

@interface TLCodexModernPeerNotifySettingsParser : TLPeerNotifySettings$peerNotifySettings
@end

@implementation TLCodexModernPeerNotifySettingsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLPeerNotifySettings$peerNotifySettings *result = [[TLPeerNotifySettings$peerNotifySettings alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (flags & (1 << 0))
        result.showPreviews = [is readInt32] == TL_BOOL_TRUE_CONSTRUCTOR;
    if (flags & (1 << 1))
        result.silent = [is readInt32] == TL_BOOL_TRUE_CONSTRUCTOR;
    if (flags & (1 << 2))
        result.mute_until = [is readInt32];
    if (flags & (1 << 3))
    {
        NSString *sound = nil;
        if (!CodexReadNotificationSound(is, &sound, error))
            return nil;
        if (sound != nil)
            result.sound = sound;
        else
            result.flags &= ~(1 << 3);
    }
    if (flags & (1 << 4))
    {
        if (!CodexReadNotificationSound(is, NULL, error))
            return nil;
    }
    if (flags & (1 << 5))
    {
        if (!CodexReadNotificationSound(is, NULL, error))
            return nil;
    }
    if (flags & (1 << 6))
        [is readInt32];
    if (flags & (1 << 7))
        [is readInt32];
    if (flags & (1 << 8))
    {
        if (!CodexReadNotificationSound(is, NULL, error))
            return nil;
    }
    if (flags & (1 << 9))
    {
        if (!CodexReadNotificationSound(is, NULL, error))
            return nil;
    }
    if (flags & (1 << 10))
    {
        if (!CodexReadNotificationSound(is, NULL, error))
            return nil;
    }
    return result;
}

@end

@interface TLCodexUpdateNotifySettingsParser : TLUpdate$updateNotifySettings
@end

@implementation TLCodexUpdateNotifySettingsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdate$updateNotifySettings *result = [[TLUpdate$updateNotifySettings alloc] init];
    result.peer = (TLNotifyPeer *)CodexReadObject(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.notify_settings = (TLPeerNotifySettings *)CodexReadObject(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    return result;
}

@end

@interface TLCodexUpdateGroupCallParser : TLUpdate
@end

@implementation TLCodexUpdateGroupCallParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    int32_t flags = [is readInt32];
    NSError *nestedError = nil;
    if (flags & (1 << 1))
        CodexReadObject(is, environment, &nestedError);
    nestedError = nil;
    CodexReadObject(is, environment, &nestedError);
    if (error != NULL)
        *error = nil;
    return self;
}

@end

@interface TLCodexChatInviteParser : TLChatInvite$chatInvite
@end

@implementation TLCodexChatInviteParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLChatInvite$chatInvite *result = [[TLChatInvite$chatInvite alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.title = [is readString];
    if (flags & (1 << 5))
        [is readString];
    CodexReadObject(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.participants_count = [is readInt32];
    if (flags & (1 << 4))
        result.participants = CodexReadObjectVector(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    [is readInt32];
    return result;
}

@end

@interface TLCodexMessageMediaGiveawayParser : TLMessageMedia$messageMediaUnsupported
@end

@implementation TLCodexMessageMediaGiveawayParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    int32_t flags = [is readInt32];
    if (signature == (int32_t)0xdaad85b0)
    {
        CodexReadInt64Vector(is);
        if (flags & (1 << 1))
            CodexSkipStringVector(is);
        if (flags & (1 << 3))
            [is readString];
        [is readInt32];
        [is readInt32];
        [is readInt32];
    }
    else if (signature == (int32_t)0xc6991068)
    {
        [is readInt64];
        if (flags & (1 << 3))
            [is readInt32];
        [is readInt32];
        [is readInt32];
        [is readInt32];
        CodexReadInt64Vector(is);
        [is readInt32];
        if (flags & (1 << 1))
            [is readString];
        [is readInt32];
    }
    return [[TLMessageMedia$messageMediaUnsupported alloc] init];
}

@end

@interface TLCodexFolderPeerParser : TLCodexFolderPeer
@end

static NSString *TLCodexReadReactionSummary(NSInputStream *is, id<TLSerializationEnvironment> environment, NSString **chosenReaction, __autoreleasing NSError **error)
{
    if (chosenReaction != NULL)
        *chosenReaction = nil;
    int32_t reactionsSignature = [is readInt32];
    if (reactionsSignature != (int32_t)0x0a339f0b && reactionsSignature != (int32_t)0x4f2b9479)
    {
        TLMetaClassStore::constructObject(is, reactionsSignature, environment, nil, error);
        return @"";
    }

    int32_t flags = [is readInt32];
    int32_t vectorMarker = [is readInt32];
    int32_t count = vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR ? [is readInt32] : vectorMarker;
    if (count < 0 || count > 10000)
        count = 0;

    NSMutableArray *parts = [[NSMutableArray alloc] init];
    for (int32_t i = 0; i < count; i++)
    {
        int32_t countSignature = [is readInt32];
        if (countSignature != (int32_t)0xa3d1cb80)
        {
            TLMetaClassStore::constructObject(is, countSignature, environment, nil, error);
            continue;
        }

        int32_t countFlags = [is readInt32];
        bool chosen = (countFlags & (1 << 0)) != 0;
        if (chosen)
            [is readInt32];

        int32_t reactionSignature = [is readInt32];
        NSString *reaction = nil;
        if (reactionSignature == (int32_t)0x1b2286b8)
            reaction = [is readString];
        else if (reactionSignature == (int32_t)0x8935fc73)
        {
            [is readInt64];
            reaction = @"◆";
        }
        else if (reactionSignature == (int32_t)0x523da4eb)
            reaction = @"★";
        else if (reactionSignature != (int32_t)0x79f5d419)
            TLMetaClassStore::constructObject(is, reactionSignature, environment, nil, error);

        int32_t reactionCount = [is readInt32];
        if (chosen && reaction.length != 0 && chosenReaction != NULL)
            *chosenReaction = reaction;
        if (reaction.length != 0 && reactionCount > 0 && parts.count < 3)
            [parts addObject:[NSString stringWithFormat:@"%@ %d", reaction, reactionCount]];
    }

    if (flags & (1 << 1))
        CodexReadObjectVector(is, environment, error);
    if (reactionsSignature != (int32_t)0x4f2b9479 && (flags & (1 << 4)))
        CodexReadObjectVector(is, environment, error);

    return [parts componentsJoinedByString:@"  "];
}

@interface TLCodexUpdateMessageReactionsParser : TLUpdate$updateMessageReactionsCodex
@end

@implementation TLCodexUpdateMessageReactionsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    int32_t flags = [is readInt32];
    TLUpdate$updateMessageReactionsCodex *result = [[TLUpdate$updateMessageReactionsCodex alloc] init];
    result.peer = (TLPeer *)CodexReadObject(is, environment, error);
    result.msg_id = [is readInt32];
    if (flags & (1 << 0))
        [is readInt32];
    if (signature == (int32_t)0x1e297bfa && (flags & (1 << 1)))
        CodexReadObject(is, environment, error);
    NSString *chosenReaction = nil;
    result.reactionSummary = TLCodexReadReactionSummary(is, environment, &chosenReaction, error);
    result.chosenReaction = chosenReaction;
    IOS6FeatureProbe(@"REACTION update.parse mid=%d peerClass=%@ flags=0x%08x summary=%@ error=%@", result.msg_id, NSStringFromClass([result.peer class]), flags, result.reactionSummary, error != NULL ? *error : nil);
    return result;
}

@end

@implementation TLCodexFolderPeerParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexFolderPeer *result = [[TLCodexFolderPeer alloc] init];
    result.peer = (TLPeer *)CodexReadObject(is, environment, error);
    result.folder_id = [is readInt32];
    return result;
}

@end

@interface TLCodexUpdateFolderPeersParser : TLUpdate$updateFolderPeers
@end

@implementation TLCodexUpdateFolderPeersParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdate$updateFolderPeers *result = [[TLUpdate$updateFolderPeers alloc] init];
    result.folder_peers = CodexReadObjectVector(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.pts = [is readInt32];
    result.pts_count = [is readInt32];
    return result;
}

@end

@interface TLCodexModernDialogParser : TLDialog$dialog
@end

@implementation TLCodexModernDialogParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLDialog$dialog *result = [[TLDialog$dialog alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.peer = (TLPeer *)CodexReadObject(is, environment, error);
    result.top_message = [is readInt32];
    result.read_inbox_max_id = [is readInt32];
    result.read_outbox_max_id = [is readInt32];
    result.unread_count = [is readInt32];
    result.unread_mentions_count = [is readInt32];
    if (signature != (int32_t)0xe4def5db)
        [is readInt32];
    if (signature == (int32_t)0x69274bc6 || signature == (int32_t)0xfc89f7f3)
        [is readInt32];
    result.notify_settings = (TLPeerNotifySettings *)CodexReadObject(is, environment, error);
    if (flags & (1 << 0))
        result.pts = [is readInt32];
    if (flags & (1 << 1))
        result.draft = (TLDraftMessage *)CodexReadObject(is, environment, error);
    if (flags & (1 << 4))
        result.folder_id = [is readInt32];
    if (flags & (1 << 5))
        [is readInt32];
    return result;
}

@end

@interface TLCodexDialogFolderParser : TLDialog$dialog
@end

@implementation TLCodexDialogFolderParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLDialog$dialog *result = [[TLDialog$dialog alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    
    int32_t folderSignature = [is readInt32];
    if (folderSignature == (int32_t)0xff544e65)
    {
        int32_t folderFlags = [is readInt32];
        [is readInt32];
        [is readString];
        if (folderFlags & (1 << 3))
            CodexReadObject(is, environment, error);
    }
    else
    {
        TLMetaClassStore::constructObject(is, folderSignature, environment, nil, error);
    }
    
    result.peer = (TLPeer *)CodexReadObject(is, environment, error);
    result.top_message = [is readInt32];
    [is readInt32];
    [is readInt32];
    [is readInt32];
    [is readInt32];
    return nil;
}

@end

@interface TLCodexModernImportedContactParser : TLImportedContact$importedContact
@end

@implementation TLCodexModernImportedContactParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLImportedContact$importedContact *result = [[TLImportedContact$importedContact alloc] init];
    int64_t userId = [is readInt64];
    result.user_id = TGModernLegacyIdForModernId(userId);
    result.client_id = [is readInt64];
    return result;
}

@end

@interface TLCodexUserStatusEmptyParser : TLUserStatus$userStatusEmpty
@end

@implementation TLCodexUserStatusEmptyParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    return [[TLUserStatus$userStatusEmpty alloc] init];
}

@end

@interface TLCodexUserStatusOnlineParser : TLUserStatus$userStatusOnline
@end

@implementation TLCodexUserStatusOnlineParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLUserStatus$userStatusOnline *result = [[TLUserStatus$userStatusOnline alloc] init];
    result.expires = [is readInt32];
    return result;
}

@end

@interface TLCodexUserStatusOfflineParser : TLUserStatus$userStatusOffline
@end

@implementation TLCodexUserStatusOfflineParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLUserStatus$userStatusOffline *result = [[TLUserStatus$userStatusOffline alloc] init];
    result.was_online = [is readInt32];
    return result;
}

@end

@interface TLCodexUserStatusNoPayloadParser : TLUserStatus$userStatusRecently
@end

@implementation TLCodexUserStatusNoPayloadParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    switch (signature)
    {
        case 0x7b197dc8:
        case 0x541a1d1a:
        case 0x65899777:
        {
            [is readInt32];
            return [[TLUserStatus$userStatusRecently alloc] init];
        }
        default:
            return [[TLUserStatus$userStatusRecently alloc] init];
    }
}

@end

@interface TLCodexModernContactStatusParser : TLContactStatus$contactStatus
@end

@implementation TLCodexModernContactStatusParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLContactStatus$contactStatus *result = [[TLContactStatus$contactStatus alloc] init];
    int64_t userId = [is readInt64];
    int32_t statusSignature = [is readInt32];
    result.user_id = TGModernLegacyIdForModernId(userId);
    result.status = (TLUserStatus *)TLMetaClassStore::constructObject(is, statusSignature, environment, nil, error);
    return result;
}

@end

@interface TLCodexModernKeyboardButtonStyleParser : NSObject <TLObject>
@end

@implementation TLCodexModernKeyboardButtonStyleParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    int32_t flags = [is readInt32];
    if (flags & (1 << 3))
        [is readInt64];
    return self;
}

@end

@interface TLCodexModernReplyMarkupParser : TLReplyMarkup
@end

@implementation TLCodexModernReplyMarkupParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0xa03e5b85)
    {
        TLReplyMarkup$replyKeyboardHide *result = [[TLReplyMarkup$replyKeyboardHide alloc] init];
        result.flags = [is readInt32];
        return result;
    }
    else if (signature == (int32_t)0x86b40b08 || signature == (int32_t)0xf4108aa0)
    {
        TLReplyMarkup$replyKeyboardForceReply *result = [[TLReplyMarkup$replyKeyboardForceReply alloc] init];
        int32_t flags = [is readInt32];
        result.flags = flags;
        if (flags & (1 << 3))
            [is readString];
        return result;
    }
    else if (signature == (int32_t)0x85dd99d1 || signature == (int32_t)0x3502758c)
    {
        TLReplyMarkup$replyKeyboardMarkup *result = [[TLReplyMarkup$replyKeyboardMarkup alloc] init];
        int32_t flags = [is readInt32];
        result.flags = flags;
        result.rows = CodexReadObjectVector(is, environment, error);
        if (flags & (1 << 3))
            [is readString];
        return result;
    }
    else if (signature == (int32_t)0x48a30254)
    {
        TLReplyMarkup$replyInlineMarkup *result = [[TLReplyMarkup$replyInlineMarkup alloc] init];
        result.rows = CodexReadObjectVector(is, environment, error);
        return result;
    }
    
    return nil;
}

@end

@interface TLCodexModernKeyboardButtonRowParser : TLKeyboardButtonRow
@end

@implementation TLCodexModernKeyboardButtonRowParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLKeyboardButtonRow$keyboardButtonRow *result = [[TLKeyboardButtonRow$keyboardButtonRow alloc] init];
    result.buttons = CodexReadObjectVector(is, environment, error);
    return result;
}

@end

@interface TLCodexModernKeyboardButtonParser : TLKeyboardButton
@end

@implementation TLCodexModernKeyboardButtonParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    int32_t flags = 0;
    bool hasFlags = signature == (int32_t)0x35bbdb6b || signature == (int32_t)0x0568a748 || signature == (int32_t)0x93b9fbb5 || signature == (int32_t)0x10b78d29 || signature == (int32_t)0xd02e7fd4 || signature == (int32_t)0xbbc7515d || signature == (int32_t)0xc9662d05 || signature == (int32_t)0x7d170cff || signature == (int32_t)0xd80c25ec || signature == (int32_t)0xe62bc960 || signature == (int32_t)0x417efd8f || signature == (int32_t)0xaa40f94d || signature == (int32_t)0x991399fc || signature == (int32_t)0x89c590f9 || signature == (int32_t)0x3fa53905 || signature == (int32_t)0xf51006f9 || signature == (int32_t)0x68013e72 || signature == (int32_t)0x7a11d782 || signature == (int32_t)0x7d5e07c7 || signature == (int32_t)0xc0fd5d09 || signature == (int32_t)0xe846b1a0 || signature == (int32_t)0xe15c4370 || signature == (int32_t)0x5b0f15f5 || signature == (int32_t)0x02b78156 || signature == (int32_t)0xbcc4af10;
    bool hasButtonStyle = signature == (int32_t)0x7d170cff || signature == (int32_t)0xd80c25ec || signature == (int32_t)0xe62bc960 || signature == (int32_t)0x417efd8f || signature == (int32_t)0xaa40f94d || signature == (int32_t)0x991399fc || signature == (int32_t)0x89c590f9 || signature == (int32_t)0x3fa53905 || signature == (int32_t)0xf51006f9 || signature == (int32_t)0x68013e72 || signature == (int32_t)0x7a11d782 || signature == (int32_t)0x7d5e07c7 || signature == (int32_t)0xc0fd5d09 || signature == (int32_t)0xe846b1a0 || signature == (int32_t)0xe15c4370 || signature == (int32_t)0x5b0f15f5 || signature == (int32_t)0x02b78156 || signature == (int32_t)0xbcc4af10;
    if (hasFlags)
    {
        flags = [is readInt32];
        if (hasButtonStyle && (flags & (1 << 10)))
            CodexReadObject(is, environment, error);
    }
    
    if ((signature == (int32_t)0xbbc7515d || signature == (int32_t)0x7a11d782) && (flags & (1 << 0)))
        CodexReadObject(is, environment, error);
    NSString *text = [is readString];
    TLKeyboardButton *result = nil;
    
    if (signature == (int32_t)0x258aff05 || signature == (int32_t)0xd80c25ec || signature == (int32_t)0x13767230 || signature == (int32_t)0xa0c0505c || signature == (int32_t)0xe846b1a0 || signature == (int32_t)0xe15c4370)
    {
        TLKeyboardButton$keyboardButtonUrl *button = [[TLKeyboardButton$keyboardButtonUrl alloc] init];
        button.text = text;
        button.url = [is readString];
        result = button;
    }
    else if (signature == (int32_t)0x683a5e46 || signature == (int32_t)0x35bbdb6b || signature == (int32_t)0xe62bc960)
    {
        TLKeyboardButton$keyboardButtonCallback *button = [[TLKeyboardButton$keyboardButtonCallback alloc] init];
        button.text = text;
        button.data = [is readBytes];
        result = button;
    }
    else if (signature == (int32_t)0xb16a6c29 || signature == (int32_t)0x417efd8f)
    {
        TLKeyboardButton$keyboardButtonRequestPhone *button = [[TLKeyboardButton$keyboardButtonRequestPhone alloc] init];
        button.text = text;
        result = button;
    }
    else if (signature == (int32_t)0xfc796b3f || signature == (int32_t)0xaa40f94d)
    {
        TLKeyboardButton$keyboardButtonRequestGeoLocation *button = [[TLKeyboardButton$keyboardButtonRequestGeoLocation alloc] init];
        button.text = text;
        result = button;
    }
    else if (signature == (int32_t)0x0568a748 || signature == (int32_t)0x93b9fbb5 || signature == (int32_t)0x991399fc)
    {
        TLKeyboardButton$keyboardButtonSwitchInline *button = [[TLKeyboardButton$keyboardButtonSwitchInline alloc] init];
        button.flags = flags;
        button.text = text;
        button.query = [is readString];
        if ((flags & (1 << 1)) && (signature == (int32_t)0x93b9fbb5 || signature == (int32_t)0x991399fc))
            CodexReadObjectVector(is, environment, error);
        result = button;
    }
    else if (signature == (int32_t)0x50f41ccf || signature == (int32_t)0x89c590f9)
    {
        TLKeyboardButton$keyboardButtonGame *button = [[TLKeyboardButton$keyboardButtonGame alloc] init];
        button.text = text;
        result = button;
    }
    else if (signature == (int32_t)0xafd93fbb || signature == (int32_t)0x3fa53905)
    {
        TLKeyboardButton$keyboardButtonBuy *button = [[TLKeyboardButton$keyboardButtonBuy alloc] init];
        button.text = text;
        result = button;
    }
    else if (signature == (int32_t)0x10b78d29 || signature == (int32_t)0xd02e7fd4 || signature == (int32_t)0xf51006f9 || signature == (int32_t)0x68013e72)
    {
        bool isOutputUrlAuth = signature == (int32_t)0x10b78d29 || signature == (int32_t)0xf51006f9;
        if ((isOutputUrlAuth && (flags & (1 << 0))) || (!isOutputUrlAuth && (flags & (1 << 1))))
            [is readString];
        TLKeyboardButton$keyboardButtonUrl *button = [[TLKeyboardButton$keyboardButtonUrl alloc] init];
        button.text = text;
        button.url = [is readString];
        if (isOutputUrlAuth)
            [is readInt32];
        else
            CodexReadObject(is, environment, error);
        result = button;
    }
    else if (signature == (int32_t)0xbbc7515d || signature == (int32_t)0x7a11d782)
    {
    }
    else if (signature == (int32_t)0xe988037b || signature == (int32_t)0x7d5e07c7)
    {
        CodexReadObject(is, environment, error);
    }
    else if (signature == (int32_t)0x308660c1 || signature == (int32_t)0xc0fd5d09)
    {
        [is readInt64];
    }
    else if (signature == (int32_t)0x53d7bfd8 || signature == (int32_t)0xc9662d05 || signature == (int32_t)0x5b0f15f5 || signature == (int32_t)0x02b78156)
    {
        [is readInt32];
        CodexReadObject(is, environment, error);
        [is readInt32];
    }
    else if (signature == (int32_t)0x75d2698e || signature == (int32_t)0xbcc4af10)
    {
        [is readString];
    }
    
    if (result == nil)
    {
        TLKeyboardButton$keyboardButton *button = [[TLKeyboardButton$keyboardButton alloc] init];
        button.text = text;
        result = button;
    }
    
    return result;
}

@end

@interface TLCodexModernUpdateUserParser : TLUpdate
{
    int64_t _userId;
}
@property (nonatomic) int64_t userId;
@end

@implementation TLCodexModernUpdateUserParser

@synthesize userId = _userId;

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLCodexModernUpdateUserParser *result = [[TLCodexModernUpdateUserParser alloc] init];
    result.userId = [is readInt64];
    return result;
}

@end

@interface TLCodexModernUpdateUserStatusParser : TLUpdate$updateUserStatus
@end

@implementation TLCodexModernUpdateUserStatusParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdate$updateUserStatus *result = [[TLUpdate$updateUserStatus alloc] init];
    int64_t userId = [is readInt64];
    int32_t statusSignature = [is readInt32];
    result.user_id = TGModernLegacyIdForModernId(userId);
    result.status = (TLUserStatus *)TLMetaClassStore::constructObject(is, statusSignature, environment, nil, error);
    return result;
}

@end

@interface TLCodexModernUpdateDeleteChannelMessagesParser : TLUpdate$updateDeleteChannelMessages
@end

@implementation TLCodexModernUpdateDeleteChannelMessagesParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLUpdate$updateDeleteChannelMessages *result = [[TLUpdate$updateDeleteChannelMessages alloc] init];
    int64_t channelId = [is readInt64];
    result.channel_id = (int32_t)channelId;
    result.messages = CodexReadInt32Vector(is);
    result.pts = [is readInt32];
    result.pts_count = [is readInt32];
    return result;
}

@end

@interface TLCodexModernUpdateChannelTooLongParser : TLUpdate$updateChannelTooLong
@end

@implementation TLCodexModernUpdateChannelTooLongParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLUpdate$updateChannelTooLong *result = [[TLUpdate$updateChannelTooLong alloc] init];
    int32_t flags = [is readInt32];
    int64_t channelId = [is readInt64];
    result.flags = flags;
    result.channel_id = (int32_t)channelId;
    if (flags & 1)
        result.pts = [is readInt32];
    return result;
}

@end

@interface TLCodexModernUpdateShortMessageParser : TLUpdates$modernUpdateShortMessage
@end

@implementation TLCodexModernUpdateShortMessageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdates$modernUpdateShortMessage *result = [[TLUpdates$modernUpdateShortMessage alloc] init];
    result.flags = [is readInt32];
    result.n_id = [is readInt32];
    result.user_id = TGModernLegacyIdForModernId([is readInt64]);
    result.message = [is readString];
    result.pts = [is readInt32];
    result.pts_count = [is readInt32];
    result.date = [is readInt32];
    if (result.flags & (1 << 2))
        result.fwd_header = (TLMessageFwdHeader *)CodexReadObject(is, environment, error);
    if (result.flags & (1 << 11))
        result.via_bot_id = TGModernLegacyIdForModernId([is readInt64]);
    if (result.flags & (1 << 3))
        result.reply_to_msg_id = CodexReadReplyHeaderCompat(is, environment, error);
    if (result.flags & (1 << 7))
        result.entities = CodexReadObjectVector(is, environment, error);
    if (result.flags & (1 << 25))
        [is readInt32];
    return result;
}

@end

@interface TLCodexModernUpdateShortChatMessageParser : TLUpdates$modernUpdateShortChatMessage
@end

@implementation TLCodexModernUpdateShortChatMessageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdates$modernUpdateShortChatMessage *result = [[TLUpdates$modernUpdateShortChatMessage alloc] init];
    result.flags = [is readInt32];
    result.n_id = [is readInt32];
    result.from_id = TGModernLegacyIdForModernId([is readInt64]);
    result.chat_id = (int32_t)[is readInt64];
    result.message = [is readString];
    result.pts = [is readInt32];
    result.pts_count = [is readInt32];
    result.date = [is readInt32];
    if (result.flags & (1 << 2))
        result.fwd_header = (TLMessageFwdHeader *)CodexReadObject(is, environment, error);
    if (result.flags & (1 << 11))
        result.via_bot_id = TGModernLegacyIdForModernId([is readInt64]);
    if (result.flags & (1 << 3))
        result.reply_to_msg_id = CodexReadReplyHeaderCompat(is, environment, error);
    if (result.flags & (1 << 7))
        result.entities = CodexReadObjectVector(is, environment, error);
    if (result.flags & (1 << 25))
        [is readInt32];
    return result;
}

@end

@interface TLCodexModernUpdateShortSentMessageParser : TLUpdates$updateShortSentMessage
@end

@implementation TLCodexModernUpdateShortSentMessageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdates$updateShortSentMessage *result = [[TLUpdates$updateShortSentMessage alloc] init];
    result.flags = [is readInt32];
    result.n_id = [is readInt32];
    result.pts = [is readInt32];
    result.pts_count = [is readInt32];
    result.date = [is readInt32];
    if (result.flags & (1 << 9))
        result.media = (TLMessageMedia *)CodexReadObject(is, environment, error);
    if (result.flags & (1 << 7))
        result.entities = CodexReadObjectVector(is, environment, error);
    if (result.flags & (1 << 25))
        [is readInt32];
    return result;
}

@end

@interface TLCodexDialogFilterItem : NSObject <TLObject>
@property (nonatomic) int32_t flags;
@property (nonatomic) int32_t filterId;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *emoticon;
@property (nonatomic) int32_t color;
@property (nonatomic, strong) NSArray *pinnedPeers;
@property (nonatomic, strong) NSArray *includePeers;
@property (nonatomic, strong) NSArray *excludePeers;
@property (nonatomic) bool defaultFilter;
@property (nonatomic) bool chatlist;
@end

@implementation TLCodexDialogFilterItem
- (int32_t)TLconstructorSignature { return 0; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

static NSString *CodexReadDialogFilterTitle(NSInputStream *is, bool textWithEntities, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    if (!textWithEntities)
        return [is readString];

    int32_t signature = [is readInt32];
    if (signature != (int32_t)0x751f3146)
    {
        if (error != NULL)
        {
            NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
            userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:@"Unexpected folder title constructor 0x%08x", signature];
            *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:userInfo];
        }
        return @"";
    }

    NSString *text = [is readString];
    CodexReadObjectVector(is, environment, error);
    return text == nil ? @"" : text;
}

@interface TLCodexDialogFilterParser : NSObject <TLObject>
@end

@implementation TLCodexDialogFilterParser
- (int32_t)TLconstructorSignature { return 0; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexDialogFilterItem *result = [[TLCodexDialogFilterItem alloc] init];

    if (signature == (int32_t)0x363293ae)
    {
        result.defaultFilter = true;
        result.filterId = 0;
        result.title = @"";
        result.pinnedPeers = @[];
        result.includePeers = @[];
        result.excludePeers = @[];
        return result;
    }

    bool modernTitle = signature == (int32_t)0xaa472651 || signature == (int32_t)0x96537bd7;
    bool chatlist = signature == (int32_t)0x9fe28ea4 || signature == (int32_t)0x96537bd7;
    bool layer166 = signature == (int32_t)0x7438f7e8;
    if (!modernTitle && !chatlist && !layer166 && signature != (int32_t)0x5fb5523b)
        return nil;

    result.chatlist = chatlist;
    result.flags = [is readInt32];
    result.filterId = [is readInt32];
    result.title = CodexReadDialogFilterTitle(is, modernTitle, environment, error);
    if (error != NULL && *error != nil)
        return nil;

    if (result.flags & (1 << 25))
        result.emoticon = [is readString];
    if (!layer166 && (result.flags & (1 << 27)))
        result.color = [is readInt32];

    result.pinnedPeers = CodexReadObjectVector(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.includePeers = CodexReadObjectVector(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;

    if (!chatlist)
    {
        result.excludePeers = CodexReadObjectVector(is, environment, error);
        if (error != NULL && *error != nil)
            return nil;
    }
    else
        result.excludePeers = @[];

    return result;
}
@end

@interface TLCodexDialogFiltersResult : NSObject <TLObject>
@property (nonatomic) int32_t flags;
@property (nonatomic, strong) NSArray *filters;
@end

@implementation TLCodexDialogFiltersResult
- (int32_t)TLconstructorSignature { return (int32_t)0x2ad93719; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

@interface TLCodexDialogFiltersParser : NSObject <TLObject>
@end

@implementation TLCodexDialogFiltersParser
- (int32_t)TLconstructorSignature { return (int32_t)0x2ad93719; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLCodexDialogFiltersResult *result = [[TLCodexDialogFiltersResult alloc] init];
    result.flags = [is readInt32];
    result.filters = CodexReadObjectVector(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    return result;
}
@end

@interface TLCodexDialogFilterUpdateParser : TLUpdate
@end

@implementation TLCodexDialogFilterUpdateParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0xa5d72105)
    {
        int32_t vectorMarker = [is readInt32];
        int32_t count = 0;
        if (vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
            count = [is readInt32];
        else if (vectorMarker >= 0 && vectorMarker <= 10000)
            count = vectorMarker;
        else
        {
            if (error != NULL)
                *error = nil;
            return self;
        }
        for (int32_t i = 0; i < count; i++)
            [is readInt32];
    }
    else if (signature == (int32_t)0x26ffde7d)
    {
        int32_t flags = [is readInt32];
        [is readInt32];
        if (flags & (1 << 0))
        {
            CodexReadObject(is, environment, error);
            if (error != NULL && *error != nil)
                return nil;
        }
    }

    OGPlatformDispatchOnMainThread(^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TGIOS6DialogFiltersUpdated" object:nil];
    });
    return self;
}

@end

@interface TLCodexModernUpdatesStateParser : TLupdates_State$updates_state
@end

@implementation TLCodexModernUpdatesStateParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLupdates_State$updates_state *result = [[TLupdates_State$updates_state alloc] init];
    result.pts = [is readInt32];
    result.qts = [is readInt32];
    result.date = [is readInt32];
    result.seq = [is readInt32];
    result.unread_count = [is readInt32];
    CodexLastReadUpdatesState = result;
    return result;
}

@end

static TLupdates_State *CodexReadUpdatesStateCompat(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t stateSignature = [is readInt32];
    if (stateSignature == (int32_t)0xa56c2a3e)
    {
        TLupdates_State$updates_state *result = [[TLupdates_State$updates_state alloc] init];
        result.pts = [is readInt32];
        result.qts = [is readInt32];
        result.date = [is readInt32];
        result.seq = [is readInt32];
        result.unread_count = [is readInt32];
        CodexLastReadUpdatesState = result;
        return result;
    }
    
    return (TLupdates_State *)TLMetaClassStore::constructObject(is, stateSignature, environment, nil, error);
}

@interface TLCodexModernUpdatesParser : TLUpdates$updates
@end

@implementation TLCodexModernUpdatesParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0x78d4dec1)
    {
        TLUpdates$updateShort *result = [[TLUpdates$updateShort alloc] init];
        result.update = (TLUpdate *)CodexReadObject(is, environment, error);
        if (error != NULL && *error != nil)
            return nil;
        result.date = [is readInt32];
        return result;
    }

    if (signature == (int32_t)0x725b04c3)
    {
        TLUpdates$updatesCombined *result = [[TLUpdates$updatesCombined alloc] init];
        result.updates = CodexReadStrictObjectVectorWithRole(is, @"updatesCombined.updates", environment, error);
        if (error != NULL && *error != nil)
            return nil;
        result.users = CodexReadStrictObjectVectorWithRole(is, @"updatesCombined.users", environment, error);
        if (error != NULL && *error != nil)
            return nil;
        result.chats = CodexReadStrictObjectVectorWithRole(is, @"updatesCombined.chats", environment, error);
        if (error != NULL && *error != nil)
            return nil;
        result.date = [is readInt32];
        result.seq_start = [is readInt32];
        result.seq = [is readInt32];
        return result;
    }

    TLUpdates$updates *result = [[TLUpdates$updates alloc] init];
    result.updates = CodexReadStrictObjectVectorWithRole(is, @"updates.updates", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.users = CodexReadStrictObjectVectorWithRole(is, @"updates.users", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.chats = CodexReadStrictObjectVectorWithRole(is, @"updates.chats", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.date = [is readInt32];
    result.seq = [is readInt32];
    return result;
}

@end

@interface TLCodexModernDifferenceEmptyParser : TLupdates_Difference$updates_differenceEmpty
@end

@implementation TLCodexModernDifferenceEmptyParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLupdates_Difference$updates_differenceEmpty *result = [[TLupdates_Difference$updates_differenceEmpty alloc] init];
    result.date = [is readInt32];
    result.seq = [is readInt32];
    return result;
}

@end

@interface TLCodexModernDifferenceParser : TLupdates_Difference$updates_difference
@end

@implementation TLCodexModernDifferenceParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0xa8fb1981)
    {
        TLupdates_Difference$updates_differenceSlice *result = [[TLupdates_Difference$updates_differenceSlice alloc] init];
        result.n_new_messages = CodexReadStrictObjectVectorWithRole(is, @"differenceSlice.messages", environment, error);
        if (error != NULL && *error != nil)
            return nil;
        result.n_new_encrypted_messages = CodexReadStrictObjectVectorWithRole(is, @"differenceSlice.encrypted", environment, error);
        if (error != NULL && *error != nil)
            return nil;
        result.other_updates = CodexReadStrictObjectVectorWithRole(is, @"differenceSlice.updates", environment, error);
        if (error != NULL && *error != nil)
            return nil;
        result.chats = CodexReadStrictObjectVectorWithRole(is, @"differenceSlice.chats", environment, error);
        if (error != NULL && *error != nil)
            return nil;
        result.users = CodexReadStrictObjectVectorWithRole(is, @"differenceSlice.users", environment, error);
        if (error != NULL && *error != nil)
            return nil;
        result.intermediate_state = CodexReadUpdatesStateCompat(is, environment, error);
        if (error != NULL && *error != nil)
            return nil;
        return result;
    }

    TLupdates_Difference$updates_difference *result = [[TLupdates_Difference$updates_difference alloc] init];
    result.n_new_messages = CodexReadStrictObjectVectorWithRole(is, @"difference.messages", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.n_new_encrypted_messages = CodexReadStrictObjectVectorWithRole(is, @"difference.encrypted", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.other_updates = CodexReadStrictObjectVectorWithRole(is, @"difference.updates", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.chats = CodexReadStrictObjectVectorWithRole(is, @"difference.chats", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.users = CodexReadStrictObjectVectorWithRole(is, @"difference.users", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.state = CodexReadUpdatesStateCompat(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    return result;
}

@end

@interface TLCodexModernChannelDifferenceParser : TLUpdates_ChannelDifference$channelDifference
@end

@implementation TLCodexModernChannelDifferenceParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdates_ChannelDifference$channelDifference *result = [[TLUpdates_ChannelDifference$channelDifference alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.pts = [is readInt32];
    if (flags & (1 << 1))
        result.timeout = [is readInt32];

    result.n_new_messages = CodexReadStrictObjectVectorWithRole(is, @"channelDifference.messages", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.other_updates = CodexReadStrictObjectVectorWithRole(is, @"channelDifference.updates", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.chats = CodexReadStrictObjectVectorWithRole(is, @"channelDifference.chats", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.users = CodexReadStrictObjectVectorWithRole(is, @"channelDifference.users", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    return result;
}

@end

@interface TLCodexChannelDifferenceTooLongParser : TLchannelDifferenceTooLong
@end

@implementation TLCodexChannelDifferenceTooLongParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLchannelDifferenceTooLong *result = [[TLchannelDifferenceTooLong alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (flags & (1 << 1))
        result.timeout = [is readInt32];
    id dialog = CodexReadObject(is, environment, error);
    if (error != NULL && *error != nil)
        return nil;
    if ([dialog isKindOfClass:[TLDialog$dialogMeta class]])
    {
        TLDialog$dialogMeta *dialogMeta = (TLDialog$dialogMeta *)dialog;
        result.pts = dialogMeta.pts;
        result.top_message = dialogMeta.top_message;
        result.unread_count = dialogMeta.unread_count;
        result.unread_mentions_count = dialogMeta.unread_mentions_count;
        result.read_inbox_max_id = dialogMeta.read_inbox_max_id;
        result.read_outbox_max_id = dialogMeta.read_outbox_max_id;
    }
    result.messages = CodexReadStrictObjectVectorWithRole(is, @"channelDifferenceTooLong.messages", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.chats = CodexReadStrictObjectVectorWithRole(is, @"channelDifferenceTooLong.chats", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    result.users = CodexReadStrictObjectVectorWithRole(is, @"channelDifferenceTooLong.users", environment, error);
    if (error != NULL && *error != nil)
        return nil;
    return result;
}

@end

void TLMetaClassStore::beginObjectClassRegistration()
{
    TGTLClassRegistryGuard guard;
    if (!TGTLObjectClassRegistrationPending)
    {
        TGTLObjectClassRegistrationPending = true;
        dispatch_group_enter(TGTLObjectClassRegistrationGroup());
    }
}

void TLMetaClassStore::completeObjectClassRegistration()
{
    bool shouldLeave = false;
    {
        TGTLClassRegistryGuard guard;
        if (TGTLObjectClassRegistrationPending)
        {
            TGTLObjectClassRegistrationPending = false;
            shouldLeave = true;
        }
    }
    if (shouldLeave)
        dispatch_group_leave(TGTLObjectClassRegistrationGroup());
}

void TLMetaClassStore::registerObjectClass(id<TLObject> objectClass)
{
    TGTLClassRegistryGuard guard;
    objectClassesByConstructorNames.insert(std::pair<int32_t, id<TLObject> >([objectClass TLconstructorName], objectClass));
}

void TLMetaClassStore::registerVectorClass(id<TLVector> vectorClass)
{
    TGTLClassRegistryGuard guard;
#if TARGET_IPHONE_SIMULATOR
    std::tr1::unordered_map<int32_t, id<TLVector> >::iterator it = vectorClassesBySignature.find([vectorClass TLconstructorSignature]);
    if (it != vectorClassesBySignature.end())
        TGLog(@"***** Overriding constructor 0x%x with %@ (was %@)", [vectorClass TLconstructorSignature], [vectorClass class], [it->second class]);
    
#endif
    vectorClassesBySignature.insert(std::pair<int32_t, id<TLVector> >([vectorClass TLconstructorSignature], vectorClass));
}

id<TLObject> TLMetaClassStore::getObjectClass(int32_t name)
{
    id<TLObject> result = nil;
    bool registrationPending = false;
    {
        TGTLClassRegistryGuard guard;
        std::tr1::unordered_map<int32_t, id<TLObject> >::iterator it = objectClassesByConstructorNames.find(name);
        if (it != objectClassesByConstructorNames.end())
            result = it->second;
        registrationPending = TGTLObjectClassRegistrationPending;
    }

    if (result == nil)
    {
        TLMetaClassTable const *table = TLgetMetaClassTable();
        id<TLObject> objectClass = TLMetaClassInstantiate(table->objectClasses, table->objectClassesCount, table->classNames, name);
        if (objectClass != nil)
        {
            TGTLClassRegistryGuard guard;
            result = objectClassesByConstructorNames.insert(std::pair<int32_t, id<TLObject> >(name, objectClass)).first->second;
        }
    }

    if (result == nil && registrationPending)
    {
        dispatch_group_wait(TGTLObjectClassRegistrationGroup(), DISPATCH_TIME_FOREVER);
        TGTLClassRegistryGuard guard;
        std::tr1::unordered_map<int32_t, id<TLObject> >::iterator it = objectClassesByConstructorNames.find(name);
        if (it != objectClassesByConstructorNames.end())
            result = it->second;
    }

    if (result == nil)
    {
        return nil;
    }
    return result;
}

id<TLVector> TLMetaClassStore::getVectorClass(int32_t signature)
{
    {
        TGTLClassRegistryGuard guard;
        std::tr1::unordered_map<int32_t, id<TLVector> >::iterator it = vectorClassesBySignature.find(signature);
        if (it != vectorClassesBySignature.end())
            return it->second;
    }

    TLMetaClassTable const *table = TLgetMetaClassTable();
    id<TLVector> vectorClass = TLMetaClassInstantiate(table->vectorClasses, table->vectorClassesCount, table->classNames, signature);
    if (vectorClass == nil)
        return nil;

    TGTLClassRegistryGuard guard;
    return vectorClassesBySignature.insert(std::pair<int32_t, id<TLVector> >(signature, vectorClass)).first->second;
}

static inline int32_t TLSchemeTextHash(const char *text, size_t length)
{
    return murMurHashBytes32((void *)text, (int)length);
}

static inline bool TLSchemeTextEquals(const char *text, size_t length, const char *literal)
{
    size_t literalLength = strlen(literal);
    return length == literalLength && memcmp(text, literal, length) == 0;
}

static inline bool TLSchemeTextHasPrefix(const char *text, size_t length, const char *prefix)
{
    size_t prefixLength = strlen(prefix);
    return length >= prefixLength && memcmp(text, prefix, prefixLength) == 0;
}

static void addHashToStringText(int32_t hash, const char *text, size_t length)
{
    std::tr1::unordered_map<int32_t, NSString *>::iterator it = hashToStringMap.find(hash);
    if (it != hashToStringMap.end())
    {
        const char *existing = [it->second UTF8String];
        if (existing != NULL && strlen(existing) == length && memcmp(existing, text, length) == 0)
            return;
    }
    NSString *string = [[NSString alloc] initWithBytes:text length:length encoding:NSUTF8StringEncoding];
    if (string != nil)
        hashToStringMap[hash] = string;
}

static int32_t TLVectorConstructorSignature(const char *elementType, size_t elementTypeLength)
{
    static const char vectorPrefix[] = "vector # [ ";
    static const char vectorSuffix[] = " ] = Vector ";
    std::vector<char> signatureString;
    signatureString.reserve(sizeof(vectorPrefix) + sizeof(vectorSuffix) + elementTypeLength * 2);
    signatureString.insert(signatureString.end(), vectorPrefix, vectorPrefix + sizeof(vectorPrefix) - 1);
    signatureString.insert(signatureString.end(), elementType, elementType + elementTypeLength);
    signatureString.insert(signatureString.end(), vectorSuffix, vectorSuffix + sizeof(vectorSuffix) - 1);
    signatureString.insert(signatureString.end(), elementType, elementType + elementTypeLength);
    return (int32_t)crc32(0, (const Bytef *)&signatureString[0], (uInt)signatureString.size());
}

struct TLSchemeBuiltinType
{
    const char *desc;
    const char *name;
    TLMetaTypeCategory category;
    bool boxed;
    int32_t unboxedConstructorSignature;
};

static const TLSchemeBuiltinType TLSchemeBuiltinTypes[] =
{
    {"int", "Int", TLMetaTypeCategoryBuiltinInt32, false, TL_INT32_CONSTRUCTOR},
    {"Int", "Int", TLMetaTypeCategoryBuiltinInt32, true, 0},
    {"long", "Long", TLMetaTypeCategoryBuiltinInt64, false, TL_INT64_CONSTRUCTOR},
    {"Long", "Long", TLMetaTypeCategoryBuiltinInt64, true, 0},
    {"int128", "Int128", TLMetaTypeCategoryBuiltinInt128, false, TL_INT128_CONSTRUCTOR},
    {"int256", "Int256", TLMetaTypeCategoryBuiltinInt256, false, TL_INT256_CONSTRUCTOR},
    {"double", "Double", TLMetaTypeCategoryBuiltinDouble, false, TL_DOUBLE_CONSTRUCTOR},
    {"Double", "Double", TLMetaTypeCategoryBuiltinDouble, true, 0},
    {"string", "String", TLMetaTypeCategoryBuiltinString, false, TL_STRING_CONSTRUCTOR},
    {"String", "String", TLMetaTypeCategoryBuiltinString, true, 0},
    {"bytes", "Bytes", TLMetaTypeCategoryBuiltinBytes, false, TL_BYTES_CONSTRUCTOR},
    {"Bytes", "Bytes", TLMetaTypeCategoryBuiltinBytes, true, 0},
    {"Bool", "Bool", TLMetaTypeCategoryBuiltinBool, true, 0},
    {"Object", "Object", TLMetaTypeCategoryObject, true, 0}
};

static TLMetaTypeArgument createTypeArgumentFromText(const char *desc, size_t length, std::set<int32_t> &typesToResolve, std::map<int32_t, TLMetaTypeArgumentWithName> &vectorTypeMap, bool &hasUnresolvedTypes)
{
    TLMetaTypeArgument type;
    
    type.boxed = false;
    type.unboxedConstructorName = 0;
    type.unboxedConstructorSignature = 0;
    
    TLMetaTypeCategory category = TLMetaTypeCategoryObject;
    int32_t typeName = 0;
    
    std::vector<TLMetaTypeArgument> typeArguments;
    
    const TLSchemeBuiltinType *builtinType = NULL;
    for (size_t i = 0; i < sizeof(TLSchemeBuiltinTypes) / sizeof(TLSchemeBuiltinTypes[0]); i++)
    {
        if (TLSchemeTextEquals(desc, length, TLSchemeBuiltinTypes[i].desc))
        {
            builtinType = &TLSchemeBuiltinTypes[i];
            break;
        }
    }
    
    if (builtinType != NULL)
    {
        size_t builtinNameLength = strlen(builtinType->name);
        typeName = TLSchemeTextHash(builtinType->name, builtinNameLength);
        addHashToStringText(typeName, builtinType->name, builtinNameLength);
        
        category = builtinType->category;
        type.boxed = builtinType->boxed;
        type.unboxedConstructorSignature = builtinType->unboxedConstructorSignature;
    }
    else if (length > 7 && (TLSchemeTextHasPrefix(desc, length, "Vector<") || TLSchemeTextHasPrefix(desc, length, "vector<")))
    {
        bool boxedVector = desc[0] == 'V';
        
        typeName = TLSchemeTextHash(desc, length);
        addHashToStringText(typeName, desc, length);
        
        const char *elementDesc = desc + 7;
        size_t elementLength = length - 7 - 1;
        TLMetaTypeArgument typeArgument = createTypeArgumentFromText(elementDesc, elementLength, typesToResolve, vectorTypeMap, hasUnresolvedTypes);
        typeArguments.push_back(typeArgument);
        
        TLMetaTypeArgumentWithName typeArgumentWithName;
        typeArgumentWithName.boxed = typeArgument.boxed;
        typeArgumentWithName.unboxedConstructorSignature = typeArgument.unboxedConstructorSignature;
        typeArgumentWithName.unboxedConstructorName = typeArgument.unboxedConstructorName;
        typeArgumentWithName.type = typeArgument.type;
        typeArgumentWithName.name.insert(typeArgumentWithName.name.end(), elementDesc, elementDesc + elementLength);
        
        vectorTypeMap[typeArgument.type->getName()] = typeArgumentWithName;
        
        category = TLMetaTypeCategoryBuiltinVector;
        type.boxed = boxedVector;
        if (boxedVector)
            type.unboxedConstructorName = typeName;
        type.unboxedConstructorSignature = TLVectorConstructorSignature(elementDesc, elementLength);
    }
    else
    {
        const char *dot = (const char *)memchr(desc, '.', length);
        size_t caseIndex = dot == NULL ? 0 : (size_t)(dot - desc) + 1;
        unsigned char c = caseIndex < length ? (unsigned char)desc[caseIndex] : 0;
        type.boxed = isupper(c) != 0;
        
        std::string boxedDesc(desc, length);
        if (!type.boxed && caseIndex < length)
            boxedDesc[caseIndex] = (char)toupper(c);
        
        typeName = TLSchemeTextHash(boxedDesc.data(), boxedDesc.size());
        addHashToStringText(typeName, boxedDesc.data(), boxedDesc.size());
        
        category = TLMetaTypeCategoryObject;
        
        type.unboxedConstructorSignature = 0;
        type.unboxedConstructorName = 0;
        if (!type.boxed)
        {
            type.unboxedConstructorName = TLSchemeTextHash(desc, length);
            addHashToStringText(type.unboxedConstructorName, desc, length);
            hasUnresolvedTypes = true;
        }
        
        typesToResolve.insert(typeName);
    }
    
    std::tr1::shared_ptr<TLMetaType> metaType(new TLMetaType(typeName, category, typeArguments));
    
    type.type = metaType;
    
    return type;
}

struct TLCachedFieldDescriptor
{
    TLMetaTypeArgument type;
    bool unresolved;
    bool hasFlag;
    int32_t flagName;
    int32_t flagBit;
    bool flagOnly;
};

static int32_t TLSchemeParseInteger(const char *text, size_t length)
{
    size_t index = 0;
    while (index < length && isspace((unsigned char)text[index]))
        index++;
    bool negative = false;
    if (index < length && (text[index] == '-' || text[index] == '+'))
    {
        negative = text[index] == '-';
        index++;
    }
    int32_t value = 0;
    while (index < length && text[index] >= '0' && text[index] <= '9')
    {
        value = value * 10 + (text[index] - '0');
        index++;
    }
    return negative ? -value : value;
}

static void TLApplyCachedFieldDescriptor(const char *rawTypeName, TLMetaField &field, bool &hasUnresolvedTypes, std::tr1::unordered_map<int32_t, TLCachedFieldDescriptor> &cachedFieldDescriptors, std::tr1::unordered_map<int32_t, std::pair<TLMetaTypeArgument, bool> > &cachedFieldTypes, std::set<int32_t> &typesToResolve, std::map<int32_t, TLMetaTypeArgumentWithName> &vectorTypeMap)
{
    size_t rawTypeLength = strlen(rawTypeName);
    int32_t rawTypeHash = TLSchemeTextHash(rawTypeName, rawTypeLength);
    std::tr1::unordered_map<int32_t, TLCachedFieldDescriptor>::iterator descriptorIt = cachedFieldDescriptors.find(rawTypeHash);
    if (descriptorIt == cachedFieldDescriptors.end())
    {
        TLCachedFieldDescriptor descriptor;
        descriptor.unresolved = false;
        descriptor.hasFlag = false;
        descriptor.flagName = 0;
        descriptor.flagBit = 0;
        descriptor.flagOnly = false;

        const char *typeName = rawTypeName;
        size_t typeNameLength = rawTypeLength;
        const char *optional = (const char *)memchr(rawTypeName, '?', rawTypeLength);
        if (optional != NULL)
        {
            const char *flagDesc = rawTypeName;
            size_t flagDescLength = (size_t)(optional - rawTypeName);
            const char *actualTypeName = optional + 1;
            size_t actualTypeNameLength = rawTypeLength - flagDescLength - 1;
            const char *dot = (const char *)memchr(flagDesc, '.', flagDescLength);
            if (dot != NULL)
            {
                size_t flagNameLength = (size_t)(dot - flagDesc);
                descriptor.hasFlag = true;
                descriptor.flagName = TLSchemeTextHash(flagDesc, flagNameLength);
                descriptor.flagBit = TLSchemeParseInteger(dot + 1, flagDescLength - flagNameLength - 1);
                descriptor.flagOnly = TLSchemeTextEquals(actualTypeName, actualTypeNameLength, "true");
                if (descriptor.flagOnly)
                {
                    typeName = "Bool";
                    typeNameLength = 4;
                }
                else
                {
                    typeName = actualTypeName;
                    typeNameLength = actualTypeNameLength;
                }
            }
        }

        int32_t fieldTypeName = TLSchemeTextHash(typeName, typeNameLength);
        std::tr1::unordered_map<int32_t, std::pair<TLMetaTypeArgument, bool> >::iterator typeIt = cachedFieldTypes.find(fieldTypeName);
        if (typeIt == cachedFieldTypes.end())
        {
            bool fieldUnresolvedTypes = false;
            descriptor.type = createTypeArgumentFromText(typeName, typeNameLength, typesToResolve, vectorTypeMap, fieldUnresolvedTypes);
            descriptor.unresolved = fieldUnresolvedTypes;
            cachedFieldTypes.insert(std::pair<int32_t, std::pair<TLMetaTypeArgument, bool> >(fieldTypeName, std::make_pair(descriptor.type, descriptor.unresolved)));
        }
        else
        {
            descriptor.type = typeIt->second.first;
            descriptor.unresolved = typeIt->second.second;
        }

        cachedFieldDescriptors.insert(std::pair<int32_t, TLCachedFieldDescriptor>(rawTypeHash, descriptor));
        descriptorIt = cachedFieldDescriptors.find(rawTypeHash);
    }

    field.type = descriptorIt->second.type;
    field.hasFlag = descriptorIt->second.hasFlag;
    field.flagName = descriptorIt->second.flagName;
    field.flagBit = descriptorIt->second.flagBit;
    field.flagOnly = descriptorIt->second.flagOnly;
    if (descriptorIt->second.unresolved)
        hasUnresolvedTypes = true;
}

static std::tr1::shared_ptr<TLMetaType> TLCachedTypeFromText(const char *desc, size_t length, std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaType> > &cachedResultTypes, std::set<int32_t> &typesToResolve, std::map<int32_t, TLMetaTypeArgumentWithName> &vectorTypeMap, bool &created)
{
    int32_t hash = TLSchemeTextHash(desc, length);
    std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaType> >::iterator it = cachedResultTypes.find(hash);
    if (it != cachedResultTypes.end())
    {
        created = false;
        return it->second;
    }

    bool hasUnresolvedTypes = false;
    std::tr1::shared_ptr<TLMetaType> type = createTypeArgumentFromText(desc, length, typesToResolve, vectorTypeMap, hasUnresolvedTypes).type;
    cachedResultTypes.insert(std::pair<int32_t, std::tr1::shared_ptr<TLMetaType> >(hash, type));
    created = true;
    return type;
}

struct TLMetaSchemeParamView
{
    const char *name;
    const char *type;
};

struct TLMetaSchemeEntryView
{
    int32_t signature;
    const char *name;
    const char *type;
    size_t paramsOffset;
    size_t paramsCount;
};

struct TLMetaSchemeEntries
{
    std::vector<TLMetaSchemeParamView> params;
    std::vector<TLMetaSchemeEntryView> types;
    std::vector<TLMetaSchemeEntryView> methods;
};

static void TLMetaSchemeAppendEntry(std::vector<TLMetaSchemeParamView> &params, std::vector<TLMetaSchemeEntryView> &list, int32_t signature, const char *name, const char *type, TLMetaSchemeParamView const *entryParams, size_t entryParamsCount)
{
    TLMetaSchemeEntryView entry;
    entry.signature = signature;
    entry.name = name;
    entry.type = type;
    entry.paramsOffset = params.size();
    entry.paramsCount = entryParamsCount;
    params.insert(params.end(), entryParams, entryParams + entryParamsCount);
    list.push_back(entry);
}

static void TLMetaSchemeAppendTableEntries(TLMetaSchemeEntries &entries, std::vector<TLMetaSchemeEntryView> &list, TLMetaSchemeTable const *table, TLMetaSchemeEntry const *tableEntries, uint32_t tableEntriesCount)
{
    list.reserve(list.size() + tableEntriesCount);
    for (uint32_t i = 0; i < tableEntriesCount; i++)
    {
        TLMetaSchemeEntry const &tableEntry = tableEntries[i];
        TLMetaSchemeEntryView entry;
        entry.signature = tableEntry.signature;
        entry.name = table->strings + tableEntry.name;
        entry.type = table->strings + tableEntry.type;
        entry.paramsOffset = entries.params.size();
        entry.paramsCount = tableEntry.paramsCount;
        for (uint32_t j = 0; j < tableEntry.paramsCount; j++)
        {
            TLMetaSchemeParamEntry const &tableParam = table->params[tableEntry.paramsOffset + j];
            TLMetaSchemeParamView param;
            param.name = table->strings + tableParam.name;
            param.type = table->strings + tableParam.type;
            entries.params.push_back(param);
        }
        list.push_back(entry);
    }
}

static void TLMetaSchemeAppendObjectEntry(TLMetaSchemeEntries &entries, std::vector<TLMetaSchemeEntryView> &list, int32_t signature, NSString *name, NSString *type, NSArray *params)
{
    TLMetaSchemeEntryView entry;
    entry.signature = signature;
    entry.name = name.UTF8String ?: "";
    entry.type = type.UTF8String ?: "";
    entry.paramsOffset = entries.params.size();
    entry.paramsCount = params.count;
    for (TLSchemeParam *objectParam in params)
    {
        TLMetaSchemeParamView param;
        param.name = objectParam.name.UTF8String ?: "";
        param.type = objectParam.type.UTF8String ?: "";
        entries.params.push_back(param);
    }
    list.push_back(entry);
}

static TLMetaSchemeParamView const TLMetaSchemeMessageContainerParams[] =
{
    {"messages", "vector<protoMessage>"}
};

static TLMetaSchemeParamView const TLMetaSchemeRpcResultParams[] =
{
    {"req_msg_id", "long"},
    {"result", "Object"}
};

static TLMetaSchemeParamView const TLMetaSchemeFutureSaltsParams[] =
{
    {"req_msg_id", "long"},
    {"now", "int"},
    {"salts", "vector<futureSalt>"}
};

static TLMetaSchemeParamView const TLMetaSchemeGetDifferenceParams[] =
{
    {"flags", "int"},
    {"pts", "int"},
    {"pts_limit", "flags.1?int"},
    {"pts_total_limit", "flags.0?int"},
    {"date", "int"},
    {"qts", "int"},
    {"qts_limit", "flags.2?int"}
};

typedef std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaConstructor> > TLMetaConstructorMap;
typedef std::vector<std::pair<int32_t, uint32_t> > TLMetaSchemeIndex;

struct TLMetaSchemeLazyStore
{
    TLMetaSchemeEntries entries;
    std::vector<TLMetaSchemeEntryView> registered;
    std::vector<std::tr1::shared_ptr<TLMetaConstructor> > constructors;
    TLMetaSchemeIndex signatureIndex;
    TLMetaSchemeIndex nameIndex;
    std::tr1::unordered_map<int32_t, std::pair<TLMetaTypeArgument, bool> > cachedFieldTypes;
    std::tr1::unordered_map<int32_t, TLCachedFieldDescriptor> cachedFieldDescriptors;
    std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaType> > cachedResultTypes;
    std::map<int32_t, TLMetaTypeArgumentWithName> vectorTypeMap;
    std::set<int32_t> typesToResolve;
    size_t registeredTypeCount;
};

static TLMetaSchemeLazyStore *TLMetaClassStoreLazyStore = NULL;

static void TLMetaSchemeFinishIndex(TLMetaSchemeIndex &index)
{
    std::sort(index.begin(), index.end());
    TLMetaSchemeIndex uniqueIndex;
    uniqueIndex.reserve(index.size());
    for (TLMetaSchemeIndex::const_iterator it = index.begin(); it != index.end(); ++it)
    {
        if (!uniqueIndex.empty() && uniqueIndex.back().first == it->first)
            uniqueIndex.back() = *it;
        else
            uniqueIndex.push_back(*it);
    }
    index.swap(uniqueIndex);
}

static bool TLMetaSchemeIndexFind(TLMetaSchemeIndex const &index, int32_t key, uint32_t *ref)
{
    TLMetaSchemeIndex::const_iterator it = std::lower_bound(index.begin(), index.end(), std::pair<int32_t, uint32_t>(key, 0));
    if (it == index.end() || it->first != key)
        return false;
    *ref = it->second;
    return true;
}

static bool TLMetaSchemeSignatureForName(TLMetaSchemeLazyStore const &store, TLMetaConstructorMap const &materializedByName, int32_t name, int32_t *signature)
{
    uint32_t ref = 0;
    if (TLMetaSchemeIndexFind(store.nameIndex, name, &ref))
    {
        *signature = store.registered[ref].signature;
        return true;
    }
    TLMetaConstructorMap::const_iterator it = materializedByName.find(name);
    if (it != materializedByName.end())
    {
        *signature = it->second->getSignature();
        return true;
    }
    return false;
}

static bool TLMetaSchemeResolveUnboxedTypes(TLMetaTypeArgument *type, TLMetaSchemeLazyStore const &store, TLMetaConstructorMap const &materializedByName)
{
    for (std::vector<TLMetaTypeArgument>::iterator it = type->type->getArguments().begin(); it != type->type->getArguments().end(); it++)
    {
        if (!TLMetaSchemeResolveUnboxedTypes(&(*it), store, materializedByName))
            return false;
    }
    
    if (!type->boxed && type->unboxedConstructorSignature == 0)
    {
        int32_t signature = 0;
        if (!TLMetaSchemeSignatureForName(store, materializedByName, type->unboxedConstructorName, &signature))
            return false;
        type->unboxedConstructorSignature = signature;
    }
    
    return true;
}

static void TLMetaSchemeLoadEntryVectorTypes(TLMetaSchemeLazyStore &store, TLMetaSchemeEntryView const &entry)
{
    for (size_t paramIndex = 0; paramIndex < entry.paramsCount; paramIndex++)
    {
        const char *rawType = store.entries.params[entry.paramsOffset + paramIndex].type;
        if (strchr(rawType, '<') == NULL)
            continue;
        
        TLMetaField field;
        bool hasUnresolvedTypes = false;
        TLApplyCachedFieldDescriptor(rawType, field, hasUnresolvedTypes, store.cachedFieldDescriptors, store.cachedFieldTypes, store.typesToResolve, store.vectorTypeMap);
    }
}

static std::tr1::shared_ptr<TLMetaConstructor> TLMetaSchemeLazyConstructor(TLMetaSchemeLazyStore &store, TLMetaConstructorMap const &materializedByName, std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaType> > &typesByName, uint32_t ref)
{
    if (store.constructors[ref])
        return store.constructors[ref];
    
    TLMetaSchemeEntryView const &entry = store.registered[ref];
    std::tr1::shared_ptr<std::vector<TLMetaField> > fields(new std::vector<TLMetaField>());
    fields->reserve(entry.paramsCount);
    
    bool hasUnresolvedTypes = false;
    for (size_t paramIndex = 0; paramIndex < entry.paramsCount; paramIndex++)
    {
        TLMetaSchemeParamView const &argDesc = store.entries.params[entry.paramsOffset + paramIndex];
        TLMetaField field;
        field.name = TLSchemeTextHash(argDesc.name, strlen(argDesc.name));
        TLApplyCachedFieldDescriptor(argDesc.type, field, hasUnresolvedTypes, store.cachedFieldDescriptors, store.cachedFieldTypes, store.typesToResolve, store.vectorTypeMap);
        fields->push_back(field);
    }
    
    bool createdResultType = false;
    std::tr1::shared_ptr<TLMetaType> resultType = TLCachedTypeFromText(entry.type, strlen(entry.type), store.cachedResultTypes, store.typesToResolve, store.vectorTypeMap, createdResultType);
    if (ref < store.registeredTypeCount)
        typesByName.insert(std::pair<int32_t, std::tr1::shared_ptr<TLMetaType> >(resultType->getName(), resultType));
    
    if (hasUnresolvedTypes)
    {
        for (std::vector<TLMetaField>::iterator fieldIt = fields->begin(); fieldIt != fields->end(); fieldIt++)
        {
            TLMetaSchemeResolveUnboxedTypes(&fieldIt->type, store, materializedByName);
        }
    }
    
    std::tr1::shared_ptr<TLMetaConstructor> constructor(new TLMetaConstructor(TLSchemeTextHash(entry.name, strlen(entry.name)), entry.signature, fields, resultType));
    store.constructors[ref] = constructor;
    return constructor;
}

static TLMetaSchemeLazyStore *TLMetaSchemeBuildLazyStore(TLMetaSchemeEntries &entries, size_t schemeMethodsCount, std::tr1::unordered_map<int32_t, TLMetaTypeArgument> &vectorElementTypesByConstructor, TLMetaConstructorMap const &materializedByName)
{
    CFAbsoluteTime buildStart = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime phaseStart = buildStart;
    TLMetaSchemeLazyStore *store = new TLMetaSchemeLazyStore();
    store->entries.params.swap(entries.params);
    store->entries.types.swap(entries.types);
    store->entries.methods.swap(entries.methods);
    store->registered.reserve(store->entries.types.size() + schemeMethodsCount);
    
    for (std::vector<TLMetaSchemeEntryView>::const_iterator typeIt = store->entries.types.begin(); typeIt != store->entries.types.end(); ++typeIt)
    {
        size_t typeLength = strlen(typeIt->type);
        if (TLSchemeTextEquals(typeIt->type, typeLength, "Bool") || TLSchemeTextEquals(typeIt->type, typeLength, "Null") || TLSchemeTextHasPrefix(typeIt->type, typeLength, "Vector<"))
            continue;
        
        TLMetaSchemeLoadEntryVectorTypes(*store, *typeIt);
        store->registered.push_back(*typeIt);
    }
    store->registeredTypeCount = store->registered.size();
    
    phaseStart = CFAbsoluteTimeGetCurrent();
    
    for (std::vector<TLMetaSchemeEntryView>::const_iterator methodIt = store->entries.methods.begin(); methodIt != store->entries.methods.end(); ++methodIt)
    {
        size_t typeLength = strlen(methodIt->type);
        if (TLSchemeTextHasPrefix(methodIt->type, typeLength, "Vector<"))
        {
            bool createdResultType = false;
            TLCachedTypeFromText(methodIt->type, typeLength, store->cachedResultTypes, store->typesToResolve, store->vectorTypeMap, createdResultType);
        }
    }
    
    for (std::map<int32_t, TLMetaTypeArgumentWithName>::iterator it = store->vectorTypeMap.begin(); it != store->vectorTypeMap.end(); it++)
    {
        int32_t signature = it->second.name.empty() ? TLVectorConstructorSignature("", 0) : TLVectorConstructorSignature(&it->second.name[0], it->second.name.size());
        
        TLMetaTypeArgument typeArgument;
        typeArgument.boxed = it->second.boxed;
        typeArgument.unboxedConstructorName = it->second.unboxedConstructorName;
        typeArgument.unboxedConstructorSignature = it->second.unboxedConstructorSignature;
        typeArgument.type = it->second.type;
        
        vectorElementTypesByConstructor.insert(std::pair<int32_t, TLMetaTypeArgument>(signature, typeArgument));
    }
    
    phaseStart = CFAbsoluteTimeGetCurrent();
    
    for (size_t methodIndex = 0; methodIndex < schemeMethodsCount; methodIndex++)
        store->registered.push_back(store->entries.methods[methodIndex]);
    
    phaseStart = CFAbsoluteTimeGetCurrent();
    
    store->signatureIndex.reserve(store->registered.size());
    store->nameIndex.reserve(store->registered.size());
    for (uint32_t ref = 0; ref < (uint32_t)store->registered.size(); ref++)
    {
        TLMetaSchemeEntryView const &entry = store->registered[ref];
        store->signatureIndex.push_back(std::pair<int32_t, uint32_t>(entry.signature, ref));
        store->nameIndex.push_back(std::pair<int32_t, uint32_t>(TLSchemeTextHash(entry.name, strlen(entry.name)), ref));
    }
    TLMetaSchemeFinishIndex(store->signatureIndex);
    TLMetaSchemeFinishIndex(store->nameIndex);
    store->constructors.resize(store->registered.size());
    
    for (std::tr1::unordered_map<int32_t, TLMetaTypeArgument>::iterator it = vectorElementTypesByConstructor.begin(); it != vectorElementTypesByConstructor.end(); ++it)
    {
        TLMetaSchemeResolveUnboxedTypes(&it->second, *store, materializedByName);
    }
    
    return store;
}

void TLMetaClassStore::mergeScheme(TLScheme *scheme)
{
    if (![scheme isKindOfClass:[TLScheme$scheme class]])
        return;
    
    @autoreleasepool
    {
        TLScheme$scheme *concreteScheme = (TLScheme$scheme *)scheme;
        TLMetaSchemeEntries entries;
        for (TLSchemeType *typeDesc in concreteScheme.types)
            TLMetaSchemeAppendObjectEntry(entries, entries.types, typeDesc.n_id, typeDesc.predicate, typeDesc.type, typeDesc.params);
        for (TLSchemeMethod *methodDesc in concreteScheme.methods)
            TLMetaSchemeAppendObjectEntry(entries, entries.methods, methodDesc.n_id, methodDesc.method, methodDesc.type, methodDesc.params);
        mergeSchemeEntries(entries, true);
    }
}

void TLMetaClassStore::mergeSchemeTable(TLMetaSchemeTable const *table)
{
    if (table == NULL)
        return;
    
    TLMetaSchemeEntries entries;
    entries.params.reserve(table->paramsCount + 16);
    TLMetaSchemeAppendTableEntries(entries, entries.types, table, table->types, table->typesCount);
    TLMetaSchemeAppendTableEntries(entries, entries.methods, table, table->methods, table->methodsCount);
    mergeSchemeEntries(entries, false);
}

void TLMetaClassStore::clearScheme()
{
    TGTLClassRegistryGuard guard;
    constructorsBySignature.clear();
    constructorsByName.clear();
    typesByName.clear();
    vectorElementTypesByConstructor.clear();
    delete TLMetaClassStoreLazyStore;
    TLMetaClassStoreLazyStore = NULL;
}

std::tr1::shared_ptr<TLMetaConstructor> TLMetaClassStore::getConstructorBySignature(int32_t signature)
{
    TGTLClassRegistryGuard guard;
    std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaConstructor> >::iterator it = constructorsBySignature.find(signature);
    if (it != constructorsBySignature.end())
        return it->second;
    
    uint32_t ref = 0;
    if (TLMetaClassStoreLazyStore == NULL || !TLMetaSchemeIndexFind(TLMetaClassStoreLazyStore->signatureIndex, signature, &ref))
        return std::tr1::shared_ptr<TLMetaConstructor>();
    
    std::tr1::shared_ptr<TLMetaConstructor> constructor = TLMetaSchemeLazyConstructor(*TLMetaClassStoreLazyStore, constructorsByName, typesByName, ref);
    constructorsBySignature[signature] = constructor;
    return constructor;
}

std::tr1::shared_ptr<TLMetaConstructor> TLMetaClassStore::getConstructorByName(int32_t name)
{
    TGTLClassRegistryGuard guard;
    std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaConstructor> >::iterator it = constructorsByName.find(name);
    if (it != constructorsByName.end())
        return it->second;
    
    uint32_t ref = 0;
    if (TLMetaClassStoreLazyStore == NULL || !TLMetaSchemeIndexFind(TLMetaClassStoreLazyStore->nameIndex, name, &ref))
        return std::tr1::shared_ptr<TLMetaConstructor>();
    
    std::tr1::shared_ptr<TLMetaConstructor> constructor = TLMetaSchemeLazyConstructor(*TLMetaClassStoreLazyStore, constructorsByName, typesByName, ref);
    constructorsByName[name] = constructor;
    return constructor;
}

void TLMetaClassStore::materializeLazyScheme()
{
    TLMetaSchemeLazyStore *store = TLMetaClassStoreLazyStore;
    if (store == NULL)
        return;
    
    for (TLMetaSchemeIndex::const_iterator it = store->signatureIndex.begin(); it != store->signatureIndex.end(); ++it)
    {
        if (constructorsBySignature.find(it->first) == constructorsBySignature.end())
            constructorsBySignature[it->first] = TLMetaSchemeLazyConstructor(*store, constructorsByName, typesByName, it->second);
    }
    for (TLMetaSchemeIndex::const_iterator it = store->nameIndex.begin(); it != store->nameIndex.end(); ++it)
    {
        if (constructorsByName.find(it->first) == constructorsByName.end())
            constructorsByName[it->first] = TLMetaSchemeLazyConstructor(*store, constructorsByName, typesByName, it->second);
    }
    
    TLMetaClassStoreLazyStore = NULL;
    delete store;
}

void TLMetaClassStore::mergeSchemeEntries(TLMetaSchemeEntries &entries, bool materialize)
{
    TGTLClassRegistryGuard guard;
    CFAbsoluteTime mergeStart = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime mergePhaseStart = mergeStart;
    
    size_t schemeMethodsCount = entries.methods.size();
    TLCodexSkipObjectParser *sharedSkipObjectParser = [[TLCodexSkipObjectParser alloc] init];
    mergePhaseStart = CFAbsoluteTimeGetCurrent();
    
    {
        id<TLObject> object = [[TLDestroySessionsRes$destroy_sessions_res alloc] init];
        manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >([object TLconstructorSignature], object));
    }
    
    TLMetaSchemeAppendEntry(entries.params, entries.types, (int32_t)0x73f1f8dc, "msg_container", "MessageContainer", TLMetaSchemeMessageContainerParams, sizeof(TLMetaSchemeMessageContainerParams) / sizeof(TLMetaSchemeMessageContainerParams[0]));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x73f1f8dc, TLLazyManualObjectParser(TLMessageContainer$msg_container)));
    
    TLMetaSchemeAppendEntry(entries.params, entries.types, (int32_t)0xf35c6d01, "rpc_result", "RpcResult", TLMetaSchemeRpcResultParams, sizeof(TLMetaSchemeRpcResultParams) / sizeof(TLMetaSchemeRpcResultParams[0]));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xf35c6d01, TLLazyManualObjectParser(TLRpcResult$rpc_result)));
    
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x5162463, TLLazyManualObjectParser(TLResPQ$resPQ_manual)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x62d6b459, TLLazyManualObjectParser(TLMsgsAck$msgs_ack_manual)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x44f9b43d, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x9815cec8, TLLazyManualObjectParser(TLMessage$modernMessage)));
    addHashToString((int32_t)0x9815cec8, @"message");
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x9e19a1f6, TLLazyManualObjectParser(TLMessage$modernMessageService)));
    
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5f07b4bc, TLLazyManualObjectParser(TLWebPage_manual)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x4b46c37e, TLLazyManualObjectParser(TLUser$modernUser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x31774388, TLLazyManualObjectParser(TLUser$modernUser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x020b1422, TLLazyManualObjectParser(TLUser$modernUser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb1b8cc83, TLLazyManualObjectParser(TLUser$modernUser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x2e13f4c3, TLLazyManualObjectParser(TLUser$modernUser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x215c4438, TLLazyManualObjectParser(TLUser$modernUser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x83314fca, TLLazyManualObjectParser(TLUser$modernUser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x2813e6db, TLLazyManualObjectParser(TLUser$modernUser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1afeb7ac, TLLazyManualObjectParser(TLUser$modernUser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd0a1d008, TLLazyManualObjectParser(TLUser$modernUser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd7c0ff9c, TLLazyManualObjectParser(TLUser$modernUser)));
    objectClassesByConstructorNames[(int32_t)0x6c3e5402] = [[TLMessageEntity$messageEntityTextUrl alloc] init];
    objectClassesByConstructorNames[(int32_t)0x9fbde43f] = [[TLChat$channelMeta alloc] init];
    addHashToString((int32_t)0x9fbde43f, @"channel");
    objectClassesByConstructorNames[(int32_t)0xe2f65ce2] = [[TLUserFull$userFullMeta alloc] init];
    addHashToString((int32_t)0xe2f65ce2, @"UserFull");
    objectClassesByConstructorNames[(int32_t)0x8c5d990f] = [[TLupdates_ChannelDifference$updates_channelDifferenceMeta alloc] init];
    addHashToString((int32_t)0x8c5d990f, @"updates.ChannelDifference");
    objectClassesByConstructorNames[(int32_t)0x4ccda305] = sharedSkipObjectParser;
    addHashToString((int32_t)0x4ccda305, @"updatePinnedChannelMessages");
    objectClassesByConstructorNames[(int32_t)0xf9a7c6d9] = sharedSkipObjectParser;
    addHashToString((int32_t)0xf9a7c6d9, @"businessLocation");
    objectClassesByConstructorNames[(int32_t)0xae9f31e8] = sharedSkipObjectParser;
    addHashToString((int32_t)0xae9f31e8, @"pollAnswerVoters");
    objectClassesByConstructorNames[(int32_t)0xd5d4c7f5] = sharedSkipObjectParser;
    addHashToString((int32_t)0xd5d4c7f5, @"mediaAreaSuggestedReaction");
    objectClassesByConstructorNames[(int32_t)0x377d3538] = sharedSkipObjectParser;
    addHashToString((int32_t)0x377d3538, @"webPageAttributeStickerSet");
    objectClassesByConstructorNames[(int32_t)0x9ac0c0cc] = sharedSkipObjectParser;
    addHashToString((int32_t)0x9ac0c0cc, @"messageEntityFormattedDate");
    objectClassesByConstructorNames[(int32_t)0x1f1ea79e] = sharedSkipObjectParser;
    addHashToString((int32_t)0x1f1ea79e, @"PeerColor");
    objectClassesByConstructorNames[(int32_t)0xa61d7ecc] = sharedSkipObjectParser;
    addHashToString((int32_t)0xa61d7ecc, @"botApp");
    objectClassesByConstructorNames[(int32_t)0xd91a34ac] = sharedSkipObjectParser;
    addHashToString((int32_t)0xd91a34ac, @"storyViews");
    objectClassesByConstructorNames[(int32_t)0x731eca73] = sharedSkipObjectParser;
    addHashToString((int32_t)0x731eca73, @"updatePinnedDialogs");
    objectClassesByConstructorNames[(int32_t)0x8350972b] = sharedSkipObjectParser;
    addHashToString((int32_t)0x8350972b, @"recentStory");
    objectClassesByConstructorNames[(int32_t)0xcba86ca2] = sharedSkipObjectParser;
    addHashToString((int32_t)0xcba86ca2, @"RequestPeerType");
    objectClassesByConstructorNames[(int32_t)0xf6781f7c] = sharedSkipObjectParser;
    addHashToString((int32_t)0xf6781f7c, @"modernOptionalFeature");
    objectClassesByConstructorNames[(int32_t)0x7f6b4284] = sharedSkipObjectParser;
    addHashToString((int32_t)0x7f6b4284, @"modernOptionalFeature");
    objectClassesByConstructorNames[(int32_t)0xd7bb4f53] = sharedSkipObjectParser;
    addHashToString((int32_t)0xd7bb4f53, @"modernOptionalFeature");
    objectClassesByConstructorNames[(int32_t)0xc18fad86] = sharedSkipObjectParser;
    addHashToString((int32_t)0xc18fad86, @"modernOptionalFeature");
    objectClassesByConstructorNames[(int32_t)0xff68ab47] = sharedSkipObjectParser;
    addHashToString((int32_t)0xff68ab47, @"notificationSound");
    objectClassesByConstructorNames[(int32_t)0x7a557809] = sharedSkipObjectParser;
    addHashToString((int32_t)0x7a557809, @"modernReactionFeature");
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x09d05049, TLLazyManualObjectParser(TLCodexUserStatusEmptyParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xedb93949, TLLazyManualObjectParser(TLCodexUserStatusOnlineParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x008c703f, TLLazyManualObjectParser(TLCodexUserStatusOfflineParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7b197dc8, TLLazyManualObjectParser(TLCodexUserStatusNoPayloadParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x541a1d1a, TLLazyManualObjectParser(TLCodexUserStatusNoPayloadParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x65899777, TLLazyManualObjectParser(TLCodexUserStatusNoPayloadParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x16d9703b, TLLazyManualObjectParser(TLCodexModernContactStatusParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe5bdf8de, TLLazyManualObjectParser(TLCodexModernUpdateUserStatusParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x18b7a10d, TLLazyManualObjectParser(TLDcOption$modernDcOption)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x14b24500, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xd597650c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x5bb98608, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x50cc03d3, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x8d595cd6, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x4e80a379, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x48e246c2, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xdc58f31e, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xac072444, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x22c0f6d5, TLLazyManualObjectParser(TLCodexModernInputReplyToParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x869fbe10, TLLazyManualObjectParser(TLCodexModernInputReplyToParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3bd4b7c2, TLLazyManualObjectParser(TLCodexModernInputReplyToParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5881323a, TLLazyManualObjectParser(TLCodexModernInputReplyToParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x69d66c45, TLLazyManualObjectParser(TLCodexModernInputReplyToParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x8c39793f, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc02d4007, TLLazyManualObjectParser(TLCodexModernChatParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe46bcee4, TLLazyManualObjectParser(TLCodexModernChatParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa0933f5b, TLLazyManualObjectParser(TLCodexModernChatParticipantParser)));
    addHashToString((int32_t)0x22c0f6d5, @"inputReplyToMessage");
    addHashToString((int32_t)0x869fbe10, @"inputReplyToMessage");
    addHashToString((int32_t)0x3bd4b7c2, @"inputReplyToMessage");
    addHashToString((int32_t)0x5881323a, @"inputReplyToStory");
    addHashToString((int32_t)0x69d66c45, @"inputReplyToMonoForum");
    addHashToString((int32_t)0x8c39793f, @"help.promoData");
    addHashToString((int32_t)0xc02d4007, @"chatParticipant");
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x914FBF11, TLLazyManualObjectParser(TLUpdates$modernUpdateShortMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x313bc7f8, TLLazyManualObjectParser(TLCodexModernUpdateShortMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x16812688, TLLazyManualObjectParser(TLUpdates$modernUpdateShortChatMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x4d6deea5, TLLazyManualObjectParser(TLCodexModernUpdateShortChatMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xBC0F17BC, TLLazyManualObjectParser(TLmessages_Messages$modernChannelMessages)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x11f1331c, TLLazyManualObjectParser(TLUpdates$updateShortSentMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x9015e101, TLLazyManualObjectParser(TLCodexModernUpdateShortSentMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa56c2a3e, TLLazyManualObjectParser(TLCodexModernUpdatesStateParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x78d4dec1, TLLazyManualObjectParser(TLCodexModernUpdatesParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x725b04c3, TLLazyManualObjectParser(TLCodexModernUpdatesParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x74ae4240, TLLazyManualObjectParser(TLCodexModernUpdatesParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5fb5523b, TLLazyManualObjectParser(TLCodexDialogFilterParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7438f7e8, TLLazyManualObjectParser(TLCodexDialogFilterParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x363293ae, TLLazyManualObjectParser(TLCodexDialogFilterParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x9fe28ea4, TLLazyManualObjectParser(TLCodexDialogFilterParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xaa472651, TLLazyManualObjectParser(TLCodexDialogFilterParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x96537bd7, TLLazyManualObjectParser(TLCodexDialogFilterParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x2ad93719, TLLazyManualObjectParser(TLCodexDialogFiltersParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x26ffde7d, TLLazyManualObjectParser(TLCodexDialogFilterUpdateParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa5d72105, TLLazyManualObjectParser(TLCodexDialogFilterUpdateParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3504914f, TLLazyManualObjectParser(TLCodexDialogFilterUpdateParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5d75a138, TLLazyManualObjectParser(TLCodexModernDifferenceEmptyParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x00f49ca0, TLLazyManualObjectParser(TLCodexModernDifferenceParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa8fb1981, TLLazyManualObjectParser(TLCodexModernDifferenceParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x2064674E, TLLazyManualObjectParser(TLCodexModernChannelDifferenceParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x3E11AFFB, TLLazyManualObjectParser(TLUpdates_ChannelDifference$empty)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xc88974ac, TLLazyManualObjectParser(TLChat$channel)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x0aadfc8f, TLLazyManualObjectParser(TLCodexModernChannelParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1c32b11c, TLLazyManualObjectParser(TLCodexModernChannelParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe00998b7, TLLazyManualObjectParser(TLCodexModernChannelParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfe4478bd, TLLazyManualObjectParser(TLCodexModernChannelParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfe685355, TLLazyManualObjectParser(TLCodexModernChannelParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd49f34c6, TLLazyManualObjectParser(TLCodexModernChannelParser)));
    addHashToString((int32_t)0xfe4478bd, @"channel");
    addHashToString((int32_t)0xfe685355, @"channel");
    addHashToString((int32_t)0xd49f34c6, @"channel");
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x65efe954, TLLazyManualObjectParser(TLChat$community)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfd3cdab8, TLLazyManualObjectParser(TLChat$communityForbidden)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xcbb7a507, TLLazyManualObjectParser(TLChatFull$communityFull)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x76141ebd, TLLazyManualObjectParser(TLCommunityPeer$communityPeer)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xf78a0973, TLLazyManualObjectParser(TLDialog$dialogCommunity)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5d20bae8, TLLazyManualObjectParser(TLMessageAction$messageActionChangeCommunity)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x20bcbba1, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x4bbb8f01, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x56dbfcf8, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x6c0d8e23, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xd9c6dc1a, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xbe376999, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x2f65c8e4, sharedSkipObjectParser));
    addHashToString((int32_t)0x65efe954, @"community");
    addHashToString((int32_t)0xfd3cdab8, @"communityForbidden");
    addHashToString((int32_t)0xcbb7a507, @"communityFull");
    addHashToString((int32_t)0x76141ebd, @"communityPeer");
    addHashToString((int32_t)0xf78a0973, @"dialogCommunity");
    addHashToString((int32_t)0x5d20bae8, @"messageActionChangeCommunity");
    addHashToString((int32_t)0x20bcbba1, @"updateNewEphemeralMessage");
    addHashToString((int32_t)0x4bbb8f01, @"updateEditEphemeralMessage");
    addHashToString((int32_t)0x56dbfcf8, @"updateDeleteEphemeralMessages");
    addHashToString((int32_t)0x6c0d8e23, @"updateBotStarsSubscription");
    addHashToString((int32_t)0xd9c6dc1a, @"ephemeralMessage");
    addHashToString((int32_t)0xbe376999, @"notifyCommunity");
    addHashToString((int32_t)0x2f65c8e4, @"dialogPeerCommunity");
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x17d493d5, TLLazyManualObjectParser(TLCodexModernChannelForbiddenParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x76af5481, TLLazyManualObjectParser(TLChatFull$channelFull)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xbbab348d, TLLazyManualObjectParser(TLCodexModernChannelFullParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa04e8d3a, TLLazyManualObjectParser(TLCodexModernChannelFullParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe4e0b29d, TLLazyManualObjectParser(TLCodexModernChannelFullParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xFC900C2B, TLLazyManualObjectParser(TLChatParticipants$chatParticipantsForbidden)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xD91CDD54, TLLazyManualObjectParser(TLChat$chat)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x41cbf256, TLLazyManualObjectParser(TLCodexModernChatParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x6592a1a7, TLLazyManualObjectParser(TLCodexModernChatForbiddenParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1c6e1c11, TLLazyManualObjectParser(TLCodexModernChatPhotoParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xB08FBB93, TLLazyManualObjectParser(TLWebPage$webPageExternal)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x947ca848, TLLazyManualObjectParser(TLMessages_BotResults$botResults)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x764cf810, TLLazyManualObjectParser(TLBotInlineMessage$botInlineMessageMediaAuto)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x8c7f65e2, TLLazyManualObjectParser(TLBotInlineMessage$botInlineMessageText)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xb722de65, TLLazyManualObjectParser(TLBotInlineMessage$botInlineMessageMediaGeo)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x8a86659c, TLLazyManualObjectParser(TLBotInlineMessage$botInlineMessageMediaVenue)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x18d1cdc2, TLLazyManualObjectParser(TLBotInlineMessage$botInlineMessageMediaContact)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x11965f3a, TLLazyManualObjectParser(TLBotInlineResult$botInlineResult)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x9852F9C6, TLLazyManualObjectParser(TLDocumentAttribute$documentAttributeAudio)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x43c57c48, TLLazyManualObjectParser(TLCodexModernDocumentAttributeVideoParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x559ebe6d, TLLazyManualObjectParser(TLMessageFwdHeader$messageFwdHeader)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xf220f3f, TLLazyManualObjectParser(TLUserFull$userFull)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x3b6d152e, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xcc997720, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xd2234ea0, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x06cbe645, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x8c92b098, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x120b1ab9, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x5a0a066d, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x711d692d, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x75b3b798, sharedSkipObjectParser));
    manualObjectParsers[(int32_t)0x1bf335b9] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xfe198602] = sharedSkipObjectParser;
    addHashToString((int32_t)0xfe198602, @"updateChannelPinnedTopics");
    manualObjectParsers[(int32_t)0x7d627683] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1824e40b] = sharedSkipObjectParser;
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x0ab4a819, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xc01e857f, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x2a17bf5c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x83487af0, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc32d5b12, TLLazyManualObjectParser(TLCodexModernUpdateDeleteChannelMessagesParser)));
    addHashToString((int32_t)0xc32d5b12, @"updateDeleteChannelMessages");
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5e1b3cb8, TLLazyManualObjectParser(TLCodexUpdateMessageReactionsParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xd6b19546, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x51e6ee4f, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xea29055d, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x922e6e10, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x9c974fdf, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x8951abef, TLLazyManualObjectParser(TLCodexModernUpdateNewAuthorizationParser)));
    addHashToString((int32_t)0x8951abef, @"updateNewAuthorization");
    manualObjectParsers[(int32_t)0xad01d61d] = TLLazyManualObjectParser(TGDeviceAuthorizationParser);
    manualObjectParsers[(int32_t)0x4bff8ea0] = TLLazyManualObjectParser(TGDeviceAuthorizationsParser);
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb75f99a9, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xf226ac08, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x6f7863f4, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x86fccf85, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x74c34319, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xffadc913, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb390dc08, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x16a4b93c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xedf164f1, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x79b26a24, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x68cb6283, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x9a35e999, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x63c3dd0a, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb826e150, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x2e94c3e7, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xcf6f6db8, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x31cad303, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x01c641c2, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xbbb6b4a3, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x74aee3e0, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x313a9547, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x85f0a9cd, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x565251e2, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x4e7085ea, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x9f2504e4, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xe0bff26c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x36437737, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xdbce6389, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xf08d516b, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x78fbf3a8, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xcef7e7a8, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xaff56398, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x71f276c4, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x4d4bd46a, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x3458f9c8, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xfe333952, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x771a4e66, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x972dabbf, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x2eeed1c4, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x3aae0528, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x0aa021e5, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xbe82db9c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb282217f, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xcad5452d, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x14455871, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x2271f2bf, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x5787686d, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xdf8b3b22, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xa5d9abb8, sharedSkipObjectParser));
    manualObjectParsers[(int32_t)0xde4c5d93] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb0bdeac5] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9083670b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xbd74cf49] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x59d78fc5] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xde9eed1d] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xe87acbc0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xe2de7737] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x6090d6d5] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xbbab2643] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xcfcd0f13] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xaa5f789c] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xa388a368] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x2ed82995] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x3de1dfed] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x416c56e8] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x41df43fc] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x95f389b1] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x69279795] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xf101aa7f] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x2085c238] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x84aa3a9c] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x48aaae3c] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x4a162433] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1f01c757] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x2eb1b658] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x947a12df] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9d6b13b0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xa0ba4f17] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x8a2932f3] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x512fe446] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x99ea331d] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x6b39f4ec] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x42b00348] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x7d5bd1f0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xd31bc45d] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xdb33dad0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xaef6abbc] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x46c6e36f] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xdaad85b0] = TLLazyManualObjectParser(TLCodexMessageMediaGiveawayParser);
    addHashToString((int32_t)0xdaad85b0, @"messageMediaGiveaway");
    manualObjectParsers[(int32_t)0xc6991068] = TLLazyManualObjectParser(TLCodexMessageMediaGiveawayParser);
    addHashToString((int32_t)0xc6991068, @"messageMediaGiveawayResults");
    manualObjectParsers[(int32_t)0xbec268ef] = TLLazyManualObjectParser(TLCodexUpdateNotifySettingsParser);
    addHashToString((int32_t)0xbec268ef, @"updateNotifySettings");
    manualObjectParsers[(int32_t)0xcde0ec40] = TLLazyManualObjectParser(TLCodexChatInviteParser);
    addHashToString((int32_t)0xcde0ec40, @"chatInvite");
    manualObjectParsers[(int32_t)0x4ba3a95a] = sharedSkipObjectParser;
    addHashToString((int32_t)0x4ba3a95a, @"messageReactor");
    manualObjectParsers[(int32_t)0xe16459c3] = sharedSkipObjectParser;
    addHashToString((int32_t)0xe16459c3, @"updateDialogUnreadMark");
    manualObjectParsers[(int32_t)0xe56dbf05] = sharedSkipObjectParser;
    addHashToString((int32_t)0xe56dbf05, @"dialogPeer");
    manualObjectParsers[(int32_t)0x514519e2] = sharedSkipObjectParser;
    addHashToString((int32_t)0x514519e2, @"dialogPeerFolder");
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xf74e932b, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb05ac6b1, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xeb0467fb, TLLazyManualObjectParser(TLUpdate$updateChannelTooLong)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x108d941f, TLLazyManualObjectParser(TLCodexModernUpdateChannelTooLongParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa4bcc6fe, TLLazyManualObjectParser(TLCodexChannelDifferenceTooLongParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x38faab5f, TLLazyManualObjectParser(TLauth_SentCode$auth_sentCode)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x5e002502, TLLazyManualObjectParser(TLauth_SentCode$auth_sentCode)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x36585ea4, TLLazyManualObjectParser(TLmessages_BotCallbackAnswer$botCallbackAnswer)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x17db940b, TLLazyManualObjectParser(TLBotInlineResult$botInlineMediaResult)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xe4def5db, TLLazyManualObjectParser(TLCodexModernDialogParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd58a08c6, TLLazyManualObjectParser(TLCodexModernDialogParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x90a6ca84, TLLazyManualObjectParser(TLCodexModernMessageEmptyParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb6c4f543, TLLazyManualObjectParser(TLCodexMessageViewsResultParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x8c718e87, TLLazyManualObjectParser(TLCodexModernMessagesParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1d73e7ea, TLLazyManualObjectParser(TLCodexModernMessagesParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3a54685e, TLLazyManualObjectParser(TLCodexModernMessagesSliceParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5f206716, TLLazyManualObjectParser(TLCodexModernMessagesSliceParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x3e0b5b6a, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc776ba4e, TLLazyManualObjectParser(TLCodexModernChannelMessagesParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x9ab0feaf, TLLazyManualObjectParser(TLCodexModernChannelsParticipantsParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xdfb80317, TLLazyManualObjectParser(TLCodexModernChannelParticipantResultParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc00c07c0, TLLazyManualObjectParser(TLCodexModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1bd54456, TLLazyManualObjectParser(TLCodexModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x35a8bfa7, TLLazyManualObjectParser(TLCodexModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa9478a1a, TLLazyManualObjectParser(TLCodexModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x2fe601d3, TLLazyManualObjectParser(TLCodexModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x34c3bb53, TLLazyManualObjectParser(TLCodexModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x6df8014e, TLLazyManualObjectParser(TLCodexModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd5f0ad91, TLLazyManualObjectParser(TLCodexModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1b03f006, TLLazyManualObjectParser(TLCodexModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x71701da9, TLLazyManualObjectParser(TLCodexForumTopicParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfcdad815, TLLazyManualObjectParser(TLCodexForumTopicParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x023f109b, TLLazyManualObjectParser(TLCodexForumTopicParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x15ba6c40, TLLazyManualObjectParser(TLCodexDialogsParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x71e094f3, TLLazyManualObjectParser(TLCodexDialogsParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xf0e3e596, TLLazyManualObjectParser(TLCodexDialogsParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x0200185b, TLLazyManualObjectParser(TLCodexDialogsParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x94345242, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x96fdbbe9, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7600b9d3, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x95ef6f2b, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x6a26cb37, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd0bbd081, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x003e38e7, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd9a7d88a, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd18fd1bb, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xff86154d, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xbb294f27, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x65fdf943, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x6a4ced37, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x6236ae4a, TLLazyManualObjectParser(TLMessage$modernMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd8a8d820, TLLazyManualObjectParser(TLMessage$modernMessage)));
    addHashToString((int32_t)0x6a26cb37, @"message");
    addHashToString((int32_t)0x96fdbbe9, @"message");
    addHashToString((int32_t)0xd0bbd081, @"message");
    addHashToString((int32_t)0x003e38e7, @"message");
    addHashToString((int32_t)0xd9a7d88a, @"message");
    addHashToString((int32_t)0xd18fd1bb, @"message");
    addHashToString((int32_t)0xff86154d, @"message");
    addHashToString((int32_t)0xbb294f27, @"message");
    addHashToString((int32_t)0x65fdf943, @"message");
    addHashToString((int32_t)0x6a4ced37, @"message");
    addHashToString((int32_t)0x6236ae4a, @"message");
    addHashToString((int32_t)0xd8a8d820, @"message");
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x2b085862, TLLazyManualObjectParser(TLMessage$modernMessageService)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x7063c3db, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd64c522b, TLLazyManualObjectParser(TLCodexUpdateMessagePollParser)));
    addHashToString((int32_t)0xd64c522b, @"updateMessagePoll");
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xed85eab5, sharedSkipObjectParser));
    addHashToString((int32_t)0xed85eab5, @"updatePinnedMessages");
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7a800e0a, TLLazyManualObjectParser(TLMessage$modernMessageService)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x6a3ac8ea, TLLazyManualObjectParser(TLMessage$modernMessageService)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x4fdd3430, TLLazyManualObjectParser(TLCodexModernKeyboardButtonStyleParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa03e5b85, TLLazyManualObjectParser(TLCodexModernReplyMarkupParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x86b40b08, TLLazyManualObjectParser(TLCodexModernReplyMarkupParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xf4108aa0, TLLazyManualObjectParser(TLCodexModernReplyMarkupParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x85dd99d1, TLLazyManualObjectParser(TLCodexModernReplyMarkupParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3502758c, TLLazyManualObjectParser(TLCodexModernReplyMarkupParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x48a30254, TLLazyManualObjectParser(TLCodexModernReplyMarkupParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x77608b83, TLLazyManualObjectParser(TLCodexModernKeyboardButtonRowParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x3081ed9d, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x833c0fac, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xd766c50a, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x5ec4be43, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x6334ee9a, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x0e3b2d0c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa2fa4880, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7d170cff, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x258aff05, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd80c25ec, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x683a5e46, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x35bbdb6b, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe62bc960, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb16a6c29, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x417efd8f, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfc796b3f, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xaa40f94d, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x0568a748, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x93b9fbb5, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x991399fc, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x50f41ccf, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x89c590f9, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xafd93fbb, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3fa53905, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x10b78d29, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd02e7fd4, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xf51006f9, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x68013e72, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xbbc7515d, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7a11d782, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe988037b, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x308660c1, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7d5e07c7, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc0fd5d09, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x13767230, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa0c0505c, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe846b1a0, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe15c4370, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x53d7bfd8, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc9662d05, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5b0f15f5, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x02b78156, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x75d2698e, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xbcc4af10, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x5f3b8a00, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xc9f06e1b, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x339bef6c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x3e81e078, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x71bd134c, TLLazyManualObjectParser(TLCodexDialogFolderParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x69274bc6, TLLazyManualObjectParser(TLCodexModernDialogParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfc89f7f3, TLLazyManualObjectParser(TLCodexModernDialogParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x59511722, TLLazyManualObjectParser(TLCodexModernPeerUserParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x15752102, TLLazyManualObjectParser(TLCodexModernPeerUserParser)));
    addHashToString((int32_t)0x15752102, @"peerUser");
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x36c6019a, TLLazyManualObjectParser(TLCodexModernPeerChatParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa2a5371e, TLLazyManualObjectParser(TLCodexModernPeerChannelParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb9c0639a, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x5da674b7, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x95fcd1d6, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x99622c0c, TLLazyManualObjectParser(TLCodexModernPeerNotifySettingsParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc13e3c50, TLLazyManualObjectParser(TLCodexModernImportedContactParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5ce14175, TLLazyManualObjectParser(TLPopularContact$popularContact)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5fb224d5, TLLazyManualObjectParser(TLCodexModernChatAdminRightsParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x9f120418, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xd072acb4, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb4073647, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb54b5acf, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x2de11aae, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x929b619d, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xfa30a8c7, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xee8c1e86, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xf35aec28, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x5b934f9d, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xcdbbcebb, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xbe382906, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x2cb51097, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x03d1ea4e, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xcfc9e002, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x770416af, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x37381085, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x49a6549c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x50a04e45, TLLazyManualObjectParser(TLCodexModernPrivacyRulesParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xfffe1bac, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x65427b82, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb8905fb2, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xf888fa1a, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x8b73e763, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xe4621141, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x6b134e8e, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x41c87565, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xf7e8d89b, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xece9814b, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x21461b5d, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xf6a5f82f, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xbc2eab30, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x500e6dfa, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x3d662b7b, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x39491cc8, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x69ec56a3, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x96151fed, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xd19ae46d, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x42ffd42b, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x0697f414, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xa486b761, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x2000a518, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x2ca4fdf8, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x17d348d2, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xff7a571b, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x2dd14edc, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x4f2b9479, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x0a339f0b, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xa3d1cb80, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x8c79b63c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x1b2286b8, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x8935fc73, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x79f5d419, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x523da4eb, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xeafc32bc, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x52928bca, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x661d4037, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe9baa668, TLLazyManualObjectParser(TLCodexFolderPeerParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x19360dc0, TLLazyManualObjectParser(TLCodexUpdateFolderPeersParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1e297bfa, TLLazyManualObjectParser(TLCodexUpdateMessageReactionsParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x695c9e7c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x4f11bae1, TLLazyManualObjectParser(TLUserProfilePhoto$userProfilePhotoEmpty)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x82d1f706, TLLazyManualObjectParser(TLCodexModernUserProfilePhotoParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xebd1c797, TLLazyManualObjectParser(TLCodexModernUserProfilePhotoParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x85dd99d1, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x48a30254, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xa03e5b85, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x86b40b08, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x77608b83, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xa2fa4880, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x258aff05, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x35bbdb6b, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb16a6c29, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xfc796b3f, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x93b9fbb5, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x50f41ccf, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xafd93fbb, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x10b78d29, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd02e7fd4, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xbbc7515d, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe988037b, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x308660c1, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x13767230, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa0c0505c, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x53d7bfd8, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc9662d05, TLLazyManualObjectParser(TLCodexModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x36086d42, TLLazyManualObjectParser(TLDialog$dialogFeed)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xfd8e711f, TLLazyManualObjectParser(TLDraftMessage$draftMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x60fe3294, TLLazyManualObjectParser(TLCodexModernDraftMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3fccf7ef, TLLazyManualObjectParser(TLCodexModernDraftMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x96eaa5eb, TLLazyManualObjectParser(TLCodexModernDraftMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x2d65321f, TLLazyManualObjectParser(TLCodexModernDraftMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1b49ec6d, TLLazyManualObjectParser(TLCodexModernUpdateDraftMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xedfc111e, TLLazyManualObjectParser(TLCodexModernUpdateDraftMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x8f300b57, TLLazyManualObjectParser(TLCodexModernBotInfoParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc27ac8c7, TLLazyManualObjectParser(TLCodexModernBotCommandParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x9852d6d2, TLLazyManualObjectParser(TLCodexModernBotCommandParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x7533a588, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x4258c205, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xc7b57ce6, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xdb74f558, TLLazyManualObjectParser(TLChatInvite$chatInvite)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x3213dbba, TLLazyManualObjectParser(TLConfig$config)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xcc1a241e, TLLazyManualObjectParser(TLCodexModernConfigParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xcd050916, TLLazyManualObjectParser(TLauth_Authorization$auth_authorization)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x2ea2c0d4, TLLazyManualObjectParser(TLauth_Authorization$auth_authorization)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x6319d612, TLLazyManualObjectParser(TLDocumentAttributeSticker)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x6c37c15c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x11b58939, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x17399fad, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x15590068, TLLazyManualObjectParser(TLCodexModernDocumentAttributeFilenameParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x9801d2f7, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xfd149899, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xbdf9653b, TLLazyManualObjectParser(TLGame$game)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xcde200d1, TLLazyManualObjectParser(TLPageBlock$pageBlockEmbed)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x1b8f4ad1, TLLazyManualObjectParser(TLPhoneCall$phoneCallWaiting)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xebe46819, TLLazyManualObjectParser(TLUpdate$updateServiceNotification)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x50ca4de1, TLLazyManualObjectParser(TLPhoneCall$phoneCallDiscarded)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xeed42858, TLLazyManualObjectParser(TLPhoneCall$phoneCallWaitingMeta)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x45361c63, TLLazyManualObjectParser(TLPhoneCall$phoneCallRequested)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x22fd7181, TLLazyManualObjectParser(TLPhoneCall$phoneCallAccepted)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3ba5940c, TLLazyManualObjectParser(TLPhoneCall$phoneCall)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xf9d25503, TLLazyManualObjectParser(TLPhoneCall$phoneCallDiscardedMeta)));
    objectClassesByConstructorNames[(int32_t)0xdc7555ab] = [[TLPhoneCall$phoneCallWaitingMeta alloc] init];
    objectClassesByConstructorNames[(int32_t)0x9627ce57] = [[TLPhoneCall$phoneCallRequested alloc] init];
    objectClassesByConstructorNames[(int32_t)0xd149f2bd] = [[TLPhoneCall$phoneCallAccepted alloc] init];
    objectClassesByConstructorNames[(int32_t)0xc9908a15] = [[TLPhoneCall$phoneCall alloc] init];
    objectClassesByConstructorNames[(int32_t)0xf01017df] = [[TLPhoneCall$phoneCallDiscardedMeta alloc] init];
    TLCodexPhoneConnectionParser *phoneConnectionParser = [[TLCodexPhoneConnectionParser alloc] init];
    manualObjectParsers[(int32_t)0x9cc123c7] = phoneConnectionParser;
    manualObjectParsers[(int32_t)0x635fe375] = phoneConnectionParser;
    manualObjectParsers[(int32_t)0xeccaad39] = sharedSkipObjectParser;
    objectClassesByConstructorNames[(int32_t)0xeccaad39] = sharedSkipObjectParser;
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xea4cb65b, TLLazyManualObjectParser(TLUpdate$updatePinnedDialogs)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x80e11a7f, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb6aef7b0, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xbd47cbad, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb5a1ce5a, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7fcb13a8, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x95e3fbef, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x15cefd00, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa43f30cc, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x031224c3, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x95d2ac92, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe1037f92, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xea3948e9, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x94bd38ed, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x9fbab604, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x92a72876, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3c134d7b, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xcc02aa6d, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x0d999256, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x8f31b327, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x96163f56, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x4792929b, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfae69f56, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc516d679, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1b287353, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd95c6154, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x98e0d697, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7a0d7f42, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x502f92f7, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb3a07661, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xaa786345, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x47dd8079, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb4c38cb5, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc83d6aec, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc0944820, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x57de635e, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x31518e9b, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5060a3f4, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x678c2e09, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x332ba9ed, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x2a9fadc5, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x93b31848, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x41b3e202, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x45d5b021, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xf3f25f76, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xebbca3cb, TLLazyManualObjectParser(TLCodexModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd7c0ff9c, TLLazyManualObjectParser(TLUser$modernUser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xc30aa358, TLLazyManualObjectParser(TLInvoice$invoice)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x84551347, TLLazyManualObjectParser(TLMessageMedia$messageMediaInvoice)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x3f56aea3, TLLazyManualObjectParser(TLpayments_PaymentForm$payments_paymentForm)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xfb8fe43c, TLLazyManualObjectParser(TLpayments_SavedInfo$payments_savedInfo)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x909c3f94, TLLazyManualObjectParser(TLPaymentRequestedInfo$paymentRequestedInfo)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x500911e1, TLLazyManualObjectParser(TLPayments_PaymentCeceipt$payments_paymentReceipt)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xd1451883, TLLazyManualObjectParser(TLpayments_ValidatedRequestedInfo$payments_validatedRequestedInfo)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x6c47ac9f, TLLazyManualObjectParser(TLLangPackStringPluralized)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x289da732, TLLazyManualObjectParser(TLChat$channelForbidden)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x695150d7, TLLazyManualObjectParser(TLCodexModernMessageMediaPhotoParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe216eb63, TLLazyManualObjectParser(TLCodexModernMessageMediaPhotoParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb940c666, TLLazyManualObjectParser(TLCodexModernMessageMediaGeoLiveParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xddf10c3b, TLLazyManualObjectParser(TLCodexModernMessageMediaWebPageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3f7ee58b, TLLazyManualObjectParser(TLCodexModernMessageMediaDiceParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x08cbec07, TLLazyManualObjectParser(TLCodexModernMessageMediaDiceParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xdc7b1140, TLLazyManualObjectParser(TLCodexModernMessageEntityMentionNameParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc8cf05f8, TLLazyManualObjectParser(TLCodexModernMessageEntityCustomEmojiParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x145ade0b, TLLazyManualObjectParser(TLCodexModernContactParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >(0x6a7e7366, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x9cb070d7, TLLazyManualObjectParser(TLCodexModernMessageMediaDocumentParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x4cf4d72d, TLLazyManualObjectParser(TLCodexModernMessageMediaDocumentParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x52d8ccd9, TLLazyManualObjectParser(TLCodexModernMessageMediaDocumentParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfb197a65, TLLazyManualObjectParser(TLCodexModernPhotoParser)));
    manualObjectParsers[(int32_t)0xdd570bd5] = TLLazyManualObjectParser(TLCodexModernMessageMediaDocumentParser);
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x75c78e60, TLLazyManualObjectParser(TLCodexModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x021e1ad6, TLLazyManualObjectParser(TLCodexModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe0b0bc2e, TLLazyManualObjectParser(TLCodexModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfa3efb95, TLLazyManualObjectParser(TLCodexModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd8214d41, TLLazyManualObjectParser(TLCodexModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xde33b094, TLLazyManualObjectParser(TLCodexModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xf85c413c, TLLazyManualObjectParser(TLCodexModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x0da082fe, TLLazyManualObjectParser(TLCodexModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x77d01c3b, TLLazyManualObjectParser(TLCodexModernImportedContactsParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x83d60fc2, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x8fd4c4d8, TLLazyManualObjectParser(TLCodexModernDocumentParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x6a9d7b35, TLLazyManualObjectParser(TLchannelDifferenceTooLong)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x55c3a1b1, TLLazyManualObjectParser(TLmessages_FeedMessages$messages_feedMessages)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x8e8bca3d, TLLazyManualObjectParser(TLchannels_FeedSources$channels_feedSources)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x31bc3d25, TLLazyManualObjectParser(TLInputSingleMedia$inputSingleMedia)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x5585a139, TLLazyManualObjectParser(TLStickerSet$stickerSet)));
    manualObjectParsers[(int32_t)0x6410a5d2] = TLLazyManualObjectParser(TLCodexModernStickerSetCoveredParser);
    manualObjectParsers[(int32_t)0x3407e51b] = TLLazyManualObjectParser(TLCodexModernStickerSetCoveredParser);
    manualObjectParsers[(int32_t)0x40d13c0e] = TLLazyManualObjectParser(TLCodexModernStickerSetCoveredParser);
    manualObjectParsers[(int32_t)0x77b15d1c] = TLLazyManualObjectParser(TLCodexModernStickerSetCoveredParser);
    manualObjectParsers[(int32_t)0xcdbbcebb] = TLLazyManualObjectParser(TLCodexModernAllStickersParser);
    manualObjectParsers[(int32_t)0x2cb51097] = TLLazyManualObjectParser(TLCodexModernFavedStickersParser);
    manualObjectParsers[(int32_t)0xfcfeb29c] = TLLazyManualObjectParser(TLCodexModernStickerKeywordParser);
    manualObjectParsers[(int32_t)0x12b299d4] = TLLazyManualObjectParser(TLCodexStickerPackParser);
    manualObjectParsers[(int32_t)0x6e153f16] = TLLazyManualObjectParser(TLCodexModernStickerSetParser);
    manualObjectParsers[(int32_t)0xe86602c3] = TLLazyManualObjectParser(TLCodexModernAllStickersParser);
    manualObjectParsers[(int32_t)0x9e8fa6d3] = TLLazyManualObjectParser(TLCodexModernFavedStickersParser);
    manualObjectParsers[(int32_t)0x88d37c56] = TLLazyManualObjectParser(TLCodexModernRecentStickersParser);
    manualObjectParsers[(int32_t)0x0b17f890] = TLLazyManualObjectParser(TLCodexModernRecentStickersParser);
    manualObjectParsers[(int32_t)0xbe382906] = TLLazyManualObjectParser(TLCodexModernFeaturedStickersParser);
    manualObjectParsers[(int32_t)0xc6dc0c66] = TLLazyManualObjectParser(TLCodexModernFeaturedStickersParser);
    manualObjectParsers[(int32_t)0x38641628] = TLLazyManualObjectParser(TLCodexModernStickerSetInstallResultParser);
    manualObjectParsers[(int32_t)0x35e410a8] = TLLazyManualObjectParser(TLCodexModernStickerSetInstallResultParser);
    manualObjectParsers[(int32_t)0x8af09dd2] = TLLazyManualObjectParser(TLCodexModernFoundStickerSetsParser);
    manualObjectParsers[(int32_t)0x0d54b65d] = TLLazyManualObjectParser(TLCodexModernFoundStickerSetsParser);
    manualObjectParsers[(int32_t)0x2dd14edc] = TLLazyManualObjectParser(TLCodexModernStickerSetMetaParser);
    manualObjectParsers[(int32_t)0xd3f924eb] = TLLazyManualObjectParser(TLCodexModernStickerSetParser);
    manualObjectParsers[(int32_t)0x6319d612] = TLLazyManualObjectParser(TLCodexModernDocumentAttributeStickerParser);
    manualObjectParsers[(int32_t)0xffb62b95] = TLLazyManualObjectParser(TLCodexModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x9de7a269] = TLLazyManualObjectParser(TLCodexModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x861cc8a0] = TLLazyManualObjectParser(TLCodexModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x028703c8] = TLLazyManualObjectParser(TLCodexModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0xe67f520e] = TLLazyManualObjectParser(TLCodexModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0xcde3739] = TLLazyManualObjectParser(TLCodexModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0xc88b3b02] = TLLazyManualObjectParser(TLCodexModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x04c4d4ce] = TLLazyManualObjectParser(TLCodexModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x29d0f5ee] = TLLazyManualObjectParser(TLCodexModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x44c1f8e9] = TLLazyManualObjectParser(TLCodexModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x49748553] = TLLazyManualObjectParser(TLCodexModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x1cf671a0] = TLLazyManualObjectParser(TLCodexModernInputStickerSetParser);
    addHashToString((int32_t)0x6cdf9cef, @"stickerPack");
    addHashToString((int32_t)0x2dd14edc, @"stickerSet");
    addHashToString((int32_t)0x88d37c56, @"messages.recentStickers");
    addHashToString((int32_t)0xbe382906, @"messages.featuredStickers");
    addHashToString((int32_t)0x8af09dd2, @"messages.foundStickerSets");
    addHashToString((int32_t)0x6319d612, @"documentAttributeSticker");
    manualObjectParsers[(int32_t)0xb434e2b8] = TLLazyManualObjectParser(TLCodexModernExportedAuthorizationParser);
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x6fa68e41, TLLazyManualObjectParser(TLUpdate$updateReadFeed)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xe09e1fb8, TLLazyManualObjectParser(TLhelp_ProxyData$proxyDataEmpty)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x2bf7ee23, TLLazyManualObjectParser(TLhelp_ProxyData$proxyDataPromo)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x780a0310, TLLazyManualObjectParser(TLhelp_TermsOfService$help_termsOfService)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x187fa0ca, TLLazyManualObjectParser(TLSecureValue$secureValue)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xdb21d0a7, TLLazyManualObjectParser(TLInputSecureValue$inputSecureValue)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xad2e1cd8, TLLazyManualObjectParser(TLaccount_AuthorizationForm$account_authorizationForm)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xaf509d20, TLLazyManualObjectParser(TLPeerNotifySettings$peerNotifySettings)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x6a4ee832, TLLazyManualObjectParser(TLhelp_DeepLinkInfo$help_deepLinkInfo)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x1b0c841a, TLLazyManualObjectParser(TLCodexModernDraftMessageEmptyParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x1da7158f, TLLazyManualObjectParser(TLhelp_AppUpdate$help_appUpdate)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xad2641f8, TLLazyManualObjectParser(TLaccount_Password$account_password)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x957b50fb, TLLazyManualObjectParser(TLaccount_Password$account_password)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x9a5c33e5, TLLazyManualObjectParser(TLaccount_PasswordSettings$account_passwordSettings)));

    manualObjectParsers[(int32_t)0x80e11a7f] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xffa00ccc] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xc624b16e] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xb91bbd3a] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x48e91302] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x31c48347] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xa80f51e4] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x87e2f155] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xb00c47a2] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xea2c31d3] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xe6c31522] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xac1f1fcd] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x84b88578] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x2ffe2f7a] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xcc7c5c89] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xc7edbc83] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xee7a1596] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x95ddcf69] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x69f916f8] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xa8a3c699] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x2c8f2a25] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x774278d4] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x73ada76b] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xb07ed085] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xe188503b] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xbf7d6572] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x3e2793ba] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x9da1cd6c] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x399674dc] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x16605e3e] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0xd7c0ff9c] = TLLazyManualObjectParser(TLUser$modernUser);
    manualObjectParsers[(int32_t)0x020b1422] = TLLazyManualObjectParser(TLUser$modernUser);
    manualObjectParsers[(int32_t)0xd8aa840f] = TLLazyManualObjectParser(TLCodexInputGroupCallParser);
    manualObjectParsers[(int32_t)0x6880b94d] = TLLazyManualObjectParser(TLCodexPeerSettingsContainerParser);
    manualObjectParsers[(int32_t)0xacd66c5e] = TLLazyManualObjectParser(TLCodexModernPeerSettingsParser);
    manualObjectParsers[(int32_t)0xcc02aa6d] = TLLazyManualObjectParser(TLCodexModernMessageActionParser);
    manualObjectParsers[(int32_t)0x83314fca] = TLLazyManualObjectParser(TLUser$modernUser);
    manualObjectParsers[(int32_t)0x2813e6db] = TLLazyManualObjectParser(TLUser$modernUser);
    manualObjectParsers[(int32_t)0x1afeb7ac] = TLLazyManualObjectParser(TLUser$modernUser);
    manualObjectParsers[(int32_t)0xd0a1d008] = TLLazyManualObjectParser(TLUser$modernUser);
    manualObjectParsers[(int32_t)0x145ade0b] = TLLazyManualObjectParser(TLCodexModernContactParser);
    manualObjectParsers[(int32_t)0xeae87e42] = TLLazyManualObjectParser(TLCodexModernContactsParser);
    manualObjectParsers[(int32_t)0x0ade1591] = TLLazyManualObjectParser(TLCodexModernBlockedParser);
    manualObjectParsers[(int32_t)0xe1664194] = TLLazyManualObjectParser(TLCodexModernBlockedParser);
    manualObjectParsers[(int32_t)0xe8fd8014] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x211a1788] = TLLazyManualObjectParser(TLCodexModernWebPageEmptyParser);
    manualObjectParsers[(int32_t)0xe89c45b2] = TLLazyManualObjectParser(TLCodexModernWebPageParser);
    manualObjectParsers[(int32_t)0xddf10c3b] = TLLazyManualObjectParser(TLCodexModernMessageMediaWebPageParser);
    manualObjectParsers[(int32_t)0xb53e8b21] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x8c9a88ac] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x3f7ee58b] = TLLazyManualObjectParser(TLCodexModernMessageMediaDiceParser);
    manualObjectParsers[(int32_t)0x08cbec07] = TLLazyManualObjectParser(TLCodexModernMessageMediaDiceParser);
    manualObjectParsers[(int32_t)0x4bd6e798] = TLLazyManualObjectParser(TLCodexModernMessageMediaPollParser);
    manualObjectParsers[(int32_t)0xb2a2f663] = TLLazyManualObjectParser(TLCodexModernGeoPointSkipParser);
    manualObjectParsers[(int32_t)0x4e4df4bb] = TLLazyManualObjectParser(TLCodexModernMessageFwdHeaderParser);
    manualObjectParsers[(int32_t)0xdc7b1140] = TLLazyManualObjectParser(TLCodexModernMessageEntityMentionNameParser);
    manualObjectParsers[(int32_t)0xc8cf05f8] = TLLazyManualObjectParser(TLCodexModernMessageEntityCustomEmojiParser);
    manualObjectParsers[(int32_t)0x9c4e7e8b] = TLLazyManualObjectParser(TLCodexModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0xbf0693d4] = TLLazyManualObjectParser(TLCodexModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x761e6af4] = TLLazyManualObjectParser(TLCodexModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x32ca960f] = TLLazyManualObjectParser(TLCodexModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0xf1ccaaac] = TLLazyManualObjectParser(TLCodexModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x904ac7c7] = TLLazyManualObjectParser(TLCodexModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x71777116] = TLLazyManualObjectParser(TLCodexModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0xc6c1e5a7] = TLLazyManualObjectParser(TLCodexModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x0652c1c5] = TLLazyManualObjectParser(TLCodexModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x6c622f67] = TLLazyManualObjectParser(TLCodexModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x751f3146] = TLLazyManualObjectParser(TLCodexTextWithEntitiesParser);
    manualObjectParsers[(int32_t)0x58747131] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xff16e2ca] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x7adf2420] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xf8227181] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xebe07752] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x20529438] = TLLazyManualObjectParser(TLCodexModernUpdateUserParser);
    manualObjectParsers[(int32_t)0x635b4c09] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x6c8e1e06] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x3b6ddad2] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xd38ff1c2] = TLLazyManualObjectParser(TLCodexModernDocumentAttributeVideoD38Parser);
    manualObjectParsers[(int32_t)0xeeca5ce3] = TLLazyManualObjectParser(TLCodexModernLangPackLanguageParser);
    manualObjectParsers[(int32_t)0x17399fad] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xfd149899] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x6a7e7366] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x98657f0d] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xde33b094] = TLLazyManualObjectParser(TLCodexModernPhotoSizeParser);
    manualObjectParsers[(int32_t)0xf85c413c] = TLLazyManualObjectParser(TLCodexModernPhotoSizeParser);
    manualObjectParsers[(int32_t)0x0da082fe] = TLLazyManualObjectParser(TLCodexModernPhotoSizeParser);
    manualObjectParsers[(int32_t)0x1759c560] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x8c88c923] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x7c8fe7b6] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x39f23300] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xa8718dc5] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xf259a80b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x65a0fa4d] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x031f9590] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xef1751b5] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x804361ea] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1e148390] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xbf4dea82] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x76768bed] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x16115a96] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xa44f3ef6] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x25e073fc] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xe4e88011] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb92fb6cd] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9a8ae1e1] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x5e068047] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x98dd8936] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x6f747657] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xdc3d824f] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0x744694e0] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0x6724abc4] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0xd912a59c] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0xc12622c4] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0x9bf8bb95] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0x6c3f19b9] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0x3c2884c1] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0xde5a0dd6] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0x7e6260d7] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0xed6a8504] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0xc7fb5e01] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0x034b8621] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0x1ccb966a] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0x081ccf4f] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);
    manualObjectParsers[(int32_t)0x35553762] = TLLazyManualObjectParser(TLCodexRichTextSkipParser);

    manualObjectParsers[(int32_t)0x2633421b] = TLLazyManualObjectParser(TLCodexModernChannelFullParser);
    manualObjectParsers[(int32_t)0x3ded6320] = TLLazyManualObjectParser(TLCodexModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x56e0d474] = TLLazyManualObjectParser(TLCodexModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x70322949] = TLLazyManualObjectParser(TLCodexModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x9f84f49e] = TLLazyManualObjectParser(TLCodexModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x2ec0533f] = TLLazyManualObjectParser(TLCodexModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0xfdb19008] = TLLazyManualObjectParser(TLCodexModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0xf6a548d3] = TLLazyManualObjectParser(TLCodexModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x773f4e66] = TLLazyManualObjectParser(TLCodexModernMessageMediaPollParser);
    manualObjectParsers[(int32_t)0xaa073beb] = TLLazyManualObjectParser(TLCodexModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0xceaa3ea1] = TLLazyManualObjectParser(TLCodexModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0xa8852491] = TLLazyManualObjectParser(TLCodexModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x8a53b014] = TLLazyManualObjectParser(TLCodexModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0xca5cab89] = TLLazyManualObjectParser(TLCodexModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x904dd49c] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xac21d3ce] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x09cb7759] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x8ae5c97a] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9ddb347c] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x07df587c] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xa02a982e] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1ea2fda7] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xa584b019] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x283bd312] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x8b725fce] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x77b0e372] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xa4a79376] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9f812b08] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x683b2c52] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xdef143d0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xfb9c547a] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x54b56617] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x7781fe18] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb98cd696] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x72c64955] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xab339c00] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9f27d26e] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xe477092e] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xd3656499] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xa2c0f695] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xe7ff068a] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x7184603b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x07141dbf] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xac5c1af7] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x21108ff7] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xe519abab] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xc9b9e2b9] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xc3f2f501] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xcc4d9ecc] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xef156a5c] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1b0e4f07] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x4b3e14d6] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x8f34b2f5] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xfebe5491] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x206ad49e] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1f0c1ad9] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xdc6cfcf0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xad628cc8] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xee479c64] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xcba9a52f] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x49b92a26] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x221bb5e4] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xcae68768] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xfd5e12bd] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x257e962b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xeb983f8f] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x4367daa0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xe175e66f] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb2539d54] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9a9d77e0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x86f8613c] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xc448415c] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9ae228e2] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x4959427a] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xe7058e7f] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x8a480e27] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x50cd067c] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1f2bf4a] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xedf3add0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x93037e20] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb8ea86a9] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x26219a58] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x767d61eb] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xadec6ebe] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x2ba1f5ce] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x00f8ed08] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x64407ea7] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xf83ae221] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x44ba9dd9] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xc01f6fe8] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xcb6ff828] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x889b59ef] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x3259950a] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x3bb842ac] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x2aee9191] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x6f8b32aa] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x0194cb3b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x832175e0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x033ed001] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x17d7f87b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x09c469cd] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xc4e5921e] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb88cf373] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1d998733] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x114ff30d] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x628c9224] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb4ae666f] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xec43a2d1] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9a23af21] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x93c3e27e] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xd1ed9a5b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xbddb616e] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb89bfccf] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x95f2bfe4] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb457b375] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x7b560a0b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x250dbaf8] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xe92fd902] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xd80da15d] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x60682812] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xf9677aad] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x0bd915c0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x13659eb0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x6c9ce8ed] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x6c207376] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1dab80b7] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x394e7f21] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x5e0589f1] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x5416d58] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x2e6eab1a] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x94ce852a] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x54236209] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xdd0c66f2] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x19a13f71] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x98d5ea1d] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb4d5d859] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xf93cd45c] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1e109708] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xe581e4e9] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb4f67e93] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xa0624cf7] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xc69708d3] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xea32b4b1] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xeb032884] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xc387c04e] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xe7e82e12] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x0e8e37e5] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9325705a] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xc3987a3a] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x374fa7ad] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xd5e58274] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x87e5dfe4] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1a8afc7e] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xee430c85] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9d1dbd26] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xda2ad647] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x59e65335] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x44e56023] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x90d7adfa] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xcff63ea9] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9bad6414] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xc1f46103] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x6c9d0efe] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xf1d628ec] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x933ca597] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x79eb8cb3] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xbaf39d8b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x7dbf8673] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xffda656d] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1839490f] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x31bd492d] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xc077ec01] = TLLazyManualObjectParser(TLCodexAvailableReactionParser);
    manualObjectParsers[(int32_t)0x9f071957] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x768e3aad] = TLLazyManualObjectParser(TLCodexAvailableReactionsParser);
    manualObjectParsers[(int32_t)0xd08ce645] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x90c467d1] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb06fdbdf] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xeafdf716] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x5f2d1df2] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb81c7034] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x367617d3] = TLLazyManualObjectParser(TLCodexForumTopicsParser);
    manualObjectParsers[(int32_t)0x5fb5523b] = TLLazyManualObjectParser(TLCodexDialogFilterParser);
    manualObjectParsers[(int32_t)0x7438f7e8] = TLLazyManualObjectParser(TLCodexDialogFilterParser);
    manualObjectParsers[(int32_t)0x363293ae] = TLLazyManualObjectParser(TLCodexDialogFilterParser);
    manualObjectParsers[(int32_t)0x9fe28ea4] = TLLazyManualObjectParser(TLCodexDialogFilterParser);
    manualObjectParsers[(int32_t)0xaa472651] = TLLazyManualObjectParser(TLCodexDialogFilterParser);
    manualObjectParsers[(int32_t)0x96537bd7] = TLLazyManualObjectParser(TLCodexDialogFilterParser);
    manualObjectParsers[(int32_t)0x2ad93719] = TLLazyManualObjectParser(TLCodexDialogFiltersParser);
    manualObjectParsers[(int32_t)0x26ffde7d] = TLLazyManualObjectParser(TLCodexDialogFilterUpdateParser);
    manualObjectParsers[(int32_t)0x43b46b20] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x481eadfa] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x7a1e11d1] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x7a9abda9] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x80d26cc7] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x093bcf34] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x6fb4ad87] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x881fb94b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xa26156c0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xc556a45d] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9e84bc99] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x2f2f21bf] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x0bb2d201] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x31c24808] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb23fc698] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x9d2216e0] = TLLazyManualObjectParser(TLCodexUpdateGroupCallParser);
    manualObjectParsers[(int32_t)0xf2ebdb4e] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x2a3dc7ac] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xeba636fe] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x67753ac8] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xdcb118b7] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xbb9bb9a5] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1e297bfa] = TLLazyManualObjectParser(TLCodexUpdateMessageReactionsParser);
    manualObjectParsers[(int32_t)0xaca1657b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x86e18161] = TLLazyManualObjectParser(TLCodexPollParser);
    manualObjectParsers[(int32_t)0xb8425be9] = TLLazyManualObjectParser(TLCodexPollParser);
    manualObjectParsers[(int32_t)0x966e2dbf] = TLLazyManualObjectParser(TLCodexPollParser);
    manualObjectParsers[(int32_t)0x6ca9c2e9] = TLLazyManualObjectParser(TLCodexPollAnswerParser);
    manualObjectParsers[(int32_t)0x4b7d786a] = TLLazyManualObjectParser(TLCodexPollAnswerParser);
    manualObjectParsers[(int32_t)0x3645230a] = TLLazyManualObjectParser(TLCodexPollAnswerVotersParser);
    manualObjectParsers[(int32_t)0x7adf2420] = TLLazyManualObjectParser(TLCodexPollResultsParser);
    manualObjectParsers[(int32_t)0xba7bb15e] = TLLazyManualObjectParser(TLCodexPollResultsParser);
    manualObjectParsers[(int32_t)0xfa0f3ca2] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xfb4c496c] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x28373599] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x30f443db] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x07b68920] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x39c67432] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xa477288f] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x8c0f91fb] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x140502d1] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xd90d8dfe] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xcfb9d957] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x5334759c] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x4345be73] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x527d22eb] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xbbf51685] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x922e55a9] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xdb909ec2] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x96d074fd] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x2b96cd1b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xe1bb0d61] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x3fc9053b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x6ebdff91] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xbac3a61a] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x4b9e22a0] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x71e4ea58] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x98613ebf] = sharedSkipObjectParser;

    TLMetaSchemeAppendEntry(entries.params, entries.types, (int32_t)0xae500895, "futuresalts", "FutureSalts", TLMetaSchemeFutureSaltsParams, sizeof(TLMetaSchemeFutureSaltsParams) / sizeof(TLMetaSchemeFutureSaltsParams[0]));
    TLMetaSchemeAppendEntry(entries.params, entries.methods, (int32_t)0x19c2f763, "updates.getDifference", "updates.Difference", TLMetaSchemeGetDifferenceParams, sizeof(TLMetaSchemeGetDifferenceParams) / sizeof(TLMetaSchemeGetDifferenceParams[0]));
    

    materializeLazyScheme();
    TLMetaSchemeLazyStore *store = TLMetaSchemeBuildLazyStore(entries, schemeMethodsCount, vectorElementTypesByConstructor, constructorsByName);
    for (TLMetaSchemeIndex::const_iterator it = store->signatureIndex.begin(); it != store->signatureIndex.end(); ++it)
        constructorsBySignature.erase(it->first);
    for (TLMetaSchemeIndex::const_iterator it = store->nameIndex.begin(); it != store->nameIndex.end(); ++it)
        constructorsByName.erase(it->first);
    TLMetaClassStoreLazyStore = store;
    if (materialize)
        materializeLazyScheme();
    
}

id TLMetaClassStore::constructObject(NSInputStream *is, int32_t signature, id<TLSerializationEnvironment> environment, TLSerializationContext *context, __autoreleasing NSError **error)
{
    TLConstructedValue value = constructValue(is, signature, environment, context, error);
    id result = nil;
    if (error == nil || *error == nil)
    {
        switch (value.type)
        {
            case TLConstructedValueTypeObject:
            case TLConstructedValueTypeString:
            case TLConstructedValueTypeBytes:
            case TLConstructedValueTypeVector:
                result = value.nativeObject;
                break;
            case TLConstructedValueTypePrimitiveInt32:
                result = [NSNumber numberWithInt:value.primitive.int32Value];
                break;
            case TLConstructedValueTypePrimitiveInt64:
                result = [NSNumber numberWithLongLong:value.primitive.int64Value];
                break;
            case TLConstructedValueTypePrimitiveDouble:
                result = [NSNumber numberWithDouble:value.primitive.doubleValue];
                break;
            case TLConstructedValueTypePrimitiveBool:
                result = [NSNumber numberWithBool:value.primitive.boolValue];
                break;
            default:
                break;
        }
    }

    return result;
}

TLConstructedValue TLMetaClassStore::constructValue(NSInputStream *is, int32_t signature, id<TLSerializationEnvironment> environment, TLSerializationContext *context, __autoreleasing NSError **error)
{
    TGTLParserSignatureScope parserSignatureScope(signature);
    if (signature == 0x3072cfa1)
    {
        NSData *packedData = [is readBytes];
        NSData *unpackedData = [packedData decompressGZip];
        if (unpackedData == nil)
        {
            if (error != NULL)
            {
                NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
                [userInfo setValue:@"Couldn't unpack gzipped data" forKey:NSLocalizedDescriptionKey];
                *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:userInfo];
            }
            return TLConstructedValue();
        }
        
        
        NSInputStream *unpackedIs = [NSInputStream inputStreamWithData:unpackedData];
        [unpackedIs open];
        int32_t unpackedSignature = [unpackedIs readInt32];
        TLConstructedValue result = constructValue(unpackedIs, unpackedSignature, environment, context, error);
        [unpackedIs close];
        
        return result;
    }
    
    switch (signature)
    {
        case TL_INT32_CONSTRUCTOR:
        {
            TLConstructedValue result;
            result.type = TLConstructedValueTypePrimitiveInt32;
            result.primitive.int32Value = [is readInt32];
            return result;
        }
        case TL_INT64_CONSTRUCTOR:
        {
            TLConstructedValue result;
            result.type = TLConstructedValueTypePrimitiveInt64;
            result.primitive.int64Value = [is readInt64];
            return result;
        }
        case TL_INT128_CONSTRUCTOR:
        {
            TLConstructedValue result;
            result.type = TLConstructedValueTypeBytes;
            NSData *data = [is readData:16];
            result.nativeObject = data;
            return result;
        }
        case TL_INT256_CONSTRUCTOR:
        {
            TLConstructedValue result;
            result.type = TLConstructedValueTypeBytes;
            NSData *data = [is readData:32];
            result.nativeObject = data;
            return result;
        }
        case TL_STRING_CONSTRUCTOR:
        {
            TLConstructedValue result;
            result.type = TLConstructedValueTypeString;
            NSString *data = [is readString];
            result.nativeObject = data;
            return result;
        }
        case TL_BYTES_CONSTRUCTOR:
        {
            TLConstructedValue result;
            result.type = TLConstructedValueTypeBytes;
            NSData *data = [is readBytes];
            result.nativeObject = data;
            return result;
        }
        case TL_DOUBLE_CONSTRUCTOR:
        {
            TLConstructedValue result;
            result.type = TLConstructedValueTypePrimitiveDouble;
            result.primitive.doubleValue = [is readDouble];
            return result;
        }
        case TL_BOOL_TRUE_CONSTRUCTOR:
        {
            TLConstructedValue result;
            result.type = TLConstructedValueTypePrimitiveBool;
            result.primitive.boolValue = true;
            return result;
        }
        case TL_BOOL_FALSE_CONSTRUCTOR:
        {
            TLConstructedValue result;
            result.type = TLConstructedValueTypePrimitiveBool;
            result.primitive.boolValue = false;
            return result;
        }
        case TL_NULL_CONSTRUCTOR:
        {
            TLConstructedValue result;
            result.type = TLConstructedValueTypeObject;
            result.nativeObject = nil;
            return result;
        }
        default:
            break;
    }
    
    if (signature == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
    {
        if (context != nil)
        {
            if (context.impliedSignature != 0)
                signature = context.impliedSignature;
            else
            {
                int32_t count = [is readInt32];
                NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)MAX(0, count)];
                for (int32_t i = 0; i < count; i++)
                {
                    int32_t itemSignature = [is readInt32];
                    id object = TLMetaClassStore::constructObject(is, itemSignature, environment, nil, error);
                    if (object != nil)
                        [array addObject:object];
                    if (error != NULL && *error != nil)
                    {
                        break;
                    }
                }
                TLConstructedValue result;
                result.type = TLConstructedValueTypeVector;
                result.nativeObject = array;
                return result;
            }
        }
        else
        {
            int32_t count = [is readInt32];
            NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)MAX(0, count)];
            for (int32_t i = 0; i < count; i++)
            {
                int32_t itemSignature = [is readInt32];
                id object = TLMetaClassStore::constructObject(is, itemSignature, environment, nil, error);
                if (object != nil)
                    [array addObject:object];
                if (error != NULL && *error != nil)
                {
                    break;
                }
            }
            TLConstructedValue result;
            result.type = TLConstructedValueTypeVector;
            result.nativeObject = array;
            return result;
        }
    }
    
    if (signature == (int32_t)0xc5226f17)
    {
        int32_t flags = [is readInt32];
        int64_t callId = [is readInt64];
        int64_t accessHash = [is readInt64];
        int32_t date = [is readInt32];
        int64_t adminId = [is readInt64];
        int64_t participantId = [is readInt64];
        int32_t protocolSignature = [is readInt32];

        TLConstructedValue protocolValue = TLMetaClassStore::constructValue(is,
                                                                            protocolSignature,
                                                                            environment,
                                                                            nil,
                                                                            error);
        if (error != NULL && *error != nil)
            return TLConstructedValue();

        TLPhoneCall$phoneCallWaitingMeta *object = [[TLPhoneCall$phoneCallWaitingMeta alloc] init];
        object.flags = flags;
        object.n_id = callId;
        object.access_hash = accessHash;
        object.date = date;
        object.admin_id = TGModernLegacyIdForModernId(adminId);
        object.participant_id = TGModernLegacyIdForModernId(participantId);
        object.protocol = protocolValue.nativeObject;
        object.receive_date = (flags & (1 << 0)) != 0 ? [is readInt32] : 0;

        TLConstructedValue result;
        result.type = TLConstructedValueTypeObject;
        result.nativeObject = object;

        return result;
    }

    id<TLObject> parser = nil;
    bool hasManualParser = false;
    {
        TGTLClassRegistryGuard guard;
        std::map<int32_t, TLManualObjectParser>::iterator manualIt = manualObjectParsers.find(signature);
        if (manualIt != manualObjectParsers.end())
        {
            if (manualIt->second.parser == nil)
                manualIt->second.parser = TLInstantiateManualObjectParser(manualIt->second.parserClassName);
            parser = manualIt->second.parser;
            hasManualParser = parser != nil;
        }
    }
    if (hasManualParser)
    {
        id<TLObject> result = nil;
        int32_t previousManualSignature = CodexCurrentManualSignature;
        NSString *previousManualParser = CodexCurrentManualParser;
        CodexCurrentManualSignature = signature;
        CodexCurrentManualParser = NSStringFromClass([parser class]);
        @try
        {
            result = [parser TLdeserialize:is signature:signature environment:environment context:nil error:error];
        }
        @catch (NSException *exception)
        {
            CodexCurrentManualSignature = previousManualSignature;
            CodexCurrentManualParser = previousManualParser;
            if (error != NULL)
            {
                NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
                [userInfo setValue:[NSString stringWithFormat:@"Exception while parsing 0x%08x with %@: %@", signature, NSStringFromClass([parser class]), exception.reason] forKey:NSLocalizedDescriptionKey];
                *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:userInfo];
            }
            return TLConstructedValue();
        }
        if (error && *error != nil)
        {
            NSString *parserName = NSStringFromClass([parser class]);
            NSString *underlyingDescription = (*error).localizedDescription ?: @"TL parse failed";
            NSString *safeDescription = [NSString stringWithFormat:@"Manual parser %@ failed for constructor %08x: %@", parserName, signature, underlyingDescription];
            NSError *safeError = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: safeDescription}];
            *error = safeError;
            CodexCurrentManualSignature = previousManualSignature;
            CodexCurrentManualParser = previousManualParser;
            return TLConstructedValue();
        }
        if (result == nil && [parser isKindOfClass:[TLCodexSkipObjectParser class]])
        {
            std::tr1::shared_ptr<TLMetaConstructor> constructor = getConstructorBySignature(signature);
            if (constructor && constructor->getResultType() && constructor->getResultType()->getName() == murMurHash32(@"Update"))
            {
                TLCodexIgnoredUpdate *ignoredUpdate = [[TLCodexIgnoredUpdate alloc] init];
                ignoredUpdate.ignoredSignature = signature;
                result = ignoredUpdate;
            }
        }
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = result;

        CodexLastCompletedManualSignature = signature;
        CodexLastCompletedManualParser = NSStringFromClass([parser class]);
        
        CodexCurrentManualSignature = previousManualSignature;
        CodexCurrentManualParser = previousManualParser;
        return value;
    }
    
    std::tr1::shared_ptr<TLMetaConstructor> constructor = getConstructorBySignature(signature);
    
    if (!constructor)
    {
        TLMetaTypeArgument vectorElementType;
        bool hasVectorElementType = false;
        {
            TGTLClassRegistryGuard guard;
            std::tr1::unordered_map<int32_t, TLMetaTypeArgument>::iterator it = vectorElementTypesByConstructor.find(signature);
            if (it != vectorElementTypesByConstructor.end())
            {
                vectorElementType = it->second;
                hasVectorElementType = true;
            }
        }
        if (hasVectorElementType)
        {
            id<TLVector> vectorClass = getVectorClass(signature);
            int32_t count = [is readInt32];

            NSMutableArray *array = nil;
            if (vectorClass != nil)
                array = [vectorClass TLvectorConstruct];
            else
                array = [[NSMutableArray alloc] init];
            
            TLConstructedValue result;
            result.type = TLConstructedValueTypeVector;
            
            for (int32_t i = 0; i < count; i++)
            {
                int itemSignature = 0;
                if (vectorElementType.boxed)
                    itemSignature = [is readInt32];
                else
                    itemSignature = vectorElementType.unboxedConstructorSignature;
                
                TLConstructedValue itemValue = constructValue(is, itemSignature, environment, nil, error);
                if (error != nil && *error != nil)
                {
                    return TLConstructedValue();
                }
                
                id nativeValue = nil;
                
                switch (itemValue.type)
                {
                    case TLConstructedValueTypePrimitiveInt32:
                        nativeValue = [[NSNumber alloc] initWithInt:itemValue.primitive.int32Value];
                        break;
                    case TLConstructedValueTypePrimitiveInt64:
                        nativeValue = [[NSNumber alloc] initWithLongLong:itemValue.primitive.int64Value];
                        break;
                    case TLConstructedValueTypePrimitiveBool:
                        nativeValue = [[NSNumber alloc] initWithBool:itemValue.primitive.boolValue];
                        break;
                    case TLConstructedValueTypePrimitiveDouble:
                        nativeValue = [[NSNumber alloc] initWithDouble:itemValue.primitive.doubleValue];
                        break;
                    case TLConstructedValueTypeObject:
                        nativeValue = itemValue.nativeObject;
                        break;
                    case TLConstructedValueTypeString:
                        nativeValue = itemValue.nativeObject;
                        break;
                    case TLConstructedValueTypeBytes:
                        nativeValue = itemValue.nativeObject;
                        break;
                    case TLConstructedValueTypeVector:
                        nativeValue = itemValue.nativeObject;
                        break;
                    default:
                        break;
                }
                
                if (nativeValue != nil)
                    [array addObject:nativeValue];
            }
            
            result.nativeObject = array;
            
            return result;
        }
        else
        {
            if (error != NULL)
            {
#if defined(DEBUG) || defined(INTERNAL_RELEASE)

#endif
                NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
                [userInfo setValue:[NSString stringWithFormat:@"Constructor with signature %.8x not found", signature] forKey:NSLocalizedDescriptionKey];
                *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:userInfo];
            }
            return TLConstructedValue();
        }
    }
    
    @try
    {
        TLConstructedValue result = constructor->construct(is, environment, nil, error);
        if (error != NULL && *error != nil)
        {
        }
        return result;
    }
    @catch (NSException *exception)
    {
        if (error != NULL)
        {
            NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
            [userInfo setValue:[NSString stringWithFormat:@"Exception while auto parsing 0x%08x: %@", signature, exception.reason] forKey:NSLocalizedDescriptionKey];
            *error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:userInfo];
        }
        return TLConstructedValue();
    }
}

void TLMetaClassStore::serializeObject(NSOutputStream *os, id<TLObject> object, bool boxed)
{

    if ([object isKindOfClass:[TLBool class]])
    {
        [os writeInt32:[((TLBool *)object) boolValue] ? TL_BOOL_TRUE_CONSTRUCTOR : TL_BOOL_FALSE_CONSTRUCTOR];
    }
    else if ([object TLconstructorSignature] == 0x3072cfa1)
    {
        if (boxed)
            [os writeInt32:[object TLconstructorSignature]];
        [os writeBytes:((TLCompressedObject *)object).compressedData];
    }
    else if ([object isKindOfClass:[TLMsgsAck class]])
    {
        if (boxed)
            [os writeInt32:[object TLconstructorSignature]];
        
        std::tr1::shared_ptr<TLMetaConstructor> constructor = getConstructorByName([object TLconstructorName]);
        
        std::map<int32_t, TLConstructedValue> fieldValues;
        [object TLfillFieldsWithValues:&fieldValues];
        
        std::vector<TLMetaField>::iterator fieldsEnd = constructor->fields->end();
        for (std::vector<TLMetaField>::iterator it = constructor->fields->begin(); it != fieldsEnd; it++)
        {
            std::map<int32_t, TLConstructedValue>::iterator fieldIt = fieldValues.find(it->name);
            
            if (it->type.boxed)
            {
                [os writeInt32:it->type.unboxedConstructorSignature];
            }
            
            NSArray *array = fieldIt->second.nativeObject;
            [os writeInt32:(int32_t)array.count];
            
            for (id item in array)
            {
                [os writeInt64:[item longLongValue]];
            }
        }
    }
    else
    {
        if ([object TLconstructorName] == -1)
        {
            if (boxed)
                [os writeInt32:[object TLconstructorSignature]];
            [object TLserialize:os];
        }
        else
        {
            std::tr1::shared_ptr<TLMetaConstructor> constructor = getConstructorByName([object TLconstructorName]);
            if (constructor)
            {
                if (boxed)
                    [os writeInt32:constructor->getSignature()];
                constructor->serialize(os, object);
            }
            else
            {
                if ([object isKindOfClass:[TLRPCphone_sendSignalingData class]])
                {
                    TLRPCphone_sendSignalingData *request = (TLRPCphone_sendSignalingData *)object;
                    if (boxed)
                        [os writeInt32:(int32_t)0xff7a9383];
                    TLMetaClassStore::serializeObject(os, request.peer, true);
                    [os writeBytes:request.data];
                }
                else
                {
                    TGLog(@"***** Constructor with name %.8x not found", [object TLconstructorName]);
                    if (boxed)
                        [os writeInt32:TL_NULL_CONSTRUCTOR];
                }
            }
        }
    }
}
