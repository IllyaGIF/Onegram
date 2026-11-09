#import "OGHelperSerialization.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTBuffer.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTDatacenterAddress.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTDatacenterAddressListData.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTExportedAuthorizationData.h"

static const int32_t OGHelperSignatureVector = (int32_t)0x1cb5c415;

static const int32_t OGHelperSignatureUpdatesTooLong = (int32_t)0xe317af7e;
static const int32_t OGHelperSignatureUpdateShortMessage = (int32_t)0x313bc7f8;
static const int32_t OGHelperSignatureUpdateShortMessageLegacy = (int32_t)0x914fbf11;
static const int32_t OGHelperSignatureUpdateShortChatMessage = (int32_t)0x4d6deea5;
static const int32_t OGHelperSignatureUpdateShortChatMessageLegacy = (int32_t)0x16812688;
static const int32_t OGHelperSignatureUpdateShort = (int32_t)0x78d4dec1;
static const int32_t OGHelperSignatureUpdates = (int32_t)0x74ae4240;
static const int32_t OGHelperSignatureUpdatesCombined = (int32_t)0x725b04c3;

static const int32_t OGHelperSignatureUpdateNewMessage = (int32_t)0x1f2b0afd;
static const int32_t OGHelperSignatureUpdateNewChannelMessage = (int32_t)0x62ba04d9;
static const int32_t OGHelperSignatureUpdateNewEncryptedMessage = (int32_t)0x12bcbd9a;
static const int32_t OGHelperSignatureUpdatePhoneCall = (int32_t)0xab0f6b1e;

static const int32_t OGHelperSignatureMessageEmpty = (int32_t)0x90a6ca84;
static const int32_t OGHelperSignatureMessageEmptyLegacy = (int32_t)0x83e5de54;

static const int32_t OGHelperSignaturePhoneCallRequested = (int32_t)0x14b0ed0c;
static const int32_t OGHelperSignaturePhoneCallRequestedModern = (int32_t)0x45361c63;
static const int32_t OGHelperSignaturePhoneCallRequestedLegacy = (int32_t)0x9627ce57;

static const int32_t OGHelperSignatureUpdatesGetState = (int32_t)0xedd4882a;
static const int32_t OGHelperSignatureUpdatesState = (int32_t)0xa56c2a3e;
static const int32_t OGHelperSignatureHelpGetConfig = (int32_t)0xc4f9186b;
static const int32_t OGHelperSignatureHelpGetNearestDc = (int32_t)0x1fb33026;
static const int32_t OGHelperSignatureNearestDc = (int32_t)0x8e1a1775;
static const int32_t OGHelperSignatureDcOption = (int32_t)0x18b7a10d;
static const int32_t OGHelperSignatureAuthExportAuthorization = (int32_t)0xe5bfffcd;
static const int32_t OGHelperSignatureAuthExportedAuthorization = (int32_t)0xb434e2b8;
static const int32_t OGHelperSignatureAuthImportAuthorization = (int32_t)0xa57a7dad;
static const int32_t OGHelperSignaturePingDelayDisconnect = (int32_t)0xf3427b8c;

static const int32_t OGHelperMessageFlagOutgoing = 1 << 1;

static const int32_t OGHelperDcOptionFlagMediaOnly = 1 << 1;
static const int32_t OGHelperDcOptionFlagTcpOnly = 1 << 2;
static const int32_t OGHelperDcOptionFlagCdn = 1 << 3;
static const int32_t OGHelperDcOptionFlagStatic = 1 << 4;
static const int32_t OGHelperDcOptionFlagSecret = 1 << 10;

static const NSUInteger OGHelperConfigHeaderLength = 6 * sizeof(int32_t);

typedef struct
{
    const uint8_t *bytes;
    NSUInteger length;
    NSUInteger offset;
} OGHelperTLReader;

static OGHelperTLReader OGHelperTLReaderMake(NSData *data)
{
    OGHelperTLReader reader = { (const uint8_t *)data.bytes, data.length, 0 };
    return reader;
}

static bool OGHelperTLSkip(OGHelperTLReader *reader, NSUInteger length)
{
    if (reader->length - reader->offset < length)
        return false;
    reader->offset += length;
    return true;
}

static bool OGHelperTLReadInt32(OGHelperTLReader *reader, int32_t *value)
{
    if (reader->length - reader->offset < sizeof(int32_t))
        return false;
    memcpy(value, reader->bytes + reader->offset, sizeof(int32_t));
    reader->offset += sizeof(int32_t);
    return true;
}

static bool OGHelperTLReadInt64(OGHelperTLReader *reader, int64_t *value)
{
    if (reader->length - reader->offset < sizeof(int64_t))
        return false;
    memcpy(value, reader->bytes + reader->offset, sizeof(int64_t));
    reader->offset += sizeof(int64_t);
    return true;
}

static bool OGHelperTLReadBytes(OGHelperTLReader *reader, NSData **value)
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

static bool OGHelperTLReadString(OGHelperTLReader *reader, NSString **value)
{
    NSData *data = nil;
    if (!OGHelperTLReadBytes(reader, &data))
        return false;
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string == nil)
        return false;
    *value = string;
    return true;
}

static bool OGHelperTLExpectSignature(OGHelperTLReader *reader, int32_t expectedSignature)
{
    int32_t signature = 0;
    return OGHelperTLReadInt32(reader, &signature) && signature == expectedSignature;
}

static bool OGHelperFlagsAreIncoming(OGHelperTLReader *reader)
{
    int32_t flags = 0;
    return OGHelperTLReadInt32(reader, &flags) && (flags & OGHelperMessageFlagOutgoing) == 0;
}

static bool OGHelperMessageIsIncoming(OGHelperTLReader *reader)
{
    int32_t signature = 0;
    if (!OGHelperTLReadInt32(reader, &signature) || signature == OGHelperSignatureMessageEmpty || signature == OGHelperSignatureMessageEmptyLegacy)
        return false;
    return OGHelperFlagsAreIncoming(reader);
}

static bool OGHelperPhoneCallIsRequested(OGHelperTLReader *reader)
{
    int32_t signature = 0;
    if (!OGHelperTLReadInt32(reader, &signature))
        return false;
    return signature == OGHelperSignaturePhoneCallRequested || signature == OGHelperSignaturePhoneCallRequestedModern || signature == OGHelperSignaturePhoneCallRequestedLegacy;
}

static bool OGHelperUpdateRequiresApplication(OGHelperTLReader *reader)
{
    int32_t signature = 0;
    if (!OGHelperTLReadInt32(reader, &signature))
        return false;
    if (signature == OGHelperSignatureUpdateNewMessage || signature == OGHelperSignatureUpdateNewChannelMessage)
        return OGHelperMessageIsIncoming(reader);
    if (signature == OGHelperSignatureUpdateNewEncryptedMessage)
        return true;
    if (signature == OGHelperSignatureUpdatePhoneCall)
        return OGHelperPhoneCallIsRequested(reader);
    return false;
}

static bool OGHelperUpdateVectorRequiresApplication(OGHelperTLReader *reader)
{
    int32_t count = 0;
    if (!OGHelperTLExpectSignature(reader, OGHelperSignatureVector) || !OGHelperTLReadInt32(reader, &count) || count <= 0)
        return false;
    return OGHelperUpdateRequiresApplication(reader);
}

static bool OGHelperUpdatesRequireApplication(int32_t signature, OGHelperTLReader *reader)
{
    if (signature == OGHelperSignatureUpdateShortMessage || signature == OGHelperSignatureUpdateShortMessageLegacy || signature == OGHelperSignatureUpdateShortChatMessage || signature == OGHelperSignatureUpdateShortChatMessageLegacy)
        return OGHelperFlagsAreIncoming(reader);
    if (signature == OGHelperSignatureUpdateShort)
        return OGHelperUpdateRequiresApplication(reader);
    if (signature == OGHelperSignatureUpdates || signature == OGHelperSignatureUpdatesCombined)
        return OGHelperUpdateVectorRequiresApplication(reader);
    return false;
}

static uint64_t OGHelperDigest(NSData *data)
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

static NSData *OGHelperRequestPayload(int32_t signature)
{
    MTBuffer *buffer = [[MTBuffer alloc] init];
    [buffer appendInt32:signature];
    return buffer.data;
}

@interface OGHelperIncomingObject ()

- (instancetype)initWithSignature:(int32_t)signature requiresApplication:(bool)requiresApplication requiresStateCheck:(bool)requiresStateCheck digest:(uint64_t)digest;

@end

@implementation OGHelperIncomingObject

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

@implementation OGHelperSerialization
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
    OGHelperTLReader reader = OGHelperTLReaderMake(data);
    int32_t signature = 0;
    if (!OGHelperTLReadInt32(&reader, &signature))
        return nil;
    bool requiresStateCheck = signature == OGHelperSignatureUpdatesTooLong;
    bool requiresApplication = !requiresStateCheck && OGHelperUpdatesRequireApplication(signature, &reader);
    return [[OGHelperIncomingObject alloc] initWithSignature:signature requiresApplication:requiresApplication requiresStateCheck:requiresStateCheck digest:OGHelperDigest(data)];
}

- (MTExportAuthorizationResponseParser)exportAuthorization:(int32_t)datacenterId data:(__autoreleasing NSData **)data
{
    MTBuffer *buffer = [[MTBuffer alloc] init];
    [buffer appendInt32:OGHelperSignatureAuthExportAuthorization];
    [buffer appendInt32:datacenterId];
    if (data != NULL)
        *data = buffer.data;

    return ^MTExportedAuthorizationData *(NSData *response)
    {
        OGHelperTLReader reader = OGHelperTLReaderMake(response);
        int64_t authorizationId = 0;
        NSData *authorizationBytes = nil;
        if (!OGHelperTLExpectSignature(&reader, OGHelperSignatureAuthExportedAuthorization) || !OGHelperTLReadInt64(&reader, &authorizationId) || !OGHelperTLReadBytes(&reader, &authorizationBytes))
            return nil;
        return [[MTExportedAuthorizationData alloc] initWithAuthorizationBytes:authorizationBytes authorizationId:authorizationId];
    };
}

- (NSData *)importAuthorization:(int64_t)authId bytes:(NSData *)bytes
{
    MTBuffer *buffer = [[MTBuffer alloc] init];
    [buffer appendInt32:OGHelperSignatureAuthImportAuthorization];
    [buffer appendInt64:authId];
    [buffer appendTLBytes:bytes];
    return buffer.data;
}

- (MTRequestNoopParser)requestNoop:(__autoreleasing NSData **)data
{
    if (data != NULL)
        *data = OGHelperRequestPayload(OGHelperSignatureHelpGetNearestDc);

    return ^id(NSData *response)
    {
        OGHelperTLReader reader = OGHelperTLReaderMake(response);
        return @(OGHelperTLExpectSignature(&reader, OGHelperSignatureNearestDc));
    };
}

- (MTRequestDatacenterAddressListParser)requestDatacenterAddressWithData:(__autoreleasing NSData **)data
{
    if (data != NULL)
        *data = OGHelperRequestPayload(OGHelperSignatureHelpGetConfig);

    return ^MTDatacenterAddressListData *(NSData *response)
    {
        OGHelperTLReader reader = OGHelperTLReaderMake(response);
        int32_t count = 0;
        if (!OGHelperTLSkip(&reader, OGHelperConfigHeaderLength) || !OGHelperTLExpectSignature(&reader, OGHelperSignatureVector) || !OGHelperTLReadInt32(&reader, &count) || count < 0)
            return nil;

        NSMutableDictionary *addressList = [[NSMutableDictionary alloc] init];
        for (int32_t index = 0; index < count; index++)
        {
            int32_t flags = 0;
            int32_t datacenterId = 0;
            int32_t port = 0;
            NSString *ip = nil;
            NSData *secret = nil;
            if (!OGHelperTLExpectSignature(&reader, OGHelperSignatureDcOption) || !OGHelperTLReadInt32(&reader, &flags) || !OGHelperTLReadInt32(&reader, &datacenterId) || !OGHelperTLReadString(&reader, &ip) || !OGHelperTLReadInt32(&reader, &port))
                return nil;
            if ((flags & OGHelperDcOptionFlagSecret) != 0 && !OGHelperTLReadBytes(&reader, &secret))
                return nil;

            NSMutableArray *addresses = addressList[@(datacenterId)];
            if (addresses == nil)
            {
                addresses = [[NSMutableArray alloc] init];
                addressList[@(datacenterId)] = addresses;
            }
            [addresses addObject:[[MTDatacenterAddress alloc] initWithIp:ip port:(uint16_t)port preferForMedia:(flags & OGHelperDcOptionFlagMediaOnly) != 0 restrictToTcp:(flags & OGHelperDcOptionFlagTcpOnly) != 0 cdn:(flags & OGHelperDcOptionFlagCdn) != 0 preferForProxy:(flags & OGHelperDcOptionFlagStatic) != 0 secret:secret]];
        }

        return [[MTDatacenterAddressListData alloc] initWithAddressList:addressList];
    };
}

+ (NSData *)pingDelayDisconnectPayloadWithPingId:(int64_t)pingId disconnectDelay:(int32_t)disconnectDelay
{
    MTBuffer *buffer = [[MTBuffer alloc] init];
    [buffer appendInt32:OGHelperSignaturePingDelayDisconnect];
    [buffer appendInt64:pingId];
    [buffer appendInt32:disconnectDelay];
    return buffer.data;
}

- (OGHelperUpdatesStateParser)requestUpdatesState:(__autoreleasing NSData **)data
{
    if (data != NULL)
        *data = OGHelperRequestPayload(OGHelperSignatureUpdatesGetState);

    return ^id(NSData *response)
    {
        OGHelperTLReader reader = OGHelperTLReaderMake(response);
        int32_t pts = 0;
        int32_t qts = 0;
        int32_t date = 0;
        int32_t seq = 0;
        int32_t unreadCount = 0;
        if (!OGHelperTLExpectSignature(&reader, OGHelperSignatureUpdatesState) || !OGHelperTLReadInt32(&reader, &pts) || !OGHelperTLReadInt32(&reader, &qts) || !OGHelperTLReadInt32(&reader, &date) || !OGHelperTLReadInt32(&reader, &seq) || !OGHelperTLReadInt32(&reader, &unreadCount))
            return nil;
        return @{@"pts": @(pts), @"qts": @(qts), @"date": @(date), @"seq": @(seq), @"unreadCount": @(unreadCount)};
    };
}

@end
