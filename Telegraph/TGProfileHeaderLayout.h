#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

extern const CGFloat TGProfileHeaderAvatarSize;

UIFont *TGProfileHeaderTitleFont(void);
UIFont *TGProfileHeaderSubtitleFont(void);
NSString *TGProfileHeaderAvatarFilter(void);
CGRect TGProfileHeaderAvatarFrame(CGRect bounds);
CGFloat TGProfileHeaderTitleTop(void);
CGFloat TGProfileHeaderTitleLineHeight(void);
CGFloat TGProfileHeaderSubtitleTop(void);
CGFloat TGProfileHeaderSubtitleLineHeight(void);
CGFloat TGProfileHeaderAccessoryTop(void);
CGFloat TGProfileHeaderHeight(CGFloat accessoryHeight);

#ifdef __cplusplus
}
#endif
