#ifndef OG_COMPAT_ABSL_OPTIONAL_H
#define OG_COMPAT_ABSL_OPTIONAL_H

#include <new>
#include <utility>

namespace absl {

struct nullopt_t {
	explicit nullopt_t(int) {
	}
};

static const nullopt_t nullopt(0);

template <class T>
class optional {
public:
	optional() : _engaged(false) {
	}

	optional(nullopt_t) : _engaged(false) {
	}

	optional(const T &value) : _engaged(false) {
		construct(value);
	}

	optional(T &&value) : _engaged(false) {
		construct(std::move(value));
	}

	optional(const optional &other) : _engaged(false) {
		if (other._engaged) {
			construct(other.value());
		}
	}

	optional(optional &&other) : _engaged(false) {
		if (other._engaged) {
			construct(std::move(other.value()));
		}
	}

	~optional() {
		reset();
	}

	optional &operator=(nullopt_t) {
		reset();
		return *this;
	}

	optional &operator=(const optional &other) {
		if (this != &other) {
			reset();
			if (other._engaged) {
				construct(other.value());
			}
		}
		return *this;
	}

	explicit operator bool() const {
		return _engaged;
	}

	bool has_value() const {
		return _engaged;
	}

	T &value() {
		return *reinterpret_cast<T *>(&_storage);
	}

	const T &value() const {
		return *reinterpret_cast<const T *>(&_storage);
	}

	T &operator*() {
		return value();
	}

	const T &operator*() const {
		return value();
	}

	T *operator->() {
		return &value();
	}

	const T *operator->() const {
		return &value();
	}

private:
	template <class Source>
	void construct(Source &&source) {
		new (&_storage) T(std::forward<Source>(source));
		_engaged = true;
	}

	void reset() {
		if (_engaged) {
			value().~T();
			_engaged = false;
		}
	}

	bool _engaged;
	typename std::aligned_storage<sizeof(T), alignof(T)>::type _storage;
};

} // namespace absl

#endif
