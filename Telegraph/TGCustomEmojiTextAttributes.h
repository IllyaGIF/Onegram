#import <UIKit/UIKit.h>

#if __has_include(<CoreText/CoreText.h>)
#import <CoreText/CoreText.h>
#else
#import "OGPlatformText.h"
#endif

NSArray *TGCustomEmojiEntities(NSArray *entities);
NSArray *TGCustomEmojiAdditionalAttributes(NSString *text, NSArray *entities, CTFontRef font, NSMutableSet *imageKeys);
