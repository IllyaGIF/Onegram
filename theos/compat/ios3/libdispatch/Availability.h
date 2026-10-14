#ifndef ONEGRAM_IOS3_LIBDISPATCH_AVAILABILITY_H
#define ONEGRAM_IOS3_LIBDISPATCH_AVAILABILITY_H

#include_next <Availability.h>

#ifdef __OSX_AVAILABLE_STARTING
#undef __OSX_AVAILABLE_STARTING
#endif
#define __OSX_AVAILABLE_STARTING(_mac, _iphone)

#ifdef __OSX_AVAILABLE_BUT_DEPRECATED
#undef __OSX_AVAILABLE_BUT_DEPRECATED
#endif
#define __OSX_AVAILABLE_BUT_DEPRECATED(_macIntro, _macDep, _iosIntro, _iosDep)

#ifdef __OSX_AVAILABLE_BUT_DEPRECATED_MSG
#undef __OSX_AVAILABLE_BUT_DEPRECATED_MSG
#endif
#define __OSX_AVAILABLE_BUT_DEPRECATED_MSG(_macIntro, _macDep, _iosIntro, _iosDep, _msg)

#endif
