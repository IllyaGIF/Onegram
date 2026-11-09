/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "TGConversationMessageAssetsSource.h"

@class TGWallpaperInfo;

extern int TGBaseFontSize;

@interface TGTelegraphConversationMessageAssetsSource : NSObject <TGConversationMessageAssetsSource>

@property (nonatomic, readonly) int monochromeColor;
@property (nonatomic, readonly) CGFloat systemAlpha;
@property (nonatomic, readonly) CGFloat buttonsAlpha;
@property (nonatomic, readonly) CGFloat highlighteButtonAlpha;
@property (nonatomic, readonly) CGFloat progressAlpha;

+ (TGTelegraphConversationMessageAssetsSource *)instance;

- (void)applyWallpaperInfo:(TGWallpaperInfo *)wallpaperInfo;

@end
