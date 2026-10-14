#import <UIKit/UIKit.h>

@class OGTheme;

typedef enum {
    OGMusicPlayerScreenOrderNormal = 0,
    OGMusicPlayerScreenOrderReversed = 1,
    OGMusicPlayerScreenOrderShuffled = 2
} OGMusicPlayerScreenOrder;

typedef enum {
    OGMusicPlayerScreenRepeatNone = 0,
    OGMusicPlayerScreenRepeatAll = 1,
    OGMusicPlayerScreenRepeatOne = 2
} OGMusicPlayerScreenRepeat;

@interface OGMusicPlayerScreenRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *durationText;
@end

@interface OGMusicPlayerScreenView : UIView

@property (nonatomic) UIEdgeInsets contentInsets;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *backTitle;
@property (nonatomic, copy) NSString *trackTitle;
@property (nonatomic, copy) NSString *trackSubtitle;
@property (nonatomic, copy) NSArray *rows;
@property (nonatomic) bool paused;
@property (nonatomic) bool controlsEnabled;
@property (nonatomic) OGMusicPlayerScreenOrder order;
@property (nonatomic) OGMusicPlayerScreenRepeat repeat;
@property (nonatomic, readonly) UIView *displayView;
@property (nonatomic, readonly) bool scrubbing;

@property (nonatomic, copy) void (^backPressed)(void);
@property (nonatomic, copy) void (^playPausePressed)(void);
@property (nonatomic, copy) void (^previousPressed)(void);
@property (nonatomic, copy) void (^nextPressed)(void);
@property (nonatomic, copy) void (^orderPressed)(void);
@property (nonatomic, copy) void (^repeatPressed)(void);
@property (nonatomic, copy) void (^rowSelected)(NSUInteger index);
@property (nonatomic, copy) void (^actionsRequested)(void);
@property (nonatomic, copy) void (^scrubbingBegan)(void);
@property (nonatomic, copy) void (^scrubbingFinished)(CGFloat progress);
@property (nonatomic, copy) void (^scrubbingCancelled)(void);

- (instancetype)initWithFrame:(CGRect)frame theme:(OGTheme *)theme;
- (void)setProgress:(CGFloat)progress knobVisible:(bool)knobVisible;
- (void)scrollToRowAtIndex:(NSUInteger)index animated:(bool)animated;

@end
