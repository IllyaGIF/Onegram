#import "../OGMessageContentView.h"
@class OGLabel;
@interface OGTextMessageView : OGMessageContentView
@property (nonatomic, retain, readonly) OGLabel *textLabel;
@property (nonatomic, copy) NSString *text;
@end
