#import "OGRemoteClock.h"

#include <math.h>
#include <pthread.h>

static NSString *const OGRemoteClockDifferenceKey = @"OGRemoteClockDifference";
static const NSTimeInterval OGRemoteClockPersistenceThreshold = 1.0;

static pthread_mutex_t OGRemoteClockLock = PTHREAD_MUTEX_INITIALIZER;
static NSTimeInterval OGRemoteClockCurrentDifference = 0.0;
static NSTimeInterval OGRemoteClockPersistedDifference = 0.0;
static BOOL OGRemoteClockLoaded = NO;

static void OGRemoteClockLoadLocked(void)
{
    if (OGRemoteClockLoaded)
        return;
    OGRemoteClockLoaded = YES;
    OGRemoteClockCurrentDifference = [[NSUserDefaults standardUserDefaults] doubleForKey:OGRemoteClockDifferenceKey];
    OGRemoteClockPersistedDifference = OGRemoteClockCurrentDifference;
}

NSTimeInterval OGRemoteClockDifference(void)
{
    pthread_mutex_lock(&OGRemoteClockLock);
    OGRemoteClockLoadLocked();
    NSTimeInterval difference = OGRemoteClockCurrentDifference;
    pthread_mutex_unlock(&OGRemoteClockLock);
    return difference;
}

NSTimeInterval OGRemoteClockTime(void)
{
    return CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970 + OGRemoteClockDifference();
}

void OGRemoteClockSetDifference(NSTimeInterval difference)
{
    if (isnan(difference) || isinf(difference))
        return;

    pthread_mutex_lock(&OGRemoteClockLock);
    OGRemoteClockLoadLocked();
    OGRemoteClockCurrentDifference = difference;
    BOOL persist = fabs(difference - OGRemoteClockPersistedDifference) >= OGRemoteClockPersistenceThreshold;
    if (persist)
        OGRemoteClockPersistedDifference = difference;
    pthread_mutex_unlock(&OGRemoteClockLock);

    if (persist)
        [[NSUserDefaults standardUserDefaults] setDouble:difference forKey:OGRemoteClockDifferenceKey];
}
