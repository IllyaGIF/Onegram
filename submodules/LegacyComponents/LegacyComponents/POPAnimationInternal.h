/**
 Copyright (c) 2014-present, Facebook, Inc.
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import <QuartzCore/CAMediaTimingFunction.h>

#import "POPAnimation.h"
#import "POPAnimationRuntime.h"
#import "POPAnimationTracerInternal.h"
#import "POPSpringSolver.h"
#import "POPAction.h"

using namespace POP;

enum POPAnimationType
{
  kPOPAnimationSpring,
  kPOPAnimationDecay,
  kPOPAnimationBasic,
  kPOPAnimationCustom,
};

typedef struct
{
  CGFloat progress;
  bool reached;
} POPProgressMarker;

typedef void (^POPAnimationDidStartBlock)(POPAnimation *anim);
typedef void (^POPAnimationDidReachToValueBlock)(POPAnimation *anim);
typedef void (^POPAnimationCompletionBlock)(POPAnimation *anim, BOOL finished);
typedef void (^POPAnimationDidApplyBlock)(POPAnimation *anim);

@interface POPAnimation()
- (instancetype)_init;

@property (assign, nonatomic) SpringSolver4d *solver;
@property (readonly, nonatomic) POPAnimationType type;

@property (copy, nonatomic, readonly) id currentValue;

@property (copy, nonatomic) NSArray *progressMarkers;

- (BOOL)_advance:(id)object currentTime:(CFTimeInterval)currentTime elapsedTime:(CFTimeInterval)elapsedTime;

- (void)_appendDescription:(NSMutableString *)s debug:(BOOL)debug;

@end

NS_INLINE NSString *describe(VectorConstRef vec)
{
  return !vec ? @"null" : vec->toString();
}

NS_INLINE Vector4r vector4(VectorConstRef vec)
{
  return !vec ? Vector4r::Zero() : vec->vector4r();
}

NS_INLINE Vector4d vector4d(VectorConstRef vec)
{
  if (!vec) {
    return Vector4d::Zero();
  } else {
    return vec->vector4r().cast<double>();
  }
}

NS_INLINE bool vec_equal(VectorConstRef v1, VectorConstRef v2)
{
  if (v1 == v2) {
    return true;
  }
  if (!v1 || !v2) {
    return false;
  }
  return *v1 == *v2;
}

NS_INLINE CGFloat * vec_data(VectorRef vec)
{
  return !vec ? NULL : vec->data();
}

template<class T>
struct ComputeProgressFunctor {
  CGFloat operator()(const T &value, const T &start, const T &end) const {
    return 0;
  }
};

template<>
struct ComputeProgressFunctor<Vector4r> {
  CGFloat operator()(const Vector4r &value, const Vector4r &start, const Vector4r &end) const {
    CGFloat s = (value - start).squaredNorm();
    CGFloat e = (value - end).squaredNorm();
    CGFloat d = (end - start).squaredNorm();
    
    if (0 == d) {
      return 1;
    } else if (s > e) {
      return sqrtr(s/d);
    } else {
      return 1 - sqrtr(e/d);
    }
  }
};

struct _POPAnimationState;
struct _POPDecayAnimationState;
struct _POPPropertyAnimationState;

extern _POPAnimationState *POPAnimationGetState(POPAnimation *a);


#define FB_FLAG_GET(stype, flag, getter) \
- (BOOL)getter { \
  return ((stype *)_state)->flag; \
}

#define FB_FLAG_SET(stype, flag, mutator) \
- (void)mutator (BOOL)value { \
  if (value == ((stype *)_state)->flag) \
    return; \
  ((stype *)_state)->flag = value; \
}

#define DEFINE_RW_FLAG(stype, flag, getter, mutator) \
  FB_FLAG_GET (stype, flag, getter) \
  FB_FLAG_SET (stype, flag, mutator)

#define FB_PROPERTY_GET(stype, property, ctype) \
- (ctype)property { \
  return ((stype *)_state)->property; \
}

#define FB_PROPERTY_SET(stype, property, mutator, ctype, ...) \
- (void)mutator (ctype)value { \
  if (value == ((stype *)_state)->property) \
    return; \
  ((stype *)_state)->property = value; \
  __VA_ARGS__ \
}

#define FB_PROPERTY_SET_OBJ_COPY(stype, property, mutator, ctype, ...) \
- (void)mutator (ctype)value { \
  if (value == ((stype *)_state)->property) \
    return; \
  ((stype *)_state)->property = [value copy]; \
  __VA_ARGS__ \
}

#define DEFINE_RW_PROPERTY(stype, flag, mutator, ctype, ...) \
  FB_PROPERTY_GET (stype, flag, ctype) \
  FB_PROPERTY_SET (stype, flag, mutator, ctype, __VA_ARGS__)

#define DEFINE_RW_PROPERTY_OBJ(stype, flag, mutator, ctype, ...) \
  FB_PROPERTY_GET (stype, flag, ctype) \
  FB_PROPERTY_SET (stype, flag, mutator, ctype, __VA_ARGS__)

#define DEFINE_RW_PROPERTY_OBJ_COPY(stype, flag, mutator, ctype, ...) \
  FB_PROPERTY_GET (stype, flag, ctype) \
  FB_PROPERTY_SET_OBJ_COPY (stype, flag, mutator, ctype, __VA_ARGS__)

@interface NSObject (POPAnimationDelegateInternal)
- (void)pop_animation:(POPAnimation *)anim didReachProgress:(CGFloat)progress;
@end

struct _POPAnimationState
{
  id __unsafe_unretained self;
  POPAnimationType type;
  NSString *name;
  NSUInteger ID;
  CFTimeInterval beginTime;
  CFTimeInterval startTime;
  CFTimeInterval lastTime;
  id __weak delegate;
  POPAnimationDidStartBlock animationDidStartBlock;
  POPAnimationDidReachToValueBlock animationDidReachToValueBlock;
  POPAnimationCompletionBlock completionBlock;
  POPAnimationDidApplyBlock animationDidApplyBlock;
  NSMutableDictionary *dict;
  POPAnimationTracer *tracer;
  CGFloat progress;
  NSInteger repeatCount;
  
  bool active:1;
  bool paused:1;
  bool removedOnCompletion:1;
  
  bool delegateDidStart:1;
  bool delegateDidStop:1;
  bool delegateDidProgress:1;
  bool delegateDidApply:1;
  bool delegateDidReachToValue:1;
  
  bool additive:1;
  bool didReachToValue:1;
  bool tracing:1; // corresponds to tracer started
  bool userSpecifiedDynamics:1;
  bool autoreverses:1;
  bool repeatForever:1;
  bool customFinished:1;

  _POPAnimationState(id __unsafe_unretained anim) :
  self(anim),
  type((POPAnimationType)0),
  name(nil),
  ID(0),
  beginTime(0),
  startTime(0),
  lastTime(0),
  delegate(nil),
  animationDidStartBlock(nil),
  animationDidReachToValueBlock(nil),
  completionBlock(nil),
  animationDidApplyBlock(nil),
  dict(nil),
  tracer(nil),
  progress(0),
  repeatCount(0),
  active(false),
  paused(true),
  removedOnCompletion(true),
  delegateDidStart(false),
  delegateDidStop(false),
  delegateDidProgress(false),
  delegateDidApply(false),
  delegateDidReachToValue(false),
  additive(false),
  didReachToValue(false),
  tracing(false),
  userSpecifiedDynamics(false),
  autoreverses(false),
  repeatForever(false),
  customFinished(false) {}
  
  virtual ~_POPAnimationState()
  {
    name = nil;
    dict = nil;
    tracer = nil;
    animationDidStartBlock = NULL;
    animationDidReachToValueBlock = NULL;
    completionBlock = NULL;
    animationDidApplyBlock = NULL;
  }
  
  bool isCustom() {
    return kPOPAnimationCustom == type;
  }
  
  bool isStarted() {
    return 0 != startTime;
  }

  id getDelegate() {
    return delegate;
  }
  
  void setDelegate(id d) {
    if (d != delegate) {
      delegate = d;
      delegateDidStart = [d respondsToSelector:@selector(pop_animationDidStart:)];
      delegateDidStop = [d respondsToSelector:@selector(pop_animationDidStop:finished:)];
      delegateDidProgress = [d respondsToSelector:@selector(pop_animation:didReachProgress:)];
      delegateDidApply = [d respondsToSelector:@selector(pop_animationDidApply:)];
      delegateDidReachToValue = [d respondsToSelector:@selector(pop_animationDidReachToValue:)];
    }
  }

  bool getPaused() {
    return paused;
  }
  
  void setPaused(bool f) {
    if (f != paused) {
      paused = f;
      if (!paused) {
        reset(false);
      }
    }
  }
  
  CGFloat getProgress() {
    return progress;
  }
  
  bool startIfNeeded(id obj, CFTimeInterval time, CFTimeInterval offset)
  {
    bool started = false;
    
    if (0 == startTime && time >= beginTime + offset) {
      
      active = true;
      setPaused(false);
      
      startTime = lastTime = time;
      started = true;
    }

    bool running = active && !paused;
    if (running) {
      willRun(started, obj);
    }

    if (started) {
      handleDidStart();
    }

    return started;
  }

  void stop(bool removing, bool done) {
    if (active)
    {
      if (done) {
        delegateProgress();
      }
      
      if (removing) {
        active = false;
      }
      
      handleDidStop(done);
    } else {
      
      if (!isStarted()) {
        handleDidStart();
        handleDidStop(false);
      }
    }
    
    setPaused(true);
  }
  
  virtual void handleDidStart()
  {
    if (delegateDidStart) {
      ActionEnabler enabler;
      [delegate pop_animationDidStart:self];
    }

    POPAnimationDidStartBlock block = animationDidStartBlock;
    if (block != NULL) {
      ActionEnabler enabler;
      block(self);
    }
    
    if (tracing) {
      [tracer didStart];
    }
  }
  
  void handleDidStop(BOOL done)
  {
    if (delegateDidStop) {
      ActionEnabler enabler;
      [delegate pop_animationDidStop:self finished:done];
    }
    
    POPAnimationCompletionBlock block = completionBlock;
    if (block != NULL) {
      ActionEnabler enabler;
      block(self, done);
    }
    
    if (tracing) {
      [tracer didStop:done];
    }
  }

  virtual bool isDone() {
    if (isCustom()) {
      return customFinished;
    }
    
    return false;
  }
  
  bool advanceTime(CFTimeInterval time, id obj) {
    bool advanced = false;
    bool computedProgress = false;
    CFTimeInterval dt = time - lastTime;

    switch (type) {
      case kPOPAnimationSpring:
        advanced = advance(time, dt, obj);
        break;
      case kPOPAnimationDecay:
        advanced = advance(time, dt, obj);
        break;
      case kPOPAnimationBasic: {
        advanced = advance(time, dt, obj);
        computedProgress = true;
        break;
      }
      case kPOPAnimationCustom: {
        customFinished = [self _advance:obj currentTime:time elapsedTime:dt] ? false : true;
        advanced = true;
        break;
      }
      default:
        break;
    }
    
    if (advanced) {
      
      if (!computedProgress) {
        computeProgress();
      }
      
      delegateProgress();
      
      lastTime = time;
    }
    
    return advanced;
  }
  
  virtual void willRun(bool started, id obj) {}
  virtual bool advance(CFTimeInterval time, CFTimeInterval dt, id obj) { return false; }
  virtual void computeProgress() {}
  virtual void delegateProgress() {}

  virtual void delegateApply() {
    if (delegateDidApply) {
      ActionEnabler enabler;
      [delegate pop_animationDidApply:self];
    }

    POPAnimationDidApplyBlock block = animationDidApplyBlock;
    if (block != NULL) {
      ActionEnabler enabler;
      block(self);
    }
  }
  
  virtual void reset(bool all) {
    startTime = 0;
    lastTime = 0;
  }
};

typedef struct _POPAnimationState POPAnimationState;


@interface POPAnimation ()
{
@protected
  struct _POPAnimationState *_state;
}

@end

@interface NSProxy (POP)
- (void)pop_addAnimation:(POPAnimation *)anim forKey:(NSString *)key;
- (void)pop_removeAllAnimations;
- (void)pop_removeAnimationForKey:(NSString *)key;
- (NSArray *)pop_animationKeys;
- (POPAnimation *)pop_animationForKey:(NSString *)key;
@end
