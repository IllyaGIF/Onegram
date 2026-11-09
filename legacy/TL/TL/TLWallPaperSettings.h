#ifndef TG_LEGACY_TL_TLWALLPAPERSETTINGS_H
#define TG_LEGACY_TL_TLWALLPAPERSETTINGS_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"


@interface TLWallPaperSettings : NSObject <TLObject>

@property (nonatomic) int32_t flags;
@property (nonatomic) int32_t background_color;
@property (nonatomic) int32_t second_background_color;
@property (nonatomic) int32_t third_background_color;
@property (nonatomic) int32_t fourth_background_color;
@property (nonatomic) int32_t intensity;
@property (nonatomic) int32_t rotation;
@property (nonatomic, retain) NSString *emoticon;

@end

@interface TLWallPaperSettings$wallPaperSettings : TLWallPaperSettings


@end

#endif
