#import "HPTextViewInternal.h"

#import "LegacyComponentsInternal.h"
#import "OGPlatformText.h"
#import "FreedomUIKit.h"

#import "HPGrowingTextView.h"

#import <MobileCoreServices/MobileCoreServices.h>

#import "TGKeyCommandController.h"

static CGPoint HPTextViewClampedContentOffset(CGPoint offset, CGSize contentSize, CGSize viewportSize, UIEdgeInsets insets)
{
    CGFloat minimumX = -insets.left;
    CGFloat minimumY = -insets.top;
    CGFloat maximumX = MAX(minimumX, contentSize.width - viewportSize.width + insets.right);
    CGFloat maximumY = MAX(minimumY, contentSize.height - viewportSize.height + insets.bottom);
    offset.x = isfinite(offset.x) ? MAX(minimumX, MIN(maximumX, offset.x)) : minimumX;
    offset.y = isfinite(offset.y) ? MAX(minimumY, MIN(maximumY, offset.y)) : minimumY;
    return offset;
}

@interface HPTextViewInternal () {
    __weak TGKeyCommandController *_keyCommandController;
    bool _ensuringSelectionVisible;
}

@end

@implementation HPTextViewInternal

- (instancetype)initWithKeyCommandController:(TGKeyCommandController *)keyCommandController {
    self = [super initWithFrame:CGRectZero];
    if (self != nil) {
        _keyCommandController = keyCommandController;
    }
    return self;
}

- (void)setText:(NSString *)text
{
    BOOL originalValue = self.scrollEnabled;
    [self setScrollEnabled:YES];
    [super setText:text];
    [self setScrollEnabled:originalValue];
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    BOOL originalValue = self.scrollEnabled;
    [self setScrollEnabled:YES];
    if (iosMajorVersion() < 6)
        [super setText:attributedText.string];
    else
        [super setAttributedText:attributedText];
    [self setScrollEnabled:originalValue];
}

- (void)setScrollable:(BOOL)isScrollable
{
    [super setScrollEnabled:isScrollable];
}

- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated
{
    if (!_freezeContentOffset)
        [super scrollRectToVisible:rect animated:_disableContentOffsetAnimation ? false : animated];
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated
{
    if (_freezeContentOffset)
        return;
    if (_ensuringSelectionVisible)
        contentOffset = HPTextViewClampedContentOffset(contentOffset, self.contentSize, self.bounds.size, self.contentInset);
    
    [super setContentOffset:contentOffset animated:_disableContentOffsetAnimation ? false : animated];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
}

-(void)setContentOffset:(CGPoint)s
{
    if (_freezeContentOffset)
        return;
    if (_ensuringSelectionVisible)
        s = HPTextViewClampedContentOffset(s, self.contentSize, self.bounds.size, self.contentInset);
    	
	[super setContentOffset:s];
}

- (void)textViewEnsureSelectionVisible
{
    if (![self isFirstResponder] || _freezeContentOffset || _ensuringSelectionVisible || self.tracking || self.dragging || self.decelerating || self.bounds.size.width <= 0.0f || self.bounds.size.height <= 0.0f)
        return;

    _ensuringSelectionVisible = true;
    bool disableContentOffsetAnimation = _disableContentOffsetAnimation;
    _disableContentOffsetAnimation = true;
    [self layoutIfNeeded];
    if (self.text.length == 0) {
        [super setContentOffset:CGPointMake(-self.contentInset.left, -self.contentInset.top) animated:false];
    } else if (iosMajorVersion() >= 7) {
        UITextRange *selection = self.selectedTextRange;
        if (selection != nil) {
            CGRect caret = [self caretRectForPosition:selection.end];
            if (!CGRectIsNull(caret) && !CGRectIsInfinite(caret) && !isnan(caret.origin.x) && !isnan(caret.origin.y))
                [super scrollRectToVisible:CGRectInset(caret, -2.0f, -4.0f) animated:false];
        }
    } else {
        NSRange range = self.selectedRange;
        NSUInteger length = self.text.length;
        if (range.location != NSNotFound) {
            range.location = MIN(range.location, length);
            range.length = MIN(range.length, length - range.location);
            [super scrollRangeToVisible:range];
        }
    }
    [self setContentOffset:self.contentOffset animated:false];
    _disableContentOffsetAnimation = disableContentOffsetAnimation;
    _ensuringSelectionVisible = false;
}

- (BOOL)canBecomeFirstResponder
{
    if (!_enableFirstResponder)
        return false;
    return true;
}

- (BOOL)becomeFirstResponder
{
    if (!_enableFirstResponder)
        return false;
    
    __block BOOL result = false;
    freedomUIKitTest4(^
    {
        if ([self.delegate respondsToSelector:@selector(textViewShouldBeginEditing:)] && ![self.delegate textViewShouldBeginEditing:self])
            result = false;
        else
            result = [super becomeFirstResponder];
    });
    
    if (result)
    {
        id delegate = _responderStateDelegate.object;
        if (delegate != nil && [delegate conformsToProtocol:@protocol(HPTextViewInternalDelegate)])
        {
            [(id<HPTextViewInternalDelegate>)delegate hpTextViewChangedResponderState:true];
        }
    }
    return result;
}

- (BOOL)resignFirstResponder
{
    __block BOOL result = false;
    freedomUIKitTest4(^
    {
        result = [super resignFirstResponder];
    });
    
    if (result)
    {
        id delegate = _responderStateDelegate.object;
        if (delegate != nil && [delegate conformsToProtocol:@protocol(HPTextViewInternalDelegate)])
        {
            [(id<HPTextViewInternalDelegate>)delegate hpTextViewChangedResponderState:false];
        }
    }
    return result;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action == @selector(paste:))
        return true;
    
    if (action == @selector(toggleUnderline:)) {
        return false;
    }
   
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    static SEL promptForReplaceSelector;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        promptForReplaceSelector = NSSelectorFromString(@"_promptForReplace:");
    });
    if (action == promptForReplaceSelector) {
        return false;
    }
#pragma clang diagnostic pop
    
    return [super canPerformAction:action withSender:sender];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
- (id)targetForAction:(SEL)action withSender:(id)__unused sender
{
    if (action == @selector(processKeyCommand:)) {
        TGKeyCommandController *keyCommandController = _keyCommandController;
        return [keyCommandController targetForAction:action withSender:sender];
    }
    
    return [super targetForAction:action withSender:sender];
}
#endif

- (void)paste:(id)sender
{
    UIPasteboard *pasteBoard = [UIPasteboard generalPasteboard];
    
    NSData *gifData = [pasteBoard dataForPasteboardType:@"com.compuserve.gif"];
    if (gifData != nil)
    {
        id delegate = self.delegate;
        if ([delegate isKindOfClass:[HPGrowingTextView class]])
        {
            HPGrowingTextView *textView = delegate;
            NSObject<HPGrowingTextViewDelegate> *textViewDelegate = (NSObject<HPGrowingTextViewDelegate> *)textView.delegate;
            if ([textViewDelegate respondsToSelector:@selector(growingTextView:didPasteData:)])
                [textViewDelegate growingTextView:textView didPasteData:gifData];
        }
    }
    else
    {
        NSMutableArray *images = [NSMutableArray arrayWithCapacity:1];
        NSString *text = nil;
        
        for (NSDictionary *item in pasteBoard.items) {
            if (item[(__bridge NSString *)kUTTypeJPEG] != nil) {
                [images addObject:item[(__bridge NSString *)kUTTypeJPEG]];
            } else if (item[(__bridge NSString *)kUTTypePNG] != nil) {
                [images addObject:item[(__bridge NSString *)kUTTypePNG]];
            } else if (item[(__bridge NSString *)kUTTypeGIF] != nil) {
                [images addObject:item[(__bridge NSString *)kUTTypeGIF]];
            } else if (item[(__bridge NSString *)kUTTypeURL] != nil) {
                id url = item[(__bridge NSString *)kUTTypeURL];
                if ([url respondsToSelector:@selector(characterAtIndex:)]) {
                    text = url;
                } else if ([url isKindOfClass:[NSURL class]]) {
                    text = ((NSURL *)url).absoluteString;
                }
            }
        }
        
        if (images.count != 0)
        {
            id delegate = self.delegate;
            if ([delegate isKindOfClass:[HPGrowingTextView class]])
            {
                HPGrowingTextView *textView = delegate;
                NSObject<HPGrowingTextViewDelegate> *textViewDelegate = (NSObject<HPGrowingTextViewDelegate> *)textView.delegate;
                if ([textViewDelegate respondsToSelector:@selector(growingTextView:didPasteImages:andText:)])
                    [textViewDelegate growingTextView:textView didPasteImages:images andText:text];
            }
        }
        else
        {
            _isPasting = true;
            
            if (iosMajorVersion() >= 6)
            {
                bool previousAllowsEditingTextAttributes = self.allowsEditingTextAttributes;
                self.allowsEditingTextAttributes = false;
                
                [super paste:sender];
                
                self.allowsEditingTextAttributes = previousAllowsEditingTextAttributes;
            }
            else
            {           
                [super paste:sender];
            }
            
            _isPasting = false;
        }
    }
}

@end
