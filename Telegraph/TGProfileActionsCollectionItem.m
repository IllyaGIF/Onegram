#import "TGProfileActionsCollectionItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGProfileActionsCollectionItemView.h"

@implementation TGProfileAction

- (instancetype)initWithTitle:(NSString *)title icon:(TGProfileActionIcon)icon action:(SEL)action
{
    return [self initWithTitle:title icon:icon action:action destructive:false];
}

- (instancetype)initWithTitle:(NSString *)title icon:(TGProfileActionIcon)icon action:(SEL)action destructive:(bool)destructive
{
    self = [super init];
    if (self != nil)
    {
        _title = title;
        _icon = icon;
        _action = action;
        _destructive = destructive;
    }
    return self;
}

- (instancetype)initWithTitle:(NSString *)title icon:(TGProfileActionIcon)icon selected:(bool)selected handler:(void (^)(void))handler
{
    self = [super init];
    if (self != nil)
    {
        _title = title;
        _icon = icon;
        _selected = selected;
        _handler = [handler copy];
    }
    return self;
}

+ (instancetype)notificationsActionMuted:(bool)muted muteAction:(SEL)muteAction unmuteAction:(SEL)unmuteAction
{
    if (muted)
        return [[self alloc] initWithTitle:TGLocalized(@"OnegramProfile.Action.Unmute") icon:TGProfileActionIconUnmute action:unmuteAction];
    return [[self alloc] initWithTitle:TGLocalized(@"OnegramProfile.Action.Mute") icon:TGProfileActionIconMute action:muteAction];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    if (![object isKindOfClass:[TGProfileAction class]])
        return false;
    TGProfileAction *other = object;
    return other->_icon == _icon && other->_action == _action && other->_destructive == _destructive && other->_selected == _selected &&
        other->_handler == _handler && (other->_title == _title || [other->_title isEqualToString:_title]);
}

- (NSUInteger)hash
{
    return [_title hash] ^ (NSUInteger)_icon;
}

@end

@implementation TGProfileActionsCollectionItem

- (instancetype)initWithTarget:(id)target
{
    self = [super init];
    if (self != nil)
    {
        _target = target;
        self.transparent = true;
        self.selectable = false;
        self.highlightable = false;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGProfileActionsCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, TGProfileActionsCollectionItemViewHeight);
}

- (void)bindView:(TGProfileActionsCollectionItemView *)view
{
    [super bindView:view];

    [view setActions:[self displayedActions]];
    [view setButtonColor:_buttonColor];
    [view setButtonStyle:_buttonStyle];
    __weak TGProfileActionsCollectionItem *weakSelf = self;
    view.actionSelected = ^(TGProfileAction *action)
    {
        __strong TGProfileActionsCollectionItem *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf performAction:action];
    };
}

- (void)unbindView
{
    ((TGProfileActionsCollectionItemView *)[self boundView]).actionSelected = nil;

    [super unbindView];
}

- (NSArray *)displayedActions
{
    if (_extraActions.count == 0)
        return _actions;
    return _actions.count == 0 ? _extraActions : [_actions arrayByAddingObjectsFromArray:_extraActions];
}

- (void)setActions:(NSArray *)actions
{
    if (_actions == actions || [_actions isEqualToArray:actions])
        return;
    _actions = actions;
    [(TGProfileActionsCollectionItemView *)[self boundView] setActions:[self displayedActions]];
}

- (void)setExtraActions:(NSArray *)extraActions
{
    if (_extraActions == extraActions || [_extraActions isEqualToArray:extraActions])
        return;
    _extraActions = extraActions;
    [(TGProfileActionsCollectionItemView *)[self boundView] setActions:[self displayedActions]];
}

- (void)setButtonColor:(UIColor *)buttonColor
{
    if (_buttonColor == buttonColor || [_buttonColor isEqual:buttonColor])
        return;
    _buttonColor = buttonColor;
    [(TGProfileActionsCollectionItemView *)[self boundView] setButtonColor:buttonColor];
}

- (void)setButtonStyle:(NSDictionary *)buttonStyle
{
    if (_buttonStyle == buttonStyle || [_buttonStyle isEqualToDictionary:buttonStyle])
        return;
    _buttonStyle = [buttonStyle copy];
    [(TGProfileActionsCollectionItemView *)[self boundView] setButtonStyle:_buttonStyle];
}

- (void)performAction:(TGProfileAction *)action
{
    if (action.handler != nil)
    {
        action.handler();
        return;
    }
    id target = _target;
    if (action.action == NULL || ![target respondsToSelector:action.action])
        return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [target performSelector:action.action];
#pragma clang diagnostic pop
}

- (UIView *)sourceViewForActionWithSelector:(SEL)action
{
    return [(TGProfileActionsCollectionItemView *)[self boundView] buttonForActionWithSelector:action];
}

@end
