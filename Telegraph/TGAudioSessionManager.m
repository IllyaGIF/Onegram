#import "TGAudioSessionManager.h"

#import <pthread.h>
#import <AudioToolbox/AudioToolbox.h>

#import "TGTelegraph.h"

static SPipe *TGAudioSessionRouteChangePipe = nil;

static void TGLegacyAudioSessionInterruptionListener(void *clientData, UInt32 interruptionState);
static void TGLegacyAudioSessionRouteListener(void *clientData, AudioSessionPropertyID propertyId, UInt32 propertySize, const void *propertyValue);

@interface TGAudioSessionInterruptionToken : NSObject
{
    pthread_mutex_t _mutex;
    void (^_block)();
    bool _active;
}

- (instancetype)initWithBlock:(void (^)())block;
- (void)invoke;
- (void)invalidate;

@end

@implementation TGAudioSessionInterruptionToken

- (instancetype)initWithBlock:(void (^)())block
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutexattr_t attributes;
        pthread_mutexattr_init(&attributes);
        pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_mutex, &attributes);
        pthread_mutexattr_destroy(&attributes);
        _block = block != nil ? [block copy] : [^{} copy];
        _active = true;
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_lock(&_mutex);
    _active = false;
    _block = nil;
    pthread_mutex_unlock(&_mutex);
    pthread_mutex_destroy(&_mutex);
}

- (void)invoke
{
    pthread_mutex_lock(&_mutex);
    if (_active && _block != nil)
    {
        void (^block)() = [_block copy];
        block();
    }
    pthread_mutex_unlock(&_mutex);
}

- (void)invalidate
{
    pthread_mutex_lock(&_mutex);
    _active = false;
    _block = nil;
    pthread_mutex_unlock(&_mutex);
}

@end

@interface TGAudioSessionManager ()
{
    pthread_mutex_t _mutex;
    int32_t _clientId;
    
    TGAudioSessionType _currentType;
    bool _currentActive;
    NSMutableArray *_currentClientIds;
    NSMutableArray *_currentInterruptedArray;
    
    bool _isInterrupting;
}

- (OSStatus)initializeLegacyAudioSession;

@end

@implementation TGAudioSessionManager

+ (TGAudioSessionManager *)instance
{
    static TGAudioSessionManager *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
                  {
                      singleton = [[TGAudioSessionManager alloc] init];
                  });
    
    return singleton;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutexattr_t attributes;
        pthread_mutexattr_init(&attributes);
        pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_mutex, &attributes);
        pthread_mutexattr_destroy(&attributes);

        if (iosMajorVersion() >= 6)
        {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionRouteChanged:) name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];
        }
        else
        {
            OSStatus status = [self initializeLegacyAudioSession];
            if (status != noErr)
                TGLog(@"(TGAudioSessionManager legacy initialize error %d)", (int)status);
        }
    }

    return self;
}

- (OSStatus)initializeLegacyAudioSession
{
    OSStatus status = AudioSessionInitialize(CFRunLoopGetMain(), kCFRunLoopCommonModes, TGLegacyAudioSessionInterruptionListener, (__bridge void *)self);
    if (status == kAudioSessionAlreadyInitialized)
        return noErr;

    if (status != noErr)
        return status;

    status = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, TGLegacyAudioSessionRouteListener, (__bridge void *)self);
    return status;
}

- (void)dealloc
{
    if (iosMajorVersion() >= 6)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
    else
    {
        AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_AudioRouteChange, TGLegacyAudioSessionRouteListener, (__bridge void *)self);
    }
    pthread_mutex_destroy(&_mutex);
}

- (NSString *)nativeCategoryForType:(TGAudioSessionType)type
{
    switch (type)
    {
        case TGAudioSessionTypePlayVoice:
        case TGAudioSessionTypePlayMusic:
        case TGAudioSessionTypePlayVideo:
        case TGAudioSessionTypePlayEmbedVideo:
            return AVAudioSessionCategoryPlayback;
            
        case TGAudioSessionTypePlayAndRecord:
        case TGAudioSessionTypePlayAndRecordHeadphones:
        case TGAudioSessionTypeCall:
            return AVAudioSessionCategoryPlayAndRecord;
    }
    
    return AVAudioSessionCategoryPlayback;
}

- (id<SDisposable>)requestSessionWithType:(TGAudioSessionType)type interrupted:(void (^)())interrupted
{
    NSArray *interruptedToInvoke = nil;
    id<SDisposable> result = nil;
    TGAudioSessionInterruptionToken *interruptionToken = [[TGAudioSessionInterruptionToken alloc] initWithBlock:interrupted];
    
    if (type == TGAudioSessionTypePlayVideo)
    {
        [TGTelegraphInstance.musicPlayer controlPause];
    }
    
    pthread_mutex_lock(&_mutex);
    {
        if (_currentType != TGAudioSessionTypeCall)
        {
            if (_isInterrupting)
            {
                interruptedToInvoke = @[interruptionToken];
            }
            else
            {
                if (_currentInterruptedArray == nil)
                    _currentInterruptedArray = [[NSMutableArray alloc] init];
                
                if (_currentClientIds == nil)
                    _currentClientIds = [[NSMutableArray alloc] init];
                
                int32_t clientId = _clientId++;
                
                if (!_currentActive || _currentType != type)
                {
                    _currentActive = true;
                    _currentType = type;
                    
                    interruptedToInvoke = [[NSArray alloc] initWithArray:_currentInterruptedArray];
                    [_currentInterruptedArray removeAllObjects];
                    [_currentClientIds removeAllObjects];
                    
                    NSError *error = nil;
                    
                    TGLog(@"(TGAudioSessionManager setting category %d active overriding port: %d)",
                          (int)type,
                          ((type == TGAudioSessionTypePlayAndRecordHeadphones ||
                            type == TGAudioSessionTypePlayMusic ||
                            type == TGAudioSessionTypePlayVideo ||
                            type == TGAudioSessionTypePlayEmbedVideo)) ? 1 : 0);
                    
                    bool shouldUseSpeaker = !(type == TGAudioSessionTypePlayAndRecordHeadphones ||
                                              type == TGAudioSessionTypePlayMusic ||
                                              type == TGAudioSessionTypePlayVideo ||
                                              type == TGAudioSessionTypePlayEmbedVideo ||
                                              type == TGAudioSessionTypeCall);

                    if (iosMajorVersion() >= 6)
                    {
                        AVAudioSession *session = [AVAudioSession sharedInstance];
                        [session
                         setCategory:[self nativeCategoryForType:type]
                         withOptions:(type == TGAudioSessionTypePlayAndRecord ||
                                      type == TGAudioSessionTypePlayAndRecordHeadphones ||
                                      type == TGAudioSessionTypeCall)
                         ? AVAudioSessionCategoryOptionAllowBluetooth
                         : 0
                         error:&error];

                        if (error != nil)
                            TGLog(@"(TGAudioSessionManager setting category %d error %@)", (int)type, error);

                        error = nil;
                        [session setMode:(type == TGAudioSessionTypeCall ? AVAudioSessionModeVoiceChat : AVAudioSessionModeDefault) error:&error];
                        if (error != nil)
                            TGLog(@"(TGAudioSessionManager setting mode error %@)", error);

                        error = nil;
                        if (type == TGAudioSessionTypeCall)
                        {
                            Float64 preferredRate = 48000.0;
                            OSStatus rateStatus = AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareSampleRate, sizeof(preferredRate), &preferredRate);
                            if (rateStatus != noErr)
                                TGLog(@"LAT audioSession preferredRate error %d", (int)rateStatus);

                            [session setPreferredIOBufferDuration:0.010 error:&error];
                            if (error != nil)
                                TGLog(@"LAT audioSession preferredBuffer error %@", error);
                            error = nil;
                        }

                        [session setActive:true error:&error];
                        if (error != nil)
                            TGLog(@"(TGAudioSessionManager setting active error %@)", error);

                        if (type == TGAudioSessionTypeCall)
                        {
                            Float64 actualRate = 0.0;
                            UInt32 actualRateSize = sizeof(actualRate);
                            OSStatus actualRateStatus = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &actualRateSize, &actualRate);
                            TGLog(@"LAT audioSession active preferred=%.4f actual=%.4f rate=%.0f rateStatus=%d", 0.010, [session IOBufferDuration], actualRate, (int)actualRateStatus);
                        }

                        error = nil;
                        [session overrideOutputAudioPort:(shouldUseSpeaker ? AVAudioSessionPortOverrideSpeaker : AVAudioSessionPortOverrideNone) error:&error];
                        if (error != nil)
                            TGLog(@"(TGAudioSessionManager override port error %@)", error);
                    }
                    else
                    {
                        OSStatus status = [self initializeLegacyAudioSession];
                        if (status != noErr)
                            TGLog(@"(TGAudioSessionManager legacy initialize error %d)", (int)status);

                        UInt32 category = (type == TGAudioSessionTypePlayAndRecord || type == TGAudioSessionTypePlayAndRecordHeadphones || type == TGAudioSessionTypeCall) ? kAudioSessionCategory_PlayAndRecord : kAudioSessionCategory_MediaPlayback;
                        TGLog(@"AUDIO category.begin type=%d category=%u", (int)type, (unsigned int)category);
                        status = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
                        if (status == kAudioSessionNotInitialized && [self initializeLegacyAudioSession] == noErr)
                            status = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
                        TGLog(@"AUDIO category.end type=%d status=%d", (int)type, (int)status);
                        if (status != noErr)
                            TGLog(@"(TGAudioSessionManager legacy category error %d)", (int)status);

                        if (type == TGAudioSessionTypeCall)
                        {
                            Float64 preferredRate = 48000.0;
                            OSStatus rateStatus = AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareSampleRate, sizeof(preferredRate), &preferredRate);
                            if (rateStatus != noErr)
                                TGLog(@"LAT audioSession preferredRate error %d", (int)rateStatus);

                            Float32 preferredDuration = 0.010f;
                            OSStatus preferredStatus = AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(preferredDuration), &preferredDuration);
                            if (preferredStatus != noErr)
                                TGLog(@"LAT audioSession preferredBuffer legacyError %d", (int)preferredStatus);
                        }

                        TGLog(@"AUDIO active.begin type=%d", (int)type);
                        status = AudioSessionSetActive(true);
                        if (status == kAudioSessionNotInitialized && [self initializeLegacyAudioSession] == noErr)
                        {
                            AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
                            status = AudioSessionSetActive(true);
                        }
                        TGLog(@"AUDIO active.end type=%d status=%d", (int)type, (int)status);
                        if (status != noErr)
                            TGLog(@"(TGAudioSessionManager legacy active error %d)", (int)status);

                        if (category == kAudioSessionCategory_PlayAndRecord)
                        {
                            UInt32 route = shouldUseSpeaker ? kAudioSessionOverrideAudioRoute_Speaker : kAudioSessionOverrideAudioRoute_None;
                            status = AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(route), &route);
                            if (status != noErr)
                                TGLog(@"(TGAudioSessionManager legacy override port error %d)", (int)status);
                        }
                    }
                }
                
                [_currentInterruptedArray addObject:interruptionToken];
                [_currentClientIds addObject:@(clientId)];
                
                TGAudioSessionManager *manager = self;
                result = [[SBlockDisposable alloc] initWithBlock:^
                          {
                              [interruptionToken invalidate];
                              [manager endSessionForClientId:clientId];
                          }];
            }
        }
    }
    pthread_mutex_unlock(&_mutex);
    
    for (TGAudioSessionInterruptionToken *token in interruptedToInvoke)
    {
        [token invoke];
        [token invalidate];
    }
    
    return result;
}

- (void)cancelCurrentSession
{
    [self cancelCurrentSession:false];
}

- (void)cancelCurrentSession:(bool)interrupted
{
    if (interrupted)
    {
        bool ignore = false;
        
        pthread_mutex_lock(&_mutex);
        {
            if (_currentType == TGAudioSessionTypeCall ||
                _currentType == TGAudioSessionTypePlayEmbedVideo)
            {
                ignore = true;
            }
        }
        pthread_mutex_unlock(&_mutex);
        
        if (ignore)
            return;
    }
    
    NSArray *interruptedToInvoke = nil;
    
    pthread_mutex_lock(&_mutex);
    {
        _isInterrupting = true;
        interruptedToInvoke = [[NSArray alloc] initWithArray:_currentInterruptedArray];
    }
    pthread_mutex_unlock(&_mutex);
    
    for (TGAudioSessionInterruptionToken *token in interruptedToInvoke)
    {
        [token invoke];
        [token invalidate];
    }
    
    pthread_mutex_lock(&_mutex);
    {
        _isInterrupting = false;
        
        [_currentClientIds removeAllObjects];
        [_currentInterruptedArray removeAllObjects];
        
        TGAudioSessionType previousType = _currentType;
        _currentActive = false;
        _currentType = TGAudioSessionTypePlayMusic;
        
        TGLog(@"(TGAudioSessionManager setting inactive)");
        
        if (iosMajorVersion() >= 6)
        {
            NSError *error = nil;
            AVAudioSession *session = [AVAudioSession sharedInstance];
            [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
            if (error != nil)
                TGLog(@"(TGAudioSessionManager override port error %@)", error);

            error = nil;
            [session setCategory:[self nativeCategoryForType:_currentType] error:&error];
            if (error != nil)
                TGLog(@"(TGAudioSessionManager setting category error %@)", error);

            error = nil;
            [session setMode:AVAudioSessionModeDefault error:&error];
            if (error != nil)
                TGLog(@"(TGAudioSessionManager setting mode error %@)", error);

            error = nil;
            [session setActive:false withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
            if (error != nil && !([error.domain isEqualToString:@"NSOSStatusErrorDomain"] && error.code == (NSInteger)0x21616374))
                TGLog(@"(TGAudioSessionManager setting inactive error %@)", error);
        }
        else
        {
            if (previousType == TGAudioSessionTypePlayAndRecord || previousType == TGAudioSessionTypePlayAndRecordHeadphones || previousType == TGAudioSessionTypeCall)
            {
                UInt32 route = kAudioSessionOverrideAudioRoute_None;
                AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(route), &route);
            }
            UInt32 category = kAudioSessionCategory_MediaPlayback;
            AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
            OSStatus status = AudioSessionSetActive(false);
            if (status != noErr)
                TGLog(@"(TGAudioSessionManager legacy inactive error %d)", (int)status);
        }
    }
    pthread_mutex_unlock(&_mutex);
}

- (void)endSessionForClientId:(int32_t)clientId
{
    pthread_mutex_lock(&_mutex);
    {
        for (NSUInteger i = 0; i < _currentClientIds.count; i++)
        {
            if ([_currentClientIds[i] intValue] == clientId)
            {
                [_currentInterruptedArray removeObjectAtIndex:i];
                [_currentClientIds removeObjectAtIndex:i];
                
                break;
            }
        }
        
        if (_currentActive && _currentClientIds.count == 0)
        {
            TGAudioSessionType previousType = _currentType;
            _currentActive = false;
            _currentType = TGAudioSessionTypePlayMusic;
            
            TGLog(@"(TGAudioSessionManager setting inactive)");
            
            if (iosMajorVersion() >= 6)
            {
                NSError *error = nil;
                AVAudioSession *session = [AVAudioSession sharedInstance];
                [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
                if (error != nil)
                    TGLog(@"(TGAudioSessionManager override port error %@)", error);

                error = nil;
                [session setCategory:[self nativeCategoryForType:_currentType] error:&error];
                if (error != nil)
                    TGLog(@"(TGAudioSessionManager setting category error %@)", error);

                error = nil;
                [session setMode:AVAudioSessionModeDefault error:&error];
                if (error != nil)
                    TGLog(@"(TGAudioSessionManager setting mode error %@)", error);

                error = nil;
                [session setActive:false withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
                if (error != nil && !([error.domain isEqualToString:@"NSOSStatusErrorDomain"] && error.code == (NSInteger)0x21616374))
                    TGLog(@"(TGAudioSessionManager setting inactive error %@)", error);
            }
            else
            {
                if (previousType == TGAudioSessionTypePlayAndRecord || previousType == TGAudioSessionTypePlayAndRecordHeadphones || previousType == TGAudioSessionTypeCall)
                {
                    UInt32 route = kAudioSessionOverrideAudioRoute_None;
                    AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(route), &route);
                }
                UInt32 category = kAudioSessionCategory_MediaPlayback;
                AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
                OSStatus status = AudioSessionSetActive(false);
                if (status != noErr)
                    TGLog(@"(TGAudioSessionManager legacy inactive error %d)", (int)status);
            }
        }
    }
    pthread_mutex_unlock(&_mutex);
}

+ (SSignal *)routeChange
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        TGAudioSessionRouteChangePipe = [[SPipe alloc] init];
    });

    return TGAudioSessionRouteChangePipe.signalProducer();
}

- (void)emitRouteChange
{
    [[self class] routeChange];
    TGAudioSessionRouteChangePipe.sink(@true);
}

- (void)audioSessionRouteChanged:(NSNotification *)__unused notification
{
    [self emitRouteChange];
}

- (void)legacyAudioSessionInterruption:(UInt32)interruptionState
{
    if (interruptionState == kAudioSessionBeginInterruption)
    {
        [self emitRouteChange];
    }
    else if (interruptionState == kAudioSessionEndInterruption)
    {
        pthread_mutex_lock(&_mutex);
        bool shouldReactivate = _currentActive && _currentType == TGAudioSessionTypeCall;
        pthread_mutex_unlock(&_mutex);

        if (shouldReactivate)
        {
            UInt32 category = kAudioSessionCategory_PlayAndRecord;
            AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
            AudioSessionSetActive(true);
            [self emitRouteChange];
        }
    }
}

- (void)legacyAudioSessionRouteChanged
{
    [self emitRouteChange];
}

- (void)legacyAudioSessionInterruptionNumber:(NSNumber *)interruptionState
{
    [self legacyAudioSessionInterruption:[interruptionState unsignedIntValue]];
}

- (void)audioSessionInterruption:(NSNotification *)notification
{
    if (iosMajorVersion() < 6)
        return;
    
    NSNumber *interruptionType =
    (NSNumber *)notification.userInfo[AVAudioSessionInterruptionTypeKey];
    
    if ([interruptionType intValue] == AVAudioSessionInterruptionTypeBegan)
    {
        [self cancelCurrentSession:true];
    }
}

- (void)applyRoute:(TGAudioRoute *)route
{
    if (route == nil)
        return;

    if (iosMajorVersion() < 6)
    {
        UInt32 value = [route.uid isEqualToString:@"speaker"] ? kAudioSessionOverrideAudioRoute_Speaker : kAudioSessionOverrideAudioRoute_None;
        OSStatus status = AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(value), &value);
        if (status != noErr)
            TGLog(@"(TGAudioSessionManager legacy apply route error %d)", (int)status);
        [self emitRouteChange];
        return;
    }

    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];

    if ([route.uid isEqualToString:@"builtin"])
    {
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];

        if (iosMajorVersion() >= 7)
        {
            NSArray *inputs = [session availableInputs];
            for (AVAudioSessionPortDescription *input in inputs)
            {
                if ([input.portType isEqualToString:AVAudioSessionPortBuiltInMic])
                {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
                    [session setPreferredInput:input error:&error];
#endif
                    break;
                }
            }
        }
    }
    else if ([route.uid isEqualToString:@"speaker"])
    {
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
    }
    else if (iosMajorVersion() >= 7)
    {
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
        NSArray *inputs = [session availableInputs];
        for (AVAudioSessionPortDescription *input in inputs)
        {
            if ([input.UID isEqualToString:route.uid])
            {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
                [session setPreferredInput:input error:&error];
#endif
                break;
            }
        }
    }

    if (error != nil)
        TGLog(@"(TGAudioSessionManager apply route error %@)", error);

    [self emitRouteChange];
}

@end

static void TGLegacyAudioSessionInterruptionListener(void *clientData, UInt32 interruptionState)
{
    TGAudioSessionManager *manager = (__bridge TGAudioSessionManager *)clientData;
    if (manager == nil)
        return;

    if ([NSThread isMainThread])
        [manager legacyAudioSessionInterruption:interruptionState];
    else
        [manager performSelectorOnMainThread:@selector(legacyAudioSessionInterruptionNumber:) withObject:[[NSNumber alloc] initWithUnsignedInt:interruptionState] waitUntilDone:false];
}

static void TGLegacyAudioSessionRouteListener(void *clientData, AudioSessionPropertyID propertyId, UInt32 propertySize, const void *propertyValue)
{
    if (propertyId != kAudioSessionProperty_AudioRouteChange)
        return;

    TGAudioSessionManager *manager = (__bridge TGAudioSessionManager *)clientData;
    if (manager == nil)
        return;

    if ([NSThread isMainThread])
        [manager legacyAudioSessionRouteChanged];
    else
        [manager performSelectorOnMainThread:@selector(legacyAudioSessionRouteChanged) withObject:nil waitUntilDone:false];
}


@interface TGAudioRoute ()
{
    bool _isBluetooth;
}

@end

@implementation TGAudioRoute

static NSString *deviceModel = nil;

+ (void)load
{
    @autoreleasepool
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
                      {
                          deviceModel = [UIDevice currentDevice].model;
                      });
    }
}

+ (instancetype)routeForBuiltIn:(bool)headphones
{
    TGAudioRoute *route = [[TGAudioRoute alloc] init];
    route->_name = headphones
    ? TGLocalized(@"Call.AudioRouteHeadphones")
    : deviceModel;
    route->_uid = @"builtin";
    route->_isBuiltIn = true;
    route->_isHeadphones = headphones;
    
    return route;
}

+ (instancetype)routeForSpeaker
{
    NSString *deviceModel = [UIDevice currentDevice].model;
    
    if (![deviceModel isEqualToString:@"iPhone"])
        return nil;
    
    TGAudioRoute *route = [[TGAudioRoute alloc] init];
    route->_name = TGLocalized(@"Call.AudioRouteSpeaker");
    route->_uid = @"speaker";
    route->_isLoudspeaker = true;
    
    return route;
}

+ (instancetype)routeWithDescription:(AVAudioSessionPortDescription *)description
{
    TGAudioRoute *route = [[TGAudioRoute alloc] init];
    route->_name = description.portName;
    route->_uid = description.UID;
    route->_isBluetooth = [[self bluetoothTypes] containsObject:description.portType];
    
    return route;
}

+ (NSArray *)bluetoothTypes
{
    static dispatch_once_t onceToken;
    static NSArray *bluetoothTypes;
    
    dispatch_once(&onceToken, ^
                  {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
                      bluetoothTypes = @[
                                         AVAudioSessionPortBluetoothA2DP,
                                         AVAudioSessionPortBluetoothLE,
                                         AVAudioSessionPortBluetoothHFP
                                         ];
#else
                      bluetoothTypes = @[
                                         AVAudioSessionPortBluetoothA2DP,
                                         AVAudioSessionPortBluetoothHFP
                                         ];
#endif
                  });
    
    return bluetoothTypes;
}

@end