#ifndef TG_LEGACY_TL_TLMESSAGEMEDIA_H
#define TG_LEGACY_TL_TLMESSAGEMEDIA_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLGeoPoint;
@class TLWebPage;
@class TLGame;
@class TLWebDocument;
@class TLPhoto;
@class TLDocument;

@interface TLMessageMedia : NSObject <TLObject>


@end

@interface TLMessageMedia$messageMediaEmpty : TLMessageMedia


@end

@interface TLMessageMedia$messageMediaGeo : TLMessageMedia

@property (nonatomic, retain) TLGeoPoint *geo;

@end

@interface TLMessageMedia$messageMediaContact : TLMessageMedia

@property (nonatomic, retain) NSString *phone_number;
@property (nonatomic, retain) NSString *first_name;
@property (nonatomic, retain) NSString *last_name;
@property (nonatomic, retain) NSString *vcard;
@property (nonatomic) int32_t user_id;

@end

@interface TLMessageMedia$messageMediaUnsupported : TLMessageMedia


@end

@interface TLMessageMedia$messageMediaWebPage : TLMessageMedia

@property (nonatomic, retain) TLWebPage *webpage;

@end

@interface TLMessageMedia$messageMediaGame : TLMessageMedia

@property (nonatomic, retain) TLGame *game;

@end

@interface TLMessageMedia$messageMediaInvoiceMeta : TLMessageMedia

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *n_description;
@property (nonatomic, retain) TLWebDocument *photo;
@property (nonatomic) int32_t receipt_msg_id;
@property (nonatomic, retain) NSString *currency;
@property (nonatomic) int64_t total_amount;
@property (nonatomic, retain) NSString *start_param;

@end

@interface TLMessageMedia$messageMediaPhotoMeta : TLMessageMedia

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLPhoto *photo;
@property (nonatomic) int32_t ttl_seconds;

@end

@interface TLMessageMedia$messageMediaDocumentMeta : TLMessageMedia

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) TLDocument *document;
@property (nonatomic) int32_t ttl_seconds;

@end

@interface TLMessageMedia$messageMediaGeoLive : TLMessageMedia

@property (nonatomic, retain) TLGeoPoint *geo;
@property (nonatomic) int32_t period;

@end

@interface TLMessageMedia$messageMediaVenue : TLMessageMedia

@property (nonatomic, retain) TLGeoPoint *geo;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *address;
@property (nonatomic, retain) NSString *provider;
@property (nonatomic, retain) NSString *venue_id;
@property (nonatomic, retain) NSString *venue_type;

@end

@interface TLCodexPollAnswerValue : NSObject <TLObject>

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) NSData *option;
@property (nonatomic, retain) id media;
@property (nonatomic, retain) id addedBy;
@property (nonatomic) int32_t date;

@end

@interface TLCodexPollValue : NSObject <TLObject>

@property (nonatomic) int64_t pollId;
@property (nonatomic) int32_t flags;
@property (nonatomic, retain) NSString *question;
@property (nonatomic, retain) NSArray *answers;
@property (nonatomic) int32_t closePeriod;
@property (nonatomic) int32_t closeDate;
@property (nonatomic, retain) NSArray *countries;
@property (nonatomic) int64_t pollHash;

@end

@interface TLCodexPollAnswerVotersValue : NSObject <TLObject>

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) NSData *option;
@property (nonatomic) int32_t voters;
@property (nonatomic, retain) NSArray *recentVoters;

@end

@interface TLCodexPollResultsValue : NSObject <TLObject>

@property (nonatomic) int32_t flags;
@property (nonatomic, retain) NSArray *results;
@property (nonatomic) int32_t totalVoters;
@property (nonatomic, retain) NSArray *recentVoters;
@property (nonatomic, retain) NSString *solution;
@property (nonatomic, retain) NSArray *solutionEntities;
@property (nonatomic, retain) id solutionMedia;

@end

@interface TLMessageMedia$messageMediaPollCodex : TLMessageMedia

@property (nonatomic, retain) TLCodexPollValue *poll;
@property (nonatomic, retain) TLCodexPollResultsValue *results;

@end

#endif
