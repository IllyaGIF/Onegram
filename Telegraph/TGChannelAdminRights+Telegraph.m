#import "TGChannelAdminRights+Telegraph.h"

@implementation TGChannelAdminRights (TL)

- (instancetype)initWithTL:(TLChannelAdminRights *)rights {
    return [self initWithFlags:rights.flags];
}

- (TLChatAdminRights *)tlRights {
    int32_t flags = [self tlFlags];
    if (flags & (1 << 6)) {
        flags = (flags & ~(1 << 6)) | (1 << 5);
    }
    TLChatAdminRights$chatAdminRights *result = [[TLChatAdminRights$chatAdminRights alloc] init];
    result.flags = flags;
    return result;
}

@end
