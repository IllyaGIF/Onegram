#import "TGEmbedVimeoPlayerView.h"
#import "TGEmbedPlayerState.h"

#import "LegacyComponentsInternal.h"

NSString *const TGVimeoPlayerCallbackOnReady = @"onReady";
NSString *const TGVimeoPlayerCallbackOnState = @"onState";

static NSString *OGEmbedPercentDecoded(NSString *text)
{
    return [text stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

static NSDictionary *OGEmbedCallbackParameters(NSURL *url)
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    for (NSString *item in [[url query] componentsSeparatedByString:@"&"])
    {
        NSRange separator = [item rangeOfString:@"="];
        bool hasValue = separator.location != NSNotFound;
        NSString *name = OGEmbedPercentDecoded(hasValue ? [item substringToIndex:separator.location] : item);
        NSString *value = OGEmbedPercentDecoded(hasValue ? [item substringFromIndex:NSMaxRange(separator)] : @"");
        if (item.length != 0 && name != nil && value != nil)
            [parameters setObject:value forKey:name];
    }
    return parameters;
}

@interface TGEmbedVimeoPlayerView ()
{
    NSString *_videoId;
    
    bool _started;
    bool _initiallyPlayed;
    
    NSInteger _ignorePositionUpdates;
}
@end

@implementation TGEmbedVimeoPlayerView

- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)thumbnailSignal alternateCachePathSignal:(SSignal *)alternateCachePathSignal
{
    self = [super initWithWebPageAttachment:webPage thumbnailSignal:thumbnailSignal alternateCachePathSignal:alternateCachePathSignal];
    if (self != nil)
    {
        _videoId = [TGEmbedVimeoPlayerView _vimeoVideoIdFromText:webPage.embedUrl];
    }
    return self;
}

- (void)playVideo
{
    [super playVideo];
    
    if (_initiallyPlayed)
    {
        [self _evaluateJS:@"player.api('play');" completion:nil];
    }
    else
    {
        [self _evaluateJS:@"injectCmd('initialPlay')" completion:nil];
        _initiallyPlayed = true;
    }
    
    _ignorePositionUpdates = 2;
}

- (void)pauseVideo:(bool)manually
{
    [super pauseVideo:manually];
    [self _evaluateJS:@"player.api('pause');" completion:nil];
}

- (void)seekToPosition:(NSTimeInterval)position
{
    NSString *command = [NSString stringWithFormat:@"player.api('seekTo', %@);", @(position)];
    [self _evaluateJS:command completion:nil];
    
    TGEmbedPlayerState *newState = [TGEmbedPlayerState stateWithPlaying:self.state.isPlaying duration:self.state.duration position:position downloadProgress:self.state.downloadProgress buffering:self.state.buffering];
    [self updateState:newState];
    
    _ignorePositionUpdates = 2;
}

- (TGEmbedPlayerControlsType)_controlsType
{
    return TGEmbedPlayerControlsTypeFull;
}

- (void)_onPageReady
{
    
}

- (void)_didBeginPlayback
{
    [super _didBeginPlayback];
    
    TGDispatchAfter(0.5, dispatch_get_main_queue(), ^
    {
        [self setDimmed:false animated:true shouldDelay:false];
    });
}

- (void)_notifyOfCallbackURL:(NSURL *)url
{
    NSString *action = url.host;
    
    NSString *query = url.query;
    NSString *data;
    if (query != nil)
        data = [query componentsSeparatedByString:@"="][1];
    
    if ([action isEqual:TGVimeoPlayerCallbackOnReady])
    {
        
    }
    else if ([action isEqualToString:TGVimeoPlayerCallbackOnState])
    {
        NSDictionary *callbackParameters = OGEmbedCallbackParameters(url);
        
        bool playing = self.state.playing;
        bool finished = false;
        NSTimeInterval position = self.state.position;
        NSTimeInterval duration = self.state.duration;
        CGFloat downloadProgress = self.state.downloadProgress;
        bool buffering = self.state.buffering;

        NSString *rawValue = nil;
        if ((rawValue = [callbackParameters objectForKey:@"playback"]) != nil)
        {
            NSInteger playbackCode = [rawValue integerValue];
            playing = (playbackCode == 1);
            finished = (playbackCode == 2);
        }
        if ((rawValue = [callbackParameters objectForKey:@"position"]) != nil)
        {
            if (_ignorePositionUpdates > 0)
                _ignorePositionUpdates--;
            else
                position = [rawValue doubleValue];
        }
        if ((rawValue = [callbackParameters objectForKey:@"duration"]) != nil)
            duration = [rawValue doubleValue];
        if ((rawValue = [callbackParameters objectForKey:@"download"]) != nil)
            downloadProgress = [rawValue floatValue];
        
        if (!_started && playing)
        {
            _started = true;
            [self _didBeginPlayback];
        }
        
        if (finished)
            position = 0.0;
        
        TGEmbedPlayerState *newState = [TGEmbedPlayerState stateWithPlaying:playing duration:duration position:position downloadProgress:downloadProgress buffering:buffering];
        [self updateState:newState];
    }
}

- (NSString *)_embedHTML
{
    NSError *error = nil;
    NSString *path = TGComponentsPathForResource(@"VimeoPlayer", @"html");
    
    NSString *embedHTMLTemplate = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
    {
        TGLegacyLog(@"[VimeoEmbedPlayer]: Received error rendering template: %@", error);
        return nil;
    }
    
    NSString *autoplay = self.disallowAutoplay ? @"false" : @"true";
    NSString *embedHTML = [NSString stringWithFormat:embedHTMLTemplate, _videoId, autoplay];
    return embedHTML;
}

- (NSURL *)_baseURL
{
    return [NSURL URLWithString:@"https://player.vimeo.com/"];
}

- (void)_setupUserScripts:(WKUserContentController *)contentController
{
    NSError *error = nil;
    NSString *path = TGComponentsPathForResource(@"VimeoPlayerInject", @"js");
    NSString *scriptText = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
        TGLegacyLog(@"[VimeoEmbedPlayer]: Received error loading inject script: %@", error);
    
    WKUserScript *script = [[WKUserScript alloc] initWithSource:scriptText injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:false];
    [contentController addUserScript:script];
}

- (bool)_scaleViewToMaxSize
{
    return true;
}

+ (NSString *)_vimeoVideoIdFromText:(NSString *)text
{
    if ([text hasPrefix:@"http://player.vimeo.com/video/"] || [text hasPrefix:@"https://player.vimeo.com/video/"])
    {
        NSString *suffix = @"";
        
        NSMutableArray *prefixes = [NSMutableArray arrayWithArray:@
        [
            @"http://player.vimeo.com/video/",
            @"https://player.vimeo.com/video/"
        ]];
        
        while (suffix.length == 0 && prefixes.count > 0)
        {
            NSString *prefix = prefixes.firstObject;
            if ([text hasPrefix:prefix])
            {
                suffix = [text substringFromIndex:prefix.length];
                break;
            }
            else
            {
                [prefixes removeObjectAtIndex:0];
            }
        }
        
        for (int i = 0; i < (int)suffix.length; i++)
        {
            unichar c = [suffix characterAtIndex:i];
            if (!((c >= '0' && c <= '9')))
                break;
        }
        
        return suffix;
    }
    
    return nil;
}

+ (bool)_supportsWebPage:(TGWebPageMediaAttachment *)webPage
{
    NSString *url = webPage.embedUrl;
    return ([url hasPrefix:@"http://player.vimeo.com/video/"] || [url hasPrefix:@"https://player.vimeo.com/video/"]);
}

@end
