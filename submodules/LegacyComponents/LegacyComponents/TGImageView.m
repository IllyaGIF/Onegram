#import "TGImageView.h"

#import "LegacyComponentsInternal.h"

#import "TGImageManager.h"

#import "UIImage+TG.h"

#import <QuartzCore/QuartzCore.h>

NSString *TGImageViewOptionKeepCurrentImageAsPlaceholder = @"TGImageViewOptionKeepCurrentImageAsPlaceholder";
NSString *TGImageViewOptionEmbeddedImage = @"TGImageViewOptionEmbeddedImage";
NSString *TGImageViewOptionSynchronous = @"TGImageViewOptionSynchronous";

@class TGImageView;

@interface TGImageViewSignalReference : NSObject
{
    NSCondition *_condition;
    __weak TGImageView *_value;
    NSUInteger _activeCallbacks;
}

- (void)setValue:(TGImageView *)value;
- (void)withValue:(void (^)(void *value))block;
- (void)invalidate;

@end

@implementation TGImageViewSignalReference

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        _condition = [[NSCondition alloc] init];
    return self;
}

- (void)setValue:(TGImageView *)value
{
    [_condition lock];
    _value = value;
    [_condition unlock];
}

- (void)withValue:(void (^)(void *value))block
{
    if (block == nil)
        return;

    void *value = NULL;
    [_condition lock];
    __attribute__((objc_precise_lifetime)) __strong TGImageView *currentValue = _value;
    if (currentValue != nil)
    {
        _activeCallbacks++;
        value = (__bridge void *)currentValue;
    }
    [_condition unlock];

    if (value != NULL)
    {
        @try
        {
            block(value);
        }
        @finally
        {
            [_condition lock];
            if (_activeCallbacks != 0)
                _activeCallbacks--;
            if (_activeCallbacks == 0)
                [_condition broadcast];
            [_condition unlock];
        }
    }
}

- (void)invalidate
{
    [_condition lock];
    _value = nil;
    while (_activeCallbacks != 0)
        [_condition wait];
    [_condition unlock];
}

@end

@interface TGImageView ()
{
    id _loadToken;
    volatile int _version;
    SMetaDisposable *_disposable;
    TGImageViewSignalReference *_signalReference;
    
    UIImageView *_transitionOverlayView;
    int _transitionVersion;
}

@end

@implementation TGImageView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _disposable = [[SMetaDisposable alloc] init];
        _signalReference = [[TGImageViewSignalReference alloc] init];
        [_signalReference setValue:self];
        _legacyAutomaticProgress = true;
    }
    return self;
}

- (void)dealloc
{
    _version++;
    [_signalReference invalidate];
    [_disposable dispose];
    if (_loadToken != nil)
    {
        [[TGImageManager instance] cancelTaskWithId:_loadToken];
        _loadToken = nil;
    }
}

- (void)setExpectExtendedEdges:(bool)expectExtendedEdges
{
    if (_expectExtendedEdges != expectExtendedEdges)
    {
        _expectExtendedEdges = expectExtendedEdges;
        
        if (_expectExtendedEdges && _extendedInsetsImageView == nil)
        {
            self.image = nil;
            _extendedInsetsImageView = [[UIImageView alloc] init];
            [self addSubview:_extendedInsetsImageView];
        }
        else if (!_expectExtendedEdges && _extendedInsetsImageView != nil)
        {
            _extendedInsetsImageView.image = nil;
            [_extendedInsetsImageView removeFromSuperview];
            _extendedInsetsImageView = nil;
        }
    }
}

- (void)loadUri:(NSString *)uri withOptions:(NSDictionary *)__unused options
{
    [_disposable setDisposable:nil];
    if (_loadToken != nil)
    {
        [[TGImageManager instance] cancelTaskWithId:_loadToken];
        _loadToken = nil;
    }
    _version++;
    TGImageViewSignalReference *signalReference = _signalReference;
    
    UIImage *image = nil;
    
    bool beganAsyncTask = false;
    
    if (options[TGImageViewOptionEmbeddedImage] != nil)
        image = options[TGImageViewOptionEmbeddedImage];
    else
    {
        __autoreleasing id asyncTaskId = nil;
        int version = _version;
        CFAbsoluteTime loadStartTime = CACurrentMediaTime();
        bool legacyAutomaticProgress = _legacyAutomaticProgress;
        image = [[TGImageManager instance] loadImageSyncWithUri:uri canWait:[options[TGImageViewOptionSynchronous] boolValue] decode:true acceptPartialData:true asyncTaskId:&asyncTaskId progress:^(float value)
        {
            if (legacyAutomaticProgress)
            {
                TGDispatchOnMainThread(^
                {
                    [signalReference withValue:^(void *referenceValue)
                    {
                        TGImageView *imageView = (__bridge TGImageView *)referenceValue;
                        if (imageView->_version == version)
                            [imageView _updateProgress:value];
                    }];
                });
            }
        } partialCompletion:^(UIImage *partialImage)
        {
            TGDispatchOnMainThread(^
            {
                [signalReference withValue:^(void *referenceValue)
                {
                    TGImageView *imageView = (__bridge TGImageView *)referenceValue;
                    if (imageView->_version == version)
                        [imageView _commitImage:partialImage partial:true loadTime:(NSTimeInterval)(CACurrentMediaTime() - loadStartTime)];
                }];
            });
        } completion:^(UIImage *image)
        {
            TGDispatchOnMainThread(^
            {
                [signalReference withValue:^(void *referenceValue)
                {
                    TGImageView *imageView = (__bridge TGImageView *)referenceValue;
                    if (imageView->_version == version)
                    {
                        imageView->_loadToken = nil;
                        if (legacyAutomaticProgress)
                            [imageView _updateProgress:1.0f];
                        [imageView _commitImage:image partial:false loadTime:(NSTimeInterval)(CACurrentMediaTime() - loadStartTime)];
                    }
                }];
            });
        }];
        
        if (asyncTaskId != nil)
        {
            beganAsyncTask = true;
            _loadToken = asyncTaskId;
        }
    }
    
    if (image != nil)
        [self _commitImage:image partial:beganAsyncTask loadTime:0.0];
    else
    {
        if (![options[TGImageViewOptionKeepCurrentImageAsPlaceholder] boolValue])
        {
            UIImage *placeholderImage = [[TGImageManager instance] loadAttributeSyncForUri:uri attribute:@"placeholder"];
            if (placeholderImage != nil)
                [self _commitImage:placeholderImage partial:beganAsyncTask loadTime:0.0];
            else
                [self _commitImage:nil partial:true loadTime:0.0];
        }
        
        CFAbsoluteTime loadStartTime = CACurrentMediaTime();
        
        int version = _version;
        bool legacyAutomaticProgress = _legacyAutomaticProgress;
        _loadToken = [[TGImageManager instance] beginLoadingImageAsyncWithUri:uri decode:true progress:^(float value)
        {
            if (legacyAutomaticProgress)
            {
                TGDispatchOnMainThread(^
                {
                    [signalReference withValue:^(void *referenceValue)
                    {
                        TGImageView *imageView = (__bridge TGImageView *)referenceValue;
                        if (imageView->_version == version)
                            [imageView _updateProgress:value];
                    }];
                });
            }
        } partialCompletion:^(UIImage *partialImage)
        {
            TGDispatchOnMainThread(^
            {
                [signalReference withValue:^(void *referenceValue)
                {
                    TGImageView *imageView = (__bridge TGImageView *)referenceValue;
                    if (imageView->_version == version)
                        [imageView _commitImage:partialImage partial:true loadTime:(NSTimeInterval)(CACurrentMediaTime() - loadStartTime)];
                }];
            });
        } completion:^(UIImage *image)
        {
            TGDispatchOnMainThread(^
            {
                [signalReference withValue:^(void *referenceValue)
                {
                    TGImageView *imageView = (__bridge TGImageView *)referenceValue;
                    if (imageView->_version == version)
                    {
                        imageView->_loadToken = nil;
                        if (legacyAutomaticProgress)
                            [imageView _updateProgress:1.0f];
                        [imageView _commitImage:image partial:false loadTime:(NSTimeInterval)(CACurrentMediaTime() - loadStartTime)];
                    }
                }];
            });
        }];
    }
}

- (void)_updateProgress:(float)value
{
    if (![NSThread isMainThread])
    {
        TGImageViewSignalReference *signalReference = _signalReference;
        int version = _version;
        TGDispatchOnMainThread(^
        {
            [signalReference withValue:^(void *referenceValue)
            {
                TGImageView *imageView = (__bridge TGImageView *)referenceValue;
                if (imageView->_version == version)
                    [imageView _updateProgress:value];
            }];
        });
        return;
    }
    [self performProgressUpdate:value];
}

- (void)_commitImage:(UIImage *)image partial:(bool)partial loadTime:(NSTimeInterval)loadTime
{
    if (![NSThread isMainThread])
    {
        TGImageViewSignalReference *signalReference = _signalReference;
        int version = _version;
        TGDispatchOnMainThread(^
        {
            [signalReference withValue:^(void *referenceValue)
            {
                TGImageView *imageView = (__bridge TGImageView *)referenceValue;
                if (imageView->_version == version)
                    [imageView _commitImage:image partial:partial loadTime:loadTime];
            }];
        });
        return;
    }

    if (image == [self currentImage])
        return;
    
    NSTimeInterval transitionDuration = 0.0;
    
    if (loadTime > DBL_EPSILON)
        transitionDuration = 0.16;
    
    [self performTransitionToImage:image partial:partial duration:transitionDuration];
}

- (void)reset
{
    _version++;
    [_disposable setDisposable:nil];
    
    if (_loadToken != nil)
    {
        [[TGImageManager instance] cancelTaskWithId:_loadToken];
        _loadToken = nil;
    }
    
    [self _commitImage:nil partial:false loadTime:0.0];
}

- (UIImage *)currentImage
{
    if (_expectExtendedEdges)
        return _extendedInsetsImageView.image;
    return [super image];
}

- (void)performProgressUpdate:(CGFloat)__unused progress
{
}

- (void)performTransitionToImage:(UIImage *)image partial:(bool)__unused partial duration:(NSTimeInterval)duration
{
    _transitionVersion++;
    int transitionVersion = _transitionVersion;

    [self.layer removeAllAnimations];
    [_extendedInsetsImageView.layer removeAllAnimations];
    if (_transitionOverlayView != nil)
    {
        [_transitionOverlayView.layer removeAllAnimations];
        _transitionOverlayView.image = nil;
        [_transitionOverlayView removeFromSuperview];
    }

    if (((_expectExtendedEdges && _extendedInsetsImageView.image != nil) || (!_expectExtendedEdges && self.image != nil)) && duration > DBL_EPSILON)
    {
        self.alpha = 1.0f;
        _extendedInsetsImageView.alpha = 1.0f;
        
        if (_transitionOverlayView == nil)
            _transitionOverlayView = [[UIImageView alloc] init];
        
        _transitionOverlayView.frame = _extendedInsetsImageView == nil ? self.bounds : _extendedInsetsImageView.frame;
        _transitionOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self insertSubview:_transitionOverlayView atIndex:0];
        
        _transitionOverlayView.image = _extendedInsetsImageView == nil ? self.image : _extendedInsetsImageView.image;
        _transitionOverlayView.backgroundColor = self.backgroundColor;
        _transitionOverlayView.alpha = 1.0;
        
        [UIView animateWithDuration:duration animations:^
        {
            _transitionOverlayView.alpha = 0.0;
        } completion:^(__unused BOOL finished)
        {
            if (_transitionVersion == transitionVersion)
            {
                _transitionOverlayView.image = nil;
                [_transitionOverlayView removeFromSuperview];
            }
        }];
        
        if (_extendedInsetsImageView != nil)
        {
            _extendedInsetsImageView.alpha = 0.0f;
            [UIView animateWithDuration:duration / 2.0f animations:^
            {
                _extendedInsetsImageView.alpha = 1.0f;
            }];
        }
    }
    else if (image != nil && duration > DBL_EPSILON)
    {
        if (_expectExtendedEdges)
            _extendedInsetsImageView.alpha = 0.0f;
        else
            self.alpha = 0.0f;
        [UIView animateWithDuration:duration animations:^
        {
            if (_expectExtendedEdges)
                _extendedInsetsImageView.alpha = 1.0f;
            else
                self.alpha = 1.0f;
        } completion:^(__unused BOOL finished)
        {
        }];
    }
    else
    {
        self.alpha = 1.0f;
    }

    if (!_expectExtendedEdges)
    {
        self.image = image;
        if (_extendedInsetsImageView != nil)
        {
            [_extendedInsetsImageView removeFromSuperview];
            _extendedInsetsImageView = nil;
        }
    }
    else
    {
        UIEdgeInsets insets = image == nil ? UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f) : [image extendedEdgeInsets];
        _extendedInsetsImageView.image = image;
        _extendedInsetsImageView.frame = CGRectMake(-insets.left, -insets.top, self.bounds.size.width + insets.left + insets.right, self.bounds.size.height + insets.top + insets.bottom);
    }
}
- (void)setSignal:(SSignal *)signal
{
    if (_loadToken != nil)
    {
        [[TGImageManager instance] cancelTaskWithId:_loadToken];
        _loadToken = nil;
    }
    _version++;
    int version = _version;
    TGImageViewSignalReference *signalReference = _signalReference;
    
    [_disposable setDisposable:[signal startWithNext:^(id next)
    {
        bool synchronous = [NSThread isMainThread];
        TGDispatchOnMainThread(^
        {
            [signalReference withValue:^(void *referenceValue)
            {
                TGImageView *imageView = (__bridge TGImageView *)referenceValue;
                if (imageView->_version == version)
                {
                    if ([next isKindOfClass:[UIImage class]])
                        [imageView _commitImage:next partial:[next degraded] && ![next edited] loadTime:synchronous ? 0.0 : 1.0];
                    else if ([next respondsToSelector:@selector(floatValue)])
                        [imageView _updateProgress:[next floatValue]];
                }
            }];
        });
    } error:^(id error)
    {
        TGLegacyLog(@"TGImageView signal error: %@", error);
    } completed:^
    {
    }]];
}

@end
