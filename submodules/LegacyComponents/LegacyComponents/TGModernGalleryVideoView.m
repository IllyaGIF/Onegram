#import "TGModernGalleryVideoView.h"
#import <AVFoundation/AVFoundation.h>

#import "LegacyComponentsInternal.h"
#import <QuartzCore/QuartzCore.h>


@implementation TGModernGalleryVideoView

- (instancetype)initWithFrame:(CGRect)frame player:(AVPlayer *)player
{
    return [self initWithFrame:frame player:player key:nil];
}

- (instancetype)initWithFrame:(CGRect)frame player:(AVPlayer *)player key:(NSString *)key
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _key = key;
        self.playerLayer.player = player;
        
        if (iosMajorVersion() >= 11)
            self.accessibilityIgnoresInvertColors = true;
    }
    return self;
}

- (void)dealloc
{
    void (^deallocBlock)(void) = self.deallocBlock;
    if (deallocBlock != nil)
        deallocBlock();
}

- (void)setPlayer:(AVPlayer *)player
{
    self.playerLayer.player = player;
}

- (AVPlayer *)player
{
    return self.playerLayer.player;
}

- (void)cleanupPlayer
{
    self.playerLayer.player = nil;
}

+ (Class)layerClass
{
    return [AVPlayerLayer class];
}

- (AVPlayerLayer *)playerLayer
{
    return (AVPlayerLayer *)self.layer;
}

@end
