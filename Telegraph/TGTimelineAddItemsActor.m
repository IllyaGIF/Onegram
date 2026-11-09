#import "TGTimelineAddItemsActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"

@implementation TGTimelineAddItemsActor

- (void)prepare:(NSDictionary *)options
{
    int64_t timelineId = [[options objectForKey:@"timelineId"] longLongValue];
    self.requestQueueName = [NSString stringWithFormat:@"timeline/%lld", timelineId];
}

- (void)execute:(NSDictionary *)options
{
    int64_t timelineId = [[options objectForKey:@"timelineId"] longLongValue];
    NSArray *items = [options objectForKey:@"items"];
    if (items == nil || items.count == 0)
        [ActionStageInstance() actionCompleted:self.path result:nil];
    
    [ActionStageInstance() dispatchResource:[[NSString alloc] initWithFormat:@"/tg/timeline/(%lld)/items", timelineId] resource:[[SGraphObjectNode alloc] initWithObject:items]];
}

@end
