#include "media/H264.h"

namespace tgcalls {
namespace h264 {

namespace {

class BitReader {
public:
    BitReader(const uint8_t *data, size_t size) : _data(data), _size(size), _bit(0), _zeros(0), _byteIndex(0), _current(0), _hasCurrent(false), _failed(false) {
    }

    uint32_t readBit() {
        if (!_hasCurrent && !loadByte()) {
            _failed = true;
            return 0;
        }
        const uint32_t value = (_current >> (7 - _bit)) & 1;
        if (++_bit == 8) {
            _bit = 0;
            _hasCurrent = false;
        }
        return value;
    }

    uint32_t readBits(int count) {
        uint32_t value = 0;
        for (int i = 0; i < count; ++i) {
            value = (value << 1) | readBit();
        }
        return value;
    }

    uint32_t readUnsignedExpGolomb() {
        int zeros = 0;
        while (readBit() == 0 && !_failed) {
            if (++zeros > 31) {
                _failed = true;
                return 0;
            }
        }
        if (zeros == 0) {
            return 0;
        }
        return ((1U << zeros) - 1) + readBits(zeros);
    }

    int32_t readSignedExpGolomb() {
        const uint32_t value = readUnsignedExpGolomb();
        return (value & 1) ? (int32_t)((value + 1) / 2) : -(int32_t)(value / 2);
    }

    bool failed() const { return _failed; }

private:
    bool loadByte() {
        while (_byteIndex < _size) {
            const uint8_t byte = _data[_byteIndex++];
            if (_zeros >= 2 && byte == 0x03) {
                _zeros = 0;
                continue;
            }
            _zeros = byte == 0 ? _zeros + 1 : 0;
            _current = byte;
            _hasCurrent = true;
            return true;
        }
        return false;
    }

    const uint8_t *_data;
    size_t _size;
    int _bit;
    int _zeros;
    size_t _byteIndex;
    uint8_t _current;
    bool _hasCurrent;
    bool _failed;
};

void SkipScalingList(BitReader &reader, int size) {
    int last = 8;
    int next = 8;
    for (int i = 0; i < size; ++i) {
        if (next != 0) {
            next = (last + reader.readSignedExpGolomb() + 256) % 256;
        }
        last = next == 0 ? last : next;
    }
}

}

void SplitAnnexB(const uint8_t *data, size_t size, std::vector<NalUnit> &units) {
    units.clear();
    size_t i = 0;
    size_t start = 0;
    bool inside = false;
    while (i + 3 <= size) {
        if (data[i] == 0 && data[i + 1] == 0 && (data[i + 2] == 1 || (i + 4 <= size && data[i + 2] == 0 && data[i + 3] == 1))) {
            const size_t codeSize = data[i + 2] == 1 ? 3 : 4;
            if (inside && i > start) {
                NalUnit unit = { data + start, i - start };
                units.push_back(unit);
            }
            i += codeSize;
            start = i;
            inside = true;
        } else {
            ++i;
        }
    }
    if (inside && size > start) {
        NalUnit unit = { data + start, size - start };
        units.push_back(unit);
    }
}

void AppendAnnexB(std::vector<uint8_t> &target, const uint8_t *nal, size_t size) {
    static const uint8_t kStartCode[4] = { 0, 0, 0, 1 };
    target.insert(target.end(), kStartCode, kStartCode + 4);
    target.insert(target.end(), nal, nal + size);
}

bool ParseSpsResolution(const uint8_t *sps, size_t size, int *width, int *height) {
    if (size < 4 || NalTypeOf(sps[0]) != NalSps) {
        return false;
    }
    BitReader reader(sps + 1, size - 1);
    const uint32_t profile = reader.readBits(8);
    reader.readBits(16);
    reader.readUnsignedExpGolomb();
    uint32_t chromaFormat = 1;
    if (profile == 100 || profile == 110 || profile == 122 || profile == 244 || profile == 44 || profile == 83 || profile == 86 || profile == 118 || profile == 128 || profile == 138 || profile == 139 || profile == 134) {
        chromaFormat = reader.readUnsignedExpGolomb();
        if (chromaFormat == 3) {
            reader.readBit();
        }
        reader.readUnsignedExpGolomb();
        reader.readUnsignedExpGolomb();
        reader.readBit();
        if (reader.readBit()) {
            const int lists = chromaFormat == 3 ? 12 : 8;
            for (int i = 0; i < lists; ++i) {
                if (reader.readBit()) {
                    SkipScalingList(reader, i < 6 ? 16 : 64);
                }
            }
        }
    }
    reader.readUnsignedExpGolomb();
    const uint32_t pocType = reader.readUnsignedExpGolomb();
    if (pocType == 0) {
        reader.readUnsignedExpGolomb();
    } else if (pocType == 1) {
        reader.readBit();
        reader.readSignedExpGolomb();
        reader.readSignedExpGolomb();
        const uint32_t cycle = reader.readUnsignedExpGolomb();
        for (uint32_t i = 0; i < cycle && i < 256; ++i) {
            reader.readSignedExpGolomb();
        }
    }
    reader.readUnsignedExpGolomb();
    reader.readBit();
    const uint32_t widthInMbs = reader.readUnsignedExpGolomb() + 1;
    const uint32_t heightInMapUnits = reader.readUnsignedExpGolomb() + 1;
    const uint32_t frameMbsOnly = reader.readBit();
    if (!frameMbsOnly) {
        reader.readBit();
    }
    reader.readBit();
    uint32_t cropLeft = 0;
    uint32_t cropRight = 0;
    uint32_t cropTop = 0;
    uint32_t cropBottom = 0;
    if (reader.readBit()) {
        cropLeft = reader.readUnsignedExpGolomb();
        cropRight = reader.readUnsignedExpGolomb();
        cropTop = reader.readUnsignedExpGolomb();
        cropBottom = reader.readUnsignedExpGolomb();
    }
    if (reader.failed()) {
        return false;
    }
    const uint32_t cropUnitX = chromaFormat == 0 || chromaFormat == 3 ? 1 : 2;
    const uint32_t cropUnitY = (chromaFormat == 1 ? 2 : 1) * (2 - frameMbsOnly);
    const int64_t w = (int64_t)widthInMbs * 16 - (int64_t)(cropLeft + cropRight) * cropUnitX;
    const int64_t h = (int64_t)heightInMapUnits * 16 * (2 - frameMbsOnly) - (int64_t)(cropTop + cropBottom) * cropUnitY;
    if (w <= 0 || h <= 0 || w > 8192 || h > 8192) {
        return false;
    }
    *width = (int)w;
    *height = (int)h;
    return true;
}

}
}
