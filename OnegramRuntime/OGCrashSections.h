#ifndef OGCrashSections_h
#define OGCrashSections_h

typedef void (*OGCrashSectionWriter)(int fd);

#ifdef __cplusplus
extern "C" {
#endif

void OGCrashSectionsSetPythonWriter(OGCrashSectionWriter writer);
void OGCrashSectionsWrite(int fd);

#ifdef __cplusplus
}
#endif

#endif
