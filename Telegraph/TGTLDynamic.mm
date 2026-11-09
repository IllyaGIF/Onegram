#import "TGTLDynamic.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TL/TLMetaSchemeData.h"
#import "TLMetaClassStore.h"
#import "NSInputStream+TL.h"
#import "NSOutputStream+TL.h"
#import "NSData+GZip.h"
#import "TGTelegramNetworking.h"

#include <map>
#include <string>
#include <pthread.h>

NSString *const TGTLDynamicErrorDomain = @"TGTLDynamic";

static const int32_t TGTLDynamicVectorSignature = (int32_t)0x1cb5c415;
static const int32_t TGTLDynamicGzipPackedSignature = (int32_t)0x3072cfa1;
static const NSUInteger TGTLDynamicMaxVectorCount = 1000000;

@interface TGTLDynamicEntry : NSObject
{
@public
    int32_t _signature;
    NSString *_name;
    NSString *_type;
    NSArray *_paramNames;
    NSArray *_paramTypes;
    NSSet *_flagsParamNames;
}

@end

@implementation TGTLDynamicEntry

@end

@interface TGTLDynamicScheme : NSObject
{
    const TLMetaSchemeTable *_table;
    std::map<int32_t, uint32_t> _typeIndexBySignature;
    std::map<std::string, uint32_t> _typeIndexByName;
    std::map<std::string, uint32_t> _methodIndexByName;
    std::map<std::string, uint32_t> _singleConstructorIndexByTypeName;
    NSMutableDictionary *_typeEntries;
    NSMutableDictionary *_methodEntries;
    pthread_mutex_t _mutex;
}

+ (TGTLDynamicScheme *)sharedScheme;

- (TGTLDynamicEntry *)typeWithSignature:(int32_t)signature;
- (TGTLDynamicEntry *)typeNamed:(NSString *)name;
- (TGTLDynamicEntry *)methodNamed:(NSString *)name;
- (TGTLDynamicEntry *)singleConstructorForType:(NSString *)typeName;

@end

static bool TGTLDynamicParseCondition(NSString *type, NSString **flagsName, int *bit, NSString **innerType);

static TGTLDynamicScheme *TGTLDynamicSharedSchemeInstance = nil;

static void TGTLDynamicCreateSharedScheme(void)
{
    TGTLDynamicSharedSchemeInstance = [[TGTLDynamicScheme alloc] init];
}

@implementation TGTLDynamicScheme

+ (TGTLDynamicScheme *)sharedScheme
{
    static pthread_once_t onceToken = PTHREAD_ONCE_INIT;
    pthread_once(&onceToken, TGTLDynamicCreateSharedScheme);
    return TGTLDynamicSharedSchemeInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_mutex, NULL);
        _table = TLgetMetaSchemeTable();
        _typeEntries = [[NSMutableDictionary alloc] init];
        _methodEntries = [[NSMutableDictionary alloc] init];

        std::map<std::string, uint32_t> constructorCountByTypeName;
        for (uint32_t i = 0; i < _table->typesCount; i++)
        {
            const TLMetaSchemeEntry *entry = &_table->types[i];
            _typeIndexBySignature[entry->signature] = i;
            _typeIndexByName[std::string(_table->strings + entry->name)] = i;
            std::string typeName(_table->strings + entry->type);
            constructorCountByTypeName[typeName]++;
            _singleConstructorIndexByTypeName[typeName] = i;
        }
        for (std::map<std::string, uint32_t>::iterator it = constructorCountByTypeName.begin(); it != constructorCountByTypeName.end(); it++)
        {
            if (it->second != 1)
                _singleConstructorIndexByTypeName.erase(it->first);
        }
        for (uint32_t i = 0; i < _table->methodsCount; i++)
        {
            const TLMetaSchemeEntry *entry = &_table->methods[i];
            _methodIndexByName[std::string(_table->strings + entry->name)] = i;
        }
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
}

- (TGTLDynamicEntry *)entryFromSchemeEntry:(const TLMetaSchemeEntry *)schemeEntry
{
    TGTLDynamicEntry *entry = [[TGTLDynamicEntry alloc] init];
    entry->_signature = schemeEntry->signature;
    entry->_name = [[NSString alloc] initWithUTF8String:_table->strings + schemeEntry->name];
    entry->_type = [[NSString alloc] initWithUTF8String:_table->strings + schemeEntry->type];
    NSMutableArray *paramNames = [[NSMutableArray alloc] initWithCapacity:schemeEntry->paramsCount];
    NSMutableArray *paramTypes = [[NSMutableArray alloc] initWithCapacity:schemeEntry->paramsCount];
    NSMutableSet *flagsParamNames = [[NSMutableSet alloc] init];
    for (uint32_t i = 0; i < schemeEntry->paramsCount; i++)
    {
        const TLMetaSchemeParamEntry *param = &_table->params[schemeEntry->paramsOffset + i];
        NSString *paramType = [[NSString alloc] initWithUTF8String:_table->strings + param->type];
        [paramNames addObject:[[NSString alloc] initWithUTF8String:_table->strings + param->name]];
        [paramTypes addObject:paramType];
        NSString *flagsName = nil;
        int bit = 0;
        NSString *innerType = nil;
        if (TGTLDynamicParseCondition(paramType, &flagsName, &bit, &innerType))
            [flagsParamNames addObject:flagsName];
    }
    entry->_paramNames = paramNames;
    entry->_paramTypes = paramTypes;
    entry->_flagsParamNames = flagsParamNames;
    return entry;
}

- (TGTLDynamicEntry *)typeEntryAtIndex:(uint32_t)index
{
    NSNumber *key = [[NSNumber alloc] initWithUnsignedInt:index];
    pthread_mutex_lock(&_mutex);
    TGTLDynamicEntry *entry = [_typeEntries objectForKey:key];
    if (entry == nil)
    {
        entry = [self entryFromSchemeEntry:&_table->types[index]];
        [_typeEntries setObject:entry forKey:key];
    }
    pthread_mutex_unlock(&_mutex);
    return entry;
}

- (TGTLDynamicEntry *)typeWithSignature:(int32_t)signature
{
    std::map<int32_t, uint32_t>::iterator it = _typeIndexBySignature.find(signature);
    if (it == _typeIndexBySignature.end())
        return nil;
    return [self typeEntryAtIndex:it->second];
}

- (TGTLDynamicEntry *)typeNamed:(NSString *)name
{
    if (name.length == 0)
        return nil;
    std::map<std::string, uint32_t>::iterator it = _typeIndexByName.find(std::string([name UTF8String]));
    if (it == _typeIndexByName.end())
        return nil;
    return [self typeEntryAtIndex:it->second];
}

- (TGTLDynamicEntry *)singleConstructorForType:(NSString *)typeName
{
    if (typeName.length == 0)
        return nil;
    std::map<std::string, uint32_t>::iterator it = _singleConstructorIndexByTypeName.find(std::string([typeName UTF8String]));
    if (it == _singleConstructorIndexByTypeName.end())
        return nil;
    return [self typeEntryAtIndex:it->second];
}

- (TGTLDynamicEntry *)methodNamed:(NSString *)name
{
    if (name.length == 0)
        return nil;
    pthread_mutex_lock(&_mutex);
    TGTLDynamicEntry *entry = [_methodEntries objectForKey:name];
    if (entry == nil)
    {
        std::map<std::string, uint32_t>::iterator it = _methodIndexByName.find(std::string([name UTF8String]));
        if (it != _methodIndexByName.end())
        {
            entry = [self entryFromSchemeEntry:&_table->methods[it->second]];
            [_methodEntries setObject:entry forKey:name];
        }
    }
    pthread_mutex_unlock(&_mutex);
    return entry;
}

@end

@implementation TGTLDynamicObject

+ (instancetype)objectWithConstructor:(NSString *)constructor fields:(NSDictionary *)fields
{
    return [[self alloc] initWithConstructor:constructor fields:fields];
}

- (instancetype)initWithConstructor:(NSString *)constructor fields:(NSDictionary *)fields
{
    self = [super init];
    if (self != nil)
    {
        _constructor = constructor;
        _fields = fields == nil ? @{} : fields;
    }
    return self;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"(%@ %@)", _constructor, _fields];
}

- (bool)isConstructor:(NSString *)constructor
{
    return [_constructor isEqualToString:constructor];
}

- (id)field:(NSString *)name
{
    id value = [_fields objectForKey:name];
    return value == [NSNull null] ? nil : value;
}

- (bool)flag:(NSString *)name
{
    id value = [self field:name];
    return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
}

- (int32_t)int32Field:(NSString *)name
{
    id value = [self field:name];
    return [value respondsToSelector:@selector(intValue)] ? [value intValue] : 0;
}

- (int64_t)int64Field:(NSString *)name
{
    id value = [self field:name];
    return [value respondsToSelector:@selector(longLongValue)] ? [value longLongValue] : 0;
}

- (double)doubleField:(NSString *)name
{
    id value = [self field:name];
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0.0;
}

- (NSString *)stringField:(NSString *)name
{
    id value = [self field:name];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

- (NSData *)dataField:(NSString *)name
{
    id value = [self field:name];
    return [value isKindOfClass:[NSData class]] ? value : nil;
}

- (NSArray *)arrayField:(NSString *)name
{
    id value = [self field:name];
    return [value isKindOfClass:[NSArray class]] ? value : nil;
}

- (TGTLDynamicObject *)objectField:(NSString *)name
{
    id value = [self field:name];
    return [value isKindOfClass:[TGTLDynamicObject class]] ? value : nil;
}

@end

static NSError *TGTLDynamicError(NSString *format, ...) __attribute__((format(__NSString__, 1, 2)));

static NSError *TGTLDynamicError(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *description = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    return [[NSError alloc] initWithDomain:TGTLDynamicErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: description}];
}

static NSSet *TGTLDynamicDefaultNativeTypes(void)
{
    static NSSet *nativeTypes = nil;
    static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&mutex);
    if (nativeTypes == nil)
        nativeTypes = [[NSSet alloc] initWithObjects:@"User", @"Chat", @"Document", @"Photo", nil];
    NSSet *result = nativeTypes;
    pthread_mutex_unlock(&mutex);
    return result;
}

struct TGTLDynamicTypePolicy
{
    __unsafe_unretained NSSet *nativeTypes;
    __unsafe_unretained NSSet *dynamicTypes;

    bool decodesNatively(NSString *typeName) const
    {
        if (dynamicTypes != nil)
            return ![dynamicTypes containsObject:typeName];
        return [nativeTypes containsObject:typeName];
    }
};

static bool TGTLDynamicParseCondition(NSString *type, NSString **flagsName, int *bit, NSString **innerType)
{
    NSRange questionRange = [type rangeOfString:@"?"];
    if (questionRange.location == NSNotFound)
        return false;
    NSString *condition = [type substringToIndex:questionRange.location];
    NSRange dotRange = [condition rangeOfString:@"." options:NSBackwardsSearch];
    if (dotRange.location == NSNotFound)
        return false;
    *flagsName = [condition substringToIndex:dotRange.location];
    *bit = [[condition substringFromIndex:dotRange.location + 1] intValue];
    *innerType = [type substringFromIndex:questionRange.location + 1];
    return true;
}

static NSString *TGTLDynamicGenericArgument(NSString *type, NSString *prefix)
{
    if (![type hasPrefix:prefix] || ![type hasSuffix:@">"])
        return nil;
    return [type substringWithRange:NSMakeRange(prefix.length, type.length - prefix.length - 1)];
}

static bool TGTLDynamicIsBareConstructorName(NSString *type)
{
    if (type.length == 0)
        return false;
    NSRange dotRange = [type rangeOfString:@"." options:NSBackwardsSearch];
    NSUInteger nameIndex = dotRange.location == NSNotFound ? 0 : dotRange.location + 1;
    if (nameIndex >= type.length)
        return false;
    unichar character = [type characterAtIndex:nameIndex];
    return character >= 'a' && character <= 'z';
}

static id TGTLDynamicDecodeValue(NSInputStream *is, NSString *type, const TGTLDynamicTypePolicy &policy, __autoreleasing NSError **error);
static id TGTLDynamicDecodeBoxed(NSInputStream *is, int32_t signature, NSString *typeName, const TGTLDynamicTypePolicy &policy, __autoreleasing NSError **error);

static TGTLDynamicObject *TGTLDynamicDecodeFields(NSInputStream *is, TGTLDynamicEntry *entry, const TGTLDynamicTypePolicy &policy, __autoreleasing NSError **error)
{
    NSMutableDictionary *fields = [[NSMutableDictionary alloc] initWithCapacity:entry->_paramNames.count];
    NSUInteger count = entry->_paramNames.count;
    for (NSUInteger i = 0; i < count; i++)
    {
        NSString *name = [entry->_paramNames objectAtIndex:i];
        NSString *type = [entry->_paramTypes objectAtIndex:i];

        NSString *flagsName = nil;
        int bit = 0;
        NSString *innerType = nil;
        if (TGTLDynamicParseCondition(type, &flagsName, &bit, &innerType))
        {
            int32_t flags = [[fields objectForKey:flagsName] intValue];
            if ((flags & (1 << bit)) == 0)
                continue;
            if ([innerType isEqualToString:@"true"])
            {
                [fields setObject:@true forKey:name];
                continue;
            }
            type = innerType;
        }

        id value = TGTLDynamicDecodeValue(is, type, policy, error);
        if (error != NULL && *error != nil)
        {
            *error = TGTLDynamicError(@"%@.%@: %@", entry->_name, name, (*error).localizedDescription);
            return nil;
        }
        if (value != nil)
            [fields setObject:value forKey:name];
    }
    return [[TGTLDynamicObject alloc] initWithConstructor:entry->_name fields:fields];
}

static NSArray *TGTLDynamicDecodeVectorItems(NSInputStream *is, NSString *itemType, const TGTLDynamicTypePolicy &policy, __autoreleasing NSError **error)
{
    bool failed = false;
    int32_t count = [is readInt32:&failed];
    if (failed || count < 0 || (NSUInteger)count > TGTLDynamicMaxVectorCount)
    {
        if (error != NULL)
            *error = TGTLDynamicError(@"invalid vector count %d", count);
        return nil;
    }
    NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)count];
    for (int32_t i = 0; i < count; i++)
    {
        id item = TGTLDynamicDecodeValue(is, itemType, policy, error);
        if (error != NULL && *error != nil)
            return nil;
        [items addObject:item == nil ? [NSNull null] : item];
    }
    return items;
}

static id TGTLDynamicDecodeValue(NSInputStream *is, NSString *type, const TGTLDynamicTypePolicy &policy, __autoreleasing NSError **error)
{
    bool failed = false;
    id result = nil;
    if ([type isEqualToString:@"int"] || [type isEqualToString:@"#"])
        result = [[NSNumber alloc] initWithInt:[is readInt32:&failed]];
    else if ([type isEqualToString:@"long"])
        result = [[NSNumber alloc] initWithLongLong:[is readInt64:&failed]];
    else if ([type isEqualToString:@"double"])
        result = [[NSNumber alloc] initWithDouble:[is readDouble:&failed]];
    else if ([type isEqualToString:@"string"])
        result = [is readString:&failed];
    else if ([type isEqualToString:@"bytes"])
        result = [is readBytes:&failed];
    else if ([type isEqualToString:@"int128"])
        result = [is readData:16 failed:&failed];
    else if ([type isEqualToString:@"int256"])
        result = [is readData:32 failed:&failed];
    else if ([type isEqualToString:@"true"])
        return @true;
    else
    {
        NSString *boxedItemType = TGTLDynamicGenericArgument(type, @"Vector<");
        NSString *bareItemType = boxedItemType == nil ? TGTLDynamicGenericArgument(type, @"vector<") : nil;
        if (boxedItemType != nil)
        {
            int32_t signature = [is readInt32:&failed];
            if (failed || signature != TGTLDynamicVectorSignature)
            {
                if (error != NULL)
                    *error = TGTLDynamicError(@"expected vector, got 0x%08x", signature);
                return nil;
            }
            return TGTLDynamicDecodeVectorItems(is, boxedItemType, policy, error);
        }
        if (bareItemType != nil)
            return TGTLDynamicDecodeVectorItems(is, bareItemType, policy, error);
        if ([type hasPrefix:@"%"])
        {
            NSString *typeName = [type substringFromIndex:1];
            TGTLDynamicEntry *entry = [[TGTLDynamicScheme sharedScheme] singleConstructorForType:typeName];
            if (entry == nil)
                entry = [[TGTLDynamicScheme sharedScheme] typeNamed:typeName];
            if (entry == nil)
            {
                if (error != NULL)
                    *error = TGTLDynamicError(@"unknown bare type %@", typeName);
                return nil;
            }
            return TGTLDynamicDecodeFields(is, entry, policy, error);
        }
        if (TGTLDynamicIsBareConstructorName(type))
        {
            TGTLDynamicEntry *entry = [[TGTLDynamicScheme sharedScheme] typeNamed:type];
            if (entry == nil)
            {
                if (error != NULL)
                    *error = TGTLDynamicError(@"unknown bare constructor %@", type);
                return nil;
            }
            return TGTLDynamicDecodeFields(is, entry, policy, error);
        }
        int32_t signature = [is readInt32:&failed];
        if (failed)
        {
            if (error != NULL)
                *error = TGTLDynamicError(@"unexpected end of stream reading %@", type);
            return nil;
        }
        return TGTLDynamicDecodeBoxed(is, signature, type, policy, error);
    }

    if (failed)
    {
        if (error != NULL)
            *error = TGTLDynamicError(@"unexpected end of stream reading %@", type);
        return nil;
    }
    return result;
}

static id TGTLDynamicDecodeBoxed(NSInputStream *is, int32_t signature, NSString *typeName, const TGTLDynamicTypePolicy &policy, __autoreleasing NSError **error)
{
    if (signature == TGTLDynamicGzipPackedSignature)
    {
        bool failed = false;
        NSData *packedData = [is readBytes:&failed];
        NSData *unpackedData = failed ? nil : [packedData decompressGZip];
        if (unpackedData.length < 4)
        {
            if (error != NULL)
                *error = TGTLDynamicError(@"cannot unpack gzip_packed %@", typeName);
            return nil;
        }
        NSInputStream *unpackedStream = [[NSInputStream alloc] initWithData:unpackedData];
        [unpackedStream open];
        int32_t unpackedSignature = [unpackedStream readInt32:&failed];
        id result = failed ? nil : TGTLDynamicDecodeBoxed(unpackedStream, unpackedSignature, typeName, policy, error);
        [unpackedStream close];
        return result;
    }

    if ([typeName isEqualToString:@"Bool"])
    {
        if (signature == TL_BOOL_TRUE_CONSTRUCTOR)
            return @true;
        if (signature == TL_BOOL_FALSE_CONSTRUCTOR)
            return @false;
        if (error != NULL)
            *error = TGTLDynamicError(@"expected Bool, got 0x%08x", signature);
        return nil;
    }

    NSString *vectorItemType = TGTLDynamicGenericArgument(typeName, @"Vector<");
    if (vectorItemType != nil)
    {
        if (signature != TGTLDynamicVectorSignature)
        {
            if (error != NULL)
                *error = TGTLDynamicError(@"expected vector, got 0x%08x", signature);
            return nil;
        }
        return TGTLDynamicDecodeVectorItems(is, vectorItemType, policy, error);
    }

    if (policy.decodesNatively(typeName))
    {
        __autoreleasing NSError *nativeError = nil;
        id object = TLMetaClassStore::constructObject(is, signature, nil, nil, &nativeError);
        if (nativeError != nil)
        {
            if (error != NULL)
                *error = TGTLDynamicError(@"%@ 0x%08x: %@", typeName, signature, nativeError.localizedDescription);
            return nil;
        }
        return object;
    }

    TGTLDynamicEntry *entry = [[TGTLDynamicScheme sharedScheme] typeWithSignature:signature];
    if (entry == nil)
    {
        if (error != NULL)
            *error = TGTLDynamicError(@"unknown constructor 0x%08x for %@", signature, typeName);
        return nil;
    }
    return TGTLDynamicDecodeFields(is, entry, policy, error);
}

static bool TGTLDynamicEncodeValue(NSOutputStream *os, NSString *type, id value, __autoreleasing NSError **error);

static bool TGTLDynamicValueIsPresent(id value, NSString *innerType)
{
    if (value == nil || value == [NSNull null])
        return false;
    if ([innerType isEqualToString:@"true"])
        return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
    return true;
}

static bool TGTLDynamicEncodeFields(NSOutputStream *os, TGTLDynamicEntry *entry, NSDictionary *values, __autoreleasing NSError **error)
{
    NSUInteger count = entry->_paramNames.count;
    NSMutableDictionary *flagsValues = [[NSMutableDictionary alloc] init];
    for (NSUInteger i = 0; i < count; i++)
    {
        NSString *flagsName = nil;
        int bit = 0;
        NSString *innerType = nil;
        if (!TGTLDynamicParseCondition([entry->_paramTypes objectAtIndex:i], &flagsName, &bit, &innerType))
            continue;
        int32_t flags = [[flagsValues objectForKey:flagsName] intValue];
        if (TGTLDynamicValueIsPresent([values objectForKey:[entry->_paramNames objectAtIndex:i]], innerType))
            flags |= (1 << bit);
        [flagsValues setObject:[[NSNumber alloc] initWithInt:flags] forKey:flagsName];
    }

    for (NSUInteger i = 0; i < count; i++)
    {
        NSString *name = [entry->_paramNames objectAtIndex:i];
        NSString *type = [entry->_paramTypes objectAtIndex:i];
        id value = [values objectForKey:name];

        if ([type isEqualToString:@"#"] || [entry->_flagsParamNames containsObject:name])
        {
            int32_t flags = [[flagsValues objectForKey:name] intValue] | [value intValue];
            [os writeInt32:flags];
            continue;
        }

        NSString *flagsName = nil;
        int bit = 0;
        NSString *innerType = nil;
        if (TGTLDynamicParseCondition(type, &flagsName, &bit, &innerType))
        {
            if (!TGTLDynamicValueIsPresent(value, innerType) || [innerType isEqualToString:@"true"])
                continue;
            type = innerType;
        }
        else if (value == nil || value == [NSNull null])
        {
            if (error != NULL)
                *error = TGTLDynamicError(@"%@: missing required parameter %@", entry->_name, name);
            return false;
        }

        if (!TGTLDynamicEncodeValue(os, type, value, error))
        {
            if (error != NULL && *error != nil)
                *error = TGTLDynamicError(@"%@.%@: %@", entry->_name, name, (*error).localizedDescription);
            return false;
        }
    }
    return true;
}

static bool TGTLDynamicEncodeVectorItems(NSOutputStream *os, NSString *itemType, id value, __autoreleasing NSError **error)
{
    if (![value isKindOfClass:[NSArray class]])
    {
        if (error != NULL)
            *error = TGTLDynamicError(@"expected array for vector<%@>", itemType);
        return false;
    }
    NSArray *items = value;
    [os writeInt32:(int32_t)items.count];
    for (id item in items)
    {
        if (!TGTLDynamicEncodeValue(os, itemType, item, error))
            return false;
    }
    return true;
}

static bool TGTLDynamicEncodeValue(NSOutputStream *os, NSString *type, id value, __autoreleasing NSError **error)
{
    if ([type isEqualToString:@"int"])
        [os writeInt32:[value intValue]];
    else if ([type isEqualToString:@"long"])
        [os writeInt64:[value longLongValue]];
    else if ([type isEqualToString:@"double"])
        [os writeDouble:[value doubleValue]];
    else if ([type isEqualToString:@"string"])
        [os writeString:[value isKindOfClass:[NSString class]] ? value : @""];
    else if ([type isEqualToString:@"bytes"])
        [os writeBytes:[value isKindOfClass:[NSData class]] ? value : [NSData data]];
    else if ([type isEqualToString:@"int128"] || [type isEqualToString:@"int256"])
    {
        NSUInteger length = [type isEqualToString:@"int128"] ? 16 : 32;
        if (![value isKindOfClass:[NSData class]] || ((NSData *)value).length != length)
        {
            if (error != NULL)
                *error = TGTLDynamicError(@"expected %lu bytes for %@", (unsigned long)length, type);
            return false;
        }
        [os writeData:value];
    }
    else if ([type isEqualToString:@"Bool"])
        [os writeInt32:[value boolValue] ? TL_BOOL_TRUE_CONSTRUCTOR : TL_BOOL_FALSE_CONSTRUCTOR];
    else if ([type isEqualToString:@"true"])
        return true;
    else
    {
        NSString *boxedItemType = TGTLDynamicGenericArgument(type, @"Vector<");
        if (boxedItemType != nil)
        {
            [os writeInt32:TGTLDynamicVectorSignature];
            return TGTLDynamicEncodeVectorItems(os, boxedItemType, value, error);
        }
        NSString *bareItemType = TGTLDynamicGenericArgument(type, @"vector<");
        if (bareItemType != nil)
            return TGTLDynamicEncodeVectorItems(os, bareItemType, value, error);

        bool bare = [type hasPrefix:@"%"] || TGTLDynamicIsBareConstructorName(type);
        if ([value isKindOfClass:[TGTLDynamicObject class]])
        {
            TGTLDynamicObject *object = value;
            TGTLDynamicEntry *entry = [[TGTLDynamicScheme sharedScheme] typeNamed:object.constructor];
            if (entry == nil)
            {
                if (error != NULL)
                    *error = TGTLDynamicError(@"unknown constructor %@", object.constructor);
                return false;
            }
            if (!bare)
                [os writeInt32:entry->_signature];
            return TGTLDynamicEncodeFields(os, entry, object.fields, error);
        }
        if ([value conformsToProtocol:@protocol(TLObject)])
        {
            TLMetaClassStore::serializeObject(os, value, !bare);
            return true;
        }
        if (error != NULL)
            *error = TGTLDynamicError(@"cannot encode %@ as %@", NSStringFromClass([value class]), type);
        return false;
    }
    return true;
}

@interface TGTLDynamicRpc ()
{
    TGTLDynamicEntry *_entry;
    NSData *_payload;
}

@end

@implementation TGTLDynamicRpc

- (instancetype)initWithMethod:(NSString *)method parameters:(NSDictionary *)parameters
{
    self = [super init];
    if (self != nil)
    {
        _method = method;
        _parameters = parameters == nil ? @{} : parameters;
        _entry = [[TGTLDynamicScheme sharedScheme] methodNamed:method];
        if (_entry == nil)
        {
            _encodingError = TGTLDynamicError(@"unknown method %@", method);
        }
        else
        {
            NSOutputStream *os = [[NSOutputStream alloc] initToMemory];
            [os open];
            __autoreleasing NSError *error = nil;
            if (TGTLDynamicEncodeFields(os, _entry, _parameters, &error))
                _payload = [os currentBytes];
            else
                _encodingError = error;
            [os close];
        }
        if (_encodingError != nil)
            TGLog(@"TLDYNAMIC %@", _encodingError.localizedDescription);
    }
    return self;
}

- (int32_t)TLconstructorSignature
{
    return _entry == nil ? TL_NULL_CONSTRUCTOR : _entry->_signature;
}

- (int32_t)TLconstructorName
{
    return -1;
}

- (Class)responseClass
{
    return [NSObject class];
}

- (int)impliedResponseSignature
{
    return 0;
}

- (int)layerVersion
{
    return 228;
}

- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject
{
    return nil;
}

- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values
{
}

- (void)TLserialize:(NSOutputStream *)os
{
    if (_payload != nil)
        [os writeData:_payload];
}

+ (SSignal *)requestSignalWithMethod:(NSString *)method parameters:(NSDictionary *)parameters
{
    return [self requestSignalWithMethod:method parameters:parameters dynamicTypes:nil];
}

+ (SSignal *)requestSignalWithMethod:(NSString *)method parameters:(NSDictionary *)parameters dynamicTypes:(NSSet *)dynamicTypes
{
    TGTLDynamicRpc *rpc = [[TGTLDynamicRpc alloc] initWithMethod:method parameters:parameters];
    rpc.dynamicTypes = dynamicTypes;
    if (rpc.encodingError != nil)
        return [SSignal fail:rpc.encodingError];
    return [[[[TGTelegramNetworking instance] requestSignal:rpc] mapToSignal:^SSignal *(id result)
    {
        if (result == nil)
            return [SSignal fail:TGTLDynamicError(@"%@: empty or malformed response", method)];
        return [SSignal single:result];
    }] onError:^(id error)
    {
        TGLog(@"TLDYNAMIC %@ failed: %@", method, error);
    }];
}

+ (id)parseResponseFromStream:(NSInputStream *)is signature:(int32_t)signature request:(TGTLDynamicRpc *)request error:(__autoreleasing NSError **)error
{
    TGTLDynamicEntry *entry = request->_entry;
    if (entry == nil)
    {
        if (error != NULL)
            *error = TGTLDynamicError(@"unknown method %@", request.method);
        return nil;
    }
    TGTLDynamicTypePolicy policy;
    policy.nativeTypes = TGTLDynamicDefaultNativeTypes();
    policy.dynamicTypes = request.dynamicTypes;
    return TGTLDynamicDecodeBoxed(is, signature, entry->_type, policy, error);
}

@end

@implementation TGTLDynamicObject (MessageActionParsing)

+ (instancetype)parseObjectFromStream:(NSInputStream *)stream signature:(int32_t)signature error:(NSError **)error
{
    TGTLDynamicTypePolicy policy;
    policy.nativeTypes = TGTLDynamicDefaultNativeTypes();
    policy.dynamicTypes = nil;
    id result = TGTLDynamicDecodeBoxed(stream, signature, @"MessageAction", policy, error);
    return [result isKindOfClass:[TGTLDynamicObject class]] ? result : nil;
}

@end
