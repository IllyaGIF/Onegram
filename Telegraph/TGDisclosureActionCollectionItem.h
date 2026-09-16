/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGCollectionItem.h"

@interface TGDisclosureActionCollectionItem : TGCollectionItem

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic) bool hideArrow;
@property (nonatomic) bool brandedProfileMusic;
@property (nonatomic) bool brandedSettingsStyle;
@property (nonatomic, strong) NSString *brandedSettingsIconName;
@property (nonatomic) SEL action;

@property (nonatomic, strong) NSString *badge;

- (instancetype)initWithTitle:(NSString *)title action:(SEL)action;

@end
