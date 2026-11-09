#import <Foundation/Foundation.h>

@interface TGMusicUtils : NSObject

+ (CGSize)albumArtworkPixelSize:(bool)thumbnail;
+ (UIImage *)albumArtwork:(UIImage *)image thumbnail:(bool)thumbnail;
+ (void)albumArtworkForURL:(NSURL *)url completion:(void (^)(UIImage *))completion;

@end
