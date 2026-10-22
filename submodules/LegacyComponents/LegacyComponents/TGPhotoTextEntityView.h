#import "TGPhotoPaintEntityView.h"
#import "TGPhotoPaintTextEntity.h"

@class TGPaintSwatch;

@interface TGPhotoTextSelectionView : TGPhotoPaintEntitySelectionView

@end


@interface TGPhotoTextEntityView : TGPhotoPaintEntityView

@property (nonatomic, readonly) TGPhotoPaintTextEntity *entity;

@property (nonatomic, readonly) bool isEmpty;

@property (nonatomic, copy) void (^beganEditing)(TGPhotoTextEntityView *);
@property (nonatomic, copy) void (^finishedEditing)(TGPhotoTextEntityView *);

- (instancetype)initWithEntity:(TGPhotoPaintTextEntity *)entity;
- (void)setFont:(TGPhotoPaintFont *)font;
- (void)setSwatch:(TGPaintSwatch *)swatch;
- (void)setStroke:(bool)stroke;

@property (nonatomic, readonly) bool isEditing;
- (void)beginEditing;
- (void)endEditing;

@end


@interface TGPhotoTextView : UITextView

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
@property (nonatomic, strong) UIColor *strokeColor;
@property (nonatomic, assign) CGFloat strokeWidth;
@property (nonatomic, assign) CGPoint strokeOffset;
#endif

@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000

@interface TGPhotoTextRenderView : UIView

@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *strokeColor;
@property (nonatomic, assign) CGFloat strokeWidth;
@property (nonatomic, assign) CGPoint strokeOffset;
@property (nonatomic, assign) bool shadowEnabled;
@property (nonatomic, assign) CGFloat textWidth;

- (CGSize)textSize;

@end

#endif
