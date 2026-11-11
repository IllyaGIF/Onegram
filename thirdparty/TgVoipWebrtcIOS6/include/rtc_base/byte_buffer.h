#ifndef OG_COMPAT_RTC_BASE_BYTE_BUFFER_H
#define OG_COMPAT_RTC_BASE_BYTE_BUFFER_H

#include <algorithm>
#include <stdint.h>
#include <string>
#include <vector>

namespace rtc {

template <class T>
class ArrayView {
	T *_data;
	size_t _size;

public:
	ArrayView(T *data, size_t size) : _data(data), _size(size) {
	}

	size_t size() const {
		return _size;
	}

	T *data() const {
		return _data;
	}
};

class ByteBufferWriter {
	std::vector<uint8_t> _data;

	void appendBigEndian(uint32_t value, int byteCount) {
		for (int shift = (byteCount - 1) * 8; shift >= 0; shift -= 8) {
			_data.push_back((uint8_t)(value >> shift));
		}
	}

public:
	size_t Length() const {
		return _data.size();
	}

	const char *Data() const {
		if (_data.empty()) {
			return nullptr;
		}
		return reinterpret_cast<const char *>(&_data[0]);
	}

	void WriteUInt8(uint8_t value) {
		appendBigEndian(value, 1);
	}

	void WriteUInt16(uint16_t value) {
		appendBigEndian(value, 2);
	}

	void WriteUInt32(uint32_t value) {
		appendBigEndian(value, 4);
	}

	void WriteString(const std::string &text) {
		_data.insert(_data.end(), text.begin(), text.end());
	}

	void WriteBytes(const uint8_t *bytes, size_t count) {
		if (bytes == nullptr || count == 0) {
			return;
		}
		_data.insert(_data.end(), bytes, bytes + count);
	}
};

class ByteBufferReader {
	const uint8_t *_bytes;
	size_t _end;
	size_t _position;

	bool readBigEndian(uint32_t *out, size_t byteCount) {
		if (Length() < byteCount) {
			return false;
		}
		uint32_t accumulated = 0;
		for (size_t i = 0; i < byteCount; i++) {
			accumulated = (accumulated << 8) | _bytes[_position + i];
		}
		*out = accumulated;
		_position += byteCount;
		return true;
	}

public:
	ByteBufferReader(const char *data, size_t length) : _bytes(reinterpret_cast<const uint8_t *>(data)), _end(length), _position(0) {
	}

	const uint8_t *Data() const {
		return _bytes + _position;
	}

	size_t Length() const {
		return _end - _position;
	}

	void Consume(size_t count) {
		_position = std::min(_position + count, _end);
	}

	bool ReadUInt8(uint8_t *out) {
		uint32_t wide = 0;
		if (!readBigEndian(&wide, 1)) {
			return false;
		}
		*out = (uint8_t)wide;
		return true;
	}

	bool ReadUInt16(uint16_t *out) {
		uint32_t wide = 0;
		if (!readBigEndian(&wide, 2)) {
			return false;
		}
		*out = (uint16_t)wide;
		return true;
	}

	bool ReadUInt32(uint32_t *out) {
		return readBigEndian(out, 4);
	}

	bool ReadString(std::string *out, size_t count) {
		if (Length() < count) {
			return false;
		}
		out->assign(reinterpret_cast<const char *>(_bytes + _position), count);
		_position += count;
		return true;
	}

	bool ReadBytes(ArrayView<uint8_t> destination) {
		if (Length() < destination.size()) {
			return false;
		}
		std::copy(_bytes + _position, _bytes + _position + destination.size(), destination.data());
		_position += destination.size();
		return true;
	}
};

} // namespace rtc

#endif
