#import "TGRichMessageMediaAttachment.h"

#import "../submodules/LegacyComponents/LegacyComponents/NSInputStream+TL.h"

@implementation TGRichMessageMediaAttachment

- (instancetype)init
{
    return [self initWithRichMessage:nil];
}

- (instancetype)initWithRichMessage:(TGRichMessage *)richMessage
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGRichMessageMediaAttachmentType;
        _richMessage = richMessage;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    id richMessage = [aDecoder decodeObjectForKey:@"richMessage"];
    return [self initWithRichMessage:[richMessage isKindOfClass:[TGRichMessage class]] ? richMessage : nil];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (_richMessage != nil)
        [aCoder encodeObject:_richMessage forKey:@"richMessage"];
}

- (void)serialize:(NSMutableData *)data
{
    NSData *serializedData = [NSKeyedArchiver archivedDataWithRootObject:self];
    int32_t length = (int32_t)serializedData.length;
    [data appendBytes:&length length:4];
    [data appendData:serializedData];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int32_t length = [is readInt32];
    NSData *data = [is readData:length];
    @try
    {
        id attachment = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if ([attachment isKindOfClass:[TGRichMessageMediaAttachment class]] && ((TGRichMessageMediaAttachment *)attachment).richMessage != nil)
            return attachment;
    }
    @catch (__unused NSException *e)
    {
    }
    return nil;
}

@end
