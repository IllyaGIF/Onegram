#ifndef OG_COMPAT_ABSL_VARIANT_H
#define OG_COMPAT_ABSL_VARIANT_H

#include <new>
#include <utility>

namespace absl {

namespace og_variant_detail {

constexpr size_t largestOf(size_t only) {
	return only;
}

template <class... Rest>
constexpr size_t largestOf(size_t first, size_t second, Rest... rest) {
	return largestOf(first > second ? first : second, rest...);
}

template <class Target, class... Alternatives>
struct SlotLookup;

template <class Target>
struct SlotLookup<Target> {
	static const int value = -1;
};

template <class Target, class Head, class... Tail>
struct SlotLookup<Target, Head, Tail...> {
	static const int deeper = SlotLookup<Target, Tail...>::value;
	static const int value = std::is_same<Target, Head>::value ? 0 : (deeper < 0 ? -1 : deeper + 1);
};

template <class T>
void destroyAt(void *place) {
	static_cast<T *>(place)->~T();
}

template <class T>
void copyInto(const void *source, void *place) {
	new (place) T(*static_cast<const T *>(source));
}

struct SlotOps {
	void (*destroy)(void *place);
	void (*copy)(const void *source, void *place);
};

template <class... Alternatives>
const SlotOps &opsFor(int slot) {
	static const SlotOps table[] = {{&destroyAt<Alternatives>, &copyInto<Alternatives>}...};
	return table[slot];
}

} // namespace og_variant_detail

template <class... Ts>
class variant {
public:
	variant() : _active(-1) {
	}

	template <class T>
	variant(const T &value) : _active(-1) {
		assign(value);
	}

	template <class T, typename std::enable_if<!std::is_same<typename std::decay<T>::type, variant>::value, int>::type = 0>
	variant(T &&value) : _active(-1) {
		assign(std::forward<T>(value));
	}

	variant(const variant &other) : _active(other._active) {
		duplicateFrom(other);
	}

	~variant() {
		reset();
	}

	variant &operator=(const variant &other) {
		if (this != &other) {
			reset();
			_active = other._active;
			duplicateFrom(other);
		}
		return *this;
	}

	template <class T, typename std::enable_if<!std::is_same<typename std::decay<T>::type, variant>::value, int>::type = 0>
	variant &operator=(T &&value) {
		assign(std::forward<T>(value));
		return *this;
	}

	int index() const {
		return _active;
	}

	template <class T>
	T *get_if() {
		return holds<T>() ? reinterpret_cast<T *>(&_storage) : nullptr;
	}

	template <class T>
	const T *get_if() const {
		return holds<T>() ? reinterpret_cast<const T *>(&_storage) : nullptr;
	}

private:
	template <class T>
	bool holds() const {
		return _active == og_variant_detail::SlotLookup<T, Ts...>::value;
	}

	void duplicateFrom(const variant &other) {
		if (other._active >= 0) {
			og_variant_detail::opsFor<Ts...>(other._active).copy(&other._storage, &_storage);
		}
	}

	template <class T>
	void assign(T &&value) {
		reset();
		typedef typename std::decay<T>::type Decayed;
		_active = og_variant_detail::SlotLookup<Decayed, Ts...>::value;
		static_assert(og_variant_detail::SlotLookup<Decayed, Ts...>::value >= 0, "type is not in absl::variant");
		new (&_storage) Decayed(std::forward<T>(value));
	}

	void reset() {
		if (_active >= 0) {
			og_variant_detail::opsFor<Ts...>(_active).destroy(&_storage);
			_active = -1;
		}
	}

	int _active;
	typename std::aligned_storage<
		og_variant_detail::largestOf(sizeof(Ts)...),
		og_variant_detail::largestOf(alignof(Ts)...)>::type _storage;
};

template <class T, class... Ts>
T *get_if(variant<Ts...> *value) {
	return value ? value->template get_if<T>() : nullptr;
}

template <class T, class... Ts>
const T *get_if(const variant<Ts...> *value) {
	return value ? value->template get_if<T>() : nullptr;
}

} // namespace absl

#endif
