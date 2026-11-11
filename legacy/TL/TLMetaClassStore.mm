
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

static inline void OGTLCoreCooperateWithInteraction(int32_t index)
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
#import "../../../Telegraph/OGFeatureProbe.h"
#import "../../../Telegraph/TGTLDynamic.h"

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
#import "TLLangPackDifference.h"
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

static std::tr1::unordered_map<int32_t, NSString *> &hashToStringMap = *new std::tr1::unordered_map<int32_t, NSString *>();

std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaConstructor> > &TLMetaClassStore::constructorsBySignature = *new std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaConstructor> >();
std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaConstructor> > &TLMetaClassStore::constructorsByName = *new std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaConstructor> >();
std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaType> > &TLMetaClassStore::typesByName = *new std::tr1::unordered_map<int32_t, std::tr1::shared_ptr<TLMetaType> >();
std::tr1::unordered_map<int32_t, TLMetaTypeArgument> &TLMetaClassStore::vectorElementTypesByConstructor = *new std::tr1::unordered_map<int32_t, TLMetaTypeArgument>();

std::tr1::unordered_map<int32_t, id<TLObject> > &TLMetaClassStore::objectClassesByConstructorNames = *new std::tr1::unordered_map<int32_t, id<TLObject> >();
std::tr1::unordered_map<int32_t, id<TLVector> > &TLMetaClassStore::vectorClassesBySignature = *new std::tr1::unordered_map<int32_t, id<TLVector> >();

std::map<int32_t, TLManualObjectParser> &TLMetaClassStore::manualObjectParsers = *new std::map<int32_t, TLManualObjectParser>();

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
std::map<int32_t, id<TLObject> > &TLMetaClassStore::manualObjectSerializers = *new std::map<int32_t, id<TLObject> >();

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

@interface OGTLThreadContext : NSObject
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

@implementation OGTLThreadContext
@end

static pthread_key_t OGTLCoreThreadContextKey;
static pthread_once_t OGTLCoreThreadContextOnce = PTHREAD_ONCE_INIT;

static void OGTLCoreThreadContextDestroy(void *value)
{
    if (value != NULL)
    {
        OGTLThreadContext *context = (__bridge_transfer OGTLThreadContext *)value;
        (void)context;
    }
}

static void OGTLCoreThreadContextInitialize(void)
{
    pthread_key_create(&OGTLCoreThreadContextKey, OGTLCoreThreadContextDestroy);
}

static OGTLThreadContext *OGTLCoreThreadContextGet(void)
{
    pthread_once(&OGTLCoreThreadContextOnce, OGTLCoreThreadContextInitialize);
    OGTLThreadContext *context = (__bridge OGTLThreadContext *)pthread_getspecific(OGTLCoreThreadContextKey);
    if (context == nil)
    {
        context = [[OGTLThreadContext alloc] init];
        pthread_setspecific(OGTLCoreThreadContextKey, (__bridge_retained void *)context);
    }
    return context;
}

#define OGTLCoreCurrentManualSignature (OGTLCoreThreadContextGet()->currentManualSignature)
#define OGTLCoreCurrentManualParser (OGTLCoreThreadContextGet()->currentManualParser)
#define OGTLCoreLastCompletedManualSignature (OGTLCoreThreadContextGet()->lastCompletedManualSignature)
#define OGTLCoreLastCompletedManualParser (OGTLCoreThreadContextGet()->lastCompletedManualParser)
#define OGTLCoreCurrentVectorRole (OGTLCoreThreadContextGet()->currentVectorRole)
#define OGTLCoreLastReadUpdatesState (OGTLCoreThreadContextGet()->lastReadUpdatesState)

static void addHashToString(int32_t hash, NSString *string)
{
    std::tr1::unordered_map<int32_t, NSString *>::iterator it = hashToStringMap.find(hash);
    if (it != hashToStringMap.end() && [it->second isEqualToString:string])
        return;
    NSString *stored = [string copy];
    hashToStringMap[hash] = stored;
}

static NSString *stringForHash(int32_t hash)
{
    std::tr1::unordered_map<int32_t, NSString *>::iterator it = hashToStringMap.find(hash);
    if (it == hashToStringMap.end())
        return [NSString stringWithFormat:@"#%.8x", hash];
    return it->second;
}

#define OGTLCtor(value) ((int32_t)(value))

static inline int32_t OGTLTakeInt32(NSInputStream *is)
{
    return [is readInt32];
}

static inline int64_t OGTLTakeInt64(NSInputStream *is)
{
    return [is readInt64];
}

static inline double OGTLTakeDouble(NSInputStream *is)
{
    return [is readDouble];
}

static inline NSString *OGTLTakeString(NSInputStream *is)
{
    return [is readString];
}

static inline NSData *OGTLTakeBytes(NSInputStream *is)
{
    return [is readBytes];
}

#define OGTLNewObject(cls) [[cls alloc] init]

static inline NSMutableArray *OGTLCoreMakeArray(int32_t count)
{
    return [[NSMutableArray alloc] initWithCapacity:(NSUInteger)MAX(0, count)];
}

static inline id OGTLCoreBuildObject(NSInputStream *is, int32_t signature, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    return TLMetaClassStore::constructObject(is, signature, environment, NULL, error);
}

static inline bool OGTLCoreIsKind(id object, Class cls)
{
    return [object isKindOfClass:cls];
}

static NSError *OGTLCoreMessageError(NSString *message)
{
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    [info setObject:message forKey:NSLocalizedDescriptionKey];
    return [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:info];
}

static NSDictionary *OGTLChatReactionModeInfo(NSString *mode, NSArray *emojis)
{
    return @{ @"mode": mode, @"emojis": emojis };
}

static inline uint8_t OGTLCoreLeadByte(int32_t word)
{
    return (uint8_t)(word & 0xff);
}

static id<TLObject> OGTLCoreReadObject(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    return TLMetaClassStore::constructObject(is, [is readInt32], environment, nil, error);
}

static inline bool OGTLFlagSet(int32_t flags, int bit)
{
    return (flags & (1 << bit)) != 0;
}

static inline bool OGTLCoreFailed(NSError **error)
{
    return error != NULL && *error != nil;
}

static NSError *OGTLCoreVectorError(NSString *description)
{
    return [NSError errorWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: description}];
}

static void OGTLCoreWrapVectorRoleError(NSString *role, __autoreleasing NSError **error)
{
    if (OGTLCoreFailed(error))
    {
        NSString *description = (*error).localizedDescription ?: @"TL vector parse failed";
        *error = OGTLCoreVectorError([NSString stringWithFormat:@"%@: %@", role ?: @"vector", description]);
    }
}

static void OGTLCoreClearVectorTrace(void)
{
    TGTLParserVectorItemIndex = -1;
    TGTLParserVectorItemCount = 0;
    TGTLParserVectorItemSignature = 0;
}

static bool OGTLCoreVectorCountForMarker(NSInputStream *is, int32_t marker, int32_t *count)
{
    if (marker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
    {
        *count = [is readInt32];
        return true;
    }
    if (marker >= 0 && marker <= 10000)
    {
        *count = marker;
        return true;
    }
    return false;
}

static inline bool OGTLCoreMarkerStartsVector(int32_t marker)
{
    if (marker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
        return true;
    return marker >= 0 && marker <= 10000;
}

static NSArray *OGTLCoreReadObjectVector(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error);
static NSArray *OGTLCoreReadObjectVectorWithMarker(NSInputStream *is, int32_t vectorMarker, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error);
static NSArray *OGTLCoreReadObjectVectorOrSingleWithMarker(NSInputStream *is, int32_t vectorMarker, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error);

enum
{
    OGTLReplyHeaderFormatA = 1,
    OGTLReplyHeaderFormatB = 2,
    OGTLReplyHeaderFormatC = 4,
    OGTLReplyHeaderFormatD = 8
};

typedef struct
{
    int32_t signature;
    uint8_t format;
} OGTLReplyHeaderSignature;

typedef struct
{
    uint8_t bit;
    char kind;
    uint8_t formats;
} OGTLReplyHeaderField;

static const OGTLReplyHeaderSignature OGTLReplyHeaderSignatures[] =
{
    {(int32_t)0xafbc09db, OGTLReplyHeaderFormatA},
    {(int32_t)0x1b97dd66, OGTLReplyHeaderFormatB},
    {(int32_t)0x6917560b, OGTLReplyHeaderFormatC},
    {(int32_t)0xddb5ab75, OGTLReplyHeaderFormatD}
};

static const OGTLReplyHeaderField OGTLReplyHeaderFields[] =
{
    {0, 'o', 15},
    {5, 'o', 15},
    {8, 'o', 15},
    {1, 'i', 15},
    {6, 's', 15},
    {7, 'v', 15},
    {10, 'i', 15},
    {11, 'i', OGTLReplyHeaderFormatB | OGTLReplyHeaderFormatC | OGTLReplyHeaderFormatD},
    {12, 'b', OGTLReplyHeaderFormatB | OGTLReplyHeaderFormatD},
    {14, 'v', OGTLReplyHeaderFormatD}
};

static int32_t OGTLCoreReadReplyHeaderCompat(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t leadSignature = [is readInt32];
    uint8_t format = 0;
    for (size_t i = 0; i < sizeof(OGTLReplyHeaderSignatures) / sizeof(OGTLReplyHeaderSignatures[0]); i++)
    {
        if (OGTLReplyHeaderSignatures[i].signature == leadSignature)
            format = OGTLReplyHeaderSignatures[i].format;
    }
    if (format != 0)
    {
        int32_t flags = [is readInt32];
        int32_t replyId = 0;
        if (OGTLFlagSet(flags, 4))
            replyId = OGTLTakeInt32(is);
        for (size_t i = 0; i < sizeof(OGTLReplyHeaderFields) / sizeof(OGTLReplyHeaderFields[0]); i++)
        {
            const OGTLReplyHeaderField *field = &OGTLReplyHeaderFields[i];
            if (!(flags & (1 << field->bit)) || !(field->formats & format))
                continue;
            switch (field->kind)
            {
                case 'o':
                    OGTLCoreReadObject(is, environment, error);
                    break;
                case 'i':
                    [is readInt32];
                    break;
                case 's':
                    OGTLTakeString(is);
                    break;
                case 'b':
                    OGTLTakeBytes(is);
                    break;
                default:
                    OGTLCoreReadObjectVector(is, environment, error);
                    break;
            }
        }
        return replyId;
    }
    if (leadSignature <= 0 || leadSignature >= 10000000)
    {
        OGTLCoreBuildObject(is, leadSignature, environment, error);
        return 0;
    }
    return leadSignature;
}

static NSArray *OGTLCoreReadObjectVector(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    return OGTLCoreReadObjectVectorWithMarker(is, [is readInt32], environment, error);
}

static NSArray *OGTLCoreReadObjectVectorWithRole(NSInputStream *is, NSString *role, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    NSString *previousRole = OGTLCoreCurrentVectorRole;
    OGTLCoreCurrentVectorRole = role;
    NSArray *result = OGTLCoreReadObjectVector(is, environment, error);
    OGTLCoreWrapVectorRoleError(role, error);
    OGTLCoreCurrentVectorRole = previousRole;
    return result;
}

static NSArray *OGTLCoreReadMaybeDoubleObjectVectorWithMarker(NSInputStream *is, int32_t vectorMarker, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    vectorMarker = vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR ? [is readInt32] : vectorMarker;
    return OGTLCoreReadObjectVectorWithMarker(is, vectorMarker, environment, error);
}

static NSArray *OGTLCoreReadObjectVectorWithMarker(NSInputStream *is, int32_t vectorMarker, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t count = 0;
    if (!OGTLCoreVectorCountForMarker(is, vectorMarker, &count))
    {
        OGTLCoreBuildObject(is, vectorMarker, environment, error);
        if (error != NULL)
            *error = nil;
        return @[];
    }

    NSMutableArray *array = OGTLCoreMakeArray(count);
    for (int32_t i = 0; i < count; i++)
    {
        bool itemFailed(false);
        int32_t objectSignature(0);
        @autoreleasepool
        {
            NSError *itemError;
            objectSignature = OGTLTakeInt32(is);
            if (objectSignature == 0 && OGTLCoreCurrentManualSignature == (int32_t)0x8fd4c4d8)
                continue;
            id object = OGTLCoreBuildObject(is, objectSignature, environment, &itemError);
            if (object != nil)
                [array addObject:object];
            itemFailed = itemError != nil;
        }
        if (!itemFailed)
        {
            OGTLCoreCooperateWithInteraction(i);
            continue;
        }
        if (error != NULL)
            *error = OGTLCoreVectorError([NSString stringWithFormat:@"Vector item %d/%d with signature %08x could not be parsed", i, count, objectSignature]);
        break;
    }
    return array;
}

static NSArray *OGTLCoreFailStrictVector(NSError **error, NSString *description)
{
    if (error != NULL)
        *error = OGTLCoreVectorError(description);
    return nil;
}

static NSArray *OGTLCoreReadStrictObjectVector(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    bool failed = false;
    int32_t vectorMarker = [is readInt32:&failed];
    if (failed || vectorMarker != TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
        return OGTLCoreFailStrictVector(error, failed ? @"Unexpected end of stream while reading vector constructor" : [NSString stringWithFormat:@"Expected vector constructor, got %08x", vectorMarker]);

    int32_t count = [is readInt32:&failed];
    if (failed || count < 0 || count > 100000)
        return OGTLCoreFailStrictVector(error, failed ? @"Unexpected end of stream while reading vector count" : [NSString stringWithFormat:@"Invalid vector count %d", count]);

    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)count];
    TGTLParserVectorItemCount = count;
    for (int32_t i = 0; i < count; i++)
    {
        int32_t objectSignature = [is readInt32:&failed];
        TGTLParserVectorItemIndex = i;
        TGTLParserVectorItemSignature = objectSignature;
        if (failed)
        {
            OGTLCoreClearVectorTrace();
            return OGTLCoreFailStrictVector(error, [NSString stringWithFormat:@"Unexpected end of stream at vector item %d/%d", i, count]);
        }

        NSError *itemError;
        id object = OGTLCoreBuildObject(is, objectSignature, environment, &itemError);
        if (itemError != nil || object == nil)
        {
            OGTLCoreClearVectorTrace();
            if (itemError == nil)
                return OGTLCoreFailStrictVector(error, [NSString stringWithFormat:@"Vector item %d/%d with signature %08x produced no object", i, count, objectSignature]);
            if (error != NULL)
                *error = itemError;
            return nil;
        }
        [array addObject:object];
        OGTLCoreCooperateWithInteraction(i);
    }
    OGTLCoreClearVectorTrace();
    return array;
}

static NSArray *OGTLCoreReadStrictObjectVectorWithRole(NSInputStream *is, NSString *role, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    NSString *previousRole = OGTLCoreCurrentVectorRole;
    OGTLCoreCurrentVectorRole = role;
    NSArray *result = nil;
    @try
    {
        result = OGTLCoreReadStrictObjectVector(is, environment, error);
    }
    @finally
    {
        OGTLCoreCurrentVectorRole = previousRole;
    }
    OGTLCoreWrapVectorRoleError(role, error);
    return result;
}

static NSArray *OGTLCoreReadObjectVectorOrSingle(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    return OGTLCoreReadObjectVectorOrSingleWithMarker(is, [is readInt32], environment, error);
}

static NSArray *OGTLCoreReadObjectVectorOrSingleWithMarker(NSInputStream *is, int32_t vectorMarker, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    if (OGTLCoreMarkerStartsVector(vectorMarker))
        return OGTLCoreReadObjectVectorWithMarker(is, vectorMarker, environment, error);

    id object = OGTLCoreBuildObject(is, vectorMarker, environment, error);
    return object != nil ? @[object] : @[];
}

static void OGTLCoreSkipStringWithFirstWord(NSInputStream *is, int32_t firstWord)
{
    uint8_t firstByte = OGTLCoreLeadByte(firstWord);
    bool extended = firstByte == 254;
    int32_t length = extended ? (int32_t)(((uint32_t)firstWord >> 8) & 0xffffff) : firstByte;
    int32_t remainingBytes = extended ? length : MAX(length - 3, 0);

    uint8_t scratch[256];
    while (0 < remainingBytes)
    {
        int32_t step = MIN(remainingBytes, (int32_t)sizeof(scratch));
        remainingBytes -= step;
        [is read:scratch maxLength:(NSUInteger)step];
    }

    int32_t padding = (4 - (((extended ? 4 : 1) + length) % 4)) % 4;
    if (padding > 0 && (extended || length > 3))
        [is read:scratch maxLength:(NSUInteger)padding];
}

static bool OGTLCoreLooksLikeStringFirstWord(int32_t firstWord)
{
    uint8_t firstByte = OGTLCoreLeadByte(firstWord);
    return firstByte == 254 || (((uint32_t)firstWord) & 0xffff0000U) == 0x6a4a0000U || (firstByte >= 4 && firstByte < 128);
}

static bool OGTLCoreLooksLikeTinyBareDocumentTailWord(int32_t word)
{
    return (uint32_t)word <= 1;
}

static bool OGTLCoreSkipBareDocumentAttributeTailWord(NSInputStream *is, int32_t signature)
{
    switch (signature)
    {
        case OGTLCtor(0x6c37c15c):
            [is readInt32];
            [is readInt32];
            return true;
        case OGTLCtor(0x15590068):
            OGTLTakeString(is);
            return true;
        case OGTLCtor(0x11b58939):
        case OGTLCtor(0x9801d2f7):
            return true;
        default:
            return false;
    }
}

static NSArray *OGTLCoreReadNumberVector(NSInputStream *is, bool wide)
{
    int32_t count = 0;
    if (!OGTLCoreVectorCountForMarker(is, [is readInt32], &count))
        return @[];

    NSMutableArray *array = OGTLCoreMakeArray(count);
    for (int32_t i = 0; i < count; i++)
        [array addObject:wide ? [[NSNumber alloc] initWithLongLong:[is readInt64]] : [[NSNumber alloc] initWithInt:[is readInt32]]];
    return array;
}

static NSArray *OGTLCoreReadInt64Vector(NSInputStream *is)
{
    return OGTLCoreReadNumberVector(is, true);
}

static NSArray *OGTLCoreReadInt32Vector(NSInputStream *is)
{
    return OGTLCoreReadNumberVector(is, false);
}

static void OGTLCoreSkipStringItems(NSInputStream *is, bool bytes)
{
    int32_t count = 0;
    if (!OGTLCoreVectorCountForMarker(is, [is readInt32], &count))
        return;
    for (int32_t i = 0; i < count; i++)
    {
        if (bytes)
            OGTLTakeBytes(is);
        else
            OGTLTakeString(is);
    }
}

static void OGTLCoreSkipStringVector(NSInputStream *is)
{
    OGTLCoreSkipStringItems(is, false);
}

static void OGTLCoreSkipBytesVector(NSInputStream *is)
{
    OGTLCoreSkipStringItems(is, true);
}

enum
{
    OGTLSkipResultNone,
    OGTLSkipResultIgnored,
    OGTLSkipResultIgnoredUnlessFailed
};

typedef struct
{
    int32_t signature;
    const char *layout;
    uint8_t result;
} OGTLSkipLayout;

static const OGTLSkipLayout *OGTLFindSkipLayout(const OGTLSkipLayout *table, size_t count, int32_t signature)
{
    size_t low = 0;
    size_t high = count;
    while (low < high)
    {
        size_t middle = low + (high - low) / 2;
        if (table[middle].signature < signature)
            low = middle + 1;
        else
            high = middle;
    }
    if (low < count && table[low].signature == signature)
        return &table[low];
    return NULL;
}

static void OGTLSkipFieldOfKind(NSInputStream *is, char kind, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    switch (kind)
    {
        case 'i':
            [is readInt32];
            break;
        case 'l':
            OGTLTakeInt64(is);
            break;
        case 's':
            OGTLTakeString(is);
            break;
        case 'b':
            OGTLTakeBytes(is);
            break;
        case 'd':
            OGTLTakeDouble(is);
            break;
        case 'o':
            OGTLCoreReadObject(is, environment, error);
            break;
        case 'v':
            OGTLCoreReadObjectVector(is, environment, error);
            break;
        case 'n':
            OGTLCoreReadInt32Vector(is);
            break;
        case 'm':
            OGTLCoreReadInt64Vector(is);
            break;
        case 't':
            OGTLCoreSkipStringVector(is);
            break;
        default:
            OGTLCoreSkipBytesVector(is);
            break;
    }
}

static void OGTLSkipFlagged(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error, int32_t flags, int bit, char kind)
{
    if (OGTLFlagSet(flags, bit))
        OGTLSkipFieldOfKind(is, kind, environment, error);
}

static void OGTLSkipFields(NSInputStream *is, const char *layout, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t flags = 0;
    for (const char *cursor = layout; *cursor != 0; cursor++)
    {
        if (*cursor >= '0' && *cursor <= '9')
        {
            int32_t bit = 0;
            while (*cursor >= '0' && *cursor <= '9')
                bit = bit * 10 + (*cursor++ - '0');
            cursor++;
            if (!OGTLFlagSet(flags, bit))
                continue;
        }
        if (*cursor == 'f')
            flags = OGTLTakeInt32(is);
        else
            OGTLSkipFieldOfKind(is, *cursor, environment, error);
    }
}

@interface OGTLManualParser : NSObject <TLObject>
@end

@implementation OGTLManualParser

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

@end

@interface OGTLModernPhotoParser : TLPhoto$photo
@end

@implementation OGTLModernPhotoParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernPhotoParser *result = [[OGTLModernPhotoParser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.n_id = [is readInt64];
    result.access_hash = [is readInt64];
    result.file_reference = OGTLTakeBytes(is);
    result.date = [is readInt32];
    result.sizes = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    if (OGTLFlagSet(flags, 1))
    {
        OGTLCoreReadObjectVector(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
    }
    result.dc_id = OGTLTakeInt32(is);

    return result;
}

@end

static NSData *OGTLCoreDecodedStrippedThumbnail(NSData *data)
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
    uint8_t *jpegBytes = (uint8_t *)[result mutableBytes];
    if (jpegBytes == NULL)
        return nil;

    memcpy(jpegBytes, header, sizeof(header));
    if (payloadLength != 0)
        memcpy(jpegBytes + sizeof(header), sourceBytes + 3, payloadLength);
    memcpy(jpegBytes + sizeof(header) + payloadLength, footer, sizeof(footer));

    jpegBytes[164] = sourceBytes[1];
    jpegBytes[166] = sourceBytes[2];
    return result;
}

@interface OGTLModernPhotoSizeParser : TLPhotoSize$photoSizeEmpty
@end

@implementation OGTLModernPhotoSizeParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0xde33b094))
    {
        int32_t flags = [is readInt32];
        NSString *type = OGTLTakeString(is);
        int32_t width = [is readInt32];
        int32_t height = [is readInt32];
        int32_t size = [is readInt32];
        OGTLSkipFlagged(is, environment, error, flags, 0, 'd');

        TLPhotoSize$photoSize *result = OGTLNewObject(TLPhotoSize$photoSize);
        [result setType:type];
        result.w = width;
        result.h = height;
        result.size = size;
        return result;
    }
    
    if (signature == OGTLCtor(0xf85c413c))
    {
        OGTLTakeInt64(is);
        OGTLCoreReadInt32Vector(is);
        return OGTLNewObject(TLPhotoSize$photoSizeEmpty);
    }
    
    if (signature == OGTLCtor(0x0da082fe))
    {
        OGTLCoreReadObject(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        OGTLTakeInt64(is);
        OGTLCoreReadInt32Vector(is);
        return OGTLNewObject(TLPhotoSize$photoSizeEmpty);
    }
    
    NSString *type = OGTLTakeString(is);
    switch (signature)
    {
        case OGTLCtor(0x75c78e60):
        {
            TLPhotoSize$photoSize *result = OGTLNewObject(TLPhotoSize$photoSize);
            [result setType:type];
            result.w = [is readInt32];
            result.h = [is readInt32];
            result.size = OGTLTakeInt32(is);

            return result;
        }
        case OGTLCtor(0x021e1ad6):
        {
            TLPhotoSize$photoCachedSize *result = OGTLNewObject(TLPhotoSize$photoCachedSize);
            [result setType:type];
            result.w = [is readInt32];
            result.h = [is readInt32];
            result.bytes = OGTLTakeBytes(is);

            return result;
        }
        case OGTLCtor(0xe0b0bc2e):
        {
            NSData *strippedData = [is readBytes];
            NSData *decodedData = OGTLCoreDecodedStrippedThumbnail(strippedData);
            if (decodedData != nil)
            {
                const uint8_t *bytes = (const uint8_t *)strippedData.bytes;
                TLPhotoSize$photoCachedSize *result = OGTLNewObject(TLPhotoSize$photoCachedSize);
                [result setType:type];
                result.w = MAX(1, (int)bytes[2]);
                result.h = MAX(1, (int)bytes[1]);
                result.bytes = decodedData;
                return result;
            }
            break;
        }
        case OGTLCtor(0xd8214d41):
            OGTLTakeBytes(is);
            break;
        case OGTLCtor(0xfa3efb95):
        {
            TLPhotoSize$photoSize *result = OGTLNewObject(TLPhotoSize$photoSize);
            [result setType:type];
            result.w = [is readInt32];
            result.h = [is readInt32];
            int32_t vectorMarker = OGTLTakeInt32(is);
            int32_t count = 0;
            OGTLCoreVectorCountForMarker(is, vectorMarker, &count);
            for (int32_t i = 0; i < count; i++)
                result.size = OGTLTakeInt32(is);

            return result;
        }
        default:
            break;
    }
    TLPhotoSize$photoSizeEmpty *result = OGTLNewObject(TLPhotoSize$photoSizeEmpty);
    [result setType:type];
    return result;
}

@end

@interface OGTLModernImportedContactsParser : TLcontacts_ImportedContacts$contacts_importedContacts
@end

@implementation OGTLModernImportedContactsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernImportedContactsParser *result = [[OGTLModernImportedContactsParser alloc] init];
    [result setImported:@[]];
    [result setPopular_invites:@[]];
    [result setRetry_contacts:@[]];
    [result setUsers:@[]];
    if (error != NULL)
        *error = nil;
    return result;
}

@end

@interface OGTLModernGeoPointSkipParser : OGTLManualParser
@end

@implementation OGTLModernGeoPointSkipParser

- (int32_t)TLconstructorSignature
{
    return OGTLCtor(0xb2a2f663);
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    int32_t flags = [is readInt32];
    TLGeoPoint$geoPoint *result = OGTLNewObject(TLGeoPoint$geoPoint);
    result.n_long = OGTLTakeDouble(is);
    result.lat = OGTLTakeDouble(is);
    result.access_hash = [is readInt64];
    OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
    return result;
}

@end

static const OGTLSkipLayout OGTLRichTextSkipLayouts[] =
{
    {(int32_t)0x9bf8bb95, "o", OGTLSkipResultNone},
    {(int32_t)0xc12622c4, "o", OGTLSkipResultNone},
    {(int32_t)0xc7fb5e01, "o", OGTLSkipResultNone},
    {(int32_t)0xd912a59c, "o", OGTLSkipResultNone},
    {(int32_t)0xdc3d824f, "", OGTLSkipResultNone},
    {(int32_t)0xde5a0dd6, "os", OGTLSkipResultNone},
    {(int32_t)0xed6a8504, "o", OGTLSkipResultNone},
    {(int32_t)0x034b8621, "o", OGTLSkipResultNone},
    {(int32_t)0x081ccf4f, "lii", OGTLSkipResultNone},
    {(int32_t)0x1ccb966a, "os", OGTLSkipResultNone},
    {(int32_t)0x35553762, "os", OGTLSkipResultNone},
    {(int32_t)0x3c2884c1, "osl", OGTLSkipResultNone},
    {(int32_t)0x6724abc4, "o", OGTLSkipResultNone},
    {(int32_t)0x6c3f19b9, "o", OGTLSkipResultNone},
    {(int32_t)0x744694e0, "s", OGTLSkipResultNone},
    {(int32_t)0x7e6260d7, "v", OGTLSkipResultNone}
};

@interface OGTLRichTextSkipParser : OGTLManualParser
@end

@implementation OGTLRichTextSkipParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    const OGTLSkipLayout *skipLayout = OGTLFindSkipLayout(OGTLRichTextSkipLayouts, sizeof(OGTLRichTextSkipLayouts) / sizeof(OGTLRichTextSkipLayouts[0]), signature);
    if (skipLayout != NULL)
        OGTLSkipFields(is, skipLayout->layout, environment, error);
    return nil;
}

@end

@interface OGTLModernConfigParser : TLConfig$config
@end

@implementation OGTLModernConfigParser

- (int32_t)TLconstructorSignature
{
    return OGTLCtor(0xcc1a241e);
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLConfig$config *result = [[TLConfig$config alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.date = [is readInt32];
    result.expires = [is readInt32];
    TLBool *testMode = (TLBool *)OGTLCoreReadObject(is, environment, error);
    [result setTest_mode:[testMode respondsToSelector:@selector(boolValue)] ? [testMode boolValue] : false];
    result.this_dc = [is readInt32];
    result.dc_options = OGTLCoreReadObjectVector(is, environment, error);
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
    if (OGTLFlagSet(flags, 0))
        result.tmp_sessions = [is readInt32];
    result.call_receive_timeout_ms = [is readInt32];
    result.call_ring_timeout_ms = [is readInt32];
    result.call_connect_timeout_ms = [is readInt32];
    result.call_packet_timeout_ms = [is readInt32];
    result.me_url_prefix = [is readString];
    if (OGTLFlagSet(flags, 7))
        result.autoupdate_url_prefix = [is readString];
    if (OGTLFlagSet(flags, 9))
        result.gif_search_username = [is readString];
    if (OGTLFlagSet(flags, 10))
        result.venue_search_username = [is readString];
    if (OGTLFlagSet(flags, 11))
        result.img_search_username = [is readString];
    if (OGTLFlagSet(flags, 12))
        result.static_maps_provider = [is readString];
    result.caption_length_max = [is readInt32];
    result.message_length_max = [is readInt32];
    result.webfile_dc_id = [is readInt32];
    if (OGTLFlagSet(flags, 2))
    {
        result.suggested_lang_code = [is readString];
        result.lang_pack_version = [is readInt32];
        [is readInt32];
    }
    if (OGTLFlagSet(flags, 15))
    {
        int32_t reactionSignature = OGTLTakeInt32(is);
        if (reactionSignature == OGTLCtor(0x1b2286b8))
            result.reactions_default = [is readString];
        else if (reactionSignature == OGTLCtor(0x8935fc73))
            result.reactions_default = [NSString stringWithFormat:@"◆%lld", [is readInt64]];
        else
            OGTLCoreBuildObject(is, reactionSignature, environment, error);
    }
    OGTLSkipFlagged(is, environment, error, flags, 16, 's');
    if (OGTLCoreFailed(error))
        *error = nil;
    return result;
}

@end

@interface OGTLAvailableReactionParser : TLAvailableReaction_manual
@end

@implementation OGTLAvailableReactionParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLAvailableReaction_manual *result = OGTLNewObject(TLAvailableReaction_manual);
    int32_t flags = [is readInt32];
    result.inactive = OGTLFlagSet(flags, 0);
    result.premium = OGTLFlagSet(flags, 2);
    result.reaction = [is readString];
    OGTLTakeString(is);
    for (int i = 0; i < ((flags & (1 << 1)) != 0 ? 7 : 5); i++)
    {
        OGTLCoreReadObject(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
    }
    return result;
}

@end

@interface OGTLAvailableReactionsParser : TLmessages_AvailableReactions_manual
@end

@implementation OGTLAvailableReactionsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    [is readInt32];
    int32_t marker = OGTLTakeInt32(is);
    int32_t count = [is readInt32];
    if (marker != TL_UNIVERSAL_VECTOR_CONSTRUCTOR || count < 0 || count > 10000)
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:@"TLAvailableReactions" code:1 userInfo:nil];
        return nil;
    }

    TLmessages_AvailableReactions_manual *result = OGTLNewObject(TLmessages_AvailableReactions_manual);
    NSMutableArray *reactions = [[NSMutableArray alloc] init];
    NSMutableArray *emojis = [[NSMutableArray alloc] init];
    for (int32_t i = 0; i < count; i++)
    {
        id reaction = OGTLCoreReadObject(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        if (!OGTLCoreIsKind(reaction, [TLAvailableReaction_manual class]))
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
    [result setReactions:reactions];
    result.activeEmojis = emojis;
    return result;
}

@end

@interface OGTLIgnoredUpdate : TLUpdate
@property (nonatomic) int32_t ignoredSignature;
@end

@implementation OGTLIgnoredUpdate

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
- (id<TLObject>)TLdeserialize:(NSInputStream *)stream signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused tlContext error:(__autoreleasing NSError **)error
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
- (id<TLObject>)TLdeserialize:(NSInputStream *)stream signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused tlContext error:(__autoreleasing NSError **)error
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
        if (!OGTLCoreIsKind(object, [TLAuthorization class]))
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

@interface OGTLModernUpdateNewAuthorizationParser : TLUpdate$updateNewAuthorization
@end

@implementation OGTLModernUpdateNewAuthorizationParser

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

static const OGTLSkipLayout OGTLSkipLayouts[] =
{
    {(int32_t)0x804361ea, "lo", OGTLSkipResultNone},
    {(int32_t)0x80d26cc7, "slt", OGTLSkipResultNone},
    {(int32_t)0x832175e0, "iioo", OGTLSkipResultNone},
    {(int32_t)0x83d60fc2, "fii1?v0?l2?i3?i", OGTLSkipResultNone},
    {(int32_t)0x84aa3a9c, "s", OGTLSkipResultNone},
    {(int32_t)0x85dd99d1, "fv3?s", OGTLSkipResultNone},
    {(int32_t)0x85f0a9cd, "fllssi0?o1?s2?svii3?s4?v5?o8?l8?s8?l10?o11?o12?o13?i16?i", OGTLSkipResultNone},
    {(int32_t)0x86e18161, "lfsv4?i5?i", OGTLSkipResultNone},
    {(int32_t)0x86f8613c, "fiv0?sv", OGTLSkipResultNone},
    {(int32_t)0x86fccf85, "il", OGTLSkipResultNone},
    {(int32_t)0x87e5dfe4, "s", OGTLSkipResultNone},
    {(int32_t)0x881fb94b, "iv", OGTLSkipResultNone},
    {(int32_t)0x889b59ef, "", OGTLSkipResultNone},
    {(int32_t)0x8935fc73, "l", OGTLSkipResultNone},
    {(int32_t)0x8a2932f3, "v", OGTLSkipResultNone},
    {(int32_t)0x8a480e27, "iiii", OGTLSkipResultNone},
    {(int32_t)0x8ae5c97a, "oi", OGTLSkipResultNone},
    {(int32_t)0x8b725fce, "o", OGTLSkipResultNone},
    {(int32_t)0x8b73e763, "", OGTLSkipResultNone},
    {(int32_t)0x8c0f91fb, "", OGTLSkipResultNone},
    {(int32_t)0x8c39793f, "fiovv1?s2?s", OGTLSkipResultNone},
    {(int32_t)0x8c79b63c, "ioio", OGTLSkipResultNone},
    {(int32_t)0x8c9a88ac, "ovv", OGTLSkipResultNone},
    {(int32_t)0x8d595cd6, "fi2?i3?v4?i0?m", OGTLSkipResultNone},
    {(int32_t)0x8f34b2f5, "fslii2?o", OGTLSkipResultNone},
    {(int32_t)0x904dd49c, "ooi", OGTLSkipResultNone},
    {(int32_t)0x9083670b, "io", OGTLSkipResultNone},
    {(int32_t)0x90c467d1, "lv", OGTLSkipResultNone},
    {(int32_t)0x90d7adfa, "fo0?o", OGTLSkipResultNone},
    {(int32_t)0x922e55a9, "s", OGTLSkipResultNone},
    {(int32_t)0x929b619d, "l", OGTLSkipResultNone},
    {(int32_t)0x93037e20, "fiv0?svv", OGTLSkipResultNone},
    {(int32_t)0x93b9fbb5, "fss1?v", OGTLSkipResultNone},
    {(int32_t)0x93c3e27e, "fls0?ll1?l", OGTLSkipResultNone},
    {(int32_t)0x947a12df, "fiv0?s1?v1?lv2?vv", OGTLSkipResultNone},
    {(int32_t)0x94ce852a, "fli2?sslv", OGTLSkipResultNone},
    {(int32_t)0x95f2bfe4, "", OGTLSkipResultNone},
    {(int32_t)0x95f389b1, "fi1?ov0?svv", OGTLSkipResultNone},
    {(int32_t)0x95fcd1d6, "fllssso0?ol", OGTLSkipResultNone},
    {(int32_t)0x96d074fd, "s", OGTLSkipResultNone},
    {(int32_t)0x972dabbf, "fiil0?i1?i1?s", OGTLSkipResultNone},
    {(int32_t)0x9801d2f7, "", OGTLSkipResultNone},
    {(int32_t)0x98d5ea1d, "ivv", OGTLSkipResultNone},
    {(int32_t)0x98dd8936, "sv", OGTLSkipResultNone},
    {(int32_t)0x99ea331d, "il", OGTLSkipResultNone},
    {(int32_t)0x9a23af21, "fos0?vvv", OGTLSkipResultNone},
    {(int32_t)0x9a35e999, "fo0?iv", OGTLSkipResultNone},
    {(int32_t)0x9a8ae1e1, "v", OGTLSkipResultNone},
    {(int32_t)0x9a9d77e0, "lliii", OGTLSkipResultNone},
    {(int32_t)0x9ae228e2, "vvv", OGTLSkipResultNone},
    {(int32_t)0x9bad6414, "sls", OGTLSkipResultNone},
    {(int32_t)0x9d1dbd26, "lvvv", OGTLSkipResultNone},
    {(int32_t)0x9d2216e0, "f1?oo", OGTLSkipResultNone},
    {(int32_t)0x9d6b13b0, "fis0?oil", OGTLSkipResultNone},
    {(int32_t)0x9ddb347c, "fso0?oi", OGTLSkipResultNone},
    {(int32_t)0x9f071957, "", OGTLSkipResultNone},
    {(int32_t)0x9f120418, "ii", OGTLSkipResultNone},
    {(int32_t)0x9f2504e4, "siiiiio", OGTLSkipResultNone},
    {(int32_t)0x9f27d26e, "", OGTLSkipResultNone},
    {(int32_t)0x9f812b08, "ilo", OGTLSkipResultNone},
    {(int32_t)0xa02a982e, "soni", OGTLSkipResultNone},
    {(int32_t)0xa0624cf7, "i", OGTLSkipResultNone},
    {(int32_t)0xa0ba4f17, "", OGTLSkipResultNone},
    {(int32_t)0xa0c0505c, "ss", OGTLSkipResultNone},
    {(int32_t)0xa26156c0, "ls", OGTLSkipResultNone},
    {(int32_t)0xa2c0f695, "", OGTLSkipResultNone},
    {(int32_t)0xa2fa4880, "s", OGTLSkipResultNone},
    {(int32_t)0xa388a368, "", OGTLSkipResultNone},
    {(int32_t)0xa3d1cb80, "f0?ioi", OGTLSkipResultNone},
    {(int32_t)0xa44f3ef6, "oiiio", OGTLSkipResultNone},
    {(int32_t)0xa477288f, "oiui", OGTLSkipResultNone},
    {(int32_t)0xa4a79376, "loi", OGTLSkipResultNone},
    {(int32_t)0xa584b019, "oo", OGTLSkipResultNone},
    {(int32_t)0xa5d9abb8, "sssssi", OGTLSkipResultNone},
    {(int32_t)0xa8718dc5, "f1?s2?s4?l5?i5?io", OGTLSkipResultNone},
    {(int32_t)0xaa5f789c, "fivvv0?s", OGTLSkipResultNone},
    {(int32_t)0xab339c00, "", OGTLSkipResultNone},
    {(int32_t)0xac072444, "", OGTLSkipResultNone},
    {(int32_t)0xac21d3ce, "oiiovvi", OGTLSkipResultNone},
    {(int32_t)0xac5c1af7, "f0?os", OGTLSkipResultNone},
    {(int32_t)0xaca1657b, "fl0?oo", OGTLSkipResultNone},
    {(int32_t)0xad628cc8, "f0?i0?i1?o2?i", OGTLSkipResultNone},
    {(int32_t)0xadec6ebe, "fi1?o2?o3?i4?i", OGTLSkipResultNone},
    {(int32_t)0xaef6abbc, "vvv", OGTLSkipResultNone},
    {(int32_t)0xafd93fbb, "s", OGTLSkipResultNone},
    {(int32_t)0xaff56398, "iii", OGTLSkipResultNone},
    {(int32_t)0xb05ac6b1, "", OGTLSkipResultNone},
    {(int32_t)0xb06fdbdf, "", OGTLSkipResultNone},
    {(int32_t)0xb0bdeac5, "fli2?o", OGTLSkipResultNone},
    {(int32_t)0xb16a6c29, "s", OGTLSkipResultNone},
    {(int32_t)0xb2539d54, "liii", OGTLSkipResultNone},
    {(int32_t)0xb282217f, "ols", OGTLSkipResultNone},
    {(int32_t)0xb2b15770, "iv", OGTLSkipResultNone},
    {(int32_t)0xb390dc08, "fsl0?s1?s2?l3?s4?i", OGTLSkipResultNone},
    {(int32_t)0xb4073647, "is", OGTLSkipResultNone},
    {(int32_t)0xb457b375, "", OGTLSkipResultNone},
    {(int32_t)0xb4ae666f, "fss0?v1?si", OGTLSkipResultNone},
    {(int32_t)0xb4f67e93, "l", OGTLSkipResultNone},
    {(int32_t)0xb53e8b21, "ov", OGTLSkipResultNone},
    {(int32_t)0xb54b5acf, "f0?i1?l", OGTLSkipResultNone},
    {(int32_t)0xb81c7034, "io", OGTLSkipResultNone},
    {(int32_t)0xb826e150, "f0?o1?s2?i", OGTLSkipResultNone},
    {(int32_t)0xb88cf373, "f4?m6?m", OGTLSkipResultNone},
    {(int32_t)0xb8905fb2, "m", OGTLSkipResultNone},
    {(int32_t)0xb89bfccf, "f1?s1?ol", OGTLSkipResultNone},
    {(int32_t)0xb8ea86a9, "l", OGTLSkipResultNone},
    {(int32_t)0xb92fb6cd, "o", OGTLSkipResultNone},
    {(int32_t)0xb98cd696, "", OGTLSkipResultNone},
    {(int32_t)0xb9c0639a, "flllin0?i1?n", OGTLSkipResultNone},
    {(int32_t)0xbac3a61a, "", OGTLSkipResultNone},
    {(int32_t)0xbaf39d8b, "ivvv", OGTLSkipResultNone},
    {(int32_t)0xbb9bb9a5, "fo0?i", OGTLSkipResultNone},
    {(int32_t)0xbbab2643, "o", OGTLSkipResultNone},
    {(int32_t)0xbbb6b4a3, "li", OGTLSkipResultNone},
    {(int32_t)0xbbc7515d, "is", OGTLSkipResultNone},
    {(int32_t)0xbbf51685, "", OGTLSkipResultNone},
    {(int32_t)0xbd74cf49, "ioo", OGTLSkipResultNone},
    {(int32_t)0xbddb616e, "ivv", OGTLSkipResultNone},
    {(int32_t)0xbe376999, "l", OGTLSkipResultNone},
    {(int32_t)0xbe82db9c, "oosssss", OGTLSkipResultNone},
    {(int32_t)0xbf4dea82, "iov", OGTLSkipResultNone},
    {(int32_t)0xc01f6fe8, "i", OGTLSkipResultNone},
    {(int32_t)0xc077ec01, "fssooooo1?o1?o", OGTLSkipResultNone},
    {(int32_t)0xc1f46103, "", OGTLSkipResultNone},
    {(int32_t)0xc32d5b12, "lnii", OGTLSkipResultNone},
    {(int32_t)0xc387c04e, "i", OGTLSkipResultNone},
    {(int32_t)0xc3987a3a, "lv", OGTLSkipResultNone},
    {(int32_t)0xc3f2f501, "", OGTLSkipResultNone},
    {(int32_t)0xc448415c, "fi0?oii1?i", OGTLSkipResultNone},
    {(int32_t)0xc556a45d, "o", OGTLSkipResultNone},
    {(int32_t)0xc6991068, "fl3?iiiimi1?si", OGTLSkipResultNone},
    {(int32_t)0xc7b57ce6, "ss", OGTLSkipResultNone},
    {(int32_t)0xc9662d05, "isioi", OGTLSkipResultNone},
    {(int32_t)0xc9b9e2b9, "", OGTLSkipResultNone},
    {(int32_t)0xc9f06e1b, "f3?o4?o1?o2?o", OGTLSkipResultNone},
    {(int32_t)0xcad5452d, "foo0?o", OGTLSkipResultNone},
    {(int32_t)0xcae68768, "ovv", OGTLSkipResultNone},
    {(int32_t)0xcb6ff828, "fo0?si", OGTLSkipResultNone},
    {(int32_t)0xcba9a52f, "io", OGTLSkipResultNone},
    {(int32_t)0xcc4d9ecc, "ii", OGTLSkipResultNone},
    {(int32_t)0xcdbbcebb, "lv", OGTLSkipResultNone},
    {(int32_t)0xcef7e7a8, "", OGTLSkipResultNone},
    {(int32_t)0xcf6f6db8, "o", OGTLSkipResultNone},
    {(int32_t)0xcfb9d957, "fls1?i1?i", OGTLSkipResultNone},
    {(int32_t)0xcfcd0f13, "oo", OGTLSkipResultNone},
    {(int32_t)0xd02e7fd4, "fs1?sso", OGTLSkipResultNone},
    {(int32_t)0xd072acb4, "sss", OGTLSkipResultNone},
    {(int32_t)0xd08ce645, "", OGTLSkipResultNone},
    {(int32_t)0xd1ed9a5b, "", OGTLSkipResultNone},
    {(int32_t)0xd31bc45d, "ooo", OGTLSkipResultNone},
    {(int32_t)0xd3656499, "", OGTLSkipResultNone},
    {(int32_t)0xd597650c, "flli3?s4?i5?i7?i10?iii16?s20?l21?o", OGTLSkipResultNone},
    {(int32_t)0xd5e58274, "o", OGTLSkipResultNone},
    {(int32_t)0xd6b19546, "flii0?l0?i", OGTLSkipResultIgnored},
    {(int32_t)0xd80da15d, "o", OGTLSkipResultNone},
    {(int32_t)0xd90d8dfe, "fls3?vv", OGTLSkipResultNone},
    {(int32_t)0xd9c6dc1a, "fiool1?iis2?v3?o4?o6?o", OGTLSkipResultNone},
    {(int32_t)0xda2ad647, "bll", OGTLSkipResultNone},
    {(int32_t)0xdaad85b0, "fm1?t3?siii", OGTLSkipResultNone},
    {(int32_t)0xdb33dad0, "", OGTLSkipResultNone},
    {(int32_t)0xdb909ec2, "s", OGTLSkipResultNone},
    {(int32_t)0xdbce6389, "", OGTLSkipResultNone},
    {(int32_t)0xdc58f31e, "lo", OGTLSkipResultNone},
    {(int32_t)0xdc6cfcf0, "o", OGTLSkipResultNone},
    {(int32_t)0xdcb118b7, "sn", OGTLSkipResultNone},
    {(int32_t)0xdd27bee9, "fio9?ol1?iis2?v3?o4?o6?o8?o10?l11?i", OGTLSkipResultNone},
    {(int32_t)0xde4c5d93, "fs0?s1?s2?s", OGTLSkipResultNone},
    {(int32_t)0xde9eed1d, "vv", OGTLSkipResultNone},
    {(int32_t)0xdef143d0, "fo0?n", OGTLSkipResultNone},
    {(int32_t)0xdf8b3b22, "oosssss", OGTLSkipResultNone},
    {(int32_t)0xe0bff26c, "f0?ooi1?o", OGTLSkipResultNone},
    {(int32_t)0xe175e66f, "fi3?s4?lii2?i", OGTLSkipResultNone},
    {(int32_t)0xe1bb0d61, "so", OGTLSkipResultNone},
    {(int32_t)0xe2de7737, "fiv0?svv", OGTLSkipResultNone},
    {(int32_t)0xe4621141, "m", OGTLSkipResultNone},
    {(int32_t)0xe46bcee4, "l", OGTLSkipResultNone},
    {(int32_t)0xe477092e, "", OGTLSkipResultNone},
    {(int32_t)0xe4e88011, "v", OGTLSkipResultNone},
    {(int32_t)0xe519abab, "ioi", OGTLSkipResultNone},
    {(int32_t)0xe581e4e9, "", OGTLSkipResultNone},
    {(int32_t)0xe7058e7f, "iiii", OGTLSkipResultNone},
    {(int32_t)0xe7e82e12, "soos", OGTLSkipResultNone},
    {(int32_t)0xe7ff068a, "fl0?i", OGTLSkipResultNone},
    {(int32_t)0xe87acbc0, "oo", OGTLSkipResultNone},
    {(int32_t)0xe8fd8014, "oi", OGTLSkipResultNone},
    {(int32_t)0xe92fd902, "", OGTLSkipResultNone},
    {(int32_t)0xe988037b, "so", OGTLSkipResultNone},
    {(int32_t)0xe9baa668, "oi", OGTLSkipResultNone},
    {(int32_t)0xea32b4b1, "", OGTLSkipResultNone},
    {(int32_t)0xeafc32bc, "", OGTLSkipResultNone},
    {(int32_t)0xeafdf716, "lv", OGTLSkipResultNone},
    {(int32_t)0xeb032884, "vvv", OGTLSkipResultNone},
    {(int32_t)0xeb983f8f, "f4?o3?i0?lii1?ivv", OGTLSkipResultNone},
    {(int32_t)0xec43a2d1, "vvv", OGTLSkipResultNone},
    {(int32_t)0xece9814b, "", OGTLSkipResultNone},
    {(int32_t)0xedf3add0, "oo", OGTLSkipResultNone},
    {(int32_t)0xee430c85, "f3?ol", OGTLSkipResultNone},
    {(int32_t)0xee479c64, "o", OGTLSkipResultNone},
    {(int32_t)0xee8c1e86, "", OGTLSkipResultNone},
    {(int32_t)0xeeca5ce3, "fsss1?ssiis", OGTLSkipResultNone},
    {(int32_t)0xef156a5c, "iioo", OGTLSkipResultNone},
    {(int32_t)0xef1751b5, "o", OGTLSkipResultNone},
    {(int32_t)0xefb2b617, "flli3?s4?i5?i7?i10?iii16?s20?l21?o", OGTLSkipResultNone},
    {(int32_t)0xf08d516b, "", OGTLSkipResultNone},
    {(int32_t)0xf101aa7f, "ol", OGTLSkipResultNone},
    {(int32_t)0xf1d628ec, "oo", OGTLSkipResultNone},
    {(int32_t)0xf259a80b, "sllsivo", OGTLSkipResultNone},
    {(int32_t)0xf35aec28, "ll", OGTLSkipResultNone},
    {(int32_t)0xf6a5f82f, "", OGTLSkipResultNone},
    {(int32_t)0xf72e0ed9, "llo", OGTLSkipResultNone},
    {(int32_t)0xf74e932b, "oi", OGTLSkipResultNone},
    {(int32_t)0xf7e8d89b, "", OGTLSkipResultNone},
    {(int32_t)0xf83ae221, "vvvv", OGTLSkipResultNone},
    {(int32_t)0xf888fa1a, "", OGTLSkipResultNone},
    {(int32_t)0xf93cd45c, "lls", OGTLSkipResultNone},
    {(int32_t)0xf9677aad, "", OGTLSkipResultNone},
    {(int32_t)0xfa0f3ca2, "f1?i0?v", OGTLSkipResultNone},
    {(int32_t)0xfa30a8c7, "li", OGTLSkipResultNone},
    {(int32_t)0xfb4c496c, "", OGTLSkipResultNone},
    {(int32_t)0xfb9c547a, "o", OGTLSkipResultNone},
    {(int32_t)0xfc796b3f, "s", OGTLSkipResultNone},
    {(int32_t)0xfd149899, "iso", OGTLSkipResultNone},
    {(int32_t)0xfd5e12bd, "ovv", OGTLSkipResultNone},
    {(int32_t)0xfe198602, "fl0?n", OGTLSkipResultNone},
    {(int32_t)0xfe333952, "", OGTLSkipResultNone},
    {(int32_t)0xfebe5491, "fooo1?i", OGTLSkipResultNone},
    {(int32_t)0xff16e2ca, "ob", OGTLSkipResultNone},
    {(int32_t)0xffadc913, "iiii", OGTLSkipResultNone},
    {(int32_t)0xfffe1bac, "", OGTLSkipResultNone},
    {(int32_t)0x00f8ed08, "iv", OGTLSkipResultNone},
    {(int32_t)0x0194cb3b, "ioi", OGTLSkipResultNone},
    {(int32_t)0x01c641c2, "oi", OGTLSkipResultNone},
    {(int32_t)0x1f2bf4a, "o", OGTLSkipResultNone},
    {(int32_t)0x031f9590, "vo", OGTLSkipResultNone},
    {(int32_t)0x033ed001, "floo0?s1?i2?s", OGTLSkipResultNone},
    {(int32_t)0x5416d58, "il", OGTLSkipResultNone},
    {(int32_t)0x07141dbf, "fl0?i", OGTLSkipResultNone},
    {(int32_t)0x07b68920, "li", OGTLSkipResultNone},
    {(int32_t)0x07df587c, "fso0?oi", OGTLSkipResultNone},
    {(int32_t)0x093bcf34, "sl", OGTLSkipResultNone},
    {(int32_t)0x09c469cd, "fss0?o", OGTLSkipResultNone},
    {(int32_t)0x09cb7759, "oiivi", OGTLSkipResultNone},
    {(int32_t)0x0a339f0b, "fv1?v4?v", OGTLSkipResultNone},
    {(int32_t)0x0aa021e5, "iiii", OGTLSkipResultNone},
    {(int32_t)0x0ab4a819, "fsli4?i1?i2?i3?i7?i8?s", OGTLSkipResultNone},
    {(int32_t)0x0bb2d201, "im", OGTLSkipResultNone},
    {(int32_t)0x0bd915c0, "fl0?ssl", OGTLSkipResultNone},
    {(int32_t)0x0e8e37e5, "f3?o0?i", OGTLSkipResultNone},
    {(int32_t)0x10b78d29, "fs0?ssi", OGTLSkipResultNone},
    {(int32_t)0x114ff30d, "vv", OGTLSkipResultNone},
    {(int32_t)0x11b58939, "", OGTLSkipResultNone},
    {(int32_t)0x120b1ab9, "ii", OGTLSkipResultNone},
    {(int32_t)0x13767230, "ss", OGTLSkipResultNone},
    {(int32_t)0x140502d1, "f0?io", OGTLSkipResultNone},
    {(int32_t)0x14455871, "ioo", OGTLSkipResultNone},
    {(int32_t)0x15590068, "s", OGTLSkipResultNone},
    {(int32_t)0x16115a96, "ov", OGTLSkipResultNone},
    {(int32_t)0x1759c560, "flo0?s0?l", OGTLSkipResultNone},
    {(int32_t)0x17d7f87b, "vv", OGTLSkipResultNone},
    {(int32_t)0x1824e40b, "ioo", OGTLSkipResultNone},
    {(int32_t)0x1839490f, "", OGTLSkipResultNone},
    {(int32_t)0x19420af6, "v", OGTLSkipResultNone},
    {(int32_t)0x1b0e4f07, "fill0?l", OGTLSkipResultNone},
    {(int32_t)0x1b2286b8, "s", OGTLSkipResultNone},
    {(int32_t)0x1bf335b9, "il", OGTLSkipResultNone},
    {(int32_t)0x1d998733, "lo", OGTLSkipResultNone},
    {(int32_t)0x1dab80b7, "s", OGTLSkipResultNone},
    {(int32_t)0x1e109708, "l", OGTLSkipResultNone},
    {(int32_t)0x1e148390, "o", OGTLSkipResultNone},
    {(int32_t)0x1e297bfa, "foi0?i1?oo", OGTLSkipResultNone},
    {(int32_t)0x1ea2fda7, "fllso2?ol0?b", OGTLSkipResultNone},
    {(int32_t)0x1f01c757, "i", OGTLSkipResultNone},
    {(int32_t)0x1f0c1ad9, "", OGTLSkipResultNone},
    {(int32_t)0x20529438, "l", OGTLSkipResultNone},
    {(int32_t)0x206ad49e, "", OGTLSkipResultNone},
    {(int32_t)0x2085c238, "s", OGTLSkipResultNone},
    {(int32_t)0x20bcbba1, "o", OGTLSkipResultIgnoredUnlessFailed},
    {(int32_t)0x21108ff7, "f4?m", OGTLSkipResultNone},
    {(int32_t)0x21461b5d, "", OGTLSkipResultNone},
    {(int32_t)0x221bb5e4, "ioi", OGTLSkipResultNone},
    {(int32_t)0x2271f2bf, "ooi", OGTLSkipResultNone},
    {(int32_t)0x22c0f6d5, "fi0?i1?o2?s3?v4?i", OGTLSkipResultNone},
    {(int32_t)0x250dbaf8, "", OGTLSkipResultNone},
    {(int32_t)0x257e962b, "fii0?s1?isl", OGTLSkipResultNone},
    {(int32_t)0x258aff05, "ss", OGTLSkipResultNone},
    {(int32_t)0x25e073fc, "v", OGTLSkipResultNone},
    {(int32_t)0x26219a58, "n", OGTLSkipResultNone},
    {(int32_t)0x28373599, "lo", OGTLSkipResultNone},
    {(int32_t)0x283bd312, "lsi", OGTLSkipResultNone},
    {(int32_t)0x2aee9191, "fiiiii1?ss", OGTLSkipResultNone},
    {(int32_t)0x2b96cd1b, "s", OGTLSkipResultNone},
    {(int32_t)0x2ba1f5ce, "", OGTLSkipResultNone},
    {(int32_t)0x2cb51097, "lvv", OGTLSkipResultNone},
    {(int32_t)0x2dd14edc, "f0?illss4?v4?i4?i8?lii", OGTLSkipResultNone},
    {(int32_t)0x2de11aae, "", OGTLSkipResultNone},
    {(int32_t)0x2e94c3e7, "foi0?o", OGTLSkipResultNone},
    {(int32_t)0x2eb1b658, "oi", OGTLSkipResultNone},
    {(int32_t)0x2ed82995, "ivvv", OGTLSkipResultNone},
    {(int32_t)0x2eeed1c4, "f0?l0?i0?l0?oi", OGTLSkipResultNone},
    {(int32_t)0x2f65c8e4, "l", OGTLSkipResultNone},
    {(int32_t)0x308660c1, "sl", OGTLSkipResultNone},
    {(int32_t)0x30f443db, "", OGTLSkipResultNone},
    {(int32_t)0x313a9547, "flol0?i0?il1?i1?i3?l4?l5?s6?o8?i8?i9?i11?s11?i11?i11?i11?i12?i13?o", OGTLSkipResultNone},
    {(int32_t)0x31c24808, "i", OGTLSkipResultNone},
    {(int32_t)0x31cad303, "v", OGTLSkipResultNone},
    {(int32_t)0x3259950a, "vl", OGTLSkipResultNone},
    {(int32_t)0x339bef6c, "f3?o1?o2?o", OGTLSkipResultNone},
    {(int32_t)0x3458f9c8, "ov", OGTLSkipResultNone},
    {(int32_t)0x35bbdb6b, "isb", OGTLSkipResultNone},
    {(int32_t)0x36437737, "i", OGTLSkipResultNone},
    {(int32_t)0x367617d3, "iivvvvi", OGTLSkipResultNone},
    {(int32_t)0x37381085, "os", OGTLSkipResultNone},
    {(int32_t)0x374fa7ad, "", OGTLSkipResultNone},
    {(int32_t)0x394e7f21, "s", OGTLSkipResultNone},
    {(int32_t)0x39c67432, "", OGTLSkipResultNone},
    {(int32_t)0x39f23300, "o", OGTLSkipResultNone},
    {(int32_t)0x3aae0528, "ii", OGTLSkipResultNone},
    {(int32_t)0x3b6ddad2, "ibi", OGTLSkipResultNone},
    {(int32_t)0x3bb842ac, "i", OGTLSkipResultNone},
    {(int32_t)0x3de1dfed, "vvv", OGTLSkipResultNone},
    {(int32_t)0x3e0b5b6a, "fii1?il", OGTLSkipResultNone},
    {(int32_t)0x3e81e078, "f1?s2?s", OGTLSkipResultNone},
    {(int32_t)0x3fc9053b, "s", OGTLSkipResultNone},
    {(int32_t)0x416c56e8, "ovv", OGTLSkipResultNone},
    {(int32_t)0x41c87565, "m", OGTLSkipResultNone},
    {(int32_t)0x41df43fc, "f1?oio2?o3?i11?l4?l6?l7?i8?l13?i14?i15?n16?s18?l19?i20?i", OGTLSkipResultNone},
    {(int32_t)0x4258c205, "", OGTLSkipResultNone},
    {(int32_t)0x42b00348, "foilii1?o2?i", OGTLSkipResultNone},
    {(int32_t)0x4345be73, "ss", OGTLSkipResultNone},
    {(int32_t)0x4367daa0, "fi1?i2?l4?s", OGTLSkipResultNone},
    {(int32_t)0x43b46b20, "i", OGTLSkipResultNone},
    {(int32_t)0x44ba9dd9, "ivvvv", OGTLSkipResultNone},
    {(int32_t)0x46c6e36f, "v", OGTLSkipResultNone},
    {(int32_t)0x481eadfa, "", OGTLSkipResultNone},
    {(int32_t)0x48a30254, "v", OGTLSkipResultNone},
    {(int32_t)0x48aaae3c, "l", OGTLSkipResultNone},
    {(int32_t)0x48e246c2, "lo", OGTLSkipResultNone},
    {(int32_t)0x4959427a, "fiii4?i0?i1?os3?v2?n", OGTLSkipResultNone},
    {(int32_t)0x49b92a26, "iov", OGTLSkipResultNone},
    {(int32_t)0x4a162433, "l", OGTLSkipResultNone},
    {(int32_t)0x4b3e14d6, "fs0?l2?iii4?s5?i6?l", OGTLSkipResultNone},
    {(int32_t)0x4b9e22a0, "", OGTLSkipResultNone},
    {(int32_t)0x4ba3a95a, "f3?oi", OGTLSkipResultNone},
    {(int32_t)0x4bbb8f01, "o", OGTLSkipResultIgnoredUnlessFailed},
    {(int32_t)0x4d4bd46a, "", OGTLSkipResultNone},
    {(int32_t)0x4e7085ea, "soo", OGTLSkipResultNone},
    {(int32_t)0x4e80a379, "o", OGTLSkipResultNone},
    {(int32_t)0x4f2b9479, "fv1?v", OGTLSkipResultNone},
    {(int32_t)0x50a04e45, "vvv", OGTLSkipResultNone},
    {(int32_t)0x50cc03d3, "iv", OGTLSkipResultNone},
    {(int32_t)0x50cd067c, "oo", OGTLSkipResultNone},
    {(int32_t)0x50f41ccf, "s", OGTLSkipResultNone},
    {(int32_t)0x512fe446, "fslill0?i0?l2?l3?l4?i5?i5?s", OGTLSkipResultNone},
    {(int32_t)0x514519e2, "i", OGTLSkipResultNone},
    {(int32_t)0x51e6ee4f, "i", OGTLSkipResultNone},
    {(int32_t)0x523da4eb, "", OGTLSkipResultNone},
    {(int32_t)0x527d22eb, "", OGTLSkipResultNone},
    {(int32_t)0x52928bca, "i", OGTLSkipResultNone},
    {(int32_t)0x5334759c, "svtvvv", OGTLSkipResultNone},
    {(int32_t)0x53d7bfd8, "sioi", OGTLSkipResultNone},
    {(int32_t)0x54236209, "iil", OGTLSkipResultNone},
    {(int32_t)0x54b56617, "f0?v1?o", OGTLSkipResultNone},
    {(int32_t)0x565251e2, "isoo", OGTLSkipResultNone},
    {(int32_t)0x56dbfcf8, "on", OGTLSkipResultIgnoredUnlessFailed},
    {(int32_t)0x5787686d, "os", OGTLSkipResultNone},
    {(int32_t)0x58747131, "lfov4?i5?i", OGTLSkipResultNone},
    {(int32_t)0x59d78fc5, "fiiiivvv0?s", OGTLSkipResultNone},
    {(int32_t)0x59e65335, "", OGTLSkipResultNone},
    {(int32_t)0x5a0a066d, "fss0?o", OGTLSkipResultNone},
    {(int32_t)0x5b934f9d, "oil", OGTLSkipResultNone},
    {(int32_t)0x5da674b7, "", OGTLSkipResultNone},
    {(int32_t)0x5e0589f1, "fl0?ssl", OGTLSkipResultNone},
    {(int32_t)0x5e068047, "so", OGTLSkipResultNone},
    {(int32_t)0x5e1b3cb8, "foi0?io", OGTLSkipResultNone},
    {(int32_t)0x5f3b8a00, "f0?o1?o", OGTLSkipResultNone},
    {(int32_t)0x60682812, "", OGTLSkipResultNone},
    {(int32_t)0x6090d6d5, "oio", OGTLSkipResultNone},
    {(int32_t)0x628c9224, "il", OGTLSkipResultNone},
    {(int32_t)0x63c3dd0a, "fiv0?nvv", OGTLSkipResultNone},
    {(int32_t)0x64407ea7, "foiiiii1?o", OGTLSkipResultNone},
    {(int32_t)0x65427b82, "", OGTLSkipResultNone},
    {(int32_t)0x65a0fa4d, "vo", OGTLSkipResultNone},
    {(int32_t)0x661d4037, "v", OGTLSkipResultNone},
    {(int32_t)0x683b2c52, "ioi", OGTLSkipResultNone},
    {(int32_t)0x68cb6283, "foi0?o", OGTLSkipResultNone},
    {(int32_t)0x69279795, "i", OGTLSkipResultNone},
    {(int32_t)0x695c9e7c, "lii", OGTLSkipResultIgnored},
    {(int32_t)0x6a7e7366, "oo", OGTLSkipResultIgnoredUnlessFailed},
    {(int32_t)0x6b134e8e, "m", OGTLSkipResultNone},
    {(int32_t)0x6b39f4ec, "oooivv", OGTLSkipResultNone},
    {(int32_t)0x6c0d8e23, "ilbi", OGTLSkipResultIgnored},
    {(int32_t)0x6c37c15c, "ii", OGTLSkipResultNone},
    {(int32_t)0x6c8e1e06, "fii0?i", OGTLSkipResultNone},
    {(int32_t)0x6c9ce8ed, "fo1?v2?s4?l3?v0?svv", OGTLSkipResultNone},
    {(int32_t)0x6c9d0efe, "lvv", OGTLSkipResultNone},
    {(int32_t)0x6ca9c2e9, "sb", OGTLSkipResultNone},
    {(int32_t)0x6ebdff91, "islsls", OGTLSkipResultNone},
    {(int32_t)0x6f747657, "oo", OGTLSkipResultNone},
    {(int32_t)0x6f7863f4, "", OGTLSkipResultNone},
    {(int32_t)0x6fb4ad87, "", OGTLSkipResultNone},
    {(int32_t)0x7063c3db, "oim", OGTLSkipResultNone},
    {(int32_t)0x711d692d, "f1?i", OGTLSkipResultNone},
    {(int32_t)0x7184603b, "fllssliiii0?i", OGTLSkipResultNone},
    {(int32_t)0x71f276c4, "i", OGTLSkipResultNone},
    {(int32_t)0x72c64955, "", OGTLSkipResultNone},
    {(int32_t)0x74aee3e0, "l", OGTLSkipResultNone},
    {(int32_t)0x74c34319, "fisls0?s", OGTLSkipResultNone},
    {(int32_t)0x751f3146, "sv", OGTLSkipResultNone},
    {(int32_t)0x7533a588, "", OGTLSkipResultNone},
    {(int32_t)0x75b3b798, "oo", OGTLSkipResultIgnoredUnlessFailed},
    {(int32_t)0x76768bed, "ivo", OGTLSkipResultNone},
    {(int32_t)0x767d61eb, "nnn", OGTLSkipResultNone},
    {(int32_t)0x768e3aad, "iv", OGTLSkipResultNone},
    {(int32_t)0x770416af, "oli", OGTLSkipResultNone},
    {(int32_t)0x771a4e66, "iiilvmiiiiv", OGTLSkipResultNone},
    {(int32_t)0x77608b83, "v", OGTLSkipResultNone},
    {(int32_t)0x7781fe18, "l", OGTLSkipResultNone},
    {(int32_t)0x77b0e372, "loi", OGTLSkipResultNone},
    {(int32_t)0x78fbf3a8, "", OGTLSkipResultNone},
    {(int32_t)0x79b26a24, "fii18?o17?oi0?s1?vo14?v2?v3?o15?o19?n20?o", OGTLSkipResultNone},
    {(int32_t)0x79eb8cb3, "ivvl", OGTLSkipResultNone},
    {(int32_t)0x79f5d419, "", OGTLSkipResultNone},
    {(int32_t)0x7a1e11d1, "lm", OGTLSkipResultNone},
    {(int32_t)0x7a9abda9, "slt", OGTLSkipResultNone},
    {(int32_t)0x7adf2420, "f1?v2?i3?v4?s4?v", OGTLSkipResultNone},
    {(int32_t)0x7b560a0b, "", OGTLSkipResultNone},
    {(int32_t)0x7c8fe7b6, "ilo", OGTLSkipResultNone},
    {(int32_t)0x7d5bd1f0, "vvv", OGTLSkipResultNone},
    {(int32_t)0x7d627683, "oio", OGTLSkipResultNone}
};

@interface OGTLSkipObjectParser : OGTLManualParser
@end

@implementation OGTLSkipObjectParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    const OGTLSkipLayout *skipLayout = OGTLFindSkipLayout(OGTLSkipLayouts, sizeof(OGTLSkipLayouts) / sizeof(OGTLSkipLayouts[0]), signature);
    if (skipLayout != NULL)
    {
        OGTLSkipFields(is, skipLayout->layout, environment, error);
        if (skipLayout->result == OGTLSkipResultNone || (skipLayout->result == OGTLSkipResultIgnoredUnlessFailed && error != NULL && *error != nil))
            return nil;
        OGTLIgnoredUpdate *result = [[OGTLIgnoredUpdate alloc] init];
        result.ignoredSignature = signature;
        return result;
    }

    switch (signature)
    {
        case OGTLCtor(0x1cb5c415):
        {
            int32_t count = [is readInt32];
            for (int32_t i = 0; i < count; i++)
            {
                @try
                {
                    OGTLCoreReadObject(is, environment, error);
                }
                @catch (NSException *exception)
                {
                    NSString *message = [NSString stringWithFormat:@"index=%d/%d manual=0x%08x manualName=%@ parser=%@ exception=%@ reason=%@", i, count, OGTLCoreCurrentManualSignature, stringForHash(OGTLCoreCurrentManualSignature), OGTLCoreCurrentManualParser, exception.name, exception.reason];
                    if (error != NULL)
                    {
                        *error = OGTLCoreMessageError(message);
                    }
                    break;
                }
                if (OGTLCoreFailed(error))
                {
                    break;
                }
            }
            break;
        }
        case OGTLCtor(0xc01e857f):
        {
            int64_t userId = OGTLTakeInt64(is);
            TLSendMessageAction *action = (TLSendMessageAction *)OGTLCoreReadObject(is, environment, error);
            TLUpdate$updateUserTyping *result = [[TLUpdate$updateUserTyping alloc] init];
            result.user_id = userId;
            result.action = action;
            return result;
        }
        case (int32_t)0x2a17bf5c:
        {
            int32_t flags = [is readInt32];
            int64_t userId = OGTLTakeInt64(is);
            OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
            TLSendMessageAction *action = (TLSendMessageAction *)OGTLCoreReadObject(is, environment, error);
            TLUpdate$updateUserTyping *result = [[TLUpdate$updateUserTyping alloc] init];
            result.user_id = userId;
            result.action = action;
            return result;
        }
        case (int32_t)0x83487af0:
        {
            int64_t chatId = OGTLTakeInt64(is);
            TLPeer *fromPeer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
            TLSendMessageAction *action = (TLSendMessageAction *)OGTLCoreReadObject(is, environment, error);
            if (!OGTLCoreIsKind(fromPeer, [TLPeer$peerUser class]))
                return nil;
            TLUpdate$updateChatUserTyping *result = [[TLUpdate$updateChatUserTyping alloc] init];
            result.chat_id = chatId;
            result.user_id = ((TLPeer$peerUser *)fromPeer).user_id;
            result.action = action;
            return result;
        }
        case OGTLCtor(0x14b24500):
        {
            OGTLTakeInt64(is);

            NSError *groupCallSkipError;
            OGTLCoreReadObject(is, environment, &groupCallSkipError);
            break;
        }
        case OGTLCtor(0xed85eab5):
        {
            int32_t flags = [is readInt32];
            TLPeer *peer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
            NSArray *messages = OGTLCoreReadInt32Vector(is);
            int32_t pts = OGTLTakeInt32(is);
            int32_t ptsCount = OGTLTakeInt32(is);
            TLUpdate$updatePinnedMessagesCodex *result = [[TLUpdate$updatePinnedMessagesCodex alloc] init];
            result.flags = flags;
            [result setPeer:peer];
            result.messages = messages;
            [result setPts:pts];
            [result setPts_count:ptsCount];
            return result;
        }
        case OGTLCtor(0xe16459c3):
        {
            int32_t flags = [is readInt32];
            TLDialogPeer *peer = (TLDialogPeer *)OGTLCoreReadObject(is, environment, error);
            TLUpdate$updateDialogUnreadMark *result = [[TLUpdate$updateDialogUnreadMark alloc] init];
            result.flags = flags;
            [result setPeer:peer];
            return result;
        }
        case OGTLCtor(0xe56dbf05):
        {
            TLPeer *peer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
            TLDialogPeer$dialogPeer *result = [[TLDialogPeer$dialogPeer alloc] init];
            [result setPeer:peer];
            return result;
        }
        case OGTLCtor(0x9e84bc99):
        {
            int32_t flags = [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
            TLPeer *peer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 1, 'i');
            int32_t maxId = OGTLTakeInt32(is);
            [is readInt32];
            int32_t pts = OGTLTakeInt32(is);
            int32_t ptsCount = OGTLTakeInt32(is);
            TLUpdate$updateReadHistoryInbox *result = OGTLNewObject(TLUpdate$updateReadHistoryInbox);
            [result setPeer:peer];
            [result setMax_id:maxId];
            [result setPts:pts];
            [result setPts_count:ptsCount];
            return result;
        }
        case OGTLCtor(0x2f2f21bf):
        {
            TLPeer *peer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
            int32_t maxId = OGTLTakeInt32(is);
            int32_t pts = OGTLTakeInt32(is);
            int32_t ptsCount = OGTLTakeInt32(is);
            TLUpdate$updateReadHistoryOutbox *result = OGTLNewObject(TLUpdate$updateReadHistoryOutbox);
            [result setPeer:peer];
            [result setMax_id:maxId];
            [result setPts:pts];
            [result setPts_count:ptsCount];
            return result;
        }
        case OGTLCtor(0xb23fc698):
        {
            int64_t channelId = OGTLTakeInt64(is);
            int32_t availableMinId = [is readInt32];
            TLUpdate$updateChannelAvailableMessages *result = [[TLUpdate$updateChannelAvailableMessages alloc] init];
            result.channel_id = channelId;
            result.available_min_id = availableMinId;
            return result;
        }
        case OGTLCtor(0xf2ebdb4e):
            OGTLCoreReadObject(is, environment, error);
            if (OGTLCoreFailed(error))
                break;
            OGTLCoreReadObjectVector(is, environment, error);
            if (OGTLCoreFailed(error))
                break;
            [is readInt32];
            break;
        case OGTLCtor(0x2a3dc7ac):
        case OGTLCtor(0xeba636fe):
        {
            int32_t flags = [is readInt32];
            OGTLCoreReadObject(is, environment, error);
            [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 3, 'i');
            [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 7, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 11, 's');
            OGTLSkipFlagged(is, environment, error, flags, 13, 'l');
            if (flags & (1 << 6)) OGTLCoreReadObject(is, environment, error);
            if (flags & (1 << 14)) OGTLCoreReadObject(is, environment, error);
            if (signature == (int32_t)0x2a3dc7ac && (OGTLFlagSet(flags, 16))) [is readInt64];
            break;
        }
        case OGTLCtor(0x67753ac8):
        {
            int32_t flags = [is readInt32];
            OGTLTakeString(is);
            OGTLCoreReadObjectVector(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 1, 'i');
            break;
        }
        case OGTLCtor(0x5bb98608):
        {
            int32_t flags = [is readInt32];
            int64_t channelId = OGTLTakeInt64(is);
            NSArray *messages = OGTLCoreReadInt32Vector(is);
            int32_t pts = OGTLTakeInt32(is);
            int32_t ptsCount = OGTLTakeInt32(is);
            TLUpdate$updatePinnedChannelMessagesCodex *result = [[TLUpdate$updatePinnedChannelMessagesCodex alloc] init];
            result.flags = flags;
            result.channel_id = channelId;
            result.messages = messages;
            [result setPts:pts];
            [result setPts_count:ptsCount];
            return result;
        }
        case OGTLCtor(0x16a4b93c):
        case OGTLCtor(0xedf164f1):
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 18, 'o');
            OGTLSkipFlagged(is, environment, error, flags, 17, 'o');
            [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 0, 's');
            OGTLSkipFlagged(is, environment, error, flags, 1, 'v');
            OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 14, 'v');
            OGTLSkipFlagged(is, environment, error, flags, 2, 'v');
            OGTLSkipFlagged(is, environment, error, flags, 3, 'o');
            OGTLSkipFlagged(is, environment, error, flags, 15, 'o');
            OGTLSkipFlagged(is, environment, error, flags, 19, 'n');
            if (signature == (int32_t)0x16a4b93c && (OGTLFlagSet(flags, 20)))
                OGTLCoreReadObject(is, environment, error);
            break;
        }
        case OGTLCtor(0x03d1ea4e):
        {
            OGTLTakeDouble(is);
            OGTLTakeDouble(is);
            OGTLTakeDouble(is);
            OGTLTakeDouble(is);
            OGTLTakeDouble(is);
            break;
        }
        case OGTLCtor(0xcfc9e002):
        {
            int32_t flags = [is readInt32];
            OGTLTakeDouble(is);
            OGTLTakeDouble(is);
            OGTLTakeDouble(is);
            OGTLTakeDouble(is);
            OGTLTakeDouble(is);
            OGTLSkipFlagged(is, environment, error, flags, 0, 'd');
            break;
        }
        case OGTLCtor(0x49a6549c):
            OGTLCoreReadObject(is, environment, error);
            OGTLTakeString(is);
            OGTLTakeDouble(is);
            [is readInt32];
            break;
        case OGTLCtor(0xbe382906):
        {
            [is readInt32];
            OGTLTakeInt64(is);
            [is readInt32];
            OGTLCoreReadObjectVector(is, environment, error);
            int32_t vectorSignature = OGTLTakeInt32(is);
            if (vectorSignature == OGTLCtor(0x1cb5c415))
            {
                int32_t count = [is readInt32];
                for (int32_t i = 0; i < count; i++)
                    OGTLTakeInt64(is);
            }
            break;
        }
        case OGTLCtor(0x3b6d152e):
        {
            TLUserFull$userFull *userFull = (TLUserFull$userFull *)OGTLCoreReadObject(is, environment, error);
            OGTLCoreReadObjectVector(is, environment, error);
            NSArray *users = OGTLCoreReadObjectVector(is, environment, error);
            if (users.count != 0 && userFull.user == nil)
                [userFull setUser:[users objectAtIndex:0]];
            return userFull;
        }
        case OGTLCtor(0xcc997720):
        case OGTLCtor(0xd2234ea0):
        case OGTLCtor(0x06cbe645):
        case (int32_t)0xb90c2afd:
        {
            TLUserFull$userFull *result = [[TLUserFull$userFull alloc] init];
            int32_t flags = [is readInt32];
            int32_t flags2 = OGTLTakeInt32(is);
            OGTLTakeInt64(is);
            [result setFlags:flags & ((1 << 0) | (1 << 1) | (1 << 2) | (1 << 3))];
            if (OGTLFlagSet(flags, 1))
                result.about = [is readString];
            OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 21, 'o');
            if (OGTLFlagSet(flags, 2))
                result.profile_photo = (TLPhoto *)OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 22, 'o');
            result.notify_settings = (TLPeerNotifySettings *)OGTLCoreReadObject(is, environment, error);
            if (OGTLFlagSet(flags, 3))
                result.bot_info = (TLBotInfo *)OGTLCoreReadObject(is, environment, error);
            if (OGTLFlagSet(flags, 6))
                result.pinned_msg_id = [is readInt32];
            result.common_chats_count = [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 11, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 14, 'i');
            if (OGTLFlagSet(flags, 15))
            {
                if (signature == (int32_t)0x06cbe645 || signature == (int32_t)0xb90c2afd)
                    OGTLCoreReadObject(is, environment, error);
                else
                    OGTLTakeString(is);
            }
            OGTLSkipFlagged(is, environment, error, flags, 16, 's');
            OGTLSkipFlagged(is, environment, error, flags, 17, 'o');
            OGTLSkipFlagged(is, environment, error, flags, 18, 'o');
            if (signature != (int32_t)0x06cbe645 && signature != (int32_t)0xb90c2afd && (flags & (1 << 19)))
                OGTLCoreReadObjectVector(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 24, 'o');
            OGTLSkipFlagged(is, environment, error, flags, 25, 'o');
            OGTLSkipFlagged(is, environment, error, flags2, 0, 'o');
            OGTLSkipFlagged(is, environment, error, flags2, 1, 'o');
            OGTLSkipFlagged(is, environment, error, flags2, 2, 'o');
            OGTLSkipFlagged(is, environment, error, flags2, 3, 'o');
            OGTLSkipFlagged(is, environment, error, flags2, 4, 'o');
            OGTLSkipFlagged(is, environment, error, flags2, 5, 'o');
            if (OGTLFlagSet(flags2, 6))
            {
                OGTLTakeInt64(is);
                [is readInt32];
            }
            OGTLSkipFlagged(is, environment, error, flags2, 8, 'i');
            OGTLSkipFlagged(is, environment, error, flags2, 11, 'o');
            OGTLSkipFlagged(is, environment, error, flags2, 12, 'o');
            if (OGTLFlagSet(flags2, 14))
                result.send_paid_messages_stars = [is readInt64];
            OGTLSkipFlagged(is, environment, error, flags2, 15, 'o');
            OGTLSkipFlagged(is, environment, error, flags2, 17, 'o');
            if (OGTLFlagSet(flags2, 18))
            {
                OGTLCoreReadObject(is, environment, error);
                [is readInt32];
            }
            OGTLSkipFlagged(is, environment, error, flags2, 20, 'o');
            if (OGTLFlagSet(flags2, 21))
            {
                result.saved_music = (TLDocument *)OGTLCoreReadObject(is, environment, error);
            }
            OGTLSkipFlagged(is, environment, error, flags2, 22, 'o');
            OGTLSkipFlagged(is, environment, error, flags2, 25, 'l');
            if (signature == (int32_t)0xb90c2afd && (flags2 & (1 << 19)))
            {
                int32_t walletCardSignature = [is readInt32];
                result.wallet_card = [TGTLDynamicObject parseObjectFromStream:is signature:walletCardSignature error:error];
            }
            if (signature == (int32_t)0xb90c2afd && (flags2 & (1 << 27)))
                OGTLCoreReadObject(is, environment, error);
            return result;
        }
        case OGTLCtor(0x8c92b098):
        {
            [is readInt32];
            OGTLTakeString(is);
            int32_t vectorMarker = OGTLTakeInt32(is);
            int32_t count = 0;
            if (!OGTLCoreVectorCountForMarker(is, vectorMarker, &count))
            {
                break;
            }
            for (int32_t i = 0; i < count; i++)
            {
                int32_t itemSignature = OGTLTakeInt32(is);
                if (itemSignature == OGTLCtor(0x120b1ab9))
                {
                    [is readInt32];
                    [is readInt32];
                }
                else
                {
                    OGTLCoreBuildObject(is, itemSignature, environment, error);
                    if (OGTLCoreFailed(error))
                        break;
                }
            }
            break;
        }
        case OGTLCtor(0x6f8b32aa):
        case OGTLCtor(0xc4e5921e):
        {
            int32_t flags = [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 4, 'v');
            if (signature == (int32_t)0xc4e5921e && (OGTLFlagSet(flags, 6)))
                OGTLCoreReadObjectVector(is, environment, error);
            break;
        }
        case OGTLCtor(0x13659eb0):
        {
            int32_t flags = [is readInt32];
            OGTLTakeString(is);
            OGTLCoreReadObject(is, environment, error);
            [is readInt32];
            OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 0, 's');
            OGTLSkipFlagged(is, environment, error, flags, 1, 's');
            if (flags & (1 << 2)) OGTLCoreReadObject(is, environment, error);
            if (OGTLFlagSet(flags, 5)) { [is readInt32]; [is readString]; }
            OGTLSkipFlagged(is, environment, error, flags, 7, 'b');
            OGTLSkipFlagged(is, environment, error, flags, 8, 'i');
            if (flags & (1 << 9)) OGTLCoreReadObjectVector(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 12, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 13, 'i');
            if (flags & (1 << 14)) OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 15, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 16, 'i');
            if (flags & (1 << 17)) { OGTLCoreReadObject(is, environment, error); OGTLCoreReadObject(is, environment, error); }
            OGTLSkipFlagged(is, environment, error, flags, 19, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 20, 'i');
            if (OGTLFlagSet(flags, 23)) { [is readInt32]; [is readInt32]; }
            break;
        }
        case OGTLCtor(0x6c207376):
        {
            int32_t flags = [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 0, 'o');
            OGTLCoreReadObject(is, environment, error);
            OGTLCoreReadObject(is, environment, error);
            OGTLTakeDouble(is);
            break;
        }
        case OGTLCtor(0x2e6eab1a):
        {
            int32_t flags = [is readInt32];
            OGTLTakeString(is);
            OGTLCoreReadObject(is, environment, error);
            [is readInt32];
            OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 3, 's');
            OGTLSkipFlagged(is, environment, error, flags, 4, 's');
            if (flags & (1 << 5)) OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 6, 's');
            break;
        }
        case OGTLCtor(0xdd0c66f2):
        {
            int32_t flags = [is readInt32];
            OGTLTakeInt64(is);
            [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 1, 'i');
            if (flags & (1 << 2)) OGTLCoreReadObject(is, environment, error);
            break;
        }
        case OGTLCtor(0x19a13f71):
        {
            int32_t flags = [is readInt32];
            OGTLTakeString(is);
            [is readInt32];
            OGTLTakeInt64(is);
            [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
            OGTLTakeInt64(is);
            OGTLTakeInt64(is);
            break;
        }
        case OGTLCtor(0xb4d5d859):
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            OGTLCoreReadObjectVector(is, environment, error);
            OGTLCoreReadObjectVector(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 0, 's');
            break;
        }
        case OGTLCtor(0xc69708d3):
        {
            int32_t flags = [is readInt32];
            OGTLTakeBytes(is);
            OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 0, 's');
            OGTLSkipFlagged(is, environment, error, flags, 1, 's');
            break;
        }
        case OGTLCtor(0x9325705a):
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            OGTLTakeString(is);
            if (flags & (1 << 0)) OGTLCoreReadObject(is, environment, error);
            if (flags & (1 << 1)) OGTLCoreReadObject(is, environment, error);
            break;
        }
        case OGTLCtor(0x1a8afc7e):
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            OGTLCoreReadObject(is, environment, error);
            [is readInt32];
            OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 0, 'l');
            break;
        }
        case OGTLCtor(0x44e56023):
        {
            int32_t flags = [is readInt32];
            OGTLTakeString(is);
            OGTLTakeInt64(is);
            [is readInt32];
            OGTLCoreReadInt32Vector(is);
            OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
            break;
        }
        case OGTLCtor(0xcff63ea9):
        {
            int32_t flags = [is readInt32];
            OGTLTakeInt64(is);
            OGTLTakeInt64(is);
            OGTLTakeString(is);
            OGTLTakeString(is);
            OGTLSkipFlagged(is, environment, error, flags, 1, 'l');
            OGTLSkipFlagged(is, environment, error, flags, 4, 's');
            OGTLSkipFlagged(is, environment, error, flags, 2, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 3, 'l');
            if (flags & (1 << 5)) OGTLCoreReadObject(is, environment, error);
            break;
        }
        case OGTLCtor(0x933ca597):
        {
            int32_t flags = [is readInt32];
            OGTLTakeString(is);
            OGTLTakeString(is);
            OGTLTakeString(is);
            OGTLSkipFlagged(is, environment, error, flags, 0, 'l');
            break;
        }
        case OGTLCtor(0x7dbf8673):
        {
            int32_t flags = [is readInt32];
            OGTLTakeBytes(is);
            OGTLTakeString(is);
            OGTLTakeString(is);
            OGTLTakeString(is);
            if (flags & (1 << 1)) OGTLCoreReadObjectVector(is, environment, error);
            if (flags & (1 << 6)) OGTLCoreReadObject(is, environment, error);
            if (flags & (1 << 14)) OGTLCoreReadObject(is, environment, error);
            if (flags & (1 << 13)) OGTLCoreReadObject(is, environment, error);
            OGTLTakeString(is);
            OGTLSkipFlagged(is, environment, error, flags, 7, 's');
            OGTLSkipFlagged(is, environment, error, flags, 8, 's');
            if (OGTLFlagSet(flags, 15)) { [is readInt32]; [is readInt32]; }
            break;
        }
        case OGTLCtor(0xffda656d):
        {
            int32_t flags = [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 1, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 2, 'i');
            OGTLCoreReadObjectVector(is, environment, error);
            OGTLCoreReadObjectVector(is, environment, error);
            OGTLCoreReadObjectVector(is, environment, error);
            break;
        }
        case OGTLCtor(0x31bd492d):
        {
            int32_t flags = [is readInt32];
            [is readInt32];
            OGTLCoreReadObjectVector(is, environment, error);
            OGTLCoreReadObjectVector(is, environment, error);
            OGTLCoreReadObjectVector(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 0, 's');
            break;
        }
        case OGTLCtor(0x5f2d1df2):
        {
            int32_t flags = [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 3, 's');
            [is readInt32];
            OGTLTakeString(is);
            OGTLTakeInt64(is);
            OGTLTakeString(is);
            OGTLSkipFlagged(is, environment, error, flags, 0, 's');
            break;
        }
        case OGTLCtor(0x71e4ea58):
        {
            int32_t flags = [is readInt32];
            if (flags & (1 << 0)) OGTLCoreReadObject(is, environment, error);
            if (flags & (1 << 1)) OGTLCoreReadObject(is, environment, error);
            if (flags & (1 << 2)) OGTLCoreReadObject(is, environment, error);
            OGTLCoreReadObject(is, environment, error);
            [is readInt32];
            break;
        }
        case OGTLCtor(0x98613ebf):
        {
            int32_t flags = [is readInt32];
            OGTLTakeString(is);
            OGTLTakeString(is);
            [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 0, 'l');
            OGTLSkipFlagged(is, environment, error, flags, 1, 'i');
            break;
        }
        case OGTLCtor(0xea29055d):
        {
            int32_t flags = [is readInt32];
            int64_t channelId = OGTLTakeInt64(is);
            OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
            NSArray *messages = OGTLCoreReadInt32Vector(is);
            TLUpdate$updateChannelReadMessagesContents *result = [[TLUpdate$updateChannelReadMessagesContents alloc] init];
            result.channel_id = channelId;
            result.messages = messages;
            return result;
        }
        case OGTLCtor(0xf8227181):
        {
            int32_t flags = [is readInt32];
            NSArray *messages = OGTLCoreReadInt32Vector(is);
            int32_t pts = OGTLTakeInt32(is);
            int32_t ptsCount = OGTLTakeInt32(is);
            OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
            TLUpdate$updateReadMessagesContents *result = OGTLNewObject(TLUpdate$updateReadMessagesContents);
            result.messages = messages;
            [result setPts:pts];
            [result setPts_count:ptsCount];
            return result;
        }
        case OGTLCtor(0xebe07752):
        {
            int32_t flags = [is readInt32];
            TLPeer *peer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
            if (OGTLCoreIsKind(peer, [TLPeer$peerUser class]))
            {
                TLUpdate$updateUserBlocked *result = [[TLUpdate$updateUserBlocked alloc] init];
                result.user_id = ((TLPeer$peerUser *)peer).user_id;
                result.blocked = (flags & (1 << 0)) != 0;
                return result;
            }
            return nil;
        }
        case OGTLCtor(0x635b4c09):
        {
            int64_t channelId = OGTLTakeInt64(is);
            TLUpdate$updateChannel *result = [[TLUpdate$updateChannel alloc] init];
            result.channel_id = channelId;
            return result;
        }
        case OGTLCtor(0x922e6e10):
        {
            int32_t flags = [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
            int64_t channelId = OGTLTakeInt64(is);
            int32_t maxId = OGTLTakeInt32(is);
            [is readInt32];
            [is readInt32];
            TLUpdate$updateReadChannelInbox *result = OGTLNewObject(TLUpdate$updateReadChannelInbox);
            result.channel_id = channelId;
            [result setMax_id:maxId];
            return result;
        }
        case OGTLCtor(0x9c974fdf):
        {
            int32_t flags = [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
            TLPeer *peer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
            int32_t maxId = OGTLTakeInt32(is);
            [is readInt32];
            int32_t pts = OGTLTakeInt32(is);
            int32_t ptsCount = OGTLTakeInt32(is);
            TLUpdate$updateReadHistoryInbox *result = OGTLNewObject(TLUpdate$updateReadHistoryInbox);
            [result setPeer:peer];
            [result setMax_id:maxId];
            [result setPts:pts];
            [result setPts_count:ptsCount];
            return result;
        }
        case OGTLCtor(0xb75f99a9):
        {
            int64_t channelId = OGTLTakeInt64(is);
            int32_t maxId = OGTLTakeInt32(is);
            TLUpdate$updateReadChannelOutbox *result = [[TLUpdate$updateReadChannelOutbox alloc] init];
            result.channel_id = channelId;
            [result setMax_id:maxId];
            return result;
        }
        case OGTLCtor(0xf226ac08):
        {
            int64_t channelId = OGTLTakeInt64(is);
            int32_t messageId = OGTLTakeInt32(is);
            int32_t views = OGTLTakeInt32(is);
            TLUpdate$updateChannelMessageViews *result = [[TLUpdate$updateChannelMessageViews alloc] init];
            result.channel_id = channelId;
            result.n_id = messageId;
            result.views = views;
            return result;
        }
        case OGTLCtor(0x98657f0d):
        {
            int32_t flags = [is readInt32];
            int32_t firstMarker = OGTLTakeInt32(is);
            if (!OGTLCoreMarkerStartsVector(firstMarker))
            {
                OGTLCoreSkipStringWithFirstWord(is, firstMarker);
                firstMarker = OGTLTakeInt32(is);
            }
            OGTLCoreReadObjectVectorWithMarker(is, firstMarker, environment, error);
            OGTLCoreReadObjectVector(is, environment, error);
            OGTLCoreReadObjectVector(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 3, 'i');
            break;
        }
        case OGTLCtor(0x8c88c923):
        {
            int32_t flags = [is readInt32];
            int64_t channelId = OGTLTakeInt64(is);
            OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
            TLPeer *fromPeer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
            TLSendMessageAction *action = (TLSendMessageAction *)OGTLCoreReadObject(is, environment, error);
            int64_t userId = 0;
            if (OGTLCoreIsKind(fromPeer, [TLPeer$peerUser class]))
                userId = ((TLPeer$peerUser *)fromPeer).user_id;
            if (userId == 0)
                return nil;
            TLUpdate$updateChatUserTyping *result = [[TLUpdate$updateChatUserTyping alloc] init];
            result.chat_id = channelId;
            result.user_id = userId;
            result.action = action;
            return result;
        }
        case OGTLCtor(0x19360dc0):
        {
            NSArray *folderPeers = OGTLCoreReadObjectVector(is, environment, error);
            int32_t pts = OGTLTakeInt32(is);
            int32_t ptsCount = OGTLTakeInt32(is);
            TLUpdate$updateFolderPeers *result = OGTLNewObject(TLUpdate$updateFolderPeers);
            result.folder_peers = folderPeers;
            [result setPts:pts];
            [result setPts_count:ptsCount];
            return result;
        }
        case OGTLCtor(0xa03e5b85):
        case OGTLCtor(0x86b40b08):
        {
            int32_t flags = [is readInt32];
            if (signature == (int32_t)0x86b40b08 && (OGTLFlagSet(flags, 3)))
                OGTLTakeString(is);
            break;
        }
        case OGTLCtor(0x17399fad):
        {
            int32_t flags = [is readInt32];
            OGTLTakeDouble(is);
            [is readInt32];
            [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 2, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 4, 'd');
            break;
        }
        case OGTLCtor(0xd38ff1c2):
        {
            int32_t flags = [is readInt32];
            OGTLTakeDouble(is);
            [is readInt32];
            [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 2, 'i');
            break;
        }
        default:
            break;
    }
    return nil;
}

@end

@interface OGTLPhoneConnectionParser : OGTLManualParser
@end

@implementation OGTLPhoneConnectionParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused tlContext error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0x9cc123c7))
    {
        TLPhoneConnection$phoneConnection *result = OGTLNewObject(TLPhoneConnection$phoneConnection);
        result.flags = [is readInt32];
        result.n_id = [is readInt64];
        result.ip = OGTLTakeString(is);
        result.ipv6 = OGTLTakeString(is);
        result.port = OGTLTakeInt32(is);
        result.peer_tag = OGTLTakeBytes(is);
        if (error != NULL)
            *error = nil;
        return result;
    }
    
    if (signature == OGTLCtor(0x635fe375))
    {
        TLPhoneConnection$phoneConnectionWebrtc *result = OGTLNewObject(TLPhoneConnection$phoneConnectionWebrtc);
        result.flags = [is readInt32];
        result.n_id = [is readInt64];
        result.ip = OGTLTakeString(is);
        result.ipv6 = OGTLTakeString(is);
        result.port = OGTLTakeInt32(is);
        result.username = [is readString];
        result.password = OGTLTakeString(is);
        if (error != NULL)
            *error = nil;
        return result;
    }
    
    TGLog(@"CALL parse phoneConnection.unknown sig=0x%08x", signature);
    return nil;
}

@end

@interface OGTLModernWebPageEmptyParser : TLWebPage$webPageEmpty
@end

@implementation OGTLModernWebPageEmptyParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    OGTLModernWebPageEmptyParser *result = [[OGTLModernWebPageEmptyParser alloc] init];
    int32_t flags = [is readInt32];
    result.n_id = [is readInt64];
    OGTLSkipFlagged(is, environment, error, flags, 0, 's');
    return result;
}

@end

@interface OGTLModernWebPageParser : TLWebPage$webPage
@end

@implementation OGTLModernWebPageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernWebPageParser *result = [[OGTLModernWebPageParser alloc] init];
    int32_t flags = [is readInt32];
    OGTLTakeInt64(is);
    OGTLTakeString(is);
    OGTLTakeString(is);
    [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 0, 's');
    OGTLSkipFlagged(is, environment, error, flags, 1, 's');
    OGTLSkipFlagged(is, environment, error, flags, 2, 's');
    OGTLSkipFlagged(is, environment, error, flags, 3, 's');
    OGTLSkipFlagged(is, environment, error, flags, 4, 'o');
    if (OGTLFlagSet(flags, 5))
    {
        OGTLTakeString(is);
        OGTLTakeString(is);
    }
    if (OGTLFlagSet(flags, 6))
    {
        [is readInt32];
        [is readInt32];
    }
    OGTLSkipFlagged(is, environment, error, flags, 7, 'i');
    OGTLSkipFlagged(is, environment, error, flags, 8, 's');
    OGTLSkipFlagged(is, environment, error, flags, 9, 'o');
    OGTLSkipFlagged(is, environment, error, flags, 10, 'o');
    OGTLSkipFlagged(is, environment, error, flags, 12, 'v');
    return result;
}

@end

static const OGTLSkipLayout OGTLMediaUnsupportedSkipLayouts[] =
{
    {(int32_t)0x8a53b014, "fo0?v", OGTLSkipResultNone},
    {(int32_t)0x9f84f49e, "", OGTLSkipResultNone},
    {(int32_t)0xa8852491, "lv", OGTLSkipResultNone},
    {(int32_t)0xaa073beb, "fm1?t3?si4?i5?li", OGTLSkipResultNone},
    {(int32_t)0xca5cab89, "io", OGTLSkipResultNone},
    {(int32_t)0xceaa3ea1, "fl3?iiiim4?i5?l1?si", OGTLSkipResultNone},
    {(int32_t)0xf6a548d3, "fss0?o2?isls4?o", OGTLSkipResultNone},
    {(int32_t)0xfdb19008, "o", OGTLSkipResultNone},
    {(int32_t)0x2238f214, "fiib3?s3?l4?s5?l", OGTLSkipResultNone},
    {(int32_t)0x2ec0533f, "osssss", OGTLSkipResultNone},
    {(int32_t)0x3ded6320, "", OGTLSkipResultNone},
    {(int32_t)0x773f4e66, "foo0?o", OGTLSkipResultNone}
};

@interface OGTLModernMessageMediaUnsupportedParser : TLMessageMedia$messageMediaUnsupported
@end

@implementation OGTLModernMessageMediaUnsupportedParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    const OGTLSkipLayout *skipLayout = OGTLFindSkipLayout(OGTLMediaUnsupportedSkipLayouts, sizeof(OGTLMediaUnsupportedSkipLayouts) / sizeof(OGTLMediaUnsupportedSkipLayouts[0]), signature);
    if (skipLayout != NULL)
        OGTLSkipFields(is, skipLayout->layout, environment, error);
    else
    {
        switch (signature)
        {
            case OGTLCtor(0x56e0d474):
            {
                TLMessageMedia$messageMediaGeo *result = [[TLMessageMedia$messageMediaGeo alloc] init];
                result.geo = (TLGeoPoint *)OGTLCoreReadObject(is, environment, error);

                if (OGTLCoreFailed(error))
                    return nil;

                return result;
            }
            case OGTLCtor(0x70322949):
            {
                TLMessageMedia$messageMediaContact *result = [[TLMessageMedia$messageMediaContact alloc] init];
                result.phone_number = [is readString];
                result.first_name = [is readString];
                result.last_name = [is readString];
                result.vcard = [is readString];

                result.user_id = [is readInt64];

                return result;
            }
            default:
                break;
        }
    }
    if (OGTLCoreFailed(error))
        return nil;
    return OGTLNewObject(TLMessageMedia$messageMediaUnsupported);
}

@end

@interface OGTLModernMessageMediaGeoLiveParser : TLMessageMedia$messageMediaGeoLive
@end

@implementation OGTLModernMessageMediaGeoLiveParser

- (int32_t)TLconstructorSignature
{
    return OGTLCtor(0xb940c666);
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernMessageMediaGeoLiveParser *result = [[OGTLModernMessageMediaGeoLiveParser alloc] init];
    int32_t flags = [is readInt32];
    result.geo = (TLGeoPoint *)OGTLCoreReadObject(is, environment, error);
    OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
    result.period = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 1, 'i');
    return result;
}

@end

@interface OGTLModernMessageMediaPhotoParser : TLMessageMedia$messageMediaPhoto
@end

@implementation OGTLModernMessageMediaPhotoParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernMessageMediaPhotoParser *result = [[OGTLModernMessageMediaPhotoParser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (OGTLFlagSet(flags, 0))
        result.photo = (TLPhoto *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(flags, 2))
        result.ttl_seconds = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 4, 'o');
    return result;
}

@end

@interface OGTLModernMessageMediaDocumentParser : TLMessageMedia$messageMediaDocument
@end

@implementation OGTLModernMessageMediaDocumentParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernMessageMediaDocumentParser *result = [[OGTLModernMessageMediaDocumentParser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (OGTLFlagSet(flags, 0))
        result.document = (TLDocument *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(flags, 5))
    {
        int32_t marker = OGTLTakeInt32(is);
        OGTLCoreReadObjectVectorOrSingleWithMarker(is, marker, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
    }
    OGTLSkipFlagged(is, environment, error, flags, 9, 'o');
    OGTLSkipFlagged(is, environment, error, flags, 10, 'i');
    if (OGTLFlagSet(flags, 2))
        result.ttl_seconds = [is readInt32];
    return result;
}

@end

@interface OGTLModernMessageMediaWebPageParser : TLMessageMedia$messageMediaWebPage
@end

@implementation OGTLModernMessageMediaWebPageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernMessageMediaWebPageParser *result = [[OGTLModernMessageMediaWebPageParser alloc] init];
    [is readInt32];
    result.webpage = (TLWebPage *)OGTLCoreReadObject(is, environment, error);
    return result;
}

@end

@interface OGTLModernMessageMediaDiceParser : TLMessageMedia$messageMediaUnsupported
@end

@implementation OGTLModernMessageMediaDiceParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0x08cbec07))
    {
        int32_t flags = [is readInt32];
        [is readInt32];
        OGTLTakeString(is);
        OGTLSkipFlagged(is, environment, error, flags, 0, 'o');
    }
    else
    {
        [is readInt32];
        OGTLTakeString(is);
    }
    if (OGTLCoreFailed(error))
        return nil;
    return OGTLNewObject(TLMessageMedia$messageMediaUnsupported);
}

@end

@interface OGTLTextWithEntitiesValue : OGTLManualParser
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSArray *entities;
@end

@implementation OGTLTextWithEntitiesValue
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

static NSArray *OGTLCoreReadPollStringVector(NSInputStream *is, __autoreleasing NSError **error)
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

@interface OGTLTextWithEntitiesParser : OGTLManualParser
@end

@implementation OGTLTextWithEntitiesParser
- (int32_t)TLconstructorSignature { return 0; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLTextWithEntitiesValue *result = [[OGTLTextWithEntitiesValue alloc] init];
    result.text = [is readString];
    result.entities = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}
@end

static NSString *OGTLCorePollText(id text)
{
    if (OGTLCoreIsKind(text, [NSString class]))
        return text;
    if (OGTLCoreIsKind(text, [OGTLTextWithEntitiesValue class]))
        return ((OGTLTextWithEntitiesValue *)text).text ?: @"";
    return @"";
}

@interface OGTLPollAnswerParser : OGTLManualParser
@end

@implementation OGTLPollAnswerParser
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
    id text = OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.text = OGTLCorePollText(text);
    result.option = [is readBytes];
    if (result.flags & (1 << 0))
        result.media = OGTLCoreReadObject(is, environment, error);
    if (result.flags & (1 << 1))
    {
        result.addedBy = OGTLCoreReadObject(is, environment, error);
        result.date = [is readInt32];
    }
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}
@end

@interface OGTLPollParser : OGTLManualParser
@end

@implementation OGTLPollParser
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
        id question = OGTLCoreReadObject(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        result.question = OGTLCorePollText(question);
    }
    result.answers = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    if (result.flags & (1 << 4))
        result.closePeriod = [is readInt32];
    if (result.flags & (1 << 5))
        result.closeDate = [is readInt32];
    if (signature == (int32_t)0x966e2dbf && (result.flags & (1 << 12)))
        result.countries = OGTLCoreReadPollStringVector(is, error);
    if (OGTLCoreFailed(error))
        return nil;
    if (signature != (int32_t)0x86e18161)
        result.pollHash = [is readInt64];
    return result;
}
@end

@interface OGTLPollAnswerVotersParser : OGTLManualParser
@end

@implementation OGTLPollAnswerVotersParser
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
    if (OGTLFlagSet(result.flags, 2))
    {
        result.voters = [is readInt32];
        result.recentVoters = OGTLCoreReadObjectVector(is, environment, error);
    }
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}
@end

@interface OGTLPollResultsParser : OGTLManualParser
@end

@implementation OGTLPollResultsParser
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
        result.results = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    if (OGTLFlagSet(result.flags, 2))
        result.totalVoters = [is readInt32];
    if (OGTLFlagSet(result.flags, 3))
        result.recentVoters = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    if (result.flags & (1 << 4))
    {
        result.solution = [is readString];
        result.solutionEntities = OGTLCoreReadObjectVector(is, environment, error);
    }
    if (OGTLCoreFailed(error))
        return nil;
    if (signature == (int32_t)0xba7bb15e && (result.flags & (1 << 5)))
        result.solutionMedia = OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}
@end


@interface OGTLModernMessageMediaPollParser : TLMessageMedia$messageMediaPollCodex
@end

@implementation OGTLModernMessageMediaPollParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    int32_t first = [is readInt32];
    bool firstIsPoll = first == (int32_t)0x86e18161 || first == (int32_t)0xb8425be9 || first == (int32_t)0x966e2dbf;
    int32_t flags = 0;
    id poll = nil;
    if (firstIsPoll)
        poll = OGTLCoreBuildObject(is, first, environment, error);
    else
    {
        flags = first;
        poll = OGTLCoreReadObject(is, environment, error);
    }
    if (OGTLCoreFailed(error))
        return nil;
    id results = OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    if (!firstIsPoll && (flags & (1 << 0)))
        OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    if (!OGTLCoreIsKind(poll, [TLCodexPollValue class]) || !OGTLCoreIsKind(results, [TLCodexPollResultsValue class]))
        return OGTLNewObject(TLMessageMedia$messageMediaUnsupported);
    TLMessageMedia$messageMediaPollCodex *result = [[TLMessageMedia$messageMediaPollCodex alloc] init];
    result.poll = poll;
    result.results = results;
    return result;
}

@end

@interface OGTLUpdateMessagePollParser : TLUpdate$updateMessagePollCodex
@end

@implementation OGTLUpdateMessagePollParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdate$updateMessagePollCodex *result = [[TLUpdate$updateMessagePollCodex alloc] init];
    int32_t flags = [is readInt32];
    if (OGTLFlagSet(flags, 1))
    {
        id peer = OGTLCoreReadObject(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        if (OGTLCoreIsKind(peer, [TLPeer class]))
            [result setPeer:peer];
        result.msg_id = [is readInt32];
    }
    OGTLSkipFlagged(is, environment, error, flags, 2, 'i');
    result.poll_id = [is readInt64];
    if (OGTLFlagSet(flags, 0))
    {
        id poll = OGTLCoreReadObject(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        if (OGTLCoreIsKind(poll, [TLCodexPollValue class]))
            result.poll = poll;
    }
    id results = OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    if (OGTLCoreIsKind(results, [TLCodexPollResultsValue class]))
        result.results = results;
    return result;
}

@end

@interface OGTLModernMessageEntityMentionNameParser : TLMessageEntity$messageEntityMentionName
@end

@implementation OGTLModernMessageEntityMentionNameParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    OGTLModernMessageEntityMentionNameParser *result = [[OGTLModernMessageEntityMentionNameParser alloc] init];
    result.offset = OGTLTakeInt32(is);
    result.length = OGTLTakeInt32(is);
    result.user_id = [is readInt64];
    return result;
}

@end

@interface OGTLModernMessageEntityCustomEmojiParser : TLMessageEntity$messageEntityCustomEmoji
@end

@implementation OGTLModernMessageEntityCustomEmojiParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLMessageEntity$messageEntityCustomEmoji *result = [[TLMessageEntity$messageEntityCustomEmoji alloc] init];
    result.offset = OGTLTakeInt32(is);
    result.length = OGTLTakeInt32(is);
    result.document_id = [is readInt64];
    return result;
}

@end

@interface OGTLModernMessageEntitySimpleParser : TLMessageEntity$messageEntityUnknown
@end

@implementation OGTLModernMessageEntitySimpleParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused tlContext error:(__autoreleasing NSError **)__unused error
{
    TLMessageEntity *result = nil;
    if (signature == (int32_t)0x9c4e7e8b)
        result = [[TLMessageEntity$messageEntityUnderline alloc] init];
    else if (signature == (int32_t)0xbf0693d4)
        result = [[TLMessageEntity$messageEntityStrike alloc] init];
    else if (signature == (int32_t)0x32ca960f)
        result = [[TLMessageEntity$messageEntitySpoiler alloc] init];
    else
        result = [[OGTLModernMessageEntitySimpleParser alloc] init];
    if (signature == OGTLCtor(0xf1ccaaac) || signature == OGTLCtor(0x904ac7c7))
        [is readInt32];
    result.offset = OGTLTakeInt32(is);
    result.length = OGTLTakeInt32(is);
    if (signature == OGTLCtor(0x904ac7c7))
        [is readInt32];
    if (signature == OGTLCtor(0x6c622f67) || signature == OGTLCtor(0xc6c1e5a7))
        OGTLTakeString(is);
    return result;
}

@end

@interface OGTLDialogsParser : TLmessages_Dialogs
@end

@implementation OGTLDialogsParser

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

    result.dialogs = OGTLCoreReadStrictObjectVectorWithRole(is, @"messages.dialogs.dialogs", environment, error);
    if (result.dialogs == nil)
        return nil;
    result.messages = OGTLCoreReadStrictObjectVectorWithRole(is, @"messages.dialogs.messages", environment, error);
    if (result.messages == nil)
        return nil;
    result.chats = OGTLCoreReadStrictObjectVectorWithRole(is, @"messages.dialogs.chats", environment, error);
    if (result.chats == nil)
        return nil;
    result.users = OGTLCoreReadStrictObjectVectorWithRole(is, @"messages.dialogs.users", environment, error);
    if (result.users == nil)
        return nil;

    return result;
}

@end

@interface OGTLModernContactParser : TLContact$contact
@end

@implementation OGTLModernContactParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernContactParser *result = [[OGTLModernContactParser alloc] init];
    result.user_id = [is readInt64];
    TLBool *mutual = (TLBool *)OGTLCoreReadObject(is, environment, error);
    [result setMutual:[mutual boolValue]];
    return result;
}

@end

@interface OGTLModernContactsParser : TLcontacts_Contacts$contacts_contacts
@end

@implementation OGTLModernContactsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernContactsParser *result = [[OGTLModernContactsParser alloc] init];
    int32_t vectorMarker = OGTLTakeInt32(is);
    int32_t count = 0;
    OGTLCoreVectorCountForMarker(is, vectorMarker, &count);
    
    NSMutableArray *parsedContacts = OGTLCoreMakeArray(count);
    bool usersEarly = false;
    int32_t earlyUsersMarker = 0;
    for (int32_t i = 0; i < count; i++)
    {
        int32_t contactSignature = OGTLTakeInt32(is);
        if (OGTLCoreMarkerStartsVector(contactSignature))
        {
            usersEarly = true;
            earlyUsersMarker = contactSignature;
            break;
        }
        if (contactSignature == OGTLCtor(0x145ade0b))
        {
            TLContact$contact *contact = OGTLNewObject(TLContact$contact);
            contact.user_id = [is readInt64];
            int32_t mutualSignature = OGTLTakeInt32(is);
            [contact setMutual:mutualSignature == (int32_t)TL_BOOL_TRUE_CONSTRUCTOR];
            [parsedContacts addObject:contact];
        }
        else
        {
            id contact = OGTLCoreBuildObject(is, contactSignature, environment, error);
            if (OGTLCoreFailed(error))
                return nil;
            if (contact != nil)
                [parsedContacts addObject:contact];
        }
    }
    
    [result setContacts:parsedContacts];
    if (usersEarly)
    {
        [result setSaved_count:0];
        result.users = OGTLCoreReadMaybeDoubleObjectVectorWithMarker(is, earlyUsersMarker, environment, error);
        return result;
    }
    int32_t nextMarker = OGTLTakeInt32(is);
    if (nextMarker != TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
    {
        [result setSaved_count:nextMarker];
        int32_t lateUsersMarker = OGTLTakeInt32(is);
        result.users = OGTLCoreReadMaybeDoubleObjectVectorWithMarker(is, lateUsersMarker, environment, error);
    }
    else
    {
        [result setSaved_count:0];
        result.users = OGTLCoreReadMaybeDoubleObjectVectorWithMarker(is, nextMarker, environment, error);
    }
    return result;
}

@end

static NSError *OGTLLangPackError(NSString *description)
{
    return [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: description}];
}

static TLLangPackString *OGTLReadLangPackString(NSInputStream *is, int32_t signature, bool *failed)
{
    switch (signature)
    {
        case (int32_t)0xcad181f6:
        {
            TLLangPackString$langPackString *string = [[TLLangPackString$langPackString alloc] init];
            string.key = [is readString:failed];
            string.value = [is readString:failed];
            return string;
        }
        case (int32_t)0x6c47ac9f:
        {
            TLLangPackString$langPackStringPluralized *string = [[TLLangPackString$langPackStringPluralized alloc] init];
            int32_t flags = [is readInt32:failed];
            string.flags = flags;
            string.key = [is readString:failed];
            if (OGTLFlagSet(flags, 0))
                string.zero_value = [is readString:failed];
            if (OGTLFlagSet(flags, 1))
                string.one_value = [is readString:failed];
            if (OGTLFlagSet(flags, 2))
                string.two_value = [is readString:failed];
            if (OGTLFlagSet(flags, 3))
                string.few_value = [is readString:failed];
            if (OGTLFlagSet(flags, 4))
                string.many_value = [is readString:failed];
            string.other_value = [is readString:failed];
            return string;
        }
        case (int32_t)0x2979eeb2:
        {
            TLLangPackString$langPackStringDeleted *string = [[TLLangPackString$langPackStringDeleted alloc] init];
            string.key = [is readString:failed];
            return string;
        }
        default:
            return nil;
    }
}

@interface OGTLLangPackStringParser : TLLangPackString$langPackString
@end

@implementation OGTLLangPackStringParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused tlContext error:(__autoreleasing NSError **)error
{
    bool failed = false;
    TLLangPackString *result = OGTLReadLangPackString(is, signature, &failed);
    if (failed || result == nil)
    {
        if (error != NULL)
            *error = OGTLLangPackError([NSString stringWithFormat:@"Invalid LangPackString %08x", signature]);
        return nil;
    }
    return result;
}

@end

@interface OGTLLangPackDifferenceParser : TLLangPackDifference$langPackDifference
@end

@implementation OGTLLangPackDifferenceParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    bool failed = false;
    TLLangPackDifference$langPackDifference *result = [[TLLangPackDifference$langPackDifference alloc] init];
    result.lang_code = [is readString:&failed];
    result.from_version = [is readInt32:&failed];
    result.version = [is readInt32:&failed];
    int32_t vectorMarker = [is readInt32:&failed];
    int32_t count = failed ? 0 : [is readInt32:&failed];
    if (failed || vectorMarker != TL_UNIVERSAL_VECTOR_CONSTRUCTOR || count < 0 || count > 100000)
    {
        if (error != NULL)
            *error = OGTLLangPackError(failed ? @"Unexpected end of stream in langPackDifference" : [NSString stringWithFormat:@"Invalid langPackDifference strings vector %08x count %d", vectorMarker, count]);
        return nil;
    }

    NSMutableArray *strings = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)count];
    for (int32_t i = 0; i < count; i++)
    {
        @autoreleasepool
        {
            int32_t stringSignature = [is readInt32:&failed];
            if (failed)
                break;
            id string = OGTLReadLangPackString(is, stringSignature, &failed);
            if (string == nil && !failed)
            {
                string = OGTLCoreBuildObject(is, stringSignature, environment, error);
                if (OGTLCoreFailed(error))
                    return nil;
            }
            if (failed)
                break;
            if (string != nil)
                [strings addObject:string];
        }
        OGTLCoreCooperateWithInteraction(i);
    }
    if (failed)
    {
        if (error != NULL)
            *error = OGTLLangPackError(@"Unexpected end of stream in langPackDifference strings");
        return nil;
    }

    result.strings = strings;
    return result;
}

@end

@interface OGTLModernBlockedParser : TLcontacts_Blocked$contacts_blocked
@end

@implementation OGTLModernBlockedParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLcontacts_Blocked$contacts_blocked *result = OGTLNewObject(TLcontacts_Blocked$contacts_blocked);
    if (signature == OGTLCtor(0xe1664194))
        [is readInt32];
    OGTLCoreReadObjectVector(is, environment, error);
    OGTLCoreReadObjectVector(is, environment, error);
    [result setBlocked:@[]];
    result.users = OGTLCoreReadObjectVector(is, environment, error);
    return result;
}

@end

@interface OGTLModernMessageFwdHeaderParser : TLMessageFwdHeader$messageFwdHeaderMeta
@end

@implementation OGTLModernMessageFwdHeaderParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernMessageFwdHeaderParser *result = [[OGTLModernMessageFwdHeaderParser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (OGTLFlagSet(flags, 0))
    {
        TLPeer *fromPeer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
        if (OGTLCoreIsKind(fromPeer, [TLPeer$peerUser class]))
            [result setFrom_id:((TLPeer$peerUser *)fromPeer).user_id];
        else if (OGTLCoreIsKind(fromPeer, [TLPeer$peerChannel class]))
            [result setChannel_id:((TLPeer$peerChannel *)fromPeer).channel_id];
        else if (OGTLCoreIsKind(fromPeer, [TLPeer$peerChat class]))
            [result setFrom_id:((TLPeer$peerChat *)fromPeer).chat_id];
    }
    OGTLSkipFlagged(is, environment, error, flags, 5, 's');
    result.date = [is readInt32];
    if (OGTLFlagSet(flags, 2))
        result.channel_post = [is readInt32];
    if (OGTLFlagSet(flags, 3))
        result.post_author = [is readString];
    if (OGTLFlagSet(flags, 4))
    {
        result.saved_from_peer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
        result.saved_from_msg_id = [is readInt32];
    }
    OGTLSkipFlagged(is, environment, error, flags, 8, 'o');
    OGTLSkipFlagged(is, environment, error, flags, 9, 's');
    OGTLSkipFlagged(is, environment, error, flags, 10, 'i');
    OGTLSkipFlagged(is, environment, error, flags, 6, 's');
    return result;
}

@end

@interface OGTLMessageViewsResultParser : OGTLManualParser
@end

@implementation OGTLMessageViewsResultParser

- (int32_t)TLconstructorSignature
{
    return OGTLCtor(0xb6c4f543);
}

- (int32_t)TLconstructorName
{
    return OGTLCtor(0xb6c4f543);
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    int32_t vectorMarker = OGTLTakeInt32(is);
    int32_t count = 0;
    if (!OGTLCoreVectorCountForMarker(is, vectorMarker, &count))
    {
        count = 0;
    }
    
    NSMutableArray *countList = OGTLCoreMakeArray(count);
    for (int32_t i = 0; i < count; i++)
    {
        int32_t itemSignature = OGTLTakeInt32(is);
        int32_t itemViews = 0;
        if (itemSignature == OGTLCtor(0x455b853d))
        {
            int32_t flags = [is readInt32];
            if (OGTLFlagSet(flags, 0))
                itemViews = OGTLTakeInt32(is);
            OGTLSkipFlagged(is, environment, error, flags, 1, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 2, 'o');
            OGTLSkipFlagged(is, environment, error, flags, 3, 'o');
            if (OGTLCoreFailed(error))
            {
                TGLog(@"VIEWS failed nested field index=%d flags=0x%08x error=%@", i, flags, *error);
                *error = nil;
            }
        }
        else
            TGLog(@"VIEWS unknown MessageViews item sig=0x%08x index=%d", itemSignature, i);
        [countList addObject:@(itemViews)];
    }
    
    OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
    {
        TGLog(@"VIEWS failed chats vector error=%@", *error);
        *error = nil;
    }
    OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
    {
        TGLog(@"VIEWS failed users vector error=%@", *error);
        *error = nil;
    }
    
    return (id<TLObject>)countList;
}

@end

@interface OGTLModernMessagesParser : TLmessages_Messages$messages_messages
@end

@implementation OGTLModernMessagesParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernMessagesParser *result = [[OGTLModernMessagesParser alloc] init];
    result.messages = OGTLCoreReadStrictObjectVectorWithRole(is, @"messages.messages.messages", environment, error);
    if (OGTLCoreFailed(error))
    {
        return nil;
    }
    if (signature == OGTLCtor(0x1d73e7ea))
    {
        OGTLCoreReadStrictObjectVectorWithRole(is, @"messages.messages.topics", environment, error);
        if (OGTLCoreFailed(error))
        {
            return nil;
        }
    }
    result.chats = OGTLCoreReadStrictObjectVectorWithRole(is, @"messages.messages.chats", environment, error);
    if (OGTLCoreFailed(error))
    {
        return nil;
    }
    result.users = OGTLCoreReadStrictObjectVectorWithRole(is, @"messages.messages.users", environment, error);
    if (OGTLCoreFailed(error))
    {
        return nil;
    }
    
    return result;
}

@end

@interface OGTLModernMessagesSliceParser : TLmessages_Messages$messages_messagesSlice
@end

@implementation OGTLModernMessagesSliceParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernMessagesSliceParser *result = [[OGTLModernMessagesSliceParser alloc] init];
    int32_t flags = [is readInt32];
    result.count = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
    OGTLSkipFlagged(is, environment, error, flags, 2, 'i');
    if (signature == (int32_t)0x5f206716 && (OGTLFlagSet(flags, 3)))
    {
        OGTLCoreReadObject(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
    }
    
    result.messages = OGTLCoreReadStrictObjectVectorWithRole(is, @"messagesSlice.messages", environment, error);
    if (OGTLCoreFailed(error))
    {
        return nil;
    }
    if (signature == OGTLCtor(0x5f206716))
    {
        OGTLCoreReadStrictObjectVectorWithRole(is, @"messagesSlice.topics", environment, error);
        if (OGTLCoreFailed(error))
        {
            return nil;
        }
    }
    result.chats = OGTLCoreReadStrictObjectVectorWithRole(is, @"messagesSlice.chats", environment, error);
    if (OGTLCoreFailed(error))
    {
        return nil;
    }
    result.users = OGTLCoreReadStrictObjectVectorWithRole(is, @"messagesSlice.users", environment, error);
    if (OGTLCoreFailed(error))
    {
        return nil;
    }
    
    return result;
}

@end

@interface OGTLModernDraftMessageEmptyParser : TLDraftMessage$draftMessageEmpty
@end

@implementation OGTLModernDraftMessageEmptyParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    int32_t flags = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
    return OGTLNewObject(TLDraftMessage$draftMessageEmpty);
}

@end

@interface OGTLModernInputPeerValue : OGTLManualParser
@property (nonatomic) int32_t signature;
@property (nonatomic) int64_t peerId;
@property (nonatomic) int64_t accessHash;
@property (nonatomic) int32_t messageId;
@property (nonatomic, strong) id sourcePeer;
@end

@implementation OGTLModernInputPeerValue
- (int32_t)TLconstructorSignature { return _signature; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

static OGTLModernInputPeerValue *OGTLCoreReadModernInputPeerValue(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t signature = [is readInt32];
    OGTLModernInputPeerValue *result = [[OGTLModernInputPeerValue alloc] init];
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
            result.sourcePeer = OGTLCoreReadModernInputPeerValue(is, environment, error);
            if (OGTLCoreFailed(error))
                return nil;
            result.messageId = [is readInt32];
            result.peerId = [is readInt64];
            break;
        default:
        {
            id object = TLMetaClassStore::constructObject(is, signature, environment, nil, error);
            if (OGTLCoreFailed(error))
                return nil;
            result.sourcePeer = object;
            break;
        }
    }
    return result;
}

@interface OGTLModernInputReplyToValue : OGTLManualParser
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

@implementation OGTLModernInputReplyToValue
- (int32_t)TLconstructorSignature { return _signature; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

@interface OGTLModernInputReplyToParser : OGTLManualParser
@end

@implementation OGTLModernInputReplyToParser
- (int32_t)TLconstructorSignature { return 0; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernInputReplyToValue *result = [[OGTLModernInputReplyToValue alloc] init];
    result.signature = signature;
    if (signature == (int32_t)0x5881323a)
    {
        result.replyToPeer = OGTLCoreReadModernInputPeerValue(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        result.storyId = [is readInt32];
        return result;
    }
    if (signature == (int32_t)0x69d66c45)
    {
        result.monoforumPeer = OGTLCoreReadModernInputPeerValue(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        return result;
    }
    result.flags = [is readInt32];
    result.replyToMessageId = [is readInt32];
    if (result.flags & (1 << 0))
        result.topMessageId = [is readInt32];
    if (result.flags & (1 << 1))
    {
        result.replyToPeer = OGTLCoreReadModernInputPeerValue(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
    }
    if (OGTLFlagSet(result.flags, 2))
        result.quoteText = [is readString];
    if (OGTLFlagSet(result.flags, 3))
    {
        result.quoteEntities = OGTLCoreReadObjectVector(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
    }
    if (result.flags & (1 << 4))
        result.quoteOffset = [is readInt32];
    if (signature != (int32_t)0x22c0f6d5 && (result.flags & (1 << 5)))
    {
        result.monoforumPeer = OGTLCoreReadModernInputPeerValue(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
    }
    if (signature != (int32_t)0x22c0f6d5 && (result.flags & (1 << 6)))
        result.todoItemId = [is readInt32];
    if ((signature == (int32_t)0x3bd4b7c2 || signature == (int32_t)0x75c1ad70) && (result.flags & (1 << 7)))
        result.pollOption = [is readBytes];
    if (signature == (int32_t)0x75c1ad70 && (result.flags & (1 << 8)))
    {
        OGTLCoreReadObjectVector(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
    }
    return result;
}
@end

@interface OGTLModernDraftMessageParser : TLDraftMessage$draftMessage
@end

@implementation OGTLModernDraftMessageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLDraftMessage$draftMessage *result = [[TLDraftMessage$draftMessage alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    OGTLSkipFlagged(is, environment, error, flags, 4, 'o');
    if (OGTLCoreFailed(error))
        return nil;
    result.message = [is readString];
    if (OGTLFlagSet(flags, 3))
        result.entities = OGTLCoreReadObjectVectorOrSingle(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    OGTLSkipFlagged(is, environment, error, flags, 5, 'o');
    if (OGTLCoreFailed(error))
        return nil;
    result.date = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 7, 'l');
    bool hasSuggestedPost = signature == OGTLCtor(0x96eaa5eb) || signature == OGTLCtor(0x60fe3294);
    bool hasRichMessage = signature == OGTLCtor(0x60fe3294);
    if (hasSuggestedPost && (OGTLFlagSet(flags, 8)))
        OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    if (hasRichMessage && (OGTLFlagSet(flags, 9)))
        OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}

@end

@interface OGTLModernUpdateDraftMessageParser : TLUpdate$updateDraftMessage
@end

@implementation OGTLModernUpdateDraftMessageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdate$updateDraftMessage *result = OGTLNewObject(TLUpdate$updateDraftMessage);
    int32_t flags = [is readInt32];
    result.peer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
    if (signature == (int32_t)0xedfc111e && (OGTLFlagSet(flags, 1)))
        OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.draft = (TLDraftMessage *)OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}

@end

@interface OGTLModernChatParticipantParser : OGTLManualParser
@end

@implementation OGTLModernChatParticipantParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused tlContext error:(__autoreleasing NSError **)__unused error
{
    TLChatParticipant *parsed = nil;
    switch (signature)
    {
        case OGTLCtor(0xc02d4007):
        {
            TLChatParticipant$chatParticipant *participant = OGTLNewObject(TLChatParticipant$chatParticipant);
            participant.user_id = [is readInt64];
            participant.inviter_id = [is readInt64];
            participant.date = OGTLTakeInt32(is);
            parsed = participant;
            break;
        }
        case OGTLCtor(0xe46bcee4):
        {
            TLChatParticipant$chatParticipantCreator *participant = OGTLNewObject(TLChatParticipant$chatParticipantCreator);
            participant.user_id = [is readInt64];
            parsed = participant;
            break;
        }
        case OGTLCtor(0xa0933f5b):
        {
            TLChatParticipant$chatParticipantAdmin *participant = OGTLNewObject(TLChatParticipant$chatParticipantAdmin);
            participant.user_id = [is readInt64];
            participant.inviter_id = [is readInt64];
            participant.date = OGTLTakeInt32(is);
            parsed = participant;
            break;
        }
    }
    return parsed;
}

@end

@interface OGTLModernChannelParticipantParser : OGTLManualParser
@end

@implementation OGTLModernChannelParticipantParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    int32_t flags = 0;
    TLChannelParticipant *parsed = nil;
    switch (signature)
    {
        case OGTLCtor(0xc00c07c0):
        {
            TLChannelParticipant$channelParticipant *participant = OGTLNewObject(TLChannelParticipant$channelParticipant);
            participant.user_id = [is readInt64];
            participant.date = OGTLTakeInt32(is);
            parsed = participant;
            break;
        }
        case OGTLCtor(0x1bd54456):
        {
            flags = OGTLTakeInt32(is);
            TLChannelParticipant$channelParticipant *participant = OGTLNewObject(TLChannelParticipant$channelParticipant);
            participant.user_id = [is readInt64];
            participant.date = OGTLTakeInt32(is);
            OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 2, 's');
            parsed = participant;
            break;
        }
        case (int32_t)0x35a8bfa7:
        {
            flags = OGTLTakeInt32(is);
            TLChannelParticipant$channelParticipantSelf *participant = OGTLNewObject(TLChannelParticipant$channelParticipantSelf);
            participant.user_id = [is readInt64];
            participant.inviter_id = [is readInt64];
            participant.date = OGTLTakeInt32(is);
            parsed = participant;
            break;
        }
        case OGTLCtor(0xa9478a1a):
        {
            flags = OGTLTakeInt32(is);
            TLChannelParticipant$channelParticipantSelf *participant = OGTLNewObject(TLChannelParticipant$channelParticipantSelf);
            participant.user_id = [is readInt64];
            participant.inviter_id = [is readInt64];
            participant.date = OGTLTakeInt32(is);
            OGTLSkipFlagged(is, environment, error, flags, 1, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 2, 's');
            parsed = participant;
            break;
        }
        case OGTLCtor(0x2fe601d3):
        {
            flags = OGTLTakeInt32(is);
            TLChannelParticipant$channelParticipantCreator *participant = OGTLNewObject(TLChannelParticipant$channelParticipantCreator);
            participant.user_id = [is readInt64];
            OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 0, 's');
            parsed = participant;
            break;
        }
        case OGTLCtor(0x34c3bb53):
        {
            flags = OGTLTakeInt32(is);
            TLChannelParticipant$channelParticipantAdmin *participant = OGTLNewObject(TLChannelParticipant$channelParticipantAdmin);
            [participant setFlags:flags];
            participant.user_id = [is readInt64];
            if (OGTLFlagSet(flags, 1))
                participant.inviter_id = [is readInt64];
            participant.promoted_by = [is readInt64];
            participant.date = OGTLTakeInt32(is);
            participant.admin_rights = (TLChannelAdminRights *)OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 2, 's');
            parsed = participant;
            break;
        }
        case (int32_t)0x6df8014e:
        {
            flags = OGTLTakeInt32(is);
            TLChannelParticipant$channelParticipantBanned *participant = OGTLNewObject(TLChannelParticipant$channelParticipantBanned);
            [participant setFlags:flags];
            OGTLCoreReadObject(is, environment, error);
            participant.kicked_by = [is readInt64];
            [participant setDate:[is readInt32]];
            participant.banned_rights = (TLChannelBannedRights *)OGTLCoreReadObject(is, environment, error);
            parsed = participant;
            break;
        }
        case OGTLCtor(0xd5f0ad91):
        {
            flags = OGTLTakeInt32(is);
            TLChannelParticipant$channelParticipantBanned *participant = OGTLNewObject(TLChannelParticipant$channelParticipantBanned);
            [participant setFlags:flags];
            OGTLCoreReadObject(is, environment, error);
            participant.kicked_by = [is readInt64];
            [participant setDate:[is readInt32]];
            participant.banned_rights = (TLChannelBannedRights *)OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 2, 's');
            parsed = participant;
            break;
        }
        case OGTLCtor(0x1b03f006):
        {
            OGTLCoreReadObject(is, environment, error);
            parsed = OGTLNewObject(TLChannelParticipant);
            break;
        }
    }
    if (OGTLCoreFailed(error))
        return nil;
    return parsed;
}

@end

@interface OGTLModernChannelParticipantResultParser : TLchannels_ChannelParticipant$channels_channelParticipant
@end

@implementation OGTLModernChannelParticipantResultParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLchannels_ChannelParticipant$channels_channelParticipant *result = [[TLchannels_ChannelParticipant$channels_channelParticipant alloc] init];
    result.participant = (TLChannelParticipant *)OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.chats = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.users = OGTLCoreReadObjectVector(is, environment, error);
    return result;
}

@end

@interface OGTLModernChannelsParticipantsParser : TLchannels_ChannelParticipants$channels_channelParticipants
@end

@implementation OGTLModernChannelsParticipantsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLchannels_ChannelParticipants$channels_channelParticipants *result = OGTLNewObject(TLchannels_ChannelParticipants$channels_channelParticipants);
    result.count = [is readInt32];
    result.participants = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.users = OGTLCoreReadObjectVector(is, environment, error);
    return result;
}

@end

@interface OGTLModernMessageEmptyParser : TLMessage$messageEmpty
@end

@implementation OGTLModernMessageEmptyParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLMessage$messageEmpty *result = OGTLNewObject(TLMessage$messageEmpty);
    int32_t flags = [is readInt32];
    result.n_id = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 0, 'o');
    return result;
}

@end

@interface OGTLModernPeerSettingsParser : TLPeerSettings$peerSettings
@end

@implementation OGTLModernPeerSettingsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLPeerSettings$peerSettings *result = OGTLNewObject(TLPeerSettings$peerSettings);
    int32_t flags = [is readInt32];
    result.flags = flags;
    OGTLSkipFlagged(is, environment, error, flags, 6, 'i');
    if (OGTLFlagSet(flags, 9))
    {
        OGTLTakeString(is);
        [is readInt32];
    }
    if (OGTLFlagSet(flags, 13))
    {
        OGTLTakeInt64(is);
        OGTLTakeString(is);
    }
    OGTLSkipFlagged(is, environment, error, flags, 14, 'l');
    OGTLSkipFlagged(is, environment, error, flags, 15, 's');
    OGTLSkipFlagged(is, environment, error, flags, 16, 's');
    OGTLSkipFlagged(is, environment, error, flags, 17, 'i');
    OGTLSkipFlagged(is, environment, error, flags, 18, 'i');
    return result;
}

@end

@interface OGTLInputGroupCallParser : OGTLManualParser
@end

@implementation OGTLInputGroupCallParser

- (int32_t)TLconstructorSignature
{
    return OGTLCtor(0xd8aa840f);
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    OGTLTakeInt64(is);
    OGTLTakeInt64(is);
    return nil;
}

@end

@interface OGTLModernBotCommandParser : TLBotCommand$botCommand
@end

@implementation OGTLModernBotCommandParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused tlContext error:(__autoreleasing NSError **)__unused error
{
    TLBotCommand$botCommand *result = OGTLNewObject(TLBotCommand$botCommand);
    if (signature == (int32_t)0x9852d6d2)
        [is readInt32];
    result.command = OGTLTakeString(is);
    result.n_description = [is readString];
    return result;
}

@end

@interface OGTLModernAllStickersParser : TLmessages_AllStickers$messages_allStickers
@end

@implementation OGTLModernAllStickersParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0xe86602c3))
    {
        return OGTLNewObject(TLmessages_AllStickers$messages_allStickersNotModified);
    }
    
    TLmessages_AllStickers$messages_allStickers *result = OGTLNewObject(TLmessages_AllStickers$messages_allStickers);
    result.n_hash = (int32_t)OGTLTakeInt64(is);
    result.sets = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}

@end

@interface OGTLModernRecentStickersParser : TLmessages_RecentStickers$messages_recentStickers
@end

@implementation OGTLModernRecentStickersParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0x0b17f890))
    {
        return OGTLNewObject(TLmessages_RecentStickers$messages_recentStickersNotModified);
    }
    
    TLmessages_RecentStickers$messages_recentStickers *result = OGTLNewObject(TLmessages_RecentStickers$messages_recentStickers);
    result.n_hash = (int32_t)OGTLTakeInt64(is);
    result.packs = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.stickers = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.dates = OGTLCoreReadInt32Vector(is);
    return result;
}

@end

@interface OGTLModernFeaturedStickersParser : TLmessages_FeaturedStickers$messages_featuredStickers
@end

@implementation OGTLModernFeaturedStickersParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0xc6dc0c66))
    {
        [is readInt32];
        return OGTLNewObject(TLmessages_FeaturedStickers$messages_featuredStickersNotModified);
    }
    
    TLmessages_FeaturedStickers$messages_featuredStickers *result = OGTLNewObject(TLmessages_FeaturedStickers$messages_featuredStickers);
    [is readInt32];
    result.n_hash = (int32_t)OGTLTakeInt64(is);
    [is readInt32];
    result.sets = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.unread = OGTLCoreReadInt64Vector(is);
    return result;
}

@end

@interface OGTLModernFavedStickersParser : TLmessages_FavedStickers$messages_favedStickers
@end

@implementation OGTLModernFavedStickersParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0x9e8fa6d3))
    {
        return OGTLNewObject(TLmessages_FavedStickers$messages_favedStickersNotModified);
    }
    
    TLmessages_FavedStickers$messages_favedStickers *result = OGTLNewObject(TLmessages_FavedStickers$messages_favedStickers);
    result.n_hash = (int32_t)OGTLTakeInt64(is);
    result.packs = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.stickers = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}

@end

@interface OGTLModernInputStickerSetParser : TLInputStickerSet
@end

@implementation OGTLModernInputStickerSetParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused tlContext error:(__autoreleasing NSError **)__unused error
{
    if (signature == OGTLCtor(0x9de7a269))
    {
        TLInputStickerSet$inputStickerSetID *result = OGTLNewObject(TLInputStickerSet$inputStickerSetID);
        result.n_id = [is readInt64];
        result.access_hash = [is readInt64];
        return result;
    }
    if (signature == OGTLCtor(0x861cc8a0))
    {
        TLInputStickerSet$inputStickerSetShortName *result = OGTLNewObject(TLInputStickerSet$inputStickerSetShortName);
        result.short_name = [is readString];
        return result;
    }
    if (signature == OGTLCtor(0xe67f520e))
        OGTLTakeString(is);
    
    return [[TLInputStickerSet$inputStickerSetEmpty alloc] init];
}

@end

@interface OGTLModernDocumentAttributeStickerParser : TLDocumentAttributeSticker
@end

@implementation OGTLModernDocumentAttributeStickerParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLDocumentAttributeSticker *result = [[TLDocumentAttributeSticker alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.alt = [is readString];
    result.stickerset = (TLInputStickerSet *)OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    if (OGTLFlagSet(flags, 0))
        result.mask_coords = (TLMaskCoords *)OGTLCoreReadObject(is, environment, error);
    return result;
}

@end

@interface OGTLModernLangPackLanguageParser : TLLangPackLanguage
@end

@implementation OGTLModernLangPackLanguageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLLangPackLanguage$langPackLanguage *result = OGTLNewObject(TLLangPackLanguage$langPackLanguage);
    int32_t flags = [is readInt32];
    result.name = [is readString];
    result.native_name = OGTLTakeString(is);
    result.lang_code = OGTLTakeString(is);
    OGTLSkipFlagged(is, environment, error, flags, 1, 's');
    OGTLTakeString(is);
    [is readInt32];
    [is readInt32];
    OGTLTakeString(is);
    return result;
}

@end

@interface OGTLModernStickerSetMetaParser : TLStickerSet$stickerSetMeta
@end

@implementation OGTLModernStickerSetMetaParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLStickerSet$stickerSetMeta *result = OGTLNewObject(TLStickerSet$stickerSetMeta);
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (OGTLFlagSet(flags, 0))
        result.installed_date = [is readInt32];
    result.n_id = [is readInt64];
    result.access_hash = [is readInt64];
    result.title = [is readString];
    result.short_name = [is readString];
    if (OGTLFlagSet(flags, 4))
    {
        OGTLCoreReadObjectVector(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        [is readInt32];
        [is readInt32];
    }
    OGTLSkipFlagged(is, environment, error, flags, 8, 'l');
    result.count = [is readInt32];
    result.n_hash = [is readInt32];
    return result;
}

@end

@interface OGTLModernStickerKeywordParser : OGTLManualParser
@end

@implementation OGTLModernStickerKeywordParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    OGTLTakeInt64(is);
    OGTLCoreSkipStringVector(is);
    return nil;
}

@end

@interface OGTLStickerPackParser : TLStickerPack$stickerPack
@end

@implementation OGTLStickerPackParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLStickerPack$stickerPack *result = [[TLStickerPack$stickerPack alloc] init];
    result.emoticon = [is readString];
    result.documents = OGTLCoreReadInt64Vector(is);
    return result;
}

@end

@interface OGTLModernStickerSetParser : TLmessages_StickerSet$messages_stickerSet
@end

@implementation OGTLModernStickerSetParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0xd3f924eb))
    {
        return OGTLNewObject(TLmessages_StickerSet);
    }
    
    TLmessages_StickerSet$messages_stickerSet *result = OGTLNewObject(TLmessages_StickerSet$messages_stickerSet);
    result.set = (TLStickerSet *)OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.packs = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.documents = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}

@end

@interface OGTLModernStickerSetCoveredParser : TLStickerSetCovered$stickerSetMultiCovered
@end

@implementation OGTLModernStickerSetCoveredParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0x6410a5d2))
    {
        TLStickerSetCovered$stickerSetCovered *result = OGTLNewObject(TLStickerSetCovered$stickerSetCovered);
        result.set = (TLStickerSet *)OGTLCoreReadObject(is, environment, error);
        result.cover = (TLDocument *)OGTLCoreReadObject(is, environment, error);
        return result;
    }

    TLStickerSetCovered$stickerSetMultiCovered *result = OGTLNewObject(TLStickerSetCovered$stickerSetMultiCovered);
    result.set = (TLStickerSet *)OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;

    if (signature == OGTLCtor(0x3407e51b))
    {
        result.covers = OGTLCoreReadObjectVector(is, environment, error);
    }
    else if (signature == OGTLCtor(0x40d13c0e))
    {
        OGTLCoreReadObjectVector(is, environment, error);
        OGTLCoreReadObjectVector(is, environment, error);
        result.covers = OGTLCoreReadObjectVector(is, environment, error);
    }
    else
    {
        [result setCovers:@[]];
    }

    return result;
}

@end

@interface OGTLModernStickerSetInstallResultParser : TLmessages_StickerSetInstallResult
@end

@implementation OGTLModernStickerSetInstallResultParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0x38641628))
    {
        return OGTLNewObject(TLmessages_StickerSetInstallResult$messages_stickerSetInstallResultSuccess);
    }
    
    TLmessages_StickerSetInstallResult$messages_stickerSetInstallResultArchive *result = OGTLNewObject(TLmessages_StickerSetInstallResult$messages_stickerSetInstallResultArchive);
    result.sets = OGTLCoreReadObjectVector(is, environment, error);
    return result;
}

@end

@interface OGTLModernFoundStickerSetsParser : TLmessages_FoundStickerSets$messages_foundStickerSets
@end

@implementation OGTLModernFoundStickerSetsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0x0d54b65d))
    {
        return OGTLNewObject(TLmessages_FoundStickerSets);
    }
    
    TLmessages_FoundStickerSets$messages_foundStickerSets *result = OGTLNewObject(TLmessages_FoundStickerSets$messages_foundStickerSets);
    result.n_hash = [is readInt32];
    result.sets = OGTLCoreReadObjectVector(is, environment, error);
    return result;
}

@end

@interface OGTLModernExportedAuthorizationParser : TLauth_ExportedAuthorization$auth_exportedAuthorization
@end

@implementation OGTLModernExportedAuthorizationParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLauth_ExportedAuthorization$auth_exportedAuthorization *result = OGTLNewObject(TLauth_ExportedAuthorization$auth_exportedAuthorization);
    result.n_id = [is readInt64];
    result.bytes = OGTLTakeBytes(is);
    return result;
}

@end

@interface OGTLModernBotInfoParser : TLBotInfo$botInfo
@end

@implementation OGTLModernBotInfoParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLBotInfo$botInfo *result = OGTLNewObject(TLBotInfo$botInfo);
    int32_t flags = [is readInt32];
    if (OGTLFlagSet(flags, 0))
    {
        int64_t userId = OGTLTakeInt64(is);
        result.user_id = userId;
    }
    if (OGTLFlagSet(flags, 1))
        result.n_description = [is readString];
    OGTLSkipFlagged(is, environment, error, flags, 4, 'o');
    if (OGTLCoreFailed(error))
        return nil;
    OGTLSkipFlagged(is, environment, error, flags, 5, 'o');
    if (OGTLCoreFailed(error))
        return nil;
    if (OGTLFlagSet(flags, 2))
        result.commands = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    OGTLSkipFlagged(is, environment, error, flags, 3, 'o');
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}

@end

@interface OGTLPeerSettingsContainerParser : TLPeerSettings$peerSettings
@end

@implementation OGTLPeerSettingsContainerParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLPeerSettings *settings = (TLPeerSettings *)OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    return settings != nil ? settings : OGTLNewObject(TLPeerSettings$peerSettings);
}

@end

@interface OGTLForumTopic : OGTLManualParser
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

@implementation OGTLForumTopic
- (int32_t)TLconstructorSignature { return (int32_t)0xfcdad815; }
- (int32_t)TLconstructorName { return 0; }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

@interface OGTLForumTopicParser : OGTLManualParser
@end

@implementation OGTLForumTopicParser

- (int32_t)TLconstructorSignature
{
    return OGTLCtor(0x71701da9);
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLForumTopic *result = [[OGTLForumTopic alloc] init];

    if (signature == OGTLCtor(0x023f109b))
    {
        result.topicId = [is readInt32];
        result.deleted = true;
        return result;
    }

    int32_t flags = [is readInt32];
    result.flags = flags;
    result.topicId = [is readInt32];
    result.date = [is readInt32];

    if (signature == OGTLCtor(0xfcdad815))
    {
        OGTLCoreReadObject(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
    }

    result.title = [is readString];
    result.iconColor = [is readInt32];
    if (OGTLFlagSet(flags, 0))
        result.iconEmojiId = [is readInt64];

    result.topMessage = [is readInt32];
    result.readInboxMaxId = [is readInt32];
    result.readOutboxMaxId = [is readInt32];
    result.unreadCount = [is readInt32];
    result.unreadMentionsCount = [is readInt32];
    result.unreadReactionsCount = [is readInt32];
    if (signature == OGTLCtor(0xfcdad815))
        result.unreadPollVotesCount = [is readInt32];

    OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;

    OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;

    if (OGTLFlagSet(flags, 4))
    {
        OGTLCoreReadObject(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
    }

    return result;
}

@end

@interface OGTLForumTopicsResult : TLmessages_Messages$messages_messagesSlice
@property (nonatomic, strong) NSArray *ios6_forumTopics;
@property (nonatomic) int32_t pts;
@property (nonatomic) bool orderByCreateDate;
@end

@implementation OGTLForumTopicsResult
@end

@interface OGTLForumTopicsParser : TLmessages_Messages
@end

@implementation OGTLForumTopicsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLForumTopicsResult *result = [[OGTLForumTopicsResult alloc] init];
    int32_t flags = [is readInt32];
    result.orderByCreateDate = (flags & (1 << 0)) != 0;
    result.count = [is readInt32];
    result.ios6_forumTopics = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.messages = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.chats = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.users = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.pts = [is readInt32];
    return result;
}

@end

@interface OGTLModernPrivacyRulesParser : TLaccount_PrivacyRules$account_privacyRules
@end

@implementation OGTLModernPrivacyRulesParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLaccount_PrivacyRules$account_privacyRules *result = OGTLNewObject(TLaccount_PrivacyRules$account_privacyRules);
    result.rules = OGTLCoreReadObjectVectorWithRole(is, @"privacy.rules", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.chats = OGTLCoreReadObjectVectorWithRole(is, @"privacy.chats", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.users = OGTLCoreReadObjectVectorWithRole(is, @"privacy.users", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}

@end

@interface OGTLModernChannelMessagesParser : TLmessages_Messages$messages_channelMessages
@end

@implementation OGTLModernChannelMessagesParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernChannelMessagesParser *result = [[OGTLModernChannelMessagesParser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.pts = [is readInt32];
    result.count = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 2, 'i');
    
    result.messages = OGTLCoreReadStrictObjectVectorWithRole(is, @"channelMessages.messages", environment, error);
    if (OGTLCoreFailed(error))
    {
        return nil;
    }
    
    OGTLCoreReadStrictObjectVectorWithRole(is, @"channelMessages.topics", environment, error);
    if (OGTLCoreFailed(error))
    {
        return nil;
    }
    
    result.chats = OGTLCoreReadStrictObjectVectorWithRole(is, @"channelMessages.chats", environment, error);
    if (OGTLCoreFailed(error))
    {
        return nil;
    }
    
    result.users = OGTLCoreReadStrictObjectVectorWithRole(is, @"channelMessages.users", environment, error);
    if (OGTLCoreFailed(error))
    {
        return nil;
    }
    
    return result;
}

@end

enum
{
    OGTLActionResultChatDeletePhoto,
    OGTLActionResultChatJoinedByRequest,
    OGTLActionResultEmpty,
    OGTLActionResultHistoryClear,
    OGTLActionResultPinMessage
};

static const OGTLSkipLayout OGTLActionSkipLayouts[] =
{
    {(int32_t)0x80e11a7f, "fl0?i1?i", OGTLActionResultEmpty},
    {(int32_t)0x87e2f155, "iii", OGTLActionResultEmpty},
    {(int32_t)0x8f31b327, "fslb0?o1?so", OGTLActionResultEmpty},
    {(int32_t)0x93b31848, "iv", OGTLActionResultEmpty},
    {(int32_t)0x94bd38ed, "", OGTLActionResultPinMessage},
    {(int32_t)0x95ddcf69, "o", OGTLActionResultEmpty},
    {(int32_t)0x95e3fbef, "", OGTLActionResultChatDeletePhoto},
    {(int32_t)0x96163f56, "fsl0?s", OGTLActionResultEmpty},
    {(int32_t)0x98e0d697, "ooi", OGTLActionResultEmpty},
    {(int32_t)0x9da1cd6c, "o", OGTLActionResultEmpty},
    {(int32_t)0x9fbab604, "", OGTLActionResultHistoryClear},
    {(int32_t)0xa80f51e4, "f0?l", OGTLActionResultEmpty},
    {(int32_t)0xa8a3c699, "fslsl0?s", OGTLActionResultEmpty},
    {(int32_t)0xaa786345, "s", OGTLActionResultEmpty},
    {(int32_t)0xb00c47a2, "ilsoi", OGTLActionResultEmpty},
    {(int32_t)0xb07ed085, "l", OGTLActionResultEmpty},
    {(int32_t)0xb3a07661, "oi", OGTLActionResultEmpty},
    {(int32_t)0xb4c38cb5, "s", OGTLActionResultEmpty},
    {(int32_t)0xb6aef7b0, "", OGTLActionResultEmpty},
    {(int32_t)0xb91bbd3a, "o", OGTLActionResultEmpty},
    {(int32_t)0xbf7d6572, "oo", OGTLActionResultEmpty},
    {(int32_t)0xc0944820, "f0?s1?l2?o3?o", OGTLActionResultEmpty},
    {(int32_t)0xc516d679, "f0?s2?o", OGTLActionResultEmpty},
    {(int32_t)0xc624b16e, "fsl0?s4?i", OGTLActionResultEmpty},
    {(int32_t)0xc7edbc83, "v", OGTLActionResultEmpty},
    {(int32_t)0xc83d6aec, "fsli0?s0?l", OGTLActionResultEmpty},
    {(int32_t)0xcc02aa6d, "i", OGTLActionResultEmpty},
    {(int32_t)0xcc7c5c89, "nn", OGTLActionResultEmpty},
    {(int32_t)0xd7c0ff9c, "", OGTLActionResultEmpty},
    {(int32_t)0xd95c6154, "v", OGTLActionResultEmpty},
    {(int32_t)0xe188503b, "l", OGTLActionResultEmpty},
    {(int32_t)0xea2c31d3, "fo1?o4?l5?i8?l11?o12?o12?l14?s15?i18?o19?i", OGTLActionResultEmpty},
    {(int32_t)0xebbca3cb, "", OGTLActionResultChatJoinedByRequest},
    {(int32_t)0xee7a1596, "f2?s3?i4?o", OGTLActionResultEmpty},
    {(int32_t)0xf3f25f76, "", OGTLActionResultEmpty},
    {(int32_t)0xfae69f56, "s", OGTLActionResultEmpty},
    {(int32_t)0xffa00ccc, "fslb0?o1?so4?i", OGTLActionResultEmpty},
    {(int32_t)0x0d999256, "fsi0?l", OGTLActionResultEmpty},
    {(int32_t)0x16605e3e, "l", OGTLActionResultEmpty},
    {(int32_t)0x1b287353, "vo", OGTLActionResultEmpty},
    {(int32_t)0x2a9fadc5, "ii", OGTLActionResultEmpty},
    {(int32_t)0x2c8f2a25, "o", OGTLActionResultEmpty},
    {(int32_t)0x2ffe2f7a, "fl2?i3?v", OGTLActionResultEmpty},
    {(int32_t)0x31518e9b, "iv", OGTLActionResultEmpty},
    {(int32_t)0x31c48347, "f1?ois2?s2?l3?s3?l4?o", OGTLActionResultEmpty},
    {(int32_t)0x332ba9ed, "", OGTLActionResultEmpty},
    {(int32_t)0x399674dc, "o", OGTLActionResultEmpty},
    {(int32_t)0x3c134d7b, "fi0?l", OGTLActionResultEmpty},
    {(int32_t)0x3e2793ba, "ioo", OGTLActionResultEmpty},
    {(int32_t)0x41b3e202, "fosl0?bo", OGTLActionResultEmpty},
    {(int32_t)0x45d5b021, "fsll0?s0?l1?s", OGTLActionResultEmpty},
    {(int32_t)0x4792929b, "", OGTLActionResultEmpty},
    {(int32_t)0x47dd8079, "ss", OGTLActionResultEmpty},
    {(int32_t)0x48e91302, "fsli0?s0?l1?o", OGTLActionResultEmpty},
    {(int32_t)0x502f92f7, "om", OGTLActionResultEmpty},
    {(int32_t)0x5060a3f4, "io", OGTLActionResultEmpty},
    {(int32_t)0x57de635e, "o", OGTLActionResultEmpty},
    {(int32_t)0x678c2e09, "f1?ois2?s2?l3?s3?l", OGTLActionResultEmpty},
    {(int32_t)0x69f916f8, "i", OGTLActionResultEmpty},
    {(int32_t)0x73ada76b, "ioo", OGTLActionResultEmpty},
    {(int32_t)0x774278d4, "iooi", OGTLActionResultEmpty},
    {(int32_t)0x7a0d7f42, "fo0?i", OGTLActionResultEmpty}
};

static id<TLObject> OGTLActionForSkippedResult(uint8_t result)
{
    switch (result)
    {
        case OGTLActionResultChatDeletePhoto:
            return OGTLNewObject(TLMessageAction$messageActionChatDeletePhoto);
        case OGTLActionResultChatJoinedByRequest:
            return [[TLMessageAction$messageActionChatJoinedByRequest alloc] init];
        case OGTLActionResultEmpty:
            return OGTLNewObject(TLMessageAction$messageActionEmpty);
        case OGTLActionResultHistoryClear:
            return OGTLNewObject(TLMessageAction$messageActionHistoryClear);
        case OGTLActionResultPinMessage:
            return OGTLNewObject(TLMessageAction$messageActionPinMessage);
        default:
            return nil;
    }
}

@interface OGTLModernMessageActionParser : TLMessageAction
@end

@implementation OGTLModernMessageActionParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    const OGTLSkipLayout *skipLayout = OGTLFindSkipLayout(OGTLActionSkipLayouts, sizeof(OGTLActionSkipLayouts) / sizeof(OGTLActionSkipLayouts[0]), signature);
    if (skipLayout != NULL)
    {
        OGTLSkipFields(is, skipLayout->layout, environment, error);
        return OGTLActionForSkippedResult(skipLayout->result);
    }

    switch (signature)
    {
        case OGTLCtor(0xbd47cbad):
        {
            TLMessageAction$messageActionChatCreate *result = OGTLNewObject(TLMessageAction$messageActionChatCreate);
            result.title = [is readString];
            result.users = OGTLCoreReadInt64Vector(is);
            return result;
        }
        case OGTLCtor(0xb5a1ce5a):
        {
            TLMessageAction$messageActionChatEditTitle *result = OGTLNewObject(TLMessageAction$messageActionChatEditTitle);
            result.title = [is readString];
            return result;
        }
        case OGTLCtor(0x7fcb13a8):
        {
            TLMessageAction$messageActionChatEditPhoto *result = OGTLNewObject(TLMessageAction$messageActionChatEditPhoto);
            result.photo = (TLPhoto *)OGTLCoreReadObject(is, environment, error);
            return result;
        }
        case OGTLCtor(0x15cefd00):
        {
            TLMessageAction$messageActionChatAddUser *result = OGTLNewObject(TLMessageAction$messageActionChatAddUser);
            result.users = OGTLCoreReadInt64Vector(is);
            return result;
        }
        case OGTLCtor(0xa43f30cc):
        {
            TLMessageAction$messageActionChatDeleteUser *result = OGTLNewObject(TLMessageAction$messageActionChatDeleteUser);
            result.user_id = [is readInt64];
            return result;
        }
        case OGTLCtor(0x31224c3):
        {
            TLMessageAction$messageActionChatJoinedByLink *result = OGTLNewObject(TLMessageAction$messageActionChatJoinedByLink);
            result.inviter_id = [is readInt64];
            return result;
        }
        case OGTLCtor(0x95d2ac92):
        {
            TLMessageAction$messageActionChannelCreate *result = OGTLNewObject(TLMessageAction$messageActionChannelCreate);
            result.title = [is readString];
            return result;
        }
        case OGTLCtor(0xe1037f92):
        {
            TLMessageAction$messageActionChatMigrateTo *result = OGTLNewObject(TLMessageAction$messageActionChatMigrateTo);
            result.channel_id = [is readInt64];
            return result;
        }
        case OGTLCtor(0xea3948e9):
        {
            TLMessageAction$messageActionChannelMigrateFrom *result = OGTLNewObject(TLMessageAction$messageActionChannelMigrateFrom);
            result.title = [is readString];
            result.chat_id = [is readInt64];
            return result;
        }
        case OGTLCtor(0x92a72876):
        {
            TLMessageAction$messageActionGameScore *result = OGTLNewObject(TLMessageAction$messageActionGameScore);
            result.game_id = OGTLTakeInt64(is);
            result.score = OGTLTakeInt32(is);
            return result;
        }
        case OGTLCtor(0xe6c31522):
        case (int32_t)0x7e1c1187:
        {
            int32_t flags = [is readInt32];
            OGTLCoreReadObject(is, environment, error);
            OGTLSkipFlagged(is, environment, error, flags, 3, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 4, 'l');
            OGTLSkipFlagged(is, environment, error, flags, 6, 'o');
            if (OGTLFlagSet(flags, 7))
            {
                OGTLCoreReadObject(is, environment, error);
                OGTLTakeInt64(is);
            }
            OGTLSkipFlagged(is, environment, error, flags, 8, 'o');
            OGTLSkipFlagged(is, environment, error, flags, 9, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 10, 'i');
            OGTLSkipFlagged(is, environment, error, flags, 12, 'l');
            OGTLSkipFlagged(is, environment, error, flags, 15, 'i');
            if (signature == (int32_t)0x7e1c1187 && (flags & (1 << 18)))
                OGTLCoreReadObject(is, environment, error);
            return OGTLNewObject(TLMessageAction$messageActionEmpty);
        }
        default:
            return OGTLNewObject(TLMessageAction$messageActionEmpty);
    }
}

@end

@interface OGTLModernDocumentParser : TLDocument$document
@end

@implementation OGTLModernDocumentParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLModernDocumentParser *result = [[OGTLModernDocumentParser alloc] init];
    int32_t flags = [is readInt32];
    result.n_id = [is readInt64];
    result.access_hash = [is readInt64];
    result.file_reference = OGTLTakeBytes(is);
    result.date = [is readInt32];
    result.mime_type = OGTLTakeString(is);
    result.size = (int32_t)OGTLTakeInt64(is);
    
    if (OGTLFlagSet(flags, 0))
    {
        NSArray *thumbs = OGTLCoreReadObjectVector(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;

        TLPhotoSize *pickedThumb = nil;
        int bestThumbnailDistance = INT_MAX;
        for (id candidate in thumbs)
        {
            if (OGTLCoreIsKind(candidate, [TLPhotoSize$photoCachedSize class]))
            {
                TLPhotoSize$photoCachedSize *cached = (TLPhotoSize$photoCachedSize *)candidate;
                int side = MAX(cached.w, cached.h);
                int distance = ABS(side - 320);
                if (cached.bytes.length != 0 && cached.bytes.length <= 512 * 1024 && cached.w > 0 && cached.h > 0 && side <= 640 && distance < bestThumbnailDistance)
                {
                    pickedThumb = cached;
                    bestThumbnailDistance = distance;
                }
            }
        }

        for (id candidate in thumbs)
        {
            if (OGTLCoreIsKind(candidate, [TLPhotoSize$photoSize class]))
            {
                TLPhotoSize$photoSize *plain = (TLPhotoSize$photoSize *)candidate;
                int side = MAX(plain.w, plain.h);
                int distance = ABS(side - 320);
                if (plain.type.length != 0 && plain.size <= 512 * 1024 && plain.w > 0 && plain.h > 0 && side <= 640 && distance < bestThumbnailDistance)
                {
                    pickedThumb = plain;
                    bestThumbnailDistance = distance;
                }
            }
        }

        [result setThumb:pickedThumb];
        result.thumbs = thumbs;
    }
    
    if (OGTLFlagSet(flags, 1))
    {
        NSArray *videoThumbnails = OGTLCoreReadObjectVectorOrSingle(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        result.video_thumbs = videoThumbnails;

        if (result.thumb == nil)
        {
            TLPhotoSize *bestVideoThumbnail = nil;
            int64_t bestVideoThumbnailArea = -1;
            for (id candidate in videoThumbnails)
            {
                if (OGTLCoreIsKind(candidate, [TLPhotoSize$photoSize class]))
                {
                    TLPhotoSize$photoSize *plain = (TLPhotoSize$photoSize *)candidate;
                    int64_t area = (int64_t)plain.w * (int64_t)plain.h;
                    if (plain.type.length != 0 && plain.w > 0 && plain.h > 0 && area > bestVideoThumbnailArea)
                    {
                        bestVideoThumbnail = plain;
                        bestVideoThumbnailArea = area;
                    }
                }
                else if (OGTLCoreIsKind(candidate, [TLPhotoSize$photoCachedSize class]))
                {
                    TLPhotoSize$photoCachedSize *cached = (TLPhotoSize$photoCachedSize *)candidate;
                    int64_t area = (int64_t)cached.w * (int64_t)cached.h;
                    if (cached.bytes.length != 0 && cached.w > 0 && cached.h > 0 && area > bestVideoThumbnailArea)
                    {
                        bestVideoThumbnail = cached;
                        bestVideoThumbnailArea = area;
                    }
                }
            }
            result.thumb = bestVideoThumbnail;
        }
    }
    
    int32_t leadingMarker = OGTLTakeInt32(is);
    if (leadingMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
    {
        [result setDc_id:0];
        result.attributes = OGTLCoreReadObjectVectorWithMarker(is, leadingMarker, environment, error);
    }
    else
    {
        [result setDc_id:leadingMarker];
        int32_t attributesMarker = OGTLTakeInt32(is);
        result.attributes = OGTLCoreReadObjectVectorOrSingleWithMarker(is, attributesMarker, environment, error);
        if ((error == nil || *error == nil) && attributesMarker == OGTLCtor(0xd38ff1c2))
        {
            for (int32_t tailIndex = 0; tailIndex < 3; tailIndex++)
            {
                int32_t tailWord = OGTLTakeInt32(is);
                if (OGTLCoreSkipBareDocumentAttributeTailWord(is, tailWord))
                {
                    continue;
                }
                else if (OGTLCoreLooksLikeStringFirstWord(tailWord))
                {
                    OGTLCoreSkipStringWithFirstWord(is, tailWord);
                }
                else if (OGTLCoreLooksLikeTinyBareDocumentTailWord(tailWord))
                {
                }
                else
                    break;
            }
        }
    }
    if (OGTLCoreFailed(error))
        return nil;
    
    return result;
}

@end

@interface OGTLModernDocumentAttributeVideoParser : TLDocumentAttribute$documentAttributeVideo
@end

@implementation OGTLModernDocumentAttributeVideoParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    OGTLModernDocumentAttributeVideoParser *result = [[OGTLModernDocumentAttributeVideoParser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.duration = (int32_t)OGTLTakeDouble(is);
    result.w = [is readInt32];
    result.h = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 2, 'i');
    OGTLSkipFlagged(is, environment, error, flags, 4, 'd');
    if (OGTLFlagSet(flags, 5))
        result.video_codec = [is readString];
    return result;
}

@end

@interface OGTLModernDocumentAttributeVideoD38Parser : TLDocumentAttribute$documentAttributeVideo
@end

@implementation OGTLModernDocumentAttributeVideoD38Parser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    OGTLModernDocumentAttributeVideoD38Parser *result = [[OGTLModernDocumentAttributeVideoD38Parser alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.duration = (int32_t)OGTLTakeDouble(is);
    result.w = [is readInt32];
    result.h = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 2, 'i');
    return result;
}

@end

@interface OGTLModernDocumentAttributeFilenameParser : TLDocumentAttribute$documentAttributeFilename
@end

@implementation OGTLModernDocumentAttributeFilenameParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    OGTLModernDocumentAttributeFilenameParser *result = [[OGTLModernDocumentAttributeFilenameParser alloc] init];
    result.file_name = OGTLTakeString(is);
    return result;
}

@end

@interface OGTLModernUserProfilePhotoParser : TLUserProfilePhoto$userProfilePhoto
@end

@implementation OGTLModernUserProfilePhotoParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    OGTLModernUserProfilePhotoParser *result = [[OGTLModernUserProfilePhotoParser alloc] init];
    int32_t flags = [is readInt32];
    result.photo_id = OGTLTakeInt64(is);
    NSData *strippedThumbnail = nil;
    if (OGTLFlagSet(flags, 1))
        strippedThumbnail = [is readBytes];
    result.dc_id = OGTLTakeInt32(is);
    if (OGPlatformUsesConstrainedBackgroundExecution() && strippedThumbnail.length != 0)
    {
        NSData *decodedThumbnail = OGTLCoreDecodedStrippedThumbnail(strippedThumbnail);
        UIImage *thumbnailImage = decodedThumbnail.length == 0 ? nil : [[UIImage alloc] initWithData:decodedThumbnail];
        if (thumbnailImage != nil)
            objc_setAssociatedObject(result, NSSelectorFromString(@"onegramStrippedAvatar"), thumbnailImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    return result;
}

@end

@interface OGTLModernChatPhotoParser : TLChatPhoto$chatPhoto
@end

@implementation OGTLModernChatPhotoParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused tlContext error:(__autoreleasing NSError **)__unused error
{
    TLChatPhoto$chatPhoto *result = OGTLNewObject(TLChatPhoto$chatPhoto);
    if (signature == OGTLCtor(0x1c6e1c11))
    {
        int32_t flags = [is readInt32];
        result.photo_id = OGTLTakeInt64(is);
        NSData *strippedThumbnail = nil;
        if (OGTLFlagSet(flags, 1))
            strippedThumbnail = [is readBytes];
        result.dc_id = OGTLTakeInt32(is);
        if (OGPlatformUsesConstrainedBackgroundExecution() && strippedThumbnail.length != 0)
        {
            NSData *decodedThumbnail = OGTLCoreDecodedStrippedThumbnail(strippedThumbnail);
            UIImage *thumbnailImage = decodedThumbnail.length == 0 ? nil : [[UIImage alloc] initWithData:decodedThumbnail];
            if (thumbnailImage != nil)
                objc_setAssociatedObject(result, NSSelectorFromString(@"onegramStrippedAvatar"), thumbnailImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

    }
    return result;
}

@end

@interface OGTLModernChatParser : TLChat$chat
@end

@implementation OGTLModernChatParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLChat$chat *result = [[TLChat$chat alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.creator = (flags & (1 << 0));
    result.left = (flags & (1 << 2));
    result.deactivated = (flags & (1 << 5));
    int64_t chatId = OGTLTakeInt64(is);
    result.n_id = chatId;
    result.title = [is readString];
    result.photo = (TLChatPhoto *)OGTLCoreReadObject(is, environment, error);
    result.participants_count = [is readInt32];
    result.date = [is readInt32];
    result.version = [is readInt32];
    if (OGTLFlagSet(flags, 6))
        result.migrated_to = (TLInputChannel *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(flags, 14))
        result.admin_rights = (TLChannelAdminRights *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(flags, 18))
        result.default_banned_rights = (TLChannelBannedRights *)OGTLCoreReadObject(is, environment, error);
    return result;
}

@end

@interface OGTLModernChatForbiddenParser : TLChat$chatForbidden
@end

@implementation OGTLModernChatForbiddenParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLChat$chatForbidden *result = OGTLNewObject(TLChat$chatForbidden);
    int64_t chatId = OGTLTakeInt64(is);
    result.n_id = chatId;
    result.title = [is readString];
    return result;
}

@end

@interface OGTLModernChatAdminRightsParser : TLChannelAdminRights$channelAdminRights
@end

@implementation OGTLModernChatAdminRightsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLChannelAdminRights$channelAdminRights *result = [[TLChannelAdminRights$channelAdminRights alloc] init];
    result.flags = [is readInt32];
    return result;
}

@end

@interface OGTLModernChatBannedRightsParser : TLChannelBannedRights$channelBannedRights
@end

@implementation OGTLModernChatBannedRightsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLChannelBannedRights$channelBannedRights *result = [[TLChannelBannedRights$channelBannedRights alloc] init];
    result.flags = [is readInt32];
    result.until_date = [is readInt32];
    return result;
}

@end

@interface OGTLModernChannelParser : TLChat$channel
@end

@implementation OGTLModernChannelParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLChat$channel *result = [[TLChat$channel alloc] init];
    result.name_color_id = -1;
    int32_t flags = [is readInt32];
    int32_t flags2 = OGTLTakeInt32(is);
    result.flags = flags;
    [result setFlags2:flags2];
    int64_t channelId = OGTLTakeInt64(is);
    result.n_id = channelId;
    if (OGTLFlagSet(flags, 13))
        result.access_hash = [is readInt64];
    result.title = [is readString];
    if (OGTLFlagSet(flags, 6))
        result.username = [is readString];
    result.photo = (TLChatPhoto *)OGTLCoreReadObject(is, environment, error);
    result.date = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 9, 'v');
    if (OGTLFlagSet(flags, 14))
        result.admin_rights = (TLChannelAdminRights *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(flags, 15))
        result.banned_rights = (TLChannelBannedRights *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(flags, 18))
        result.default_banned_rights = (TLChannelBannedRights *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(flags, 17))
        result.participants_count = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags2, 0, 'v');
    if (OGTLFlagSet(flags2, 4))
    {

        if (signature == (int32_t)0x1c32b11c || signature == (int32_t)0xd49f34c6 || signature == (int32_t)0x7ad15240)
            OGTLCoreReadObject(is, environment, error);
        else
            [is readInt32];
    }
    if (OGTLFlagSet(flags2, 7))
    {
        int32_t colorSignature = [is readInt32];
        if (colorSignature == (int32_t)0xb54b5acf)
        {
            int32_t colorFlags = [is readInt32];
            if (colorFlags & (1 << 0))
                result.name_color_id = [is readInt32];
            if (colorFlags & (1 << 1))
                OGTLTakeInt64(is);
        }
        else
            OGTLCoreBuildObject(is, colorSignature, environment, error);
    }
    OGTLSkipFlagged(is, environment, error, flags2, 8, 'o');
    OGTLSkipFlagged(is, environment, error, flags2, 9, 'o');
    OGTLSkipFlagged(is, environment, error, flags2, 10, 'i');
    OGTLSkipFlagged(is, environment, error, flags2, 11, 'i');
    OGTLSkipFlagged(is, environment, error, flags2, 13, 'l');
    if (OGTLFlagSet(flags2, 14))
        result.send_paid_messages_stars = [is readInt64];
    if (OGTLFlagSet(flags2, 18))
        result.linked_monoforum_id = [is readInt64];
    if ((signature == (int32_t)0xd49f34c6 || signature == (int32_t)0x7ad15240) && (flags2 & (1 << 20)))
        result.linked_community_id = [is readInt64];
    if (signature == (int32_t)0x7ad15240 && (flags2 & (1 << 22)))
        [is readInt32];
    return result;
}

@end

static NSDictionary *OGTLReadChatReactionPolicy(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t signature = [is readInt32];
    if (signature == (int32_t)0xeafc32bc)
        return OGTLChatReactionModeInfo(@"none", @[]);

    if (signature == (int32_t)0x52928bca)
    {
        [is readInt32];
        return OGTLChatReactionModeInfo(@"all", @[]);
    }

    if (signature == (int32_t)0x661d4037)
    {
        int32_t marker = OGTLTakeInt32(is);
        int32_t count = marker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR ? OGTLTakeInt32(is) : 0;
        if ((uint32_t)count > 256)
            count = 0;

        NSMutableArray *pickedEmojis = [[NSMutableArray alloc] init];
        for (int32_t i = 0; i < count; i++)
        {
            int32_t reactionSignature = OGTLTakeInt32(is);
            if (reactionSignature == OGTLCtor(0x1b2286b8))
            {
                NSString *emoji = OGTLTakeString(is);
                if (emoji.length == 0 || [pickedEmojis containsObject:emoji])
                    continue;
                [pickedEmojis addObject:emoji];
            }
            else if (reactionSignature == OGTLCtor(0x8935fc73))
                OGTLTakeInt64(is);
            else if (reactionSignature != OGTLCtor(0x79f5d419) && reactionSignature != OGTLCtor(0x523da4eb))
                OGTLCoreBuildObject(is, reactionSignature, environment, error);
        }
        return OGTLChatReactionModeInfo(@"some", pickedEmojis);
    }

    OGTLCoreBuildObject(is, signature, environment, error);
    return nil;
}

static void OGTLStoreChatReactionPolicy(id object, NSDictionary *policy)
{
    if (object == nil || policy == nil)
        return;
    static NSString *const policyKey = @"tg_ios6_availableReactionPolicy";
    objc_setAssociatedObject(object, NSSelectorFromString(policyKey), policy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@interface OGTLModernChannelFullParser : TLChatFull$chatFull
@end

@implementation OGTLModernChannelFullParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    int32_t flags = [is readInt32];
    bool usesFlags2Layout = signature == (int32_t)0xbbab348d || signature == (int32_t)0xa04e8d3a || signature == (int32_t)0xe4e0b29d || signature == (int32_t)0xc4c4dd40;
    int32_t flags2 = usesFlags2Layout ? OGTLTakeInt32(is) : 0;

    int64_t channelId = OGTLTakeInt64(is);
    NSString *about = [is readString];

    if (!usesFlags2Layout)
    {
        OGTLModernChannelFullParser *result = [[OGTLModernChannelFullParser alloc] init];
        result.n_id = channelId;
        objc_setAssociatedObject(result, NSSelectorFromString(@"tg_ios6_chatAbout"), about == nil ? @"" : about, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        result.participants = (TLChatParticipants *)OGTLCoreReadObject(is, environment, error);
        if (OGTLFlagSet(flags, 2))
            result.chat_photo = (TLPhoto *)OGTLCoreReadObject(is, environment, error);
        result.notify_settings = (TLPeerNotifySettings *)OGTLCoreReadObject(is, environment, error);
        if (OGTLFlagSet(flags, 13))
            result.exported_invite = (TLExportedChatInvite *)OGTLCoreReadObject(is, environment, error);
        if (OGTLFlagSet(flags, 3))
            result.bot_info = OGTLCoreReadObjectVector(is, environment, error);
        OGTLSkipFlagged(is, environment, error, flags, 6, 'i');
        OGTLSkipFlagged(is, environment, error, flags, 11, 'i');
        if (flags & (1 << 12)) OGTLCoreReadObject(is, environment, error);
        OGTLSkipFlagged(is, environment, error, flags, 14, 'i');
        if (flags & (1 << 15)) OGTLCoreReadObject(is, environment, error);
        OGTLSkipFlagged(is, environment, error, flags, 16, 's');
        if (flags & (1 << 17)) { [is readInt32]; OGTLCoreReadInt64Vector(is); }
        if (flags & (1 << 18)) OGTLStoreChatReactionPolicy(result, OGTLReadChatReactionPolicy(is, environment, error));
        OGTLSkipFlagged(is, environment, error, flags, 20, 'i');
        return result;
    }

    TLChatFull$channelFull *result = [[TLChatFull$channelFull alloc] init];
    result.flags = flags;
    [result setFlags2:flags2];
    result.canViewParticipants = (flags & (1 << 3)) != 0;
    result.can_set_username = (flags & (1 << 6)) != 0;
    result.can_set_stickers = (flags & (1 << 7)) != 0;
    result.n_id = channelId;
    result.about = about;

    if (OGTLFlagSet(flags, 0))
        result.participants_count = [is readInt32];
    if (OGTLFlagSet(flags, 1))
        result.admins_count = [is readInt32];
    if (OGTLFlagSet(flags, 2))
    {
        result.kicked_count = [is readInt32];
        result.banned_count = [is readInt32];
    }
    OGTLSkipFlagged(is, environment, error, flags, 13, 'i');

    result.read_inbox_max_id = [is readInt32];
    result.read_outbox_max_id = [is readInt32];
    result.unread_count = [is readInt32];
    result.chat_photo = (TLPhoto *)OGTLCoreReadObject(is, environment, error);
    result.notify_settings = (TLPeerNotifySettings *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(flags, 23))
        result.exported_invite = (TLExportedChatInvite *)OGTLCoreReadObject(is, environment, error);
    result.bot_info = OGTLCoreReadObjectVector(is, environment, error);

    if (OGTLFlagSet(flags, 4))
    {
        result.migrated_from_chat_id = [is readInt64];
        result.migrated_from_max_id = [is readInt32];
    }
    if (OGTLFlagSet(flags, 5))
        result.pinned_msg_id = [is readInt32];
    if (OGTLFlagSet(flags, 8))
        result.stickerset = (TLStickerSet *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(flags, 9))
        result.available_min_id = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 11, 'i');
    OGTLSkipFlagged(is, environment, error, flags, 14, 'l');
    if (flags & (1 << 15)) OGTLCoreReadObject(is, environment, error);
    OGTLSkipFlagged(is, environment, error, flags, 17, 'i');
    OGTLSkipFlagged(is, environment, error, flags, 18, 'i');
    OGTLSkipFlagged(is, environment, error, flags, 12, 'i');
    [is readInt32];
    if (flags & (1 << 21)) OGTLCoreReadObject(is, environment, error);
    OGTLSkipFlagged(is, environment, error, flags, 24, 'i');
    if (flags & (1 << 25)) OGTLCoreSkipStringVector(is);
    if (flags & (1 << 26)) OGTLCoreReadObject(is, environment, error);
    OGTLSkipFlagged(is, environment, error, flags, 27, 's');
    if (flags & (1 << 28)) { [is readInt32]; OGTLCoreReadInt64Vector(is); }
    if (flags & (1 << 29)) OGTLCoreReadObject(is, environment, error);
    if (flags & (1 << 30)) OGTLStoreChatReactionPolicy(result, OGTLReadChatReactionPolicy(is, environment, error));
    OGTLSkipFlagged(is, environment, error, flags2, 13, 'i');
    if (flags2 & (1 << 4)) OGTLCoreReadObject(is, environment, error);
    if (flags2 & (1 << 7)) OGTLCoreReadObject(is, environment, error);
    OGTLSkipFlagged(is, environment, error, flags2, 8, 'i');
    OGTLSkipFlagged(is, environment, error, flags2, 9, 'i');
    if (flags2 & (1 << 10)) OGTLCoreReadObject(is, environment, error);
    if (signature != (int32_t)0xbbab348d)
    {
        if (flags2 & (1 << 17)) OGTLCoreReadObject(is, environment, error);
        OGTLSkipFlagged(is, environment, error, flags2, 18, 'i');
        OGTLSkipFlagged(is, environment, error, flags2, 21, 'l');
        if (flags2 & (1 << 22)) OGTLCoreReadObject(is, environment, error);
        if (signature != (int32_t)0xe4e0b29d && (flags2 & (1 << 23))) [is readInt64];
        if (signature == (int32_t)0xc4c4dd40 && (flags2 & (1 << 25))) OGTLCoreReadObject(is, environment, error);
    }
    return result;
}

@end

@interface OGTLModernChannelForbiddenParser : TLChat$channelForbidden
@end

@implementation OGTLModernChannelForbiddenParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLChat$channelForbidden *result = [[TLChat$channelForbidden alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    int64_t channelId = OGTLTakeInt64(is);
    result.n_id = channelId;
    result.access_hash = [is readInt64];
    result.title = [is readString];
    if (OGTLFlagSet(flags, 16))
        result.until_date = [is readInt32];
    return result;
}

@end

@interface OGTLModernPeerUserParser : TLPeer$peerUser
@end

@implementation OGTLModernPeerUserParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLPeer$peerUser *result = OGTLNewObject(TLPeer$peerUser);
    int64_t userId = OGTLTakeInt64(is);
    result.user_id = userId;
    return result;
}

@end

@interface OGTLModernPeerChatParser : TLPeer$peerChat
@end

@implementation OGTLModernPeerChatParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLPeer$peerChat *result = OGTLNewObject(TLPeer$peerChat);
    int64_t chatId = OGTLTakeInt64(is);
    result.chat_id = chatId;
    return result;
}

@end

@interface OGTLModernPeerChannelParser : TLPeer$peerChannel
@end

@implementation OGTLModernPeerChannelParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLPeer$peerChannel *result = OGTLNewObject(TLPeer$peerChannel);
    int64_t channelId = OGTLTakeInt64(is);
    result.channel_id = channelId;
    return result;
}

@end

static bool OGTLCoreReadNotificationSound(NSInputStream *is, NSString *__autoreleasing *legacySound, __autoreleasing NSError **error)
{
    if (legacySound != NULL)
        *legacySound = nil;

    int32_t signature = [is readInt32];
    switch (signature)
    {
        case OGTLCtor(0x97e8bebe):
            if (legacySound != NULL)
                *legacySound = @"default";
            return true;
        case OGTLCtor(0x6f0c34df):
            if (legacySound != NULL)
                *legacySound = @"";
            return true;
        case OGTLCtor(0x830b9ae4):
        {
            OGTLTakeString(is);
            NSString *data = [is readString];
            if (legacySound != NULL)
                *legacySound = data;
            return true;
        }
        case OGTLCtor(0xff6c8049):
            OGTLTakeInt64(is);
            return true;
        default:
            if (error != NULL)
                *error = [NSError errorWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unknown NotificationSound constructor %08x", signature]}];
            return false;
    }
}

@interface OGTLModernPeerNotifySettingsParser : TLPeerNotifySettings$peerNotifySettings
@end

@implementation OGTLModernPeerNotifySettingsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused tlContext error:(__autoreleasing NSError **)error
{
    TLPeerNotifySettings$peerNotifySettings *result = [[TLPeerNotifySettings$peerNotifySettings alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (OGTLFlagSet(flags, 0))
        result.showPreviews = [is readInt32] == TL_BOOL_TRUE_CONSTRUCTOR;
    if (OGTLFlagSet(flags, 1))
        result.silent = [is readInt32] == TL_BOOL_TRUE_CONSTRUCTOR;
    if (OGTLFlagSet(flags, 2))
        result.mute_until = [is readInt32];
    if (OGTLFlagSet(flags, 3))
    {
        NSString *sound = nil;
        if (!OGTLCoreReadNotificationSound(is, &sound, error))
            return nil;
        if (sound != nil)
            result.sound = sound;
        else
            result.flags &= ~(1 << 3);
    }
    if (OGTLFlagSet(flags, 4))
    {
        if (!OGTLCoreReadNotificationSound(is, NULL, error))
            return nil;
    }
    if (OGTLFlagSet(flags, 5))
    {
        if (!OGTLCoreReadNotificationSound(is, NULL, error))
            return nil;
    }
    OGTLSkipFlagged(is, environment, error, flags, 6, 'i');
    OGTLSkipFlagged(is, environment, error, flags, 7, 'i');
    if (OGTLFlagSet(flags, 8))
    {
        if (!OGTLCoreReadNotificationSound(is, NULL, error))
            return nil;
    }
    if (OGTLFlagSet(flags, 9))
    {
        if (!OGTLCoreReadNotificationSound(is, NULL, error))
            return nil;
    }
    if (OGTLFlagSet(flags, 10))
    {
        if (!OGTLCoreReadNotificationSound(is, NULL, error))
            return nil;
    }
    return result;
}

@end

@interface OGTLUpdateNotifySettingsParser : TLUpdate$updateNotifySettings
@end

@implementation OGTLUpdateNotifySettingsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdate$updateNotifySettings *result = OGTLNewObject(TLUpdate$updateNotifySettings);
    result.peer = (TLNotifyPeer *)OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.notify_settings = (TLPeerNotifySettings *)OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}

@end

@interface OGTLUpdateGroupCallParser : TLUpdate
@end

@implementation OGTLUpdateGroupCallParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    int32_t flags = [is readInt32];
    NSError *nestedError;
    if (OGTLFlagSet(flags, 1))
    {
        OGTLCoreReadObject(is, environment, &nestedError);
        if (nestedError != nil)
        {
            if (error != NULL)
                *error = nestedError;
            return nil;
        }
    }
    OGTLCoreReadObject(is, environment, &nestedError);
    if (nestedError != nil)
    {
        if (error != NULL)
            *error = nestedError;
        return nil;
    }
    return self;
}

@end

@interface OGTLChatInviteParser : TLChatInvite$chatInvite
@end

@implementation OGTLChatInviteParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLChatInvite$chatInvite *result = [[TLChatInvite$chatInvite alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.title = [is readString];
    OGTLSkipFlagged(is, environment, error, flags, 5, 's');
    OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.participants_count = [is readInt32];
    if (OGTLFlagSet(flags, 4))
        result.participants = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    [is readInt32];
    return result;
}

@end

@interface OGTLMessageMediaGiveawayParser : TLMessageMedia$messageMediaUnsupported
@end

@implementation OGTLMessageMediaGiveawayParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused tlContext error:(__autoreleasing NSError **)__unused error
{
    int32_t flags = [is readInt32];
    if (signature == OGTLCtor(0xdaad85b0))
    {
        OGTLCoreReadInt64Vector(is);
        OGTLSkipFlagged(is, environment, error, flags, 1, 't');
        OGTLSkipFlagged(is, environment, error, flags, 3, 's');
        [is readInt32];
        [is readInt32];
        [is readInt32];
    }
    else if (signature == OGTLCtor(0xc6991068))
    {
        OGTLTakeInt64(is);
        OGTLSkipFlagged(is, environment, error, flags, 3, 'i');
        [is readInt32];
        [is readInt32];
        [is readInt32];
        OGTLCoreReadInt64Vector(is);
        [is readInt32];
        OGTLSkipFlagged(is, environment, error, flags, 1, 's');
        [is readInt32];
    }
    return OGTLNewObject(TLMessageMedia$messageMediaUnsupported);
}

@end

@interface OGTLFolderPeerParser : TLFolderPeerEntry
@end

static NSString *OGTLReadReactionSummary(NSInputStream *is, id<TLSerializationEnvironment> environment, NSString **chosenReaction, __autoreleasing NSError **error)
{
    if (chosenReaction != NULL)
        *chosenReaction = nil;
    int32_t reactionsSignature = [is readInt32];
    if (reactionsSignature != (int32_t)0x0a339f0b && reactionsSignature != (int32_t)0x4f2b9479)
    {
        OGTLCoreBuildObject(is, reactionsSignature, environment, error);
        return @"";
    }

    int32_t flags = [is readInt32];
    int32_t vectorMarker = OGTLTakeInt32(is);
    int32_t count = vectorMarker == TL_UNIVERSAL_VECTOR_CONSTRUCTOR ? [is readInt32] : vectorMarker;
    if (count < 0 || count > 10000)
        count = 0;

    NSMutableArray *parts = [[NSMutableArray alloc] init];
    for (int32_t i = 0; i < count; i++)
    {
        int32_t countSignature = [is readInt32];
        if (countSignature != (int32_t)0xa3d1cb80)
        {
            OGTLCoreBuildObject(is, countSignature, environment, error);
            continue;
        }

        int32_t countFlags = [is readInt32];
        bool chosen = (countFlags & (1 << 0)) != 0;
        if (chosen)
            [is readInt32];

        int32_t reactionSignature = OGTLTakeInt32(is);
        NSString *reaction = nil;
        if (reactionSignature == OGTLCtor(0x1b2286b8))
            reaction = [is readString];
        else if (reactionSignature == OGTLCtor(0x8935fc73))
            reaction = [NSString stringWithFormat:@"◆%lld", [is readInt64]];
        else if (reactionSignature == (int32_t)0x523da4eb)
            reaction = @"★";
        else if (reactionSignature != (int32_t)0x79f5d419)
            OGTLCoreBuildObject(is, reactionSignature, environment, error);

        int32_t reactionCount = [is readInt32];
        if (chosen && reaction.length != 0 && chosenReaction != NULL)
            *chosenReaction = reaction;
        if (reaction.length != 0 && reactionCount > 0)
            [parts addObject:[NSString stringWithFormat:@"%@ %d", reaction, reactionCount]];
    }

    OGTLSkipFlagged(is, environment, error, flags, 1, 'v');
    if (reactionsSignature != (int32_t)0x4f2b9479 && (flags & (1 << 4)))
        OGTLCoreReadObjectVector(is, environment, error);

    return [parts componentsJoinedByString:@"  "];
}

@interface OGTLUpdateMessageReactionsParser : TLUpdate$updateMessageReactionsSummary
@end

@implementation OGTLUpdateMessageReactionsParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    int32_t flags = [is readInt32];
    TLUpdate$updateMessageReactionsSummary *result = [[TLUpdate$updateMessageReactionsSummary alloc] init];
    result.peer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
    result.msg_id = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
    if (signature == (int32_t)0x1e297bfa && (flags & (1 << 1)))
        OGTLCoreReadObject(is, environment, error);
    NSString *chosenReaction = nil;
    result.reactionSummary = OGTLReadReactionSummary(is, environment, &chosenReaction, error);
    result.chosenReaction = chosenReaction;
    OGFeatureProbe(@"REACTION update.parse mid=%d peerClass=%@ flags=0x%08x summary=%@ error=%@", result.msg_id, NSStringFromClass([result.peer class]), flags, result.reactionSummary, error != NULL ? *error : nil);
    return result;
}

@end

@implementation OGTLFolderPeerParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLFolderPeerEntry *result = OGTLNewObject(TLFolderPeerEntry);
    result.peer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
    result.folder_id = OGTLTakeInt32(is);
    return result;
}

@end

@interface OGTLUpdateFolderPeersParser : TLUpdate$updateFolderPeers
@end

@implementation OGTLUpdateFolderPeersParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdate$updateFolderPeers *result = OGTLNewObject(TLUpdate$updateFolderPeers);
    result.folder_peers = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.pts = [is readInt32];
    result.pts_count = [is readInt32];
    return result;
}

@end

@interface OGTLModernDialogParser : TLDialog$dialog
@end

@implementation OGTLModernDialogParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLDialog$dialog *result = [[TLDialog$dialog alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.peer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
    result.top_message = [is readInt32];
    result.read_inbox_max_id = [is readInt32];
    result.read_outbox_max_id = [is readInt32];
    result.unread_count = [is readInt32];
    result.unread_mentions_count = [is readInt32];
    if (signature != OGTLCtor(0xe4def5db))
        [is readInt32];
    if (signature == OGTLCtor(0x69274bc6) || signature == OGTLCtor(0xfc89f7f3))
        [is readInt32];
    result.notify_settings = (TLPeerNotifySettings *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(flags, 0))
        result.pts = [is readInt32];
    if (OGTLFlagSet(flags, 1))
        result.draft = (TLDraftMessage *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(flags, 4))
        result.folder_id = OGTLTakeInt32(is);
    OGTLSkipFlagged(is, environment, error, flags, 5, 'i');
    return result;
}

@end

@interface OGTLDialogFolderParser : TLDialog$dialog
@end

@implementation OGTLDialogFolderParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLDialog$dialog *result = [[TLDialog$dialog alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    
    int32_t folderSignature = OGTLTakeInt32(is);
    if (folderSignature == OGTLCtor(0xff544e65))
    {
        int32_t folderFlags = OGTLTakeInt32(is);
        [is readInt32];
        OGTLTakeString(is);
        OGTLSkipFlagged(is, environment, error, folderFlags, 3, 'o');
    }
    else
    {
        OGTLCoreBuildObject(is, folderSignature, environment, error);
    }
    
    result.peer = (TLPeer *)OGTLCoreReadObject(is, environment, error);
    result.top_message = [is readInt32];
    [is readInt32];
    [is readInt32];
    [is readInt32];
    [is readInt32];
    return nil;
}

@end

@interface OGTLModernImportedContactParser : TLImportedContact$importedContact
@end

@implementation OGTLModernImportedContactParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLImportedContact$importedContact *result = OGTLNewObject(TLImportedContact$importedContact);
    int64_t userId = OGTLTakeInt64(is);
    result.user_id = userId;
    result.client_id = OGTLTakeInt64(is);
    return result;
}

@end

@interface OGTLUserStatusEmptyParser : TLUserStatus$userStatusEmpty
@end

@implementation OGTLUserStatusEmptyParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)__unused is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    return OGTLNewObject(TLUserStatus$userStatusEmpty);
}

@end

@interface OGTLUserStatusOnlineParser : TLUserStatus$userStatusOnline
@end

@implementation OGTLUserStatusOnlineParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLUserStatus$userStatusOnline *result = OGTLNewObject(TLUserStatus$userStatusOnline);
    result.expires = [is readInt32];
    return result;
}

@end

@interface OGTLUserStatusOfflineParser : TLUserStatus$userStatusOffline
@end

@implementation OGTLUserStatusOfflineParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLUserStatus$userStatusOffline *result = OGTLNewObject(TLUserStatus$userStatusOffline);
    result.was_online = OGTLTakeInt32(is);
    return result;
}

@end

@interface OGTLUserStatusNoPayloadParser : TLUserStatus$userStatusRecently
@end

@implementation OGTLUserStatusNoPayloadParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused tlContext error:(__autoreleasing NSError **)__unused error
{
    switch (signature)
    {
        case OGTLCtor(0x7b197dc8):
        case OGTLCtor(0x541a1d1a):
        case OGTLCtor(0x65899777):
        {
            [is readInt32];
            return OGTLNewObject(TLUserStatus$userStatusRecently);
        }
        default:
            return OGTLNewObject(TLUserStatus$userStatusRecently);
    }
}

@end

@interface OGTLModernContactStatusParser : TLContactStatus$contactStatus
@end

@implementation OGTLModernContactStatusParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLContactStatus$contactStatus *result = OGTLNewObject(TLContactStatus$contactStatus);
    int64_t userId = OGTLTakeInt64(is);
    int32_t statusSignature = OGTLTakeInt32(is);
    result.user_id = userId;
    [result setStatus:(TLUserStatus *)OGTLCoreBuildObject(is, statusSignature, environment, error)];
    return result;
}

@end

@interface OGTLModernKeyboardButtonStyleParser : OGTLManualParser
@end

@implementation OGTLModernKeyboardButtonStyleParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    int32_t flags = [is readInt32];
    OGTLSkipFlagged(is, environment, error, flags, 3, 'l');
    return self;
}

@end

@interface OGTLModernReplyMarkupParser : TLReplyMarkup
@end

@implementation OGTLModernReplyMarkupParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0xa03e5b85))
    {
        TLReplyMarkup$replyKeyboardHide *result = OGTLNewObject(TLReplyMarkup$replyKeyboardHide);
        result.flags = [is readInt32];
        return result;
    }
    else if (signature == OGTLCtor(0x86b40b08) || signature == OGTLCtor(0xf4108aa0))
    {
        TLReplyMarkup$replyKeyboardForceReply *result = OGTLNewObject(TLReplyMarkup$replyKeyboardForceReply);
        int32_t flags = [is readInt32];
        result.flags = flags;
        OGTLSkipFlagged(is, environment, error, flags, 3, 's');
        return result;
    }
    else if (signature == OGTLCtor(0x85dd99d1) || signature == OGTLCtor(0x3502758c))
    {
        TLReplyMarkup$replyKeyboardMarkup *result = OGTLNewObject(TLReplyMarkup$replyKeyboardMarkup);
        int32_t flags = [is readInt32];
        result.flags = flags;
        result.rows = OGTLCoreReadObjectVector(is, environment, error);
        OGTLSkipFlagged(is, environment, error, flags, 3, 's');
        return result;
    }
    else if (signature == OGTLCtor(0x48a30254))
    {
        TLReplyMarkup$replyInlineMarkup *result = OGTLNewObject(TLReplyMarkup$replyInlineMarkup);
        result.rows = OGTLCoreReadObjectVector(is, environment, error);
        return result;
    }
    else if (signature == (int32_t)0xb2b15770)
    {
        TLReplyMarkup$replyInlineMarkup *result = OGTLNewObject(TLReplyMarkup$replyInlineMarkup);
        [is readInt32];
        result.rows = OGTLCoreReadObjectVector(is, environment, error);
        return result;
    }
    
    return nil;
}

@end

@interface OGTLModernKeyboardButtonRowParser : TLKeyboardButtonRow
@end

@implementation OGTLModernKeyboardButtonRowParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLKeyboardButtonRow$keyboardButtonRow *result = OGTLNewObject(TLKeyboardButtonRow$keyboardButtonRow);
    result.buttons = OGTLCoreReadObjectVector(is, environment, error);
    return result;
}

@end

static TLKeyboardButton *OGTLKeyboardButtonWithType(NSInputStream *is, int32_t typeSignature, NSString *text, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    switch (typeSignature)
    {
        case (int32_t)0xdf3d36f9:
        {
            TLKeyboardButton$keyboardButtonRequestPhone *button = OGTLNewObject(TLKeyboardButton$keyboardButtonRequestPhone);
            [button setText:text];
            return button;
        }
        case (int32_t)0x9beee140:
        {
            TLKeyboardButton$keyboardButtonRequestGeoLocation *button = OGTLNewObject(TLKeyboardButton$keyboardButtonRequestGeoLocation);
            [button setText:text];
            return button;
        }
        case (int32_t)0xaacfff84:
        {
            int32_t flags = [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 0, 'i');
            break;
        }
        case (int32_t)0x4f58a237:
        case (int32_t)0x3fe268fe:
            [is readInt32];
            [is readInt32];
            OGTLCoreReadObject(is, environment, error);
            [is readInt32];
            break;
        case (int32_t)0xc01a597a:
        case (int32_t)0xeca4f8d4:
        case (int32_t)0x3bcab5b4:
        {
            TLKeyboardButton$keyboardButtonUrl *button = OGTLNewObject(TLKeyboardButton$keyboardButtonUrl);
            [button setText:text];
            button.url = OGTLTakeString(is);
            return button;
        }
        case (int32_t)0xbfd02da2:
        {
            int32_t flags = [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 0, 's');
            TLKeyboardButton$keyboardButtonUrl *button = OGTLNewObject(TLKeyboardButton$keyboardButtonUrl);
            [button setText:text];
            button.url = OGTLTakeString(is);
            [is readInt32];
            return button;
        }
        case (int32_t)0x9961bcb4:
        {
            int32_t flags = [is readInt32];
            OGTLSkipFlagged(is, environment, error, flags, 1, 's');
            TLKeyboardButton$keyboardButtonUrl *button = OGTLNewObject(TLKeyboardButton$keyboardButtonUrl);
            [button setText:text];
            [button setUrl:[is readString]];
            OGTLSkipFlagged(is, environment, error, flags, 2, 'o');
            return button;
        }
        case (int32_t)0x2955bc38:
        {
            [is readInt32];
            TLKeyboardButton$keyboardButtonCallback *button = OGTLNewObject(TLKeyboardButton$keyboardButtonCallback);
            [button setText:text];
            button.data = OGTLTakeBytes(is);
            return button;
        }
        case (int32_t)0x5cd3709d:
        {
            TLKeyboardButton$keyboardButtonGame *button = OGTLNewObject(TLKeyboardButton$keyboardButtonGame);
            [button setText:text];
            return button;
        }
        case (int32_t)0x48bad7a5:
        {
            TLKeyboardButton$keyboardButtonBuy *button = OGTLNewObject(TLKeyboardButton$keyboardButtonBuy);
            [button setText:text];
            return button;
        }
        case (int32_t)0x93773ff5:
        {
            int32_t flags = [is readInt32];
            TLKeyboardButton$keyboardButtonSwitchInline *button = OGTLNewObject(TLKeyboardButton$keyboardButtonSwitchInline);
            button.flags = flags & (1 << 0);
            [button setText:text];
            button.query = OGTLTakeString(is);
            OGTLSkipFlagged(is, environment, error, flags, 1, 'v');
            return button;
        }
        case (int32_t)0x3fa33fcf:
            OGTLTakeInt64(is);
            break;
        case (int32_t)0x53f3ce5a:
            OGTLCoreReadObject(is, environment, error);
            break;
        case (int32_t)0xb41d3272:
            OGTLTakeString(is);
            break;
        case (int32_t)0xc9dd90e9:
        case (int32_t)0xa438619d:
            break;
        default:
            OGTLCoreBuildObject(is, typeSignature, environment, error);
            break;
    }
    TLKeyboardButton$keyboardButton *button = OGTLNewObject(TLKeyboardButton$keyboardButton);
    [button setText:text];
    return button;
}

@interface OGTLModernKeyboardButtonParser : TLKeyboardButton
@end

@implementation OGTLModernKeyboardButtonParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == (int32_t)0x2f67a72f || signature == (int32_t)0x11c1a322)
    {
        int32_t buttonFlags = [is readInt32];
        if (buttonFlags & (1 << 10))
            OGTLCoreReadObject(is, environment, error);
        NSString *buttonText = [is readString];
        int32_t typeSignature = [is readInt32];
        return OGTLKeyboardButtonWithType(is, typeSignature, buttonText, environment, error);
    }

    int32_t flags = 0;
    bool carriesFlags = signature == OGTLCtor(0x35bbdb6b) || signature == OGTLCtor(0x0568a748) || signature == OGTLCtor(0x93b9fbb5) || signature == OGTLCtor(0x10b78d29) || signature == OGTLCtor(0xd02e7fd4) || signature == OGTLCtor(0xbbc7515d) || signature == OGTLCtor(0xc9662d05) || signature == OGTLCtor(0x7d170cff) || signature == OGTLCtor(0xd80c25ec) || signature == OGTLCtor(0xe62bc960) || signature == OGTLCtor(0x417efd8f) || signature == OGTLCtor(0xaa40f94d) || signature == OGTLCtor(0x991399fc) || signature == OGTLCtor(0x89c590f9) || signature == OGTLCtor(0x3fa53905) || signature == OGTLCtor(0xf51006f9) || signature == OGTLCtor(0x68013e72) || signature == OGTLCtor(0x7a11d782) || signature == OGTLCtor(0x7d5e07c7) || signature == OGTLCtor(0xc0fd5d09) || signature == OGTLCtor(0xe846b1a0) || signature == OGTLCtor(0xe15c4370) || signature == OGTLCtor(0x5b0f15f5) || signature == OGTLCtor(0x02b78156) || signature == OGTLCtor(0xbcc4af10);
    bool hasButtonStyle = signature == OGTLCtor(0x7d170cff) || signature == OGTLCtor(0xd80c25ec) || signature == OGTLCtor(0xe62bc960) || signature == OGTLCtor(0x417efd8f) || signature == OGTLCtor(0xaa40f94d) || signature == OGTLCtor(0x991399fc) || signature == OGTLCtor(0x89c590f9) || signature == OGTLCtor(0x3fa53905) || signature == OGTLCtor(0xf51006f9) || signature == OGTLCtor(0x68013e72) || signature == OGTLCtor(0x7a11d782) || signature == OGTLCtor(0x7d5e07c7) || signature == OGTLCtor(0xc0fd5d09) || signature == OGTLCtor(0xe846b1a0) || signature == OGTLCtor(0xe15c4370) || signature == OGTLCtor(0x5b0f15f5) || signature == OGTLCtor(0x02b78156) || signature == OGTLCtor(0xbcc4af10);
    if (carriesFlags)
    {
        flags = OGTLTakeInt32(is);
        if (hasButtonStyle && (OGTLFlagSet(flags, 10)))
            OGTLCoreReadObject(is, environment, error);
    }
    
    if ((signature == (int32_t)0xbbc7515d || signature == (int32_t)0x7a11d782) && (OGTLFlagSet(flags, 0)))
        OGTLCoreReadObject(is, environment, error);
    NSString *text = OGTLTakeString(is);
    TLKeyboardButton *built = nil;
    
    if (signature == OGTLCtor(0x258aff05) || signature == OGTLCtor(0xd80c25ec) || signature == OGTLCtor(0x13767230) || signature == OGTLCtor(0xa0c0505c) || signature == OGTLCtor(0xe846b1a0) || signature == OGTLCtor(0xe15c4370))
    {
        TLKeyboardButton$keyboardButtonUrl *button = OGTLNewObject(TLKeyboardButton$keyboardButtonUrl);
        [button setText:text];
        [button setUrl:[is readString]];
        built = button;
    }
    else if (signature == OGTLCtor(0x683a5e46) || signature == OGTLCtor(0x35bbdb6b) || signature == OGTLCtor(0xe62bc960))
    {
        TLKeyboardButton$keyboardButtonCallback *button = OGTLNewObject(TLKeyboardButton$keyboardButtonCallback);
        [button setText:text];
        [button setData:[is readBytes]];
        built = button;
    }
    else if (signature == OGTLCtor(0xb16a6c29) || signature == OGTLCtor(0x417efd8f))
    {
        TLKeyboardButton$keyboardButtonRequestPhone *button = OGTLNewObject(TLKeyboardButton$keyboardButtonRequestPhone);
        [button setText:text];
        built = button;
    }
    else if (signature == OGTLCtor(0xfc796b3f) || signature == OGTLCtor(0xaa40f94d))
    {
        TLKeyboardButton$keyboardButtonRequestGeoLocation *button = OGTLNewObject(TLKeyboardButton$keyboardButtonRequestGeoLocation);
        [button setText:text];
        built = button;
    }
    else if (signature == OGTLCtor(0x0568a748) || signature == OGTLCtor(0x93b9fbb5) || signature == OGTLCtor(0x991399fc))
    {
        TLKeyboardButton$keyboardButtonSwitchInline *button = OGTLNewObject(TLKeyboardButton$keyboardButtonSwitchInline);
        [button setFlags:flags];
        [button setText:text];
        [button setQuery:[is readString]];
        if ((OGTLFlagSet(flags, 1)) && (signature == (int32_t)0x93b9fbb5 || signature == (int32_t)0x991399fc))
            OGTLCoreReadObjectVector(is, environment, error);
        built = button;
    }
    else if (signature == OGTLCtor(0x50f41ccf) || signature == OGTLCtor(0x89c590f9))
    {
        TLKeyboardButton$keyboardButtonGame *button = OGTLNewObject(TLKeyboardButton$keyboardButtonGame);
        [button setText:text];
        built = button;
    }
    else if (signature == OGTLCtor(0xafd93fbb) || signature == OGTLCtor(0x3fa53905))
    {
        TLKeyboardButton$keyboardButtonBuy *button = OGTLNewObject(TLKeyboardButton$keyboardButtonBuy);
        [button setText:text];
        built = button;
    }
    else if (signature == OGTLCtor(0x10b78d29) || signature == OGTLCtor(0xd02e7fd4) || signature == OGTLCtor(0xf51006f9) || signature == OGTLCtor(0x68013e72))
    {
        bool isUrlAuthOutput = signature == OGTLCtor(0x10b78d29) || signature == OGTLCtor(0xf51006f9);
        if ((isUrlAuthOutput && (OGTLFlagSet(flags, 0))) || (!isUrlAuthOutput && (OGTLFlagSet(flags, 1))))
            OGTLTakeString(is);
        TLKeyboardButton$keyboardButtonUrl *button = OGTLNewObject(TLKeyboardButton$keyboardButtonUrl);
        [button setText:text];
        [button setUrl:[is readString]];
        if (isUrlAuthOutput)
            [is readInt32];
        else
            OGTLCoreReadObject(is, environment, error);
        built = button;
    }
    else if (signature == OGTLCtor(0xbbc7515d) || signature == OGTLCtor(0x7a11d782))
    {
    }
    else if (signature == OGTLCtor(0xe988037b) || signature == OGTLCtor(0x7d5e07c7))
    {
        OGTLCoreReadObject(is, environment, error);
    }
    else if (signature == OGTLCtor(0x308660c1) || signature == OGTLCtor(0xc0fd5d09))
    {
        OGTLTakeInt64(is);
    }
    else if (signature == OGTLCtor(0x53d7bfd8) || signature == OGTLCtor(0xc9662d05) || signature == OGTLCtor(0x5b0f15f5) || signature == OGTLCtor(0x02b78156))
    {
        [is readInt32];
        OGTLCoreReadObject(is, environment, error);
        [is readInt32];
    }
    else if (signature == OGTLCtor(0x75d2698e) || signature == OGTLCtor(0xbcc4af10))
    {
        OGTLTakeString(is);
    }
    
    if (built == nil)
    {
        TLKeyboardButton$keyboardButton *button = OGTLNewObject(TLKeyboardButton$keyboardButton);
        [button setText:text];
        built = button;
    }
    
    return built;
}

@end

@interface OGTLModernUpdateUserParser : TLUpdate
{
    int64_t _userId;
}
@property (nonatomic) int64_t userId;
@end

@implementation OGTLModernUpdateUserParser

@synthesize userId = _userId;

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    OGTLModernUpdateUserParser *result = [[OGTLModernUpdateUserParser alloc] init];
    result.userId = [is readInt64];
    return result;
}

@end

@interface OGTLModernUpdateUserStatusParser : TLUpdate$updateUserStatus
@end

@implementation OGTLModernUpdateUserStatusParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdate$updateUserStatus *result = OGTLNewObject(TLUpdate$updateUserStatus);
    int64_t userId = OGTLTakeInt64(is);
    int32_t statusSignature = OGTLTakeInt32(is);
    result.user_id = userId;
    [result setStatus:(TLUserStatus *)OGTLCoreBuildObject(is, statusSignature, environment, error)];
    return result;
}

@end

@interface OGTLModernUpdateDeleteChannelMessagesParser : TLUpdate$updateDeleteChannelMessages
@end

@implementation OGTLModernUpdateDeleteChannelMessagesParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLUpdate$updateDeleteChannelMessages *result = OGTLNewObject(TLUpdate$updateDeleteChannelMessages);
    int64_t channelId = OGTLTakeInt64(is);
    result.channel_id = channelId;
    result.messages = OGTLCoreReadInt32Vector(is);
    result.pts = [is readInt32];
    result.pts_count = [is readInt32];
    return result;
}

@end

@interface OGTLModernUpdateChannelTooLongParser : TLUpdate$updateChannelTooLong
@end

@implementation OGTLModernUpdateChannelTooLongParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLUpdate$updateChannelTooLong *result = [[TLUpdate$updateChannelTooLong alloc] init];
    int32_t flags = [is readInt32];
    int64_t channelId = OGTLTakeInt64(is);
    result.flags = flags;
    result.channel_id = channelId;
    if (OGTLFlagSet(flags, 0))
        result.pts = [is readInt32];
    return result;
}

@end

@interface OGTLModernUpdateShortMessageParser : TLUpdates$modernUpdateShortMessage
@end

@implementation OGTLModernUpdateShortMessageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdates$modernUpdateShortMessage *result = [[TLUpdates$modernUpdateShortMessage alloc] init];
    result.flags = [is readInt32];
    result.n_id = [is readInt32];
    result.user_id = [is readInt64];
    result.message = [is readString];
    result.pts = [is readInt32];
    result.pts_count = [is readInt32];
    result.date = [is readInt32];
    if (OGTLFlagSet(result.flags, 2))
        result.fwd_header = (TLMessageFwdHeader *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(result.flags, 11))
        result.via_bot_id = [is readInt64];
    if (OGTLFlagSet(result.flags, 3))
        result.reply_to_msg_id = OGTLCoreReadReplyHeaderCompat(is, environment, error);
    if (OGTLFlagSet(result.flags, 7))
        result.entities = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLFlagSet(result.flags, 25))
        [is readInt32];
    return result;
}

@end

@interface OGTLModernUpdateShortChatMessageParser : TLUpdates$modernUpdateShortChatMessage
@end

@implementation OGTLModernUpdateShortChatMessageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdates$modernUpdateShortChatMessage *result = [[TLUpdates$modernUpdateShortChatMessage alloc] init];
    result.flags = [is readInt32];
    result.n_id = [is readInt32];
    result.from_id = [is readInt64];
    result.chat_id = [is readInt64];
    result.message = [is readString];
    result.pts = [is readInt32];
    result.pts_count = [is readInt32];
    result.date = [is readInt32];
    if (OGTLFlagSet(result.flags, 2))
        result.fwd_header = (TLMessageFwdHeader *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(result.flags, 11))
        result.via_bot_id = [is readInt64];
    if (OGTLFlagSet(result.flags, 3))
        result.reply_to_msg_id = OGTLCoreReadReplyHeaderCompat(is, environment, error);
    if (OGTLFlagSet(result.flags, 7))
        result.entities = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLFlagSet(result.flags, 25))
        [is readInt32];
    return result;
}

@end

@interface OGTLModernUpdateShortSentMessageParser : TLUpdates$updateShortSentMessage
@end

@implementation OGTLModernUpdateShortSentMessageParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdates$updateShortSentMessage *result = [[TLUpdates$updateShortSentMessage alloc] init];
    result.flags = [is readInt32];
    result.n_id = [is readInt32];
    result.pts = [is readInt32];
    result.pts_count = [is readInt32];
    result.date = [is readInt32];
    if (OGTLFlagSet(result.flags, 9))
        result.media = (TLMessageMedia *)OGTLCoreReadObject(is, environment, error);
    if (OGTLFlagSet(result.flags, 7))
        result.entities = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLFlagSet(result.flags, 25))
        [is readInt32];
    return result;
}

@end

@interface OGTLDialogFilterItem : OGTLManualParser
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

@implementation OGTLDialogFilterItem
- (int32_t)TLconstructorSignature { return 0; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

static NSString *OGTLCoreReadDialogFilterTitle(NSInputStream *is, bool textWithEntities, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
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

    NSString *text = OGTLTakeString(is);
    OGTLCoreReadObjectVector(is, environment, error);
    return text == nil ? @"" : text;
}

@interface OGTLDialogFilterParser : OGTLManualParser
@end

@implementation OGTLDialogFilterParser
- (int32_t)TLconstructorSignature { return 0; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLDialogFilterItem *result = [[OGTLDialogFilterItem alloc] init];

    if (signature == (int32_t)0x363293ae)
    {
        result.defaultFilter = true;
        result.filterId = 0;
        result.color = -1;
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
    result.color = -1;
    result.flags = [is readInt32];
    result.filterId = [is readInt32];
    result.title = OGTLCoreReadDialogFilterTitle(is, modernTitle, environment, error);
    if (OGTLCoreFailed(error))
        return nil;

    if (OGTLFlagSet(result.flags, 25))
        result.emoticon = [is readString];
    if (!layer166 && (result.flags & (1 << 27)))
        result.color = [is readInt32];

    result.pinnedPeers = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.includePeers = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;

    if (!chatlist)
    {
        result.excludePeers = OGTLCoreReadObjectVector(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
    }
    else
        result.excludePeers = @[];

    return result;
}
@end

@interface OGTLDialogFiltersResult : OGTLManualParser
@property (nonatomic) int32_t flags;
@property (nonatomic, strong) NSArray *filters;
@end

@implementation OGTLDialogFiltersResult
- (int32_t)TLconstructorSignature { return (int32_t)0x2ad93719; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }
@end

@interface OGTLDialogFiltersParser : OGTLManualParser
@end

@implementation OGTLDialogFiltersParser
- (int32_t)TLconstructorSignature { return (int32_t)0x2ad93719; }
- (int32_t)TLconstructorName { return -1; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)__unused os { }

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    OGTLDialogFiltersResult *result = [[OGTLDialogFiltersResult alloc] init];
    result.flags = [is readInt32];
    result.filters = OGTLCoreReadObjectVector(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}
@end

@interface OGTLDialogFilterUpdateParser : TLUpdate
@end

@implementation OGTLDialogFilterUpdateParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0xa5d72105))
    {
        int32_t vectorMarker = OGTLTakeInt32(is);
        int32_t count = 0;
        if (!OGTLCoreVectorCountForMarker(is, vectorMarker, &count))
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
        if (OGTLFlagSet(flags, 0))
        {
            OGTLCoreReadObject(is, environment, error);
            if (OGTLCoreFailed(error))
                return nil;
        }
    }

    OGPlatformDispatchOnMainThread(^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TGIOS6DialogFiltersUpdated" object:nil];
    });
    return self;
}

@end

@interface OGTLModernUpdatesStateParser : TLupdates_State$updates_state
@end

@implementation OGTLModernUpdatesStateParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLupdates_State$updates_state *result = OGTLNewObject(TLupdates_State$updates_state);
    result.pts = [is readInt32];
    result.qts = OGTLTakeInt32(is);
    result.date = [is readInt32];
    result.seq = OGTLTakeInt32(is);
    result.unread_count = [is readInt32];
    OGTLCoreLastReadUpdatesState = result;
    return result;
}

@end

static TLupdates_State *OGTLCoreReadUpdatesStateCompat(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    int32_t stateSignature = OGTLTakeInt32(is);
    if (stateSignature == OGTLCtor(0xa56c2a3e))
    {
        TLupdates_State$updates_state *result = OGTLNewObject(TLupdates_State$updates_state);
        result.pts = [is readInt32];
        result.qts = OGTLTakeInt32(is);
        result.date = [is readInt32];
        result.seq = OGTLTakeInt32(is);
        result.unread_count = [is readInt32];
        OGTLCoreLastReadUpdatesState = result;
        return result;
    }
    
    return (TLupdates_State *)OGTLCoreBuildObject(is, stateSignature, environment, error);
}

@interface OGTLModernUpdatesParser : TLUpdates$updates
@end

@implementation OGTLModernUpdatesParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0x78d4dec1))
    {
        TLUpdates$updateShort *result = OGTLNewObject(TLUpdates$updateShort);
        result.update = (TLUpdate *)OGTLCoreReadObject(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        result.date = [is readInt32];
        return result;
    }

    if (signature == OGTLCtor(0x725b04c3))
    {
        TLUpdates$updatesCombined *result = OGTLNewObject(TLUpdates$updatesCombined);
        result.updates = OGTLCoreReadStrictObjectVectorWithRole(is, @"updatesCombined.updates", environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        result.users = OGTLCoreReadStrictObjectVectorWithRole(is, @"updatesCombined.users", environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        result.chats = OGTLCoreReadStrictObjectVectorWithRole(is, @"updatesCombined.chats", environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        result.date = [is readInt32];
        result.seq_start = OGTLTakeInt32(is);
        result.seq = OGTLTakeInt32(is);
        return result;
    }

    TLUpdates$updates *result = OGTLNewObject(TLUpdates$updates);
    result.updates = OGTLCoreReadStrictObjectVectorWithRole(is, @"updates.updates", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.users = OGTLCoreReadStrictObjectVectorWithRole(is, @"updates.users", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.chats = OGTLCoreReadStrictObjectVectorWithRole(is, @"updates.chats", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.date = [is readInt32];
    result.seq = OGTLTakeInt32(is);
    return result;
}

@end

@interface OGTLModernDifferenceEmptyParser : TLupdates_Difference$updates_differenceEmpty
@end

@implementation OGTLModernDifferenceEmptyParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)__unused environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)__unused error
{
    TLupdates_Difference$updates_differenceEmpty *result = [[TLupdates_Difference$updates_differenceEmpty alloc] init];
    result.date = [is readInt32];
    [result setSeq:[is readInt32]];
    return result;
}

@end

@interface OGTLModernDifferenceParser : TLupdates_Difference$updates_difference
@end

@implementation OGTLModernDifferenceParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    if (signature == OGTLCtor(0xa8fb1981))
    {
        TLupdates_Difference$updates_differenceSlice *result = OGTLNewObject(TLupdates_Difference$updates_differenceSlice);
        result.n_new_messages = OGTLCoreReadStrictObjectVectorWithRole(is, @"differenceSlice.messages", environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        result.n_new_encrypted_messages = OGTLCoreReadStrictObjectVectorWithRole(is, @"differenceSlice.encrypted", environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        result.other_updates = OGTLCoreReadStrictObjectVectorWithRole(is, @"differenceSlice.updates", environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        result.chats = OGTLCoreReadStrictObjectVectorWithRole(is, @"differenceSlice.chats", environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        result.users = OGTLCoreReadStrictObjectVectorWithRole(is, @"differenceSlice.users", environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        result.intermediate_state = OGTLCoreReadUpdatesStateCompat(is, environment, error);
        if (OGTLCoreFailed(error))
            return nil;
        return result;
    }

    TLupdates_Difference$updates_difference *result = OGTLNewObject(TLupdates_Difference$updates_difference);
    result.n_new_messages = OGTLCoreReadStrictObjectVectorWithRole(is, @"difference.messages", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.n_new_encrypted_messages = OGTLCoreReadStrictObjectVectorWithRole(is, @"difference.encrypted", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.other_updates = OGTLCoreReadStrictObjectVectorWithRole(is, @"difference.updates", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.chats = OGTLCoreReadStrictObjectVectorWithRole(is, @"difference.chats", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.users = OGTLCoreReadStrictObjectVectorWithRole(is, @"difference.users", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.state = OGTLCoreReadUpdatesStateCompat(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}

@end

@interface OGTLModernChannelDifferenceParser : TLUpdates_ChannelDifference$channelDifference
@end

@implementation OGTLModernChannelDifferenceParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUpdates_ChannelDifference$channelDifference *result = [[TLUpdates_ChannelDifference$channelDifference alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    result.pts = [is readInt32];
    if (OGTLFlagSet(flags, 1))
        result.timeout = [is readInt32];

    result.n_new_messages = OGTLCoreReadStrictObjectVectorWithRole(is, @"channelDifference.messages", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.other_updates = OGTLCoreReadStrictObjectVectorWithRole(is, @"channelDifference.updates", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.chats = OGTLCoreReadStrictObjectVectorWithRole(is, @"channelDifference.chats", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.users = OGTLCoreReadStrictObjectVectorWithRole(is, @"channelDifference.users", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    return result;
}

@end

@interface OGTLChannelDifferenceTooLongParser : TLchannelDifferenceTooLong
@end

@implementation OGTLChannelDifferenceTooLongParser

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)__unused signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLchannelDifferenceTooLong *result = [[TLchannelDifferenceTooLong alloc] init];
    int32_t flags = [is readInt32];
    result.flags = flags;
    if (OGTLFlagSet(flags, 1))
        result.timeout = [is readInt32];
    id dialog = OGTLCoreReadObject(is, environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    if (OGTLCoreIsKind(dialog, [TLDialog$dialogMeta class]))
    {
        TLDialog$dialogMeta *channelMeta = (TLDialog$dialogMeta *)dialog;
        [result setPts:channelMeta.pts];
        [result setTop_message:channelMeta.top_message];
        [result setUnread_count:channelMeta.unread_count];
        [result setUnread_mentions_count:channelMeta.unread_mentions_count];
        [result setRead_inbox_max_id:channelMeta.read_inbox_max_id];
        [result setRead_outbox_max_id:channelMeta.read_outbox_max_id];
    }
    result.messages = OGTLCoreReadStrictObjectVectorWithRole(is, @"channelDifferenceTooLong.messages", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.chats = OGTLCoreReadStrictObjectVectorWithRole(is, @"channelDifferenceTooLong.chats", environment, error);
    if (OGTLCoreFailed(error))
        return nil;
    result.users = OGTLCoreReadStrictObjectVectorWithRole(is, @"channelDifferenceTooLong.users", environment, error);
    if (OGTLCoreFailed(error))
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
    id<TLObject> found = nil;
    bool registrationPending = false;
    {
        TGTLClassRegistryGuard guard;
        std::tr1::unordered_map<int32_t, id<TLObject> >::iterator it = objectClassesByConstructorNames.find(name);
        if (it != objectClassesByConstructorNames.end())
            found = it->second;
        registrationPending = TGTLObjectClassRegistrationPending;
    }

    if (found == nil)
    {
        TLMetaClassTable const *table = TLgetMetaClassTable();
        id<TLObject> objectClass = TLMetaClassInstantiate(table->objectClasses, table->objectClassesCount, table->classNames, name);
        if (objectClass != nil)
        {
            TGTLClassRegistryGuard guard;
            found = objectClassesByConstructorNames.insert(std::pair<int32_t, id<TLObject> >(name, objectClass)).first->second;
        }
    }

    if (found == nil && registrationPending)
    {
        dispatch_group_wait(TGTLObjectClassRegistrationGroup(), DISPATCH_TIME_FOREVER);
        TGTLClassRegistryGuard guard;
        std::tr1::unordered_map<int32_t, id<TLObject> >::iterator it = objectClassesByConstructorNames.find(name);
        if (it != objectClassesByConstructorNames.end())
            found = it->second;
    }

    if (found == nil)
    {
        return nil;
    }
    return found;
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
    if (!OGTLCoreIsKind(scheme, [TLScheme$scheme class]))
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

typedef struct
{
    int32_t signature;
    NSString *name;
} OGTLHashName;

void TLMetaClassStore::mergeSchemeEntries(TLMetaSchemeEntries &entries, bool materialize)
{
    TGTLClassRegistryGuard guard;
    CFAbsoluteTime mergeStart = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime mergePhaseStart = mergeStart;
    
    size_t schemeMethodsCount = entries.methods.size();
    OGTLSkipObjectParser *sharedSkipObjectParser = [[OGTLSkipObjectParser alloc] init];
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
    objectClassesByConstructorNames[OGTLCtor(0x9fbde43f)] = [[TLChat$channelMeta alloc] init];
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x9fbde43f, @"channel"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[OGTLCtor(0xe2f65ce2)] = [[TLUserFull$userFullMeta alloc] init];
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xe2f65ce2, @"UserFull"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[OGTLCtor(0x8c5d990f)] = [[TLupdates_ChannelDifference$updates_channelDifferenceMeta alloc] init];
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x8c5d990f, @"updates.ChannelDifference"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0x4ccda305] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x4ccda305, @"updatePinnedChannelMessages"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0xf9a7c6d9] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xf9a7c6d9, @"businessLocation"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0xae9f31e8] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xae9f31e8, @"pollAnswerVoters"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0xd5d4c7f5] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xd5d4c7f5, @"mediaAreaSuggestedReaction"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0x377d3538] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x377d3538, @"webPageAttributeStickerSet"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0x9ac0c0cc] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x9ac0c0cc, @"messageEntityFormattedDate"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0x1f1ea79e] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x1f1ea79e, @"PeerColor"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0xa61d7ecc] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xa61d7ecc, @"botApp"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0xd91a34ac] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xd91a34ac, @"storyViews"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0x731eca73] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x731eca73, @"updatePinnedDialogs"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0x8350972b] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x8350972b, @"recentStory"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0xcba86ca2] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xcba86ca2, @"RequestPeerType"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0xf6781f7c] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xf6781f7c, @"modernOptionalFeature"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0x7f6b4284] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x7f6b4284, @"modernOptionalFeature"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0xd7bb4f53] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xd7bb4f53, @"modernOptionalFeature"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0xc18fad86] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xc18fad86, @"modernOptionalFeature"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0xff68ab47] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xff68ab47, @"notificationSound"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    objectClassesByConstructorNames[(int32_t)0x7a557809] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x7a557809, @"modernReactionFeature"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x09d05049, TLLazyManualObjectParser(OGTLUserStatusEmptyParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xedb93949, TLLazyManualObjectParser(OGTLUserStatusOnlineParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x008c703f, TLLazyManualObjectParser(OGTLUserStatusOfflineParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7b197dc8, TLLazyManualObjectParser(OGTLUserStatusNoPayloadParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x541a1d1a, TLLazyManualObjectParser(OGTLUserStatusNoPayloadParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x65899777, TLLazyManualObjectParser(OGTLUserStatusNoPayloadParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x16d9703b, TLLazyManualObjectParser(OGTLModernContactStatusParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe5bdf8de, TLLazyManualObjectParser(OGTLModernUpdateUserStatusParser)));
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
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x22c0f6d5, TLLazyManualObjectParser(OGTLModernInputReplyToParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x869fbe10, TLLazyManualObjectParser(OGTLModernInputReplyToParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3bd4b7c2, TLLazyManualObjectParser(OGTLModernInputReplyToParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x75c1ad70, TLLazyManualObjectParser(OGTLModernInputReplyToParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5881323a, TLLazyManualObjectParser(OGTLModernInputReplyToParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x69d66c45, TLLazyManualObjectParser(OGTLModernInputReplyToParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x8c39793f, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc02d4007, TLLazyManualObjectParser(OGTLModernChatParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe46bcee4, TLLazyManualObjectParser(OGTLModernChatParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa0933f5b, TLLazyManualObjectParser(OGTLModernChatParticipantParser)));
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x22c0f6d5, @"inputReplyToMessage"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    addHashToString((int32_t)0x869fbe10, @"inputReplyToMessage");
    addHashToString((int32_t)0x3bd4b7c2, @"inputReplyToMessage");
    addHashToString((int32_t)0x75c1ad70, @"inputReplyToMessage");
    addHashToString((int32_t)0x5881323a, @"inputReplyToStory");
    addHashToString((int32_t)0x69d66c45, @"inputReplyToMonoForum");
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x8c39793f, @"help.promoData"},
            {(int32_t)0xc02d4007, @"chatParticipant"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x914FBF11, TLLazyManualObjectParser(TLUpdates$modernUpdateShortMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x313bc7f8, TLLazyManualObjectParser(OGTLModernUpdateShortMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x16812688, TLLazyManualObjectParser(TLUpdates$modernUpdateShortChatMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x4d6deea5, TLLazyManualObjectParser(OGTLModernUpdateShortChatMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xBC0F17BC, TLLazyManualObjectParser(TLmessages_Messages$modernChannelMessages)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x11f1331c, TLLazyManualObjectParser(TLUpdates$updateShortSentMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x9015e101, TLLazyManualObjectParser(OGTLModernUpdateShortSentMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa56c2a3e, TLLazyManualObjectParser(OGTLModernUpdatesStateParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x78d4dec1, TLLazyManualObjectParser(OGTLModernUpdatesParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x725b04c3, TLLazyManualObjectParser(OGTLModernUpdatesParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x74ae4240, TLLazyManualObjectParser(OGTLModernUpdatesParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5fb5523b, TLLazyManualObjectParser(OGTLDialogFilterParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7438f7e8, TLLazyManualObjectParser(OGTLDialogFilterParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x363293ae, TLLazyManualObjectParser(OGTLDialogFilterParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x9fe28ea4, TLLazyManualObjectParser(OGTLDialogFilterParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xaa472651, TLLazyManualObjectParser(OGTLDialogFilterParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x96537bd7, TLLazyManualObjectParser(OGTLDialogFilterParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x2ad93719, TLLazyManualObjectParser(OGTLDialogFiltersParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x26ffde7d, TLLazyManualObjectParser(OGTLDialogFilterUpdateParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa5d72105, TLLazyManualObjectParser(OGTLDialogFilterUpdateParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3504914f, TLLazyManualObjectParser(OGTLDialogFilterUpdateParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5d75a138, TLLazyManualObjectParser(OGTLModernDifferenceEmptyParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x00f49ca0, TLLazyManualObjectParser(OGTLModernDifferenceParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa8fb1981, TLLazyManualObjectParser(OGTLModernDifferenceParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x2064674E, TLLazyManualObjectParser(OGTLModernChannelDifferenceParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x3E11AFFB, TLLazyManualObjectParser(TLUpdates_ChannelDifference$empty)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xc88974ac, TLLazyManualObjectParser(TLChat$channel)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x0aadfc8f, TLLazyManualObjectParser(OGTLModernChannelParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1c32b11c, TLLazyManualObjectParser(OGTLModernChannelParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe00998b7, TLLazyManualObjectParser(OGTLModernChannelParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfe4478bd, TLLazyManualObjectParser(OGTLModernChannelParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfe685355, TLLazyManualObjectParser(OGTLModernChannelParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd49f34c6, TLLazyManualObjectParser(OGTLModernChannelParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7ad15240, TLLazyManualObjectParser(OGTLModernChannelParser)));
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xfe4478bd, @"channel"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    addHashToString((int32_t)0xfe685355, @"channel");
    addHashToString((int32_t)0xd49f34c6, @"channel");
    addHashToString((int32_t)0x7ad15240, @"channel");
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
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xdd27bee9, sharedSkipObjectParser));
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
    addHashToString((int32_t)0xdd27bee9, @"ephemeralMessage");
    addHashToString((int32_t)0xbe376999, @"notifyCommunity");
    addHashToString((int32_t)0x2f65c8e4, @"dialogPeerCommunity");
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x17d493d5, TLLazyManualObjectParser(OGTLModernChannelForbiddenParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x76af5481, TLLazyManualObjectParser(TLChatFull$channelFull)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xbbab348d, TLLazyManualObjectParser(OGTLModernChannelFullParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa04e8d3a, TLLazyManualObjectParser(OGTLModernChannelFullParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe4e0b29d, TLLazyManualObjectParser(OGTLModernChannelFullParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc4c4dd40, TLLazyManualObjectParser(OGTLModernChannelFullParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xFC900C2B, TLLazyManualObjectParser(TLChatParticipants$chatParticipantsForbidden)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xD91CDD54, TLLazyManualObjectParser(TLChat$chat)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x41cbf256, TLLazyManualObjectParser(OGTLModernChatParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x6592a1a7, TLLazyManualObjectParser(OGTLModernChatForbiddenParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1c6e1c11, TLLazyManualObjectParser(OGTLModernChatPhotoParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xB08FBB93, TLLazyManualObjectParser(TLWebPage$webPageExternal)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x947ca848, TLLazyManualObjectParser(TLMessages_BotResults$botResults)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe021f2f6, TLLazyManualObjectParser(TLMessages_BotResults$botResults)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x764cf810, TLLazyManualObjectParser(TLBotInlineMessage$botInlineMessageMediaAuto)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x8c7f65e2, TLLazyManualObjectParser(TLBotInlineMessage$botInlineMessageText)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xb722de65, TLLazyManualObjectParser(TLBotInlineMessage$botInlineMessageMediaGeo)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x051846fd, TLLazyManualObjectParser(TLBotInlineMessage$botInlineMessageMediaGeo)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x8a86659c, TLLazyManualObjectParser(TLBotInlineMessage$botInlineMessageMediaVenue)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x18d1cdc2, TLLazyManualObjectParser(TLBotInlineMessage$botInlineMessageMediaContact)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x11965f3a, TLLazyManualObjectParser(TLBotInlineResult$botInlineResult)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x9852F9C6, TLLazyManualObjectParser(TLDocumentAttribute$documentAttributeAudio)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x43c57c48, TLLazyManualObjectParser(OGTLModernDocumentAttributeVideoParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x559ebe6d, TLLazyManualObjectParser(TLMessageFwdHeader$messageFwdHeader)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xf220f3f, TLLazyManualObjectParser(TLUserFull$userFull)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x3b6d152e, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xcc997720, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xd2234ea0, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x06cbe645, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb90c2afd, sharedSkipObjectParser));
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
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc32d5b12, TLLazyManualObjectParser(OGTLModernUpdateDeleteChannelMessagesParser)));
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xc32d5b12, @"updateDeleteChannelMessages"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5e1b3cb8, TLLazyManualObjectParser(OGTLUpdateMessageReactionsParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xd6b19546, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x51e6ee4f, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xea29055d, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x922e6e10, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x9c974fdf, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x8951abef, TLLazyManualObjectParser(OGTLModernUpdateNewAuthorizationParser)));
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
    manualObjectParsers[(int32_t)0xdaad85b0] = TLLazyManualObjectParser(OGTLMessageMediaGiveawayParser);
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xdaad85b0, @"messageMediaGiveaway"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers[(int32_t)0xc6991068] = TLLazyManualObjectParser(OGTLMessageMediaGiveawayParser);
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xc6991068, @"messageMediaGiveawayResults"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers[(int32_t)0xbec268ef] = TLLazyManualObjectParser(OGTLUpdateNotifySettingsParser);
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xbec268ef, @"updateNotifySettings"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers[(int32_t)0xcde0ec40] = TLLazyManualObjectParser(OGTLChatInviteParser);
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xcde0ec40, @"chatInvite"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers[(int32_t)0x4ba3a95a] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x4ba3a95a, @"messageReactor"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers[(int32_t)0xe16459c3] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xe16459c3, @"updateDialogUnreadMark"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers[(int32_t)0xe56dbf05] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xe56dbf05, @"dialogPeer"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers[(int32_t)0x514519e2] = sharedSkipObjectParser;
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x514519e2, @"dialogPeerFolder"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xf74e932b, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb05ac6b1, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xeb0467fb, TLLazyManualObjectParser(TLUpdate$updateChannelTooLong)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x108d941f, TLLazyManualObjectParser(OGTLModernUpdateChannelTooLongParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa4bcc6fe, TLLazyManualObjectParser(OGTLChannelDifferenceTooLongParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x38faab5f, TLLazyManualObjectParser(TLauth_SentCode$auth_sentCode)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x5e002502, TLLazyManualObjectParser(TLauth_SentCode$auth_sentCode)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x36585ea4, TLLazyManualObjectParser(TLmessages_BotCallbackAnswer$botCallbackAnswer)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x17db940b, TLLazyManualObjectParser(TLBotInlineResult$botInlineMediaResult)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xe4def5db, TLLazyManualObjectParser(OGTLModernDialogParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd58a08c6, TLLazyManualObjectParser(OGTLModernDialogParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x90a6ca84, TLLazyManualObjectParser(OGTLModernMessageEmptyParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb6c4f543, TLLazyManualObjectParser(OGTLMessageViewsResultParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x8c718e87, TLLazyManualObjectParser(OGTLModernMessagesParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1d73e7ea, TLLazyManualObjectParser(OGTLModernMessagesParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3a54685e, TLLazyManualObjectParser(OGTLModernMessagesSliceParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5f206716, TLLazyManualObjectParser(OGTLModernMessagesSliceParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x3e0b5b6a, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc776ba4e, TLLazyManualObjectParser(OGTLModernChannelMessagesParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x9ab0feaf, TLLazyManualObjectParser(OGTLModernChannelsParticipantsParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xdfb80317, TLLazyManualObjectParser(OGTLModernChannelParticipantResultParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc00c07c0, TLLazyManualObjectParser(OGTLModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1bd54456, TLLazyManualObjectParser(OGTLModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x35a8bfa7, TLLazyManualObjectParser(OGTLModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa9478a1a, TLLazyManualObjectParser(OGTLModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x2fe601d3, TLLazyManualObjectParser(OGTLModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x34c3bb53, TLLazyManualObjectParser(OGTLModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x6df8014e, TLLazyManualObjectParser(OGTLModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd5f0ad91, TLLazyManualObjectParser(OGTLModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1b03f006, TLLazyManualObjectParser(OGTLModernChannelParticipantParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x71701da9, TLLazyManualObjectParser(OGTLForumTopicParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfcdad815, TLLazyManualObjectParser(OGTLForumTopicParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x023f109b, TLLazyManualObjectParser(OGTLForumTopicParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x15ba6c40, TLLazyManualObjectParser(OGTLDialogsParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x71e094f3, TLLazyManualObjectParser(OGTLDialogsParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xf0e3e596, TLLazyManualObjectParser(OGTLDialogsParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x0200185b, TLLazyManualObjectParser(OGTLDialogsParser)));
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
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x6a26cb37, @"message"},
            {(int32_t)0x96fdbbe9, @"message"},
            {(int32_t)0xd0bbd081, @"message"},
            {(int32_t)0x003e38e7, @"message"},
            {(int32_t)0xd9a7d88a, @"message"},
            {(int32_t)0xd18fd1bb, @"message"},
            {(int32_t)0xff86154d, @"message"},
            {(int32_t)0xbb294f27, @"message"},
            {(int32_t)0x65fdf943, @"message"},
            {(int32_t)0x6a4ced37, @"message"},
            {(int32_t)0x6236ae4a, @"message"},
            {(int32_t)0xd8a8d820, @"message"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x2b085862, TLLazyManualObjectParser(TLMessage$modernMessageService)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x7063c3db, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd64c522b, TLLazyManualObjectParser(OGTLUpdateMessagePollParser)));
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xd64c522b, @"updateMessagePoll"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xed85eab5, sharedSkipObjectParser));
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0xed85eab5, @"updatePinnedMessages"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7a800e0a, TLLazyManualObjectParser(TLMessage$modernMessageService)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x6a3ac8ea, TLLazyManualObjectParser(TLMessage$modernMessageService)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x4fdd3430, TLLazyManualObjectParser(OGTLModernKeyboardButtonStyleParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa03e5b85, TLLazyManualObjectParser(OGTLModernReplyMarkupParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x86b40b08, TLLazyManualObjectParser(OGTLModernReplyMarkupParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xf4108aa0, TLLazyManualObjectParser(OGTLModernReplyMarkupParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x85dd99d1, TLLazyManualObjectParser(OGTLModernReplyMarkupParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3502758c, TLLazyManualObjectParser(OGTLModernReplyMarkupParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x48a30254, TLLazyManualObjectParser(OGTLModernReplyMarkupParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb2b15770, TLLazyManualObjectParser(OGTLModernReplyMarkupParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x77608b83, TLLazyManualObjectParser(OGTLModernKeyboardButtonRowParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x19420af6, TLLazyManualObjectParser(OGTLModernKeyboardButtonRowParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x3081ed9d, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x833c0fac, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xd766c50a, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x5ec4be43, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x6334ee9a, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x0e3b2d0c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa2fa4880, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7d170cff, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x2f67a72f, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x11c1a322, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x258aff05, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd80c25ec, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x683a5e46, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x35bbdb6b, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe62bc960, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb16a6c29, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x417efd8f, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfc796b3f, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xaa40f94d, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x0568a748, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x93b9fbb5, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x991399fc, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x50f41ccf, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x89c590f9, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xafd93fbb, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3fa53905, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x10b78d29, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd02e7fd4, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xf51006f9, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x68013e72, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xbbc7515d, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7a11d782, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe988037b, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x308660c1, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7d5e07c7, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc0fd5d09, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x13767230, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa0c0505c, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe846b1a0, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe15c4370, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x53d7bfd8, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc9662d05, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5b0f15f5, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x02b78156, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x75d2698e, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xbcc4af10, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x5f3b8a00, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xc9f06e1b, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x339bef6c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x3e81e078, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x71bd134c, TLLazyManualObjectParser(OGTLDialogFolderParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x69274bc6, TLLazyManualObjectParser(OGTLModernDialogParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfc89f7f3, TLLazyManualObjectParser(OGTLModernDialogParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x59511722, TLLazyManualObjectParser(OGTLModernPeerUserParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x15752102, TLLazyManualObjectParser(OGTLModernPeerUserParser)));
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x15752102, @"peerUser"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x36c6019a, TLLazyManualObjectParser(OGTLModernPeerChatParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa2a5371e, TLLazyManualObjectParser(OGTLModernPeerChannelParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb9c0639a, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x5da674b7, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x95fcd1d6, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x99622c0c, TLLazyManualObjectParser(OGTLModernPeerNotifySettingsParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc13e3c50, TLLazyManualObjectParser(OGTLModernImportedContactParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5ce14175, TLLazyManualObjectParser(TLPopularContact$popularContact)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5fb224d5, TLLazyManualObjectParser(OGTLModernChatAdminRightsParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x9f120418, TLLazyManualObjectParser(OGTLModernChatBannedRightsParser)));
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
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x50a04e45, TLLazyManualObjectParser(OGTLModernPrivacyRulesParser)));
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
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe9baa668, TLLazyManualObjectParser(OGTLFolderPeerParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x19360dc0, TLLazyManualObjectParser(OGTLUpdateFolderPeersParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1e297bfa, TLLazyManualObjectParser(OGTLUpdateMessageReactionsParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x695c9e7c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x4f11bae1, TLLazyManualObjectParser(TLUserProfilePhoto$userProfilePhotoEmpty)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x82d1f706, TLLazyManualObjectParser(OGTLModernUserProfilePhotoParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xebd1c797, TLLazyManualObjectParser(OGTLModernUserProfilePhotoParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x85dd99d1, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x48a30254, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xa03e5b85, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x86b40b08, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x77608b83, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xa2fa4880, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x258aff05, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x35bbdb6b, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xb16a6c29, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xfc796b3f, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x93b9fbb5, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x50f41ccf, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xafd93fbb, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x10b78d29, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd02e7fd4, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xbbc7515d, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe988037b, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x308660c1, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x13767230, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa0c0505c, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x53d7bfd8, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc9662d05, TLLazyManualObjectParser(OGTLModernKeyboardButtonParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x36086d42, TLLazyManualObjectParser(TLDialog$dialogFeed)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xfd8e711f, TLLazyManualObjectParser(TLDraftMessage$draftMessage)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x60fe3294, TLLazyManualObjectParser(OGTLModernDraftMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3fccf7ef, TLLazyManualObjectParser(OGTLModernDraftMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x96eaa5eb, TLLazyManualObjectParser(OGTLModernDraftMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x2d65321f, TLLazyManualObjectParser(OGTLModernDraftMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1b49ec6d, TLLazyManualObjectParser(OGTLModernUpdateDraftMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xedfc111e, TLLazyManualObjectParser(OGTLModernUpdateDraftMessageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x8f300b57, TLLazyManualObjectParser(OGTLModernBotInfoParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc27ac8c7, TLLazyManualObjectParser(OGTLModernBotCommandParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x9852d6d2, TLLazyManualObjectParser(OGTLModernBotCommandParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x7533a588, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x4258c205, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0xc7b57ce6, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xdb74f558, TLLazyManualObjectParser(TLChatInvite$chatInvite)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x3213dbba, TLLazyManualObjectParser(TLConfig$config)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xcc1a241e, TLLazyManualObjectParser(OGTLModernConfigParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xcd050916, TLLazyManualObjectParser(TLauth_Authorization$auth_authorization)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x2ea2c0d4, TLLazyManualObjectParser(TLauth_Authorization$auth_authorization)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x6319d612, TLLazyManualObjectParser(TLDocumentAttributeSticker)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x6c37c15c, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x11b58939, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x17399fad, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x15590068, TLLazyManualObjectParser(OGTLModernDocumentAttributeFilenameParser)));
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
    objectClassesByConstructorNames[OGTLCtor(0xdc7555ab)] = [[TLPhoneCall$phoneCallWaitingMeta alloc] init];
    objectClassesByConstructorNames[OGTLCtor(0x9627ce57)] = [[TLPhoneCall$phoneCallRequested alloc] init];
    objectClassesByConstructorNames[OGTLCtor(0xd149f2bd)] = [[TLPhoneCall$phoneCallAccepted alloc] init];
    objectClassesByConstructorNames[OGTLCtor(0xc9908a15)] = [[TLPhoneCall$phoneCall alloc] init];
    objectClassesByConstructorNames[OGTLCtor(0xf01017df)] = [[TLPhoneCall$phoneCallDiscardedMeta alloc] init];
    OGTLPhoneConnectionParser *phoneConnectionParser = [[OGTLPhoneConnectionParser alloc] init];
    manualObjectParsers[OGTLCtor(0x9cc123c7)] = phoneConnectionParser;
    manualObjectParsers[OGTLCtor(0x635fe375)] = phoneConnectionParser;
    manualObjectParsers[(int32_t)0xeccaad39] = sharedSkipObjectParser;
    objectClassesByConstructorNames[(int32_t)0xeccaad39] = sharedSkipObjectParser;
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xea4cb65b, TLLazyManualObjectParser(TLUpdate$updatePinnedDialogs)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x80e11a7f, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb6aef7b0, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xbd47cbad, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb5a1ce5a, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7fcb13a8, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x95e3fbef, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x15cefd00, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xa43f30cc, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x031224c3, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x95d2ac92, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe1037f92, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xea3948e9, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x94bd38ed, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x9fbab604, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x92a72876, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3c134d7b, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xcc02aa6d, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x0d999256, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x8f31b327, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x96163f56, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x4792929b, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfae69f56, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc516d679, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x1b287353, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd95c6154, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x98e0d697, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x7a0d7f42, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x502f92f7, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb3a07661, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xaa786345, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x47dd8079, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb4c38cb5, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc83d6aec, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc0944820, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x57de635e, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x31518e9b, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x5060a3f4, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x678c2e09, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x332ba9ed, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x2a9fadc5, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x93b31848, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x41b3e202, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x45d5b021, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xf3f25f76, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xebbca3cb, TLLazyManualObjectParser(OGTLModernMessageActionParser)));
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
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x695150d7, TLLazyManualObjectParser(OGTLModernMessageMediaPhotoParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe216eb63, TLLazyManualObjectParser(OGTLModernMessageMediaPhotoParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xb940c666, TLLazyManualObjectParser(OGTLModernMessageMediaGeoLiveParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xddf10c3b, TLLazyManualObjectParser(OGTLModernMessageMediaWebPageParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x3f7ee58b, TLLazyManualObjectParser(OGTLModernMessageMediaDiceParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x08cbec07, TLLazyManualObjectParser(OGTLModernMessageMediaDiceParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xdc7b1140, TLLazyManualObjectParser(OGTLModernMessageEntityMentionNameParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xc8cf05f8, TLLazyManualObjectParser(OGTLModernMessageEntityCustomEmojiParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x145ade0b, TLLazyManualObjectParser(OGTLModernContactParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >(0x6a7e7366, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x9cb070d7, TLLazyManualObjectParser(OGTLModernMessageMediaDocumentParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x4cf4d72d, TLLazyManualObjectParser(OGTLModernMessageMediaDocumentParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x52d8ccd9, TLLazyManualObjectParser(OGTLModernMessageMediaDocumentParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfb197a65, TLLazyManualObjectParser(OGTLModernPhotoParser)));
    manualObjectParsers[(int32_t)0xdd570bd5] = TLLazyManualObjectParser(OGTLModernMessageMediaDocumentParser);
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x75c78e60, TLLazyManualObjectParser(OGTLModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x021e1ad6, TLLazyManualObjectParser(OGTLModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xe0b0bc2e, TLLazyManualObjectParser(OGTLModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xfa3efb95, TLLazyManualObjectParser(OGTLModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xd8214d41, TLLazyManualObjectParser(OGTLModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xde33b094, TLLazyManualObjectParser(OGTLModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0xf85c413c, TLLazyManualObjectParser(OGTLModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x0da082fe, TLLazyManualObjectParser(OGTLModernPhotoSizeParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x77d01c3b, TLLazyManualObjectParser(OGTLModernImportedContactsParser)));
    manualObjectParsers.insert(std::pair<int32_t, id<TLObject> >((int32_t)0x83d60fc2, sharedSkipObjectParser));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>((int32_t)0x8fd4c4d8, TLLazyManualObjectParser(OGTLModernDocumentParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x6a9d7b35, TLLazyManualObjectParser(TLchannelDifferenceTooLong)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x55c3a1b1, TLLazyManualObjectParser(TLmessages_FeedMessages$messages_feedMessages)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x8e8bca3d, TLLazyManualObjectParser(TLchannels_FeedSources$channels_feedSources)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x31bc3d25, TLLazyManualObjectParser(TLInputSingleMedia$inputSingleMedia)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x5585a139, TLLazyManualObjectParser(TLStickerSet$stickerSet)));
    manualObjectParsers[(int32_t)0x6410a5d2] = TLLazyManualObjectParser(OGTLModernStickerSetCoveredParser);
    manualObjectParsers[(int32_t)0x3407e51b] = TLLazyManualObjectParser(OGTLModernStickerSetCoveredParser);
    manualObjectParsers[(int32_t)0x40d13c0e] = TLLazyManualObjectParser(OGTLModernStickerSetCoveredParser);
    manualObjectParsers[(int32_t)0x77b15d1c] = TLLazyManualObjectParser(OGTLModernStickerSetCoveredParser);
    manualObjectParsers[(int32_t)0xcdbbcebb] = TLLazyManualObjectParser(OGTLModernAllStickersParser);
    manualObjectParsers[(int32_t)0x2cb51097] = TLLazyManualObjectParser(OGTLModernFavedStickersParser);
    manualObjectParsers[(int32_t)0xfcfeb29c] = TLLazyManualObjectParser(OGTLModernStickerKeywordParser);
    manualObjectParsers[(int32_t)0x12b299d4] = TLLazyManualObjectParser(OGTLStickerPackParser);
    manualObjectParsers[(int32_t)0x6e153f16] = TLLazyManualObjectParser(OGTLModernStickerSetParser);
    manualObjectParsers[(int32_t)0xe86602c3] = TLLazyManualObjectParser(OGTLModernAllStickersParser);
    manualObjectParsers[(int32_t)0x9e8fa6d3] = TLLazyManualObjectParser(OGTLModernFavedStickersParser);
    manualObjectParsers[(int32_t)0x88d37c56] = TLLazyManualObjectParser(OGTLModernRecentStickersParser);
    manualObjectParsers[(int32_t)0x0b17f890] = TLLazyManualObjectParser(OGTLModernRecentStickersParser);
    manualObjectParsers[(int32_t)0xbe382906] = TLLazyManualObjectParser(OGTLModernFeaturedStickersParser);
    manualObjectParsers[(int32_t)0xc6dc0c66] = TLLazyManualObjectParser(OGTLModernFeaturedStickersParser);
    manualObjectParsers[(int32_t)0x38641628] = TLLazyManualObjectParser(OGTLModernStickerSetInstallResultParser);
    manualObjectParsers[(int32_t)0x35e410a8] = TLLazyManualObjectParser(OGTLModernStickerSetInstallResultParser);
    manualObjectParsers[(int32_t)0x8af09dd2] = TLLazyManualObjectParser(OGTLModernFoundStickerSetsParser);
    manualObjectParsers[(int32_t)0x0d54b65d] = TLLazyManualObjectParser(OGTLModernFoundStickerSetsParser);
    manualObjectParsers[(int32_t)0x2dd14edc] = TLLazyManualObjectParser(OGTLModernStickerSetMetaParser);
    manualObjectParsers[(int32_t)0xd3f924eb] = TLLazyManualObjectParser(OGTLModernStickerSetParser);
    manualObjectParsers[(int32_t)0x6319d612] = TLLazyManualObjectParser(OGTLModernDocumentAttributeStickerParser);
    manualObjectParsers[(int32_t)0xffb62b95] = TLLazyManualObjectParser(OGTLModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x9de7a269] = TLLazyManualObjectParser(OGTLModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x861cc8a0] = TLLazyManualObjectParser(OGTLModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x028703c8] = TLLazyManualObjectParser(OGTLModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0xe67f520e] = TLLazyManualObjectParser(OGTLModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0xcde3739] = TLLazyManualObjectParser(OGTLModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0xc88b3b02] = TLLazyManualObjectParser(OGTLModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x04c4d4ce] = TLLazyManualObjectParser(OGTLModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x29d0f5ee] = TLLazyManualObjectParser(OGTLModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x44c1f8e9] = TLLazyManualObjectParser(OGTLModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x49748553] = TLLazyManualObjectParser(OGTLModernInputStickerSetParser);
    manualObjectParsers[(int32_t)0x1cf671a0] = TLLazyManualObjectParser(OGTLModernInputStickerSetParser);
    addHashToString((int32_t)0x6cdf9cef, @"stickerPack");
    {
        static const OGTLHashName table[] =
        {
            {(int32_t)0x2dd14edc, @"stickerSet"},
            {(int32_t)0x88d37c56, @"messages.recentStickers"},
            {(int32_t)0xbe382906, @"messages.featuredStickers"},
            {(int32_t)0x8af09dd2, @"messages.foundStickerSets"},
            {(int32_t)0x6319d612, @"documentAttributeSticker"}
        };
        for (size_t i = 0; i < sizeof(table) / sizeof(table[0]); i++)
            addHashToString(table[i].signature, table[i].name);
    }
    manualObjectParsers[(int32_t)0xb434e2b8] = TLLazyManualObjectParser(OGTLModernExportedAuthorizationParser);
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x6fa68e41, TLLazyManualObjectParser(TLUpdate$updateReadFeed)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xe09e1fb8, TLLazyManualObjectParser(TLhelp_ProxyData$proxyDataEmpty)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x2bf7ee23, TLLazyManualObjectParser(TLhelp_ProxyData$proxyDataPromo)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x780a0310, TLLazyManualObjectParser(TLhelp_TermsOfService$help_termsOfService)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x187fa0ca, TLLazyManualObjectParser(TLSecureValue$secureValue)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xdb21d0a7, TLLazyManualObjectParser(TLInputSecureValue$inputSecureValue)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xad2e1cd8, TLLazyManualObjectParser(TLaccount_AuthorizationForm$account_authorizationForm)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xaf509d20, TLLazyManualObjectParser(TLPeerNotifySettings$peerNotifySettings)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x6a4ee832, TLLazyManualObjectParser(TLhelp_DeepLinkInfo$help_deepLinkInfo)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x1b0c841a, TLLazyManualObjectParser(OGTLModernDraftMessageEmptyParser)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x1da7158f, TLLazyManualObjectParser(TLhelp_AppUpdate$help_appUpdate)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0xad2641f8, TLLazyManualObjectParser(TLaccount_Password$account_password)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x957b50fb, TLLazyManualObjectParser(TLaccount_Password$account_password)));
    manualObjectParsers.insert(std::pair<int32_t, TLManualObjectParser>(0x9a5c33e5, TLLazyManualObjectParser(TLaccount_PasswordSettings$account_passwordSettings)));

    manualObjectParsers[(int32_t)0x80e11a7f] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xffa00ccc] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xc624b16e] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xb91bbd3a] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x48e91302] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x31c48347] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xa80f51e4] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x87e2f155] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xb00c47a2] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xea2c31d3] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xe6c31522] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x7e1c1187] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x2ffe2f7a] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xcc7c5c89] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xc7edbc83] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xee7a1596] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x95ddcf69] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x69f916f8] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xa8a3c699] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x2c8f2a25] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x774278d4] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x73ada76b] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xb07ed085] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xe188503b] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xbf7d6572] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x3e2793ba] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x9da1cd6c] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x399674dc] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x16605e3e] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0xd7c0ff9c] = TLLazyManualObjectParser(TLUser$modernUser);
    manualObjectParsers[(int32_t)0x020b1422] = TLLazyManualObjectParser(TLUser$modernUser);
    manualObjectParsers[(int32_t)0xd8aa840f] = TLLazyManualObjectParser(OGTLInputGroupCallParser);
    manualObjectParsers[(int32_t)0x6880b94d] = TLLazyManualObjectParser(OGTLPeerSettingsContainerParser);
    manualObjectParsers[(int32_t)0xacd66c5e] = TLLazyManualObjectParser(OGTLModernPeerSettingsParser);
    manualObjectParsers[(int32_t)0xcc02aa6d] = TLLazyManualObjectParser(OGTLModernMessageActionParser);
    manualObjectParsers[(int32_t)0x83314fca] = TLLazyManualObjectParser(TLUser$modernUser);
    manualObjectParsers[(int32_t)0x2813e6db] = TLLazyManualObjectParser(TLUser$modernUser);
    manualObjectParsers[(int32_t)0x1afeb7ac] = TLLazyManualObjectParser(TLUser$modernUser);
    manualObjectParsers[(int32_t)0xd0a1d008] = TLLazyManualObjectParser(TLUser$modernUser);
    manualObjectParsers[(int32_t)0x145ade0b] = TLLazyManualObjectParser(OGTLModernContactParser);
    manualObjectParsers[(int32_t)0xeae87e42] = TLLazyManualObjectParser(OGTLModernContactsParser);
    manualObjectParsers[(int32_t)0xf385c1f6] = TLLazyManualObjectParser(OGTLLangPackDifferenceParser);
    manualObjectParsers[(int32_t)0xcad181f6] = TLLazyManualObjectParser(OGTLLangPackStringParser);
    manualObjectParsers[(int32_t)0x2979eeb2] = TLLazyManualObjectParser(OGTLLangPackStringParser);
    manualObjectParsers[(int32_t)0x0ade1591] = TLLazyManualObjectParser(OGTLModernBlockedParser);
    manualObjectParsers[(int32_t)0xe1664194] = TLLazyManualObjectParser(OGTLModernBlockedParser);
    manualObjectParsers[(int32_t)0xe8fd8014] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x211a1788] = TLLazyManualObjectParser(OGTLModernWebPageEmptyParser);
    manualObjectParsers[(int32_t)0xe89c45b2] = TLLazyManualObjectParser(OGTLModernWebPageParser);
    manualObjectParsers[(int32_t)0xddf10c3b] = TLLazyManualObjectParser(OGTLModernMessageMediaWebPageParser);
    manualObjectParsers[(int32_t)0xb53e8b21] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x8c9a88ac] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x3f7ee58b] = TLLazyManualObjectParser(OGTLModernMessageMediaDiceParser);
    manualObjectParsers[(int32_t)0x08cbec07] = TLLazyManualObjectParser(OGTLModernMessageMediaDiceParser);
    manualObjectParsers[(int32_t)0x4bd6e798] = TLLazyManualObjectParser(OGTLModernMessageMediaPollParser);
    manualObjectParsers[(int32_t)0xb2a2f663] = TLLazyManualObjectParser(OGTLModernGeoPointSkipParser);
    manualObjectParsers[(int32_t)0x4e4df4bb] = TLLazyManualObjectParser(OGTLModernMessageFwdHeaderParser);
    manualObjectParsers[(int32_t)0xdc7b1140] = TLLazyManualObjectParser(OGTLModernMessageEntityMentionNameParser);
    manualObjectParsers[(int32_t)0xc8cf05f8] = TLLazyManualObjectParser(OGTLModernMessageEntityCustomEmojiParser);
    manualObjectParsers[(int32_t)0x9c4e7e8b] = TLLazyManualObjectParser(OGTLModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0xbf0693d4] = TLLazyManualObjectParser(OGTLModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x761e6af4] = TLLazyManualObjectParser(OGTLModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x32ca960f] = TLLazyManualObjectParser(OGTLModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0xf1ccaaac] = TLLazyManualObjectParser(OGTLModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x904ac7c7] = TLLazyManualObjectParser(OGTLModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x71777116] = TLLazyManualObjectParser(OGTLModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0xc6c1e5a7] = TLLazyManualObjectParser(OGTLModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x0652c1c5] = TLLazyManualObjectParser(OGTLModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x6c622f67] = TLLazyManualObjectParser(OGTLModernMessageEntitySimpleParser);
    manualObjectParsers[(int32_t)0x751f3146] = TLLazyManualObjectParser(OGTLTextWithEntitiesParser);
    manualObjectParsers[(int32_t)0x58747131] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xff16e2ca] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x7adf2420] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xf8227181] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xebe07752] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x20529438] = TLLazyManualObjectParser(OGTLModernUpdateUserParser);
    manualObjectParsers[(int32_t)0x635b4c09] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x6c8e1e06] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x3b6ddad2] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xd38ff1c2] = TLLazyManualObjectParser(OGTLModernDocumentAttributeVideoD38Parser);
    manualObjectParsers[(int32_t)0xeeca5ce3] = TLLazyManualObjectParser(OGTLModernLangPackLanguageParser);
    manualObjectParsers[(int32_t)0x17399fad] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xfd149899] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x6a7e7366] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x98657f0d] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xde33b094] = TLLazyManualObjectParser(OGTLModernPhotoSizeParser);
    manualObjectParsers[(int32_t)0xf85c413c] = TLLazyManualObjectParser(OGTLModernPhotoSizeParser);
    manualObjectParsers[(int32_t)0x0da082fe] = TLLazyManualObjectParser(OGTLModernPhotoSizeParser);
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
    manualObjectParsers[(int32_t)0xdc3d824f] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0x744694e0] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0x6724abc4] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0xd912a59c] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0xc12622c4] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0x9bf8bb95] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0x6c3f19b9] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0x3c2884c1] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0xde5a0dd6] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0x7e6260d7] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0xed6a8504] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0xc7fb5e01] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0x034b8621] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0x1ccb966a] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0x081ccf4f] = TLLazyManualObjectParser(OGTLRichTextSkipParser);
    manualObjectParsers[(int32_t)0x35553762] = TLLazyManualObjectParser(OGTLRichTextSkipParser);

    manualObjectParsers[(int32_t)0x2633421b] = TLLazyManualObjectParser(OGTLModernChannelFullParser);
    manualObjectParsers[(int32_t)0x3ded6320] = TLLazyManualObjectParser(OGTLModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x2238f214] = TLLazyManualObjectParser(OGTLModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x56e0d474] = TLLazyManualObjectParser(OGTLModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x70322949] = TLLazyManualObjectParser(OGTLModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x9f84f49e] = TLLazyManualObjectParser(OGTLModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x2ec0533f] = TLLazyManualObjectParser(OGTLModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0xfdb19008] = TLLazyManualObjectParser(OGTLModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0xf6a548d3] = TLLazyManualObjectParser(OGTLModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x773f4e66] = TLLazyManualObjectParser(OGTLModernMessageMediaPollParser);
    manualObjectParsers[(int32_t)0xaa073beb] = TLLazyManualObjectParser(OGTLModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0xceaa3ea1] = TLLazyManualObjectParser(OGTLModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0xa8852491] = TLLazyManualObjectParser(OGTLModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0x8a53b014] = TLLazyManualObjectParser(OGTLModernMessageMediaUnsupportedParser);
    manualObjectParsers[(int32_t)0xca5cab89] = TLLazyManualObjectParser(OGTLModernMessageMediaUnsupportedParser);
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
    manualObjectParsers[(int32_t)0xf72e0ed9] = sharedSkipObjectParser;
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
    manualObjectParsers[(int32_t)0xc077ec01] = TLLazyManualObjectParser(OGTLAvailableReactionParser);
    manualObjectParsers[(int32_t)0x9f071957] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x768e3aad] = TLLazyManualObjectParser(OGTLAvailableReactionsParser);
    manualObjectParsers[(int32_t)0xd08ce645] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x90c467d1] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb06fdbdf] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xeafdf716] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x5f2d1df2] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xb81c7034] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x367617d3] = TLLazyManualObjectParser(OGTLForumTopicsParser);
    manualObjectParsers[(int32_t)0x5fb5523b] = TLLazyManualObjectParser(OGTLDialogFilterParser);
    manualObjectParsers[(int32_t)0x7438f7e8] = TLLazyManualObjectParser(OGTLDialogFilterParser);
    manualObjectParsers[(int32_t)0x363293ae] = TLLazyManualObjectParser(OGTLDialogFilterParser);
    manualObjectParsers[(int32_t)0x9fe28ea4] = TLLazyManualObjectParser(OGTLDialogFilterParser);
    manualObjectParsers[(int32_t)0xaa472651] = TLLazyManualObjectParser(OGTLDialogFilterParser);
    manualObjectParsers[(int32_t)0x96537bd7] = TLLazyManualObjectParser(OGTLDialogFilterParser);
    manualObjectParsers[(int32_t)0x2ad93719] = TLLazyManualObjectParser(OGTLDialogFiltersParser);
    manualObjectParsers[(int32_t)0x26ffde7d] = TLLazyManualObjectParser(OGTLDialogFilterUpdateParser);
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
    manualObjectParsers[(int32_t)0x9d2216e0] = TLLazyManualObjectParser(OGTLUpdateGroupCallParser);
    manualObjectParsers[(int32_t)0xf2ebdb4e] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x2a3dc7ac] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xeba636fe] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x67753ac8] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xdcb118b7] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0xbb9bb9a5] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x1e297bfa] = TLLazyManualObjectParser(OGTLUpdateMessageReactionsParser);
    manualObjectParsers[(int32_t)0xaca1657b] = sharedSkipObjectParser;
    manualObjectParsers[(int32_t)0x86e18161] = TLLazyManualObjectParser(OGTLPollParser);
    manualObjectParsers[(int32_t)0xb8425be9] = TLLazyManualObjectParser(OGTLPollParser);
    manualObjectParsers[(int32_t)0x966e2dbf] = TLLazyManualObjectParser(OGTLPollParser);
    manualObjectParsers[(int32_t)0x6ca9c2e9] = TLLazyManualObjectParser(OGTLPollAnswerParser);
    manualObjectParsers[(int32_t)0x4b7d786a] = TLLazyManualObjectParser(OGTLPollAnswerParser);
    manualObjectParsers[(int32_t)0x3645230a] = TLLazyManualObjectParser(OGTLPollAnswerVotersParser);
    manualObjectParsers[(int32_t)0x7adf2420] = TLLazyManualObjectParser(OGTLPollResultsParser);
    manualObjectParsers[(int32_t)0xba7bb15e] = TLLazyManualObjectParser(OGTLPollResultsParser);
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
            if (context.impliedSignature != 0 && context.impliedSignature != TL_UNIVERSAL_VECTOR_CONSTRUCTOR)
                signature = context.impliedSignature;
            else
            {
                int32_t count = [is readInt32];
                NSMutableArray *array = OGTLCoreMakeArray(count);
                for (int32_t i = 0; i < count; i++)
                {
                    int32_t itemSignature = OGTLTakeInt32(is);
                    id object = OGTLCoreBuildObject(is, itemSignature, environment, error);
                    if (object != nil)
                        [array addObject:object];
                    if (OGTLCoreFailed(error))
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
            NSMutableArray *array = OGTLCoreMakeArray(count);
            for (int32_t i = 0; i < count; i++)
            {
                int32_t itemSignature = OGTLTakeInt32(is);
                id object = OGTLCoreBuildObject(is, itemSignature, environment, error);
                if (object != nil)
                    [array addObject:object];
                if (OGTLCoreFailed(error))
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
        if (OGTLCoreFailed(error))
            return TLConstructedValue();

        TLPhoneCall$phoneCallWaitingMeta *object = [[TLPhoneCall$phoneCallWaitingMeta alloc] init];
        object.flags = flags;
        object.n_id = callId;
        object.access_hash = accessHash;
        object.date = date;
        object.admin_id = adminId;
        object.participant_id = participantId;
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
        id<TLObject> outcome = nil;
        int32_t previousManualSignature = OGTLCoreCurrentManualSignature;
        NSString *previousManualParser = OGTLCoreCurrentManualParser;
        OGTLCoreCurrentManualSignature = signature;
        OGTLCoreCurrentManualParser = NSStringFromClass([parser class]);
        @try
        {
            outcome = [parser TLdeserialize:is signature:signature environment:environment context:nil error:error];
        }
        @catch (NSException *exception)
        {
            OGTLCoreCurrentManualSignature = previousManualSignature;
            OGTLCoreCurrentManualParser = previousManualParser;
            if (error != NULL)
            {
                *error = OGTLCoreMessageError([NSString stringWithFormat:@"Exception while parsing 0x%08x with %@: %@", signature, NSStringFromClass([parser class]), exception.reason]);
            }
            return TLConstructedValue();
        }
        if (error && *error != nil)
        {
            NSString *failedParserName = NSStringFromClass([parser class]);
            NSString *underlyingDescription = (*error).localizedDescription ?: @"TL parse failed";
            NSString *safeDescription = [NSString stringWithFormat:@"Manual parser %@ failed for constructor %08x: %@", failedParserName, signature, underlyingDescription];
            NSError *wrappedError = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: safeDescription}];
            *error = wrappedError;
            OGTLCoreCurrentManualSignature = previousManualSignature;
            OGTLCoreCurrentManualParser = previousManualParser;
            return TLConstructedValue();
        }
        if (outcome == nil && OGTLCoreIsKind(parser, [OGTLSkipObjectParser class]))
        {
            std::tr1::shared_ptr<TLMetaConstructor> constructor = getConstructorBySignature(signature);
            if (constructor && constructor->getResultType() && constructor->getResultType()->getName() == murMurHash32(@"Update"))
            {
                OGTLIgnoredUpdate *ignoredUpdate = [[OGTLIgnoredUpdate alloc] init];
                ignoredUpdate.ignoredSignature = signature;
                outcome = ignoredUpdate;
            }
        }
        TLConstructedValue value;
        value.type = TLConstructedValueTypeObject;
        value.nativeObject = outcome;

        OGTLCoreLastCompletedManualSignature = signature;
        OGTLCoreLastCompletedManualParser = NSStringFromClass([parser class]);
        
        OGTLCoreCurrentManualSignature = previousManualSignature;
        OGTLCoreCurrentManualParser = previousManualParser;
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
                if (OGTLCoreFailed(error))
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
        TLConstructedValue built = constructor->construct(is, environment, nil, error);
        if ((error == NULL || *error == nil) && built.type == TLConstructedValueTypeObject && built.nativeObject == nil && constructor->getResultType() && constructor->getResultType()->getName() == murMurHash32(@"Update"))
        {
            OGTLIgnoredUpdate *ignoredUpdate = [[OGTLIgnoredUpdate alloc] init];
            ignoredUpdate.ignoredSignature = signature;
            built.nativeObject = ignoredUpdate;
        }
        return built;
    }
    @catch (NSException *exception)
    {
        if (error != NULL)
        {
            *error = OGTLCoreMessageError([NSString stringWithFormat:@"Exception while auto parsing 0x%08x: %@", signature, exception.reason]);
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
                if (OGTLCoreIsKind(object, [TLRPCphone_sendSignalingData class]))
                {
                    TLRPCphone_sendSignalingData *signaling = (TLRPCphone_sendSignalingData *)object;
                    if (boxed)
                        [os writeInt32:OGTLCtor(0xff7a9383)];
                    TLMetaClassStore::serializeObject(os, signaling.peer, true);
                    [os writeBytes:signaling.data];
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
