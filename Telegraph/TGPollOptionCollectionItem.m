#import "TGPollOptionCollectionItem.h"

#import "TGPollOptionCollectionItemView.h"

static const CGFloat TGPollOptionAccessoryInset = 30.0f;

@implementation TGPollOptionCollectionItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.disallowNewLines = true;
        self.returnKeyType = UIReturnKeyNext;
        [self updateInsets];
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGPollOptionCollectionItemView class];
}

- (void)updateInsets
{
    self.insets = UIEdgeInsetsMake(0.0f, _quiz ? TGPollOptionAccessoryInset : 0.0f, 0.0f, _canDelete ? TGPollOptionAccessoryInset : 0.0f);
}

- (void)bindView:(TGPollOptionCollectionItemView *)view
{
    [super bindView:view];

    [view setQuiz:_quiz correct:_correct canDelete:_canDelete];
    __weak TGPollOptionCollectionItem *weakSelf = self;
    view.deletePressed = ^
    {
        __strong TGPollOptionCollectionItem *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf->_deletePressed)
            strongSelf->_deletePressed();
    };
    view.correctPressed = ^
    {
        __strong TGPollOptionCollectionItem *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf->_correctPressed)
            strongSelf->_correctPressed();
    };
}

- (void)unbindView
{
    TGPollOptionCollectionItemView *view = (TGPollOptionCollectionItemView *)self.boundView;
    view.deletePressed = nil;
    view.correctPressed = nil;
    [super unbindView];
}

- (void)updateView
{
    [self updateInsets];
    [(TGPollOptionCollectionItemView *)self.boundView setQuiz:_quiz correct:_correct canDelete:_canDelete];
}

- (void)setQuiz:(bool)quiz
{
    _quiz = quiz;
    [self updateView];
}

- (void)setCorrect:(bool)correct
{
    _correct = correct;
    [self updateView];
}

- (void)setCanDelete:(bool)canDelete
{
    _canDelete = canDelete;
    [self updateView];
}

@end
