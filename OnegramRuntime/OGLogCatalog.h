#import <Foundation/Foundation.h>

typedef enum {
    OGLogSourceOnegram = 0,
    OGLogSourceHelper = 1,
    OGLogSourceSystem = 2
} OGLogSource;

@interface OGLogEntry : NSObject

@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) OGLogSource source;
@property (nonatomic, readonly) NSDate *modificationDate;
@property (nonatomic, readonly) unsigned long long size;

- (NSComparisonResult)compareNewestFirst:(OGLogEntry *)other;

@end

@interface OGLogCatalog : NSObject

+ (NSArray *)installedApplicationDocumentsPaths;
+ (NSArray *)applicationEntriesWithDocumentsPath:(NSString *)documentsPath;
+ (NSArray *)helperEntries;
+ (NSArray *)systemEntriesWithAdditionalDirectories:(NSArray *)directories;
+ (NSArray *)entriesWithDocumentsPaths:(NSArray *)documentsPaths;

+ (NSString *)textAtPath:(NSString *)path maximumLength:(NSUInteger)maximumLength truncated:(bool *)truncated;
+ (NSString *)fullTextAtPath:(NSString *)path;

@end
