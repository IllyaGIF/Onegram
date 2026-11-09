#import "TGCollectionItem.h"

@class TGAccountRecord;

@interface TGSettingsAccountCollectionItem : TGCollectionItem

@property (nonatomic, strong, readonly) TGAccountRecord *account;
@property (nonatomic, copy) void (^pressed)(void);

- (instancetype)initWithAccount:(TGAccountRecord *)account;

@end
