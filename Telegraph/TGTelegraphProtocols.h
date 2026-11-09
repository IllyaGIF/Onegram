/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#ifndef Telegraph_TGTelegraphProtocols_h
#define Telegraph_TGTelegraphProtocols_h

#import "TL/TLMetaScheme.h"

@protocol TGRawHttpActor <NSObject>

- (void)httpRequestSuccess:(NSString *)url response:(NSData *)response;
- (void)httpRequestFailed:(NSString *)url;

@optional

- (void)httpRequestProgress:(NSString *)url progress:(float)progress;

@end

@protocol TGRawHttpFileActor <NSObject>

- (void)httpFileDownloadSuccess:(NSString *)url;
- (void)httpFileDownloadFailed:(NSString *)url;

@end

@protocol TGFileUploadActor <NSObject>

- (void)filePartUploadSuccess:(int)partId;
- (void)filePartUploadFailed:(int)partId;

@end

@protocol TGPeerSettingsActorProtocol <NSObject>

- (void)peerNotifySettingsRequestSuccess:(TLPeerNotifySettings *)settings;
- (void)peerNotifySettingsRequestFailed;

@end

@protocol TGContactDeleteActorProtocol <NSObject>

- (void)deleteContactsSuccess:(NSArray *)uids;
- (void)deleteContactsFailed:(NSArray *)uids;

@end

@protocol TGLocateContactsProtocol <NSObject>

- (void)locateSuccess:(TLcontacts_Located *)locatedContacts;
- (void)locateFailed;

@end

@protocol TGDeleteChatMemberProtocol <NSObject>

- (void)deleteMemberSuccess:(TLUpdates *)statedMessage;
- (void)deleteMemberFailed;

@end

#endif
