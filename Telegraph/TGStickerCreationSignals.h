#import <UIKit/UIKit.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGDocumentMediaAttachment;

@interface TGStickerCreationPack : NSObject

@property (nonatomic, readonly) int64_t packId;
@property (nonatomic, readonly) int64_t accessHash;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *shortName;
@property (nonatomic, readonly) int32_t count;

@end

@interface TGStickerCreationSignals : NSObject

+ (bool)canRemoveBackground;
+ (SSignal *)foregroundImageFromImage:(UIImage *)image;
+ (UIImage *)stickerImageFromImage:(UIImage *)image;
+ (SSignal *)stickerDataFromImage:(UIImage *)image;
+ (SSignal *)uploadStickerData:(NSData *)data size:(CGSize)size emoji:(NSString *)emoji;

+ (SSignal *)myStickerPacks;
+ (SSignal *)addSticker:(TGDocumentMediaAttachment *)document emoji:(NSString *)emoji toPack:(TGStickerCreationPack *)pack;
+ (SSignal *)suggestShortNameForTitle:(NSString *)title;
+ (SSignal *)checkShortName:(NSString *)shortName;
+ (SSignal *)createPackWithTitle:(NSString *)title shortName:(NSString *)shortName sticker:(TGDocumentMediaAttachment *)document emoji:(NSString *)emoji;

+ (NSString *)errorTypeForError:(id)error;

@end
