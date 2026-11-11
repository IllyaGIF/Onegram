#import "TelegramMediaResources.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGStringUtils.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMediaOriginInfo.h"

#import "TL/TLMetaScheme.h"

static NSData *OGCompatEffectiveFileReference(TGMediaOriginInfo *originInfo, NSData *storedReference)
{
    NSData *originReference = [originInfo fileReference];
    return originReference.length != 0 ? originReference : (storedReference ?: [NSData data]);
}

@interface OGCompatResourceIdBase : NSObject <NSCopying>

@end

@implementation OGCompatResourceIdBase

- (instancetype)copyWithZone:(NSZone *)__unused zone {
    return self;
}

@end

@interface OGCompatThumbResourceId : OGCompatResourceIdBase

@property (nonatomic, readonly) int64_t mediaId;
@property (nonatomic, strong, readonly) NSString *sizeTag;

- (instancetype)initWithMediaId:(int64_t)mediaId sizeTag:(NSString *)sizeTag;

@end

@implementation OGCompatThumbResourceId

- (instancetype)initWithMediaId:(int64_t)mediaId sizeTag:(NSString *)sizeTag {
    self = [super init];
    if (self != nil) {
        _sizeTag = sizeTag;
        _mediaId = mediaId;
    }
    return self;
}

- (NSUInteger)hash {
    return _sizeTag.hash ^ _mediaId;
}

- (BOOL)isEqual:(id)object {
    if (![object isMemberOfClass:[self class]])
        return NO;
    OGCompatThumbResourceId *other = object;
    return TGObjectCompare(_sizeTag, other->_sizeTag) && _mediaId == other->_mediaId;
}

@end

@interface CloudFileMediaResourceId : OGCompatResourceIdBase <MediaResourceId>

@property (nonatomic, readonly) int32_t datacenterId;
@property (nonatomic, readonly) int64_t volumeId;
@property (nonatomic, readonly) int32_t localId;
@property (nonatomic, readonly) int64_t secret;

@end

@implementation CloudFileMediaResourceId

- (instancetype)initWithDatacenterId:(int32_t)datacenterId volumeId:(int64_t)volumeId localId:(int32_t)localId secret:(int64_t)secret {
    self = [super init];
    if (self != nil) {
        _datacenterId = datacenterId;
        _volumeId = volumeId;
        _localId = localId;
        _secret = secret;
    }
    return self;
}

- (NSUInteger)hash {
    return _volumeId ^ _localId;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[CloudFileMediaResourceId class]])
        return NO;
    CloudFileMediaResourceId *other = object;
    return _datacenterId == other->_datacenterId && _volumeId == other->_volumeId && _localId == other->_localId && _secret == other->_secret;
}

- (NSString *)uniqueId {
    return [[NSString alloc] initWithFormat:@"telegram-cloud-file-%d-%lld-%d-%lld", _datacenterId, _volumeId, _localId, _secret];
}

@end

@implementation CloudFileMediaResource

- (instancetype)initWithDatacenterId:(int32_t)datacenterId volumeId:(int64_t)volumeId localId:(int32_t)localId secret:(int64_t)secret size:(NSNumber *)size legacyCacheUrl:(NSString *)legacyCacheUrl legacyCachePath:(NSString *)legacyCachePath mediaType:(id)mediaType originInfo:(TGMediaOriginInfo *)originInfo identifier:(int64_t)identifier {
    self = [super init];
    if (self != nil) {
        _datacenterId = datacenterId;
        _volumeId = volumeId;
        _localId = localId;
        _secret = secret;
        _legacyCacheUrl = legacyCacheUrl;
        _legacyCachePath = legacyCachePath;
        _size = size;
        _mediaType = mediaType;
        _originInfo = originInfo;
        _identifier = identifier;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[CloudFileMediaResource class]])
        return NO;
    CloudFileMediaResource *other = object;
    return _datacenterId == other->_datacenterId && _volumeId == other->_volumeId && _localId == other->_localId && _secret == other->_secret;
}

- (id<MediaResourceId>)resourceId {
    return [[CloudFileMediaResourceId alloc] initWithDatacenterId:_datacenterId volumeId:_volumeId localId:_localId secret:_secret];
}

- (TLInputFileLocation *)apiInputLocation {
    TLInputFileLocation$inputFileLocation *location = [[TLInputFileLocation$inputFileLocation alloc] init];
    location.volume_id = _volumeId;
    location.local_id = _localId;
    location.secret = _secret;
    location.file_reference = [_originInfo fileReferenceForVolumeId:_volumeId localId:_localId];
    return location;
}

@end

@interface OGCompatPhotoResourceId : OGCompatThumbResourceId <MediaResourceId>

@end

@implementation OGCompatPhotoResourceId

- (NSString *)uniqueId {
    return [NSString stringWithFormat:@"telegram-cloud-photo-%lld-%@", self.mediaId, self.sizeTag ?: @""];
}

@end

@implementation CloudPhotoMediaResource

- (instancetype)initWithDatacenterId:(int32_t)dc fileId:(int64_t)fid accessHash:(int64_t)hash fileReference:(NSData *)reference thumbSize:(NSString *)sizeTag size:(NSNumber *)byteSize mediaType:(id)kind originInfo:(TGMediaOriginInfo *)origin identifier:(int64_t)ident {
    self = [super init];
    if (self != nil) {
        _identifier = ident;
        _originInfo = origin;
        _mediaType = kind;
        _size = byteSize;
        _thumbSize = sizeTag;
        _fileReference = reference;
        _accessHash = hash;
        _fileId = fid;
        _datacenterId = dc;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[CloudPhotoMediaResource class]])
        return NO;
    CloudPhotoMediaResource *other = object;
    return TGObjectCompare(_thumbSize, other->_thumbSize) && _fileId == other->_fileId && _accessHash == other->_accessHash && _datacenterId == other->_datacenterId;
}

- (id<MediaResourceId>)resourceId {
    return [[OGCompatPhotoResourceId alloc] initWithMediaId:_fileId sizeTag:_thumbSize];
}

- (TLInputFileLocation *)apiInputLocation {
    TLInputFileLocation$inputPhotoFileLocation *location = [TLInputFileLocation$inputPhotoFileLocation new];
    location.thumb_size = _thumbSize ?: @"";
    location.file_reference = OGCompatEffectiveFileReference(_originInfo, _fileReference);
    location.access_hash = _accessHash;
    location.n_id = _fileId;
    return location;
}

@end

@interface OGCompatPeerPictureResourceId : OGCompatResourceIdBase <MediaResourceId>

@property (nonatomic, readonly) int64_t ownerId;
@property (nonatomic, readonly) int64_t pictureId;
@property (nonatomic, readonly) bool isLarge;

@end

@implementation OGCompatPeerPictureResourceId

- (instancetype)initWithOwnerId:(int64_t)ownerId pictureId:(int64_t)pictureId isLarge:(bool)isLarge {
    self = [super init];
    if (self != nil) {
        _isLarge = isLarge;
        _pictureId = pictureId;
        _ownerId = ownerId;
    }
    return self;
}

- (NSUInteger)hash {
    return (_isLarge ? 1 : 0) ^ _pictureId ^ _ownerId;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[OGCompatPeerPictureResourceId class]])
        return NO;
    OGCompatPeerPictureResourceId *other = object;
    return _isLarge == other->_isLarge && _pictureId == other->_pictureId && _ownerId == other->_ownerId;
}

- (NSString *)uniqueId {
    return [NSString stringWithFormat:@"telegram-peer-photo-%lld-%lld-%d", _ownerId, _pictureId, _isLarge ? 1 : 0];
}

@end

@implementation CloudPeerPhotoMediaResource

- (instancetype)initWithDatacenterId:(int32_t)dc peerId:(int64_t)owner accessHash:(int64_t)hash photoId:(int64_t)picture peerType:(int32_t)ownerKind big:(bool)large mediaType:(id)kind identifier:(int64_t)ident {
    self = [super init];
    if (self != nil) {
        _identifier = ident;
        _mediaType = kind;
        _big = large;
        _peerType = ownerKind;
        _photoId = picture;
        _accessHash = hash;
        _peerId = owner;
        _datacenterId = dc;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[CloudPeerPhotoMediaResource class]])
        return NO;
    CloudPeerPhotoMediaResource *other = object;
    return _big == other->_big && _photoId == other->_photoId && _peerId == other->_peerId;
}

- (id<MediaResourceId>)resourceId {
    return [[OGCompatPeerPictureResourceId alloc] initWithOwnerId:_peerId pictureId:_photoId isLarge:_big];
}

- (TLInputFileLocation *)apiInputLocation {
    TLInputFileLocation$inputPeerPhotoFileLocation *location = [TLInputFileLocation$inputPeerPhotoFileLocation new];
    location.big = _big;
    location.peer_type = _peerType;
    location.photo_id = _photoId;
    location.access_hash = _accessHash;
    location.peer_id = _peerId;
    return location;
}

@end

@interface OGCompatDocumentResourceId : OGCompatThumbResourceId <MediaResourceId>

@end

@implementation OGCompatDocumentResourceId

- (NSString *)uniqueId {
    return [NSString stringWithFormat:@"telegram-cloud-document-%lld-%@", self.mediaId, self.sizeTag ?: @""];
}

@end

@implementation CloudDocumentMediaResource

- (instancetype)initWithDatacenterId:(int32_t)dc fileId:(int64_t)fid accessHash:(int64_t)hash fileReference:(NSData *)reference thumbSize:(NSString *)sizeTag size:(NSNumber *)byteSize mediaType:(id)kind originInfo:(TGMediaOriginInfo *)origin identifier:(int64_t)ident {
    self = [super init];
    if (self != nil) {
        _identifier = ident;
        _originInfo = origin;
        _mediaType = kind;
        _size = byteSize;
        _thumbSize = sizeTag;
        _fileReference = reference;
        _accessHash = hash;
        _fileId = fid;
        _datacenterId = dc;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[CloudDocumentMediaResource class]])
        return NO;
    CloudDocumentMediaResource *other = object;
    return TGObjectCompare(_thumbSize, other->_thumbSize) && _fileId == other->_fileId && _accessHash == other->_accessHash && _datacenterId == other->_datacenterId;
}

- (id<MediaResourceId>)resourceId {
    return [[OGCompatDocumentResourceId alloc] initWithMediaId:_fileId sizeTag:_thumbSize];
}

- (TLInputFileLocation *)apiInputLocation {
    TLInputFileLocation$inputDocumentFileLocation *location = [TLInputFileLocation$inputDocumentFileLocation new];
    location.thumb_size = _thumbSize ?: @"";
    location.file_reference = OGCompatEffectiveFileReference(_originInfo, _fileReference);
    location.access_hash = _accessHash;
    location.n_id = _fileId;
    return location;
}

@end

@interface CloudSecureMediaResourceId : OGCompatResourceIdBase <MediaResourceId>

@property (nonatomic, readonly) NSString *fileHash;
@property (nonatomic, readonly) int64_t fileId;
@property (nonatomic, readonly) bool thumbnail;

@end

@implementation CloudSecureMediaResourceId

- (instancetype)initWithFileHash:(NSString *)fileHash fileId:(int64_t)fileId thumbnail:(bool)thumbnail {
    self = [super init];
    if (self != nil) {
        _fileHash = fileHash;
        _fileId = fileId;
        _thumbnail = thumbnail;
    }
    return self;
}

- (NSUInteger)hash {
    return _fileHash.hash;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[CloudSecureMediaResourceId class]])
        return NO;
    CloudSecureMediaResourceId *other = object;
    return TGObjectCompare(_fileHash, other->_fileHash) && _thumbnail == other->_thumbnail;
}

- (NSString *)uniqueId {
    NSString *uniqueId = [[NSString alloc] initWithFormat:@"telegram-secure-document-%@", _fileHash];
    if (_thumbnail)
        uniqueId = [uniqueId stringByAppendingString:@"-thumb"];
    return uniqueId;
}

@end

@implementation CloudSecureMediaResource

- (instancetype)initWithDatacenterId:(int32_t)datacenterId fileId:(int64_t)fileId accessHash:(int64_t)accessHash size:(NSNumber *)size fileHash:(NSData *)fileHash thumbnail:(bool)thumbnail mediaType:(id)mediaType {
    self = [super init];
    if (self != nil) {
        _datacenterId = datacenterId;
        _fileId = fileId;
        _accessHash = accessHash;
        _size = size;
        _fileHash = fileHash;
        _thumbnail = thumbnail;
        _mediaType = mediaType;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[CloudSecureMediaResource class]])
        return NO;
    CloudSecureMediaResource *other = object;
    return [_fileHash isEqual:other->_fileHash] && _thumbnail == other->_thumbnail;
}

- (id<MediaResourceId>)resourceId {
    return [[CloudSecureMediaResourceId alloc] initWithFileHash:[_fileHash stringByEncodingInHex] fileId:_fileId thumbnail:_thumbnail];
}

- (TLInputFileLocation *)apiInputLocation {
    if (_thumbnail)
        return nil;
    TLInputFileLocation$inputSecureFileLocation *location = [[TLInputFileLocation$inputSecureFileLocation alloc] init];
    location.n_id = _fileId;
    location.access_hash = _accessHash;
    return location;
}

@end
