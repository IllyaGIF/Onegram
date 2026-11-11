#import "TGCollectionItem.h"

@interface TGDialogFilterIconsCollectionItem : TGCollectionItem

@property (nonatomic, strong) NSString *selectedEmoticon;
@property (nonatomic, copy) void (^emoticonSelected)(NSString *emoticon);

@end
