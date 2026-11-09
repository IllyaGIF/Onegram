#ifndef OGPluginAvailability_h
#define OGPluginAvailability_h

#if !defined(ONEGRAM_ARMV6) && (!defined(ONEGRAM_PLUGINS) || ONEGRAM_PLUGINS)
#define OG_PLUGINS_AVAILABLE 1
#else
#define OG_PLUGINS_AVAILABLE 0
#endif

#endif
