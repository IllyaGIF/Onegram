#import "TGModernConversationViewLayout.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "TGTelegraph.h"

#import "TGMessageModernConversationItem.h"
#import "TGMessageViewModel.h"

#import "TGModernConversationCollectionView.h"

#import "TGTelegramNetworking.h"

#import <algorithm>
#import <pthread.h>
#import <mach/mach.h>
#import <map>
#import <set>
#import <vector>
#import <objc/runtime.h>
#import "../OnegramPlatform/OGPlatformDispatch.h"
#import "../OnegramRuntime/OGRuntime.h"

static const NSInteger TGModernConversationLayoutIndexPathCacheLimit = 16384;
static const NSUInteger TGModernConversationLayoutSpliceThreshold = 64;

#if defined(ONEGRAM_DIAGNOSTICS)
static double TGModernConversationLayoutThreadTime(void)
{
    thread_basic_info_data_t basicInfo;
    mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
    if (thread_info(pthread_mach_thread_np(pthread_self()), THREAD_BASIC_INFO, (thread_info_t)&basicInfo, &count) != KERN_SUCCESS)
        return 0.0;
    return (double)basicInfo.user_time.seconds + (double)basicInfo.user_time.microseconds / 1000000.0 + (double)basicInfo.system_time.seconds + (double)basicInfo.system_time.microseconds / 1000000.0;
}
#endif

static NSIndexPath *TGModernConversationLayoutIndexPath(NSInteger item)
{
    if (item < 0 || item >= TGModernConversationLayoutIndexPathCacheLimit)
        return [NSIndexPath indexPathForItem:item inSection:0];
    
    static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
    static CFMutableArrayRef cache = NULL;
    pthread_mutex_lock(&lock);
    if (cache == NULL)
        cache = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    CFIndex count = CFArrayGetCount(cache);
    while (count <= item)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:count inSection:0];
        CFArrayAppendValue(cache, (__bridge const void *)indexPath);
        count++;
    }
    NSIndexPath *result = (__bridge NSIndexPath *)CFArrayGetValueAtIndex(cache, item);
    pthread_mutex_unlock(&lock);
    return result;
}

struct TGModernConversationLayoutCheckpoint
{
    CGFloat currentHeight;
    int lastMessageDay;
    int groupCollapseFlags;
    int64_t lastGroupedId;
    NSUInteger attributesCount;
    NSUInteger decorationsCount;
    NSUInteger completedGroupsCount;
    NSInteger maxGroupItemIndex;
    bool lastCollapse;
    bool lastInsideUnreadRange;
    bool didAddUnreadHeader;
};

struct TGModernConversationLayoutJournal
{
    std::vector<TGModernConversationLayoutCheckpoint> checkpoints;
    std::vector<int64_t> completedGroupIds;
    std::vector<CGFloat> heights;
    NSInteger maxGroupItemIndex;
};

struct TGModernConversationLayoutConvergence
{
    const TGModernConversationLayoutJournal *previousJournal;
    NSUInteger previousStart;
    NSUInteger currentStart;
    NSUInteger convergedIndex;
    std::map<int64_t, NSUInteger> suffixGroupLastIndex;
    NSUInteger suffixUnreadLastIndex;
};

static bool TGModernConversationCompletedGroupsCompatible(const std::vector<int64_t> &current, const std::vector<int64_t> &previous, size_t previousCount, const std::map<int64_t, NSUInteger> &suffixGroupLastIndex, NSUInteger index)
{
    if (current.empty() && previousCount == 0)
        return true;
    std::set<int64_t> currentSet(current.begin(), current.end());
    std::set<int64_t> previousSet(previous.begin(), previous.begin() + (std::ptrdiff_t)previousCount);
    if (currentSet == previousSet)
        return true;
    std::vector<int64_t> difference;
    std::set_symmetric_difference(currentSet.begin(), currentSet.end(), previousSet.begin(), previousSet.end(), std::back_inserter(difference));
    for (std::vector<int64_t>::const_iterator it = difference.begin(); it != difference.end(); ++it)
    {
        std::map<int64_t, NSUInteger>::const_iterator found = suffixGroupLastIndex.find(*it);
        if (found != suffixGroupLastIndex.end() && found->second >= index)
            return false;
    }
    return true;
}

@interface TGModernConversationViewLayout ()
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    UIDynamicAnimator *_dynamicAnimator;
#endif
    
    NSMutableArray *_layoutAttributes;
    CGSize _contentSize;
    
    int _dateOffset;
    
    NSMutableArray *_insertIndexPaths;
    NSMutableArray *_deleteIndexPaths;
    
    NSMutableDictionary *_cachedGroupedLayouts;
    
    std::vector<TGDecorationViewAttrubutes> _decorationViewAttributes;
    
    TGModernConversationLayoutJournal _journal;
    NSMutableArray *_journalItems;
    std::vector<const void *> _journalMessages;
    bool _journalValid;
    CGFloat _journalWidth;
    TGMessageRange _journalUnreadRange;
    bool _journalInhibitDateHeaders;
}

@end

@implementation TGModernConversationViewLayout

static bool TGIOS6ValidConversationIndexPath(NSIndexPath *indexPath)
{
    return indexPath != nil && indexPath.length >= 2 && indexPath.section == 0 && indexPath.item != NSNotFound;
}

static inline bool TGModernConversationLayoutIsMessageItem(__unsafe_unretained id item, Class messageItemClass)
{
    return item != nil && (object_getClass(item) == messageItemClass || [item isKindOfClass:messageItemClass]);
}

static void TGModernConversationLayoutCopyPointers(NSArray *array, NSUInteger location, NSUInteger length, std::vector<const void *> &pointers)
{
    pointers.resize(length);
    if (length != 0)
        CFArrayGetValues((__bridge CFArrayRef)array, CFRangeMake((CFIndex)location, (CFIndex)length), &pointers[0]);
}

static void TGModernConversationLayoutAppendMessages(NSArray *items, NSUInteger location, std::vector<const void *> &messages)
{
    NSUInteger count = items.count;
    if (location >= count)
        return;
    std::vector<const void *> pointers;
    TGModernConversationLayoutCopyPointers(items, location, count - location, pointers);
    Class messageItemClass = [TGMessageModernConversationItem class];
    messages.reserve(messages.size() + pointers.size());
    for (size_t index = 0; index < pointers.size(); index++)
    {
        __unsafe_unretained id item = (__bridge id)pointers[index];
        messages.push_back(TGModernConversationLayoutIsMessageItem(item, messageItemClass) ? (__bridge const void *)((TGMessageModernConversationItem *)item)->_message : NULL);
    }
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _layoutAttributes = [[NSMutableArray alloc] init];
        
        _dateOffset = (int)[[TGTelegramNetworking instance] timeOffset];
        
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        if (iosMajorVersion() >= 7 && cpuCoreCount() > 1 && [self isKindOfClass:[UICollectionViewLayout class]])
            _dynamicAnimator = [[UIDynamicAnimator alloc] initWithCollectionViewLayout:(UICollectionViewLayout *)self];
#endif
        
        _cachedGroupedLayouts = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (CGFloat)contentHeight
{
    return _contentSize.height;
}

- (void)prepareForCollectionViewUpdates:(NSArray *)updateItems
{
    [super prepareForCollectionViewUpdates:updateItems];
    
    _deleteIndexPaths = [NSMutableArray array];
    _insertIndexPaths = [NSMutableArray array];
    
    for (PSTCollectionViewUpdateItem *update in updateItems)
    {
        if (update.updateAction == PSTCollectionUpdateActionDelete)
        {
            if (TGIOS6ValidConversationIndexPath(update.indexPathBeforeUpdate))
                [_deleteIndexPaths addObject:update.indexPathBeforeUpdate];
        }
        else if (update.updateAction == PSTCollectionUpdateActionInsert)
        {
            if (TGIOS6ValidConversationIndexPath(update.indexPathAfterUpdate))
                [_insertIndexPaths addObject:update.indexPathAfterUpdate];
        }
    }
}

- (void)finalizeCollectionViewUpdates
{
    [super finalizeCollectionViewUpdates];
    _deleteIndexPaths = nil;
    _insertIndexPaths = nil;
}

- (PSUICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)itemIndexPath
{
    if (!TGIOS6ValidConversationIndexPath(itemIndexPath))
        return nil;

    PSUICollectionViewLayoutAttributes *attributes = [super initialLayoutAttributesForAppearingItemAtIndexPath:itemIndexPath];
    
    if ([_insertIndexPaths containsObject:itemIndexPath])
    {
        if (!attributes)
            attributes = [self layoutAttributesForItemAtIndexPath:itemIndexPath];
        
        attributes = [attributes copy];
        
        attributes.transform3D = CATransform3DMakeTranslation(0.0f, -attributes.frame.size.height - 4.0f, 0.0f);
        
        if (itemIndexPath.item != 0 || iosMajorVersion() < 7 || self.collectionView.contentOffset.y < -self.collectionView.contentInset.top - FLT_EPSILON)
        {
            attributes.alpha = 0.0f;
        }
        else
        {
            attributes.alpha = 1.0f;
            attributes.frame = CGRectMake(attributes.frame.origin.x, attributes.frame.origin.y, attributes.frame.size.width, 24.0);
        }
    }
    
    return attributes;
}

- (PSUICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)itemIndexPath
{
    if (!TGIOS6ValidConversationIndexPath(itemIndexPath))
        return nil;

    PSUICollectionViewLayoutAttributes *attributes = [super finalLayoutAttributesForDisappearingItemAtIndexPath:itemIndexPath];
    
    if ([_deleteIndexPaths containsObject:itemIndexPath])
    {
        if (!attributes)
        {
        }
        
        attributes = [attributes copy];
        
        attributes.alpha = 0.0;
    }
    
    return attributes;
}

static bool TGModernConversationGroupedLayoutMatchesMessages(TGMessageGroupedLayout *groupedLayout, NSArray *messages)
{
    if (groupedLayout == nil || groupedLayout.count != messages.count)
        return false;
    
    for (TGMessage *message in messages)
    {
        if ([groupedLayout positionForMessageId:message.mid] == TGMessageGroupPositionNone)
            return false;
    }
    return true;
}

static inline CGFloat addDate(CGFloat currentHeight, CGFloat containerWidth, int date, std::vector<TGDecorationViewAttrubutes> *pAttributes)
{
    if (pAttributes != NULL)
        pAttributes->push_back((TGDecorationViewAttrubutes){.index = date, .frame = CGRectMake(0, currentHeight, containerWidth, 27.0f)});
    
    return 27.0f;
}

static inline CGFloat addUnreadHeader(CGFloat currentHeight, CGFloat containerWidth, std::vector<TGDecorationViewAttrubutes> *pAttributes)
{
    if (pAttributes != NULL)
        pAttributes->push_back((TGDecorationViewAttrubutes){.index = INT_MIN, .frame = CGRectMake(0, currentHeight, containerWidth, 31.0f)});
    
    return 31.0f;
}

- (NSArray *)layoutAttributesForItems:(NSArray *)items containerWidth:(CGFloat)containerWidth maxHeight:(CGFloat)maxHeight decorationViewAttributes:(std::vector<TGDecorationViewAttrubutes> *)decorationViewAttributes contentHeight:(CGFloat *)contentHeight viewStorage:(TGModernViewStorage *)viewStorage
{
    return [TGModernConversationViewLayout layoutAttributesForItems:items containerWidth:containerWidth maxHeight:maxHeight dateOffset:_dateOffset decorationViewAttributes:decorationViewAttributes contentHeight:contentHeight unreadMessageRange:((TGModernConversationCollectionView *)self.collectionView).unreadMessageRange viewStorage:viewStorage cachedGroupedLayouts:_cachedGroupedLayouts inhibitDateHeaders:self.inhibitDateHeaders];
}

+ (NSArray *)layoutAttributesForItems:(NSArray *)items containerWidth:(CGFloat)containerWidth maxHeight:(CGFloat)maxHeight dateOffset:(int)dateOffset decorationViewAttributes:(std::vector<TGDecorationViewAttrubutes> *)decorationViewAttributes contentHeight:(CGFloat *)contentHeight unreadMessageRange:(TGMessageRange)unreadMessageRange viewStorage:(TGModernViewStorage *)viewStorage cachedGroupedLayouts:(NSMutableDictionary *)cachedGroupedLayouts inhibitDateHeaders:(bool)inhibitDateHeaders
{
    return [self _layoutAttributesForItems:items containerWidth:containerWidth maxHeight:maxHeight dateOffset:dateOffset decorationViewAttributes:decorationViewAttributes contentHeight:contentHeight unreadMessageRange:unreadMessageRange viewStorage:viewStorage cachedGroupedLayouts:cachedGroupedLayouts inhibitDateHeaders:inhibitDateHeaders journal:NULL startIndex:0 convergence:NULL];
}

+ (NSArray *)layoutAttributesForItems:(NSArray *)items containerWidth:(CGFloat)containerWidth maxHeight:(CGFloat)maxHeight dateOffset:(int)dateOffset decorationViewAttributes:(std::vector<TGDecorationViewAttrubutes> *)decorationViewAttributes contentHeight:(CGFloat *)contentHeight unreadMessageRange:(TGMessageRange)unreadMessageRange viewStorage:(TGModernViewStorage *)viewStorage cachedGroupedLayouts:(NSMutableDictionary *)cachedGroupedLayouts
{
    return [self _layoutAttributesForItems:items containerWidth:containerWidth maxHeight:maxHeight dateOffset:dateOffset decorationViewAttributes:decorationViewAttributes contentHeight:contentHeight unreadMessageRange:unreadMessageRange viewStorage:viewStorage cachedGroupedLayouts:cachedGroupedLayouts inhibitDateHeaders:false journal:NULL startIndex:0 convergence:NULL];
}

+ (NSArray *)_layoutAttributesForItems:(NSArray *)items containerWidth:(CGFloat)containerWidth maxHeight:(CGFloat)maxHeight dateOffset:(int)dateOffset decorationViewAttributes:(std::vector<TGDecorationViewAttrubutes> *)decorationViewAttributes contentHeight:(CGFloat *)contentHeight unreadMessageRange:(TGMessageRange)unreadMessageRange viewStorage:(TGModernViewStorage *)viewStorage cachedGroupedLayouts:(NSMutableDictionary *)cachedGroupedLayouts inhibitDateHeaders:(bool)inhibitDateHeaders journal:(TGModernConversationLayoutJournal *)journal startIndex:(NSUInteger)startIndex convergence:(TGModernConversationLayoutConvergence *)convergence
{
    NSMutableArray *layoutAttributes = [[NSMutableArray alloc] init];
    
    CGFloat bottomInset = 0.0f;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        bottomInset = 4.0f;
    else
        bottomInset = 14.0f;
    
    CGFloat currentHeight = bottomInset;
    int lastMessageDay = INT_MIN;
    
    int count = (int)items.count;
    int index = 0;
    
    bool lastCollapse = false;
    bool lastInsideUnreadRange = false;
    bool didAddUnreadHeader = false;
    
    bool unreadRangeIsEmpty = TGMessageRangeIsEmpty(unreadMessageRange);
    
    NSMutableDictionary *groupedLayouts = [[NSMutableDictionary alloc] init];
    NSMutableSet *completedGroups = [[NSMutableSet alloc] init];
    
    int groupCollapseFlags = 0;
    int64_t lastGroupedId = 0;
    NSUInteger attributesBase = 0;
    
    if (journal != NULL)
    {
        if (startIndex != 0 && startIndex < journal->checkpoints.size() && (int)startIndex < count)
        {
            TGModernConversationLayoutCheckpoint const &checkpoint = journal->checkpoints[startIndex];
            currentHeight = checkpoint.currentHeight;
            lastMessageDay = checkpoint.lastMessageDay;
            groupCollapseFlags = checkpoint.groupCollapseFlags;
            lastGroupedId = checkpoint.lastGroupedId;
            lastCollapse = checkpoint.lastCollapse;
            lastInsideUnreadRange = checkpoint.lastInsideUnreadRange;
            didAddUnreadHeader = checkpoint.didAddUnreadHeader;
            attributesBase = checkpoint.attributesCount;
            journal->maxGroupItemIndex = checkpoint.maxGroupItemIndex;
            journal->completedGroupIds.resize(checkpoint.completedGroupsCount);
            for (std::vector<int64_t>::const_iterator it = journal->completedGroupIds.begin(); it != journal->completedGroupIds.end(); ++it)
                [completedGroups addObject:@(*it)];
            journal->checkpoints.resize(startIndex);
            journal->heights.resize(startIndex);
            index = (int)startIndex;
        }
        else
        {
            journal->checkpoints.clear();
            journal->completedGroupIds.clear();
            journal->heights.clear();
            journal->maxGroupItemIndex = -1;
        }
        journal->heights.resize((NSUInteger)count, -1.0f);
    }
    
    for (; index < count; index++)
    {
        OGRuntimeLatencyYield();
        TGMessageModernConversationItem *messageItem = items[index];
        if (journal != NULL)
        {
            TGModernConversationLayoutCheckpoint checkpoint;
            checkpoint.currentHeight = currentHeight;
            checkpoint.lastMessageDay = lastMessageDay;
            checkpoint.groupCollapseFlags = groupCollapseFlags;
            checkpoint.lastGroupedId = lastGroupedId;
            checkpoint.attributesCount = attributesBase + layoutAttributes.count;
            checkpoint.decorationsCount = decorationViewAttributes != NULL ? decorationViewAttributes->size() : 0;
            checkpoint.completedGroupsCount = journal->completedGroupIds.size();
            checkpoint.maxGroupItemIndex = journal->maxGroupItemIndex;
            checkpoint.lastCollapse = lastCollapse;
            checkpoint.lastInsideUnreadRange = lastInsideUnreadRange;
            checkpoint.didAddUnreadHeader = didAddUnreadHeader;
            journal->checkpoints.push_back(checkpoint);
            
            if (convergence != NULL && (NSUInteger)index >= convergence->currentStart)
            {
                NSUInteger previousIndex = (NSUInteger)index - convergence->currentStart + convergence->previousStart;
                const TGModernConversationLayoutJournal *previousJournal = convergence->previousJournal;
                if (previousIndex < previousJournal->checkpoints.size())
                {
                    TGModernConversationLayoutCheckpoint const &previousCheckpoint = previousJournal->checkpoints[previousIndex];
                    bool unreadCompatible = previousCheckpoint.didAddUnreadHeader == didAddUnreadHeader || (!lastInsideUnreadRange && (convergence->suffixUnreadLastIndex == NSNotFound || convergence->suffixUnreadLastIndex < (NSUInteger)index));
                    if (previousCheckpoint.lastGroupedId == 0 && lastGroupedId == 0 && previousCheckpoint.maxGroupItemIndex < (NSInteger)previousIndex && journal->maxGroupItemIndex < (NSInteger)index && previousCheckpoint.lastMessageDay == lastMessageDay && previousCheckpoint.groupCollapseFlags == groupCollapseFlags && previousCheckpoint.lastCollapse == lastCollapse && previousCheckpoint.lastInsideUnreadRange == lastInsideUnreadRange && unreadCompatible && TGModernConversationCompletedGroupsCompatible(journal->completedGroupIds, previousJournal->completedGroupIds, previousCheckpoint.completedGroupsCount, convergence->suffixGroupLastIndex, (NSUInteger)index))
                    {
                        convergence->convergedIndex = (NSUInteger)index;
                        if (contentHeight != NULL)
                            *contentHeight = currentHeight;
                        return layoutAttributes;
                    }
                }
            }
        }
        
        if (!unreadRangeIsEmpty)
        {
            int messageDate = (int32_t)messageItem->_message.date;
            bool currentInsideUnreadRange = TGMessageRangeContains(unreadMessageRange, messageItem->_message.fromUid, ABS(messageItem->_message.mid), messageDate);
            if (lastInsideUnreadRange && !currentInsideUnreadRange && !didAddUnreadHeader)
            {
                didAddUnreadHeader = true;
                currentHeight += addUnreadHeader(currentHeight, containerWidth, decorationViewAttributes);
                lastCollapse = false;
            }
            
            lastInsideUnreadRange = currentInsideUnreadRange;
        }
        
        int currentMessageDay = (((int)messageItem->_message.date) + dateOffset) / (24 * 60 * 60);
        if (messageItem->_message.hole != nil || messageItem->_message.group != nil) {
            for (int nextIndex = index + 1; nextIndex < count; nextIndex++) {
                TGMessage *message = ((TGMessageModernConversationItem *)items[nextIndex])->_message;
                if (message.hole == nil && message.group == nil) {
                    currentMessageDay = (((int)message.date) + dateOffset) / (24 * 60 * 60);
                    break;
                }
            }
        }
        if (lastMessageDay != INT_MIN && currentMessageDay != lastMessageDay)
            currentHeight += addDate(currentHeight, containerWidth, lastMessageDay, decorationViewAttributes);
        lastMessageDay = currentMessageDay;
        
        int collapseFlags = 0;
        if (lastCollapse)
            collapseFlags |= TGModernConversationItemCollapseBottom;
        
        int64_t groupedId = messageItem->_message.groupedId;
        if ([completedGroups containsObject:@(groupedId)])
        {
            continue;
        }
        
        if (groupedId != lastGroupedId)
        {
            if (groupedId != 0)
            {
                for (int i = index + 1; i < count; i++)
                {
                    TGMessageModernConversationItem *nextItem = items[i];
                    if (nextItem->_message.groupedId != groupedId)
                    {
                        int nextMessageDay = (((int)nextItem->_message.date) + dateOffset) / (24 * 60 * 60);
                        if (lastMessageDay != INT_MIN && nextMessageDay != lastMessageDay)
                            lastCollapse = false;
                        else
                        {
                            lastCollapse = [nextItem collapseWithItem:messageItem forContainerSize:CGSizeMake(containerWidth, 0.0f)];
                            if (lastCollapse && !unreadRangeIsEmpty)
                            {
                                int nextMessageDate = (int32_t)nextItem->_message.date;
                                bool nextInsideUnreadRange = TGMessageRangeContains(unreadMessageRange, nextItem->_message.fromUid, nextItem->_message.mid, nextMessageDate);
                                if (lastInsideUnreadRange && !nextInsideUnreadRange)
                                    lastCollapse = false;
                            }
                        }
                        
                        if (lastCollapse)
                            collapseFlags |= TGModernConversationItemCollapseTop;
                        
                        break;
                    }
                }
                
                groupCollapseFlags = collapseFlags;
            }
            else
            {
                groupCollapseFlags = 0;
            }
            
            lastGroupedId = groupedId;
        }
        else
        {
            if (index + 1 < count)
            {
                TGMessageModernConversationItem *nextItem = items[index + 1];
                
                int nextMessageDay = (((int)nextItem->_message.date) + dateOffset) / (24 * 60 * 60);
                if (lastMessageDay != INT_MIN && nextMessageDay != lastMessageDay)
                    lastCollapse = false;
                else
                {
                    lastCollapse = [nextItem collapseWithItem:messageItem forContainerSize:CGSizeMake(containerWidth, 0.0f)];
                    if (lastCollapse && !unreadRangeIsEmpty)
                    {
                        int nextMessageDate = (int32_t)nextItem->_message.date;
                        bool nextInsideUnreadRange = TGMessageRangeContains(unreadMessageRange, nextItem->_message.fromUid, nextItem->_message.mid, nextMessageDate);
                        if (lastInsideUnreadRange && !nextInsideUnreadRange)
                            lastCollapse = false;
                    }
                }
                
                if (lastCollapse)
                    collapseFlags |= TGModernConversationItemCollapseTop;
            }
        }
        
        CGSize itemSize = CGSizeZero;
        CGFloat groupHeight = 0.0f;
        if (groupedId != 0)
        {
            NSMutableArray *groupedMessageItems = [[NSMutableArray alloc] init];
            NSMutableDictionary *indexes = [[NSMutableDictionary alloc] init];
            TGMessageGroupedLayout *groupedLayout = groupedLayouts[@(groupedId)];
            if (groupedLayout == nil)
            {
                NSMutableArray *groupedMessages = [[NSMutableArray alloc] initWithObjects:messageItem->_message, nil];
                indexes[@(messageItem->_message.mid)] = @(index);
                [groupedMessageItems addObject:messageItem];
                int32_t lastCurrentGroupMid = messageItem->_message.mid;
                for (int groupIndex = index + 1; groupIndex < count; groupIndex++)
                {
                    TGMessageModernConversationItem *groupItem = items[groupIndex];
                    if (groupItem->_message.groupedId == groupedId)
                    {
                        [groupedMessages insertObject:groupItem->_message atIndex:0];
                        [groupedMessageItems addObject:groupItem];
                        indexes[@(groupItem->_message.mid)] = @(groupIndex);
                        lastCurrentGroupMid = groupItem->_message.mid;
                    }
                    else
                    {
                        if (abs(groupItem->_message.mid - lastCurrentGroupMid) > 10)
                            break;
                    }
                }
                
                if (groupedMessages.count > 1 && groupedMessages.count <= 10)
                {
                    TGMessageGroupedLayout *cachedGroupedLayout = cachedGroupedLayouts[@(groupedId)];
                    if (cachedGroupedLayout == nil || cachedGroupedLayout.count != groupedMessages.count || [cachedGroupedLayout positionForMessageId:messageItem->_message.mid] == 0)
                    {
                        TGMessageGroupedLayout *itemGroupedLayout = [messageItem groupedLayout];
                        if (TGModernConversationGroupedLayoutMatchesMessages(itemGroupedLayout, groupedMessages))
                            cachedGroupedLayout = itemGroupedLayout;
                    }
                    if (cachedGroupedLayout == nil || cachedGroupedLayout.count != groupedMessages.count || [cachedGroupedLayout positionForMessageId:messageItem->_message.mid] == 0)
                    {
                        
                        bool larger = !messageItem.isFeedItem && ((TGPeerIdIsUser(messageItem->_message.cid) || [messageItem.currentAuthorPeer isKindOfClass:[TGConversation class]]) && messageItem->_message.cid != TGTelegraphInstance.clientUserId);
                        TGMessageGroupedLayout *calculatedGroupedLayout = [[TGMessageGroupedLayout alloc] initWithMessages:groupedMessages larger:larger];
                        if (calculatedGroupedLayout.count == groupedMessages.count)
                        {
                            groupedLayout = calculatedGroupedLayout;
                            groupedLayouts[@(groupedId)] = groupedLayout;
                            cachedGroupedLayouts[@(groupedId)] = groupedLayout;
                        }
                        else
                        {
                            [cachedGroupedLayouts removeObjectForKey:@(groupedId)];
                        }
                    }
                    else
                    {
                        groupedLayout = cachedGroupedLayout;
                        groupedLayouts[@(groupedId)] = groupedLayout;
                        cachedGroupedLayouts[@(groupedId)] = groupedLayout;
                    }
                }
                else
                {
                    groupedId = 0;
                }
            }
            
            if (groupedLayout != nil)
            {
                TGMessageModernConversationItem *primaryGroupItem = nil;
                for (TGMessageModernConversationItem *groupItem in groupedMessageItems)
                {
                    TGMessageGroupPositionFlags position = [groupedLayout positionForMessageId:groupItem->_message.mid];
                    if ((position & TGMessageGroupPositionTop) && (position & TGMessageGroupPositionLeft))
                    {
                        primaryGroupItem = groupItem;
                        break;
                    }
                }

                CGFloat groupedMediaOffsetX = 0.0f;
                CGFloat groupedMediaOffsetY = 0.0f;
                if (primaryGroupItem != nil)
                {
                    [primaryGroupItem setGroupedMediaOffsetX:0.0f y:0.0f];
                    primaryGroupItem.collapseFlags = groupCollapseFlags;
                    [primaryGroupItem updateGroupedLayout:groupedLayout];
                    itemSize = [primaryGroupItem sizeForContainerSize:CGSizeMake(containerWidth, 0.0f) viewStorage:viewStorage];
                    groupHeight = MAX(groupHeight, itemSize.height);
                    if (journal != NULL)
                    {
                        NSInteger primaryIndex = [indexes[@(primaryGroupItem->_message.mid)] integerValue];
                        if (primaryIndex >= 0 && primaryIndex < count)
                            journal->heights[(NSUInteger)primaryIndex] = itemSize.height;
                    }
                    groupedMediaOffsetX = [primaryGroupItem groupedMediaOffsetX];
                    groupedMediaOffsetY = [primaryGroupItem groupedMediaOffsetY];
                }

                for (TGMessageModernConversationItem *groupItem in groupedMessageItems)
                {
                    if (groupItem == primaryGroupItem)
                        continue;

                    [groupItem setGroupedMediaOffsetX:groupedMediaOffsetX y:groupedMediaOffsetY];
                    groupItem.collapseFlags = groupCollapseFlags;
                    [groupItem updateGroupedLayout:groupedLayout];
                    itemSize = [groupItem sizeForContainerSize:CGSizeMake(containerWidth, 0.0f) viewStorage:viewStorage];
                    groupHeight = MAX(groupHeight, itemSize.height);
                    if (journal != NULL)
                    {
                        NSInteger groupItemIndex = [indexes[@(groupItem->_message.mid)] integerValue];
                        if (groupItemIndex >= 0 && groupItemIndex < count)
                            journal->heights[(NSUInteger)groupItemIndex] = itemSize.height;
                    }
                }

                for (TGMessageModernConversationItem *groupItem in groupedMessageItems)
                {
                    NSInteger groupIndex = [indexes[@(groupItem->_message.mid)] integerValue];
                    TGMessageGroupPositionFlags position = [groupedLayout positionForMessageId:groupItem->_message.mid];

                    PSUICollectionViewLayoutAttributes *attributes = [PSUICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:TGModernConversationLayoutIndexPath(groupIndex)];
                    attributes.frame = CGRectMake(0, currentHeight, containerWidth, groupHeight);
                    bool isPrimaryGroupItem = (position & TGMessageGroupPositionTop) && (position & TGMessageGroupPositionLeft);
                    attributes.zIndex = isPrimaryGroupItem ? (NSIntegerMax - indexes.count - groupIndex) : (NSIntegerMax - groupIndex);
                    [layoutAttributes addObject:attributes];
                }
                
                if (groupHeight > FLT_EPSILON)
                    currentHeight += groupHeight;
                
                [completedGroups addObject:@(groupedId)];
                if (journal != NULL)
                {
                    journal->completedGroupIds.push_back(groupedId);
                    for (NSNumber *nIndex in [indexes allValues])
                        journal->maxGroupItemIndex = MAX(journal->maxGroupItemIndex, [nIndex integerValue]);
                }
            }
            else
            {
                groupedId = 0;
                
                messageItem.collapseFlags = collapseFlags;
                [messageItem updateGroupedLayout:nil];
                
                itemSize = [messageItem sizeForContainerSize:CGSizeMake(containerWidth, 0.0f) viewStorage:viewStorage];
                if (journal != NULL)
                    journal->heights[(NSUInteger)index] = itemSize.height;
            }
        }
        else
        {
            messageItem.collapseFlags = collapseFlags;
            itemSize = [messageItem sizeForContainerSize:CGSizeMake(containerWidth, 0.0f) viewStorage:viewStorage];
            if (journal != NULL)
                journal->heights[(NSUInteger)index] = itemSize.height;
        }
        
        if (groupedId == 0)
        {
            PSUICollectionViewLayoutAttributes *attributes = [PSUICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:TGModernConversationLayoutIndexPath(index)];
            attributes.frame = CGRectMake(0, currentHeight, itemSize.width, itemSize.height);
            attributes.zIndex = NSIntegerMax - index;
            [layoutAttributes addObject:attributes];
        
            currentHeight += itemSize.height;
        }
        
        if (currentHeight >= maxHeight)
            break;
    }
    
    if (lastMessageDay != INT_MIN && index == (int)items.count && !inhibitDateHeaders)
        currentHeight += addDate(currentHeight, containerWidth, lastMessageDay, decorationViewAttributes);
    
    if (lastInsideUnreadRange)
        currentHeight += addUnreadHeader(currentHeight, containerWidth, decorationViewAttributes);
    
    currentHeight += 4.0f;

    if (contentHeight != NULL)
       *contentHeight = currentHeight;
    
    return layoutAttributes;
}

+ (void)prepareItems:(NSArray *)items containerWidth:(CGFloat)containerWidth dateOffset:(int)dateOffset unreadMessageRange:(TGMessageRange)unreadMessageRange
{
    if (items.count == 0 || containerWidth <= FLT_EPSILON)
        return;
    
    [self layoutAttributesForItems:items containerWidth:containerWidth maxHeight:FLT_MAX dateOffset:dateOffset decorationViewAttributes:NULL contentHeight:NULL unreadMessageRange:unreadMessageRange viewStorage:nil cachedGroupedLayouts:nil inhibitDateHeaders:true];
}

- (bool)hasLayoutAttributes
{
    return _contentSize.height > FLT_EPSILON;
}

- (NSUInteger)_journalStartIndexForItems:(NSArray *)items containerWidth:(CGFloat)containerWidth unreadMessageRange:(TGMessageRange)unreadMessageRange inhibitDateHeaders:(bool)inhibitDateHeaders
{
    NSUInteger previousCount = _journalItems.count;
    NSUInteger count = items.count;
    if (!_journalValid || previousCount == 0 || count == 0 || _journal.checkpoints.size() != previousCount || _journal.heights.size() != previousCount || _journalMessages.size() != previousCount || _layoutAttributes.count == 0)
        return 0;
    if (ABS(_journalWidth - containerWidth) > FLT_EPSILON || _journalInhibitDateHeaders != inhibitDateHeaders || !TGMessageRangeEquals(_journalUnreadRange, unreadMessageRange) || _journalUnreadRange.firstPeerId != unreadMessageRange.firstPeerId || _journalUnreadRange.lastPeerId != unreadMessageRange.lastPeerId)
        return 0;
    
    NSUInteger limit = MIN(count, previousCount);
    std::vector<const void *> currentPointers;
    std::vector<const void *> previousPointers;
    TGModernConversationLayoutCopyPointers(items, 0, limit, currentPointers);
    TGModernConversationLayoutCopyPointers(_journalItems, 0, limit, previousPointers);
    Class messageItemClass = [TGMessageModernConversationItem class];
    NSUInteger changedIndex = 0;
    for (; changedIndex < limit; changedIndex++)
    {
        if (currentPointers[changedIndex] != previousPointers[changedIndex])
            break;
        __unsafe_unretained id candidate = (__bridge id)currentPointers[changedIndex];
        if (!TGModernConversationLayoutIsMessageItem(candidate, messageItemClass))
            break;
        __unsafe_unretained TGMessageModernConversationItem *item = (TGMessageModernConversationItem *)candidate;
        if ((__bridge const void *)item->_message != _journalMessages[changedIndex])
            break;
        CGFloat height = _journal.heights[changedIndex];
        if (height >= 0.0f && ![item hasValidLayoutForContainerWidth:containerWidth height:height])
            break;
    }
    
    if (changedIndex < 2)
        return 0;
    
    NSUInteger startIndex = changedIndex - 1;
    std::set<int64_t> changedGroupIds;
    for (NSUInteger index = changedIndex; index < count; index++)
    {
        TGMessageModernConversationItem *item = items[index];
        if ([item isKindOfClass:[TGMessageModernConversationItem class]])
        {
            int64_t groupedId = item->_message.groupedId;
            if (groupedId != 0)
                changedGroupIds.insert(groupedId);
        }
    }
    
    while (startIndex > 0)
    {
        TGMessageModernConversationItem *previousItem = items[startIndex - 1];
        TGModernConversationLayoutCheckpoint const &checkpoint = _journal.checkpoints[startIndex];
        TGMessage *previousMessage = previousItem->_message;
        bool clean = previousMessage.hole == nil && previousMessage.group == nil && previousMessage.groupedId == 0 && checkpoint.lastGroupedId == 0 && checkpoint.maxGroupItemIndex < (NSInteger)startIndex;
        if (clean && !changedGroupIds.empty())
        {
            NSUInteger windowStart = startIndex > 64 ? startIndex - 64 : 0;
            for (NSUInteger index = windowStart; index < startIndex; index++)
            {
                int64_t groupedId = ((TGMessageModernConversationItem *)items[index])->_message.groupedId;
                if (groupedId != 0 && changedGroupIds.find(groupedId) != changedGroupIds.end())
                {
                    clean = false;
                    break;
                }
            }
        }
        if (clean)
            break;
        startIndex--;
    }
    
    return startIndex;
}

- (bool)_prepareSplicedLayoutForItems:(NSArray *)items containerWidth:(CGFloat)containerWidth unreadMessageRange:(TGMessageRange)unreadMessageRange inhibitDateHeaders:(bool)inhibitDateHeaders maximumPrefixLength:(NSUInteger)maximumPrefixLength contentHeight:(CGFloat *)contentHeight
{
    NSUInteger previousCount = _journalItems.count;
    NSUInteger count = items.count;
    if (!_journalValid || previousCount < 2 || count == 0 || _journal.checkpoints.size() != previousCount || _journal.heights.size() != previousCount || _journalMessages.size() != previousCount || _layoutAttributes.count == 0)
        return false;
    if (ABS(_journalWidth - containerWidth) > FLT_EPSILON || _journalInhibitDateHeaders != inhibitDateHeaders || !TGMessageRangeEquals(_journalUnreadRange, unreadMessageRange) || _journalUnreadRange.firstPeerId != unreadMessageRange.firstPeerId || _journalUnreadRange.lastPeerId != unreadMessageRange.lastPeerId)
        return false;
    
    NSUInteger suffixLength = 0;
    NSUInteger limit = MIN(count, previousCount);
    std::vector<const void *> currentPointers;
    std::vector<const void *> previousPointers;
    TGModernConversationLayoutCopyPointers(items, count - limit, limit, currentPointers);
    TGModernConversationLayoutCopyPointers(_journalItems, previousCount - limit, limit, previousPointers);
    Class messageItemClass = [TGMessageModernConversationItem class];
    while (suffixLength < limit)
    {
        NSUInteger previousIndex = previousCount - 1 - suffixLength;
        NSUInteger pointerIndex = limit - 1 - suffixLength;
        if (currentPointers[pointerIndex] != previousPointers[pointerIndex])
            break;
        __unsafe_unretained id candidate = (__bridge id)currentPointers[pointerIndex];
        if (!TGModernConversationLayoutIsMessageItem(candidate, messageItemClass))
            break;
        __unsafe_unretained TGMessageModernConversationItem *item = (TGMessageModernConversationItem *)candidate;
        if ((__bridge const void *)item->_message != _journalMessages[previousIndex])
            break;
        CGFloat height = _journal.heights[previousIndex];
        if (height >= 0.0f && ![item hasValidLayoutForContainerWidth:containerWidth height:height])
            break;
        suffixLength++;
    }
    
    NSUInteger previousStart = previousCount - suffixLength;
    NSUInteger currentStart = count - suffixLength;
    if (suffixLength < 2 || (previousStart == 0 && currentStart == 0) || currentStart > maximumPrefixLength)
        return false;
    for (NSUInteger index = 0; index < currentStart; index++)
    {
        if (![items[index] isKindOfClass:[TGMessageModernConversationItem class]])
            return false;
    }
    
    TGModernConversationLayoutJournal previousJournal = _journal;
    NSArray *previousAttributes = _layoutAttributes;
    std::vector<TGDecorationViewAttrubutes> previousDecorations = _decorationViewAttributes;
    CGFloat previousContentHeight = _contentSize.height;
    
    TGModernConversationLayoutConvergence convergence;
    convergence.previousJournal = &previousJournal;
    convergence.previousStart = previousStart;
    convergence.currentStart = currentStart;
    convergence.convergedIndex = NSNotFound;
    convergence.suffixUnreadLastIndex = NSNotFound;
    bool unreadRangeIsEmpty = TGMessageRangeIsEmpty(unreadMessageRange);
    for (NSUInteger index = currentStart; index < count; index++)
    {
        TGMessage *message = ((TGMessageModernConversationItem *)items[index])->_message;
        int64_t groupedId = message.groupedId;
        if (groupedId != 0)
            convergence.suffixGroupLastIndex[groupedId] = index;
        if (!unreadRangeIsEmpty && TGMessageRangeContains(unreadMessageRange, message.fromUid, ABS(message.mid), (int32_t)message.date))
            convergence.suffixUnreadLastIndex = index;
    }
    
    std::vector<TGDecorationViewAttrubutes> decorations;
    CGFloat layoutHeight = 0.0f;
    NSArray *prefixAttributes = [TGModernConversationViewLayout _layoutAttributesForItems:items containerWidth:containerWidth maxHeight:FLT_MAX dateOffset:_dateOffset decorationViewAttributes:&decorations contentHeight:&layoutHeight unreadMessageRange:unreadMessageRange viewStorage:_viewStorage cachedGroupedLayouts:_cachedGroupedLayouts inhibitDateHeaders:inhibitDateHeaders journal:&_journal startIndex:0 convergence:&convergence];
    
    NSMutableArray *attributes = [[NSMutableArray alloc] initWithCapacity:previousAttributes.count + prefixAttributes.count];
    [attributes addObjectsFromArray:prefixAttributes];
    
    if (convergence.convergedIndex == NSNotFound)
    {
        _layoutAttributes = attributes;
        _decorationViewAttributes = decorations;
        *contentHeight = layoutHeight;
        return true;
    }
    
    NSUInteger convergedIndex = convergence.convergedIndex;
    NSUInteger previousIndex = convergedIndex - currentStart + previousStart;
    TGModernConversationLayoutCheckpoint const currentCheckpoint = _journal.checkpoints[convergedIndex];
    TGModernConversationLayoutCheckpoint const previousCheckpoint = previousJournal.checkpoints[previousIndex];
    
    CGFloat heightDelta = currentCheckpoint.currentHeight - previousCheckpoint.currentHeight;
    NSInteger indexDelta = (NSInteger)convergedIndex - (NSInteger)previousIndex;
    NSInteger attributesDelta = (NSInteger)currentCheckpoint.attributesCount - (NSInteger)previousCheckpoint.attributesCount;
    NSInteger decorationsDelta = (NSInteger)currentCheckpoint.decorationsCount - (NSInteger)previousCheckpoint.decorationsCount;
    NSInteger groupsDelta = (NSInteger)currentCheckpoint.completedGroupsCount - (NSInteger)previousCheckpoint.completedGroupsCount;
    
    NSUInteger previousAttributesCount = previousAttributes.count;
    for (NSUInteger index = previousCheckpoint.attributesCount; index < previousAttributesCount; index++)
    {
        PSUICollectionViewLayoutAttributes *previous = previousAttributes[index];
        PSUICollectionViewLayoutAttributes *current = [PSUICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:TGModernConversationLayoutIndexPath(previous.indexPath.item + indexDelta)];
        current.frame = CGRectOffset(previous.frame, 0.0f, heightDelta);
        current.zIndex = previous.zIndex - indexDelta;
        [attributes addObject:current];
    }
    
    for (size_t index = previousCheckpoint.decorationsCount; index < previousDecorations.size(); index++)
    {
        TGDecorationViewAttrubutes decoration = previousDecorations[index];
        decoration.frame.origin.y += heightDelta;
        decorations.push_back(decoration);
    }
    
    _journal.checkpoints.resize(convergedIndex);
    for (size_t index = previousIndex; index < previousJournal.checkpoints.size(); index++)
    {
        TGModernConversationLayoutCheckpoint checkpoint = previousJournal.checkpoints[index];
        checkpoint.currentHeight += heightDelta;
        checkpoint.attributesCount = (NSUInteger)((NSInteger)checkpoint.attributesCount + attributesDelta);
        checkpoint.decorationsCount = (NSUInteger)((NSInteger)checkpoint.decorationsCount + decorationsDelta);
        checkpoint.completedGroupsCount = (NSUInteger)((NSInteger)checkpoint.completedGroupsCount + groupsDelta);
        checkpoint.maxGroupItemIndex = checkpoint.maxGroupItemIndex >= (NSInteger)previousIndex ? checkpoint.maxGroupItemIndex + indexDelta : currentCheckpoint.maxGroupItemIndex;
        _journal.checkpoints.push_back(checkpoint);
    }
    
    _journal.completedGroupIds.insert(_journal.completedGroupIds.end(), previousJournal.completedGroupIds.begin() + (std::ptrdiff_t)previousCheckpoint.completedGroupsCount, previousJournal.completedGroupIds.end());
    _journal.maxGroupItemIndex = previousJournal.maxGroupItemIndex >= (NSInteger)previousIndex ? previousJournal.maxGroupItemIndex + indexDelta : currentCheckpoint.maxGroupItemIndex;
    _journal.heights.resize(count, -1.0f);
    for (NSUInteger index = convergedIndex; index < count; index++)
        _journal.heights[index] = previousJournal.heights[index - convergedIndex + previousIndex];
    
    _layoutAttributes = attributes;
    _decorationViewAttributes = decorations;
    *contentHeight = previousContentHeight + heightDelta;
    return true;
}

- (void)prepareLayout
{
#if defined(ONEGRAM_DIAGNOSTICS)
    CFAbsoluteTime diagnosticStartTime = CFAbsoluteTimeGetCurrent();
    double diagnosticStartThreadTime = TGModernConversationLayoutThreadTime();
#endif
    NSArray *items = [(id<TGModernConversationViewLayoutDelegate>)self.collectionView.delegate items];
    CGFloat containerWidth = self.collectionView.bounds.size.width;
    TGMessageRange unreadMessageRange = ((TGModernConversationCollectionView *)self.collectionView).unreadMessageRange;
    bool inhibitDateHeaders = self.inhibitDateHeaders;
    
    NSUInteger startIndex = [self _journalStartIndexForItems:items containerWidth:containerWidth unreadMessageRange:unreadMessageRange inhibitDateHeaders:inhibitDateHeaders];
    
    __block CGFloat contentHeight = 0.0f;
    __block bool spliced = false;
    dispatch_block_t block = ^
    {
        if (startIndex == 0 || items.count - startIndex > TGModernConversationLayoutSpliceThreshold)
            spliced = [self _prepareSplicedLayoutForItems:items containerWidth:containerWidth unreadMessageRange:unreadMessageRange inhibitDateHeaders:inhibitDateHeaders maximumPrefixLength:startIndex == 0 ? items.count : (items.count - startIndex) / 2 contentHeight:&contentHeight];
        if (spliced)
            return;
        
        if (startIndex == 0)
        {
            [_layoutAttributes removeAllObjects];
            _decorationViewAttributes.clear();
        }
        else
        {
            TGModernConversationLayoutCheckpoint const &checkpoint = _journal.checkpoints[startIndex];
            if (checkpoint.attributesCount < _layoutAttributes.count)
                [_layoutAttributes removeObjectsInRange:NSMakeRange(checkpoint.attributesCount, _layoutAttributes.count - checkpoint.attributesCount)];
            if (checkpoint.decorationsCount < _decorationViewAttributes.size())
                _decorationViewAttributes.resize(checkpoint.decorationsCount);
        }
        
        [_layoutAttributes addObjectsFromArray:[TGModernConversationViewLayout _layoutAttributesForItems:items containerWidth:containerWidth maxHeight:FLT_MAX dateOffset:_dateOffset decorationViewAttributes:&_decorationViewAttributes contentHeight:&contentHeight unreadMessageRange:unreadMessageRange viewStorage:_viewStorage cachedGroupedLayouts:_cachedGroupedLayouts inhibitDateHeaders:inhibitDateHeaders journal:&_journal startIndex:startIndex convergence:NULL]];
    };
    
    if (_animateLayout)
    {
        [UIView animateWithDuration:0.3 * 0.7 delay:0 options:0 animations:^
        {
            block();
        } completion:nil];
    }
    else
        block();
    
    _contentSize = CGSizeMake(self.collectionView.bounds.size.width, contentHeight);
    std::sort(_decorationViewAttributes.begin(), _decorationViewAttributes.end(), TGDecorationViewAttrubutesComparator());
    
    NSUInteger itemCount = items.count;
    if (!spliced && startIndex != 0 && _journalItems != nil && startIndex <= _journalItems.count && startIndex <= _journalMessages.size() && startIndex <= itemCount)
    {
        [_journalItems removeObjectsInRange:NSMakeRange(startIndex, _journalItems.count - startIndex)];
        [_journalItems addObjectsFromArray:[items subarrayWithRange:NSMakeRange(startIndex, itemCount - startIndex)]];
        _journalMessages.resize(startIndex);
        TGModernConversationLayoutAppendMessages(items, startIndex, _journalMessages);
    }
    else
    {
        _journalItems = [[NSMutableArray alloc] initWithArray:items];
        _journalMessages.clear();
        TGModernConversationLayoutAppendMessages(items, 0, _journalMessages);
    }
    _journalWidth = containerWidth;
    _journalUnreadRange = unreadMessageRange;
    _journalInhibitDateHeaders = inhibitDateHeaders;
    _journalValid = _journal.checkpoints.size() == items.count;
#if defined(ONEGRAM_DIAGNOSTICS)
    CFAbsoluteTime diagnosticDuration = CFAbsoluteTimeGetCurrent() - diagnosticStartTime;
    if (diagnosticDuration >= 0.016)
        OGPlatformDiagnosticLog(@"LAYOUTSLOW items=%d start=%d spliced=%d ms=%.0f main=%.0f", (int)items.count, (int)startIndex, spliced ? 1 : 0, diagnosticDuration * 1000.0, (TGModernConversationLayoutThreadTime() - diagnosticStartThreadTime) * 1000.0);
#endif

}

- (CGSize)collectionViewContentSize
{
    return _contentSize;
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSUInteger count = _layoutAttributes.count;
    if (count == 0)
        return @[];

    CGFloat minY = CGRectGetMinY(rect);
    CGFloat maxY = CGRectGetMaxY(rect);

    NSUInteger low = 0;
    NSUInteger high = count;
    while (low < high)
    {
        NSUInteger mid = low + (high - low) / 2;
        PSUICollectionViewLayoutAttributes *attributes = _layoutAttributes[mid];
        if (CGRectGetMaxY(attributes.frame) < minY)
            low = mid + 1;
        else
            high = mid;
    }

    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:16];
    for (NSUInteger index = low; index < count; index++)
    {
        PSUICollectionViewLayoutAttributes *attributes = _layoutAttributes[index];
        if (CGRectGetMinY(attributes.frame) > maxY)
            break;

        if (TGIOS6ValidConversationIndexPath(attributes.indexPath) && CGRectIntersectsRect(rect, attributes.frame))
            [array addObject:attributes];
    }

    return array;
}

- (std::vector<TGDecorationViewAttrubutes> *)allDecorationViewAttributes
{
    return &_decorationViewAttributes;
}

- (bool)frameForItemAtIndex:(NSUInteger)index frame:(CGRect *)frame
{
    NSUInteger count = _layoutAttributes.count;
    if (index < count)
    {
        PSUICollectionViewLayoutAttributes *attributes = _layoutAttributes[index];
        NSIndexPath *indexPath = attributes.indexPath;
        if (TGIOS6ValidConversationIndexPath(indexPath) && (NSUInteger)indexPath.row == index)
        {
            if (frame != NULL)
                *frame = attributes.frame;
            return true;
        }
    }
    
    for (PSUICollectionViewLayoutAttributes *attributes in _layoutAttributes)
    {
        NSIndexPath *indexPath = attributes.indexPath;
        if (TGIOS6ValidConversationIndexPath(indexPath) && (NSUInteger)indexPath.row == index)
        {
            if (frame != NULL)
                *frame = attributes.frame;
            return true;
        }
    }
    return false;
}

- (PSUICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!TGIOS6ValidConversationIndexPath(indexPath) || indexPath.row >= (int)_layoutAttributes.count)
    {
        return nil;
    }

    PSUICollectionViewLayoutAttributes *attributes = _layoutAttributes[indexPath.row];
    return attributes;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)__unused newBounds
{
    return false;
}

@end
