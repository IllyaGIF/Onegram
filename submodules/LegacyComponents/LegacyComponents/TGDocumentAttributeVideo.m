#import "TGDocumentAttributeVideo.h"

#import "PSKeyValueCoder.h"

@implementation TGDocumentAttributeVideo

- (instancetype)initWithRoundMessage:(bool)isRoundMessage size:(CGSize)size duration:(int32_t)duration {
    self = [super init];
    if (self != nil) {
        _isRoundMessage = isRoundMessage;
        _size = size;
        _duration = duration;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    CGFloat width = (CGFloat)[aDecoder decodeDoubleForKey:@"sizeWidth"];
    CGFloat height = (CGFloat)[aDecoder decodeDoubleForKey:@"sizeHeight"];
    if (width == 0.0f && height == 0.0f) {
        @try {
            CGSize legacySize = [aDecoder decodeCGSizeForKey:@"size"];
            width = legacySize.width;
            height = legacySize.height;
        } @catch (__unused NSException *exception) {
        }
    }
    return [self initWithRoundMessage:[aDecoder decodeBoolForKey:@"roundMessage"] size:CGSizeMake(width, height) duration:[aDecoder decodeInt32ForKey:@"duration"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeBool:_isRoundMessage forKey:@"roundMessage"];
    [aCoder encodeDouble:_size.width forKey:@"sizeWidth"];
    [aCoder encodeDouble:_size.height forKey:@"sizeHeight"];
    [aCoder encodeInt32:_duration forKey:@"duration"];
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithRoundMessage:[coder decodeInt32ForCKey:"r"] size:CGSizeMake([coder decodeInt32ForCKey:"s.w"], [coder decodeInt32ForCKey:"s.h"]) duration:[coder decodeInt32ForCKey:"d"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeInt32:(int32_t)_isRoundMessage forKey:@"r"];
    [coder encodeInt32:(int32_t)_size.width forCKey:"s.w"];
    [coder encodeInt32:(int32_t)_size.height forCKey:"s.h"];
    [coder encodeInt32:_duration forCKey:"d"];
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[TGDocumentAttributeVideo class]] && _isRoundMessage == ((TGDocumentAttributeVideo *)object)->_isRoundMessage && CGSizeEqualToSize(_size, ((TGDocumentAttributeVideo *)object)->_size) && _duration == ((TGDocumentAttributeVideo *)object)->_duration;
}

@end
