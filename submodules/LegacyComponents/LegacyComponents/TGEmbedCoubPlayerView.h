#import "TGEmbedPlayerView.h"

@interface TGEmbedCoubPlayerView : TGEmbedPlayerView

+ (NSString *)_coubVideoIdFromText:(NSString *)text;

+ (NSDictionary *)coubJSONByPermalink:(NSString *)permalink;
+ (void)setCoubJSON:(NSDictionary *)json forPermalink:(NSString *)permalink;
+ (void)reloadForAccountSwitch;

- (void)setVideoPath:(NSString *)videoPath;

@end
