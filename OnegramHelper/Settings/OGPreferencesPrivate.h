#import <UIKit/UIKit.h>

enum
{
    OGPreferencesGroupCell = 0,
    OGPreferencesLinkCell = 1,
    OGPreferencesSwitchCell = 6,
    OGPreferencesStaticTextCell = 7
};

@interface PSSpecifier : NSObject

+ (id)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(int)cell edit:(Class)edit;
- (void)setProperty:(id)property forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;

@end

@interface PSViewController : NSObject

- (id)rootController;

@end

@interface PSListController : PSViewController
{
    NSMutableArray *_specifiers;
}

- (NSArray *)specifiers;
- (void)reloadSpecifiers;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

@end
