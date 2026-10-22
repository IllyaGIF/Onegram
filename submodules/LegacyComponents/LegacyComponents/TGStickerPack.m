#import "TGStickerPack.h"

#import "LegacyComponents.h"
#import <libkern/OSAtomic.h>

@interface TGStickerPackArchivedArray : NSObject
{
    NSData *_data;
    NSArray *_array;
    NSData *_encodedData;
}

- (instancetype)initWithArray:(NSArray *)array;
- (instancetype)initWithEncodedData:(NSData *)data;
- (NSArray *)array;
- (NSData *)encodedData;
- (BOOL)isEqualToArchivedArray:(TGStickerPackArchivedArray *)other;

@end

@implementation TGStickerPackArchivedArray

- (instancetype)initWithArray:(NSArray *)array
{
    self = [super init];
    if (self != nil)
        _array = array;
    return self;
}

- (instancetype)initWithEncodedData:(NSData *)data
{
    self = [super init];
    if (self != nil)
    {
        _data = data;
        _encodedData = data;
    }
    return self;
}

- (NSArray *)array
{
    if (_data == nil)
    {
        OSMemoryBarrier();
        return _array;
    }
    @synchronized (self)
    {
        if (_data != nil)
        {
            NSArray *decoded = nil;
            @try
            {
                decoded = [NSKeyedUnarchiver unarchiveObjectWithData:_data];
            }
            @catch (__unused NSException *exception)
            {
            }
            _array = [decoded isKindOfClass:[NSArray class]] ? decoded : @[];
            OSMemoryBarrier();
            _data = nil;
        }
        return _array;
    }
}

- (NSData *)encodedData
{
    @synchronized (self)
    {
        if (_encodedData == nil)
            _encodedData = [NSKeyedArchiver archivedDataWithRootObject:_array ?: @[]];
        return _encodedData;
    }
}

- (NSData *)pendingData
{
    @synchronized (self)
    {
        return _data;
    }
}

- (BOOL)isEqualToArchivedArray:(TGStickerPackArchivedArray *)other
{
    if (other == self)
        return true;
    NSData *data = [self pendingData];
    NSData *otherData = [other pendingData];
    if (data != nil && otherData != nil)
        return [data isEqualToData:otherData];
    return TGObjectCompare([self array], [other array]);
}

@end

static TGStickerPackArchivedArray *TGStickerPackDecodeArchivedArray(NSCoder *coder, NSString *dataKey, NSString *arrayKey)
{
    if ([coder containsValueForKey:dataKey])
    {
        NSData *data = [coder decodeObjectForKey:dataKey];
        if ([data isKindOfClass:[NSData class]])
            return [[TGStickerPackArchivedArray alloc] initWithEncodedData:data];
    }
    NSArray *array = [coder decodeObjectForKey:arrayKey];
    return [[TGStickerPackArchivedArray alloc] initWithArray:[array isKindOfClass:[NSArray class]] ? array : nil];
}

@implementation TGStickerPack
{
    TGStickerPackArchivedArray *_archivedStickerAssociations;
    TGStickerPackArchivedArray *_archivedDocuments;
}

- (instancetype)initWithPackReference:(id<TGStickerPackReference>)packReference title:(NSString *)title stickerAssociations:(NSArray *)stickerAssociations documents:(NSArray *)documents packHash:(int32_t)packHash hidden:(bool)hidden isMask:(bool)isMask isFeatured:(bool)isFeatured installedDate:(int32_t)installedDate
{
    return [self initWithPackReference:packReference title:title archivedStickerAssociations:[[TGStickerPackArchivedArray alloc] initWithArray:stickerAssociations] archivedDocuments:[[TGStickerPackArchivedArray alloc] initWithArray:documents] packHash:packHash hidden:hidden isMask:isMask isFeatured:isFeatured installedDate:installedDate];
}

- (instancetype)initWithPackReference:(id<TGStickerPackReference>)packReference title:(NSString *)title archivedStickerAssociations:(TGStickerPackArchivedArray *)archivedStickerAssociations archivedDocuments:(TGStickerPackArchivedArray *)archivedDocuments packHash:(int32_t)packHash hidden:(bool)hidden isMask:(bool)isMask isFeatured:(bool)isFeatured installedDate:(int32_t)installedDate
{
    self = [super init];
    if (self != nil)
    {
        _packReference = packReference;
        _title = title;
        _archivedStickerAssociations = archivedStickerAssociations;
        _archivedDocuments = archivedDocuments;
        _packHash = packHash;
        _hidden = hidden;
        _isMask = isMask;
        _isFeatured = isFeatured;
        _installedDate = installedDate;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithPackReference:[aDecoder decodeObjectForKey:@"packReference"] title:[aDecoder decodeObjectForKey:@"title"] archivedStickerAssociations:TGStickerPackDecodeArchivedArray(aDecoder, @"stickerAssociationsData", @"stickerAssociations") archivedDocuments:TGStickerPackDecodeArchivedArray(aDecoder, @"documentsData", @"documents") packHash:[aDecoder decodeInt32ForKey:@"packHash"] hidden:[aDecoder decodeInt32ForKey:@"hidden"] isMask:[aDecoder decodeInt32ForKey:@"isMask"] isFeatured:[aDecoder decodeInt32ForKey:@"isFeatured"] installedDate:[aDecoder decodeInt32ForKey:@"installedDate"]];
}

- (NSArray *)stickerAssociations
{
    return [_archivedStickerAssociations array];
}

- (NSArray *)documents
{
    return [_archivedDocuments array];
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithPackReference:(id<TGStickerPackReference>)[coder decodeObjectForCKey:"r"] title:[coder decodeStringForCKey:"t"] stickerAssociations:[coder decodeArrayForCKey:"a"] documents:[coder decodeArrayForCKey:"d"] packHash:[coder decodeInt32ForCKey:"ph"] hidden:[coder decodeInt32ForCKey:"hi"] isMask:[coder decodeInt32ForCKey:"ma"] isFeatured:[coder decodeInt32ForCKey:"if"] installedDate:[coder decodeInt32ForCKey:"id"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_packReference forKey:@"packReference"];
    [aCoder encodeObject:_title forKey:@"title"];
    [aCoder encodeObject:[_archivedStickerAssociations encodedData] forKey:@"stickerAssociationsData"];
    [aCoder encodeObject:[_archivedDocuments encodedData] forKey:@"documentsData"];
    [aCoder encodeInt32:_packHash forKey:@"packHash"];
    [aCoder encodeInt32:_hidden ? 1 : 0 forKey:@"hidden"];
    [aCoder encodeInt32:_isMask ? 1 : 0 forKey:@"isMask"];
    [aCoder encodeInt32:_isFeatured ? 1 : 0 forKey:@"isFeatured"];
    [aCoder encodeInt32:_installedDate forKey:@"installedDate"];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeObject:_packReference forKey:@"r"];
    [coder encodeString:_title forCKey:"t"];
    [coder encodeArray:self.stickerAssociations forCKey:"a"];
    [coder encodeArray:self.documents forCKey:"d"];
    [coder encodeInt32:_packHash forCKey:"ph"];
    [coder encodeInt32:_hidden ? 1 : 0 forCKey:"hi"];
    [coder encodeInt32:_isMask ? 1 : 0 forCKey:"ma"];
    [coder encodeInt32:_isFeatured ? 1 : 0 forCKey:"if"];
    [coder encodeInt32:_installedDate forCKey:"id"];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;

    if (![object isKindOfClass:[TGStickerPack class]])
        return false;

    TGStickerPack *other = object;

    if (![other->_packReference isEqual:_packReference])
        return false;

    if (other->_packHash != _packHash || other->_hidden != _hidden || other->_isMask != _isMask || other->_isFeatured != _isFeatured || other->_installedDate != _installedDate)
        return false;

    if (![other->_archivedStickerAssociations isEqualToArchivedArray:_archivedStickerAssociations])
        return false;

    return [other->_archivedDocuments isEqualToArchivedArray:_archivedDocuments];
}

@end
