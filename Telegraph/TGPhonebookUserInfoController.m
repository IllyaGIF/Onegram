#import "TGPhonebookUserInfoController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "../OnegramPlatform/OGPlatformUIKit.h"

#import "TGDatabase.h"
#import "TGTelegraph.h"

#import "TGUserInfoCollectionItem.h"
#import "TGUserInfoPhoneCollectionItem.h"
#import "TGUserInfoButtonCollectionItem.h"

#import "TGCustomActionSheet.h"

#import "TGPresentation.h"

#import "TGContactsController.h"

@interface TGPhonebookUserInfoController ()
{
    TGPhonebookContact *_phonebookInfo;
    TGUserInfoButtonCollectionItem *_inviteItem;
}

@end

@implementation TGPhonebookUserInfoController

- (instancetype)initWithNativeContactId:(int)nativeContactId
{
    self = [super init];
    if (self != nil)
    {
        [self setTitleText:TGLocalized(@"UserInfo.Title")];
        
        _phonebookInfo = [TGDatabaseInstance() phonebookContactByNativeId:nativeContactId];
        if (_phonebookInfo != nil)
        {
            TGUser *user = [[TGUser alloc] init];
            user.firstName = _phonebookInfo.firstName;
            user.lastName = _phonebookInfo.lastName;
            self.userInfoItem.automaticallyManageUserPresence = false;
            [self.userInfoItem setUser:user animated:false];
            
            NSUInteger phonesSectionIndex = [self indexForSection:self.phonesSection];
            
            for (TGPhoneNumber *phoneNumber in _phonebookInfo.phoneNumbers)
            {
                TGUserInfoPhoneCollectionItem *phoneItem = [[TGUserInfoPhoneCollectionItem alloc] initWithLabel:phoneNumber.label phone:phoneNumber.number phoneColor:self.presentation.pallete.collectionMenuAccentColor action:@selector(phonePressed:)];
                
                if (phonesSectionIndex != NSNotFound)
                    [self.menuSections insertItem:phoneItem toSection:phonesSectionIndex atIndex:self.phonesSection.items.count];
            }
            
            if (_phonebookInfo.phoneNumbers.count != 0)
            {
                NSUInteger actionsSectionIndex = [self indexForSection:self.actionsSection];
                
                _inviteItem = [[TGUserInfoButtonCollectionItem alloc] initWithTitle:TGLocalized(@"UserInfo.Invite") action:@selector(invitePressed)];
                _inviteItem.deselectAutomatically = true;
                _inviteItem.titleColor = self.presentation.pallete.dialogEncryptedColor;
                if (actionsSectionIndex != NSNotFound)
                    [self.menuSections insertItem:_inviteItem toSection:actionsSectionIndex atIndex:self.actionsSection.items.count];
            }
        }
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    _inviteItem.titleColor = presentation.pallete.dialogEncryptedColor;
}

- (void)phonePressed:(id)__unused sender {
}

- (void)invitePressed
{
    if (_phonebookInfo.phoneNumbers.count == 0)
        return;
    
    if (_phonebookInfo.phoneNumbers.count == 1)
        [self _inviteWithPhoneNumber:((TGPhoneNumber *)_phonebookInfo.phoneNumbers[0]).number];
    else
    {
        NSMutableArray *actions = [[NSMutableArray alloc] init];
        for (TGPhoneNumber *phoneNumber in _phonebookInfo.phoneNumbers)
        {
            if (phoneNumber.number.length != 0)
            {
                [actions addObject:[[TGActionSheetAction alloc] initWithTitle:[[NSString alloc] initWithFormat:@"%@: %@", phoneNumber.label, [TGPhoneUtils formatPhone:phoneNumber.number forceInternational:false]] action:phoneNumber.number]];
            }
        }
        
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];
        
        [[[TGCustomActionSheet alloc] initWithTitle:nil actions:actions actionBlock:^(TGPhonebookUserInfoController *controller, NSString *action)
        {
            if (![action isEqualToString:@"cancel"])
                [controller _inviteWithPhoneNumber:action];
        } target:self] showInView:self.view];
    }
}

- (void)_inviteWithPhoneNumber:(NSString *)phoneNumber
{
    if (OGPlatformCanSendTextMessage())
    {
        NSArray *recipients = [[NSArray alloc] initWithObjects:phoneNumber, nil];
        NSString *body = [NSString stringWithFormat:TGLocalized(@"InviteText.SingleContact"), [TGContactsController downloadLink]];
        id messageComposer = OGPlatformCreateTextMessageComposer(self, recipients, body);
        
        if (messageComposer != nil)
        {
            [self presentViewController:messageComposer animated:true completion:nil];
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque];
        }
        else
        {
            OGPlatformOpenTextMessage(recipients);
        }
    }
}

- (void)messageComposeViewController:(id)__unused controller didFinishWithResult:(NSInteger)__unused result
{
    [self dismissViewControllerAnimated:true completion:nil];
}

@end
