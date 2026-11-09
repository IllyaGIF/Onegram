#import "TGWallpaperListRequestActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TGTelegraph.h"

#import "TGImageInfo+Telegraph.h"
#import "TGDocumentMediaAttachment+Telegraph.h"

#import "TGAppDelegate.h"

#define TGWallpaperListVersion 3

@implementation TGWallpaperListRequestActor

+ (NSString *)genericPath
{
    return @"/tg/assets/wallpaperList/@";
}

+ (NSArray *)parseWallpaperData:(NSData *)data
{
    NSInputStream *is = [[NSInputStream alloc] initWithData:data];
    [is open];
    
    __unused int version = [is readInt32];
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    int count = [is readInt32];
    for (int i = 0; i < count; i++)
    {
        int64_t itemId = [is readInt64];
        TGImageInfo *imageInfo = [TGImageInfo deserialize:is];
        int color = [is readInt32];
        
        [array addObject:[[NSDictionary alloc] initWithObjectsAndKeys:@(itemId), @"id", imageInfo, @"imageInfo", [[NSNumber alloc] initWithInt:color], @"color", nil]];
    }
    
    [is close];
    
    return array;
}

- (NSData *)serializeWallpaperData:(NSArray *)wallpaperList
{
    NSMutableData *data = [[NSMutableData alloc] init];
    
    int version = TGWallpaperListVersion;
    [data appendBytes:&version length:4];
    
    int count = (int)wallpaperList.count;
    [data appendBytes:&count length:4];
    
    for (NSDictionary *dict in wallpaperList)
    {
        int64_t itemId = [[dict objectForKey:@"id"] longLongValue];
        [data appendBytes:&itemId length:8];
        
        TGImageInfo *imageInfo = [dict objectForKey:@"imageInfo"];
        [imageInfo serialize:data];
        
        int color = [[dict objectForKey:@"color"] intValue];
        [data appendBytes:&color length:4];
    }
    
    return data;
}

+ (NSArray *)cachedList
{
    NSString *wallpapersPath = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"wallpapers"];
    NSData *wallpapersData = [[NSData alloc] initWithContentsOfFile:[wallpapersPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"_remote-list_v%d", TGWallpaperListVersion]]];
    
    if (wallpapersData != nil)
        return [TGWallpaperListRequestActor parseWallpaperData:wallpapersData];
    
    return nil;
}

- (void)execute:(NSDictionary *)__unused options
{
    static bool didRequestWallpaperList = false;
    
    NSString *wallpapersPath = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"wallpapers"];
    NSData *wallpapersData = [[NSData alloc] initWithContentsOfFile:[wallpapersPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"_remote-list_v%d", TGWallpaperListVersion]]];
    
    if (wallpapersData == nil || [self.path hasSuffix:@"force)"])
    {
        didRequestWallpaperList = true;
        self.cancelToken = [TGTelegraphInstance doRequestWallpaperList:self];
    }
    else if (wallpapersData != nil)
    {
        if (!didRequestWallpaperList)
        {
            [ActionStageInstance() requestActor:@"/tg/assets/wallpaperList/(force)" options:nil flags:0 watcher:TGTelegraphInstance];
        }
        
        NSArray *wallpaperList = [TGWallpaperListRequestActor parseWallpaperData:wallpapersData];
        [ActionStageInstance() actionCompleted:self.path result:wallpaperList];
    }
    else
    {
        [ActionStageInstance() actionFailed:self.path reason:-1];
    }
}

- (void)wallpaperListRequestSuccess:(NSArray *)wallpaperList
{
    NSMutableArray *parsedList = [[NSMutableArray alloc] init];
    for (TLWallPaper *wallpaperDesc in wallpaperList)
    {
        if ([wallpaperDesc isKindOfClass:[TLWallPaper$wallPaper class]])
        {
            TLWallPaper$wallPaper *concreteWallpaper = (TLWallPaper$wallPaper *)wallpaperDesc;
            
            TGDocumentMediaAttachment *document = [[TGDocumentMediaAttachment alloc] initWithTelegraphDocumentDesc:concreteWallpaper.document];
            TGImageInfo *imageInfo = document.thumbnailInfo;
            if (imageInfo.empty)
                continue;
            
            NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:@(concreteWallpaper.n_id), @"id", imageInfo, @"imageInfo", @(0), @"color", nil];
            [parsedList addObject:dict];
        }
    }
    
    NSData *data = [self serializeWallpaperData:parsedList];
    
    if (data != nil)
    {
        NSString *wallpapersPath = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"wallpapers"];
        [[ActionStageInstance() globalFileManager] createDirectoryAtPath:wallpapersPath withIntermediateDirectories:true attributes:nil error:nil];
        [data writeToFile:[wallpapersPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"_remote-list_v%d", TGWallpaperListVersion]] atomically:false];
        
        if ([self.path hasSuffix:@"force)"])
            [ActionStageInstance() dispatchResource:@"/tg/assets/wallpaperList" resource:parsedList];
        [ActionStageInstance() actionCompleted:self.path result:parsedList];
    }
    else
        [ActionStageInstance() actionFailed:self.path reason:-1];
}

- (void)wallpaperListRequestFailed
{
    [ActionStageInstance() actionFailed:self.path reason:-1];
}

@end
