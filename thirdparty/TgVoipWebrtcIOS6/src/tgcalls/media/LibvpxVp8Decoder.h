#ifndef TGCALLS_MEDIA_LIBVPX_VP8_DECODER_H
#define TGCALLS_MEDIA_LIBVPX_VP8_DECODER_H

#include "media/VideoDecoder.h"

#include "vpx/vpx_decoder.h"

namespace tgcalls {

class LibvpxVp8Decoder : public VideoDecoder {
public:
    LibvpxVp8Decoder();
    ~LibvpxVp8Decoder();

    Result decode(const EncodedVideoFrame &frame, VideoFrameSink &sink) override;

private:
    LibvpxVp8Decoder(const LibvpxVp8Decoder &) = delete;
    LibvpxVp8Decoder &operator=(const LibvpxVp8Decoder &) = delete;

    bool ensureContext();
    void destroyContext();

    vpx_codec_ctx_t _context;
    bool _initialized;
};

}

#endif
