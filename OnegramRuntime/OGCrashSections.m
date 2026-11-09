#import "OGCrashSections.h"

#include <unistd.h>

static OGCrashSectionWriter volatile OGCrashSectionPythonWriter = NULL;

void OGCrashSectionsSetPythonWriter(OGCrashSectionWriter writer)
{
    OGCrashSectionPythonWriter = writer;
    __sync_synchronize();
}

void OGCrashSectionsWrite(int fd)
{
    OGCrashSectionWriter writer = OGCrashSectionPythonWriter;
    if (writer == NULL)
        return;
    static const char begin[] = "CRASH python-begin\n";
    static const char end[] = "\nCRASH python-end\n";
    write(fd, begin, sizeof(begin) - 1);
    writer(fd);
    write(fd, end, sizeof(end) - 1);
}
