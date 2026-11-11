#import "TGAudioMediaAttachment+Telegraph.h"

#import "TGAppDelegate.h"
#import <objc/runtime.h>

static const void *OGCompatAudioOriginKey = &OGCompatAudioOriginKey;

@implementation TGAudioMediaAttachment (TG)

- (void)setDownloadOriginInfo:(TGMediaOriginInfo *)downloadOriginInfo
{
    objc_setAssociatedObject(self, OGCompatAudioOriginKey, downloadOriginInfo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (TGMediaOriginInfo *)downloadOriginInfo
{
    return objc_getAssociatedObject(self, OGCompatAudioOriginKey);
}

+ (NSString *)localAudioFileDirectoryForLocalAudioId:(int64_t)audioId
{
    NSString *documentsDirectory = [TGAppDelegate documentsPath];
    NSString *audiosDirectory = [documentsDirectory stringByAppendingPathComponent:@"audio"];
    return [audiosDirectory stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"local%" PRIx64 "", audioId]];
}

+ (NSString *)localAudioFileDirectoryForRemoteAudioId:(int64_t)audioId
{
    NSString *documentsDirectory = [TGAppDelegate documentsPath];
    NSString *audiosDirectory = [documentsDirectory stringByAppendingPathComponent:@"audio"];
    return [audiosDirectory stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"%" PRIx64 "", audioId]];
}

- (NSString *)localFilePath
{
    if (self.localAudioId != 0)
        return [[TGAudioMediaAttachment localAudioFileDirectoryForLocalAudioId:self.localAudioId] stringByAppendingPathComponent:@"audio.m4a"];
    return [[TGAudioMediaAttachment localAudioFileDirectoryForRemoteAudioId:self.audioId] stringByAppendingPathComponent:@"audio.m4a"];
}

+ (NSString *)localAudioFilePathForLocalAudioId:(int64_t)audioId
{
    return [[self localAudioFileDirectoryForLocalAudioId:audioId] stringByAppendingPathComponent:@"audio.m4a"];
}

+ (NSString *)localAudioFilePathForRemoteAudioId:(int64_t)audioId
{
    return [[self localAudioFileDirectoryForRemoteAudioId:audioId] stringByAppendingPathComponent:@"audio.m4a"];
}

@end
