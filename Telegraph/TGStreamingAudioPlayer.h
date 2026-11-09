#import "TGAudioPlayer.h"

#import <AudioToolbox/AudioToolbox.h>

@class OGMediaStreamReader;

@interface TGStreamingAudioPlayer : TGAudioPlayer

+ (AudioFileTypeID)fileTypeForPathExtension:(NSString *)pathExtension;

- (instancetype)initWithReader:(OGMediaStreamReader *)reader fileType:(AudioFileTypeID)fileType music:(bool)music controlAudioSession:(bool)controlAudioSession;

@end
