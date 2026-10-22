#import "TGCollectionMultilineInputItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"

@interface TGCollectionMultilineInputItemView () <UITextViewDelegate> {
    UILabel *_placeholderLabel;
    UITextView *_textView;
    UILabel *_countLabel;
}

@end

static const CGFloat TGCollectionMultilineInputRemainingCountWidth = 30.0f;

@implementation TGCollectionMultilineInputItemView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _textView = [[UITextView alloc] initWithFrame:CGRectZero];
        _textView.backgroundColor = [UIColor clearColor];
        _textView.textColor = [UIColor blackColor];
        _textView.font = [TGCollectionMultilineInputItemView font];
        _textView.delegate = self;
        _textView.scrollEnabled = false;
        UIEdgeInsets insets = [TGCollectionMultilineInputItemView insets];
        _textView.contentInset = UIEdgeInsetsMake(insets.top, 0.0f, insets.bottom, 0.0f);
        [self.contentView addSubview:_textView];
        
        _placeholderLabel = [[UILabel alloc] init];
        _placeholderLabel.font = _textView.font;
        _placeholderLabel.textColor = UIColorRGB(0xc7c7cd);
        [self.contentView addSubview:_placeholderLabel];
        
        _countLabel = [[UILabel alloc] init];
        _countLabel.font = _textView.font;
        _countLabel.textColor = UIColorRGB(0xc7c7cd);
        _countLabel.userInteractionEnabled = false;
        _countLabel.hidden = true;
        _countLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_countLabel];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    _textView.textColor = presentation.pallete.collectionMenuTextColor;
    _placeholderLabel.textColor = presentation.pallete.collectionMenuPlaceholderColor;
    _countLabel.textColor = presentation.pallete.collectionMenuPlaceholderColor;
    _countLabel.backgroundColor = presentation.pallete.collectionMenuCellBackgroundColor;
    _textView.keyboardAppearance = presentation.pallete.isDark ? UIKeyboardAppearanceAlert : UIKeyboardAppearanceDefault;
}

+ (UIFont *)font {
    return TGSystemFontOfSize(16.0f);
}

+ (UIEdgeInsets)insets {
    return UIEdgeInsetsMake(13.0f, 11.0f, 13.0f, 11.0f);
}

+ (CGFloat)textHorizontalPadding {
    return iosMajorVersion() < 7 ? 8.0f : 5.0f;
}

+ (CGRect)textViewFrameForBounds:(CGRect)bounds insets:(UIEdgeInsets)additionalInsets safeAreaInset:(UIEdgeInsets)safeAreaInset showRemainingCount:(bool)showRemainingCount {
    UIEdgeInsets insets = [self insets];
    CGFloat left = insets.left + additionalInsets.left + safeAreaInset.left;
    CGFloat right = insets.right + additionalInsets.right + safeAreaInset.right;
    if (showRemainingCount)
        right += TGCollectionMultilineInputRemainingCountWidth;
    return CGRectMake(bounds.origin.x + left, bounds.origin.y, MAX(0.0f, bounds.size.width - left - right), bounds.size.height);
}

+ (CGFloat)heightForText:(NSString *)text textViewWidth:(CGFloat)textViewWidth {
    UIEdgeInsets insets = [self insets];
    CGFloat textWidth = MAX(1.0f, textViewWidth - [self textHorizontalPadding] * 2.0f);
    return CGCeil([text.length == 0 ? @" " : text sizeWithFont:[self font] constrainedToSize:CGSizeMake(textWidth, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping].height + insets.top + insets.bottom);
}

- (void)setPlaceholder:(NSString *)placeholder {
    _placeholder = placeholder;
    _placeholderLabel.text = placeholder;
    [_placeholderLabel sizeToFit];
    [self setNeedsLayout];
}

- (void)setText:(NSString *)text {
    _text = text;
    _textView.text = text;
    _placeholderLabel.hidden = _text.length != 0;
    [self updateRemainingCount];
}

- (void)setMaxLength:(NSUInteger)maxLength {
    _maxLength = maxLength;
    [self updateRemainingCount];
}

- (void)setEditable:(bool)editable {
    _editable = editable;
    _textView.editable = editable;
    _textView.userInteractionEnabled = editable;
}

- (void)setReturnKeyType:(UIReturnKeyType)returnKeyType {
    _textView.returnKeyType = returnKeyType;
}

- (void)setShowRemainingCount:(bool)showRemainingCount
{
    _showRemainingCount = showRemainingCount;
    _countLabel.hidden = !showRemainingCount;
}

- (void)updateRemainingCount {
    _countLabel.text = [NSString stringWithFormat:@"%ld", _maxLength - _text.length];
    [_countLabel sizeToFit];
    [self setNeedsLayout];
}

- (void)setInsets:(UIEdgeInsets)insets
{
    _insets = insets;
    [self setNeedsLayout];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if (_disallowNewLines && [text rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound)
    {
        if ([text isEqualToString:@"\n"])
        {
            [textView resignFirstResponder];
            if (self.returned)
                self.returned();
        }
        else
        {
            NSString *newReplacementText = [[text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
            NSString *newText = [textView.text stringByReplacingCharactersInRange:range withString:newReplacementText];
            NSUInteger length = newText.length;
            if (length > _maxLength)
            {
                NSUInteger difference = length - _maxLength;
                newText = [newText stringByReplacingCharactersInRange:range withString:[newReplacementText substringToIndex:length - difference]];
            }
            
            _textView.text = newText;
            [self textViewDidChange:textView];
        }
        return false;
    }

    NSString *result = [textView.text stringByReplacingCharactersInRange:range withString:text];
    if (_maxLength != 0 && result.length > _maxLength) {
        _textView.text = [result substringToIndex:_maxLength];
        [self textViewDidChange:textView];
        return false;
    }
    return true;
}

- (void)textViewDidChange:(UITextView *)__unused textView {
    _text = _textView.text;
    _placeholderLabel.hidden = _text.length != 0;
    if (_textChanged) {
        _textChanged(_text);
    }
    [self updateRemainingCount];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    UIEdgeInsets insets = [TGCollectionMultilineInputItemView insets];
    CGRect textViewFrame = [TGCollectionMultilineInputItemView textViewFrameForBounds:self.bounds insets:self.insets safeAreaInset:self.safeAreaInset showRemainingCount:!_countLabel.hidden];
    
    _textView.frame = textViewFrame;
    _placeholderLabel.frame = CGRectOffset(_placeholderLabel.bounds, textViewFrame.origin.x + [TGCollectionMultilineInputItemView textHorizontalPadding], insets.top + self.insets.top + TGRetinaPixel);
    _countLabel.frame = CGRectMake(self.bounds.size.width - insets.right - TGCollectionMultilineInputRemainingCountWidth - 4.0f - self.safeAreaInset.right, insets.top + TGRetinaPixel, TGCollectionMultilineInputRemainingCountWidth, _countLabel.frame.size.height);
}

- (BOOL)becomeFirstResponder {
    return [_textView becomeFirstResponder];
}

@end
