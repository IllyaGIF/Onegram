#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class TGImageMediaAttachment;
@class TGDocumentMediaAttachment;
@class TGRichMessageButton;

typedef enum {
    TGRichMessageTextKindEmpty = 0,
    TGRichMessageTextKindPlain,
    TGRichMessageTextKindBold,
    TGRichMessageTextKindItalic,
    TGRichMessageTextKindUnderline,
    TGRichMessageTextKindStrike,
    TGRichMessageTextKindFixed,
    TGRichMessageTextKindUrl,
    TGRichMessageTextKindEmail,
    TGRichMessageTextKindConcat,
    TGRichMessageTextKindSubscript,
    TGRichMessageTextKindSuperscript,
    TGRichMessageTextKindMarked,
    TGRichMessageTextKindPhone,
    TGRichMessageTextKindImage,
    TGRichMessageTextKindAnchor,
    TGRichMessageTextKindMath,
    TGRichMessageTextKindCustomEmoji,
    TGRichMessageTextKindSpoiler,
    TGRichMessageTextKindMention,
    TGRichMessageTextKindHashtag,
    TGRichMessageTextKindBotCommand,
    TGRichMessageTextKindCashtag,
    TGRichMessageTextKindAutoUrl,
    TGRichMessageTextKindAutoEmail,
    TGRichMessageTextKindAutoPhone,
    TGRichMessageTextKindBankCard,
    TGRichMessageTextKindMentionName,
    TGRichMessageTextKindDate,
    TGRichMessageTextKindDiff,
    TGRichMessageTextKindButton
} TGRichMessageTextKind;

typedef enum {
    TGRichMessageDateFlagRelative = 1 << 0,
    TGRichMessageDateFlagShortTime = 1 << 1,
    TGRichMessageDateFlagLongTime = 1 << 2,
    TGRichMessageDateFlagShortDate = 1 << 3,
    TGRichMessageDateFlagLongDate = 1 << 4,
    TGRichMessageDateFlagDayOfWeek = 1 << 5
} TGRichMessageDateFlags;

@interface TGRichMessageText : NSObject <NSCoding>

@property (nonatomic, readonly) TGRichMessageTextKind kind;
@property (nonatomic, strong, readonly) NSString *string;
@property (nonatomic, strong, readonly) NSArray *texts;
@property (nonatomic, readonly) int64_t identifier;
@property (nonatomic, readonly) int32_t value;
@property (nonatomic, readonly) int32_t flags;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, strong, readonly) TGRichMessageButton *button;

- (instancetype)initWithKind:(TGRichMessageTextKind)kind string:(NSString *)string texts:(NSArray *)texts identifier:(int64_t)identifier value:(int32_t)value flags:(int32_t)flags size:(CGSize)size button:(TGRichMessageButton *)button;

+ (instancetype)plainText:(NSString *)string;
+ (instancetype)textWithKind:(TGRichMessageTextKind)kind text:(TGRichMessageText *)text;

- (TGRichMessageText *)text;
- (NSString *)plainText;
- (bool)isEmpty;

@end

typedef enum {
    TGRichMessageButtonActionUnsupported = 0,
    TGRichMessageButtonActionUrl,
    TGRichMessageButtonActionUrlAuth,
    TGRichMessageButtonActionWebView,
    TGRichMessageButtonActionCallback,
    TGRichMessageButtonActionGame,
    TGRichMessageButtonActionBuy,
    TGRichMessageButtonActionSwitchInline,
    TGRichMessageButtonActionUserProfile,
    TGRichMessageButtonActionCopy,
    TGRichMessageButtonActionDisabled
} TGRichMessageButtonAction;

typedef enum {
    TGRichMessageButtonStylePrimary = 1 << 0,
    TGRichMessageButtonStyleDanger = 1 << 1,
    TGRichMessageButtonStyleSuccess = 1 << 2,
    TGRichMessageButtonStyleLink = 1 << 3
} TGRichMessageButtonStyle;

@interface TGRichMessageButton : NSObject <NSCoding>

@property (nonatomic, strong, readonly) TGRichMessageText *text;
@property (nonatomic, readonly) TGRichMessageButtonAction action;
@property (nonatomic, strong, readonly) NSString *string;
@property (nonatomic, strong, readonly) NSData *data;
@property (nonatomic, readonly) int64_t identifier;
@property (nonatomic, readonly) bool samePeer;
@property (nonatomic, readonly) bool requiresPassword;
@property (nonatomic, readonly) int32_t style;

- (instancetype)initWithText:(TGRichMessageText *)text action:(TGRichMessageButtonAction)action string:(NSString *)string data:(NSData *)data identifier:(int64_t)identifier samePeer:(bool)samePeer requiresPassword:(bool)requiresPassword style:(int32_t)style;

@end

typedef enum {
    TGRichMessageBlockKindUnsupported = 0,
    TGRichMessageBlockKindTitle,
    TGRichMessageBlockKindSubtitle,
    TGRichMessageBlockKindAuthorDate,
    TGRichMessageBlockKindHeading,
    TGRichMessageBlockKindKicker,
    TGRichMessageBlockKindParagraph,
    TGRichMessageBlockKindPreformatted,
    TGRichMessageBlockKindFooter,
    TGRichMessageBlockKindDivider,
    TGRichMessageBlockKindAnchor,
    TGRichMessageBlockKindList,
    TGRichMessageBlockKindOrderedList,
    TGRichMessageBlockKindBlockquote,
    TGRichMessageBlockKindBlockquoteBlocks,
    TGRichMessageBlockKindPullquote,
    TGRichMessageBlockKindPhoto,
    TGRichMessageBlockKindVideo,
    TGRichMessageBlockKindCover,
    TGRichMessageBlockKindEmbed,
    TGRichMessageBlockKindEmbedPost,
    TGRichMessageBlockKindCollage,
    TGRichMessageBlockKindSlideshow,
    TGRichMessageBlockKindChannel,
    TGRichMessageBlockKindAudio,
    TGRichMessageBlockKindTable,
    TGRichMessageBlockKindDetails,
    TGRichMessageBlockKindRelatedArticles,
    TGRichMessageBlockKindMap,
    TGRichMessageBlockKindMath,
    TGRichMessageBlockKindThinking,
    TGRichMessageBlockKindButtonRow,
    TGRichMessageBlockKindDocument
} TGRichMessageBlockKind;

typedef enum {
    TGRichMessageBlockFlagBlockquoteCollapsed = 1 << 0,
    TGRichMessageBlockFlagPhotoSpoiler = 1 << 1,
    TGRichMessageBlockFlagVideoAutoplay = 1 << 0,
    TGRichMessageBlockFlagVideoLoop = 1 << 1,
    TGRichMessageBlockFlagVideoSpoiler = 1 << 2,
    TGRichMessageBlockFlagEmbedFullWidth = 1 << 0,
    TGRichMessageBlockFlagEmbedAllowScrolling = 1 << 3,
    TGRichMessageBlockFlagTableBordered = 1 << 0,
    TGRichMessageBlockFlagTableStriped = 1 << 1,
    TGRichMessageBlockFlagTableCompact = 1 << 2,
    TGRichMessageBlockFlagOrderedListReversed = 1 << 2,
    TGRichMessageBlockFlagDetailsOpen = 1 << 0,
    TGRichMessageBlockFlagButtonRowLeft = 1 << 0,
    TGRichMessageBlockFlagButtonRowCenter = 1 << 1,
    TGRichMessageBlockFlagButtonRowRight = 1 << 2,
    TGRichMessageBlockFlagOrderedListHasStart = 1 << 0
} TGRichMessageBlockFlags;

@interface TGRichMessageBlock : NSObject <NSCoding>

@property (nonatomic) TGRichMessageBlockKind kind;
@property (nonatomic) int32_t level;
@property (nonatomic) int32_t flags;
@property (nonatomic, strong) TGRichMessageText *text;
@property (nonatomic, strong) TGRichMessageText *secondaryText;
@property (nonatomic, strong) TGRichMessageText *caption;
@property (nonatomic, strong) TGRichMessageText *credit;
@property (nonatomic, strong) NSString *string;
@property (nonatomic, strong) NSString *secondaryString;
@property (nonatomic) int64_t identifier;
@property (nonatomic) int64_t secondaryIdentifier;
@property (nonatomic) int32_t date;
@property (nonatomic) int32_t start;
@property (nonatomic, strong) NSArray *blocks;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) NSArray *rows;
@property (nonatomic, strong) NSArray *buttons;
@property (nonatomic, strong) NSArray *articles;
@property (nonatomic) double latitude;
@property (nonatomic) double longitude;
@property (nonatomic) int32_t zoom;
@property (nonatomic) CGSize size;

- (instancetype)initWithKind:(TGRichMessageBlockKind)kind;

- (NSString *)plainText;

@end

typedef enum {
    TGRichMessageListItemFlagCheckbox = 1 << 0,
    TGRichMessageListItemFlagChecked = 1 << 1,
    TGRichMessageListItemFlagHasValue = 1 << 3
} TGRichMessageListItemFlags;

@interface TGRichMessageListItem : NSObject <NSCoding>

@property (nonatomic, readonly) int32_t flags;
@property (nonatomic, strong, readonly) NSString *number;
@property (nonatomic, strong, readonly) TGRichMessageText *text;
@property (nonatomic, strong, readonly) NSArray *blocks;
@property (nonatomic, readonly) int32_t value;
@property (nonatomic, strong, readonly) NSString *numberingType;

- (instancetype)initWithFlags:(int32_t)flags number:(NSString *)number text:(TGRichMessageText *)text blocks:(NSArray *)blocks value:(int32_t)value numberingType:(NSString *)numberingType;

@end

typedef enum {
    TGRichMessageTableCellFlagHeader = 1 << 0,
    TGRichMessageTableCellFlagAlignCenter = 1 << 3,
    TGRichMessageTableCellFlagAlignRight = 1 << 4,
    TGRichMessageTableCellFlagVerticalAlignMiddle = 1 << 5,
    TGRichMessageTableCellFlagVerticalAlignBottom = 1 << 6
} TGRichMessageTableCellFlags;

@interface TGRichMessageTableCell : NSObject <NSCoding>

@property (nonatomic, readonly) int32_t flags;
@property (nonatomic, strong, readonly) TGRichMessageText *text;
@property (nonatomic, readonly) int32_t colspan;
@property (nonatomic, readonly) int32_t rowspan;

- (instancetype)initWithFlags:(int32_t)flags text:(TGRichMessageText *)text colspan:(int32_t)colspan rowspan:(int32_t)rowspan;

@end

@interface TGRichMessageRelatedArticle : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSString *url;
@property (nonatomic, readonly) int64_t webpageId;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *articleDescription;
@property (nonatomic, readonly) int64_t photoId;
@property (nonatomic, strong, readonly) NSString *author;
@property (nonatomic, readonly) int32_t publishedDate;

- (instancetype)initWithUrl:(NSString *)url webpageId:(int64_t)webpageId title:(NSString *)title articleDescription:(NSString *)articleDescription photoId:(int64_t)photoId author:(NSString *)author publishedDate:(int32_t)publishedDate;

@end

@interface TGRichMessage : NSObject <NSCoding>

@property (nonatomic, readonly) bool rtl;
@property (nonatomic, readonly) bool part;
@property (nonatomic, strong, readonly) NSArray *blocks;
@property (nonatomic, strong, readonly) NSDictionary *photos;
@property (nonatomic, strong, readonly) NSDictionary *documents;

- (instancetype)initWithRtl:(bool)rtl part:(bool)part blocks:(NSArray *)blocks photos:(NSDictionary *)photos documents:(NSDictionary *)documents;

- (TGImageMediaAttachment *)photoWithId:(int64_t)photoId;
- (TGDocumentMediaAttachment *)documentWithId:(int64_t)documentId;

- (NSString *)plainText;

@end
