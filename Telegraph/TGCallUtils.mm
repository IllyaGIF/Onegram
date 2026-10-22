#import "TGCallUtils.h"
#import "Reachability.h"

#import "../OnegramPlatform/OGPlatformTelephony.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTEncryption.h"
#import "../submodules/MtProtoKit/MTAes.h"

void TGCallAesIgeEncryptInplace(uint8_t *inBytes, uint8_t *outBytes, size_t length, uint8_t *key, uint8_t *iv)
{
    MyAesIgeEncrypt(inBytes, (int)length, outBytes, key, 32, iv);
}

void TGCallAesIgeDecryptInplace(uint8_t *inBytes, uint8_t *outBytes, size_t length, uint8_t *key, uint8_t *iv)
{
    MyAesIgeDecrypt(inBytes, (int)length, outBytes, key, 32, iv);
}

void TGCallAesCtrEncrypt(uint8_t *inOut, size_t length, uint8_t *key, uint8_t *iv, uint8_t *ecount, uint32_t *num)
{
    MTAesCtr *aesCtr = [[MTAesCtr alloc] initWithKey:key keyLength:32 iv:iv ecount:ecount num:*num];
    [aesCtr encryptIn:inOut out:inOut len:length];
    [aesCtr getIv:iv];
    memcpy(ecount, [aesCtr ecount], 16);
    *num = [aesCtr num];
}

void TGCallSha1(uint8_t *msg, size_t length, uint8_t *output)
{
    CC_SHA1(msg, (CC_LONG)length, output);
}

void TGCallSha256(uint8_t *msg, size_t length, uint8_t *output)
{
    CC_SHA256(msg, (CC_LONG)length, output);
}

void TGCallRandomBytes(uint8_t *buffer, size_t length)
{
    arc4random_buf(buffer, length);
}

void TGCallLoggingFunction(const char *msg)
{
}

@implementation TGCallUtils

+ (bool)canCheckPhoneCallState
{
    return iosMajorVersion() < 10;
}

+ (bool)isOnPhoneCall
{
    if (![self canCheckPhoneCallState])
        return false;

    return OGPlatformIsOnPhoneCall();
}

@end
