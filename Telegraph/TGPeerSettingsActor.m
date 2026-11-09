#import "TGPeerSettingsActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"

#import "TGDatabase.h"

#import "TGTelegraph.h"

#import "TGUpdateStateRequestBuilder.h"

#import "TGTelegramNetworking.h"

#import "TLPeerNotifySettings$peerNotifySettings.h"
#import "../OnegramRuntime/OGRemoteClock.h"

int cachedMessageSettingsVersion = -1;
int cachedGroupSettingsVersion = -1;
int cachedChannelSettingsVersion = -1;

@interface TGPeerSettingsActor ()

@property (nonatomic) int64_t peerId;

@property (nonatomic) bool force;

- (void)continueWithStoredSoundId:(NSNumber *)peerSoundId muteUntil:(NSNumber *)peerMuteUntil previewText:(NSNumber *)peerPreviewText messagesMuted:(NSNumber *)messagesMuted notFound:(bool)notFound cachedOnly:(bool)cachedOnly accessHash:(int64_t)accessHash;
- (void)completeWithServerSoundId:(NSNumber *)peerSoundId muteUntil:(NSNumber *)peerMuteUntil previewText:(NSNumber *)peerPreviewText messagesMuted:(NSNumber *)messagesMuted pendingAction:(TGChangeNotificationSettingsFutureAction *)action clearPending:(bool)clearPending;

@end

@implementation TGPeerSettingsActor

@synthesize peerId = _peerId;

@synthesize force = _force;

+ (NSString *)genericPath
{
    return @"/tg/peerSettings/@";
}

- (void)prepare:(NSDictionary *)options
{
    if ([[options objectForKey:@"force"] boolValue])
        self.requestQueueName = @"settings";
}

- (void)execute:(NSDictionary *)options
{
    _peerId = [[options objectForKey:@"peerId"] longLongValue];
    if (_peerId == 0)
    {
        [ActionStageInstance() nodeRetrieveFailed:self.path];
        return;
    }
    
    bool cachedOnly = [self.path hasSuffix:@"cachedOnly)"];
    
    _force = [[options objectForKey:@"force"] boolValue];
    
    int64_t peerId = _peerId;
    int64_t accessHash = [options[@"accessHash"] longLongValue];
    [TGDatabaseInstance() dispatchOnDatabaseThread:^
    {
        bool notFound = false;
        NSNumber *peerSoundId = nil;
        NSNumber *peerMuteUntil = nil;
        NSNumber *peerPreviewText = nil;
        NSNumber *messagesMuted = nil;
        [TGDatabaseInstance() loadPeerNotificationSettings:peerId soundId:&peerSoundId muteUntil:&peerMuteUntil previewText:&peerPreviewText messagesMuted:&messagesMuted notFound:&notFound];
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            if (self.cancelled)
                return;
            [self continueWithStoredSoundId:peerSoundId muteUntil:peerMuteUntil previewText:peerPreviewText messagesMuted:messagesMuted notFound:notFound cachedOnly:cachedOnly accessHash:accessHash];
        }];
    } synchronous:false];
}

- (void)continueWithStoredSoundId:(NSNumber *)peerSoundId muteUntil:(NSNumber *)peerMuteUntil previewText:(NSNumber *)peerPreviewText messagesMuted:(NSNumber *)messagesMuted notFound:(bool)notFound cachedOnly:(bool)cachedOnly accessHash:(int64_t)accessHash
{
    if ((notFound || _force) && !cachedOnly)
    {
        self.cancelToken = [TGTelegraphInstance doRequestPeerNotificationSettings:_peerId accessHash:accessHash actor:self];
    }
    else
    {
        if (TGPeerIdIsNotificationDefaults(_peerId))
        {
            if (peerSoundId == nil)
                peerSoundId = @1;
            
            if (peerMuteUntil == nil)
                peerMuteUntil = @0;
            
            if (peerPreviewText == nil)
                peerPreviewText = @true;
            
            if (messagesMuted == nil)
                messagesMuted = @false;
        }
        
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        if (peerSoundId != nil)
            dict[@"soundId"] = peerSoundId;
        if (peerMuteUntil != nil)
            dict[@"muteUntil"] = peerMuteUntil;
        if (peerPreviewText != nil)
            dict[@"previewText"] = peerPreviewText;
        if (messagesMuted != nil)
            dict[@"messagesMuted"] = messagesMuted;
        
        [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphObjectNode alloc] initWithObject:dict]];
        
        if ((_peerId == TGPeerIdNotificationDefaultsPrivate && cachedMessageSettingsVersion < [TGUpdateStateRequestBuilder stateVersion]) || (_peerId == TGPeerIdNotificationDefaultsGroup && cachedGroupSettingsVersion < [TGUpdateStateRequestBuilder stateVersion]) || (_peerId == TGPeerIdNotificationDefaultsChannel && cachedChannelSettingsVersion < [TGUpdateStateRequestBuilder stateVersion]))
        {
            [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/peerSettings/(%lld,force)", _peerId] options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithLongLong:_peerId], @"peerId", [[NSNumber alloc] initWithBool:true], @"force", nil] watcher:TGTelegraphInstance];
        }
    }
}

- (void)peerNotifySettingsRequestSuccess:(TLPeerNotifySettings *)settings
{
    NSNumber *peerSoundId = nil;
    NSNumber *peerMuteUntil = nil;
    NSNumber *peerPreviewText = nil;
    NSNumber *messagesMuted = nil;
    
    if ([settings isKindOfClass:[TLPeerNotifySettings$peerNotifySettings class]])
    {
        TLPeerNotifySettings$peerNotifySettings *concreteSettings = (TLPeerNotifySettings$peerNotifySettings *)settings;
        if (concreteSettings.flags & (1 << 0)) {
            peerPreviewText = @(concreteSettings.showPreviews);
        }
        if (concreteSettings.flags & (1 << 1)) {
            messagesMuted = @(concreteSettings.silent);
        }
        if (concreteSettings.flags & (1 << 2)) {
            if (concreteSettings.mute_until > OGRemoteClockTime())
                peerMuteUntil = @(concreteSettings.mute_until);
            else
                peerMuteUntil = @0;
        }
        if (concreteSettings.flags & (1 << 3))
        {
            if (concreteSettings.sound.length == 0)
                peerSoundId = @(0);
            else if ([concreteSettings.sound isEqualToString:@"default"])
                peerSoundId = @(1);
            else
                peerSoundId = @([concreteSettings.sound intValue]);
        }
    }
    
    int64_t peerId = _peerId;
    [TGDatabaseInstance() dispatchOnDatabaseThread:^
    {
        TGChangeNotificationSettingsFutureAction *action = (TGChangeNotificationSettingsFutureAction *)[TGDatabaseInstance() loadFutureAction:peerId type:TGChangeNotificationSettingsFutureActionType];
        bool clearPending = action == nil && [TGDatabaseInstance() loadFutureAction:0 type:TGClearNotificationsFutureActionType] != nil;
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            if (self.cancelled)
                return;
            [self completeWithServerSoundId:peerSoundId muteUntil:peerMuteUntil previewText:peerPreviewText messagesMuted:messagesMuted pendingAction:action clearPending:clearPending];
        }];
    } synchronous:false];
}

- (void)completeWithServerSoundId:(NSNumber *)peerSoundId muteUntil:(NSNumber *)peerMuteUntil previewText:(NSNumber *)peerPreviewText messagesMuted:(NSNumber *)messagesMuted pendingAction:(TGChangeNotificationSettingsFutureAction *)action clearPending:(bool)clearPending
{
    if (action != nil)
    {
        peerSoundId = action.soundId;
        peerMuteUntil = action.muteUntil;
        peerPreviewText = action.previewText;
        messagesMuted = action.messagesMuted;
    }
    else if (clearPending)
    {
        peerSoundId = nil;
        peerMuteUntil = nil;
        peerPreviewText = nil;
        messagesMuted = nil;
    }
    
    if (_peerId == TGPeerIdNotificationDefaultsPrivate)
        cachedMessageSettingsVersion = [TGUpdateStateRequestBuilder stateVersion];
    else if (_peerId == TGPeerIdNotificationDefaultsGroup)
        cachedGroupSettingsVersion = [TGUpdateStateRequestBuilder stateVersion];
    else if (_peerId == TGPeerIdNotificationDefaultsChannel)
        cachedChannelSettingsVersion = [TGUpdateStateRequestBuilder stateVersion];
    
    bool force = _force;
    int64_t peerId = _peerId;
    
    [TGDatabaseInstance() storePeerNotificationSettings:_peerId soundId:peerSoundId muteUntil:peerMuteUntil previewText:peerPreviewText messagesMuted:messagesMuted writeToActionQueue:false completion:^(bool changed)
    {
        if (changed && force)
        {
            [ActionStageInstance() dispatchOnStageQueue:^
            {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                if (peerSoundId != nil)
                    dict[@"soundId"] = peerSoundId;
                if (peerMuteUntil != nil)
                    dict[@"muteUntil"] = peerMuteUntil;
                if (peerPreviewText != nil)
                    dict[@"previewText"] = peerPreviewText;
                if (messagesMuted != nil)
                    dict[@"messagesMuted"] = messagesMuted;
                
                [ActionStageInstance() dispatchResource:[NSString stringWithFormat:@"/tg/peerSettings/(%lld)", peerId] resource:[[SGraphObjectNode alloc] initWithObject:dict]];
            }];
        }
    }];
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    if (peerSoundId != nil)
        dict[@"soundId"] = peerSoundId;
    if (peerMuteUntil != nil)
        dict[@"muteUntil"] = peerMuteUntil;
    if (peerPreviewText != nil)
        dict[@"previewText"] = peerPreviewText;
    if (messagesMuted != nil)
        dict[@"messagesMuted"] = messagesMuted;
    
    [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphObjectNode alloc] initWithObject:dict]];
}

- (void)peerNotifySettingsRequestFailed
{
    [ActionStageInstance() nodeRetrieveFailed:self.path];
}

@end
