#ifndef OGDiagnostics_h
#define OGDiagnostics_h

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    OGDiagnosticsComponentOnegram = 0,
    OGDiagnosticsComponentHelper = 1
} OGDiagnosticsComponent;

extern bool OGDiagnosticsActive;

static inline bool OGDiagnosticsEnabled(void)
{
    return OGDiagnosticsActive;
}

bool OGDiagnosticsOverride(OGDiagnosticsComponent component, bool *value);
bool OGDiagnosticsSetOverride(OGDiagnosticsComponent component, bool value);
bool OGDiagnosticsResolve(OGDiagnosticsComponent component, bool buildDefault);
void OGDiagnosticsActivate(OGDiagnosticsComponent component, bool buildDefault);

#ifdef __cplusplus
}
#endif

#endif
