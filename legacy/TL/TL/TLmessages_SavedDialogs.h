#ifndef TG_LEGACY_TL_TLMESSAGES_SAVEDDIALOGS_H
#define TG_LEGACY_TL_TLMESSAGES_SAVEDDIALOGS_H

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"


@interface TLmessages_SavedDialogs : NSObject <TLObject>


@end

@interface TLmessages_SavedDialogs$messages_savedDialogs : TLmessages_SavedDialogs

@property (nonatomic, retain) NSArray *dialogs;
@property (nonatomic, retain) NSArray *messages;
@property (nonatomic, retain) NSArray *chats;
@property (nonatomic, retain) NSArray *users;

@end

@interface TLmessages_SavedDialogs$messages_savedDialogsSlice : TLmessages_SavedDialogs

@property (nonatomic) int32_t count;
@property (nonatomic, retain) NSArray *dialogs;
@property (nonatomic, retain) NSArray *messages;
@property (nonatomic, retain) NSArray *chats;
@property (nonatomic, retain) NSArray *users;

@end

@interface TLmessages_SavedDialogs$messages_savedDialogsNotModified : TLmessages_SavedDialogs

@property (nonatomic) int32_t count;

@end

#endif
