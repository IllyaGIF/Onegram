#import "TGCollectionItemView.h"

@interface TGDialogFilterIconsCollectionItemView : TGCollectionItemView

@property (nonatomic, copy) void (^emoticonSelected)(NSString *emoticon);

+ (CGFloat)heightForWidth:(CGFloat)width count:(NSUInteger)count;

- (void)setEmoticons:(NSArray *)emoticons selectedEmoticon:(NSString *)selectedEmoticon;

@end
