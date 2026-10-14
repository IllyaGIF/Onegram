#import "TGGiphySearchResultItem.h"

@implementation TGGiphySearchResultItem

- (instancetype)initWithGifId:(NSString *)gifId gifUrl:(NSString *)gifUrl gifSize:(CGSize)gifSize gifFileSize:(NSUInteger)gifFileSize previewUrl:(NSString *)previewUrl previewSize:(CGSize)previewSize
{
    self = [super init];
    if (self != nil)
    {
        _gifId = gifId;
        _gifUrl = gifUrl;
        _gifSize = gifSize;
        _gifFileSize = gifFileSize;
        _previewUrl = previewUrl;
        _previewSize = previewSize;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    CGFloat gifWidth = (CGFloat)[aDecoder decodeDoubleForKey:@"gifWidth"];
    CGFloat gifHeight = (CGFloat)[aDecoder decodeDoubleForKey:@"gifHeight"];
    CGFloat previewWidth = (CGFloat)[aDecoder decodeDoubleForKey:@"previewWidth"];
    CGFloat previewHeight = (CGFloat)[aDecoder decodeDoubleForKey:@"previewHeight"];
    return [self initWithGifId:[aDecoder decodeObjectForKey:@"gifId"] gifUrl:[aDecoder decodeObjectForKey:@"gifUrl"] gifSize:CGSizeMake(gifWidth, gifHeight) gifFileSize:[aDecoder decodeIntegerForKey:@"gifFileSize"] previewUrl:[aDecoder decodeObjectForKey:@"previewUrl"] previewSize:CGSizeMake(previewWidth, previewHeight)];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_gifId == nil ? @"" : _gifId forKey:@"gifId"];
    [aCoder encodeObject:_gifUrl == nil ? @"" : _gifUrl forKey:@"gifUrl"];
    [aCoder encodeDouble:_gifSize.width forKey:@"gifWidth"];
    [aCoder encodeDouble:_gifSize.height forKey:@"gifHeight"];
    [aCoder encodeInteger:_gifFileSize forKey:@"gifFileSize"];
    [aCoder encodeObject:_previewUrl == nil ? @"" : _previewUrl forKey:@"previewUrl"];
    [aCoder encodeDouble:_previewSize.width forKey:@"previewWidth"];
    [aCoder encodeDouble:_previewSize.height forKey:@"previewHeight"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGGiphySearchResultItem class]] && TGStringCompare(_gifId, ((TGGiphySearchResultItem *)object)->_gifId);
}

@end
