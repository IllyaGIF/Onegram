#import <Foundation/Foundation.h>


@class TGUser;

@interface TGAppSession : NSObject

@property (nonatomic, readonly) int64_t sessionHash;
@property (nonatomic, readonly) TGUser *bot;
@property (nonatomic, strong, readonly) NSString *domain;
@property (nonatomic, strong, readonly) NSString *browser;
@property (nonatomic, strong, readonly) NSString *platform;
@property (nonatomic, readonly) int32_t dateCreated;
@property (nonatomic, readonly) int32_t dateActive;
@property (nonatomic, strong, readonly) NSString *ip;
@property (nonatomic, strong, readonly) NSString *country;
@property (nonatomic, strong, readonly) NSString *region;

- (instancetype)initWithSessionHash:(int64_t)sessionHash bot:(TGUser *)bot domain:(NSString *)domain browser:(NSString *)browser platform:(NSString *)platform dateCreated:(int32_t)dateCreated dateActive:(int32_t)dateActive ip:(NSString *)ip country:(NSString *)country region:(NSString *)region;

@end

