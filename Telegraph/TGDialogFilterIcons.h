#import <UIKit/UIKit.h>

UIImage *TGDialogFilterCategoryIcon(int32_t category);
UIImage *TGDialogFilterSettingsIcon(void);
UIImage *TGDialogFilterFolderIcon(UIColor *color, CGFloat side);
UIImage *TGDialogFilterEmoticonIcon(NSString *emoticon, CGFloat side);
UIImage *TGDialogFilterColorDotImage(UIColor *color, CGFloat side, bool selected, UIColor *ringColor);
UIImage *TGDialogFilterNoColorImage(UIColor *strokeColor, CGFloat side, bool selected, UIColor *ringColor);
CGSize TGDialogFilterTagSize(NSString *title, UIFont *font);
void TGDialogFilterDrawTag(NSString *title, UIColor *color, UIFont *font, CGRect rect);
