#import "TGAnimatedEmojiStore.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGStickerPack.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGStickerAssociation.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGStickerPackReference.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDocumentMediaAttachment.h"
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

#import "TGStickersSignals.h"

#import <pthread.h>

NSString *const TGAnimatedEmojiStoreDidUpdateNotification = @"TGAnimatedEmojiStoreDidUpdateNotification";

static NSString *const TGAnimatedEmojiPackShortName = @"AnimatedEmojies";
static NSString *const TGAnimatedEmojiUpdateDateKey = @"Onegram.AnimatedEmoji.UpdateDate";
static const NSTimeInterval TGAnimatedEmojiRefreshInterval = 24.0 * 60.0 * 60.0;

static pthread_mutex_t TGAnimatedEmojiLock = PTHREAD_MUTEX_INITIALIZER;
static NSDictionary *TGAnimatedEmojiDocuments = nil;
static bool TGAnimatedEmojiPreloaded = false;
static bool TGAnimatedEmojiLoading = false;

static NSString *TGAnimatedEmojiNormalizedKey(NSString *emoji)
{
    return [emoji stringByReplacingOccurrencesOfString:@"️" withString:@""];
}

static NSString *TGAnimatedEmojiCachePath(void)
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, true);
    NSString *caches = paths.count != 0 ? paths[0] : NSTemporaryDirectory();
    return [caches stringByAppendingPathComponent:@"animated-emoji.pack"];
}

static NSDictionary *TGAnimatedEmojiDocumentsForPack(TGStickerPack *pack)
{
    NSMutableDictionary *documentsById = [[NSMutableDictionary alloc] init];
    for (TGDocumentMediaAttachment *document in pack.documents)
    {
        if ([document isKindOfClass:[TGDocumentMediaAttachment class]] && document.documentId != 0)
            documentsById[@(document.documentId)] = document;
    }
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    for (TGStickerAssociation *association in pack.stickerAssociations)
    {
        if (![association isKindOfClass:[TGStickerAssociation class]] || association.key.length == 0)
            continue;
        for (NSNumber *documentId in association.documentIds)
        {
            TGDocumentMediaAttachment *document = documentsById[documentId];
            if (document != nil)
            {
                result[TGAnimatedEmojiNormalizedKey(association.key)] = document;
                break;
            }
        }
    }
    return result;
}

static void TGAnimatedEmojiApplyPack(TGStickerPack *pack)
{
    NSDictionary *documents = TGAnimatedEmojiDocumentsForPack(pack);
    pthread_mutex_lock(&TGAnimatedEmojiLock);
    TGAnimatedEmojiDocuments = documents;
    pthread_mutex_unlock(&TGAnimatedEmojiLock);
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:TGAnimatedEmojiStoreDidUpdateNotification object:nil];
    });
}

@implementation TGAnimatedEmojiStore

+ (void)preload
{
    pthread_mutex_lock(&TGAnimatedEmojiLock);
    bool alreadyPreloaded = TGAnimatedEmojiPreloaded;
    TGAnimatedEmojiPreloaded = true;
    pthread_mutex_unlock(&TGAnimatedEmojiLock);
    if (alreadyPreloaded)
        return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^
    {
        TGStickerPack *cachedPack = nil;
        @try
        {
            NSData *data = [[NSData alloc] initWithContentsOfFile:TGAnimatedEmojiCachePath()];
            if (data.length != 0)
                cachedPack = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        }
        @catch (__unused NSException *exception)
        {
            cachedPack = nil;
        }
        if ([cachedPack isKindOfClass:[TGStickerPack class]])
            TGAnimatedEmojiApplyPack(cachedPack);
        else
            cachedPack = nil;
        dispatch_async(dispatch_get_main_queue(), ^
        {
            NSTimeInterval updateDate = [[NSUserDefaults standardUserDefaults] doubleForKey:TGAnimatedEmojiUpdateDateKey];
            if (cachedPack == nil || CFAbsoluteTimeGetCurrent() - updateDate > TGAnimatedEmojiRefreshInterval)
                [self refresh];
        });
    });
}

+ (void)refresh
{
    if (TGAnimatedEmojiLoading)
        return;
    TGAnimatedEmojiLoading = true;
    TGStickerPackShortnameReference *reference = [[TGStickerPackShortnameReference alloc] initWithShortName:TGAnimatedEmojiPackShortName];
    [[[TGStickersSignals stickerPackInfo:reference] deliverOn:[SQueue concurrentDefaultQueue]] startWithNext:^(id next)
    {
        if (![next isKindOfClass:[TGStickerPack class]])
            return;
        TGStickerPack *pack = next;
        TGAnimatedEmojiApplyPack(pack);
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:pack];
        if (data.length != 0)
            [data writeToFile:TGAnimatedEmojiCachePath() atomically:true];
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [[NSUserDefaults standardUserDefaults] setDouble:CFAbsoluteTimeGetCurrent() forKey:TGAnimatedEmojiUpdateDateKey];
        });
    } error:^(__unused id error)
    {
        TGDispatchOnMainThread(^
        {
            TGAnimatedEmojiLoading = false;
        });
    } completed:^
    {
        TGDispatchOnMainThread(^
        {
            TGAnimatedEmojiLoading = false;
        });
    }];
}

+ (TGDocumentMediaAttachment *)documentForText:(NSString *)text
{
    if (text.length == 0 || text.length > 16)
        return nil;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0)
        return nil;
    NSRange range = [trimmed rangeOfComposedCharacterSequenceAtIndex:0];
    if (range.location != 0 || range.length != trimmed.length)
        return nil;
    pthread_mutex_lock(&TGAnimatedEmojiLock);
    NSDictionary *documents = TGAnimatedEmojiDocuments;
    bool preloaded = TGAnimatedEmojiPreloaded;
    pthread_mutex_unlock(&TGAnimatedEmojiLock);
    if (!preloaded)
        TGDispatchOnMainThread(^
        {
            [self preload];
        });
    return documents[TGAnimatedEmojiNormalizedKey(trimmed)];
}

@end
