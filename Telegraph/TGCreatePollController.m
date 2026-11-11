#import "TGCreatePollController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGPreparedPollMessage.h"
#import "TGPollOptionCollectionItem.h"
#import "TGCollectionMultilineInputItem.h"
#import "TGHeaderCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGSwitchCollectionItem.h"
#import "TGCustomAlertView.h"

static const NSUInteger TGCreatePollQuestionMaxLength = 255;
static const NSUInteger TGCreatePollOptionMaxLength = 100;
static const NSUInteger TGCreatePollSolutionMaxLength = 200;
static const NSUInteger TGCreatePollMaxOptions = 10;
static const NSUInteger TGCreatePollMinOptions = 2;

@interface TGCreatePollController ()
{
    bool _allowPublicVoters;
    bool _anonymous;
    bool _multipleChoice;
    bool _quiz;
    NSInteger _correctIndex;
    NSString *_question;
    NSString *_solution;
    NSMutableArray *_optionItems;

    TGCollectionMultilineInputItem *_questionItem;
    TGButtonCollectionItem *_addOptionItem;
    TGCommentCollectionItem *_optionsFooterItem;
    TGSwitchCollectionItem *_anonymousItem;
    TGSwitchCollectionItem *_multipleChoiceItem;
    TGSwitchCollectionItem *_quizItem;
    TGCollectionMultilineInputItem *_solutionItem;

    TGCollectionMenuSection *_optionsSection;
    TGCollectionMenuSection *_settingsSection;
    TGCollectionMenuSection *_solutionSection;
}

@end

@implementation TGCreatePollController

- (instancetype)initWithAllowPublicVoters:(bool)allowPublicVoters quiz:(bool)quiz
{
    self = [super init];
    if (self != nil)
    {
        _allowPublicVoters = allowPublicVoters;
        _anonymous = true;
        _quiz = quiz;
        _correctIndex = -1;
        _question = @"";
        _solution = @"";
        _optionItems = [[NSMutableArray alloc] init];

        [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelPressed)] animated:false];
        [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"CreatePoll.Send") style:UIBarButtonItemStyleDone target:self action:@selector(sendPressed)] animated:false];

        __weak TGCreatePollController *weakSelf = self;
        void (^heightChanged)(void) = ^
        {
            __strong TGCreatePollController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                [strongSelf.collectionLayout invalidateLayout];
                [strongSelf.collectionView layoutSubviews];
            }
        };

        _questionItem = [[TGCollectionMultilineInputItem alloc] init];
        _questionItem.placeholder = TGLocalized(@"CreatePoll.QuestionPlaceholder");
        _questionItem.maxLength = TGCreatePollQuestionMaxLength;
        _questionItem.disallowNewLines = false;
        _questionItem.textChanged = ^(NSString *text)
        {
            __strong TGCreatePollController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            strongSelf->_question = text ?: @"";
            [strongSelf updateNavigation];
        };
        _questionItem.heightChanged = heightChanged;
        TGCollectionMenuSection *questionSection = [[TGCollectionMenuSection alloc] initWithItems:@[[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"CreatePoll.Question")], _questionItem]];
        questionSection.insets = UIEdgeInsetsMake(24.0f, 0.0f, 16.0f, 0.0f);
        [self.menuSections addSection:questionSection];

        _addOptionItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"CreatePoll.AddOption") action:@selector(addOptionPressed)];
        _addOptionItem.deselectAutomatically = true;
        _optionsFooterItem = [[TGCommentCollectionItem alloc] initWithText:@""];
        _optionsSection = [[TGCollectionMenuSection alloc] initWithItems:@[]];
        [self.menuSections addSection:_optionsSection];

        for (NSUInteger index = 0; index < TGCreatePollMinOptions; index++)
            [_optionItems addObject:[self createOptionItem]];

        _anonymousItem = [[TGSwitchCollectionItem alloc] initWithTitle:TGLocalized(@"CreatePoll.Anonymous") isOn:_anonymous];
        _anonymousItem.toggled = ^(bool value, __unused TGSwitchCollectionItem *item)
        {
            __strong TGCreatePollController *strongSelf = weakSelf;
            if (strongSelf != nil)
                strongSelf->_anonymous = value;
        };
        _multipleChoiceItem = [[TGSwitchCollectionItem alloc] initWithTitle:TGLocalized(@"CreatePoll.MultipleChoice") isOn:_multipleChoice];
        _multipleChoiceItem.toggled = ^(bool value, __unused TGSwitchCollectionItem *item)
        {
            __strong TGCreatePollController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            strongSelf->_multipleChoice = value;
            if (value && strongSelf->_quiz)
                [strongSelf setQuiz:false];
        };
        _quizItem = [[TGSwitchCollectionItem alloc] initWithTitle:TGLocalized(@"CreatePoll.Quiz") isOn:_quiz];
        _quizItem.toggled = ^(bool value, __unused TGSwitchCollectionItem *item)
        {
            __strong TGCreatePollController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf setQuiz:value];
        };
        NSMutableArray *settingsItems = [[NSMutableArray alloc] init];
        [settingsItems addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"CreatePoll.Settings")]];
        if (_allowPublicVoters)
            [settingsItems addObject:_anonymousItem];
        [settingsItems addObject:_multipleChoiceItem];
        [settingsItems addObject:_quizItem];
        [settingsItems addObject:[[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"CreatePoll.QuizInfo")]];
        _settingsSection = [[TGCollectionMenuSection alloc] initWithItems:settingsItems];
        [self.menuSections addSection:_settingsSection];

        _solutionItem = [[TGCollectionMultilineInputItem alloc] init];
        _solutionItem.placeholder = TGLocalized(@"CreatePoll.SolutionPlaceholder");
        _solutionItem.maxLength = TGCreatePollSolutionMaxLength;
        _solutionItem.textChanged = ^(NSString *text)
        {
            __strong TGCreatePollController *strongSelf = weakSelf;
            if (strongSelf != nil)
                strongSelf->_solution = text ?: @"";
        };
        _solutionItem.heightChanged = heightChanged;
        _solutionSection = [[TGCollectionMenuSection alloc] initWithItems:@[[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"CreatePoll.Solution")], _solutionItem, [[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"CreatePoll.SolutionInfo")]]];

        [self updateTitle];
        [self rebuildOptionsSection:false];
        [self updateSolutionSection];
        [self updateNavigation];
    }
    return self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_question.length == 0)
        [_questionItem becomeFirstResponder];
}

- (void)updateTitle
{
    self.title = _quiz ? TGLocalized(@"CreatePoll.QuizTitle") : TGLocalized(@"CreatePoll.Title");
}

- (TGPollOptionCollectionItem *)createOptionItem
{
    TGPollOptionCollectionItem *item = [[TGPollOptionCollectionItem alloc] init];
    item.placeholder = TGLocalized(@"CreatePoll.OptionPlaceholder");
    item.maxLength = TGCreatePollOptionMaxLength;
    item.quiz = _quiz;
    __weak TGCreatePollController *weakSelf = self;
    __weak TGPollOptionCollectionItem *weakItem = item;
    item.textChanged = ^(__unused NSString *text)
    {
        __strong TGCreatePollController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf updateNavigation];
    };
    item.heightChanged = ^
    {
        __strong TGCreatePollController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            [strongSelf.collectionLayout invalidateLayout];
            [strongSelf.collectionView layoutSubviews];
        }
    };
    item.returned = ^
    {
        __strong TGCreatePollController *strongSelf = weakSelf;
        __strong TGPollOptionCollectionItem *strongItem = weakItem;
        if (strongSelf != nil && strongItem != nil)
            [strongSelf optionReturned:strongItem];
    };
    item.deletePressed = ^
    {
        __strong TGCreatePollController *strongSelf = weakSelf;
        __strong TGPollOptionCollectionItem *strongItem = weakItem;
        if (strongSelf != nil && strongItem != nil)
            [strongSelf deleteOption:strongItem];
    };
    item.correctPressed = ^
    {
        __strong TGCreatePollController *strongSelf = weakSelf;
        __strong TGPollOptionCollectionItem *strongItem = weakItem;
        if (strongSelf != nil && strongItem != nil)
            [strongSelf selectCorrectOption:strongItem];
    };
    return item;
}

- (void)rebuildOptionsSection:(bool)reload
{
    bool canDelete = _optionItems.count > TGCreatePollMinOptions;
    [_optionItems enumerateObjectsUsingBlock:^(TGPollOptionCollectionItem *item, NSUInteger index, __unused BOOL *stop)
    {
        item.quiz = _quiz;
        item.correct = _quiz && (NSInteger)index == _correctIndex;
        item.canDelete = canDelete;
        item.returnKeyType = index + 1 < _optionItems.count || _optionItems.count < TGCreatePollMaxOptions ? UIReturnKeyNext : UIReturnKeyDone;
    }];

    NSMutableArray *items = [[NSMutableArray alloc] init];
    [items addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"CreatePoll.Options")]];
    [items addObjectsFromArray:_optionItems];
    NSUInteger remaining = TGCreatePollMaxOptions - MIN(TGCreatePollMaxOptions, _optionItems.count);
    if (remaining != 0)
        [items addObject:_addOptionItem];
    if (remaining == 0)
        _optionsFooterItem.text = TGLocalized(@"CreatePoll.OptionsLimitReached");
    else
        _optionsFooterItem.text = [effectiveLocalization() getPluralized:@"CreatePoll.OptionsRemaining" count:(int32_t)remaining];
    if (_quiz)
        _optionsFooterItem.text = [NSString stringWithFormat:@"%@ %@", TGLocalized(@"CreatePoll.SelectCorrect"), _optionsFooterItem.text];
    [items addObject:_optionsFooterItem];
    [_optionsSection replaceItems:items];

    if (reload)
    {
        [self.collectionLayout invalidateLayout];
        [self.collectionView reloadData];
    }
}

- (void)updateSolutionSection
{
    NSUInteger index = [self indexForSection:_solutionSection];
    if (_quiz && index == NSNotFound)
        [self.menuSections insertSection:_solutionSection atIndex:[self indexForSection:_settingsSection] + 1];
    else if (!_quiz && index != NSNotFound)
        [self.menuSections deleteSectionByReference:_solutionSection];
}

- (void)setQuiz:(bool)quiz
{
    if (_quiz == quiz)
        return;
    [self.view endEditing:true];
    _quiz = quiz;
    if (_quizItem.isOn != quiz)
        [_quizItem setIsOn:quiz animated:true];
    if (quiz)
    {
        _multipleChoice = false;
        [_multipleChoiceItem setIsOn:false animated:true];
    }
    else
        _correctIndex = -1;
    [self updateTitle];
    [self updateSolutionSection];
    [self rebuildOptionsSection:true];
    [self updateNavigation];
}

- (void)addOptionPressed
{
    if (_optionItems.count >= TGCreatePollMaxOptions)
        return;
    TGPollOptionCollectionItem *item = [self createOptionItem];
    [_optionItems addObject:item];
    [self rebuildOptionsSection:true];
    [self updateNavigation];
    [self focusItem:item];
}

- (void)focusItem:(TGCollectionMultilineInputItem *)item
{
    __weak TGCollectionMultilineInputItem *weakItem = item;
    dispatch_async(dispatch_get_main_queue(), ^
    {
        __strong TGCollectionMultilineInputItem *strongItem = weakItem;
        [strongItem becomeFirstResponder];
    });
}

- (void)optionReturned:(TGPollOptionCollectionItem *)item
{
    NSUInteger index = [_optionItems indexOfObject:item];
    if (index == NSNotFound)
        return;
    if (index + 1 < _optionItems.count)
        [self focusItem:_optionItems[index + 1]];
    else if (_optionItems.count < TGCreatePollMaxOptions)
        [self addOptionPressed];
    else
        [self.view endEditing:true];
}

- (void)deleteOption:(TGPollOptionCollectionItem *)item
{
    NSUInteger index = [_optionItems indexOfObject:item];
    if (index == NSNotFound || _optionItems.count <= TGCreatePollMinOptions)
        return;
    [self.view endEditing:true];
    [_optionItems removeObjectAtIndex:index];
    if (_correctIndex == (NSInteger)index)
        _correctIndex = -1;
    else if (_correctIndex > (NSInteger)index)
        _correctIndex--;
    [self rebuildOptionsSection:true];
    [self updateNavigation];
}

- (void)selectCorrectOption:(TGPollOptionCollectionItem *)item
{
    NSUInteger index = [_optionItems indexOfObject:item];
    if (index == NSNotFound || !_quiz)
        return;
    _correctIndex = (NSInteger)index;
    [_optionItems enumerateObjectsUsingBlock:^(TGPollOptionCollectionItem *option, NSUInteger optionIndex, __unused BOOL *stop)
    {
        option.correct = (NSInteger)optionIndex == _correctIndex;
    }];
    [self updateNavigation];
}

+ (NSString *)trimmedText:(NSString *)text
{
    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
}

- (NSArray *)filledOptionIndices
{
    NSMutableArray *indices = [[NSMutableArray alloc] init];
    [_optionItems enumerateObjectsUsingBlock:^(TGPollOptionCollectionItem *item, NSUInteger index, __unused BOOL *stop)
    {
        if ([TGCreatePollController trimmedText:item.text].length != 0)
            [indices addObject:@(index)];
    }];
    return indices;
}

- (bool)isDirty
{
    return [TGCreatePollController trimmedText:_question].length != 0 || [self filledOptionIndices].count != 0 || [TGCreatePollController trimmedText:_solution].length != 0;
}

- (void)updateNavigation
{
    self.navigationItem.rightBarButtonItem.enabled = [TGCreatePollController trimmedText:_question].length != 0 && [self filledOptionIndices].count >= TGCreatePollMinOptions;
}

- (void)cancelPressed
{
    [self.view endEditing:true];
    if (![self isDirty])
    {
        [self dismiss];
        return;
    }
    __weak TGCreatePollController *weakSelf = self;
    [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"CreatePoll.DiscardMessage") cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"CreatePoll.Discard") destructive:true completionBlock:^(bool okButtonPressed)
    {
        __strong TGCreatePollController *strongSelf = weakSelf;
        if (okButtonPressed && strongSelf != nil)
            [strongSelf dismiss];
    } disableKeyboardWorkaround:false];
}

- (void)dismiss
{
    [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
}

- (void)presentError:(NSString *)message
{
    [TGCustomAlertView presentAlertWithTitle:nil message:message cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
}

- (void)sendPressed
{
    [self.view endEditing:true];
    NSString *question = [TGCreatePollController trimmedText:_question];
    NSArray *filledIndices = [self filledOptionIndices];
    if (question.length == 0 || filledIndices.count < TGCreatePollMinOptions)
        return;

    NSMutableArray *answers = [[NSMutableArray alloc] init];
    NSMutableSet *uniqueAnswers = [[NSMutableSet alloc] init];
    NSInteger correctIndex = -1;
    for (NSNumber *index in filledIndices)
    {
        NSString *text = [TGCreatePollController trimmedText:((TGPollOptionCollectionItem *)_optionItems[index.unsignedIntegerValue]).text];
        if ([uniqueAnswers containsObject:[text lowercaseString]])
        {
            [self presentError:TGLocalized(@"CreatePoll.ErrorDuplicate")];
            return;
        }
        [uniqueAnswers addObject:[text lowercaseString]];
        if (index.integerValue == _correctIndex)
            correctIndex = (NSInteger)answers.count;
        [answers addObject:text];
    }

    if (_quiz && correctIndex < 0)
    {
        [self presentError:TGLocalized(@"CreatePoll.ErrorSelectCorrect")];
        return;
    }

    TGPreparedPollMessage *pollMessage = [[TGPreparedPollMessage alloc] initWithQuestion:question answers:answers publicVoters:_allowPublicVoters && !_anonymous multipleChoice:_multipleChoice quiz:_quiz correctAnswerIndices:_quiz ? @[@((int32_t)correctIndex)] : nil solution:_quiz ? [TGCreatePollController trimmedText:_solution] : nil replyMessage:nil replyMarkup:nil];
    void (^completion)(TGPreparedPollMessage *) = _completion;
    [self dismiss];
    if (completion)
        completion(pollMessage);
}

@end
