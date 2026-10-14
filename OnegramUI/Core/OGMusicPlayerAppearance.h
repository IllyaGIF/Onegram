#import <UIKit/UIKit.h>

@class OGSurfaceStyle;

typedef enum {
    OGMusicPlayerGlyphPlay,
    OGMusicPlayerGlyphPause,
    OGMusicPlayerGlyphClose,
    OGMusicPlayerGlyphMusic,
    OGMusicPlayerGlyphChevron
} OGMusicPlayerGlyph;

@interface OGMusicPlayerAppearance : NSObject
@property (nonatomic, retain) OGSurfaceStyle *backgroundSurfaceStyle;
@property (nonatomic, retain) OGSurfaceStyle *displaySurfaceStyle;
@property (nonatomic, retain) UIFont *font;
@property (nonatomic, retain) UIColor *titleColor;
@property (nonatomic, retain) UIColor *timeColor;
@property (nonatomic, retain) UIColor *controlColor;
@property (nonatomic) CGFloat height;
@property (nonatomic) CGFloat displayLeftInset;
@property (nonatomic) CGFloat displayRightInset;
@property (nonatomic) CGFloat displayTopInset;
@property (nonatomic) CGFloat controlLeftInset;
@property (nonatomic) CGFloat controlTopInset;
@property (nonatomic) CGFloat closeRightInset;
@property (nonatomic) CGFloat closeTopInset;
+ (OGMusicPlayerAppearance *)brandedAppearanceDark:(BOOL)dark;
+ (OGMusicPlayerAppearance *)conversationAppearanceDark:(BOOL)dark compact:(BOOL)compact;
- (UIImage *)imageForGlyph:(OGMusicPlayerGlyph)glyph;
@end
