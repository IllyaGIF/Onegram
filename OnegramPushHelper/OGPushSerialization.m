#import "OGPushSerialization.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTBuffer.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTDatacenterAddress.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTDatacenterAddressListData.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTExportedAuthorizationData.h"

static const int32_t OGPushSignatureVector = (int32_t)0x1cb5c415;

static const int32_t OGPushSignatureUpdatesTooLong = (int32_t)0xe317af7e;
static const int32_t OGPushSignatureUpdateShortMessage = (int32_t)0x313bc7f8;
static const int32_t OGPushSignatureUpdateShortMessageLegacy = (int32_t)0x914fbf11;
static const int32_t OGPushSignatureUpdateShortChatMessage = (int32_t)0x4d6deea5;
static const int32_t OGPushSignatureUpdateShortChatMessageLegacy = (int32_t)0x16812688;
static const int32_t OGPushSignatureUpdateShort = (int32_t)0x78d4dec1;
static const int32_t OGPushSignatureUpdates = (int32_t)0x74ae4240;
static const int32_t OGPushSignatureUpdatesCombined = (int32_t)0x725b04c3;

static const int32_t OGPushSignatureUpdateNewMessage = (int32_t)0x1f2b0afd;
static const int32_t OGPushSignatureUpdateNewChannelMessage = (int32_t)0x62ba04d9;
static const int32_t OGPushSignatureUpdateNewEncryptedMessage = (int32_t)0x12bcbd9a;
static const int32_t OGPushSignatureUpdatePhoneCall = (int32_t)0xab0f6b1e;

static const int32_t OGPushSignatureMessageEmpty = (int32_t)0x90a6ca84;
static const int32_t OGPushSignatureMessageEmptyLegacy = (int32_t)0x83e5de54;

static const int32_t OGPushSignaturePhoneCallRequested = (int32_t)0x14b0ed0c;
static const int32_t OGPushSignaturePhoneCallRequestedModern = (int32_t)0x45361c63;
static const int32_t OGPushSignaturePhoneCallRequestedLegacy = (int32_t)0x9627ce57;

static const int32_t OGPushSignatureUpdatesGetState = (int32_t)0xedd4882a;
static const int32_t OGPushSignatureUpdatesState = (int32_t)0xa56c2a3e;
static const int32_t OGPushSignatureHelpGetConfig = (int32_t)0xc4f9186b;
static const int32_t OGPushSignatureHelpGetNearestDc = (int32_t)0x1fb33026;
static const int32_t OGPushSignatureNearestDc = (int32_t)0x8e1a1775;
static const int32_t OGPushSignatureDcOption = (int32_t)0x18b7a10d;
static const int32_t OGPushSignatureAuthExportAuthorization = (int32_t)0xe5bfffcd;
static const int32_t OGPushSignatureAuthExportedAuthorization = (int32_t)0xb434e2b8;
static const int32_t OGPushSignatureAuthImportAuthorization = (int32_t)0xa57a7dad;
static const int32_t OGPushSignaturePingDelayDisconnect = (int32_t)0xf3427b8c;

static const int32_t OGPushMessageFlagOutgoing = 1 << 1;

static const int32_t OGPushDcOptionFlagMediaOnly = 1 << 1;
static const int32_t OGPushDcOptionFlagTcpOnly = 1 << 2;
static const int32_t OGPushDcOptionFlagCdn = 1 << 3;
static const int32_t OGPushDcOptionFlagStatic = 1 << 4;
static const int32_t OGPushDcOptionFlagSecret = 1 << 10;

static const NSUInteger OGPushConfigHeaderLength = 6 * sizeof(int32_t);

typedef struct
{
    const uint8_t *bytes;
    NSUInteger length;
    NSUInteger offset;
} OGPushTLReader;

static OGPushTLReader OGPushTLReaderMake(NSData *data)
{
    OGPushTLReader reader = { (const uint8_t *)data.bytes, data.length, 0 };
    return reader;
}

static bool OGPushTLSkip(OGPushTLReader *reader, NSUInteger length)
{
    if (reader->length - reader->offset < length)
        return false;
    reader->offset += length;
    return true;
}

static bool OGPushTLReadInt32(OGPushTLReader *reader, int32_t *value)
{
    if (reader->length - reader->offset < sizeof(int32_t))
        return false;
    memcpy(value, reader->bytes + reader->offset, sizeof(int32_t));
    reader->offset += sizeof(int32_t);
    return true;
}

static bool OGPushTLReadInt64(OGPushTLReader *reader, int64_t *value)
{
    if (reader->length - reader->offset < sizeof(int64_t))
        return false;
    memcpy(value, reader->bytes + reader->offset, sizeof(int64_t));
    reader->offset += sizeof(int64_t);
    return true;
}

static bool OGPushTLReadBytes(OGPushTLReader *reader, NSData **value)
{
    if (reader->offset >= reader->length)
        return false;

    const uint8_t *header = reader->bytes + reader->offset;
    NSUInteger headerLength = 1;
    NSUInteger dataLength = header[0];
    if (dataLength == 254)
    {
        if (reader->length - reader->offset < 4)
            return false;
        dataLength = (NSUInteger)header[1] | ((NSUInteger)header[2] << 8) | ((NSUInteger)header[3] << 16);
        headerLength = 4;
    }

    NSUInteger paddedLength = (headerLength + dataLength + 3) & ~(NSUInteger)3;
    if (reader->length - reader->offset < paddedLength)
        return false;

    if (value != NULL)
        *value = [[NSData alloc] initWithBytes:header + headerLength length:dataLength];
    reader->offset += paddedLength;
    return true;
}

static bool OGPushTLReadString(OGPushTLReader *reader, NSString **value)
{
    NSData *data = nil;
    if (!OGPushTLReadBytes(reader, &data))
        return false;
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string == nil)
        return false;
    *value = string;
    return true;
}

static bool OGPushTLExpectSignature(OGPushTLReader *reader, int32_t expectedSignature)
{
    int32_t signature = 0;
    return OGPushTLReadInt32(reader, &signature) && signature == expectedSignature;
}

static bool OGPushFlagsAreIncoming(OGPushTLReader *reader)
{
    int32_t flags = 0;
    return OGPushTLReadInt32(reader, &flags) && (flags & OGPushMessageFlagOutgoing) == 0;
}

static bool OGPushMessageIsIncoming(OGPushTLReader *reader)
{
    int32_t signature = 0;
    if (!OGPushTLReadInt32(reader, &signature) || signature == OGPushSignatureMessageEmpty || signature == OGPushSignatureMessageEmptyLegacy)
        return false;
    return OGPushFlagsAreIncoming(reader);
}

static bool OGPushPhoneCallIsRequested(OGPushTLReader *reader)
{
    int32_t signature = 0;
    if (!OGPushTLReadInt32(reader, &signature))
        return false;
    return signature == OGPushSignaturePhoneCallRequested || signature == OGPushSignaturePhoneCallRequestedModern || signature == OGPushSignaturePhoneCallRequestedLegacy;
}

static bool OGPushUpdateRequiresApplication(OGPushTLReader *reader)
{
    int32_t signature = 0;
    if (!OGPushTLReadInt32(reader, &signature))
        return false;
    if (signature == OGPushSignatureUpdateNewMessage || signature == OGPushSignatureUpdateNewChannelMessage)
        return OGPushMessageIsIncoming(reader);
    if (signature == OGPushSignatureUpdateNewEncryptedMessage)
        return true;
    if (signature == OGPushSignatureUpdatePhoneCall)
        return OGPushPhoneCallIsRequested(reader);
    return false;
}

static bool OGPushUpdateVectorRequiresApplication(OGPushTLReader *reader)
{
    int32_t count = 0;
    if (!OGPushTLExpectSignature(reader, OGPushSignatureVector) || !OGPushTLReadInt32(reader, &count) || count <= 0)
        return false;
    return OGPushUpdateRequiresApplication(reader);
}

static bool OGPushUpdatesRequireApplication(int32_t signature, OGPushTLReader *reader)
{
    if (signature == OGPushSignatureUpdateShortMessage || signature == OGPushSignatureUpdateShortMessageLegacy || signature == OGPushSignatureUpdateShortChatMessage || signature == OGPushSignatureUpdateShortChatMessageLegacy)
        return OGPushFlagsAreIncoming(reader);
    if (signature == OGPushSignatureUpdateShort)
        return OGPushUpdateRequiresApplication(reader);
    if (signature == OGPushSignatureUpdates || signature == OGPushSignatureUpdatesCombined)
        return OGPushUpdateVectorRequiresApplication(reader);
    return false;
}

static uint64_t OGPushDigest(NSData *data)
{
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger length = data.length;
    uint64_t hash = 0xcbf29ce484222325ULL;
    for (NSUInteger index = 0; index < length; index++)
    {
        hash ^= bytes[index];
        hash *= 0x100000001b3ULL;
    }
    return hash;
}

static NSData *OGPushRequestPayload(int32_t signature)
{
    MTBuffer *buffer = [[MTBuffer alloc] init];
    [buffer appendInt32:signature];
    return buffer.data;
}

@interface OGPushIncomingObject ()

- (instancetype)initWithSignature:(int32_t)signature requiresApplication:(bool)requiresApplication requiresStateCheck:(bool)requiresStateCheck digest:(uint64_t)digest;

@end

@implementation OGPushIncomingObject

- (instancetype)initWithSignature:(int32_t)signature requiresApplication:(bool)requiresApplication requiresStateCheck:(bool)requiresStateCheck digest:(uint64_t)digest
{
    self = [super init];
    if (self != nil)
    {
        _signature = signature;
        _requiresApplication = requiresApplication;
        _requiresStateCheck = requiresStateCheck;
        _digest = digest;
    }
    return self;
}

@end

@implementation OGPushSerialization
{
    NSUInteger _layer;
}

- (instancetype)initWithLayer:(NSUInteger)layer
{
    self = [super init];
    if (self != nil)
        _layer = layer;
    return self;
}

- (NSUInteger)currentLayer
{
    return _layer;
}

- (id)parseMessage:(NSData *)data
{
    OGPushTLReader reader = OGPushTLReaderMake(data);
    int32_t signature = 0;
    if (!OGPushTLReadInt32(&reader, &signature))
        return nil;
    bool requiresStateCheck = signature == OGPushSignatureUpdatesTooLong;
    bool requiresApplication = !requiresStateCheck && OGPushUpdatesRequireApplication(signature, &reader);
    return [[OGPushIncomingObject alloc] initWithSignature:signature requiresApplication:requiresApplication requiresStateCheck:requiresStateCheck digest:OGPushDigest(data)];
}

- (MTExportAuthorizationResponseParser)exportAuthorization:(int32_t)datacenterId data:(__autoreleasing NSData **)data
{
    MTBuffer *buffer = [[MTBuffer alloc] init];
    [buffer appendInt32:OGPushSignatureAuthExportAuthorization];
    [buffer appendInt32:datacenterId];
    if (data != NULL)
        *data = buffer.data;

    return ^MTExportedAuthorizationData *(NSData *response)
    {
        OGPushTLReader reader = OGPushTLReaderMake(response);
        int64_t authorizationId = 0;
        NSData *authorizationBytes = nil;
        if (!OGPushTLExpectSignature(&reader, OGPushSignatureAuthExportedAuthorization) || !OGPushTLReadInt64(&reader, &authorizationId) || !OGPushTLReadBytes(&reader, &authorizationBytes))
            return nil;
        return [[MTExportedAuthorizationData alloc] initWithAuthorizationBytes:authorizationBytes authorizationId:authorizationId];
    };
}

- (NSData *)importAuthorization:(int64_t)authId bytes:(NSData *)bytes
{
    MTBuffer *buffer = [[MTBuffer alloc] init];
    [buffer appendInt32:OGPushSignatureAuthImportAuthorization];
    [buffer appendInt64:authId];
    [buffer appendTLBytes:bytes];
    return buffer.data;
}

- (MTRequestNoopParser)requestNoop:(__autoreleasing NSData **)data
{
    if (data != NULL)
        *data = OGPushRequestPayload(OGPushSignatureHelpGetNearestDc);

    return ^id(NSData *response)
    {
        OGPushTLReader reader = OGPushTLReaderMake(response);
        return @(OGPushTLExpectSignature(&reader, OGPushSignatureNearestDc));
    };
}

- (MTRequestDatacenterAddressListParser)requestDatacenterAddressWithData:(__autoreleasing NSData **)data
{
    if (data != NULL)
        *data = OGPushRequestPayload(OGPushSignatureHelpGetConfig);

    return ^MTDatacenterAddressListData *(NSData *response)
    {
        OGPushTLReader reader = OGPushTLReaderMake(response);
        int32_t count = 0;
        if (!OGPushTLSkip(&reader, OGPushConfigHeaderLength) || !OGPushTLExpectSignature(&reader, OGPushSignatureVector) || !OGPushTLReadInt32(&reader, &count) || count < 0)
            return nil;

        NSMutableDictionary *addressList = [[NSMutableDictionary alloc] init];
        for (int32_t index = 0; index < count; index++)
        {
            int32_t flags = 0;
            int32_t datacenterId = 0;
            int32_t port = 0;
            NSString *ip = nil;
            NSData *secret = nil;
            if (!OGPushTLExpectSignature(&reader, OGPushSignatureDcOption) || !OGPushTLReadInt32(&reader, &flags) || !OGPushTLReadInt32(&reader, &datacenterId) || !OGPushTLReadString(&reader, &ip) || !OGPushTLReadInt32(&reader, &port))
                return nil;
            if ((flags & OGPushDcOptionFlagSecret) != 0 && !OGPushTLReadBytes(&reader, &secret))
                return nil;

            NSMutableArray *addresses = addressList[@(datacenterId)];
            if (addresses == nil)
            {
                addresses = [[NSMutableArray alloc] init];
                addressList[@(datacenterId)] = addresses;
            }
            [addresses addObject:[[MTDatacenterAddress alloc] initWithIp:ip port:(uint16_t)port preferForMedia:(flags & OGPushDcOptionFlagMediaOnly) != 0 restrictToTcp:(flags & OGPushDcOptionFlagTcpOnly) != 0 cdn:(flags & OGPushDcOptionFlagCdn) != 0 preferForProxy:(flags & OGPushDcOptionFlagStatic) != 0 secret:secret]];
        }

        return [[MTDatacenterAddressListData alloc] initWithAddressList:addressList];
    };
}

+ (NSData *)pingDelayDisconnectPayloadWithPingId:(int64_t)pingId disconnectDelay:(int32_t)disconnectDelay
{
    MTBuffer *buffer = [[MTBuffer alloc] init];
    [buffer appendInt32:OGPushSignaturePingDelayDisconnect];
    [buffer appendInt64:pingId];
    [buffer appendInt32:disconnectDelay];
    return buffer.data;
}

- (OGPushUpdatesStateParser)requestUpdatesState:(__autoreleasing NSData **)data
{
    if (data != NULL)
        *data = OGPushRequestPayload(OGPushSignatureUpdatesGetState);

    return ^id(NSData *response)
    {
        OGPushTLReader reader = OGPushTLReaderMake(response);
        int32_t pts = 0;
        int32_t qts = 0;
        int32_t date = 0;
        int32_t seq = 0;
        int32_t unreadCount = 0;
        if (!OGPushTLExpectSignature(&reader, OGPushSignatureUpdatesState) || !OGPushTLReadInt32(&reader, &pts) || !OGPushTLReadInt32(&reader, &qts) || !OGPushTLReadInt32(&reader, &date) || !OGPushTLReadInt32(&reader, &seq) || !OGPushTLReadInt32(&reader, &unreadCount))
            return nil;
        return @{@"pts": @(pts), @"qts": @(qts), @"date": @(date), @"seq": @(seq), @"unreadCount": @(unreadCount)};
    };
}

@end
