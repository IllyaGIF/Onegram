#import "TGCollectionItem.h"

typedef enum {
    TGProfileMediaTabPosts = 0,
    TGProfileMediaTabGifts = 1
} TGProfileMediaTab;

@interface TGProfileMediaTabsCollectionItem : TGCollectionItem

@property (nonatomic) TGProfileMediaTab selectedTab;
@property (nonatomic, strong) NSArray *stories;
@property (nonatomic) int32_t storiesTotal;
@property (nonatomic) bool storiesLoaded;
@property (nonatomic) bool storiesFailed;
@property (nonatomic) bool showsAddTile;
@property (nonatomic, strong) NSArray *gifts;
@property (nonatomic) int32_t giftsTotal;
@property (nonatomic) bool giftsLoaded;
@property (nonatomic) bool giftsFailed;
@property (nonatomic) bool showsSendTile;
@property (nonatomic) bool showsMediaTab;

@property (nonatomic, copy) void (^storySelected)(NSUInteger index);
@property (nonatomic, copy) void (^addStoryPressed)(void);
@property (nonatomic, copy) void (^showAllStoriesPressed)(void);
@property (nonatomic, copy) void (^giftSelected)(NSUInteger index);
@property (nonatomic, copy) void (^sendGiftPressed)(void);
@property (nonatomic, copy) void (^showAllGiftsPressed)(void);
@property (nonatomic, copy) void (^mediaPressed)(void);
@property (nonatomic, copy) void (^heightChanged)(void);

- (void)reloadContent;

@end
