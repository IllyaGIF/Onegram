#import "TGBingSearchResultItem.h"

@implementation TGBingSearchResultItem

- (instancetype)initWithImageUrl:(NSString *)imageUrl imageSize:(CGSize)imageSize previewUrl:(NSString *)previewUrl previewSize:(CGSize)previewSize
{
    self = [super init];
    if (self != nil)
    {
        _imageUrl = imageUrl;
        _imageSize = imageSize;
        _previewUrl = previewUrl;
        _previewSize = previewSize;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    CGSize imageSize = CGSizeMake((CGFloat)[aDecoder decodeDoubleForKey:@"imageWidth"], (CGFloat)[aDecoder decodeDoubleForKey:@"imageHeight"]);
    CGSize previewSize = CGSizeMake((CGFloat)[aDecoder decodeDoubleForKey:@"previewWidth"], (CGFloat)[aDecoder decodeDoubleForKey:@"previewHeight"]);
    return [self initWithImageUrl:[aDecoder decodeObjectForKey:@"imageUrl"] imageSize:imageSize previewUrl:[aDecoder decodeObjectForKey:@"previewUrl"] previewSize:previewSize];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_imageUrl == nil ? @"" : _imageUrl forKey:@"imageUrl"];
    [aCoder encodeDouble:_imageSize.width forKey:@"imageWidth"];
    [aCoder encodeDouble:_imageSize.height forKey:@"imageHeight"];
    [aCoder encodeObject:_previewUrl == nil ? @"" : _previewUrl forKey:@"previewUrl"];
    [aCoder encodeDouble:_previewSize.width forKey:@"previewWidth"];
    [aCoder encodeDouble:_previewSize.height forKey:@"previewHeight"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGBingSearchResultItem class]] && TGStringCompare(_imageUrl, ((TGBingSearchResultItem *)object)->_imageUrl) && TGStringCompare(_previewUrl, ((TGBingSearchResultItem *)object)->_previewUrl);
}

@end
