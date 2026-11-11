#import "TGDialogFiltersController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGPresentation.h"
#import "TGDialogFilter.h"
#import "TGDialogFilterSignals.h"
#import "TGDialogFilterIcons.h"
#import "TGDialogFilterCollectionItem.h"
#import "TGDialogFilterEditController.h"
#import "TGHeaderCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGSwitchCollectionItem.h"
#import "TGCustomAlertView.h"
#import "TGCustomActionSheet.h"

@interface TGDialogFiltersController ()
{
    TGDialogFiltersState *_state;
    NSArray *_suggestions;
    NSArray *_originalOrder;
    bool _editing;
    bool _ready;

    TGCollectionMenuSection *_foldersSection;
    TGCollectionMenuSection *_suggestionsSection;
    TGCollectionMenuSection *_tagsSection;
    TGButtonCollectionItem *_createItem;
    TGSwitchCollectionItem *_tagsItem;

    SMetaDisposable *_stateDisposable;
    SMetaDisposable *_suggestionsDisposable;
    SMetaDisposable *_actionDisposable;
    UIActivityIndicatorView *_activityIndicator;
}

@end

@implementation TGDialogFiltersController

+ (NSString *)summaryForFilter:(TGDialogFilter *)filter
{
    if (filter == nil || filter.defaultFilter)
        return nil;
    NSMutableArray *parts = [[NSMutableArray alloc] init];
    if (filter.chatlist)
        [parts addObject:TGLocalized(@"DialogFilters.SharedFolder")];
    for (NSNumber *category in [TGDialogFilter includeCategories])
    {
        if (filter.flags & category.intValue)
            [parts addObject:[TGDialogFilter titleForCategory:(TGDialogFilterCategory)category.intValue]];
    }
    NSUInteger peerCount = [filter includedPeerIds].count;
    if (peerCount != 0)
        [parts addObject:[effectiveLocalization() getPluralized:@"DialogFilters.ChatCount" count:(int32_t)peerCount]];
    if (parts.count == 0)
        return TGLocalized(@"DialogFilters.NoChats");
    return [parts componentsJoinedByString:@", "];
}

+ (UIImage *)iconForFilter:(TGDialogFilter *)filter presentation:(TGPresentation *)presentation
{
    if (filter.emoticon.length != 0)
    {
        UIImage *image = TGDialogFilterEmoticonIcon(filter.emoticon, 30.0f);
        if (image != nil)
            return image;
    }
    UIColor *color = [TGDialogFilter colorForIndex:filter.color] ?: presentation.pallete.collectionMenuAccentColor;
    return TGDialogFilterFolderIcon(color ?: UIColorRGB(0x2f8cf0), 30.0f);
}

+ (SSignal *)signalWithProgress:(SSignal *)signal
{
    return [[SSignal defer:^SSignal *
    {
        TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
        [progressWindow showWithDelay:0.25];
        return [[signal deliverOn:[SQueue mainQueue]] onDispose:^
        {
            TGDispatchOnMainThread(^
            {
                [progressWindow dismiss:true];
            });
        }];
    }] startOn:[SQueue mainQueue]];
}

+ (void)presentError:(id)error
{
    [TGCustomAlertView presentAlertWithTitle:nil message:[TGDialogFilterSignals errorTextForError:error] cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
}

+ (void)presentActionSheetWithTitle:(NSString *)title actions:(NSArray *)actions controller:(UIViewController *)controller sourceRect:(CGRect)sourceRect actionBlock:(void (^)(NSString *action))actionBlock
{
    void (^block)(NSString *) = [actionBlock copy];
    UIView *view = controller.navigationController.view ?: controller.view;
    TGCustomActionSheet *sheet = [[TGCustomActionSheet alloc] initWithTitle:title actions:actions actionBlock:^(__unused id target, NSString *action)
    {
        if (block)
            block(action);
    } target:controller];
    if (TGIsPad() && !CGRectIsEmpty(sourceRect))
        [sheet showFromRect:sourceRect inView:controller.view animated:true];
    else
        [sheet showInView:view];
}

+ (void)performDeletion:(SSignal *)signal completion:(void (^)(bool))completion
{
    void (^block)(bool) = [completion copy];
    [[self signalWithProgress:signal] startWithNext:nil error:^(id error)
    {
        [self presentError:error];
        if (block)
            block(false);
    } completed:^
    {
        if (block)
            block(true);
    }];
}

+ (void)deleteFilter:(TGDialogFilter *)filter controller:(UIViewController *)controller completion:(void (^)(bool deleted))completion
{
    if (filter == nil || filter.defaultFilter)
        return;
    void (^block)(bool) = [completion copy];
    NSString *title = [NSString stringWithFormat:TGLocalized(@"DialogFilters.DeleteTitle"), filter.title];

    if (filter.chatlist && !filter.hasMyInvites)
    {
        [[self signalWithProgress:[TGDialogFilterSignals leaveSuggestionsForFilter:filter]] startWithNext:^(NSArray *peerIds)
        {
            NSMutableArray *actions = [[NSMutableArray alloc] init];
            if (peerIds.count != 0)
                [actions addObject:[[TGActionSheetAction alloc] initWithTitle:[effectiveLocalization() getPluralized:@"DialogFilters.DeleteAndLeave" count:(int32_t)peerIds.count] action:@"leave" type:TGActionSheetActionTypeDestructive]];
            [actions addObject:[[TGActionSheetAction alloc] initWithTitle:peerIds.count != 0 ? TGLocalized(@"DialogFilters.DeleteAndStay") : TGLocalized(@"DialogFilters.Delete") action:@"stay" type:peerIds.count != 0 ? TGActionSheetActionTypeGeneric : TGActionSheetActionTypeDestructive]];
            [actions addObject:[[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]];
            [self presentActionSheetWithTitle:title actions:actions controller:controller sourceRect:CGRectZero actionBlock:^(NSString *action)
            {
                if ([action isEqualToString:@"leave"])
                    [self performDeletion:[TGDialogFilterSignals leaveChatlist:filter peerIds:peerIds] completion:block];
                else if ([action isEqualToString:@"stay"])
                    [self performDeletion:[TGDialogFilterSignals leaveChatlist:filter peerIds:@[]] completion:block];
                else if (block)
                    block(false);
            }];
        } error:^(id error)
        {
            [self presentError:error];
            if (block)
                block(false);
        } completed:nil];
        return;
    }

    NSString *message = filter.hasMyInvites ? TGLocalized(@"DialogFilters.DeleteSharedInfo") : TGLocalized(@"DialogFilters.DeleteInfo");
    [TGCustomAlertView presentAlertWithTitle:title message:message cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"Common.Delete") destructive:true completionBlock:^(bool okButtonPressed)
    {
        if (okButtonPressed)
            [self performDeletion:[TGDialogFilterSignals deleteFilter:filter] completion:block];
        else if (block)
            block(false);
    } disableKeyboardWorkaround:false];
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.title = TGLocalized(@"DialogFilters.Title");

        _stateDisposable = [[SMetaDisposable alloc] init];
        _suggestionsDisposable = [[SMetaDisposable alloc] init];
        _actionDisposable = [[SMetaDisposable alloc] init];

        TGCommentCollectionItem *headerItem = [[TGCommentCollectionItem alloc] initWithFormattedText:TGLocalized(@"DialogFilters.Info") paragraphSpacing:0.0f clearFormatting:false alignment:NSTextAlignmentCenter];
        TGCollectionMenuSection *infoSection = [[TGCollectionMenuSection alloc] initWithItems:@[headerItem]];
        infoSection.insets = UIEdgeInsetsMake(16.0f, 0.0f, 0.0f, 0.0f);
        [self.menuSections addSection:infoSection];

        _createItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.Create") action:@selector(createPressed)];
        _createItem.icon = self.presentation.images.collectionMenuAddImage;
        _createItem.iconOffset = CGPointMake(0.0f, 0.0f);
        _createItem.leftInset = 50.0f;
        _createItem.deselectAutomatically = true;
        _foldersSection = [[TGCollectionMenuSection alloc] initWithItems:@[[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.MyFolders")], _createItem]];
        [self.menuSections addSection:_foldersSection];

        _suggestionsSection = [[TGCollectionMenuSection alloc] initWithItems:@[]];

        __weak TGDialogFiltersController *weakSelf = self;
        _tagsItem = [[TGSwitchCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.ShowTags") isOn:[TGDialogFilterSignals tagsVisible]];
        _tagsItem.toggled = ^(bool value, __unused TGSwitchCollectionItem *item)
        {
            __strong TGDialogFiltersController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf->_actionDisposable setDisposable:[[TGDialogFilterSignals setTagsVisible:value] startWithNext:nil]];
        };
        _tagsSection = [[TGCollectionMenuSection alloc] initWithItems:@[_tagsItem, [[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"DialogFilters.ShowTagsInfo")]]];
        [self.menuSections addSection:_tagsSection];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(filtersDidChange:) name:TGDialogFiltersDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverFiltersUpdated:) name:@"TGIOS6DialogFiltersUpdated" object:nil];

        [self reloadState];
        [self reloadSuggestions];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_stateDisposable dispose];
    [_suggestionsDisposable dispose];
    [_actionDisposable dispose];
}

- (void)loadView
{
    [super loadView];

    _createItem.icon = self.presentation.images.collectionMenuAddImage;
    if (!_ready)
    {
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        _activityIndicator.frame = CGRectMake(CGFloor((self.view.frame.size.width - _activityIndicator.frame.size.width) / 2.0f), CGFloor((self.view.frame.size.height - _activityIndicator.frame.size.height) / 2.0f), _activityIndicator.frame.size.width, _activityIndicator.frame.size.height);
        [self.view addSubview:_activityIndicator];
        [_activityIndicator startAnimating];
        self.collectionView.hidden = true;
    }
}

- (void)reloadState
{
    __weak TGDialogFiltersController *weakSelf = self;
    [_stateDisposable setDisposable:[[[TGDialogFilterSignals filters] deliverOn:[SQueue mainQueue]] startWithNext:^(TGDialogFiltersState *state)
    {
        __strong TGDialogFiltersController *strongSelf = weakSelf;
        if (strongSelf != nil && !strongSelf->_editing)
            [strongSelf setState:state];
    } error:^(id error)
    {
        __strong TGDialogFiltersController *strongSelf = weakSelf;
        if (strongSelf != nil && !strongSelf->_ready)
        {
            [strongSelf setState:[[TGDialogFiltersState alloc] initWithFilters:@[[TGDialogFilter defaultDialogFilter]] tagsEnabled:false]];
            [TGDialogFiltersController presentError:error];
        }
    } completed:nil]];
}

- (void)reloadSuggestions
{
    __weak TGDialogFiltersController *weakSelf = self;
    [_suggestionsDisposable setDisposable:[[[TGDialogFilterSignals suggestedFilters] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *suggestions)
    {
        __strong TGDialogFiltersController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_suggestions = suggestions;
        [strongSelf updateSuggestionsSection];
    } error:nil completed:nil]];
}

- (void)filtersDidChange:(NSNotification *)notification
{
    NSArray *filters = notification.userInfo[@"filters"];
    if ([filters isKindOfClass:[NSArray class]])
    {
        if (!_editing)
            [self setState:[[TGDialogFiltersState alloc] initWithFilters:filters tagsEnabled:[notification.userInfo[@"tagsEnabled"] boolValue]]];
        [self reloadSuggestions];
    }
    else
        _tagsItem.isOn = [TGDialogFilterSignals tagsVisible];
}

- (void)serverFiltersUpdated:(NSNotification *)__unused notification
{
    if (!_editing)
        [self reloadState];
}

- (NSArray *)userFilters
{
    NSMutableArray *filters = [[NSMutableArray alloc] init];
    for (TGDialogFilter *filter in _state.filters)
    {
        if (!filter.defaultFilter)
            [filters addObject:filter];
    }
    return filters;
}

- (void)setState:(TGDialogFiltersState *)state
{
    _state = state;
    if (!_ready)
    {
        _ready = true;
        [_activityIndicator stopAnimating];
        [_activityIndicator removeFromSuperview];
        _activityIndicator = nil;
        self.collectionView.hidden = false;
    }

    NSUInteger sectionIndex = [self indexForSection:_foldersSection];
    while (_foldersSection.items.count > 2)
        [self.menuSections deleteItemFromSection:sectionIndex atIndex:_foldersSection.items.count - 1];

    __weak TGDialogFiltersController *weakSelf = self;
    TGDialogFilterCollectionItem *allChatsItem = [[TGDialogFilterCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.AllChats") subtitle:TGLocalized(@"DialogFilters.AllChatsInfo") icon:TGDialogFilterFolderIcon(self.presentation.pallete.collectionMenuVariantColor ?: [UIColor grayColor], 30.0f)];
    allChatsItem.selectable = false;
    allChatsItem.highlightable = false;
    [self.menuSections addItemToSection:sectionIndex item:allChatsItem];

    NSMutableArray *order = [[NSMutableArray alloc] init];
    for (TGDialogFilter *filter in [self userFilters])
    {
        [order addObject:@(filter.filterId)];
        TGDialogFilterCollectionItem *item = [[TGDialogFilterCollectionItem alloc] initWithTitle:filter.title subtitle:[TGDialogFiltersController summaryForFilter:filter] icon:[TGDialogFiltersController iconForFilter:filter presentation:self.presentation]];
        item.representedObject = filter;
        item.showsDisclosure = true;
        item.enableEditing = true;
        item.pressed = ^
        {
            __strong TGDialogFiltersController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf editFilter:filter];
        };
        item.deletePressed = ^
        {
            __strong TGDialogFiltersController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [TGDialogFiltersController deleteFilter:filter controller:strongSelf completion:nil];
        };
        item.canBeMovedToSectionAtIndex = ^bool (NSUInteger targetSectionIndex, NSUInteger index)
        {
            __strong TGDialogFiltersController *strongSelf = weakSelf;
            if (strongSelf == nil || targetSectionIndex >= strongSelf.menuSections.sections.count)
                return false;
            TGCollectionMenuSection *section = strongSelf.menuSections.sections[targetSectionIndex];
            return section == strongSelf->_foldersSection && index >= 3 && index < section.items.count;
        };
        [self.menuSections addItemToSection:sectionIndex item:item];
    }
    _originalOrder = order;

    _tagsItem.isOn = [TGDialogFilterSignals tagsVisibleWithServerValue:state.tagsEnabled];
    [self updateEditButton];
    [self updateSuggestionsSection];
    [self.collectionView reloadData];

    if (_startsReordering && !_editing && [self userFilters].count > 1)
    {
        _startsReordering = false;
        __weak TGDialogFiltersController *weakController = self;
        dispatch_async(dispatch_get_main_queue(), ^
        {
            __strong TGDialogFiltersController *strongController = weakController;
            if (strongController != nil && !strongController->_editing)
                [strongController editPressed];
        });
    }
}

- (void)updateSuggestionsSection
{
    NSUInteger sectionIndex = [self indexForSection:_suggestionsSection];
    bool attached = sectionIndex != NSNotFound && sectionIndex < self.menuSections.sections.count && self.menuSections.sections[sectionIndex] == _suggestionsSection;
    bool show = _ready && !_editing && _suggestions.count != 0 && [self userFilters].count < [TGDialogFilterSignals folderLimit];

    NSMutableArray *items = [[NSMutableArray alloc] init];
    if (show)
    {
        [items addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.Recommended")]];
        __weak TGDialogFiltersController *weakSelf = self;
        for (TGDialogFilterSuggestion *suggestion in _suggestions)
        {
            TGDialogFilterCollectionItem *item = [[TGDialogFilterCollectionItem alloc] initWithTitle:suggestion.filter.title subtitle:suggestion.descriptionText icon:[TGDialogFiltersController iconForFilter:suggestion.filter presentation:self.presentation]];
            item.selectable = false;
            item.highlightable = false;
            item.addButtonTitle = TGLocalized(@"DialogFilters.Add");
            item.addPressed = ^
            {
                __strong TGDialogFiltersController *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf addSuggestion:suggestion];
            };
            [items addObject:item];
        }
    }

    if (show)
    {
        [_suggestionsSection replaceItems:items];
        if (!attached)
            [self.menuSections insertSection:_suggestionsSection atIndex:[self indexForSection:_tagsSection]];
    }
    else if (attached)
        [self.menuSections deleteSectionByReference:_suggestionsSection];
    [self.collectionView reloadData];
}

- (void)updateEditButton
{
    if (_editing)
    {
        [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(editCancelPressed)] animated:true];
        [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Done") style:UIBarButtonItemStyleDone target:self action:@selector(editDonePressed)] animated:true];
    }
    else
    {
        [self setLeftBarButtonItem:nil animated:true];
        if ([self userFilters].count != 0)
            [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Edit") style:UIBarButtonItemStylePlain target:self action:@selector(editPressed)] animated:true];
        else
            [self setRightBarButtonItem:nil animated:true];
    }
}

- (void)editPressed
{
    _editing = true;
    self.enableItemReorderingGestures = true;
    [self updateEditButton];
    [self updateSuggestionsSection];
    [self enterEditingMode:true];
}

- (void)finishEditing
{
    _editing = false;
    self.enableItemReorderingGestures = false;
    [self leaveEditingMode:true];
    [self updateEditButton];
    [self updateSuggestionsSection];
}

- (NSArray *)currentOrder
{
    NSMutableArray *order = [[NSMutableArray alloc] init];
    for (id item in _foldersSection.items)
    {
        if ([item isKindOfClass:[TGDialogFilterCollectionItem class]] && [((TGDialogFilterCollectionItem *)item).representedObject isKindOfClass:[TGDialogFilter class]])
            [order addObject:@(((TGDialogFilter *)((TGDialogFilterCollectionItem *)item).representedObject).filterId)];
    }
    return order;
}

- (void)editCancelPressed
{
    [self finishEditing];
    [self animateCollectionCrossfade];
    [self setState:_state];
}

- (void)editDonePressed
{
    NSArray *order = [self currentOrder];
    if ([order isEqualToArray:_originalOrder])
    {
        [self finishEditing];
        return;
    }

    NSMutableArray *serverOrder = [order mutableCopy];
    NSUInteger defaultIndex = 0;
    for (TGDialogFilter *filter in _state.filters)
    {
        if (filter.defaultFilter)
            break;
        defaultIndex++;
    }
    if (defaultIndex >= _state.filters.count)
        defaultIndex = 0;
    if ([TGDialogFilterSignals isPremium] || defaultIndex != 0)
        [serverOrder insertObject:@0 atIndex:MIN(defaultIndex, serverOrder.count)];

    __weak TGDialogFiltersController *weakSelf = self;
    [_actionDisposable setDisposable:[[TGDialogFiltersController signalWithProgress:[TGDialogFilterSignals reorderFilterIds:serverOrder]] startWithNext:^(TGDialogFiltersState *state)
    {
        __strong TGDialogFiltersController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        [strongSelf finishEditing];
        [strongSelf setState:state];
    } error:^(id error)
    {
        [TGDialogFiltersController presentError:error];
    } completed:nil]];
}

- (void)createPressed
{
    if (_editing)
        return;
    if ([self userFilters].count >= [TGDialogFilterSignals folderLimit])
    {
        [TGDialogFiltersController presentError:@"DIALOG_FILTERS_TOO_MUCH"];
        return;
    }
    [self.navigationController pushViewController:[[TGDialogFilterEditController alloc] initWithFilter:nil allFilters:_state.filters] animated:true];
}

- (void)editFilter:(TGDialogFilter *)filter
{
    if (_editing)
        return;
    [self.navigationController pushViewController:[[TGDialogFilterEditController alloc] initWithFilter:filter allFilters:_state.filters] animated:true];
}

- (void)addSuggestion:(TGDialogFilterSuggestion *)suggestion
{
    if ([self userFilters].count >= [TGDialogFilterSignals folderLimit])
    {
        [TGDialogFiltersController presentError:@"DIALOG_FILTERS_TOO_MUCH"];
        return;
    }
    int32_t filterId = [TGDialogFilterSignals unusedFilterIdForFilters:_state.filters];
    if (filterId == 0)
        return;
    TGDialogFilter *filter = [suggestion.filter copy];
    filter.filterId = filterId;
    __weak TGDialogFiltersController *weakSelf = self;
    [_actionDisposable setDisposable:[[TGDialogFiltersController signalWithProgress:[TGDialogFilterSignals saveFilter:filter]] startWithNext:^(TGDialogFiltersState *state)
    {
        __strong TGDialogFiltersController *strongSelf = weakSelf;
        if (strongSelf != nil && !strongSelf->_editing)
            [strongSelf setState:state];
    } error:^(id error)
    {
        [TGDialogFiltersController presentError:error];
    } completed:nil]];
}

@end
