#import "TGConversationHistoryRequestActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TGTelegraph.h"
#import "TGMessage+Telegraph.h"
#import "TGConversation+Telegraph.h"

#import "TGDatabase.h"

#import "TGSchema.h"

#import "TGUserDataRequestBuilder.h"

@interface TGConversationHistoryRequestActor ()
{
}

@property (nonatomic) bool loadUnread;
@property (nonatomic) int loadAtMessageId;

@end

@implementation TGConversationHistoryRequestActor

+ (NSString *)genericPath
{
    return @"/tg/conversations/@/history/@";
}


- (id)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)execute:(NSDictionary *)options
{
    NSRange range;
    range.location = [@"/tg/conversations/(" length];
    range.length = self.path.length - [@")/history" length] - range.location;
    int64_t conversationId = [[self.path substringWithRange:range] longLongValue];
    
    int maxMid = [options[@"maxMid"] intValue];
    
    int limit = 70;
    if ([options objectForKey:@"limit"] != nil)
        limit = [TGSchema intFromObject:[options objectForKey:@"limit"]];
    
    int maxDate = 0;
    if ([options objectForKey:@"maxDate"] != nil)
        maxDate = [TGSchema intFromObject:[options objectForKey:@"maxDate"]];
    
    int maxLocalMid = 0;
    if ([options objectForKey:@"maxLocalMid"] != nil)
        maxLocalMid = [TGSchema intFromObject:[options objectForKey:@"maxLocalMid"]];
    
    int offset = 0;
    if ([options objectForKey:@"offset"] != nil)
        offset = [[options objectForKey:@"offset"] intValue];
    
    bool clearExisting = [options[@"clearExisting"] boolValue];
    
    _loadUnread = [[options objectForKey:@"loadUnread"] boolValue];
    
    _loadAtMessageId = [options[@"loadAtMessageId"] intValue];
    if (_loadAtMessageId)
        _loadUnread = false;
    
    bool extraUnread = _loadUnread && _loadAtMessageId == 0 && [self.path hasSuffix:@"/(up0)"];
    
    if ([options[@"downwards"] boolValue])
    {
        [TGDatabaseInstance() loadMessagesFromConversationDownwards:conversationId minMid:maxMid minLocalMid:maxLocalMid minDate:maxDate limit:limit completion:^(NSArray *messages)
        {
            int minMessageId = INT_MAX;
            int maxMessageId = 0;
            for (TGMessage *message in messages)
            {
                if (message.mid < TGMessageLocalMidBaseline)
                {
                    minMessageId = MIN(minMessageId, message.mid);
                    maxMessageId = MAX(maxMessageId, message.mid);
                }
            }
            
            bool sequenceContainsHoles = minMessageId >= maxMid && [TGDatabaseInstance() conversationContainsHole:conversationId minMessageId:maxMid maxMessageId:maxMessageId];
            
            if (sequenceContainsHoles)
            {
                NSMutableDictionary *newOptions = [[NSMutableDictionary alloc] initWithDictionary:options];
                newOptions[@"down"] = @true;
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%lld)/asyncHistory/(%d,down)", conversationId, maxMid] options:newOptions watcher:self];
            }
            else
            {
                [ActionStageInstance() actionCompleted:self.path result:[[NSDictionary alloc] initWithObjectsAndKeys:messages, @"messages", [[NSNumber alloc] initWithBool:true], @"downwards", nil]];
            }
        }];
    }
    else
    {
        int requestMaxMid = (maxMid == 0 ? INT_MAX : maxMid);
        bool isEncrypted = [options[@"isEncrypted"] boolValue];
        bool isBroadcast = [options[@"isBroadcast"] boolValue];
        bool plainPeer = !isEncrypted && !isBroadcast;
        bool modernNegativeUser = false;
        if (conversationId < 0)
        {
            TGUser *user = [TGDatabaseInstance() loadUser:conversationId];
            modernNegativeUser = user != nil && user.phoneNumberHash != 0;
        }
        bool latestPage = offset == 0 && (maxMid == 0 || maxMid == INT_MAX);
        bool openEnded = _loadAtMessageId == 0 && ![options[@"downwards"] boolValue] && plainPeer;
        bool userLatest = (conversationId > 0 || modernNegativeUser) && latestPage && openEnded;
        bool forceRemoteTopRefresh = userLatest || (offset == 0 && maxDate == 0 && openEnded);
        
        [[TGDatabase instance] loadMessagesFromConversation:conversationId maxMid:requestMaxMid maxDate:(maxDate == 0 ? INT_MAX : maxDate) maxLocalMid:(maxLocalMid == 0 ? INT_MAX : maxLocalMid) atMessageId:_loadAtMessageId limit:limit extraUnread:extraUnread completion:^(NSArray *messages, bool historyExistsBelow)
        {
            int peerMinMid = [TGDatabaseInstance() loadPeerMinMid:conversationId];
            [ActionStageInstance() dispatchOnStageQueue:^
            {
                int minMessageId = INT_MAX;
                int maxMessageId = 0;
                for (TGMessage *message in messages)
                {
                    if (message.mid < TGMessageLocalMidBaseline)
                    {
                        minMessageId = MIN(minMessageId, message.mid);
                        maxMessageId = MAX(maxMessageId, message.mid);
                    }
                }
                
                bool sequenceContainsHoles = minMessageId <= requestMaxMid && [TGDatabaseInstance() conversationContainsHole:conversationId minMessageId:minMessageId maxMessageId:requestMaxMid];
                bool staleHistoryEnd = peerMinMid == 1 && messages.count <= 1 && conversationId < 0 && plainPeer;
                if (((messages.count != 0 && !staleHistoryEnd) || (peerMinMid != 0 && !staleHistoryEnd) || [options[@"isEncrypted"] boolValue] || [options[@"isBroadcast"] boolValue]) && !sequenceContainsHoles && !forceRemoteTopRefresh)
                {
                    
                    [ActionStageInstance() actionCompleted:self.path result:@{
                        @"messages": messages,
                        @"historyExistsBelow": @(historyExistsBelow),
                        @"clearExisting": @(clearExisting)
                     }];
                }
                else
                {
                    bool emptyBasicChat = messages.count == 0 && conversationId < 0 && plainPeer && !modernNegativeUser;
                    int remoteMaxMid = (forceRemoteTopRefresh || emptyBasicChat) ? 0 : maxMid;
                    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%lld)/asyncHistory/(%d)", conversationId, remoteMaxMid] options:options watcher:self];
                }
            }];
        }];
    }
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/conversations/"])
    {
        if (resultCode == ASStatusSuccess)
            [ActionStageInstance() actionCompleted:self.path result:[[NSDictionary alloc] initWithObjectsAndKeys:result, @"messages", [[NSNumber alloc] initWithBool:false], @"remote", nil]];
        else
            [ActionStageInstance() nodeRetrieveFailed:self.path];
    }
}

- (void)cancel
{
    [ActionStageInstance() removeWatcher:self];
    
    [super cancel];
}

@end
