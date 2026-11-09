#import "TGCollectionMenuController.h"
#import "TGVariantCollectionItem.h"

@class TGSwitchCollectionItem;
@class TGOnegramSliderCollectionItem;

@interface TGOnegramActionCollectionItem : TGVariantCollectionItem

@property (nonatomic, copy) void (^pressed)(void);

- (instancetype)initWithTitle:(NSString *)title variant:(NSString *)variant pressed:(void (^)(void))pressed;

@end

@interface TGOnegramSettingsController : TGCollectionMenuController

- (instancetype)initWithTitle:(NSString *)title;

- (NSArray *)buildSections;
- (void)rebuild;
- (bool)rebuildsForSettingKey:(NSString *)key;
- (void)settingDidChange:(NSString *)key;

- (TGCollectionMenuSection *)sectionWithHeader:(NSString *)header items:(NSArray *)items footer:(NSString *)footer;
- (TGSwitchCollectionItem *)switchWithTitle:(NSString *)title key:(NSString *)key;
- (TGSwitchCollectionItem *)switchWithTitle:(NSString *)title key:(NSString *)key description:(NSString *)description;
- (TGSwitchCollectionItem *)switchWithTitle:(NSString *)title value:(bool)value toggled:(void (^)(bool value))toggled;
- (TGOnegramActionCollectionItem *)choiceWithTitle:(NSString *)title key:(NSString *)key options:(NSArray *)options;
- (TGOnegramActionCollectionItem *)choiceWithTitle:(NSString *)title key:(NSString *)key options:(NSArray *)options description:(NSString *)description;
- (TGOnegramActionCollectionItem *)actionWithTitle:(NSString *)title variant:(NSString *)variant pressed:(void (^)(void))pressed;
- (TGOnegramActionCollectionItem *)actionWithTitle:(NSString *)title variant:(NSString *)variant description:(NSString *)description pressed:(void (^)(void))pressed;
- (TGOnegramSliderCollectionItem *)sliderWithTitle:(NSString *)title key:(NSString *)key minimumValue:(NSInteger)minimumValue maximumValue:(NSInteger)maximumValue formatter:(NSString *(^)(NSInteger value))formatter;

- (void)pushChoiceWithTitle:(NSString *)title options:(NSArray *)options selectedIndex:(NSInteger)selectedIndex footer:(NSString *)footer completion:(void (^)(NSInteger index))completion;
- (void)pushMultipleChoiceWithTitle:(NSString *)title options:(NSArray *)options selectedIndices:(NSIndexSet *)selectedIndices footer:(NSString *)footer completion:(void (^)(NSIndexSet *indices))completion;
- (void)pushTextInputWithTitle:(NSString *)title text:(NSString *)text placeholder:(NSString *)placeholder secure:(bool)secure footer:(NSString *)footer completion:(void (^)(NSString *text))completion;

@end
