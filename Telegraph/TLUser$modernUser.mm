#import "TLUser$modernUser.h"

#import "TLMetaClassStore.h"

static const int32_t TGModernUserEmojiStatusEmpty = (int32_t)0x2de11aae;
static const int32_t TGModernUserEmojiStatus = (int32_t)0xe7ff068a;
static const int32_t TGModernUserEmojiStatusCollectible = (int32_t)0x7184603b;

static inline void OGModernUserDiscardInt32(NSInputStream *is)
{
    (void)[is readInt32];
}

static inline void OGModernUserDiscardInt64(NSInputStream *is)
{
    (void)[is readInt64];
}

static inline void OGModernUserDiscardString(NSInputStream *is)
{
    (void)[is readString];
}

static inline void OGModernUserConstructQuiet(NSInputStream *is, int32_t signature, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    TLMetaClassStore::constructObject(is, signature, environment, nil, error);
}

static int64_t TGModernUserParseEmojiStatus(NSInputStream *is, int32_t signature, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    switch (signature)
    {
        case TGModernUserEmojiStatusEmpty:
            return 0;
        case TGModernUserEmojiStatus:
        {
            bool hasUntil = ([is readInt32] & 1) != 0;
            int64_t documentId = [is readInt64];
            if (hasUntil)
                OGModernUserDiscardInt32(is);
            return documentId;
        }
        case TGModernUserEmojiStatusCollectible:
        {
            bool hasUntil = ([is readInt32] & 1) != 0;
            OGModernUserDiscardInt64(is);
            int64_t documentId = [is readInt64];
            OGModernUserDiscardString(is);
            OGModernUserDiscardString(is);
            OGModernUserDiscardInt64(is);
            for (int colorIndex = 0; colorIndex < 4; colorIndex++)
                OGModernUserDiscardInt32(is);
            if (hasUntil)
                OGModernUserDiscardInt32(is);
            return documentId;
        }
        default:
            OGModernUserConstructQuiet(is, signature, environment, error);
            return 0;
    }
}

static const int32_t OGModernUserPeerColorSignature = (int32_t)0xb54b5acf;
static const int32_t OGModernUserVectorSignature = (int32_t)0x1cb5c415;

static bool OGModernUserHasModernLayout(int32_t signature)
{
    static const uint32_t knownSignatures[] = {
        0x4b46c37e, 0xb1b8cc83, 0x31774388, 0x020b1422, 0x83314fca,
        0x215c4438, 0x2813e6db, 0x1afeb7ac, 0xd0a1d008, 0xd7c0ff9c
    };
    for (size_t index = 0; index < sizeof(knownSignatures) / sizeof(knownSignatures[0]); index++)
    {
        if ((int32_t)knownSignatures[index] == signature)
            return true;
    }
    return false;
}

static int32_t OGModernUserPeerColorId(NSInputStream *is, int32_t signature, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    if (signature != OGModernUserPeerColorSignature)
    {
        OGModernUserConstructQuiet(is, signature, environment, error);
        return -1;
    }
    
    int32_t colorFlags = [is readInt32];
    int32_t colorId = (colorFlags & (1 << 0)) ? [is readInt32] : -1;
    if (colorFlags & (1 << 1))
        OGModernUserDiscardInt64(is);
    return colorId;
}

static void OGModernUserSkipVector(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error)
{
    if ([is readInt32] != OGModernUserVectorSignature)
        return;
    
    int32_t count = [is readInt32];
    while (count-- > 0)
    {
        int32_t elementSignature = [is readInt32];
        TLMetaClassStore::constructObject(is, elementSignature, environment, nil, error);
        if (error != nil && *error != nil)
            return;
    }
}

static bool OGModernUserFailed(__autoreleasing NSError **error)
{
    return error != nil && *error != nil;
}

static id<TLObject> OGModernUserReadBoxed(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error, int32_t *signatureOut)
{
    int32_t boxedSignature = [is readInt32];
    if (signatureOut != NULL)
        *signatureOut = boxedSignature;
    return TLMetaClassStore::constructObject(is, boxedSignature, environment, nil, error);
}

static bool OGModernUserReadColor(NSInputStream *is, id<TLSerializationEnvironment> environment, __autoreleasing NSError **error, int64_t userId, NSString *label, int32_t *colorId)
{
    int32_t colorSignature = [is readInt32];
    if (colorSignature == 0)
        return true;
    
    *colorId = OGModernUserPeerColorId(is, colorSignature, environment, error);
    if (OGModernUserFailed(error))
    {
        TGLog(@"AUTH modernUser id=%lld %@ failed sig=0x%x error=%@", (long long)userId, label, colorSignature, *error);
        return false;
    }
    return true;
}

@implementation TLUser$modernUser

- (void)TLserialize:(NSOutputStream *)__unused os
{
    TGLog(@"***** TLUser$modernUser serialization not supported");
}

- (id<TLObject>)TLdeserialize:(NSInputStream *)is signature:(int32_t)signature environment:(id<TLSerializationEnvironment>)environment context:(TLSerializationContext *)__unused context error:(__autoreleasing NSError **)error
{
    TLUser$modernUser *object = [[TLUser$modernUser alloc] init];
    object.nameColorId = -1;
    object.profileColorId = -1;
    
    object.flags = [is readInt32];
    const bool modernLayout = OGModernUserHasModernLayout(signature);
    int32_t flags2 = modernLayout ? [is readInt32] : 0;
    
    object.n_id = modernLayout ? [is readInt64] : [is readInt32];
    
    if (object.flags & (1 << 0))
        object.access_hash = [is readInt64];
    
    if (object.flags & (1 << 1))
        object.first_name = [is readString];
    if (object.flags & (1 << 2))
        object.last_name = [is readString];
    if (object.flags & (1 << 3))
        object.username = [is readString];
    if (object.flags & (1 << 4))
        object.phone = [is readString];
    
    if (object.flags & (1 << 5))
    {
        int32_t photoSignature = 0;
        object.photo = OGModernUserReadBoxed(is, environment, error, &photoSignature);
        if (OGModernUserFailed(error)) {
            TGLog(@"AUTH modernUser id=%lld photo failed sig=0x%x error=%@", (long long)object.n_id, photoSignature, *error);
            return nil;
        }
    }
    
    if (object.flags & (1 << 6))
    {
        int32_t statusSignature = 0;
        object.status = OGModernUserReadBoxed(is, environment, error, &statusSignature);
        if (OGModernUserFailed(error)) {
            TGLog(@"AUTH modernUser id=%lld status failed sig=0x%x error=%@", (long long)object.n_id, statusSignature, *error);
            return nil;
        }
    }
    
    if (object.flags & (1 << 14))
        object.bot_info_version = [is readInt32];
    
    if ((object.flags >> 18) & 1)
    {
        if (modernLayout)
        {
            OGModernUserSkipVector(is, environment, error);
            if (OGModernUserFailed(error))
                return nil;
        }
        else
            object.restriction_reason = [is readString];
    }
    
    if (object.flags & (1 << 19))
        object.inlineBotPlaceholder = [is readString];
    
    if (object.flags & (1 << 22))
        __unused NSString *langCode = [is readString];
    
    if (modernLayout && (object.flags & (1 << 30)))
    {
        int32_t emojiSignature = [is readInt32];
        object.emojiStatusDocumentId = TGModernUserParseEmojiStatus(is, emojiSignature, environment, error);
        if (OGModernUserFailed(error))
        {
            TGLog(@"AUTH modernUser id=%lld emoji_status failed sig=0x%x error=%@", (long long)object.n_id, emojiSignature, *error);
            return nil;
        }
    }
    
    if (modernLayout && (flags2 & (1 << 0)))
    {
        OGModernUserSkipVector(is, environment, error);
        if (OGModernUserFailed(error))
            return nil;
    }
    
    if (modernLayout && (flags2 & (1 << 5)))
    {
        switch ((uint32_t)signature)
        {
            case 0x2813e6db:
            case 0x1afeb7ac:
            case 0xd0a1d008:
            case 0x31774388:
            case 0xb1b8cc83:
            {
                int32_t storySignature = 0;
                OGModernUserReadBoxed(is, environment, error, &storySignature);
                if (OGModernUserFailed(error))
                {
                    TGLog(@"AUTH modernUser id=%lld recent_story failed sig=0x%x error=%@", (long long)object.n_id, storySignature, *error);
                    return nil;
                }
                break;
            }
            default:
                OGModernUserDiscardInt32(is);
                break;
        }
    }
    
    if (modernLayout && (flags2 & (1 << 8)))
    {
        int32_t nameColorId = object.nameColorId;
        if (!OGModernUserReadColor(is, environment, error, object.n_id, @"color", &nameColorId))
            return nil;
        object.nameColorId = nameColorId;
    }
    
    if (modernLayout && (flags2 & (1 << 9)))
    {
        int32_t profileColorId = object.profileColorId;
        if (!OGModernUserReadColor(is, environment, error, object.n_id, @"profile_color", &profileColorId))
            return nil;
        object.profileColorId = profileColorId;
    }
    
    if (modernLayout)
    {
        if (flags2 & (1 << 12))
            OGModernUserDiscardInt32(is);
        if (flags2 & (1 << 14))
            OGModernUserDiscardInt64(is);
        if (flags2 & (1 << 15))
            OGModernUserDiscardInt64(is);
        if ((flags2 & (1 << 21)) && signature == (int32_t)0xb1b8cc83)
            OGModernUserDiscardInt64(is);
    }
    
    return object;
}

@end
