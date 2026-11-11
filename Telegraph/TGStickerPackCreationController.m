#import "TGStickerPackCreationController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGPresentation.h"
#import "TGStickerCreationSignals.h"
#import "TGCollectionMultilineInputItem.h"
#import "TGUsernameCollectionItem.h"
#import "TGHeaderCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGCustomAlertView.h"

static const NSUInteger TGStickerPackTitleMaxLength = 64;
static const NSUInteger TGStickerPackShortNameMaxLength = 64;
static const NSTimeInterval TGStickerPackInputDelay = 0.4;

typedef enum {
    TGStickerPackShortNameStateEmpty,
    TGStickerPackShortNameStateInvalid,
    TGStickerPackShortNameStateChecking,
    TGStickerPackShortNameStateAvailable,
    TGStickerPackShortNameStateOccupied
} TGStickerPackShortNameState;

@interface TGStickerPackCreationController ()
{
    NSString *_title;
    NSString *_shortName;
    bool _shortNameEdited;
    bool _settingShortName;
    TGStickerPackShortNameState _shortNameState;

    TGCollectionMultilineInputItem *_titleItem;
    TGUsernameCollectionItem *_shortNameItem;
    TGCommentCollectionItem *_shortNameCommentItem;

    SMetaDisposable *_suggestDisposable;
    SMetaDisposable *_checkDisposable;
    SMetaDisposable *_createDisposable;
}

@end

@implementation TGStickerPackCreationController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _title = @"";
        _shortName = @"";
        _suggestDisposable = [[SMetaDisposable alloc] init];
        _checkDisposable = [[SMetaDisposable alloc] init];
        _createDisposable = [[SMetaDisposable alloc] init];

        self.title = TGLocalized(@"StickerPackCreation.Title");
        [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"StickerPackCreation.Create") style:UIBarButtonItemStyleDone target:self action:@selector(createPressed)] animated:false];

        __weak TGStickerPackCreationController *weakSelf = self;
        _titleItem = [[TGCollectionMultilineInputItem alloc] init];
        _titleItem.placeholder = TGLocalized(@"StickerPackCreation.NamePlaceholder");
        _titleItem.maxLength = TGStickerPackTitleMaxLength;
        _titleItem.disallowNewLines = true;
        _titleItem.returnKeyType = UIReturnKeyNext;
        _titleItem.textChanged = ^(NSString *text)
        {
            __strong TGStickerPackCreationController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf titleChanged:text];
        };
        _titleItem.returned = ^
        {
            __strong TGStickerPackCreationController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf->_shortNameItem becomeFirstResponder];
        };
        TGCollectionMenuSection *titleSection = [[TGCollectionMenuSection alloc] initWithItems:@[[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"StickerPackCreation.Name")], _titleItem]];
        titleSection.insets = UIEdgeInsetsMake(24.0f, 0.0f, 16.0f, 0.0f);
        [self.menuSections addSection:titleSection];

        _shortNameItem = [[TGUsernameCollectionItem alloc] init];
        _shortNameItem.title = @"";
        _shortNameItem.prefix = @"t.me/addstickers/";
        _shortNameItem.placeholder = TGLocalized(@"StickerPackCreation.LinkPlaceholder");
        _shortNameItem.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _shortNameItem.keyboardType = UIKeyboardTypeASCIICapable;
        _shortNameItem.returnKeyType = UIReturnKeyDone;
        _shortNameItem.usernameValid = true;
        _shortNameItem.shouldChangeText = ^bool(NSString *text)
        {
            return text.length <= TGStickerPackShortNameMaxLength;
        };
        _shortNameItem.usernameChanged = ^(NSString *text)
        {
            __strong TGStickerPackCreationController *strongSelf = weakSelf;
            if (strongSelf != nil && !strongSelf->_settingShortName)
            {
                strongSelf->_shortNameEdited = text.length != 0;
                [strongSelf shortNameChanged:text];
            }
        };
        _shortNameItem.returnPressed = ^(__unused TGUsernameCollectionItem *item)
        {
            __strong TGStickerPackCreationController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf createPressed];
        };
        _shortNameCommentItem = [[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"StickerPackCreation.LinkInfo")];
        TGCollectionMenuSection *shortNameSection = [[TGCollectionMenuSection alloc] initWithItems:@[[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"StickerPackCreation.Link")], _shortNameItem, _shortNameCommentItem]];
        [self.menuSections addSection:shortNameSection];

        [self updateState];
    }
    return self;
}

- (void)dealloc
{
    [_suggestDisposable dispose];
    [_checkDisposable dispose];
    [_createDisposable dispose];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_title.length == 0)
        [_titleItem becomeFirstResponder];
}

+ (bool)isValidShortName:(NSString *)shortName
{
    if (shortName.length == 0 || shortName.length > TGStickerPackShortNameMaxLength)
        return false;
    unichar previous = 0;
    for (NSUInteger i = 0; i < shortName.length; i++)
    {
        unichar c = [shortName characterAtIndex:i];
        bool letter = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
        bool digit = c >= '0' && c <= '9';
        if (i == 0 && !letter)
            return false;
        if (!letter && !digit && c != '_')
            return false;
        if (c == '_' && previous == '_')
            return false;
        previous = c;
    }
    return true;
}

- (NSString *)trimmedTitle
{
    return [_title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
}

- (void)titleChanged:(NSString *)text
{
    _title = text ?: @"";
    [self updateState];

    if (_shortNameEdited)
        return;

    NSString *title = [self trimmedTitle];
    if (title.length == 0)
    {
        [_suggestDisposable setDisposable:nil];
        [self setShortNameProgrammatically:@""];
        return;
    }

    __weak TGStickerPackCreationController *weakSelf = self;
    SSignal *signal = [[[[SSignal complete] delay:TGStickerPackInputDelay onQueue:[SQueue mainQueue]] then:[TGStickerCreationSignals suggestShortNameForTitle:title]] deliverOn:[SQueue mainQueue]];
    [_suggestDisposable setDisposable:[signal startWithNext:^(NSString *shortName)
    {
        __strong TGStickerPackCreationController *strongSelf = weakSelf;
        if (strongSelf != nil && !strongSelf->_shortNameEdited && shortName.length != 0)
            [strongSelf setShortNameProgrammatically:shortName];
    } error:nil completed:nil]];
}

- (void)setShortNameProgrammatically:(NSString *)shortName
{
    _settingShortName = true;
    _shortNameItem.username = shortName;
    _settingShortName = false;
    [self shortNameChanged:shortName];
}

- (void)shortNameChanged:(NSString *)text
{
    _shortName = text ?: @"";
    [_checkDisposable setDisposable:nil];

    if (_shortName.length == 0)
    {
        [self setShortNameState:TGStickerPackShortNameStateEmpty];
        return;
    }
    if (![TGStickerPackCreationController isValidShortName:_shortName])
    {
        [self setShortNameState:TGStickerPackShortNameStateInvalid];
        return;
    }

    [self setShortNameState:TGStickerPackShortNameStateChecking];
    NSString *shortName = _shortName;
    __weak TGStickerPackCreationController *weakSelf = self;
    SSignal *signal = [[[[SSignal complete] delay:TGStickerPackInputDelay onQueue:[SQueue mainQueue]] then:[TGStickerCreationSignals checkShortName:shortName]] deliverOn:[SQueue mainQueue]];
    [_checkDisposable setDisposable:[signal startWithNext:^(NSNumber *available)
    {
        __strong TGStickerPackCreationController *strongSelf = weakSelf;
        if (strongSelf != nil && [strongSelf->_shortName isEqualToString:shortName])
            [strongSelf setShortNameState:[available boolValue] ? TGStickerPackShortNameStateAvailable : TGStickerPackShortNameStateOccupied];
    } error:^(id error)
    {
        __strong TGStickerPackCreationController *strongSelf = weakSelf;
        if (strongSelf == nil || ![strongSelf->_shortName isEqualToString:shortName])
            return;
        NSString *type = [TGStickerCreationSignals errorTypeForError:error];
        if ([type isEqualToString:@"SHORT_NAME_OCCUPIED"])
            [strongSelf setShortNameState:TGStickerPackShortNameStateOccupied];
        else if ([type isEqualToString:@"SHORT_NAME_INVALID"])
            [strongSelf setShortNameState:TGStickerPackShortNameStateInvalid];
        else
            [strongSelf setShortNameState:TGStickerPackShortNameStateEmpty];
    } completed:nil]];
}

- (void)setShortNameState:(TGStickerPackShortNameState)state
{
    _shortNameState = state;
    [self updateState];
}

- (void)updateState
{
    NSString *comment = TGLocalized(@"StickerPackCreation.LinkInfo");
    UIColor *commentColor = nil;
    bool valid = true;
    bool checking = false;
    switch (_shortNameState)
    {
        case TGStickerPackShortNameStateInvalid:
            comment = TGLocalized(@"StickerPackCreation.LinkInvalid");
            commentColor = self.presentation.pallete.collectionMenuDestructiveColor;
            valid = false;
            break;
        case TGStickerPackShortNameStateChecking:
            comment = TGLocalized(@"StickerPackCreation.LinkChecking");
            checking = true;
            break;
        case TGStickerPackShortNameStateAvailable:
            comment = [[NSString alloc] initWithFormat:TGLocalized(@"StickerPackCreation.LinkAvailable"), _shortName];
            commentColor = self.presentation.pallete.collectionMenuAccentColor;
            break;
        case TGStickerPackShortNameStateOccupied:
            comment = TGLocalized(@"StickerPackCreation.LinkOccupied");
            commentColor = self.presentation.pallete.collectionMenuDestructiveColor;
            valid = false;
            break;
        default:
            break;
    }
    _shortNameItem.usernameValid = valid;
    _shortNameItem.usernameChecking = checking;
    _shortNameCommentItem.textColor = commentColor;
    _shortNameCommentItem.text = comment;

    self.navigationItem.rightBarButtonItem.enabled = [self trimmedTitle].length != 0 && _shortNameState == TGStickerPackShortNameStateAvailable;

    [self.collectionLayout invalidateLayout];
}

- (void)presentError:(NSString *)message
{
    [TGCustomAlertView presentAlertWithTitle:nil message:message cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
}

- (void)createPressed
{
    NSString *title = [self trimmedTitle];
    NSString *shortName = _shortName;
    if (title.length == 0 || _shortNameState != TGStickerPackShortNameStateAvailable || _createPack == nil)
        return;

    [self.view endEditing:true];

    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.1];

    __weak TGStickerPackCreationController *weakSelf = self;
    [_createDisposable setDisposable:[[[_createPack(title, shortName) take:1] deliverOn:[SQueue mainQueue]] startWithNext:^(__unused id result)
    {
        [progressWindow dismissWithSuccess];
        __strong TGStickerPackCreationController *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf->_completed != nil)
            strongSelf->_completed();
    } error:^(id error)
    {
        [progressWindow dismiss:true];
        __strong TGStickerPackCreationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        NSString *type = [TGStickerCreationSignals errorTypeForError:error];
        if ([type isEqualToString:@"SHORT_NAME_OCCUPIED"])
        {
            [strongSelf setShortNameState:TGStickerPackShortNameStateOccupied];
            [strongSelf presentError:TGLocalized(@"StickerPackCreation.LinkOccupied")];
        }
        else if ([type isEqualToString:@"SHORT_NAME_INVALID"])
        {
            [strongSelf setShortNameState:TGStickerPackShortNameStateInvalid];
            [strongSelf presentError:TGLocalized(@"StickerPackCreation.LinkInvalid")];
        }
        else if ([type isEqualToString:@"STICKER_EMOJI_INVALID"])
            [strongSelf presentError:TGLocalized(@"StickerCreation.ErrorEmoji")];
        else if ([type hasPrefix:@"FLOOD_WAIT"])
            [strongSelf presentError:TGLocalized(@"StickerCreation.ErrorFlood")];
        else
            [strongSelf presentError:TGLocalized(@"StickerCreation.ErrorGeneric")];
    } completed:nil]];
}

@end
