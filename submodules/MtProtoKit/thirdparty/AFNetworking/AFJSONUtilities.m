// AFJSONUtilities.m
//
// Copyright (c) 2011 Gowalla (http://gowalla.com/)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFJSONUtilities.h"

#if ONEGRAM_ARMV6
#include <stdlib.h>
#include <string.h>

typedef struct
{
    const unsigned char *bytes;
    NSUInteger length;
    NSUInteger index;
    NSError **error;
} AFJSONLegacyParser;

static void AFJSONLegacySkipWhitespace(AFJSONLegacyParser *parser)
{
    while (parser->index < parser->length)
    {
        unsigned char c = parser->bytes[parser->index];
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n')
            parser->index++;
        else
            break;
    }
}

static id AFJSONLegacyFail(AFJSONLegacyParser *parser, NSString *message)
{
    if (parser->error != NULL)
    {
        *parser->error = [NSError errorWithDomain:@"AFJSONErrorDomain" code:1 userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
    }
    return nil;
}

static int AFJSONLegacyHex(unsigned char c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    return -1;
}

static BOOL AFJSONLegacyAppendUTF8(AFJSONLegacyParser *parser, NSMutableString *string, NSUInteger start, NSUInteger end)
{
    if (end <= start)
        return YES;
    NSString *part = [[[NSString alloc] initWithBytes:parser->bytes + start length:end - start encoding:NSUTF8StringEncoding] autorelease];
    if (part == nil)
    {
        AFJSONLegacyFail(parser, @"Invalid UTF-8 in JSON string");
        return NO;
    }
    [string appendString:part];
    return YES;
}

static BOOL AFJSONLegacyReadUnicode(AFJSONLegacyParser *parser, unichar *value)
{
    if (parser->index + 4 > parser->length)
        return NO;
    unsigned int result = 0;
    for (NSUInteger i = 0; i < 4; i++)
    {
        int digit = AFJSONLegacyHex(parser->bytes[parser->index++]);
        if (digit < 0)
            return NO;
        result = (result << 4) | (unsigned int)digit;
    }
    *value = (unichar)result;
    return YES;
}

static NSString *AFJSONLegacyParseString(AFJSONLegacyParser *parser)
{
    if (parser->index >= parser->length || parser->bytes[parser->index] != '"')
        return AFJSONLegacyFail(parser, @"Expected JSON string");
    parser->index++;
    NSUInteger segmentStart = parser->index;
    NSMutableString *result = [NSMutableString string];
    while (parser->index < parser->length)
    {
        unsigned char c = parser->bytes[parser->index];
        if (c == '"')
        {
            if (!AFJSONLegacyAppendUTF8(parser, result, segmentStart, parser->index))
                return nil;
            parser->index++;
            return result;
        }
        if (c < 0x20)
            return AFJSONLegacyFail(parser, @"Invalid control character in JSON string");
        if (c != '\\')
        {
            parser->index++;
            continue;
        }
        if (!AFJSONLegacyAppendUTF8(parser, result, segmentStart, parser->index))
            return nil;
        parser->index++;
        if (parser->index >= parser->length)
            return AFJSONLegacyFail(parser, @"Invalid JSON escape");
        unsigned char escaped = parser->bytes[parser->index++];
        switch (escaped)
        {
            case '"': [result appendString:@"\""]; break;
            case '\\': [result appendString:@"\\"]; break;
            case '/': [result appendString:@"/"]; break;
            case 'b': [result appendString:[NSString stringWithFormat:@"%C", (unichar)0x08]]; break;
            case 'f': [result appendString:[NSString stringWithFormat:@"%C", (unichar)0x0c]]; break;
            case 'n': [result appendString:@"\n"]; break;
            case 'r': [result appendString:@"\r"]; break;
            case 't': [result appendString:@"\t"]; break;
            case 'u':
            {
                unichar high = 0;
                if (!AFJSONLegacyReadUnicode(parser, &high))
                    return AFJSONLegacyFail(parser, @"Invalid JSON unicode escape");
                if (high >= 0xd800 && high <= 0xdbff)
                {
                    if (parser->index + 6 > parser->length || parser->bytes[parser->index] != '\\' || parser->bytes[parser->index + 1] != 'u')
                        return AFJSONLegacyFail(parser, @"Invalid JSON surrogate pair");
                    parser->index += 2;
                    unichar low = 0;
                    if (!AFJSONLegacyReadUnicode(parser, &low) || low < 0xdc00 || low > 0xdfff)
                        return AFJSONLegacyFail(parser, @"Invalid JSON surrogate pair");
                    unichar pair[2] = {high, low};
                    [result appendString:[NSString stringWithCharacters:pair length:2]];
                }
                else if (high >= 0xdc00 && high <= 0xdfff)
                {
                    return AFJSONLegacyFail(parser, @"Invalid JSON surrogate pair");
                }
                else
                {
                    [result appendString:[NSString stringWithCharacters:&high length:1]];
                }
                break;
            }
            default:
                return AFJSONLegacyFail(parser, @"Invalid JSON escape");
        }
        segmentStart = parser->index;
    }
    return AFJSONLegacyFail(parser, @"Unterminated JSON string");
}

static id AFJSONLegacyParseValue(AFJSONLegacyParser *parser);

static id AFJSONLegacyParseArray(AFJSONLegacyParser *parser)
{
    parser->index++;
    AFJSONLegacySkipWhitespace(parser);
    NSMutableArray *array = [NSMutableArray array];
    if (parser->index < parser->length && parser->bytes[parser->index] == ']')
    {
        parser->index++;
        return array;
    }
    while (parser->index < parser->length)
    {
        id value = AFJSONLegacyParseValue(parser);
        if (value == nil)
            return nil;
        [array addObject:value];
        AFJSONLegacySkipWhitespace(parser);
        if (parser->index >= parser->length)
            return AFJSONLegacyFail(parser, @"Unterminated JSON array");
        unsigned char c = parser->bytes[parser->index++];
        if (c == ']')
            return array;
        if (c != ',')
            return AFJSONLegacyFail(parser, @"Expected comma in JSON array");
        AFJSONLegacySkipWhitespace(parser);
    }
    return AFJSONLegacyFail(parser, @"Unterminated JSON array");
}

static id AFJSONLegacyParseObject(AFJSONLegacyParser *parser)
{
    parser->index++;
    AFJSONLegacySkipWhitespace(parser);
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    if (parser->index < parser->length && parser->bytes[parser->index] == '}')
    {
        parser->index++;
        return dictionary;
    }
    while (parser->index < parser->length)
    {
        NSString *key = AFJSONLegacyParseString(parser);
        if (key == nil)
            return nil;
        AFJSONLegacySkipWhitespace(parser);
        if (parser->index >= parser->length || parser->bytes[parser->index] != ':')
            return AFJSONLegacyFail(parser, @"Expected colon in JSON object");
        parser->index++;
        AFJSONLegacySkipWhitespace(parser);
        id value = AFJSONLegacyParseValue(parser);
        if (value == nil)
            return nil;
        [dictionary setObject:value forKey:key];
        AFJSONLegacySkipWhitespace(parser);
        if (parser->index >= parser->length)
            return AFJSONLegacyFail(parser, @"Unterminated JSON object");
        unsigned char c = parser->bytes[parser->index++];
        if (c == '}')
            return dictionary;
        if (c != ',')
            return AFJSONLegacyFail(parser, @"Expected comma in JSON object");
        AFJSONLegacySkipWhitespace(parser);
    }
    return AFJSONLegacyFail(parser, @"Unterminated JSON object");
}

static id AFJSONLegacyParseNumber(AFJSONLegacyParser *parser)
{
    NSUInteger start = parser->index;
    if (parser->index < parser->length && parser->bytes[parser->index] == '-')
        parser->index++;
    if (parser->index >= parser->length)
        return AFJSONLegacyFail(parser, @"Invalid JSON number");
    if (parser->bytes[parser->index] == '0')
    {
        parser->index++;
    }
    else
    {
        if (parser->bytes[parser->index] < '1' || parser->bytes[parser->index] > '9')
            return AFJSONLegacyFail(parser, @"Invalid JSON number");
        while (parser->index < parser->length && parser->bytes[parser->index] >= '0' && parser->bytes[parser->index] <= '9')
            parser->index++;
    }
    BOOL floating = NO;
    if (parser->index < parser->length && parser->bytes[parser->index] == '.')
    {
        floating = YES;
        parser->index++;
        NSUInteger fractionStart = parser->index;
        while (parser->index < parser->length && parser->bytes[parser->index] >= '0' && parser->bytes[parser->index] <= '9')
            parser->index++;
        if (fractionStart == parser->index)
            return AFJSONLegacyFail(parser, @"Invalid JSON number");
    }
    if (parser->index < parser->length && (parser->bytes[parser->index] == 'e' || parser->bytes[parser->index] == 'E'))
    {
        floating = YES;
        parser->index++;
        if (parser->index < parser->length && (parser->bytes[parser->index] == '+' || parser->bytes[parser->index] == '-'))
            parser->index++;
        NSUInteger exponentStart = parser->index;
        while (parser->index < parser->length && parser->bytes[parser->index] >= '0' && parser->bytes[parser->index] <= '9')
            parser->index++;
        if (exponentStart == parser->index)
            return AFJSONLegacyFail(parser, @"Invalid JSON number");
    }
    NSUInteger length = parser->index - start;
    char *buffer = malloc(length + 1);
    if (buffer == NULL)
        return AFJSONLegacyFail(parser, @"Out of memory while parsing JSON");
    memcpy(buffer, parser->bytes + start, length);
    buffer[length] = 0;
    NSNumber *number = floating ? [NSNumber numberWithDouble:strtod(buffer, NULL)] : [NSNumber numberWithLongLong:strtoll(buffer, NULL, 10)];
    free(buffer);
    return number;
}

static BOOL AFJSONLegacyConsume(AFJSONLegacyParser *parser, const char *literal)
{
    NSUInteger length = strlen(literal);
    if (parser->index + length > parser->length)
        return NO;
    if (memcmp(parser->bytes + parser->index, literal, length) != 0)
        return NO;
    parser->index += length;
    return YES;
}

static id AFJSONLegacyParseValue(AFJSONLegacyParser *parser)
{
    AFJSONLegacySkipWhitespace(parser);
    if (parser->index >= parser->length)
        return AFJSONLegacyFail(parser, @"Unexpected end of JSON");
    unsigned char c = parser->bytes[parser->index];
    if (c == '"')
        return AFJSONLegacyParseString(parser);
    if (c == '{')
        return AFJSONLegacyParseObject(parser);
    if (c == '[')
        return AFJSONLegacyParseArray(parser);
    if (c == '-' || (c >= '0' && c <= '9'))
        return AFJSONLegacyParseNumber(parser);
    if (c == 't' && AFJSONLegacyConsume(parser, "true"))
        return [NSNumber numberWithBool:YES];
    if (c == 'f' && AFJSONLegacyConsume(parser, "false"))
        return [NSNumber numberWithBool:NO];
    if (c == 'n' && AFJSONLegacyConsume(parser, "null"))
        return [NSNull null];
    return AFJSONLegacyFail(parser, @"Invalid JSON value");
}

static id AFJSONLegacyDecode(NSData *data, NSError **error)
{
    AFJSONLegacyParser parser;
    parser.bytes = [data bytes];
    parser.length = [data length];
    parser.index = 0;
    parser.error = error;
    if (error != NULL)
        *error = nil;
    id result = AFJSONLegacyParseValue(&parser);
    if (result == nil)
        return nil;
    AFJSONLegacySkipWhitespace(&parser);
    if (parser.index != parser.length)
        return AFJSONLegacyFail(&parser, @"Trailing data after JSON value");
    return result;
}
#endif

static Class AFJSONSerializationClass(void)
{
    Class serializationClass = NSClassFromString(@"NSJSONSerialization");
#if ONEGRAM_ARMV6
    if (serializationClass == Nil)
        serializationClass = [NSJSONSerialization class];
#endif
    return serializationClass;
}

NSData * AFJSONEncode(id object, NSError **error) {
    NSData *data = nil;
    
    SEL _JSONKitSelector = NSSelectorFromString(@"JSONDataWithOptions:error:"); 
    SEL _YAJLSelector = NSSelectorFromString(@"yajl_JSONString");
    
    id _SBJsonWriterClass = NSClassFromString(@"SBJsonWriter");
    SEL _SBJsonWriterSelector = NSSelectorFromString(@"dataWithObject:");
    
    id _NXJsonSerializerClass = NSClassFromString(@"NXJsonSerializer");
    SEL _NXJsonSerializerSelector = NSSelectorFromString(@"serialize:");

    id _NSJSONSerializationClass = AFJSONSerializationClass();
    SEL _NSJSONSerializationSelector = NSSelectorFromString(@"dataWithJSONObject:options:error:");
    
#ifdef _AFNETWORKING_PREFER_NSJSONSERIALIZATION_
    if (_NSJSONSerializationClass && [_NSJSONSerializationClass respondsToSelector:_NSJSONSerializationSelector]) {
        goto _af_nsjson_encode;
    }
#endif
    
    if (_JSONKitSelector && [object respondsToSelector:_JSONKitSelector]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:_JSONKitSelector]];
        invocation.target = object;
        invocation.selector = _JSONKitSelector;
        
        NSUInteger serializeOptionFlags = 0;
        [invocation setArgument:&serializeOptionFlags atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        if (error != NULL) {
            [invocation setArgument:error atIndex:3];
        }
        
        [invocation invoke];
        [invocation getReturnValue:&data];
    } else if (_SBJsonWriterClass && [_SBJsonWriterClass instancesRespondToSelector:_SBJsonWriterSelector]) {
        id writer = [[_SBJsonWriterClass alloc] init];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[writer methodSignatureForSelector:_SBJsonWriterSelector]];
        invocation.target = writer;
        invocation.selector = _SBJsonWriterSelector;
        
        [invocation setArgument:&object atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        
        [invocation invoke];
        [invocation getReturnValue:&data];
        [writer release];
    } else if (_YAJLSelector && [object respondsToSelector:_YAJLSelector]) {
        @try {
            NSString *JSONString = nil;
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:_YAJLSelector]];
            invocation.target = object;
            invocation.selector = _YAJLSelector;
            
            [invocation invoke];
            [invocation getReturnValue:&JSONString];
            
            data = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
        }
        @catch (NSException *exception) {
           *error = [[[NSError alloc] initWithDomain:NSStringFromClass([exception class]) code:0 userInfo:[exception userInfo]] autorelease];
        }
    } else if (_NXJsonSerializerClass && [_NXJsonSerializerClass respondsToSelector:_NXJsonSerializerSelector]) {
        NSString *JSONString = nil;
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_NXJsonSerializerClass methodSignatureForSelector:_NXJsonSerializerSelector]];
        invocation.target = _NXJsonSerializerClass;
        invocation.selector = _NXJsonSerializerSelector;
        
        [invocation setArgument:&object atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        
        [invocation invoke];
        [invocation getReturnValue:&JSONString];
        data = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
    } else if (_NSJSONSerializationClass && [_NSJSONSerializationClass respondsToSelector:_NSJSONSerializationSelector]) {
#ifdef _AFNETWORKING_PREFER_NSJSONSERIALIZATION_
    _af_nsjson_encode:;
#endif
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_NSJSONSerializationClass methodSignatureForSelector:_NSJSONSerializationSelector]];
        invocation.target = _NSJSONSerializationClass;
        invocation.selector = _NSJSONSerializationSelector;

        [invocation setArgument:&object atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        NSUInteger writeOptions = 0;
        [invocation setArgument:&writeOptions atIndex:3];
        if (error != NULL) {
            [invocation setArgument:error atIndex:4];
        }

        [invocation invoke];
        [invocation getReturnValue:&data];
    } else {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSLocalizedString(@"Please either target a platform that supports NSJSONSerialization or add one of the following libraries to your project: JSONKit, SBJSON, or YAJL", nil) forKey:NSLocalizedRecoverySuggestionErrorKey];
        [[NSException exceptionWithName:NSInternalInconsistencyException reason:NSLocalizedString(@"No JSON generation functionality available", nil) userInfo:userInfo] raise];
    }

    return data;
}

id AFJSONDecode(NSData *data, NSError **error) {    
    id JSON = nil;
    
    SEL _JSONKitSelector = NSSelectorFromString(@"objectFromJSONDataWithParseOptions:error:"); 
    SEL _YAJLSelector = NSSelectorFromString(@"yajl_JSONWithOptions:error:");
    
    id _SBJSONParserClass = NSClassFromString(@"SBJsonParser");
    SEL _SBJSONParserSelector = NSSelectorFromString(@"objectWithData:");

    id _NSJSONSerializationClass = AFJSONSerializationClass();
    SEL _NSJSONSerializationSelector = NSSelectorFromString(@"JSONObjectWithData:options:error:");
    
    id _NXJsonParserClass = NSClassFromString(@"NXJsonParser");
    SEL _NXJsonParserSelector = NSSelectorFromString(@"parseData:error:ignoreNulls:");

    
#ifdef _AFNETWORKING_PREFER_NSJSONSERIALIZATION_
    if (_NSJSONSerializationClass && [_NSJSONSerializationClass respondsToSelector:_NSJSONSerializationSelector]) {
        goto _af_nsjson_decode;
    }
#endif
    
    if (_JSONKitSelector && [data respondsToSelector:_JSONKitSelector]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[data methodSignatureForSelector:_JSONKitSelector]];
        invocation.target = data;
        invocation.selector = _JSONKitSelector;
        
        NSUInteger parseOptionFlags = 0;
        [invocation setArgument:&parseOptionFlags atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        if (error != NULL) {
            [invocation setArgument:&error atIndex:3];
        }
        
        [invocation invoke];
        [invocation getReturnValue:&JSON];
    } else if (_SBJSONParserClass && [_SBJSONParserClass instancesRespondToSelector:_SBJSONParserSelector]) {
        id parser = [[_SBJSONParserClass alloc] init];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[parser methodSignatureForSelector:_SBJSONParserSelector]];
        invocation.target = parser;
        invocation.selector = _SBJSONParserSelector;
        
        [invocation setArgument:&data atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation

        [invocation invoke];
        [invocation getReturnValue:&JSON];
        [parser release];
    } else if (_YAJLSelector && [data respondsToSelector:_YAJLSelector]) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[data methodSignatureForSelector:_YAJLSelector]];
        invocation.target = data;
        invocation.selector = _YAJLSelector;
        
        NSUInteger yajlParserOptions = 0;
        [invocation setArgument:&yajlParserOptions atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        if (error != NULL) {
            [invocation setArgument:&error atIndex:3];
        }
        
        [invocation invoke];
        [invocation getReturnValue:&JSON];
    } else if (_NXJsonParserClass && [_NXJsonParserClass respondsToSelector:_NXJsonParserSelector]) {
        NSNumber *nullOption = [NSNumber numberWithBool:YES];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_NXJsonParserClass methodSignatureForSelector:_NXJsonParserSelector]];
        invocation.target = _NXJsonParserClass;
        invocation.selector = _NXJsonParserSelector;
        
        [invocation setArgument:&data atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        if (error != NULL) {
            [invocation setArgument:&error atIndex:3];
        }
        [invocation setArgument:&nullOption atIndex:4];
        
        [invocation invoke];
        [invocation getReturnValue:&JSON];
    } else if (_NSJSONSerializationClass && [_NSJSONSerializationClass respondsToSelector:_NSJSONSerializationSelector]) {
#ifdef _AFNETWORKING_PREFER_NSJSONSERIALIZATION_
    _af_nsjson_decode:;
#endif
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[_NSJSONSerializationClass methodSignatureForSelector:_NSJSONSerializationSelector]];
        invocation.target = _NSJSONSerializationClass;
        invocation.selector = _NSJSONSerializationSelector;

        [invocation setArgument:&data atIndex:2]; // arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
        NSUInteger readOptions = 0;
        [invocation setArgument:&readOptions atIndex:3];
        if (error != NULL) {
            [invocation setArgument:&error atIndex:4];
        }

        [invocation invoke];
        [invocation getReturnValue:&JSON];
    } else {
#if ONEGRAM_ARMV6
        JSON = AFJSONLegacyDecode(data, error);
#else
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSLocalizedString(@"Please either target a platform that supports NSJSONSerialization or add one of the following libraries to your project: JSONKit, SBJSON, or YAJL", nil) forKey:NSLocalizedRecoverySuggestionErrorKey];
        [[NSException exceptionWithName:NSInternalInconsistencyException reason:NSLocalizedString(@"No JSON parsing functionality available", nil) userInfo:userInfo] raise];
#endif
    }
        
    return JSON;
}
