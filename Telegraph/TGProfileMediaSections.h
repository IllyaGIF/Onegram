#import <Foundation/Foundation.h>

#import "TGStoryRingView.h"

@class TGCollectionMenuController;
@class TGCollectionMenuSection;

@interface TGProfileMediaSections : NSObject

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic) bool canPostStories;
@property (nonatomic) bool canReceiveGifts;
@property (nonatomic) bool canManageGifts;
@property (nonatomic) bool loadsActiveStories;
@property (nonatomic) bool showsMediaTab;
@property (nonatomic, copy) void (^mediaPressed)(void);
@property (nonatomic, copy) void (^heightChanged)(void);
@property (nonatomic, copy) void (^contentChanged)(void);
@property (nonatomic, copy) void (^storyRingChanged)(TGStoryRingState state);

@property (nonatomic, strong, readonly) TGCollectionMenuSection *mediaSection;

- (instancetype)initWithPeerId:(int64_t)peerId parentController:(TGCollectionMenuController *)parentController;

- (void)requestIfNeeded;
- (void)reloadStories;
- (void)reloadGifts;

- (bool)updateSectionsEnabled:(bool)enabled afterSectionIndex:(NSUInteger)anchorIndex;

- (TGStoryRingState)storyRingState;
- (bool)hasActiveStories;
- (void)openActiveStories;
- (void)postStory;

@end
