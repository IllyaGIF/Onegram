#include "monocypher.h"

#ifdef MONOCYPHER_CPP_NAMESPACE
namespace MONOCYPHER_CPP_NAMESPACE {
#endif

#define FOR_T(type, i, start, end) for (type i = (start); i < (end); i++)
#define FOR(i, start, end)         FOR_T(size_t, i, start, end)
#define COPY(dst, src, size)       FOR(_i_, 0, size) (dst)[_i_] = (src)[_i_]
#define ZERO(buf, size)            FOR(_i_, 0, size) (buf)[_i_] = 0
#define WIPE_CTX(ctx)              crypto_wipe(ctx   , sizeof(*(ctx)))
#define WIPE_BUFFER(buffer)        crypto_wipe(buffer, sizeof(buffer))
#define MIN(a, b)                  ((a) <= (b) ? (a) : (b))
#define MAX(a, b)                  ((a) >= (b) ? (a) : (b))

typedef int8_t   i8;
typedef uint8_t  u8;
typedef int16_t  i16;
typedef uint32_t u32;
typedef int32_t  i32;
typedef int64_t  i64;
typedef uint64_t u64;

static const u8 zero[128] = {0};

static size_t gap(size_t x, size_t pow_2)
{
	return (~x + 1) & (pow_2 - 1);
}

static u32 load24_le(const u8 s[3])
{
	return
		((u32)s[0] <<  0) |
		((u32)s[1] <<  8) |
		((u32)s[2] << 16);
}

static u32 load32_le(const u8 s[4])
{
	return
		((u32)s[0] <<  0) |
		((u32)s[1] <<  8) |
		((u32)s[2] << 16) |
		((u32)s[3] << 24);
}

static u64 load64_le(const u8 s[8])
{
	return load32_le(s) | ((u64)load32_le(s+4) << 32);
}

static void store32_le(u8 out[4], u32 in)
{
	out[0] = (u8)(in      );
	out[1] = (u8)(in >>  8);
	out[2] = (u8)(in >> 16);
	out[3] = (u8)(in >> 24);
}

static void store64_le(u8 out[8], u64 in)
{
	store32_le(out    , (u32)(in      ));
	store32_le(out + 4, (u32)(in >> 32));
}

static void load32_le_buf (u32 *dst, const u8 *src, size_t size) {
	FOR(i, 0, size) { dst[i] = load32_le(src + i*4); }
}
static void load64_le_buf (u64 *dst, const u8 *src, size_t size) {
	FOR(i, 0, size) { dst[i] = load64_le(src + i*8); }
}
static void store32_le_buf(u8 *dst, const u32 *src, size_t size) {
	FOR(i, 0, size) { store32_le(dst + i*4, src[i]); }
}
static void store64_le_buf(u8 *dst, const u64 *src, size_t size) {
	FOR(i, 0, size) { store64_le(dst + i*8, src[i]); }
}

static u64 rotr64(u64 x, u64 n) { return (x >> n) ^ (x << (64 - n)); }
static u32 rotl32(u32 x, u32 n) { return (x << n) ^ (x >> (32 - n)); }

static int neq0(u64 diff)
{

	u64 half = (diff >> 32) | ((u32)diff);
	u64 eq0  = 1 & ((half - 1) >> 32);
	return (int)eq0 - 1;
}

static u64 x16(const u8 a[16], const u8 b[16])
{
	return (load64_le(a + 0) ^ load64_le(b + 0))
		|  (load64_le(a + 8) ^ load64_le(b + 8));
}
static u64 x32(const u8 a[32],const u8 b[32]){return x16(a,b)| x16(a+16, b+16);}
static u64 x64(const u8 a[64],const u8 b[64]){return x32(a,b)| x32(a+32, b+32);}
int crypto_verify16(const u8 a[16], const u8 b[16]){ return neq0(x16(a, b)); }
int crypto_verify32(const u8 a[32], const u8 b[32]){ return neq0(x32(a, b)); }
int crypto_verify64(const u8 a[64], const u8 b[64]){ return neq0(x64(a, b)); }

void crypto_wipe(void *secret, size_t size)
{
	volatile u8 *v_secret = (u8*)secret;
	ZERO(v_secret, size);
}

#define QUARTERROUND(a, b, c, d)	\
	a += b;  d = rotl32(d ^ a, 16); \
	c += d;  b = rotl32(b ^ c, 12); \
	a += b;  d = rotl32(d ^ a,  8); \
	c += d;  b = rotl32(b ^ c,  7)

static void chacha20_rounds(u32 out[16], const u32 in[16])
{

	u32 t0  = in[ 0];  u32 t1  = in[ 1];  u32 t2  = in[ 2];  u32 t3  = in[ 3];
	u32 t4  = in[ 4];  u32 t5  = in[ 5];  u32 t6  = in[ 6];  u32 t7  = in[ 7];
	u32 t8  = in[ 8];  u32 t9  = in[ 9];  u32 t10 = in[10];  u32 t11 = in[11];
	u32 t12 = in[12];  u32 t13 = in[13];  u32 t14 = in[14];  u32 t15 = in[15];

	FOR (i, 0, 10) {
		QUARTERROUND(t0, t4, t8 , t12);
		QUARTERROUND(t1, t5, t9 , t13);
		QUARTERROUND(t2, t6, t10, t14);
		QUARTERROUND(t3, t7, t11, t15);
		QUARTERROUND(t0, t5, t10, t15);
		QUARTERROUND(t1, t6, t11, t12);
		QUARTERROUND(t2, t7, t8 , t13);
		QUARTERROUND(t3, t4, t9 , t14);
	}
	out[ 0] = t0;   out[ 1] = t1;   out[ 2] = t2;   out[ 3] = t3;
	out[ 4] = t4;   out[ 5] = t5;   out[ 6] = t6;   out[ 7] = t7;
	out[ 8] = t8;   out[ 9] = t9;   out[10] = t10;  out[11] = t11;
	out[12] = t12;  out[13] = t13;  out[14] = t14;  out[15] = t15;
}

#if defined(__ARM_NEON__) || defined(__ARM_NEON)

void awg_chacha20_neon_blocks(u8 *out, const u8 *in, size_t nb_blocks, u32 state[16]);
#endif

static const u8 *chacha20_constant = (const u8*)"expand 32-byte k";

void crypto_chacha20_h(u8 out[32], const u8 key[32], const u8 in [16])
{
	u32 block[16];
	load32_le_buf(block     , chacha20_constant, 4);
	load32_le_buf(block +  4, key              , 8);
	load32_le_buf(block + 12, in               , 4);

	chacha20_rounds(block, block);

	store32_le_buf(out   , block   , 4);
	store32_le_buf(out+16, block+12, 4);
	WIPE_BUFFER(block);
}

u64 crypto_chacha20_djb(u8 *cipher_text, const u8 *plain_text,
                        size_t text_size, const u8 key[32], const u8 nonce[8],
                        u64 ctr)
{
	u32 input[16];
	load32_le_buf(input     , chacha20_constant, 4);
	load32_le_buf(input +  4, key              , 8);
	load32_le_buf(input + 14, nonce            , 2);
	input[12] = (u32) ctr;
	input[13] = (u32)(ctr >> 32);

	u32    pool[16];
	size_t nb_blocks = text_size >> 6;
#if defined(__ARM_NEON__) || defined(__ARM_NEON)

	if (nb_blocks > 0) {
		awg_chacha20_neon_blocks(cipher_text, plain_text, nb_blocks, input);
		cipher_text += nb_blocks << 6;
		if (plain_text != NULL) {
			plain_text += nb_blocks << 6;
		}
		nb_blocks = 0;
	}
#endif
	FOR (i, 0, nb_blocks) {
		chacha20_rounds(pool, input);
		if (plain_text != NULL) {
			FOR (j, 0, 16) {
				u32 p = pool[j] + input[j];
				store32_le(cipher_text, p ^ load32_le(plain_text));
				cipher_text += 4;
				plain_text  += 4;
			}
		} else {
			FOR (j, 0, 16) {
				u32 p = pool[j] + input[j];
				store32_le(cipher_text, p);
				cipher_text += 4;
			}
		}
		input[12]++;
		if (input[12] == 0) {
			input[13]++;
		}
	}
	text_size &= 63;

	if (text_size > 0) {
		if (plain_text == NULL) {
			plain_text = zero;
		}
		chacha20_rounds(pool, input);
		u8 tmp[64];
		FOR (i, 0, 16) {
			store32_le(tmp + i*4, pool[i] + input[i]);
		}
		FOR (i, 0, text_size) {
			cipher_text[i] = tmp[i] ^ plain_text[i];
		}
		WIPE_BUFFER(tmp);
	}
	ctr = input[12] + ((u64)input[13] << 32) + (text_size > 0);

	WIPE_BUFFER(pool);
	WIPE_BUFFER(input);
	return ctr;
}

u32 crypto_chacha20_ietf(u8 *cipher_text, const u8 *plain_text,
                         size_t text_size,
                         const u8 key[32], const u8 nonce[12], u32 ctr)
{
	u64 big_ctr = ctr + ((u64)load32_le(nonce) << 32);
	return (u32)crypto_chacha20_djb(cipher_text, plain_text, text_size,
	                                key, nonce + 4, big_ctr);
}

u64 crypto_chacha20_x(u8 *cipher_text, const u8 *plain_text,
                      size_t text_size,
                      const u8 key[32], const u8 nonce[24], u64 ctr)
{
	u8 sub_key[32];
	crypto_chacha20_h(sub_key, key, nonce);
	ctr = crypto_chacha20_djb(cipher_text, plain_text, text_size,
	                          sub_key, nonce + 16, ctr);
	WIPE_BUFFER(sub_key);
	return ctr;
}

static void poly_blocks(crypto_poly1305_ctx *ctx, const u8 *in,
                        size_t nb_blocks, unsigned end)
{

	const u32 r0 = ctx->r[0];
	const u32 r1 = ctx->r[1];
	const u32 r2 = ctx->r[2];
	const u32 r3 = ctx->r[3];
	const u32 rr0 = (r0 >> 2) * 5;
	const u32 rr1 = (r1 >> 2) + r1;
	const u32 rr2 = (r2 >> 2) + r2;
	const u32 rr3 = (r3 >> 2) + r3;
	const u32 rr4 = r0 & 3;
	u32 h0 = ctx->h[0];
	u32 h1 = ctx->h[1];
	u32 h2 = ctx->h[2];
	u32 h3 = ctx->h[3];
	u32 h4 = ctx->h[4];

	FOR (i, 0, nb_blocks) {

		const u64 s0 = (u64)h0 + load32_le(in);  in += 4;
		const u64 s1 = (u64)h1 + load32_le(in);  in += 4;
		const u64 s2 = (u64)h2 + load32_le(in);  in += 4;
		const u64 s3 = (u64)h3 + load32_le(in);  in += 4;
		const u32 s4 =      h4 + end;

		const u64 x0 = s0*r0+ s1*rr3+ s2*rr2+ s3*rr1+ s4*rr0;
		const u64 x1 = s0*r1+ s1*r0 + s2*rr3+ s3*rr2+ s4*rr1;
		const u64 x2 = s0*r2+ s1*r1 + s2*r0 + s3*rr3+ s4*rr2;
		const u64 x3 = s0*r3+ s1*r2 + s2*r1 + s3*r0 + s4*rr3;
		const u32 x4 =                                s4*rr4;

		const u32 u5 = (u32)(x3 >> 32) + x4;
		const u64 u0 = (u32)(u5 >>  2) * 5 + (x0 & 0xffffffff);
		const u64 u1 = (u32)(u0 >> 32)     + (x1 & 0xffffffff) + (x0 >> 32);
		const u64 u2 = (u32)(u1 >> 32)     + (x2 & 0xffffffff) + (x1 >> 32);
		const u64 u3 = (u32)(u2 >> 32)     + (x3 & 0xffffffff) + (x2 >> 32);
		const u32 u4 = (u32)(u3 >> 32)     + (u5 & 3);

		h0 = u0 & 0xffffffff;
		h1 = u1 & 0xffffffff;
		h2 = u2 & 0xffffffff;
		h3 = u3 & 0xffffffff;
		h4 = u4;
	}
	ctx->h[0] = h0;
	ctx->h[1] = h1;
	ctx->h[2] = h2;
	ctx->h[3] = h3;
	ctx->h[4] = h4;
}

void crypto_poly1305_init(crypto_poly1305_ctx *ctx, const u8 key[32])
{
	ZERO(ctx->h, 5);
	ctx->c_idx = 0;

	load32_le_buf(ctx->r  , key   , 4);
	load32_le_buf(ctx->pad, key+16, 4);
	FOR (i, 0, 1) { ctx->r[i] &= 0x0fffffff; }
	FOR (i, 1, 4) { ctx->r[i] &= 0x0ffffffc; }
}

void crypto_poly1305_update(crypto_poly1305_ctx *ctx,
                            const u8 *message, size_t message_size)
{

	if (message_size == 0) {
		return;
	}

	size_t aligned = MIN(gap(ctx->c_idx, 16), message_size);
	FOR (i, 0, aligned) {
		ctx->c[ctx->c_idx] = *message;
		ctx->c_idx++;
		message++;
		message_size--;
	}

	if (ctx->c_idx == 16) {
		poly_blocks(ctx, ctx->c, 1, 1);
		ctx->c_idx = 0;
	}

	size_t nb_blocks = message_size >> 4;
	poly_blocks(ctx, message, nb_blocks, 1);
	message      += nb_blocks << 4;
	message_size &= 15;

	FOR (i, 0, message_size) {
		ctx->c[ctx->c_idx] = message[i];
		ctx->c_idx++;
	}
}

void crypto_poly1305_final(crypto_poly1305_ctx *ctx, u8 mac[16])
{

	if (ctx->c_idx != 0) {
		ZERO(ctx->c + ctx->c_idx, 16 - ctx->c_idx);
		ctx->c[ctx->c_idx] = 1;
		poly_blocks(ctx, ctx->c, 1, 0);
	}

	u64 c = 5;
	FOR (i, 0, 4) {
		c  += ctx->h[i];
		c >>= 32;
	}
	c += ctx->h[4];
	c  = (c >> 2) * 5;

	FOR (i, 0, 4) {
		c += (u64)ctx->h[i] + ctx->pad[i];
		store32_le(mac + i*4, (u32)c);
		c = c >> 32;
	}
	WIPE_CTX(ctx);
}

void crypto_poly1305(u8     mac[16],  const u8 *message,
                     size_t message_size, const u8  key[32])
{
	crypto_poly1305_ctx ctx;
	crypto_poly1305_init  (&ctx, key);
	crypto_poly1305_update(&ctx, message, message_size);
	crypto_poly1305_final (&ctx, mac);
}

static const u64 iv[8] = {
	0x6a09e667f3bcc908, 0xbb67ae8584caa73b,
	0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
	0x510e527fade682d1, 0x9b05688c2b3e6c1f,
	0x1f83d9abfb41bd6b, 0x5be0cd19137e2179,
};

static void blake2b_compress(crypto_blake2b_ctx *ctx, int is_last_block)
{
	static const u8 sigma[12][16] = {
		{  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15 },
		{ 14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3 },
		{ 11,  8, 12,  0,  5,  2, 15, 13, 10, 14,  3,  6,  7,  1,  9,  4 },
		{  7,  9,  3,  1, 13, 12, 11, 14,  2,  6,  5, 10,  4,  0, 15,  8 },
		{  9,  0,  5,  7,  2,  4, 10, 15, 14,  1, 11, 12,  6,  8,  3, 13 },
		{  2, 12,  6, 10,  0, 11,  8,  3,  4, 13,  7,  5, 15, 14,  1,  9 },
		{ 12,  5,  1, 15, 14, 13,  4, 10,  0,  7,  6,  3,  9,  2,  8, 11 },
		{ 13, 11,  7, 14, 12,  1,  3,  9,  5,  0, 15,  4,  8,  6,  2, 10 },
		{  6, 15, 14,  9, 11,  3,  0,  8, 12,  2, 13,  7,  1,  4, 10,  5 },
		{ 10,  2,  8,  4,  7,  6,  1,  5, 15, 11,  9, 14,  3, 12, 13,  0 },
		{  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15 },
		{ 14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3 },
	};

	u64   *x = ctx->input_offset;
	size_t y = ctx->input_idx;
	x[0] += y;
	if (x[0] < y) {
		x[1]++;
	}

	u64 v0 = ctx->hash[0];  u64 v8  = iv[0];
	u64 v1 = ctx->hash[1];  u64 v9  = iv[1];
	u64 v2 = ctx->hash[2];  u64 v10 = iv[2];
	u64 v3 = ctx->hash[3];  u64 v11 = iv[3];
	u64 v4 = ctx->hash[4];  u64 v12 = iv[4] ^ ctx->input_offset[0];
	u64 v5 = ctx->hash[5];  u64 v13 = iv[5] ^ ctx->input_offset[1];
	u64 v6 = ctx->hash[6];  u64 v14 = iv[6] ^ (u64)~(is_last_block - 1);
	u64 v7 = ctx->hash[7];  u64 v15 = iv[7];

	u64 *input = ctx->input;
#define BLAKE2_G(a, b, c, d, x, y)	\
	a += b + x;  d = rotr64(d ^ a, 32); \
	c += d;      b = rotr64(b ^ c, 24); \
	a += b + y;  d = rotr64(d ^ a, 16); \
	c += d;      b = rotr64(b ^ c, 63)
#define BLAKE2_ROUND(i)	\
	BLAKE2_G(v0, v4, v8 , v12, input[sigma[i][ 0]], input[sigma[i][ 1]]); \
	BLAKE2_G(v1, v5, v9 , v13, input[sigma[i][ 2]], input[sigma[i][ 3]]); \
	BLAKE2_G(v2, v6, v10, v14, input[sigma[i][ 4]], input[sigma[i][ 5]]); \
	BLAKE2_G(v3, v7, v11, v15, input[sigma[i][ 6]], input[sigma[i][ 7]]); \
	BLAKE2_G(v0, v5, v10, v15, input[sigma[i][ 8]], input[sigma[i][ 9]]); \
	BLAKE2_G(v1, v6, v11, v12, input[sigma[i][10]], input[sigma[i][11]]); \
	BLAKE2_G(v2, v7, v8 , v13, input[sigma[i][12]], input[sigma[i][13]]); \
	BLAKE2_G(v3, v4, v9 , v14, input[sigma[i][14]], input[sigma[i][15]])

#ifdef BLAKE2_NO_UNROLLING
	FOR (i, 0, 12) {
		BLAKE2_ROUND(i);
	}
#else
	BLAKE2_ROUND(0);  BLAKE2_ROUND(1);  BLAKE2_ROUND(2);  BLAKE2_ROUND(3);
	BLAKE2_ROUND(4);  BLAKE2_ROUND(5);  BLAKE2_ROUND(6);  BLAKE2_ROUND(7);
	BLAKE2_ROUND(8);  BLAKE2_ROUND(9);  BLAKE2_ROUND(10); BLAKE2_ROUND(11);
#endif

	ctx->hash[0] ^= v0 ^ v8;   ctx->hash[1] ^= v1 ^ v9;
	ctx->hash[2] ^= v2 ^ v10;  ctx->hash[3] ^= v3 ^ v11;
	ctx->hash[4] ^= v4 ^ v12;  ctx->hash[5] ^= v5 ^ v13;
	ctx->hash[6] ^= v6 ^ v14;  ctx->hash[7] ^= v7 ^ v15;
}

void crypto_blake2b_keyed_init(crypto_blake2b_ctx *ctx, size_t hash_size,
                               const u8 *key, size_t key_size)
{

	COPY(ctx->hash, iv, 8);
	ctx->hash[0] ^= 0x01010000 ^ (key_size << 8) ^ hash_size;

	ctx->input_offset[0] = 0;
	ctx->input_offset[1] = 0;
	ctx->hash_size       = hash_size;
	ctx->input_idx       = 0;
	ZERO(ctx->input, 16);

	if (key_size > 0) {
		u8 key_block[128] = {0};
		COPY(key_block, key, key_size);

		load64_le_buf(ctx->input, key_block, 16);
		ctx->input_idx = 128;
		WIPE_BUFFER(key_block);
	}
}

void crypto_blake2b_init(crypto_blake2b_ctx *ctx, size_t hash_size)
{
	crypto_blake2b_keyed_init(ctx, hash_size, 0, 0);
}

void crypto_blake2b_update(crypto_blake2b_ctx *ctx,
                           const u8 *message, size_t message_size)
{

	if (message_size == 0) {
		return;
	}

	if ((ctx->input_idx & 7) != 0) {
		size_t nb_bytes = MIN(gap(ctx->input_idx, 8), message_size);
		size_t word     = ctx->input_idx >> 3;
		size_t byte     = ctx->input_idx & 7;
		FOR (i, 0, nb_bytes) {
			ctx->input[word] |= (u64)message[i] << ((byte + i) << 3);
		}
		ctx->input_idx += nb_bytes;
		message        += nb_bytes;
		message_size   -= nb_bytes;
	}

	if ((ctx->input_idx & 127) != 0) {
		size_t nb_words = MIN(gap(ctx->input_idx, 128), message_size) >> 3;
		load64_le_buf(ctx->input + (ctx->input_idx >> 3), message, nb_words);
		ctx->input_idx += nb_words << 3;
		message        += nb_words << 3;
		message_size   -= nb_words << 3;
	}

	size_t nb_blocks = message_size >> 7;
	FOR (i, 0, nb_blocks) {
		if (ctx->input_idx == 128) {
			blake2b_compress(ctx, 0);
		}
		load64_le_buf(ctx->input, message, 16);
		message += 128;
		ctx->input_idx = 128;
	}
	message_size &= 127;

	if (message_size != 0) {

		if (ctx->input_idx == 128) {
			blake2b_compress(ctx, 0);
			ctx->input_idx = 0;
		}
		if (ctx->input_idx == 0) {
			ZERO(ctx->input, 16);
		}

		size_t nb_words = message_size >> 3;
		load64_le_buf(ctx->input, message, nb_words);
		ctx->input_idx += nb_words << 3;
		message        += nb_words << 3;
		message_size   -= nb_words << 3;

		FOR (i, 0, message_size) {
			size_t word = ctx->input_idx >> 3;
			size_t byte = ctx->input_idx & 7;
			ctx->input[word] |= (u64)message[i] << (byte << 3);
			ctx->input_idx++;
		}
	}
}

void crypto_blake2b_final(crypto_blake2b_ctx *ctx, u8 *hash)
{
	blake2b_compress(ctx, 1);
	size_t hash_size = MIN(ctx->hash_size, 64);
	size_t nb_words  = hash_size >> 3;
	store64_le_buf(hash, ctx->hash, nb_words);
	FOR (i, nb_words << 3, hash_size) {
		hash[i] = (ctx->hash[i >> 3] >> (8 * (i & 7))) & 0xff;
	}
	WIPE_CTX(ctx);
}

void crypto_blake2b_keyed(u8 *hash,          size_t hash_size,
                          const u8 *key,     size_t key_size,
                          const u8 *message, size_t message_size)
{
	crypto_blake2b_ctx ctx;
	crypto_blake2b_keyed_init(&ctx, hash_size, key, key_size);
	crypto_blake2b_update    (&ctx, message, message_size);
	crypto_blake2b_final     (&ctx, hash);
}

void crypto_blake2b(u8 *hash, size_t hash_size, const u8 *msg, size_t msg_size)
{
	crypto_blake2b_keyed(hash, hash_size, 0, 0, msg, msg_size);
}

typedef struct { u64 a[128]; } blk;

static void blake_update_32(crypto_blake2b_ctx *ctx, u32 input)
{
	u8 buf[4];
	store32_le(buf, input);
	crypto_blake2b_update(ctx, buf, 4);
	WIPE_BUFFER(buf);
}

static void blake_update_32_buf(crypto_blake2b_ctx *ctx,
                                const u8 *buf, u32 size)
{
	blake_update_32(ctx, size);
	crypto_blake2b_update(ctx, buf, size);
}

static void copy_block(blk *o,const blk*in){FOR(i, 0, 128) o->a[i]  = in->a[i];}
static void  xor_block(blk *o,const blk*in){FOR(i, 0, 128) o->a[i] ^= in->a[i];}

static void extended_hash(u8       *digest, u32 digest_size,
                          const u8 *input , u32 input_size)
{
	crypto_blake2b_ctx ctx;
	crypto_blake2b_init  (&ctx, MIN(digest_size, 64));
	blake_update_32      (&ctx, digest_size);
	crypto_blake2b_update(&ctx, input, input_size);
	crypto_blake2b_final (&ctx, digest);

	if (digest_size > 64) {

		u32 r   = (u32)(((u64)digest_size + 31) >> 5) - 2;
		u32 i   =  1;
		u32 in  =  0;
		u32 out = 32;
		while (i < r) {

			crypto_blake2b(digest + out, 64, digest + in, 64);
			i   +=  1;
			in  += 32;
			out += 32;
		}
		crypto_blake2b(digest + out, digest_size - (32 * r), digest + in , 64);
	}
}

#define LSB(x) ((u64)(u32)x)
#define G(a, b, c, d)	\
	a += b + ((LSB(a) * LSB(b)) << 1);  d ^= a;  d = rotr64(d, 32); \
	c += d + ((LSB(c) * LSB(d)) << 1);  b ^= c;  b = rotr64(b, 24); \
	a += b + ((LSB(a) * LSB(b)) << 1);  d ^= a;  d = rotr64(d, 16); \
	c += d + ((LSB(c) * LSB(d)) << 1);  b ^= c;  b = rotr64(b, 63)
#define ROUND(v0,  v1,  v2,  v3,  v4,  v5,  v6,  v7,	\
              v8,  v9, v10, v11, v12, v13, v14, v15)	\
	G(v0, v4,  v8, v12);  G(v1, v5,  v9, v13); \
	G(v2, v6, v10, v14);  G(v3, v7, v11, v15); \
	G(v0, v5, v10, v15);  G(v1, v6, v11, v12); \
	G(v2, v7,  v8, v13);  G(v3, v4,  v9, v14)

static void g_rounds(blk *b)
{

	for (int i = 0; i < 128; i += 16) {
		ROUND(b->a[i   ], b->a[i+ 1], b->a[i+ 2], b->a[i+ 3],
		      b->a[i+ 4], b->a[i+ 5], b->a[i+ 6], b->a[i+ 7],
		      b->a[i+ 8], b->a[i+ 9], b->a[i+10], b->a[i+11],
		      b->a[i+12], b->a[i+13], b->a[i+14], b->a[i+15]);
	}

	for (int i = 0; i < 16; i += 2) {
		ROUND(b->a[i   ], b->a[i+ 1], b->a[i+ 16], b->a[i+ 17],
		      b->a[i+32], b->a[i+33], b->a[i+ 48], b->a[i+ 49],
		      b->a[i+64], b->a[i+65], b->a[i+ 80], b->a[i+ 81],
		      b->a[i+96], b->a[i+97], b->a[i+112], b->a[i+113]);
	}
}

const crypto_argon2_extras crypto_argon2_no_extras = { 0, 0, 0, 0 };

void crypto_argon2(u8 *hash, u32 hash_size, void *work_area,
                   crypto_argon2_config config,
                   crypto_argon2_inputs inputs,
                   crypto_argon2_extras extras)
{
	const u32 segment_size = config.nb_blocks / config.nb_lanes / 4;
	const u32 lane_size    = segment_size * 4;
	const u32 nb_blocks    = lane_size * config.nb_lanes;

	blk *blocks = (blk*)work_area;
	{
		u8 initial_hash[72];
		crypto_blake2b_ctx ctx;
		crypto_blake2b_init (&ctx, 64);
		blake_update_32     (&ctx, config.nb_lanes );
		blake_update_32     (&ctx, hash_size);
		blake_update_32     (&ctx, config.nb_blocks);
		blake_update_32     (&ctx, config.nb_passes);
		blake_update_32     (&ctx, 0x13);
		blake_update_32     (&ctx, config.algorithm);
		blake_update_32_buf (&ctx, inputs.pass, inputs.pass_size);
		blake_update_32_buf (&ctx, inputs.salt, inputs.salt_size);
		blake_update_32_buf (&ctx, extras.key,  extras.key_size);
		blake_update_32_buf (&ctx, extras.ad,   extras.ad_size);
		crypto_blake2b_final(&ctx, initial_hash);

		u8 hash_area[1024];
		FOR_T(u32, l, 0, config.nb_lanes) {
			FOR_T(u32, i, 0, 2) {
				store32_le(initial_hash + 64, i);
				store32_le(initial_hash + 68, l);
				extended_hash(hash_area, 1024, initial_hash, 72);
				load64_le_buf(blocks[l * lane_size + i].a, hash_area, 128);
			}
		}

		WIPE_BUFFER(initial_hash);
		WIPE_BUFFER(hash_area);
	}

	int constant_time = config.algorithm != CRYPTO_ARGON2_D;

	blk tmp;
	FOR_T(u32, pass, 0, config.nb_passes) {
		FOR_T(u32, slice, 0, 4) {

			u32 pass_offset  = pass == 0 && slice == 0 ? 2 : 0;
			u32 slice_offset = slice * segment_size;

			if (slice == 2 && config.algorithm == CRYPTO_ARGON2_ID) {
				constant_time = 0;
			}

			FOR_T(u32, segment, 0, config.nb_lanes) {
				blk index_block;
				u32 index_ctr = 1;
				FOR_T (u32, block, pass_offset, segment_size) {

					u32  lane_offset   = segment * lane_size;
					blk *segment_start = blocks + lane_offset + slice_offset;
					blk *current       = segment_start + block;
					blk *previous      =
						block == 0 && slice_offset == 0
						? segment_start + lane_size - 1
						: segment_start + block - 1;

					u64 index_seed;
					if (constant_time) {
						if (block == pass_offset || (block % 128) == 0) {

							ZERO(index_block.a, 128);
							index_block.a[0] = pass;
							index_block.a[1] = segment;
							index_block.a[2] = slice;
							index_block.a[3] = nb_blocks;
							index_block.a[4] = config.nb_passes;
							index_block.a[5] = config.algorithm;
							index_block.a[6] = index_ctr;
							index_ctr++;

							copy_block(&tmp, &index_block);
							g_rounds  (&index_block);
							xor_block (&index_block, &tmp);
							copy_block(&tmp, &index_block);
							g_rounds  (&index_block);
							xor_block (&index_block, &tmp);
						}
						index_seed = index_block.a[block % 128];
					} else {
						index_seed = previous->a[0];
					}

					u32 next_slice   = ((slice + 1) % 4) * segment_size;
					u32 window_start = pass == 0 ? 0     : next_slice;
					u32 nb_segments  = pass == 0 ? slice : 3;
					u32 lane         =
						pass == 0 && slice == 0
						? segment
						: (u32)(index_seed >> 32) % config.nb_lanes;
					u32 window_size  =
						nb_segments * segment_size +
						(lane  == segment ? block-1 :
						 block == 0       ? (u32)-1 : 0);

					u64  j1        = index_seed & 0xffffffff;
					u64  x         = (j1 * j1)         >> 32;
					u64  y         = (window_size * x) >> 32;
					u64  z         = (window_size - 1) - y;
					u32  ref       = (u32)((window_start + z) % lane_size);
					u32  index     = lane * lane_size + ref;
					blk *reference = blocks + index;

					copy_block(&tmp, previous);
					xor_block (&tmp, reference);
					if (pass == 0) { copy_block(current, &tmp); }
					else           { xor_block (current, &tmp); }
					g_rounds  (&tmp);
					xor_block (current, &tmp);
				}
			}
		}
	}

	volatile u64* p = tmp.a;
	ZERO(p, 128);

	blk *last_block = blocks + lane_size - 1;
	FOR_T (u32, lane, 1, config.nb_lanes) {
		blk *next_block = last_block + lane_size;
		xor_block(next_block, last_block);
		last_block = next_block;
	}

	u8 final_block[1024];
	store64_le_buf(final_block, last_block->a, 128);

	p = (u64*)work_area;
	ZERO(p, 128 * nb_blocks);

	extended_hash(hash, hash_size, final_block, 1024);
	WIPE_BUFFER(final_block);
}

typedef i32 fe[10];

static const fe fe_one  = {1};
static const fe sqrtm1  = {
	-32595792, -7943725, 9377950, 3500415, 12389472,
	-272473, -25146209, -2005654, 326686, 11406482,
};
static const fe d       = {
	-10913610, 13857413, -15372611, 6949391, 114729,
	-8787816, -6275908, -3247719, -18696448, -12055116,
};
static const fe D2      = {
	-21827239, -5839606, -30745221, 13898782, 229458,
	15978800, -12551817, -6495438, 29715968, 9444199,
};
static const fe lop_x   = {
	21352778, 5345713, 4660180, -8347857, 24143090,
	14568123, 30185756, -12247770, -33528939, 8345319,
};
static const fe lop_y   = {
	-6952922, -1265500, 6862341, -7057498, -4037696,
	-5447722, 31680899, -15325402, -19365852, 1569102,
};
static const fe ufactor = {
	-1917299, 15887451, -18755900, -7000830, -24778944,
	544946, -16816446, 4011309, -653372, 10741468,
};
static const fe A2      = {
	12721188, 3529, 0, 0, 0, 0, 0, 0, 0, 0,
};

static void fe_0(fe h) {           ZERO(h  , 10); }
static void fe_1(fe h) { h[0] = 1; ZERO(h+1,  9); }

static void fe_copy(fe h,const fe f           ){FOR(i,0,10) h[i] =  f[i];      }
static void fe_neg (fe h,const fe f           ){FOR(i,0,10) h[i] = -f[i];      }
static void fe_add (fe h,const fe f,const fe g){FOR(i,0,10) h[i] = f[i] + g[i];}
static void fe_sub (fe h,const fe f,const fe g){FOR(i,0,10) h[i] = f[i] - g[i];}

static void fe_cswap(fe f, fe g, int b)
{
	volatile i32 mask = -b;
	i32 x0 = (f[0] ^ g[0]) & mask;    f[0] = f[0] ^ x0;    g[0] = g[0] ^ x0;
	i32 x1 = (f[1] ^ g[1]) & mask;    f[1] = f[1] ^ x1;    g[1] = g[1] ^ x1;
	i32 x2 = (f[2] ^ g[2]) & mask;    f[2] = f[2] ^ x2;    g[2] = g[2] ^ x2;
	i32 x3 = (f[3] ^ g[3]) & mask;    f[3] = f[3] ^ x3;    g[3] = g[3] ^ x3;
	i32 x4 = (f[4] ^ g[4]) & mask;    f[4] = f[4] ^ x4;    g[4] = g[4] ^ x4;
	i32 x5 = (f[5] ^ g[5]) & mask;    f[5] = f[5] ^ x5;    g[5] = g[5] ^ x5;
	i32 x6 = (f[6] ^ g[6]) & mask;    f[6] = f[6] ^ x6;    g[6] = g[6] ^ x6;
	i32 x7 = (f[7] ^ g[7]) & mask;    f[7] = f[7] ^ x7;    g[7] = g[7] ^ x7;
	i32 x8 = (f[8] ^ g[8]) & mask;    f[8] = f[8] ^ x8;    g[8] = g[8] ^ x8;
	i32 x9 = (f[9] ^ g[9]) & mask;    f[9] = f[9] ^ x9;    g[9] = g[9] ^ x9;
}

static void fe_ccopy(fe f, const fe g, int b)
{
	volatile i32 mask = -b;
	i32 x0 = (f[0] ^ g[0]) & mask;    f[0] = f[0] ^ x0;
	i32 x1 = (f[1] ^ g[1]) & mask;    f[1] = f[1] ^ x1;
	i32 x2 = (f[2] ^ g[2]) & mask;    f[2] = f[2] ^ x2;
	i32 x3 = (f[3] ^ g[3]) & mask;    f[3] = f[3] ^ x3;
	i32 x4 = (f[4] ^ g[4]) & mask;    f[4] = f[4] ^ x4;
	i32 x5 = (f[5] ^ g[5]) & mask;    f[5] = f[5] ^ x5;
	i32 x6 = (f[6] ^ g[6]) & mask;    f[6] = f[6] ^ x6;
	i32 x7 = (f[7] ^ g[7]) & mask;    f[7] = f[7] ^ x7;
	i32 x8 = (f[8] ^ g[8]) & mask;    f[8] = f[8] ^ x8;
	i32 x9 = (f[9] ^ g[9]) & mask;    f[9] = f[9] ^ x9;
}

#define FE_CARRY	\
	i64 c; \
	c = (t0 + ((i64)1<<25)) >> 26;  t0 -= c * ((i64)1 << 26);  t1 += c; \
	c = (t4 + ((i64)1<<25)) >> 26;  t4 -= c * ((i64)1 << 26);  t5 += c; \
	c = (t1 + ((i64)1<<24)) >> 25;  t1 -= c * ((i64)1 << 25);  t2 += c; \
	c = (t5 + ((i64)1<<24)) >> 25;  t5 -= c * ((i64)1 << 25);  t6 += c; \
	c = (t2 + ((i64)1<<25)) >> 26;  t2 -= c * ((i64)1 << 26);  t3 += c; \
	c = (t6 + ((i64)1<<25)) >> 26;  t6 -= c * ((i64)1 << 26);  t7 += c; \
	c = (t3 + ((i64)1<<24)) >> 25;  t3 -= c * ((i64)1 << 25);  t4 += c; \
	c = (t7 + ((i64)1<<24)) >> 25;  t7 -= c * ((i64)1 << 25);  t8 += c; \
	c = (t4 + ((i64)1<<25)) >> 26;  t4 -= c * ((i64)1 << 26);  t5 += c; \
	c = (t8 + ((i64)1<<25)) >> 26;  t8 -= c * ((i64)1 << 26);  t9 += c; \
	c = (t9 + ((i64)1<<24)) >> 25;  t9 -= c * ((i64)1 << 25);  t0 += c * 19; \
	c = (t0 + ((i64)1<<25)) >> 26;  t0 -= c * ((i64)1 << 26);  t1 += c; \
	h[0]=(i32)t0;  h[1]=(i32)t1;  h[2]=(i32)t2;  h[3]=(i32)t3;  h[4]=(i32)t4; \
	h[5]=(i32)t5;  h[6]=(i32)t6;  h[7]=(i32)t7;  h[8]=(i32)t8;  h[9]=(i32)t9

static void fe_frombytes_mask(fe h, const u8 s[32], unsigned nb_mask)
{
	u32 mask = 0xffffff >> nb_mask;
	i64 t0 =  load32_le(s);
	i64 t1 =  load24_le(s +  4) << 6;
	i64 t2 =  load24_le(s +  7) << 5;
	i64 t3 =  load24_le(s + 10) << 3;
	i64 t4 =  load24_le(s + 13) << 2;
	i64 t5 =  load32_le(s + 16);
	i64 t6 =  load24_le(s + 20) << 7;
	i64 t7 =  load24_le(s + 23) << 5;
	i64 t8 =  load24_le(s + 26) << 4;
	i64 t9 = (load24_le(s + 29) & mask) << 2;
	FE_CARRY;
}

static void fe_frombytes(fe h, const u8 s[32])
{
	fe_frombytes_mask(h, s, 1);
}

static void fe_tobytes(u8 s[32], const fe h)
{
	i32 t[10];
	COPY(t, h, 10);
	i32 q = (19 * t[9] + (((i32) 1) << 24)) >> 25;

	FOR (i, 0, 5) {
		q += t[2*i  ]; q >>= 26;
		q += t[2*i+1]; q >>= 25;
	}

	q *= 19;
	FOR (i, 0, 5) {
		t[i*2  ] += q;  q = t[i*2  ] >> 26;  t[i*2  ] -= q * ((i32)1 << 26);
		t[i*2+1] += q;  q = t[i*2+1] >> 25;  t[i*2+1] -= q * ((i32)1 << 25);
	}

	store32_le(s +  0, ((u32)t[0] >>  0) | ((u32)t[1] << 26));
	store32_le(s +  4, ((u32)t[1] >>  6) | ((u32)t[2] << 19));
	store32_le(s +  8, ((u32)t[2] >> 13) | ((u32)t[3] << 13));
	store32_le(s + 12, ((u32)t[3] >> 19) | ((u32)t[4] <<  6));
	store32_le(s + 16, ((u32)t[5] >>  0) | ((u32)t[6] << 25));
	store32_le(s + 20, ((u32)t[6] >>  7) | ((u32)t[7] << 19));
	store32_le(s + 24, ((u32)t[7] >> 13) | ((u32)t[8] << 12));
	store32_le(s + 28, ((u32)t[8] >> 20) | ((u32)t[9] <<  6));

	WIPE_BUFFER(t);
}

static void fe_mul_small(fe h, const fe f, i32 g)
{
	i64 t0 = f[0] * (i64) g;  i64 t1 = f[1] * (i64) g;
	i64 t2 = f[2] * (i64) g;  i64 t3 = f[3] * (i64) g;
	i64 t4 = f[4] * (i64) g;  i64 t5 = f[5] * (i64) g;
	i64 t6 = f[6] * (i64) g;  i64 t7 = f[7] * (i64) g;
	i64 t8 = f[8] * (i64) g;  i64 t9 = f[9] * (i64) g;

	FE_CARRY;
}

static void fe_mul(fe h, const fe f, const fe g)
{

	i32 f0 = f[0]; i32 f1 = f[1]; i32 f2 = f[2]; i32 f3 = f[3]; i32 f4 = f[4];
	i32 f5 = f[5]; i32 f6 = f[6]; i32 f7 = f[7]; i32 f8 = f[8]; i32 f9 = f[9];
	i32 g0 = g[0]; i32 g1 = g[1]; i32 g2 = g[2]; i32 g3 = g[3]; i32 g4 = g[4];
	i32 g5 = g[5]; i32 g6 = g[6]; i32 g7 = g[7]; i32 g8 = g[8]; i32 g9 = g[9];
	i32 F1 = f1*2; i32 F3 = f3*2; i32 F5 = f5*2; i32 F7 = f7*2; i32 F9 = f9*2;
	i32 G1 = g1*19;  i32 G2 = g2*19;  i32 G3 = g3*19;
	i32 G4 = g4*19;  i32 G5 = g5*19;  i32 G6 = g6*19;
	i32 G7 = g7*19;  i32 G8 = g8*19;  i32 G9 = g9*19;

	i64 t0 = f0*(i64)g0 + F1*(i64)G9 + f2*(i64)G8 + F3*(i64)G7 + f4*(i64)G6
	       + F5*(i64)G5 + f6*(i64)G4 + F7*(i64)G3 + f8*(i64)G2 + F9*(i64)G1;
	i64 t1 = f0*(i64)g1 + f1*(i64)g0 + f2*(i64)G9 + f3*(i64)G8 + f4*(i64)G7
	       + f5*(i64)G6 + f6*(i64)G5 + f7*(i64)G4 + f8*(i64)G3 + f9*(i64)G2;
	i64 t2 = f0*(i64)g2 + F1*(i64)g1 + f2*(i64)g0 + F3*(i64)G9 + f4*(i64)G8
	       + F5*(i64)G7 + f6*(i64)G6 + F7*(i64)G5 + f8*(i64)G4 + F9*(i64)G3;
	i64 t3 = f0*(i64)g3 + f1*(i64)g2 + f2*(i64)g1 + f3*(i64)g0 + f4*(i64)G9
	       + f5*(i64)G8 + f6*(i64)G7 + f7*(i64)G6 + f8*(i64)G5 + f9*(i64)G4;
	i64 t4 = f0*(i64)g4 + F1*(i64)g3 + f2*(i64)g2 + F3*(i64)g1 + f4*(i64)g0
	       + F5*(i64)G9 + f6*(i64)G8 + F7*(i64)G7 + f8*(i64)G6 + F9*(i64)G5;
	i64 t5 = f0*(i64)g5 + f1*(i64)g4 + f2*(i64)g3 + f3*(i64)g2 + f4*(i64)g1
	       + f5*(i64)g0 + f6*(i64)G9 + f7*(i64)G8 + f8*(i64)G7 + f9*(i64)G6;
	i64 t6 = f0*(i64)g6 + F1*(i64)g5 + f2*(i64)g4 + F3*(i64)g3 + f4*(i64)g2
	       + F5*(i64)g1 + f6*(i64)g0 + F7*(i64)G9 + f8*(i64)G8 + F9*(i64)G7;
	i64 t7 = f0*(i64)g7 + f1*(i64)g6 + f2*(i64)g5 + f3*(i64)g4 + f4*(i64)g3
	       + f5*(i64)g2 + f6*(i64)g1 + f7*(i64)g0 + f8*(i64)G9 + f9*(i64)G8;
	i64 t8 = f0*(i64)g8 + F1*(i64)g7 + f2*(i64)g6 + F3*(i64)g5 + f4*(i64)g4
	       + F5*(i64)g3 + f6*(i64)g2 + F7*(i64)g1 + f8*(i64)g0 + F9*(i64)G9;
	i64 t9 = f0*(i64)g9 + f1*(i64)g8 + f2*(i64)g7 + f3*(i64)g6 + f4*(i64)g5
	       + f5*(i64)g4 + f6*(i64)g3 + f7*(i64)g2 + f8*(i64)g1 + f9*(i64)g0;

	FE_CARRY;
}

static void fe_sq(fe h, const fe f)
{
	i32 f0 = f[0]; i32 f1 = f[1]; i32 f2 = f[2]; i32 f3 = f[3]; i32 f4 = f[4];
	i32 f5 = f[5]; i32 f6 = f[6]; i32 f7 = f[7]; i32 f8 = f[8]; i32 f9 = f[9];
	i32 f0_2  = f0*2;   i32 f1_2  = f1*2;   i32 f2_2  = f2*2;   i32 f3_2 = f3*2;
	i32 f4_2  = f4*2;   i32 f5_2  = f5*2;   i32 f6_2  = f6*2;   i32 f7_2 = f7*2;
	i32 f5_38 = f5*38;  i32 f6_19 = f6*19;  i32 f7_38 = f7*38;
	i32 f8_19 = f8*19;  i32 f9_38 = f9*38;

	i64 t0 = f0  *(i64)f0    + f1_2*(i64)f9_38 + f2_2*(i64)f8_19
	       + f3_2*(i64)f7_38 + f4_2*(i64)f6_19 + f5  *(i64)f5_38;
	i64 t1 = f0_2*(i64)f1    + f2  *(i64)f9_38 + f3_2*(i64)f8_19
	       + f4  *(i64)f7_38 + f5_2*(i64)f6_19;
	i64 t2 = f0_2*(i64)f2    + f1_2*(i64)f1    + f3_2*(i64)f9_38
	       + f4_2*(i64)f8_19 + f5_2*(i64)f7_38 + f6  *(i64)f6_19;
	i64 t3 = f0_2*(i64)f3    + f1_2*(i64)f2    + f4  *(i64)f9_38
	       + f5_2*(i64)f8_19 + f6  *(i64)f7_38;
	i64 t4 = f0_2*(i64)f4    + f1_2*(i64)f3_2  + f2  *(i64)f2
	       + f5_2*(i64)f9_38 + f6_2*(i64)f8_19 + f7  *(i64)f7_38;
	i64 t5 = f0_2*(i64)f5    + f1_2*(i64)f4    + f2_2*(i64)f3
	       + f6  *(i64)f9_38 + f7_2*(i64)f8_19;
	i64 t6 = f0_2*(i64)f6    + f1_2*(i64)f5_2  + f2_2*(i64)f4
	       + f3_2*(i64)f3    + f7_2*(i64)f9_38 + f8  *(i64)f8_19;
	i64 t7 = f0_2*(i64)f7    + f1_2*(i64)f6    + f2_2*(i64)f5
	       + f3_2*(i64)f4    + f8  *(i64)f9_38;
	i64 t8 = f0_2*(i64)f8    + f1_2*(i64)f7_2  + f2_2*(i64)f6
	       + f3_2*(i64)f5_2  + f4  *(i64)f4    + f9  *(i64)f9_38;
	i64 t9 = f0_2*(i64)f9    + f1_2*(i64)f8    + f2_2*(i64)f7
	       + f3_2*(i64)f6    + f4  *(i64)f5_2;

	FE_CARRY;
}

static int fe_isodd(const fe f)
{
	u8 s[32];
	fe_tobytes(s, f);
	u8 isodd = s[0] & 1;
	WIPE_BUFFER(s);
	return isodd;
}

static int fe_isequal(const fe f, const fe g)
{
	u8 fs[32];
	u8 gs[32];
	fe_tobytes(fs, f);
	fe_tobytes(gs, g);
	int isdifferent = crypto_verify32(fs, gs);
	WIPE_BUFFER(fs);
	WIPE_BUFFER(gs);
	return 1 + isdifferent;
}

static int invsqrt(fe isr, const fe x)
{
	fe t0, t1, t2;

	fe_sq(t0, x);
	fe_sq(t1,t0);                     fe_sq(t1, t1);    fe_mul(t1, x, t1);
	fe_mul(t0, t0, t1);
	fe_sq(t0, t0);                                      fe_mul(t0, t1, t0);
	fe_sq(t1, t0);  FOR (i, 1,   5) { fe_sq(t1, t1); }  fe_mul(t0, t1, t0);
	fe_sq(t1, t0);  FOR (i, 1,  10) { fe_sq(t1, t1); }  fe_mul(t1, t1, t0);
	fe_sq(t2, t1);  FOR (i, 1,  20) { fe_sq(t2, t2); }  fe_mul(t1, t2, t1);
	fe_sq(t1, t1);  FOR (i, 1,  10) { fe_sq(t1, t1); }  fe_mul(t0, t1, t0);
	fe_sq(t1, t0);  FOR (i, 1,  50) { fe_sq(t1, t1); }  fe_mul(t1, t1, t0);
	fe_sq(t2, t1);  FOR (i, 1, 100) { fe_sq(t2, t2); }  fe_mul(t1, t2, t1);
	fe_sq(t1, t1);  FOR (i, 1,  50) { fe_sq(t1, t1); }  fe_mul(t0, t1, t0);
	fe_sq(t0, t0);  FOR (i, 1,   2) { fe_sq(t0, t0); }  fe_mul(t0, t0, x);

	i32 *quartic = t1;
	fe_sq (quartic, t0);
	fe_mul(quartic, quartic, x);

	i32 *check = t2;
	fe_0  (check);          int z0 = fe_isequal(x      , check);
	fe_1  (check);          int p1 = fe_isequal(quartic, check);
	fe_neg(check, check );  int m1 = fe_isequal(quartic, check);
	fe_neg(check, sqrtm1);  int ms = fe_isequal(quartic, check);

	fe_mul(isr, t0, sqrtm1);
	fe_ccopy(isr, t0, 1 - (m1 | ms));

	WIPE_BUFFER(t0);
	WIPE_BUFFER(t1);
	WIPE_BUFFER(t2);
	return p1 | m1 | z0;
}

static void fe_invert(fe out, const fe x)
{
	fe tmp;
	fe_sq(tmp, x);
	invsqrt(tmp, tmp);
	fe_sq(tmp, tmp);
	fe_mul(out, tmp, x);
	WIPE_BUFFER(tmp);
}

void crypto_eddsa_trim_scalar(u8 out[32], const u8 in[32])
{
	COPY(out, in, 32);
	out[ 0] &= 248;
	out[31] &= 127;
	out[31] |= 64;
}

static int scalar_bit(const u8 s[32], int i)
{
	if (i < 0) { return 0; }
	return (s[i>>3] >> (i&7)) & 1;
}

static void scalarmult(u8 q[32], const u8 scalar[32], const u8 p[32],
                       int nb_bits)
{

	fe x1;
	fe_frombytes(x1, p);

	fe x2, z2, x3, z3, t0, t1;

	fe_1(x2);        fe_0(z2);
	fe_copy(x3, x1); fe_1(z3);
	int swap = 0;
	for (int pos = nb_bits-1; pos >= 0; --pos) {

		int b = scalar_bit(scalar, pos);
		swap ^= b;
		fe_cswap(x2, x3, swap);
		fe_cswap(z2, z3, swap);
		swap = b;

		fe_sub(t0, x3, z3);
		fe_sub(t1, x2, z2);
		fe_add(x2, x2, z2);
		fe_add(z2, x3, z3);
		fe_mul(z3, t0, x2);
		fe_mul(z2, z2, t1);
		fe_sq (t0, t1    );
		fe_sq (t1, x2    );
		fe_add(x3, z3, z2);
		fe_sub(z2, z3, z2);
		fe_mul(x2, t1, t0);
		fe_sub(t1, t1, t0);
		fe_sq (z2, z2    );
		fe_mul_small(z3, t1, 121666);
		fe_sq (x3, x3    );
		fe_add(t0, t0, z3);
		fe_mul(z3, x1, z2);
		fe_mul(z2, t1, t0);
	}

	fe_cswap(x2, x3, swap);
	fe_cswap(z2, z3, swap);

	fe_invert(z2, z2);
	fe_mul(x2, x2, z2);
	fe_tobytes(q, x2);

	WIPE_BUFFER(x1);
	WIPE_BUFFER(x2);  WIPE_BUFFER(z2);  WIPE_BUFFER(t0);
	WIPE_BUFFER(x3);  WIPE_BUFFER(z3);  WIPE_BUFFER(t1);
}

void crypto_x25519(u8       raw_shared_secret[32],
                   const u8 your_secret_key  [32],
                   const u8 their_public_key [32])
{

	u8 e[32];
	crypto_eddsa_trim_scalar(e, your_secret_key);
	scalarmult(raw_shared_secret, e, their_public_key, 255);
	WIPE_BUFFER(e);
}

void crypto_x25519_public_key(u8       public_key[32],
                              const u8 secret_key[32])
{
	static const u8 base_point[32] = {9};
	crypto_x25519(public_key, secret_key, base_point);
}

static const u32 L[8] = {
	0x5cf5d3ed, 0x5812631a, 0xa2f79cd6, 0x14def9de,
	0x00000000, 0x00000000, 0x00000000, 0x10000000,
};

static void multiply(u32 p[16], const u32 a[8], const u32 b[8])
{
	FOR (i, 0, 8) {
		u64 carry = 0;
		FOR (j, 0, 8) {
			carry  += p[i+j] + (u64)a[i] * b[j];
			p[i+j]  = (u32)carry;
			carry >>= 32;
		}
		p[i+8] = (u32)carry;
	}
}

static int is_above_l(const u32 x[8])
{

	u64 carry = 1;
	FOR (i, 0, 8) {
		carry  += (u64)x[i] + (~L[i] & 0xffffffff);
		carry >>= 32;
	}
	return (int)carry;
}

static void remove_l(u32 r[8], const u32 x[8])
{
	u64 carry = (u64)is_above_l(x);
	u32 mask  = ~(u32)carry + 1;
	FOR (i, 0, 8) {
		carry += (u64)x[i] + (~L[i] & mask);
		r[i]   = (u32)carry;
		carry >>= 32;
	}
}

static void mod_l(u8 reduced[32], const u32 x[16])
{
	static const u32 r[9] = {
		0x0a2c131b,0xed9ce5a3,0x086329a7,0x2106215d,
		0xffffffeb,0xffffffff,0xffffffff,0xffffffff,0xf,
	};

	u32 xr[25] = {0};
	FOR (i, 0, 9) {
		u64 carry = 0;
		FOR (j, 0, 16) {
			carry  += xr[i+j] + (u64)r[i] * x[j];
			xr[i+j] = (u32)carry;
			carry >>= 32;
		}
		xr[i+16] = (u32)carry;
	}

	ZERO(xr, 8);
	FOR (i, 0, 8) {
		u64 carry = 0;
		FOR (j, 0, 8-i) {
			carry   += xr[i+j] + (u64)xr[i+16] * L[j];
			xr[i+j] = (u32)carry;
			carry >>= 32;
		}
	}

	u64 carry = 1;
	FOR (i, 0, 8) {
		carry  += (u64)x[i] + (~xr[i] & 0xffffffff);
		xr[i]   = (u32)carry;
		carry >>= 32;
	}

	remove_l(xr, xr);
	store32_le_buf(reduced, xr, 8);

	WIPE_BUFFER(xr);
}

void crypto_eddsa_reduce(u8 reduced[32], const u8 expanded[64])
{
	u32 x[16];
	load32_le_buf(x, expanded, 16);
	mod_l(reduced, x);
	WIPE_BUFFER(x);
}

void crypto_eddsa_mul_add(u8 r[32],
                          const u8 a[32], const u8 b[32], const u8 c[32])
{
	u32 A[8];  load32_le_buf(A, a, 8);
	u32 B[8];  load32_le_buf(B, b, 8);
	u32 p[16]; load32_le_buf(p, c, 8);  ZERO(p + 8, 8);
	multiply(p, A, B);
	mod_l(r, p);
	WIPE_BUFFER(p);
	WIPE_BUFFER(A);
	WIPE_BUFFER(B);
}

typedef struct { fe X;  fe Y;  fe Z; fe T;  } ge;
typedef struct { fe Yp; fe Ym; fe Z; fe T2; } ge_cached;
typedef struct { fe Yp; fe Ym;       fe T2; } ge_precomp;

static void ge_zero(ge *p)
{
	fe_0(p->X);
	fe_1(p->Y);
	fe_1(p->Z);
	fe_0(p->T);
}

static void ge_tobytes(u8 s[32], const ge *h)
{
	fe recip, x, y;
	fe_invert(recip, h->Z);
	fe_mul(x, h->X, recip);
	fe_mul(y, h->Y, recip);
	fe_tobytes(s, y);
	s[31] ^= (u8)fe_isodd(x) << 7;

	WIPE_BUFFER(recip);
	WIPE_BUFFER(x);
	WIPE_BUFFER(y);
}

static int ge_frombytes_neg_vartime(ge *h, const u8 s[32])
{
	fe_frombytes(h->Y, s);
	fe_1(h->Z);
	fe_sq (h->T, h->Y);
	fe_mul(h->X, h->T, d   );
	fe_sub(h->T, h->T, h->Z);
	fe_add(h->X, h->X, h->Z);
	fe_mul(h->X, h->T, h->X);
	int is_square = invsqrt(h->X, h->X);
	if (!is_square) {
		return -1;
	}
	fe_mul(h->X, h->T, h->X);
	if (fe_isodd(h->X) == (s[31] >> 7)) {
		fe_neg(h->X, h->X);
	}
	fe_mul(h->T, h->X, h->Y);
	return 0;
}

static void ge_cache(ge_cached *c, const ge *p)
{
	fe_add (c->Yp, p->Y, p->X);
	fe_sub (c->Ym, p->Y, p->X);
	fe_copy(c->Z , p->Z      );
	fe_mul (c->T2, p->T, D2  );
}

static void ge_add(ge *s, const ge *p, const ge_cached *q)
{
	fe a, b;
	fe_add(a   , p->Y, p->X );
	fe_sub(b   , p->Y, p->X );
	fe_mul(a   , a   , q->Yp);
	fe_mul(b   , b   , q->Ym);
	fe_add(s->Y, a   , b    );
	fe_sub(s->X, a   , b    );

	fe_add(s->Z, p->Z, p->Z );
	fe_mul(s->Z, s->Z, q->Z );
	fe_mul(s->T, p->T, q->T2);
	fe_add(a   , s->Z, s->T );
	fe_sub(b   , s->Z, s->T );

	fe_mul(s->T, s->X, s->Y);
	fe_mul(s->X, s->X, b   );
	fe_mul(s->Y, s->Y, a   );
	fe_mul(s->Z, a   , b   );
}

static void ge_sub(ge *s, const ge *p, const ge_cached *q)
{
	ge_cached neg;
	fe_copy(neg.Ym, q->Yp);
	fe_copy(neg.Yp, q->Ym);
	fe_copy(neg.Z , q->Z );
	fe_neg (neg.T2, q->T2);
	ge_add(s, p, &neg);
}

static void ge_madd(ge *s, const ge *p, const ge_precomp *q, fe a, fe b)
{
	fe_add(a   , p->Y, p->X );
	fe_sub(b   , p->Y, p->X );
	fe_mul(a   , a   , q->Yp);
	fe_mul(b   , b   , q->Ym);
	fe_add(s->Y, a   , b    );
	fe_sub(s->X, a   , b    );

	fe_add(s->Z, p->Z, p->Z );
	fe_mul(s->T, p->T, q->T2);
	fe_add(a   , s->Z, s->T );
	fe_sub(b   , s->Z, s->T );

	fe_mul(s->T, s->X, s->Y);
	fe_mul(s->X, s->X, b   );
	fe_mul(s->Y, s->Y, a   );
	fe_mul(s->Z, a   , b   );
}

static void ge_msub(ge *s, const ge *p, const ge_precomp *q, fe a, fe b)
{
	ge_precomp neg;
	fe_copy(neg.Ym, q->Yp);
	fe_copy(neg.Yp, q->Ym);
	fe_neg (neg.T2, q->T2);
	ge_madd(s, p, &neg, a, b);
}

static void ge_double(ge *s, const ge *p, ge *q)
{
	fe_sq (q->X, p->X);
	fe_sq (q->Y, p->Y);
	fe_sq (q->Z, p->Z);
	fe_mul_small(q->Z, q->Z, 2);
	fe_add(q->T, p->X, p->Y);
	fe_sq (s->T, q->T);
	fe_add(q->T, q->Y, q->X);
	fe_sub(q->Y, q->Y, q->X);
	fe_sub(q->X, s->T, q->T);
	fe_sub(q->Z, q->Z, q->Y);

	fe_mul(s->X, q->X , q->Z);
	fe_mul(s->Y, q->T , q->Y);
	fe_mul(s->Z, q->Y , q->Z);
	fe_mul(s->T, q->X , q->T);
}

static const ge_precomp b_window[8] = {
	{{25967493,-14356035,29566456,3660896,-12694345,
	  4014787,27544626,-11754271,-6079156,2047605,},
	 {-12545711,934262,-2722910,3049990,-727428,
	  9406986,12720692,5043384,19500929,-15469378,},
	 {-8738181,4489570,9688441,-14785194,10184609,
	  -12363380,29287919,11864899,-24514362,-4438546,},},
	{{15636291,-9688557,24204773,-7912398,616977,
	  -16685262,27787600,-14772189,28944400,-1550024,},
	 {16568933,4717097,-11556148,-1102322,15682896,
	  -11807043,16354577,-11775962,7689662,11199574,},
	 {30464156,-5976125,-11779434,-15670865,23220365,
	  15915852,7512774,10017326,-17749093,-9920357,},},
	{{10861363,11473154,27284546,1981175,-30064349,
	  12577861,32867885,14515107,-15438304,10819380,},
	 {4708026,6336745,20377586,9066809,-11272109,
	  6594696,-25653668,12483688,-12668491,5581306,},
	 {19563160,16186464,-29386857,4097519,10237984,
	  -4348115,28542350,13850243,-23678021,-15815942,},},
	{{5153746,9909285,1723747,-2777874,30523605,
	  5516873,19480852,5230134,-23952439,-15175766,},
	 {-30269007,-3463509,7665486,10083793,28475525,
	  1649722,20654025,16520125,30598449,7715701,},
	 {28881845,14381568,9657904,3680757,-20181635,
	  7843316,-31400660,1370708,29794553,-1409300,},},
	{{-22518993,-6692182,14201702,-8745502,-23510406,
	  8844726,18474211,-1361450,-13062696,13821877,},
	 {-6455177,-7839871,3374702,-4740862,-27098617,
	  -10571707,31655028,-7212327,18853322,-14220951,},
	 {4566830,-12963868,-28974889,-12240689,-7602672,
	  -2830569,-8514358,-10431137,2207753,-3209784,},},
	{{-25154831,-4185821,29681144,7868801,-6854661,
	  -9423865,-12437364,-663000,-31111463,-16132436,},
	 {25576264,-2703214,7349804,-11814844,16472782,
	  9300885,3844789,15725684,171356,6466918,},
	 {23103977,13316479,9739013,-16149481,817875,
	  -15038942,8965339,-14088058,-30714912,16193877,},},
	{{-33521811,3180713,-2394130,14003687,-16903474,
	  -16270840,17238398,4729455,-18074513,9256800,},
	 {-25182317,-4174131,32336398,5036987,-21236817,
	  11360617,22616405,9761698,-19827198,630305,},
	 {-13720693,2639453,-24237460,-7406481,9494427,
	  -5774029,-6554551,-15960994,-2449256,-14291300,},},
	{{-3151181,-5046075,9282714,6866145,-31907062,
	  -863023,-18940575,15033784,25105118,-7894876,},
	 {-24326370,15950226,-31801215,-14592823,-11662737,
	  -5090925,1573892,-2625887,2198790,-15804619,},
	 {-3099351,10324967,-2241613,7453183,-5446979,
	  -2735503,-13812022,-16236442,-32461234,-12290683,},},
};

typedef struct {
	i16 next_index;
	i8  next_digit;
	u8  next_check;
} slide_ctx;

static void slide_init(slide_ctx *ctx, const u8 scalar[32])
{

	int i = 252;
	while (i > 0 && scalar_bit(scalar, i) == 0) {
		i--;
	}
	ctx->next_check = (u8)(i + 1);
	ctx->next_index = -1;
	ctx->next_digit = -1;
}

static int slide_step(slide_ctx *ctx, int width, int i, const u8 scalar[32])
{
	if (i == ctx->next_check) {
		if (scalar_bit(scalar, i) == scalar_bit(scalar, i - 1)) {
			ctx->next_check--;
		} else {

			int w = MIN(width, i + 1);
			int v = -(scalar_bit(scalar, i) << (w-1));
			FOR_T (int, j, 0, w-1) {
				v += scalar_bit(scalar, i-(w-1)+j) << j;
			}
			v += scalar_bit(scalar, i-w);
			int lsb = v & (~v + 1);
			int s   =
				(((lsb & 0xAA) != 0) << 0) |
				(((lsb & 0xCC) != 0) << 1) |
				(((lsb & 0xF0) != 0) << 2);
			ctx->next_index  = (i16)(i-(w-1)+s);
			ctx->next_digit  = (i8) (v >> s   );
			ctx->next_check -= (u8) w;
		}
	}
	return i == ctx->next_index ? ctx->next_digit: 0;
}

#define P_W_WIDTH 3
#define B_W_WIDTH 5
#define P_W_SIZE  (1<<(P_W_WIDTH-2))

int crypto_eddsa_check_equation(const u8 signature[64], const u8 public_key[32],
                                const u8 h[32])
{
	ge minus_A;
	ge minus_R;
	const u8 *s = signature + 32;

	{
		u32 s32[8];
		load32_le_buf(s32, s, 8);
		if (ge_frombytes_neg_vartime(&minus_A, public_key) ||
		    ge_frombytes_neg_vartime(&minus_R, signature)  ||
		    is_above_l(s32)) {
			return -1;
		}
	}

	ge_cached lutA[P_W_SIZE];
	{
		ge minus_A2, tmp;
		ge_double(&minus_A2, &minus_A, &tmp);
		ge_cache(&lutA[0], &minus_A);
		FOR (i, 1, P_W_SIZE) {
			ge_add(&tmp, &minus_A2, &lutA[i-1]);
			ge_cache(&lutA[i], &tmp);
		}
	}

	slide_ctx h_slide;  slide_init(&h_slide, h);
	slide_ctx s_slide;  slide_init(&s_slide, s);
	int i = MAX(h_slide.next_check, s_slide.next_check);
	ge *sum = &minus_A;
	ge_zero(sum);
	while (i >= 0) {
		ge tmp;
		ge_double(sum, sum, &tmp);
		int h_digit = slide_step(&h_slide, P_W_WIDTH, i, h);
		int s_digit = slide_step(&s_slide, B_W_WIDTH, i, s);
		if (h_digit > 0) { ge_add(sum, sum, &lutA[ h_digit / 2]); }
		if (h_digit < 0) { ge_sub(sum, sum, &lutA[-h_digit / 2]); }
		fe t1, t2;
		if (s_digit > 0) { ge_madd(sum, sum, b_window +  s_digit/2, t1, t2); }
		if (s_digit < 0) { ge_msub(sum, sum, b_window + -s_digit/2, t1, t2); }
		i--;
	}

	ge_cached cached;
	u8 check[32];
	static const u8 zero_point[32] = {1};
	ge_cache(&cached, &minus_R);
	ge_add(sum, sum, &cached);
	ge_double(sum, sum, &minus_R);
	ge_double(sum, sum, &minus_R);
	ge_double(sum, sum, &minus_R);
	ge_tobytes(check, sum);
	return crypto_verify32(check, zero_point);
}

static const ge_precomp b_comb_low[8] = {
	{{-6816601,-2324159,-22559413,124364,18015490,
	  8373481,19993724,1979872,-18549925,9085059,},
	 {10306321,403248,14839893,9633706,8463310,
	  -8354981,-14305673,14668847,26301366,2818560,},
	 {-22701500,-3210264,-13831292,-2927732,-16326337,
	  -14016360,12940910,177905,12165515,-2397893,},},
	{{-12282262,-7022066,9920413,-3064358,-32147467,
	  2927790,22392436,-14852487,2719975,16402117,},
	 {-7236961,-4729776,2685954,-6525055,-24242706,
	  -15940211,-6238521,14082855,10047669,12228189,},
	 {-30495588,-12893761,-11161261,3539405,-11502464,
	  16491580,-27286798,-15030530,-7272871,-15934455,},},
	{{17650926,582297,-860412,-187745,-12072900,
	  -10683391,-20352381,15557840,-31072141,-5019061,},
	 {-6283632,-2259834,-4674247,-4598977,-4089240,
	  12435688,-31278303,1060251,6256175,10480726,},
	 {-13871026,2026300,-21928428,-2741605,-2406664,
	  -8034988,7355518,15733500,-23379862,7489131,},},
	{{6883359,695140,23196907,9644202,-33430614,
	  11354760,-20134606,6388313,-8263585,-8491918,},
	 {-7716174,-13605463,-13646110,14757414,-19430591,
	  -14967316,10359532,-11059670,-21935259,12082603,},
	 {-11253345,-15943946,10046784,5414629,24840771,
	  8086951,-6694742,9868723,15842692,-16224787,},},
	{{9639399,11810955,-24007778,-9320054,3912937,
	  -9856959,996125,-8727907,-8919186,-14097242,},
	 {7248867,14468564,25228636,-8795035,14346339,
	  8224790,6388427,-7181107,6468218,-8720783,},
	 {15513115,15439095,7342322,-10157390,18005294,
	  -7265713,2186239,4884640,10826567,7135781,},},
	{{-14204238,5297536,-5862318,-6004934,28095835,
	  4236101,-14203318,1958636,-16816875,3837147,},
	 {-5511166,-13176782,-29588215,12339465,15325758,
	  -15945770,-8813185,11075932,-19608050,-3776283,},
	 {11728032,9603156,-4637821,-5304487,-7827751,
	  2724948,31236191,-16760175,-7268616,14799772,},},
	{{-28842672,4840636,-12047946,-9101456,-1445464,
	  381905,-30977094,-16523389,1290540,12798615,},
	 {27246947,-10320914,14792098,-14518944,5302070,
	  -8746152,-3403974,-4149637,-27061213,10749585,},
	 {25572375,-6270368,-15353037,16037944,1146292,
	  32198,23487090,9585613,24714571,-1418265,},},
	{{19844825,282124,-17583147,11004019,-32004269,
	  -2716035,6105106,-1711007,-21010044,14338445,},
	 {8027505,8191102,-18504907,-12335737,25173494,
	  -5923905,15446145,7483684,-30440441,10009108,},
	 {-14134701,-4174411,10246585,-14677495,33553567,
	  -14012935,23366126,15080531,-7969992,7663473,},},
};

static const ge_precomp b_comb_high[8] = {
	{{33055887,-4431773,-521787,6654165,951411,
	  -6266464,-5158124,6995613,-5397442,-6985227,},
	 {4014062,6967095,-11977872,3960002,8001989,
	  5130302,-2154812,-1899602,-31954493,-16173976,},
	 {16271757,-9212948,23792794,731486,-25808309,
	  -3546396,6964344,-4767590,10976593,10050757,},},
	{{2533007,-4288439,-24467768,-12387405,-13450051,
	  14542280,12876301,13893535,15067764,8594792,},
	 {20073501,-11623621,3165391,-13119866,13188608,
	  -11540496,-10751437,-13482671,29588810,2197295,},
	 {-1084082,11831693,6031797,14062724,14748428,
	  -8159962,-20721760,11742548,31368706,13161200,},},
	{{2050412,-6457589,15321215,5273360,25484180,
	  124590,-18187548,-7097255,-6691621,-14604792,},
	 {9938196,2162889,-6158074,-1711248,4278932,
	  -2598531,-22865792,-7168500,-24323168,11746309,},
	 {-22691768,-14268164,5965485,9383325,20443693,
	  5854192,28250679,-1381811,-10837134,13717818,},},
	{{-8495530,16382250,9548884,-4971523,-4491811,
	  -3902147,6182256,-12832479,26628081,10395408,},
	 {27329048,-15853735,7715764,8717446,-9215518,
	  -14633480,28982250,-5668414,4227628,242148,},
	 {-13279943,-7986904,-7100016,8764468,-27276630,
	  3096719,29678419,-9141299,3906709,11265498,},},
	{{11918285,15686328,-17757323,-11217300,-27548967,
	  4853165,-27168827,6807359,6871949,-1075745,},
	 {-29002610,13984323,-27111812,-2713442,28107359,
	  -13266203,6155126,15104658,3538727,-7513788,},
	 {14103158,11233913,-33165269,9279850,31014152,
	  4335090,-1827936,4590951,13960841,12787712,},},
	{{1469134,-16738009,33411928,13942824,8092558,
	  -8778224,-11165065,1437842,22521552,-2792954,},
	 {31352705,-4807352,-25327300,3962447,12541566,
	  -9399651,-27425693,7964818,-23829869,5541287,},
	 {-25732021,-6864887,23848984,3039395,-9147354,
	  6022816,-27421653,10590137,25309915,-1584678,},},
	{{-22951376,5048948,31139401,-190316,-19542447,
	  -626310,-17486305,-16511925,-18851313,-12985140,},
	 {-9684890,14681754,30487568,7717771,-10829709,
	  9630497,30290549,-10531496,-27798994,-13812825,},
	 {5827835,16097107,-24501327,12094619,7413972,
	  11447087,28057551,-1793987,-14056981,4359312,},},
	{{26323183,2342588,-21887793,-1623758,-6062284,
	  2107090,-28724907,9036464,-19618351,-13055189,},
	 {-29697200,14829398,-4596333,14220089,-30022969,
	  2955645,12094100,-13693652,-5941445,7047569,},
	 {-3201977,14413268,-12058324,-16417589,-9035655,
	  -7224648,9258160,1399236,30397584,-5684634,},},
};

static void lookup_add(ge *p, ge_precomp *tmp_c, fe tmp_a, fe tmp_b,
                       const ge_precomp comb[8], const u8 scalar[32], int i)
{
	u8 teeth = (u8)((scalar_bit(scalar, i)          ) +
	                (scalar_bit(scalar, i + 32) << 1) +
	                (scalar_bit(scalar, i + 64) << 2) +
	                (scalar_bit(scalar, i + 96) << 3));
	u8 high  = teeth >> 3;
	u8 index = (teeth ^ (high - 1)) & 7;
	FOR (j, 0, 8) {
		i32 select = 1 & (((j ^ index) - 1) >> 8);
		fe_ccopy(tmp_c->Yp, comb[j].Yp, select);
		fe_ccopy(tmp_c->Ym, comb[j].Ym, select);
		fe_ccopy(tmp_c->T2, comb[j].T2, select);
	}
	fe_neg(tmp_a, tmp_c->T2);
	fe_cswap(tmp_c->T2, tmp_a    , high ^ 1);
	fe_cswap(tmp_c->Yp, tmp_c->Ym, high ^ 1);
	ge_madd(p, p, tmp_c, tmp_a, tmp_b);
}

static void ge_scalarmult_base(ge *p, const u8 scalar[32])
{

	static const u8 half_mod_L[32] = {
		247,233,122,46,141,49,9,44,107,206,123,81,239,124,111,10,
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,
	};

	static const u8 half_ones[32] = {
		142,74,204,70,186,24,118,107,184,231,190,57,250,173,119,99,
		255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,7,
	};

	u8 s_scalar[32];
	crypto_eddsa_mul_add(s_scalar, scalar, half_mod_L, half_ones);

	fe tmp_a, tmp_b;
	ge_precomp tmp_c;
	ge tmp_d;
	fe_1(tmp_c.Yp);
	fe_1(tmp_c.Ym);
	fe_0(tmp_c.T2);

	ge_zero(p);
	lookup_add(p, &tmp_c, tmp_a, tmp_b, b_comb_low , s_scalar, 31);
	lookup_add(p, &tmp_c, tmp_a, tmp_b, b_comb_high, s_scalar, 31+128);

	for (int i = 30; i >= 0; i--) {
		ge_double(p, p, &tmp_d);
		lookup_add(p, &tmp_c, tmp_a, tmp_b, b_comb_low , s_scalar, i);
		lookup_add(p, &tmp_c, tmp_a, tmp_b, b_comb_high, s_scalar, i+128);
	}

	WIPE_BUFFER(tmp_a);  WIPE_CTX(&tmp_d);
	WIPE_BUFFER(tmp_b);  WIPE_CTX(&tmp_c);
	WIPE_BUFFER(s_scalar);
}

void crypto_eddsa_scalarbase(u8 point[32], const u8 scalar[32])
{
	ge P;
	ge_scalarmult_base(&P, scalar);
	ge_tobytes(point, &P);
	WIPE_CTX(&P);
}

void crypto_eddsa_key_pair(u8 secret_key[64], u8 public_key[32], u8 seed[32])
{

	u8 a[64];
	COPY(a, seed, 32);
	crypto_wipe(seed, 32);
	COPY(secret_key, a, 32);
	crypto_blake2b(a, 64, a, 32);
	crypto_eddsa_trim_scalar(a, a);
	crypto_eddsa_scalarbase(secret_key + 32, a);
	COPY(public_key, secret_key + 32, 32);
	WIPE_BUFFER(a);
}

static void hash_reduce(u8 h[32],
                        const u8 *a, size_t a_size,
                        const u8 *b, size_t b_size,
                        const u8 *c, size_t c_size)
{
	u8 hash[64];
	crypto_blake2b_ctx ctx;
	crypto_blake2b_init  (&ctx, 64);
	crypto_blake2b_update(&ctx, a, a_size);
	crypto_blake2b_update(&ctx, b, b_size);
	crypto_blake2b_update(&ctx, c, c_size);
	crypto_blake2b_final (&ctx, hash);
	crypto_eddsa_reduce(h, hash);
}

void crypto_eddsa_sign(u8 signature [64], const u8 secret_key[64],
                       const u8 *message, size_t message_size)
{
	u8 a[64];
	u8 r[32];
	u8 h[32];
	u8 R[32];

	crypto_blake2b(a, 64, secret_key, 32);
	crypto_eddsa_trim_scalar(a, a);
	hash_reduce(r, a + 32, 32, message, message_size, 0, 0);
	crypto_eddsa_scalarbase(R, r);
	hash_reduce(h, R, 32, secret_key + 32, 32, message, message_size);
	COPY(signature, R, 32);
	crypto_eddsa_mul_add(signature + 32, h, a, r);

	WIPE_BUFFER(a);
	WIPE_BUFFER(r);
}

int crypto_eddsa_check(const u8  signature[64], const u8 public_key[32],
                       const u8 *message, size_t message_size)
{
	u8 h[32];
	hash_reduce(h, signature, 32, public_key, 32, message, message_size);
	return crypto_eddsa_check_equation(signature, public_key, h);
}

void crypto_eddsa_to_x25519(u8 x25519[32], const u8 eddsa[32])
{

	fe t1, t2;
	fe_frombytes(t2, eddsa);
	fe_add(t1, fe_one, t2);
	fe_sub(t2, fe_one, t2);
	fe_invert(t2, t2);
	fe_mul(t1, t1, t2);
	fe_tobytes(x25519, t1);
	WIPE_BUFFER(t1);
	WIPE_BUFFER(t2);
}

void crypto_x25519_to_eddsa(u8 eddsa[32], const u8 x25519[32])
{

	fe t1, t2;
	fe_frombytes(t2, x25519);
	fe_sub(t1, t2, fe_one);
	fe_add(t2, t2, fe_one);
	fe_invert(t2, t2);
	fe_mul(t1, t1, t2);
	fe_tobytes(eddsa, t1);
	WIPE_BUFFER(t1);
	WIPE_BUFFER(t2);
}

static void add_xl(u8 s[32], u8 x)
{
	u64 mod8  = x & 7;
	u64 carry = 0;
	FOR (i , 0, 8) {
		carry = carry + load32_le(s + 4*i) + L[i] * mod8;
		store32_le(s + 4*i, (u32)carry);
		carry >>= 32;
	}
}

void crypto_x25519_dirty_small(u8 public_key[32], const u8 secret_key[32])
{

	static const u8 dirty_base_point[32] = {
		0xd8, 0x86, 0x1a, 0xa2, 0x78, 0x7a, 0xd9, 0x26,
		0x8b, 0x74, 0x74, 0xb6, 0x82, 0xe3, 0xbe, 0xc3,
		0xce, 0x36, 0x9a, 0x1e, 0x5e, 0x31, 0x47, 0xa2,
		0x6d, 0x37, 0x7c, 0xfd, 0x20, 0xb5, 0xdf, 0x75,
	};

	u8 scalar[32];
	crypto_eddsa_trim_scalar(scalar, secret_key);

	add_xl(scalar, secret_key[0]);
	scalarmult(public_key, scalar, dirty_base_point, 256);
	WIPE_BUFFER(scalar);
}

static void select_lop(fe out, const fe x, const fe k, u8 cofactor)
{
	fe tmp;
	fe_0(out);
	fe_ccopy(out, k  , (cofactor >> 1) & 1);
	fe_ccopy(out, x  , (cofactor >> 0) & 1);
	fe_neg  (tmp, out);
	fe_ccopy(out, tmp, (cofactor >> 2) & 1);
	WIPE_BUFFER(tmp);
}

void crypto_x25519_dirty_fast(u8 public_key[32], const u8 secret_key[32])
{

	u8 scalar[32];
	ge pk;
	crypto_eddsa_trim_scalar(scalar, secret_key);
	ge_scalarmult_base(&pk, scalar);

	fe t1, t2;
	select_lop(t1, lop_x, sqrtm1, secret_key[0]);
	select_lop(t2, lop_y, fe_one, secret_key[0] + 2);
	ge_precomp low_order_point;
	fe_add(low_order_point.Yp, t2, t1);
	fe_sub(low_order_point.Ym, t2, t1);
	fe_mul(low_order_point.T2, t2, t1);
	fe_mul(low_order_point.T2, low_order_point.T2, D2);

	ge_madd(&pk, &pk, &low_order_point, t1, t2);

	fe_add(t1, pk.Z, pk.Y);
	fe_sub(t2, pk.Z, pk.Y);
	fe_invert(t2, t2);
	fe_mul(t1, t1, t2);

	fe_tobytes(public_key, t1);

	WIPE_BUFFER(t1);    WIPE_CTX(&pk);
	WIPE_BUFFER(t2);    WIPE_CTX(&low_order_point);
	WIPE_BUFFER(scalar);
}

static const fe A = {486662};

void crypto_elligator_map(u8 curve[32], const u8 hidden[32])
{
	fe r, u, t1, t2, t3;
	fe_frombytes_mask(r, hidden, 2);
	fe_sq(r, r);
	fe_add(t1, r, r);
	fe_add(u, t1, fe_one);
	fe_sq (t2, u);
	fe_mul(t3, A2, t1);
	fe_sub(t3, t3, t2);
	fe_mul(t3, t3, A);
	fe_mul(t1, t2, u);
	fe_mul(t1, t3, t1);
	int is_square = invsqrt(t1, t1);
	fe_mul(u, r, ufactor);
	fe_ccopy(u, fe_one, is_square);
	fe_sq (t1, t1);
	fe_mul(u, u, A);
	fe_mul(u, u, t3);
	fe_mul(u, u, t2);
	fe_mul(u, u, t1);
	fe_neg(u, u);
	fe_tobytes(curve, u);

	WIPE_BUFFER(t1);  WIPE_BUFFER(r);
	WIPE_BUFFER(t2);  WIPE_BUFFER(u);
	WIPE_BUFFER(t3);
}

int crypto_elligator_rev(u8 hidden[32], const u8 public_key[32], u8 tweak)
{
	fe t1, t2, t3;
	fe_frombytes(t1, public_key);

	fe_add(t2, t1, A);
	fe_mul(t3, t1, t2);
	fe_mul_small(t3, t3, -2);
	int is_square = invsqrt(t3, t3);
	if (is_square) {

		fe_ccopy    (t1, t2, tweak & 1);
		fe_mul      (t3, t1, t3);
		fe_mul_small(t1, t3, 2);
		fe_neg      (t2, t3);
		fe_ccopy    (t3, t2, fe_isodd(t1));
		fe_tobytes(hidden, t3);

		hidden[31] |= tweak & 0xc0;
	}

	WIPE_BUFFER(t1);
	WIPE_BUFFER(t2);
	WIPE_BUFFER(t3);
	return is_square - 1;
}

void crypto_elligator_key_pair(u8 hidden[32], u8 secret_key[32], u8 seed[32])
{
	u8 pk [32];
	u8 buf[64];
	COPY(buf + 32, seed, 32);
	do {
		crypto_chacha20_djb(buf, 0, 64, buf+32, zero, 0);
		crypto_x25519_dirty_fast(pk, buf);
	} while(crypto_elligator_rev(buf+32, pk, buf[32]));

	crypto_wipe(seed, 32);
	COPY(hidden    , buf + 32, 32);
	COPY(secret_key, buf     , 32);
	WIPE_BUFFER(buf);
	WIPE_BUFFER(pk);
}

static void redc(u32 u[8], u32 x[16])
{
	static const u32 k[8] = {
		0x12547e1b, 0xd2b51da3, 0xfdba84ff, 0xb1a206f2,
		0xffa36bea, 0x14e75438, 0x6fe91836, 0x9db6c6f2,
	};

	u32 s[8] = {0};
	FOR (i, 0, 8) {
		u64 carry = 0;
		FOR (j, 0, 8-i) {
			carry  += s[i+j] + (u64)x[i] * k[j];
			s[i+j]  = (u32)carry;
			carry >>= 32;
		}
	}
	u32 t[16] = {0};
	multiply(t, s, L);

	u64 carry = 0;
	FOR (i, 0, 16) {
		carry  += (u64)t[i] + x[i];
		t[i]    = (u32)carry;
		carry >>= 32;
	}

	remove_l(u, t+8);

	WIPE_BUFFER(s);
	WIPE_BUFFER(t);
}

void crypto_x25519_inverse(u8 blind_salt [32], const u8 private_key[32],
                           const u8 curve_point[32])
{
	static const  u8 Lm2[32] = {
		0xeb, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58,
		0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14,
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10,
	};

	u32 m_inv [8] = {
		0x8d98951d, 0xd6ec3174, 0x737dcf70, 0xc6ef5bf4,
		0xfffffffe, 0xffffffff, 0xffffffff, 0x0fffffff,
	};

	u8 scalar[32];
	crypto_eddsa_trim_scalar(scalar, private_key);

	u32 m_scl[8];
	{
		u32 tmp[16];
		ZERO(tmp, 8);
		load32_le_buf(tmp+8, scalar, 8);
		mod_l(scalar, tmp);
		load32_le_buf(m_scl, scalar, 8);
		WIPE_BUFFER(tmp);
	}

	u32 product[16];
	for (int i = 252; i >= 0; i--) {
		ZERO(product, 16);
		multiply(product, m_inv, m_inv);
		redc(m_inv, product);
		if (scalar_bit(Lm2, i)) {
			ZERO(product, 16);
			multiply(product, m_inv, m_scl);
			redc(m_inv, product);
		}
	}

	COPY(product, m_inv, 8);
	ZERO(product + 8, 8);
	redc(m_inv, product);
	store32_le_buf(scalar, m_inv, 8);

	add_xl(scalar, scalar[0] * 3);

	scalarmult(blind_salt, scalar, curve_point, 256);

	WIPE_BUFFER(scalar);   WIPE_BUFFER(m_scl);
	WIPE_BUFFER(product);  WIPE_BUFFER(m_inv);
}

static void lock_auth(u8 mac[16], const u8  auth_key[32],
                      const u8 *ad         , size_t ad_size,
                      const u8 *cipher_text, size_t text_size)
{
	u8 sizes[16];
	store64_le(sizes + 0, ad_size);
	store64_le(sizes + 8, text_size);
	crypto_poly1305_ctx poly_ctx;
	crypto_poly1305_init  (&poly_ctx, auth_key);
	crypto_poly1305_update(&poly_ctx, ad         , ad_size);
	crypto_poly1305_update(&poly_ctx, zero       , gap(ad_size, 16));
	crypto_poly1305_update(&poly_ctx, cipher_text, text_size);
	crypto_poly1305_update(&poly_ctx, zero       , gap(text_size, 16));
	crypto_poly1305_update(&poly_ctx, sizes      , 16);
	crypto_poly1305_final (&poly_ctx, mac);
}

void crypto_aead_init_x(crypto_aead_ctx *ctx,
                        u8 const key[32], const u8 nonce[24])
{
	crypto_chacha20_h(ctx->key, key, nonce);
	COPY(ctx->nonce, nonce + 16, 8);
	ctx->counter = 0;
}

void crypto_aead_init_djb(crypto_aead_ctx *ctx,
                          const u8 key[32], const u8 nonce[8])
{
	COPY(ctx->key  , key  , 32);
	COPY(ctx->nonce, nonce,  8);
	ctx->counter = 0;
}

void crypto_aead_init_ietf(crypto_aead_ctx *ctx,
                           const u8 key[32], const u8 nonce[12])
{
	COPY(ctx->key  , key      , 32);
	COPY(ctx->nonce, nonce + 4,  8);
	ctx->counter = (u64)load32_le(nonce) << 32;
}

void crypto_aead_write(crypto_aead_ctx *ctx, u8 *cipher_text, u8 mac[16],
                       const u8 *ad,         size_t ad_size,
                       const u8 *plain_text, size_t text_size)
{
	u8 auth_key[64];
	crypto_chacha20_djb(auth_key, 0, 64, ctx->key, ctx->nonce, ctx->counter);
	crypto_chacha20_djb(cipher_text, plain_text, text_size,
	                    ctx->key, ctx->nonce, ctx->counter + 1);
	lock_auth(mac, auth_key, ad, ad_size, cipher_text, text_size);
	COPY(ctx->key, auth_key + 32, 32);
	WIPE_BUFFER(auth_key);
}

int crypto_aead_read(crypto_aead_ctx *ctx, u8 *plain_text, const u8 mac[16],
                     const u8 *ad,          size_t ad_size,
                     const u8 *cipher_text, size_t text_size)
{
	u8 auth_key[64];
	u8 real_mac[16];
	crypto_chacha20_djb(auth_key, 0, 64, ctx->key, ctx->nonce, ctx->counter);
	lock_auth(real_mac, auth_key, ad, ad_size, cipher_text, text_size);
	int mismatch = crypto_verify16(mac, real_mac);
	if (!mismatch) {
		crypto_chacha20_djb(plain_text, cipher_text, text_size,
		                    ctx->key, ctx->nonce, ctx->counter + 1);
		COPY(ctx->key, auth_key + 32, 32);
	}
	WIPE_BUFFER(auth_key);
	WIPE_BUFFER(real_mac);
	return mismatch;
}

void crypto_aead_lock(u8 *cipher_text, u8 mac[16], const u8 key[32],
                      const u8  nonce[24], const u8 *ad, size_t ad_size,
                      const u8 *plain_text, size_t text_size)
{
	crypto_aead_ctx ctx;
	crypto_aead_init_x(&ctx, key, nonce);
	crypto_aead_write(&ctx, cipher_text, mac, ad, ad_size,
	                  plain_text, text_size);
	crypto_wipe(&ctx, sizeof(ctx));
}

int crypto_aead_unlock(u8 *plain_text, const u8  mac[16], const u8 key[32],
                       const u8 nonce[24], const u8 *ad, size_t ad_size,
                       const u8 *cipher_text, size_t text_size)
{
	crypto_aead_ctx ctx;
	crypto_aead_init_x(&ctx, key, nonce);
	int mismatch = crypto_aead_read(&ctx, plain_text, mac, ad, ad_size,
	                                cipher_text, text_size);
	crypto_wipe(&ctx, sizeof(ctx));
	return mismatch;
}

#ifdef MONOCYPHER_CPP_NAMESPACE
}
#endif
