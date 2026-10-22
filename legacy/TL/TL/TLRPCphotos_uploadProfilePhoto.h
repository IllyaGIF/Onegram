#ifndef TG_LEGACY_TL_TLRPCPHOTOS_UPLOADPROFILEPHOTO_H
#define TG_LEGACY_TL_TLRPCPHOTOS_UPLOADPROFILEPHOTO_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLInputFile;
@class TLInputUser;
@class TLVideoSize;
@class TLphotos_Photo;

@interface TLRPCphotos_uploadProfilePhoto : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLInputUser *bot;
@property (nonatomic, retain) TLInputFile *file;
@property (nonatomic, retain) TLInputFile *video;
@property (nonatomic) double video_start_ts;
@property (nonatomic, retain) TLVideoSize *video_emoji_markup;

- (Class)responseClass;

- (int)impliedResponseSignature;

@end

@interface TLRPCphotos_uploadProfilePhoto$photos_uploadProfilePhoto : TLRPCphotos_uploadProfilePhoto


@end

#endif
