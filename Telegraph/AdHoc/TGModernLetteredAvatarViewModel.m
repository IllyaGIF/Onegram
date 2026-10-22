/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGModernLetteredAvatarViewModel.h"

#import "TGModernLetteredAvatarView.h"
#import "../../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"
#import "../../submodules/LegacyComponents/LegacyComponents/TGCache.h"
#import "TGPresentation.h"
#import "../../OnegramRuntime/OGRuntime.h"

@interface TGModernLetteredAvatarViewModel ()
{
    CGSize _size;
    UIImage *_placeholder;
    NSString *_filter;
    
    NSString *_avatarUri;
    
    NSString *_firstName;
    NSString *_lastName;
    NSString *_title;
    int32_t _uid;
    int64_t _groupId;
}

@end

@implementation TGModernLetteredAvatarViewModel

- (instancetype)initWithSize:(CGSize)size placeholder:(UIImage *)placeholder
{
    self = [super init];
    if (self != nil)
    {
        _fontSize = 16.0f;
        _size = size;
        _placeholder = placeholder;
        _filter = [[NSString alloc] initWithFormat:@"circle:%dx%d", (int)_size.width, (int)_size.height];
    }
    return self;
}

- (Class)viewClass
{
    return [TGModernLetteredAvatarView class];
}

- (NSString *)avatarUri
{
    return _avatarUri;
}

- (NSString *)avatarFilter
{
    return _filter;
}

- (void)_prepareLetters
{
    if (_avatarUri.length != 0 || [NSThread isMainThread])
        return;
    if (_uid != 0 || _groupId == 0)
        [TGLetteredAvatarView prepareLettersForFirstName:_firstName lastName:_lastName fontSize:_fontSize height:_size.height];
    else
        [TGLetteredAvatarView prepareLettersForTitle:_title fontSize:_fontSize height:_size.height];
}

- (void)_updateViewStateIdentifier
{
    if (_avatarUri.length != 0)
    {
        self.viewStateIdentifier = [[NSString alloc] initWithFormat:@"TGModernRemoteImageView/%@/%@/%@/%@/%" PRId32 "", _filter, _avatarUri, nil, nil, 0];
    }
    else
    {
        self.viewStateIdentifier = [[NSString alloc] initWithFormat:@"TGModernRemoteImageView/%@/%@/%@/%@/%" PRId32 "", nil, nil, _firstName, _lastName, _uid];
    }
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [self _updateViewStateIdentifier];
    
    [super bindViewToContainer:container viewStorage:viewStorage];
    
    TGModernLetteredAvatarView *view = (TGModernLetteredAvatarView *)[self boundView];
    [view setSingleFontSize:_fontSize doubleFontSize:_fontSize useBoldFont:false];
    view.fadeTransition = !(OGRuntimeSingleCoreDevice() && OGRuntimeInteractionActiveFast());
    
    if (_avatarUri.length == 0) {
        if (_uid != 0) {
            [view setFirstName:_firstName lastName:_lastName uid:_uid placeholder:_placeholder];
        } else if (_groupId != 0) {
            [view setTitle:_title groupId:_groupId placeholder:_placeholder];
        } else {
            [view setFirstName:_firstName lastName:_lastName uid:0 placeholder:_placeholder];
        }
    } else {
        [view setAvatarUri:_avatarUri filter:_filter placeholder:_placeholder];
    }
}

- (void)setFontSize:(CGFloat)fontSize
{
    bool changed = ABS(_fontSize - fontSize) > FLT_EPSILON;
    _fontSize = fontSize;
    [(TGModernLetteredAvatarView *)self.boundView setSingleFontSize:_fontSize doubleFontSize:_fontSize useBoldFont:false];
    if (changed && (_firstName.length != 0 || _lastName.length != 0 || _title.length != 0))
        [self _prepareLetters];
}

- (void)setAvatarUri:(NSString *)avatarUri
{
    _avatarUri = avatarUri;
    if (_avatarUri.length != 0 && _filter.length != 0)
        [[TGRemoteImageView sharedCache] prefetchRenderedAvatar:[TGRemoteImageView cacheKeyForUrl:_avatarUri filter:_filter] completion:nil];
    
    _firstName = nil;
    _lastName = nil;
    _uid = 0;
    TGModernLetteredAvatarView *view = (TGModernLetteredAvatarView *)[self boundView];
    if (view != nil)
    {
        if (_avatarUri.length == 0)
            [view setFirstName:_firstName lastName:_lastName uid:_uid placeholder:_placeholder];
        else
            [view setAvatarUri:_avatarUri filter:_filter placeholder:_placeholder];
    }
}

- (void)setAvatarFirstName:(NSString *)firstName lastName:(NSString *)lastName uid:(int32_t)uid
{
    _avatarUri = nil;
    _firstName = firstName;
    _lastName = lastName;
    _title = nil;
    _uid = uid;
    _groupId = 0;
    
    [self _prepareLetters];
    
    TGModernLetteredAvatarView *view = (TGModernLetteredAvatarView *)[self boundView];
    if (view != nil)
    {
        if (_avatarUri.length == 0)
            [view setFirstName:_firstName lastName:_lastName uid:_uid placeholder:_placeholder];
        else
            [view setAvatarUri:_avatarUri filter:_filter placeholder:_placeholder];
    }
}

- (void)setAvatarTitle:(NSString *)title groupId:(int64_t)groupId
{
    _avatarUri = nil;
    _firstName = nil;
    _lastName = nil;
    _title = title;
    _uid = 0;
    _groupId = groupId;
    
    [self _prepareLetters];
    
    TGModernLetteredAvatarView *view = (TGModernLetteredAvatarView *)[self boundView];
    if (view != nil)
    {
        if (_avatarUri.length == 0)
            [view setTitle:_title groupId:_groupId placeholder:_placeholder];
        else
            [view setAvatarUri:_avatarUri filter:_filter placeholder:_placeholder];
    }
}

@end
