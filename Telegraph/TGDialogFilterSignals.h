#import <Foundation/Foundation.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGDialogFilter;

extern NSString *const TGDialogFiltersDidChangeNotification;

@interface TGDialogFiltersState : NSObject

@property (nonatomic, strong, readonly) NSArray *filters;
@property (nonatomic, readonly) bool tagsEnabled;

- (instancetype)initWithFilters:(NSArray *)filters tagsEnabled:(bool)tagsEnabled;

@end

@interface TGDialogFilterSuggestion : NSObject

@property (nonatomic, strong, readonly) TGDialogFilter *filter;
@property (nonatomic, strong, readonly) NSString *descriptionText;

@end

@interface TGDialogFilterInvite : NSObject

@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *url;
@property (nonatomic, strong, readonly) NSString *slug;
@property (nonatomic, strong, readonly) NSArray *peerIds;

@end

@interface TGDialogFilterSignals : NSObject

+ (SSignal *)filters;
+ (SSignal *)suggestedFilters;
+ (SSignal *)saveFilter:(TGDialogFilter *)filter;
+ (SSignal *)deleteFilter:(TGDialogFilter *)filter;
+ (SSignal *)leaveSuggestionsForFilter:(TGDialogFilter *)filter;
+ (SSignal *)leaveChatlist:(TGDialogFilter *)filter peerIds:(NSArray *)peerIds;
+ (SSignal *)reorderFilterIds:(NSArray *)filterIds;
+ (SSignal *)setTagsVisible:(bool)visible;

+ (SSignal *)invitesForFilter:(TGDialogFilter *)filter;
+ (SSignal *)createInviteForFilter:(TGDialogFilter *)filter peerIds:(NSArray *)peerIds;
+ (SSignal *)editInvite:(TGDialogFilterInvite *)invite filter:(TGDialogFilter *)filter title:(NSString *)title peerIds:(NSArray *)peerIds;
+ (SSignal *)deleteInvite:(TGDialogFilterInvite *)invite filter:(TGDialogFilter *)filter;

+ (int32_t)unusedFilterIdForFilters:(NSArray *)filters;
+ (bool)isPremium;
+ (NSUInteger)folderLimit;
+ (NSUInteger)chatsPerFolderLimit;
+ (NSUInteger)invitesPerFolderLimit;
+ (NSString *)errorTextForError:(id)error;

+ (bool)tagsVisible;
+ (bool)tagsVisibleWithServerValue:(bool)serverValue;
+ (void)storeServerTagsEnabled:(bool)enabled;
+ (int32_t)effectiveColorForFilterId:(int32_t)filterId serverColor:(int32_t)serverColor;

@end
