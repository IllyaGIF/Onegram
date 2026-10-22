#ifndef TGIOS6_RTC_BASE_THREAD_H
#define TGIOS6_RTC_BASE_THREAD_H

#include <algorithm>
#include <errno.h>
#include <exception>
#include <functional>
#include <memory>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <string>
#include <sys/time.h>
#include <time.h>
#include <vector>
#ifdef __APPLE__
#include <mach/mach_time.h>
#include <dlfcn.h>
extern "C" void TGIOS6RunThreadTask(void (*task)(void *), void *context);
#endif

namespace rtc {

class Thread {
public:
    static std::unique_ptr<Thread> Create() { return std::unique_ptr<Thread>(new Thread()); }
    static std::unique_ptr<Thread> CreateWithSocketServer() { return Create(); }

    ~Thread() {
        std::vector<Task> cancelled;
        pthread_mutex_lock(&_state->mutex);
        _state->stopping = true;
        cancelled.swap(_state->tasks);
        const bool started = _state->started;
        const pthread_t native = _state->native;
        pthread_cond_signal(&_state->condition);
        pthread_mutex_unlock(&_state->mutex);
        cancelled.clear();
        if (started) {
            if (pthread_equal(pthread_self(), native)) pthread_detach(native);
            else pthread_join(native, NULL);
        }
    }

    void SetName(const std::string &name, const void *) {
        pthread_mutex_lock(&_state->mutex);
        _state->name = name;
        pthread_mutex_unlock(&_state->mutex);
    }

    bool Start() {
        pthread_mutex_lock(&_state->mutex);
        if (_state->started || _state->stopping) {
            const bool started = _state->started && !_state->stopping;
            pthread_mutex_unlock(&_state->mutex);
            return started;
        }
        std::shared_ptr<State> *context = new std::shared_ptr<State>(_state);
        const int error = pthread_create(&_state->native, NULL, &Thread::Run, context);
        if (error == 0) _state->started = true;
        else delete context;
        pthread_mutex_unlock(&_state->mutex);
        return error == 0;
    }

    bool IsCurrent() const {
        pthread_mutex_lock(&_state->mutex);
        const bool current = _state->started && pthread_equal(pthread_self(), _state->native);
        pthread_mutex_unlock(&_state->mutex);
        return current;
    }

    template <class Functor>
    void PostTask(Functor functor) { Enqueue(std::move(functor), 0); }

    template <class Functor, class Delay>
    void PostDelayedTask(Functor functor, Delay delay) { Enqueue(std::move(functor), delay.ms()); }

private:
    struct Task {
        double deadline;
        uint64_t order;
        std::function<void()> functor;
    };
    struct State {
        pthread_mutex_t mutex;
        pthread_cond_t condition;
        pthread_t native = pthread_t();
        bool started = false;
        bool stopping = false;
        uint64_t nextOrder = 0;
        std::string name;
        std::vector<Task> tasks;
        State() {
            if (pthread_mutex_init(&mutex, NULL) != 0) std::terminate();
            pthread_condattr_t attributes;
            pthread_condattr_init(&attributes);
#ifndef __APPLE__
            pthread_condattr_setclock(&attributes, CLOCK_MONOTONIC);
#endif
            if (pthread_cond_init(&condition, &attributes) != 0) std::terminate();
            pthread_condattr_destroy(&attributes);
        }
        ~State() {
            pthread_cond_destroy(&condition);
            pthread_mutex_destroy(&mutex);
        }
    };

    Thread() : _state(new State()) { }
    Thread(const Thread &) = delete;
    Thread &operator=(const Thread &) = delete;
    std::shared_ptr<State> _state;

    static double NowMs() {
#ifdef __APPLE__
        mach_timebase_info_data_t scale;
        mach_timebase_info(&scale);
        return static_cast<double>(mach_absolute_time()) * scale.numer / scale.denom / 1000000.0;
#else
        struct timespec now;
        clock_gettime(CLOCK_MONOTONIC, &now);
        return static_cast<double>(now.tv_sec) * 1000.0 + now.tv_nsec / 1000000.0;
#endif
    }

    template <class Functor>
    void Enqueue(Functor functor, int64_t delayMs) {
        if (!Start()) std::terminate();
        std::shared_ptr<Functor> held(new Functor(std::move(functor)));
        Task task;
        task.deadline = NowMs() + static_cast<double>(std::max<int64_t>(0, delayMs));
        task.functor = [held]() { (*held)(); };
        pthread_mutex_lock(&_state->mutex);
        if (!_state->stopping) {
            task.order = _state->nextOrder++;
            _state->tasks.push_back(task);
            pthread_cond_signal(&_state->condition);
        }
        pthread_mutex_unlock(&_state->mutex);
    }

    static void Execute(void *context) {
        (*static_cast<std::function<void()> *>(context))();
    }

    static void *Run(void *context) {
        std::shared_ptr<State> state = *static_cast<std::shared_ptr<State> *>(context);
        delete static_cast<std::shared_ptr<State> *>(context);
        pthread_mutex_lock(&state->mutex);
        char name[16];
        snprintf(name, sizeof(name), "%s", state->name.c_str());
#ifdef __APPLE__
        typedef int (*SetNameFunction)(const char *);
        SetNameFunction setName = reinterpret_cast<SetNameFunction>(dlsym(RTLD_DEFAULT, "pthread_setname_np"));
        if (setName != NULL) setName(name);
#else
        pthread_setname_np(pthread_self(), name);
#endif
        while (!state->stopping) {
            if (state->tasks.empty()) {
                pthread_cond_wait(&state->condition, &state->mutex);
                continue;
            }
            size_t selected = 0;
            for (size_t i = 1; i < state->tasks.size(); ++i) {
                const Task &left = state->tasks[i];
                const Task &right = state->tasks[selected];
                if (left.deadline < right.deadline || (left.deadline == right.deadline && left.order < right.order)) selected = i;
            }
            const double now = NowMs();
            if (state->tasks[selected].deadline > now) {
                struct timespec timeout;
#ifdef __APPLE__
                const double waitMs = state->tasks[selected].deadline - now;
                timeout.tv_sec = static_cast<time_t>(waitMs / 1000.0);
                timeout.tv_nsec = static_cast<long>((waitMs - timeout.tv_sec * 1000.0) * 1000000.0);
                pthread_cond_timedwait_relative_np(&state->condition, &state->mutex, &timeout);
#else
                const double deadline = state->tasks[selected].deadline;
                timeout.tv_sec = static_cast<time_t>(deadline / 1000.0);
                timeout.tv_nsec = static_cast<long>((deadline - timeout.tv_sec * 1000.0) * 1000000.0);
                pthread_cond_timedwait(&state->condition, &state->mutex, &timeout);
#endif
                continue;
            }
            Task task = std::move(state->tasks[selected]);
            state->tasks.erase(state->tasks.begin() + selected);
            pthread_mutex_unlock(&state->mutex);
#ifdef __APPLE__
            TGIOS6RunThreadTask(&Thread::Execute, &task.functor);
#else
            Execute(&task.functor);
#endif
            task.functor = std::function<void()>();
            pthread_mutex_lock(&state->mutex);
        }
        pthread_mutex_unlock(&state->mutex);
        return NULL;
    }
};

}

#endif
