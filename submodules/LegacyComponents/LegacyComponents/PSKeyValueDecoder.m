#import "PSKeyValueDecoder.h"

#import <objc/runtime.h>

@interface PSKeyValueDecoder ()
{
    NSData *_data;
 
@public
    uint8_t const *_currentPtr;
    uint8_t const *_begin;
    uint8_t const *_end;
    
    PSKeyValueDecoder *_tempCoder;
}

@end

static bool PSCanRead(uint8_t const *ptr, uint8_t const *end, NSUInteger length)
{
    return ptr != NULL && end != NULL && ptr <= end && length <= (NSUInteger)(end - ptr);
}

static bool PSReadLength(uint8_t const **currentPtr, uint8_t const *end, uint32_t *value)
{
    uint32_t result = 0;
    for (int i = 0; i < 5; i++)
    {
        if (!PSCanRead(*currentPtr, end, 1))
            return false;
        uint8_t byte = **currentPtr;
        (*currentPtr)++;
        if (i == 4 && (byte & 0xf0) != 0)
            return false;
        result |= ((uint32_t)(byte & 0x7f)) << (7 * i);
        if ((byte & 0x80) == 0)
        {
            if (value != NULL)
                *value = result;
            return true;
        }
    }
    return false;
}

static NSString *PSReadString(uint8_t const **currentPtr, uint8_t const *end)
{
    uint32_t length = 0;
    if (!PSReadLength(currentPtr, end, &length) || !PSCanRead(*currentPtr, end, length))
    {
        *currentPtr = end;
        return nil;
    }
    NSString *string = [[NSString alloc] initWithBytes:*currentPtr length:length encoding:NSUTF8StringEncoding];
    *currentPtr += length;
    return string;
}

static bool PSSkipLengthPrefixed(uint8_t const **currentPtr, uint8_t const *end)
{
    uint32_t length = 0;
    if (!PSReadLength(currentPtr, end, &length) || !PSCanRead(*currentPtr, end, length))
    {
        *currentPtr = end;
        return false;
    }
    *currentPtr += length;
    return true;
}

static bool PSReadInt32(uint8_t const **currentPtr, uint8_t const *end, int32_t *value)
{
    if (!PSCanRead(*currentPtr, end, 4))
    {
        *currentPtr = end;
        return false;
    }
    int32_t result = 0;
    memcpy(&result, *currentPtr, 4);
    *currentPtr += 4;
    if (value != NULL)
        *value = result;
    return true;
}

static bool PSReadUInt32(uint8_t const **currentPtr, uint8_t const *end, uint32_t *value)
{
    if (!PSCanRead(*currentPtr, end, 4))
    {
        *currentPtr = end;
        return false;
    }
    uint32_t result = 0;
    memcpy(&result, *currentPtr, 4);
    *currentPtr += 4;
    if (value != NULL)
        *value = result;
    return true;
}

static bool PSReadInt64(uint8_t const **currentPtr, uint8_t const *end, int64_t *value)
{
    if (!PSCanRead(*currentPtr, end, 8))
    {
        *currentPtr = end;
        return false;
    }
    int64_t result = 0;
    memcpy(&result, *currentPtr, 8);
    *currentPtr += 8;
    if (value != NULL)
        *value = result;
    return true;
}

static bool PSReadDouble(uint8_t const **currentPtr, uint8_t const *end, double *value)
{
    if (!PSCanRead(*currentPtr, end, 8))
    {
        *currentPtr = end;
        return false;
    }
    double result = 0.0;
    memcpy(&result, *currentPtr, 8);
    *currentPtr += 8;
    if (value != NULL)
        *value = result;
    return true;
}

static bool PSSkipBytes(uint8_t const **currentPtr, uint8_t const *end, NSUInteger length)
{
    if (!PSCanRead(*currentPtr, end, length))
    {
        *currentPtr = end;
        return false;
    }
    *currentPtr += length;
    return true;
}

static bool PSSkipSizedObject(uint8_t const **currentPtr, uint8_t const *end)
{
    uint32_t length = 0;
    if (!PSReadUInt32(currentPtr, end, &length) || !PSCanRead(*currentPtr, end, length))
    {
        *currentPtr = end;
        return false;
    }
    *currentPtr += length;
    return true;
}

static bool PSReadObject(uint8_t const **currentPtr, uint8_t const *end, PSKeyValueDecoder *tempCoder, id<PSCoding> *object)
{
    uint32_t objectLength = 0;
    if (!PSReadUInt32(currentPtr, end, &objectLength) || !PSCanRead(*currentPtr, end, objectLength))
    {
        *currentPtr = end;
        if (object != NULL)
            *object = nil;
        return false;
    }
    uint8_t const *objectEnd = *currentPtr + objectLength;
    const void *zero = memchr(*currentPtr, 0, (size_t)(objectEnd - *currentPtr));
    if (zero == NULL)
    {
        *currentPtr = objectEnd;
        if (object != NULL)
            *object = nil;
        return false;
    }
    const char *className = (const char *)*currentPtr;
    *currentPtr = (uint8_t const *)zero + 1;
    id<PSCoding> result = nil;
    Class<PSCoding> objectClass = objc_getClass(className);
    if (objectClass != nil)
    {
        tempCoder->_begin = *currentPtr;
        tempCoder->_end = objectEnd;
        tempCoder->_currentPtr = tempCoder->_begin;
        result = [(id<PSCoding>)[(id)objectClass alloc] initWithKeyValueCoder:tempCoder];
    }
    *currentPtr = objectEnd;
    if (object != NULL)
        *object = result;
    return true;
}

static NSArray *PSReadArray(uint8_t const **currentPtr, uint8_t const *end, PSKeyValueDecoder *tempCoder)
{
    uint32_t objectLength = 0;
    if (!PSReadUInt32(currentPtr, end, &objectLength) || !PSCanRead(*currentPtr, end, objectLength))
    {
        *currentPtr = end;
        return nil;
    }
    uint8_t const *objectEnd = *currentPtr + objectLength;
    uint32_t count = 0;
    if (!PSReadLength(currentPtr, objectEnd, &count))
    {
        *currentPtr = objectEnd;
        return nil;
    }
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:MIN((NSUInteger)count, (NSUInteger)1024)];
    for (uint32_t i = 0; i < count; i++)
    {
        if (*currentPtr >= objectEnd)
            break;
        id<PSCoding> value = nil;
        if (!PSReadObject(currentPtr, objectEnd, tempCoder, &value))
            break;
        if (value != nil)
            [array addObject:value];
    }
    *currentPtr = objectEnd;
    return array;
}

static NSDictionary *PSReadInt32Dictionary(uint8_t const **currentPtr, uint8_t const *end, PSKeyValueDecoder *tempCoder)
{
    uint32_t objectLength = 0;
    if (!PSReadUInt32(currentPtr, end, &objectLength) || !PSCanRead(*currentPtr, end, objectLength))
    {
        *currentPtr = end;
        return nil;
    }
    uint8_t const *objectEnd = *currentPtr + objectLength;
    uint32_t count = 0;
    if (!PSReadLength(currentPtr, objectEnd, &count))
    {
        *currentPtr = objectEnd;
        return nil;
    }
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:MIN((NSUInteger)count, (NSUInteger)1024)];
    for (uint32_t i = 0; i < count; i++)
    {
        int32_t key = 0;
        if (!PSReadInt32(currentPtr, objectEnd, &key))
            break;
        id<PSCoding> value = nil;
        if (!PSReadObject(currentPtr, objectEnd, tempCoder, &value))
            break;
        if (value != nil)
            dict[@(key)] = value;
    }
    *currentPtr = objectEnd;
    return dict;
}

static NSData *PSReadData(uint8_t const **currentPtr, uint8_t const *end)
{
    uint32_t length = 0;
    if (!PSReadLength(currentPtr, end, &length) || !PSCanRead(*currentPtr, end, length))
    {
        *currentPtr = end;
        return nil;
    }
    NSData *data = [[NSData alloc] initWithBytes:*currentPtr length:length];
    *currentPtr += length;
    return data;
}

static void PSReadBytes(uint8_t const **currentPtr, uint8_t const *end, uint8_t *value, NSUInteger maxLength)
{
    uint32_t length = 0;
    if (!PSReadLength(currentPtr, end, &length) || !PSCanRead(*currentPtr, end, length))
    {
        *currentPtr = end;
        return;
    }
    if (value != NULL && maxLength != 0)
        memcpy(value, *currentPtr, MIN(maxLength, (NSUInteger)length));
    *currentPtr += length;
}

static bool PSSkipValue(uint8_t fieldType, uint8_t const **currentPtr, uint8_t const *end)
{
    switch (fieldType)
    {
        case PSKeyValueCoderFieldTypeString:
        case PSKeyValueCoderFieldTypeData:
            return PSSkipLengthPrefixed(currentPtr, end);
        case PSKeyValueCoderFieldTypeInt32:
            return PSSkipBytes(currentPtr, end, 4);
        case PSKeyValueCoderFieldTypeInt64:
        case PSKeyValueCoderFieldTypeDouble:
            return PSSkipBytes(currentPtr, end, 8);
        case PSKeyValueCoderFieldTypeCustomClass:
        case PSKeyValueCoderFieldTypeArray:
        case PSKeyValueCoderFieldTypeInt32Dictionary:
            return PSSkipSizedObject(currentPtr, end);
        case PSKeyValueCoderFieldTypeInt32Array:
        {
            int32_t count = 0;
            if (!PSReadInt32(currentPtr, end, &count) || count < 0)
                return false;
            NSUInteger bytes = (NSUInteger)count * 4;
            if (count != 0 && bytes / 4 != (NSUInteger)count)
            {
                *currentPtr = end;
                return false;
            }
            return PSSkipBytes(currentPtr, end, bytes);
        }
        default:
            *currentPtr = end;
            return false;
    }
}

static bool PSSkipField(uint8_t const **currentPtr, uint8_t const *end)
{
    if (!PSCanRead(*currentPtr, end, 1))
    {
        *currentPtr = end;
        return false;
    }
    uint8_t fieldType = **currentPtr;
    (*currentPtr)++;
    return PSSkipValue(fieldType, currentPtr, end);
}

@implementation PSKeyValueDecoder

- (instancetype)init
{
    self = [super init];
    return self;
}

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self != nil)
        [self resetData:data];
    return self;
}

- (void)resetData:(NSData *)data
{
    _data = data;
    if (_data == nil || _data.length == 0)
    {
        _begin = NULL;
        _end = NULL;
    }
    else
    {
        _begin = (uint8_t const *)[_data bytes];
        _end = _begin + [_data length];
    }
    _currentPtr = _begin;
}

- (void)resetBytes:(uint8_t const *)bytes length:(NSUInteger)length
{
    _data = nil;
    _begin = bytes;
    _end = bytes == NULL ? NULL : bytes + length;
    _currentPtr = _begin;
}

- (void)rewind
{
    if (_data != nil)
        [self resetData:_data];
    else
        _currentPtr = _begin;
}

static bool PSSkipToValueForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (key == NULL || self->_begin == NULL || self->_end == NULL)
        return false;
    uint8_t const *middlePtr = self->_currentPtr;
    if (middlePtr < self->_begin || middlePtr > self->_end)
        middlePtr = self->_begin;
    for (int pass = 0; pass < 2; pass++)
    {
        uint8_t const *scanEnd = pass == 0 ? self->_end : middlePtr;
        if (pass == 1)
            self->_currentPtr = self->_begin;
        while (self->_currentPtr < scanEnd)
        {
            uint32_t compareKeyLength = 0;
            if (!PSReadLength(&self->_currentPtr, scanEnd, &compareKeyLength) || !PSCanRead(self->_currentPtr, scanEnd, compareKeyLength))
            {
                self->_currentPtr = scanEnd;
                break;
            }
            bool matches = compareKeyLength == keyLength && keyLength <= (NSUInteger)(scanEnd - self->_currentPtr) && memcmp(key, self->_currentPtr, keyLength) == 0;
            self->_currentPtr += compareKeyLength;
            if (matches)
                return PSCanRead(self->_currentPtr, scanEnd, 1);
            if (!PSSkipField(&self->_currentPtr, scanEnd))
                break;
        }
    }
    return false;
}

static NSString *PSDecodeString(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (!PSSkipToValueForRawKey(self, key, keyLength) || !PSCanRead(self->_currentPtr, self->_end, 1))
        return nil;
    uint8_t type = *self->_currentPtr++;
    if (type == PSKeyValueCoderFieldTypeString)
        return PSReadString(&self->_currentPtr, self->_end);
    if (type == PSKeyValueCoderFieldTypeInt32)
    {
        int32_t value = 0;
        return PSReadInt32(&self->_currentPtr, self->_end, &value) ? [[NSString alloc] initWithFormat:@"%" PRId32 "", value] : nil;
    }
    if (type == PSKeyValueCoderFieldTypeInt64)
    {
        int64_t value = 0;
        return PSReadInt64(&self->_currentPtr, self->_end, &value) ? [[NSString alloc] initWithFormat:@"%" PRId64 "", value] : nil;
    }
    PSSkipValue(type, &self->_currentPtr, self->_end);
    return nil;
}

- (NSString *)decodeStringForKey:(NSString *)key
{
    NSData *data = [key dataUsingEncoding:NSUTF8StringEncoding];
    return PSDecodeString(self, data.bytes, data.length);
}

- (NSString *)decodeStringForCKey:(const char *)key
{
    return PSDecodeString(self, (uint8_t const *)key, key == NULL ? 0 : strlen(key));
}

static int32_t PSDecodeInt32(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (!PSSkipToValueForRawKey(self, key, keyLength) || !PSCanRead(self->_currentPtr, self->_end, 1))
        return 0;
    uint8_t type = *self->_currentPtr++;
    if (type == PSKeyValueCoderFieldTypeInt32)
    {
        int32_t value = 0;
        return PSReadInt32(&self->_currentPtr, self->_end, &value) ? value : 0;
    }
    if (type == PSKeyValueCoderFieldTypeInt64)
    {
        int64_t value = 0;
        return PSReadInt64(&self->_currentPtr, self->_end, &value) ? (int32_t)value : 0;
    }
    if (type == PSKeyValueCoderFieldTypeString)
        return (int32_t)[PSReadString(&self->_currentPtr, self->_end) intValue];
    PSSkipValue(type, &self->_currentPtr, self->_end);
    return 0;
}

- (int32_t)decodeInt32ForKey:(NSString *)key
{
    NSData *data = [key dataUsingEncoding:NSUTF8StringEncoding];
    return PSDecodeInt32(self, data.bytes, data.length);
}

- (int32_t)decodeInt32ForCKey:(const char *)key
{
    return PSDecodeInt32(self, (uint8_t const *)key, key == NULL ? 0 : strlen(key));
}

static int64_t PSDecodeInt64(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (!PSSkipToValueForRawKey(self, key, keyLength) || !PSCanRead(self->_currentPtr, self->_end, 1))
        return 0;
    uint8_t type = *self->_currentPtr++;
    if (type == PSKeyValueCoderFieldTypeInt64)
    {
        int64_t value = 0;
        return PSReadInt64(&self->_currentPtr, self->_end, &value) ? value : 0;
    }
    if (type == PSKeyValueCoderFieldTypeInt32)
    {
        int32_t value = 0;
        return PSReadInt32(&self->_currentPtr, self->_end, &value) ? value : 0;
    }
    if (type == PSKeyValueCoderFieldTypeString)
        return [PSReadString(&self->_currentPtr, self->_end) longLongValue];
    PSSkipValue(type, &self->_currentPtr, self->_end);
    return 0;
}

- (int64_t)decodeInt64ForKey:(NSString *)key
{
    NSData *data = [key dataUsingEncoding:NSUTF8StringEncoding];
    return PSDecodeInt64(self, data.bytes, data.length);
}

- (int64_t)decodeInt64ForCKey:(const char *)key
{
    return PSDecodeInt64(self, (uint8_t const *)key, key == NULL ? 0 : strlen(key));
}

static id<PSCoding> PSDecodeObject(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (!PSSkipToValueForRawKey(self, key, keyLength) || !PSCanRead(self->_currentPtr, self->_end, 1))
        return nil;
    uint8_t type = *self->_currentPtr++;
    if (type != PSKeyValueCoderFieldTypeCustomClass)
    {
        PSSkipValue(type, &self->_currentPtr, self->_end);
        return nil;
    }
    if (self->_tempCoder == nil)
        self->_tempCoder = [[PSKeyValueDecoder alloc] init];
    id<PSCoding> object = nil;
    PSReadObject(&self->_currentPtr, self->_end, self->_tempCoder, &object);
    return object;
}

- (id<PSCoding>)decodeObjectForKey:(NSString *)key
{
    NSData *data = [key dataUsingEncoding:NSUTF8StringEncoding];
    return PSDecodeObject(self, data.bytes, data.length);
}

- (id<PSCoding>)decodeObjectForCKey:(const char *)key
{
    return PSDecodeObject(self, (uint8_t const *)key, key == NULL ? 0 : strlen(key));
}

static NSArray *PSDecodeArray(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (!PSSkipToValueForRawKey(self, key, keyLength) || !PSCanRead(self->_currentPtr, self->_end, 1))
        return nil;
    uint8_t type = *self->_currentPtr++;
    if (type != PSKeyValueCoderFieldTypeArray)
    {
        PSSkipValue(type, &self->_currentPtr, self->_end);
        return nil;
    }
    if (self->_tempCoder == nil)
        self->_tempCoder = [[PSKeyValueDecoder alloc] init];
    return PSReadArray(&self->_currentPtr, self->_end, self->_tempCoder);
}

- (NSArray *)decodeArrayForKey:(NSString *)key
{
    NSData *data = [key dataUsingEncoding:NSUTF8StringEncoding];
    return PSDecodeArray(self, data.bytes, data.length);
}

- (NSArray *)decodeArrayForCKey:(const char *)key
{
    return PSDecodeArray(self, (uint8_t const *)key, key == NULL ? 0 : strlen(key));
}

- (NSData *)decodeDataCorCKey:(const char *)key
{
    NSUInteger keyLength = key == NULL ? 0 : strlen(key);
    if (!PSSkipToValueForRawKey(self, (uint8_t const *)key, keyLength) || !PSCanRead(self->_currentPtr, self->_end, 1))
        return nil;
    uint8_t type = *self->_currentPtr++;
    if (type == PSKeyValueCoderFieldTypeData)
        return PSReadData(&self->_currentPtr, self->_end);
    PSSkipValue(type, &self->_currentPtr, self->_end);
    return nil;
}

- (void)decodeBytesForCKey:(const char *)key value:(uint8_t *)value length:(NSUInteger)length
{
    NSUInteger keyLength = key == NULL ? 0 : strlen(key);
    if (!PSSkipToValueForRawKey(self, (uint8_t const *)key, keyLength) || !PSCanRead(self->_currentPtr, self->_end, 1))
        return;
    uint8_t type = *self->_currentPtr++;
    if (type == PSKeyValueCoderFieldTypeData)
        PSReadBytes(&self->_currentPtr, self->_end, value, length);
    else
        PSSkipValue(type, &self->_currentPtr, self->_end);
}

- (NSDictionary *)decodeObjectsByKeys
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    if (_tempCoder == nil)
        _tempCoder = [[PSKeyValueDecoder alloc] init];
    _currentPtr = _begin;
    while (_currentPtr != NULL && _currentPtr < _end)
    {
        uint32_t keyLength = 0;
        if (!PSReadLength(&_currentPtr, _end, &keyLength) || !PSCanRead(_currentPtr, _end, keyLength))
            break;
        NSString *key = [[NSString alloc] initWithBytes:_currentPtr length:keyLength encoding:NSUTF8StringEncoding];
        _currentPtr += keyLength;
        if (key == nil || !PSCanRead(_currentPtr, _end, 1))
            break;
        uint8_t type = *_currentPtr++;
        if (type != PSKeyValueCoderFieldTypeCustomClass)
        {
            if (!PSSkipValue(type, &_currentPtr, _end))
                break;
            continue;
        }
        id<PSCoding> value = nil;
        if (!PSReadObject(&_currentPtr, _end, _tempCoder, &value))
            break;
        if (value != nil)
            dict[key] = value;
    }
    _currentPtr = _begin;
    return dict;
}

- (NSArray *)decodeInt32ArrayForCKey:(const char *)key
{
    NSUInteger keyLength = key == NULL ? 0 : strlen(key);
    if (!PSSkipToValueForRawKey(self, (uint8_t const *)key, keyLength) || !PSCanRead(_currentPtr, _end, 1))
        return nil;
    uint8_t type = *_currentPtr++;
    if (type != PSKeyValueCoderFieldTypeInt32Array)
    {
        PSSkipValue(type, &_currentPtr, _end);
        return nil;
    }
    int32_t count = 0;
    if (!PSReadInt32(&_currentPtr, _end, &count) || count < 0 || (NSUInteger)count > (NSUInteger)(_end - _currentPtr) / 4)
    {
        _currentPtr = _end;
        return nil;
    }
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)count];
    for (int32_t i = 0; i < count; i++)
    {
        int32_t value = 0;
        if (!PSReadInt32(&_currentPtr, _end, &value))
            return nil;
        [array addObject:@(value)];
    }
    return array;
}

- (NSDictionary *)decodeInt32DictionaryForCKey:(const char *)key
{
    NSUInteger keyLength = key == NULL ? 0 : strlen(key);
    if (!PSSkipToValueForRawKey(self, (uint8_t const *)key, keyLength) || !PSCanRead(_currentPtr, _end, 1))
        return nil;
    uint8_t type = *_currentPtr++;
    if (type != PSKeyValueCoderFieldTypeInt32Dictionary)
    {
        PSSkipValue(type, &_currentPtr, _end);
        return nil;
    }
    if (_tempCoder == nil)
        _tempCoder = [[PSKeyValueDecoder alloc] init];
    return PSReadInt32Dictionary(&_currentPtr, _end, _tempCoder);
}

- (double)decodeDoubleForCKey:(const char *)key
{
    NSUInteger keyLength = key == NULL ? 0 : strlen(key);
    if (!PSSkipToValueForRawKey(self, (uint8_t const *)key, keyLength) || !PSCanRead(_currentPtr, _end, 1))
        return 0.0;
    uint8_t type = *_currentPtr++;
    if (type == PSKeyValueCoderFieldTypeDouble)
    {
        double value = 0.0;
        return PSReadDouble(&_currentPtr, _end, &value) ? value : 0.0;
    }
    if (type == PSKeyValueCoderFieldTypeInt32)
    {
        int32_t value = 0;
        return PSReadInt32(&_currentPtr, _end, &value) ? value : 0.0;
    }
    if (type == PSKeyValueCoderFieldTypeInt64)
    {
        int64_t value = 0;
        return PSReadInt64(&_currentPtr, _end, &value) ? (double)value : 0.0;
    }
    if (type == PSKeyValueCoderFieldTypeString)
        return [PSReadString(&_currentPtr, _end) doubleValue];
    PSSkipValue(type, &_currentPtr, _end);
    return 0.0;
}

@end
