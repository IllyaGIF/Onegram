#import <Foundation/Foundation.h>

typedef enum
{
    TGNekroReady,
    TGNekroMissing,
    TGNekroNotPrivileged,
    TGNekroUnsupportedOS
} TGNekroAvailability;

#define TGNekroExitUnsupportedOS 99
#define TGNekroBridgeMissing ((TGNekroAvailability)4)

@interface TGNekroCommand : NSObject

+ (NSString *)enginePath;
+ (TGNekroAvailability)availability;
+ (BOOL)isAvailable;

+ (BOOL)isOSSupported;
+ (NSString *)osVersionDescription;

+ (BOOL)unsupportedOSOverrideEnabled;
+ (void)setUnsupportedOSOverrideEnabled:(BOOL)enabled;

+ (int)run:(NSArray *)arguments;
+ (int)run:(NSArray *)arguments output:(NSString **)output;

@end
