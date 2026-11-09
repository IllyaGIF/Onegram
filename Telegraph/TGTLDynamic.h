#import <Foundation/Foundation.h>

#import "TLMetaRpc.h"

@class SSignal;

extern NSString *const TGTLDynamicErrorDomain;

@interface TGTLDynamicObject : NSObject

@property (nonatomic, strong, readonly) NSString *constructor;
@property (nonatomic, strong, readonly) NSDictionary *fields;

+ (instancetype)objectWithConstructor:(NSString *)constructor fields:(NSDictionary *)fields;
- (instancetype)initWithConstructor:(NSString *)constructor fields:(NSDictionary *)fields;

- (bool)isConstructor:(NSString *)constructor;
- (id)field:(NSString *)name;
- (bool)flag:(NSString *)name;
- (int32_t)int32Field:(NSString *)name;
- (int64_t)int64Field:(NSString *)name;
- (double)doubleField:(NSString *)name;
- (NSString *)stringField:(NSString *)name;
- (NSData *)dataField:(NSString *)name;
- (NSArray *)arrayField:(NSString *)name;
- (TGTLDynamicObject *)objectField:(NSString *)name;

@end

@interface TGTLDynamicObject (MessageActionParsing)

+ (instancetype)parseObjectFromStream:(NSInputStream *)stream signature:(int32_t)signature error:(NSError **)error;

@end

@interface TGTLDynamicRpc : TLMetaRpc

@property (nonatomic, strong, readonly) NSString *method;
@property (nonatomic, strong, readonly) NSDictionary *parameters;
@property (nonatomic, strong, readonly) NSError *encodingError;
@property (nonatomic, strong) NSSet *dynamicTypes;

- (instancetype)initWithMethod:(NSString *)method parameters:(NSDictionary *)parameters;

+ (SSignal *)requestSignalWithMethod:(NSString *)method parameters:(NSDictionary *)parameters;
+ (SSignal *)requestSignalWithMethod:(NSString *)method parameters:(NSDictionary *)parameters dynamicTypes:(NSSet *)dynamicTypes;

+ (id)parseResponseFromStream:(NSInputStream *)is signature:(int32_t)signature request:(TGTLDynamicRpc *)request error:(__autoreleasing NSError **)error;

@end
