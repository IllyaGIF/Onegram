#import "TGDialogFilterEditController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGDialogFilter.h"
#import "TGDialogFilterSignals.h"
#import "TGDialogFiltersController.h"
#import "TGDialogFilterPeersController.h"
#import "TGDialogFilterInviteController.h"
#import "TGDialogFilterCollectionItem.h"
#import "TGDialogFilterCategoryCollectionItem.h"
#import "TGDialogFilterIconsCollectionItem.h"
#import "TGDialogFilterColorsCollectionItem.h"
#import "TGGroupInfoUserCollectionItem.h"
#import "TGHeaderCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGCollectionMultilineInputItem.h"
#import "TGCustomAlertView.h"

static const NSUInteger TGDialogFilterEditCollapsedRowCount = 8;

@interface TGDialogFilterEditController ()
{
    TGDialogFilter *_originalFilter;
    TGDialogFilter *_filter;
    NSArray *_allFilters;
    bool _isNew;
    NSArray *_invites;
    bool _includeExpanded;
    bool _excludeExpanded;
    bool _didAppear;
    NSDictionary *_conversations;

    TGCollectionMultilineInputItem *_nameItem;
    TGDialogFilterIconsCollectionItem *_iconsItem;
    TGDialogFilterColorsCollectionItem *_colorsItem;
    TGCommentCollectionItem *_colorFooterItem;

    TGCollectionMenuSection *_includeSection;
    TGCollectionMenuSection *_excludeSection;
    TGCollectionMenuSection *_colorSection;
    TGCollectionMenuSection *_inviteSection;
    TGCollectionMenuSection *_deleteSection;

    SMetaDisposable *_saveDisposable;
    SMetaDisposable *_invitesDisposable;
}

@end

@implementation TGDialogFilterEditController

- (instancetype)initWithFilter:(TGDialogFilter *)filter allFilters:(NSArray *)allFilters
{
    self = [super init];
    if (self != nil)
    {
        _isNew = filter == nil;
        _originalFilter = [filter copy];
        _filter = filter == nil ? [TGDialogFilter emptyFilterWithId:0] : [filter copy];
        _allFilters = allFilters == nil ? @[] : allFilters;
        _saveDisposable = [[SMetaDisposable alloc] init];
        _invitesDisposable = [[SMetaDisposable alloc] init];
        _conversations = [TGDialogFilterPeersController conversationsById];

        self.title = _isNew ? TGLocalized(@"DialogFilters.NewFolder") : TGLocalized(@"DialogFilters.EditFolder");
        [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelPressed)] animated:false];
        [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Done") style:UIBarButtonItemStyleDone target:self action:@selector(donePressed)] animated:false];

        __weak TGDialogFilterEditController *weakSelf = self;

        _nameItem = [[TGCollectionMultilineInputItem alloc] init];
        _nameItem.placeholder = TGLocalized(@"DialogFilters.NamePlaceholder");
        _nameItem.text = _filter.title;
        _nameItem.maxLength = TGDialogFilterTitleMaxLength;
        _nameItem.disallowNewLines = true;
        _nameItem.showRemainingCount = true;
        _nameItem.returnKeyType = UIReturnKeyDone;
        _nameItem.textChanged = ^(NSString *text)
        {
            __strong TGDialogFilterEditController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            strongSelf->_filter.title = text;
            strongSelf->_colorsItem.previewTitle = text;
            [strongSelf updateNavigation];
        };
        _nameItem.returned = ^
        {
            __strong TGDialogFilterEditController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf.view endEditing:true];
        };
        TGCollectionMenuSection *nameSection = [[TGCollectionMenuSection alloc] initWithItems:@[[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.Name")], _nameItem]];
        nameSection.insets = UIEdgeInsetsMake(24.0f, 0.0f, 16.0f, 0.0f);
        [self.menuSections addSection:nameSection];

        _iconsItem = [[TGDialogFilterIconsCollectionItem alloc] init];
        _iconsItem.selectedEmoticon = _filter.emoticon;
        _iconsItem.emoticonSelected = ^(NSString *emoticon)
        {
            __strong TGDialogFilterEditController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            strongSelf->_filter.emoticon = emoticon;
            [strongSelf updateNavigation];
        };
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.Icon")], _iconsItem]]];

        _includeSection = [[TGCollectionMenuSection alloc] initWithItems:@[]];
        [self.menuSections addSection:_includeSection];

        _excludeSection = [[TGCollectionMenuSection alloc] initWithItems:@[]];
        [self.menuSections addSection:_excludeSection];

        _colorsItem = [[TGDialogFilterColorsCollectionItem alloc] init];
        _colorsItem.selectedColor = _filter.color;
        _colorsItem.previewTitle = _filter.title;
        _colorsItem.colorSelected = ^(int32_t color)
        {
            __strong TGDialogFilterEditController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            strongSelf->_filter.color = color;
            [strongSelf updateNavigation];
        };
        _colorFooterItem = [[TGCommentCollectionItem alloc] initWithText:@""];
        _colorSection = [[TGCollectionMenuSection alloc] initWithItems:@[[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.Color")], _colorsItem, _colorFooterItem]];
        [self.menuSections addSection:_colorSection];

        _inviteSection = [[TGCollectionMenuSection alloc] initWithItems:@[]];
        [self.menuSections addSection:_inviteSection];

        if (!_isNew)
        {
            TGButtonCollectionItem *deleteItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.DeleteFolder") action:@selector(deletePressed)];
            deleteItem.titleColor = self.presentation.pallete.collectionMenuDestructiveColor;
            deleteItem.deselectAutomatically = true;
            _deleteSection = [[TGCollectionMenuSection alloc] initWithItems:@[deleteItem]];
            _deleteSection.insets = UIEdgeInsetsMake(8.0f, 0.0f, 32.0f, 0.0f);
            [self.menuSections addSection:_deleteSection];
        }

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(filtersDidChange:) name:TGDialogFiltersDidChangeNotification object:nil];

        [self rebuildPeerSections];
        [self rebuildInviteSection];
        [self updateColorFooter];
        [self updateNavigation];
        [self reloadInvites];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_saveDisposable dispose];
    [_invitesDisposable dispose];
}

- (void)setInitialIncludedPeerIds:(NSArray *)initialIncludedPeerIds
{
    _initialIncludedPeerIds = initialIncludedPeerIds;
    for (NSNumber *peerId in initialIncludedPeerIds)
        [_filter addIncludedPeerId:peerId.longLongValue];
    [self rebuildPeerSections];
    [self updateNavigation];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (_didAppear)
        [self reloadInvites];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    bool firstAppearance = !_didAppear;
    _didAppear = true;
    [self updateNavigation];
    if (firstAppearance && _presentsIncludePickerOnAppear)
    {
        _presentsIncludePickerOnAppear = false;
        [self addIncludedPressed];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (iosMajorVersion() >= 7)
        self.navigationController.interactivePopGestureRecognizer.enabled = true;
}

- (bool)hasIncludeRules
{
    return (_filter.flags & TGDialogFilterIncludeCategoriesMask) != 0 || [_filter includedPeerIds].count != 0;
}

- (bool)isDirty
{
    if (_isNew)
        return _filter.title.length != 0 || [self hasIncludeRules] || _filter.excludePeerIds.count != 0 || (_filter.flags & TGDialogFilterExcludeCategoriesMask) != 0 || _filter.emoticon.length != 0 || _filter.color != TGDialogFilterNoColor;
    return ![_filter isContentEqualToFilter:_originalFilter];
}

- (void)updateNavigation
{
    if (iosMajorVersion() >= 7 && _didAppear)
        self.navigationController.interactivePopGestureRecognizer.enabled = ![self isDirty];
}

- (void)updateColorFooter
{
    _colorFooterItem.text = [TGDialogFilterSignals tagsVisible] ? TGLocalized(@"DialogFilters.ColorInfo") : TGLocalized(@"DialogFilters.ColorTagsDisabledInfo");
    if (self.isViewLoaded)
    {
        [self.collectionLayout invalidateLayout];
        [self.collectionView reloadData];
    }
}

- (UIImage *)addIcon
{
    return self.presentation.images.collectionMenuAddImage;
}

- (TGButtonCollectionItem *)addButtonWithTitle:(NSString *)title action:(SEL)action
{
    TGButtonCollectionItem *item = [[TGButtonCollectionItem alloc] initWithTitle:title action:action];
    item.icon = [self addIcon];
    item.iconOffset = CGPointMake(0.0f, 0.0f);
    item.leftInset = 50.0f;
    item.deselectAutomatically = true;
    return item;
}

- (NSArray *)rowsForCategories:(int32_t)categories peerIds:(NSArray *)peerIds categoryList:(NSArray *)categoryList exclude:(bool)exclude
{
    __weak TGDialogFilterEditController *weakSelf = self;
    NSMutableArray *rows = [[NSMutableArray alloc] init];
    for (NSNumber *category in categoryList)
    {
        if ((categories & category.intValue) == 0)
            continue;
        TGDialogFilterCategoryCollectionItem *item = [[TGDialogFilterCategoryCollectionItem alloc] initWithCategory:category.intValue];
        item.selectable = false;
        item.highlightable = false;
        item.canDelete = true;
        int32_t value = category.intValue;
        item.deletePressed = ^
        {
            __strong TGDialogFilterEditController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf removeCategory:value];
        };
        [rows addObject:item];
    }
    for (NSNumber *peerId in peerIds)
    {
        TGGroupInfoUserCollectionItem *item = [TGDialogFilterPeersController itemForPeerId:peerId.longLongValue conversations:_conversations];
        if (item == nil)
            continue;
        item.selectable = false;
        item.canDelete = true;
        [item setCanEdit:true];
        int64_t value = peerId.longLongValue;
        item.requestDelete = ^
        {
            __strong TGDialogFilterEditController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            if (exclude)
                [strongSelf->_filter removeExcludedPeerId:value];
            else
                [strongSelf->_filter removeIncludedPeerId:value];
            [strongSelf rebuildPeerSections];
            [strongSelf updateNavigation];
        };
        [rows addObject:item];
    }
    return rows;
}

- (void)rebuildPeerSections
{
    NSMutableArray *includeItems = [[NSMutableArray alloc] init];
    [includeItems addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.IncludedChats")]];
    [includeItems addObject:[self addButtonWithTitle:TGLocalized(@"DialogFilters.AddChats") action:@selector(addIncludedPressed)]];
    NSArray *includeRows = [self rowsForCategories:_filter.chatlist ? 0 : _filter.flags peerIds:[_filter includedPeerIds] categoryList:[TGDialogFilter includeCategories] exclude:false];
    [self appendRows:includeRows toItems:includeItems expanded:_includeExpanded action:@selector(showMoreIncludedPressed)];
    [includeItems addObject:[[TGCommentCollectionItem alloc] initWithText:_filter.chatlist ? TGLocalized(@"DialogFilters.IncludedChatlistInfo") : TGLocalized(@"DialogFilters.IncludedInfo")]];
    [_includeSection replaceItems:includeItems];

    NSUInteger excludeIndex = [self indexForSection:_excludeSection];
    if (_filter.chatlist)
    {
        if (excludeIndex != NSNotFound)
            [self.menuSections deleteSectionByReference:_excludeSection];
    }
    else
    {
        NSMutableArray *excludeItems = [[NSMutableArray alloc] init];
        [excludeItems addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.ExcludedChats")]];
        [excludeItems addObject:[self addButtonWithTitle:TGLocalized(@"DialogFilters.ExcludeChats") action:@selector(addExcludedPressed)]];
        NSArray *excludeRows = [self rowsForCategories:_filter.flags peerIds:_filter.excludePeerIds categoryList:[TGDialogFilter excludeCategories] exclude:true];
        [self appendRows:excludeRows toItems:excludeItems expanded:_excludeExpanded action:@selector(showMoreExcludedPressed)];
        [excludeItems addObject:[[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"DialogFilters.ExcludedInfo")]];
        [_excludeSection replaceItems:excludeItems];
        if (excludeIndex == NSNotFound)
            [self.menuSections insertSection:_excludeSection atIndex:[self indexForSection:_includeSection] + 1];
    }
    [self.collectionView reloadData];
}

- (void)appendRows:(NSArray *)rows toItems:(NSMutableArray *)items expanded:(bool)expanded action:(SEL)action
{
    if (expanded || rows.count <= TGDialogFilterEditCollapsedRowCount)
    {
        [items addObjectsFromArray:rows];
        return;
    }
    NSUInteger visible = TGDialogFilterEditCollapsedRowCount - 1;
    [items addObjectsFromArray:[rows subarrayWithRange:NSMakeRange(0, visible)]];
    TGButtonCollectionItem *moreItem = [[TGButtonCollectionItem alloc] initWithTitle:[effectiveLocalization() getPluralized:@"DialogFilters.ShowMore" count:(int32_t)(rows.count - visible)] action:action];
    moreItem.leftInset = 65.0f;
    moreItem.deselectAutomatically = true;
    [items addObject:moreItem];
}

- (void)showMoreIncludedPressed
{
    _includeExpanded = true;
    [self rebuildPeerSections];
}

- (void)showMoreExcludedPressed
{
    _excludeExpanded = true;
    [self rebuildPeerSections];
}

- (void)removeCategory:(int32_t)category
{
    _filter.flags = _filter.flags & ~category;
    [self rebuildPeerSections];
    [self updateNavigation];
}

- (void)addIncludedPressed
{
    [self.view endEditing:true];
    TGDialogFilterPeersMode mode = _filter.chatlist ? TGDialogFilterPeersModeChatlist : TGDialogFilterPeersModeInclude;
    TGDialogFilterPeersController *controller = [[TGDialogFilterPeersController alloc] initWithMode:mode categories:_filter.flags & TGDialogFilterIncludeCategoriesMask peerIds:[_filter includedPeerIds] limit:[TGDialogFilterSignals chatsPerFolderLimit]];
    __weak TGDialogFilterEditController *weakSelf = self;
    controller.completion = ^(int32_t categories, NSArray *peerIds)
    {
        __strong TGDialogFilterEditController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        if (!strongSelf->_filter.chatlist)
            strongSelf->_filter.flags = (strongSelf->_filter.flags & ~TGDialogFilterIncludeCategoriesMask) | (categories & TGDialogFilterIncludeCategoriesMask);
        [strongSelf->_filter setIncludedPeerIds:peerIds];
        [strongSelf rebuildPeerSections];
        [strongSelf updateNavigation];
    };
    [self.navigationController pushViewController:controller animated:true];
}

- (void)addExcludedPressed
{
    [self.view endEditing:true];
    TGDialogFilterPeersController *controller = [[TGDialogFilterPeersController alloc] initWithMode:TGDialogFilterPeersModeExclude categories:_filter.flags & TGDialogFilterExcludeCategoriesMask peerIds:_filter.excludePeerIds limit:[TGDialogFilterSignals chatsPerFolderLimit]];
    __weak TGDialogFilterEditController *weakSelf = self;
    controller.completion = ^(int32_t categories, NSArray *peerIds)
    {
        __strong TGDialogFilterEditController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_filter.flags = (strongSelf->_filter.flags & ~TGDialogFilterExcludeCategoriesMask) | (categories & TGDialogFilterExcludeCategoriesMask);
        [strongSelf->_filter setExcludedPeerIds:peerIds];
        [strongSelf rebuildPeerSections];
        [strongSelf updateNavigation];
    };
    [self.navigationController pushViewController:controller animated:true];
}

- (void)reloadInvites
{
    if (_isNew || _filter.filterId == 0 || !(_filter.chatlist || _filter.hasMyInvites))
    {
        _invites = @[];
        [self rebuildInviteSection];
        return;
    }
    __weak TGDialogFilterEditController *weakSelf = self;
    [_invitesDisposable setDisposable:[[[TGDialogFilterSignals invitesForFilter:_filter] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *invites)
    {
        __strong TGDialogFilterEditController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_invites = invites;
        [strongSelf rebuildInviteSection];
    } error:nil completed:nil]];
}

- (void)rebuildInviteSection
{
    __weak TGDialogFilterEditController *weakSelf = self;
    NSMutableArray *items = [[NSMutableArray alloc] init];
    [items addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.InviteLinks")]];
    [items addObject:[self addButtonWithTitle:TGLocalized(@"DialogFilters.CreateInvite") action:@selector(createInvitePressed)]];
    for (TGDialogFilterInvite *invite in _invites)
    {
        NSString *title = invite.title.length != 0 ? invite.title : [invite.url stringByReplacingOccurrencesOfString:@"https://" withString:@""];
        TGDialogFilterCollectionItem *item = [[TGDialogFilterCollectionItem alloc] initWithTitle:title subtitle:[effectiveLocalization() getPluralized:@"DialogFilters.ChatCount" count:(int32_t)invite.peerIds.count] icon:nil];
        item.showsDisclosure = true;
        item.pressed = ^
        {
            __strong TGDialogFilterEditController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf openInvite:invite];
        };
        [items addObject:item];
    }
    [items addObject:[[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"DialogFilters.InviteLinksInfo")]];
    [_inviteSection replaceItems:items];
    [self.collectionView reloadData];
}

- (void)openInvite:(TGDialogFilterInvite *)invite
{
    [self.navigationController pushViewController:[[TGDialogFilterInviteController alloc] initWithInvite:invite filter:_filter] animated:true];
}

- (NSArray *)shareablePeerIds
{
    NSMutableArray *peerIds = [[NSMutableArray alloc] init];
    for (NSNumber *peerId in [_filter includedPeerIds])
    {
        if ([TGDialogFilterPeersController peerIdIsShareable:peerId.longLongValue conversations:_conversations])
            [peerIds addObject:peerId];
    }
    return peerIds;
}

- (void)createInvitePressed
{
    [self.view endEditing:true];
    if (!_filter.chatlist && [_filter hasCategoryRules])
    {
        [TGDialogFiltersController presentError:@"FILTER_NOT_SUPPORTED"];
        return;
    }
    if ([self shareablePeerIds].count == 0)
    {
        [TGDialogFiltersController presentError:@"PEERS_LIST_EMPTY"];
        return;
    }
    if (_invites.count >= [TGDialogFilterSignals invitesPerFolderLimit])
    {
        [TGDialogFiltersController presentError:@"INVITES_TOO_MUCH"];
        return;
    }

    if (_isNew || [self isDirty])
    {
        __weak TGDialogFilterEditController *weakSelf = self;
        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"DialogFilters.SaveBeforeInvite") cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"DialogFilters.Save") completionBlock:^(bool okButtonPressed)
        {
            __strong TGDialogFilterEditController *strongSelf = weakSelf;
            if (strongSelf == nil || !okButtonPressed)
                return;
            [strongSelf saveWithCompletion:^(bool success)
            {
                __strong TGDialogFilterEditController *innerSelf = weakSelf;
                if (success && innerSelf != nil)
                    [innerSelf createInvite];
            }];
        }];
        return;
    }
    [self createInvite];
}

- (void)createInvite
{
    __weak TGDialogFilterEditController *weakSelf = self;
    TGDialogFilter *filter = [_filter copy];
    [_saveDisposable setDisposable:[[TGDialogFiltersController signalWithProgress:[TGDialogFilterSignals createInviteForFilter:filter peerIds:[self shareablePeerIds]]] startWithNext:^(TGDialogFilterInvite *invite)
    {
        __strong TGDialogFilterEditController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_filter.chatlist = true;
        strongSelf->_filter.hasMyInvites = true;
        strongSelf->_originalFilter.chatlist = true;
        strongSelf->_originalFilter.hasMyInvites = true;
        strongSelf->_invites = [strongSelf->_invites ?: @[] arrayByAddingObject:invite];
        [strongSelf rebuildPeerSections];
        [strongSelf rebuildInviteSection];
        [strongSelf openInvite:invite];
    } error:^(id error)
    {
        [TGDialogFiltersController presentError:error];
    } completed:nil]];
}

- (void)filtersDidChange:(NSNotification *)notification
{
    if (_isNew)
        return;
    NSArray *filters = notification.userInfo[@"filters"];
    if (![filters isKindOfClass:[NSArray class]])
    {
        [self updateColorFooter];
        return;
    }
    _allFilters = filters;
    TGDialogFilter *updated = nil;
    for (TGDialogFilter *filter in filters)
    {
        if (filter.filterId == _filter.filterId && !filter.defaultFilter)
        {
            updated = filter;
            break;
        }
    }
    if (updated == nil)
        return;
    bool dirty = [self isDirty];
    if (!dirty)
    {
        _originalFilter = [updated copy];
        _filter = [updated copy];
        _nameItem.text = _filter.title;
        _iconsItem.selectedEmoticon = _filter.emoticon;
        _colorsItem.selectedColor = _filter.color;
        _colorsItem.previewTitle = _filter.title;
    }
    else
    {
        _filter.chatlist = updated.chatlist;
        _filter.hasMyInvites = updated.hasMyInvites;
        _originalFilter.chatlist = updated.chatlist;
        _originalFilter.hasMyInvites = updated.hasMyInvites;
    }
    [self rebuildPeerSections];
    [self reloadInvites];
}

- (TGDialogFilter *)preparedFilter
{
    TGDialogFilter *filter = [_filter copy];
    filter.title = [filter.title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return filter;
}

- (NSString *)validationErrorForFilter:(TGDialogFilter *)filter
{
    if (filter.title.length == 0)
        return @"FILTER_TITLE_EMPTY";
    if ((filter.flags & TGDialogFilterIncludeCategoriesMask) == 0 && [filter includedPeerIds].count == 0)
        return @"FILTER_INCLUDE_EMPTY";
    if ([filter includedPeerIds].count > [TGDialogFilterSignals chatsPerFolderLimit])
        return @"FILTER_INCLUDE_TOO_MUCH";
    if (filter.excludePeerIds.count > [TGDialogFilterSignals chatsPerFolderLimit])
        return @"FILTER_EXCLUDE_TOO_MUCH";
    return nil;
}

- (void)saveWithCompletion:(void (^)(bool success))completion
{
    [self.view endEditing:true];
    TGDialogFilter *filter = [self preparedFilter];
    NSString *validationError = [self validationErrorForFilter:filter];
    if (validationError != nil)
    {
        [TGDialogFiltersController presentError:validationError];
        if ([validationError isEqualToString:@"FILTER_TITLE_EMPTY"])
            [_nameItem becomeFirstResponder];
        if (completion)
            completion(false);
        return;
    }
    if (_isNew)
    {
        NSUInteger userFolders = 0;
        for (TGDialogFilter *existing in _allFilters)
        {
            if (!existing.defaultFilter)
                userFolders++;
        }
        int32_t filterId = [TGDialogFilterSignals unusedFilterIdForFilters:_allFilters];
        if (filterId == 0 || userFolders >= [TGDialogFilterSignals folderLimit])
        {
            [TGDialogFiltersController presentError:@"DIALOG_FILTERS_TOO_MUCH"];
            if (completion)
                completion(false);
            return;
        }
        filter.filterId = filterId;
    }

    void (^block)(bool) = [completion copy];
    __weak TGDialogFilterEditController *weakSelf = self;
    [_saveDisposable setDisposable:[[TGDialogFiltersController signalWithProgress:[TGDialogFilterSignals saveFilter:filter]] startWithNext:^(TGDialogFiltersState *state)
    {
        __strong TGDialogFilterEditController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        TGDialogFilter *saved = filter;
        for (TGDialogFilter *candidate in state.filters)
        {
            if (candidate.filterId == filter.filterId && !candidate.defaultFilter)
            {
                saved = candidate;
                break;
            }
        }
        strongSelf->_isNew = false;
        strongSelf->_allFilters = state.filters;
        strongSelf->_originalFilter = [saved copy];
        strongSelf->_filter = [saved copy];
        strongSelf.title = TGLocalized(@"DialogFilters.EditFolder");
        [strongSelf updateNavigation];
        if (block)
            block(true);
    } error:^(id error)
    {
        [TGDialogFiltersController presentError:error];
        if (block)
            block(false);
    } completed:nil]];
}

- (void)donePressed
{
    [self.view endEditing:true];
    if (!_isNew && ![self isDirty])
    {
        [self.navigationController popViewControllerAnimated:true];
        return;
    }
    __weak TGDialogFilterEditController *weakSelf = self;
    [self saveWithCompletion:^(bool success)
    {
        __strong TGDialogFilterEditController *strongSelf = weakSelf;
        if (success && strongSelf != nil)
            [strongSelf.navigationController popViewControllerAnimated:true];
    }];
}

- (void)cancelPressed
{
    [self.view endEditing:true];
    if (![self isDirty])
    {
        [self.navigationController popViewControllerAnimated:true];
        return;
    }
    __weak TGDialogFilterEditController *weakSelf = self;
    [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"DialogFilters.DiscardMessage") cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"DialogFilters.Discard") destructive:true completionBlock:^(bool okButtonPressed)
    {
        __strong TGDialogFilterEditController *strongSelf = weakSelf;
        if (okButtonPressed && strongSelf != nil)
            [strongSelf.navigationController popViewControllerAnimated:true];
    } disableKeyboardWorkaround:false];
}

- (void)deletePressed
{
    [self.view endEditing:true];
    TGDialogFilter *filter = _originalFilter ?: _filter;
    __weak TGDialogFilterEditController *weakSelf = self;
    [TGDialogFiltersController deleteFilter:filter controller:self completion:^(bool deleted)
    {
        __strong TGDialogFilterEditController *strongSelf = weakSelf;
        if (deleted && strongSelf != nil)
            [strongSelf.navigationController popViewControllerAnimated:true];
    }];
}

@end
