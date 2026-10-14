#import <UIKit/UIKit.h>

#import "TGRichMessageTheme.h"

@class TGRichMessage;
@class TGRichMessageText;
@class TGModernTextViewModel;

@interface TGRichMessageTextStyle : NSObject <NSCopying>

@property (nonatomic) CGFloat size;
@property (nonatomic) bool bold;
@property (nonatomic) bool italic;
@property (nonatomic) bool mono;
@property (nonatomic) bool codeBlock;
@property (nonatomic) bool underline;
@property (nonatomic) bool strike;
@property (nonatomic) bool marked;
@property (nonatomic) bool spoiler;
@property (nonatomic) TGRichMessageColorKind colorKind;
@property (nonatomic, strong) NSString *link;
@property (nonatomic) NSTextAlignment alignment;
@property (nonatomic) NSUInteger maxNumberOfLines;

+ (instancetype)styleWithSize:(CGFloat)size;

@end

@interface TGRichMessageTextEnvironment : NSObject

@property (nonatomic, strong, readonly) TGRichMessageTheme *theme;
@property (nonatomic, strong, readonly) TGRichMessage *richMessage;
@property (nonatomic, readonly) bool spoilersRevealed;
@property (nonatomic, strong, readonly) NSMutableArray *buttons;
@property (nonatomic, strong, readonly) NSMutableSet *inlineImageKeys;

- (instancetype)initWithTheme:(TGRichMessageTheme *)theme richMessage:(TGRichMessage *)richMessage spoilersRevealed:(bool)spoilersRevealed;

- (TGModernTextViewModel *)textModelWithText:(TGRichMessageText *)text style:(TGRichMessageTextStyle *)style anchors:(NSMutableDictionary *)anchors;
- (TGModernTextViewModel *)textModelWithString:(NSString *)string style:(TGRichMessageTextStyle *)style;

+ (NSString *)formattedDate:(int32_t)date flags:(int32_t)flags;

@end
