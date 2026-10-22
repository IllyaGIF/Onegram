#import "MTAes.h"

#import <CommonCrypto/CommonCrypto.h>

# define AES_MAXNR 14
# define AES_BLOCK_SIZE 16

#define N_WORDS (AES_BLOCK_SIZE / sizeof(unsigned long))
typedef struct {
    unsigned long data[N_WORDS];
} aes_block_t;

# define load_block(d, s)        memcpy((d).data, (s), AES_BLOCK_SIZE)
# define store_block(d, s)       memcpy((d), (s).data, AES_BLOCK_SIZE)

void MyAesIgeEncrypt(const void *inBytes, int length, void *outBytes, const void *key, int keyLength, void *iv) {
    assert(length >= 0 && length % AES_BLOCK_SIZE == 0);
    if (length == 0)
        return;

    const uint8_t *input = inBytes;
    uint8_t *output = outBytes;
    uint8_t *ivBytes = iv;
    aes_block_t previousCiphertext;
    aes_block_t previousPlaintext;
    load_block(previousCiphertext, ivBytes);
    load_block(previousPlaintext, ivBytes + AES_BLOCK_SIZE);
    aes_block_t secondPreviousPlaintext = previousPlaintext;

    uint8_t *tmpInBytes = malloc(length);
    assert(tmpInBytes != NULL);
    for (int offset = 0; offset < length; offset += AES_BLOCK_SIZE) {
        aes_block_t plaintext;
        load_block(plaintext, input + offset);
        aes_block_t block = plaintext;
        if (offset != 0) {
            for (size_t n = 0; n < N_WORDS; ++n)
                block.data[n] ^= secondPreviousPlaintext.data[n];
        }
        store_block(tmpInBytes + offset, block);
        secondPreviousPlaintext = previousPlaintext;
        previousPlaintext = plaintext;
    }
    
    size_t realOutLength = 0;
    CCCryptorStatus result = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, 0, key, keyLength, previousCiphertext.data, tmpInBytes, length, tmpInBytes, length, &realOutLength);
    
    assert(result == kCCSuccess);
    
    assert(realOutLength == (size_t)length);
    load_block(previousPlaintext, ivBytes + AES_BLOCK_SIZE);
    for (int offset = 0; offset < length; offset += AES_BLOCK_SIZE) {
        aes_block_t plaintext;
        aes_block_t ciphertext;
        load_block(plaintext, input + offset);
        load_block(ciphertext, tmpInBytes + offset);
        for (size_t n = 0; n < N_WORDS; ++n)
            ciphertext.data[n] ^= previousPlaintext.data[n];
        store_block(output + offset, ciphertext);
        previousCiphertext = ciphertext;
        previousPlaintext = plaintext;
    }
    free(tmpInBytes);

    store_block(ivBytes, previousCiphertext);
    store_block(ivBytes + AES_BLOCK_SIZE, previousPlaintext);
}

void MyAesIgeDecrypt(const void *inBytes, int length, void *outBytes, const void *key, int keyLength, void *iv) {
    assert(length >= 0 && length % AES_BLOCK_SIZE == 0);
    if (length == 0)
        return;

    const uint8_t *input = inBytes;
    uint8_t *output = outBytes;
    uint8_t *ivBytes = iv;
    aes_block_t previousCiphertext;
    aes_block_t previousPlaintext;
    load_block(previousCiphertext, ivBytes);
    load_block(previousPlaintext, ivBytes + AES_BLOCK_SIZE);
    
    CCCryptorRef decryptor = NULL;
    CCCryptorCreate(kCCDecrypt, kCCAlgorithmAES128, kCCOptionECBMode, key, keyLength, nil, &decryptor);
    if (decryptor != NULL) {
        for (int offset = 0; offset < length; offset += AES_BLOCK_SIZE) {
            aes_block_t ciphertext;
            aes_block_t block;
            aes_block_t plaintext;
            load_block(ciphertext, input + offset);
            for (size_t n = 0; n < N_WORDS; ++n)
                block.data[n] = ciphertext.data[n] ^ previousPlaintext.data[n];
            
            size_t dataOutMoved = 0;
            CCCryptorStatus result = CCCryptorUpdate(decryptor, block.data, AES_BLOCK_SIZE, plaintext.data, AES_BLOCK_SIZE, &dataOutMoved);
            assert(result == kCCSuccess);
            assert(dataOutMoved == AES_BLOCK_SIZE);
            
            for (size_t n = 0; n < N_WORDS; ++n)
                plaintext.data[n] ^= previousCiphertext.data[n];
            store_block(output + offset, plaintext);
            previousCiphertext = ciphertext;
            previousPlaintext = plaintext;
        }
        
        store_block(ivBytes, previousCiphertext);
        store_block(ivBytes + AES_BLOCK_SIZE, previousPlaintext);
        
        CCCryptorRelease(decryptor);
    }
}

static void ctr128_inc(unsigned char *counter)
{
    uint32_t n = 16, c = 1;
    
    do {
        --n;
        c += counter[n];
        counter[n] = (uint8_t)c;
        c >>= 8;
    } while (n);
}

static void ctr128_inc_aligned(unsigned char *counter)
{
    size_t *data, c, d, n;
    const union {
        long one;
        char little;
    } is_endian = {
        1
    };
    
    if (is_endian.little || ((size_t)counter % sizeof(size_t)) != 0) {
        ctr128_inc(counter);
        return;
    }
    
    data = (size_t *)counter;
    c = 1;
    n = 16 / sizeof(size_t);
    do {
        --n;
        d = data[n] += c;
        c = ((d - c) ^ d) >> (sizeof(size_t) * 8 - 1);
    } while (n);
}


@interface MTAesCtr () {
    CCCryptorRef _cryptor;
    
    unsigned char _ivec[16] __attribute__((aligned(16)));
    unsigned int _num;
    unsigned char _ecount[16] __attribute__((aligned(16)));
}

@end

@implementation MTAesCtr

- (instancetype)initWithKey:(const void *)key keyLength:(int)keyLength iv:(const void *)iv decrypt:(bool)decrypt {
    self = [super init];
    if (self != nil) {
        _num = 0;
        memset(_ecount, 0, 16);
        memcpy(_ivec, iv, 16);
        
        CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES128, kCCOptionECBMode, key, keyLength, nil, &_cryptor);
    }
    return self;
}

- (instancetype)initWithKey:(const void *)key keyLength:(int)keyLength iv:(const void *)iv ecount:(void *)ecount num:(uint32_t)num {
    self = [super init];
    if (self != nil) {
        _num = num;
        memcpy(_ecount, ecount, 16);
        memcpy(_ivec, iv, 16);
        
        CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES128, kCCOptionECBMode, key, keyLength, nil, &_cryptor);
    }
    return self;
}

- (void)dealloc {
    if (_cryptor) {
        CCCryptorRelease(_cryptor);
    }
}

- (uint32_t)num {
    return _num;
}

- (void *)ecount {
    return _ecount;
}

- (void)getIv:(void *)iv {
    memcpy(iv, _ivec, 16);
}

- (void)encryptIn:(const unsigned char *)in out:(unsigned char *)out len:(size_t)len {
    unsigned int n;
    size_t l = 0;
    
    assert(in && out);
    assert(_num < 16);
    
    n = _num;
    
    if (16 % sizeof(size_t) == 0) {
        do {
            while (n && len) {
               *(out++) = *(in++) ^ _ecount[n];
                --len;
                n = (n + 1) % 16;
            }
            
            if (((size_t)in|(size_t)out|(size_t)_ivec)%sizeof(size_t) != 0)
                break;
            
            while (len >= 16) {
                size_t dataOutMoved;
                CCCryptorUpdate(_cryptor, _ivec, 16, _ecount, 16, &dataOutMoved);
                ctr128_inc_aligned(_ivec);
                for (n = 0; n < 16; n += sizeof(size_t)) {
                   *(size_t *)(out + n) =
                   *(size_t *)(in + n) ^ *(size_t *)(_ecount + n);
                }
                len -= 16;
                out += 16;
                in += 16;
                n = 0;
            }
            if (len) {
                size_t dataOutMoved;
                CCCryptorUpdate(_cryptor, _ivec, 16, _ecount, 16, &dataOutMoved);
                ctr128_inc_aligned(_ivec);
                while (len--) {
                    out[n] = in[n] ^ _ecount[n];
                    ++n;
                }
            }
            _num = n;
            return;
        } while (0);
    }
    
    while (l < len) {
        if (n == 0) {
            size_t dataOutMoved;
            CCCryptorUpdate(_cryptor, _ivec, 16, _ecount, 16, &dataOutMoved);
            ctr128_inc(_ivec);
        }
        out[l] = in[l] ^ _ecount[n];
        ++l;
        n = (n + 1) % 16;
    }
    
    _num = n;
}

@end
