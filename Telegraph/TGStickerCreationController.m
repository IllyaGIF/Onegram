#import "TGStickerCreationController.h"

#import <objc/runtime.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGPresentation.h"
#import "TGStickerCreationSignals.h"
#import "TGStickerCreationPreviewItem.h"
#import "TGStickerPackCreationController.h"
#import "TGCollectionMultilineInputItem.h"
#import "TGHeaderCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGSwitchCollectionItem.h"
#import "TGCustomAlertView.h"
#import "TGCustomActionSheet.h"

static const NSUInteger TGStickerCreationEmojiMaxLength = 16;
static char TGStickerCreationImagePickerKey;

@interface TGStickerCreationImagePicker : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, copy) void (^completion)(UIImage *image);
@property (nonatomic, strong) UIPopoverController *popoverController;

@end

@implementation TGStickerCreationImagePicker

- (void)finishWithPicker:(UIImagePickerController *)picker image:(UIImage *)image
{
    void (^completion)(UIImage *) = _completion;
    _completion = nil;
    UIPopoverController *popoverController = _popoverController;
    _popoverController = nil;
    picker.delegate = nil;

    void (^finish)(void) = ^
    {
        if (completion != nil && image != nil)
            completion(image);
        objc_setAssociatedObject(picker, &TGStickerCreationImagePickerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    };

    if (popoverController != nil)
    {
        [popoverController dismissPopoverAnimated:true];
        finish();
    }
    else
        [picker.presentingViewController dismissViewControllerAnimated:true completion:finish];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    [self finishWithPicker:picker image:image];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self finishWithPicker:picker image:nil];
}

@end

@interface TGStickerCreationController ()
{
    UIImage *_sourceImage;
    UIImage *_foregroundImage;
    UIImage *_stickerImage;
    bool _removeBackground;
    bool _processing;
    NSString *_emoji;

    TGDocumentMediaAttachment *_uploadedDocument;
    NSString *_uploadedKey;

    TGStickerCreationPreviewItem *_previewItem;
    TGSwitchCollectionItem *_removeBackgroundItem;
    TGCollectionMultilineInputItem *_emojiItem;
    TGButtonCollectionItem *_sendItem;
    TGButtonCollectionItem *_addToPackItem;
    TGButtonCollectionItem *_createPackItem;

    SMetaDisposable *_processingDisposable;
    SMetaDisposable *_actionDisposable;
}

@end

@implementation TGStickerCreationController

+ (void)presentFromController:(UIViewController *)parentController sourceView:(UIView *)sourceView sendSticker:(void (^)(TGDocumentMediaAttachment *))sendSticker
{
    if (parentController == nil)
        return;

    void (^presentPicker)(UIImagePickerControllerSourceType) = ^(UIImagePickerControllerSourceType sourceType)
    {
        if (![UIImagePickerController isSourceTypeAvailable:sourceType])
            return;

        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType = sourceType;
        picker.allowsEditing = true;

        TGStickerCreationImagePicker *helper = [[TGStickerCreationImagePicker alloc] init];
        __weak UIViewController *weakParentController = parentController;
        helper.completion = ^(UIImage *image)
        {
            __strong UIViewController *strongParentController = weakParentController;
            if (strongParentController == nil)
                return;
            TGStickerCreationController *controller = [[TGStickerCreationController alloc] initWithImage:image];
            controller.sendSticker = sendSticker;
            TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[controller]];
            if (TGIsPad())
            {
                navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
                navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
            }
            [strongParentController presentViewController:navigationController animated:true completion:nil];
        };
        picker.delegate = helper;
        objc_setAssociatedObject(picker, &TGStickerCreationImagePickerKey, helper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        if (TGIsPad() && sourceType != UIImagePickerControllerSourceTypeCamera && iosMajorVersion() < 8)
        {
            UIView *anchorView = sourceView ?: parentController.view;
            helper.popoverController = [[UIPopoverController alloc] initWithContentViewController:picker];
            [helper.popoverController presentPopoverFromRect:anchorView.bounds inView:anchorView permittedArrowDirections:UIPopoverArrowDirectionAny animated:true];
        }
        else
        {
            [parentController presentViewController:picker animated:true completion:nil];
        }
    };

    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        presentPicker(UIImagePickerControllerSourceTypePhotoLibrary);
        return;
    }

    NSArray *actions = @[
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.ChoosePhoto") action:@"library"],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.TakePhoto") action:@"camera"],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]
    ];
    TGCustomActionSheet *actionSheet = [[TGCustomActionSheet alloc] initWithTitle:nil actions:actions actionBlock:^(__unused id target, NSString *action)
    {
        if ([action isEqualToString:@"library"])
            presentPicker(UIImagePickerControllerSourceTypePhotoLibrary);
        else if ([action isEqualToString:@"camera"])
            presentPicker(UIImagePickerControllerSourceTypeCamera);
    } target:parentController];
    if (sourceView != nil && TGIsPad())
        [actionSheet showFromRect:sourceView.bounds inView:sourceView animated:true];
    else
        [actionSheet showInView:parentController.view];
}

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super init];
    if (self != nil)
    {
        _sourceImage = image;
        _stickerImage = [TGStickerCreationSignals stickerImageFromImage:image];
        _emoji = @"\U0001F642";
        _processingDisposable = [[SMetaDisposable alloc] init];
        _actionDisposable = [[SMetaDisposable alloc] init];

        self.title = TGLocalized(@"StickerCreation.Title");
        [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelPressed)] animated:false];

        _previewItem = [[TGStickerCreationPreviewItem alloc] init];
        _previewItem.image = _stickerImage;
        TGCollectionMenuSection *previewSection = [[TGCollectionMenuSection alloc] initWithItems:@[_previewItem]];
        previewSection.insets = UIEdgeInsetsMake(8.0f, 0.0f, 0.0f, 0.0f);
        [self.menuSections addSection:previewSection];

        __weak TGStickerCreationController *weakSelf = self;
        if ([TGStickerCreationSignals canRemoveBackground])
        {
            _removeBackgroundItem = [[TGSwitchCollectionItem alloc] initWithTitle:TGLocalized(@"StickerCreation.RemoveBackground") isOn:false];
            _removeBackgroundItem.toggled = ^(bool value, __unused TGSwitchCollectionItem *item)
            {
                __strong TGStickerCreationController *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf setRemoveBackground:value];
            };
            TGCollectionMenuSection *backgroundSection = [[TGCollectionMenuSection alloc] initWithItems:@[_removeBackgroundItem, [[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"StickerCreation.RemoveBackgroundInfo")]]];
            [self.menuSections addSection:backgroundSection];
        }

        _emojiItem = [[TGCollectionMultilineInputItem alloc] init];
        _emojiItem.placeholder = TGLocalized(@"StickerCreation.EmojiPlaceholder");
        _emojiItem.text = _emoji;
        _emojiItem.maxLength = TGStickerCreationEmojiMaxLength;
        _emojiItem.disallowNewLines = true;
        _emojiItem.returnKeyType = UIReturnKeyDone;
        _emojiItem.textChanged = ^(NSString *text)
        {
            __strong TGStickerCreationController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            strongSelf->_emoji = text ?: @"";
            [strongSelf updateActions];
        };
        _emojiItem.returned = ^
        {
            __strong TGStickerCreationController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf.view endEditing:true];
        };
        TGCollectionMenuSection *emojiSection = [[TGCollectionMenuSection alloc] initWithItems:@[[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"StickerCreation.Emoji")], _emojiItem]];
        [self.menuSections addSection:emojiSection];

        _sendItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"StickerCreation.Send") action:@selector(sendPressed)];
        _sendItem.deselectAutomatically = true;
        _addToPackItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"StickerCreation.AddToPack") action:@selector(addToPackPressed)];
        _addToPackItem.deselectAutomatically = true;
        _createPackItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"StickerCreation.CreatePack") action:@selector(createPackPressed)];
        _createPackItem.deselectAutomatically = true;
        NSMutableArray *actionItems = [[NSMutableArray alloc] init];
        [actionItems addObject:_sendItem];
        [actionItems addObject:_addToPackItem];
        [actionItems addObject:_createPackItem];
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:actionItems]];

        [self updateActions];
    }
    return self;
}

- (void)dealloc
{
    [_processingDisposable dispose];
    [_actionDisposable dispose];
}

- (void)setSendSticker:(void (^)(TGDocumentMediaAttachment *))sendSticker
{
    _sendSticker = [sendSticker copy];
    [self updateActions];
}

- (NSString *)currentEmoji
{
    return [_emoji stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
}

- (void)updateActions
{
    bool enabled = !_processing && _stickerImage != nil && [self currentEmoji].length != 0;
    _sendItem.enabled = enabled && _sendSticker != nil;
    _addToPackItem.enabled = enabled;
    _createPackItem.enabled = enabled;
    _removeBackgroundItem.isEnabled = !_processing;
}

- (void)setProcessing:(bool)processing
{
    _processing = processing;
    _previewItem.processing = processing;
    [self updateActions];
}

- (void)applyImage:(UIImage *)image
{
    _stickerImage = [TGStickerCreationSignals stickerImageFromImage:image];
    _previewItem.image = _stickerImage;
    [self updateActions];
}

- (void)setRemoveBackground:(bool)removeBackground
{
    _removeBackground = removeBackground;
    if (!removeBackground)
    {
        [_processingDisposable setDisposable:nil];
        [self setProcessing:false];
        [self applyImage:_sourceImage];
        return;
    }

    if (_foregroundImage != nil)
    {
        [self applyImage:_foregroundImage];
        return;
    }

    [self setProcessing:true];
    __weak TGStickerCreationController *weakSelf = self;
    [_processingDisposable setDisposable:[[[TGStickerCreationSignals foregroundImageFromImage:_sourceImage] deliverOn:[SQueue mainQueue]] startWithNext:^(UIImage *image)
    {
        __strong TGStickerCreationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_foregroundImage = image;
        [strongSelf setProcessing:false];
        if (strongSelf->_removeBackground)
            [strongSelf applyImage:image];
    } error:^(__unused id error)
    {
        __strong TGStickerCreationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_removeBackground = false;
        [strongSelf->_removeBackgroundItem setIsOn:false animated:true];
        [strongSelf setProcessing:false];
        [strongSelf presentError:TGLocalized(@"StickerCreation.RemoveBackgroundFailed")];
    } completed:nil]];
}

- (NSString *)uploadKey
{
    return [[NSString alloc] initWithFormat:@"%d:%@", _removeBackground ? 1 : 0, [self currentEmoji]];
}

- (SSignal *)preparedDocumentSignal
{
    NSString *key = [self uploadKey];
    if (_uploadedDocument != nil && [_uploadedKey isEqualToString:key])
        return [SSignal single:_uploadedDocument];

    UIImage *stickerImage = _stickerImage;
    NSString *emoji = [self currentEmoji];
    CGSize size = CGSizeMake(stickerImage.size.width * stickerImage.scale, stickerImage.size.height * stickerImage.scale);
    __weak TGStickerCreationController *weakSelf = self;
    return [[[[TGStickerCreationSignals stickerDataFromImage:stickerImage] mapToSignal:^SSignal *(NSData *data)
    {
        return [TGStickerCreationSignals uploadStickerData:data size:size emoji:emoji];
    }] deliverOn:[SQueue mainQueue]] onNext:^(TGDocumentMediaAttachment *document)
    {
        __strong TGStickerCreationController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_uploadedDocument = document;
            strongSelf->_uploadedKey = key;
        }
    }];
}

- (void)presentError:(NSString *)message
{
    [TGCustomAlertView presentAlertWithTitle:nil message:message cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
}

+ (NSString *)messageForError:(id)error
{
    NSString *type = [TGStickerCreationSignals errorTypeForError:error];
    if ([type isEqualToString:@"STICKERS_TOO_MUCH"])
        return TGLocalized(@"StickerCreation.ErrorTooMany");
    if ([type isEqualToString:@"STICKER_EMOJI_INVALID"])
        return TGLocalized(@"StickerCreation.ErrorEmoji");
    if ([type hasPrefix:@"FLOOD_WAIT"])
        return TGLocalized(@"StickerCreation.ErrorFlood");
    return TGLocalized(@"StickerCreation.ErrorGeneric");
}

- (void)dismiss
{
    [_processingDisposable setDisposable:nil];
    [_actionDisposable setDisposable:nil];
    [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
}

- (void)cancelPressed
{
    [self.view endEditing:true];
    [self dismiss];
}

- (void)performWithDocument:(SSignal *(^)(TGDocumentMediaAttachment *document))action completion:(void (^)(TGDocumentMediaAttachment *document))completion
{
    [self.view endEditing:true];

    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.1];

    SSignal *signal = [[[self preparedDocumentSignal] mapToSignal:^SSignal *(TGDocumentMediaAttachment *document)
    {
        if (action == nil)
            return [SSignal single:document];
        return [[action(document) take:1] map:^id(__unused id result)
        {
            return document;
        }];
    }] deliverOn:[SQueue mainQueue]];

    __weak TGStickerCreationController *weakSelf = self;
    [_actionDisposable setDisposable:[signal startWithNext:^(TGDocumentMediaAttachment *document)
    {
        [progressWindow dismissWithSuccess];
        __strong TGStickerCreationController *strongSelf = weakSelf;
        if (strongSelf != nil && completion != nil)
            completion(document);
    } error:^(id error)
    {
        [progressWindow dismiss:true];
        __strong TGStickerCreationController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf presentError:[TGStickerCreationController messageForError:error]];
    } completed:nil]];
}

- (void)sendPressed
{
    if (!_sendItem.enabled)
        return;
    __weak TGStickerCreationController *weakSelf = self;
    [self performWithDocument:nil completion:^(TGDocumentMediaAttachment *document)
    {
        __strong TGStickerCreationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        void (^sendSticker)(TGDocumentMediaAttachment *) = strongSelf->_sendSticker;
        [strongSelf dismiss];
        if (sendSticker != nil)
            sendSticker(document);
    }];
}

- (void)addToPackPressed
{
    if (!_addToPackItem.enabled)
        return;
    [self.view endEditing:true];

    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.1];

    __weak TGStickerCreationController *weakSelf = self;
    [_actionDisposable setDisposable:[[[TGStickerCreationSignals myStickerPacks] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *packs)
    {
        [progressWindow dismiss:true];
        __strong TGStickerCreationController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf choosePackFrom:packs];
    } error:^(id error)
    {
        [progressWindow dismiss:true];
        __strong TGStickerCreationController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf presentError:[TGStickerCreationController messageForError:error]];
    } completed:nil]];
}

- (void)choosePackFrom:(NSArray *)packs
{
    if (packs.count == 0)
    {
        [self createPackPressed];
        return;
    }

    NSMutableArray *actions = [[NSMutableArray alloc] init];
    [packs enumerateObjectsUsingBlock:^(TGStickerCreationPack *pack, NSUInteger index, __unused BOOL *stop)
    {
        [actions addObject:[[TGActionSheetAction alloc] initWithTitle:pack.title.length != 0 ? pack.title : pack.shortName action:[[NSString alloc] initWithFormat:@"%d", (int)index]]];
    }];
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"StickerCreation.CreatePack") action:@"create"]];
    [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];

    __weak TGStickerCreationController *weakSelf = self;
    TGCustomActionSheet *actionSheet = [[TGCustomActionSheet alloc] initWithTitle:TGLocalized(@"StickerCreation.ChoosePack") actions:actions actionBlock:^(__unused id target, NSString *action)
    {
        __strong TGStickerCreationController *strongSelf = weakSelf;
        if (strongSelf == nil || [action isEqualToString:@"cancel"])
            return;
        if ([action isEqualToString:@"create"])
        {
            [strongSelf createPackPressed];
            return;
        }
        NSInteger index = [action integerValue];
        if (index >= 0 && index < (NSInteger)packs.count)
            [strongSelf addToPack:packs[index]];
    } target:self];
    [actionSheet showInView:self.view];
}

- (void)addToPack:(TGStickerCreationPack *)pack
{
    NSString *emoji = [self currentEmoji];
    __weak TGStickerCreationController *weakSelf = self;
    [self performWithDocument:^SSignal *(TGDocumentMediaAttachment *document)
    {
        return [TGStickerCreationSignals addSticker:document emoji:emoji toPack:pack];
    } completion:^(__unused TGDocumentMediaAttachment *document)
    {
        __strong TGStickerCreationController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf dismiss];
    }];
}

- (void)createPackPressed
{
    if (!_createPackItem.enabled)
        return;
    [self.view endEditing:true];

    NSString *emoji = [self currentEmoji];
    __weak TGStickerCreationController *weakSelf = self;
    TGStickerPackCreationController *packController = [[TGStickerPackCreationController alloc] init];
    packController.createPack = ^SSignal *(NSString *title, NSString *shortName)
    {
        __strong TGStickerCreationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return [SSignal fail:nil];
        return [[strongSelf preparedDocumentSignal] mapToSignal:^SSignal *(TGDocumentMediaAttachment *document)
        {
            return [TGStickerCreationSignals createPackWithTitle:title shortName:shortName sticker:document emoji:emoji];
        }];
    };
    packController.completed = ^
    {
        __strong TGStickerCreationController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf dismiss];
    };
    [self.navigationController pushViewController:packController animated:true];
}

@end
