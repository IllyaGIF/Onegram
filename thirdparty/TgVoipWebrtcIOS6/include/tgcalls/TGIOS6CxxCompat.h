#ifndef TGIOS6_CXX_COMPAT_H
#define TGIOS6_CXX_COMPAT_H

#include <memory>
#include <tr1/memory>
#include <functional>
#include <tr1/functional>
#include <utility>
#include <sstream>
#include <string>
#include <stddef.h>

namespace std {

typedef decltype(nullptr) nullptr_t;

template <class T>
using shared_ptr = tr1::shared_ptr<T>;

template <class T>
using weak_ptr = tr1::weak_ptr<T>;

template <class T>
using enable_shared_from_this = tr1::enable_shared_from_this<T>;

template <class T, T V>
struct integral_constant {
    static const T value = V;
    typedef T value_type;
    typedef integral_constant type;
    operator value_type() const { return value; }
};

typedef integral_constant<bool, true> true_type;
typedef integral_constant<bool, false> false_type;

template <class T, class U>
struct is_same : false_type {};

template <class T>
struct is_same<T, T> : true_type {};

template <bool B, class T = void>
struct enable_if {};

template <class T>
struct enable_if<true, T> { typedef T type; };

template <bool B, class T = void>
using enable_if_t = typename enable_if<B, T>::type;

template <class T>
struct remove_reference { typedef T type; };

template <class T>
struct remove_reference<T &> { typedef T type; };

template <class T>
struct remove_reference<T &&> { typedef T type; };

template <class T>
struct remove_const { typedef T type; };

template <class T>
struct remove_const<const T> { typedef T type; };

template <class T>
struct remove_volatile { typedef T type; };

template <class T>
struct remove_volatile<volatile T> { typedef T type; };

template <class T>
struct remove_cv {
    typedef typename remove_volatile<typename remove_const<T>::type>::type type;
};

template <class T>
struct decay {
    typedef typename remove_cv<typename remove_reference<T>::type>::type type;
};

template <size_t Len, size_t Align>
struct aligned_storage {
    struct type {
        unsigned char data[Len];
    } __attribute__((aligned(Align)));
};

template <class T>
typename remove_reference<T>::type &&move(T &&value) {
    return static_cast<typename remove_reference<T>::type &&>(value);
}

template <class T>
T &&forward(typename remove_reference<T>::type &value) {
    return static_cast<T &&>(value);
}

template <class T>
T &&forward(typename remove_reference<T>::type &&value) {
    return static_cast<T &&>(value);
}

template <class T>
typename remove_reference<T>::type &&declval();

template <class Signature>
using function = tr1::function<Signature>;

template <class T>
class unique_ptr {
public:
    typedef T element_type;

    unique_ptr() : _ptr(NULL) {}
    unique_ptr(nullptr_t) : _ptr(NULL) {}
    explicit unique_ptr(T *ptr) : _ptr(ptr) {}

    unique_ptr(unique_ptr &&other) : _ptr(other.release()) {}

    template <class U>
    unique_ptr(unique_ptr<U> &&other) : _ptr(other.release()) {}

    ~unique_ptr() {
        delete _ptr;
    }

    unique_ptr &operator=(unique_ptr &&other) {
        if (this != &other)
            reset(other.release());
        return *this;
    }

    template <class U>
    unique_ptr &operator=(unique_ptr<U> &&other) {
        reset(other.release());
        return *this;
    }

    unique_ptr &operator=(nullptr_t) {
        reset();
        return *this;
    }

    T *get() const { return _ptr; }
    T *operator->() const { return _ptr; }
    T &operator*() const { return *_ptr; }
    explicit operator bool() const { return _ptr != NULL; }

    T *release() {
        T *result = _ptr;
        _ptr = NULL;
        return result;
    }

    void reset(T *ptr = NULL) {
        if (_ptr != ptr) {
            delete _ptr;
            _ptr = ptr;
        }
    }

    void swap(unique_ptr &other) {
        T *tmp = _ptr;
        _ptr = other._ptr;
        other._ptr = tmp;
    }

private:
    unique_ptr(const unique_ptr &) = delete;
    unique_ptr &operator=(const unique_ptr &) = delete;
    T *_ptr;
};

template <class T, class... Args>
unique_ptr<T> make_unique(Args &&... args) {
    return unique_ptr<T>(new T(forward<Args>(args)...));
}

template <class T, class... Args>
shared_ptr<T> make_shared(Args &&... args) {
    return shared_ptr<T>(new T(forward<Args>(args)...));
}

template <class T>
string to_string(const T &value) {
    ostringstream stream;
    stream << value;
    return stream.str();
}

}


#endif
