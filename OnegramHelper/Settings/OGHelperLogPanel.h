#import "OGPreferencesPrivate.h"

@class OGLogEntry;

@interface OGHelperLogPanel : UIView

- (instancetype)initWithEntry:(OGLogEntry *)entry bundle:(NSBundle *)bundle;

+ (void)presentEntry:(OGLogEntry *)entry bundle:(NSBundle *)bundle fromController:(PSViewController *)controller;

@end
