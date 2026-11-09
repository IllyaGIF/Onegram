#import "TGStoryComposerController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#endif

#import "TGCollectionItem.h"
#import "TGCollectionItemView.h"
#import "TGCollectionMenuSection.h"
#import "TGCollectionMultilineInputItem.h"
#import "TGCheckCollectionItem.h"
#import "TGSwitchCollectionItem.h"
#import "TGHeaderCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGCustomActionSheet.h"
#import "TGCustomAlertView.h"
#import "TGStoriesSignals.h"
#import "TGStoriesStore.h"
#import "TGUploadFileSignals.h"
#import "TGTelegraph.h"
#import "TGPresentation.h"

static const CGFloat TGStoryComposerMaxPhotoSide = 1920.0f;
static const NSTimeInterval TGStoryComposerMaxVideoDuration = 60.0;
static const int32_t TGStoryComposerDefaultPeriod = 86400;

static uint64_t TGStoryReadBigEndian(const uint8_t *bytes, NSUInteger length)
{
    uint64_t value = 0;
    for (NSUInteger i = 0; i < length; i++)
        value = (value << 8) | bytes[i];
    return value;
}

static bool TGStoryFindBox(NSData *data, NSUInteger start, NSUInteger end, const char *type, NSUInteger *boxStart, NSUInteger *boxEnd)
{
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger offset = start;
    while (offset + 8 <= end)
    {
        uint64_t size = TGStoryReadBigEndian(bytes + offset, 4);
        NSUInteger header = 8;
        if (size == 1)
        {
            if (offset + 16 > end)
                return false;
            size = TGStoryReadBigEndian(bytes + offset + 8, 8);
            header = 16;
        }
        else if (size == 0)
            size = end - offset;
        if (size < header || offset + size > end)
            return false;
        if (memcmp(bytes + offset + 4, type, 4) == 0)
        {
            *boxStart = offset + header;
            *boxEnd = offset + (NSUInteger)size;
            return true;
        }
        offset += (NSUInteger)size;
    }
    return false;
}

static NSData *TGStoryReadMovieBox(NSString *path)
{
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (handle == nil)
        return nil;
    unsigned long long fileSize = [handle seekToEndOfFile];
    unsigned long long offset = 0;
    NSData *result = nil;
    while (offset + 8 <= fileSize)
    {
        [handle seekToFileOffset:offset];
        NSData *header = [handle readDataOfLength:16];
        if (header.length < 8)
            break;
        const uint8_t *bytes = (const uint8_t *)header.bytes;
        uint64_t size = TGStoryReadBigEndian(bytes, 4);
        if (size == 1 && header.length >= 16)
            size = TGStoryReadBigEndian(bytes + 8, 8);
        else if (size == 0)
            size = fileSize - offset;
        if (size < 8 || offset + size > fileSize)
            break;
        if (memcmp(bytes + 4, "moov", 4) == 0 && size < 64 * 1024 * 1024)
        {
            [handle seekToFileOffset:offset];
            result = [handle readDataOfLength:(NSUInteger)size];
            break;
        }
        offset += size;
    }
    [handle closeFile];
    return result;
}

static bool TGStoryMovieInfo(NSString *path, NSTimeInterval *duration, CGSize *dimensions)
{
    NSData *moov = TGStoryReadMovieBox(path);
    if (moov.length < 8)
        return false;
    const uint8_t *bytes = (const uint8_t *)moov.bytes;
    NSUInteger moovStart = 0;
    NSUInteger moovEnd = 0;
    if (!TGStoryFindBox(moov, 0, moov.length, "moov", &moovStart, &moovEnd))
        return false;

    NSUInteger mvhdStart = 0;
    NSUInteger mvhdEnd = 0;
    if (TGStoryFindBox(moov, moovStart, moovEnd, "mvhd", &mvhdStart, &mvhdEnd) && mvhdEnd - mvhdStart >= 20)
    {
        uint8_t version = bytes[mvhdStart];
        uint64_t timescale = 0;
        uint64_t length = 0;
        if (version == 1 && mvhdEnd - mvhdStart >= 32)
        {
            timescale = TGStoryReadBigEndian(bytes + mvhdStart + 20, 4);
            length = TGStoryReadBigEndian(bytes + mvhdStart + 24, 8);
        }
        else
        {
            timescale = TGStoryReadBigEndian(bytes + mvhdStart + 12, 4);
            length = TGStoryReadBigEndian(bytes + mvhdStart + 16, 4);
        }
        if (timescale != 0)
            *duration = (NSTimeInterval)length / (NSTimeInterval)timescale;
    }

    NSUInteger offset = moovStart;
    while (offset < moovEnd)
    {
        NSUInteger trakStart = 0;
        NSUInteger trakEnd = 0;
        if (!TGStoryFindBox(moov, offset, moovEnd, "trak", &trakStart, &trakEnd))
            break;
        NSUInteger tkhdStart = 0;
        NSUInteger tkhdEnd = 0;
        if (TGStoryFindBox(moov, trakStart, trakEnd, "tkhd", &tkhdStart, &tkhdEnd) && tkhdEnd - tkhdStart >= 8)
        {
            CGFloat width = (CGFloat)(TGStoryReadBigEndian(bytes + tkhdEnd - 8, 4) >> 16);
            CGFloat height = (CGFloat)(TGStoryReadBigEndian(bytes + tkhdEnd - 4, 4) >> 16);
            if (width > 0.0f && height > 0.0f)
            {
                *dimensions = CGSizeMake(width, height);
                return true;
            }
        }
        offset = trakEnd;
    }
    return *duration > DBL_EPSILON;
}

static UIImage *TGStoryScaledImage(UIImage *image)
{
    CGSize size = image.size;
    CGFloat scale = MIN(1.0f, TGStoryComposerMaxPhotoSide / MAX(size.width, size.height));
    CGSize targetSize = CGSizeMake(CGFloor(size.width * scale), CGFloor(size.height * scale));
    UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0f);
    [image drawInRect:CGRectMake(0.0f, 0.0f, targetSize.width, targetSize.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@interface TGStoryComposerPreviewItemView : TGCollectionItemView
{
    UIImageView *_imageView;
}

- (void)setImage:(UIImage *)image;

@end

@implementation TGStoryComposerPreviewItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = true;
        _imageView.layer.cornerRadius = 10.0f;
        _imageView.backgroundColor = [UIColor blackColor];
        [self.contentView addSubview:_imageView];
    }
    return self;
}

- (void)setImage:(UIImage *)image
{
    _imageView.image = image;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat height = self.bounds.size.height - 16.0f;
    CGFloat width = CGFloor(height * 9.0f / 16.0f);
    _imageView.frame = CGRectMake(CGFloor((self.bounds.size.width - width) / 2.0f), 8.0f, width, height);
}

@end

@interface TGStoryComposerPreviewItem : TGCollectionItem

@property (nonatomic, strong) UIImage *image;

@end

@implementation TGStoryComposerPreviewItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.transparent = true;
        self.selectable = false;
        self.highlightable = false;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGStoryComposerPreviewItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 300.0f);
}

- (void)bindView:(TGStoryComposerPreviewItemView *)view
{
    [super bindView:view];
    [view setImage:_image];
}

@end

@interface TGStoryComposerLauncher : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, weak) UIViewController *parentController;
@property (nonatomic, copy) void (^completion)(NSArray *stories);

- (void)presentWithSourceType:(UIImagePickerControllerSourceType)sourceType;

@end

static NSMutableSet *TGStoryComposerActiveLaunchers(void)
{
    static NSMutableSet *launchers = nil;
    if (launchers == nil)
        launchers = [[NSMutableSet alloc] init];
    return launchers;
}

@implementation TGStoryComposerLauncher

- (void)presentWithSourceType:(UIImagePickerControllerSourceType)sourceType
{
    UIViewController *parentController = _parentController;
    if (parentController == nil || ![UIImagePickerController isSourceTypeAvailable:sourceType])
        return;
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = sourceType;
    NSArray *availableTypes = [UIImagePickerController availableMediaTypesForSourceType:sourceType];
    NSMutableArray *mediaTypes = [[NSMutableArray alloc] init];
    for (NSString *type in @[@"public.image", @"public.movie"])
    {
        if ([availableTypes containsObject:type])
            [mediaTypes addObject:type];
    }
    if (mediaTypes.count != 0)
        picker.mediaTypes = mediaTypes;
    picker.delegate = self;
    [TGStoryComposerActiveLaunchers() addObject:self];
    [parentController presentViewController:picker animated:true completion:nil];
}

- (void)finish
{
    [TGStoryComposerActiveLaunchers() removeObject:self];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker.presentingViewController dismissViewControllerAnimated:true completion:nil];
    [self finish];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIViewController *parentController = _parentController;
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    TGStoryComposerController *composer = nil;
    if ([mediaType isEqualToString:@"public.movie"])
    {
        NSURL *url = [info objectForKey:UIImagePickerControllerMediaURL];
        if (url != nil)
            composer = [[TGStoryComposerController alloc] initWithVideoPath:url.path previewImage:nil];
    }
    else
    {
        UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
        if (image != nil)
            composer = [[TGStoryComposerController alloc] initWithImage:image];
    }
    composer.completion = _completion;

    [picker.presentingViewController dismissViewControllerAnimated:true completion:nil];
    if (composer != nil && parentController != nil)
    {
        TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[composer]];
        TGDispatchAfter(0.5, dispatch_get_main_queue(), ^
        {
            [parentController presentViewController:navigationController animated:true completion:nil];
        });
    }
    [self finish];
}

@end

@interface TGStoryComposerController ()
{
    UIImage *_image;
    NSString *_videoPath;
    TGStoryPrivacy _privacy;

    TGStoryComposerPreviewItem *_previewItem;
    TGCollectionMultilineInputItem *_captionItem;
    TGCheckCollectionItem *_everyoneItem;
    TGCheckCollectionItem *_contactsItem;
    TGCheckCollectionItem *_closeFriendsItem;
    TGSwitchCollectionItem *_pinnedItem;

    SMetaDisposable *_publishDisposable;
    TGProgressWindow *_progressWindow;
}

@end

@implementation TGStoryComposerController

+ (void)presentFromController:(UIViewController *)controller completion:(void (^)(NSArray *stories))completion
{
    if (controller == nil)
        return;
    __weak UIViewController *weakController = controller;
    void (^launch)(UIImagePickerControllerSourceType) = ^(UIImagePickerControllerSourceType sourceType)
    {
        __strong UIViewController *strongController = weakController;
        if (strongController == nil)
            return;
        TGStoryComposerLauncher *launcher = [[TGStoryComposerLauncher alloc] init];
        launcher.parentController = strongController;
        launcher.completion = completion;
        [launcher presentWithSourceType:sourceType];
    };

    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        launch(UIImagePickerControllerSourceTypePhotoLibrary);
        return;
    }
    NSArray *actions = @[
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"OnegramStories.TakeMedia") action:@"camera"],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"OnegramStories.ChooseFromLibrary") action:@"library"],
        [[TGActionSheetAction alloc] initWithTitle:TGLocalized(@"Common.Cancel") action:@"cancel" type:TGActionSheetActionTypeCancel]
    ];
    [[[TGCustomActionSheet alloc] initWithTitle:nil actions:actions actionBlock:^(__unused id target, NSString *action)
    {
        if ([action isEqualToString:@"camera"])
            launch(UIImagePickerControllerSourceTypeCamera);
        else if ([action isEqualToString:@"library"])
            launch(UIImagePickerControllerSourceTypePhotoLibrary);
    } target:controller] showInView:controller.view];
}

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super init];
    if (self != nil)
    {
        _image = image;
        [self commonInitWithPreview:image];
    }
    return self;
}

- (instancetype)initWithVideoPath:(NSString *)videoPath previewImage:(UIImage *)previewImage
{
    self = [super init];
    if (self != nil)
    {
        _videoPath = videoPath;
        [self commonInitWithPreview:previewImage];
    }
    return self;
}

- (void)commonInitWithPreview:(UIImage *)preview
{
    _publishDisposable = [[SMetaDisposable alloc] init];
    [self setTitleText:TGLocalized(@"OnegramStories.NewStory")];
    [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelPressed)] animated:false];
    [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"OnegramStories.Publish") style:UIBarButtonItemStyleDone target:self action:@selector(publishPressed)] animated:false];

    _previewItem = [[TGStoryComposerPreviewItem alloc] init];
    _previewItem.image = preview;

    _captionItem = [[TGCollectionMultilineInputItem alloc] init];
    _captionItem.placeholder = TGLocalized(@"OnegramStories.CaptionPlaceholder");
    _captionItem.maxLength = 2048;

    TGCollectionMenuSection *previewSection = [[TGCollectionMenuSection alloc] initWithItems:@[_previewItem]];
    previewSection.insets = UIEdgeInsetsMake(8.0f, 0.0f, 8.0f, 0.0f);
    [self.menuSections addSection:previewSection];
    [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[_captionItem]]];

    _everyoneItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramStories.PrivacyEveryone") action:@selector(everyonePressed)];
    _contactsItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramStories.PrivacyContacts") action:@selector(contactsPressed)];
    _closeFriendsItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramStories.PrivacyCloseFriends") action:@selector(closeFriendsPressed)];
    [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[
        [[TGHeaderCollectionItem alloc] initWithTitle:[TGLocalized(@"OnegramStories.WhoCanSee") uppercaseString]],
        _everyoneItem,
        _contactsItem,
        _closeFriendsItem
    ]]];

    _pinnedItem = [[TGSwitchCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramStories.KeepOnProfile") isOn:true];
    [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[
        _pinnedItem,
        [[TGCommentCollectionItem alloc] initWithFormattedText:TGLocalized(@"OnegramStories.KeepOnProfileInfo")]
    ]]];

    [self setPrivacy:TGStoryPrivacyEveryone];

    if (_videoPath != nil && preview == nil)
        [self generateVideoPreview];
}

- (void)dealloc
{
    [_publishDisposable dispose];
    [_progressWindow dismiss:false];
}

- (void)generateVideoPreview
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    if (iosMajorVersion() < 4)
        return;
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:_videoPath] options:nil];
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.appliesPreferredTrackTransform = true;
    generator.maximumSize = CGSizeMake(540.0f, 960.0f);
    CGImageRef imageRef = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:NULL];
    if (imageRef != NULL)
    {
        _previewItem.image = [[UIImage alloc] initWithCGImage:imageRef];
        CGImageRelease(imageRef);
    }
#endif
}

- (void)setPrivacy:(TGStoryPrivacy)privacy
{
    _privacy = privacy;
    _everyoneItem.isChecked = privacy == TGStoryPrivacyEveryone;
    _contactsItem.isChecked = privacy == TGStoryPrivacyContacts;
    _closeFriendsItem.isChecked = privacy == TGStoryPrivacyCloseFriends;
}

- (void)everyonePressed
{
    [self setPrivacy:TGStoryPrivacyEveryone];
}

- (void)contactsPressed
{
    [self setPrivacy:TGStoryPrivacyContacts];
}

- (void)closeFriendsPressed
{
    [self setPrivacy:TGStoryPrivacyCloseFriends];
}

- (void)cancelPressed
{
    [_publishDisposable setDisposable:nil];
    [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
}

- (void)publishPressed
{
    [self.view endEditing:true];
    self.navigationItem.rightBarButtonItem.enabled = false;
    _progressWindow = [[TGProgressWindow alloc] init];
    [_progressWindow show:true];

    int64_t peerId = TGTelegraphInstance.clientUserId;
    NSString *caption = _captionItem.text;
    TGStoryPrivacy privacy = _privacy;
    bool pinned = _pinnedItem.isOn;

    SSignal *publishSignal = nil;
    if (_image != nil)
    {
        UIImage *image = _image;
        publishSignal = [[[SSignal defer:^SSignal *
        {
            NSData *data = UIImageJPEGRepresentation(TGStoryScaledImage(image), 0.87f);
            if (data.length == 0)
                return [SSignal fail:nil];
            return [TGUploadFileSignals uploadedFileWithData:data mediaTypeTag:TGNetworkMediaTypeTagImage];
        }] startOn:[SQueue concurrentDefaultQueue]] mapToSignal:^SSignal *(TLInputFile *file)
        {
            return [TGStoriesSignals sendPhotoStoryWithFile:file peerId:peerId caption:caption privacy:privacy period:TGStoryComposerDefaultPeriod pinned:pinned];
        }];
    }
    else if (_videoPath != nil)
    {
        publishSignal = [[self preparedVideoSignal] mapToSignal:^SSignal *(NSString *path)
        {
            NSTimeInterval duration = 0.0;
            CGSize dimensions = CGSizeZero;
            TGStoryMovieInfo(path, &duration, &dimensions);
            return [[TGUploadFileSignals uploadedFileWithPath:path liveData:nil mediaTypeTag:TGNetworkMediaTypeTagVideo] mapToSignal:^SSignal *(TLInputFile *file)
            {
                return [TGStoriesSignals sendVideoStoryWithFile:file thumbnail:nil duration:MIN(duration, TGStoryComposerMaxVideoDuration) dimensions:dimensions peerId:peerId caption:caption privacy:privacy period:TGStoryComposerDefaultPeriod pinned:pinned];
            }];
        }];
    }
    if (publishSignal == nil)
        return;

    __weak TGStoryComposerController *weakSelf = self;
    [_publishDisposable setDisposable:[[[[[TGStoriesSignals canSendStory:peerId] catch:^SSignal *(__unused id error)
    {
        return [SSignal single:@1];
    }] mapToSignal:^SSignal *(NSNumber *remains)
    {
        if ([remains intValue] <= 0)
            return [SSignal fail:@"limit"];
        return publishSignal;
    }] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *stories)
    {
        __strong TGStoryComposerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf publishCompleted:stories];
    } error:^(id error)
    {
        __strong TGStoryComposerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf publishFailed:[error isEqual:@"limit"]];
    } completed:nil]];
}

- (SSignal *)preparedVideoSignal
{
    NSString *sourcePath = _videoPath;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    if (iosMajorVersion() >= 4)
    {
        return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:sourcePath] options:nil];
            NSString *preset = [[AVAssetExportSession exportPresetsCompatibleWithAsset:asset] containsObject:AVAssetExportPreset1280x720] ? AVAssetExportPreset1280x720 : AVAssetExportPresetMediumQuality;
            AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:asset presetName:preset];
            NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"story-%x.mp4", (int)arc4random()]];
            session.outputURL = [NSURL fileURLWithPath:outputPath];
            session.outputFileType = AVFileTypeMPEG4;
            session.shouldOptimizeForNetworkUse = true;
            if (CMTimeGetSeconds(asset.duration) > TGStoryComposerMaxVideoDuration)
                session.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(TGStoryComposerMaxVideoDuration, 600));
            [session exportAsynchronouslyWithCompletionHandler:^
            {
                if (session.status == AVAssetExportSessionStatusCompleted)
                {
                    [subscriber putNext:outputPath];
                    [subscriber putCompletion];
                }
                else
                    [subscriber putError:nil];
            }];
            return [[SBlockDisposable alloc] initWithBlock:^
            {
                [session cancelExport];
            }];
        }];
    }
#endif
    return [SSignal single:sourcePath];
}

- (void)publishCompleted:(NSArray *)stories
{
    [_progressWindow dismissWithSuccess];
    _progressWindow = nil;
    [[TGStoriesStore instance] addStories:stories forPeerId:TGTelegraphInstance.clientUserId];
    [[TGStoriesStore instance] refresh];
    void (^completion)(NSArray *) = _completion;
    [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
    if (completion != nil)
        completion(stories);
}

- (void)publishFailed:(bool)limitReached
{
    [_progressWindow dismiss:true];
    _progressWindow = nil;
    self.navigationItem.rightBarButtonItem.enabled = true;
    [TGCustomAlertView presentAlertWithTitle:nil message:limitReached ? TGLocalized(@"OnegramStories.LimitReached") : TGLocalized(@"OnegramStories.PublishFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
}

@end
