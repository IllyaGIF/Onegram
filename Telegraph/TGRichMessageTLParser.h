#import <Foundation/Foundation.h>

#import "TLObject.h"

@class TGRichMessage;

#ifdef __cplusplus
extern "C" {
#endif

TGRichMessage *TGRichMessageReadTL(NSInputStream *is, id<TLSerializationEnvironment> environment, NSArray **photos, NSArray **documents, NSError **error);

#ifdef __cplusplus
}
#endif
