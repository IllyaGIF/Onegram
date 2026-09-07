#import "TGAudioWaveform.h"

#import "LegacyComponentsInternal.h"

#import "PSKeyValueCoder.h"

static int32_t get_bits(uint8_t const *bytes, unsigned int bitOffset, unsigned int numBits)
{
    uint32_t value = 0;
    for (unsigned int i = 0; i < numBits; i++)
    {
        unsigned int absoluteBit = bitOffset + i;
        if ((bytes[absoluteBit >> 3] & (1 << (absoluteBit & 7))) != 0)
            value |= 1U << i;
    }
    return (int32_t)value;
}

static void set_bits(uint8_t *bytes, unsigned int bitOffset, unsigned int numBits, uint32_t value)
{
    for (unsigned int i = 0; i < numBits; i++)
    {
        unsigned int absoluteBit = bitOffset + i;
        uint8_t mask = (uint8_t)(1 << (absoluteBit & 7));
        if ((value & (1U << i)) != 0)
            bytes[absoluteBit >> 3] |= mask;
        else
            bytes[absoluteBit >> 3] &= (uint8_t)~mask;
    }
}

@implementation TGAudioWaveform

- (instancetype)initWithSamples:(NSData *)samples peak:(int32_t)peak {
    self = [super init];
    if (self != nil) {
        _samples = samples;
        _peak = peak;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithSamples:[aDecoder decodeObjectForKey:@"samples"] peak:[aDecoder decodeInt32ForKey:@"peak"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_samples forKey:@"samples"];
    [aCoder encodeInt32:_peak forKey:@"peak"];
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithSamples:[coder decodeDataCorCKey:"samples"] peak:[coder decodeInt32ForCKey:"peak"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeData:_samples forCKey:"samples"];
    [coder encodeInt32:_peak forCKey:"peak"];
}

- (instancetype)initWithBitstream:(NSData *)bitstream bitsPerSample:(NSUInteger)bitsPerSample {
    int numSamples = (int)(bitstream.length * 8 / bitsPerSample);
    uint8_t const *bytes = bitstream.bytes;
    int32_t maxSample = (1 << bitsPerSample) - 1;
    NSMutableData *result = [[NSMutableData alloc] initWithLength:numSamples * 2];
    uint8_t *samplesBytes = result.mutableBytes;
    int32_t norm = MAX(1, (1 << bitsPerSample) - 1);
    for (int i = 0; i < numSamples; i++) {
        int16_t sample = (int16_t)(((int64_t)get_bits(bytes, i * (unsigned int)bitsPerSample, (unsigned int)bitsPerSample) * maxSample) / norm);
        memcpy(samplesBytes + i * 2, &sample, sizeof(sample));
    }
    return [self initWithSamples:result peak:31];
}

- (NSData *)bitstream {
    int numSamples = (int)(_samples.length / 2);
    int bitstreamLength = (numSamples * 5) / 8 + (((numSamples * 5) % 8) == 0 ? 0 : 1);
    NSMutableData *result = [[NSMutableData alloc] initWithLength:bitstreamLength];
    int32_t maxSample = MAX(1, _peak);
    uint8_t const *samplesBytes = _samples.bytes;
    uint8_t *bytes = result.mutableBytes;

    for (int i = 0; i < numSamples; i++) {
        int16_t sample = 0;
        memcpy(&sample, samplesBytes + i * 2, sizeof(sample));
        int32_t value = MIN(31, ABS((int32_t)sample) * 31 / maxSample);
        set_bits(bytes, (unsigned int)(i * 5), 5, (uint32_t)(value & 31));
    }
    return result;
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGAudioWaveform class]] && TGObjectCompare(_samples, ((TGAudioWaveform *)object)->_samples) && _peak == ((TGAudioWaveform *)object)->_peak;
}

@end
