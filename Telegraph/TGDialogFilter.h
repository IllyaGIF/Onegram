#import <UIKit/UIKit.h>

@class TGTLDynamicObject;

typedef enum {
    TGDialogFilterIncludeContacts = 1 << 0,
    TGDialogFilterIncludeNonContacts = 1 << 1,
    TGDialogFilterIncludeGroups = 1 << 2,
    TGDialogFilterIncludeChannels = 1 << 3,
    TGDialogFilterIncludeBots = 1 << 4,
    TGDialogFilterExcludeMuted = 1 << 11,
    TGDialogFilterExcludeRead = 1 << 12,
    TGDialogFilterExcludeArchived = 1 << 13
} TGDialogFilterCategory;

extern const int32_t TGDialogFilterIncludeCategoriesMask;
extern const int32_t TGDialogFilterExcludeCategoriesMask;
extern const int32_t TGDialogFilterNoColor;
extern const int32_t TGDialogFilterColorCount;
extern const NSUInteger TGDialogFilterTitleMaxLength;

@interface TGDialogFilter : NSObject <NSCopying>

@property (nonatomic) int32_t filterId;
@property (nonatomic) bool defaultFilter;
@property (nonatomic) bool chatlist;
@property (nonatomic) bool hasMyInvites;
@property (nonatomic, strong) NSString *title;
@property (nonatomic) bool titleNoAnimate;
@property (nonatomic, strong) NSString *emoticon;
@property (nonatomic) int32_t color;
@property (nonatomic) int32_t flags;
@property (nonatomic, strong) NSArray *pinnedPeerIds;
@property (nonatomic, strong) NSArray *includePeerIds;
@property (nonatomic, strong) NSArray *excludePeerIds;

+ (instancetype)filterWithObject:(TGTLDynamicObject *)object;
+ (instancetype)defaultDialogFilter;
+ (instancetype)emptyFilterWithId:(int32_t)filterId;

+ (UIColor *)colorForIndex:(int32_t)index;
+ (NSArray *)availableEmoticons;
+ (NSString *)titleForCategory:(TGDialogFilterCategory)category;
+ (NSArray *)includeCategories;
+ (NSArray *)excludeCategories;

- (TGTLDynamicObject *)inputObject;
- (bool)isContentEqualToFilter:(TGDialogFilter *)filter;

- (NSArray *)includedPeerIds;
- (bool)includesPeerId:(int64_t)peerId;
- (bool)excludesPeerId:(int64_t)peerId;
- (void)setIncludedPeerIds:(NSArray *)peerIds;
- (void)setExcludedPeerIds:(NSArray *)peerIds;
- (void)addIncludedPeerId:(int64_t)peerId;
- (void)removeIncludedPeerId:(int64_t)peerId;
- (void)addExcludedPeerId:(int64_t)peerId;
- (void)removeExcludedPeerId:(int64_t)peerId;
- (void)registerInputPeer:(id)inputPeer forPeerId:(int64_t)peerId;
- (bool)hasCategoryRules;

- (NSArray *)pinnedPeers;
- (NSArray *)includePeers;
- (NSArray *)excludePeers;

@end
