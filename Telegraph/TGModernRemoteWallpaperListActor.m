/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGModernRemoteWallpaperListActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TL/TLMetaScheme.h"
#import "TGTelegraph.h"

#import "TGImageInfo+Telegraph.h"
#import "TGDocumentMediaAttachment+Telegraph.h"
#import "TGCloudThemeWallpaper.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteWallpaperInfo.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGColorWallpaperInfo.h"

static bool alreadyCachedList = false;

@implementation TGModernRemoteWallpaperListActor

+ (NSString *)genericPath
{
    return @"/tg/remoteWallpapers/@";
}

+ (NSArray *)cachedList
{
    NSMutableArray *wallpaperInfos = [[NSMutableArray alloc] init];
    
    NSArray *list = [[NSUserDefaults standardUserDefaults] objectForKey:@"TG_remoteWallpaperList"];
    if (list != nil)
    {
        for (NSDictionary *dict in list)
        {
            TGWallpaperInfo *wallpaperInfo = [TGWallpaperInfo infoWithDictionary:dict];
            if (wallpaperInfo != nil)
                [wallpaperInfos addObject:wallpaperInfo];
        }
    }
    
    return wallpaperInfos;
}

+ (void)cacheList:(NSArray *)wallpaperInfos
{
    TGDispatchOnMainThread(^
    {
        NSMutableArray *list = [[NSMutableArray alloc] init];
        
        for (TGWallpaperInfo *wallpaperInfo in wallpaperInfos)
        {
            NSDictionary *dict = [wallpaperInfo infoDictionary];
            if (dict != nil)
                [list addObject:dict];
        }
        
        [[NSUserDefaults standardUserDefaults] setObject:list forKey:@"TG_remoteWallpaperList"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
}

- (void)execute:(NSDictionary *)__unused options
{
    if (alreadyCachedList)
        [ActionStageInstance() actionFailed:self.path reason:-1];
    else
        self.cancelToken = [TGTelegraphInstance doRequestWallpaperList:(TGWallpaperListRequestActor *)self];
}

- (void)wallpaperListRequestSuccess:(NSArray *)wallpaperList
{
    NSMutableArray *wallpaperInfos = [[NSMutableArray alloc] init];
    
    for (id item in wallpaperList)
    {
        if ([item isKindOfClass:[TLWallPaper$wallPaperNoFile class]])
        {
            TLWallPaper$wallPaperNoFile *wallpaper = item;
            TLWallPaperSettings$wallPaperSettings *settings = wallpaper.settings;
            if (!(settings.flags & 1))
                continue;
            NSMutableArray *colors = [[NSMutableArray alloc] initWithObjects:@((uint32_t)settings.background_color & 0xffffff), nil];
            if (settings.flags & (1 << 4))
                [colors addObject:@((uint32_t)settings.second_background_color & 0xffffff)];
            if (settings.flags & (1 << 5))
                [colors addObject:@((uint32_t)settings.third_background_color & 0xffffff)];
            if (settings.flags & (1 << 6))
                [colors addObject:@((uint32_t)settings.fourth_background_color & 0xffffff)];
            if (colors.count == 1)
            {
                uint32_t rgb = [colors[0] unsignedIntValue];
                CGFloat luminance = (0.299f * ((rgb >> 16) & 0xff) + 0.587f * ((rgb >> 8) & 0xff) + 0.114f * (rgb & 0xff)) / 255.0f;
                if (luminance < 0.2f)
                    [wallpaperInfos addObject:[[TGColorWallpaperInfo alloc] initWithColor:rgb tintColor:0xffffff systemAlpha:0.2f buttonsAlpha:0.3f highlightedButtonAlpha:0.45f progressAlpha:0.3f]];
                else
                    [wallpaperInfos addObject:[[TGColorWallpaperInfo alloc] initWithColor:rgb]];
            }
            else
            {
                [wallpaperInfos addObject:[[TGGradientWallpaperInfo alloc] initWithWallpaperId:wallpaper.n_id colors:colors rotation:settings.rotation]];
            }
        }
        else if ([item isKindOfClass:[TLWallPaper$wallPaper class]])
        {
            TLWallPaper$wallPaper *concreteWallpaper = item;
            TGDocumentMediaAttachment *document = [[TGDocumentMediaAttachment alloc] initWithTelegraphDocumentDesc:concreteWallpaper.document];
            TGImageInfo *imageInfo = document.thumbnailInfo;
            
            NSString *thumbnailUri = [imageInfo closestImageUrlWithSize:CGSizeMake(256.0f, 256.0f) resultingSize:NULL];
            
            CGSize fullscreenSize = TGScreenScaling() > 2 ? CGSizeMake(1080, 1920) : CGSizeMake(640.0f, 1136.0f);
            NSString *fullscreenUri = [imageInfo closestImageUrlWithSize:fullscreenSize resultingSize:NULL];
            if (thumbnailUri != nil && fullscreenUri != nil)
            {
                TGRemoteWallpaperInfo *wallpaperInfo = [[TGRemoteWallpaperInfo alloc] initWithRemoteId:concreteWallpaper.n_id thumbnailUri:thumbnailUri fullscreenUri:fullscreenUri tintColor:0];
                [wallpaperInfos addObject:wallpaperInfo];
            }
        }
    }
    
    [TGModernRemoteWallpaperListActor cacheList:wallpaperInfos];
    alreadyCachedList = true;
    
    [ActionStageInstance() actionCompleted:self.path result:@{@"wallpaperInfos": wallpaperInfos}];
}

- (void)wallpaperListRequestFailed
{
    [ActionStageInstance() actionFailed:self.path reason:-1];
}

@end
