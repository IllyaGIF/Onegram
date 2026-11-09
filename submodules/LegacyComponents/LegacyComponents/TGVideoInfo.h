

#import <Foundation/Foundation.h>

static const int TGVideoInfoAlternativeQualityBase = 1000;

@interface TGVideoInfo : NSObject <NSCoding>

- (void)addVideoWithQuality:(int)quality url:(NSString *)url size:(int)size;
- (void)addVideoWithQuality:(int)quality url:(NSString *)url size:(int)size codec:(NSString *)codec;
- (NSString *)urlWithQuality:(int)quality actualQuality:(int *)actualQuality actualSize:(int *)actualSize;
- (void)enumerateVideos:(void (^)(int quality, NSString *url, int size, NSString *codec))block;

- (void)serialize:(NSMutableData *)data;
+ (TGVideoInfo *)deserialize:(NSInputStream *)is;

@end
