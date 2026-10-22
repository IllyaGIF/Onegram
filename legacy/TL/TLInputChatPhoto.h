#ifndef TG_LEGACY_TL_TLINPUTCHATPHOTO_H
#define TG_LEGACY_TL_TLINPUTCHATPHOTO_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputFile;
@class TLInputPhoto;
@class TLVideoSize;

@interface TLInputChatPhoto : NSObject <TLObject>


@end

@interface TLInputChatPhoto$inputChatPhotoEmpty : TLInputChatPhoto


@end

@interface TLInputChatPhoto$inputChatUploadedPhoto : TLInputChatPhoto

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLInputFile *file;
@property (nonatomic, retain) TLInputFile *video;
@property (nonatomic) double video_start_ts;
@property (nonatomic, retain) TLVideoSize *video_emoji_markup;

@end

@interface TLInputChatPhoto$inputChatPhoto : TLInputChatPhoto

@property (nonatomic, retain) TLInputPhoto *n_id;

@end

#endif
