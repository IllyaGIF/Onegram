#import "TGStarGiftSendController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGCollectionMenuSection.h"
#import "TGCollectionMultilineInputItem.h"
#import "TGSwitchCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGStarGiftHeaderCollectionItem.h"
#import "TGStarGift.h"
#import "TGStarGiftTileView.h"
#import "TGStarGiftsSignals.h"
#import "TGCustomAlertView.h"
#import "TGDatabase.h"
#import "TGPresentation.h"

@interface TGStarGiftSendController ()
{
    TGStarGift *_gift;
    int64_t _peerId;
    NSNumber *_balance;
    TGCollectionMultilineInputItem *_messageItem;
    TGSwitchCollectionItem *_hideNameItem;
    SMetaDisposable *_sendDisposable;
}

@end

@implementation TGStarGiftSendController

- (instancetype)initWithGift:(TGStarGift *)gift peerId:(int64_t)peerId balance:(NSNumber *)balance
{
    self = [super init];
    if (self != nil)
    {
        _gift = gift;
        _peerId = peerId;
        _balance = balance;
        _sendDisposable = [[SMetaDisposable alloc] init];
        [self setTitleText:TGLocalized(@"OnegramGifts.SendTitle")];

        NSString *recipient = TGPeerIdIsUser(peerId) ? [TGDatabaseInstance() loadUser:peerId].displayName : [TGDatabaseInstance() loadConversationWithId:peerId].chatTitle;
        TGStarGiftHeaderCollectionItem *headerItem = [[TGStarGiftHeaderCollectionItem alloc] init];
        headerItem.gift = gift;
        headerItem.title = TGStarGiftStarsString(gift.stars);
        headerItem.subtitle = recipient.length == 0 ? nil : [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.SendTo"), recipient];
        TGCollectionMenuSection *headerSection = [[TGCollectionMenuSection alloc] initWithItems:@[headerItem]];
        headerSection.insets = UIEdgeInsetsZero;
        [self.menuSections addSection:headerSection];

        _messageItem = [[TGCollectionMultilineInputItem alloc] init];
        _messageItem.placeholder = TGLocalized(@"OnegramGifts.MessagePlaceholder");
        _messageItem.maxLength = 255;
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[_messageItem]]];

        _hideNameItem = [[TGSwitchCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramGifts.HideName") isOn:false];
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[
            _hideNameItem,
            [[TGCommentCollectionItem alloc] initWithFormattedText:TGLocalized(@"OnegramGifts.HideNameInfo")]
        ]]];

        TGButtonCollectionItem *sendItem = [[TGButtonCollectionItem alloc] initWithTitle:[[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.SendFor"), TGStarGiftStarsString(gift.stars)] action:@selector(sendPressed)];
        sendItem.alignment = NSTextAlignmentCenter;
        sendItem.deselectAutomatically = true;
        sendItem.titleColor = [TGPresentation current].pallete.collectionMenuAccentColor;
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[sendItem]]];
    }
    return self;
}

- (void)dealloc
{
    [_sendDisposable dispose];
}

- (void)sendPressed
{
    [self.view endEditing:true];
    if (_balance != nil && [_balance longLongValue] < _gift.stars)
    {
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramGifts.NotEnoughStars") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
        return;
    }
    __weak TGStarGiftSendController *weakSelf = self;
    NSString *message = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.SendConfirm"), TGStarGiftStarsString(_gift.stars)];
    [TGCustomAlertView presentAlertWithTitle:nil message:message cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"OnegramGifts.Send") completionBlock:^(bool okButtonPressed)
    {
        __strong TGStarGiftSendController *strongSelf = weakSelf;
        if (strongSelf != nil && okButtonPressed)
            [strongSelf commitSend];
    }];
}

- (void)commitSend
{
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow show:true];
    __weak TGStarGiftSendController *weakSelf = self;
    [_sendDisposable setDisposable:[[[TGStarGiftsSignals sendGiftWithId:_gift.giftId toPeerId:_peerId message:_messageItem.text hideName:_hideNameItem.isOn] deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error)
    {
        [progressWindow dismiss:true];
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramGifts.SendFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    } completed:^
    {
        [progressWindow dismissWithSuccess];
        __strong TGStarGiftSendController *strongSelf = weakSelf;
        [strongSelf.navigationController.presentingViewController dismissViewControllerAnimated:true completion:nil];
    }]];
}

@end
