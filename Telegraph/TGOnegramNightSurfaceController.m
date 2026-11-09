#import "TGOnegramNightSurfaceController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGCollectionMenuSection.h"
#import "TGHeaderCollectionItem.h"
#import "TGCheckCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGNightPresentationPallete.h"
#import "TGOnegramSettings.h"

NSString *TGOnegramNightSurfaceToneTitle(NSInteger tone)
{
    uint32_t color = [TGNightPresentationPallete surfaceColorForTone:(NSUInteger)MAX(0, tone)];
    NSString *name = TGLocalized([[NSString alloc] initWithFormat:@"OnegramAppearance.NightSurface.%d", (int)tone]);
    return [[NSString alloc] initWithFormat:@"%@ · #%06X", name, (unsigned int)color];
}

@interface TGOnegramNightSurfaceController ()
{
    NSArray *_toneItems;
}

@end

@implementation TGOnegramNightSurfaceController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [self setTitleText:TGLocalized(@"OnegramAppearance.NightSurface")];

        NSMutableArray *items = [[NSMutableArray alloc] init];
        [items addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramAppearance.NightSurfaceHeader")]];
        NSMutableArray *toneItems = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < [TGNightPresentationPallete surfaceToneCount]; i++)
        {
            TGCheckCollectionItem *item = [[TGCheckCollectionItem alloc] initWithTitle:TGOnegramNightSurfaceToneTitle((NSInteger)i) action:@selector(tonePressed:)];
            [toneItems addObject:item];
            [items addObject:item];
        }
        [items addObject:[[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"OnegramAppearance.NightSurfaceInfo")]];
        _toneItems = toneItems;
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:items]];
        [self updateSelection];
    }
    return self;
}

- (void)updateSelection
{
    NSInteger tone = [TGOnegramSettings integerForKey:TGOnegramSettingAppearanceNightSurface];
    for (NSUInteger i = 0; i < _toneItems.count; i++)
        ((TGCheckCollectionItem *)_toneItems[i]).isChecked = (NSInteger)i == tone;
}

- (void)tonePressed:(TGCheckCollectionItem *)item
{
    NSUInteger index = [_toneItems indexOfObject:item];
    if (index == NSNotFound || item.isChecked)
        return;
    [TGOnegramSettings setInteger:(NSInteger)index forKey:TGOnegramSettingAppearanceNightSurface];
    [self updateSelection];
}

@end
