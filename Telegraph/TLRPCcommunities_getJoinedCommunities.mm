#import "TLRPCcommunities_getJoinedCommunities.h"

#import "TLmessages_Chats.h"

@implementation TLRPCcommunities_getJoinedCommunities

- (int32_t)TLconstructorSignature
{
    return (int32_t)0xa663e830;
}

- (int32_t)TLconstructorName
{
    return -1;
}

- (Class)responseClass
{
    return [TLmessages_Chats class];
}

- (int)impliedResponseSignature
{
    return 0;
}

- (int)layerVersion
{
    return 228;
}

- (void)TLserialize:(NSOutputStream *)__unused os
{
}

@end
