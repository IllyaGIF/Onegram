#include "PowerReality.h"
#include "PowerSHA256.h"
#include "monocypher.h"
#include "OGDanteSocket.h"
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

static const uint8_t PW_REALITY_VER[4] = { 26, 9, 9, 0 };

#define PW_MAX_RECORD  18432   
#define PW_MAX_PLAIN   16384

static long PWNow(void) { return (long)time(NULL); }

static int PWReadFull(int fd, uint8_t *buf, size_t n, long deadline) {
    size_t have = 0;
    while (have < n) {
        long left = deadline - PWNow();
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

static int PWWriteFull(int fd, const uint8_t *buf, size_t n, long deadline) {
    size_t sent = 0;
    while (sent < n) {
        long left = deadline - PWNow();
        if (left <= 0) return -1;
        fd_set w; FD_ZERO(&w); FD_SET(fd, &w);
        struct timeval tv = { left, 0 };
        int rc = select(fd + 1, NULL, &w, NULL, &tv);
        if (rc < 0) { if (errno == EINTR) continue; return -1; }
        if (rc == 0) return -1;
        ssize_t put = OGDanteSocketSend(fd, buf + sent, n - sent);
        if (put < 0) { if (errno == EINTR) continue; return -1; }
        if (put == 0) return -1;
        sent += (size_t)put;
    }
    return 0;
}

volatile int gPWRealityTrace = 0;

static void PWTrace(const char *stage, long value) {
    if (!gPWRealityTrace) return;
    fprintf(stderr, "[reality] %s %ld\n", stage, value);
    fflush(stderr);
}

typedef struct {
    uint8_t *data;
    size_t len;
    size_t cap;
    int failed;
} PWBuf;

static void PWBufPut(PWBuf *b, const void *bytes, size_t n) {
    if (b->failed) return;
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

static void PWBufU8(PWBuf *b, uint8_t v) { PWBufPut(b, &v, 1); }
static void PWBufU16(PWBuf *b, uint16_t v) {
    uint8_t t[2] = { (uint8_t)(v >> 8), (uint8_t)v };
    PWBufPut(b, t, 2);
}
static void PWBufU24(PWBuf *b, uint32_t v) {
    uint8_t t[3] = { (uint8_t)(v >> 16), (uint8_t)(v >> 8), (uint8_t)v };
    PWBufPut(b, t, 3);
}
static void PWBufFree(PWBuf *b) { free(b->data); b->data = NULL; b->len = b->cap = 0; }

static void PWRecordNonce(const uint8_t iv[12], uint64_t seq, uint8_t nonce[12]) {
    memcpy(nonce, iv, 12);
    for (int i = 0; i < 8; i++) nonce[11 - i] ^= (uint8_t)(seq >> (8 * i));
}

static const EVP_CIPHER *PWCipher(int cipher) {
    switch (cipher) {
        case 1: return EVP_aes_128_gcm();
        case 2: return EVP_aes_256_gcm();
        default: return NULL;
    }
}

static size_t PWKeyLength(int cipher) { return cipher == 1 ? 16 : 32; }

static int PWSeal(int cipher, const uint8_t key[32], const uint8_t iv[12],
                  uint64_t seq, const uint8_t aad[5],
                  const uint8_t *payload, size_t payloadLen,
                  uint8_t *out, size_t outCap, size_t *outLen) {
    if (outCap < payloadLen + 16) return -1;
    uint8_t nonce[12];
    PWRecordNonce(iv, seq, nonce);
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
    ok = EVP_EncryptInit_ex(ctx, PWCipher(cipher), NULL, NULL, NULL) == 1;
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

static int PWOpen(int cipher, const uint8_t key[32], const uint8_t iv[12],
                  uint64_t seq, const uint8_t aad[5],
                  const uint8_t *input, size_t inputLen,
                  uint8_t *out, size_t outCap, size_t *outLen) {
    if (inputLen < 16 || outCap < inputLen - 16) return -1;
    uint8_t nonce[12];
    PWRecordNonce(iv, seq, nonce);
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
    ok = EVP_DecryptInit_ex(ctx, PWCipher(cipher), NULL, NULL, NULL) == 1;
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

static int PWOpenBuf(int cipher, const uint8_t key[32], const uint8_t iv[12],
                     uint64_t seq, uint8_t header[5],
                     const uint8_t *input, size_t inputLen,
                     uint8_t *out, size_t outCap, size_t *outLen,
                     uint8_t *innerType) {
    if (PWOpen(cipher, key, iv, seq, header, input, inputLen, out, outCap, outLen) != 0) {
        return -1;
    }
    size_t n = *outLen;
    while (n > 0 && out[n - 1] == 0) n--;
    if (n == 0) return -1;                           
    if (innerType) *innerType = out[n - 1];
    *outLen = n - 1;
    return 0;
}

typedef struct { const uint8_t *d; size_t len; size_t pos; } PWCursor;

static int PWTLV(PWCursor *c, uint8_t tag, size_t *bodyLen, size_t *bodyAt) {
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

static int PWParseCert(const uint8_t *der, size_t derLen,
                       const uint8_t **pub, size_t *pubLen,
                       const uint8_t **sig, size_t *sigLen) {
    PWCursor c = { der, derLen, 0 };
    size_t certBody, at;
    if (PWTLV(&c, 0x30, &certBody, &at) != 0) { PWTrace("  разбор: шаг 1", 0); return -1; }
    (void)certBody;
    c.pos = at;

    size_t tbsBody, tbsAt;
    if (PWTLV(&c, 0x30, &tbsBody, &tbsAt) != 0) { PWTrace("  разбор: шаг 2", 0); return -1; }
    size_t tbsEnd = c.pos + tbsBody;
    c.pos = tbsEnd;                    

    size_t algBody, algAt;
    if (PWTLV(&c, 0x30, &algBody, &algAt) != 0) { PWTrace("  разбор: шаг 3", 0); return -1; }
    c.pos = algAt + algBody;

    size_t sigBody, sigAt;
    if (PWTLV(&c, 0x03, &sigBody, &sigAt) != 0) { PWTrace("  разбор: шаг 4", 0); return -1; }
    if (sigBody < 2) return -1;
    *sig = der + sigAt + 1;   
    *sigLen = sigBody - 1;

    c.pos = tbsAt;
    while (c.pos < tbsEnd) {
        uint8_t tag = c.d[c.pos];
        size_t flen, fat;
        if (PWTLV(&c, tag, &flen, &fat) != 0) return -1;
        PWTrace("  поле метки", (long)tag);
        if (tag == 0x30 && flen >= 8 &&
            c.d[fat] == 0x30 && c.d[fat + 1] == 0x05 &&
            c.d[fat + 2] == 0x06 && c.d[fat + 3] == 0x03 &&
            c.d[fat + 4] == 0x2b && c.d[fat + 5] == 0x65 &&
            c.d[fat + 6] == 0x70) {
            
            PWCursor inner = { c.d + fat, flen, 7 };
            size_t klen, kat;
            if (PWTLV(&inner, 0x03, &klen, &kat) != 0) return -1;
            if (klen != 33) return -1;
            *pub = c.d + fat + kat + 1;
            *pubLen = 32;
            return 0;
        }
        c.pos = fat + flen;
    }
    PWTrace("  разбор: ключ ed25519 не найден", 0);
    return -1;
}

static uint8_t *PWBuildClientHello(const uint8_t ephPub[32],
                                   const uint8_t clientRandom[32],
                                   const char *sni, const uint8_t sid[8],
                                   const char *const *alpn, size_t alpnCount,
                                   size_t *sessionIdAt, size_t *outLen) {

    PWBuf ext = { NULL, 0, 0, 0 };

    size_t sniLen = strlen(sni);
    if (!sniLen || sniLen > 253) { free(ext.data); return NULL; }
    PWBufU16(&ext, 0x0000);
    PWBufU16(&ext, (uint16_t)(2 + 1 + 2 + sniLen));
    PWBufU16(&ext, (uint16_t)(1 + 2 + sniLen));
    PWBufU8(&ext, 0);
    PWBufU16(&ext, (uint16_t)sniLen);
    PWBufPut(&ext, sni, sniLen);

    PWBufU16(&ext, 0x002b);
    PWBufU16(&ext, 3);
    PWBufU8(&ext, 2);
    PWBufU16(&ext, 0x0304);

    PWBufU16(&ext, 0x000a);
    PWBufU16(&ext, 4);
    PWBufU16(&ext, 2);
    PWBufU16(&ext, 0x001d);

    PWBufU16(&ext, 0x0033);
    PWBufU16(&ext, (uint16_t)(2 + 2 + 2 + 32));
    PWBufU16(&ext, (uint16_t)(2 + 2 + 32));
    PWBufU16(&ext, 0x001d);
    PWBufU16(&ext, 32);
    PWBufPut(&ext, ephPub, 32);

    PWBufU16(&ext, 0x002d);
    PWBufU16(&ext, 2);
    PWBufU8(&ext, 1);
    PWBufU8(&ext, 1);

    PWBufU16(&ext, 0x000d);
    PWBufU16(&ext, 2 + 18);
    PWBufU16(&ext, 18);
    PWBufU16(&ext, 0x0403);
    PWBufU16(&ext, 0x0503);
    PWBufU16(&ext, 0x0603);
    PWBufU16(&ext, 0x0804);
    PWBufU16(&ext, 0x0805);
    PWBufU16(&ext, 0x0806);
    PWBufU16(&ext, 0x0401);
    PWBufU16(&ext, 0x0501);
    PWBufU16(&ext, 0x0601);

    PWBufU16(&ext, 0x0023);
    PWBufU16(&ext, 0);

    if (alpnCount) {
        PWBuf protos = { NULL, 0, 0, 0 };
        for (size_t i = 0; i < alpnCount; i++) {
            size_t l = strlen(alpn[i]);
            if (!l || l > 255) continue;
            PWBufU8(&protos, (uint8_t)l);
            PWBufPut(&protos, alpn[i], l);
        }
        if (protos.len) {
            PWBufU16(&ext, 0x0010);
            PWBufU16(&ext, (uint16_t)(2 + protos.len));
            PWBufU16(&ext, (uint16_t)protos.len);
            PWBufPut(&ext, protos.data, protos.len);
        }
        PWBufFree(&protos);
    }

    if (ext.failed) { PWBufFree(&ext); return NULL; }

    PWBuf body = { NULL, 0, 0, 0 };
    PWBufU16(&body, 0x0303);               
    PWBufPut(&body, clientRandom, 32);
    PWBufU8(&body, 32);                    
    *sessionIdAt = body.len;
    uint8_t zeros[32] = { 0 };
    PWBufPut(&body, zeros, 32);
    PWBufU16(&body, 6);                    
    PWBufU16(&body, 0x1301);
    PWBufU16(&body, 0x1302);
    PWBufU16(&body, 0x1303);
    PWBufU8(&body, 1);                     
    PWBufU8(&body, 0);
    PWBufU16(&body, (uint16_t)ext.len);
    PWBufPut(&body, ext.data, ext.len);
    PWBufFree(&ext);
    if (body.failed) { PWBufFree(&body); return NULL; }

    (void)sid;

    PWBuf msg = { NULL, 0, 0, 0 };
    PWBufU8(&msg, 1);
    PWBufU24(&msg, (uint32_t)body.len);
    PWBufPut(&msg, body.data, body.len);
    PWBufFree(&body);
    if (msg.failed) { PWBufFree(&msg); return NULL; }
    *sessionIdAt += 4;                     
    *outLen = msg.len;
    return msg.data;
}

static const EVP_MD *PWDigest(int cipher) { return cipher == 2 ? EVP_sha384() : EVP_sha256(); }
static size_t PWHashLength(int cipher) { return cipher == 2 ? 48 : 32; }

static int PWHash(int cipher, const uint8_t *data, size_t size, uint8_t out[48]) {
    unsigned length = 0;
    return EVP_Digest(data, size, out, &length, PWDigest(cipher), NULL) == 1 && length == PWHashLength(cipher);
}

static int PWExtract(int cipher, const uint8_t *salt, size_t saltSize,
                     const uint8_t *data, size_t size, uint8_t out[48]) {
    unsigned length = 0;
    return HMAC(PWDigest(cipher), salt, (int)saltSize, data, size, out, &length) != NULL && length == PWHashLength(cipher);
}

static int PWExpandLabel(int cipher, const uint8_t *secret, const char *label,
                         const uint8_t *context, size_t contextSize, uint8_t *out, size_t outSize) {
    size_t hashSize = PWHashLength(cipher);
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
        if (!PWExtract(cipher, secret, hashSize, input, previous + infoSize + 1, block)) {
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

static int PWTrafficSecret(int cipher, const uint8_t *secret, const char *label,
                           const uint8_t *thash, uint8_t out[48]) {
    size_t size = PWHashLength(cipher);
    return PWExpandLabel(cipher, secret, label, thash, size, out, size);
}

static int PWTrafficKeyIV(const uint8_t *secret, int cipher, uint8_t key[32], uint8_t iv[12]) {
    return PWExpandLabel(cipher, secret, "key", NULL, 0, key, PWKeyLength(cipher)) &&
           PWExpandLabel(cipher, secret, "iv", NULL, 0, iv, 12);
}

static int PWFinishedKey(int cipher, const uint8_t *secret, uint8_t out[48]) {
    return PWExpandLabel(cipher, secret, "finished", NULL, 0, out, PWHashLength(cipher));
}

static int PWReadRawRecord(int fd, long deadline, uint8_t *type,
                           uint8_t *buf, size_t *len) {
    uint8_t head[5];
    if (PWReadFull(fd, head, 5, deadline) != 0) return -1;
    size_t n = ((size_t)head[3] << 8) | head[4];
    if (n < 1 || n > PW_MAX_RECORD) return -1;
    if (PWReadFull(fd, buf, n, deadline) != 0) return -1;
    *type = head[0];                                 
    *len = n;
    return 0;
}

PWRealityResult pwRealityConnect(PWReality *r, int fd,
                                 const char *sni,
                                 const uint8_t pbk[32], const uint8_t sid[8],
                                 const char *const *alpn, size_t alpnCount,
                                 long timeoutSec) {
    memset(r, 0, sizeof(*r));
    r->fd = fd;
    long deadline = PWNow() + (timeoutSec > 0 ? timeoutSec : 10);

    uint8_t ephPriv[32], ephPub[32], clientRandom[32];
    if (RAND_bytes(ephPriv, 32) != 1) return PWR_AUTH;
    ephPriv[0] &= 248;
    ephPriv[31] &= 127;
    ephPriv[31] |= 64;
    crypto_x25519_public_key(ephPub, ephPriv);
    if (RAND_bytes(clientRandom, 32) != 1) { crypto_wipe(ephPriv, 32); return PWR_AUTH; }
    PWTrace("старт, sni", (long)strlen(sni));
    size_t sidAt = 0, chLen = 0;
    uint8_t *ch = PWBuildClientHello(ephPub, clientRandom,
                                     sni, sid, alpn, alpnCount,
                                     &sidAt, &chLen);
    if (!ch) return PWR_PROTOCOL;
    PWTrace("приветствие собрано, байт", (long)chLen);

    uint8_t shared[32];
    crypto_x25519(shared, ephPriv, pbk);
    uint8_t authKey[32];
    PWHKDFExtract(clientRandom, 20, shared, 32, authKey);
    PWHKDFExpand(authKey, (const uint8_t *)"REALITY", 7, authKey, 32);
    crypto_wipe(shared, 32);

    {
        uint8_t authBlock[16];
        memcpy(authBlock, PW_REALITY_VER, 4);
        uint32_t now = (uint32_t)PWNow();
        authBlock[4] = (uint8_t)(now >> 24); authBlock[5] = (uint8_t)(now >> 16);
        authBlock[6] = (uint8_t)(now >> 8);  authBlock[7] = (uint8_t)now;
        memcpy(authBlock + 8, sid, 8);

        uint8_t nonce[12];
        memcpy(nonce, clientRandom + 20, 12);
        uint8_t sealed[32];
        EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
        if (!ctx) { free(ch); return PWR_PROTOCOL; }
        int len = 0, ok = 1;
        ok = EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL) == 1;
        if (ok) ok = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, 12, NULL) == 1;
        if (ok) ok = EVP_EncryptInit_ex(ctx, NULL, NULL, authKey, nonce) == 1;
        if (ok) ok = EVP_EncryptUpdate(ctx, NULL, &len, ch, (int)chLen) == 1;
        if (ok) ok = EVP_EncryptUpdate(ctx, sealed, &len, authBlock, 16) == 1;
        if (ok) ok = EVP_EncryptFinal_ex(ctx, sealed, &len) == 1;
        if (ok) ok = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, sealed + 16) == 1;
        EVP_CIPHER_CTX_free(ctx);
        if (!ok) { free(ch); return PWR_PROTOCOL; }
        memcpy(ch + sidAt, sealed, 32);
    }

    PWTrace("session id запечатан", 0);
    
    uint8_t recHead[5] = { 22, 3, 3, (uint8_t)(chLen >> 8), (uint8_t)chLen };
    if (PWWriteFull(fd, recHead, 5, deadline) != 0 ||
        PWWriteFull(fd, ch, chLen, deadline) != 0) {
        free(ch);
        return PWR_IO;
    }

    PWTrace("приветствие отправлено", 0);
    
    PWBuf transcript = { NULL, 0, 0, 0 };
    PWBufPut(&transcript, ch, chLen);
    free(ch);
    uint8_t record[PW_MAX_RECORD];
    size_t recLen = 0;
    uint8_t recType = 0;
    uint8_t *sh = NULL;
    size_t shLen = 0;
    for (;;) {
        PWTrace("жду запись", 0);
        if (PWReadRawRecord(fd, deadline, &recType, record, &recLen) != 0) {
            PWTrace("запись не пришла", 0);
            PWBufFree(&transcript);
            return PWR_IO;
        }
        PWTrace("запись типа", (long)recType);
        PWTrace("  длиной", (long)recLen);
        if (recType == 20) continue;                 
        if (recType == 21) {                         
            PWTrace("тревога, код", recLen >= 2 ? (long)record[1] : -1);
            PWBufFree(&transcript);
            return PWR_PROTOCOL;
        }
        if (recType != 22 || recLen < 4 || record[0] != 2) {
            PWBufFree(&transcript);
            return PWR_PROTOCOL;
        }
        size_t want = ((size_t)record[1] << 16) | ((size_t)record[2] << 8) | record[3];
        if (want + 4 != recLen) { PWBufFree(&transcript); return PWR_PROTOCOL; }
        sh = malloc(recLen);
        if (!sh) { PWBufFree(&transcript); return PWR_PROTOCOL; }
        memcpy(sh, record, recLen);
        shLen = recLen;
        PWBufPut(&transcript, sh, shLen);
        break;
    }

    PWTrace("ServerHello получен, байт", (long)shLen);
    
    int cipher = 0;
    uint8_t serverPub[32];
    {
        PWCursor c = { sh, shLen, 4 };               
        if (shLen < 4 + 2 + 32 + 1) { free(sh); PWBufFree(&transcript); return PWR_PROTOCOL; }
        c.pos += 2 + 32;                             
        uint8_t sidEcho = sh[c.pos++];
        if (c.pos + sidEcho + 3 > shLen) { free(sh); PWBufFree(&transcript); return PWR_PROTOCOL; }
        c.pos += sidEcho;
        uint16_t suite = ((uint16_t)sh[c.pos] << 8) | sh[c.pos + 1];
        c.pos += 2;
        c.pos++;                                     
        cipher = suite == 0x1301 ? 1 : suite == 0x1302 ? 2 : suite == 0x1303 ? 3 : 0;
        size_t extTotal = ((size_t)sh[c.pos] << 8) | sh[c.pos + 1];
        c.pos += 2;
        size_t extEnd = c.pos + extTotal;
        if (extEnd > shLen) { free(sh); PWBufFree(&transcript); return PWR_PROTOCOL; }
        int haveKey = 0, haveVersion = 0;
        while (c.pos + 4 <= extEnd) {
            uint16_t etype = ((uint16_t)sh[c.pos] << 8) | sh[c.pos + 1];
            uint16_t elen = ((uint16_t)sh[c.pos + 2] << 8) | sh[c.pos + 3];
            c.pos += 4;
            if (c.pos + elen > extEnd) break;
            if (etype == 51 && elen >= 36) {         
                uint16_t group = ((uint16_t)sh[c.pos] << 8) | sh[c.pos + 1];
                uint16_t klen = ((uint16_t)sh[c.pos + 2] << 8) | sh[c.pos + 3];
                if (group == 0x001d && klen == 32) {
                    memcpy(serverPub, sh + c.pos + 4, 32);
                    haveKey = 1;
                }
            } else if (etype == 43) {                
                haveVersion = elen >= 2 && sh[c.pos] == 3 && sh[c.pos + 1] == 4;
            }
            c.pos += elen;
        }
        free(sh);
        if (!cipher || !haveKey || !haveVersion) {
            PWBufFree(&transcript);
            return cipher ? PWR_PROTOCOL : PWR_PROTOCOL;
        }
    }

    PWTrace("ServerHello разобран, шифр", (long)cipher);
    
    size_t hashSize = PWHashLength(cipher);
    uint8_t early[48], derived[48], hsSecret[48], ecdhe[32], thash[48];
    uint8_t zeros[48] = {0}, emptyHash[48], sHS[48], cHS[48];
    uint8_t sKey[32], sIV[12], cKey[32], cIV[12], sFinKey[48], cFinKey[48];
    crypto_x25519(ecdhe, ephPriv, serverPub);
    if (!PWExtract(cipher, zeros, hashSize, zeros, hashSize, early) ||
        !PWHash(cipher, NULL, 0, emptyHash) ||
        !PWExpandLabel(cipher, early, "derived", emptyHash, hashSize, derived, hashSize) ||
        !PWExtract(cipher, derived, hashSize, ecdhe, 32, hsSecret) ||
        !PWHash(cipher, transcript.data, transcript.len, thash) ||
        !PWTrafficSecret(cipher, hsSecret, "s hs traffic", thash, sHS) ||
        !PWTrafficSecret(cipher, hsSecret, "c hs traffic", thash, cHS) ||
        !PWTrafficKeyIV(sHS, cipher, sKey, sIV) || !PWTrafficKeyIV(cHS, cipher, cKey, cIV) ||
        !PWFinishedKey(cipher, sHS, sFinKey) || !PWFinishedKey(cipher, cHS, cFinKey)) {
        crypto_wipe(ecdhe, sizeof(ecdhe));
        PWBufFree(&transcript);
        return PWR_AUTH;
    }
    crypto_wipe(ecdhe, sizeof(ecdhe));

    PWTrace("ключи рукопожатия выведены", 0);

    uint8_t hsBuf[16384 + 4096];
    size_t hsHave = 0;
    int authenticated = 0;
    int gotServerFin = 0;
    uint64_t rxSeq = 0;
    while (!gotServerFin) {
        uint8_t head[5];
        if (PWReadFull(fd, head, 5, deadline) != 0) { PWBufFree(&transcript); return PWR_IO; }
        size_t n = ((size_t)head[3] << 8) | head[4];
        if (n < 1 || n > PW_MAX_RECORD) { PWBufFree(&transcript); return PWR_PROTOCOL; }
        if (PWReadFull(fd, record, n, deadline) != 0) { PWBufFree(&transcript); return PWR_IO; }

        if (head[0] == 20) continue;
        if (head[0] == 21) {
            PWTrace("тревога после ServerHello, код", n >= 2 ? (long)record[1] : -1);
            PWBufFree(&transcript);
            return PWR_PROTOCOL;
        }

        if (head[0] != 23 && head[0] != 22) continue;
        if (n < 17) { PWBufFree(&transcript); return PWR_PROTOCOL; }
        size_t plainLen = 0;
        uint8_t inner = 0;
        if (PWOpenBuf(cipher, sKey, sIV, rxSeq++, head, record, n,
                      hsBuf + hsHave, sizeof(hsBuf) - hsHave, &plainLen, &inner) != 0) {
            PWTrace("запись не расшифровалась, байт", (long)n);
            PWBufFree(&transcript);
            return PWR_PROTOCOL;
        }
        PWTrace("расшифровано, байт", (long)plainLen);
        if (inner == 21) { PWBufFree(&transcript); return PWR_PROTOCOL; }
        if (inner != 22) continue;                   
        
        size_t at = hsHave, end = hsHave + plainLen;
        while (at + 4 <= end) {
            size_t mlen = ((size_t)hsBuf[at + 1] << 16) | ((size_t)hsBuf[at + 2] << 8) | hsBuf[at + 3];
            if (at + 4 + mlen > end) break;          
            uint8_t mtype = hsBuf[at];
            const uint8_t *msg = hsBuf + at + 4;
            if (mtype == 11) {                       

                if (mlen < 1 + 3 + 3) { PWBufFree(&transcript); return PWR_PROTOCOL; }
                size_t ctxLen = msg[0];
                if (1 + ctxLen + 3 > mlen) { PWBufFree(&transcript); return PWR_PROTOCOL; }
                const uint8_t *list = msg + 1 + ctxLen;
                size_t listLen = ((size_t)list[0] << 16) | ((size_t)list[1] << 8) | list[2];
                list += 3;
                if ((size_t)(list - msg) + listLen > mlen || listLen < 3) {
                    PWBufFree(&transcript);
                    return PWR_PROTOCOL;
                }
                size_t certLen = ((size_t)list[0] << 16) | ((size_t)list[1] << 8) | list[2];
                list += 3;
                if (certLen + 3 > listLen) { PWBufFree(&transcript); return PWR_PROTOCOL; }
                PWTrace("сертификат, байт", (long)certLen);
                const uint8_t *pub = NULL, *sig = NULL;
                size_t pubLen = 0, sigLen = 0;
                if (PWParseCert(list, certLen, &pub, &pubLen, &sig, &sigLen) != 0) {
                    PWBufFree(&transcript);
                    return PWR_AUTH;                 
                }
                
                PWTrace("  ключ в нём, байт", (long)pubLen);
                PWTrace("  подпись, байт", (long)sigLen);
                uint8_t mac[64];
                unsigned int macLen = 0;
                HMAC(EVP_sha512(), authKey, 32, pub, (int)pubLen, mac, &macLen);
                if (macLen != sigLen || CRYPTO_memcmp(mac, sig, sigLen) != 0) {
                    PWBufFree(&transcript);
                    return PWR_AUTH;                 
                }
                authenticated = 1;
            }
            if (mtype == 20) {                       
                if (mlen != hashSize || !authenticated) { PWBufFree(&transcript); return PWR_PROTOCOL; }

                uint8_t expect[48];
                if (!PWHash(cipher, transcript.data, transcript.len, thash) ||
                    !PWExtract(cipher, sFinKey, hashSize, thash, hashSize, expect) ||
                    CRYPTO_memcmp(expect, msg, hashSize) != 0) {
                    PWTrace("Finished сервера не сошёлся", 0);
                    PWBufFree(&transcript);
                    return PWR_PROTOCOL;
                }
                PWBufPut(&transcript, hsBuf + at, 4 + mlen);   
                gotServerFin = 1;
                at += 4 + mlen;
                break;
            }
            PWBufPut(&transcript, hsBuf + at, 4 + mlen);
            at += 4 + mlen;
        }
        
        memmove(hsBuf, hsBuf + at, end - at);
        hsHave = end - at;
    }
    crypto_wipe(authKey, 32);

    {
        uint8_t verify[48];
        if (!PWHash(cipher, transcript.data, transcript.len, thash) ||
            !PWExtract(cipher, cFinKey, hashSize, thash, hashSize, verify)) {
            PWBufFree(&transcript); return PWR_AUTH;
        }
        uint8_t finMsg[53] = {20, 0, 0, 0};
        size_t finSize = hashSize + 5;
        finMsg[3] = (uint8_t)hashSize;
        memcpy(finMsg + 4, verify, hashSize);
        finMsg[finSize - 1] = 22;
        uint8_t head[5] = {23, 3, 3, 0, (uint8_t)(finSize + 16)};
        uint8_t sealed[69];
        size_t sealedLen = 0;
        if (PWSeal(cipher, cKey, cIV, 0, head, finMsg, finSize, sealed, sizeof(sealed), &sealedLen) != 0) {
            PWBufFree(&transcript); return PWR_PROTOCOL;
        }
        if (PWWriteFull(fd, head, 5, deadline) != 0 || PWWriteFull(fd, sealed, sealedLen, deadline) != 0) {
            PWBufFree(&transcript); return PWR_IO;
        }
    }
    uint8_t master[48], sApp[48], cApp[48];
    if (!PWExpandLabel(cipher, hsSecret, "derived", emptyHash, hashSize, derived, hashSize) ||
        !PWExtract(cipher, derived, hashSize, zeros, hashSize, master) ||
        !PWTrafficSecret(cipher, master, "s ap traffic", thash, sApp) ||
        !PWTrafficSecret(cipher, master, "c ap traffic", thash, cApp) ||
        !PWTrafficKeyIV(cApp, cipher, r->sendKey, r->sendIV) ||
        !PWTrafficKeyIV(sApp, cipher, r->recvKey, r->recvIV)) {
        PWBufFree(&transcript); return PWR_AUTH;
    }
    crypto_wipe(master, sizeof(master));
    crypto_wipe(hsSecret, sizeof(hsSecret));
    crypto_wipe(sApp, sizeof(sApp)); crypto_wipe(cApp, sizeof(cApp));
    r->cipher = cipher;
    r->sendSeq = 0;
    r->recvSeq = 0;
    crypto_wipe(ephPriv, 32);
    PWBufFree(&transcript);
    return PWR_OK;
}

size_t pwRealityPending(const PWReality *r) { return r->readLength - r->readOffset; }

ssize_t pwRealityRead(PWReality *r, uint8_t *buf, size_t capacity) {
    if (!capacity) return 0;
    if (pwRealityPending(r)) {
        size_t count = pwRealityPending(r) < capacity ? pwRealityPending(r) : capacity;
        memcpy(buf, r->readBuffer + r->readOffset, count);
        r->readOffset += count;
        return (ssize_t)count;
    }
    uint8_t head[5];
    uint8_t body[PW_MAX_RECORD];
    for (;;) {
        long deadline = PWNow() + 60;
        if (PWReadFull(r->fd, head, 5, deadline) != 0) return -1;
        size_t n = ((size_t)head[3] << 8) | head[4];
        if (n < 1 || n > PW_MAX_RECORD) return -1;
        if (PWReadFull(r->fd, body, n, deadline) != 0) return -1;
        PWTrace("после рукопожатия: запись типа", (long)head[0]);
        PWTrace("  длиной", (long)n);
        if (head[0] == 20) continue;
        if (head[0] == 21) {                         
            PWTrace("  открытая тревога, код", n >= 2 ? (long)body[1] : -1);
            if (n >= 2 && body[1] == 0) return 0;    
            return -1;
        }
        if (head[0] != 23 && head[0] != 22) continue;
        size_t plainLen = 0;
        if (n < 17) return -1;

        uint8_t inner = 0;
        if (PWOpenBuf(r->cipher, r->recvKey, r->recvIV, r->recvSeq++,
                      head, body, n, r->readBuffer, sizeof(r->readBuffer), &plainLen, &inner) != 0) return -1;
        PWTrace("  внутренний тип", (long)inner);
        if (inner == 22) continue;                   
        if (inner == 21) {
            PWTrace("  тревога после рукопожатия, код", plainLen >= 2 ? (long)r->readBuffer[1] : -1);
            return plainLen >= 2 && r->readBuffer[1] == 0 ? 0 : -1;
        }
        if (inner != 23) continue;

        if (plainLen == 0) continue;
        r->readOffset = 0;
        r->readLength = plainLen;
        return pwRealityRead(r, buf, capacity);
    }
}

int pwRealityWrite(PWReality *r, const uint8_t *buf, size_t length) {
    while (length) {
        size_t chunk = length > PW_MAX_PLAIN - 1 ? PW_MAX_PLAIN - 1 : length;
        
        uint8_t plain[PW_MAX_PLAIN];
        memcpy(plain, buf, chunk);
        plain[chunk] = 23;
        size_t plainLen = chunk + 1;
        uint8_t head[5] = { 23, 3, 3,
            (uint8_t)((plainLen + 16) >> 8), (uint8_t)(plainLen + 16) };
        uint8_t sealed[PW_MAX_PLAIN + 16];
        size_t sealedLen = 0;
        if (PWSeal(r->cipher, r->sendKey, r->sendIV, r->sendSeq++,
                   head, plain, plainLen, sealed, sizeof(sealed), &sealedLen) != 0) return 0;
        long deadline = PWNow() + 60;
        if (PWWriteFull(r->fd, head, 5, deadline) != 0) return 0;
        if (PWWriteFull(r->fd, sealed, sealedLen, deadline) != 0) return 0;
        buf += chunk;
        length -= chunk;
    }
    return 1;
}

void pwRealityClose(PWReality *r) {
    uint8_t alert[3] = { 1, 0, 21 };                 
    uint8_t head[5] = { 23, 3, 3, 0, 3 + 16 };
    uint8_t sealed[32];
    size_t sealedLen = 0;
    if (r->fd >= 0 && PWSeal(r->cipher, r->sendKey, r->sendIV, r->sendSeq++,
                             head, alert, 3, sealed, sizeof(sealed), &sealedLen) == 0) {
        PWWriteFull(r->fd, head, 5, PWNow() + 5);
        PWWriteFull(r->fd, sealed, sealedLen, PWNow() + 5);
    }
    crypto_wipe(r, sizeof(*r));
    r->fd = -1;
}
