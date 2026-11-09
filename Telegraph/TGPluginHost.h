#import "../OnegramRuntime/OGPluginAvailability.h"

#if OG_PLUGINS_AVAILABLE

#import <Foundation/Foundation.h>

@class TGDocumentMediaAttachment;
@class TGMusicPlayer;
@class TGViewController;
@class UIImage;
@class UIViewController;

#import "../OnegramPlugins/OGPluginHost.h"
#import "../OnegramPlugins/OGPluginHooks.h"

@interface TGPluginHost : NSObject <OGPluginHost>

+ (TGPluginHost *)sharedHost;
+ (TGViewController *)presentingController;

+ (int64_t)dialogIdForPeerId:(int64_t)peerId;
+ (int64_t)peerIdForDialogId:(int64_t)dialogId;

+ (NSString *)languageCode;
+ (NSString *)localizedStringForKey:(NSString *)key;
+ (bool)applyUpdatesData:(NSData *)data;
+ (NSString *)localPathForDocumentId:(int64_t)documentId version:(int32_t)version fileName:(NSString *)fileName;
+ (id)downloadFileLocation:(NSDictionary *)location toPath:(NSString *)path progress:(void (^)(int64_t loaded, int64_t total))progress completion:(void (^)(NSString *path, NSString *error))completion;
+ (void)cancelDownload:(id)download;
+ (TGMusicPlayer *)musicPlayer;
+ (bool)switchToAccountIndex:(NSInteger)index;
+ (NSArray *)conversationsInFolder:(int32_t)folderId limit:(int32_t)limit;
+ (NSString *)presentationKind;
+ (bool)applyPresentationKind:(NSString *)kind;
+ (UIImage *)currentWallpaperImage;
+ (int32_t)notificationsMuteUntilForPeerId:(int64_t)peerId;
+ (int64_t)notificationDefaultsPeerIdForPeerId:(int64_t)peerId;
+ (int64_t)notificationDefaultsPeerIdForType:(int32_t)type;
+ (void)refreshNotifications;
+ (bool)isSendingMessageId:(int32_t)messageId peerId:(int64_t)peerId;
+ (bool)cancelSendingMessageId:(int32_t)messageId peerId:(int64_t)peerId;
+ (bool)presentShareWithText:(NSString *)text paths:(NSArray *)paths completion:(void (^)(NSArray *peerIds, NSString *comment))completion;

+ (void)resolveLink:(NSURL *)url completion:(void (^)(NSURL *resolved))completion;
+ (void)completeLink:(NSURL *)url;
+ (bool)openDocumentAtPath:(NSString *)path attachment:(TGDocumentMediaAttachment *)attachment peerId:(int64_t)peerId messageId:(int32_t)messageId place:(NSString *)place;

+ (bool)hasMenuItemsOfType:(NSString *)menuType;
+ (bool)isMenuChangeNotification:(NSNotification *)notification;
+ (NSDictionary *)menuContextWithController:(UIViewController *)controller peerId:(int64_t)peerId messageId:(int32_t)messageId groupedMessageIds:(NSArray *)groupedMessageIds;
+ (NSArray *)menuItemsOfType:(NSString *)menuType context:(NSDictionary *)context;
+ (bool)performMenuItem:(NSDictionary *)item ofType:(NSString *)menuType context:(NSDictionary *)context;

+ (void)processOutgoingText:(NSString *)text entities:(NSArray *)entities peerId:(int64_t)peerId replyMessageId:(int32_t)replyMessageId disableLinkPreviews:(bool)disableLinkPreviews completion:(void (^)(NSString *text, NSArray *entities, int32_t replyMessageId, bool disableLinkPreviews, bool cancelled))completion;

@end

#endif
