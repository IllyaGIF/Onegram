#import "PGCameraDeviceAngleSampler.h"

#if __has_include(<CoreMotion/CoreMotion.h>)
#import <CoreMotion/CoreMotion.h>
#define PG_CAMERA_DEVICE_ANGLE_HAS_CORE_MOTION 1
#else
#import <UIKit/UIKit.h>
#define PG_CAMERA_DEVICE_ANGLE_HAS_CORE_MOTION 0
#endif

#import "TGPhotoEditorUtils.h"

#import "LegacyComponentsInternal.h"

#if PG_CAMERA_DEVICE_ANGLE_HAS_CORE_MOTION
@interface PGCameraDeviceAngleSampler ()
{
    CMMotionManager *_motionManager;
    NSOperationQueue *_motionQueue;
}
@end
#else
@interface PGCameraDeviceAngleSampler () <UIAccelerometerDelegate>
{
    UIAccelerometer *_accelerometer;
    id<UIAccelerometerDelegate> _previousAccelerometerDelegate;
    NSTimeInterval _previousAccelerometerUpdateInterval;
    bool _measuring;
}
@end
#endif

@implementation PGCameraDeviceAngleSampler

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _deviceOrientation = UIDeviceOrientationUnknown;

#if PG_CAMERA_DEVICE_ANGLE_HAS_CORE_MOTION
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.accelerometerUpdateInterval = 1.0f;
        _motionManager.deviceMotionUpdateInterval = 1.0f;
        _motionManager.gyroUpdateInterval = 1.0f;
        _motionManager.magnetometerUpdateInterval = 1.0f;
        _motionQueue = [[NSOperationQueue alloc] init];
#else
        _accelerometer = [UIAccelerometer sharedAccelerometer];
#endif
    }
    return self;
}

- (void)dealloc
{
    [self stopMeasuring];
}

- (bool)isMeasuring
{
#if PG_CAMERA_DEVICE_ANGLE_HAS_CORE_MOTION
    return [_motionManager isDeviceMotionActive];
#else
    return _measuring;
#endif
}

- (void)stopMeasuring
{
#if PG_CAMERA_DEVICE_ANGLE_HAS_CORE_MOTION
    [_motionManager stopAccelerometerUpdates];
    [_motionManager stopDeviceMotionUpdates];
#else
    if (_measuring && _accelerometer.delegate == self)
    {
        _accelerometer.updateInterval = _previousAccelerometerUpdateInterval;
        _accelerometer.delegate = _previousAccelerometerDelegate;
    }
    _previousAccelerometerDelegate = nil;
    _measuring = false;
#endif
}

- (void)updateDeviceOrientationWithX:(CGFloat)x y:(CGFloat)y z:(CGFloat)z
{
    CGFloat xx = -x;
    CGFloat yy = y;
    CGFloat angle = atan2(yy, xx);

    UIDeviceOrientation deviceOrientation = self.deviceOrientation;
    CGFloat absoluteZ = fabs(z);

    if (deviceOrientation == UIDeviceOrientationFaceUp || deviceOrientation == UIDeviceOrientationFaceDown)
    {
        if (absoluteZ < 0.845f)
        {
            if (angle < -2.6f)
                deviceOrientation = UIDeviceOrientationLandscapeRight;
            else if (angle > -2.05f && angle < -1.1f)
                deviceOrientation = UIDeviceOrientationPortrait;
            else if (angle > -0.48f && angle < 0.48f)
                deviceOrientation = UIDeviceOrientationLandscapeLeft;
            else if (angle > 1.08f && angle < 2.08f)
                deviceOrientation = UIDeviceOrientationPortraitUpsideDown;
        }
        else if (z < 0.f)
        {
            deviceOrientation = UIDeviceOrientationFaceUp;
        }
        else if (z > 0.f)
        {
            deviceOrientation = UIDeviceOrientationFaceDown;
        }
    }
    else
    {
        if (z > 0.875f)
        {
            deviceOrientation = UIDeviceOrientationFaceDown;
        }
        else if (z < -0.875f)
        {
            deviceOrientation = UIDeviceOrientationFaceUp;
        }
        else
        {
            switch (deviceOrientation)
            {
                case UIDeviceOrientationLandscapeLeft:
                    if (angle < -1.07f) deviceOrientation = UIDeviceOrientationPortrait;
                    if (angle > 1.08f) deviceOrientation = UIDeviceOrientationPortraitUpsideDown;
                    break;

                case UIDeviceOrientationLandscapeRight:
                    if (angle < 0.f && angle > -2.05f) deviceOrientation = UIDeviceOrientationPortrait;
                    if (angle > 0.f && angle < 2.05f) deviceOrientation = UIDeviceOrientationPortraitUpsideDown;
                    break;

                case UIDeviceOrientationPortraitUpsideDown:
                    if (angle > 2.66f) deviceOrientation = UIDeviceOrientationLandscapeRight;
                    if (angle < 0.48f) deviceOrientation = UIDeviceOrientationLandscapeLeft;
                    break;

                case UIDeviceOrientationPortrait:
                default:
                    if (angle > -0.47f) deviceOrientation = UIDeviceOrientationLandscapeLeft;
                    if (angle < -2.64f) deviceOrientation = UIDeviceOrientationLandscapeRight;
                    break;
            }
        }
    }

    if (deviceOrientation != self.deviceOrientation)
    {
        _deviceOrientation = deviceOrientation;
        TGDispatchOnMainThread(^
        {
            if (self.deviceOrientationChanged != nil)
                self.deviceOrientationChanged(deviceOrientation);
        });
    }
}

- (void)updateDeviceAngleWithX:(CGFloat)x y:(CGFloat)y
{
    _currentDeviceAngle = TGRadiansToDegrees((CGFloat)(atan2(x, y) - M_PI)) * -1;
}

- (void)startMeasuring
{
#if PG_CAMERA_DEVICE_ANGLE_HAS_CORE_MOTION
    if (![_motionManager isDeviceMotionAvailable])
        return;

    __weak PGCameraDeviceAngleSampler *weakSelf = self;
    [_motionManager startAccelerometerUpdatesToQueue:_motionQueue withHandler:^(CMAccelerometerData *accelerometerData, __unused NSError *error)
    {
        __strong PGCameraDeviceAngleSampler *strongSelf = weakSelf;
        if (strongSelf == nil || accelerometerData == nil || error != nil)
            return;

        CMAcceleration acceleration = accelerometerData.acceleration;
        [strongSelf updateDeviceOrientationWithX:(CGFloat)acceleration.x y:(CGFloat)acceleration.y z:(CGFloat)acceleration.z];
    }];

    [_motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical toQueue:_motionQueue withHandler:^(CMDeviceMotion *motion, __unused NSError *error)
    {
        __strong PGCameraDeviceAngleSampler *strongSelf = weakSelf;
        if (strongSelf == nil || motion == nil || error != nil)
            return;

        [strongSelf updateDeviceAngleWithX:(CGFloat)motion.gravity.x y:(CGFloat)motion.gravity.y];
    }];
#else
    if (_measuring)
        return;

    _previousAccelerometerDelegate = _accelerometer.delegate;
    _previousAccelerometerUpdateInterval = _accelerometer.updateInterval;
    _accelerometer.updateInterval = 1.0f;
    _accelerometer.delegate = self;
    _measuring = true;
#endif
}

#if !PG_CAMERA_DEVICE_ANGLE_HAS_CORE_MOTION
- (void)accelerometer:(UIAccelerometer *)__unused accelerometer didAccelerate:(UIAcceleration *)acceleration
{
    [self updateDeviceOrientationWithX:acceleration.x y:acceleration.y z:acceleration.z];
    [self updateDeviceAngleWithX:acceleration.x y:acceleration.y];
}
#endif

@end
