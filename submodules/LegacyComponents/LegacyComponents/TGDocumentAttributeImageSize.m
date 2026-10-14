#import "TGDocumentAttributeImageSize.h"

#import "PSKeyValueCoder.h"

@implementation TGDocumentAttributeImageSize

- (instancetype)initWithSize:(CGSize)size
{
    self = [super init];
    if (self != nil)
    {
        _size = size;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithSize:CGSizeMake([coder decodeInt32ForCKey:"w"], [coder decodeInt32ForCKey:"h"])];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeInt32:(int32_t)_size.width forCKey:"w"];
    [coder encodeInt32:(int32_t)_size.height forCKey:"h"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    CGFloat width = (CGFloat)[aDecoder decodeDoubleForKey:@"sizeWidth"];
    CGFloat height = (CGFloat)[aDecoder decodeDoubleForKey:@"sizeHeight"];
    if (width == 0.0f && height == 0.0f)
    {
        @try
        {
            CGSize legacySize = [aDecoder decodeCGSizeForKey:@"size"];
            width = legacySize.width;
            height = legacySize.height;
        }
        @catch (__unused NSException *exception)
        {
        }
    }
    return [self initWithSize:CGSizeMake(width, height)];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeDouble:_size.width forKey:@"sizeWidth"];
    [aCoder encodeDouble:_size.height forKey:@"sizeHeight"];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGDocumentAttributeImageSize class]] && CGSizeEqualToSize(_size, ((TGDocumentAttributeImageSize *)object)->_size);
}

@end
