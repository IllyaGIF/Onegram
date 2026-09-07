#import <UIKit/UIKit.h>

@class TGPresentation;

@interface TGStickerCollectionHeader : PSUICollectionReusableView

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic, strong) TGPresentation *presentation;

@property (nonatomic, copy) void (^accessoryPressed)(void);

@end
