#import <UIKit/UIKit.h>

@class OGSurfaceStyle;

@interface OGMusicPlayerScreenGlyphStyle : NSObject
@property (nonatomic, copy) NSArray *colors;
@property (nonatomic, copy) NSArray *locations;
@property (nonatomic, copy) NSArray *shadows;
- (UIEdgeInsets)symmetricOutsets;
@end

@interface OGMusicPlayerScreenAppearance : NSObject

@property (nonatomic, copy) NSString *resourceDirectory;
@property (nonatomic, retain) UIColor *statusBarBackgroundColor;
@property (nonatomic, retain) OGSurfaceStyle *backgroundSurfaceStyle;

@property (nonatomic, retain) UIFont *titleFont;
@property (nonatomic, retain) UIColor *titleColor;
@property (nonatomic) CGFloat titleTopInset;
@property (nonatomic) CGFloat titleHeight;
@property (nonatomic) CGFloat titleHorizontalOffset;

@property (nonatomic, retain) OGSurfaceStyle *backButtonSurfaceStyle;
@property (nonatomic, retain) OGSurfaceStyle *backButtonPressedSurfaceStyle;
@property (nonatomic, retain) UIFont *backButtonFont;
@property (nonatomic, retain) UIColor *backButtonTitleColor;
@property (nonatomic) CGPoint backButtonOrigin;
@property (nonatomic) CGFloat backButtonHeight;
@property (nonatomic) CGFloat backButtonMinimumWidth;
@property (nonatomic) CGFloat backButtonHorizontalPadding;

@property (nonatomic, retain) OGSurfaceStyle *displaySurfaceStyle;
@property (nonatomic) CGFloat displayTopInset;
@property (nonatomic) CGFloat displayLeftInset;
@property (nonatomic) CGFloat displayRightInset;
@property (nonatomic) CGFloat displayHeight;
@property (nonatomic) CGFloat displayTextHorizontalInset;
@property (nonatomic, retain) UIFont *displayTitleFont;
@property (nonatomic, retain) UIColor *displayTitleColor;
@property (nonatomic) CGFloat displayTitleTopInset;
@property (nonatomic) CGFloat displayTitleHeight;
@property (nonatomic) CGFloat displayTitleHorizontalOffset;
@property (nonatomic, retain) UIFont *displaySubtitleFont;
@property (nonatomic, retain) UIColor *displaySubtitleColor;
@property (nonatomic) CGFloat displaySubtitleTopInset;
@property (nonatomic) CGFloat displaySubtitleHeight;
@property (nonatomic) CGFloat displaySubtitleHorizontalOffset;
@property (nonatomic) CGFloat progressLeftInset;
@property (nonatomic) CGFloat progressRightInset;
@property (nonatomic) CGFloat progressTopInset;
@property (nonatomic) CGFloat progressHeight;
@property (nonatomic) CGFloat progressBorderWidth;
@property (nonatomic, retain) UIColor *progressBorderColor;
@property (nonatomic, retain) UIColor *progressFillColor;
@property (nonatomic, retain) UIColor *progressKnobColor;
@property (nonatomic) CGFloat progressKnobSize;
@property (nonatomic) CGFloat progressTouchOutset;

@property (nonatomic, retain) OGSurfaceStyle *playlistSurfaceStyle;
@property (nonatomic, retain) OGSurfaceStyle *playlistOverlaySurfaceStyle;
@property (nonatomic) CGFloat playlistTopInset;
@property (nonatomic) CGFloat playlistHorizontalInset;
@property (nonatomic) CGFloat playlistBottomSpacing;
@property (nonatomic) CGFloat playlistCornerRadius;
@property (nonatomic) CGFloat rowHeight;
@property (nonatomic, retain) OGSurfaceStyle *rowSurfaceStyle;
@property (nonatomic, retain) UIColor *rowHighlightColor;
@property (nonatomic, copy) NSString *rowIconName;
@property (nonatomic, retain) OGMusicPlayerScreenGlyphStyle *rowIconStyle;
@property (nonatomic) CGPoint rowIconOrigin;
@property (nonatomic, retain) UIFont *rowTitleFont;
@property (nonatomic, retain) UIColor *rowTitleColor;
@property (nonatomic) CGFloat rowTitleLeftInset;
@property (nonatomic) CGFloat rowTitleRightInset;
@property (nonatomic) CGFloat rowTitleTopInset;
@property (nonatomic) CGFloat rowTitleHeight;
@property (nonatomic, retain) UIFont *rowDurationFont;
@property (nonatomic, retain) UIColor *rowDurationColor;
@property (nonatomic) CGFloat rowDurationCenterRightInset;
@property (nonatomic) CGFloat rowDurationWidth;
@property (nonatomic) CGFloat rowDurationTopInset;
@property (nonatomic) CGFloat rowDurationHeight;

@property (nonatomic, retain) OGSurfaceStyle *largeButtonSurfaceStyle;
@property (nonatomic, retain) OGSurfaceStyle *largeButtonPressedSurfaceStyle;
@property (nonatomic, retain) OGSurfaceStyle *smallButtonSurfaceStyle;
@property (nonatomic, retain) OGSurfaceStyle *smallButtonPressedSurfaceStyle;
@property (nonatomic) CGFloat largeButtonDiameter;
@property (nonatomic) CGFloat smallButtonDiameter;
@property (nonatomic) CGFloat transportBottomInset;
@property (nonatomic) CGFloat transportCenterOffset;
@property (nonatomic) CGFloat smallButtonTopOffset;
@property (nonatomic) CGFloat smallButtonCenterSpacing;
@property (nonatomic, copy) NSString *rewindIconName;
@property (nonatomic, copy) NSString *forwardIconName;
@property (nonatomic, copy) NSString *playIconName;
@property (nonatomic, copy) NSString *pauseIconName;
@property (nonatomic, retain) OGMusicPlayerScreenGlyphStyle *rewindGlyphStyle;
@property (nonatomic, retain) OGMusicPlayerScreenGlyphStyle *forwardGlyphStyle;
@property (nonatomic, retain) OGMusicPlayerScreenGlyphStyle *playPauseGlyphStyle;
@property (nonatomic) CGPoint rewindGlyphOffset;
@property (nonatomic) CGPoint forwardGlyphOffset;
@property (nonatomic) CGPoint pauseGlyphOffset;
@property (nonatomic) CGPoint playGlyphOffset;
@property (nonatomic) CGFloat disabledControlAlpha;

@property (nonatomic, copy) NSString *repeatIconName;
@property (nonatomic, copy) NSString *repeatOneIconName;
@property (nonatomic, copy) NSString *shuffleIconName;
@property (nonatomic, copy) NSString *reverseIconName;
@property (nonatomic, retain) OGMusicPlayerScreenGlyphStyle *repeatGlyphStyle;
@property (nonatomic, retain) OGMusicPlayerScreenGlyphStyle *orderGlyphStyle;
@property (nonatomic, retain) OGMusicPlayerScreenGlyphStyle *modeSelectedGlyphStyle;
@property (nonatomic) CGFloat modeGlyphOpticalSize;
@property (nonatomic) CGPoint modeGlyphOffset;
@property (nonatomic, retain) OGSurfaceStyle *modeButtonSurfaceStyle;
@property (nonatomic, retain) OGSurfaceStyle *modeButtonPressedSurfaceStyle;
@property (nonatomic) CGFloat modeButtonDiameter;
@property (nonatomic) CGFloat modeButtonSideInset;
@property (nonatomic) CGFloat modeButtonBottomInset;
@property (nonatomic) CGFloat modeButtonTouchSize;

@property (nonatomic, retain) OGSurfaceStyle *volumeMinimumTrackSurfaceStyle;
@property (nonatomic, retain) OGSurfaceStyle *volumeMaximumTrackSurfaceStyle;
@property (nonatomic, retain) OGSurfaceStyle *volumeThumbSurfaceStyle;
@property (nonatomic) CGFloat volumeTrackHeight;
@property (nonatomic) CGFloat volumeThumbDiameter;
@property (nonatomic) CGFloat volumeTrackVerticalOffset;
@property (nonatomic) CGFloat volumeIconVerticalOffset;
@property (nonatomic) CGFloat volumeTrackLeftInset;
@property (nonatomic) CGFloat volumeTrackRightInset;
@property (nonatomic) CGFloat volumeCenterBottomInset;
@property (nonatomic, copy) NSString *volumeLowIconName;
@property (nonatomic, copy) NSString *volumeHighIconName;
@property (nonatomic, retain) OGMusicPlayerScreenGlyphStyle *volumeGlyphStyle;
@property (nonatomic) CGFloat volumeLowIconLeftInset;
@property (nonatomic) CGFloat volumeHighIconRightInset;

+ (OGMusicPlayerScreenAppearance *)brandedAppearance;

@end
