#ifndef TG_LEGACY_TL_TLWALLPAPER_H
#define TG_LEGACY_TL_TLWALLPAPER_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLDocument;
@class TLWallPaperSettings;

@interface TLWallPaper : NSObject <TLObject>

@property (nonatomic) int64_t n_id;
@property (nonatomic, retain) NSString *title;
@property (nonatomic) int32_t color;

@end

@interface TLWallPaper$wallPaper : TLWallPaper

@property (nonatomic) int32_t flags;
@property (nonatomic) int64_t access_hash;
@property (nonatomic, retain) NSString *slug;
@property (nonatomic, retain) TLDocument *document;
@property (nonatomic, retain) TLWallPaperSettings *settings;

@end

@interface TLWallPaper$wallPaperSolid : TLWallPaper

@property (nonatomic) int32_t bg_color;

@end

@interface TLWallPaper$wallPaperNoFile : TLWallPaper

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLWallPaperSettings *settings;

@end

#endif
