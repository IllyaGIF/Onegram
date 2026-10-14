#ifndef OG_RELEASE_LOGGING_H
#define OG_RELEASE_LOGGING_H

#if defined(__OBJC__) && !defined(ONEGRAM_DIAGNOSTICS)
#import <Foundation/NSObjCRuntime.h>
#define NSLog(...) ((void)0)
#endif

#endif
