#import "TGOnegramTranslationCard.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"
#import "../OnegramPlatform/OGPlatformText.h"
#import "../legacy/TelegraphKit/TGCommon.h"

#import "TGPresentation.h"
#import "TGOnegramTranslator.h"
#import "TGOnegramSettings.h"

@interface TGOnegramTranslationCard ()
{
    NSString *_sourceText;
    TGPresentationPallete *_pallete;
    UILabel *_titleLabel;
    UILabel *_languagesLabel;
    UITextView *_textView;
    UIActivityIndicatorView *_activityView;
    UILabel *_errorLabel;
    TGModernButton *_primaryButton;
    TGModernButton *_closeButton;
    TGOnegramTranslation *_translation;
    NSError *_error;
    id<SDisposable> _disposable;
}

@end

@implementation TGOnegramTranslationCard

+ (void)presentForText:(NSString *)text fromController:(UIViewController *)controller
{
    TGOnegramTranslationCard *card = [[TGOnegramTranslationCard alloc] initWithText:text];
    [TGOnegramCardOverlay presentCardView:card placement:TGOnegramCardPlacementCenter parentController:controller];
}

- (instancetype)initWithText:(NSString *)text
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _sourceText = text;
        _pallete = [TGPresentation current].pallete;
        self.backgroundColor = _pallete.menuBackgroundColor;

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSemiboldSystemFontOfSize(17.0f);
        _titleLabel.textColor = _pallete.menuTextColor;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.text = TGLocalized(@"Translator.Title");
        [self addSubview:_titleLabel];

        _languagesLabel = [[UILabel alloc] init];
        _languagesLabel.backgroundColor = [UIColor clearColor];
        _languagesLabel.font = TGSystemFontOfSize(13.0f);
        _languagesLabel.textColor = _pallete.menuSecondaryTextColor;
        _languagesLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_languagesLabel];

        _textView = [[UITextView alloc] init];
        _textView.editable = false;
        _textView.backgroundColor = _pallete.menuSelectionColor;
        _textView.textColor = _pallete.menuTextColor;
        _textView.font = TGSystemFontOfSize(16.0f);
        _textView.layer.cornerRadius = 12.0f;
        _textView.clipsToBounds = true;
        _textView.hidden = true;
        [self addSubview:_textView];

        _activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [_activityView startAnimating];
        [self addSubview:_activityView];

        _errorLabel = [[UILabel alloc] init];
        _errorLabel.backgroundColor = [UIColor clearColor];
        _errorLabel.font = TGSystemFontOfSize(15.0f);
        _errorLabel.textColor = _pallete.menuDestructiveColor;
        _errorLabel.textAlignment = NSTextAlignmentCenter;
        _errorLabel.numberOfLines = 0;
        _errorLabel.hidden = true;
        [self addSubview:_errorLabel];

        _primaryButton = [[TGModernButton alloc] init];
        _primaryButton.backgroundColor = _pallete.menuAccentColor;
        _primaryButton.highlightBackgroundColor = [_pallete.menuAccentColor colorWithAlphaComponent:0.8f];
        _primaryButton.layer.cornerRadius = 12.0f;
        _primaryButton.clipsToBounds = true;
        _primaryButton.titleLabel.font = TGMediumSystemFontOfSize(17.0f);
        [_primaryButton setTitleColor:_pallete.accentContrastColor];
        [_primaryButton addTarget:self action:@selector(primaryPressed) forControlEvents:UIControlEventTouchUpInside];
        _primaryButton.hidden = true;
        [self addSubview:_primaryButton];

        _closeButton = [[TGModernButton alloc] init];
        _closeButton.layer.cornerRadius = 12.0f;
        _closeButton.clipsToBounds = true;
        _closeButton.titleLabel.font = TGSystemFontOfSize(17.0f);
        [_closeButton setTitleColor:_pallete.menuAccentColor];
        _closeButton.highlightBackgroundColor = _pallete.menuSelectionColor;
        [_closeButton setTitle:TGLocalized(@"Common.Close") forState:UIControlStateNormal];
        [_closeButton addTarget:self action:@selector(closePressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_closeButton];

        NSArray *providers = [TGOnegramTranslator providerTitles];
        NSUInteger provider = (NSUInteger)[TGOnegramSettings integerForKey:TGOnegramSettingTranslatorProvider];
        _languagesLabel.text = [[NSString alloc] initWithFormat:TGLocalized(@"Translator.Via"), provider < providers.count ? providers[provider] : providers.firstObject];
        [self translate];
    }
    return self;
}

- (void)dealloc
{
    [_disposable dispose];
}

- (void)translate
{
    _error = nil;
    _translation = nil;
    _errorLabel.hidden = true;
    _primaryButton.hidden = true;
    _textView.hidden = true;
    [_activityView startAnimating];
    [_disposable dispose];
    __weak TGOnegramTranslationCard *weakSelf = self;
    _disposable = [[TGOnegramTranslator translateText:_sourceText] startWithNext:^(TGOnegramTranslation *translation)
    {
        __strong TGOnegramTranslationCard *strongSelf = weakSelf;
        [strongSelf showTranslation:translation];
    } error:^(NSError *error)
    {
        __strong TGOnegramTranslationCard *strongSelf = weakSelf;
        [strongSelf showError:error];
    } completed:nil];
    [self relayout];
}

- (void)relayout
{
    [self setNeedsLayout];
    [self.overlay setNeedsCardLayoutAnimated:true];
}

- (void)showTranslation:(TGOnegramTranslation *)translation
{
    _translation = translation;
    [_activityView stopAnimating];
    NSString *source = translation.sourceLanguage.length != 0 ? [TGOnegramTranslator displayNameForLanguage:translation.sourceLanguage] : TGLocalized(@"Translator.UnknownLanguage");
    _languagesLabel.text = [[NSString alloc] initWithFormat:@"%@ → %@", source, [TGOnegramTranslator displayNameForLanguage:translation.targetLanguage]];
    _textView.text = translation.text;
    _textView.hidden = false;
    [_primaryButton setTitle:TGLocalized(@"Translator.Copy") forState:UIControlStateNormal];
    _primaryButton.hidden = false;
    [self relayout];
}

- (void)showError:(NSError *)error
{
    _error = error;
    [_activityView stopAnimating];
    _errorLabel.text = error.localizedDescription ?: TGLocalized(@"Translator.Error.Generic");
    _errorLabel.hidden = false;
    [_primaryButton setTitle:TGLocalized(@"Translator.Retry") forState:UIControlStateNormal];
    _primaryButton.hidden = false;
    [self relayout];
}

- (CGFloat)layoutForWidth:(CGFloat)width apply:(bool)apply
{
    CGFloat inset = 20.0f;
    CGFloat contentWidth = width - inset * 2.0f;
    CGFloat y = 20.0f;
    if (apply)
        _titleLabel.frame = CGRectMake(inset, y, contentWidth, 22.0f);
    y += 22.0f + 4.0f;
    if (apply)
        _languagesLabel.frame = CGRectMake(inset, y, contentWidth, 18.0f);
    y += 18.0f + 14.0f;

    if (!_textView.hidden)
    {
        CGFloat maximumHeight = MAX(120.0f, [UIScreen mainScreen].bounds.size.height * 0.45f);
        CGFloat textHeight = CGCeil(OGPlatformTextSize(_textView.text, _textView.font, CGSizeMake(contentWidth - 16.0f, CGFLOAT_MAX), UILineBreakModeWordWrap).height) + 20.0f;
        CGFloat height = MIN(maximumHeight, MAX(44.0f, textHeight));
        if (apply)
            _textView.frame = CGRectMake(inset, y, contentWidth, height);
        y += height;
    }
    else if (!_errorLabel.hidden)
    {
        CGFloat errorHeight = CGCeil(OGPlatformTextSize(_errorLabel.text, _errorLabel.font, CGSizeMake(contentWidth, CGFLOAT_MAX), UILineBreakModeWordWrap).height);
        if (apply)
            _errorLabel.frame = CGRectMake(inset, y, contentWidth, errorHeight);
        y += errorHeight;
    }
    else
    {
        if (apply)
            _activityView.center = CGPointMake(width / 2.0f, y + 22.0f);
        y += 44.0f;
    }

    y += 16.0f;
    if (!_primaryButton.hidden)
    {
        if (apply)
            _primaryButton.frame = CGRectMake(inset, y, contentWidth, 48.0f);
        y += 48.0f + 6.0f;
    }
    if (apply)
        _closeButton.frame = CGRectMake(inset, y, contentWidth, 44.0f);
    y += 44.0f + 12.0f;
    return y;
}

- (CGFloat)heightForWidth:(CGFloat)width
{
    return [self layoutForWidth:width apply:false];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self layoutForWidth:self.bounds.size.width apply:true];
}

- (void)primaryPressed
{
    if (_translation != nil)
    {
        [UIPasteboard generalPasteboard].string = _translation.text;
        [_primaryButton setTitle:TGLocalized(@"Translator.Copied") forState:UIControlStateNormal];
        return;
    }
    [self translate];
}

- (void)closePressed
{
    [self.overlay dismissAnimated:true completion:nil];
}

- (void)cardDidDisappear
{
    [_disposable dispose];
    _disposable = nil;
}

@end
