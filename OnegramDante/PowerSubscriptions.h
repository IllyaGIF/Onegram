#import "OGDanteSupport.h"

extern NSString * const PowerSubscriptionsDidChangeNotification;

@interface PowerSubscriptions : NSObject

+ (PowerSubscriptions *)shared;

- (NSArray *)allLines;
- (NSArray *)manualLines;
- (BOOL)addText:(NSString *)text error:(NSString **)error;
- (BOOL)removeManualLine:(NSString *)line error:(NSString **)error;

- (NSString *)addURL:(NSString *)url error:(NSString **)error;

- (NSArray *)subscriptions;
- (BOOL)removeAtIndex:(NSUInteger)index error:(NSString **)error;
@property (nonatomic, readonly) NSError *storageError;
@property (nonatomic, readonly) NSString *selectedLine;
- (BOOL)selectLine:(NSString *)line error:(NSString **)error;

- (NSString *)refreshAllNow;

- (void)refreshIfStale;

@end
