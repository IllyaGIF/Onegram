#import "TGChannelBannedRights+Telegraph.h"

@implementation TGChannelBannedRights (TG)

- (instancetype)initWithTL:(TLChannelBannedRights *)tlRights {
    return [self initWithFlags:tlRights.flags timeout:tlRights.until_date];
}

- (TLChatBannedRights *)tlRights {
    TLChatBannedRights$chatBannedRights *rights = [[TLChatBannedRights$chatBannedRights alloc] init];
    rights.flags = [self tlFlags];
    rights.until_date = self.timeout;
    return rights;
}

@end
