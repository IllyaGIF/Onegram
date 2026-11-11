#import "TGWallpaperListController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TGAppDelegate.h"

#import "TGWallpaperListLayout.h"
#import "TGWallpaperItemCell.h"

#import "TGCollectionItemView.h"
#import "TGDisclosureActionCollectionItem.h"

#import "TGWallpaperManager.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGWallpaperInfo.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGCustomImageWallpaperInfo.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteWallpaperInfo.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGColorWallpaperInfo.h"
#import "TGModernRemoteWallpaperListActor.h"

#import "TGLegacyWallpaperController.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGOverlayFormsheetWindow.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGOverlayFormsheetController.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGMediaAssetsController.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLegacyCameraController.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImagePickerController.h"

#import "TGLegacyComponentsContext.h"

#import "TGAppearanceController.h"

#import "TGPresentation.h"
#import "TGDefaultPresentationPallete.h"

@interface TGWallpaperListController () <PSUICollectionViewDelegateFlowLayout, PSUICollectionViewDataSource, TGLegacyWallpaperControllerDelegate, TGLegacyCameraControllerDelegate, TGImagePickerControllerDelegate>
{
    PSUICollectionView *_collectionView;
    TGWallpaperListLayout *_collectionLayout;
    NSMutableSet *_collectionRegisteredItemIdentifiers;
    CGFloat _currentLayoutWidth;
    
    NSArray *_wallpaperItems;
    NSArray *_remoteWallpaperItems;
    
    TGDisclosureActionCollectionItem *_photoLibraryItem;
    
    __weak TGOverlayFormsheetWindow *_photoLibraryWindow;
    UIPopoverController *_pickerPopover;
}

@end

@implementation TGWallpaperListController

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        [self setTitleText:TGLocalized(@"Wallpaper.Title")];
        
        _photoLibraryItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Wallpaper.PhotoLibrary") action:@selector(photoLibraryPressed)];
        _photoLibraryItem.deselectAutomatically = TGIsPad();
        
        TGPresentation *presentation = TGPresentation.current;
        NSMutableArray *wallpaperItems = [[NSMutableArray alloc] init];
        NSMutableArray *colorWallpapers = [[NSMutableArray alloc] init];
        if (![presentation.pallete isMemberOfClass:[TGDefaultPresentationPallete class]])
            [colorWallpapers addObject:@(TGColorHexCode(presentation.pallete.backgroundColor))];
        for (NSNumber *color in @[@(0xffffff), @(0x000000)])
        {
            if (![colorWallpapers containsObject:color])
                [colorWallpapers addObject:color];
        }
        for (NSNumber *color in colorWallpapers)
        {
            uint32_t rgb = [color unsignedIntValue];
            CGFloat luminance = (0.299f * ((rgb >> 16) & 0xff) + 0.587f * ((rgb >> 8) & 0xff) + 0.114f * (rgb & 0xff)) / 255.0f;
            if (luminance < 0.2f)
                [wallpaperItems addObject:[[TGColorWallpaperInfo alloc] initWithColor:rgb tintColor:0xffffff systemAlpha:0.2f buttonsAlpha:0.3f highlightedButtonAlpha:0.45f progressAlpha:0.3f]];
            else
                [wallpaperItems addObject:[[TGColorWallpaperInfo alloc] initWithColor:rgb]];
        }
        [wallpaperItems addObjectsFromArray:[[TGWallpaperManager instance] builtinWallpaperList]];
        _remoteWallpaperItems = [TGModernRemoteWallpaperListActor cachedList];
        [wallpaperItems addObjectsFromArray:_remoteWallpaperItems];
        _wallpaperItems = wallpaperItems;
        
        [ActionStageInstance() requestActor:@"/tg/remoteWallpapers/(cached)" options:nil flags:0 watcher:self];
    }
    return self;
}

- (void)dealloc
{
    _collectionView.delegate = nil;
    _collectionView.dataSource = nil;
    
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    _photoLibraryItem.presentation = presentation;
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = _presentation.pallete.collectionMenuBackgroundColor;
    
    _currentLayoutWidth = self.view.frame.size.width;
    _collectionRegisteredItemIdentifiers = [[NSMutableSet alloc] init];
    
    _collectionLayout = [[TGWallpaperListLayout alloc] init];
    _collectionLayout.presentation = self.presentation;
    _collectionView = [[PSUICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:_collectionLayout];
    if (iosMajorVersion() >= 11)
        _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _collectionView.backgroundColor = nil;
    _collectionView.opaque = false;
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    _collectionView.alwaysBounceVertical = true;
    [_collectionView registerClass:[TGCollectionItemView class] forCellWithReuseIdentifier:@"_empty"];
    [_collectionView registerClass:[TGWallpaperItemCell class] forCellWithReuseIdentifier:@"_wallpaper"];
    [self.view addSubview:_collectionView];
    
    [self setExplicitTableInset:UIEdgeInsetsMake(-(TGScreenPixel), 0, 0, 0)];
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

#pragma mark -

- (void)viewWillAppear:(BOOL)animated
{
    CGFloat currentLayoutWidth = [TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation].width;
    if (ABS(currentLayoutWidth - _currentLayoutWidth) > FLT_EPSILON)
    {
        _currentLayoutWidth = currentLayoutWidth;
        [_collectionLayout invalidateLayout];
    }
    
    for (NSIndexPath *indexPath in [_collectionView indexPathsForSelectedItems])
    {
        [_collectionView deselectItemAtIndexPath:indexPath animated:animated];
    }
    
    [super viewWillAppear:animated];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    _currentLayoutWidth = [TGViewController screenSizeForInterfaceOrientation:toInterfaceOrientation].width;
    [_collectionLayout invalidateLayout];
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    
    if ([self isViewLoaded]) {
        for (TGCollectionItemView *itemView in [_collectionView visibleCells])
        {
            if (![itemView isKindOfClass:[TGCollectionItemView class]])
                continue;
            
            itemView.safeAreaInset = self.controllerSafeAreaInset;
        }
    }
}

#pragma mark -

- (CGSize)collectionView:(PSUICollectionView *)collectionView layout:(PSUICollectionViewLayout *)__unused collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
        return CGSizeMake(collectionView.frame.size.width, 44.0f);
    
    if (TGIsPad())
        return [self og_compat_padLayoutWidthForCollectionView:collectionView] > 320.0f + FLT_EPSILON ? CGSizeMake(110.0f, 146.0f) : CGSizeMake(91.0f, 121.0f);
    
    if ([UIScreen mainScreen].scale < 2.0f - FLT_EPSILON)
        return CGSizeMake(91.0f, 162.0f);
    
    CGSize screenSize = TGScreenSize();
    CGFloat longSide = MAX(screenSize.width, screenSize.height);
    if (longSide >= 812.0f - FLT_EPSILON)
        return CGSizeMake(108.0f, 163.0f);
    if (longSide >= 736.0f - FLT_EPSILON)
        return CGSizeMake(122.0f, 216.0f);
    if (longSide >= 667.0f - FLT_EPSILON)
        return CGSizeMake(108.0f, 163.0f);
    return CGSizeMake(91.0f, 162.0f);
}

- (CGFloat)og_compat_padLayoutWidthForCollectionView:(PSUICollectionView *)collectionView
{
    if ([self inPopover])
        return 320.0f;
    if ([self inFormSheet])
        return 540.0f;
    return collectionView.frame.size.width;
}

- (UIEdgeInsets)collectionView:(PSUICollectionView *)__unused collectionView layout:(PSUICollectionViewLayout *)__unused collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    if (section == 0)
        return UIEdgeInsetsMake(32.0f, 0.0f, 0.0f, 0.0f);
    
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    if (collectionView.frame.size.width > collectionView.frame.size.height)
        orientation = UIInterfaceOrientationLandscapeLeft;
    
    UIEdgeInsets safeAreaInset = [self calculatedSafeAreaInset];
    return UIEdgeInsetsMake(32.0f + 15.0f, 15.0f + safeAreaInset.left, 15.0f + 32.0f, 15.0f + safeAreaInset.left);
}

- (CGFloat)collectionView:(PSUICollectionView *)__unused collectionView layout:(PSUICollectionViewLayout *)__unused collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    if (section == 0)
        return 0.0f;
    
    if (TGIsPad() && [self og_compat_padLayoutWidthForCollectionView:collectionView] > 320.0f + FLT_EPSILON)
        return 14.0f;
    
    return 8.0f;
}

- (CGFloat)collectionView:(PSUICollectionView *)__unused collectionView layout:(PSUICollectionViewLayout*)__unused collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    if (section == 0)
        return 0.0f;
    
    return 8.0f;
}

- (NSInteger)numberOfSectionsInCollectionView:(PSUICollectionView *)__unused collectionView
{
    return 2;
}

- (NSInteger)collectionView:(PSUICollectionView *)__unused collectionView numberOfItemsInSection:(NSInteger)section
{
    if (section == 0)
        return 1;
    
    return _wallpaperItems.count;
}

- (PSUICollectionViewCell *)collectionView:(PSUICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        TGCollectionItemView *itemView = [_photoLibraryItem dequeueItemView:collectionView registeredIdentifiers:_collectionRegisteredItemIdentifiers forIndexPath:indexPath];
        [itemView setItemPosition:TGCollectionItemViewPositionFirstInBlock | TGCollectionItemViewPositionLastInBlock];
        itemView.safeAreaInset = self.controllerSafeAreaInset;
        [_photoLibraryItem bindView:itemView];
        
        return itemView;
    }
    else if (indexPath.item < (NSInteger)_wallpaperItems.count)
    {
        TGWallpaperItemCell *wallpaperCell = (TGWallpaperItemCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"_wallpaper" forIndexPath:indexPath];
        wallpaperCell.presentation = self.presentation;
        TGWallpaperInfo *wallpaperInfo = _wallpaperItems[indexPath.item];
        [wallpaperCell setWallpaperInfo:wallpaperInfo];
        [wallpaperCell setIsSelected:[wallpaperInfo isEqual:[[TGWallpaperManager instance] currentWallpaperInfo]]];
        
        return wallpaperCell;
    }
    
    return [collectionView dequeueReusableCellWithReuseIdentifier:@"_empty" forIndexPath:indexPath];
}

#pragma mark -

- (void)collectionView:(PSUICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        TGCollectionItem *item = _photoLibraryItem;
        
        if (item != nil)
        {
            if (item.deselectAutomatically)
                [collectionView deselectItemAtIndexPath:indexPath animated:true];
            
            [item itemSelected:self];
        }
    }
    else
    {
        TGWallpaperItemCell *wallpaperCell = (TGWallpaperItemCell *)[collectionView cellForItemAtIndexPath:indexPath];
        UIImage *currentImage = [wallpaperCell currentImage];
        if (currentImage)
        {
            TGLegacyWallpaperController *wallpaperController = [[TGLegacyWallpaperController alloc] initWithWallpaperInfo:_wallpaperItems[indexPath.item] thumbnailImage:currentImage];
            wallpaperController.delegate = self;
            wallpaperController.presentation = self.presentation;
            
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
                wallpaperController.modalPresentationStyle = UIModalPresentationFormSheet;
            
            [TGAppDelegateInstance.rootController presentViewController:wallpaperController animated:true completion:nil];
        }
    }
}

- (void)wallpaperController:(TGLegacyWallpaperController *)__unused wallpaperController didSelectWallpaperWithInfo:(TGWallpaperInfo *)wallpaperInfo
{
    if (wallpaperInfo != nil)
    {
        bool shouldReset = [TGPresentationPallete hasWallpaper] == [wallpaperInfo isKindOfClass:[TGColorWallpaperInfo class]];
        [[TGWallpaperManager instance] setCurrentWallpaperWithInfo:wallpaperInfo];
        if (shouldReset)
            [self.presentation.images resetBubbleBackgrounds];
        
        for (id cell in [_collectionView visibleCells])
        {
            if ([cell isKindOfClass:[TGWallpaperItemCell class]])
            {
                [(TGWallpaperItemCell *)cell setIsSelected:[((TGWallpaperItemCell *)cell).wallpaperInfo isEqual:[[TGWallpaperManager instance] currentWallpaperInfo]]];
            }
        }
        
        [self _dismissPhotoLibrary];
    }
    
    for (TGViewController *controller in self.navigationController.viewControllers)
    {
        if ([controller isKindOfClass:[TGAppearanceController class]])
        {
            [self.navigationController popToViewController:controller animated:false];
            break;
        }
    }
}

- (void)photoLibraryPressed
{
    TGLegacyCameraController *imagePickerController = [[TGLegacyCameraController alloc] initWithContext:[TGLegacyComponentsContext shared]];
    imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePickerController.completionDelegate = self;
    
    if (!TGIsPad())
    {
        [self presentViewController:imagePickerController animated:true completion:nil];
        return;
    }
    
    _pickerPopover = [[UIPopoverController alloc] initWithContentViewController:imagePickerController];
    CGRect bounds = self.view.bounds;
    [_pickerPopover presentPopoverFromRect:CGRectMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds), 1.0f, 1.0f) inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:true];
}

- (void)_dismissPhotoLibrary
{
    UIPopoverController *popover = _pickerPopover;
    if (popover != nil)
    {
        _pickerPopover = nil;
        [popover dismissPopoverAnimated:true];
        return;
    }
    
    TGOverlayFormsheetWindow *formsheet = _photoLibraryWindow;
    if (formsheet != nil)
        [formsheet dismissAnimated:true];
    else
        [self dismissViewControllerAnimated:true completion:nil];
}

- (void)legacyCameraControllerCompletedWithNoResult
{
    [self _dismissPhotoLibrary];
}

- (void)imagePickerController:(TGImagePickerController *)__unused imagePicker didFinishPickingWithAssets:(NSArray *)assets
{
    TGOverlayFormsheetWindow *photoLibraryWindow = _photoLibraryWindow;
    UIViewController *hosted = photoLibraryWindow != nil ? [(TGOverlayFormsheetController *)[photoLibraryWindow rootViewController] viewController] : (_pickerPopover != nil ? _pickerPopover.contentViewController : self.presentedViewController);
    UINavigationController *controller = (UINavigationController *)hosted;
    
    if ([controller isKindOfClass:[UINavigationController class]] && assets.count != 0 && [assets[0] isKindOfClass:[UIImage class]])
    {
        UIImage *wallpaperImage = assets[0];
        
        TGLegacyWallpaperController *wallpaperController = [[TGLegacyWallpaperController alloc] initWithWallpaperInfo:[[TGCustomImageWallpaperInfo alloc] initWithImage:wallpaperImage] thumbnailImage:nil];
        wallpaperController.presentation = self.presentation;
        wallpaperController.delegate = self;
        wallpaperController.enableWallpaperAdjustment = true;
        wallpaperController.doNotFlipIfRTL = true;
        [controller pushViewController:wallpaperController animated:true];
    }
    else
    {
        [self _dismissPhotoLibrary];
    }
}

#pragma mark -

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/remoteWallpapers/"])
    {
        if (status == ASStatusSuccess)
        {
            NSArray *wallpaperInfos = result[@"wallpaperInfos"];
            
            TGDispatchOnMainThread(^
            {
                NSMutableArray *wallpaperItems = [[NSMutableArray alloc] init];
                
                for (TGWallpaperInfo *wallpaperInfo in _wallpaperItems)
                {
                    if ([_remoteWallpaperItems indexOfObjectIdenticalTo:wallpaperInfo] == NSNotFound)
                        [wallpaperItems addObject:wallpaperInfo];
                }
                
                [wallpaperItems addObjectsFromArray:wallpaperInfos];
                _remoteWallpaperItems = wallpaperInfos;
                
                bool changed = false;
                
                if (wallpaperItems.count != _wallpaperItems.count)
                    changed = true;
                else
                {
                    for (int i = 0; i < (int)_wallpaperItems.count; i++)
                    {
                        if (![_wallpaperItems[i] isEqual:wallpaperItems[i]])
                        {
                            changed = true;
                            break;
                        }
                    }
                }
                
                if (changed)
                {
                    _wallpaperItems = wallpaperItems;
                    [_collectionView reloadData];
                }
            });
        }
    }
}

@end
