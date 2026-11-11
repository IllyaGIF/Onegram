#ifndef OG_COMPAT_RTC_BASE_COPY_ON_WRITE_BUFFER_H
#define OG_COMPAT_RTC_BASE_COPY_ON_WRITE_BUFFER_H

#include <stdint.h>
#include <string>
#include <vector>

namespace rtc {

class CopyOnWriteBuffer {
	std::vector<uint8_t> _bytes;

	uint8_t *first() {
		return _bytes.empty() ? nullptr : &_bytes[0];
	}

	const uint8_t *first() const {
		return _bytes.empty() ? nullptr : &_bytes[0];
	}

public:
	CopyOnWriteBuffer() = default;

	explicit CopyOnWriteBuffer(size_t count) : _bytes(count) {
	}

	CopyOnWriteBuffer(const uint8_t *source, size_t count) : _bytes(source, source + count) {
	}

	size_t size() const {
		return _bytes.size();
	}

	void SetSize(size_t count) {
		_bytes.resize(count);
	}

	uint8_t *data() {
		return first();
	}

	const uint8_t *data() const {
		return first();
	}

	const uint8_t *cdata() const {
		return first();
	}

	void *MutableData() {
		return first();
	}

	void AppendData(const uint8_t *source, size_t count) {
		if (source == nullptr || count == 0) {
			return;
		}
		_bytes.insert(_bytes.end(), source, source + count);
	}

	void AppendData(const char *source, size_t count) {
		AppendData(reinterpret_cast<const uint8_t *>(source), count);
	}

	void AppendData(const CopyOnWriteBuffer &other) {
		AppendData(other.first(), other.size());
	}
};

class Buffer : public CopyOnWriteBuffer {
public:
	Buffer() = default;

	explicit Buffer(size_t count) : CopyOnWriteBuffer(count) {
	}

	Buffer(const uint8_t *source, size_t count) : CopyOnWriteBuffer(source, count) {
	}
};

struct PacketOptions {
	int packet_id = 0;
};

struct SentPacket {
	int packet_id = 0;
	int64_t send_time_ms = 0;
};

class Socket {
public:
	enum Option {
		OPT_DUMMY
	};
};

inline int64_t TimeMillis() {
	return 0;
}

class PacketTransportInternal {
public:
	virtual ~PacketTransportInternal() = default;

	virtual bool writable() const { return false; }
	virtual bool receiving() const { return false; }
	virtual int GetError() { return 0; }
	virtual int SetOption(Socket::Option, int) { return 0; }
	virtual bool GetOption(Socket::Option, int *) { return false; }
	virtual int SendPacket(const char *, size_t, const PacketOptions &, int = 0) { return -1; }

	virtual const std::string &transport_name() const {
		static const std::string unnamed;
		return unnamed;
	}
};

} // namespace rtc

#endif
