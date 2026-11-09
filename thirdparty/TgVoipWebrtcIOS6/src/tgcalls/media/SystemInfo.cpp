#include "media/SystemInfo.h"

#include <pthread.h>
#include <sys/sysctl.h>
#include <sys/types.h>

namespace tgcalls {

namespace {

pthread_once_t processorCountOnce = PTHREAD_ONCE_INIT;
int processorCount = 1;

void ReadProcessorCount() {
    int value = 0;
    size_t size = sizeof(value);
    if (sysctlbyname("hw.ncpu", &value, &size, 0, 0) == 0 && value > 0) {
        processorCount = value;
    }
}

}

int ProcessorCount() {
    pthread_once(&processorCountOnce, &ReadProcessorCount);
    return processorCount;
}

}
