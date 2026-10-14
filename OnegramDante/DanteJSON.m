#import "OGDanteSupport.h"
#import "DanteJSON.h"
#include <string.h>

@interface DanteJSONParser : NSObject {
    NSString *_text;
    NSUInteger _index;
    NSUInteger _length;
    NSUInteger _depth;
    NSError *_error;
}
- (id)initWithData:(NSData *)data;
- (id)parse;
- (NSError *)error;
@end

@implementation DanteJSONParser

- (id)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        _text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        _length = [_text length];
    }
    return self;
}

- (void)dealloc {
    [_text release];
    [_error release];
    [super dealloc];
}

- (NSError *)error { return _error; }

- (void)setErrorText:(NSString *)text {
    if (_error) return;
    NSDictionary *info = [NSDictionary dictionaryWithObject:(text ? text : @"Invalid JSON") forKey:NSLocalizedDescriptionKey];
    _error = [[NSError errorWithDomain:@"DanteJSON" code:1 userInfo:info] retain];
}

- (void)skipSpace {
    while (_index < _length) {
        unichar c = [_text characterAtIndex:_index];
        if (c != ' ' && c != '\t' && c != '\r' && c != '\n') break;
        _index++;
    }
}

- (BOOL)consume:(unichar)c {
    [self skipSpace];
    if (_index >= _length || [_text characterAtIndex:_index] != c) return NO;
    _index++;
    return YES;
}

- (NSString *)parseString {
    [self skipSpace];
    if (_index >= _length || [_text characterAtIndex:_index] != '"') {
        [self setErrorText:@"Expected string"];
        return nil;
    }
    _index++;
    NSMutableString *out = [NSMutableString string];
    while (_index < _length) {
        unichar c = [_text characterAtIndex:_index++];
        if (c == '"') return out;
        if (c != '\\') {
            [out appendFormat:@"%C", c];
            continue;
        }
        if (_index >= _length) break;
        c = [_text characterAtIndex:_index++];
        switch (c) {
            case '"': [out appendString:@"\""]; break;
            case '\\': [out appendString:@"\\"]; break;
            case '/': [out appendString:@"/"]; break;
            case 'b': [out appendFormat:@"%C", (unichar)8]; break;
            case 'f': [out appendFormat:@"%C", (unichar)12]; break;
            case 'n': [out appendString:@"\n"]; break;
            case 'r': [out appendString:@"\r"]; break;
            case 't': [out appendString:@"\t"]; break;
            case 'u': {
                if (_index + 4 > _length) {
                    [self setErrorText:@"Invalid unicode escape"];
                    return nil;
                }
                unsigned value = 0;
                NSUInteger i;
                for (i = 0; i < 4; i++) {
                    unichar h = [_text characterAtIndex:_index++];
                    value <<= 4;
                    if (h >= '0' && h <= '9') value |= h - '0';
                    else if (h >= 'a' && h <= 'f') value |= h - 'a' + 10;
                    else if (h >= 'A' && h <= 'F') value |= h - 'A' + 10;
                    else {
                        [self setErrorText:@"Invalid unicode escape"];
                        return nil;
                    }
                }
                [out appendFormat:@"%C", (unichar)value];
                break;
            }
            default:
                [self setErrorText:@"Invalid escape"];
                return nil;
        }
    }
    [self setErrorText:@"Unterminated string"];
    return nil;
}

- (id)parseNumber {
    [self skipSpace];
    NSUInteger start = _index;
    if (_index < _length && [_text characterAtIndex:_index] == '-') _index++;
    while (_index < _length) {
        unichar c = [_text characterAtIndex:_index];
        if (c < '0' || c > '9') break;
        _index++;
    }
    if (_index < _length && [_text characterAtIndex:_index] == '.') {
        _index++;
        while (_index < _length) {
            unichar c = [_text characterAtIndex:_index];
            if (c < '0' || c > '9') break;
            _index++;
        }
    }
    if (_index < _length) {
        unichar c = [_text characterAtIndex:_index];
        if (c == 'e' || c == 'E') {
            _index++;
            if (_index < _length) {
                c = [_text characterAtIndex:_index];
                if (c == '+' || c == '-') _index++;
            }
            while (_index < _length) {
                c = [_text characterAtIndex:_index];
                if (c < '0' || c > '9') break;
                _index++;
            }
        }
    }
    if (_index == start) {
        [self setErrorText:@"Expected number"];
        return nil;
    }
    NSString *s = [_text substringWithRange:NSMakeRange(start, _index - start)];
    return [NSNumber numberWithDouble:[s doubleValue]];
}

- (id)parseValue {
    if (_depth >= 64) {
        [self setErrorText:@"JSON nesting limit exceeded"];
        return nil;
    }
    _depth++;
    id result = [self parseNode];
    _depth--;
    return result;
}

- (id)parseNode {
    [self skipSpace];
    if (_index >= _length) {
        [self setErrorText:@"Unexpected end of JSON"];
        return nil;
    }
    unichar c = [_text characterAtIndex:_index];
    if (c == '"') return [self parseString];
    if (c == '{') {
        _index++;
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [self skipSpace];
        if ([self consume:'}']) return dict;
        while (!_error) {
            NSString *key = [self parseString];
            if (!key || ![self consume:':']) {
                [self setErrorText:@"Expected ':'"];
                return nil;
            }
            id value = [self parseValue];
            if (!value) return nil;
            [dict setObject:value forKey:key];
            if ([self consume:'}']) return dict;
            if (![self consume:',']) {
                [self setErrorText:@"Expected ','"];
                return nil;
            }
        }
        return nil;
    }
    if (c == '[') {
        _index++;
        NSMutableArray *array = [NSMutableArray array];
        [self skipSpace];
        if ([self consume:']']) return array;
        while (!_error) {
            id value = [self parseValue];
            if (!value) return nil;
            [array addObject:value];
            if ([self consume:']']) return array;
            if (![self consume:',']) {
                [self setErrorText:@"Expected ','"];
                return nil;
            }
        }
        return nil;
    }
    if (_index + 4 <= _length && [[_text substringWithRange:NSMakeRange(_index, 4)] isEqualToString:@"true"]) {
        _index += 4;
        return [NSNumber numberWithBool:YES];
    }
    if (_index + 5 <= _length && [[_text substringWithRange:NSMakeRange(_index, 5)] isEqualToString:@"false"]) {
        _index += 5;
        return [NSNumber numberWithBool:NO];
    }
    if (_index + 4 <= _length && [[_text substringWithRange:NSMakeRange(_index, 4)] isEqualToString:@"null"]) {
        _index += 4;
        return [NSNull null];
    }
    return [self parseNumber];
}

- (id)parse {
    if (!_text) {
        [self setErrorText:@"Input is not UTF-8"];
        return nil;
    }
    id value = [self parseValue];
    [self skipSpace];
    if (value && _index != _length) {
        [self setErrorText:@"Trailing JSON data"];
        return nil;
    }
    return value;
}

@end

id DanteJSONObjectWithData(NSData *data, NSError **error) {
    DanteJSONParser *parser = [[DanteJSONParser alloc] initWithData:data];
    id value = [[parser parse] retain];
    NSError *parseError = [[parser error] retain];
    [parser release];
    if (error) *error = [parseError autorelease];
    else [parseError release];
    return [value autorelease];
}

static NSError *DanteJSONMakeError(NSString *message) {
    NSDictionary *info = [NSDictionary dictionaryWithObject:(message ? message : @"Invalid JSON object")
                                                       forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"DanteJSON" code:2 userInfo:info];
}

static BOOL DanteJSONAppendEscapedString(NSMutableString *out, NSString *value) {
    if (!out || !value) return NO;
    [out appendString:@"\""];
    NSUInteger length = [value length];
    NSUInteger i;
    for (i = 0; i < length; i++) {
        unichar c = [value characterAtIndex:i];
        switch (c) {
            case '"': [out appendString:@"\\\""]; break;
            case '\\': [out appendString:@"\\\\"]; break;
            case '\b': [out appendString:@"\\b"]; break;
            case '\f': [out appendString:@"\\f"]; break;
            case '\n': [out appendString:@"\\n"]; break;
            case '\r': [out appendString:@"\\r"]; break;
            case '\t': [out appendString:@"\\t"]; break;
            default:
                if (c < 0x20) [out appendFormat:@"\\u%04x", (unsigned)c];
                else [out appendFormat:@"%C", c];
                break;
        }
    }
    [out appendString:@"\""];
    return YES;
}

static BOOL DanteJSONAppendValue(NSMutableString *out, id object, NSError **error) {
    if (!object || object == [NSNull null]) {
        [out appendString:@"null"];
        return YES;
    }
    if ([object isKindOfClass:[NSString class]]) {
        return DanteJSONAppendEscapedString(out, object);
    }
    if ([object isKindOfClass:[NSNumber class]]) {
        const char *type = [(NSNumber *)object objCType];
        if (type && strcmp(type, @encode(BOOL)) == 0) {
            [out appendString:[(NSNumber *)object boolValue] ? @"true" : @"false"];
        } else {
            [out appendString:[(NSNumber *)object stringValue]];
        }
        return YES;
    }
    if ([object isKindOfClass:[NSArray class]]) {
        [out appendString:@"["];
        NSUInteger count = [(NSArray *)object count];
        NSUInteger i;
        for (i = 0; i < count; i++) {
            if (i != 0) [out appendString:@","];
            if (!DanteJSONAppendValue(out, [(NSArray *)object objectAtIndex:i], error)) return NO;
        }
        [out appendString:@"]"];
        return YES;
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        [out appendString:@"{"];
        NSArray *keys = [(NSDictionary *)object allKeys];
        NSUInteger count = [keys count];
        NSUInteger i;
        for (i = 0; i < count; i++) {
            id key = [keys objectAtIndex:i];
            if (![key isKindOfClass:[NSString class]]) {
                if (error) *error = DanteJSONMakeError(@"JSON dictionary key is not a string");
                return NO;
            }
            if (i != 0) [out appendString:@","];
            DanteJSONAppendEscapedString(out, key);
            [out appendString:@":"];
            if (!DanteJSONAppendValue(out, [(NSDictionary *)object objectForKey:key], error)) return NO;
        }
        [out appendString:@"}"];
        return YES;
    }
    if (error) *error = DanteJSONMakeError([NSString stringWithFormat:@"Unsupported JSON class: %@", NSStringFromClass([object class])]);
    return NO;
}

NSData *DanteJSONDataWithObject(id object, NSError **error) {
    NSMutableString *json = [NSMutableString string];
    NSError *localError = nil;
    if (!DanteJSONAppendValue(json, object, &localError)) {
        if (error) *error = localError;
        return nil;
    }
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (!data && error) *error = DanteJSONMakeError(@"Could not encode JSON as UTF-8");
    return data;
}
