#import "TGPluginMenuSection.h"

#if OG_PLUGINS_AVAILABLE

#import "TGCollectionMenuController.h"
#import "TGOnegramSettingsController.h"
#import "TGPluginHost.h"

@interface TGPluginMenuSection ()
{
    NSArray *_menuTypes;
    __weak TGCollectionMenuController *_controller;
    int64_t _peerId;
    TGCollectionMenuSection *_section;
    NSArray *_items;
    bool _visible;
    __weak TGCollectionMenuSection *_anchorSection;
}

@end

@implementation TGPluginMenuSection

- (instancetype)initWithMenuType:(NSString *)menuType controller:(TGCollectionMenuController *)controller peerId:(int64_t)peerId
{
    return [self initWithMenuTypes:@[menuType] controller:controller peerId:peerId];
}

- (instancetype)initWithMenuTypes:(NSArray *)menuTypes controller:(TGCollectionMenuController *)controller peerId:(int64_t)peerId
{
    self = [super init];
    if (self != nil)
    {
        _menuTypes = [menuTypes copy];
        _controller = controller;
        _peerId = peerId;
        _section = [[TGCollectionMenuSection alloc] initWithItems:@[]];
        _items = @[];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pluginsEventNotification:) name:OGPluginsEventNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSDictionary *)menuContext
{
    TGCollectionMenuController *controller = _controller;
    return [TGPluginHost menuContextWithController:controller peerId:_peerId messageId:0 groupedMessageIds:nil];
}

- (NSArray *)currentItems
{
    if (!_visible)
        return @[];
    NSMutableArray *items = [[NSMutableArray alloc] init];
    NSDictionary *context = nil;
    for (NSString *menuType in _menuTypes)
    {
        if (![TGPluginHost hasMenuItemsOfType:menuType])
            continue;
        if (context == nil)
            context = [self menuContext];
        for (NSDictionary *item in [TGPluginHost menuItemsOfType:menuType context:context])
            [items addObject:@{@"type": menuType, @"item": item}];
    }
    return items;
}

- (void)rebuildRows
{
    __weak TGPluginMenuSection *weakSelf = self;
    NSMutableArray *rows = [[NSMutableArray alloc] init];
    for (NSDictionary *entry in _items)
    {
        NSString *menuType = entry[@"type"];
        NSDictionary *menuItem = entry[@"item"];
        TGOnegramActionCollectionItem *row = [[TGOnegramActionCollectionItem alloc] initWithTitle:menuItem[@"text"] variant:nil pressed:^
        {
            __strong TGPluginMenuSection *strongSelf = weakSelf;
            if (strongSelf != nil)
                [TGPluginHost performMenuItem:menuItem ofType:menuType context:[strongSelf menuContext]];
        }];
        NSString *subtext = menuItem[@"subtext"];
        if ([subtext isKindOfClass:[NSString class]] && subtext.length != 0)
            row.descriptionText = subtext;
        [rows addObject:row];
    }
    [_section replaceItems:rows];
}

- (bool)place
{
    TGCollectionMenuController *controller = _controller;
    if (controller == nil)
        return false;
    NSUInteger index = [controller indexForSection:_section];
    if (_items.count == 0)
    {
        if (index == NSNotFound)
            return false;
        [controller.menuSections deleteSection:index];
        return true;
    }
    TGCollectionMenuSection *anchorSection = _anchorSection;
    NSUInteger anchorIndex = anchorSection != nil ? [controller indexForSection:anchorSection] : NSNotFound;
    NSUInteger target = anchorIndex != NSNotFound ? anchorIndex : controller.menuSections.sections.count;
    if (index != NSNotFound)
    {
        if (index + 1 == target)
            return false;
        [controller.menuSections deleteSection:index];
        if (index < target)
            target--;
    }
    [controller.menuSections insertSection:_section atIndex:MIN(target, controller.menuSections.sections.count)];
    return true;
}

- (bool)updateVisible:(bool)visible beforeSection:(TGCollectionMenuSection *)anchorSection
{
    _visible = visible;
    _anchorSection = anchorSection;
    NSArray *items = [self currentItems];
    bool changed = ![items isEqualToArray:_items];
    if (changed)
    {
        _items = items;
        [self rebuildRows];
    }
    return [self place] || changed;
}

- (void)pluginsEventNotification:(NSNotification *)notification
{
    if (![TGPluginHost isMenuChangeNotification:notification])
        return;
    TGCollectionMenuSection *anchorSection = _anchorSection;
    TGCollectionMenuController *controller = _controller;
    if ([self updateVisible:_visible beforeSection:anchorSection] && controller.isViewLoaded)
        [controller.collectionView reloadData];
}

@end

#endif
