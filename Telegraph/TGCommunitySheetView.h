#import <UIKit/UIKit.h>

@class SSignal;
@class TGConversation;
@class TGPresentation;
@class TGCommunitySheetView;

@protocol TGCommunitySheetViewDataSource <NSObject>

- (void)communitySheetView:(TGCommunitySheetView *)sheetView configureTableView:(UITableView *)tableView;
- (SSignal *)communitySheetView:(TGCommunitySheetView *)sheetView displayConversations:(NSArray *)conversations;
- (UITableViewCell *)communitySheetView:(TGCommunitySheetView *)sheetView tableView:(UITableView *)tableView cellForConversation:(TGConversation *)conversation;
- (void)communitySheetView:(TGCommunitySheetView *)sheetView tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell;

@end

@interface TGCommunitySheetView : UIView

@property (nonatomic, copy) void (^conversationSelected)(TGConversation *conversation, bool joined);

- (instancetype)initWithConversation:(TGConversation *)conversation presentation:(TGPresentation *)presentation dataSource:(id<TGCommunitySheetViewDataSource>)dataSource;

- (void)showInView:(UIView *)view;
- (void)dismissAnimated:(bool)animated completion:(void (^)(void))completion;

@end
