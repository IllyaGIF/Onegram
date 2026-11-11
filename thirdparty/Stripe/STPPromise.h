//
//  STPPromise.h
//  Stripe
//
//  Created by Jack Flintermann on 4/20/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OGStripeCompat.h"
#import "STPBlocks.h"

NS_ASSUME_NONNULL_BEGIN

@class STPVoidPromise;

@interface STPPromise OG_COMPAT_TYPE_PARAMETERS(T): NSObject

typedef void (^STPPromiseErrorBlock)(NSError *error);
typedef void (^STPPromiseValueBlock)(OG_COMPAT_TYPE_PARAMETER(T, id) value);
typedef void (^STPPromiseCompletionBlock)(__nullable OG_COMPAT_TYPE_PARAMETER(T, id) value,  NSError * _Nullable error);
typedef id _Nonnull (^STPPromiseMapBlock)(OG_COMPAT_TYPE_PARAMETER(T, id) value);
typedef STPPromise* _Nonnull (^STPPromiseFlatMapBlock)(OG_COMPAT_TYPE_PARAMETER(T, id) value);

@property(atomic, readonly)BOOL completed;
@property(atomic, readonly)OG_COMPAT_TYPE_PARAMETER(T, id) value;
@property(atomic, readonly)NSError *error;

+ (instancetype)promiseWithError:(NSError *)error;
+ (instancetype)promiseWithValue:(OG_COMPAT_TYPE_PARAMETER(T, id))value;

- (void)succeed:(OG_COMPAT_TYPE_PARAMETER(T, id))value;
- (void)fail:(NSError *)error;

- (void)completeWith:(OG_COMPAT_GENERIC(STPPromise, T) *)promise;

- (instancetype)onSuccess:(STPPromiseValueBlock)callback;
- (instancetype)onFailure:(STPPromiseErrorBlock)callback;
- (instancetype)onCompletion:(STPPromiseCompletionBlock)callback;

- (OG_COMPAT_GENERIC(STPPromise, id) *)map:(STPPromiseMapBlock)callback;
- (OG_COMPAT_GENERIC(STPPromise, id) *)flatMap:(STPPromiseFlatMapBlock)callback;
- (STPVoidPromise *)asVoid;

@end

typedef STPPromise* _Nonnull (^STPVoidPromiseFlatMapBlock)();

@interface STPVoidPromise : STPPromise

- (void)succeed;
- (void)voidCompleteWith:(STPVoidPromise *)promise;
- (instancetype)voidOnSuccess:(STPVoidBlock)block;
- (OG_COMPAT_GENERIC(STPPromise, id) *)voidFlatMap:(STPVoidPromiseFlatMapBlock)block;

@end

NS_ASSUME_NONNULL_END
