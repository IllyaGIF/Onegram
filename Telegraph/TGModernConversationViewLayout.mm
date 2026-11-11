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

static double TGModernConversationLayoutThreadTime(void)
{
    thread_basic_info_data_t basicInfo;
    mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
    if (thread_info(pthread_mach_thread_np(pthread_self()), THREAD_BASIC_INFO, (thread_info_t)&basicInfo, &count) != KERN_SUCCESS)
        return 0.0;
    return (double)basicInfo.user_time.seconds + (double)basicInfo.user_time.microseconds / 1000000.0 + (double)basicInfo.system_time.seconds + (double)basicInfo.system_time.microseconds / 1000000.0;
}

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

struct TGModernConversationPreparedFrame
{
    CGRect frame;
    NSInteger zIndex;
    bool valid;
};

struct TGModernConversationPreparedFrameOrder
{
    const std::vector<TGModernConversationPreparedFrame> *frames;
    bool operator()(NSUInteger left, NSUInteger right) const
    {
        CGRect leftFrame = (*frames)[left].frame;
        CGRect rightFrame = (*frames)[right].frame;
        if (CGRectGetMaxY(leftFrame) == CGRectGetMaxY(rightFrame))
            return left < right;
        return CGRectGetMaxY(leftFrame) < CGRectGetMaxY(rightFrame);
    }
};

@interface TGModernConversationPreparedLayout : NSObject
{
@public
    NSArray *_items;
    CGFloat _width;
    int _dateOffset;
    TGMessageRange _unreadMessageRange;
    CGFloat _contentHeight;
    std::vector<TGModernConversationPreparedFrame> _frames;
    std::vector<NSUInteger> _orderedIndices;
    std::vector<TGDecorationViewAttrubutes> _decorations;
}
@end

@implementation TGModernConversationPreparedLayout
@end

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
    TGModernConversationPreparedLayout *_preparedLayout;
    NSMutableDictionary *_preparedAttributes;
    NSMutableArray *_retiredAttributes;
    bool _preparedLayoutApplied;
}

@end

@implementation TGModernConversationViewLayout

static bool OGCompatIsConversationItemPath(NSIndexPath *indexPath)
{
    if (indexPath == nil || indexPath.length < 2)
        return false;
    return indexPath.section == 0 && indexPath.item != NSNotFound;
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
            if (OGCompatIsConversationItemPath(update.indexPathBeforeUpdate))
                [_deleteIndexPaths addObject:update.indexPathBeforeUpdate];
        }
        else if (update.updateAction == PSTCollectionUpdateActionInsert)
        {
            if (OGCompatIsConversationItemPath(update.indexPathAfterUpdate))
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
    if (!OGCompatIsConversationItemPath(itemIndexPath))
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
    if (!OGCompatIsConversationItemPath(itemIndexPath))
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
    return [self _layoutAttributesForItems:items containerWidth:containerWidth maxHeight:maxHeight dateOffset:dateOffset decorationViewAttributes:decorationViewAttributes contentHeight:contentHeight unreadMessageRange:unreadMessageRange viewStorage:viewStorage cachedGroupedLayouts:cachedGroupedLayouts inhibitDateHeaders:inhibitDateHeaders journal:NULL startIndex:0 convergence:NULL collectAttributes:true preparedLayout:nil];
}

+ (NSArray *)layoutAttributesForItems:(NSArray *)items containerWidth:(CGFloat)containerWidth maxHeight:(CGFloat)maxHeight dateOffset:(int)dateOffset decorationViewAttributes:(std::vector<TGDecorationViewAttrubutes> *)decorationViewAttributes contentHeight:(CGFloat *)contentHeight unreadMessageRange:(TGMessageRange)unreadMessageRange viewStorage:(TGModernViewStorage *)viewStorage cachedGroupedLayouts:(NSMutableDictionary *)cachedGroupedLayouts
{
    return [self _layoutAttributesForItems:items containerWidth:containerWidth maxHeight:maxHeight dateOffset:dateOffset decorationViewAttributes:decorationViewAttributes contentHeight:contentHeight unreadMessageRange:unreadMessageRange viewStorage:viewStorage cachedGroupedLayouts:cachedGroupedLayouts inhibitDateHeaders:false journal:NULL startIndex:0 convergence:NULL collectAttributes:true preparedLayout:nil];
}

+ (NSArray *)_layoutAttributesForItems:(NSArray *)items containerWidth:(CGFloat)containerWidth maxHeight:(CGFloat)maxHeight dateOffset:(int)dateOffset decorationViewAttributes:(std::vector<TGDecorationViewAttrubutes> *)decorationViewAttributes contentHeight:(CGFloat *)contentHeight unreadMessageRange:(TGMessageRange)unreadMessageRange viewStorage:(TGModernViewStorage *)viewStorage cachedGroupedLayouts:(NSMutableDictionary *)cachedGroupedLayouts inhibitDateHeaders:(bool)inhibitDateHeaders journal:(TGModernConversationLayoutJournal *)journal startIndex:(NSUInteger)startIndex convergence:(TGModernConversationLayoutConvergence *)convergence collectAttributes:(bool)collectAttributes preparedLayout:(TGModernConversationPreparedLayout *)preparedLayout
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
                    bool reusesCachedLayout = cachedGroupedLayout != nil && cachedGroupedLayout.count == groupedMessages.count && [cachedGroupedLayout positionForMessageId:messageItem->_message.mid] != 0;
                    TGMessageGroupedLayout *adoptedLayout = cachedGroupedLayout;
                    if (!reusesCachedLayout)
                    {
                        bool larger = !messageItem.isFeedItem && ((TGPeerIdIsUser(messageItem->_message.cid) || [messageItem.currentAuthorPeer isKindOfClass:[TGConversation class]]) && messageItem->_message.cid != TGTelegraphInstance.clientUserId);
                        adoptedLayout = [[TGMessageGroupedLayout alloc] initWithMessages:groupedMessages larger:larger];
                        if (adoptedLayout.count != groupedMessages.count)
                        {
                            adoptedLayout = nil;
                            [cachedGroupedLayouts removeObjectForKey:@(groupedId)];
                        }
                    }
                    
                    if (adoptedLayout != nil)
                    {
                        groupedLayout = adoptedLayout;
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
                    if (itemSize.height > groupHeight)
                        groupHeight = itemSize.height;
                    if (journal != NULL)
                    {
                        NSInteger primaryIndex = [indexes[@(primaryGroupItem->_message.mid)] integerValue];
                        if (primaryIndex >= 0 && primaryIndex < count)
                            journal->heights[(NSUInteger)primaryIndex] = itemSize.height;
                    }
                    groupedMediaOffsetX = [primaryGroupItem groupedMediaOffsetX];
                    groupedMediaOffsetY = [primaryGroupItem groupedMediaOffsetY];
                    groupedLayout.headerVisible = [primaryGroupItem groupedHeaderVisible];
                    groupedLayout.topCornersHidden = [primaryGroupItem groupedTopCornersHidden];
                }

                for (TGMessageModernConversationItem *groupItem in groupedMessageItems)
                {
                    if (groupItem == primaryGroupItem)
                        continue;

                    [groupItem setGroupedMediaOffsetX:groupedMediaOffsetX y:groupedMediaOffsetY];
                    groupItem.collapseFlags = groupCollapseFlags;
                    [groupItem updateGroupedLayout:groupedLayout];
                    itemSize = [groupItem sizeForContainerSize:CGSizeMake(containerWidth, 0.0f) viewStorage:viewStorage];
                    if (itemSize.height > groupHeight)
                        groupHeight = itemSize.height;
                    if (journal != NULL)
                    {
                        NSInteger groupItemIndex = [indexes[@(groupItem->_message.mid)] integerValue];
                        if (groupItemIndex >= 0 && groupItemIndex < count)
                            journal->heights[(NSUInteger)groupItemIndex] = itemSize.height;
                    }
                }

                if (preparedLayout != nil)
                {
                    for (TGMessageModernConversationItem *groupItem in groupedMessageItems)
                    {
                        NSInteger groupIndex = [indexes[@(groupItem->_message.mid)] integerValue];
                        TGMessageGroupPositionFlags position = [groupedLayout positionForMessageId:groupItem->_message.mid];
                        bool primary = (position & TGMessageGroupPositionTop) && (position & TGMessageGroupPositionLeft);
                        TGModernConversationPreparedFrame &frame = preparedLayout->_frames[(NSUInteger)groupIndex];
                        frame.frame = CGRectMake(0, currentHeight, containerWidth, groupHeight);
                        frame.zIndex = primary ? (NSIntegerMax - indexes.count - groupIndex) : (NSIntegerMax - groupIndex);
                        frame.valid = true;
                    }
                }
                if (collectAttributes)
                {
                    for (TGMessageModernConversationItem *groupItem in groupedMessageItems)
                    {
                        NSInteger groupIndex = [indexes[@(groupItem->_message.mid)] integerValue];
                        TGMessageGroupPositionFlags position = [groupedLayout positionForMessageId:groupItem->_message.mid];

                        PSUICollectionViewLayoutAttributes *attributes = [PSUICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:TGModernConversationLayoutIndexPath(groupIndex)];
                        attributes.frame = CGRectMake(0.0f, currentHeight, containerWidth, groupHeight);
                        int leadingCorner = TGMessageGroupPositionTop | TGMessageGroupPositionLeft;
                        NSInteger leadingLift = (position & leadingCorner) == leadingCorner ? (NSInteger)indexes.count : 0;
                        attributes.zIndex = NSIntegerMax - groupIndex - leadingLift;
                        [layoutAttributes addObject:attributes];
                    }
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
            if (preparedLayout != nil)
            {
                TGModernConversationPreparedFrame &frame = preparedLayout->_frames[(NSUInteger)index];
                frame.frame = CGRectMake(0, currentHeight, itemSize.width, itemSize.height);
                frame.zIndex = NSIntegerMax - index;
                frame.valid = true;
            }
            if (collectAttributes)
            {
                PSUICollectionViewLayoutAttributes *attributes = [PSUICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:TGModernConversationLayoutIndexPath(index)];
                attributes.frame = CGRectMake(0, currentHeight, itemSize.width, itemSize.height);
                attributes.zIndex = NSIntegerMax - index;
                [layoutAttributes addObject:attributes];
            }
        
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
    
    [self _layoutAttributesForItems:items containerWidth:containerWidth maxHeight:FLT_MAX dateOffset:dateOffset decorationViewAttributes:NULL contentHeight:NULL unreadMessageRange:unreadMessageRange viewStorage:nil cachedGroupedLayouts:nil inhibitDateHeaders:true journal:NULL startIndex:0 convergence:NULL collectAttributes:false preparedLayout:nil];
}

+ (TGModernConversationPreparedLayout *)preparedLayoutForItems:(NSArray *)items containerWidth:(CGFloat)containerWidth dateOffset:(int)dateOffset unreadMessageRange:(TGMessageRange)unreadMessageRange
{
    if (items.count == 0 || containerWidth <= FLT_EPSILON)
        return nil;

    TGModernConversationPreparedLayout *preparedLayout = [[TGModernConversationPreparedLayout alloc] init];
    preparedLayout->_items = [items copy];
    preparedLayout->_width = containerWidth;
    preparedLayout->_dateOffset = dateOffset;
    preparedLayout->_unreadMessageRange = unreadMessageRange;
    preparedLayout->_frames.resize(items.count);
    [self _layoutAttributesForItems:items containerWidth:containerWidth maxHeight:FLT_MAX dateOffset:dateOffset decorationViewAttributes:&preparedLayout->_decorations contentHeight:&preparedLayout->_contentHeight unreadMessageRange:unreadMessageRange viewStorage:nil cachedGroupedLayouts:nil inhibitDateHeaders:false journal:NULL startIndex:0 convergence:NULL collectAttributes:false preparedLayout:preparedLayout];
    for (NSUInteger index = 0; index < preparedLayout->_frames.size(); index++)
    {
        if (preparedLayout->_frames[index].valid)
            preparedLayout->_orderedIndices.push_back(index);
    }
    TGModernConversationPreparedFrameOrder order = {&preparedLayout->_frames};
    std::sort(preparedLayout->_orderedIndices.begin(), preparedLayout->_orderedIndices.end(), order);
    std::sort(preparedLayout->_decorations.begin(), preparedLayout->_decorations.end(), TGDecorationViewAttrubutesComparator());
    return preparedLayout;
}

- (bool)hasLayoutAttributes
{
    return _contentSize.height > FLT_EPSILON;
}

- (void)installPreparedLayout:(TGModernConversationPreparedLayout *)preparedLayout
{
    if (![NSThread isMainThread])
        return;

    [self _retainLayoutAttributesDuringCollectionUpdates];
    _preparedLayout = preparedLayout;
    _preparedAttributes = [[NSMutableDictionary alloc] init];
    _preparedLayoutApplied = false;
    _journalValid = false;
    _journalItems = nil;
    _journal.checkpoints.clear();
    _journal.heights.clear();
    _journalMessages.clear();
    [_layoutAttributes removeAllObjects];
    [_cachedGroupedLayouts removeAllObjects];
    _contentSize = CGSizeZero;
    _decorationViewAttributes.clear();
    [super invalidateLayout];
}

- (void)_retainLayoutAttributesDuringCollectionUpdates
{
    if (_layoutAttributes.count == 0 && _preparedAttributes.count == 0)
        return;

    NSMutableArray *retained = [[NSMutableArray alloc] initWithArray:_layoutAttributes];
    [retained addObjectsFromArray:[_preparedAttributes allValues]];
    if (_retiredAttributes == nil)
        _retiredAttributes = [[NSMutableArray alloc] init];
    [_retiredAttributes addObject:retained];
    __weak TGModernConversationViewLayout *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
    {
        __strong TGModernConversationViewLayout *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf->_retiredAttributes removeObjectIdenticalTo:retained];
    });
}

- (void)invalidateLayout
{
    if (_preparedLayoutApplied)
    {
        [self _retainLayoutAttributesDuringCollectionUpdates];
        _preparedLayout = nil;
        _preparedAttributes = nil;
        _preparedLayoutApplied = false;
    }
    [super invalidateLayout];
}

- (PSUICollectionViewLayoutAttributes *)_preparedAttributesAtIndex:(NSUInteger)index
{
    if (_preparedLayout == nil || index >= _preparedLayout->_frames.size())
        return nil;
    TGModernConversationPreparedFrame const &frame = _preparedLayout->_frames[index];
    if (!frame.valid)
        return nil;

    NSNumber *key = @(index);
    PSUICollectionViewLayoutAttributes *attributes = _preparedAttributes[key];
    if (attributes == nil)
    {
        attributes = [PSUICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:TGModernConversationLayoutIndexPath(index)];
        attributes.frame = frame.frame;
        attributes.zIndex = frame.zIndex;
        _preparedAttributes[key] = attributes;
    }
    return attributes;
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
    NSArray *prefixAttributes = [TGModernConversationViewLayout _layoutAttributesForItems:items containerWidth:containerWidth maxHeight:FLT_MAX dateOffset:_dateOffset decorationViewAttributes:&decorations contentHeight:&layoutHeight unreadMessageRange:unreadMessageRange viewStorage:_viewStorage cachedGroupedLayouts:_cachedGroupedLayouts inhibitDateHeaders:inhibitDateHeaders journal:&_journal startIndex:0 convergence:&convergence collectAttributes:true preparedLayout:nil];
    
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
    bool diagnostics = OGDiagnosticsEnabled();
    CFAbsoluteTime diagnosticStartTime = diagnostics ? CFAbsoluteTimeGetCurrent() : 0.0;
    double diagnosticStartThreadTime = diagnostics ? TGModernConversationLayoutThreadTime() : 0.0;
    NSArray *items = [(id<TGModernConversationViewLayoutDelegate>)self.collectionView.delegate items];
    CGFloat containerWidth = self.collectionView.bounds.size.width;
    TGMessageRange unreadMessageRange = ((TGModernConversationCollectionView *)self.collectionView).unreadMessageRange;
    bool inhibitDateHeaders = self.inhibitDateHeaders;
    bool retainedPreparedAttributes = false;

    if (_preparedLayout != nil)
    {
        BOOL matches = !_animateLayout && !inhibitDateHeaders && _preparedLayout->_items.count == items.count && ABS(_preparedLayout->_width - containerWidth) < FLT_EPSILON && _preparedLayout->_dateOffset == _dateOffset && TGMessageRangeEquals(_preparedLayout->_unreadMessageRange, unreadMessageRange) && _preparedLayout->_unreadMessageRange.firstPeerId == unreadMessageRange.firstPeerId && _preparedLayout->_unreadMessageRange.lastPeerId == unreadMessageRange.lastPeerId;
        if (matches)
        {
            for (NSUInteger index = 0; index < items.count; index++)
            {
                if (_preparedLayout->_items[index] != items[index])
                {
                    matches = false;
                    break;
                }
            }
        }
        if (matches)
        {
            _contentSize = CGSizeMake(containerWidth, _preparedLayout->_contentHeight);
            _decorationViewAttributes = _preparedLayout->_decorations;
            _preparedLayoutApplied = true;
            if (diagnostics)
            {
                CFAbsoluteTime duration = CFAbsoluteTimeGetCurrent() - diagnosticStartTime;
                OGDiagnosticsTimingRecordOnce("chat_first_layout", duration * 1000.0);
                if (duration >= 0.016)
                    OGPlatformDiagnosticLog(@"LAYOUTSLOW items=%d start=0 spliced=0 prepared=1 ms=%.0f main=%.0f", (int)items.count, duration * 1000.0, (TGModernConversationLayoutThreadTime() - diagnosticStartThreadTime) * 1000.0);
            }
            return;
        }
        [self _retainLayoutAttributesDuringCollectionUpdates];
        retainedPreparedAttributes = true;
        _preparedLayout = nil;
        _preparedAttributes = nil;
        _preparedLayoutApplied = false;
    }
    
    NSUInteger startIndex = [self _journalStartIndexForItems:items containerWidth:containerWidth unreadMessageRange:unreadMessageRange inhibitDateHeaders:inhibitDateHeaders];

    if (!retainedPreparedAttributes)
        [self _retainLayoutAttributesDuringCollectionUpdates];
    
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
        
        [_layoutAttributes addObjectsFromArray:[TGModernConversationViewLayout _layoutAttributesForItems:items containerWidth:containerWidth maxHeight:FLT_MAX dateOffset:_dateOffset decorationViewAttributes:&_decorationViewAttributes contentHeight:&contentHeight unreadMessageRange:unreadMessageRange viewStorage:_viewStorage cachedGroupedLayouts:_cachedGroupedLayouts inhibitDateHeaders:inhibitDateHeaders journal:&_journal startIndex:startIndex convergence:NULL collectAttributes:true preparedLayout:nil]];
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
    if (diagnostics)
    {
        CFAbsoluteTime diagnosticDuration = CFAbsoluteTimeGetCurrent() - diagnosticStartTime;
        if (items.count != 0)
            OGDiagnosticsTimingRecordOnce("chat_first_layout", diagnosticDuration * 1000.0);
        if (diagnosticDuration >= 0.016)
            OGPlatformDiagnosticLog(@"LAYOUTSLOW items=%d start=%d spliced=%d ms=%.0f main=%.0f", (int)items.count, (int)startIndex, spliced ? 1 : 0, diagnosticDuration * 1000.0, (TGModernConversationLayoutThreadTime() - diagnosticStartThreadTime) * 1000.0);
    }

}

- (CGSize)collectionViewContentSize
{
    return _contentSize;
}

- (NSUInteger)_firstAttributesIndexEndingAtOrBelowY:(CGFloat)minY
{
    if (_preparedLayout != nil)
    {
        NSUInteger low = 0;
        NSUInteger high = _preparedLayout->_orderedIndices.size();
        while (low < high)
        {
            NSUInteger middle = low + (high - low) / 2;
            CGRect frame = _preparedLayout->_frames[_preparedLayout->_orderedIndices[middle]].frame;
            if (CGRectGetMaxY(frame) < minY)
                low = middle + 1;
            else
                high = middle;
        }
        return low;
    }
    NSUInteger low = 0;
    NSUInteger high = _layoutAttributes.count;
    while (low < high)
    {
        NSUInteger mid = low + (high - low) / 2;
        PSUICollectionViewLayoutAttributes *attributes = _layoutAttributes[mid];
        if (CGRectGetMaxY(attributes.frame) < minY)
            low = mid + 1;
        else
            high = mid;
    }
    return low;
}

- (void)enumerateItemsInVerticalRangeOfRect:(CGRect)rect usingBlock:(void (^)(NSUInteger itemIndex, CGRect frame))block
{
    if (_preparedLayout != nil)
    {
        NSUInteger count = _preparedLayout->_orderedIndices.size();
        CGFloat maxY = CGRectGetMaxY(rect);
        for (NSUInteger index = [self _firstAttributesIndexEndingAtOrBelowY:CGRectGetMinY(rect)]; index < count; index++)
        {
            NSUInteger itemIndex = _preparedLayout->_orderedIndices[index];
            CGRect frame = _preparedLayout->_frames[itemIndex].frame;
            if (CGRectGetMinY(frame) <= maxY)
                block(itemIndex, frame);
        }
        return;
    }
    NSUInteger count = _layoutAttributes.count;
    CGFloat maxY = CGRectGetMaxY(rect);
    for (NSUInteger index = [self _firstAttributesIndexEndingAtOrBelowY:CGRectGetMinY(rect)]; index < count; index++)
    {
        PSUICollectionViewLayoutAttributes *attributes = _layoutAttributes[index];
        CGRect frame = attributes.frame;
        if (CGRectGetMinY(frame) > maxY)
            break;
        
        NSIndexPath *indexPath = attributes.indexPath;
        if (OGCompatIsConversationItemPath(indexPath))
            block((NSUInteger)indexPath.row, frame);
    }
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    if (_preparedLayout != nil)
    {
        NSMutableArray *attributes = [[NSMutableArray alloc] initWithCapacity:16];
        NSUInteger count = _preparedLayout->_orderedIndices.size();
        CGFloat maxY = CGRectGetMaxY(rect);
        for (NSUInteger index = [self _firstAttributesIndexEndingAtOrBelowY:CGRectGetMinY(rect)]; index < count; index++)
        {
            NSUInteger itemIndex = _preparedLayout->_orderedIndices[index];
            CGRect frame = _preparedLayout->_frames[itemIndex].frame;
            if (CGRectGetMinY(frame) > maxY)
                continue;
            if (CGRectIntersectsRect(rect, frame))
            {
                PSUICollectionViewLayoutAttributes *itemAttributes = [self _preparedAttributesAtIndex:itemIndex];
                if (itemAttributes != nil)
                    [attributes addObject:itemAttributes];
            }
        }
        return attributes;
    }
    NSUInteger count = _layoutAttributes.count;
    if (count == 0)
        return @[];

    CGFloat maxY = CGRectGetMaxY(rect);

    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:16];
    for (NSUInteger index = [self _firstAttributesIndexEndingAtOrBelowY:CGRectGetMinY(rect)]; index < count; index++)
    {
        PSUICollectionViewLayoutAttributes *attributes = _layoutAttributes[index];
        if (CGRectGetMinY(attributes.frame) > maxY)
            break;

        if (OGCompatIsConversationItemPath(attributes.indexPath) && CGRectIntersectsRect(rect, attributes.frame))
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
    if (_preparedLayout != nil)
    {
        if (index >= _preparedLayout->_frames.size() || !_preparedLayout->_frames[index].valid)
            return false;
        if (frame != NULL)
            *frame = _preparedLayout->_frames[index].frame;
        return true;
    }
    NSUInteger count = _layoutAttributes.count;
    if (index < count)
    {
        PSUICollectionViewLayoutAttributes *attributes = _layoutAttributes[index];
        NSIndexPath *indexPath = attributes.indexPath;
        if (OGCompatIsConversationItemPath(indexPath) && (NSUInteger)indexPath.row == index)
        {
            if (frame != NULL)
                *frame = attributes.frame;
            return true;
        }
    }
    
    for (PSUICollectionViewLayoutAttributes *attributes in _layoutAttributes)
    {
        NSIndexPath *indexPath = attributes.indexPath;
        if (OGCompatIsConversationItemPath(indexPath) && (NSUInteger)indexPath.row == index)
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
    if (_preparedLayout != nil)
    {
        if (!OGCompatIsConversationItemPath(indexPath))
            return nil;
        return [self _preparedAttributesAtIndex:(NSUInteger)indexPath.row];
    }
    if (!OGCompatIsConversationItemPath(indexPath) || indexPath.row >= (int)_layoutAttributes.count)
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
