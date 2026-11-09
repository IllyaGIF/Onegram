#import "TGCallVideoCapturer.h"
#import "TGCallVideoView.h"

#include "../thirdparty/TgVoipWebrtcIOS6/include/tgcalls/TGIOS6CxxCompat.h"
#include <memory>

namespace tgcalls {
class VideoFrameSink;
class VideoCaptureController;
}

@interface TGCallVideoView (TGCallVideoNative)

- (std::shared_ptr<tgcalls::VideoFrameSink>)frameSink;

@end

@interface TGCallVideoCapturer (TGCallVideoNative)

- (void)setFrameSink:(std::shared_ptr<tgcalls::VideoFrameSink>)sink;
- (std::shared_ptr<tgcalls::VideoCaptureController>)captureController;

@end
