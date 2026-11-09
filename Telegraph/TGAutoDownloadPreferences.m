#import "TGAutoDownloadPreferences.h"

NSString *const TGAutoDownloadPreferencesDidChangeNotification = @"TGAutoDownloadPreferencesDidChangeNotification";

@implementation TGAutoDownloadPreferences

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _disabled = [aDecoder decodeBoolForKey:@"disabled"];
        _photos = [aDecoder decodeInt32ForKey:@"photos"];
        _videos = [aDecoder decodeInt32ForKey:@"videos"];
        _maximumVideoSize = [aDecoder decodeInt32ForKey:@"maxVideoSize"];
        _documents = [aDecoder decodeInt32ForKey:@"documents"];
        _maximumDocumentSize = [aDecoder decodeInt32ForKey:@"maxDocumentSize"];
        _gifs = [aDecoder decodeInt32ForKey:@"gifs"];
        _voiceMessages = [aDecoder decodeInt32ForKey:@"voiceMessages"];
        _videoMessages = [aDecoder decodeInt32ForKey:@"videoMessages"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeBool:_disabled forKey:@"disabled"];
    [aCoder encodeInt32:_photos forKey:@"photos"];
    [aCoder encodeInt32:_videos forKey:@"videos"];
    [aCoder encodeInt32:_maximumVideoSize forKey:@"maxVideoSize"];
    [aCoder encodeInt32:_documents forKey:@"documents"];
    [aCoder encodeInt32:_maximumDocumentSize forKey:@"maxDocumentSize"];
    [aCoder encodeInt32:_gifs forKey:@"gifs"];
    [aCoder encodeInt32:_voiceMessages forKey:@"voiceMessages"];
    [aCoder encodeInt32:_videoMessages forKey:@"videoMessages"];
}

+ (instancetype)defaultPreferences
{
    TGAutoDownloadPreferences *preferences = [[TGAutoDownloadPreferences alloc] init];
    preferences->_photos = TGAutoDownloadModeWifiContacts | TGAutoDownloadModeWifiPrivateChats | TGAutoDownloadModeWifiGroups | TGAutoDownloadModeWifiChannels;
    preferences->_videos = preferences->_photos;
    preferences->_maximumVideoSize = 10;
    preferences->_documents = preferences->_photos;
    preferences->_maximumDocumentSize = 5;
    preferences->_gifs = preferences->_photos;
    preferences->_voiceMessages = TGAutoDownloadModeAll;
    preferences->_videoMessages = preferences->_photos;
    return preferences;
}

+ (instancetype)preferencesWithLegacyDownloadPrivatePhotos:(bool)privatePhotos groupPhotos:(bool)groupPhotos privateVoiceMessages:(bool)privateVoiceMessages groupVoiceMessages:(bool)groupVoiceMessages privateVideoMessages:(bool)privateVideoMessages groupVideoMessages:(bool)groupVideoMessages
{
    TGAutoDownloadPreferences *preferences = [[TGAutoDownloadPreferences alloc] init];
    
    if (privatePhotos)
        preferences->_photos |= TGAutoDownloadModeAllPrivateChats;
    if (groupPhotos)
        preferences->_photos |= TGAutoDownloadModeAllGroups;
    
    if (privateVoiceMessages)
        preferences->_voiceMessages |= TGAutoDownloadModeAllPrivateChats;
    if (groupVoiceMessages)
        preferences->_voiceMessages |= TGAutoDownloadModeAllGroups;
    
    if (privateVideoMessages)
        preferences->_videoMessages |= TGAutoDownloadModeAllPrivateChats;
    if (groupVideoMessages)
        preferences->_videoMessages |= TGAutoDownloadModeAllGroups;
    
    preferences->_maximumVideoSize = 10;
    preferences->_maximumDocumentSize = 10;
    
    return preferences;
}

- (TGAutoDownloadPreferences *)copyPreferences
{
    TGAutoDownloadPreferences *preferences = [[TGAutoDownloadPreferences alloc] init];
    preferences->_disabled = _disabled;
    preferences->_photos = _photos;
    preferences->_videos = _videos;
    preferences->_maximumVideoSize = _maximumVideoSize;
    preferences->_documents = _documents;
    preferences->_maximumDocumentSize = _maximumDocumentSize;
    preferences->_gifs = _gifs;
    preferences->_voiceMessages = _voiceMessages;
    preferences->_videoMessages = _videoMessages;
    return preferences;
}

- (instancetype)updateDisabled:(bool)disabled
{
    TGAutoDownloadPreferences *preferences = [self copyPreferences];
    preferences->_disabled = disabled;
    return preferences;
}

- (instancetype)updatePhotosMode:(TGAutoDownloadMode)mode
{
    TGAutoDownloadPreferences *preferences = [self copyPreferences];
    preferences->_photos = mode;
    return preferences;
}

- (instancetype)updateVideosMode:(TGAutoDownloadMode)mode maximumSize:(int32_t)maximumSize
{
    TGAutoDownloadPreferences *preferences = [self copyPreferences];
    preferences->_videos = mode;
    preferences->_maximumVideoSize = MAX(0, maximumSize);
    return preferences;
}

- (instancetype)updateDocumentsMode:(TGAutoDownloadMode)mode maximumSize:(int32_t)maximumSize
{
    TGAutoDownloadPreferences *preferences = [self copyPreferences];
    preferences->_documents = mode;
    preferences->_maximumDocumentSize = MAX(0, maximumSize);
    return preferences;
}

- (instancetype)updateGifsMode:(TGAutoDownloadMode)mode
{
    TGAutoDownloadPreferences *preferences = [self copyPreferences];
    preferences->_gifs = mode;
    return preferences;
}

- (instancetype)updateVoiceMessagesMode:(TGAutoDownloadMode)mode
{
    TGAutoDownloadPreferences *preferences = [self copyPreferences];
    preferences->_voiceMessages = mode;
    return preferences;
}

- (instancetype)updateVideoMessagesMode:(TGAutoDownloadMode)mode
{
    TGAutoDownloadPreferences *preferences = [self copyPreferences];
    preferences->_videoMessages = mode;
    return preferences;
}

+ (bool)shouldDownload:(TGAutoDownloadMode)mode inChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType
{
    bool isWiFi = networkType == TGNetworkTypeWiFi;
    bool isCellular = networkType == TGNetworkTypeGPRS || networkType == TGNetworkTypeEdge || networkType == TGNetworkType3G || networkType == TGNetworkTypeLTE;
    
    bool shouldDownload = false;
    switch (chat)
    {
        case TGAutoDownloadChatContact:
            if (isCellular)
                shouldDownload = (mode & TGAutoDownloadModeCellularContacts) != 0;
            else if (isWiFi)
                shouldDownload = (mode & TGAutoDownloadModeWifiContacts) != 0;
            break;
            
        case TGAutoDownloadChatOtherPrivateChat:
            if (isCellular)
                shouldDownload = (mode & TGAutoDownloadModeCellularPrivateChats) != 0;
            else if (isWiFi)
                shouldDownload = (mode & TGAutoDownloadModeWifiPrivateChats) != 0;
            break;
            
        case TGAutoDownloadChatGroup:
            if (isCellular)
                shouldDownload = (mode & TGAutoDownloadModeCellularGroups) != 0;
            else if (isWiFi)
                shouldDownload = (mode & TGAutoDownloadModeWifiGroups) != 0;
            break;
            
        case TGAutoDownloadChatChannel:
            if (isCellular)
                shouldDownload = (mode & TGAutoDownloadModeCellularChannels) != 0;
            else if (isWiFi)
                shouldDownload = (mode & TGAutoDownloadModeWifiChannels) != 0;
            break;
            
        default:
            break;
    }
    return shouldDownload;
}

- (bool)shouldDownloadPhotoInChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType
{
    if (self.disabled)
        return false;
    
    return [TGAutoDownloadPreferences shouldDownload:_photos inChat:chat networkType:networkType];
}

- (bool)shouldDownloadVideoInChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType
{
    if (self.disabled)
        return false;
    
    return [TGAutoDownloadPreferences shouldDownload:_videos inChat:chat networkType:networkType];
}

- (bool)shouldDownloadDocumentInChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType
{
    if (self.disabled)
        return false;
    
    return [TGAutoDownloadPreferences shouldDownload:_documents inChat:chat networkType:networkType];
}

- (bool)shouldDownloadGifInChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType
{
    return !self.disabled && [TGAutoDownloadPreferences shouldDownload:_gifs inChat:chat networkType:networkType];
}

- (bool)shouldDownloadVoiceMessageInChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType
{
    if (self.disabled)
        return false;
    
    return [TGAutoDownloadPreferences shouldDownload:_voiceMessages inChat:chat networkType:networkType];
}

- (bool)shouldDownloadVideoMessageInChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType
{
    if (self.disabled)
        return false;
    
    return [TGAutoDownloadPreferences shouldDownload:_videoMessages inChat:chat networkType:networkType];
}

- (bool)isDefaultPreferences
{
    return [self isEqual:[TGAutoDownloadPreferences defaultPreferences]];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    TGAutoDownloadPreferences *preferences = (TGAutoDownloadPreferences *)object;
    return preferences.gifs == _gifs && preferences.photos == _photos && preferences.videos == _videos && preferences.documents == _documents && preferences.voiceMessages == _voiceMessages && preferences.videoMessages == _videoMessages && preferences.maximumVideoSize == _maximumVideoSize && preferences.maximumDocumentSize == _maximumDocumentSize && preferences.disabled == _disabled;
}

@end
