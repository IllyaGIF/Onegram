#ifndef TG_LEGACY_TL_TLACCOUNT_WALLPAPERS_H
#define TG_LEGACY_TL_TLACCOUNT_WALLPAPERS_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"


@interface TLaccount_WallPapers : NSObject <TLObject>


@end

@interface TLaccount_WallPapers$account_wallPapers : TLaccount_WallPapers

@property (nonatomic) int64_t n_hash;
@property (nonatomic, retain) NSArray *wallpapers;

@end

@interface TLaccount_WallPapers$account_wallPapersNotModified : TLaccount_WallPapers


@end

#endif
