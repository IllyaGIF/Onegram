#include "PowerSHA256.h"
#include <string.h>

static const uint32_t K[64] = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

#define ROR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))

static void compress(uint32_t state[8], const uint8_t block[64]) {
    uint32_t w[64];
    for (int i = 0; i < 16; i++) {
        w[i] = ((uint32_t)block[i*4] << 24) | ((uint32_t)block[i*4+1] << 16) |
               ((uint32_t)block[i*4+2] << 8) | block[i*4+3];
    }
    for (int i = 16; i < 64; i++) {
        uint32_t s0 = ROR(w[i-15],7) ^ ROR(w[i-15],18) ^ (w[i-15] >> 3);
        uint32_t s1 = ROR(w[i-2],17) ^ ROR(w[i-2],19) ^ (w[i-2] >> 10);
        w[i] = w[i-16] + s0 + w[i-7] + s1;
    }
    uint32_t a=state[0],b=state[1],c=state[2],d=state[3];
    uint32_t e=state[4],f=state[5],g=state[6],h=state[7];
    for (int i = 0; i < 64; i++) {
        uint32_t S1 = ROR(e,6) ^ ROR(e,11) ^ ROR(e,25);
        uint32_t ch = (e & f) ^ (~e & g);
        uint32_t t1 = h + S1 + ch + K[i] + w[i];
        uint32_t S0 = ROR(a,2) ^ ROR(a,13) ^ ROR(a,22);
        uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
        uint32_t t2 = S0 + maj;
        h=g; g=f; f=e; e=d+t1; d=c; c=b; b=a; a=t1+t2;
    }
    state[0]+=a; state[1]+=b; state[2]+=c; state[3]+=d;
    state[4]+=e; state[5]+=f; state[6]+=g; state[7]+=h;
}

void PWSHA256Init(PWSHA256 *ctx) {
    ctx->state[0]=0x6a09e667; ctx->state[1]=0xbb67ae85;
    ctx->state[2]=0x3c6ef372; ctx->state[3]=0xa54ff53a;
    ctx->state[4]=0x510e527f; ctx->state[5]=0x9b05688c;
    ctx->state[6]=0x1f83d9ab; ctx->state[7]=0x5be0cd19;
    ctx->length = 0;
    ctx->filled = 0;
}

void PWSHA256Update(PWSHA256 *ctx, const uint8_t *data, size_t length) {
    ctx->length += length;
    while (length) {
        size_t take = 64 - ctx->filled;
        if (take > length) take = length;
        memcpy(ctx->block + ctx->filled, data, take);
        ctx->filled += take;
        data += take;
        length -= take;
        if (ctx->filled == 64) {
            compress(ctx->state, ctx->block);
            ctx->filled = 0;
        }
    }
}

void PWSHA256Final(PWSHA256 *ctx, uint8_t out[PW_SHA256_LEN]) {
    uint64_t bits = ctx->length * 8;
    uint8_t one = 0x80;
    PWSHA256Update(ctx, &one, 1);
    uint8_t zero = 0;
    while (ctx->filled != 56) PWSHA256Update(ctx, &zero, 1);
    uint8_t tail[8];
    for (int i = 0; i < 8; i++) tail[i] = (uint8_t)(bits >> (56 - 8*i));
    
    memcpy(ctx->block + 56, tail, 8);
    compress(ctx->state, ctx->block);
    for (int i = 0; i < 8; i++) {
        out[i*4]   = (uint8_t)(ctx->state[i] >> 24);
        out[i*4+1] = (uint8_t)(ctx->state[i] >> 16);
        out[i*4+2] = (uint8_t)(ctx->state[i] >> 8);
        out[i*4+3] = (uint8_t)(ctx->state[i]);
    }
}

void PWSHA256Hash(const uint8_t *data, size_t length, uint8_t out[PW_SHA256_LEN]) {
    PWSHA256 ctx;
    PWSHA256Init(&ctx);
    PWSHA256Update(&ctx, data, length);
    PWSHA256Final(&ctx, out);
}

void PWHMACSHA256(const uint8_t *key, size_t keyLength,
                  const uint8_t *data, size_t dataLength,
                  uint8_t out[PW_SHA256_LEN]) {
    uint8_t padded[64];
    memset(padded, 0, sizeof(padded));
    if (keyLength > 64) {
        PWSHA256Hash(key, keyLength, padded);
    } else if (keyLength) {
        memcpy(padded, key, keyLength);
    }

    uint8_t inner[64], outer[64];
    for (int i = 0; i < 64; i++) {
        inner[i] = padded[i] ^ 0x36;
        outer[i] = padded[i] ^ 0x5c;
    }

    uint8_t hash[PW_SHA256_LEN];
    PWSHA256 ctx;
    PWSHA256Init(&ctx);
    PWSHA256Update(&ctx, inner, 64);
    PWSHA256Update(&ctx, data, dataLength);
    PWSHA256Final(&ctx, hash);

    PWSHA256Init(&ctx);
    PWSHA256Update(&ctx, outer, 64);
    PWSHA256Update(&ctx, hash, PW_SHA256_LEN);
    PWSHA256Final(&ctx, out);
}

void PWHKDFExtract(const uint8_t *salt, size_t saltLength,
                   const uint8_t *secret, size_t secretLength,
                   uint8_t out[PW_SHA256_LEN]) {
    uint8_t zeros[PW_SHA256_LEN];
    if (!salt || !saltLength) {
        memset(zeros, 0, sizeof(zeros));
        salt = zeros;
        saltLength = sizeof(zeros);
    }
    PWHMACSHA256(salt, saltLength, secret, secretLength, out);
}

void PWHKDFExpand(const uint8_t prk[PW_SHA256_LEN],
                  const uint8_t *info, size_t infoLength,
                  uint8_t *out, size_t outLength) {
    uint8_t block[PW_SHA256_LEN];
    size_t done = 0;
    uint8_t counter = 1;
    size_t blockLength = 0;
    while (done < outLength) {
        
        uint8_t buffer[PW_SHA256_LEN + 512 + 1];
        size_t n = 0;
        if (blockLength) { memcpy(buffer, block, blockLength); n = blockLength; }
        if (infoLength) {
            if (infoLength > 512) infoLength = 512;   
            memcpy(buffer + n, info, infoLength);
            n += infoLength;
        }
        buffer[n++] = counter++;
        PWHMACSHA256(prk, PW_SHA256_LEN, buffer, n, block);
        blockLength = PW_SHA256_LEN;
        size_t take = outLength - done;
        if (take > PW_SHA256_LEN) take = PW_SHA256_LEN;
        memcpy(out + done, block, take);
        done += take;
    }
}

void PWHKDFExpandLabel(const uint8_t secret[PW_SHA256_LEN],
                       const char *label,
                       const uint8_t *context, size_t contextLength,
                       uint8_t *out, size_t outLength) {
    
    uint8_t info[2 + 1 + 6 + 64 + 1 + 255];
    size_t n = 0;
    info[n++] = (uint8_t)(outLength >> 8);
    info[n++] = (uint8_t)(outLength & 0xff);
    size_t labelLength = strlen(label);
    if (labelLength > 64) labelLength = 64;
    info[n++] = (uint8_t)(6 + labelLength);
    memcpy(info + n, "tls13 ", 6); n += 6;
    memcpy(info + n, label, labelLength); n += labelLength;
    if (contextLength > 255) contextLength = 255;
    info[n++] = (uint8_t)contextLength;
    if (contextLength) { memcpy(info + n, context, contextLength); n += contextLength; }
    PWHKDFExpand(secret, info, n, out, outLength);
}
