#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <pthread.h>

static uint8_t  PW_AES_SBOX[256];
static pthread_once_t PW_AES_ONCE = PTHREAD_ONCE_INIT;

static uint8_t PWGfMul(uint8_t a, uint8_t b) {
    uint8_t r = 0;
    while (b) {
        if (b & 1) r ^= a;
        uint8_t hi = a & 0x80;
        a <<= 1;
        if (hi) a ^= 0x1b;
        b >>= 1;
    }
    return r;
}

static uint8_t PWRotl8(uint8_t v, int n) {
    return (uint8_t)((v << n) | (v >> (8 - n)));
}

static void PW_AES_Init(void) {
    
    uint8_t log[256], exp[256];
    uint8_t x = 1;
    for (int i = 0; i < 255; i++) {
        exp[i] = x;
        log[x] = (uint8_t)i;
        x = PWGfMul(x, 3);
    }
    exp[255] = exp[0];
    for (int i = 0; i < 256; i++) {
        uint8_t y = i ? exp[255 - log[i]] : 0;   
        PW_AES_SBOX[i] = (uint8_t)(y ^ PWRotl8(y, 1) ^ PWRotl8(y, 2) ^
                                   PWRotl8(y, 3) ^ PWRotl8(y, 4) ^ 0x63);
    }
}

typedef struct {
    uint32_t rk[60];      
    int      rounds;
} PWAESKey;

static uint32_t PWSubWord(uint32_t w) {
    return (uint32_t)PW_AES_SBOX[w & 0xff]
        | ((uint32_t)PW_AES_SBOX[(w >> 8) & 0xff] << 8)
        | ((uint32_t)PW_AES_SBOX[(w >> 16) & 0xff] << 16)
        | ((uint32_t)PW_AES_SBOX[(w >> 24) & 0xff] << 24);
}

static uint32_t PWRotWord(uint32_t w) { return (w << 8) | (w >> 24); }

static void PW_AES_SetKey(PWAESKey *k, const uint8_t *key, size_t keyLen) {
    pthread_once(&PW_AES_ONCE, PW_AES_Init);
    int nk = (int)(keyLen / 4);          
    k->rounds = nk + 6;                  
    int total = 4 * (k->rounds + 1);
    for (int i = 0; i < nk; i++) {
        k->rk[i] = ((uint32_t)key[4 * i] << 24) | ((uint32_t)key[4 * i + 1] << 16) |
                   ((uint32_t)key[4 * i + 2] << 8) | key[4 * i + 3];
    }
    uint32_t rcon = 1;
    for (int i = nk; i < total; i++) {
        uint32_t t = k->rk[i - 1];
        if (i % nk == 0) {
            t = PWSubWord(PWRotWord(t)) ^ (rcon << 24);
            rcon = (uint32_t)PWGfMul((uint8_t)rcon, 2);
        }
        else if (nk == 8 && i % nk == 4) t = PWSubWord(t);
        k->rk[i] = k->rk[i - nk] ^ t;
    }
}

static void PW_AES_Encrypt(const PWAESKey *k, const uint8_t in[16], uint8_t out[16]) {
    uint8_t s[16];
    memcpy(s, in, 16);
    
    #define PWXOR(i) s[i] ^= (uint8_t)(k->rk[0 + (i) / 4] >> (24 - 8 * ((i) % 4)))
    for (int i = 0; i < 16; i++) PWXOR(i);
    #undef PWXOR
    for (int round = 1; round <= k->rounds; round++) {
        
        for (int i = 0; i < 16; i++) s[i] = PW_AES_SBOX[s[i]];
        
        uint8_t t[16];
        memcpy(t, s, 16);
        for (int r = 1; r < 4; r++) {
            for (int c = 0; c < 4; c++) s[r + 4 * c] = t[r + 4 * ((c + r) % 4)];
        }
        
        if (round < k->rounds) {
            for (int c = 0; c < 4; c++) {
                uint8_t *col = s + 4 * c;
                uint8_t a0 = col[0], a1 = col[1], a2 = col[2], a3 = col[3];
                col[0] = (uint8_t)(PWGfMul(a0, 2) ^ PWGfMul(a1, 3) ^ a2 ^ a3);
                col[1] = (uint8_t)(a0 ^ PWGfMul(a1, 2) ^ PWGfMul(a2, 3) ^ a3);
                col[2] = (uint8_t)(a0 ^ a1 ^ PWGfMul(a2, 2) ^ PWGfMul(a3, 3));
                col[3] = (uint8_t)(PWGfMul(a0, 3) ^ a1 ^ a2 ^ PWGfMul(a3, 2));
            }
        }
        
        for (int i = 0; i < 16; i++) {
            s[i] ^= (uint8_t)(k->rk[4 * round + i / 4] >> (24 - 8 * (i % 4)));
        }
    }
    memcpy(out, s, 16);
}

static void PWGHashMul(uint8_t out[16], const uint8_t x[16], const uint8_t h[16]) {
    uint8_t z[16] = { 0 }, v[16];
    memcpy(v, x, 16);
    for (int i = 0; i < 128; i++) {
        int bit = (h[i / 8] >> (7 - (i % 8))) & 1;
        if (bit) {
            for (int j = 0; j < 16; j++) z[j] ^= v[j];
        }
        int lsb = v[15] & 1;
        for (int j = 15; j > 0; j--) v[j] = (uint8_t)((v[j] >> 1) | (v[j - 1] << 7));
        v[0] >>= 1;
        if (lsb) v[0] ^= 0xe1;
    }
    memcpy(out, z, 16);
}

static void PWGHash(uint8_t y[16], const uint8_t h[16],
                    const uint8_t *data, size_t len) {
    for (size_t off = 0; off < len; off += 16) {
        uint8_t block[16] = { 0 };
        size_t n = len - off < 16 ? len - off : 16;
        memcpy(block, data + off, n);
        for (int i = 0; i < 16; i++) y[i] ^= block[i];
        PWGHashMul(y, y, h);
    }
}

static void PWGctr(const PWAESKey *k, const uint8_t iv[12], uint32_t ctr,
                   const uint8_t *in, uint8_t *out, size_t len) {
    uint8_t block[16];
    memcpy(block, iv, 12);
    for (size_t off = 0; off < len; off += 16) {
        block[12] = (uint8_t)(ctr >> 24); block[13] = (uint8_t)(ctr >> 16);
        block[14] = (uint8_t)(ctr >> 8);  block[15] = (uint8_t)ctr;
        ctr++;
        uint8_t ks[16];
        PW_AES_Encrypt(k, block, ks);
        size_t n = len - off < 16 ? len - off : 16;
        for (size_t i = 0; i < n; i++) out[off + i] = (uint8_t)(in[off + i] ^ ks[i]);
    }
}

void PWAESGCMSeal(const uint8_t *key, size_t keyLen,
                  const uint8_t iv[12],
                  const uint8_t *aad, size_t aadLen,
                  const uint8_t *plain, size_t plainLen,
                  uint8_t *out) {
    PWAESKey k;
    PW_AES_SetKey(&k, key, keyLen);
    uint8_t h[16] = { 0 }, y[16] = { 0 }, j0[16], s[16];
    PW_AES_Encrypt(&k, h, h);                       
    
    PWGHash(y, h, aad, aadLen);
    
    memcpy(j0, iv, 12);
    j0[12] = j0[13] = j0[14] = 0; j0[15] = 1;
    PWGctr(&k, iv, 2, plain, out, plainLen);
    PWGHash(y, h, out, plainLen);
    uint8_t lens[16] = { 0 };
    uint64_t abits = (uint64_t)aadLen * 8, cbits = (uint64_t)plainLen * 8;
    for (int i = 0; i < 8; i++) lens[7 - i] = (uint8_t)(abits >> (8 * i));
    for (int i = 0; i < 8; i++) lens[15 - i] = (uint8_t)(cbits >> (8 * i));
    PWGHash(y, h, lens, 16);
    
    PW_AES_Encrypt(&k, j0, s);
    for (int i = 0; i < 16; i++) out[plainLen + i] = (uint8_t)(y[i] ^ s[i]);
}

int PWAESGCMOpen(const uint8_t *key, size_t keyLen,
                 const uint8_t iv[12],
                 const uint8_t *aad, size_t aadLen,
                 const uint8_t *input, size_t inputLen,
                 uint8_t *out, size_t outCap) {
    if (inputLen < 16) return -1;
    size_t plainLen = inputLen - 16;
    if (outCap < plainLen) return -1;
    PWAESKey k;
    PW_AES_SetKey(&k, key, keyLen);
    uint8_t h[16] = { 0 }, y[16] = { 0 }, j0[16], s[16];
    PW_AES_Encrypt(&k, h, h);
    PWGHash(y, h, aad, aadLen);
    PWGHash(y, h, input, plainLen);
    uint8_t lens[16] = { 0 };
    uint64_t abits = (uint64_t)aadLen * 8, cbits = (uint64_t)plainLen * 8;
    for (int i = 0; i < 8; i++) lens[7 - i] = (uint8_t)(abits >> (8 * i));
    for (int i = 0; i < 8; i++) lens[15 - i] = (uint8_t)(cbits >> (8 * i));
    PWGHash(y, h, lens, 16);
    memcpy(j0, iv, 12);
    j0[12] = j0[13] = j0[14] = 0; j0[15] = 1;
    PW_AES_Encrypt(&k, j0, s);
    uint8_t tag[16];
    for (int i = 0; i < 16; i++) tag[i] = (uint8_t)(y[i] ^ s[i]);
    uint8_t diff = 0;
    for (int i = 0; i < 16; i++) diff |= (uint8_t)(tag[i] ^ input[plainLen + i]);
    if (diff != 0) return -1;
    PWGctr(&k, iv, 2, input, out, plainLen);
    return 0;
}
