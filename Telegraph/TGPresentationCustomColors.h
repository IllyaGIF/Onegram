#import <UIKit/UIKit.h>

@class TGPresentationPallete;

typedef enum {
    TGPresentationColorSectionGeneral = 0,
    TGPresentationColorSectionChatList,
    TGPresentationColorSectionMessages
} TGPresentationColorSection;

typedef enum {
    TGPresentationColorPreviewAccent = 0,
    TGPresentationColorPreviewScreenBackground,
    TGPresentationColorPreviewListBackground,
    TGPresentationColorPreviewBar,
    TGPresentationColorPreviewBarTitle,
    TGPresentationColorPreviewTabIcons,
    TGPresentationColorPreviewText,
    TGPresentationColorPreviewSecondaryText,
    TGPresentationColorPreviewSeparator,
    TGPresentationColorPreviewDialogTitle,
    TGPresentationColorPreviewDialogText,
    TGPresentationColorPreviewDialogDate,
    TGPresentationColorPreviewDialogBadge,
    TGPresentationColorPreviewDialogBadgeText,
    TGPresentationColorPreviewOutgoingBubble,
    TGPresentationColorPreviewOutgoingText,
    TGPresentationColorPreviewOutgoingSecondary,
    TGPresentationColorPreviewOutgoingLink,
    TGPresentationColorPreviewIncomingBubble,
    TGPresentationColorPreviewIncomingText,
    TGPresentationColorPreviewIncomingSecondary,
    TGPresentationColorPreviewIncomingLink,
    TGPresentationColorPreviewSystemBackground,
    TGPresentationColorPreviewSystemText,
    TGPresentationColorPreviewInputPanel,
    TGPresentationColorPreviewSendButton
} TGPresentationColorPreview;

@interface TGPresentationColorParameter : NSObject

@property (nonatomic, strong, readonly) NSString *identifier;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, readonly) TGPresentationColorSection section;
@property (nonatomic, readonly) TGPresentationColorPreview preview;

@end

@interface TGPresentationCustomColors : NSObject

+ (NSArray *)parameters;
+ (NSArray *)parametersInSection:(TGPresentationColorSection)section;

+ (TGPresentationPallete *)palleteApplyingCustomColors:(TGPresentationPallete *)pallete;

+ (UIColor *)colorForParameter:(TGPresentationColorParameter *)parameter pallete:(TGPresentationPallete *)pallete;
+ (bool)hasCustomColorForParameter:(TGPresentationColorParameter *)parameter pallete:(TGPresentationPallete *)pallete;
+ (bool)hasCustomColorsForPallete:(TGPresentationPallete *)pallete;

+ (void)setColor:(UIColor *)color forParameter:(TGPresentationColorParameter *)parameter pallete:(TGPresentationPallete *)pallete;
+ (void)resetColorsForPallete:(TGPresentationPallete *)pallete;

+ (void)setThemeColors:(NSDictionary *)colors forPalleteClass:(Class)palleteClass;
+ (NSDictionary *)themeColorsByPalleteClassName;
+ (TGPresentationPallete *)previewPalleteWithPallete:(TGPresentationPallete *)pallete themeColors:(NSDictionary *)colors;
+ (NSArray *)selectorNamesForParameterIdentifier:(NSString *)identifier;

+ (void)setSeparatorsHidden:(bool)hidden;

@end
