#import "TGDisclosureActionCollectionItem.h"

#import "TGDisclosureActionCollectionItemView.h"
#import "TGPresentation.h"

@implementation TGDisclosureActionCollectionItem

- (instancetype)initWithTitle:(NSString *)title action:(SEL)action
{
    self = [super init];
    if (self != nil)
    {
        _title = title;
        _action = action;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGDisclosureActionCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, [TGPresentation brandedIOS6Style] && _brandedSettingsStyle ? 35.0f : ([TGPresentation brandedIOS6Style] && _brandedProfileMusic ? 40.0f : 44.0f));
}

- (void)itemSelected:(id)actionTarget
{
    if (_action != NULL && [actionTarget respondsToSelector:_action])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [actionTarget performSelector:_action];
#pragma clang diagnostic pop
    }
}

- (void)bindView:(TGDisclosureActionCollectionItemView *)view
{
    if (![view isKindOfClass:[TGDisclosureActionCollectionItemView class]])
        return;
    
    [super bindView:view];
    
    [view setBrandedProfileMusic:_brandedProfileMusic];
    [view setTitle:_title];
    [view setIcon:_icon];
    [view setBadge:_badge];
    [view setHideArrow:_hideArrow];
    [view setBrandedSettingsStyle:_brandedSettingsStyle iconName:_brandedSettingsIconName];
}

- (void)unbindView {
    [super unbindView];
}

- (void)setTitle:(NSString *)title
{
    _title = title;
    
    if (self.boundView != nil)
        [(TGDisclosureActionCollectionItemView *)self.view setTitle:title];
}

- (void)setIcon:(UIImage *)icon
{
    _icon = icon;
    
    if (self.boundView != nil)
        [(TGDisclosureActionCollectionItemView *)self.view setIcon:icon];
}

- (void)setBadge:(NSString *)badge {
    _badge = badge;
    
    if (self.boundView != nil && [self.boundView respondsToSelector:@selector(setBadge:)])
        [(TGDisclosureActionCollectionItemView *)self.view setBadge:badge];
}

- (void)setBrandedSettingsStyle:(bool)brandedSettingsStyle
{
    if (_brandedSettingsStyle == brandedSettingsStyle)
        return;

    _brandedSettingsStyle = brandedSettingsStyle;
    if (self.boundView != nil)
        [(TGDisclosureActionCollectionItemView *)self.boundView setBrandedSettingsStyle:_brandedSettingsStyle iconName:_brandedSettingsIconName];
}

- (void)setBrandedSettingsIconName:(NSString *)brandedSettingsIconName
{
    if (_brandedSettingsIconName == brandedSettingsIconName || [_brandedSettingsIconName isEqualToString:brandedSettingsIconName])
        return;

    _brandedSettingsIconName = brandedSettingsIconName;
    if (self.boundView != nil)
        [(TGDisclosureActionCollectionItemView *)self.boundView setBrandedSettingsStyle:_brandedSettingsStyle iconName:_brandedSettingsIconName];
}

@end
