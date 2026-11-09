#ifndef TGCALLS_MEDIA_WORKER_THREAD_H
#define TGCALLS_MEDIA_WORKER_THREAD_H

#include <pthread.h>
#include <stdint.h>

namespace tgcalls {

class ScopedMutex {
public:
    explicit ScopedMutex(pthread_mutex_t *mutex) : _mutex(mutex) { pthread_mutex_lock(_mutex); }
    ~ScopedMutex() { pthread_mutex_unlock(_mutex); }

private:
    ScopedMutex(const ScopedMutex &) = delete;
    ScopedMutex &operator=(const ScopedMutex &) = delete;

    pthread_mutex_t *_mutex;
};

class WorkerThread {
public:
    WorkerThread();
    virtual ~WorkerThread();

    bool start(int priorityOffset);
    void stop();
    void wake();

protected:
    virtual void runIteration(int64_t nowMicros) = 0;
    virtual int64_t nextWakeMicros(int64_t nowMicros) = 0;
    virtual bool hasPendingWork() = 0;

    pthread_mutex_t _mutex;

private:
    static void *entry(void *context);
    void run();

    pthread_cond_t _condition;
    pthread_t _thread;
    bool _started;
    bool _stopping;
    int _priorityOffset;
};

}

#endif
