#import "OGPlatformUIKit.h"
#import "OGPlatformVersion.h"
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <objc/runtime.h>

CGRect OGPlatformKeyboardEndFrame(NSNotification *notification)
{
    if ([notification.name isEqualToString:UIKeyboardWillHideNotification] || [notification.name isEqualToString:UIKeyboardDidHideNotification])
        return CGRectZero;

    NSDictionary *userInfo = notification.userInfo;
    NSValue *frameValue = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
    if (frameValue != nil)
        return [frameValue CGRectValue];

    NSValue *boundsValue = [userInfo objectForKey:UIKeyboardBoundsUserInfoKey];
    NSValue *centerValue = [userInfo objectForKey:UIKeyboardCenterEndUserInfoKey];
    if (boundsValue == nil || centerValue == nil)
        return CGRectZero;

    CGRect bounds = [boundsValue CGRectValue];
    CGPoint center = [centerValue CGPointValue];
    return CGRectMake(center.x - bounds.size.width * 0.5f, center.y - bounds.size.height * 0.5f, bounds.size.width, bounds.size.height);
}

CGRect OGPlatformKeyboardFrameInView(NSNotification *notification, UIView *view)
{
    CGRect frame = OGPlatformKeyboardEndFrame(notification);
    if (CGRectIsEmpty(frame) || view == nil)
        return CGRectZero;

    UIWindow *window = view.window;
    if (window != nil)
        frame = [window convertRect:frame fromWindow:nil];
    return [view convertRect:frame fromView:window];
}

static id OGPlatformObjectProperty(id object, NSString *selectorName)
{
    if (object == nil || selectorName.length == 0)
        return nil;
    SEL selector = NSSelectorFromString(selectorName);
    if (![object respondsToSelector:selector])
        return nil;
    id (*function)(id, SEL) = (id (*)(id, SEL))[object methodForSelector:selector];
    return function == NULL ? nil : function(object, selector);
}

static void OGPlatformSetObjectProperty(id object, NSString *selectorName, id value)
{
    if (object == nil || selectorName.length == 0)
        return;
    SEL selector = NSSelectorFromString(selectorName);
    if (![object respondsToSelector:selector])
        return;
    void (*function)(id, SEL, id) = (void (*)(id, SEL, id))[object methodForSelector:selector];
    if (function != NULL)
        function(object, selector, value);
}

BOOL OGPlatformAccessibilityInvertColorsEnabled(void)
{
    BOOL (*function)(void) = (BOOL (*)(void))dlsym(RTLD_DEFAULT, "UIAccessibilityIsInvertColorsEnabled");
    return function == NULL ? NO : function();
}

void OGPlatformHideAccessibilityElements(UIView *view)
{
    if (view == nil)
        return;

    SEL selector = NSSelectorFromString(@"setAccessibilityElementsHidden:");
    if ([view respondsToSelector:selector])
    {
        void (*function)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[view methodForSelector:selector];
        if (function != NULL)
            function(view, selector, YES);
    }
    else
    {
        view.isAccessibilityElement = NO;
    }
}

BOOL OGPlatformSupportsModernLoginIntro(void)
{
    return OGPlatformMajorVersion() >= 4;
}

BOOL OGPlatformControlAnimationsEnabled(void)
{
    return OGPlatformMajorVersion() >= 4;
}

BOOL OGPlatformTransientAnimationsEnabled(void)
{
    return OGPlatformMajorVersion() >= 4;
}

static void (*OGPlatformOriginalLabelSetFont)(id, SEL, UIFont *) = NULL;
static void (*OGPlatformOriginalButtonLabelSetFont)(id, SEL, UIFont *) = NULL;

static UIFont *OGPlatformLegacyFallbackFont(id object, UIFont *font)
{
    if (font != nil)
        return font;

    UIFont *currentFont = nil;
    if ([object respondsToSelector:@selector(font)])
        currentFont = [(UILabel *)object font];
    return currentFont != nil ? currentFont : [UIFont systemFontOfSize:17.0f];
}

static void OGPlatformLegacyLabelSetFont(id object, SEL selector, UIFont *font)
{
    if (OGPlatformOriginalLabelSetFont != NULL)
        OGPlatformOriginalLabelSetFont(object, selector, OGPlatformLegacyFallbackFont(object, font));
}

static void OGPlatformLegacyButtonLabelSetFont(id object, SEL selector, UIFont *font)
{
    if (OGPlatformOriginalButtonLabelSetFont != NULL)
        OGPlatformOriginalButtonLabelSetFont(object, selector, OGPlatformLegacyFallbackFont(object, font));
}

typedef void (*OGPlatformCollectionDataSetLayoutAttributesFunction)(id, SEL, id, NSInteger);
typedef id (*OGPlatformCollectionDataScreenPageFunction)(id, SEL, CGPoint);
typedef CGRect (*OGPlatformLayoutAttributesFrameFunction)(id, SEL);

static OGPlatformCollectionDataSetLayoutAttributesFunction OGPlatformOriginalCollectionDataSetLayoutAttributes = NULL;
static OGPlatformCollectionDataScreenPageFunction OGPlatformCollectionDataScreenPage = NULL;
static SEL OGPlatformCollectionDataScreenPageSelector = NULL;
static CGFloat OGPlatformCollectionDataPageStep = 0.0f;
static ptrdiff_t OGPlatformCollectionDataItemCountOffset = -1;

static void OGPlatformCollectionDataSetLayoutAttributes(id data, SEL selector, id attributes, NSInteger globalIndex)
{
    if (OGPlatformCollectionDataItemCountOffset >= 0)
    {
        int itemCount = *(int *)((uint8_t *)(__bridge void *)data + OGPlatformCollectionDataItemCountOffset);
        if (globalIndex < 0 || globalIndex >= itemCount)
            return;
    }

    OGPlatformOriginalCollectionDataSetLayoutAttributes(data, selector, attributes, globalIndex);

    if (attributes == nil || globalIndex < 0)
        return;
    SEL frameSelector = @selector(frame);
    if (![attributes respondsToSelector:frameSelector])
        return;
    OGPlatformLayoutAttributesFrameFunction frameFunction = (OGPlatformLayoutAttributesFrameFunction)[attributes methodForSelector:frameSelector];
    if (frameFunction == NULL)
        return;
    CGRect frame = frameFunction(attributes, frameSelector);
    CGFloat step = OGPlatformCollectionDataPageStep;
    if (CGRectIsNull(frame) || CGRectIsInfinite(frame) || step < 1.0f || (frame.size.width <= step && frame.size.height <= step))
        return;

    Class indexSetClass = [NSMutableIndexSet class];
    CGFloat minX = CGRectGetMinX(frame);
    CGFloat minY = CGRectGetMinY(frame);
    CGFloat maxX = MAX(minX, CGRectGetMaxX(frame) - 1.0f);
    CGFloat maxY = MAX(minY, CGRectGetMaxY(frame) - 1.0f);
    for (CGFloat y = minY; ; y += step)
    {
        CGFloat pointY = MIN(y, maxY);
        for (CGFloat x = minX; ; x += step)
        {
            CGFloat pointX = MIN(x, maxX);
            id page = OGPlatformCollectionDataScreenPage(data, OGPlatformCollectionDataScreenPageSelector, CGPointMake(pointX, pointY));
            if ([page isKindOfClass:indexSetClass])
                [(NSMutableIndexSet *)page addIndex:(NSUInteger)globalIndex];
            if (pointX >= maxX)
                break;
        }
        if (pointY >= maxY)
            break;
    }
}

static void OGPlatformInstallCollectionViewDataGuard(void)
{
    Class dataClass = NSClassFromString(@"UICollectionViewData");
    if (dataClass == Nil)
        return;

    SEL setSelector = NSSelectorFromString(@"_setLayoutAttributes:atGlobalItemIndex:");
    SEL pageSelector = NSSelectorFromString(@"_screenPageForPoint:");
    Method setMethod = class_getInstanceMethod(dataClass, setSelector);
    Method pageMethod = class_getInstanceMethod(dataClass, pageSelector);
    if (setMethod == NULL || pageMethod == NULL || method_getNumberOfArguments(setMethod) != 4 || method_getNumberOfArguments(pageMethod) != 3)
        return;

    char returnType[8] = { 0 };
    method_getReturnType(pageMethod, returnType, sizeof(returnType));
    if (returnType[0] != '@')
        return;
    char pointType[64] = { 0 };
    method_getArgumentType(pageMethod, 2, pointType, sizeof(pointType));
    if (strncmp(pointType, "{CGPoint=", 9) != 0)
        return;

    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGFloat step = MIN(screenSize.width, screenSize.height);
    if (step < 1.0f)
        return;

    Ivar itemCountIvar = class_getInstanceVariable(dataClass, "_numItems");
    const char *itemCountType = itemCountIvar == NULL ? NULL : ivar_getTypeEncoding(itemCountIvar);
    if (itemCountType != NULL && strcmp(itemCountType, @encode(int)) == 0)
        OGPlatformCollectionDataItemCountOffset = ivar_getOffset(itemCountIvar);

    OGPlatformCollectionDataPageStep = step;
    OGPlatformCollectionDataScreenPageSelector = pageSelector;
    OGPlatformCollectionDataScreenPage = (OGPlatformCollectionDataScreenPageFunction)method_getImplementation(pageMethod);
    OGPlatformOriginalCollectionDataSetLayoutAttributes = (OGPlatformCollectionDataSetLayoutAttributesFunction)method_setImplementation(setMethod, (IMP)OGPlatformCollectionDataSetLayoutAttributes);
}

void OGPlatformInstallUIKitGuards(void)
{
    static BOOL installed = NO;
    if (installed)
        return;
    installed = YES;

    OGPlatformInstallCollectionViewDataGuard();

    if (OGPlatformMajorVersion() >= 4)
        return;

    SEL selector = @selector(setFont:);
    Method labelMethod = class_getInstanceMethod([UILabel class], selector);
    IMP labelImplementation = labelMethod == NULL ? NULL : method_getImplementation(labelMethod);

    Class buttonLabelClass = NSClassFromString(@"UIButtonLabel");
    Method buttonLabelMethod = buttonLabelClass == Nil ? NULL : class_getInstanceMethod(buttonLabelClass, selector);
    IMP buttonLabelImplementation = buttonLabelMethod == NULL ? NULL : method_getImplementation(buttonLabelMethod);

    if (buttonLabelClass != Nil && buttonLabelMethod != NULL && buttonLabelImplementation != labelImplementation)
    {
        OGPlatformOriginalButtonLabelSetFont = (void (*)(id, SEL, UIFont *))buttonLabelImplementation;
        class_replaceMethod(buttonLabelClass, selector, (IMP)OGPlatformLegacyButtonLabelSetFont, method_getTypeEncoding(buttonLabelMethod));
    }

    if (labelMethod != NULL)
    {
        OGPlatformOriginalLabelSetFont = (void (*)(id, SEL, UIFont *))labelImplementation;
        method_setImplementation(labelMethod, (IMP)OGPlatformLegacyLabelSetFont);
    }
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 32000
static char OGPlatformLegacyInputAccessoryViewKey;
static char OGPlatformLegacyInputViewKey;

@interface OGPlatformLegacyTextInputPresenter : NSObject
{
    UIView *_activeField;
    UIView *_presentedAccessoryView;
    UIView *_presentedInputView;
    CGRect _keyboardBounds;
}
+ (instancetype)sharedPresenter;
- (void)refresh;
@end

@implementation OGPlatformLegacyTextInputPresenter

+ (instancetype)sharedPresenter
{
    static OGPlatformLegacyTextInputPresenter *presenter = nil;
    if (presenter == nil)
        presenter = [[self alloc] init];
    return presenter;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(textFieldDidBeginEditing:) name:UITextFieldTextDidBeginEditingNotification object:nil];
        [center addObserver:self selector:@selector(textFieldDidEndEditing:) name:UITextFieldTextDidEndEditingNotification object:nil];
        [center addObserver:self selector:@selector(textFieldDidBeginEditing:) name:UITextViewTextDidBeginEditingNotification object:nil];
        [center addObserver:self selector:@selector(textFieldDidEndEditing:) name:UITextViewTextDidEndEditingNotification object:nil];
        [center addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
        [center addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
    }
    return self;
}

- (void)removePresentedViews
{
    [_presentedAccessoryView removeFromSuperview];
    [_presentedInputView removeFromSuperview];
    _presentedAccessoryView = nil;
    _presentedInputView = nil;
}

- (UIWindow *)keyboardWindow
{
    UIWindow *fieldWindow = _activeField.window;
    UIWindow *result = nil;
    for (UIWindow *window in [[UIApplication sharedApplication] windows])
    {
        if (!window.hidden && window != fieldWindow && (result == nil || window.windowLevel >= result.windowLevel))
            result = window;
    }
    return result == nil ? fieldWindow : result;
}

- (CGFloat)heightForView:(UIView *)view fallback:(CGFloat)fallback
{
    if (view == nil)
        return 0.0f;
    CGFloat height = view.bounds.size.height;
    if (height <= 0.0f)
    {
        [view sizeToFit];
        height = view.bounds.size.height;
    }
    return height > 0.0f ? height : fallback;
}

- (void)refresh
{
    [self removePresentedViews];
    if (_activeField == nil || ![_activeField isFirstResponder])
        return;

    UIView *accessoryView = objc_getAssociatedObject(_activeField, &OGPlatformLegacyInputAccessoryViewKey);
    UIView *inputView = objc_getAssociatedObject(_activeField, &OGPlatformLegacyInputViewKey);
    if (accessoryView == nil && inputView == nil)
        return;

    UIWindow *window = [self keyboardWindow];
    if (window == nil)
        return;

    CGFloat width = window.bounds.size.width;
    CGFloat inputHeight = [self heightForView:inputView fallback:216.0f];
    CGFloat accessoryHeight = [self heightForView:accessoryView fallback:44.0f];
    CGFloat keyboardHeight = _keyboardBounds.size.height > 0.0f ? MIN(_keyboardBounds.size.width, _keyboardBounds.size.height) : 216.0f;
    CGFloat bottom = window.bounds.size.height;

    if (inputView != nil)
    {
        inputView.frame = CGRectMake(0.0f, bottom - inputHeight, width, inputHeight);
        inputView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [window addSubview:inputView];
        _presentedInputView = inputView;
        bottom -= inputHeight;
    }
    else
        bottom -= keyboardHeight;

    if (accessoryView != nil)
    {
        accessoryView.frame = CGRectMake(0.0f, bottom - accessoryHeight, width, accessoryHeight);
        accessoryView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [window addSubview:accessoryView];
        _presentedAccessoryView = accessoryView;
    }
}

- (void)textFieldDidBeginEditing:(NSNotification *)notification
{
    _activeField = [notification object];
}

- (void)textFieldDidEndEditing:(NSNotification *)notification
{
    if ([notification object] == _activeField)
    {
        [self removePresentedViews];
        _activeField = nil;
    }
}

- (void)keyboardDidShow:(NSNotification *)notification
{
    NSValue *boundsValue = [[notification userInfo] objectForKey:UIKeyboardBoundsUserInfoKey];
    _keyboardBounds = boundsValue == nil ? CGRectZero : [boundsValue CGRectValue];
    [self refresh];
}

- (void)keyboardDidHide:(NSNotification *)notification
{
    [self removePresentedViews];
    _keyboardBounds = CGRectZero;
}

@end
#endif

void OGPlatformSetStatusBarHidden(UIApplication *application, BOOL hidden, NSInteger animation)
{
    if (application == nil)
        return;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 32000
    [application setStatusBarHidden:hidden withAnimation:(UIStatusBarAnimation)animation];
#else
    [application setStatusBarHidden:hidden animated:animation != 0];
#endif
}

void OGPlatformSetTextFieldSelectionRange(UITextField *textField, NSRange range)
{
    if (textField == nil)
        return;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 32000
    UITextPosition *startPosition = [textField positionFromPosition:textField.beginningOfDocument offset:(NSInteger)range.location];
    UITextPosition *endPosition = [textField positionFromPosition:textField.beginningOfDocument offset:(NSInteger)NSMaxRange(range)];
    if (startPosition != nil && endPosition != nil)
        textField.selectedTextRange = [textField textRangeFromPosition:startPosition toPosition:endPosition];
#else
    SEL selector = NSSelectorFromString(@"setSelectionRange:");
    if ([textField respondsToSelector:selector])
    {
        void (*function)(id, SEL, NSRange) = (void (*)(id, SEL, NSRange))[textField methodForSelector:selector];
        if (function != NULL)
            function(textField, selector, range);
    }
#endif
}

void OGPlatformSetTextFieldInputAccessoryView(UITextField *textField, UIView *accessoryView)
{
    if (textField == nil)
        return;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 32000
    textField.inputAccessoryView = accessoryView;
#else
    objc_setAssociatedObject(textField, &OGPlatformLegacyInputAccessoryViewKey, accessoryView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    OGPlatformLegacyTextInputPresenter *presenter = [OGPlatformLegacyTextInputPresenter sharedPresenter];
    if ([textField isFirstResponder])
        [presenter refresh];
#endif
}

void OGPlatformSetTextFieldInputView(UITextField *textField, UIView *inputView)
{
    OGPlatformSetTextInputView(textField, inputView);
}

UIView *OGPlatformTextInputView(id textInput)
{
    if (textInput == nil)
        return nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 32000
    return OGPlatformObjectProperty(textInput, @"inputView");
#else
    return objc_getAssociatedObject(textInput, &OGPlatformLegacyInputViewKey);
#endif
}

void OGPlatformSetTextInputView(id textInput, UIView *inputView)
{
    if (textInput == nil)
        return;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 32000
    OGPlatformSetObjectProperty(textInput, @"setInputView:", inputView);
#else
    objc_setAssociatedObject(textInput, &OGPlatformLegacyInputViewKey, inputView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    OGPlatformLegacyTextInputPresenter *presenter = [OGPlatformLegacyTextInputPresenter sharedPresenter];
    if ([textInput isFirstResponder])
        [presenter refresh];
#endif
}

void OGPlatformDisableSpellChecking(id textInput)
{
    if (textInput == nil)
        return;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 32000
    if ([textInput respondsToSelector:@selector(setSpellCheckingType:)])
        [textInput setSpellCheckingType:UITextSpellCheckingTypeNo];
#else
    if ([textInput respondsToSelector:@selector(setAutocorrectionType:)])
        [textInput setAutocorrectionType:UITextAutocorrectionTypeNo];
#endif
}

static void OGPlatformSetRectProperty(id object, NSString *selectorName, CGRect value)
{
    if (object == nil || selectorName.length == 0)
        return;
    SEL selector = NSSelectorFromString(selectorName);
    if (![object respondsToSelector:selector])
        return;
    void (*function)(id, SEL, CGRect) = (void (*)(id, SEL, CGRect))[object methodForSelector:selector];
    if (function != NULL)
        function(object, selector, value);
}

static void OGPlatformSetUnsignedIntegerProperty(id object, NSString *selectorName, NSUInteger value)
{
    if (object == nil || selectorName.length == 0)
        return;
    SEL selector = NSSelectorFromString(selectorName);
    if (![object respondsToSelector:selector])
        return;
    void (*function)(id, SEL, NSUInteger) = (void (*)(id, SEL, NSUInteger))[object methodForSelector:selector];
    if (function != NULL)
        function(object, selector, value);
}

static BOOL OGPlatformBoolProperty(id object, NSString *selectorName)
{
    if (object == nil || selectorName.length == 0)
        return NO;
    SEL selector = NSSelectorFromString(selectorName);
    if (![object respondsToSelector:selector])
        return NO;
    BOOL (*function)(id, SEL) = (BOOL (*)(id, SEL))[object methodForSelector:selector];
    return function == NULL ? NO : function(object, selector);
}

static IMP OGPlatformSuperclassImplementation(Class currentClass, NSString *selectorName)
{
    if (currentClass == Nil || selectorName.length == 0)
        return NULL;
    Class superclass = class_getSuperclass(currentClass);
    if (superclass == Nil)
        return NULL;
    Method method = class_getInstanceMethod(superclass, NSSelectorFromString(selectorName));
    return method == NULL ? NULL : method_getImplementation(method);
}

static NSString *OGPlatformStringConstant(const char *symbolName, NSString *fallback)
{
    void *symbol = dlsym(RTLD_DEFAULT, symbolName);
    if (symbol != NULL)
    {
        NSString * __unsafe_unretained *value = (NSString * __unsafe_unretained *)symbol;
        if (value != NULL && *value != nil)
            return *value;
    }
    return fallback;
}

void OGPlatformSetExclusiveTouch(UIView *view, BOOL enabled)
{
    SEL selector = NSSelectorFromString(@"setExclusiveTouch:");
    if (view == nil || ![view respondsToSelector:selector])
        return;
    void (*function)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[view methodForSelector:selector];
    if (function != NULL)
        function(view, selector, enabled);
}

void OGPlatformSetViewRasterization(UIView *view, BOOL enabled, CGFloat scale)
{
    if (view == nil)
        return;
    CALayer *layer = [view layer];
    SEL rasterSelector = NSSelectorFromString(@"setShouldRasterize:");
    if ([layer respondsToSelector:rasterSelector])
    {
        void (*setRasterize)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[layer methodForSelector:rasterSelector];
        if (setRasterize != NULL)
            setRasterize(layer, rasterSelector, enabled);
    }
    SEL scaleSelector = NSSelectorFromString(@"setRasterizationScale:");
    if (enabled && [layer respondsToSelector:scaleSelector])
    {
        void (*setScale)(id, SEL, CGFloat) = (void (*)(id, SEL, CGFloat))[layer methodForSelector:scaleSelector];
        if (setScale != NULL)
            setScale(layer, scaleSelector, scale);
    }
}


void OGPlatformSetLayerContentsScale(CALayer *layer, CGFloat scale)
{
    if (layer == nil)
        return;
    SEL selector = NSSelectorFromString(@"setContentsScale:");
    if (![layer respondsToSelector:selector])
        return;
    void (*function)(id, SEL, CGFloat) = (void (*)(id, SEL, CGFloat))[layer methodForSelector:selector];
    if (function != NULL)
        function(layer, selector, scale);
}


void OGPlatformSetLabelMinimumScaleFactor(UILabel *label, CGFloat minimumScaleFactor)
{
    if (label == nil)
        return;
    CGFloat factor = MAX(0.0f, minimumScaleFactor);
    SEL selector = NSSelectorFromString(@"setMinimumScaleFactor:");
    if ([label respondsToSelector:selector])
    {
        void (*function)(id, SEL, CGFloat) = (void (*)(id, SEL, CGFloat))[label methodForSelector:selector];
        if (function != NULL)
        {
            function(label, selector, factor);
            return;
        }
    }
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumFontSize = label.font.pointSize * factor;
}

BOOL OGPlatformSuperclassViewTranslatesAutoresizingMaskIntoConstraints(UIView *view, Class currentClass)
{
    if (view == nil)
        return YES;
    NSString *selectorName = @"translatesAutoresizingMaskIntoConstraints";
    IMP implementation = OGPlatformSuperclassImplementation(currentClass, selectorName);
    if (implementation == NULL)
        return YES;
    BOOL (*function)(id, SEL) = (BOOL (*)(id, SEL))implementation;
    return function(view, NSSelectorFromString(selectorName));
}

void OGPlatformSetViewTranslatesAutoresizingMaskIntoConstraints(UIView *view, BOOL enabled)
{
    if (view == nil)
        return;
    SEL selector = NSSelectorFromString(@"setTranslatesAutoresizingMaskIntoConstraints:");
    if (![view respondsToSelector:selector])
        return;
    void (*function)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[view methodForSelector:selector];
    if (function != NULL)
        function(view, selector, enabled);
}

UIEdgeInsets OGPlatformSuperclassViewAlignmentRectInsets(UIView *view, Class currentClass)
{
    if (view == nil)
        return UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
    NSString *selectorName = @"alignmentRectInsets";
    IMP implementation = OGPlatformSuperclassImplementation(currentClass, selectorName);
    if (implementation == NULL)
        return UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
    UIEdgeInsets (*function)(id, SEL) = (UIEdgeInsets (*)(id, SEL))implementation;
    return function(view, NSSelectorFromString(selectorName));
}

CGSize OGPlatformViewIntrinsicContentSize(UIView *view)
{
    if (view == nil)
        return CGSizeZero;
    SEL selector = NSSelectorFromString(@"intrinsicContentSize");
    if ([view respondsToSelector:selector])
    {
        CGSize (*function)(id, SEL) = (CGSize (*)(id, SEL))[view methodForSelector:selector];
        if (function != NULL)
            return function(view, selector);
    }
    return [view sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
}

void OGPlatformInvalidateViewIntrinsicContentSize(UIView *view)
{
    if (view == nil)
        return;
    SEL selector = NSSelectorFromString(@"invalidateIntrinsicContentSize");
    if (![view respondsToSelector:selector])
        return;
    void (*function)(id, SEL) = (void (*)(id, SEL))[view methodForSelector:selector];
    if (function != NULL)
        function(view, selector);
}

void OGPlatformSetTableViewSectionIndexColor(UITableView *tableView, UIColor *color)
{
    OGPlatformSetObjectProperty(tableView, @"setSectionIndexColor:", color);
}

void OGPlatformSetTableViewSectionIndexBackgroundColor(UITableView *tableView, UIColor *color)
{
    OGPlatformSetObjectProperty(tableView, @"setSectionIndexBackgroundColor:", color);
}

void OGPlatformSetTableViewSectionIndexTrackingBackgroundColor(UITableView *tableView, UIColor *color)
{
    OGPlatformSetObjectProperty(tableView, @"setSectionIndexTrackingBackgroundColor:", color);
}

BOOL OGPlatformSetSwitchColors(UISwitch *switchView, UIColor *onTintColor, UIColor *tintColor)
{
    if (switchView == nil || ![switchView respondsToSelector:NSSelectorFromString(@"setOnTintColor:")])
        return NO;
    OGPlatformSetObjectProperty(switchView, @"setOnTintColor:", onTintColor);
    OGPlatformSetObjectProperty(switchView, @"setTintColor:", tintColor);
    return YES;
}

void OGPlatformSetSwitchThumbTintColor(UISwitch *switchView, UIColor *color)
{
    OGPlatformSetObjectProperty(switchView, @"setThumbTintColor:", color);
}

BOOL OGPlatformPresentActivityItems(UIViewController *presenter, NSArray *items, UIView *sourceView, CGRect sourceRect, UIBarButtonItem *barButtonItem, NSUInteger permittedArrowDirections, void (^completion)(void))
{
    if (presenter == nil || items.count == 0)
        return NO;

    Class activityClass = NSClassFromString(@"UIActivityViewController");
    if (activityClass == Nil)
        return NO;

    id activityController = [activityClass alloc];
    SEL initializer = NSSelectorFromString(@"initWithActivityItems:applicationActivities:");
    if (![activityController respondsToSelector:initializer])
        return NO;

    id (*initialize)(id, SEL, id, id) = (id (*)(id, SEL, id, id))[activityController methodForSelector:initializer];
    if (initialize == NULL)
        return NO;

    activityController = initialize(activityController, initializer, items, nil);
    if (activityController == nil)
        return NO;

    id popoverController = OGPlatformObjectProperty(activityController, @"popoverPresentationController");
    if (popoverController != nil)
    {
        if (barButtonItem != nil)
            OGPlatformSetObjectProperty(popoverController, @"setBarButtonItem:", barButtonItem);
        else if (sourceView != nil)
        {
            OGPlatformSetObjectProperty(popoverController, @"setSourceView:", sourceView);
            OGPlatformSetRectProperty(popoverController, @"setSourceRect:", sourceRect);
        }
        OGPlatformSetUnsignedIntegerProperty(popoverController, @"setPermittedArrowDirections:", permittedArrowDirections);
    }

    SEL presentSelector = NSSelectorFromString(@"presentViewController:animated:completion:");
    if (![presenter respondsToSelector:presentSelector])
        return NO;
    void (*present)(id, SEL, id, BOOL, void (^)(void)) = (void (*)(id, SEL, id, BOOL, void (^)(void)))[presenter methodForSelector:presentSelector];
    if (present == NULL)
        return NO;
    present(presenter, presentSelector, activityController, YES, completion);
    return YES;
}

void OGPlatformBeginReceivingRemoteControlEvents(UIApplication *application)
{
    if (application == nil)
        return;
    SEL selector = NSSelectorFromString(@"beginReceivingRemoteControlEvents");
    if (![application respondsToSelector:selector])
        return;
    void (*function)(id, SEL) = (void (*)(id, SEL))[application methodForSelector:selector];
    if (function != NULL)
        function(application, selector);
}

OGPlatformBackgroundTaskIdentifier OGPlatformBeginBackgroundTask(UIApplication *application, void (^expirationHandler)(void))
{
    SEL selector = NSSelectorFromString(@"beginBackgroundTaskWithExpirationHandler:");
    if (application == nil || ![application respondsToSelector:selector])
        return OGPlatformBackgroundTaskInvalid;
    OGPlatformBackgroundTaskIdentifier (*function)(id, SEL, void (^)(void)) = (OGPlatformBackgroundTaskIdentifier (*)(id, SEL, void (^)(void)))[application methodForSelector:selector];
    return function == NULL ? OGPlatformBackgroundTaskInvalid : function(application, selector, expirationHandler);
}

void OGPlatformEndBackgroundTask(UIApplication *application, OGPlatformBackgroundTaskIdentifier identifier)
{
    if (application == nil || identifier == OGPlatformBackgroundTaskInvalid)
        return;
    SEL selector = NSSelectorFromString(@"endBackgroundTask:");
    if (![application respondsToSelector:selector])
        return;
    void (*function)(id, SEL, OGPlatformBackgroundTaskIdentifier) = (void (*)(id, SEL, OGPlatformBackgroundTaskIdentifier))[application methodForSelector:selector];
    if (function != NULL)
        function(application, selector, identifier);
}

void OGPlatformCancelAllLocalNotifications(UIApplication *application)
{
    if (application == nil)
        return;
    SEL selector = NSSelectorFromString(@"cancelAllLocalNotifications");
    if (![application respondsToSelector:selector])
        return;
    void (*function)(id, SEL) = (void (*)(id, SEL))[application methodForSelector:selector];
    if (function != NULL)
        function(application, selector);
}

BOOL OGPlatformViewControllerIsTransitioning(UIViewController *viewController)
{
    return OGPlatformBoolProperty(viewController, @"isBeingDismissed") || OGPlatformBoolProperty(viewController, @"isBeingPresented");
}

NSURL *OGPlatformBundleResourceURL(NSBundle *bundle, NSString *name, NSString *extension)
{
    if (bundle == nil || name.length == 0)
        return nil;
    NSString *path = [bundle pathForResource:name ofType:extension];
    return path.length == 0 ? nil : [NSURL fileURLWithPath:path];
}

void OGPlatformConfigureWebViewMediaPlayback(id webView, BOOL allowsInlinePlayback, BOOL requiresUserAction)
{
    if (webView == nil)
        return;
    SEL inlineSelector = NSSelectorFromString(@"setAllowsInlineMediaPlayback:");
    if ([webView respondsToSelector:inlineSelector])
    {
        void (*setInline)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[webView methodForSelector:inlineSelector];
        if (setInline != NULL)
            setInline(webView, inlineSelector, allowsInlinePlayback);
    }
    SEL actionSelector = NSSelectorFromString(@"setMediaPlaybackRequiresUserAction:");
    if ([webView respondsToSelector:actionSelector])
    {
        void (*setRequiresAction)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[webView methodForSelector:actionSelector];
        if (setRequiresAction != NULL)
            setRequiresAction(webView, actionSelector, requiresUserAction);
    }
}

BOOL OGPlatformCanSendTextMessage(void)
{
    Class composerClass = NSClassFromString(@"MFMessageComposeViewController");
    if (composerClass != Nil)
    {
        SEL selector = NSSelectorFromString(@"canSendText");
        if (![composerClass respondsToSelector:selector])
            return NO;
        BOOL (*function)(id, SEL) = (BOOL (*)(id, SEL))[composerClass methodForSelector:selector];
        return function != NULL && function(composerClass, selector);
    }

    UIApplication *application = [UIApplication sharedApplication];
    NSURL *url = [NSURL URLWithString:@"sms:"];
    return url != nil && [application canOpenURL:url];
}

id OGPlatformCreateTextMessageComposer(id delegate, NSArray *recipients, NSString *body)
{
    Class composerClass = NSClassFromString(@"MFMessageComposeViewController");
    if (composerClass == Nil)
        return nil;

    SEL selector = NSSelectorFromString(@"canSendText");
    if (![composerClass respondsToSelector:selector])
        return nil;
    BOOL (*canSendText)(id, SEL) = (BOOL (*)(id, SEL))[composerClass methodForSelector:selector];
    if (canSendText == NULL || !canSendText(composerClass, selector))
        return nil;

    id composer = [[composerClass alloc] init];
    if (composer == nil)
        return nil;

    OGPlatformSetObjectProperty(composer, @"setRecipients:", recipients);
    OGPlatformSetObjectProperty(composer, @"setMessageComposeDelegate:", delegate);
    OGPlatformSetObjectProperty(composer, @"setBody:", body);
    return composer;
}

NSArray *OGPlatformTextMessageComposerRecipients(id composer)
{
    id value = OGPlatformObjectProperty(composer, @"recipients");
    return [value isKindOfClass:[NSArray class]] ? value : nil;
}

NSString *OGPlatformTextMessageComposerBody(id composer)
{
    id value = OGPlatformObjectProperty(composer, @"body");
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

BOOL OGPlatformOpenTextMessage(NSArray *recipients)
{
    UIApplication *application = [UIApplication sharedApplication];
    NSString *urlString = @"sms:";
    if (recipients.count == 1)
    {
        id value = [recipients objectAtIndex:0];
        if ([value isKindOfClass:[NSString class]] && [value length] != 0)
        {
            NSString *escaped = [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            if (escaped.length != 0)
                urlString = [urlString stringByAppendingString:escaped];
        }
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil || ![application canOpenURL:url])
        return NO;
    return [application openURL:url];
}

id OGPlatformCreateLocalNotification(void)
{
    Class notificationClass = NSClassFromString(@"UILocalNotification");
    return notificationClass == Nil ? nil : [[notificationClass alloc] init];
}

id OGPlatformLocalNotificationFromLaunchOptions(NSDictionary *launchOptions)
{
    if (launchOptions == nil)
        return nil;
    NSString *key = OGPlatformStringConstant("UIApplicationLaunchOptionsLocalNotificationKey", @"UIApplicationLaunchOptionsLocalNotificationKey");
    return [launchOptions objectForKey:key];
}

NSDictionary *OGPlatformLocalNotificationUserInfo(id notification)
{
    id value = OGPlatformObjectProperty(notification, @"userInfo");
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

NSString *OGPlatformLocalNotificationSoundName(id notification)
{
    id value = OGPlatformObjectProperty(notification, @"soundName");
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

void OGPlatformSetLocalNotificationFireDate(id notification, NSDate *fireDate)
{
    OGPlatformSetObjectProperty(notification, @"setFireDate:", fireDate);
}

void OGPlatformSetLocalNotificationAlertBody(id notification, NSString *alertBody)
{
    OGPlatformSetObjectProperty(notification, @"setAlertBody:", alertBody);
}

void OGPlatformSetLocalNotificationSoundName(id notification, NSString *soundName)
{
    OGPlatformSetObjectProperty(notification, @"setSoundName:", soundName);
}

void OGPlatformSetLocalNotificationUserInfo(id notification, NSDictionary *userInfo)
{
    OGPlatformSetObjectProperty(notification, @"setUserInfo:", userInfo);
}

void OGPlatformSetLocalNotificationCategory(id notification, NSString *category)
{
    OGPlatformSetObjectProperty(notification, @"setCategory:", category);
}

void OGPlatformSetLocalNotificationAlertTitle(id notification, NSString *alertTitle)
{
    OGPlatformSetObjectProperty(notification, @"setAlertTitle:", alertTitle);
}

NSString *OGPlatformDefaultLocalNotificationSoundName(void)
{
    return OGPlatformStringConstant("UILocalNotificationDefaultSoundName", @"default");
}

id OGPlatformCreateUserNotificationAction(NSString *identifier, NSString *title, BOOL destructive, BOOL authenticationRequired, BOOL foreground, BOOL textInput)
{
    Class actionClass = NSClassFromString(@"UIMutableUserNotificationAction");
    if (actionClass == Nil || identifier == nil)
        return nil;
    id action = [[actionClass alloc] init];
    [action setValue:identifier forKey:@"identifier"];
    [action setValue:title forKey:@"title"];
    [action setValue:[NSNumber numberWithBool:destructive] forKey:@"destructive"];
    [action setValue:[NSNumber numberWithBool:authenticationRequired] forKey:@"authenticationRequired"];
    [action setValue:[NSNumber numberWithUnsignedInteger:foreground ? 0 : 1] forKey:@"activationMode"];
    if (textInput && [action respondsToSelector:NSSelectorFromString(@"setBehavior:")])
        [action setValue:[NSNumber numberWithUnsignedInteger:1] forKey:@"behavior"];
    return action;
}

id OGPlatformCreateUserNotificationCategory(NSString *identifier, NSArray *defaultActions, NSArray *minimalActions)
{
    Class categoryClass = NSClassFromString(@"UIMutableUserNotificationCategory");
    if (categoryClass == Nil || identifier == nil)
        return nil;
    id category = [[categoryClass alloc] init];
    [category setValue:identifier forKey:@"identifier"];
    SEL selector = NSSelectorFromString(@"setActions:forContext:");
    void (*function)(id, SEL, NSArray *, NSUInteger) = (void (*)(id, SEL, NSArray *, NSUInteger))[category methodForSelector:selector];
    if (function == NULL)
        return category;
    if (defaultActions != nil)
        function(category, selector, defaultActions, 0);
    if (minimalActions != nil)
        function(category, selector, minimalActions, 1);
    return category;
}

BOOL OGPlatformUserNotificationSettingsSupported(UIApplication *application)
{
    return application != nil && NSClassFromString(@"UIUserNotificationSettings") != Nil && [application respondsToSelector:NSSelectorFromString(@"registerUserNotificationSettings:")];
}

BOOL OGPlatformRegisterUserNotificationSettings(UIApplication *application, NSArray *categories)
{
    if (!OGPlatformUserNotificationSettingsSupported(application))
        return NO;
    Class settingsClass = NSClassFromString(@"UIUserNotificationSettings");
    SEL settingsSelector = NSSelectorFromString(@"settingsForTypes:categories:");
    id (*settingsFunction)(id, SEL, NSUInteger, NSSet *) = (id (*)(id, SEL, NSUInteger, NSSet *))[settingsClass methodForSelector:settingsSelector];
    if (settingsFunction == NULL)
        return NO;
    NSUInteger types = (1 << 0) | (1 << 1) | (1 << 2);
    id settings = settingsFunction(settingsClass, settingsSelector, types, categories.count == 0 ? nil : [NSSet setWithArray:categories]);
    if (settings == nil)
        return NO;
    SEL registerSelector = NSSelectorFromString(@"registerUserNotificationSettings:");
    void (*registerFunction)(id, SEL, id) = (void (*)(id, SEL, id))[application methodForSelector:registerSelector];
    if (registerFunction == NULL)
        return NO;
    registerFunction(application, registerSelector, settings);
    return YES;
}

void OGPlatformPresentLocalNotificationNow(UIApplication *application, id notification)
{
    if (application == nil || notification == nil)
        return;
    SEL selector = NSSelectorFromString(@"presentLocalNotificationNow:");
    if (![application respondsToSelector:selector])
        return;
    void (*function)(id, SEL, id) = (void (*)(id, SEL, id))[application methodForSelector:selector];
    if (function != NULL)
        function(application, selector, notification);
}

void OGPlatformScheduleLocalNotification(UIApplication *application, id notification)
{
    if (application == nil || notification == nil)
        return;
    SEL selector = NSSelectorFromString(@"scheduleLocalNotification:");
    if (![application respondsToSelector:selector])
        return;
    void (*function)(id, SEL, id) = (void (*)(id, SEL, id))[application methodForSelector:selector];
    if (function != NULL)
        function(application, selector, notification);
}

void OGPlatformCancelLocalNotification(UIApplication *application, id notification)
{
    if (application == nil || notification == nil)
        return;
    SEL selector = NSSelectorFromString(@"cancelLocalNotification:");
    if (![application respondsToSelector:selector])
        return;
    void (*function)(id, SEL, id) = (void (*)(id, SEL, id))[application methodForSelector:selector];
    if (function != NULL)
        function(application, selector, notification);
}

void OGPlatformApplyLegacySegmentedControlStyle(UISegmentedControl *control, UIColor *tintColor)
{
    if (control == nil)
        return;

    SEL styleSelector = NSSelectorFromString(@"setSegmentedControlStyle:");
    if ([control respondsToSelector:styleSelector])
    {
        void (*setStyle)(id, SEL, NSInteger) = (void (*)(id, SEL, NSInteger))[control methodForSelector:styleSelector];
        if (setStyle != NULL)
            setStyle(control, styleSelector, UISegmentedControlStyleBar);
    }

    SEL tintSelector = NSSelectorFromString(@"setTintColor:");
    if (tintColor != nil && [control respondsToSelector:tintSelector])
    {
        void (*setTint)(id, SEL, id) = (void (*)(id, SEL, id))[control methodForSelector:tintSelector];
        if (setTint != NULL)
            setTint(control, tintSelector, tintColor);
    }
}

void OGPlatformSetSegmentedControlBackgroundImage(UISegmentedControl *control, UIImage *image, UIControlState state, UIBarMetrics barMetrics)
{
    if (control == nil)
        return;
    SEL selector = NSSelectorFromString(@"setBackgroundImage:forState:barMetrics:");
    if ([control respondsToSelector:selector])
    {
        void (*function)(id, SEL, id, UIControlState, UIBarMetrics) = (void (*)(id, SEL, id, UIControlState, UIBarMetrics))[control methodForSelector:selector];
        if (function != NULL)
        {
            function(control, selector, image, state, barMetrics);
            return;
        }
    }
    if (state == UIControlStateNormal)
        OGPlatformApplyLegacySegmentedControlStyle(control, nil);
}

void OGPlatformSetSegmentedControlDividerImage(UISegmentedControl *control, UIImage *image, UIControlState leftState, UIControlState rightState, UIBarMetrics barMetrics)
{
    if (control == nil)
        return;
    SEL selector = NSSelectorFromString(@"setDividerImage:forLeftSegmentState:rightSegmentState:barMetrics:");
    if (![control respondsToSelector:selector])
        return;
    void (*function)(id, SEL, id, UIControlState, UIControlState, UIBarMetrics) = (void (*)(id, SEL, id, UIControlState, UIControlState, UIBarMetrics))[control methodForSelector:selector];
    if (function != NULL)
        function(control, selector, image, leftState, rightState, barMetrics);
}

void OGPlatformSetSegmentedControlTitleTextAttributes(UISegmentedControl *control, NSDictionary *attributes, UIControlState state)
{
    if (control == nil)
        return;
    SEL selector = NSSelectorFromString(@"setTitleTextAttributes:forState:");
    if ([control respondsToSelector:selector])
    {
        void (*function)(id, SEL, id, UIControlState) = (void (*)(id, SEL, id, UIControlState))[control methodForSelector:selector];
        if (function != NULL)
        {
            function(control, selector, attributes, state);
            return;
        }
    }
    if (state == UIControlStateNormal)
    {
        NSString *colorKey = OGPlatformStringConstant("UITextAttributeTextColor", @"UITextAttributeTextColor");
        UIColor *color = [attributes objectForKey:colorKey];
        if ([color isKindOfClass:[UIColor class]])
            OGPlatformApplyLegacySegmentedControlStyle(control, color);
    }
}


void OGPlatformPresentActionSheet(UIActionSheet *actionSheet, UIBarButtonItem *barButtonItem, UIView *sourceView, CGRect sourceRect, UIView *fallbackView, BOOL animated)
{
    if (actionSheet == nil)
        return;

    if (barButtonItem != nil)
    {
        SEL selector = NSSelectorFromString(@"showFromBarButtonItem:animated:");
        if ([actionSheet respondsToSelector:selector])
        {
            void (*function)(id, SEL, id, BOOL) = (void (*)(id, SEL, id, BOOL))[actionSheet methodForSelector:selector];
            if (function != NULL)
            {
                function(actionSheet, selector, barButtonItem, animated);
                return;
            }
        }
    }

    if (sourceView != nil)
    {
        SEL selector = NSSelectorFromString(@"showFromRect:inView:animated:");
        if ([actionSheet respondsToSelector:selector])
        {
            void (*function)(id, SEL, CGRect, id, BOOL) = (void (*)(id, SEL, CGRect, id, BOOL))[actionSheet methodForSelector:selector];
            if (function != NULL)
            {
                function(actionSheet, selector, sourceRect, sourceView, animated);
                return;
            }
        }
    }

    UIView *view = fallbackView != nil ? fallbackView : sourceView;
    if (view != nil)
        [actionSheet showInView:view];
}

void OGPlatformSetPopoverBackgroundColor(id popoverController, UIColor *color)
{
    if (popoverController == nil || color == nil)
        return;
    SEL selector = NSSelectorFromString(@"setBackgroundColor:");
    if (![popoverController respondsToSelector:selector])
        return;
    void (*function)(id, SEL, id) = (void (*)(id, SEL, id))[popoverController methodForSelector:selector];
    if (function != NULL)
        function(popoverController, selector, color);
}


static BOOL OGPlatformViewIsDescendantOfView(UIView *view, UIView *ancestor)
{
    if (view == nil || ancestor == nil)
        return NO;
    UIView *current = view;
    while (current != nil)
    {
        if (current == ancestor)
            return YES;
        current = current.superview;
    }
    return NO;
}

static BOOL OGPlatformViewHasControlAncestor(UIView *view, UIView *rootView)
{
    UIView *current = view.superview;
    while (current != nil && current != rootView)
    {
        if ([current isKindOfClass:[UIControl class]])
            return YES;
        current = current.superview;
    }
    return NO;
}

static void OGPlatformApplyNavigationBarTitleStyleToSubviews(UINavigationBar *navigationBar, UIView *view, UIView *customTitleView, UIColor *textColor, UIColor *shadowColor, CGSize shadowOffset, UIFont *font)
{
    for (UIView *subview in view.subviews)
    {
        if ([subview isKindOfClass:[UILabel class]] && !OGPlatformViewHasControlAncestor(subview, navigationBar) && !OGPlatformViewIsDescendantOfView(subview, customTitleView))
        {
            CGRect frame = [subview convertRect:subview.bounds toView:navigationBar];
            CGFloat centerX = CGRectGetMidX(frame);
            CGFloat navigationCenterX = CGRectGetMidX(navigationBar.bounds);
            CGFloat deltaX = centerX - navigationCenterX;
            if (deltaX < 0.0f)
                deltaX = -deltaX;
            if (deltaX <= navigationBar.bounds.size.width * 0.30f)
            {
                UILabel *label = (UILabel *)subview;
                if (font != nil)
                    label.font = font;
                if (textColor != nil)
                    label.textColor = textColor;
                label.shadowColor = shadowColor;
                label.shadowOffset = shadowOffset;
            }
        }
        OGPlatformApplyNavigationBarTitleStyleToSubviews(navigationBar, subview, customTitleView, textColor, shadowColor, shadowOffset, font);
    }
}

void OGPlatformApplyNavigationBarTitleStyle(UINavigationBar *navigationBar, UIColor *textColor, UIColor *shadowColor, CGSize shadowOffset, UIFont *font)
{
    if (navigationBar == nil)
        return;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    SEL selector = NSSelectorFromString(@"setTitleTextAttributes:");
    if ([navigationBar respondsToSelector:selector])
    {
        NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
        if (textColor != nil)
            [attributes setObject:textColor forKey:UITextAttributeTextColor];
        if (shadowColor != nil)
            [attributes setObject:shadowColor forKey:UITextAttributeTextShadowColor];
        [attributes setObject:[NSValue valueWithUIOffset:UIOffsetMake(shadowOffset.width, shadowOffset.height)] forKey:UITextAttributeTextShadowOffset];
        if (font != nil)
            [attributes setObject:font forKey:UITextAttributeFont];
        void (*function)(id, SEL, id) = (void (*)(id, SEL, id))[navigationBar methodForSelector:selector];
        if (function != NULL)
        {
            function(navigationBar, selector, attributes);
            return;
        }
    }
#endif

    UIView *customTitleView = navigationBar.topItem.titleView;
    OGPlatformApplyNavigationBarTitleStyleToSubviews(navigationBar, navigationBar, customTitleView, textColor, shadowColor, shadowOffset, font);
}
