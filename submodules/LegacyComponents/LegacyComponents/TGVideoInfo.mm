#import "TGVideoInfo.h"

#include <vector>

static const int32_t TGVideoInfoModernTag = (int32_t)0xe7d1c0de;
static const uint8_t TGVideoInfoModernVersion = 1;

struct TGVideoQualityRecord
{
    int quality;
    int size;
    NSString *url;
    NSString *codec;
    
    TGVideoQualityRecord(int quality_, NSString *url_, int size_, NSString *codec_) :
        quality(quality_), size(size_)
    {
        url = url_;
        codec = codec_;
    }
    
    TGVideoQualityRecord(const TGVideoQualityRecord &other)
    {
        url = other.url;
        codec = other.codec;
        quality = other.quality;
        size = other.size;
    }
    
    TGVideoQualityRecord & operator= (const TGVideoQualityRecord &other)
    {
        if (this != &other)
        {
            url = other.url;
            codec = other.codec;
            quality = other.quality;
            size = other.size;
        }
        
        return *this;
    }
    
    ~TGVideoQualityRecord()
    {
        url = nil;
        codec = nil;
    }
};

static void TGVideoInfoWriteString(NSMutableData *data, NSString *string)
{
    NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
    int32_t length = (int32_t)stringData.length;
    [data appendBytes:&length length:4];
    if (length != 0)
        [data appendData:stringData];
}

static NSString *TGVideoInfoReadString(NSInputStream *is)
{
    int32_t length = 0;
    [is read:(uint8_t *)&length maxLength:4];
    if (length <= 0)
        return @"";
    uint8_t *bytes = (uint8_t *)malloc(length);
    [is read:bytes maxLength:length];
    return [[NSString alloc] initWithBytesNoCopy:bytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
}

@interface TGVideoInfo ()
{
    std::vector<TGVideoQualityRecord> _qualitySet;
}

@end

@implementation TGVideoInfo

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _qualitySet.push_back(TGVideoQualityRecord(0, [aDecoder decodeObjectForKey:@"url"], [aDecoder decodeInt32ForKey:@"size"], [aDecoder decodeObjectForKey:@"codec"]));
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    if (!_qualitySet.empty()) {
        auto q = _qualitySet[0];
        [aCoder encodeInt32:q.size forKey:@"size"];
        [aCoder encodeObject:q.url forKey:@"url"];
        if (q.codec != nil)
            [aCoder encodeObject:q.codec forKey:@"codec"];
    }
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[TGVideoInfo class]])
        return false;
    
    TGVideoInfo *other = object;
    
    if (_qualitySet.size() != other->_qualitySet.size())
        return false;
    
    for (size_t i = 0; i < _qualitySet.size(); i++)
    {
        if (_qualitySet[i].quality != other->_qualitySet[i].quality)
            return false;
        
        if (_qualitySet[i].size != other->_qualitySet[i].size)
            return false;
        
        if (![_qualitySet[i].url isEqualToString:other->_qualitySet[i].url])
            return false;
        
        if (_qualitySet[i].codec != other->_qualitySet[i].codec && ![_qualitySet[i].codec isEqualToString:other->_qualitySet[i].codec])
            return false;
    }
    
    return true;
}

- (void)addVideoWithQuality:(int)quality url:(NSString *)url size:(int)size
{
    [self addVideoWithQuality:quality url:url size:size codec:nil];
}

- (void)addVideoWithQuality:(int)quality url:(NSString *)url size:(int)size codec:(NSString *)codec
{
    _qualitySet.push_back(TGVideoQualityRecord(quality, url, size, codec.length == 0 ? nil : codec));
}

- (void)enumerateVideos:(void (^)(int quality, NSString *url, int size, NSString *codec))block
{
    if (block == nil)
        return;
    for (std::vector<TGVideoQualityRecord>::iterator it = _qualitySet.begin(); it != _qualitySet.end(); it++)
        block(it->quality, it->url, it->size, it->codec);
}

- (NSString *)urlWithQuality:(int)quality actualQuality:(int *)actualQuality actualSize:(int *)actualSize
{
    NSString *url = nil;
    int closestQuality = INT_MAX;
    int closestSize = 0;
    
    for (std::vector<TGVideoQualityRecord>::iterator it = _qualitySet.begin(); it != _qualitySet.end(); it++)
    {
        if (it->quality == quality)
        {
            if (actualQuality != NULL)
                *actualQuality = quality;
            if (actualSize != NULL)
                *actualSize = it->size;
            return it->url;
        }
        else if (ABS(it->quality - quality) < ABS(closestQuality - quality))
        {
            closestQuality = quality;
            url = it->url;
            closestSize = it->size;
        }
    }
    
    if (url != nil)
    {
        if (actualQuality != NULL)
            *actualQuality = closestQuality;
        if (actualSize != NULL)
            *actualSize = closestSize;
    }
    
    return url;
}

- (void)serialize:(NSMutableData *)data
{
    int32_t tag = TGVideoInfoModernTag;
    [data appendBytes:&tag length:4];
    uint8_t version = TGVideoInfoModernVersion;
    [data appendBytes:&version length:1];
    
    int32_t count = (int32_t)_qualitySet.size();
    [data appendBytes:&count length:4];
    
    for (std::vector<TGVideoQualityRecord>::iterator it = _qualitySet.begin(); it != _qualitySet.end(); it++)
    {
        TGVideoInfoWriteString(data, it->url);
        [data appendBytes:&it->quality length:4];
        [data appendBytes:&it->size length:4];
        TGVideoInfoWriteString(data, it->codec);
    }
}

+ (TGVideoInfo *)deserialize:(NSInputStream *)is
{
    TGVideoInfo *videoInfo = [[TGVideoInfo alloc] init];
    
    int32_t count = 0;
    [is read:(uint8_t *)&count maxLength:4];
    
    bool hasCodecs = false;
    if (count == TGVideoInfoModernTag)
    {
        uint8_t version = 0;
        [is read:&version maxLength:1];
        hasCodecs = version >= 1;
        [is read:(uint8_t *)&count maxLength:4];
    }
    
    for (int32_t i = 0; i < count; i++)
    {
        NSString *url = TGVideoInfoReadString(is);
        
        int quality = 0;
        [is read:(uint8_t *)&quality maxLength:4];
        
        int size = 0;
        [is read:(uint8_t *)&size maxLength:4];
        
        NSString *codec = hasCodecs ? TGVideoInfoReadString(is) : nil;
        
        [videoInfo addVideoWithQuality:quality url:url size:size codec:codec];
    }
    
    return videoInfo;
}

@end
