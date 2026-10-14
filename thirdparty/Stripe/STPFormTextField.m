//
//  STPFormTextField.m
//  Stripe
//
//  Created by Jack Flintermann on 7/24/15.
//  Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import "STPFormTextField.h"
#import "STPCardValidator.h"
#import "STPPhoneNumberValidator.h"
#import "NSString+Stripe.h"
#import "STPDelegateProxy.h"
#import "STPWeakStrongMacros.h"
#import "../../OnegramPlatform/OGPlatformUIKit.h"

#define FAUXPAS_IGNORED_IN_METHOD(...)

@interface STPTextFieldDelegateProxy : STPDelegateProxy
@property(nonatomic, assign)STPFormTextFieldAutoFormattingBehavior autoformattingBehavior;
@property(nonatomic, assign)BOOL selectionEnabled;
@end

@implementation STPTextFieldDelegateProxy

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    BOOL deleting = (range.location == textField.text.length - 1 && range.length == 1 && [string isEqualToString:@""]);
    NSString *inputText;
    if (deleting) {
        NSString *sanitized = [self unformattedStringForString:textField.text];
        inputText = [sanitized stp_safeSubstringToIndex:sanitized.length - 1];
    } else {
        NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        NSString *sanitized = [self unformattedStringForString:newString];
        inputText = sanitized;
    }
    
    if ([textField.text isEqualToString:inputText]) {
        return NO;
    }
    
    textField.text = inputText;
    
    if (self.autoformattingBehavior == STPFormTextFieldAutoFormattingBehaviorNone && self.selectionEnabled) {
        NSInteger cursorOffset = range.location + string.length;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 32000
        UITextPosition *newCursorPosition = [textField positionFromPosition:textField.beginningOfDocument offset:cursorOffset];
        UITextRange *newSelectedRange = [textField textRangeFromPosition:newCursorPosition toPosition:newCursorPosition];
        [textField setSelectedTextRange:newSelectedRange];
#else
        OGPlatformSetTextFieldSelectionRange(textField, NSMakeRange((NSUInteger)cursorOffset, 0));
#endif
    }
    
    return NO;
}

- (NSString *)unformattedStringForString:(NSString *)string {
    switch (self.autoformattingBehavior) {
        case STPFormTextFieldAutoFormattingBehaviorNone:
            return string;
        case STPFormTextFieldAutoFormattingBehaviorCardNumbers:
        case STPFormTextFieldAutoFormattingBehaviorPhoneNumbers:
        case STPFormTextFieldAutoFormattingBehaviorExpiration:
            return [STPCardValidator sanitizedNumericStringForString:string];
    }
}

@end

typedef NSAttributedString* (^STPFormTextTransformationBlock)(NSAttributedString *inputText);

@interface STPFormTextField()
@property(nonatomic)STPTextFieldDelegateProxy *delegateProxy;
@property(nonatomic, copy)STPFormTextTransformationBlock textFormattingBlock;
// This property only exists to disable keyboard loading in Travis CI due to a crash that occurs while trying to load the keyboard. Don't use it outside of tests.
@property(nonatomic)BOOL skipsReloadingInputViews;
@end

@implementation STPFormTextField

@synthesize placeholderColor = _placeholderColor;

- (void)reloadInputViews {
    if (self.skipsReloadingInputViews) {
        return;
    }
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 32000
    [super reloadInputViews];
#endif
}

+ (NSDictionary *)attributesForAttributedString:(NSAttributedString *)attributedString {
    if (attributedString.length == 0) {
        return @{};
    }
    return [attributedString attributesAtIndex:0 longestEffectiveRange:nil inRange:NSMakeRange(0, attributedString.length)];
}

- (void)setSelectionEnabled:(BOOL)selectionEnabled {
    _selectionEnabled = selectionEnabled;
    self.delegateProxy.selectionEnabled = selectionEnabled;
}

- (void)setAutoFormattingBehavior:(STPFormTextFieldAutoFormattingBehavior)autoFormattingBehavior {
    _autoFormattingBehavior = autoFormattingBehavior;
    self.delegateProxy.autoformattingBehavior = autoFormattingBehavior;
    switch (autoFormattingBehavior) {
        case STPFormTextFieldAutoFormattingBehaviorNone:
        case STPFormTextFieldAutoFormattingBehaviorExpiration:
            self.textFormattingBlock = nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 100000
            if ([self respondsToSelector:@selector(setTextContentType:)]) {
                self.textContentType = nil;
            }
#endif
            break;
        case STPFormTextFieldAutoFormattingBehaviorCardNumbers:
            self.textFormattingBlock = ^NSAttributedString *(NSAttributedString *inputString) {
                if (![STPCardValidator stringIsNumeric:inputString.string]) {
                    return [inputString copy];
                }
                NSMutableAttributedString *attributedString = [inputString mutableCopy];
                NSArray *cardSpacing;
                STPCardBrand currentBrand = [STPCardValidator brandForNumber:attributedString.string];
                if (currentBrand == STPCardBrandAmex) {
                    cardSpacing = @[@3, @9];
                } else {
                    cardSpacing = @[@3, @7, @11];
                }
                for (NSUInteger i = 0; i < attributedString.length; i++) {
                    if ([cardSpacing containsObject:@(i)]) {
                        [attributedString addAttribute:NSKernAttributeName value:@(5)
                                                 range:NSMakeRange(i, 1)];
                    } else {
                        [attributedString addAttribute:NSKernAttributeName value:@(0)
                                                 range:NSMakeRange(i, 1)];
                    }
                }
                return [attributedString copy];
            };
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 100000
            if ([self respondsToSelector:@selector(setTextContentType:)]) {
                self.textContentType = UITextContentTypeCreditCardNumber;
            }
#endif
            break;
        case STPFormTextFieldAutoFormattingBehaviorPhoneNumbers: {
            WEAK(self);
            self.textFormattingBlock = ^NSAttributedString *(NSAttributedString *inputString) {
                if (![STPCardValidator stringIsNumeric:inputString.string]) {
                    return [inputString copy];
                }
                STRONG(self);
                NSString *phoneNumber = [STPPhoneNumberValidator formattedSanitizedPhoneNumberForString:inputString.string];
                NSDictionary *attributes = [[self class] attributesForAttributedString:inputString];
                return [[NSAttributedString alloc] initWithString:phoneNumber attributes:attributes];
            };
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 100000
            if ([self respondsToSelector:@selector(setTextContentType:)]) {
                self.textContentType = UITextContentTypeTelephoneNumber;
            }
#endif
            break;
        }
    }
}

- (void)setFormDelegate:(id<STPFormTextFieldDelegate>)formDelegate {
    _formDelegate = formDelegate;
    self.delegate = formDelegate;
}

- (void)insertText:(NSString *)text {
    [self setText:[self.text stringByAppendingString:text]];
}

- (BOOL)hasText {
    return self.text.length != 0;
}

- (void)deleteBackward {
    [super deleteBackward];
    if (self.text.length == 0) {
        if ([self.formDelegate respondsToSelector:@selector(formTextFieldDidBackspaceOnEmpty:)]) {
            [self.formDelegate formTextFieldDidBackspaceOnEmpty:self];
        }
    }
}

- (CGSize)measureTextSize {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    return self.attributedText.size;
#else
    return [self.text sizeWithFont:self.font ?: [UIFont systemFontOfSize:17.0f]];
#endif
}

- (void)setText:(NSString *)text {
    NSString *nonNilText = text ?: @"";
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    NSDictionary *attributes = self.defaultTextAttributes;
#else
    NSDictionary *attributes = @{ NSFontAttributeName: self.font ?: [UIFont systemFontOfSize:17.0f], NSForegroundColorAttributeName: self.textColor ?: [UIColor blackColor] };
#endif
    NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:nonNilText attributes:attributes];
    [self setAttributedText:attributed];
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    NSAttributedString *oldValue = [self attributedText];
#else
    NSString *oldValue = [super text];
#endif
    BOOL shouldModify = self.formDelegate && [self.formDelegate respondsToSelector:@selector(formTextField:modifyIncomingTextChange:)];
    NSAttributedString *modified = shouldModify ?
        [self.formDelegate formTextField:self modifyIncomingTextChange:attributedText] :
        attributedText;
    NSAttributedString *transformed = self.textFormattingBlock ? self.textFormattingBlock(modified) : modified;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    [super setAttributedText:transformed];
#else
    [super setText:transformed.string];
#endif
    [self sendActionsForControlEvents:UIControlEventEditingChanged];
    if ([self.formDelegate respondsToSelector:@selector(formTextFieldTextDidChange:)]) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
        if (![transformed isEqualToAttributedString:oldValue]) {
#else
        if (![transformed.string isEqualToString:oldValue]) {
#endif
            [self.formDelegate formTextFieldTextDidChange:self];
        }
    }
}

- (void)setPlaceholder:(NSString *)placeholder {
    NSString *nonNilPlaceholder = placeholder ?: @"";
    NSAttributedString *attributedPlaceholder = [[NSAttributedString alloc] initWithString:nonNilPlaceholder attributes:[self placeholderTextAttributes]];
    [self setAttributedPlaceholder:attributedPlaceholder];
}

- (void)setAttributedPlaceholder:(NSAttributedString *)attributedPlaceholder {
    NSAttributedString *transformed = self.textFormattingBlock ? self.textFormattingBlock(attributedPlaceholder) : attributedPlaceholder;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    [super setAttributedPlaceholder:transformed];
#else
    [super setPlaceholder:transformed.string];
#endif
}

- (NSDictionary *)placeholderTextAttributes {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    NSMutableDictionary *defaultAttributes = [[self defaultTextAttributes] mutableCopy];
#else
    NSMutableDictionary *defaultAttributes = [@{ NSFontAttributeName: self.font ?: [UIFont systemFontOfSize:17.0f], NSForegroundColorAttributeName: self.textColor ?: [UIColor blackColor] } mutableCopy];
#endif
    if (self.placeholderColor) {
        defaultAttributes[NSForegroundColorAttributeName] = self.placeholderColor;
    }
    return [defaultAttributes copy];
}

- (void)setDefaultColor:(UIColor *)defaultColor {
    _defaultColor = defaultColor;
    [self updateColor];
}

- (void)setErrorColor:(UIColor *)errorColor {
    _errorColor = errorColor;
    [self updateColor];
}

- (void)setValidText:(BOOL)validText {
    _validText = validText;
    [self updateColor];
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor {
    _placeholderColor = placeholderColor;
    [self setPlaceholder:self.placeholder]; //explicitly rebuild attributed placeholder
}

- (void)updateColor {
    self.textColor = _validText ? self.defaultColor : self.errorColor;
}

// Workaround for http://www.openradar.appspot.com/19374610
- (CGRect)editingRectForBounds:(CGRect)bounds {
    if (UIDevice.currentDevice.systemVersion.integerValue != 8) {
        return [self textRectForBounds:bounds];
    }
    
    CGFloat const scale = UIScreen.mainScreen.scale;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    CGFloat const preferred = self.attributedText.size.height;
#else
    CGFloat const preferred = [self.text sizeWithFont:self.font ?: [UIFont systemFontOfSize:17.0f]].height;
#endif
    CGFloat const delta = (CGFloat)ceil(preferred) - preferred;
    CGFloat const adjustment = (CGFloat)floor(delta * scale) / scale;
    
    CGRect const textRect = [self textRectForBounds:bounds];
    CGRect const editingRect = CGRectOffset(textRect, 0.0, adjustment);
    
    return editingRect;
}

// Fixes a weird issue related to our custom override of deleteBackwards. This only affects the simulator and iPads with custom keyboards.
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
- (NSArray *)keyCommands {
    FAUXPAS_IGNORED_IN_METHOD(APIAvailability);
    return @[[UIKeyCommand keyCommandWithInput:@"\b" modifierFlags:UIKeyModifierCommand action:@selector(commandDeleteBackwards)]];
}

#endif
- (void)commandDeleteBackwards {
    self.text = @"";
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 32000
- (UITextPosition *)closestPositionToPoint:(CGPoint)point {
    if (self.selectionEnabled) {
        return [super closestPositionToPoint:point];
    }
    return [self positionFromPosition:self.beginningOfDocument offset:self.text.length];
}
#endif

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    return [super canPerformAction:action withSender:sender] && action == @selector(paste:);
}

- (void)paste:(id)sender {
    if (self.preservesContentsOnPaste) {
        [super paste:sender];
    } else {
        self.text = [UIPasteboard generalPasteboard].string;
    }
}

- (void)setDelegate:(id <UITextFieldDelegate>)delegate {
    STPTextFieldDelegateProxy *delegateProxy = [[STPTextFieldDelegateProxy alloc] init];
    delegateProxy.autoformattingBehavior = self.autoFormattingBehavior;
    delegateProxy.selectionEnabled = self.selectionEnabled;
    delegateProxy.delegate = delegate;
    self.delegateProxy = delegateProxy;
    [super setDelegate:delegateProxy];
}

- (id <UITextFieldDelegate>)delegate {
    return self.delegateProxy;
}

@end
