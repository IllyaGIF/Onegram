#ifndef TG_LEGACY_TL_TLPAGELISTORDEREDITEM_H
#define TG_LEGACY_TL_TLPAGELISTORDEREDITEM_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLRichText;

@interface TLPageListOrderedItem : NSObject <TLObject>


@end

@interface TLPageListOrderedItem$pageListOrderedItemText : TLPageListOrderedItem

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) NSString *num;
@property (nonatomic, retain) TLRichText *text;
@property (nonatomic) int32_t value;
@property (nonatomic, retain) NSString *n_type;

@end

@interface TLPageListOrderedItem$pageListOrderedItemBlocks : TLPageListOrderedItem

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) NSString *num;
@property (nonatomic, retain) NSArray *blocks;
@property (nonatomic) int32_t value;
@property (nonatomic, retain) NSString *n_type;

@end

#endif
