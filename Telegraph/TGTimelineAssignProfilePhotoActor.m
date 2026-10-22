#import "TGTimelineAssignProfilePhotoActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TGUser+Telegraph.h"
#import "TGTelegraph.h"
#import "TGDatabase.h"

#import "TGUserDataRequestBuilder.h"

#import "TGImageInfo+Telegraph.h"
#import "TLUser$modernUser.h"

@implementation TGTimelineAssignProfilePhotoActor

+ (NSString *)genericPath
{
    return @"/tg/timeline/@/assignProfilePhoto/@";
}

- (id)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        NSRange range = [self.path rangeOfString:@")/assignProfilePhoto/"];
        int timelineId = [[self.path substringWithRange:NSMakeRange(14, range.location - 14)] intValue];
        self.requestQueueName = [NSString stringWithFormat:@"timeline/%d", timelineId];
    }
    return self;
}

- (void)execute:(NSDictionary *)__unused options
{
    TGLog(@"Method currently unsupported");
    [ActionStageInstance() actionFailed:self.path reason:-1];
}

+ (TLUserProfilePhoto *)selfProfilePhotoFromResult:(TLphotos_Photo *)result
{
    for (TLUser *userDesc in result.users)
    {
        if ([userDesc isKindOfClass:[TLUser$modernUser class]] && ((TLUser$modernUser *)userDesc).n_id == TGTelegraphInstance.clientUserId)
            return ((TLUser$modernUser *)userDesc).photo;
    }
    return nil;
}

- (void)assignProfilePhotoRequestSuccess:(TLphotos_Photo *)result
{
    TLUserProfilePhoto *photo = [TGTimelineAssignProfilePhotoActor selfProfilePhotoFromResult:result];
    if ([photo isKindOfClass:[TLUserProfilePhoto$userProfilePhoto class]])
    {
        TLUserProfilePhoto$userProfilePhoto *concretePhoto = (TLUserProfilePhoto$userProfilePhoto *)photo;
        
        TGUser *originalUser = [[TGDatabase instance] loadUser:TGTelegraphInstance.clientUserId];
        TGUser *selfUser = [originalUser copy];
        if (selfUser != nil)
        {
            selfUser.photoUrlSmall = extractFileUrl(concretePhoto.photo_small);
            selfUser.photoUrlMedium = nil;
            selfUser.photoUrlBig = extractFileUrl(concretePhoto.photo_big);
            
            [TGUserDataRequestBuilder executeUserObjectsUpdate:[NSArray arrayWithObject:selfUser]];
        }
    }
    
    [ActionStageInstance() actionCompleted:self.path result:nil];
}

- (void)assignProfilePhotoRequestFailed
{
    [ActionStageInstance() actionFailed:self.path reason:-1];
}

@end
