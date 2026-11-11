/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "../submodules/LegacyComponents/LegacyComponents/ASActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

@class TLInputFileLocation;

#ifdef __cplusplus
extern "C" {
#endif

TLInputFileLocation *OGInputLocationFromImageUrl(NSString *url, TGMediaOriginInfo *originInfo, int *datacenterId, int64_t *identifier);

#ifdef __cplusplus
}
#endif

@interface TGImageDownloadActor : ASActor <ASWatcher>
@property (nonatomic, strong) ASHandle *actionHandle;

+ (NSString *)genericPath;

+ (NSOperationQueue *)operationQueue;

+ (void)addUrlRewrite:(NSString *)currentUrl newUrl:(NSString *)newUrl;

+ (NSDictionary *)serverMediaDataForAssetUrl:(NSString *)assetUrl;
+ (void)addServerMediaDataForAssetUrl:(NSString *)assetUrl attachment:(TGMediaAttachment *)attachment;
+ (void)clearServerMediaSataForAssetUrl:(NSString *)assetUrl;

+ (void)reloadForAccountSwitch;

@end
