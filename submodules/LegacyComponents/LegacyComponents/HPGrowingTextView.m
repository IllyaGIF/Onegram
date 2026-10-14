#import "HPGrowingTextView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "OGPlatformText.h"

#import "HPTextViewInternal.h"

#import "TGInputTextTag.h"

#import "TGMessage.h"

#import "TGColor.h"

NSString *TGMentionUidAttributeName = @"TGMentionUidAttributeName";
NSString *TGMentionBoldAttributeName = @"TGMentionBoldAttributeName";

@implementation TGAttributedTextRange

- (instancetype)initWithAttachment:(id)attachment {
    self = [super init];
    if (self != nil) {
        _attachment = attachment;
    }
    return self;
}

@end

@interface HPGrowingTextView ()
{
    UIColor *_intrinsicTextColor;
    UIFont *_intrinsicTextFont;
    
    __weak TGKeyCommandController *_keyCommandController;
    CGFloat _maxLinesMeasurementWidth;
    CGFloat _minLinesMeasurementWidth;
    UIFont *_maxLinesMeasurementFont;
    UIFont *_minLinesMeasurementFont;
}

@end

@implementation HPGrowingTextView

- (instancetype)initWithKeyCommandController:(TGKeyCommandController *)keyCommandController
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _keyCommandController = keyCommandController;
        
        [self commonInitialiser];
    }
    return self;
}

- (NSDictionary *)defaultAttributes
{
    if (iosMajorVersion() < 6)
        return nil;
    
    if (_intrinsicTextFont == nil)
        return @{NSFontAttributeName: TGSystemFontOfSize(17)};
    else
    {
        if (_intrinsicTextColor)
            return @{NSFontAttributeName: _intrinsicTextFont, NSForegroundColorAttributeName: _intrinsicTextColor};
        else
            return @{NSFontAttributeName: _intrinsicTextFont};
    }
}

- (void)commonInitialiser
{
    CGRect frame = self.frame;
    frame.origin = CGPointZero;
    _internalTextView = [[HPTextViewInternal alloc] initWithKeyCommandController:_keyCommandController];
    _internalTextView.frame = frame;
    _internalTextView.delegate = self;
    _internalTextView.contentInset = UIEdgeInsetsZero;
    _internalTextView.showsHorizontalScrollIndicator = NO;
    if (iosMajorVersion() >= 6)
        _internalTextView.attributedText = [[NSAttributedString alloc] initWithString:@"-" attributes:[self defaultAttributes]];
    else
        _internalTextView.text = @"-";
    _internalTextView.scrollsToTop = false;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (iosMajorVersion() >= 7) {
        _internalTextView.textContainer.layoutManager.allowsNonContiguousLayout = true;
        if (iosMajorVersion() >= 6)
            _internalTextView.allowsEditingTextAttributes = true;
    }
#endif
    [self addSubview:_internalTextView];
    
    _minHeight = _internalTextView.frame.size.height;
    _minNumberOfLines = 1;
    
    _animateHeightChange = true;
    _animationDuration = 0.1f;
    
    if (iosMajorVersion() >= 6)
        _internalTextView.attributedText = [[NSAttributedString alloc] initWithString:@"" attributes:[self defaultAttributes]];
    else
        _internalTextView.text = @"";
}

- (void)setDisableFormatting:(bool)disableFormatting
{
    _disableFormatting = disableFormatting;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (iosMajorVersion() >= 7)
        if (iosMajorVersion() >= 6)
            _internalTextView.allowsEditingTextAttributes = !disableFormatting;
#endif
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    frame.origin = CGPointZero;
    if (!CGRectEqualToRect(_internalTextView.frame, frame)) {
        bool freezeContentOffset = _internalTextView.freezeContentOffset;
        _internalTextView.freezeContentOffset = true;
        _internalTextView.frame = frame;
        _internalTextView.freezeContentOffset = freezeContentOffset;
    }
}

- (CGSize)sizeThatFits:(CGSize)size
{
    if ((iosMajorVersion() >= 6 ? self.attributedText.length : self.text.length) == 0)
        size.height = _minHeight;
    
    return size;
}

- (CGFloat)heightForNumberOfLines:(int)numberOfLines
{
    UIFont *font = _intrinsicTextFont ?: _internalTextView.font;
    CGFloat verticalPadding = 16.0f;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (iosMajorVersion() >= 7)
        verticalPadding = _internalTextView.textContainerInset.top + _internalTextView.textContainerInset.bottom;
#endif
    CGFloat height = CGCeil(OGPlatformFontLineHeight(font) * MAX(1, numberOfLines) + verticalPadding);
    if (iosMajorVersion() < 6)
        return height;
    UITextView *measurementView = [[UITextView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, MAX(1.0f, _internalTextView.bounds.size.width), height)];
    measurementView.font = font;
    measurementView.contentInset = _internalTextView.contentInset;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (iosMajorVersion() >= 7) {
        measurementView.textContainerInset = _internalTextView.textContainerInset;
        measurementView.textContainer.lineFragmentPadding = _internalTextView.textContainer.lineFragmentPadding;
    }
#endif
    NSMutableString *text = [[NSMutableString alloc] initWithString:@"-"];
    for (int i = 1; i < numberOfLines; i++)
        [text appendString:@"\n|W|"];
    if (iosMajorVersion() >= 6)
        measurementView.attributedText = [[NSAttributedString alloc] initWithString:text attributes:[self defaultAttributes]];
    else
        measurementView.text = text;
    [measurementView setNeedsLayout];
    [measurementView layoutIfNeeded];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (iosMajorVersion() >= 7)
        return CGCeil([measurementView sizeThatFits:CGSizeMake(measurementView.bounds.size.width, CGFLOAT_MAX)].height);
#endif
    return MAX(height, CGCeil(measurementView.contentSize.height));
}

- (void)setMaxNumberOfLines:(int)maxNumberOfLines
{
    if (maxNumberOfLines == 0 && _maxHeight > 0)
        return;
    CGFloat width = _internalTextView.bounds.size.width;
    UIFont *font = _intrinsicTextFont ?: _internalTextView.font;
    if (_maxNumberOfLines == maxNumberOfLines && _maxHeight > 0 && _maxLinesMeasurementWidth == width && [_maxLinesMeasurementFont isEqual:font])
        return;
    _maxHeight = [self heightForNumberOfLines:maxNumberOfLines];
    _maxNumberOfLines = maxNumberOfLines;
    _maxLinesMeasurementWidth = width;
    _maxLinesMeasurementFont = font;
    [self sizeToFit];
}

- (void)setMaxHeight:(CGFloat)maxHeight
{
    _maxHeight = maxHeight;
    _maxNumberOfLines = 0;
}

- (void)setMinNumberOfLines:(int)minNumberOfLines
{
    if (minNumberOfLines == 0 && _minHeight > 0)
        return;
    CGFloat width = _internalTextView.bounds.size.width;
    UIFont *font = _intrinsicTextFont ?: _internalTextView.font;
    if (_minNumberOfLines == minNumberOfLines && _minHeight > 0 && _minLinesMeasurementWidth == width && [_minLinesMeasurementFont isEqual:font])
        return;
    _minHeight = [self heightForNumberOfLines:minNumberOfLines];
    _minNumberOfLines = minNumberOfLines;
    _minLinesMeasurementWidth = width;
    _minLinesMeasurementFont = font;
    [self sizeToFit];
}

- (void)setMinHeight:(CGFloat)minHeight
{
    _minHeight = minHeight;
    _minNumberOfLines = 0;
}

- (void)textViewDidChange:(UITextView *)__unused textView
{
    [self refreshAttributes];
    
    [self refreshHeight:true];
    if (self.showPlaceholderWhenFocussed)
        _placeholderView.hidden = [_internalTextView hasText];
}

- (void)textViewDidChangeSelection:(UITextView *)__unused textView
{
    id<HPGrowingTextViewDelegate> delegate = _delegate;
    
    if ([delegate respondsToSelector:@selector(growingTextViewDidChangeSelection:)])
        [delegate growingTextViewDidChangeSelection:self];
    
    [_internalTextView textViewEnsureSelectionVisible];
}

- (void)refreshHeight:(bool)textChanged
{
    CGFloat newSizeH = [self measureHeight];
    if (newSizeH < _minHeight || !_internalTextView.hasText)
        newSizeH = _minHeight;
    if (_maxHeight > 0.0f)
        newSizeH = MIN(newSizeH, MAX(_minHeight, _maxHeight));

    id<HPGrowingTextViewDelegate> delegate = _delegate;
    bool heightChanged = ABS(_internalTextView.frame.size.height - newSizeH) > FLT_EPSILON || _oneTimeLongAnimation;
    if (heightChanged) {
        NSTimeInterval duration = 0.0;
        if (_animateHeightChange && !_internalTextView.isPasting) {
            duration = _oneTimeLongAnimation ? 0.3 : 0.12;
            if (_oneTimeLongAnimation && iosMajorVersion() < 7)
                duration *= 0.7;
        }
        _oneTimeLongAnimation = false;
        if (duration > 0.0) {
            [UIView animateWithDuration:duration delay:0 options:(UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState) animations:^{
                [self resizeTextView:newSizeH];
            } completion:nil];
        } else {
            [self resizeTextView:newSizeH];
        }
        if ([delegate respondsToSelector:@selector(growingTextView:willChangeHeight:duration:animationCurve:)])
            [delegate growingTextView:self willChangeHeight:newSizeH duration:duration animationCurve:0];
    }

    if (textChanged && [delegate respondsToSelector:@selector(growingTextViewDidChange:afterSetText:afterPastingText:)])
        [delegate growingTextViewDidChange:self afterSetText:_ignoreChangeNotification afterPastingText:_internalTextView.isPasting];
    if (heightChanged || textChanged)
        [_internalTextView textViewEnsureSelectionVisible];

    _oneTimeLongAnimation = false;
}

- (void)notifyHeight {
    id<HPGrowingTextViewDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(growingTextView:willChangeHeight:duration:animationCurve:)])
        [delegate growingTextView:self willChangeHeight:_internalTextView.frame.size.height duration:0.0 animationCurve:0];
}

- (CGFloat)measureHeight
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (iosMajorVersion() >= 7)
    {
        return CGCeil([_internalTextView sizeThatFits:CGSizeMake(MAX(1.0f, _internalTextView.bounds.size.width), CGFLOAT_MAX)].height);
    }
    else
#endif
    {
        return CGFloor(self.internalTextView.contentSize.height);
    }
}

- (void)resizeTextView:(CGFloat)newSizeH
{
    CGRect internalTextViewFrame = self.frame;
    internalTextViewFrame.size.height = CGFloor(newSizeH);
    self.frame = internalTextViewFrame;
    
    internalTextViewFrame.origin = CGPointZero;
    if(!CGRectEqualToRect(_internalTextView.frame, internalTextViewFrame))
        _internalTextView.frame = internalTextViewFrame;
    
}

- (BOOL)becomeFirstResponder
{
    return [_internalTextView becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
	return [_internalTextView resignFirstResponder];
}

- (BOOL)isFirstResponder
{
    return [_internalTextView isFirstResponder];
}

- (BOOL)canBecomeFirstResponder
{
    return [_internalTextView canBecomeFirstResponder];
}

- (void)setText:(NSString *)newText
{
    [self setText:newText animated:true];
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    [self setAttributedText:attributedText animated:true];
}

- (NSAttributedString *)attributedText {
    if (iosMajorVersion() < 6)
        return nil;

    return _internalTextView.attributedText;
}

- (void)setText:(NSString *)newText animated:(bool)animated {
    if (iosMajorVersion() < 6)
    {
        _internalTextView.text = newText == nil ? @"" : newText;
        _placeholderView.hidden = _internalTextView.text.length != 0 || [_internalTextView isFirstResponder];

        bool previousAnimateHeightChange = _animateHeightChange;
        _animateHeightChange = animated;
        _ignoreChangeNotification = true;
        [self performSelector:@selector(textViewDidChange:) withObject:_internalTextView];
        _ignoreChangeNotification = false;
        _animateHeightChange = previousAnimateHeightChange;
        return;
    }

    [self setAttributedText:[[NSAttributedString alloc] initWithString:newText == nil ? @"" : newText attributes:[self defaultAttributes]] animated:animated];
}

- (void)setAttributedText:(NSAttributedString *)newText animated:(bool)animated {
    [self setAttributedText:newText keepFormatting:false animated:animated];
}

- (void)setAttributedText:(NSAttributedString *)newText keepFormatting:(bool)keepFormatting animated:(bool)animated {
    if (iosMajorVersion() < 6)
    {
        [self setText:newText == nil ? @"" : newText.string animated:animated];
        return;
    }

    NSMutableAttributedString *fixedFontString = [[NSMutableAttributedString alloc] initWithAttributedString:newText];
    if (!keepFormatting)
    {
        [fixedFontString removeAttribute:NSFontAttributeName range:NSMakeRange(0, fixedFontString.length)];
        [fixedFontString addAttribute:NSFontAttributeName value:_intrinsicTextFont == nil ? [UIFont systemFontOfSize:17.0f] : _intrinsicTextFont range:NSMakeRange(0, fixedFontString.length)];
    }
    
    _internalTextView.attributedText = fixedFontString;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    _internalTextView.typingAttributes = [self defaultAttributes];
#endif
    _placeholderView.hidden = fixedFontString.length != 0 || [_internalTextView isFirstResponder];
    
    
    bool previousAnimateHeightChange = _animateHeightChange;
    _animateHeightChange = animated;
    _ignoreChangeNotification = true;
    [self performSelector:@selector(textViewDidChange:) withObject:_internalTextView];
    _ignoreChangeNotification = false;
    _animateHeightChange = previousAnimateHeightChange;
}

- (void)selectRange:(NSRange)range force:(bool)force {
    if (range.length != 0 || force) {
        NSUInteger length = _internalTextView.text.length;
        if (range.location > length)
            range.location = length;
        if (range.length > length - range.location)
            range.length = length - range.location;
        _internalTextView.selectedRange = range;
    }
}

-(NSString *)text
{
    return _internalTextView.text;
}

- (void)setFont:(UIFont *)afont
{
	_internalTextView.font = afont;
    _intrinsicTextFont = afont;
	
	[self setMaxNumberOfLines:_maxNumberOfLines];
	[self setMinNumberOfLines:_minNumberOfLines];
}

- (UIFont *)font
{
    return _intrinsicTextFont;
}

- (void)setTextColor:(UIColor *)color
{
	_internalTextView.textColor = color;
    _intrinsicTextColor = color;
}

- (UIColor *)textColor
{
	return _internalTextView.textColor;
}

- (UIColor *)accentColor
{
    if (_accentColor != nil)
        return _accentColor;
    
    return TGAccentColor();
}

- (void)setTextAlignment:(NSTextAlignment)aligment
{
	_internalTextView.textAlignment = aligment;
}

- (NSTextAlignment)textAlignment
{
	return _internalTextView.textAlignment;
}

#pragma mark -

- (BOOL)textViewShouldBeginEditing:(UITextView *)__unused textView
{
    id<HPGrowingTextViewDelegate> delegate = _delegate;
    
    if ([delegate respondsToSelector:@selector(growingTextViewShouldBeginEditing:)])
        return [delegate growingTextViewShouldBeginEditing:self];
    
    return true;
}

- (void)textViewDidBeginEditing:(UITextView *)__unused textView
{
    [_internalTextView textViewEnsureSelectionVisible];

    id<HPGrowingTextViewDelegate> delegate = _delegate;
    
	if ([delegate respondsToSelector:@selector(growingTextViewDidBeginEditing:)])
		[delegate growingTextViewDidBeginEditing:self];
    
    if (!self.showPlaceholderWhenFocussed && ![_internalTextView hasText])
        _placeholderView.hidden = true;
}

- (void)textViewDidEndEditing:(UITextView *)__unused textView
{
    id<HPGrowingTextViewDelegate> delegate = _delegate;
    
	if ([delegate respondsToSelector:@selector(growingTextViewDidEndEditing:)])
		[delegate growingTextViewDidEndEditing:self];
    
    if (!self.showPlaceholderWhenFocussed)
        _placeholderView.hidden = [_internalTextView hasText];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)atext
{
    id<HPGrowingTextViewDelegate> delegate = _delegate;
    
    if ([delegate respondsToSelector:@selector(growingTextViewEnabled:)]) {
        if (![delegate growingTextViewEnabled:self]) {
            return false;
        }
    }
    
	if (![textView hasText] && [atext isEqualToString:@""])
        return NO;
	
	if ([atext isEqualToString:@"\n"])
    {
        id<HPGrowingTextViewDelegate> delegate = _delegate;
        
		if ([delegate respondsToSelector:@selector(growingTextViewShouldReturn:)])
            return (BOOL)[delegate performSelector:@selector(growingTextViewShouldReturn:) withObject:self];
	}
    
    if (iosMajorVersion() < 6)
        return true;
    
    if (atext.length == 0) {
        if (range.location != 0 && range.length == 1 && range.location < textView.text.length && [textView.text characterAtIndex:range.location] == 0xfffc) {
            NSAttributedString *string = self.attributedText;
            if ([string attributesAtIndex:range.location effectiveRange:nil][NSAttachmentAttributeName] != nil) {
                NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] initWithAttributedString:string];
                [mutableString replaceCharactersInRange:NSMakeRange(range.location - 1, 1) withString:@""];
                NSRange badRange = [mutableString.string rangeOfString:@"\uFFFC"];
                if (badRange.location != NSNotFound)
                    [mutableString replaceCharactersInRange:badRange withString:@""];
                self.attributedText = mutableString;
                
                return false;
            }
        }
    } else if (range.length == 0 && range.location != 0 && range.location <= textView.text.length && [textView.text characterAtIndex:range.location - 1] == 0xfffc) {
        NSAttributedString *string = self.attributedText;
        if (range.location != 0 && [string attributesAtIndex:range.location - 1 effectiveRange:nil][NSAttachmentAttributeName] != nil) {
            NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] initWithAttributedString:string];
            [mutableString replaceCharactersInRange:NSMakeRange(range.location - 1, 0) withString:atext];
            NSRange badRange = [mutableString.string rangeOfString:@"\uFFFC"];
            if (badRange.location != NSNotFound)
                [mutableString replaceCharactersInRange:badRange withString:@""];
            self.attributedText = mutableString;
            
            return false;
        }
    }
	
    return true;
}

- (void)keyCommandPressed:(UIKeyCommand *)keyCommand
{
    id<HPGrowingTextViewDelegate> delegate = _delegate;
    
    if ([delegate respondsToSelector:@selector(growingTextView:receivedReturnKeyCommandWithModifierFlags:)])
        [delegate growingTextView:self receivedReturnKeyCommandWithModifierFlags:keyCommand.modifierFlags];
}

- (NSArray *)keyCommands
{
    if (iosMajorVersion() < 7 || !self.receiveKeyCommands)
        return nil;
    
    return @
    [
     [UIKeyCommand keyCommandWithInput:@"\r" modifierFlags:0 action:@selector(keyCommandPressed:)],
     [UIKeyCommand keyCommandWithInput:@"\r" modifierFlags:UIKeyModifierAlternate action:@selector(keyCommandPressed:)]
    ];
}

- (void)refreshAttributes {
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
    return;
#else
    if (iosMajorVersion() < 7)
        return;

    self.internalTextView.typingAttributes = [self defaultAttributes];
    
    NSAttributedString *string = _internalTextView.textStorage;
    if (string.length == 0) {
        return;
    }
    
    CGPoint contentOffset = _internalTextView.contentOffset;
    [_internalTextView setScrollEnabled:false];
    _internalTextView.disableContentOffsetAnimation = true;
    _internalTextView.freezeContentOffset = true;
    
    NSTextStorage *storage = _internalTextView.textStorage;
    NSMutableArray *colorRanges = [[NSMutableArray alloc] init];
    [storage enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0, storage.length) options:0 usingBlock:^(id color, NSRange range, __unused BOOL *stop) {
        if (!((color == nil && _intrinsicTextColor == nil) || [color isEqual:_intrinsicTextColor]))
            [colorRanges addObject:[NSValue valueWithRange:range]];
    }];
    [storage beginEditing];
    for (NSValue *value in colorRanges) {
        NSRange range = value.rangeValue;
        if (_intrinsicTextColor != nil)
            [storage addAttribute:NSForegroundColorAttributeName value:_intrinsicTextColor range:range];
        else
            [storage removeAttribute:NSForegroundColorAttributeName range:range];
    }

    __block NSMutableArray *inputTextTags = [[NSMutableArray alloc] init];
    [string enumerateAttribute:TGMentionUidAttributeName inRange:NSMakeRange(0, string.length) options:0 usingBlock:^(__unused id value, NSRange range, __unused BOOL *stop) {
        if ([value isKindOfClass:[TGInputTextTag class]]) {
            [inputTextTags addObject:[[TGInputTextTagAndRange alloc] initWithTag:value range:range]];
        }
    }];
    
    [string enumerateAttribute:TGMentionBoldAttributeName inRange:NSMakeRange(0, string.length) options:0 usingBlock:^(__unused id value, NSRange range, __unused BOOL *stop) {
        if ([value isKindOfClass:[TGInputTextTag class]]) {
            [inputTextTags addObject:[[TGInputTextTagAndRange alloc] initWithTag:value range:range]];
        }
    }];
    
    if (inputTextTags != nil) {
        
        static NSCharacterSet *alphanumericSet = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            alphanumericSet = [NSCharacterSet alphanumericCharacterSet];
        });
        
        NSMutableSet *removeTags = [[NSMutableSet alloc] init];
        for (NSInteger i = 0; i < ((NSInteger)inputTextTags.count); i++) {
            TGInputTextTagAndRange *tagAndRange = inputTextTags[i];
            if ([removeTags containsObject:@(tagAndRange.tag.uniqueId)]) {
                [inputTextTags removeObjectAtIndex:i];
                [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                
                i--;
            } else {
                NSInteger j = tagAndRange.range.location;
                while (j < (NSInteger)(tagAndRange.range.location + tagAndRange.range.length)) {
                    unichar c = [string.string characterAtIndex:j];
                    if (c != ' ') {
                        break;
                    }
                    j++;
                }
                
                if (j != (NSInteger)tagAndRange.range.location) {
                    NSRange updatedRange = NSMakeRange(j, tagAndRange.range.location + tagAndRange.range.length - j);
                    [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                    
                    [_internalTextView.textStorage addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                    
                    inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                    
                    i--;
                } else {
                    NSInteger j = tagAndRange.range.location;
                    while (j >= 0) {
                        unichar c = [string.string characterAtIndex:j];
                        if (![alphanumericSet characterIsMember:c]) {
                            break;
                        }
                        j--;
                    }
                    j++;
                    
                    if (j < ((NSInteger)tagAndRange.range.location)) {
                        NSRange updatedRange = NSMakeRange(j, tagAndRange.range.location + tagAndRange.range.length - j);
                        [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                        
                        [_internalTextView.textStorage addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                         
                        inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                        
                        i--;
                    } else {
                        TGInputTextTagAndRange *nextTagAndRange = nil;
                        if (i != ((NSInteger)inputTextTags.count) - 1) {
                            nextTagAndRange = inputTextTags[i + 1];
                        }
                        
                        if (nextTagAndRange == nil || nextTagAndRange.tag.uniqueId != tagAndRange.tag.uniqueId) {
                            NSInteger candidateStart = tagAndRange.range.location + tagAndRange.range.length;
                            NSInteger candidateEnd = nextTagAndRange == nil ? string.length : nextTagAndRange.range.location;
                            NSInteger j = candidateStart;
                            while (j < candidateEnd) {
                                unichar c = [string.string characterAtIndex:j];
                                static NSCharacterSet *alphanumericSet = nil;
                                static dispatch_once_t onceToken;
                                dispatch_once(&onceToken, ^{
                                    alphanumericSet = [NSCharacterSet alphanumericCharacterSet];
                                });
                                if (![alphanumericSet characterIsMember:c]) {
                                    break;
                                }
                                j++;
                            }
                            
                            if (j == candidateStart) {
                                [removeTags addObject:@(tagAndRange.tag.uniqueId)];
                                [_internalTextView.textStorage addAttribute:NSForegroundColorAttributeName value:self.accentColor range:tagAndRange.range];
                            } else {
                                [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                                
                                NSRange updatedRange = NSMakeRange(tagAndRange.range.location, j - tagAndRange.range.location);
                                [_internalTextView.textStorage addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                                inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                                
                                i--;
                            }
                        } else {
                            NSInteger candidateStart = tagAndRange.range.location + tagAndRange.range.length;
                            NSInteger candidateEnd = nextTagAndRange.range.location;
                            NSInteger j = candidateStart;
                            while (j < candidateEnd) {
                                unichar c = [string.string characterAtIndex:j];
                                if (![alphanumericSet characterIsMember:c] && c != ' ') {
                                    break;
                                }
                                j++;
                            }
                            
                            if (j == candidateEnd) {
                                [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                                
                                [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:nextTagAndRange.range];
                                
                                NSRange updatedRange = NSMakeRange(tagAndRange.range.location, nextTagAndRange.range.location + nextTagAndRange.range.length - tagAndRange.range.location);
                                
                                [_internalTextView.textStorage addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                                
                                inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                                [inputTextTags removeObjectAtIndex:i + 1];
                                
                                i--;
                            } else if (j != candidateStart) {
                                [_internalTextView.textStorage removeAttribute:TGMentionUidAttributeName range:tagAndRange.range];
                                
                                NSRange updatedRange = NSMakeRange(tagAndRange.range.location, j - tagAndRange.range.location);
                                [_internalTextView.textStorage addAttribute:TGMentionUidAttributeName value:tagAndRange.tag range:updatedRange];
                                
                                inputTextTags[i] = [[TGInputTextTagAndRange alloc] initWithTag:tagAndRange.tag range:updatedRange];
                                
                                i--;
                            } else {
                                [removeTags addObject:@(tagAndRange.tag.uniqueId)];
                                [_internalTextView.textStorage addAttribute:NSForegroundColorAttributeName value:self.accentColor range:tagAndRange.range];
                            }
                        }
                    }
                }
            }
        }
    }
    
    [storage endEditing];
    _internalTextView.freezeContentOffset = false;
    [_internalTextView setContentOffset:contentOffset];
    _internalTextView.disableContentOffsetAnimation = false;
    [_internalTextView setScrollEnabled:true];
    
    {
    }
#endif
}

- (NSString *)textWithEntities:(__autoreleasing NSArray **)entities
{
    if (iosMajorVersion() < 6)
    {
        if (entities != NULL)
            *entities = @[];
        
        return self.text == nil ? @"" : self.text;
    }
    
    NSAttributedString *string = self.attributedText;
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    [string enumerateAttribute:TGMentionUidAttributeName
                       inRange:NSMakeRange(0, string.length)
                       options:0
                    usingBlock:^(__unused id value, NSRange range, __unused BOOL *stop)
     {
         if ([value isKindOfClass:[TGInputTextTag class]])
         {
             [result addObject:[[TGMessageEntityMentionName alloc]
                                initWithRange:range
                                userId:[((TGInputTextTag *)value).attachment intValue]]];
         }
     }];
    
    if (iosMajorVersion() >= 7)
    {
        [string enumerateAttribute:NSFontAttributeName
                           inRange:NSMakeRange(0, string.length)
                           options:0
                        usingBlock:^(UIFont *font, NSRange range, __unused BOOL *stop)
         {
             NSString *fontDescription = font.description;
             
             if ([fontDescription rangeOfString:@"font-weight: bold"].location != NSNotFound)
             {
                 [result addObject:[[TGMessageEntityBold alloc] initWithRange:range]];
             }
             else if ([fontDescription rangeOfString:@"font-style: italic"].location != NSNotFound)
             {
                 [result addObject:[[TGMessageEntityItalic alloc] initWithRange:range]];
             }
         }];
    }
    
    if (entities != NULL)
        *entities = result;
    
    return string.string;
}

+ (bool)isMentionCharacter:(unichar)character
{
    static NSCharacterSet *characters = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *set = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
        [set formUnionWithCharacterSet:[NSCharacterSet nonBaseCharacterSet]];
        [set addCharactersInString:@"_"];
        characters = [set copy];
    });
    return [characters characterIsMember:character];
}

+ (void)replaceMention:(NSString *)mention inputField:(HPGrowingTextView *)inputField username:(bool)username userId:(int32_t)userId
{
    NSString *replacementText = [mention stringByAppendingString:@" "];

    if (iosMajorVersion() < 6)
    {
        NSInteger index = (NSInteger)inputField.internalTextView.selectedRange.location - 1;
        NSMutableString *text = [NSMutableString stringWithString:inputField.text == nil ? @"" : inputField.text];
        NSRange candidateRange = NSMakeRange(NSNotFound, 0);

        for (NSInteger i = index; i >= 0 && i < (NSInteger)text.length; i--)
        {
            unichar c = [text characterAtIndex:i];
            if (c == '@')
            {
                candidateRange = NSMakeRange(username ? i + 1 : i, username ? index - i : index - i + 1);
                break;
            }
            if (![HPGrowingTextView isMentionCharacter:c])
                break;
        }

        if (candidateRange.location != NSNotFound)
        {
            [text replaceCharactersInRange:candidateRange withString:replacementText];
            [inputField setText:text];
            [inputField selectRange:NSMakeRange(candidateRange.location + replacementText.length, 0) force:true];
        }
        return;
    }
    
    NSMutableAttributedString *text = inputField.internalTextView.attributedText == nil ? [[NSMutableAttributedString alloc] init] : [[NSMutableAttributedString alloc] initWithAttributedString:inputField.internalTextView.attributedText];
    
    NSInteger idx = (NSInteger)inputField.internalTextView.selectedRange.location;
    idx--;
    NSRange candidateMentionRange = NSMakeRange(NSNotFound, 0);
    
    if (idx >= 0 && idx < (int)text.length)
    {
        for (NSInteger i = idx; i >= 0; i--)
        {
            unichar c = [text.string characterAtIndex:i];
            if (c == '@')
            {
                if (i == idx)
                    candidateMentionRange = NSMakeRange(i + 1, 0);
                else
                    candidateMentionRange = NSMakeRange(i + 1, idx - i);
                break;
            }
            
            if (![HPGrowingTextView isMentionCharacter:c])
                break;
        }
    }
    
    if (candidateMentionRange.location != NSNotFound)
    {
        if (!username) {
            candidateMentionRange.location -= 1;
            candidateMentionRange.length += 1;
            
            [text replaceCharactersInRange:candidateMentionRange withString:replacementText];
            
            static int64_t nextId = 0;
            nextId++;
            [text addAttributes:@{TGMentionUidAttributeName: [[TGInputTextTag alloc] initWithUniqueId:nextId left:true attachment:@(userId)]} range:NSMakeRange(candidateMentionRange.location, replacementText.length - 1)];
        } else {
            [text replaceCharactersInRange:candidateMentionRange withString:replacementText];
        }
        
        [inputField setAttributedText:text];
        inputField.internalTextView.selectedRange = NSMakeRange(candidateMentionRange.location + replacementText.length, 0);
    }
}

+ (void)replaceHashtag:(NSString *)hashtag inputField:(HPGrowingTextView *)inputField
{
    if (iosMajorVersion() < 6)
    {
        NSInteger index = (NSInteger)inputField.internalTextView.selectedRange.location - 1;
        NSMutableString *text = [NSMutableString stringWithString:inputField.text == nil ? @"" : inputField.text];
        NSRange candidateRange = NSMakeRange(NSNotFound, 0);

        for (NSInteger i = index; i >= 0 && i < (NSInteger)text.length; i--)
        {
            unichar c = [text characterAtIndex:i];
            if (c == '#')
            {
                candidateRange = NSMakeRange(i + 1, index - i);
                break;
            }
            if (c == ' ')
                break;
        }

        if (candidateRange.location != NSNotFound)
        {
            NSString *replacementText = [hashtag stringByAppendingString:@" "];
            [text replaceCharactersInRange:candidateRange withString:replacementText];
            [inputField setText:text];
            [inputField selectRange:NSMakeRange(candidateRange.location + replacementText.length, 0) force:true];
        }
        return;
    }

    if (inputField.attributedText == nil) {
        return;
    }
    
    static NSCharacterSet *characterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        characterSet = [NSCharacterSet alphanumericCharacterSet];
    });
    
    NSString *replacementText = [hashtag stringByAppendingString:@" "];
    
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithAttributedString:inputField.attributedText];
    
    NSInteger idx = (NSInteger)inputField.internalTextView.selectedRange.location;
    idx--;
    NSRange candidateHashtagRange = NSMakeRange(NSNotFound, 0);
    NSString *string = text.string;
    
    if (idx >= 0 && idx < (int)text.length)
    {
        for (NSInteger i = idx; i >= 0; i--)
        {
            unichar c = [string characterAtIndex:i];
            if (c == '#')
            {
                if (i == idx)
                    candidateHashtagRange = NSMakeRange(i + 1, 0);
                else
                    candidateHashtagRange = NSMakeRange(i + 1, idx - i);
                break;
            }
            
            if (c == ' ' || (![characterSet characterIsMember:c] && c != '_'))
                break;
        }
    }
    
    if (candidateHashtagRange.location != NSNotFound)
    {
        [text replaceCharactersInRange:candidateHashtagRange withString:replacementText];
        [inputField setAttributedText:text];
        inputField.internalTextView.selectedRange = NSMakeRange(candidateHashtagRange.location + replacementText.length, 0);
    }
}

@end
