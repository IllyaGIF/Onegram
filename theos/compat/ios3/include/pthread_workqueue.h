#ifndef ONEGRAM_PTHREAD_WORKQUEUE_H
#define ONEGRAM_PTHREAD_WORKQUEUE_H

#include <pthread.h>
#include <stdint.h>

typedef struct _pthread_workqueue *pthread_workqueue_t;
typedef void *pthread_workitem_handle_t;

typedef struct {
    uint32_t sig;
    int queueprio;
    int overcommit;
    unsigned int pad[13];
} pthread_workqueue_attr_t;

#define WORKQ_HIGH_PRIOQUEUE 0
#define WORKQ_DEFAULT_PRIOQUEUE 1
#define WORKQ_LOW_PRIOQUEUE 2

int pthread_workqueue_init_np(void);
int pthread_workqueue_create_np(pthread_workqueue_t *, const pthread_workqueue_attr_t *);
int pthread_workqueue_additem_np(pthread_workqueue_t, void (*)(void *), void *, pthread_workitem_handle_t *, unsigned int *);
int pthread_workqueue_attr_init_np(pthread_workqueue_attr_t *);
int pthread_workqueue_attr_destroy_np(pthread_workqueue_attr_t *);
int pthread_workqueue_attr_setqueuepriority_np(pthread_workqueue_attr_t *, int);
int pthread_workqueue_attr_setovercommit_np(pthread_workqueue_attr_t *, int);

#endif
