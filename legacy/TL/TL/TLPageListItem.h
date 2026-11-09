#ifndef TG_LEGACY_TL_TLPAGELISTITEM_H
#define TG_LEGACY_TL_TLPAGELISTITEM_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLRichText;

@interface TLPageListItem : NSObject <TLObject>


@end

@interface TLPageListItem$pageListItemText : TLPageListItem

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLRichText *text;

@end

@interface TLPageListItem$pageListItemBlocks : TLPageListItem

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) NSArray *blocks;

@end

#endif
