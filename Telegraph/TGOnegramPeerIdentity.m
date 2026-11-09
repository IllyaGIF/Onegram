#import "TGOnegramPeerIdentity.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGPeerIdAdapter.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGOnegramSettings.h"

@implementation TGOnegramCopyValueCollectionItem

- (void)itemSelected:(id)__unused actionTarget
{
    if (self.username.length == 0)
        return;
    [UIPasteboard generalPasteboard].string = self.username;
    [[[TGProgressWindow alloc] init] dismissWithSuccess];
}

@end

NSString *TGOnegramDisplayPeerId(int64_t peerId)
{
    return [[NSString alloc] initWithFormat:@"%lld", peerId];
}

NSArray *TGOnegramPeerIdentityItems(int64_t peerId, NSString *photoUrl)
{
    TGOnegramCopyValueCollectionItem *idItem = [[TGOnegramCopyValueCollectionItem alloc] initWithLabel:@"ID" username:TGOnegramDisplayPeerId(peerId)];
    idItem.deselectAutomatically = true;
    int32_t datacenterId = TGOnegramDatacenterForPhotoUrl(photoUrl);
    if (datacenterId == 0)
    {
        idItem.lastInList = true;
        return @[idItem];
    }
    TGOnegramCopyValueCollectionItem *dcItem = [[TGOnegramCopyValueCollectionItem alloc] initWithLabel:@"DC" username:[[NSString alloc] initWithFormat:@"%d", datacenterId]];
    dcItem.deselectAutomatically = true;
    dcItem.lastInList = true;
    return @[idItem, dcItem];
}
