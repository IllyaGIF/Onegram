#import "TGCollectionItem.h"

@interface TGOnegramSliderCollectionItem : TGCollectionItem

@property (nonatomic, strong) NSString *title;
@property (nonatomic) NSInteger minimumValue;
@property (nonatomic) NSInteger maximumValue;
@property (nonatomic) NSInteger step;
@property (nonatomic) bool reversed;
@property (nonatomic) NSInteger value;
@property (nonatomic, copy) NSString *(^valueFormatter)(NSInteger value);
@property (nonatomic, copy) void (^valueChanged)(NSInteger value);
@property (nonatomic, copy) void (^valueCommitted)(NSInteger value);

- (instancetype)initWithTitle:(NSString *)title minimumValue:(NSInteger)minimumValue maximumValue:(NSInteger)maximumValue value:(NSInteger)value;

@end
