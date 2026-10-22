#import "TGRemoteImageView.h"

#import <QuartzCore/QuartzCore.h>

#import "TGCache.h"

#import "SGraphObjectNode.h"

#import "TGImageManager.h"
#import "LegacyComponentsInternal.h"
#import "../../../OnegramPlatform/OGPlatformDispatch.h"
#import "../../../OnegramPlatform/OGPlatformUIKit.h"

static TGCache *sharedCache = nil;

static NSString *TGStrippedPlaceholderCacheUrl(NSString *url)
{
    if (url.length == 0)
        return nil;
    return [@"onegram-stripped:" stringByAppendingString:url];
}

@interface TGRemoteImageView ()
{
    NSUInteger _loadGeneration;
#if defined(ONEGRAM_DIAGNOSTICS)
    CFAbsoluteTime _avatarRequestedAt;
#endif
    int _peerPhotoRetryCount;
    NSString *_peerPhotoRetryUrl;
    UIImage *_peerPhotoRetryPlaceholder;
}

@property (atomic, strong) NSString *path;
@property (atomic, strong) NSString *currentCacheUrl;

@property (nonatomic, strong) UIImageView *placeholderView;

@end

#if defined(ONEGRAM_DIAGNOSTICS)
static NSUInteger TGRemoteAvatarMemoryHits = 0;
static NSUInteger TGRemoteAvatarColdLoads = 0;
static NSUInteger TGRemoteAvatarCancelledLoads = 0;
static double TGRemoteAvatarVisibleDuration = 0.0;
static double TGRemoteAvatarMaximumVisibleDuration = 0.0;
static CFAbsoluteTime TGRemoteAvatarLastReport = 0.0;

static void TGRemoteAvatarReportStatistics(void)
{
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - TGRemoteAvatarLastReport < 3.0)
        return;
    TGRemoteAvatarLastReport = now;
    OGPlatformDiagnosticLog(@"AVATARSTAT memory=%lu cold=%lu cancelled=%lu visibleMs=%.1f visibleMaxMs=%.1f", (unsigned long)TGRemoteAvatarMemoryHits, (unsigned long)TGRemoteAvatarColdLoads, (unsigned long)TGRemoteAvatarCancelledLoads, TGRemoteAvatarVisibleDuration * 1000.0, TGRemoteAvatarMaximumVisibleDuration * 1000.0);
    TGRemoteAvatarMemoryHits = 0;
    TGRemoteAvatarColdLoads = 0;
    TGRemoteAvatarCancelledLoads = 0;
    TGRemoteAvatarVisibleDuration = 0.0;
    TGRemoteAvatarMaximumVisibleDuration = 0.0;
}
#endif

@implementation TGRemoteImageView

static NSUInteger TGRemoteImageLegacyLocationPrefixLength(NSString *url)
{
    NSUInteger length = url.length;
    CFStringInlineBuffer buffer;
    CFStringInitInlineBuffer((__bridge CFStringRef)url, &buffer, CFRangeMake(0, (CFIndex)length));
    CFCharacterSetRef whitespace = CFCharacterSetGetPredefined(kCFCharacterSetWhitespaceAndNewline);
    NSUInteger index = 0;
    for (NSUInteger component = 0; component < 4; component++)
    {
        while (index < length && CFCharacterSetIsCharacterMember(whitespace, CFStringGetCharacterFromInlineBuffer(&buffer, (CFIndex)index)))
            index++;
        if (index < length)
        {
            UniChar sign = CFStringGetCharacterFromInlineBuffer(&buffer, (CFIndex)index);
            if (sign == '+' || sign == '-')
                index++;
        }
        NSUInteger digitsStart = index;
        while (index < length)
        {
            UniChar value = CFStringGetCharacterFromInlineBuffer(&buffer, (CFIndex)index);
            if (value < '0' || value > '9')
                break;
            index++;
        }
        if (index == digitsStart)
            return NSNotFound;
        while (index < length && CFCharacterSetIsCharacterMember(whitespace, CFStringGetCharacterFromInlineBuffer(&buffer, (CFIndex)index)))
            index++;
        if (index >= length || CFStringGetCharacterFromInlineBuffer(&buffer, (CFIndex)index) != '_')
            return NSNotFound;
        if (component < 3)
            index++;
    }
    return index;
}

+ (NSString *)cacheKeyForUrl:(NSString *)url filter:(NSString *)filter
{
    if (url.length == 0)
        return nil;
    NSUInteger legacyPrefixLength = TGRemoteImageLegacyLocationPrefixLength(url);
    NSString *normalizedUrl = legacyPrefixLength == NSNotFound ? url : [url substringToIndex:legacyPrefixLength];
    return filter.length == 0 ? normalizedUrl : [[NSString alloc] initWithFormat:@"{filter:%@}%@", filter, normalizedUrl];
}

+ (NSMutableDictionary *)imageProcessors
{
    static NSMutableDictionary *dictionary = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        dictionary = [[NSMutableDictionary alloc] init];
    });
    return dictionary;
}

+ (NSMutableDictionary *)universalImageProcessors
{
    static NSMutableDictionary *dictionary = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        dictionary = [[NSMutableDictionary alloc] init];
    });
    return dictionary;
}

+ (void)throttleDownProcessing
{
    
}

+ (void)registerImageUniversalProcessor:(TGImageUniversalProcessor)universalProcessor withBaseName:(NSString *)baseName
{
    [[TGRemoteImageView universalImageProcessors] setObject:[universalProcessor copy] forKey:baseName];
}

+ (void)registerImageProcessor:(TGImageProcessor)imageProcessor withName:(NSString *)name
{
    [[TGRemoteImageView imageProcessors] setObject:[imageProcessor copy] forKey:name];
}

+ (TGImageProcessor)imageProcessorForName:(NSString *)name
{
    TGImageProcessor processor = [[TGRemoteImageView imageProcessors] objectForKey:name];
    if (processor != nil)
        return processor;
    
    NSRange range = [name rangeOfString:@":"];
    if (range.location != NSNotFound)
    {
        NSString *baseName = [name substringToIndex:range.location];
        TGImageUniversalProcessor universalProcessor = [[TGRemoteImageView universalImageProcessors] objectForKey:baseName];
        if (universalProcessor != nil)
        {
            return ^UIImage *(UIImage *source)
            {
                return universalProcessor(name, source);
            };
        }
    }
    
    return nil;
}

+ (void)setSharedCache:(TGCache *)cache
{
    sharedCache = cache;
}

+ (TGCache *)sharedCache
{
    return sharedCache;
}

+ (void)cacheStrippedPlaceholderImage:(UIImage *)image forUrl:(NSString *)url
{
    if (image == nil || url.length == 0)
        return;
    NSString *cacheUrl = TGStrippedPlaceholderCacheUrl(url);
    if (cacheUrl != nil)
        [sharedCache cacheImage:image withData:nil url:cacheUrl availability:TGCacheMemory];
}

#pragma mark - Implementation

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        _fadeTransitionDuration = 0.14;
        _useCache = true;
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [self cancelLoading];
}

- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    self.userInteractionEnabled = true;
    
    [super addGestureRecognizer:gestureRecognizer];
}

- (void)setFadeTransition:(bool)fadeTransition
{
    if (!OGPlatformTransientAnimationsEnabled())
        fadeTransition = false;

    if (fadeTransition != _fadeTransition)
    {
        if (fadeTransition && _placeholderView == nil)
        {
            _placeholderView = [[UIImageView alloc] init];
            _placeholderView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
            _placeholderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [_placeholderView setContentMode:self.contentMode];
            [self addSubview:_placeholderView];
        }
        else if (!fadeTransition && _placeholderView != nil)
        {
            [_placeholderView removeFromSuperview];
            _placeholderView = nil;
        }
        
        _fadeTransition = fadeTransition;
    }
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    if (_placeholderView != nil)
        [_placeholderView setContentMode:contentMode];
    
    [super setContentMode:contentMode];
}

- (void)setPlaceholderOverlay:(UIView *)placeholderOverlay
{
    if (_placeholderOverlay != nil)
    {
        [_placeholderOverlay removeFromSuperview];
        _placeholderOverlay = nil;
    }
    
    _placeholderOverlay = placeholderOverlay;
    [_placeholderView addSubview:placeholderOverlay];
}

- (void)prepareForRecycle
{
    [self cancelLoading];
    self.image = nil;
    
    if (_placeholderOverlay != nil)
    {
        [_placeholderOverlay removeFromSuperview];
        _placeholderOverlay = nil;
    }
}

- (void)prepareForReuse
{
    [self cancelLoading];
    self.image = nil;
}

- (UIImage *)currentImage
{
    return self.image;
}

- (UIImage *)currentPlaceholderImage
{
    return _placeholderView.image;
}

- (void)tryFillCache:(NSMutableDictionary *)dict
{
    if (_currentUrl == nil)
        return;
    
    UIImage *currentImage = [self currentImage];
    if (currentImage != nil)
    {
        NSString *key = [TGRemoteImageView cacheKeyForUrl:_currentUrl filter:_currentFilter];
        
        if (key != nil)
            [dict setObject:currentImage forKey:key];
    }
}

- (void)loadImage:(UIImage *)image
{
    [self cancelLoading];
    
    self.image = image;
    
    if (_placeholderView != nil)
    {
        [_placeholderView.layer removeAllAnimations];
        _placeholderView.image = nil;
        _placeholderView.hidden = true;
        _placeholderView.alpha = 0.0f;
    }
}

- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder
{
    [self loadImage:url filter:filter placeholder:placeholder forceFade:false];
}

- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder forceFade:(bool)forceFade
{
    [self cancelLoading];

    if (!TGStringCompare(url, _peerPhotoRetryUrl))
    {
        _peerPhotoRetryCount = 0;
        _peerPhotoRetryUrl = [url hasPrefix:@"peerphoto:"] ? url : nil;
    }
    _peerPhotoRetryPlaceholder = _peerPhotoRetryUrl != nil ? placeholder : nil;
    
    self.currentUrl = url;
    self.currentFilter = filter;
    
    TGCache *cache = _cache != nil ? _cache : [TGRemoteImageView sharedCache];
    
    NSString *trimmedUrl = [TGRemoteImageView cacheKeyForUrl:url filter:nil];
    NSString *cacheUrl = [TGRemoteImageView cacheKeyForUrl:url filter:filter];
    self.currentCacheUrl = cacheUrl;
    UIImage *image = [cache cachedImage:cacheUrl availability:TGCacheMemory];
#if defined(ONEGRAM_DIAGNOSTICS)
    if ([cache isRenderedAvatarKey:cacheUrl])
    {
        if (image != nil)
        {
            TGRemoteAvatarMemoryHits++;
            TGRemoteAvatarReportStatistics();
        }
        else
            _avatarRequestedAt = CFAbsoluteTimeGetCurrent();
    }
#endif

#if defined(ONEGRAM_ARMV6)
    bool onegramPeerPhoto = [url hasPrefix:@"peerphoto:"];
    if (image == nil && onegramPeerPhoto)
        image = [cache cachedThumbnail:cacheUrl];

    if (image == nil && onegramPeerPhoto)
    {
        NSString *strippedCacheUrl = TGStrippedPlaceholderCacheUrl(url);
        UIImage *strippedPlaceholder = strippedCacheUrl == nil ? nil : [cache cachedImage:strippedCacheUrl availability:TGCacheMemory];
        if (strippedPlaceholder != nil && filter == nil)
            placeholder = strippedPlaceholder;
    }

    if (image == nil && filter != nil && !onegramPeerPhoto)
    {
        UIImage *sourceImage = [cache cachedImage:trimmedUrl availability:TGCacheMemory];
        if (sourceImage != nil)
        {
            TGImageProcessor processor = [TGRemoteImageView imageProcessorForName:filter];
            image = processor == nil ? sourceImage : processor(sourceImage);
            if (image != nil)
                [cache cacheImage:image withData:nil url:cacheUrl availability:TGCacheMemory];
        }
    }
#endif
    
    if (image == nil
#if defined(ONEGRAM_ARMV6)
        && !onegramPeerPhoto
#endif
        )
        image = [[TGImageManager instance] loadImageSyncWithUri:url canWait:false decode:true acceptPartialData:false asyncTaskId:NULL progress:nil partialCompletion:nil completion:nil];
    
    if (image == nil && (_contentHints & TGRemoteImageContentHintLoadFromDiskSynchronously)
#if defined(ONEGRAM_ARMV6)
        && !onegramPeerPhoto
#endif
        )
    {
        UIImage *managerImage = [[TGImageManager instance] loadImageSyncWithUri:url canWait:true decode:filter == nil acceptPartialData:false asyncTaskId:NULL progress:nil partialCompletion:nil completion:nil];
        if (managerImage == nil)
            managerImage = [cache cachedImage:url availability:TGCacheDisk];
        
        if (managerImage != nil)
        {
            if (filter != nil)
            {
                TGImageProcessor procesor = [TGRemoteImageView imageProcessorForName:filter];
                if (procesor != nil)
                    image = procesor(managerImage);
            }
            else
                image = managerImage;
        }
    }
    
    if (image != nil)
    {
#if defined(ONEGRAM_DIAGNOSTICS)
        [self recordAvatarReady];
#endif
        if (_contentHints & TGRemoteImageContentHintSaveToGallery)
        {
            [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/checkImageStored/(%lu)", (unsigned long)[url hash]] options:[[NSDictionary alloc] initWithObjectsAndKeys:url, @"url", nil] watcher:self];
        }
        
        if (forceFade && OGPlatformTransientAnimationsEnabled())
        {
            self.image = image;
            
            if (_placeholderView != nil)
            {   
                [_placeholderView.layer removeAllAnimations];
                UIView *placeholderView = _placeholderView;
                _placeholderView.alpha = 1.0f;
                _placeholderView.hidden = false;
                if (placeholder != nil)
                    _placeholderView.image = placeholder;
                [UIView animateWithDuration:_fadeTransitionDuration animations:^{
                    placeholderView.alpha = 0.0f;
                } completion:^(BOOL finished)
                {
                    if (finished)
                        placeholderView.hidden = true;
                }];
            }
        }
        else
        {
            self.image = image;
            
            if (_placeholderView != nil)
            {
                [_placeholderView.layer removeAllAnimations];
                _placeholderView.image = nil;
                _placeholderView.hidden = true;
                _placeholderView.alpha = 0.0f;
            }
        }
        
        if (_progressHandler)
            _progressHandler(self, 1.0f);
    }
    else
    {
        if (_allowThumbnailCache)
        {
            UIImage *thumbnail = [cache cachedThumbnail:cacheUrl];
            if (thumbnail != nil)
                placeholder = thumbnail;
        }
        
        if (_placeholderView != nil)
        {
            self.image = nil;
            [_placeholderView.layer removeAllAnimations];
            _placeholderView.image = placeholder;
            _placeholderView.hidden = false;
            _placeholderView.alpha = 1.0f;
        }
        else
        {
            self.image = placeholder;
        }
        
        if (filter != nil)
            self.path = [NSString stringWithFormat:@"/img/({filter:%@}%@)", filter, url];
        else
            self.path = [NSString stringWithFormat:@"/img/(%@)", url];
        
        NSMutableDictionary *options = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInt:_cancelTimeout], @"cancelTimeout", cache, @"cache", [NSNumber numberWithBool:_useCache], @"useCache", [NSNumber numberWithBool:_allowThumbnailCache], @"allowThumbnailCache", [[NSNumber alloc] initWithInt:_contentHints], @"contentHints", nil];
        if (_userProperties != nil)
            [options setObject:_userProperties forKey:@"userProperties"];
#if defined(ONEGRAM_ARMV6)
        NSMutableDictionary *priorityProperties = _userProperties != nil ? [NSMutableDictionary dictionaryWithDictionary:_userProperties] : [NSMutableDictionary dictionary];
        if (onegramPeerPhoto)
        {
            [options setObject:@true forKey:@"allowThumbnailCache"];
        }
        if ([priorityProperties objectForKey:@"onegramImagePriority"] == nil)
            [priorityProperties setObject:@2 forKey:@"onegramImagePriority"];
        if ([[priorityProperties objectForKey:@"onegramImagePriority"] integerValue] >= 2)
            [priorityProperties setObject:@true forKey:@"changePriority"];
        [options setObject:priorityProperties forKey:@"userProperties"];
#endif
        if (_contentHints & TGRemoteImageContentHintBlurRemote)
            options[@"blurIfRemote"] = @(true);
        int requestFlags = [[[options objectForKey:@"userProperties"] objectForKey:@"changePriority"] boolValue] ? TGActorRequestChangePriority : 0;
        if ([cache isRenderedAvatarKey:cacheUrl])
        {
            NSString *actorPath = self.path;
            NSUInteger generation = _loadGeneration;
            CFAbsoluteTime requestTime = CFAbsoluteTimeGetCurrent();
            __weak TGRemoteImageView *weakSelf = self;
            [cache loadRenderedAvatar:cacheUrl completion:^(UIImage *renderedImage)
            {
                OGPlatformDispatchOnMainThread(^
                {
                    __strong TGRemoteImageView *strongSelf = weakSelf;
                    if (strongSelf == nil || strongSelf->_loadGeneration != generation || !TGStringCompare(strongSelf.path, actorPath))
                        return;
                    if (renderedImage != nil)
                    {
                        [strongSelf applyLoadedImage:renderedImage animated:CFAbsoluteTimeGetCurrent() - requestTime > 0.1];
                        TGImageProgressHandler progressHandler = strongSelf.progressHandler;
                        if (progressHandler)
                            progressHandler(strongSelf, 1.0f);
                        strongSelf.path = nil;
                    }
                    else
                        [ActionStageInstance() requestActor:actorPath options:options flags:requestFlags watcher:strongSelf];
                });
            }];
        }
        else
            [ActionStageInstance() requestActor:self.path options:options flags:requestFlags watcher:self];
    }
}

#if defined(ONEGRAM_DIAGNOSTICS)
- (void)recordAvatarReady
{
    if (_avatarRequestedAt == 0.0)
        return;
    double duration = CFAbsoluteTimeGetCurrent() - _avatarRequestedAt;
    _avatarRequestedAt = 0.0;
    TGRemoteAvatarColdLoads++;
    TGRemoteAvatarVisibleDuration += duration;
    TGRemoteAvatarMaximumVisibleDuration = MAX(TGRemoteAvatarMaximumVisibleDuration, duration);
    TGRemoteAvatarReportStatistics();
}
#endif

- (void)applyLoadedImage:(UIImage *)image animated:(bool)animated
{
#if defined(ONEGRAM_DIAGNOSTICS)
    if (image != nil)
        [self recordAvatarReady];
#endif
    self.image = image;
    
    if (_placeholderView != nil)
    {
        if (!animated || _fadeTransitionDuration < FLT_EPSILON)
        {
            [_placeholderView.layer removeAllAnimations];
            _placeholderView.alpha = 0.0f;
            _placeholderView.hidden = true;
        }
        else
        {
            UIView *placeholderView = _placeholderView;
            [UIView animateWithDuration:_fadeTransitionDuration animations:^
            {
                placeholderView.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                    placeholderView.hidden = true;
            }];
        }
    }
}

- (void)loadPlaceholder:(UIImage *)placeholder
{
    if (!_placeholderView.hidden)
        _placeholderView.image = placeholder;
}

- (void)cancelLoading
{
#if defined(ONEGRAM_DIAGNOSTICS)
    if (_avatarRequestedAt != 0.0)
    {
        _avatarRequestedAt = 0.0;
        TGRemoteAvatarCancelledLoads++;
    }
#endif
    _loadGeneration++;
    if (self.path != nil)
    {
        ASHandle *actionHandle = _actionHandle;
        NSString *path = self.path;
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [ActionStageInstance() removeWatcherByHandle:actionHandle fromPath:path];
        }];
        
        self.image = nil;

        if (_placeholderView != nil)
        {
            [_placeholderView.layer removeAllAnimations];
        }
        
        self.path = nil;
    }
    
    self.currentUrl = nil;
    self.currentFilter = nil;
}

- (void)schedulePeerPhotoRetryForUrl:(NSString *)url filter:(NSString *)filter
{
    if (url.length == 0 || !TGStringCompare(url, _peerPhotoRetryUrl) || _peerPhotoRetryCount >= 3)
        return;

    _peerPhotoRetryCount++;
    NSUInteger generation = _loadGeneration;
    UIImage *placeholder = _peerPhotoRetryPlaceholder;
    __weak TGRemoteImageView *weakSelf = self;
    OGPlatformDispatchOnMainThreadAfter(4.0 * (double)(1 << (_peerPhotoRetryCount - 1)), ^
    {
        TGRemoteImageView *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_loadGeneration != generation || strongSelf.currentUrl != nil || strongSelf.window == nil)
            return;
        [strongSelf loadImage:url filter:filter placeholder:placeholder];
    });
}

+ (UIImage *)imageFromCache:(NSString *)url filter:(NSString *)filter cache:(TGCache *)cache
{
    TGCache *usingCache = cache != nil ? cache : [TGRemoteImageView sharedCache];
    
    UIImage *image = nil;
    NSString *cacheUrl = [TGRemoteImageView cacheKeyForUrl:url filter:filter];
    image = [usingCache cachedImage:cacheUrl availability:TGCacheMemory];
#if defined(ONEGRAM_ARMV6)
    if (image == nil && [url hasPrefix:@"peerphoto:"])
        image = [usingCache cachedThumbnail:cacheUrl];
#endif
    
    return image;
}

+ (NSString *)preloadImage:(NSString *)url filter:(NSString *)filter blurIfRemote:(bool)blurIfRemote cache:(TGCache *)cache allowThumbnailCache:(bool)allowThumbnailCache watcher:(id<ASWatcher>)watcher
{
    TGCache *usingCache = cache != nil ? cache : [TGRemoteImageView sharedCache];
    
    UIImage *image = nil;
    NSString *cacheUrl = [TGRemoteImageView cacheKeyForUrl:url filter:filter];
    image = [usingCache cachedImage:cacheUrl availability:TGCacheMemory];
#if defined(ONEGRAM_ARMV6)
    if (image == nil && [url hasPrefix:@"peerphoto:"])
        image = [usingCache cachedThumbnail:cacheUrl];
#endif
    
    if (image == nil)
    {
        NSString *path = nil;
        if (filter != nil)
            path = [NSString stringWithFormat:@"/img/({filter:%@}%@)", filter, url];
        else
            path = [NSString stringWithFormat:@"/img/(%@)", url];
        
        NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"cancelTimeout", usingCache, @"cache", [NSNumber numberWithBool:allowThumbnailCache], @"forceMemoryCache", @(TG_CACHE_INPLACE), @"allowThumbnailCache", @(blurIfRemote), @"blurIfRemote", nil];
#if defined(ONEGRAM_ARMV6)
        [options setObject:@{ @"onegramImagePriority": @2 } forKey:@"userProperties"];
        if ([url hasPrefix:@"peerphoto:"])
            [options setObject:@true forKey:@"allowThumbnailCache"];
#endif
        [ActionStageInstance() requestActor:path options:options watcher:watcher];
        
        return path;
    }
    
    return nil;
}

- (void)actorMessageReceived:(NSString *)path messageType:(NSString *)messageType message:(id)message
{
    if ([messageType isEqualToString:@"progress"])
    {
        OGPlatformDispatchOnMainThread(^
        {
            if (_progressHandler == nil)
                return;
            
            if (self.path != nil && [path isEqualToString:self.path])
            {
                if (_progressHandler)
                    _progressHandler(self, [message floatValue]);
            }
        });
    }
}

- (void)actorReportedProgress:(NSString *)path progress:(float)progress
{
    OGPlatformDispatchOnMainThread(^
    {
        if (_progressHandler == nil)
            return;
        
        if (self.path != nil && [path isEqualToString:self.path])
        {
            if (_progressHandler)
                _progressHandler(self, progress);
        }
    });
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    OGPlatformDispatchOnMainThread(^
    {
        if (self.path != nil && [path isEqualToString:self.path])
        {
            if (resultCode == ASStatusSuccess && result != nil)
            {
                if (_contentHints & TGRemoteImageContentHintSaveToGallery)
                {
                    [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/checkImageStored/(%lu)", (unsigned long)[self.currentUrl hash]] options:[[NSDictionary alloc] initWithObjectsAndKeys:self.currentUrl, @"url", nil] watcher:self];
                }
                
                UIImage *image = ((SGraphObjectNode *)result).object;
                if (image != nil)
                {
#if TG_CACHE_INPLACE
                    if (_useCache)
                    {
                        TGCache *cache = _cache != nil ? _cache : [TGRemoteImageView sharedCache];
                        [cache cacheImage:image withData:nil url:self.currentCacheUrl availability:TGCacheMemory];
                    }
#endif
                    
                    [self applyLoadedImage:image animated:true];
                }
            }
            else
            {
                NSString *failedUrl = self.currentUrl;
                NSString *failedFilter = self.currentFilter;
                self.currentUrl = nil;
                self.currentFilter = nil;
                [self schedulePeerPhotoRetryForUrl:failedUrl filter:failedFilter];
            }
            
            if (_progressHandler)
                _progressHandler(self, 1.0f);
            
            self.path = nil;
        }
    });
}

@end
