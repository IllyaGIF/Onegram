#import <Foundation/Foundation.h>
@interface OGDialogItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *preview;
@property (nonatomic, copy) NSString *dateText;
@property (nonatomic) NSInteger unreadCount;
@property (nonatomic) BOOL muted;
@end
