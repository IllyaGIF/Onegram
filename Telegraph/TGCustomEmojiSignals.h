#import <UIKit/UIKit.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGDocumentMediaAttachment;
@class TGStickerPack;

@interface TGCustomEmojiItem : NSObject

@property (nonatomic, readonly) int64_t documentId;
@property (nonatomic, strong, readonly) NSString *alt;
@property (nonatomic, strong, readonly) NSString *thumbnailUri;

- (instancetype)initWithDocumentId:(int64_t)documentId alt:(NSString *)alt thumbnailUri:(NSString *)thumbnailUri;

@end

@interface TGCustomEmojiPack : NSObject

@property (nonatomic, readonly) int64_t packId;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSArray *items;

- (instancetype)initWithPackId:(int64_t)packId title:(NSString *)title items:(NSArray *)items;

@end

@interface TGCustomEmojiSignals : NSObject

+ (SSignal *)installedPacks;
+ (NSArray *)recentItems;
+ (void)addRecentItem:(TGCustomEmojiItem *)item;
+ (bool)canSendCustomEmoji;

+ (NSString *)imageKeyForItem:(TGCustomEmojiItem *)item;
+ (SSignal *)imageSignalForItem:(TGCustomEmojiItem *)item;

@end
