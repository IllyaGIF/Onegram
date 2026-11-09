#import "TGOnegramSettingsController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGHeaderCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGSwitchCollectionItem.h"
#import "TGCheckCollectionItem.h"
#import "TGPresentation.h"
#import "TGOnegramSettings.h"
#import "TGOnegramSliderCollectionItem.h"

@implementation TGOnegramActionCollectionItem

- (instancetype)initWithTitle:(NSString *)title variant:(NSString *)variant pressed:(void (^)(void))pressed
{
    self = [super initWithTitle:title variant:variant action:NULL];
    if (self != nil)
    {
        _pressed = [pressed copy];
        self.deselectAutomatically = true;
    }
    return self;
}

- (void)itemSelected:(id)__unused actionTarget
{
    if (_pressed != nil && self.enabled)
        _pressed();
}

@end

@interface TGOnegramChoiceController : TGCollectionMenuController
{
    NSArray *_items;
    NSMutableIndexSet *_selected;
    bool _multiple;
}

@property (nonatomic, copy) void (^singleCompletion)(NSInteger index);
@property (nonatomic, copy) void (^multipleCompletion)(NSIndexSet *indices);

- (instancetype)initWithTitle:(NSString *)title options:(NSArray *)options selected:(NSIndexSet *)selected multiple:(bool)multiple footer:(NSString *)footer;

@end

@implementation TGOnegramChoiceController

- (instancetype)initWithTitle:(NSString *)title options:(NSArray *)options selected:(NSIndexSet *)selected multiple:(bool)multiple footer:(NSString *)footer
{
    self = [super init];
    if (self != nil)
    {
        [self setTitleText:title];
        _multiple = multiple;
        _selected = [selected mutableCopy] ?: [[NSMutableIndexSet alloc] init];
        NSMutableArray *items = [[NSMutableArray alloc] init];
        for (NSString *option in options)
        {
            TGCheckCollectionItem *item = [[TGCheckCollectionItem alloc] initWithTitle:option action:@selector(checkPressed:)];
            item.deselectAutomatically = true;
            [items addObject:item];
        }
        _items = items;
        NSMutableArray *sectionItems = [[NSMutableArray alloc] initWithArray:items];
        if (footer.length != 0)
            [sectionItems addObject:[[TGCommentCollectionItem alloc] initWithText:footer]];
        TGCollectionMenuSection *section = [[TGCollectionMenuSection alloc] initWithItems:sectionItems];
        UIEdgeInsets insets = section.insets;
        insets.top = 32.0f;
        section.insets = insets;
        [self.menuSections addSection:section];
        [self updateChecks];
    }
    return self;
}

- (void)updateChecks
{
    [_items enumerateObjectsUsingBlock:^(TGCheckCollectionItem *item, NSUInteger index, __unused BOOL *stop)
    {
        item.isChecked = [_selected containsIndex:index];
    }];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSUInteger first = _selected.firstIndex;
    if (!_multiple && first != NSNotFound && first < _items.count)
    {
        NSIndexPath *indexPath = [self indexPathForItem:_items[first]];
        if (indexPath != nil)
            [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:PSTCollectionViewScrollPositionCenteredVertically animated:false];
    }
}

- (void)checkPressed:(TGCheckCollectionItem *)item
{
    NSUInteger index = [_items indexOfObject:item];
    if (index == NSNotFound)
        return;
    if (_multiple)
    {
        if ([_selected containsIndex:index])
            [_selected removeIndex:index];
        else
            [_selected addIndex:index];
        [self updateChecks];
        if (_multipleCompletion != nil)
            _multipleCompletion([_selected copy]);
        return;
    }
    [_selected removeAllIndexes];
    [_selected addIndex:index];
    [self updateChecks];
    if (_singleCompletion != nil)
        _singleCompletion((NSInteger)index);
    [self.navigationController popViewControllerAnimated:true];
}

@end

@interface TGOnegramTextInputController : TGViewController <UITextFieldDelegate>
{
    UITextField *_textField;
    UILabel *_footerLabel;
    NSString *_text;
    NSString *_placeholder;
    NSString *_footer;
    bool _secure;
}

@property (nonatomic, copy) void (^completion)(NSString *text);

- (instancetype)initWithTitle:(NSString *)title text:(NSString *)text placeholder:(NSString *)placeholder secure:(bool)secure footer:(NSString *)footer;

@end

@implementation TGOnegramTextInputController

- (instancetype)initWithTitle:(NSString *)title text:(NSString *)text placeholder:(NSString *)placeholder secure:(bool)secure footer:(NSString *)footer
{
    self = [super init];
    if (self != nil)
    {
        [self setTitleText:title];
        _text = text;
        _placeholder = placeholder;
        _secure = secure;
        _footer = footer;
        [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Done") style:UIBarButtonItemStyleDone target:self action:@selector(donePressed)]];
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    TGPresentationPallete *pallete = TGPresentation.current.pallete;
    self.view.backgroundColor = pallete.collectionMenuBackgroundColor;

    _textField = [[UITextField alloc] init];
    _textField.backgroundColor = pallete.collectionMenuCellBackgroundColor;
    _textField.textColor = pallete.collectionMenuTextColor;
    _textField.font = TGSystemFontOfSize(17.0f);
    _textField.placeholder = _placeholder;
    _textField.text = _text;
    _textField.secureTextEntry = _secure;
    _textField.autocorrectionType = UITextAutocorrectionTypeNo;
    _textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _textField.returnKeyType = UIReturnKeyDone;
    _textField.delegate = self;
    _textField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 15.0f, 1.0f)];
    _textField.leftViewMode = UITextFieldViewModeAlways;
    _textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    [self.view addSubview:_textField];

    _footerLabel = [[UILabel alloc] init];
    _footerLabel.backgroundColor = [UIColor clearColor];
    _footerLabel.font = TGSystemFontOfSize(13.0f);
    _footerLabel.textColor = pallete.collectionMenuCommentColor;
    _footerLabel.numberOfLines = 0;
    _footerLabel.text = _footer;
    [self.view addSubview:_footerLabel];

    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    CGFloat width = self.view.bounds.size.width;
    CGFloat y = self.controllerInset.top + 32.0f;
    _textField.frame = CGRectMake(0.0f, y, width, 44.0f);
    CGSize footerSize = [_footerLabel sizeThatFits:CGSizeMake(width - 30.0f, CGFLOAT_MAX)];
    _footerLabel.frame = CGRectMake(15.0f, y + 44.0f + 8.0f, width - 30.0f, footerSize.height);
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [_textField becomeFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)__unused textField
{
    [self donePressed];
    return false;
}

- (void)donePressed
{
    if (_completion != nil)
        _completion([_textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"");
    [self.navigationController popViewControllerAnimated:true];
}

@end

@interface TGOnegramSettingsController ()
{
    bool _rebuildScheduled;
}

@end

@implementation TGOnegramSettingsController

- (instancetype)initWithTitle:(NSString *)title
{
    self = [super init];
    if (self != nil)
    {
        [self setTitleText:title];
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Back") style:UIBarButtonItemStylePlain target:nil action:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:TGOnegramSettingsDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self rebuild];
    [super viewWillAppear:animated];
}

- (NSArray *)buildSections
{
    return @[];
}

- (bool)rebuildsForSettingKey:(NSString *)__unused key
{
    return false;
}

- (void)settingDidChange:(NSString *)__unused key
{
}

- (void)settingsChanged:(NSNotification *)notification
{
    NSString *key = notification.userInfo[TGOnegramSettingsChangedKey];
    [self settingDidChange:key];
    if (![self rebuildsForSettingKey:key] || _rebuildScheduled)
        return;
    _rebuildScheduled = true;
    __weak TGOnegramSettingsController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^
    {
        __strong TGOnegramSettingsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_rebuildScheduled = false;
        [strongSelf rebuild];
    });
}

- (void)rebuild
{
    NSArray *sections = [self buildSections];
    while (self.menuSections.sections.count != 0)
        [self.menuSections deleteSection:0];
    bool first = true;
    for (TGCollectionMenuSection *section in sections)
    {
        if (first)
        {
            UIEdgeInsets insets = section.insets;
            insets.top = 32.0f;
            section.insets = insets;
            first = false;
        }
        [self.menuSections addSection:section];
    }
    [self.collectionView reloadData];
}

- (TGCollectionMenuSection *)sectionWithHeader:(NSString *)header items:(NSArray *)items footer:(NSString *)footer
{
    NSMutableArray *sectionItems = [[NSMutableArray alloc] init];
    if (header.length != 0)
        [sectionItems addObject:[[TGHeaderCollectionItem alloc] initWithTitle:header]];
    [sectionItems addObjectsFromArray:items];
    if (footer.length != 0)
        [sectionItems addObject:[[TGCommentCollectionItem alloc] initWithText:footer]];
    return [[TGCollectionMenuSection alloc] initWithItems:sectionItems];
}

- (TGSwitchCollectionItem *)switchWithTitle:(NSString *)title value:(bool)value toggled:(void (^)(bool))toggled
{
    TGSwitchCollectionItem *item = [[TGSwitchCollectionItem alloc] initWithTitle:title isOn:value];
    void (^block)(bool) = [toggled copy];
    item.toggled = ^(bool newValue, __unused TGSwitchCollectionItem *switchItem)
    {
        block(newValue);
    };
    return item;
}

- (TGSwitchCollectionItem *)switchWithTitle:(NSString *)title key:(NSString *)key
{
    return [self switchWithTitle:title value:[TGOnegramSettings boolForKey:key] toggled:^(bool value)
    {
        [TGOnegramSettings setBool:value forKey:key];
    }];
}

- (TGSwitchCollectionItem *)switchWithTitle:(NSString *)title key:(NSString *)key description:(NSString *)description
{
    TGSwitchCollectionItem *item = [self switchWithTitle:title key:key];
    item.descriptionText = description;
    return item;
}

- (TGOnegramActionCollectionItem *)choiceWithTitle:(NSString *)title key:(NSString *)key options:(NSArray *)options description:(NSString *)description
{
    TGOnegramActionCollectionItem *item = [self choiceWithTitle:title key:key options:options];
    item.descriptionText = description;
    return item;
}

- (TGOnegramActionCollectionItem *)actionWithTitle:(NSString *)title variant:(NSString *)variant description:(NSString *)description pressed:(void (^)(void))pressed
{
    TGOnegramActionCollectionItem *item = [self actionWithTitle:title variant:variant pressed:pressed];
    item.descriptionText = description;
    return item;
}

- (TGOnegramActionCollectionItem *)actionWithTitle:(NSString *)title variant:(NSString *)variant pressed:(void (^)(void))pressed
{
    return [[TGOnegramActionCollectionItem alloc] initWithTitle:title variant:variant pressed:pressed];
}

- (TGOnegramActionCollectionItem *)choiceWithTitle:(NSString *)title key:(NSString *)key options:(NSArray *)options
{
    NSInteger selected = [TGOnegramSettings integerForKey:key];
    NSString *variant = selected >= 0 && selected < (NSInteger)options.count ? options[(NSUInteger)selected] : @"";
    __weak TGOnegramSettingsController *weakSelf = self;
    return [self actionWithTitle:title variant:variant pressed:^
    {
        __strong TGOnegramSettingsController *strongSelf = weakSelf;
        [strongSelf pushChoiceWithTitle:title options:options selectedIndex:[TGOnegramSettings integerForKey:key] footer:nil completion:^(NSInteger index)
        {
            [TGOnegramSettings setInteger:index forKey:key];
        }];
    }];
}

- (TGOnegramSliderCollectionItem *)sliderWithTitle:(NSString *)title key:(NSString *)key minimumValue:(NSInteger)minimumValue maximumValue:(NSInteger)maximumValue formatter:(NSString *(^)(NSInteger))formatter
{
    TGOnegramSliderCollectionItem *item = [[TGOnegramSliderCollectionItem alloc] initWithTitle:title minimumValue:minimumValue maximumValue:maximumValue value:[TGOnegramSettings integerForKey:key]];
    item.valueFormatter = formatter;
    item.valueCommitted = ^(NSInteger value)
    {
        [TGOnegramSettings setInteger:value forKey:key];
    };
    return item;
}

- (void)pushChoiceWithTitle:(NSString *)title options:(NSArray *)options selectedIndex:(NSInteger)selectedIndex footer:(NSString *)footer completion:(void (^)(NSInteger))completion
{
    NSIndexSet *selected = selectedIndex >= 0 ? [NSIndexSet indexSetWithIndex:(NSUInteger)selectedIndex] : [NSIndexSet indexSet];
    TGOnegramChoiceController *controller = [[TGOnegramChoiceController alloc] initWithTitle:title options:options selected:selected multiple:false footer:footer];
    controller.singleCompletion = completion;
    controller.presentation = self.presentation;
    [self.navigationController pushViewController:controller animated:true];
}

- (void)pushMultipleChoiceWithTitle:(NSString *)title options:(NSArray *)options selectedIndices:(NSIndexSet *)selectedIndices footer:(NSString *)footer completion:(void (^)(NSIndexSet *))completion
{
    TGOnegramChoiceController *controller = [[TGOnegramChoiceController alloc] initWithTitle:title options:options selected:selectedIndices multiple:true footer:footer];
    controller.multipleCompletion = completion;
    controller.presentation = self.presentation;
    [self.navigationController pushViewController:controller animated:true];
}

- (void)pushTextInputWithTitle:(NSString *)title text:(NSString *)text placeholder:(NSString *)placeholder secure:(bool)secure footer:(NSString *)footer completion:(void (^)(NSString *))completion
{
    TGOnegramTextInputController *controller = [[TGOnegramTextInputController alloc] initWithTitle:title text:text placeholder:placeholder secure:secure footer:footer];
    controller.completion = completion;
    [self.navigationController pushViewController:controller animated:true];
}

@end
