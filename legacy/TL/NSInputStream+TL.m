#import "NSInputStream+TL.h"

#import <endian.h>

static inline int roundUpInput(int numToRound, int multiple)
{
    if (multiple == 0)
    {
        return numToRound;
    }
    
    int remainder = numToRound % multiple;
    if (remainder == 0)
    {
        return numToRound;
    }
    
    return numToRound + multiple - remainder;
}

static NSInteger TLReadExactly(NSInputStream *stream, uint8_t *buffer, NSUInteger length)
{
    NSUInteger offset = 0;
    while (offset < length)
    {
        NSInteger count = [stream read:buffer + offset maxLength:length - offset];
        if (count <= 0)
            break;
        offset += (NSUInteger)count;
    }
    return (NSInteger)offset;
}

@implementation NSInputStream (TL)

- (int32_t)readInt32
{
    int32_t value = 0;
    
    if (TLReadExactly(self, (uint8_t *)&value, 4) != 4)
    {
        TGLog(@"***** Couldn't read int32");
        
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readInt32 end of stream" userInfo:@{}];
    }
    
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
    
    return value;
}

- (int32_t)readInt32:(bool *)failed
{
    int32_t value = 0;
    
    if (TLReadExactly(self, (uint8_t *)&value, 4) != 4)
    {
        *failed = true;
        return 0;
    }
    
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
    
    return value;
}

- (int64_t)readInt64
{
    int64_t value = 0;
    
    if (TLReadExactly(self, (uint8_t *)&value, 8) != 8)
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readInt64 end of stream" userInfo:@{}];
    
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
    
    return value;
}

- (int64_t)readInt64:(bool *)failed
{
    int64_t value = 0;
    
    if (TLReadExactly(self, (uint8_t *)&value, 8) != 8)
    {
        *failed = true;
        return 0;
    }
    
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
    
    return value;
}

- (double)readDouble
{
    double value = 0.0;
    
    if (TLReadExactly(self, (uint8_t *)&value, 8) != 8)
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readDouble end of stream" userInfo:@{}];
    
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
    
    return value;
}

- (double)readDouble:(bool *)failed
{
    double value = 0.0;
    
    if (TLReadExactly(self, (uint8_t *)&value, 8) != 8)
    {
        *failed = true;
        return 0.0;
    }
    
#if __BYTE_ORDER == __LITTLE_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#   error "Big endian is not implemented"
#else
#   error "Unknown byte order"
#endif
    
    return value;
}

- (NSData *)readData:(int)length
{
    if (length < 0)
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readData invalid length" userInfo:@{}];
    if (length == 0)
        return [NSData data];
    uint8_t *bytes = (uint8_t *)malloc((size_t)length);
    if (bytes == NULL)
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readData allocation failed" userInfo:@{}];
    if (TLReadExactly(self, bytes, (NSUInteger)length) != length)
    {
        free(bytes);
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readData end of stream" userInfo:@{}];
    }
    return [[NSData alloc] initWithBytesNoCopy:bytes length:(NSUInteger)length freeWhenDone:true];
}

- (NSData *)readData:(int)length failed:(bool *)failed
{
    if (length < 0)
    {
        *failed = true;
        return nil;
    }
    if (length == 0)
        return [NSData data];
    uint8_t *bytes = (uint8_t *)malloc((size_t)length);
    if (bytes == NULL || TLReadExactly(self, bytes, (NSUInteger)length) != length)
    {
        if (bytes != NULL)
            free(bytes);
        *failed = true;
        return nil;
    }
    return [[NSData alloc] initWithBytesNoCopy:bytes length:(NSUInteger)length freeWhenDone:true];
}

- (NSMutableData *)readMutableData:(int)length
{
    if (length < 0)
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readMutableData invalid length" userInfo:@{}];
    if (length == 0)
        return [[NSMutableData alloc] init];
    uint8_t *bytes = (uint8_t *)malloc((size_t)length);
    if (bytes == NULL)
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readMutableData allocation failed" userInfo:@{}];
    if (TLReadExactly(self, bytes, (NSUInteger)length) != length)
    {
        free(bytes);
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readMutableData end of stream" userInfo:@{}];
    }
    return [[NSMutableData alloc] initWithBytesNoCopy:bytes length:(NSUInteger)length freeWhenDone:true];
}

- (NSMutableData *)readMutableData:(int)length failed:(bool *)failed
{
    if (length < 0)
    {
        *failed = true;
        return nil;
    }
    if (length == 0)
        return [[NSMutableData alloc] init];
    uint8_t *bytes = (uint8_t *)malloc((size_t)length);
    if (bytes == NULL || TLReadExactly(self, bytes, (NSUInteger)length) != length)
    {
        if (bytes != NULL)
            free(bytes);
        *failed = true;
        return nil;
    }
    return [[NSMutableData alloc] initWithBytesNoCopy:bytes length:(NSUInteger)length freeWhenDone:true];
}

- (NSString *)readString
{
    uint8_t tmp = 0;
    if (TLReadExactly(self, &tmp, 1) != 1)
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readString end of stream" userInfo:@{}];

    int paddingBytes = 0;
    int32_t length = tmp;
    if (length == 254)
    {
        length = 0;
        if (TLReadExactly(self, ((uint8_t *)&length) + 1, 3) != 3)
            @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readString length end of stream" userInfo:@{}];
        length >>= 8;
        paddingBytes = roundUpInput(length, 4) - length;
    }
    else
        paddingBytes = roundUpInput(length + 1, 4) - (length + 1);

    NSString *string = @"";
    if (length > 0)
    {
        uint8_t *bytes = (uint8_t *)malloc((size_t)length);
        if (bytes == NULL)
            @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readString allocation failed" userInfo:@{}];
        if (TLReadExactly(self, bytes, (NSUInteger)length) != length)
        {
            free(bytes);
            @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readString data end of stream" userInfo:@{}];
        }
        string = [[NSString alloc] initWithBytesNoCopy:bytes length:(NSUInteger)length encoding:NSUTF8StringEncoding freeWhenDone:true];
        if (string == nil)
            @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readString invalid UTF-8" userInfo:@{}];
    }

    for (int i = 0; i < paddingBytes; i++)
    {
        if (TLReadExactly(self, &tmp, 1) != 1)
            @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readString padding end of stream" userInfo:@{}];
    }
    return string;
}

- (NSString *)readString:(bool *)failed
{
    uint8_t tmp = 0;
    if (TLReadExactly(self, &tmp, 1) != 1)
    {
        *failed = true;
        return nil;
    }

    int paddingBytes = 0;
    int32_t length = tmp;
    if (length == 254)
    {
        length = 0;
        if (TLReadExactly(self, ((uint8_t *)&length) + 1, 3) != 3)
        {
            *failed = true;
            return nil;
        }
        length >>= 8;
        paddingBytes = roundUpInput(length, 4) - length;
    }
    else
        paddingBytes = roundUpInput(length + 1, 4) - (length + 1);

    NSString *string = @"";
    if (length > 0)
    {
        uint8_t *bytes = (uint8_t *)malloc((size_t)length);
        if (bytes == NULL || TLReadExactly(self, bytes, (NSUInteger)length) != length)
        {
            if (bytes != NULL)
                free(bytes);
            *failed = true;
            return nil;
        }
        string = [[NSString alloc] initWithBytesNoCopy:bytes length:(NSUInteger)length encoding:NSUTF8StringEncoding freeWhenDone:true];
        if (string == nil)
        {
            *failed = true;
            return nil;
        }
    }

    for (int i = 0; i < paddingBytes; i++)
    {
        if (TLReadExactly(self, &tmp, 1) != 1)
        {
            *failed = true;
            return nil;
        }
    }
    return string;
}

- (NSData *)readBytes
{
    uint8_t tmp = 0;
    if (TLReadExactly(self, &tmp, 1) != 1)
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readBytes end of stream" userInfo:@{}];

    int paddingBytes = 0;
    int32_t length = tmp;
    if (length == 254)
    {
        length = 0;
        if (TLReadExactly(self, ((uint8_t *)&length) + 1, 3) != 3)
            @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readBytes length end of stream" userInfo:@{}];
        length >>= 8;
        paddingBytes = roundUpInput(length, 4) - length;
    }
    else
        paddingBytes = roundUpInput(length + 1, 4) - (length + 1);

    uint8_t *bytes = length == 0 ? NULL : (uint8_t *)malloc((size_t)length);
    if (length != 0 && bytes == NULL)
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readBytes allocation failed" userInfo:@{}];
    if (length != 0 && TLReadExactly(self, bytes, (NSUInteger)length) != length)
    {
        free(bytes);
        @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readBytes data end of stream" userInfo:@{}];
    }

    NSData *result = length == 0 ? [NSData data] : [NSData dataWithBytesNoCopy:bytes length:(NSUInteger)length freeWhenDone:true];
    for (int i = 0; i < paddingBytes; i++)
    {
        if (TLReadExactly(self, &tmp, 1) != 1)
            @throw [[NSException alloc] initWithName:@"NSInputStream+TLException" reason:@"readBytes padding end of stream" userInfo:@{}];
    }
    return result;
}

- (NSData *)readBytes:(bool *)failed
{
    uint8_t tmp = 0;
    if (TLReadExactly(self, &tmp, 1) != 1)
    {
        *failed = true;
        return nil;
    }

    int paddingBytes = 0;
    int32_t length = tmp;
    if (length == 254)
    {
        length = 0;
        if (TLReadExactly(self, ((uint8_t *)&length) + 1, 3) != 3)
        {
            *failed = true;
            return nil;
        }
        length >>= 8;
        paddingBytes = roundUpInput(length, 4) - length;
    }
    else
        paddingBytes = roundUpInput(length + 1, 4) - (length + 1);

    uint8_t *bytes = length == 0 ? NULL : (uint8_t *)malloc((size_t)length);
    if (length != 0 && (bytes == NULL || TLReadExactly(self, bytes, (NSUInteger)length) != length))
    {
        if (bytes != NULL)
            free(bytes);
        *failed = true;
        return nil;
    }

    NSData *result = length == 0 ? [NSData data] : [NSData dataWithBytesNoCopy:bytes length:(NSUInteger)length freeWhenDone:true];
    for (int i = 0; i < paddingBytes; i++)
    {
        if (TLReadExactly(self, &tmp, 1) != 1)
        {
            *failed = true;
            return nil;
        }
    }
    return result;
}

@end
