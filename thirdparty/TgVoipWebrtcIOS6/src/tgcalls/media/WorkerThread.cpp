#include "media/WorkerThread.h"

#include "rtp/RtpTime.h"

#include <errno.h>
#include <sched.h>
#include <sys/time.h>

namespace tgcalls {

WorkerThread::WorkerThread() :
_started(false),
_stopping(false),
_priorityOffset(0) {
    pthread_mutex_init(&_mutex, 0);
    pthread_cond_init(&_condition, 0);
}

WorkerThread::~WorkerThread() {
    stop();
    pthread_cond_destroy(&_condition);
    pthread_mutex_destroy(&_mutex);
}

bool WorkerThread::start(int priorityOffset) {
    ScopedMutex lock(&_mutex);
    if (_started) {
        return true;
    }
    _priorityOffset = priorityOffset;
    _stopping = false;
    _started = pthread_create(&_thread, 0, &WorkerThread::entry, this) == 0;
    return _started;
}

void WorkerThread::stop() {
    bool join = false;
    {
        ScopedMutex lock(&_mutex);
        if (_started && !_stopping) {
            _stopping = true;
            join = true;
            pthread_cond_signal(&_condition);
        }
    }
    if (join && !pthread_equal(pthread_self(), _thread)) {
        pthread_join(_thread, 0);
    }
}

void WorkerThread::wake() {
    pthread_cond_signal(&_condition);
}

void *WorkerThread::entry(void *context) {
    static_cast<WorkerThread *>(context)->run();
    return 0;
}

void WorkerThread::run() {
    struct sched_param parameters;
    int policy = SCHED_OTHER;
    if (pthread_getschedparam(pthread_self(), &policy, &parameters) == 0) {
        const int maximum = sched_get_priority_max(policy);
        const int minimum = sched_get_priority_min(policy);
        int priority = parameters.sched_priority + _priorityOffset;
        if (priority > maximum) {
            priority = maximum;
        }
        if (priority < minimum) {
            priority = minimum;
        }
        parameters.sched_priority = priority;
        pthread_setschedparam(pthread_self(), policy, &parameters);
    }
    for (;;) {
        pthread_mutex_lock(&_mutex);
        if (_stopping) {
            pthread_mutex_unlock(&_mutex);
            break;
        }
        const int64_t now = rtp::MonotonicMicros();
        if (!hasPendingWork()) {
            const int64_t wake = nextWakeMicros(now);
            if (wake > now) {
                const int64_t delay = wake - now;
                struct timeval current;
                gettimeofday(&current, 0);
                const int64_t targetMicros = (int64_t)current.tv_sec * 1000000 + current.tv_usec + delay;
                struct timespec deadline;
                deadline.tv_sec = (time_t)(targetMicros / 1000000);
                deadline.tv_nsec = (long)((targetMicros % 1000000) * 1000);
                pthread_cond_timedwait(&_condition, &_mutex, &deadline);
            }
        }
        const bool stopping = _stopping;
        pthread_mutex_unlock(&_mutex);
        if (stopping) {
            break;
        }
        runIteration(rtp::MonotonicMicros());
    }
}

}
