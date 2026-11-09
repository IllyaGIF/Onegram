#import <Foundation/Foundation.h>

static inline NSString *OGHelperSettingsString(NSBundle *bundle, NSString *key)
{
    return [bundle localizedStringForKey:key value:key table:nil];
}
