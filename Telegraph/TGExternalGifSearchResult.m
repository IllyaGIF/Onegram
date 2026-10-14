#import "TGExternalGifSearchResult.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

@implementation TGExternalGifSearchResult

- (instancetype)initWithUrl:(NSString *)url originalUrl:(NSString *)originalUrl thumbnailUrl:(NSString *)thumbnailUrl size:(CGSize)size {
    self = [super init];
    if (self != nil) {
        _url = url;
        _originalUrl = originalUrl;
        _thumbnailUrl = thumbnailUrl;
        _size = size;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithUrl:[aDecoder decodeObjectForKey:@"url"] originalUrl:[aDecoder decodeObjectForKey:@"originalUrl"] thumbnailUrl:[aDecoder decodeObjectForKey:@"thumbnailUrl"] size:CGSizeMake((CGFloat)[aDecoder decodeDoubleForKey:@"sizeWidth"], (CGFloat)[aDecoder decodeDoubleForKey:@"sizeHeight"])];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_url forKey:@"url"];
    [aCoder encodeObject:_originalUrl forKey:@"originalUrl"];
    [aCoder encodeObject:_thumbnailUrl forKey:@"thumbnailUrl"];
    [aCoder encodeDouble:_size.width forKey:@"sizeWidth"];
    [aCoder encodeDouble:_size.height forKey:@"sizeHeight"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGExternalGifSearchResult class]] && TGStringCompare(_url, ((TGExternalGifSearchResult *)object)->_url);
}

- (NSUInteger)hash {
    return [_url hash];
}

@end
