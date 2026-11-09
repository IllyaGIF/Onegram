#include "VLESSReality.h"
#include "VLESSSHA256.h"
#include "VLESSMLKEM.h"
#include "monocypher.h"
#include "OGCoreSocket.h"
#include <openssl/rand.h>

#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/crypto.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <errno.h>
#include <sys/time.h>
#include <sys/select.h>

static const uint8_t VL_REALITY_VER[4] = { 26, 9, 9, 0 };

#define VL_MAX_RECORD  18432
#define VL_MAX_PLAIN   16384

static long VLNow(void) { return (long)time(NULL); }

static int VLReadFull(int fd, uint8_t *buf, size_t n, long deadline) {
    size_t have = 0;
    while (have < n) {
        long left = deadline - VLNow();
        if (left <= 0) return -1;
        fd_set r; FD_ZERO(&r); FD_SET(fd, &r);
        struct timeval tv = { left, 0 };
        int rc = select(fd + 1, &r, NULL, NULL, &tv);
        if (rc < 0) { if (errno == EINTR) continue; return -1; }
        if (rc == 0) return -1;
        ssize_t got = read(fd, buf + have, n - have);
        if (got < 0) { if (errno == EINTR) continue; return -1; }
        if (got == 0) return -1;
        have += (size_t)got;
    }
    return 0;
}

static int VLWriteFull(int fd, const uint8_t *buf, size_t n, long deadline) {
    size_t sent = 0;
    while (sent < n) {
        long left = deadline - VLNow();
        if (left <= 0) return -1;
        fd_set w; FD_ZERO(&w); FD_SET(fd, &w);
        struct timeval tv = { left, 0 };
        int rc = select(fd + 1, NULL, &w, NULL, &tv);
        if (rc < 0) { if (errno == EINTR) continue; return -1; }
        if (rc == 0) return -1;
        ssize_t put = OGCoreSocketSend(fd, buf + sent, n - sent);
        if (put < 0) { if (errno == EINTR) continue; return -1; }
        if (put == 0) return -1;
        sent += (size_t)put;
    }
    return 0;
}

volatile int gVLRealityTrace = 0;

static void VLTrace(const char *stage, long value) {
    if (!gVLRealityTrace) return;
    fprintf(stderr, "[reality] %s %ld\n", stage, value);
    fflush(stderr);
}

typedef struct {
    uint8_t *data;
    size_t len;
    size_t cap;
    int failed;
} VLBuf;

static void VLBufPut(VLBuf *b, const void *bytes, size_t n) {
    if (b->failed) return;
    if (n > 131072 - b->len) { b->failed = 1; return; }
    if (b->len + n > b->cap) {
        size_t cap = b->cap ? b->cap * 2 : 512;
        while (cap < b->len + n) cap *= 2;
        uint8_t *p = (uint8_t *)realloc(b->data, cap);
        if (!p) { b->failed = 1; return; }
        b->data = p;
        b->cap = cap;
    }
    memcpy(b->data + b->len, bytes, n);
    b->len += n;
}

static void VLBufU8(VLBuf *b, uint8_t v) { VLBufPut(b, &v, 1); }
static void VLBufU16(VLBuf *b, uint16_t v) {
    uint8_t t[2] = { (uint8_t)(v >> 8), (uint8_t)v };
    VLBufPut(b, t, 2);
}
static void VLBufU24(VLBuf *b, uint32_t v) {
    uint8_t t[3] = { (uint8_t)(v >> 16), (uint8_t)(v >> 8), (uint8_t)v };
    VLBufPut(b, t, 3);
}
static void VLBufFree(VLBuf *b) { free(b->data); b->data = NULL; b->len = b->cap = 0; }

static void VLRecordNonce(const uint8_t iv[12], uint64_t seq, uint8_t nonce[12]) {
    memcpy(nonce, iv, 12);
    for (int i = 0; i < 8; i++) nonce[11 - i] ^= (uint8_t)(seq >> (8 * i));
}

static const EVP_CIPHER *VLCipher(int cipher) {
    switch (cipher) {
        case 1: return EVP_aes_128_gcm();
        case 2: return EVP_aes_256_gcm();
        default: return NULL;
    }
}

static size_t VLKeyLength(int cipher) { return cipher == 1 ? 16 : 32; }

static int VLSeal(int cipher, const uint8_t key[32], const uint8_t iv[12],
                  uint64_t seq, const uint8_t aad[5],
                  const uint8_t *payload, size_t payloadLen,
                  uint8_t *out, size_t outCap, size_t *outLen) {
    if (outCap < payloadLen + 16) return -1;
    uint8_t nonce[12];
    VLRecordNonce(iv, seq, nonce);
    if (cipher == 3) {
        crypto_aead_ctx context;
        crypto_aead_init_ietf(&context, key, nonce);
        crypto_aead_write(&context, out, out + payloadLen, aad, 5, payload, payloadLen);
        crypto_wipe(&context, sizeof(context));
        *outLen = payloadLen + 16;
        return 0;
    }
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) return -1;
    int len = 0, ok = 1;
    ok = EVP_EncryptInit_ex(ctx, VLCipher(cipher), NULL, NULL, NULL) == 1;
    if (ok) ok = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, 12, NULL) == 1;
    if (ok) ok = EVP_EncryptInit_ex(ctx, NULL, NULL, key, nonce) == 1;
    if (ok) ok = EVP_EncryptUpdate(ctx, NULL, &len, aad, 5) == 1;
    if (ok && payloadLen) ok = EVP_EncryptUpdate(ctx, out, &len, payload, (int)payloadLen) == 1;
    if (ok) ok = EVP_EncryptFinal_ex(ctx, out, &len) == 1;
    if (ok) ok = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, out + payloadLen) == 1;
    EVP_CIPHER_CTX_free(ctx);
    if (!ok) return -1;
    *outLen = payloadLen + 16;
    return 0;
}

static int VLOpen(int cipher, const uint8_t key[32], const uint8_t iv[12],
                  uint64_t seq, const uint8_t aad[5],
                  const uint8_t *input, size_t inputLen,
                  uint8_t *out, size_t outCap, size_t *outLen) {
    if (inputLen < 16 || outCap < inputLen - 16) return -1;
    uint8_t nonce[12];
    VLRecordNonce(iv, seq, nonce);
    if (cipher == 3) {
        crypto_aead_ctx context;
        crypto_aead_init_ietf(&context, key, nonce);
        int result = crypto_aead_read(&context, out, input + inputLen - 16, aad, 5, input, inputLen - 16);
        crypto_wipe(&context, sizeof(context));
        if (result != 0) return -1;
        *outLen = inputLen - 16;
        return 0;
    }
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) return -1;
    int len = 0, ok = 1;
    ok = EVP_DecryptInit_ex(ctx, VLCipher(cipher), NULL, NULL, NULL) == 1;
    if (ok) ok = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, 12, NULL) == 1;
    if (ok) ok = EVP_DecryptInit_ex(ctx, NULL, NULL, key, nonce) == 1;
    if (ok) ok = EVP_DecryptUpdate(ctx, NULL, &len, aad, 5) == 1;
    if (ok) ok = EVP_DecryptUpdate(ctx, out, &len, input, (int)(inputLen - 16)) == 1;
    if (ok) ok = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16,
                                     (void *)(input + inputLen - 16)) == 1;
    if (ok) ok = EVP_DecryptFinal_ex(ctx, out, &len) == 1;
    EVP_CIPHER_CTX_free(ctx);
    if (!ok) return -1;
    *outLen = inputLen - 16;
    return 0;
}

static int VLOpenBuf(int cipher, const uint8_t key[32], const uint8_t iv[12],
                     uint64_t seq, uint8_t header[5],
                     const uint8_t *input, size_t inputLen,
                     uint8_t *out, size_t outCap, size_t *outLen,
                     uint8_t *innerType) {
    if (VLOpen(cipher, key, iv, seq, header, input, inputLen, out, outCap, outLen) != 0) {
        return -1;
    }
    size_t n = *outLen;
    while (n > 0 && out[n - 1] == 0) n--;
    if (n == 0) return -1;
    if (innerType) *innerType = out[n - 1];
    *outLen = n - 1;
    return 0;
}

typedef struct { const uint8_t *d; size_t len; size_t pos; } VLCursor;

static int VLTLV(VLCursor *c, uint8_t tag, size_t *bodyLen, size_t *bodyAt) {
    if (c->pos >= c->len || c->d[c->pos] != tag) return -1;
    c->pos++;
    if (c->pos >= c->len) return -1;
    uint8_t fb = c->d[c->pos++];
    size_t n;
    if ((fb & 0x80) == 0) n = fb;
    else {
        int nb = fb & 0x7f;
        if (nb < 1 || nb > 3 || c->pos + (size_t)nb > c->len) return -1;
        n = 0;
        for (int i = 0; i < nb; i++) n = (n << 8) | c->d[c->pos++];
    }
    if (c->pos + n > c->len) return -1;
    *bodyLen = n;
    *bodyAt = c->pos;
    return 0;
}

static int VLParseCert(const uint8_t *der, size_t derLen,
                       const uint8_t **pub, size_t *pubLen,
                       const uint8_t **sig, size_t *sigLen) {
    VLCursor c = { der, derLen, 0 };
    size_t certBody, at;
    if (VLTLV(&c, 0x30, &certBody, &at) != 0) { VLTrace("  разбор: шаг 1", 0); return -1; }
    (void)certBody;
    c.pos = at;

    size_t tbsBody, tbsAt;
    if (VLTLV(&c, 0x30, &tbsBody, &tbsAt) != 0) { VLTrace("  разбор: шаг 2", 0); return -1; }
    size_t tbsEnd = c.pos + tbsBody;
    c.pos = tbsEnd;

    size_t algBody, algAt;
    if (VLTLV(&c, 0x30, &algBody, &algAt) != 0) { VLTrace("  разбор: шаг 3", 0); return -1; }
    c.pos = algAt + algBody;

    size_t sigBody, sigAt;
    if (VLTLV(&c, 0x03, &sigBody, &sigAt) != 0) { VLTrace("  разбор: шаг 4", 0); return -1; }
    if (sigBody < 2) return -1;
    *sig = der + sigAt + 1;
    *sigLen = sigBody - 1;

    c.pos = tbsAt;
    while (c.pos < tbsEnd) {
        uint8_t tag = c.d[c.pos];
        size_t flen, fat;
        if (VLTLV(&c, tag, &flen, &fat) != 0) return -1;
        VLTrace("  поле метки", (long)tag);
        if (tag == 0x30 && flen >= 8 &&
            c.d[fat] == 0x30 && c.d[fat + 1] == 0x05 &&
            c.d[fat + 2] == 0x06 && c.d[fat + 3] == 0x03 &&
            c.d[fat + 4] == 0x2b && c.d[fat + 5] == 0x65 &&
            c.d[fat + 6] == 0x70) {

            VLCursor inner = { c.d + fat, flen, 7 };
            size_t klen, kat;
            if (VLTLV(&inner, 0x03, &klen, &kat) != 0) return -1;
            if (klen != 33) return -1;
            *pub = c.d + fat + kat + 1;
            *pubLen = 32;
            return 0;
        }
        c.pos = fat + flen;
    }
    VLTrace("  разбор: ключ ed25519 не найден", 0);
    return -1;
}

static uint8_t *VLBuildClientHello(const uint8_t ephPub[32],
                                   const uint8_t kemPub[VL_MLKEM_PUBLIC_BYTES],
                                   const uint8_t clientRandom[32],
                                   const char *sni, const uint8_t sid[8],
                                   const char *const *alpn, size_t alpnCount,
                                   size_t *sessionIdAt, size_t *outLen) {

    VLBuf ext = { NULL, 0, 0, 0 };

    size_t sniLen = strlen(sni);
    if (!sniLen || sniLen > 253) { free(ext.data); return NULL; }
    VLBufU16(&ext, 0x0000);
    VLBufU16(&ext, (uint16_t)(2 + 1 + 2 + sniLen));
    VLBufU16(&ext, (uint16_t)(1 + 2 + sniLen));
    VLBufU8(&ext, 0);
    VLBufU16(&ext, (uint16_t)sniLen);
    VLBufPut(&ext, sni, sniLen);

    VLBufU16(&ext, 0x002b);
    VLBufU16(&ext, 3);
    VLBufU8(&ext, 2);
    VLBufU16(&ext, 0x0304);

    VLBufU16(&ext, 0x000a);
    VLBufU16(&ext, 6);
    VLBufU16(&ext, 4);
    VLBufU16(&ext, 0x11ec);
    VLBufU16(&ext, 0x001d);

    VLBufU16(&ext, 0x0033);
    VLBufU16(&ext, (uint16_t)(2 + 4 + VL_MLKEM_PUBLIC_BYTES + 32 + 4 + 32));
    VLBufU16(&ext, (uint16_t)(4 + VL_MLKEM_PUBLIC_BYTES + 32 + 4 + 32));
    VLBufU16(&ext, 0x11ec);
    VLBufU16(&ext, VL_MLKEM_PUBLIC_BYTES + 32);
    VLBufPut(&ext, kemPub, VL_MLKEM_PUBLIC_BYTES);
    VLBufPut(&ext, ephPub, 32);
    VLBufU16(&ext, 0x001d);
    VLBufU16(&ext, 32);
    VLBufPut(&ext, ephPub, 32);

    VLBufU16(&ext, 0x002d);
    VLBufU16(&ext, 2);
    VLBufU8(&ext, 1);
    VLBufU8(&ext, 1);

    VLBufU16(&ext, 0x000d);
    VLBufU16(&ext, 2 + 20);
    VLBufU16(&ext, 20);
    VLBufU16(&ext, 0x0807);
    VLBufU16(&ext, 0x0403);
    VLBufU16(&ext, 0x0503);
    VLBufU16(&ext, 0x0603);
    VLBufU16(&ext, 0x0804);
    VLBufU16(&ext, 0x0805);
    VLBufU16(&ext, 0x0806);
    VLBufU16(&ext, 0x0401);
    VLBufU16(&ext, 0x0501);
    VLBufU16(&ext, 0x0601);

    VLBufU16(&ext, 0x0023);
    VLBufU16(&ext, 0);

    if (alpnCount) {
        VLBuf protos = { NULL, 0, 0, 0 };
        for (size_t i = 0; i < alpnCount; i++) {
            size_t l = strlen(alpn[i]);
            if (!l || l > 255) continue;
            VLBufU8(&protos, (uint8_t)l);
            VLBufPut(&protos, alpn[i], l);
        }
        if (protos.len) {
            VLBufU16(&ext, 0x0010);
            VLBufU16(&ext, (uint16_t)(2 + protos.len));
            VLBufU16(&ext, (uint16_t)protos.len);
            VLBufPut(&ext, protos.data, protos.len);
        }
        VLBufFree(&protos);
    }

    if (ext.failed) { VLBufFree(&ext); return NULL; }

    VLBuf body = { NULL, 0, 0, 0 };
    VLBufU16(&body, 0x0303);
    VLBufPut(&body, clientRandom, 32);
    VLBufU8(&body, 32);
    *sessionIdAt = body.len;
    uint8_t zeros[32] = { 0 };
    VLBufPut(&body, zeros, 32);
    VLBufU16(&body, 6);
    VLBufU16(&body, 0x1301);
    VLBufU16(&body, 0x1302);
    VLBufU16(&body, 0x1303);
    VLBufU8(&body, 1);
    VLBufU8(&body, 0);
    VLBufU16(&body, (uint16_t)ext.len);
    VLBufPut(&body, ext.data, ext.len);
    VLBufFree(&ext);
    if (body.failed) { VLBufFree(&body); return NULL; }

    (void)sid;

    VLBuf msg = { NULL, 0, 0, 0 };
    VLBufU8(&msg, 1);
    VLBufU24(&msg, (uint32_t)body.len);
    VLBufPut(&msg, body.data, body.len);
    VLBufFree(&body);
    if (msg.failed) { VLBufFree(&msg); return NULL; }
    *sessionIdAt += 4;
    *outLen = msg.len;
    return msg.data;
}

static const EVP_MD *VLDigest(int cipher) { return cipher == 2 ? EVP_sha384() : EVP_sha256(); }
static size_t VLHashLength(int cipher) { return cipher == 2 ? 48 : 32; }

static int VLHash(int cipher, const uint8_t *data, size_t size, uint8_t out[48]) {
    unsigned length = 0;
    return EVP_Digest(data, size, out, &length, VLDigest(cipher), NULL) == 1 && length == VLHashLength(cipher);
}

static int VLExtract(int cipher, const uint8_t *salt, size_t saltSize,
                     const uint8_t *data, size_t size, uint8_t out[48]) {
    unsigned length = 0;
    return HMAC(VLDigest(cipher), salt, (int)saltSize, data, size, out, &length) != NULL && length == VLHashLength(cipher);
}

static int VLExpandLabel(int cipher, const uint8_t *secret, const char *label,
                         const uint8_t *context, size_t contextSize, uint8_t *out, size_t outSize) {
    size_t hashSize = VLHashLength(cipher);
    size_t labelSize = strlen(label);
    if (labelSize > 249 || contextSize > 255 || outSize > 255 * hashSize) return 0;
    uint8_t info[514];
    size_t infoSize = 0;
    info[infoSize++] = (uint8_t)(outSize >> 8);
    info[infoSize++] = (uint8_t)outSize;
    info[infoSize++] = (uint8_t)(6 + labelSize);
    memcpy(info + infoSize, "tls13 ", 6); infoSize += 6;
    memcpy(info + infoSize, label, labelSize); infoSize += labelSize;
    info[infoSize++] = (uint8_t)contextSize;
    if (contextSize) { memcpy(info + infoSize, context, contextSize); infoSize += contextSize; }
    uint8_t block[48], input[48 + 514 + 1];
    size_t previous = 0, written = 0;
    uint8_t counter = 1;
    while (written < outSize) {
        memcpy(input, block, previous);
        memcpy(input + previous, info, infoSize);
        input[previous + infoSize] = counter++;
        if (!VLExtract(cipher, secret, hashSize, input, previous + infoSize + 1, block)) {
            crypto_wipe(block, sizeof(block));
            crypto_wipe(input, sizeof(input));
            return 0;
        }
        size_t chunk = outSize - written < hashSize ? outSize - written : hashSize;
        memcpy(out + written, block, chunk);
        written += chunk;
        previous = hashSize;
    }
    crypto_wipe(block, sizeof(block));
    crypto_wipe(input, sizeof(input));
    return 1;
}

static int VLTrafficSecret(int cipher, const uint8_t *secret, const char *label,
                           const uint8_t *thash, uint8_t out[48]) {
    size_t size = VLHashLength(cipher);
    return VLExpandLabel(cipher, secret, label, thash, size, out, size);
}

static int VLTrafficKeyIV(const uint8_t *secret, int cipher, uint8_t key[32], uint8_t iv[12]) {
    return VLExpandLabel(cipher, secret, "key", NULL, 0, key, VLKeyLength(cipher)) &&
           VLExpandLabel(cipher, secret, "iv", NULL, 0, iv, 12);
}

static int VLFinishedKey(int cipher, const uint8_t *secret, uint8_t out[48]) {
    return VLExpandLabel(cipher, secret, "finished", NULL, 0, out, VLHashLength(cipher));
}

static int VLReadRawRecord(int fd, long deadline, uint8_t *type,
                           uint8_t *buf, size_t *len) {
    uint8_t head[5];
    if (VLReadFull(fd, head, 5, deadline) != 0 || head[1] != 3 || head[2] != 3) return -1;
    size_t n = ((size_t)head[3] << 8) | head[4];
    if (n < 1 || n > VL_MAX_RECORD) return -1;
    if (VLReadFull(fd, buf, n, deadline) != 0) return -1;
    *type = head[0];
    *len = n;
    return 0;
}

typedef struct {
    uint8_t ephemeralPrivate[32];
    uint8_t authKey[32];
    uint8_t kemPrivate[VL_MLKEM_PRIVATE_BYTES];
    uint8_t kemShared[32];
} VLRealitySecrets;

static VLRealityResult VLRealityHandshake(VLReality *r, int fd,
                                 const char *sni,
                                 const uint8_t pbk[32], const uint8_t sid[8],
                                 const char *const *alpn, size_t alpnCount,
                                 long timeoutSec, VLRealitySecrets *secrets) {
    if (!r || fd < 0 || fd >= FD_SETSIZE || !sni || !pbk || !sid || alpnCount > 8 || (alpnCount && !alpn)) return VLR_PROTOCOL;
    static const char *const defaultALPN[] = { "h2", "http/1.1" };
    if (!alpnCount) { alpn = defaultALPN; alpnCount = 2; }
    for (size_t i = 0; i < alpnCount; i++) if (!alpn[i] || !strlen(alpn[i]) || strlen(alpn[i]) > 255) return VLR_PROTOCOL;
    memset(r, 0, sizeof(*r));
    r->fd = fd;
    long deadline = VLNow() + (timeoutSec > 0 ? timeoutSec : 10);

    uint8_t *ephPriv = secrets->ephemeralPrivate;
    uint8_t *authKey = secrets->authKey;
    uint8_t ephPub[32], clientRandom[32], kemPub[VL_MLKEM_PUBLIC_BYTES];
    if (!VLMLKEMKeyPair(kemPub, secrets->kemPrivate)) return VLR_AUTH;
    if (RAND_bytes(ephPriv, 32) != 1) return VLR_AUTH;
    ephPriv[0] &= 248;
    ephPriv[31] &= 127;
    ephPriv[31] |= 64;
    crypto_x25519_public_key(ephPub, ephPriv);
    if (RAND_bytes(clientRandom, 32) != 1) { crypto_wipe(ephPriv, 32); return VLR_AUTH; }
    VLTrace("старт, sni", (long)strlen(sni));
    size_t sidAt = 0, chLen = 0;
    uint8_t *ch = VLBuildClientHello(ephPub, kemPub, clientRandom,
                                     sni, sid, alpn, alpnCount,
                                     &sidAt, &chLen);
    if (!ch) return VLR_PROTOCOL;
    VLTrace("приветствие собрано, байт", (long)chLen);

    uint8_t shared[32];
    crypto_x25519(shared, ephPriv, pbk);
    uint8_t zero[32] = {0};
    if (crypto_verify32(shared, zero) == 0) { free(ch); return VLR_AUTH; }
    VLHKDFExtract(clientRandom, 20, shared, 32, authKey);
    VLHKDFExpand(authKey, (const uint8_t *)"REALITY", 7, authKey, 32);
    crypto_wipe(shared, 32);

    {
        uint8_t authBlock[16];
        memcpy(authBlock, VL_REALITY_VER, 4);
        uint32_t now = (uint32_t)VLNow();
        authBlock[4] = (uint8_t)(now >> 24); authBlock[5] = (uint8_t)(now >> 16);
        authBlock[6] = (uint8_t)(now >> 8);  authBlock[7] = (uint8_t)now;
        memcpy(authBlock + 8, sid, 8);

        uint8_t nonce[12];
        memcpy(nonce, clientRandom + 20, 12);
        uint8_t sealed[32];
        EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
        if (!ctx) { free(ch); return VLR_PROTOCOL; }
        int len = 0, ok = 1;
        ok = EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL) == 1;
        if (ok) ok = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, 12, NULL) == 1;
        if (ok) ok = EVP_EncryptInit_ex(ctx, NULL, NULL, authKey, nonce) == 1;
        if (ok) ok = EVP_EncryptUpdate(ctx, NULL, &len, ch, (int)chLen) == 1;
        if (ok) ok = EVP_EncryptUpdate(ctx, sealed, &len, authBlock, 16) == 1;
        if (ok) ok = EVP_EncryptFinal_ex(ctx, sealed, &len) == 1;
        if (ok) ok = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, sealed + 16) == 1;
        EVP_CIPHER_CTX_free(ctx);
        if (!ok) { free(ch); return VLR_PROTOCOL; }
        memcpy(ch + sidAt, sealed, 32);
    }

    uint8_t expectedSessionID[32];
    memcpy(expectedSessionID, ch + sidAt, sizeof(expectedSessionID));
    VLTrace("session id запечатан", 0);

    uint8_t recHead[5] = { 22, 3, 3, (uint8_t)(chLen >> 8), (uint8_t)chLen };
    if (VLWriteFull(fd, recHead, 5, deadline) != 0 ||
        VLWriteFull(fd, ch, chLen, deadline) != 0) {
        free(ch);
        return VLR_IO;
    }

    VLTrace("приветствие отправлено", 0);

    VLBuf transcript = { NULL, 0, 0, 0 };
    VLBufPut(&transcript, ch, chLen);
    free(ch);
    uint8_t record[VL_MAX_RECORD];
    size_t recLen = 0;
    uint8_t recType = 0;
    VLBuf serverHello = { NULL, 0, 0, 0 };
    for (;;) {
        if (VLReadRawRecord(fd, deadline, &recType, record, &recLen) != 0) {
            VLBufFree(&serverHello); VLBufFree(&transcript); return VLR_IO;
        }
        if (recType == 20 && recLen == 1 && record[0] == 1) continue;
        if (recType != 22 || serverHello.len + recLen > 4096) {
            VLBufFree(&serverHello); VLBufFree(&transcript); return VLR_PROTOCOL;
        }
        VLBufPut(&serverHello, record, recLen);
        if (serverHello.failed) { VLBufFree(&serverHello); VLBufFree(&transcript); return VLR_PROTOCOL; }
        if (serverHello.len < 4) continue;
        size_t want = ((size_t)serverHello.data[1] << 16) | ((size_t)serverHello.data[2] << 8) | serverHello.data[3];
        if (serverHello.data[0] != 2 || want > 4092 || serverHello.len > want + 4) {
            VLBufFree(&serverHello); VLBufFree(&transcript); return VLR_PROTOCOL;
        }
        if (serverHello.len == want + 4) break;
    }
    uint8_t *sh = serverHello.data;
    size_t shLen = serverHello.len;
    VLBufPut(&transcript, sh, shLen);
    if (transcript.failed) { VLBufFree(&serverHello); VLBufFree(&transcript); return VLR_PROTOCOL; }

    VLTrace("ServerHello получен, байт", (long)shLen);

    int cipher = 0, hybrid = 0;
    uint8_t serverPub[32];
    {
        VLCursor c = { sh, shLen, 4 };
        if (shLen < 4 + 2 + 32 + 1) { free(sh); VLBufFree(&transcript); return VLR_PROTOCOL; }
        if (sh[4] != 3 || sh[5] != 3) { free(sh); VLBufFree(&transcript); return VLR_PROTOCOL; }
        c.pos += 2 + 32;
        uint8_t sidEcho = sh[c.pos++];
        if (sidEcho != 32 || c.pos + sidEcho + 5 > shLen || CRYPTO_memcmp(sh + c.pos, expectedSessionID, 32) != 0) { free(sh); VLBufFree(&transcript); return VLR_PROTOCOL; }
        c.pos += sidEcho;
        uint16_t suite = ((uint16_t)sh[c.pos] << 8) | sh[c.pos + 1];
        c.pos += 2;
        if (sh[c.pos++] != 0) { free(sh); VLBufFree(&transcript); return VLR_PROTOCOL; }
        cipher = suite == 0x1301 ? 1 : suite == 0x1302 ? 2 : suite == 0x1303 ? 3 : 0;
        size_t extTotal = ((size_t)sh[c.pos] << 8) | sh[c.pos + 1];
        c.pos += 2;
        size_t extEnd = c.pos + extTotal;
        if (extEnd != shLen) { free(sh); VLBufFree(&transcript); return VLR_PROTOCOL; }
        int haveKey = 0, haveVersion = 0;
        while (c.pos + 4 <= extEnd) {
            uint16_t etype = ((uint16_t)sh[c.pos] << 8) | sh[c.pos + 1];
            uint16_t elen = ((uint16_t)sh[c.pos + 2] << 8) | sh[c.pos + 3];
            c.pos += 4;
            if (c.pos + elen > extEnd) { free(sh); VLBufFree(&transcript); return VLR_PROTOCOL; }
            if (etype == 51 && elen >= 4) {
                uint16_t group = ((uint16_t)sh[c.pos] << 8) | sh[c.pos + 1];
                uint16_t klen = ((uint16_t)sh[c.pos + 2] << 8) | sh[c.pos + 3];
                if (haveKey || elen != 4 + klen) { free(sh); VLBufFree(&transcript); return VLR_PROTOCOL; }
                if (group == 0x001d && klen == 32) {
                    memcpy(serverPub, sh + c.pos + 4, 32);
                    haveKey = 1;
                } else if (group == 0x11ec && klen == VL_MLKEM_CIPHER_BYTES + 32) {
                    if (!VLMLKEMDecapsulate(secrets->kemShared, sh + c.pos + 4, secrets->kemPrivate)) {
                        free(sh); VLBufFree(&transcript); return VLR_AUTH;
                    }
                    memcpy(serverPub, sh + c.pos + 4 + VL_MLKEM_CIPHER_BYTES, 32);
                    haveKey = hybrid = 1;
                }
            } else if (etype == 43) {
                if (haveVersion) { free(sh); VLBufFree(&transcript); return VLR_PROTOCOL; }
                haveVersion = elen == 2 && sh[c.pos] == 3 && sh[c.pos + 1] == 4;
            }
            c.pos += elen;
        }
        free(sh);
        if (!cipher || !haveKey || !haveVersion || c.pos != extEnd) {
            VLBufFree(&transcript);
            return VLR_PROTOCOL;
        }
    }

    VLTrace("ServerHello разобран, шифр", (long)cipher);

    size_t hashSize = VLHashLength(cipher);
    uint8_t early[48], derived[48], hsSecret[48], ecdhe[64], thash[48];
    uint8_t zeros[48] = {0}, emptyHash[48], sHS[48], cHS[48];
    uint8_t sKey[32], sIV[12], cKey[32], cIV[12], sFinKey[48], cFinKey[48];
    size_t ecdheLength = hybrid ? 64 : 32;
    uint8_t *x25519Shared = ecdhe + (hybrid ? 32 : 0);
    crypto_x25519(x25519Shared, ephPriv, serverPub);
    if (crypto_verify32(x25519Shared, zero) == 0) { VLBufFree(&transcript); return VLR_AUTH; }
    if (hybrid) memcpy(ecdhe, secrets->kemShared, 32);
    if (!VLExtract(cipher, zeros, hashSize, zeros, hashSize, early) ||
        !VLHash(cipher, NULL, 0, emptyHash) ||
        !VLExpandLabel(cipher, early, "derived", emptyHash, hashSize, derived, hashSize) ||
        !VLExtract(cipher, derived, hashSize, ecdhe, ecdheLength, hsSecret) ||
        !VLHash(cipher, transcript.data, transcript.len, thash) ||
        !VLTrafficSecret(cipher, hsSecret, "s hs traffic", thash, sHS) ||
        !VLTrafficSecret(cipher, hsSecret, "c hs traffic", thash, cHS) ||
        !VLTrafficKeyIV(sHS, cipher, sKey, sIV) || !VLTrafficKeyIV(cHS, cipher, cKey, cIV) ||
        !VLFinishedKey(cipher, sHS, sFinKey) || !VLFinishedKey(cipher, cHS, cFinKey)) {
        crypto_wipe(ecdhe, sizeof(ecdhe));
        VLBufFree(&transcript);
        return VLR_AUTH;
    }
    crypto_wipe(ecdhe, sizeof(ecdhe));

    VLTrace("ключи рукопожатия выведены", 0);

    uint8_t hsBuf[16384 + 4096];
    size_t hsHave = 0;
    int authenticated = 0;
    int gotServerFin = 0;
    unsigned handshakeStage = 0;
    uint64_t rxSeq = 0;
    while (!gotServerFin) {
        uint8_t head[5];
        if (VLReadFull(fd, head, 5, deadline) != 0) { VLBufFree(&transcript); return VLR_IO; }
        size_t n = ((size_t)head[3] << 8) | head[4];
        if (n < 1 || n > VL_MAX_RECORD) { VLBufFree(&transcript); return VLR_PROTOCOL; }
        if (VLReadFull(fd, record, n, deadline) != 0) { VLBufFree(&transcript); return VLR_IO; }

        if (head[1] != 3 || head[2] != 3) { VLBufFree(&transcript); return VLR_PROTOCOL; }
        if (head[0] == 20 && n == 1 && record[0] == 1) continue;
        if (head[0] == 21) {
            VLTrace("тревога после ServerHello, код", n >= 2 ? (long)record[1] : -1);
            VLBufFree(&transcript);
            return VLR_PROTOCOL;
        }

        if (head[0] != 23) { VLBufFree(&transcript); return VLR_PROTOCOL; }
        if (n < 17) { VLBufFree(&transcript); return VLR_PROTOCOL; }
        size_t plainLen = 0;
        uint8_t inner = 0;
        if (VLOpenBuf(cipher, sKey, sIV, rxSeq++, head, record, n,
                      hsBuf + hsHave, sizeof(hsBuf) - hsHave, &plainLen, &inner) != 0) {
            VLTrace("запись не расшифровалась, байт", (long)n);
            VLBufFree(&transcript);
            return VLR_PROTOCOL;
        }
        VLTrace("расшифровано, байт", (long)plainLen);
        if (inner == 21) { VLBufFree(&transcript); return VLR_PROTOCOL; }
        if (inner != 22) continue;

        size_t at = 0, end = hsHave + plainLen;
        while (at + 4 <= end) {
            size_t mlen = ((size_t)hsBuf[at + 1] << 16) | ((size_t)hsBuf[at + 2] << 8) | hsBuf[at + 3];
            if (at + 4 + mlen > end) break;
            uint8_t mtype = hsBuf[at];
            const uint8_t *msg = hsBuf + at + 4;
            static const uint8_t expectedTypes[] = {8, 11, 15, 20};
            if (handshakeStage >= sizeof(expectedTypes) || mtype != expectedTypes[handshakeStage++]) {
                VLBufFree(&transcript); return VLR_PROTOCOL;
            }
            if (mtype == 15 && (mlen != 68 || msg[0] != 8 || msg[1] != 7 || msg[2] != 0 || msg[3] != 64)) {
                VLBufFree(&transcript); return VLR_PROTOCOL;
            }
            if (mtype == 11) {

                if (mlen < 1 + 3 + 3) { VLBufFree(&transcript); return VLR_PROTOCOL; }
                size_t ctxLen = msg[0];
                if (1 + ctxLen + 3 > mlen) { VLBufFree(&transcript); return VLR_PROTOCOL; }
                const uint8_t *list = msg + 1 + ctxLen;
                size_t listLen = ((size_t)list[0] << 16) | ((size_t)list[1] << 8) | list[2];
                list += 3;
                if ((size_t)(list - msg) + listLen > mlen || listLen < 3) {
                    VLBufFree(&transcript);
                    return VLR_PROTOCOL;
                }
                size_t certLen = ((size_t)list[0] << 16) | ((size_t)list[1] << 8) | list[2];
                list += 3;
                if (certLen + 3 > listLen) { VLBufFree(&transcript); return VLR_PROTOCOL; }
                VLTrace("сертификат, байт", (long)certLen);
                const uint8_t *pub = NULL, *sig = NULL;
                size_t pubLen = 0, sigLen = 0;
                if (VLParseCert(list, certLen, &pub, &pubLen, &sig, &sigLen) != 0) {
                    VLBufFree(&transcript);
                    return VLR_AUTH;
                }

                VLTrace("  ключ в нём, байт", (long)pubLen);
                VLTrace("  подпись, байт", (long)sigLen);
                uint8_t mac[64];
                unsigned int macLen = 0;
                HMAC(EVP_sha512(), authKey, 32, pub, (int)pubLen, mac, &macLen);
                if (macLen != sigLen || CRYPTO_memcmp(mac, sig, sigLen) != 0) {
                    VLBufFree(&transcript);
                    return VLR_AUTH;
                }
                authenticated = 1;
            }
            if (mtype == 20) {
                if (mlen != hashSize || !authenticated) { VLBufFree(&transcript); return VLR_PROTOCOL; }

                uint8_t expect[48];
                if (!VLHash(cipher, transcript.data, transcript.len, thash) ||
                    !VLExtract(cipher, sFinKey, hashSize, thash, hashSize, expect) ||
                    CRYPTO_memcmp(expect, msg, hashSize) != 0) {
                    VLTrace("Finished сервера не сошёлся", 0);
                    VLBufFree(&transcript);
                    return VLR_PROTOCOL;
                }
                VLBufPut(&transcript, hsBuf + at, 4 + mlen);
                gotServerFin = 1;
                at += 4 + mlen;
                break;
            }
            VLBufPut(&transcript, hsBuf + at, 4 + mlen);
            at += 4 + mlen;
        }

        memmove(hsBuf, hsBuf + at, end - at);
        hsHave = end - at;
        if (transcript.failed || (gotServerFin && hsHave)) { VLBufFree(&transcript); return VLR_PROTOCOL; }
    }
    crypto_wipe(authKey, 32);

    {
        uint8_t verify[48];
        if (!VLHash(cipher, transcript.data, transcript.len, thash) ||
            !VLExtract(cipher, cFinKey, hashSize, thash, hashSize, verify)) {
            VLBufFree(&transcript); return VLR_AUTH;
        }
        uint8_t finMsg[53] = {20, 0, 0, 0};
        size_t finSize = hashSize + 5;
        finMsg[3] = (uint8_t)hashSize;
        memcpy(finMsg + 4, verify, hashSize);
        finMsg[finSize - 1] = 22;
        uint8_t head[5] = {23, 3, 3, 0, (uint8_t)(finSize + 16)};
        uint8_t sealed[69];
        size_t sealedLen = 0;
        if (VLSeal(cipher, cKey, cIV, 0, head, finMsg, finSize, sealed, sizeof(sealed), &sealedLen) != 0) {
            VLBufFree(&transcript); return VLR_PROTOCOL;
        }
        if (VLWriteFull(fd, head, 5, deadline) != 0 || VLWriteFull(fd, sealed, sealedLen, deadline) != 0) {
            VLBufFree(&transcript); return VLR_IO;
        }
    }
    uint8_t master[48], sApp[48], cApp[48];
    if (!VLExpandLabel(cipher, hsSecret, "derived", emptyHash, hashSize, derived, hashSize) ||
        !VLExtract(cipher, derived, hashSize, zeros, hashSize, master) ||
        !VLTrafficSecret(cipher, master, "s ap traffic", thash, sApp) ||
        !VLTrafficSecret(cipher, master, "c ap traffic", thash, cApp) ||
        !VLTrafficKeyIV(cApp, cipher, r->sendKey, r->sendIV) ||
        !VLTrafficKeyIV(sApp, cipher, r->recvKey, r->recvIV)) {
        VLBufFree(&transcript); return VLR_AUTH;
    }
    crypto_wipe(master, sizeof(master));
    crypto_wipe(hsSecret, sizeof(hsSecret));
    crypto_wipe(sApp, sizeof(sApp)); crypto_wipe(cApp, sizeof(cApp));
    r->cipher = cipher;
    r->sendSeq = 0;
    r->recvSeq = 0;
    crypto_wipe(ephPriv, 32);
    VLBufFree(&transcript);
    return VLR_OK;
}

VLRealityResult vlRealityConnect(VLReality *r, int fd, const char *sni,
                                 const uint8_t pbk[32], const uint8_t sid[8],
                                 const char *const *alpn, size_t alpnCount, long timeoutSec) {
    VLRealitySecrets secrets;
    VLRealityResult result = VLRealityHandshake(r, fd, sni, pbk, sid, alpn, alpnCount, timeoutSec, &secrets);
    crypto_wipe(&secrets, sizeof(secrets));
    if (result != VLR_OK && r) { crypto_wipe(r, sizeof(*r)); r->fd = -1; }
    return result;
}

size_t vlRealityPending(const VLReality *r) { return r->readLength - r->readOffset; }

ssize_t vlRealityRead(VLReality *r, uint8_t *buf, size_t capacity) {
    if (!capacity) return 0;
    if (vlRealityPending(r)) {
        size_t count = vlRealityPending(r) < capacity ? vlRealityPending(r) : capacity;
        memcpy(buf, r->readBuffer + r->readOffset, count);
        r->readOffset += count;
        return (ssize_t)count;
    }
    uint8_t head[5];
    uint8_t body[VL_MAX_RECORD];
    for (;;) {
        long deadline = VLNow() + 60;
        if (VLReadFull(r->fd, head, 5, deadline) != 0) return -1;
        size_t n = ((size_t)head[3] << 8) | head[4];
        if (n < 1 || n > VL_MAX_RECORD) return -1;
        if (VLReadFull(r->fd, body, n, deadline) != 0) return -1;
        VLTrace("после рукопожатия: запись типа", (long)head[0]);
        VLTrace("  длиной", (long)n);
        if (head[0] == 20) continue;
        if (head[0] == 21) {
            VLTrace("  открытая тревога, код", n >= 2 ? (long)body[1] : -1);
            if (n >= 2 && body[1] == 0) return 0;
            return -1;
        }
        if (head[0] != 23 && head[0] != 22) continue;
        size_t plainLen = 0;
        if (n < 17) return -1;

        uint8_t inner = 0;
        if (VLOpenBuf(r->cipher, r->recvKey, r->recvIV, r->recvSeq++,
                      head, body, n, r->readBuffer, sizeof(r->readBuffer), &plainLen, &inner) != 0) return -1;
        VLTrace("  внутренний тип", (long)inner);
        if (inner == 22) continue;
        if (inner == 21) {
            VLTrace("  тревога после рукопожатия, код", plainLen >= 2 ? (long)r->readBuffer[1] : -1);
            return plainLen >= 2 && r->readBuffer[1] == 0 ? 0 : -1;
        }
        if (inner != 23) continue;

        if (plainLen == 0) continue;
        r->readOffset = 0;
        r->readLength = plainLen;
        return vlRealityRead(r, buf, capacity);
    }
}

int vlRealityWrite(VLReality *r, const uint8_t *buf, size_t length) {
    while (length) {
        size_t chunk = length > VL_MAX_PLAIN - 1 ? VL_MAX_PLAIN - 1 : length;

        uint8_t plain[VL_MAX_PLAIN];
        memcpy(plain, buf, chunk);
        plain[chunk] = 23;
        size_t plainLen = chunk + 1;
        uint8_t head[5] = { 23, 3, 3,
            (uint8_t)((plainLen + 16) >> 8), (uint8_t)(plainLen + 16) };
        uint8_t sealed[VL_MAX_PLAIN + 16];
        size_t sealedLen = 0;
        if (VLSeal(r->cipher, r->sendKey, r->sendIV, r->sendSeq++,
                   head, plain, plainLen, sealed, sizeof(sealed), &sealedLen) != 0) return 0;
        long deadline = VLNow() + 60;
        if (VLWriteFull(r->fd, head, 5, deadline) != 0) return 0;
        if (VLWriteFull(r->fd, sealed, sealedLen, deadline) != 0) return 0;
        buf += chunk;
        length -= chunk;
    }
    return 1;
}

void vlRealityClose(VLReality *r) {
    uint8_t alert[3] = { 1, 0, 21 };
    uint8_t head[5] = { 23, 3, 3, 0, 3 + 16 };
    uint8_t sealed[32];
    size_t sealedLen = 0;
    if (r->fd >= 0 && VLSeal(r->cipher, r->sendKey, r->sendIV, r->sendSeq++,
                             head, alert, 3, sealed, sizeof(sealed), &sealedLen) == 0) {
        VLWriteFull(r->fd, head, 5, VLNow() + 5);
        VLWriteFull(r->fd, sealed, sealedLen, VLNow() + 5);
    }
    crypto_wipe(r, sizeof(*r));
    r->fd = -1;
}
