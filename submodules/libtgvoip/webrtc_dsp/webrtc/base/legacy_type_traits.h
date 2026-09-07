#ifndef WEBRTC_BASE_LEGACY_TYPE_TRAITS_H_
#define WEBRTC_BASE_LEGACY_TYPE_TRAITS_H_

#include <limits>

namespace rtc {
namespace legacy_traits {

template <typename T, T V>
struct integral_constant {
  static const T value = V;
  typedef T value_type;
  typedef integral_constant<T, V> type;
  operator value_type() const { return value; }
};

typedef integral_constant<bool, true> true_type;
typedef integral_constant<bool, false> false_type;

template <bool B, typename T = void>
struct enable_if {};

template <typename T>
struct enable_if<true, T> {
  typedef T type;
};

template <typename T>
struct remove_reference {
  typedef T type;
};

template <typename T>
struct remove_reference<T&> {
  typedef T type;
};

template <typename T>
struct remove_reference<T&&> {
  typedef T type;
};

template <typename T>
struct remove_const {
  typedef T type;
};

template <typename T>
struct remove_const<const T> {
  typedef T type;
};

template <typename T>
struct remove_volatile {
  typedef T type;
};

template <typename T>
struct remove_volatile<volatile T> {
  typedef T type;
};

template <typename T>
struct remove_cv {
  typedef typename remove_const<typename remove_volatile<T>::type>::type type;
};

template <typename T, typename U>
struct is_same : false_type {};

template <typename T>
struct is_same<T, T> : true_type {};

template <typename T>
struct is_integral
    : integral_constant<bool,
                        std::numeric_limits<typename remove_cv<typename remove_reference<T>::type>::type>::is_integer> {};

template <typename T>
struct is_signed
    : integral_constant<bool,
                        is_integral<T>::value &&
                            std::numeric_limits<typename remove_cv<typename remove_reference<T>::type>::type>::is_signed> {};

template <typename T>
struct is_unsigned
    : integral_constant<bool, is_integral<T>::value && !is_signed<T>::value> {};

template <typename T>
struct make_unsigned_base;

template <> struct make_unsigned_base<signed char> { typedef unsigned char type; };
template <> struct make_unsigned_base<unsigned char> { typedef unsigned char type; };
template <> struct make_unsigned_base<char> { typedef unsigned char type; };
template <> struct make_unsigned_base<short> { typedef unsigned short type; };
template <> struct make_unsigned_base<unsigned short> { typedef unsigned short type; };
template <> struct make_unsigned_base<int> { typedef unsigned int type; };
template <> struct make_unsigned_base<unsigned int> { typedef unsigned int type; };
template <> struct make_unsigned_base<long> { typedef unsigned long type; };
template <> struct make_unsigned_base<unsigned long> { typedef unsigned long type; };
template <> struct make_unsigned_base<long long> { typedef unsigned long long type; };
template <> struct make_unsigned_base<unsigned long long> { typedef unsigned long long type; };

template <typename T>
struct make_unsigned {
  typedef typename make_unsigned_base<typename remove_cv<typename remove_reference<T>::type>::type>::type type;
};

template <typename T>
T& Declval();

template <typename T>
void Accept(T);

}
}

#endif
