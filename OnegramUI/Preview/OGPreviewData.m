#import "OGPreviewData.h"
@implementation OGPreviewData
+ (NSArray *)badgeCounts
{
    return [NSArray arrayWithObjects:[NSNumber numberWithInt:0], [NSNumber numberWithInt:1], [NSNumber numberWithInt:9], [NSNumber numberWithInt:42], [NSNumber numberWithInt:99], [NSNumber numberWithInt:100], nil];
}
+ (NSArray *)sampleTitles
{
    return [NSArray arrayWithObjects:@"Settings", @"Contacts", @"Calls", @"Saved Messages", nil];
}
@end
