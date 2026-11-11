#import <Foundation/Foundation.h>

#import "PSCoding.h"

@interface TGMessageEntity : NSObject <PSCoding, NSCoding>

@property (nonatomic, readonly) NSRange range;

- (instancetype)initWithRange:(NSRange)range;

@end

@interface TGMessageEntityUnderline : TGMessageEntity

@end

@interface TGMessageEntityStrikethrough : TGMessageEntity

@end

@interface TGMessageEntitySpoiler : TGMessageEntity

@end

@interface TGMessageEntityCustomEmoji : TGMessageEntity

@property (nonatomic, readonly) int64_t documentId;

- (instancetype)initWithRange:(NSRange)range documentId:(int64_t)documentId;

@end
