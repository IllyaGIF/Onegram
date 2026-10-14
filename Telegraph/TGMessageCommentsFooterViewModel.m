#import "TGMessageCommentsFooterViewModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGMessageCommentsFooterView.h"
#import "TGDatabase.h"

@interface TGMessageCommentsFooterReplier ()

- (instancetype)initWithPeerId:(int64_t)peerId isUser:(bool)isUser avatarUrl:(NSString *)avatarUrl firstName:(NSString *)firstName lastName:(NSString *)lastName;

@end

@implementation TGMessageCommentsFooterReplier

- (instancetype)initWithPeerId:(int64_t)peerId isUser:(bool)isUser avatarUrl:(NSString *)avatarUrl firstName:(NSString *)firstName lastName:(NSString *)lastName
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _isUser = isUser;
        _avatarUrl = [avatarUrl copy];
        _firstName = [firstName copy];
        _lastName = [lastName copy];
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[TGMessageCommentsFooterReplier class]])
        return false;
    TGMessageCommentsFooterReplier *other = object;
    return other.peerId == _peerId && other.isUser == _isUser && TGStringCompare(other.avatarUrl, _avatarUrl) && TGStringCompare(other.firstName, _firstName) && TGStringCompare(other.lastName, _lastName);
}

- (NSUInteger)hash
{
    return (NSUInteger)_peerId;
}

+ (NSArray *)repliersWithPeerIds:(NSArray *)peerIds
{
    NSMutableArray *repliers = [[NSMutableArray alloc] init];
    for (NSNumber *peerIdValue in peerIds)
    {
        int64_t peerId = [peerIdValue longLongValue];
        if (TGPeerIdIsUser(peerId))
        {
            TGUser *user = [TGDatabaseInstance() loadUser:(int32_t)peerId];
            if (user != nil)
                [repliers addObject:[[TGMessageCommentsFooterReplier alloc] initWithPeerId:peerId isUser:true avatarUrl:user.photoFullUrlSmall firstName:user.firstName lastName:user.lastName]];
        }
        else if (TGPeerIdIsChannel(peerId) || TGPeerIdIsGroup(peerId))
        {
            TGConversation *conversation = TGPeerIdIsChannel(peerId) ? [TGDatabaseInstance() loadChannels:@[@(peerId)]][@(peerId)] : [TGDatabaseInstance() loadConversationWithId:peerId];
            if (conversation != nil)
                [repliers addObject:[[TGMessageCommentsFooterReplier alloc] initWithPeerId:peerId isUser:false avatarUrl:conversation.chatPhotoFullSmall firstName:conversation.chatTitle lastName:nil]];
        }
    }
    return repliers;
}

@end

@implementation TGMessageCommentsFooterViewModel

- (Class)viewClass
{
    return [TGMessageCommentsFooterView class];
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [super bindViewToContainer:container viewStorage:viewStorage];

    TGMessageCommentsFooterView *view = (TGMessageCommentsFooterView *)[self boundView];
    [view setRepliers:_repliers presentation:_presentation];
    [view setTitle:_title count:_count];
    [view addTarget:self action:@selector(footerPressed) forControlEvents:UIControlEventTouchUpInside];
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    [(TGMessageCommentsFooterView *)[self boundView] removeTarget:self action:@selector(footerPressed) forControlEvents:UIControlEventTouchUpInside];
    [super unbindView:viewStorage];
}

- (void)setRepliers:(NSArray *)repliers
{
    _repliers = [repliers copy];
    [(TGMessageCommentsFooterView *)[self boundView] setRepliers:_repliers presentation:_presentation];
}

- (void)setTitle:(NSString *)title
{
    _title = [title copy];
    [(TGMessageCommentsFooterView *)[self boundView] setTitle:_title count:_count];
}

- (void)setCount:(int32_t)count
{
    _count = count;
    [(TGMessageCommentsFooterView *)[self boundView] setTitle:_title count:_count];
}

- (void)footerPressed
{
    if (_pressed)
        _pressed();
}

- (bool)recordDrawing:(TGModernDrawingRecording *)__unused recording
{
    return [self drawsInContextWithImplementationOfClass:[TGMessageCommentsFooterViewModel class]];
}

- (void)drawInContext:(CGContextRef)__unused context
{
}

@end
