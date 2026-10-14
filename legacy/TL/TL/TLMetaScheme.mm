#import "TLMetaScheme.h"
#import "../TLMetaClassStore.h"

void TLRegisterClasses()
{
    TLMetaClassStore::registerObjectClass([TLPage$pagePart new]);
    TLMetaClassStore::registerObjectClass([TLPage$pageFull new]);
    TLMetaClassStore::registerObjectClass([TLNewSession$new_session_created new]);
    TLMetaClassStore::registerObjectClass([TLupdates_Difference$updates_differenceEmpty new]);
    TLMetaClassStore::registerObjectClass([TLupdates_Difference$updates_difference new]);
    TLMetaClassStore::registerObjectClass([TLupdates_Difference$updates_differenceSlice new]);
    TLMetaClassStore::registerObjectClass([TLupdates_Difference$updates_differenceTooLong new]);
    TLMetaClassStore::registerVectorClass([NSArray_Peer new]);
    TLMetaClassStore::registerVectorClass([NSArray_RichText new]);
    TLMetaClassStore::registerObjectClass([TLInputPhoto$inputPhotoEmpty new]);
    TLMetaClassStore::registerObjectClass([TLInputPhoto$inputPhoto new]);
    TLMetaClassStore::registerObjectClass([TLPeer$peerUser new]);
    TLMetaClassStore::registerObjectClass([TLPeer$peerChat new]);
    TLMetaClassStore::registerObjectClass([TLPeer$peerChannel new]);
    TLMetaClassStore::registerObjectClass([TLDialogPeer$dialogPeerFeed new]);
    TLMetaClassStore::registerObjectClass([TLDialogPeer$dialogPeer new]);
    TLMetaClassStore::registerObjectClass([TLDataJSON$dataJSON new]);
    TLMetaClassStore::registerVectorClass([NSArray_PrivacyRule new]);
    TLMetaClassStore::registerObjectClass([TLInputUser$inputUserEmpty new]);
    TLMetaClassStore::registerObjectClass([TLInputUser$inputUserSelf new]);
    TLMetaClassStore::registerObjectClass([TLInputUser$inputUser new]);
    TLMetaClassStore::registerObjectClass([TLHighScore$highScore new]);
    TLMetaClassStore::registerObjectClass([TLpayments_ValidatedRequestedInfo$payments_validatedRequestedInfoMeta new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageTypingAction new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageCancelAction new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageRecordVideoAction new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageRecordAudioAction new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageGeoLocationAction new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageChooseContactAction new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageUploadVideoAction new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageUploadAudioAction new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageUploadDocumentAction new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageUploadPhotoAction new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageGamePlayAction new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageGameStopAction new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageRecordRoundAction new]);
    TLMetaClassStore::registerObjectClass([TLSendMessageAction$sendMessageUploadRoundAction new]);
    TLMetaClassStore::registerObjectClass([TLmessages_FeaturedStickers$messages_featuredStickersNotModified new]);
    TLMetaClassStore::registerObjectClass([TLmessages_FeaturedStickers$messages_featuredStickers new]);
    TLMetaClassStore::registerVectorClass([NSArray_Document new]);
    TLMetaClassStore::registerObjectClass([TLPong$pong new]);
    TLMetaClassStore::registerObjectClass([TLInputFileLocation$inputFileLocation new]);
    TLMetaClassStore::registerObjectClass([TLInputFileLocation$inputEncryptedFileLocation new]);
    TLMetaClassStore::registerObjectClass([TLInputFileLocation$inputDocumentFileLocation new]);
    TLMetaClassStore::registerObjectClass([TLInputFileLocation$inputSecureFileLocation new]);
    TLMetaClassStore::registerVectorClass([NSArray_InputPrivacyRule new]);
    TLMetaClassStore::registerVectorClass([NSArray_CdnPublicKey new]);
    TLMetaClassStore::registerObjectClass([TLImportedContact$importedContact new]);
    TLMetaClassStore::registerObjectClass([TLPhoto$photoEmpty new]);
    TLMetaClassStore::registerObjectClass([TLPhoto$wallPhoto new]);
    TLMetaClassStore::registerObjectClass([TLPhoto$photo new]);
    TLMetaClassStore::registerObjectClass([TLDestroySessionsRes$destroy_sessions_res new]);
    TLMetaClassStore::registerObjectClass([TLBadMsgNotification$bad_msg_notification new]);
    TLMetaClassStore::registerObjectClass([TLBadMsgNotification$bad_server_salt new]);
    TLMetaClassStore::registerObjectClass([TLmessages_AffectedHistory$messages_affectedHistory new]);
    TLMetaClassStore::registerObjectClass([TLInputEncryptedChat$inputEncryptedChat new]);
    TLMetaClassStore::registerVectorClass([NSArray_TopPeer new]);
    TLMetaClassStore::registerObjectClass([TLInputPhoneCall$inputPhoneCall new]);
    TLMetaClassStore::registerObjectClass([TLMsgResendReq$msg_resend_req new]);
    TLMetaClassStore::registerObjectClass([TLInputWebFileLocation$inputWebFileLocation new]);
    TLMetaClassStore::registerObjectClass([TLInputWebDocument$inputWebDocument new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_Link$contacts_link new]);
    TLMetaClassStore::registerObjectClass([TLInputEncryptedFile$inputEncryptedFileEmpty new]);
    TLMetaClassStore::registerObjectClass([TLInputEncryptedFile$inputEncryptedFileUploaded new]);
    TLMetaClassStore::registerObjectClass([TLInputEncryptedFile$inputEncryptedFile new]);
    TLMetaClassStore::registerObjectClass([TLInputEncryptedFile$inputEncryptedFileBigUploaded new]);
    TLMetaClassStore::registerVectorClass([NSArray_LangPackString new]);
    TLMetaClassStore::registerObjectClass([TLpayments_PaymentForm$payments_paymentFormMeta new]);
    TLMetaClassStore::registerObjectClass([TLMsgsStateInfo$msgs_state_info new]);
    TLMetaClassStore::registerObjectClass([TLWallPaper$wallPaper new]);
    TLMetaClassStore::registerObjectClass([TLWallPaper$wallPaperSolid new]);
    TLMetaClassStore::registerVectorClass([NSArray_SchemeMethod new]);
    TLMetaClassStore::registerObjectClass([TLServer_DH_inner_data$server_DH_inner_data new]);
    TLMetaClassStore::registerObjectClass([TLProtoMessage$protoMessage new]);
    TLMetaClassStore::registerObjectClass([TLInputChatPhoto$inputChatPhotoEmpty new]);
    TLMetaClassStore::registerObjectClass([TLInputChatPhoto$inputChatUploadedPhoto new]);
    TLMetaClassStore::registerObjectClass([TLInputChatPhoto$inputChatPhoto new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateMessageID new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateRestoreMessages new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChatParticipants new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateUserStatus new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateContactRegistered new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateContactLocated new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateActivation new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updatePhoneCallRequested new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updatePhoneCallConfirmed new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updatePhoneCallDeclined new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateUserPhoto new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateNewEncryptedMessage new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateEncryptedChatTyping new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateEncryption new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateEncryptedMessagesRead new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChatParticipantDelete new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateDcOptions new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateUserBlocked new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateNotifySettings new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateUserTyping new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChatUserTyping new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateUserName new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updatePrivacy new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateUserPhone new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateNewMessage new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateDeleteMessages new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateReadHistoryInbox new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateReadHistoryOutbox new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateContactLink new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateReadMessagesContents new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChatParticipantAdd new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateWebPage new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChannel new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChannelGroup new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateNewChannelMessage new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateReadChannelInbox new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateDeleteChannelMessages new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChannelMessageViews new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChatAdmins new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChatParticipantAdmin new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateNewStickerSet new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateStickerSets new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateSavedGifs new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateEditChannelMessage new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChannelPinnedMessage new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChannelTooLongMeta new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateEditMessage new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateReadChannelOutbox new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateDraftMessage new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateReadFeaturedStickers new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateRecentStickers new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateConfig new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updatePtsChanged new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateStickerSetsOrder new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChannelWebPage new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateServiceNotificationMeta new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updatePhoneCall new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updatePhoneCallSignalingData new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateDialogPinned new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updatePinnedDialogsMeta new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateLangPackTooLong new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateLangPack new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateLangPackLanguageSuggested new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateFavedStickers new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChannelReadMessagesContents new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateContactsReset new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateChannelAvailableMessages new]);
    TLMetaClassStore::registerObjectClass([TLUpdate$updateDialogUnreadMark new]);
    TLMetaClassStore::registerObjectClass([TLBotInlineMessage$botInlineMessageMeta new]);
    TLMetaClassStore::registerObjectClass([TLmessages_FavedStickers$messages_favedStickersNotModified new]);
    TLMetaClassStore::registerObjectClass([TLmessages_FavedStickers$messages_favedStickers new]);
    TLMetaClassStore::registerObjectClass([TLFileLocation$fileLocationUnavailable new]);
    TLMetaClassStore::registerObjectClass([TLFileLocation$fileLocation new]);
    TLMetaClassStore::registerObjectClass([TLExportedChatInvite$chatInviteEmpty new]);
    TLMetaClassStore::registerObjectClass([TLExportedChatInvite$chatInviteExported new]);
    TLMetaClassStore::registerVectorClass([NSArray_InputPeer new]);
    TLMetaClassStore::registerObjectClass([TLDcNetworkStats$dcPingStats new]);
    TLMetaClassStore::registerObjectClass([TLRpcError$rpc_error new]);
    TLMetaClassStore::registerVectorClass([NSArray_Photo new]);
    TLMetaClassStore::registerObjectClass([TLMessage$messageEmpty new]);
    TLMetaClassStore::registerObjectClass([TLMessage$message new]);
    TLMetaClassStore::registerObjectClass([TLMessage$messageMeta new]);
    TLMetaClassStore::registerObjectClass([TLpayments_PaymentReceipt$payments_paymentReceiptMeta new]);
    TLMetaClassStore::registerObjectClass([TLChatParticipants$chatParticipants new]);
    TLMetaClassStore::registerObjectClass([TLInputNotifyPeer$inputNotifyPeer new]);
    TLMetaClassStore::registerObjectClass([TLInputNotifyPeer$inputNotifyUsers new]);
    TLMetaClassStore::registerObjectClass([TLInputNotifyPeer$inputNotifyChats new]);
    TLMetaClassStore::registerObjectClass([TLInputNotifyPeer$inputNotifyBroadcasts new]);
    TLMetaClassStore::registerObjectClass([TLClient_DH_Inner_Data$client_DH_inner_data new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_Blocked$contacts_blocked new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_Blocked$contacts_blockedSlice new]);
    TLMetaClassStore::registerObjectClass([TLProtoMessageCopy$msg_copy new]);
    TLMetaClassStore::registerVectorClass([NSArray_EncryptedMessage new]);
    TLMetaClassStore::registerObjectClass([TLGlobalPrivacySettings$globalPrivacySettings new]);
    TLMetaClassStore::registerObjectClass([TLmessages_DhConfig$messages_dhConfigNotModified new]);
    TLMetaClassStore::registerObjectClass([TLmessages_DhConfig$messages_dhConfig new]);
    TLMetaClassStore::registerObjectClass([TLChatInvite$chatInviteAlready new]);
    TLMetaClassStore::registerObjectClass([TLChatInvite$chatInviteMeta new]);
    TLMetaClassStore::registerObjectClass([TLMessageRange$messageRange new]);
    TLMetaClassStore::registerVectorClass([NSArray_PhoneConnection new]);
    TLMetaClassStore::registerObjectClass([TLInputBotInlineResult$inputBotInlineResultGame new]);
    TLMetaClassStore::registerVectorClass([NSArray_DcOption new]);
    TLMetaClassStore::registerObjectClass([TLmessages_AllStickers$messages_allStickersNotModified new]);
    TLMetaClassStore::registerObjectClass([TLmessages_AllStickers$messages_allStickers new]);
    TLMetaClassStore::registerObjectClass([TLDocument$documentEmpty new]);
    TLMetaClassStore::registerObjectClass([TLDocument$document new]);
    TLMetaClassStore::registerVectorClass([NSArray_ReceivedNotifyMessage new]);
    TLMetaClassStore::registerObjectClass([TLConfig$configMeta new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterEmpty new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterPhotos new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterVideo new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterPhotoVideo new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterDocument new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterPhotoVideoDocuments new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterUrl new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterVoice new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterMusic new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterChatPhotos new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterPhoneCalls new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterRoundVideo new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterRoundVoice new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterMyMentions new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterMyMentionsUnread new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterGeo new]);
    TLMetaClassStore::registerObjectClass([TLMessagesFilter$inputMessagesFilterContacts new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_Found$contacts_found new]);
    TLMetaClassStore::registerObjectClass([TLmessages_HighScores$messages_highScores new]);
    TLMetaClassStore::registerObjectClass([TLauth_Authorization$auth_authorizationMeta new]);
    TLMetaClassStore::registerObjectClass([TLReportReason$inputReportReasonSpam new]);
    TLMetaClassStore::registerObjectClass([TLReportReason$inputReportReasonViolence new]);
    TLMetaClassStore::registerObjectClass([TLReportReason$inputReportReasonPornography new]);
    TLMetaClassStore::registerObjectClass([TLReportReason$inputReportReasonOther new]);
    TLMetaClassStore::registerObjectClass([TLReportReason$inputReportReasonCopyright new]);
    TLMetaClassStore::registerObjectClass([TLmessages_StickerSet$messages_stickerSet new]);
    TLMetaClassStore::registerObjectClass([TLContactStatus$contactStatus new]);
    TLMetaClassStore::registerObjectClass([TLInputMedia$inputMediaEmpty new]);
    TLMetaClassStore::registerObjectClass([TLInputMedia$inputMediaGeoPoint new]);
    TLMetaClassStore::registerObjectClass([TLInputMedia$inputMediaContact new]);
    TLMetaClassStore::registerObjectClass([TLInputMedia$inputMediaPhotoMeta new]);
    TLMetaClassStore::registerObjectClass([TLInputMedia$inputMediaGifExternal new]);
    TLMetaClassStore::registerObjectClass([TLInputMedia$inputMediaDocumentMeta new]);
    TLMetaClassStore::registerObjectClass([TLInputMedia$inputMediaPhotoExternalMeta new]);
    TLMetaClassStore::registerObjectClass([TLInputMedia$inputMediaDocumentExternalMeta new]);
    TLMetaClassStore::registerObjectClass([TLInputMedia$inputMediaGame new]);
    TLMetaClassStore::registerObjectClass([TLInputMedia$inputMediaUploadedPhotoMeta new]);
    TLMetaClassStore::registerObjectClass([TLInputMedia$inputMediaUploadedDocumentMeta new]);
    TLMetaClassStore::registerObjectClass([TLInputMedia$inputMediaGeoLive new]);
    TLMetaClassStore::registerObjectClass([TLInputMedia$inputMediaVenue new]);
    TLMetaClassStore::registerObjectClass([TLRichText$textEmpty new]);
    TLMetaClassStore::registerObjectClass([TLRichText$textPlain new]);
    TLMetaClassStore::registerObjectClass([TLRichText$textBold new]);
    TLMetaClassStore::registerObjectClass([TLRichText$textItalic new]);
    TLMetaClassStore::registerObjectClass([TLRichText$textUnderline new]);
    TLMetaClassStore::registerObjectClass([TLRichText$textStrike new]);
    TLMetaClassStore::registerObjectClass([TLRichText$textFixed new]);
    TLMetaClassStore::registerObjectClass([TLRichText$textUrl new]);
    TLMetaClassStore::registerObjectClass([TLRichText$textEmail new]);
    TLMetaClassStore::registerObjectClass([TLRichText$textConcat new]);
    TLMetaClassStore::registerObjectClass([TLChannelBannedRights$channelBannedRights new]);
    TLMetaClassStore::registerVectorClass([NSArray_FoundGif new]);
    TLMetaClassStore::registerVectorClass([NSArray_StickerSet new]);
    TLMetaClassStore::registerObjectClass([TLShippingOption$shippingOption new]);
    TLMetaClassStore::registerObjectClass([TLReceivedNotifyMessage$receivedNotifyMessage new]);
    TLMetaClassStore::registerObjectClass([TLGame$gameMeta new]);
    TLMetaClassStore::registerObjectClass([TLUserFull$userFullMeta new]);
    TLMetaClassStore::registerObjectClass([TLmessages_SentEncryptedMessage$messages_sentEncryptedMessage new]);
    TLMetaClassStore::registerObjectClass([TLmessages_SentEncryptedMessage$messages_sentEncryptedFile new]);
    TLMetaClassStore::registerVectorClass([NSArray_ContactStatus new]);
    TLMetaClassStore::registerObjectClass([TLDialog$dialogMeta new]);
    TLMetaClassStore::registerObjectClass([TLDialog$dialogFeedMeta new]);
    TLMetaClassStore::registerObjectClass([TLauth_SentCodeType$auth_sentCodeTypeApp new]);
    TLMetaClassStore::registerObjectClass([TLauth_SentCodeType$auth_sentCodeTypeSms new]);
    TLMetaClassStore::registerObjectClass([TLauth_SentCodeType$auth_sentCodeTypeCall new]);
    TLMetaClassStore::registerObjectClass([TLauth_SentCodeType$auth_sentCodeTypeFlashCall new]);
    TLMetaClassStore::registerObjectClass([TLChat$chatEmpty new]);
    TLMetaClassStore::registerObjectClass([TLChat$chatForbidden new]);
    TLMetaClassStore::registerObjectClass([TLChat$channelMeta new]);
    TLMetaClassStore::registerObjectClass([TLChat$channelForbiddenMeta new]);
    TLMetaClassStore::registerObjectClass([TLContactRequest$contactRequest new]);
    TLMetaClassStore::registerObjectClass([TLFileHash$fileHash new]);
    TLMetaClassStore::registerObjectClass([TLInputSecureFile$inputSecureFileUploaded new]);
    TLMetaClassStore::registerObjectClass([TLInputSecureFile$inputSecureFile new]);
    TLMetaClassStore::registerObjectClass([TLSecureFile$secureFileEmpty new]);
    TLMetaClassStore::registerObjectClass([TLSecureFile$secureFile new]);
    TLMetaClassStore::registerObjectClass([TLSecureData$secureData new]);
    TLMetaClassStore::registerObjectClass([TLSecurePlainData$securePlainPhone new]);
    TLMetaClassStore::registerObjectClass([TLSecurePlainData$securePlainEmail new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueType$secureValueTypePersonalDetails new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueType$secureValueTypePassport new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueType$secureValueTypeDriverLicense new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueType$secureValueTypeIdentityCard new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueType$secureValueTypeInternalPassport new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueType$secureValueTypeAddress new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueType$secureValueTypeUtilityBill new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueType$secureValueTypeBankStatement new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueType$secureValueTypeRentalAgreement new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueType$secureValueTypePassportRegistration new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueType$secureValueTypeTemporaryRegistration new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueType$secureValueTypePhone new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueType$secureValueTypeEmail new]);
    TLMetaClassStore::registerObjectClass([TLSecureValue$secureValueMeta new]);
    TLMetaClassStore::registerObjectClass([TLInputSecureValue$inputSecureValueMeta new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueHash$secureValueHash new]);
    TLMetaClassStore::registerObjectClass([TLSecureCredentialsEncrypted$secureCredentialsEncrypted new]);
    TLMetaClassStore::registerObjectClass([TLaccount_AuthorizationForm$account_authorizationFormMeta new]);
    TLMetaClassStore::registerObjectClass([TLaccount_SentEmailCode$account_sentEmailCode new]);
    TLMetaClassStore::registerObjectClass([TLhelp_DeepLinkInfo$help_deepLinkInfoEmpty new]);
    TLMetaClassStore::registerObjectClass([TLhelp_DeepLinkInfo$help_deepLinkInfoMeta new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueError$secureValueErrorData new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueError$secureValueErrorFrontSide new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueError$secureValueErrorReverseSide new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueError$secureValueErrorSelfie new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueError$secureValueErrorFile new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueError$secureValueErrorFiles new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueError$secureValueError new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueError$secureValueErrorTranslationFile new]);
    TLMetaClassStore::registerObjectClass([TLSecureValueError$secureValueErrorTranslationFiles new]);
    TLMetaClassStore::registerVectorClass([NSArray_SecureValue new]);
    TLMetaClassStore::registerObjectClass([TLLangPackDifference$langPackDifference new]);
    TLMetaClassStore::registerVectorClass([NSArray_InputChannel new]);
    TLMetaClassStore::registerObjectClass([TLaccount_PrivacyRules$account_privacyRules new]);
    TLMetaClassStore::registerObjectClass([TLhelp_TermsOfService$help_termsOfServiceMeta new]);
    TLMetaClassStore::registerObjectClass([TLhelp_TermsOfServiceUpdate$help_termsOfServiceUpdateEmpty new]);
    TLMetaClassStore::registerObjectClass([TLhelp_TermsOfServiceUpdate$help_termsOfServiceUpdate new]);
    TLMetaClassStore::registerObjectClass([TLSet_client_DH_params_answer$dh_gen_ok new]);
    TLMetaClassStore::registerObjectClass([TLSet_client_DH_params_answer$dh_gen_retry new]);
    TLMetaClassStore::registerObjectClass([TLSet_client_DH_params_answer$dh_gen_fail new]);
    TLMetaClassStore::registerObjectClass([TLReplyMarkup$replyKeyboardHide new]);
    TLMetaClassStore::registerObjectClass([TLReplyMarkup$replyKeyboardForceReply new]);
    TLMetaClassStore::registerObjectClass([TLReplyMarkup$replyKeyboardMarkup new]);
    TLMetaClassStore::registerObjectClass([TLReplyMarkup$replyInlineMarkup new]);
    TLMetaClassStore::registerObjectClass([TLLangPackLanguage$langPackLanguage new]);
    TLMetaClassStore::registerObjectClass([TLMaskCoords$maskCoords new]);
    TLMetaClassStore::registerVectorClass([NSArray_BotCommand new]);
    TLMetaClassStore::registerObjectClass([TLmessages_MessageEditData$messages_messageEditData new]);
    TLMetaClassStore::registerVectorClass([NSArray_StickerPack new]);
    TLMetaClassStore::registerObjectClass([TLauth_SentCode$auth_sentCodeMeta new]);
    TLMetaClassStore::registerObjectClass([TLCdnPublicKey$cdnPublicKey new]);
    TLMetaClassStore::registerObjectClass([TLContactBlocked$contactBlocked new]);
    TLMetaClassStore::registerObjectClass([TLMessageFwdHeader$messageFwdHeaderMeta new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_MyLink$contacts_myLinkEmpty new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_MyLink$contacts_myLinkRequested new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_MyLink$contacts_myLinkContact new]);
    TLMetaClassStore::registerObjectClass([TLupdates_ChannelDifference$updates_channelDifferenceMeta new]);
    TLMetaClassStore::registerObjectClass([TLupdates_ChannelDifference$updates_channelDifferenceTooLongMeta new]);
    TLMetaClassStore::registerObjectClass([TLphone_DhConfig$phone_dhConfig new]);
    TLMetaClassStore::registerObjectClass([TLInputStickeredMedia$inputStickeredMediaPhoto new]);
    TLMetaClassStore::registerObjectClass([TLInputStickeredMedia$inputStickeredMediaDocument new]);
    TLMetaClassStore::registerObjectClass([TLaccount_TmpPassword$account_tmpPassword new]);
    TLMetaClassStore::registerVectorClass([NSArray_DcNetworkStats new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEvent$channelAdminLogEvent new]);
    TLMetaClassStore::registerObjectClass([TLphone_DiscardedCall$phone_discardedCall new]);
    TLMetaClassStore::registerObjectClass([TLphone_PhoneCall$phone_phoneCall new]);
    TLMetaClassStore::registerObjectClass([TLInputPrivacyKey$inputPrivacyKeyStatusTimestamp new]);
    TLMetaClassStore::registerObjectClass([TLInputPrivacyKey$inputPrivacyKeyChatInvite new]);
    TLMetaClassStore::registerObjectClass([TLInputPrivacyKey$inputPrivacyKeyPhoneCall new]);
    TLMetaClassStore::registerVectorClass([NSArray_Message new]);
    TLMetaClassStore::registerObjectClass([TLInputGeoPlaceName$inputGeoPlaceName new]);
    TLMetaClassStore::registerObjectClass([TLUserStatus$userStatusEmpty new]);
    TLMetaClassStore::registerObjectClass([TLUserStatus$userStatusOnline new]);
    TLMetaClassStore::registerObjectClass([TLUserStatus$userStatusOffline new]);
    TLMetaClassStore::registerObjectClass([TLUserStatus$userStatusRecently new]);
    TLMetaClassStore::registerObjectClass([TLUserStatus$userStatusLastWeek new]);
    TLMetaClassStore::registerObjectClass([TLUserStatus$userStatusLastMonth new]);
    TLMetaClassStore::registerVectorClass([NSArray_Dialog new]);
    TLMetaClassStore::registerObjectClass([TLChatLocated$chatLocated new]);
    TLMetaClassStore::registerObjectClass([TLPhoneCallProtocol$phoneCallProtocol new]);
    TLMetaClassStore::registerObjectClass([TLEncryptedChat$encryptedChatEmpty new]);
    TLMetaClassStore::registerObjectClass([TLEncryptedChat$encryptedChatWaiting new]);
    TLMetaClassStore::registerObjectClass([TLEncryptedChat$encryptedChatDiscarded new]);
    TLMetaClassStore::registerObjectClass([TLEncryptedChat$encryptedChatRequested new]);
    TLMetaClassStore::registerObjectClass([TLEncryptedChat$encryptedChat new]);
    TLMetaClassStore::registerVectorClass([NSArray_ImportedContact new]);
    TLMetaClassStore::registerObjectClass([TLInvokeWithLayer$invokeWithLayer new]);
    TLMetaClassStore::registerObjectClass([TLTopPeerCategoryPeers$topPeerCategoryPeers new]);
    TLMetaClassStore::registerVectorClass([NSArray_InputContact new]);
    TLMetaClassStore::registerObjectClass([TLDisabledFeature$disabledFeature new]);
    TLMetaClassStore::registerVectorClass([NSArray_Update new]);
    TLMetaClassStore::registerObjectClass([TLPaymentSavedCredentials$paymentSavedCredentialsCard new]);
    TLMetaClassStore::registerObjectClass([TLKeyboardButtonRow$keyboardButtonRow new]);
    TLMetaClassStore::registerObjectClass([TLmessages_BotCallbackAnswer$messages_botCallbackAnswerMeta new]);
    TLMetaClassStore::registerObjectClass([TLContactLink$contactLinkUnknown new]);
    TLMetaClassStore::registerObjectClass([TLContactLink$contactLinkNone new]);
    TLMetaClassStore::registerObjectClass([TLContactLink$contactLinkHasPhone new]);
    TLMetaClassStore::registerObjectClass([TLContactLink$contactLinkContact new]);
    TLMetaClassStore::registerObjectClass([TLInputPeer$inputPeerEmpty new]);
    TLMetaClassStore::registerObjectClass([TLInputPeer$inputPeerSelf new]);
    TLMetaClassStore::registerObjectClass([TLInputPeer$inputPeerChat new]);
    TLMetaClassStore::registerObjectClass([TLInputPeer$inputPeerUser new]);
    TLMetaClassStore::registerObjectClass([TLInputPeer$inputPeerChannel new]);
    TLMetaClassStore::registerObjectClass([TLDcOption$dcOption new]);
    TLMetaClassStore::registerVectorClass([NSArray_KeyboardButtonRow new]);
    TLMetaClassStore::registerObjectClass([TLmessages_Dialogs$messages_dialogs new]);
    TLMetaClassStore::registerObjectClass([TLmessages_Dialogs$messages_dialogsSlice new]);
    TLMetaClassStore::registerObjectClass([TLFeedPosition$feedPosition new]);
    TLMetaClassStore::registerObjectClass([TLmessages_FeedMessages$messages_feedMessagesNotModified new]);
    TLMetaClassStore::registerObjectClass([TLFeedBroadcasts$feedBroadcasts new]);
    TLMetaClassStore::registerObjectClass([TLFeedBroadcasts$feedBroadcastsUngrouped new]);
    TLMetaClassStore::registerObjectClass([TLchannels_FeedSources$channels_feedSourcesNotModified new]);
    TLMetaClassStore::registerObjectClass([TLFeedPosition$feedPosition new]);
    TLMetaClassStore::registerObjectClass([TLInputDialogPeer$inputDialogPeerFeed new]);
    TLMetaClassStore::registerObjectClass([TLInputDialogPeer$inputDialogPeer new]);
    TLMetaClassStore::registerVectorClass([NSArray_ContactRequest new]);
    TLMetaClassStore::registerObjectClass([TLSchemeMethod$schemeMethod new]);
    TLMetaClassStore::registerObjectClass([TLDocumentAttribute$documentAttributeImageSize new]);
    TLMetaClassStore::registerObjectClass([TLDocumentAttribute$documentAttributeAnimated new]);
    TLMetaClassStore::registerObjectClass([TLDocumentAttribute$documentAttributeFilename new]);
    TLMetaClassStore::registerObjectClass([TLDocumentAttribute$documentAttributeStickerMeta new]);
    TLMetaClassStore::registerObjectClass([TLDocumentAttribute$documentAttributeHasStickers new]);
    TLMetaClassStore::registerObjectClass([TLDocumentAttribute$documentAttributeVideo new]);
    TLMetaClassStore::registerObjectClass([TLchannels_ChannelParticipant$channels_channelParticipant new]);
    TLMetaClassStore::registerObjectClass([TLWebPage$webPageEmpty new]);
    TLMetaClassStore::registerObjectClass([TLWebPage$webPagePending new]);
    TLMetaClassStore::registerObjectClass([TLWebPage$webPage new]);
    TLMetaClassStore::registerObjectClass([TLWebPage$webPageNotModified new]);
    TLMetaClassStore::registerObjectClass([TLInputPeerNotifySettings$inputPeerNotifySettingsMeta new]);
    TLMetaClassStore::registerObjectClass([TLStickerSet$stickerSetMeta new]);
    TLMetaClassStore::registerObjectClass([TLGeoPlaceName$geoPlaceName new]);
    TLMetaClassStore::registerObjectClass([TLPeerSettings$peerSettings new]);
    TLMetaClassStore::registerVectorClass([NSArray_ShippingOption new]);
    TLMetaClassStore::registerObjectClass([TLauth_CheckedPhone$auth_checkedPhone new]);
    TLMetaClassStore::registerVectorClass([NSArray_Chat new]);
    TLMetaClassStore::registerObjectClass([TLInputDocument$inputDocumentEmpty new]);
    TLMetaClassStore::registerObjectClass([TLInputDocument$inputDocument new]);
    TLMetaClassStore::registerObjectClass([TLFoundGif$foundGif new]);
    TLMetaClassStore::registerObjectClass([TLFoundGif$foundGifCached new]);
    TLMetaClassStore::registerObjectClass([TLMsgsStateReq$msgs_state_req new]);
    TLMetaClassStore::registerObjectClass([TLLabeledPrice$labeledPrice new]);
    TLMetaClassStore::registerObjectClass([TLSchemeParam$schemeParam new]);
    TLMetaClassStore::registerObjectClass([TLTopPeerCategory$topPeerCategoryBotsPM new]);
    TLMetaClassStore::registerObjectClass([TLTopPeerCategory$topPeerCategoryBotsInline new]);
    TLMetaClassStore::registerObjectClass([TLTopPeerCategory$topPeerCategoryCorrespondents new]);
    TLMetaClassStore::registerObjectClass([TLTopPeerCategory$topPeerCategoryGroups new]);
    TLMetaClassStore::registerObjectClass([TLTopPeerCategory$topPeerCategoryChannels new]);
    TLMetaClassStore::registerObjectClass([TLPeerNotifySettings$peerNotifySettingsMeta new]);
    TLMetaClassStore::registerObjectClass([TLphotos_Photos$photos_photos new]);
    TLMetaClassStore::registerObjectClass([TLphotos_Photos$photos_photosSlice new]);
    TLMetaClassStore::registerVectorClass([NSArray_DocumentAttribute new]);
    TLMetaClassStore::registerObjectClass([TLGeoPoint$geoPointEmpty new]);
    TLMetaClassStore::registerObjectClass([TLGeoPoint$geoPoint new]);
    TLMetaClassStore::registerObjectClass([TLGeoPoint$geoPlace new]);
    TLMetaClassStore::registerVectorClass([NSArray_ContactBlocked new]);
    TLMetaClassStore::registerVectorClass([NSArray_PhotoSize new]);
    TLMetaClassStore::registerObjectClass([TLChatParticipant$chatParticipant new]);
    TLMetaClassStore::registerObjectClass([TLChatParticipant$chatParticipantCreator new]);
    TLMetaClassStore::registerObjectClass([TLChatParticipant$chatParticipantAdmin new]);
    TLMetaClassStore::registerObjectClass([TLPrivacyRule$privacyValueAllowContacts new]);
    TLMetaClassStore::registerObjectClass([TLPrivacyRule$privacyValueAllowAll new]);
    TLMetaClassStore::registerObjectClass([TLPrivacyRule$privacyValueAllowUsers new]);
    TLMetaClassStore::registerObjectClass([TLPrivacyRule$privacyValueDisallowContacts new]);
    TLMetaClassStore::registerObjectClass([TLPrivacyRule$privacyValueDisallowAll new]);
    TLMetaClassStore::registerObjectClass([TLPrivacyRule$privacyValueDisallowUsers new]);
    TLMetaClassStore::registerObjectClass([TLmessages_BotResults$messages_botResultsMeta new]);
    TLMetaClassStore::registerObjectClass([TLaccount_PasswordSettings$account_passwordSettingsMeta new]);
    TLMetaClassStore::registerObjectClass([TLScheme$scheme new]);
    TLMetaClassStore::registerObjectClass([TLScheme$schemeNotModified new]);
    TLMetaClassStore::registerVectorClass([NSArray_ChannelParticipant new]);
    TLMetaClassStore::registerVectorClass([NSArray_InputDocument new]);
    TLMetaClassStore::registerObjectClass([TLmessages_RecentStickers$messages_recentStickersNotModified new]);
    TLMetaClassStore::registerObjectClass([TLmessages_RecentStickers$messages_recentStickers new]);
    TLMetaClassStore::registerObjectClass([TLmessages_FoundStickerSets$messages_foundStickerSets new]);
    TLMetaClassStore::registerObjectClass([TLauth_ExportedAuthorization$auth_exportedAuthorization new]);
    TLMetaClassStore::registerVectorClass([NSArray_BotInfo new]);
    TLMetaClassStore::registerObjectClass([TLContact$contact new]);
    TLMetaClassStore::registerObjectClass([TLpayments_SavedInfo$payments_savedInfoMeta new]);
    TLMetaClassStore::registerObjectClass([TLBotInfo$botInfo new]);
    TLMetaClassStore::registerObjectClass([TLhelp_AppChangelog$help_appChangelogEmpty new]);
    TLMetaClassStore::registerObjectClass([TLhelp_AppChangelog$help_appChangelog new]);
    TLMetaClassStore::registerObjectClass([TLstorage_FileType$storage_fileUnknown new]);
    TLMetaClassStore::registerObjectClass([TLstorage_FileType$storage_fileJpeg new]);
    TLMetaClassStore::registerObjectClass([TLstorage_FileType$storage_fileGif new]);
    TLMetaClassStore::registerObjectClass([TLstorage_FileType$storage_filePng new]);
    TLMetaClassStore::registerObjectClass([TLstorage_FileType$storage_filePdf new]);
    TLMetaClassStore::registerObjectClass([TLstorage_FileType$storage_fileMp3 new]);
    TLMetaClassStore::registerObjectClass([TLstorage_FileType$storage_fileMov new]);
    TLMetaClassStore::registerObjectClass([TLstorage_FileType$storage_filePartial new]);
    TLMetaClassStore::registerObjectClass([TLstorage_FileType$storage_fileMp4 new]);
    TLMetaClassStore::registerObjectClass([TLstorage_FileType$storage_fileWebp new]);
    TLMetaClassStore::registerObjectClass([TLInvoice$invoiceMeta new]);
    TLMetaClassStore::registerObjectClass([TLBotCommand$botCommand new]);
    TLMetaClassStore::registerObjectClass([TLupdates_State$updates_state new]);
    TLMetaClassStore::registerObjectClass([TLInitConnection$initConnection new]);
    TLMetaClassStore::registerObjectClass([TLBotInlineResult$botInlineMediaResultMeta new]);
    TLMetaClassStore::registerObjectClass([TLContactSuggested$contactSuggested new]);
    TLMetaClassStore::registerObjectClass([TLmessages_SavedGifs$messages_savedGifsNotModified new]);
    TLMetaClassStore::registerObjectClass([TLmessages_SavedGifs$messages_savedGifs new]);
    TLMetaClassStore::registerObjectClass([TLupload_File$upload_file new]);
    TLMetaClassStore::registerObjectClass([TLupload_File$upload_fileCdnRedirect new]);
    TLMetaClassStore::registerObjectClass([TLmessages_Messages$messages_messages new]);
    TLMetaClassStore::registerObjectClass([TLmessages_Messages$messages_messagesSlice new]);
    TLMetaClassStore::registerObjectClass([TLmessages_Messages$messages_channelMessages new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_ImportedContacts$contacts_importedContacts new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_Located$contacts_located new]);
    TLMetaClassStore::registerObjectClass([TLchannels_AdminLogResults$channels_adminLogResults new]);
    TLMetaClassStore::registerObjectClass([TLChannelParticipantsFilter$channelParticipantsRecent new]);
    TLMetaClassStore::registerObjectClass([TLChannelParticipantsFilter$channelParticipantsAdmins new]);
    TLMetaClassStore::registerObjectClass([TLChannelParticipantsFilter$channelParticipantsBanned new]);
    TLMetaClassStore::registerObjectClass([TLChannelParticipantsFilter$channelParticipantsSearch new]);
    TLMetaClassStore::registerObjectClass([TLChannelParticipantsFilter$channelParticipantsKicked new]);
    TLMetaClassStore::registerVectorClass([NSArray_string new]);
    TLMetaClassStore::registerObjectClass([TLServer_DH_Params$server_DH_params_fail new]);
    TLMetaClassStore::registerObjectClass([TLServer_DH_Params$server_DH_params_ok new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_ForeignLink$contacts_foreignLinkUnknown new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_ForeignLink$contacts_foreignLinkRequested new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_ForeignLink$contacts_foreignLinkMutual new]);
    TLMetaClassStore::registerObjectClass([TLaccount_Password$account_passwordMeta new]);
    TLMetaClassStore::registerObjectClass([TLInputPaymentCredentials$inputPaymentCredentialsSaved new]);
    TLMetaClassStore::registerObjectClass([TLInputPaymentCredentials$inputPaymentCredentials new]);
    TLMetaClassStore::registerObjectClass([TLInputPaymentCredentials$inputPaymentCredentialsApplePay new]);
    TLMetaClassStore::registerObjectClass([TLP_Q_inner_data$p_q_inner_data new]);
    TLMetaClassStore::registerObjectClass([TLEncryptedFile$encryptedFileEmpty new]);
    TLMetaClassStore::registerObjectClass([TLEncryptedFile$encryptedFile new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionChangeTitle new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionChangeAbout new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionChangeUsername new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionChangePhoto new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionToggleInvites new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionToggleSignatures new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionUpdatePinned new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionEditMessage new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionDeleteMessage new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionParticipantJoin new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionParticipantLeave new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionParticipantInvite new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionParticipantToggleBan new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionParticipantToggleAdmin new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionChangeStickerSet new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventAction$channelAdminLogEventActionTogglePreHistoryHidden new]);
    TLMetaClassStore::registerObjectClass([TLUpdates$updatesTooLong new]);
    TLMetaClassStore::registerObjectClass([TLUpdates$updateShort new]);
    TLMetaClassStore::registerObjectClass([TLUpdates$updatesCombined new]);
    TLMetaClassStore::registerObjectClass([TLUpdates$updates new]);
    TLMetaClassStore::registerObjectClass([TLmessages_Stickers$messages_stickersNotModified new]);
    TLMetaClassStore::registerObjectClass([TLmessages_Stickers$messages_stickers new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_ResolvedPeer$contacts_resolvedPeer new]);
    TLMetaClassStore::registerObjectClass([TLMessageGroup$messageGroup new]);
    TLMetaClassStore::registerObjectClass([TLauth_PasswordRecovery$auth_passwordRecovery new]);
    TLMetaClassStore::registerObjectClass([TLInvokeAfterMsg$invokeAfterMsg new]);
    TLMetaClassStore::registerObjectClass([TLChatPhoto$chatPhotoEmpty new]);
    TLMetaClassStore::registerObjectClass([TLChatPhoto$chatPhoto new]);
    TLMetaClassStore::registerObjectClass([TLChatFull$chatFull new]);
    TLMetaClassStore::registerObjectClass([TLchannels_ChannelParticipants$channels_channelParticipants new]);
    TLMetaClassStore::registerObjectClass([TLchannels_ChannelParticipants$channels_channelParticipantsNotModified new]);
    TLMetaClassStore::registerVectorClass([NSArray_SchemeType new]);
    TLMetaClassStore::registerObjectClass([TLInputStickerSet$inputStickerSetEmpty new]);
    TLMetaClassStore::registerObjectClass([TLInputStickerSet$inputStickerSetID new]);
    TLMetaClassStore::registerObjectClass([TLInputStickerSet$inputStickerSetShortName new]);
    TLMetaClassStore::registerVectorClass([NSArray_User new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionEmpty new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChatCreate new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChatEditTitle new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChatEditPhoto new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChatDeletePhoto new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChatDeleteUser new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionSentRequest new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionAcceptRequest new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChatJoinedByLink new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChannelCreate new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChannelToggleComments new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChatMigrateTo new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChatDeactivate new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChatActivate new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChannelMigrateFrom new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChatAddUser new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionChatAddUserLegacy new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionPinMessage new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionHistoryClear new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionGameScore new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionPaymentSent new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionScreenshotTaken new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionCustomAction new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionBotAllowed new]);
    TLMetaClassStore::registerObjectClass([TLMessageAction$messageActionSecureValuesSent new]);
    TLMetaClassStore::registerObjectClass([TLEmbedPostMedia$embedPostPhoto new]);
    TLMetaClassStore::registerObjectClass([TLEmbedPostMedia$embedPostVideo new]);
    TLMetaClassStore::registerObjectClass([TLCdnConfig$cdnConfig new]);
    TLMetaClassStore::registerObjectClass([TLmessages_Message$messages_messageEmpty new]);
    TLMetaClassStore::registerObjectClass([TLmessages_Message$messages_message new]);
    TLMetaClassStore::registerObjectClass([TLRpcDropAnswer$rpc_answer_unknown new]);
    TLMetaClassStore::registerObjectClass([TLRpcDropAnswer$rpc_answer_dropped_running new]);
    TLMetaClassStore::registerObjectClass([TLRpcDropAnswer$rpc_answer_dropped new]);
    TLMetaClassStore::registerVectorClass([NSArray_LangPackLanguage new]);
    TLMetaClassStore::registerObjectClass([TLInputGame$inputGameID new]);
    TLMetaClassStore::registerObjectClass([TLInputGame$inputGameShortName new]);
    TLMetaClassStore::registerVectorClass([NSArray_ChannelAdminLogEvent new]);
    TLMetaClassStore::registerObjectClass([TLKeyboardButton$keyboardButton new]);
    TLMetaClassStore::registerObjectClass([TLKeyboardButton$keyboardButtonUrl new]);
    TLMetaClassStore::registerObjectClass([TLKeyboardButton$keyboardButtonCallback new]);
    TLMetaClassStore::registerObjectClass([TLKeyboardButton$keyboardButtonRequestPhone new]);
    TLMetaClassStore::registerObjectClass([TLKeyboardButton$keyboardButtonRequestGeoLocation new]);
    TLMetaClassStore::registerObjectClass([TLKeyboardButton$keyboardButtonSwitchInline new]);
    TLMetaClassStore::registerObjectClass([TLKeyboardButton$keyboardButtonGame new]);
    TLMetaClassStore::registerObjectClass([TLKeyboardButton$keyboardButtonBuy new]);
    TLMetaClassStore::registerObjectClass([TLUser$userEmpty new]);
    TLMetaClassStore::registerObjectClass([TLUser$user new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminRights$channelAdminRights new]);
    TLMetaClassStore::registerVectorClass([NSArray_Contact new]);
    TLMetaClassStore::registerObjectClass([TLLangPackString$langPackString new]);
    TLMetaClassStore::registerObjectClass([TLLangPackString$langPackStringPluralized new]);
    TLMetaClassStore::registerObjectClass([TLLangPackString$langPackStringDeleted new]);
    TLMetaClassStore::registerObjectClass([TLPhoneCallDiscardReason$phoneCallDiscardReasonMissed new]);
    TLMetaClassStore::registerObjectClass([TLPhoneCallDiscardReason$phoneCallDiscardReasonDisconnect new]);
    TLMetaClassStore::registerObjectClass([TLPhoneCallDiscardReason$phoneCallDiscardReasonHangup new]);
    TLMetaClassStore::registerObjectClass([TLPhoneCallDiscardReason$phoneCallDiscardReasonBusy new]);
    TLMetaClassStore::registerObjectClass([TLhelp_AppUpdate$help_appUpdateMeta new]);
    TLMetaClassStore::registerObjectClass([TLhelp_AppUpdate$help_noAppUpdate new]);
    TLMetaClassStore::registerObjectClass([TLmessages_ChatFull$messages_chatFull new]);
    TLMetaClassStore::registerVectorClass([NSArray_TopPeerCategoryPeers new]);
    TLMetaClassStore::registerObjectClass([TLInputPhotoCrop$inputPhotoCropAuto new]);
    TLMetaClassStore::registerObjectClass([TLInputPhotoCrop$inputPhotoCrop new]);
    TLMetaClassStore::registerObjectClass([TLupload_CdnFile$upload_cdnFileReuploadNeeded new]);
    TLMetaClassStore::registerObjectClass([TLupload_CdnFile$upload_cdnFile new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_SentLink$contacts_sentLink new]);
    TLMetaClassStore::registerObjectClass([TLaccount_PasswordInputSettings$account_passwordInputSettings new]);
    TLMetaClassStore::registerVectorClass([NSArray_PageBlock new]);
    TLMetaClassStore::registerObjectClass([TLaccount_Authorizations$account_authorizations new]);
    TLMetaClassStore::registerObjectClass([TLaccount_WebAuthorizations$account_webAuthorizations new]);
    TLMetaClassStore::registerObjectClass([TLEncryptedMessage$encryptedMessage new]);
    TLMetaClassStore::registerObjectClass([TLEncryptedMessage$encryptedMessageService new]);
    TLMetaClassStore::registerObjectClass([TLMsgsAllInfo$msgs_all_info new]);
    TLMetaClassStore::registerObjectClass([TLMsgDetailedInfo$msg_detailed_info new]);
    TLMetaClassStore::registerObjectClass([TLMsgDetailedInfo$msg_new_detailed_info new]);
    TLMetaClassStore::registerObjectClass([TLupload_WebFile$upload_webFile new]);
    TLMetaClassStore::registerVectorClass([NSArray_int new]);
    TLMetaClassStore::registerObjectClass([TLContactLocated$contactLocated new]);
    TLMetaClassStore::registerObjectClass([TLContactLocated$contactLocatedPreview new]);
    TLMetaClassStore::registerObjectClass([TLInputPrivacyRule$inputPrivacyValueAllowContacts new]);
    TLMetaClassStore::registerObjectClass([TLInputPrivacyRule$inputPrivacyValueAllowAll new]);
    TLMetaClassStore::registerObjectClass([TLInputPrivacyRule$inputPrivacyValueAllowUsers new]);
    TLMetaClassStore::registerObjectClass([TLInputPrivacyRule$inputPrivacyValueDisallowContacts new]);
    TLMetaClassStore::registerObjectClass([TLInputPrivacyRule$inputPrivacyValueDisallowAll new]);
    TLMetaClassStore::registerObjectClass([TLInputPrivacyRule$inputPrivacyValueDisallowUsers new]);
    TLMetaClassStore::registerObjectClass([TLmessages_AffectedMessages$messages_affectedMessages new]);
    TLMetaClassStore::registerVectorClass([NSArray_InputUser new]);
    TLMetaClassStore::registerObjectClass([TLNotifyPeer$notifyPeer new]);
    TLMetaClassStore::registerObjectClass([TLNotifyPeer$notifyUsers new]);
    TLMetaClassStore::registerObjectClass([TLNotifyPeer$notifyChats new]);
    TLMetaClassStore::registerObjectClass([TLNotifyPeer$notifyBroadcasts new]);
    TLMetaClassStore::registerObjectClass([TLChannelParticipant$channelParticipant new]);
    TLMetaClassStore::registerObjectClass([TLChannelParticipant$channelParticipantSelf new]);
    TLMetaClassStore::registerObjectClass([TLChannelParticipant$channelParticipantCreator new]);
    TLMetaClassStore::registerObjectClass([TLChannelParticipant$channelParticipantAdmin new]);
    TLMetaClassStore::registerObjectClass([TLChannelParticipant$channelParticipantBanned new]);
    TLMetaClassStore::registerObjectClass([TLPhoneCall$phoneCallEmpty new]);
    TLMetaClassStore::registerObjectClass([TLPhoneCall$phoneCallWaitingMeta new]);
    TLMetaClassStore::registerObjectClass([TLPhoneCall$phoneCallRequested new]);
    TLMetaClassStore::registerObjectClass([TLPhoneCall$phoneCallDiscardedMeta new]);
    TLMetaClassStore::registerObjectClass([TLPhoneCall$phoneCallAccepted new]);
    TLMetaClassStore::registerObjectClass([TLPhoneCall$phoneCall new]);
    TLMetaClassStore::registerVectorClass([NSArray_HighScore new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityUnknown new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityMention new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityHashtag new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityBotCommand new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityUrl new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityEmail new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityBold new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityItalic new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityCode new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityPre new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityTextUrl new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityMentionName new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$inputMessageEntityMentionName new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityPhone new]);
    TLMetaClassStore::registerObjectClass([TLMessageEntity$messageEntityCashtag new]);
    TLMetaClassStore::registerObjectClass([TLInputChannel$inputChannelEmpty new]);
    TLMetaClassStore::registerObjectClass([TLInputChannel$inputChannel new]);
    TLMetaClassStore::registerObjectClass([TLInputGeoPoint$inputGeoPointEmpty new]);
    TLMetaClassStore::registerObjectClass([TLInputGeoPoint$inputGeoPoint new]);
    TLMetaClassStore::registerObjectClass([TLmessages_Chat$messages_chat new]);
    TLMetaClassStore::registerObjectClass([TLPhotoSize$photoSizeEmpty new]);
    TLMetaClassStore::registerObjectClass([TLPhotoSize$photoSize new]);
    TLMetaClassStore::registerObjectClass([TLPhotoSize$photoCachedSize new]);
    TLMetaClassStore::registerObjectClass([TLmessages_ArchivedStickers$messages_archivedStickers new]);
    TLMetaClassStore::registerVectorClass([NSArray_FileHash new]);
    TLMetaClassStore::registerObjectClass([TLPopularContact$popularContact new]);
    TLMetaClassStore::registerObjectClass([TLAccountDaysTTL$accountDaysTTL new]);
    TLMetaClassStore::registerVectorClass([NSArray_long new]);
    TLMetaClassStore::registerObjectClass([TLHttpWait$http_wait new]);
    TLMetaClassStore::registerObjectClass([TLInputFile$inputFile new]);
    TLMetaClassStore::registerObjectClass([TLInputFile$inputFileBig new]);
    TLMetaClassStore::registerObjectClass([TLSchemeType$schemeType new]);
    TLMetaClassStore::registerObjectClass([TLPaymentRequestedInfo$paymentRequestedInfoMeta new]);
    TLMetaClassStore::registerObjectClass([TLDestroySessionRes$destroy_session_ok new]);
    TLMetaClassStore::registerObjectClass([TLDestroySessionRes$destroy_session_none new]);
    TLMetaClassStore::registerVectorClass([NSArray_KeyboardButton new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_Requests$contacts_requests new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_Requests$contacts_requestsSlice new]);
    TLMetaClassStore::registerObjectClass([TLChannelAdminLogEventsFilter$channelAdminLogEventsFilter new]);
    TLMetaClassStore::registerObjectClass([TLInlineBotSwitchPM$inlineBotSwitchPM new]);
    TLMetaClassStore::registerObjectClass([TLInputBotInlineMessage$inputBotInlineMessageGame new]);
    TLMetaClassStore::registerObjectClass([TLUserProfilePhoto$userProfilePhotoEmpty new]);
    TLMetaClassStore::registerObjectClass([TLUserProfilePhoto$userProfilePhoto new]);
    TLMetaClassStore::registerObjectClass([TLhelp_InviteText$help_inviteText new]);
    TLMetaClassStore::registerVectorClass([NSArray_ContactSuggested new]);
    TLMetaClassStore::registerObjectClass([TLmessages_StickerSetInstallResult$messages_stickerSetInstallResultSuccess new]);
    TLMetaClassStore::registerObjectClass([TLmessages_StickerSetInstallResult$messages_stickerSetInstallResultArchive new]);
    TLMetaClassStore::registerObjectClass([TLError$error new]);
    TLMetaClassStore::registerObjectClass([TLError$richError new]);
    TLMetaClassStore::registerObjectClass([TLExportedMessageLink$exportedMessageLink new]);
    TLMetaClassStore::registerObjectClass([TLPhoneConnection$phoneConnectionNotReady new]);
    TLMetaClassStore::registerObjectClass([TLPhoneConnection$phoneConnection new]);
    TLMetaClassStore::registerObjectClass([TLNearestDc$nearestDc new]);
    TLMetaClassStore::registerVectorClass([NSArray_InputPhoto new]);
    TLMetaClassStore::registerObjectClass([TLphotos_Photo$photos_photo new]);
    TLMetaClassStore::registerObjectClass([TLMsgsAck$msgs_ack new]);
    TLMetaClassStore::registerVectorClass([NSArray_WallPaper new]);
    TLMetaClassStore::registerVectorClass([NSArray_MessageEntity new]);
    TLMetaClassStore::registerObjectClass([TLhelp_AppPrefs$help_appPrefs new]);
    TLMetaClassStore::registerObjectClass([TLStickerPack$stickerPack new]);
    TLMetaClassStore::registerVectorClass([NSArray_ContactLocated new]);
    TLMetaClassStore::registerObjectClass([TLResPQ$resPQ new]);
    TLMetaClassStore::registerObjectClass([TLDraftMessage$draftMessageEmptyMeta new]);
    TLMetaClassStore::registerObjectClass([TLDraftMessage$draftMessageMeta new]);
    TLMetaClassStore::registerObjectClass([TLStickerSetCovered$stickerSetCovered new]);
    TLMetaClassStore::registerObjectClass([TLStickerSetCovered$stickerSetMultiCovered new]);
    TLMetaClassStore::registerObjectClass([TLChannelMessagesFilter$channelMessagesFilterEmpty new]);
    TLMetaClassStore::registerObjectClass([TLChannelMessagesFilter$channelMessagesFilter new]);
    TLMetaClassStore::registerObjectClass([TLChannelMessagesFilter$channelMessagesFilterCollapsed new]);
    TLMetaClassStore::registerVectorClass([NSArray_BotInlineResult new]);
    TLMetaClassStore::registerVectorClass([NSArray_DestroySessionRes new]);
    TLMetaClassStore::registerVectorClass([NSArray_ChatParticipant new]);
    TLMetaClassStore::registerObjectClass([TLmessages_FoundGifs$messages_foundGifs new]);
    TLMetaClassStore::registerObjectClass([TLAuthorization$authorization new]);
    TLMetaClassStore::registerObjectClass([TLWebAuthorization$webAuthorization new]);
    TLMetaClassStore::registerVectorClass([NSArray_MessageRange new]);
    TLMetaClassStore::registerObjectClass([TLMessageMedia$messageMediaEmpty new]);
    TLMetaClassStore::registerObjectClass([TLMessageMedia$messageMediaGeo new]);
    TLMetaClassStore::registerObjectClass([TLMessageMedia$messageMediaContact new]);
    TLMetaClassStore::registerObjectClass([TLMessageMedia$messageMediaUnsupported new]);
    TLMetaClassStore::registerObjectClass([TLMessageMedia$messageMediaWebPage new]);
    TLMetaClassStore::registerObjectClass([TLMessageMedia$messageMediaGame new]);
    TLMetaClassStore::registerObjectClass([TLMessageMedia$messageMediaInvoiceMeta new]);
    TLMetaClassStore::registerObjectClass([TLMessageMedia$messageMediaPhotoMeta new]);
    TLMetaClassStore::registerObjectClass([TLMessageMedia$messageMediaDocumentMeta new]);
    TLMetaClassStore::registerObjectClass([TLMessageMedia$messageMediaGeoLive new]);
    TLMetaClassStore::registerObjectClass([TLMessageMedia$messageMediaVenue new]);
    TLMetaClassStore::registerObjectClass([TLWebDocument$webDocument new]);
    TLMetaClassStore::registerObjectClass([TLWebDocument$webDocumentNoProxy new]);
    TLMetaClassStore::registerObjectClass([TLhelp_Support$help_support new]);
    TLMetaClassStore::registerObjectClass([TLTopPeer$topPeer new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_TopPeers$contacts_topPeersNotModified new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_TopPeers$contacts_topPeers new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_TopPeers$contacts_topPeersDisabled new]);
    TLMetaClassStore::registerObjectClass([TLPostAddress$postAddress new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_Suggested$contacts_suggested new]);
    TLMetaClassStore::registerObjectClass([TLInputContact$inputPhoneContact new]);
    TLMetaClassStore::registerObjectClass([TLauth_CodeType$auth_codeTypeSms new]);
    TLMetaClassStore::registerObjectClass([TLauth_CodeType$auth_codeTypeCall new]);
    TLMetaClassStore::registerObjectClass([TLauth_CodeType$auth_codeTypeFlashCall new]);
    TLMetaClassStore::registerObjectClass([TLmessages_Chats$messages_chats new]);
    TLMetaClassStore::registerObjectClass([TLmessages_Chats$messages_chatsSlice new]);
    TLMetaClassStore::registerObjectClass([TLFutureSalt$futureSalt new]);
    TLMetaClassStore::registerVectorClass([NSArray_SchemeParam new]);
    TLMetaClassStore::registerObjectClass([TLmessages_PeerDialogs$messages_peerDialogs new]);
    TLMetaClassStore::registerVectorClass([NSArray_Authorization new]);
    TLMetaClassStore::registerVectorClass([NSArray_PopularContact new]);
    TLMetaClassStore::registerObjectClass([TLpayments_PaymentResult$payments_paymentResult new]);
    TLMetaClassStore::registerObjectClass([TLpayments_PaymentResult$payments_paymentVerficationNeeded new]);
    TLMetaClassStore::registerVectorClass([NSArray_LabeledPrice new]);
    TLMetaClassStore::registerVectorClass([NSArray_StickerSetCovered new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockTitle new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockSubtitle new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockHeader new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockSubheader new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockParagraph new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockPreformatted new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockFooter new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockDivider new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockList new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockBlockquote new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockPullquote new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockPhoto new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockVideo new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockCover new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockEmbedPost new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockCollage new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockSlideshow new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockUnsupported new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockAnchor new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockEmbedMeta new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockAuthorDate new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockChannel new]);
    TLMetaClassStore::registerObjectClass([TLPageBlock$pageBlockAudio new]);
    TLMetaClassStore::registerObjectClass([TLResponseIndirect$responseIndirect new]);
    TLMetaClassStore::registerObjectClass([TLPrivacyKey$privacyKeyStatusTimestamp new]);
    TLMetaClassStore::registerObjectClass([TLPrivacyKey$privacyKeyChatInvite new]);
    TLMetaClassStore::registerObjectClass([TLPrivacyKey$privacyKeyPhoneCall new]);
    TLMetaClassStore::registerObjectClass([TLPasswordKdfAlgo$passwordKdfAlgoUnknown new]);
    TLMetaClassStore::registerObjectClass([TLPasswordKdfAlgo$passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow new]);
    TLMetaClassStore::registerObjectClass([TLSecurePasswordKdfAlgo$securePasswordKdfAlgoUnknown new]);
    TLMetaClassStore::registerObjectClass([TLSecurePasswordKdfAlgo$securePasswordKdfAlgoPBKDF2HMACSHA512iter100000 new]);
    TLMetaClassStore::registerObjectClass([TLSecurePasswordKdfAlgo$securePasswordKdfAlgoSHA512 new]);
    TLMetaClassStore::registerObjectClass([TLSecureSecretSettings$secureSecretSettings new]);
    TLMetaClassStore::registerObjectClass([TLSecureRequiredType$secureRequiredType new]);
    TLMetaClassStore::registerObjectClass([TLSecureRequiredType$secureRequiredTypeOneOf new]);
    TLMetaClassStore::registerObjectClass([TLInputCheckPasswordSRP$inputCheckPasswordSRP new]);
    TLMetaClassStore::registerObjectClass([TLInputCheckPasswordSRP$inputCheckPasswordEmpty new]);
    TLMetaClassStore::registerObjectClass([TLhelp_PassportConfig$help_passportConfigNotModified new]);
    TLMetaClassStore::registerObjectClass([TLhelp_PassportConfig$help_passportConfig new]);
    TLMetaClassStore::registerVectorClass([NSArray_DisabledFeature new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_Contacts$contacts_contactsNotModified new]);
    TLMetaClassStore::registerObjectClass([TLcontacts_Contacts$contacts_contacts new]);
    TLMetaClassStore::registerObjectClass([TLRPCreq_pq$req_pq new]);
    TLMetaClassStore::registerObjectClass([TLRPCreq_DH_params$req_DH_params new]);
    TLMetaClassStore::registerObjectClass([TLRPCset_client_DH_params$set_client_DH_params new]);
    TLMetaClassStore::registerObjectClass([TLRPCping$ping new]);
    TLMetaClassStore::registerObjectClass([TLRPCping_delay_disconnect$ping_delay_disconnect new]);
    TLMetaClassStore::registerObjectClass([TLRPCdestroy_session$destroy_session new]);
    TLMetaClassStore::registerObjectClass([TLRPCdestroy_sessions$destroy_sessions new]);
    TLMetaClassStore::registerObjectClass([TLRPCget_future_salts$get_future_salts new]);
    TLMetaClassStore::registerObjectClass([TLRPCrpc_drop_answer$rpc_drop_answer new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_checkPhone$auth_checkPhone new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_signUp$auth_signUp new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_signIn$auth_signIn new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_logOut$auth_logOut new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_resetAuthorizations$auth_resetAuthorizations new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_sendInvites$auth_sendInvites new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_exportAuthorization$auth_exportAuthorization new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_importAuthorization$auth_importAuthorization new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_unregisterDevice$account_unregisterDevice new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_updateNotifySettings$account_updateNotifySettings new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_getNotifySettings$account_getNotifySettings new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_resetNotifySettings$account_resetNotifySettings new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_updateStatus$account_updateStatus new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_getWallPapers$account_getWallPapers new]);
    TLMetaClassStore::registerObjectClass([TLRPCusers_getUsers$users_getUsers new]);
    TLMetaClassStore::registerObjectClass([TLRPCusers_getFullUser$users_getFullUser new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_getContactIDs$contacts_getContactIDs new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_getStatuses$contacts_getStatuses new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_getRequests$contacts_getRequests new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_getLink$contacts_getLink new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_getLocated$contacts_getLocated new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_getSuggested$contacts_getSuggested new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_sendRequest$contacts_sendRequest new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_acceptRequest$contacts_acceptRequest new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_declineRequest$contacts_declineRequest new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_deleteContact$contacts_deleteContact new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_clearContact$contacts_clearContact new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_deleteContacts$contacts_deleteContacts new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_block$contacts_block new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_unblock$contacts_unblock new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_getBlocked$contacts_getBlocked new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getMessages$messages_getMessages new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_restoreMessages$messages_restoreMessages new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getChats$messages_getChats new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getFullChat$messages_getFullChat new]);
    TLMetaClassStore::registerObjectClass([TLRPCphone_getDhConfig$phone_getDhConfig new]);
    TLMetaClassStore::registerObjectClass([TLRPCphone_declineCall$phone_declineCall new]);
    TLMetaClassStore::registerObjectClass([TLRPCupdates_getState$updates_getState new]);
    TLMetaClassStore::registerObjectClass([TLRPCupdates_subscribe$updates_subscribe new]);
    TLMetaClassStore::registerObjectClass([TLRPCupdates_unsubscribe$updates_unsubscribe new]);
    TLMetaClassStore::registerObjectClass([TLRPCphotos_getPhotos$photos_getPhotos new]);
    TLMetaClassStore::registerObjectClass([TLRPCphotos_getWall$photos_getWall new]);
    TLMetaClassStore::registerObjectClass([TLRPCphotos_readWall$photos_readWall new]);
    TLMetaClassStore::registerObjectClass([TLRPCphotos_editPhoto$photos_editPhoto new]);
    TLMetaClassStore::registerObjectClass([TLRPCphotos_updateProfilePhoto$photos_updateProfilePhoto new]);
    TLMetaClassStore::registerObjectClass([TLRPCphotos_uploadPhoto$photos_uploadPhoto new]);
    TLMetaClassStore::registerObjectClass([TLRPCphotos_uploadProfilePhoto$photos_uploadProfilePhoto new]);
    TLMetaClassStore::registerObjectClass([TLRPCphotos_deletePhotos$photos_deletePhotos new]);
    TLMetaClassStore::registerObjectClass([TLRPCphotos_restorePhotos$photos_restorePhotos new]);
    TLMetaClassStore::registerObjectClass([TLRPCupload_saveFilePart$upload_saveFilePart new]);
    TLMetaClassStore::registerObjectClass([TLRPCupload_getFile$upload_getFile new]);
    TLMetaClassStore::registerObjectClass([TLRPCgeo_saveGeoPlace$geo_saveGeoPlace new]);
    TLMetaClassStore::registerObjectClass([TLRPChelp_getConfig$help_getConfig new]);
    TLMetaClassStore::registerObjectClass([TLRPChelp_getNearestDc$help_getNearestDc new]);
    TLMetaClassStore::registerObjectClass([TLRPChelp_getScheme$help_getScheme new]);
    TLMetaClassStore::registerObjectClass([TLRPChelp_getAppUpdate$help_getAppUpdate new]);
    TLMetaClassStore::registerObjectClass([TLRPChelp_getInviteText$help_getInviteText new]);
    TLMetaClassStore::registerObjectClass([TLRPChelp_getAppPrefs$help_getAppPrefs new]);
    TLMetaClassStore::registerObjectClass([TLRPChelp_saveNetworkStats$help_saveNetworkStats new]);
    TLMetaClassStore::registerObjectClass([TLRPChelp_test$help_test new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontest_saveDeveloperInfo$contest_saveDeveloperInfo new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_registerDevice$account_registerDevice new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getDhConfig$messages_getDhConfig new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_requestEncryption$messages_requestEncryption new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_acceptEncryption$messages_acceptEncryption new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_discardEncryption$messages_discardEncryption new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_setEncryptedTyping$messages_setEncryptedTyping new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_readEncryptedHistory$messages_readEncryptedHistory new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_sendEncrypted$messages_sendEncrypted new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_sendEncryptedFile$messages_sendEncryptedFile new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_sendEncryptedService$messages_sendEncryptedService new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_receivedQueue$messages_receivedQueue new]);
    TLMetaClassStore::registerObjectClass([TLRPCupload_saveBigFilePart$upload_saveBigFilePart new]);
    TLMetaClassStore::registerObjectClass([TLRPChelp_getSupport$help_getSupport new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_setTyping$messages_setTyping new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_checkUsername$account_checkUsername new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_updateUsername$account_updateUsername new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_search$contacts_search new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_getPrivacy$account_getPrivacy new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_setPrivacy$account_setPrivacy new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_deleteAccount$account_deleteAccount new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_getAccountTTL$account_getAccountTTL new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_setAccountTTL$account_setAccountTTL new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_changePhone$account_changePhone new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_setPassword$account_setPassword new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_resetAccountPassword$auth_resetAccountPassword new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getStickers$messages_getStickers new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_updateDeviceLocked$account_updateDeviceLocked new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_readHistory$messages_readHistory new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_readMessageContents$messages_readMessageContents new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_editChatTitle$messages_editChatTitle new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_editChatPhoto$messages_editChatPhoto new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_addChatUser$messages_addChatUser new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_deleteChatUser$messages_deleteChatUser new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_createChat$messages_createChat new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_sendBroadcast$messages_sendBroadcast new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getWebPagePreview$messages_getWebPagePreview new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_getAuthorizations$account_getAuthorizations new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_resetAuthorization$account_resetAuthorization new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_getWebAuthorizations$account_getWebAuthorizations new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_resetWebAuthorization$account_resetWebAuthorization new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_resetWebAuthorizations$account_resetWebAuthorizations new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_getPassword$account_getPassword new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_getPasswordSettings$account_getPasswordSettings new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_updatePasswordSettings$account_updatePasswordSettings new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_checkPassword$auth_checkPassword new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_requestPasswordRecovery$auth_requestPasswordRecovery new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_recoverPassword$auth_recoverPassword new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_receivedMessages$messages_receivedMessages new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_exportChatInvite$messages_exportChatInvite new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_checkChatInvite$messages_checkChatInvite new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_importChatInvite$messages_importChatInvite new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getStickerSet$messages_getStickerSet new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_uninstallStickerSet$messages_uninstallStickerSet new]);
    TLMetaClassStore::registerObjectClass([TLRPCphotos_getUserPhotos$photos_getUserPhotos new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getMessagesViews$messages_getMessagesViews new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_reportSpam$messages_reportSpam new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_resolveUsername$contacts_resolveUsername new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_readHistory$channels_readHistory new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_deleteMessages$channels_deleteMessages new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_getMessages$channels_getMessages new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_getParticipant$channels_getParticipant new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_getChannels$channels_getChannels new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_getFullChannel$channels_getFullChannel new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_editAbout$channels_editAbout new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_editTitle$channels_editTitle new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_editPhoto$channels_editPhoto new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_checkUsername$channels_checkUsername new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_updateUsername$channels_updateUsername new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_joinChannel$channels_joinChannel new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_leaveChannel$channels_leaveChannel new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_inviteToChannel$channels_inviteToChannel new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_exportInvite$channels_exportInvite new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_deleteChannel$channels_deleteChannel new]);
    TLMetaClassStore::registerObjectClass([TLRPCupdates_getChannelDifference$updates_getChannelDifference new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_toggleChatAdmins$messages_toggleChatAdmins new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_editChatAdmin$messages_editChatAdmin new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_createChannel$channels_createChannel new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_deactivateChat$messages_deactivateChat new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_migrateChat$messages_migrateChat new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_searchGlobal$messages_searchGlobal new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_startBot$messages_startBot new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_reportPeer$account_reportPeer new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getAllStickers$messages_getAllStickers new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_searchGifs$messages_searchGifs new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getSavedGifs$messages_getSavedGifs new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_saveGif$messages_saveGif new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getDocumentByHash$messages_getDocumentByHash new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_toggleInvites$channels_toggleInvites new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_exportMessageLink$channels_exportMessageLink new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_toggleSignatures$channels_toggleSignatures new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_updatePinnedMessage$channels_updatePinnedMessage new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_deleteUserHistory$channels_deleteUserHistory new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_reportSpam$channels_reportSpam new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_hideReportSpam$messages_hideReportSpam new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getPeerSettings$messages_getPeerSettings new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_resendCode$auth_resendCode new]);
    TLMetaClassStore::registerObjectClass([TLRPCauth_cancelCode$auth_cancelCode new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getMessageEditData$messages_getMessageEditData new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_getTopPeers$contacts_getTopPeers new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_resetTopPeerRating$contacts_resetTopPeerRating new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getPeerDialogs$messages_getPeerDialogs new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getAllDrafts$messages_getAllDrafts new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_deleteHistory$messages_deleteHistory new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getFeaturedStickers$messages_getFeaturedStickers new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getUnusedStickers$messages_getUnusedStickers new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_saveRecentSticker$messages_saveRecentSticker new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_installStickerSet$messages_installStickerSet new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_confirmPhone$account_confirmPhone new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_getAdminedPublicChannels$channels_getAdminedPublicChannels new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getMaskStickers$messages_getMaskStickers new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_readFeaturedStickers$messages_readFeaturedStickers new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_reorderStickerSets$messages_reorderStickerSets new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getAttachedStickers$messages_getAttachedStickers new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getRecentStickers$messages_getRecentStickers new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_clearRecentStickers$messages_clearRecentStickers new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getArchivedStickers$messages_getArchivedStickers new]);
    TLMetaClassStore::registerObjectClass([TLRPCupdates_getDifference$updates_getDifference new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getCommonChats$messages_getCommonChats new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getAllChats$messages_getAllChats new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getWebPage$messages_getWebPage new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getHistory$messages_getHistory new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_toggleDialogPin$messages_toggleDialogPin new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_reorderPinnedDialogs$messages_reorderPinnedDialogs new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getPinnedDialogs$messages_getPinnedDialogs new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_deleteMessages$messages_deleteMessages new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_reportEncryptedSpam$messages_reportEncryptedSpam new]);
    TLMetaClassStore::registerObjectClass([TLRPCphone_requestCall$phone_requestCall new]);
    TLMetaClassStore::registerObjectClass([TLRPCphone_acceptCall$phone_acceptCall new]);
    TLMetaClassStore::registerObjectClass([TLRPCphone_receivedCall$phone_receivedCall new]);
    TLMetaClassStore::registerObjectClass([TLRPCphone_discardCall$phone_discardCall new]);
    TLMetaClassStore::registerObjectClass([TLRPCphone_setCallRating$phone_setCallRating new]);
    TLMetaClassStore::registerObjectClass([TLRPCupload_getWebFile$upload_getWebFile new]);
    TLMetaClassStore::registerObjectClass([TLRPCpayments_getPaymentForm$payments_getPaymentForm new]);
    TLMetaClassStore::registerObjectClass([TLRPCpayments_getPaymentReceipt$payments_getPaymentReceipt new]);
    TLMetaClassStore::registerObjectClass([TLRPCpayments_validateRequestedInfo$payments_validateRequestedInfo new]);
    TLMetaClassStore::registerObjectClass([TLRPCaccount_getTmpPassword$account_getTmpPassword new]);
    TLMetaClassStore::registerObjectClass([TLRPCpayments_getSavedInfo$payments_getSavedInfo new]);
    TLMetaClassStore::registerObjectClass([TLRPCpayments_clearSavedInfo$payments_clearSavedInfo new]);
    TLMetaClassStore::registerObjectClass([TLRPChelp_getAppChangelog$help_getAppChangelog new]);
    TLMetaClassStore::registerObjectClass([TLRPCphone_getCallConfig$phone_getCallConfig new]);
    TLMetaClassStore::registerObjectClass([TLRPCphone_saveCallDebug$phone_saveCallDebug new]);
    TLMetaClassStore::registerObjectClass([TLRPCphone_confirmCall$phone_confirmCall new]);
    TLMetaClassStore::registerObjectClass([TLRPCphone_sendSignalingData$phone_sendSignalingData new]);
    TLMetaClassStore::registerObjectClass([TLRPCupload_getCdnFile$upload_getCdnFile new]);
    TLMetaClassStore::registerObjectClass([TLRPChelp_getCdnConfig$help_getCdnConfig new]);
    TLMetaClassStore::registerObjectClass([TLRPClangpack_getLangPack$langpack_getLangPack new]);
    TLMetaClassStore::registerObjectClass([TLRPClangpack_getStrings$langpack_getStrings new]);
    TLMetaClassStore::registerObjectClass([TLRPClangpack_getDifference$langpack_getDifference new]);
    TLMetaClassStore::registerObjectClass([TLRPClangpack_getLanguages$langpack_getLanguages new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_editAdmin$channels_editAdmin new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_editBanned$channels_editBanned new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_getAdminLogMeta$channels_getAdminLogMeta new]);
    TLMetaClassStore::registerObjectClass([TLRPCupload_reuploadCdnFile$upload_reuploadCdnFile new]);
    TLMetaClassStore::registerObjectClass([TLRPCupload_getCdnFileHashes$upload_getCdnFileHashes new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_sendScreenshotNotification$messages_sendScreenshotNotification new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_setStickers$channels_setStickers new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getFavedStickers$messages_getFavedStickers new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_faveSticker$messages_faveSticker new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_readMessageContents$channels_readMessageContents new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_importContacts$contacts_importContacts new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_resetSaved$contacts_resetSaved new]);
    TLMetaClassStore::registerObjectClass([TLRPCcontacts_getContacts$contacts_getContacts new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getUnreadMentions$messages_getUnreadMentions new]);
    TLMetaClassStore::registerObjectClass([TLRPChelp_getRecentMeUrls$help_getRecentMeUrls new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_deleteHistory$channels_deleteHistory new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_togglePreHistoryHidden$channels_togglePreHistoryHidden new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_readMentions$messages_readMentions new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_getRecentLocations$messages_getRecentLocations new]);
    TLMetaClassStore::registerObjectClass([TLRPCchannels_getParticipants$channels_getParticipants new]);
    TLMetaClassStore::registerObjectClass([TLRPCmessages_uploadMedia$messages_uploadMedia new]);
}

static const char TLMetaClassNames[] =
    "TLDialogPeer$dialogPeerFeed\0"
    "TLInputCheckPasswordSRP$inputCheckPasswordEmpty\0"
    "TLUpdate$updatePrivacy\0"
    "TLmessages_AllStickers$messages_allStickers\0"
    "TLInputMedia$inputMediaGifExternal\0"
    "TLInputMedia$inputMediaPhotoMeta\0"
    "TLMessagesFilter$inputMessagesFilterPhotoVideoDocuments\0"
    "TLKeyboardButton$keyboardButtonCallback\0"
    "TLResponseIndirect$responseIndirect\0"
    "TLSecurePasswordKdfAlgo$securePasswordKdfAlgoUnknown\0"
    "TLRPCchannels_getAdminLogMeta$channels_getAdminLogMeta\0"
    "TLRPCmessages_editChatPhoto$messages_editChatPhoto\0"
    "TLReplyMarkup$replyKeyboardMarkup\0"
    "TLRPCauth_signUp$auth_signUp\0"
    "TLUpdates$updatesCombined\0"
    "TLRPCmessages_addChatUser$messages_addChatUser\0"
    "TLContactLink$contactLinkHasPhone\0"
    "TLRichText$textItalic\0"
    "TLRPCchannels_updateUsername$channels_updateUsername\0"
    "TLUpdate$updateUserTyping\0"
    "TLKeyboardButtonRow$keyboardButtonRow\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionChangeAbout\0"
    "TLcontacts_Requests$contacts_requests\0"
    "TLLangPackString$langPackStringPluralized\0"
    "TLUpdate$updateChannelGroup\0"
    "TLSecureValueType$secureValueTypeDriverLicense\0"
    "TLSchemeType$schemeType\0"
    "TLmessages_Dialogs$messages_dialogs\0"
    "TLInputNotifyPeer$inputNotifyUsers\0"
    "TLContactStatus$contactStatus\0"
    "TLContactLocated$contactLocatedPreview\0"
    "TLSecureFile$secureFileEmpty\0"
    "TLRPCmessages_getMessageEditData$messages_getMessageEditData\0"
    "TLRPCupdates_subscribe$updates_subscribe\0"
    "TLUserStatus$userStatusRecently\0"
    "TLmessages_RecentStickers$messages_recentStickersNotModified\0"
    "TLhelp_AppPrefs$help_appPrefs\0"
    "TLRPCaccount_checkUsername$account_checkUsername\0"
    "TLUpdate$updateUserPhoto\0"
    "TLInputStickerSet$inputStickerSetEmpty\0"
    "TLRPCphotos_readWall$photos_readWall\0"
    "TLRPCaccount_registerDevice$account_registerDevice\0"
    "TLSecurePasswordKdfAlgo$securePasswordKdfAlgoPBKDF2HMACSHA512iter100000\0"
    "TLInputMedia$inputMediaGeoLive\0"
    "TLInputSecureFile$inputSecureFile\0"
    "TLstorage_FileType$storage_fileWebp\0"
    "TLRPCaccount_getTmpPassword$account_getTmpPassword\0"
    "TLRPCauth_importAuthorization$auth_importAuthorization\0"
    "TLRPCmessages_setEncryptedTyping$messages_setEncryptedTyping\0"
    "TLSecureValueType$secureValueTypePhone\0"
    "TLMessageMedia$messageMediaUnsupported\0"
    "TLUpdate$updateRestoreMessages\0"
    "TLBotCommand$botCommand\0"
    "TLUpdate$updateNewEncryptedMessage\0"
    "TLRPCmessages_getAllChats$messages_getAllChats\0"
    "TLRPCchannels_inviteToChannel$channels_inviteToChannel\0"
    "TLMessageAction$messageActionHistoryClear\0"
    "TLRPCauth_logOut$auth_logOut\0"
    "TLRPCcontest_saveDeveloperInfo$contest_saveDeveloperInfo\0"
    "TLPageBlock$pageBlockBlockquote\0"
    "TLRichText$textFixed\0"
    "TLPage$pagePart\0"
    "TLReplyMarkup$replyKeyboardForceReply\0"
    "TLShippingOption$shippingOption\0"
    "TLGeoPoint$geoPointEmpty\0"
    "TLInputPeer$inputPeerChannel\0"
    "TLRPCmessages_deleteHistory$messages_deleteHistory\0"
    "TLInputGeoPoint$inputGeoPoint\0"
    "TLmessages_DhConfig$messages_dhConfig\0"
    "TLSecurePlainData$securePlainPhone\0"
    "TLRichText$textStrike\0"
    "TLRPCaccount_resetWebAuthorization$account_resetWebAuthorization\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionToggleInvites\0"
    "TLRPCcontacts_importContacts$contacts_importContacts\0"
    "TLPageBlock$pageBlockEmbedMeta\0"
    "TLRPCchannels_joinChannel$channels_joinChannel\0"
    "TLRPCmessages_sendEncrypted$messages_sendEncrypted\0"
    "TLInputChatPhoto$inputChatPhoto\0"
    "TLauth_CodeType$auth_codeTypeCall\0"
    "TLcontacts_Located$contacts_located\0"
    "TLMsgDetailedInfo$msg_new_detailed_info\0"
    "TLRPCaccount_resetNotifySettings$account_resetNotifySettings\0"
    "TLRPCphotos_uploadPhoto$photos_uploadPhoto\0"
    "TLMessageAction$messageActionChatJoinedByLink\0"
    "TLLangPackString$langPackStringDeleted\0"
    "TLGeoPoint$geoPoint\0"
    "TLMessagesFilter$inputMessagesFilterMusic\0"
    "TLPhoneConnection$phoneConnection\0"
    "TLPhoneCallDiscardReason$phoneCallDiscardReasonDisconnect\0"
    "TLSecureSecretSettings$secureSecretSettings\0"
    "TLaccount_SentEmailCode$account_sentEmailCode\0"
    "TLMessageAction$messageActionChatEditPhoto\0"
    "TLmessages_FoundGifs$messages_foundGifs\0"
    "TLInvoice$invoiceMeta\0"
    "TLPhoneCall$phoneCallRequested\0"
    "TLRPCmessages_getFeaturedStickers$messages_getFeaturedStickers\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionTogglePreHistoryHidden\0"
    "TLRPCaccount_deleteAccount$account_deleteAccount\0"
    "TLChannelParticipantsFilter$channelParticipantsAdmins\0"
    "TLRPCchannels_editBanned$channels_editBanned\0"
    "TLRPChelp_getSupport$help_getSupport\0"
    "TLChatInvite$chatInviteMeta\0"
    "TLRPCmessages_deactivateChat$messages_deactivateChat\0"
    "TLRPCcontacts_getLink$contacts_getLink\0"
    "TLRPCaccount_getPassword$account_getPassword\0"
    "TLRPCmessages_requestEncryption$messages_requestEncryption\0"
    "TLPageBlock$pageBlockVideo\0"
    "TLRPCmessages_discardEncryption$messages_discardEncryption\0"
    "TLSet_client_DH_params_answer$dh_gen_retry\0"
    "TLMaskCoords$maskCoords\0"
    "TLUpdates$updates\0"
    "TLRPCmessages_getCommonChats$messages_getCommonChats\0"
    "TLDocumentAttribute$documentAttributeImageSize\0"
    "TLUpdate$updatePhoneCallSignalingData\0"
    "TLReceivedNotifyMessage$receivedNotifyMessage\0"
    "TLMessageAction$messageActionChatAddUserLegacy\0"
    "TLMessageAction$messageActionPaymentSent\0"
    "TLMessagesFilter$inputMessagesFilterChatPhotos\0"
    "TLPrivacyRule$privacyValueDisallowUsers\0"
    "TLRPCchannels_toggleInvites$channels_toggleInvites\0"
    "TLRPCphotos_updateProfilePhoto$photos_updateProfilePhoto\0"
    "TLWebPage$webPageEmpty\0"
    "TLcontacts_SentLink$contacts_sentLink\0"
    "TLPageBlock$pageBlockPullquote\0"
    "TLRPCaccount_setPrivacy$account_setPrivacy\0"
    "TLUpdate$updateNewStickerSet\0"
    "TLRPCmessages_getDocumentByHash$messages_getDocumentByHash\0"
    "TLLangPackLanguage$langPackLanguage\0"
    "TLauth_CheckedPhone$auth_checkedPhone\0"
    "TLChannelMessagesFilter$channelMessagesFilterEmpty\0"
    "TLRPCmessages_checkChatInvite$messages_checkChatInvite\0"
    "TLhelp_PassportConfig$help_passportConfigNotModified\0"
    "TLError$error\0"
    "TLWebAuthorization$webAuthorization\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionUpdatePinned\0"
    "TLRPCmessages_getHistory$messages_getHistory\0"
    "TLRPCcontacts_search$contacts_search\0"
    "TLSendMessageAction$sendMessageTypingAction\0"
    "TLRPCphotos_restorePhotos$photos_restorePhotos\0"
    "TLInputEncryptedFile$inputEncryptedFileUploaded\0"
    "TLauth_PasswordRecovery$auth_passwordRecovery\0"
    "TLInputGame$inputGameShortName\0"
    "TLFoundGif$foundGifCached\0"
    "TLauth_CodeType$auth_codeTypeSms\0"
    "TLcontacts_Link$contacts_link\0"
    "TLMessageAction$messageActionChatMigrateTo\0"
    "TLInputPrivacyRule$inputPrivacyValueAllowUsers\0"
    "TLSendMessageAction$sendMessageGamePlayAction\0"
    "TLRPCcontacts_resetSaved$contacts_resetSaved\0"
    "TLUserStatus$userStatusLastWeek\0"
    "TLUpdate$updateNotifySettings\0"
    "TLDataJSON$dataJSON\0"
    "TLUserStatus$userStatusOnline\0"
    "TLPhoto$photoEmpty\0"
    "TLPeerNotifySettings$peerNotifySettingsMeta\0"
    "TLRPCmessages_getMaskStickers$messages_getMaskStickers\0"
    "TLInputChatPhoto$inputChatPhotoEmpty\0"
    "TLRPCmessages_uninstallStickerSet$messages_uninstallStickerSet\0"
    "TLInputPeer$inputPeerEmpty\0"
    "TLSecureValueHash$secureValueHash\0"
    "TLhelp_TermsOfService$help_termsOfServiceMeta\0"
    "TLFileLocation$fileLocation\0"
    "TLUserStatus$userStatusEmpty\0"
    "TLmessages_RecentStickers$messages_recentStickers\0"
    "TLPhotoSize$photoCachedSize\0"
    "TLKeyboardButton$keyboardButtonGame\0"
    "TLUpdate$updateContactRegistered\0"
    "TLRichText$textBold\0"
    "TLRPCping$ping\0"
    "TLRPCaccount_setPassword$account_setPassword\0"
    "TLMessageMedia$messageMediaPhotoMeta\0"
    "TLInputUser$inputUserEmpty\0"
    "TLInputMedia$inputMediaVenue\0"
    "TLChat$chatEmpty\0"
    "TLmessages_Messages$messages_messagesSlice\0"
    "TLUpdate$updateEditMessage\0"
    "TLaccount_AuthorizationForm$account_authorizationFormMeta\0"
    "TLRPCcontacts_sendRequest$contacts_sendRequest\0"
    "TLRPCmessages_startBot$messages_startBot\0"
    "TLRPCmessages_toggleDialogPin$messages_toggleDialogPin\0"
    "TLmessages_PeerDialogs$messages_peerDialogs\0"
    "TLcontacts_Blocked$contacts_blocked\0"
    "TLSecureValueError$secureValueErrorTranslationFile\0"
    "TLUpdate$updateEncryptedChatTyping\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionEditMessage\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionDeleteMessage\0"
    "TLcontacts_ResolvedPeer$contacts_resolvedPeer\0"
    "TLchannels_FeedSources$channels_feedSourcesNotModified\0"
    "TLRPCmessages_sendBroadcast$messages_sendBroadcast\0"
    "TLInputWebFileLocation$inputWebFileLocation\0"
    "TLRPCcontacts_getLocated$contacts_getLocated\0"
    "TLSendMessageAction$sendMessageRecordVideoAction\0"
    "TLUpdate$updateChannelTooLongMeta\0"
    "TLUpdate$updateChatParticipantAdmin\0"
    "TLUpdate$updateReadChannelOutbox\0"
    "TLRPCmessages_reportEncryptedSpam$messages_reportEncryptedSpam\0"
    "TLRPCchannels_exportInvite$channels_exportInvite\0"
    "TLInputMedia$inputMediaEmpty\0"
    "TLmessages_Dialogs$messages_dialogsSlice\0"
    "TLInputEncryptedFile$inputEncryptedFileBigUploaded\0"
    "TLSendMessageAction$sendMessageGameStopAction\0"
    "TLInputMedia$inputMediaDocumentExternalMeta\0"
    "TLRPClangpack_getStrings$langpack_getStrings\0"
    "TLchannels_ChannelParticipants$channels_channelParticipants\0"
    "TLDocumentAttribute$documentAttributeAnimated\0"
    "TLSecurePlainData$securePlainEmail\0"
    "TLRPCmessages_reportSpam$messages_reportSpam\0"
    "TLRPCcontacts_resetTopPeerRating$contacts_resetTopPeerRating\0"
    "TLMessagesFilter$inputMessagesFilterEmpty\0"
    "TLUpdate$updateChannelReadMessagesContents\0"
    "TLRPCaccount_getAuthorizations$account_getAuthorizations\0"
    "TLmessages_SentEncryptedMessage$messages_sentEncryptedFile\0"
    "TLRPCcontacts_getBlocked$contacts_getBlocked\0"
    "TLMessageAction$messageActionChannelMigrateFrom\0"
    "TLPageBlock$pageBlockPreformatted\0"
    "TLInputMedia$inputMediaGame\0"
    "TLMessagesFilter$inputMessagesFilterPhotos\0"
    "TLInputPaymentCredentials$inputPaymentCredentialsSaved\0"
    "TLReplyMarkup$replyInlineMarkup\0"
    "TLcontacts_MyLink$contacts_myLinkEmpty\0"
    "TLRPCmessages_getMessages$messages_getMessages\0"
    "TLContactBlocked$contactBlocked\0"
    "TLChannelParticipantsFilter$channelParticipantsKicked\0"
    "TLRPCusers_getFullUser$users_getFullUser\0"
    "TLupdates_Difference$updates_differenceSlice\0"
    "TLMessageAction$messageActionChatEditTitle\0"
    "TLRPCaccount_unregisterDevice$account_unregisterDevice\0"
    "TLInputNotifyPeer$inputNotifyPeer\0"
    "TLMessageAction$messageActionChatDeletePhoto\0"
    "TLRPCaccount_getWebAuthorizations$account_getWebAuthorizations\0"
    "TLUpdate$updateEncryptedMessagesRead\0"
    "TLEncryptedFile$encryptedFileEmpty\0"
    "TLauth_SentCodeType$auth_sentCodeTypeSms\0"
    "TLRPCget_future_salts$get_future_salts\0"
    "TLRPCmessages_sendScreenshotNotification$messages_sendScreenshotNotification\0"
    "TLupload_CdnFile$upload_cdnFile\0"
    "TLRPCauth_recoverPassword$auth_recoverPassword\0"
    "TLMessageRange$messageRange\0"
    "TLRPChelp_test$help_test\0"
    "TLChatParticipant$chatParticipant\0"
    "TLupload_File$upload_fileCdnRedirect\0"
    "TLRPCmessages_getFullChat$messages_getFullChat\0"
    "TLcontacts_Found$contacts_found\0"
    "TLRichText$textPlain\0"
    "TLRPCmessages_getAttachedStickers$messages_getAttachedStickers\0"
    "TLDestroySessionRes$destroy_session_ok\0"
    "TLauth_Authorization$auth_authorizationMeta\0"
    "TLUpdates$updatesTooLong\0"
    "TLRichText$textUnderline\0"
    "TLDocumentAttribute$documentAttributeVideo\0"
    "TLRPCmessages_getArchivedStickers$messages_getArchivedStickers\0"
    "TLEncryptedFile$encryptedFile\0"
    "TLInputGeoPoint$inputGeoPointEmpty\0"
    "TLMessageMedia$messageMediaContact\0"
    "TLmessages_Message$messages_message\0"
    "TLInputBotInlineMessage$inputBotInlineMessageGame\0"
    "TLChannelAdminLogEventsFilter$channelAdminLogEventsFilter\0"
    "TLstorage_FileType$storage_fileMov\0"
    "TLRPCmessages_createChat$messages_createChat\0"
    "TLupdates_ChannelDifference$updates_channelDifferenceTooLongMeta\0"
    "TLPasswordKdfAlgo$passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow\0"
    "TLUpdate$updateReadMessagesContents\0"
    "TLRPCauth_resetAccountPassword$auth_resetAccountPassword\0"
    "TLUpdate$updateReadChannelInbox\0"
    "TLInputPhotoCrop$inputPhotoCrop\0"
    "TLChannelMessagesFilter$channelMessagesFilterCollapsed\0"
    "TLEncryptedMessage$encryptedMessage\0"
    "TLPageBlock$pageBlockSubtitle\0"
    "TLContactLink$contactLinkNone\0"
    "TLRPCmessages_readFeaturedStickers$messages_readFeaturedStickers\0"
    "TLRPCaccount_setAccountTTL$account_setAccountTTL\0"
    "TLMessageAction$messageActionSecureValuesSent\0"
    "TLRPCchannels_deleteUserHistory$channels_deleteUserHistory\0"
    "TLGlobalPrivacySettings$globalPrivacySettings\0"
    "TLphone_DiscardedCall$phone_discardedCall\0"
    "TLInputPaymentCredentials$inputPaymentCredentialsApplePay\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionParticipantToggleAdmin\0"
    "TLRPCaccount_getWallPapers$account_getWallPapers\0"
    "TLMessage$message\0"
    "TLRPCauth_requestPasswordRecovery$auth_requestPasswordRecovery\0"
    "TLReportReason$inputReportReasonViolence\0"
    "TLMessageEntity$messageEntityPhone\0"
    "TLMessageEntity$messageEntityHashtag\0"
    "TLRPCphone_requestCall$phone_requestCall\0"
    "TLRPCmessages_getRecentLocations$messages_getRecentLocations\0"
    "TLcontacts_MyLink$contacts_myLinkContact\0"
    "TLUpdate$updateChannel\0"
    "TLPeer$peerChannel\0"
    "TLRPCphotos_getWall$photos_getWall\0"
    "TLRPCauth_signIn$auth_signIn\0"
    "TLRPCchannels_createChannel$channels_createChannel\0"
    "TLPhoneCall$phoneCallEmpty\0"
    "TLTopPeerCategory$topPeerCategoryBotsInline\0"
    "TLcontacts_ForeignLink$contacts_foreignLinkMutual\0"
    "TLPageBlock$pageBlockUnsupported\0"
    "TLChannelParticipantsFilter$channelParticipantsSearch\0"
    "TLRPCpayments_clearSavedInfo$payments_clearSavedInfo\0"
    "TLcontacts_TopPeers$contacts_topPeersDisabled\0"
    "TLReportReason$inputReportReasonOther\0"
    "TLupdates_Difference$updates_difference\0"
    "TLPhoneCall$phoneCall\0"
    "TLSendMessageAction$sendMessageUploadDocumentAction\0"
    "TLSendMessageAction$sendMessageUploadRoundAction\0"
    "TLcontacts_ImportedContacts$contacts_importedContacts\0"
    "TLInputFileLocation$inputFileLocation\0"
    "TLMessagesFilter$inputMessagesFilterVoice\0"
    "TLUpdate$updateWebPage\0"
    "TLRPCcontacts_getRequests$contacts_getRequests\0"
    "TLRPCmessages_getChats$messages_getChats\0"
    "TLaccount_PrivacyRules$account_privacyRules\0"
    "TLUpdate$updateChatParticipants\0"
    "TLInputMedia$inputMediaUploadedPhotoMeta\0"
    "TLExportedMessageLink$exportedMessageLink\0"
    "TLDestroySessionRes$destroy_session_none\0"
    "TLUpdates$updateShort\0"
    "TLPhoneCallDiscardReason$phoneCallDiscardReasonBusy\0"
    "TLPage$pageFull\0"
    "TLRPCphotos_editPhoto$photos_editPhoto\0"
    "TLRPCchannels_editAdmin$channels_editAdmin\0"
    "TLDocumentAttribute$documentAttributeFilename\0"
    "TLPeer$peerUser\0"
    "TLRPCmessages_deleteChatUser$messages_deleteChatUser\0"
    "TLpayments_PaymentForm$payments_paymentFormMeta\0"
    "TLLangPackString$langPackString\0"
    "TLRPCauth_sendInvites$auth_sendInvites\0"
    "TLInputMedia$inputMediaContact\0"
    "TLMessage$messageMeta\0"
    "TLPaymentRequestedInfo$paymentRequestedInfoMeta\0"
    "TLCdnConfig$cdnConfig\0"
    "TLEncryptedChat$encryptedChatEmpty\0"
    "TLhelp_DeepLinkInfo$help_deepLinkInfoEmpty\0"
    "TLTopPeerCategoryPeers$topPeerCategoryPeers\0"
    "TLLabeledPrice$labeledPrice\0"
    "TLPhoneCall$phoneCallAccepted\0"
    "TLDraftMessage$draftMessageEmptyMeta\0"
    "TLUpdate$updatePhoneCallRequested\0"
    "TLRPChelp_getConfig$help_getConfig\0"
    "TLPhoto$wallPhoto\0"
    "TLRPCauth_resendCode$auth_resendCode\0"
    "TLTopPeerCategory$topPeerCategoryGroups\0"
    "TLMessageEntity$messageEntityCashtag\0"
    "TLInputEncryptedFile$inputEncryptedFile\0"
    "TLNotifyPeer$notifyUsers\0"
    "TLEncryptedChat$encryptedChat\0"
    "TLPaymentSavedCredentials$paymentSavedCredentialsCard\0"
    "TLUpdate$updateChannelPinnedMessage\0"
    "TLHttpWait$http_wait\0"
    "TLRPCupload_saveBigFilePart$upload_saveBigFilePart\0"
    "TLRPCmessages_getSavedGifs$messages_getSavedGifs\0"
    "TLDialog$dialogFeedMeta\0"
    "TLRPCmessages_acceptEncryption$messages_acceptEncryption\0"
    "TLInputPeer$inputPeerSelf\0"
    "TLInputStickeredMedia$inputStickeredMediaDocument\0"
    "TLChannelParticipant$channelParticipantAdmin\0"
    "TLRPCchannels_setStickers$channels_setStickers\0"
    "TLAuthorization$authorization\0"
    "TLUpdate$updatePhoneCallDeclined\0"
    "TLUserStatus$userStatusLastMonth\0"
    "TLRPCmessages_getUnusedStickers$messages_getUnusedStickers\0"
    "TLPrivacyKey$privacyKeyPhoneCall\0"
    "TLRPCchannels_getAdminedPublicChannels$channels_getAdminedPublicChannels\0"
    "TLRPCreq_pq$req_pq\0"
    "TLstorage_FileType$storage_fileUnknown\0"
    "TLMessagesFilter$inputMessagesFilterPhoneCalls\0"
    "TLUpdate$updatePtsChanged\0"
    "TLRPCauth_checkPassword$auth_checkPassword\0"
    "TLInputPhotoCrop$inputPhotoCropAuto\0"
    "TLPageBlock$pageBlockChannel\0"
    "TLPhoneCall$phoneCallWaitingMeta\0"
    "TLUpdate$updatePinnedDialogsMeta\0"
    "TLRPCaccount_changePhone$account_changePhone\0"
    "TLSecureValueType$secureValueTypeTemporaryRegistration\0"
    "TLcontacts_Blocked$contacts_blockedSlice\0"
    "TLMessageAction$messageActionChannelCreate\0"
    "TLRPCchannels_readHistory$channels_readHistory\0"
    "TLRPChelp_getNearestDc$help_getNearestDc\0"
    "TLMsgDetailedInfo$msg_detailed_info\0"
    "TLInputFile$inputFileBig\0"
    "TLchannels_ChannelParticipants$channels_channelParticipantsNotModified\0"
    "TLInputNotifyPeer$inputNotifyChats\0"
    "TLRichText$textUrl\0"
    "TLDestroySessionsRes$destroy_sessions_res\0"
    "TLSendMessageAction$sendMessageChooseContactAction\0"
    "TLMsgResendReq$msg_resend_req\0"
    "TLaccount_TmpPassword$account_tmpPassword\0"
    "TLBotInlineResult$botInlineMediaResultMeta\0"
    "TLPong$pong\0"
    "TLEncryptedChat$encryptedChatDiscarded\0"
    "TLcontacts_Suggested$contacts_suggested\0"
    "TLauth_SentCode$auth_sentCodeMeta\0"
    "TLUpdate$updateContactsReset\0"
    "TLChannelAdminRights$channelAdminRights\0"
    "TLRPCgeo_saveGeoPlace$geo_saveGeoPlace\0"
    "TLMessageEntity$messageEntityBold\0"
    "TLNearestDc$nearestDc\0"
    "TLupdates_Difference$updates_differenceEmpty\0"
    "TLMsgsStateReq$msgs_state_req\0"
    "TLRichText$textEmail\0"
    "TLPhoto$photo\0"
    "TLMessageAction$messageActionBotAllowed\0"
    "TLKeyboardButton$keyboardButton\0"
    "TLMessageEntity$messageEntityMentionName\0"
    "TLSecureValueType$secureValueTypeUtilityBill\0"
    "TLKeyboardButton$keyboardButtonUrl\0"
    "TLRPCmessages_getPeerSettings$messages_getPeerSettings\0"
    "TLRPCupload_reuploadCdnFile$upload_reuploadCdnFile\0"
    "TLmessages_FoundStickerSets$messages_foundStickerSets\0"
    "TLInputMedia$inputMediaDocumentMeta\0"
    "TLInputChannel$inputChannelEmpty\0"
    "TLUpdate$updateStickerSets\0"
    "TLInputPaymentCredentials$inputPaymentCredentials\0"
    "TLUserFull$userFullMeta\0"
    "TLContactLink$contactLinkUnknown\0"
    "TLRPCaccount_resetAuthorization$account_resetAuthorization\0"
    "TLChannelAdminLogEvent$channelAdminLogEvent\0"
    "TLupload_CdnFile$upload_cdnFileReuploadNeeded\0"
    "TLInputFileLocation$inputEncryptedFileLocation\0"
    "TLRPCphone_acceptCall$phone_acceptCall\0"
    "TLInputStickeredMedia$inputStickeredMediaPhoto\0"
    "TLSchemeParam$schemeParam\0"
    "TLChannelParticipantsFilter$channelParticipantsBanned\0"
    "TLRPCcontacts_acceptRequest$contacts_acceptRequest\0"
    "TLPrivacyRule$privacyValueAllowContacts\0"
    "TLReportReason$inputReportReasonPornography\0"
    "TLMessageEntity$messageEntityPre\0"
    "TLPageBlock$pageBlockAnchor\0"
    "TLMessageEntity$messageEntityMention\0"
    "TLPrivacyRule$privacyValueDisallowContacts\0"
    "TLUpdate$updateChatUserTyping\0"
    "TLSchemeMethod$schemeMethod\0"
    "TLReportReason$inputReportReasonSpam\0"
    "TLChannelParticipant$channelParticipantBanned\0"
    "TLScheme$schemeNotModified\0"
    "TLmessages_AffectedHistory$messages_affectedHistory\0"
    "TLServer_DH_Params$server_DH_params_fail\0"
    "TLPhoneCall$phoneCallDiscardedMeta\0"
    "TLcontacts_ForeignLink$contacts_foreignLinkRequested\0"
    "TLInvokeWithLayer$invokeWithLayer\0"
    "TLmessages_Message$messages_messageEmpty\0"
    "TLRPCchannels_getChannels$channels_getChannels\0"
    "TLFileHash$fileHash\0"
    "TLKeyboardButton$keyboardButtonSwitchInline\0"
    "TLDocument$document\0"
    "TLRPCchannels_deleteMessages$channels_deleteMessages\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionChangeStickerSet\0"
    "TLRPCmessages_editChatTitle$messages_editChatTitle\0"
    "TLServer_DH_Params$server_DH_params_ok\0"
    "TLRPCphone_discardCall$phone_discardCall\0"
    "TLUpdate$updatePhoneCall\0"
    "TLhelp_AppUpdate$help_noAppUpdate\0"
    "TLUpdate$updateLangPack\0"
    "TLSecurePasswordKdfAlgo$securePasswordKdfAlgoSHA512\0"
    "TLRPCmessages_getStickerSet$messages_getStickerSet\0"
    "TLRPCmessages_getWebPagePreview$messages_getWebPagePreview\0"
    "TLWebPage$webPagePending\0"
    "TLRPCdestroy_sessions$destroy_sessions\0"
    "TLPageBlock$pageBlockList\0"
    "TLSecureValueType$secureValueTypeRentalAgreement\0"
    "TLUpdate$updateUserPhone\0"
    "TLMessageAction$messageActionChatAddUser\0"
    "TLmessages_AffectedMessages$messages_affectedMessages\0"
    "TLKeyboardButton$keyboardButtonRequestPhone\0"
    "TLBadMsgNotification$bad_msg_notification\0"
    "TLmessages_Chats$messages_chatsSlice\0"
    "TLmessages_BotResults$messages_botResultsMeta\0"
    "TLRpcDropAnswer$rpc_answer_unknown\0"
    "TLhelp_AppChangelog$help_appChangelog\0"
    "TLInputMedia$inputMediaUploadedDocumentMeta\0"
    "TLstorage_FileType$storage_fileGif\0"
    "TLMessagesFilter$inputMessagesFilterUrl\0"
    "TLGame$gameMeta\0"
    "TLTopPeer$topPeer\0"
    "TLFeedPosition$feedPosition\0"
    "TLP_Q_inner_data$p_q_inner_data\0"
    "TLMessageEntity$messageEntityUrl\0"
    "TLRPCphotos_deletePhotos$photos_deletePhotos\0"
    "TLInputChatPhoto$inputChatUploadedPhoto\0"
    "TLUpdate$updateChannelMessageViews\0"
    "TLRPCmessages_saveRecentSticker$messages_saveRecentSticker\0"
    "TLRPCupload_getCdnFile$upload_getCdnFile\0"
    "TLRPChelp_getAppChangelog$help_getAppChangelog\0"
    "TLMessageMedia$messageMediaEmpty\0"
    "TLmessages_FeaturedStickers$messages_featuredStickers\0"
    "TLUpdate$updateDcOptions\0"
    "TLUpdate$updateMessageID\0"
    "TLInputPrivacyRule$inputPrivacyValueAllowContacts\0"
    "TLRPCcontacts_deleteContact$contacts_deleteContact\0"
    "TLNotifyPeer$notifyChats\0"
    "TLPageBlock$pageBlockCover\0"
    "TLRPCcontacts_resolveUsername$contacts_resolveUsername\0"
    "TLRPCcontacts_getTopPeers$contacts_getTopPeers\0"
    "TLupdates_ChannelDifference$updates_channelDifferenceMeta\0"
    "TLRPCaccount_updateStatus$account_updateStatus\0"
    "TLContactLink$contactLinkContact\0"
    "TLInitConnection$initConnection\0"
    "TLRPCmessages_toggleChatAdmins$messages_toggleChatAdmins\0"
    "TLUpdate$updateDraftMessage\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionChangePhoto\0"
    "TLRPCchannels_exportMessageLink$channels_exportMessageLink\0"
    "TLInputEncryptedChat$inputEncryptedChat\0"
    "TLSendMessageAction$sendMessageCancelAction\0"
    "TLaccount_Password$account_passwordMeta\0"
    "TLRPCcontacts_block$contacts_block\0"
    "TLMessageFwdHeader$messageFwdHeaderMeta\0"
    "TLInputFileLocation$inputDocumentFileLocation\0"
    "TLPageBlock$pageBlockParagraph\0"
    "TLUpdate$updateRecentStickers\0"
    "TLRichText$textEmpty\0"
    "TLRPCchannels_getFullChannel$channels_getFullChannel\0"
    "TLInputPrivacyRule$inputPrivacyValueDisallowAll\0"
    "TLRPCaccount_updateUsername$account_updateUsername\0"
    "TLNotifyPeer$notifyPeer\0"
    "TLInputDialogPeer$inputDialogPeerFeed\0"
    "TLChannelParticipantsFilter$channelParticipantsRecent\0"
    "TLRPCmessages_getMessagesViews$messages_getMessagesViews\0"
    "TLpayments_ValidatedRequestedInfo$payments_validatedRequestedInfoMeta\0"
    "TLWebDocument$webDocument\0"
    "TLFileLocation$fileLocationUnavailable\0"
    "TLRPCaccount_resetWebAuthorizations$account_resetWebAuthorizations\0"
    "TLauth_SentCodeType$auth_sentCodeTypeFlashCall\0"
    "TLDialogPeer$dialogPeer\0"
    "TLMsgsStateInfo$msgs_state_info\0"
    "TLstorage_FileType$storage_filePng\0"
    "TLPageBlock$pageBlockDivider\0"
    "TLhelp_InviteText$help_inviteText\0"
    "TLMessageMedia$messageMediaGeo\0"
    "TLTopPeerCategory$topPeerCategoryChannels\0"
    "TLWebDocument$webDocumentNoProxy\0"
    "TLRPCupdates_unsubscribe$updates_unsubscribe\0"
    "TLRPClangpack_getDifference$langpack_getDifference\0"
    "TLReportReason$inputReportReasonCopyright\0"
    "TLpayments_PaymentReceipt$payments_paymentReceiptMeta\0"
    "TLRPCphone_getDhConfig$phone_getDhConfig\0"
    "TLSecureFile$secureFile\0"
    "TLInputContact$inputPhoneContact\0"
    "TLRPCphotos_uploadProfilePhoto$photos_uploadProfilePhoto\0"
    "TLRPCupdates_getState$updates_getState\0"
    "TLContact$contact\0"
    "TLRPChelp_getCdnConfig$help_getCdnConfig\0"
    "TLSecureValueType$secureValueTypePassportRegistration\0"
    "TLmessages_Messages$messages_messages\0"
    "TLMessageEntity$messageEntityEmail\0"
    "TLUserStatus$userStatusOffline\0"
    "TLMessageAction$messageActionAcceptRequest\0"
    "TLRPCpayments_getPaymentForm$payments_getPaymentForm\0"
    "TLMessageAction$messageActionPinMessage\0"
    "TLphone_DhConfig$phone_dhConfig\0"
    "TLInputFileLocation$inputSecureFileLocation\0"
    "TLRPCphone_saveCallDebug$phone_saveCallDebug\0"
    "TLUpdate$updateUserName\0"
    "TLRichText$textConcat\0"
    "TLMessageEntity$messageEntityCode\0"
    "TLFoundGif$foundGif\0"
    "TLMessagesFilter$inputMessagesFilterContacts\0"
    "TLInputGeoPlaceName$inputGeoPlaceName\0"
    "TLSecureRequiredType$secureRequiredTypeOneOf\0"
    "TLRPCphone_declineCall$phone_declineCall\0"
    "TLPageBlock$pageBlockEmbedPost\0"
    "TLRPCchannels_toggleSignatures$channels_toggleSignatures\0"
    "TLSecureValueError$secureValueErrorSelfie\0"
    "TLhelp_TermsOfServiceUpdate$help_termsOfServiceUpdate\0"
    "TLcontacts_TopPeers$contacts_topPeersNotModified\0"
    "TLhelp_AppUpdate$help_appUpdateMeta\0"
    "TLNewSession$new_session_created\0"
    "TLPrivacyRule$privacyValueAllowUsers\0"
    "TLUpdate$updateNewMessage\0"
    "TLMessageGroup$messageGroup\0"
    "TLMessageMedia$messageMediaInvoiceMeta\0"
    "TLmessages_FavedStickers$messages_favedStickers\0"
    "TLRPCpayments_validateRequestedInfo$payments_validateRequestedInfo\0"
    "TLSecureValueType$secureValueTypeInternalPassport\0"
    "TLScheme$scheme\0"
    "TLRPCping_delay_disconnect$ping_delay_disconnect\0"
    "TLstorage_FileType$storage_fileMp4\0"
    "TLSet_client_DH_params_answer$dh_gen_fail\0"
    "TLPhotoSize$photoSizeEmpty\0"
    "TLcontacts_ForeignLink$contacts_foreignLinkUnknown\0"
    "TLChatInvite$chatInviteAlready\0"
    "TLEncryptedChat$encryptedChatWaiting\0"
    "TLRPCchannels_deleteChannel$channels_deleteChannel\0"
    "TLRPCchannels_editAbout$channels_editAbout\0"
    "TLmessages_FeaturedStickers$messages_featuredStickersNotModified\0"
    "TLRPCupload_saveFilePart$upload_saveFilePart\0"
    "TLUpdate$updateEditChannelMessage\0"
    "TLstorage_FileType$storage_filePartial\0"
    "TLInlineBotSwitchPM$inlineBotSwitchPM\0"
    "TLcontacts_Contacts$contacts_contactsNotModified\0"
    "TLProtoMessage$protoMessage\0"
    "TLSendMessageAction$sendMessageUploadAudioAction\0"
    "TLRPCcontacts_getContacts$contacts_getContacts\0"
    "TLRpcError$rpc_error\0"
    "TLcontacts_Requests$contacts_requestsSlice\0"
    "TLMessageAction$messageActionChannelToggleComments\0"
    "TLRPCphone_sendSignalingData$phone_sendSignalingData\0"
    "TLPageBlock$pageBlockSlideshow\0"
    "TLstorage_FileType$storage_filePdf\0"
    "TLWebPage$webPageNotModified\0"
    "TLRPCmessages_getDhConfig$messages_getDhConfig\0"
    "TLRPCaccount_updateNotifySettings$account_updateNotifySettings\0"
    "TLContactLocated$contactLocated\0"
    "TLUpdate$updateReadHistoryOutbox\0"
    "TLPasswordKdfAlgo$passwordKdfAlgoUnknown\0"
    "TLRPCchannels_leaveChannel$channels_leaveChannel\0"
    "TLUpdate$updateActivation\0"
    "TLStickerSet$stickerSetMeta\0"
    "TLNotifyPeer$notifyBroadcasts\0"
    "TLRPCchannels_getMessages$channels_getMessages\0"
    "TLPrivacyRule$privacyValueAllowAll\0"
    "TLPageBlock$pageBlockTitle\0"
    "TLDocumentAttribute$documentAttributeStickerMeta\0"
    "TLSendMessageAction$sendMessageUploadPhotoAction\0"
    "TLRPCupload_getCdnFileHashes$upload_getCdnFileHashes\0"
    "TLSecureValueError$secureValueErrorReverseSide\0"
    "TLMessageEntity$messageEntityItalic\0"
    "TLhelp_DeepLinkInfo$help_deepLinkInfoMeta\0"
    "TLError$richError\0"
    "TLBotInfo$botInfo\0"
    "TLRPCmessages_restoreMessages$messages_restoreMessages\0"
    "TLRPCmessages_clearRecentStickers$messages_clearRecentStickers\0"
    "TLSecureValueType$secureValueTypePassport\0"
    "TLcontacts_Contacts$contacts_contacts\0"
    "TLImportedContact$importedContact\0"
    "TLMessagesFilter$inputMessagesFilterGeo\0"
    "TLDocument$documentEmpty\0"
    "TLChannelParticipant$channelParticipantSelf\0"
    "TLInputPhoneCall$inputPhoneCall\0"
    "TLmessages_Stickers$messages_stickersNotModified\0"
    "TLMessagesFilter$inputMessagesFilterPhotoVideo\0"
    "TLRPCauth_exportAuthorization$auth_exportAuthorization\0"
    "TLMessageAction$messageActionSentRequest\0"
    "TLUpdate$updateDialogPinned\0"
    "TLInputWebDocument$inputWebDocument\0"
    "TLSecureValueError$secureValueErrorFrontSide\0"
    "TLUpdate$updateDeleteChannelMessages\0"
    "TLRPCmessages_reorderPinnedDialogs$messages_reorderPinnedDialogs\0"
    "TLInputPrivacyRule$inputPrivacyValueAllowAll\0"
    "TLUpdate$updateChannelAvailableMessages\0"
    "TLInputMedia$inputMediaGeoPoint\0"
    "TLUser$user\0"
    "TLSecureValueError$secureValueErrorTranslationFiles\0"
    "TLContactSuggested$contactSuggested\0"
    "TLTopPeerCategory$topPeerCategoryBotsPM\0"
    "TLChatParticipant$chatParticipantAdmin\0"
    "TLRPClangpack_getLanguages$langpack_getLanguages\0"
    "TLRPCmessages_saveGif$messages_saveGif\0"
    "TLInputSecureValue$inputSecureValueMeta\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionChangeUsername\0"
    "TLUpdate$updateFavedStickers\0"
    "TLRPCaccount_updateDeviceLocked$account_updateDeviceLocked\0"
    "TLRPCmessages_getWebPage$messages_getWebPage\0"
    "TLmessages_FeedMessages$messages_feedMessagesNotModified\0"
    "TLPhotoSize$photoSize\0"
    "TLRPCchannels_reportSpam$channels_reportSpam\0"
    "TLRPCchannels_editPhoto$channels_editPhoto\0"
    "TLphotos_Photos$photos_photosSlice\0"
    "TLUpdate$updateLangPackLanguageSuggested\0"
    "TLMessagesFilter$inputMessagesFilterDocument\0"
    "TLmessages_ChatFull$messages_chatFull\0"
    "TLChatPhoto$chatPhotoEmpty\0"
    "TLProtoMessageCopy$msg_copy\0"
    "TLRPCpayments_getSavedInfo$payments_getSavedInfo\0"
    "TLupdates_State$updates_state\0"
    "TLRPClangpack_getLangPack$langpack_getLangPack\0"
    "TLDocumentAttribute$documentAttributeHasStickers\0"
    "TLaccount_PasswordSettings$account_passwordSettingsMeta\0"
    "TLRPCphone_getCallConfig$phone_getCallConfig\0"
    "TLRPCmessages_readMentions$messages_readMentions\0"
    "TLRPCphotos_getPhotos$photos_getPhotos\0"
    "TLmessages_Chat$messages_chat\0"
    "TLWallPaper$wallPaper\0"
    "TLInputPeer$inputPeerUser\0"
    "TLPageBlock$pageBlockHeader\0"
    "TLRPCmessages_receivedMessages$messages_receivedMessages\0"
    "TLEmbedPostMedia$embedPostPhoto\0"
    "TLAccountDaysTTL$accountDaysTTL\0"
    "TLInputPeerNotifySettings$inputPeerNotifySettingsMeta\0"
    "TLRPCchannels_togglePreHistoryHidden$channels_togglePreHistoryHidden\0"
    "TLChatFull$chatFull\0"
    "TLRPCaccount_getNotifySettings$account_getNotifySettings\0"
    "TLPeerSettings$peerSettings\0"
    "TLRPCcontacts_getSuggested$contacts_getSuggested\0"
    "TLmessages_StickerSetInstallResult$messages_stickerSetInstallResultArchive\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionParticipantJoin\0"
    "TLRPCmessages_getUnreadMentions$messages_getUnreadMentions\0"
    "TLRPCauth_cancelCode$auth_cancelCode\0"
    "TLRPChelp_getAppUpdate$help_getAppUpdate\0"
    "TLhelp_AppChangelog$help_appChangelogEmpty\0"
    "TLstorage_FileType$storage_fileJpeg\0"
    "TLupdates_Difference$updates_differenceTooLong\0"
    "TLGeoPlaceName$geoPlaceName\0"
    "TLBadMsgNotification$bad_server_salt\0"
    "TLUserProfilePhoto$userProfilePhotoEmpty\0"
    "TLmessages_Messages$messages_channelMessages\0"
    "TLRPCmessages_getPinnedDialogs$messages_getPinnedDialogs\0"
    "TLChannelParticipant$channelParticipantCreator\0"
    "TLMessagesFilter$inputMessagesFilterMyMentions\0"
    "TLSecureValueError$secureValueErrorData\0"
    "TLRPChelp_saveNetworkStats$help_saveNetworkStats\0"
    "TLPageBlock$pageBlockAuthorDate\0"
    "TLRPCcontacts_unblock$contacts_unblock\0"
    "TLMessageAction$messageActionChatDeleteUser\0"
    "TLRPChelp_getInviteText$help_getInviteText\0"
    "TLcontacts_MyLink$contacts_myLinkRequested\0"
    "TLUpdate$updateContactLocated\0"
    "TLUpdate$updateReadHistoryInbox\0"
    "TLDisabledFeature$disabledFeature\0"
    "TLRPCmessages_readEncryptedHistory$messages_readEncryptedHistory\0"
    "TLmessages_MessageEditData$messages_messageEditData\0"
    "TLPhoneCallDiscardReason$phoneCallDiscardReasonHangup\0"
    "TLInputPrivacyKey$inputPrivacyKeyStatusTimestamp\0"
    "TLRPChelp_getScheme$help_getScheme\0"
    "TLSecureValueType$secureValueTypeIdentityCard\0"
    "TLUpdate$updateStickerSetsOrder\0"
    "TLInputGame$inputGameID\0"
    "TLInputBotInlineResult$inputBotInlineResultGame\0"
    "TLInputMedia$inputMediaPhotoExternalMeta\0"
    "TLMessagesFilter$inputMessagesFilterRoundVoice\0"
    "TLSecureValueError$secureValueErrorFile\0"
    "TLmessages_SentEncryptedMessage$messages_sentEncryptedMessage\0"
    "TLRPChelp_getRecentMeUrls$help_getRecentMeUrls\0"
    "TLRPCaccount_confirmPhone$account_confirmPhone\0"
    "TLRPCcontacts_declineRequest$contacts_declineRequest\0"
    "TLChatPhoto$chatPhoto\0"
    "TLRPCmessages_faveSticker$messages_faveSticker\0"
    "TLUpdate$updateLangPackTooLong\0"
    "TLmessages_ArchivedStickers$messages_archivedStickers\0"
    "TLmessages_StickerSet$messages_stickerSet\0"
    "TLInvokeAfterMsg$invokeAfterMsg\0"
    "TLUpdate$updateSavedGifs\0"
    "TLInputUser$inputUserSelf\0"
    "TLupload_File$upload_file\0"
    "TLmessages_SavedGifs$messages_savedGifs\0"
    "TLRPCreq_DH_params$req_DH_params\0"
    "TLRPCrpc_drop_answer$rpc_drop_answer\0"
    "TLhelp_Support$help_support\0"
    "TLChatParticipant$chatParticipantCreator\0"
    "TLInputDocument$inputDocument\0"
    "TLDcNetworkStats$dcPingStats\0"
    "TLRPCmessages_exportChatInvite$messages_exportChatInvite\0"
    "TLhelp_TermsOfServiceUpdate$help_termsOfServiceUpdateEmpty\0"
    "TLPhoneCallProtocol$phoneCallProtocol\0"
    "TLRPCmessages_readMessageContents$messages_readMessageContents\0"
    "TLFeedBroadcasts$feedBroadcastsUngrouped\0"
    "TLServer_DH_inner_data$server_DH_inner_data\0"
    "TLRPCauth_resetAuthorizations$auth_resetAuthorizations\0"
    "TLClient_DH_Inner_Data$client_DH_inner_data\0"
    "TLStickerSetCovered$stickerSetCovered\0"
    "TLPrivacyRule$privacyValueDisallowAll\0"
    "TLRPCmessages_sendEncryptedFile$messages_sendEncryptedFile\0"
    "TLmessages_DhConfig$messages_dhConfigNotModified\0"
    "TLaccount_PasswordInputSettings$account_passwordInputSettings\0"
    "TLUpdate$updateNewChannelMessage\0"
    "TLRPCmessages_searchGlobal$messages_searchGlobal\0"
    "TLauth_SentCodeType$auth_sentCodeTypeApp\0"
    "TLRPCmessages_searchGifs$messages_searchGifs\0"
    "TLDcOption$dcOption\0"
    "TLRPCcontacts_getContactIDs$contacts_getContactIDs\0"
    "TLFeedBroadcasts$feedBroadcasts\0"
    "TLPrivacyKey$privacyKeyStatusTimestamp\0"
    "TLMessageAction$messageActionCustomAction\0"
    "TLmessages_AllStickers$messages_allStickersNotModified\0"
    "TLPhoneCallDiscardReason$phoneCallDiscardReasonMissed\0"
    "TLMessagesFilter$inputMessagesFilterVideo\0"
    "TLSecureValueType$secureValueTypeAddress\0"
    "TLInputPeer$inputPeerChat\0"
    "TLChatLocated$chatLocated\0"
    "TLmessages_SavedGifs$messages_savedGifsNotModified\0"
    "TLRPCaccount_getPrivacy$account_getPrivacy\0"
    "TLContactRequest$contactRequest\0"
    "TLPrivacyKey$privacyKeyChatInvite\0"
    "TLResPQ$resPQ\0"
    "TLUpdate$updateUserStatus\0"
    "TLhelp_PassportConfig$help_passportConfig\0"
    "TLMessageEntity$messageEntityUnknown\0"
    "TLEncryptedChat$encryptedChatRequested\0"
    "TLMessageAction$messageActionScreenshotTaken\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionParticipantInvite\0"
    "TLInputSecureFile$inputSecureFileUploaded\0"
    "TLmessages_Stickers$messages_stickers\0"
    "TLpayments_PaymentResult$payments_paymentVerficationNeeded\0"
    "TLRPCchannels_updatePinnedMessage$channels_updatePinnedMessage\0"
    "TLEmbedPostMedia$embedPostVideo\0"
    "TLPageBlock$pageBlockCollage\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionParticipantLeave\0"
    "TLCdnPublicKey$cdnPublicKey\0"
    "TLPageBlock$pageBlockPhoto\0"
    "TLInputPhoto$inputPhotoEmpty\0"
    "TLRPCchannels_editTitle$channels_editTitle\0"
    "TLRPCmessages_getFavedStickers$messages_getFavedStickers\0"
    "TLInputCheckPasswordSRP$inputCheckPasswordSRP\0"
    "TLUpdate$updateServiceNotificationMeta\0"
    "TLInputNotifyPeer$inputNotifyBroadcasts\0"
    "TLSecureValueType$secureValueTypeBankStatement\0"
    "TLMessageAction$messageActionGameScore\0"
    "TLUpdate$updateEncryption\0"
    "TLstorage_FileType$storage_fileMp3\0"
    "TLReplyMarkup$replyKeyboardHide\0"
    "TLUpdate$updateDialogUnreadMark\0"
    "TLTopPeerCategory$topPeerCategoryCorrespondents\0"
    "TLMessageAction$messageActionEmpty\0"
    "TLStickerSetCovered$stickerSetMultiCovered\0"
    "TLPhoneConnection$phoneConnectionNotReady\0"
    "TLInputStickerSet$inputStickerSetID\0"
    "TLChatParticipants$chatParticipants\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionToggleSignatures\0"
    "TLSecureData$secureData\0"
    "TLRPCcontacts_clearContact$contacts_clearContact\0"
    "TLcontacts_TopPeers$contacts_topPeers\0"
    "TLKeyboardButton$keyboardButtonRequestGeoLocation\0"
    "TLChat$channelForbiddenMeta\0"
    "TLMessageAction$messageActionChatDeactivate\0"
    "TLUpdate$updateConfig\0"
    "TLRPCmessages_editChatAdmin$messages_editChatAdmin\0"
    "TLRPCchannels_deleteHistory$channels_deleteHistory\0"
    "TLRPCupload_getWebFile$upload_getWebFile\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionChangeTitle\0"
    "TLInputStickerSet$inputStickerSetShortName\0"
    "TLWebPage$webPage\0"
    "TLChannelAdminLogEventAction$channelAdminLogEventActionParticipantToggleBan\0"
    "TLPageBlock$pageBlockSubheader\0"
    "TLRpcDropAnswer$rpc_answer_dropped\0"
    "TLDraftMessage$draftMessageMeta\0"
    "TLMessagesFilter$inputMessagesFilterRoundVideo\0"
    "TLRPCmessages_readHistory$messages_readHistory\0"
    "TLRPCaccount_getAccountTTL$account_getAccountTTL\0"
    "TLInputChannel$inputChannel\0"
    "TLRpcDropAnswer$rpc_answer_dropped_running\0"
    "TLMsgsAck$msgs_ack\0"
    "TLInputEncryptedFile$inputEncryptedFileEmpty\0"
    "TLRPCmessages_uploadMedia$messages_uploadMedia\0"
    "TLRPChelp_getAppPrefs$help_getAppPrefs\0"
    "TLRPCmessages_getPeerDialogs$messages_getPeerDialogs\0"
    "TLaccount_Authorizations$account_authorizations\0"
    "TLMessageMedia$messageMediaGame\0"
    "TLInputPrivacyRule$inputPrivacyValueDisallowUsers\0"
    "TLPageBlock$pageBlockFooter\0"
    "TLmessages_Chats$messages_chats\0"
    "TLUpdate$updateDeleteMessages\0"
    "TLRPCcontacts_getStatuses$contacts_getStatuses\0"
    "TLChat$chatForbidden\0"
    "TLChat$channelMeta\0"
    "TLRPCaccount_reportPeer$account_reportPeer\0"
    "TLupload_WebFile$upload_webFile\0"
    "TLmessages_FavedStickers$messages_favedStickersNotModified\0"
    "TLSecureValueError$secureValueErrorFiles\0"
    "TLHighScore$highScore\0"
    "TLInputPrivacyKey$inputPrivacyKeyChatInvite\0"
    "TLRPCchannels_readMessageContents$channels_readMessageContents\0"
    "TLRPCusers_getUsers$users_getUsers\0"
    "TLRPCphotos_getUserPhotos$photos_getUserPhotos\0"
    "TLChannelParticipant$channelParticipant\0"
    "TLSendMessageAction$sendMessageRecordRoundAction\0"
    "TLmessages_BotCallbackAnswer$messages_botCallbackAnswerMeta\0"
    "TLUserProfilePhoto$userProfilePhoto\0"
    "TLMessageMedia$messageMediaDocumentMeta\0"
    "TLInputPrivacyRule$inputPrivacyValueDisallowContacts\0"
    "TLRPCaccount_getPasswordSettings$account_getPasswordSettings\0"
    "TLSecureRequiredType$secureRequiredType\0"
    "TLSecureValue$secureValueMeta\0"
    "TLphotos_Photo$photos_photo\0"
    "TLGeoPoint$geoPlace\0"
    "TLUpdate$updatePhoneCallConfirmed\0"
    "TLExportedChatInvite$chatInviteExported\0"
    "TLInputDialogPeer$inputDialogPeer\0"
    "TLSecureValueType$secureValueTypePersonalDetails\0"
    "TLMessagesFilter$inputMessagesFilterMyMentionsUnread\0"
    "TLKeyboardButton$keyboardButtonBuy\0"
    "TLRPCphone_receivedCall$phone_receivedCall\0"
    "TLSecureCredentialsEncrypted$secureCredentialsEncrypted\0"
    "TLMsgsAllInfo$msgs_all_info\0"
    "TLRPCauth_checkPhone$auth_checkPhone\0"
    "TLRPCchannels_getParticipants$channels_getParticipants\0"
    "TLRPCmessages_setTyping$messages_setTyping\0"
    "TLpayments_SavedInfo$payments_savedInfoMeta\0"
    "TLInputPhoto$inputPhoto\0"
    "TLRPCmessages_getAllStickers$messages_getAllStickers\0"
    "TLMessageEntity$messageEntityTextUrl\0"
    "TLInputPrivacyKey$inputPrivacyKeyPhoneCall\0"
    "TLRPCpayments_getPaymentReceipt$payments_getPaymentReceipt\0"
    "TLRPCchannels_checkUsername$channels_checkUsername\0"
    "TLStickerPack$stickerPack\0"
    "TLPeer$peerChat\0"
    "TLInputUser$inputUser\0"
    "TLMessageAction$messageActionChatCreate\0"
    "TLRPCaccount_updatePasswordSettings$account_updatePasswordSettings\0"
    "TLUpdate$updateReadFeaturedStickers\0"
    "TLInputFile$inputFile\0"
    "TLInputDocument$inputDocumentEmpty\0"
    "TLphotos_Photos$photos_photos\0"
    "TLPageBlock$pageBlockAudio\0"
    "TLphone_PhoneCall$phone_phoneCall\0"
    "TLPopularContact$popularContact\0"
    "TLauth_SentCodeType$auth_sentCodeTypeCall\0"
    "TLauth_CodeType$auth_codeTypeFlashCall\0"
    "TLBotInlineMessage$botInlineMessageMeta\0"
    "TLRPCmessages_importChatInvite$messages_importChatInvite\0"
    "TLRPCmessages_migrateChat$messages_migrateChat\0"
    "TLUpdate$updateChannelWebPage\0"
    "TLRPCphone_setCallRating$phone_setCallRating\0"
    "TLPostAddress$postAddress\0"
    "TLRPCmessages_hideReportSpam$messages_hideReportSpam\0"
    "TLChannelBannedRights$channelBannedRights\0"
    "TLChannelMessagesFilter$channelMessagesFilter\0"
    "TLSecureValueError$secureValueError\0"
    "TLRPCset_client_DH_params$set_client_DH_params\0"
    "TLRPCmessages_deleteMessages$messages_deleteMessages\0"
    "TLEncryptedMessage$encryptedMessageService\0"
    "TLLangPackDifference$langPackDifference\0"
    "TLmessages_StickerSetInstallResult$messages_stickerSetInstallResultSuccess\0"
    "TLUpdate$updateChatParticipantAdd\0"
    "TLUser$userEmpty\0"
    "TLRPCmessages_sendEncryptedService$messages_sendEncryptedService\0"
    "TLRPCcontacts_deleteContacts$contacts_deleteContacts\0"
    "TLRPCmessages_getRecentStickers$messages_getRecentStickers\0"
    "TLRPCphone_confirmCall$phone_confirmCall\0"
    "TLConfig$configMeta\0"
    "TLMessageAction$messageActionChatActivate\0"
    "TLRPCmessages_getStickers$messages_getStickers\0"
    "TLRPCmessages_installStickerSet$messages_installStickerSet\0"
    "TLRPCmessages_reorderStickerSets$messages_reorderStickerSets\0"
    "TLMessageMedia$messageMediaGeoLive\0"
    "TLMessageEntity$messageEntityBotCommand\0"
    "TLMessage$messageEmpty\0"
    "TLpayments_PaymentResult$payments_paymentResult\0"
    "TLchannels_ChannelParticipant$channels_channelParticipant\0"
    "TLWallPaper$wallPaperSolid\0"
    "TLSet_client_DH_params_answer$dh_gen_ok\0"
    "TLUpdate$updateContactLink\0"
    "TLRPCmessages_receivedQueue$messages_receivedQueue\0"
    "TLSendMessageAction$sendMessageRecordAudioAction\0"
    "TLUpdate$updateChatAdmins\0"
    "TLMessageMedia$messageMediaWebPage\0"
    "TLMessageEntity$inputMessageEntityMentionName\0"
    "TLRPCdestroy_session$destroy_session\0"
    "TLauth_ExportedAuthorization$auth_exportedAuthorization\0"
    "TLFutureSalt$futureSalt\0"
    "TLRPCmessages_getAllDrafts$messages_getAllDrafts\0"
    "TLMessageMedia$messageMediaVenue\0"
    "TLExportedChatInvite$chatInviteEmpty\0"
    "TLSecureValueType$secureValueTypeEmail\0"
    "TLSendMessageAction$sendMessageGeoLocationAction\0"
    "TLUpdate$updateUserBlocked\0"
    "TLmessages_HighScores$messages_highScores\0"
    "TLSendMessageAction$sendMessageUploadVideoAction\0"
    "TLchannels_AdminLogResults$channels_adminLogResults\0"
    "TLDialog$dialogMeta\0"
    "TLaccount_WebAuthorizations$account_webAuthorizations\0"
    "TLUpdate$updateChatParticipantDelete\0"
    "NSArray_FileHash\0"
    "NSArray_PopularContact\0"
    "NSArray_Contact\0"
    "NSArray_LabeledPrice\0"
    "NSArray_PrivacyRule\0"
    "NSArray_CdnPublicKey\0"
    "NSArray_ChannelAdminLogEvent\0"
    "NSArray_SecureValue\0"
    "NSArray_int\0"
    "NSArray_ContactRequest\0"
    "NSArray_ReceivedNotifyMessage\0"
    "NSArray_Chat\0"
    "NSArray_ContactStatus\0"
    "NSArray_Peer\0"
    "NSArray_ContactBlocked\0"
    "NSArray_InputUser\0"
    "NSArray_long\0"
    "NSArray_SchemeType\0"
    "NSArray_FoundGif\0"
    "NSArray_DisabledFeature\0"
    "NSArray_KeyboardButtonRow\0"
    "NSArray_BotCommand\0"
    "NSArray_PhoneConnection\0"
    "NSArray_InputDocument\0"
    "NSArray_InputPrivacyRule\0"
    "NSArray_ContactLocated\0"
    "NSArray_Dialog\0"
    "NSArray_ShippingOption\0"
    "NSArray_DocumentAttribute\0"
    "NSArray_LangPackLanguage\0"
    "NSArray_InputPhoto\0"
    "NSArray_TopPeerCategoryPeers\0"
    "NSArray_StickerPack\0"
    "NSArray_ContactSuggested\0"
    "NSArray_InputPeer\0"
    "NSArray_LangPackString\0"
    "NSArray_Message\0"
    "NSArray_Document\0"
    "NSArray_DcOption\0"
    "NSArray_BotInlineResult\0"
    "NSArray_DcNetworkStats\0"
    "NSArray_InputContact\0"
    "NSArray_Update\0"
    "NSArray_Photo\0"
    "NSArray_TopPeer\0"
    "NSArray_SchemeMethod\0"
    "NSArray_MessageRange\0"
    "NSArray_ImportedContact\0"
    "NSArray_User\0"
    "NSArray_RichText\0"
    "NSArray_ChannelParticipant\0"
    "NSArray_StickerSet\0"
    "NSArray_WallPaper\0"
    "NSArray_MessageEntity\0"
    "NSArray_EncryptedMessage\0"
    "NSArray_StickerSetCovered\0"
    "NSArray_InputChannel\0"
    "NSArray_string\0"
    "NSArray_KeyboardButton\0"
    "NSArray_HighScore\0"
    "NSArray_Authorization\0"
    "NSArray_DestroySessionRes\0"
    "NSArray_ChatParticipant\0"
    "NSArray_PhotoSize\0"
    "NSArray_BotInfo\0"
    "NSArray_PageBlock\0"
    "NSArray_SchemeParam\0"
    ;

static const TLMetaClassEntry TLMetaObjectClassEntries[] =
{
    {(int32_t)0x8097eed4, 0},
    {(int32_t)0x80cec44a, 28},
    {(int32_t)0x80d0afbd, 76},
    {(int32_t)0x80e65716, 99},
    {(int32_t)0x80fe5c41, 143},
    {(int32_t)0x813364f2, 178},
    {(int32_t)0x8134f213, 211},
    {(int32_t)0x81365104, 267},
    {(int32_t)0x81ee5457, 307},
    {(int32_t)0x825eed19, 343},
    {(int32_t)0x82866ecb, 396},
    {(int32_t)0x829bb82f, 451},
    {(int32_t)0x82aadd81, 502},
    {(int32_t)0x82dec460, 536},
    {(int32_t)0x83479e5f, 565},
    {(int32_t)0x83811712, 591},
    {(int32_t)0x8397c9a5, 638},
    {(int32_t)0x83a88724, 672},
    {(int32_t)0x83bc28ba, 694},
    {(int32_t)0x83cd7672, 747},
    {(int32_t)0x844efad3, 773},
    {(int32_t)0x8465d5e7, 811},
    {(int32_t)0x84e1c318, 878},
    {(int32_t)0x8510bef6, 916},
    {(int32_t)0x85296c06, 958},
    {(int32_t)0x8580ba55, 986},
    {(int32_t)0x85a203a1, 1033},
    {(int32_t)0x861842fe, 1057},
    {(int32_t)0x8682a419, 1093},
    {(int32_t)0x86ca4966, 1128},
    {(int32_t)0x86dfd42d, 1158},
    {(int32_t)0x86e21919, 1197},
    {(int32_t)0x86e85509, 1226},
    {(int32_t)0x874123f1, 1287},
    {(int32_t)0x87ba0780, 1328},
    {(int32_t)0x880f146d, 1360},
    {(int32_t)0x8871c57f, 1421},
    {(int32_t)0x88dd0547, 1451},
    {(int32_t)0x88f33ef8, 1500},
    {(int32_t)0x89555221, 1525},
    {(int32_t)0x8a03e4d3, 1564},
    {(int32_t)0x8a408e97, 1601},
    {(int32_t)0x8a4dc260, 1652},
    {(int32_t)0x8ab41d1e, 1724},
    {(int32_t)0x8ac73306, 1755},
    {(int32_t)0x8aebc1a6, 1789},
    {(int32_t)0x8b211c75, 1825},
    {(int32_t)0x8b783939, 1876},
    {(int32_t)0x8bb2428d, 1931},
    {(int32_t)0x8bd93562, 1992},
    {(int32_t)0x8bdaec28, 2031},
    {(int32_t)0x8c21e474, 2070},
    {(int32_t)0x8c8b652b, 2101},
    {(int32_t)0x8cfe55d7, 2125},
    {(int32_t)0x8d0f7474, 2160},
    {(int32_t)0x8dddca46, 2207},
    {(int32_t)0x8e5afb58, 2262},
    {(int32_t)0x8e64d5e6, 2304},
    {(int32_t)0x8e6e165a, 2333},
    {(int32_t)0x8ebaca59, 2390},
    {(int32_t)0x8ecfe758, 2422},
    {(int32_t)0x8f4cfe36, 2443},
    {(int32_t)0x8f52bf3f, 2459},
    {(int32_t)0x8fb043b0, 2497},
    {(int32_t)0x8fc1c3ef, 2529},
    {(int32_t)0x8fc84fa0, 2554},
    {(int32_t)0x90004f94, 2583},
    {(int32_t)0x90c5b4ec, 2634},
    {(int32_t)0x911db814, 2664},
    {(int32_t)0x914f7ead, 2702},
    {(int32_t)0x91885697, 2737},
    {(int32_t)0x91964be8, 2759},
    {(int32_t)0x91acc9cb, 2824},
    {(int32_t)0x91f82313, 2893},
    {(int32_t)0x9211319e, 2946},
    {(int32_t)0x923dad74, 2977},
    {(int32_t)0x9253fb1b, 3024},
    {(int32_t)0x93b721ca, 3075},
    {(int32_t)0x93c0e85f, 3107},
    {(int32_t)0x93c46bc6, 3141},
    {(int32_t)0x93d991f8, 3177},
    {(int32_t)0x94330ad5, 3217},
    {(int32_t)0x947b2a4d, 3278},
    {(int32_t)0x949ac2ac, 3321},
    {(int32_t)0x94a916af, 3367},
    {(int32_t)0x94efe0d2, 3406},
    {(int32_t)0x951de5b3, 3426},
    {(int32_t)0x957070a3, 3468},
    {(int32_t)0x957ab535, 3502},
    {(int32_t)0x95c15cb1, 3560},
    {(int32_t)0x95c4f46e, 3604},
    {(int32_t)0x95d33c18, 3650},
    {(int32_t)0x960b3289, 3693},
    {(int32_t)0x961979ab, 3733},
    {(int32_t)0x9627ce57, 3755},
    {(int32_t)0x9741cc6f, 3786},
    {(int32_t)0x97d44287, 3849},
    {(int32_t)0x980b9e1b, 3927},
    {(int32_t)0x981d1035, 3976},
    {(int32_t)0x987e139a, 4030},
    {(int32_t)0x98d22080, 4075},
    {(int32_t)0x9906c635, 4112},
    {(int32_t)0x99449c24, 4140},
    {(int32_t)0x995c11b2, 4193},
    {(int32_t)0x99c11e22, 4232},
    {(int32_t)0x99df1c99, 4277},
    {(int32_t)0x9a2d2fce, 4336},
    {(int32_t)0x9a9ceef6, 4363},
    {(int32_t)0x9aa19bbd, 4422},
    {(int32_t)0x9ace4a2c, 4465},
    {(int32_t)0x9ae046f4, 4489},
    {(int32_t)0x9b62b77e, 4507},
    {(int32_t)0x9b6d8cdd, 4560},
    {(int32_t)0x9bc80023, 4607},
    {(int32_t)0x9be8a90a, 4645},
    {(int32_t)0x9bfff3e5, 4691},
    {(int32_t)0x9c224127, 4738},
    {(int32_t)0x9c280bf0, 4779},
    {(int32_t)0x9c2b188b, 4826},
    {(int32_t)0x9d1cc58a, 4866},
    {(int32_t)0x9d39aee4, 4917},
    {(int32_t)0x9d3e7f82, 4974},
    {(int32_t)0x9d4b1aca, 4997},
    {(int32_t)0x9d8ee9fd, 5035},
    {(int32_t)0x9d958687, 5066},
    {(int32_t)0x9e624634, 5109},
    {(int32_t)0x9e7ab9b7, 5138},
    {(int32_t)0x9eb9f3df, 5197},
    {(int32_t)0x9eebac54, 5233},
    {(int32_t)0x9f28b489, 5271},
    {(int32_t)0x9fdaa53b, 5322},
    {(int32_t)0xa0491def, 5377},
    {(int32_t)0xa0494afb, 5430},
    {(int32_t)0xa0792d73, 5444},
    {(int32_t)0xa11d7a2e, 5480},
    {(int32_t)0xa186939b, 5548},
    {(int32_t)0xa19c29b8, 5593},
    {(int32_t)0xa23f8326, 5630},
    {(int32_t)0xa2787571, 5674},
    {(int32_t)0xa2934e84, 5721},
    {(int32_t)0xa314075d, 5769},
    {(int32_t)0xa326b4d4, 5815},
    {(int32_t)0xa33e4eb3, 5846},
    {(int32_t)0xa372a139, 5872},
    {(int32_t)0xa4041d8c, 5905},
    {(int32_t)0xa414884f, 5935},
    {(int32_t)0xa41cc9fa, 5978},
    {(int32_t)0xa4acd6c6, 6025},
    {(int32_t)0xa4c6a25b, 6071},
    {(int32_t)0xa4dc11f5, 6116},
    {(int32_t)0xa51d20b5, 6148},
    {(int32_t)0xa51fe2ae, 6178},
    {(int32_t)0xa545e562, 6198},
    {(int32_t)0xa585e4bc, 6228},
    {(int32_t)0xa5e37dbc, 6247},
    {(int32_t)0xa62e9efa, 6291},
    {(int32_t)0xa748307c, 6346},
    {(int32_t)0xa74a7ebb, 6383},
    {(int32_t)0xa74ec2c1, 6446},
    {(int32_t)0xa75765d2, 6473},
    {(int32_t)0xa75f7fc3, 6507},
    {(int32_t)0xa7654e99, 6553},
    {(int32_t)0xa7e91cbf, 6581},
    {(int32_t)0xa7fdfb2f, 6610},
    {(int32_t)0xa80b2929, 6660},
    {(int32_t)0xa81e7110, 6688},
    {(int32_t)0xa8b24c75, 6724},
    {(int32_t)0xa8b7999d, 6757},
    {(int32_t)0xa93c6200, 6777},
    {(int32_t)0xa9e71630, 6792},
    {(int32_t)0xaa0b9bcc, 6837},
    {(int32_t)0xaaa4a462, 6874},
    {(int32_t)0xaad6ab5b, 6901},
    {(int32_t)0xaae285ba, 6930},
    {(int32_t)0xab0dc545, 6947},
    {(int32_t)0xab25af7b, 6990},
    {(int32_t)0xab4da313, 7017},
    {(int32_t)0xab9f2663, 7075},
    {(int32_t)0xabbcf900, 7122},
    {(int32_t)0xaca92abb, 7163},
    {(int32_t)0xad5ec18b, 7218},
    {(int32_t)0xad72f1c3, 7262},
    {(int32_t)0xadd3ad9c, 7298},
    {(int32_t)0xaeaf448f, 7349},
    {(int32_t)0xaf0cfbc1, 7384},
    {(int32_t)0xaf11ec2c, 7451},
    {(int32_t)0xaf87dd0a, 7520},
    {(int32_t)0xafbf13d1, 7566},
    {(int32_t)0xafd7bca6, 7621},
    {(int32_t)0xafe24346, 7672},
    {(int32_t)0xb01f0675, 7716},
    {(int32_t)0xb0361e8e, 7761},
    {(int32_t)0xb06c83f8, 7810},
    {(int32_t)0xb0816061, 7844},
    {(int32_t)0xb082cf0f, 7880},
    {(int32_t)0xb0de70ca, 7913},
    {(int32_t)0xb0fc1727, 7976},
    {(int32_t)0xb1217c38, 8025},
    {(int32_t)0xb12352b4, 8054},
    {(int32_t)0xb131c22b, 8095},
    {(int32_t)0xb14ab57e, 8146},
    {(int32_t)0xb14ffa16, 8192},
    {(int32_t)0xb1550bc8, 8236},
    {(int32_t)0xb17cd3d8, 8281},
    {(int32_t)0xb1b0af2c, 8341},
    {(int32_t)0xb1dfe11d, 8387},
    {(int32_t)0xb1ee1df2, 8422},
    {(int32_t)0xb208e389, 8467},
    {(int32_t)0xb251cae0, 8528},
    {(int32_t)0xb26ed96e, 8570},
    {(int32_t)0xb28a0f5b, 8613},
    {(int32_t)0xb2f767d7, 8670},
    {(int32_t)0xb32ef7bd, 8729},
    {(int32_t)0xb37541c7, 8774},
    {(int32_t)0xb42c6a2e, 8822},
    {(int32_t)0xb4710a06, 8856},
    {(int32_t)0xb48bc46b, 8884},
    {(int32_t)0xb4b18174, 8927},
    {(int32_t)0xb4cb9b07, 8982},
    {(int32_t)0xb4cf4e51, 9014},
    {(int32_t)0xb5456aab, 9053},
    {(int32_t)0xb5c6722b, 9100},
    {(int32_t)0xb6bbfc3a, 9132},
    {(int32_t)0xb6d156bf, 9186},
    {(int32_t)0xb6d9f085, 9227},
    {(int32_t)0xb765cec5, 9272},
    {(int32_t)0xb7a9ce9e, 9315},
    {(int32_t)0xb7c88cfb, 9370},
    {(int32_t)0xb7e0dd8f, 9404},
    {(int32_t)0xb8b49554, 9449},
    {(int32_t)0xb8e3d3c4, 9512},
    {(int32_t)0xb946dbc2, 9549},
    {(int32_t)0xb96de300, 9584},
    {(int32_t)0xb96ee025, 9625},
    {(int32_t)0xb97dbb08, 9664},
    {(int32_t)0xb9a72f80, 9741},
    {(int32_t)0xbaf9c23a, 9773},
    {(int32_t)0xbb35ae8e, 9820},
    {(int32_t)0xbb3e9f0e, 9848},
    {(int32_t)0xbb7c75d2, 9873},
    {(int32_t)0xbb7ed5f1, 9907},
    {(int32_t)0xbb8f9fa6, 9944},
    {(int32_t)0xbc285d36, 9991},
    {(int32_t)0xbc9c9c54, 10023},
    {(int32_t)0xbcb4fbc5, 10044},
    {(int32_t)0xbcf984a4, 10107},
    {(int32_t)0xbd12e422, 10146},
    {(int32_t)0xbd35b7ee, 10190},
    {(int32_t)0xbd3ac160, 10215},
    {(int32_t)0xbd5974ef, 10240},
    {(int32_t)0xbda87060, 10283},
    {(int32_t)0xbdb37017, 10346},
    {(int32_t)0xbdde1e02, 10376},
    {(int32_t)0xbe4c9bee, 10411},
    {(int32_t)0xbe8f6997, 10446},
    {(int32_t)0xbee56e20, 10482},
    {(int32_t)0xbf0b5d6b, 10532},
    {(int32_t)0xbfa46836, 10590},
    {(int32_t)0xbfb03a82, 10625},
    {(int32_t)0xbfb5e5f6, 10670},
    {(int32_t)0xbfbd4719, 10735},
    {(int32_t)0xbff26a94, 10819},
    {(int32_t)0xc001ddc3, 10855},
    {(int32_t)0xc0325936, 10912},
    {(int32_t)0xc05dc5bf, 10944},
    {(int32_t)0xc072b842, 10976},
    {(int32_t)0xc086c3a7, 11031},
    {(int32_t)0xc128b427, 11067},
    {(int32_t)0xc13f076f, 11097},
    {(int32_t)0xc174e83b, 11127},
    {(int32_t)0xc18e8d78, 11192},
    {(int32_t)0xc1f61281, 11241},
    {(int32_t)0xc230b82e, 11287},
    {(int32_t)0xc26b5ab2, 11346},
    {(int32_t)0xc2ab858b, 11392},
    {(int32_t)0xc3a14b22, 11434},
    {(int32_t)0xc3c7a1b2, 11492},
    {(int32_t)0xc4047dc6, 11570},
    {(int32_t)0xc43b7853, 11619},
    {(int32_t)0xc44309fe, 11637},
    {(int32_t)0xc48824f5, 11700},
    {(int32_t)0xc517c26e, 11741},
    {(int32_t)0xc5e2530d, 11776},
    {(int32_t)0xc5eecdc9, 11813},
    {(int32_t)0xc613ba1b, 11854},
    {(int32_t)0xc69f50c4, 11915},
    {(int32_t)0xc6b3ac6e, 11956},
    {(int32_t)0xc6cb4351, 11979},
    {(int32_t)0xc6db35bb, 11998},
    {(int32_t)0xc6e76afa, 12033},
    {(int32_t)0xc7171da5, 12062},
    {(int32_t)0xc76344fc, 12113},
    {(int32_t)0xc769f11d, 12140},
    {(int32_t)0xc7d5d948, 12184},
    {(int32_t)0xc81baebc, 12234},
    {(int32_t)0xc820ea99, 12267},
    {(int32_t)0xc8dfc792, 12321},
    {(int32_t)0xc8e1bdfe, 12374},
    {(int32_t)0xc92626ed, 12420},
    {(int32_t)0xc92fa56d, 12458},
    {(int32_t)0xc9908a15, 12498},
    {(int32_t)0xc9b9e79c, 12520},
    {(int32_t)0xca170402, 12572},
    {(int32_t)0xca675ec3, 12621},
    {(int32_t)0xcab26024, 12675},
    {(int32_t)0xcb0789b9, 12713},
    {(int32_t)0xcb53d8fa, 12755},
    {(int32_t)0xcb8473eb, 12778},
    {(int32_t)0xcba8d7ad, 12825},
    {(int32_t)0xcbcb2ff6, 12866},
    {(int32_t)0xcc141a77, 12910},
    {(int32_t)0xcc1a5a1f, 12942},
    {(int32_t)0xcc4d4449, 12983},
    {(int32_t)0xcc6b35fe, 13025},
    {(int32_t)0xccd3026b, 13066},
    {(int32_t)0xcce41369, 13088},
    {(int32_t)0xcd6b246c, 13140},
    {(int32_t)0xcda48140, 13156},
    {(int32_t)0xcdb8de75, 13195},
    {(int32_t)0xcddece5f, 13238},
    {(int32_t)0xceb751ba, 13284},
    {(int32_t)0xcf0fceb9, 13300},
    {(int32_t)0xcf18b5ee, 13353},
    {(int32_t)0xcf2cb57a, 13401},
    {(int32_t)0xcf3190cf, 13433},
    {(int32_t)0xcfb05079, 13472},
    {(int32_t)0xcffde30d, 13503},
    {(int32_t)0xd00e6be1, 13525},
    {(int32_t)0xd033a8d7, 13573},
    {(int32_t)0xd0f49303, 13595},
    {(int32_t)0xd10f80c7, 13630},
    {(int32_t)0xd125dd73, 13673},
    {(int32_t)0xd13f0dd5, 13717},
    {(int32_t)0xd149f2bd, 13745},
    {(int32_t)0xd158331f, 13775},
    {(int32_t)0xd2a99b80, 13812},
    {(int32_t)0xd393702c, 13846},
    {(int32_t)0xd3b3bebc, 13881},
    {(int32_t)0xd3df47d2, 13899},
    {(int32_t)0xd4870810, 13936},
    {(int32_t)0xd5af324c, 13976},
    {(int32_t)0xd60eda43, 14013},
    {(int32_t)0xd6283d7f, 14053},
    {(int32_t)0xd6d39e97, 14078},
    {(int32_t)0xd7567874, 14108},
    {(int32_t)0xd7cb3038, 14162},
    {(int32_t)0xd7cd05e6, 14198},
    {(int32_t)0xd80f6162, 14219},
    {(int32_t)0xd812ad77, 14270},
    {(int32_t)0xd82d069a, 14319},
    {(int32_t)0xd836a254, 14343},
    {(int32_t)0xd83b195a, 14400},
    {(int32_t)0xd84687ab, 14426},
    {(int32_t)0xd92d146c, 14476},
    {(int32_t)0xd940772b, 14521},
    {(int32_t)0xd97b25b7, 14568},
    {(int32_t)0xd99045cb, 14598},
    {(int32_t)0xd9c9a73a, 14631},
    {(int32_t)0xda6201ed, 14664},
    {(int32_t)0xda7dacf7, 14723},
    {(int32_t)0xda925482, 14756},
    {(int32_t)0xdaa01692, 14829},
    {(int32_t)0xdaaa77af, 14848},
    {(int32_t)0xdaf53069, 14887},
    {(int32_t)0xdb1205e2, 14934},
    {(int32_t)0xdb1254c3, 14960},
    {(int32_t)0xdbf47abb, 15003},
    {(int32_t)0xdc17e55d, 15039},
    {(int32_t)0xdc7555ab, 15068},
    {(int32_t)0xdcd62630, 15101},
    {(int32_t)0xdd2757c6, 15134},
    {(int32_t)0xdd513fe7, 15179},
    {(int32_t)0xdd6282f6, 15234},
    {(int32_t)0xde6ac75e, 15275},
    {(int32_t)0xdeb4256d, 15318},
    {(int32_t)0xded6b405, 15365},
    {(int32_t)0xdee9ed72, 15406},
    {(int32_t)0xdef02630, 15442},
    {(int32_t)0xdf763428, 15467},
    {(int32_t)0xdf8b004e, 15538},
    {(int32_t)0xe0e8b8d3, 15573},
    {(int32_t)0xe0fad008, 15592},
    {(int32_t)0xe14f76c0, 15634},
    {(int32_t)0xe14fdee1, 15685},
    {(int32_t)0xe1e01797, 15715},
    {(int32_t)0xe1f87296, 15757},
    {(int32_t)0xe217bf47, 15800},
    {(int32_t)0xe2266ec5, 15812},
    {(int32_t)0xe2397d8c, 15851},
    {(int32_t)0xe2c5dc1d, 15891},
    {(int32_t)0xe32254dd, 15925},
    {(int32_t)0xe36ada56, 15954},
    {(int32_t)0xe3c9b4dc, 15994},
    {(int32_t)0xe4046999, 16033},
    {(int32_t)0xe44a03ed, 16067},
    {(int32_t)0xe47016d4, 16089},
    {(int32_t)0xe51d7069, 16134},
    {(int32_t)0xe5503523, 16164},
    {(int32_t)0xe6c52372, 16185},
    {(int32_t)0xe6f2dbf1, 16199},
    {(int32_t)0xe71a782a, 16239},
    {(int32_t)0xe727402c, 16271},
    {(int32_t)0xe7e18435, 16312},
    {(int32_t)0xe834ec84, 16357},
    {(int32_t)0xe85e363e, 16392},
    {(int32_t)0xe88add26, 16447},
    {(int32_t)0xe8a26dde, 16498},
    {(int32_t)0xe8c5765a, 16552},
    {(int32_t)0xe8e89274, 16588},
    {(int32_t)0xe8fbc566, 16621},
    {(int32_t)0xe941b9bc, 16648},
    {(int32_t)0xe9fe8dce, 16698},
    {(int32_t)0xea033ab4, 16722},
    {(int32_t)0xea144ef4, 16755},
    {(int32_t)0xea4139da, 16814},
    {(int32_t)0xea5b6634, 16858},
    {(int32_t)0xeabc984c, 16904},
    {(int32_t)0xeaead4cb, 16951},
    {(int32_t)0xeb3eac5a, 16990},
    {(int32_t)0xeb7eda78, 17037},
    {(int32_t)0xeb80e009, 17063},
    {(int32_t)0xeb927049, 17117},
    {(int32_t)0xeb9d8189, 17168},
    {(int32_t)0xebc89a31, 17208},
    {(int32_t)0xebd4d098, 17252},
    {(int32_t)0xebe5709d, 17285},
    {(int32_t)0xec0b00e2, 17313},
    {(int32_t)0xec102e9b, 17350},
    {(int32_t)0xecc51515, 17393},
    {(int32_t)0xed3e7bb0, 17423},
    {(int32_t)0xed7d341e, 17451},
    {(int32_t)0xee8ea686, 17488},
    {(int32_t)0xee8efac4, 17534},
    {(int32_t)0xef024466, 17561},
    {(int32_t)0xf001b9ed, 17613},
    {(int32_t)0xf01017df, 17654},
    {(int32_t)0xf0395e38, 17689},
    {(int32_t)0xf0662114, 17742},
    {(int32_t)0xf0899de2, 17776},
    {(int32_t)0xf09d85b5, 17817},
    {(int32_t)0xf1225ba6, 17864},
    {(int32_t)0xf1356aa1, 17884},
    {(int32_t)0xf1465b5f, 17928},
    {(int32_t)0xf15395a8, 17948},
    {(int32_t)0xf17e13b5, 18001},
    {(int32_t)0xf186ee03, 18073},
    {(int32_t)0xf1e19570, 18124},
    {(int32_t)0xf204e6fb, 18163},
    {(int32_t)0xf21d3247, 18204},
    {(int32_t)0xf22462b1, 18229},
    {(int32_t)0xf23b0fdd, 18263},
    {(int32_t)0xf2d6f3d6, 18287},
    {(int32_t)0xf333dc14, 18339},
    {(int32_t)0xf3394118, 18390},
    {(int32_t)0xf3e5a76c, 18449},
    {(int32_t)0xf4a3e682, 18474},
    {(int32_t)0xf4ace92d, 18513},
    {(int32_t)0xf4d49b3a, 18539},
    {(int32_t)0xf4e1bdf6, 18588},
    {(int32_t)0xf4f77cb2, 18613},
    {(int32_t)0xf5212ff2, 18654},
    {(int32_t)0xf5700be8, 18708},
    {(int32_t)0xf58e5117, 18752},
    {(int32_t)0xf5d77925, 18794},
    {(int32_t)0xf63b203d, 18831},
    {(int32_t)0xf656bba1, 18877},
    {(int32_t)0xf6885eca, 18912},
    {(int32_t)0xf6ef5e25, 18950},
    {(int32_t)0xf76b52ef, 18994},
    {(int32_t)0xf7d4c7b2, 19029},
    {(int32_t)0xf8befed9, 19069},
    {(int32_t)0xf8cee3e4, 19085},
    {(int32_t)0xf8f341b2, 19103},
    {(int32_t)0xf92ddfed, 19131},
    {(int32_t)0xf95ff8ac, 19163},
    {(int32_t)0xf9c8a529, 19196},
    {(int32_t)0xfa544488, 19241},
    {(int32_t)0xfac722e9, 19281},
    {(int32_t)0xfb028aa4, 19316},
    {(int32_t)0xfb0af8ed, 19375},
    {(int32_t)0xfb23d486, 19416},
    {(int32_t)0xfb752ca9, 19463},
    {(int32_t)0xfb99259c, 19496},
    {(int32_t)0xfba8237e, 19550},
    {(int32_t)0xfbcd22b5, 19575},
    {(int32_t)0xfc107595, 19600},
    {(int32_t)0xfc1dc656, 19650},
    {(int32_t)0xfc446803, 19701},
    {(int32_t)0xfcc73ba5, 19726},
    {(int32_t)0xfd586d9b, 19753},
    {(int32_t)0xfd983c3a, 19808},
    {(int32_t)0xfda83d1e, 19855},
    {(int32_t)0xfded5077, 19913},
    {(int32_t)0xfdfccded, 19960},
    {(int32_t)0xfe10095a, 19993},
    {(int32_t)0xfe61e1ed, 20025},
    {(int32_t)0xfe7220e2, 20082},
    {(int32_t)0xfe9e171d, 20110},
    {(int32_t)0xfec5c7bc, 20177},
    {(int32_t)0xff2c582b, 20236},
    {(int32_t)0xff2c7ded, 20276},
    {(int32_t)0xff523bc6, 20320},
    {(int32_t)0xff6f5d37, 20360},
    {(int32_t)0xff8f2d02, 20395},
    {(int32_t)0xffffffff, 20435},
    {(int32_t)0x00f763f6, 20481},
    {(int32_t)0x015cdf58, 20512},
    {(int32_t)0x0161255a, 20542},
    {(int32_t)0x01851eb5, 20563},
    {(int32_t)0x023ab6ca, 20616},
    {(int32_t)0x02dc6b67, 20664},
    {(int32_t)0x03164b8c, 20715},
    {(int32_t)0x0321e581, 20739},
    {(int32_t)0x03299c20, 20777},
    {(int32_t)0x0359b04a, 20831},
    {(int32_t)0x035fa113, 20888},
    {(int32_t)0x03d81671, 20958},
    {(int32_t)0x04182aac, 20984},
    {(int32_t)0x04f2654a, 21023},
    {(int32_t)0x05bb63a1, 21090},
    {(int32_t)0x0639158a, 21137},
    {(int32_t)0x06487aab, 21161},
    {(int32_t)0x066b8981, 21193},
    {(int32_t)0x071a070b, 21228},
    {(int32_t)0x07383601, 21257},
    {(int32_t)0x07f81253, 21291},
    {(int32_t)0x0861caef, 21322},
    {(int32_t)0x089b2b47, 21364},
    {(int32_t)0x08a02d1e, 21397},
    {(int32_t)0x08b088c1, 21442},
    {(int32_t)0x08d871e9, 21493},
    {(int32_t)0x09573627, 21535},
    {(int32_t)0x09cc7b96, 21589},
    {(int32_t)0x09ff393a, 21630},
    {(int32_t)0x0a4294ea, 21654},
    {(int32_t)0x0a5a4710, 21687},
    {(int32_t)0x0a67b40e, 21744},
    {(int32_t)0x0a9d2a4b, 21783},
    {(int32_t)0x0ab2a23f, 21801},
    {(int32_t)0x0ada3d50, 21842},
    {(int32_t)0x0b68d7dc, 21896},
    {(int32_t)0x0bdc7f80, 21934},
    {(int32_t)0x0c74fd9f, 21969},
    {(int32_t)0x0c771c6c, 22000},
    {(int32_t)0x0c8a871f, 22043},
    {(int32_t)0x0ce93aa0, 22096},
    {(int32_t)0x0d4ba8a8, 22136},
    {(int32_t)0x0da7ad9c, 22168},
    {(int32_t)0x0dec7584, 22212},
    {(int32_t)0x0e13ece0, 22257},
    {(int32_t)0x0e17b82e, 22281},
    {(int32_t)0x0e801eca, 22303},
    {(int32_t)0x0ed32366, 22337},
    {(int32_t)0x0f1b4dde, 22357},
    {(int32_t)0x0feaf2b8, 22402},
    {(int32_t)0x1034479a, 22440},
    {(int32_t)0x10943414, 22485},
    {(int32_t)0x10b2cd34, 22526},
    {(int32_t)0x10df3b5a, 22557},
    {(int32_t)0x11460082, 22614},
    {(int32_t)0x1170b6d4, 22656},
    {(int32_t)0x117aade4, 22710},
    {(int32_t)0x11b83f18, 22759},
    {(int32_t)0x11cb312c, 22795},
    {(int32_t)0x11fc301c, 22828},
    {(int32_t)0x1238c8f8, 22865},
    {(int32_t)0x1250dca4, 22891},
    {(int32_t)0x127e5278, 22919},
    {(int32_t)0x12ed18de, 22958},
    {(int32_t)0x136390b0, 23006},
    {(int32_t)0x1396b8da, 23073},
    {(int32_t)0x141525ef, 23123},
    {(int32_t)0x14c36a18, 23139},
    {(int32_t)0x14eef747, 23188},
    {(int32_t)0x155d9cb0, 23223},
    {(int32_t)0x1561e8e7, 23265},
    {(int32_t)0x15bce3ba, 23292},
    {(int32_t)0x1601d4c5, 23343},
    {(int32_t)0x1602df74, 23374},
    {(int32_t)0x167bfb74, 23411},
    {(int32_t)0x16d8d10a, 23462},
    {(int32_t)0x176b8be2, 23505},
    {(int32_t)0x179429e6, 23570},
    {(int32_t)0x17ac2ddb, 23615},
    {(int32_t)0x17b5e28e, 23649},
    {(int32_t)0x17d7b5b9, 23688},
    {(int32_t)0x17d85a83, 23726},
    {(int32_t)0x18a5e7a3, 23775},
    {(int32_t)0x18b3b5e7, 23803},
    {(int32_t)0x18ccaa08, 23852},
    {(int32_t)0x18d9115d, 23899},
    {(int32_t)0x190088f5, 23920},
    {(int32_t)0x19080453, 23963},
    {(int32_t)0x19468a40, 24014},
    {(int32_t)0x1974634a, 24067},
    {(int32_t)0x19ddb5ca, 24098},
    {(int32_t)0x1a1d275f, 24133},
    {(int32_t)0x1a66479b, 24162},
    {(int32_t)0x1aafa7e1, 24209},
    {(int32_t)0x1ab68184, 24272},
    {(int32_t)0x1b325cd6, 24304},
    {(int32_t)0x1b3fd618, 24337},
    {(int32_t)0x1b8e1464, 24378},
    {(int32_t)0x1b92ff80, 24427},
    {(int32_t)0x1bf4595e, 24453},
    {(int32_t)0x1bfab52f, 24481},
    {(int32_t)0x1c319037, 24511},
    {(int32_t)0x1c4faf84, 24558},
    {(int32_t)0x1c50d52c, 24593},
    {(int32_t)0x1cbf90c3, 24620},
    {(int32_t)0x1ccc146b, 24669},
    {(int32_t)0x1ccd5960, 24718},
    {(int32_t)0x1d0d63e2, 24771},
    {(int32_t)0x1d3611f9, 24818},
    {(int32_t)0x1d5eec1b, 24854},
    {(int32_t)0x1d86ae1f, 24896},
    {(int32_t)0x1db27dc2, 24914},
    {(int32_t)0x1e226492, 24932},
    {(int32_t)0x1e42a52f, 24987},
    {(int32_t)0x1e8abd97, 25050},
    {(int32_t)0x1eb2e51b, 25092},
    {(int32_t)0x1ecefc34, 25130},
    {(int32_t)0x1f09bf6b, 25164},
    {(int32_t)0x1f0e5347, 25204},
    {(int32_t)0x1f33494d, 25229},
    {(int32_t)0x1f40644d, 25273},
    {(int32_t)0x1f8c5fc8, 25305},
    {(int32_t)0x1f9a0830, 25354},
    {(int32_t)0x1fa9ee2d, 25401},
    {(int32_t)0x1faf63c6, 25456},
    {(int32_t)0x20b73f55, 25497},
    {(int32_t)0x20c2ded4, 25525},
    {(int32_t)0x21060bf9, 25561},
    {(int32_t)0x214271f3, 25606},
    {(int32_t)0x216dd31f, 25643},
    {(int32_t)0x21f0227f, 25708},
    {(int32_t)0x221242b5, 25753},
    {(int32_t)0x222d34ba, 25793},
    {(int32_t)0x2275eda7, 25825},
    {(int32_t)0x22877d33, 25837},
    {(int32_t)0x22bbd6f9, 25889},
    {(int32_t)0x22cb4913, 25925},
    {(int32_t)0x22e1e015, 25965},
    {(int32_t)0x230ac3a6, 26004},
    {(int32_t)0x23635cd6, 26053},
    {(int32_t)0x23663ab1, 26092},
    {(int32_t)0x2385ff1e, 26132},
    {(int32_t)0x23cfb248, 26202},
    {(int32_t)0x24bb22af, 26231},
    {(int32_t)0x24dbf77a, 26290},
    {(int32_t)0x24e69b83, 26335},
    {(int32_t)0x2585930b, 26392},
    {(int32_t)0x25a5d9e7, 26414},
    {(int32_t)0x260eb5e4, 26459},
    {(int32_t)0x261480f9, 26502},
    {(int32_t)0x26b51897, 26537},
    {(int32_t)0x2703fa7c, 26578},
    {(int32_t)0x275c9b66, 26623},
    {(int32_t)0x276a59a0, 26661},
    {(int32_t)0x27a996b5, 26688},
    {(int32_t)0x27af031b, 26716},
    {(int32_t)0x27cd12fd, 26765},
    {(int32_t)0x2810501d, 26795},
    {(int32_t)0x2865c028, 26842},
    {(int32_t)0x28bafaad, 26891},
    {(int32_t)0x28c34829, 26947},
    {(int32_t)0x28c4e5c7, 26992},
    {(int32_t)0x29233652, 27041},
    {(int32_t)0x296bf2d3, 27080},
    {(int32_t)0x29cac8ce, 27110},
    {(int32_t)0x29e02491, 27132},
    {(int32_t)0x2a05cd39, 27158},
    {(int32_t)0x2a5097f5, 27186},
    {(int32_t)0x2a94ab03, 27243},
    {(int32_t)0x2aca3801, 27275},
    {(int32_t)0x2acbe3d5, 27307},
    {(int32_t)0x2ad1b215, 27361},
    {(int32_t)0x2be8331c, 27430},
    {(int32_t)0x2d42db16, 27450},
    {(int32_t)0x2d5be1b7, 27507},
    {(int32_t)0x2d975ce6, 27535},
    {(int32_t)0x2dd4853e, 27584},
    {(int32_t)0x2e7c715e, 27659},
    {(int32_t)0x2f53ea0a, 27730},
    {(int32_t)0x2f5b84ff, 27789},
    {(int32_t)0x3001772a, 27826},
    {(int32_t)0x308647de, 27867},
    {(int32_t)0x30e964f3, 27910},
    {(int32_t)0x3105285b, 27946},
    {(int32_t)0x31146b5c, 27993},
    {(int32_t)0x31e51389, 28021},
    {(int32_t)0x32a9eac7, 28058},
    {(int32_t)0x32c4ae63, 28099},
    {(int32_t)0x32cd5d83, 28144},
    {(int32_t)0x32ce00ff, 28201},
    {(int32_t)0x3330f265, 28248},
    {(int32_t)0x339b5df7, 28295},
    {(int32_t)0x33ae9178, 28335},
    {(int32_t)0x33f71e25, 28384},
    {(int32_t)0x3437875f, 28416},
    {(int32_t)0x3481dd7e, 28455},
    {(int32_t)0x35425749, 28499},
    {(int32_t)0x35bdcac7, 28542},
    {(int32_t)0x35d0d4f0, 28585},
    {(int32_t)0x35d81163, 28615},
    {(int32_t)0x35db1f63, 28647},
    {(int32_t)0x35df8fda, 28681},
    {(int32_t)0x360ebf02, 28746},
    {(int32_t)0x36169835, 28798},
    {(int32_t)0x364e966f, 28852},
    {(int32_t)0x36525e30, 28901},
    {(int32_t)0x36a8e579, 28936},
    {(int32_t)0x36f35b1a, 28982},
    {(int32_t)0x36fc6ad3, 29014},
    {(int32_t)0x37249336, 29038},
    {(int32_t)0x37524dc0, 29086},
    {(int32_t)0x37e60c8b, 29127},
    {(int32_t)0x380c9c66, 29174},
    {(int32_t)0x3870329c, 29214},
    {(int32_t)0x38a0843b, 29276},
    {(int32_t)0x38b298c5, 29323},
    {(int32_t)0x38b934ff, 29370},
    {(int32_t)0x39bae953, 29423},
    {(int32_t)0x39c46b9a, 29445},
    {(int32_t)0x3a1c6b8a, 29492},
    {(int32_t)0x3a4e4c46, 29523},
    {(int32_t)0x3af4e357, 29577},
    {(int32_t)0x3b7ec605, 29619},
    {(int32_t)0x3beee132, 29651},
    {(int32_t)0x3c1f445e, 29676},
    {(int32_t)0x3c40a687, 29702},
    {(int32_t)0x3c9b9655, 29728},
    {(int32_t)0x3cf4b562, 29768},
    {(int32_t)0x3d4df5cf, 29801},
    {(int32_t)0x3e56b684, 29838},
    {(int32_t)0x3eceaec9, 29866},
    {(int32_t)0x3effa48f, 29907},
    {(int32_t)0x3fb0ef38, 29937},
    {(int32_t)0x3fe1647c, 29966},
    {(int32_t)0x400e1037, 30023},
    {(int32_t)0x40cd0b19, 30082},
    {(int32_t)0x40cdc0b4, 30120},
    {(int32_t)0x40d855e4, 30183},
    {(int32_t)0x41472b5b, 30224},
    {(int32_t)0x415d802d, 30268},
    {(int32_t)0x4199e5da, 30323},
    {(int32_t)0x41bf2fa7, 30367},
    {(int32_t)0x4219ce13, 30405},
    {(int32_t)0x4261b092, 30443},
    {(int32_t)0x4271272b, 30502},
    {(int32_t)0x4281a929, 30551},
    {(int32_t)0x42a922c5, 30613},
    {(int32_t)0x43461509, 30646},
    {(int32_t)0x435260a8, 30695},
    {(int32_t)0x438d6970, 30736},
    {(int32_t)0x43ea98d5, 30781},
    {(int32_t)0x444b3c08, 30801},
    {(int32_t)0x4450e4bf, 30852},
    {(int32_t)0x44f2ddc3, 30884},
    {(int32_t)0x45995670, 30923},
    {(int32_t)0x459e0091, 30965},
    {(int32_t)0x45f41192, 31020},
    {(int32_t)0x46081055, 31074},
    {(int32_t)0x466f254d, 31116},
    {(int32_t)0x4697094b, 31157},
    {(int32_t)0x479697e6, 31183},
    {(int32_t)0x47a4a839, 31209},
    {(int32_t)0x47cf378f, 31260},
    {(int32_t)0x47f7fd62, 31303},
    {(int32_t)0x481adf95, 31335},
    {(int32_t)0x486e9ec7, 31369},
    {(int32_t)0x48b263c8, 31383},
    {(int32_t)0x49152abd, 31409},
    {(int32_t)0x49391fa8, 31451},
    {(int32_t)0x49581c53, 31488},
    {(int32_t)0x496da402, 31527},
    {(int32_t)0x4a04b49a, 31572},
    {(int32_t)0x4a90394d, 31645},
    {(int32_t)0x4aa7363e, 31687},
    {(int32_t)0x4aeb3c30, 31725},
    {(int32_t)0x4b4ad3eb, 31784},
    {(int32_t)0x4b4ff7f9, 31847},
    {(int32_t)0x4bc2a414, 31879},
    {(int32_t)0x4bf24475, 31908},
    {(int32_t)0x4c493829, 31980},
    {(int32_t)0x4c5df270, 32008},
    {(int32_t)0x4ceb7e2f, 32035},
    {(int32_t)0x4cf4dc26, 32064},
    {(int32_t)0x4d66ed5c, 32107},
    {(int32_t)0x4d9e32d1, 32164},
    {(int32_t)0x4dc70db6, 32210},
    {(int32_t)0x4e013e4f, 32249},
    {(int32_t)0x4e061e08, 32289},
    {(int32_t)0x4e1def96, 32336},
    {(int32_t)0x4f822e35, 32375},
    {(int32_t)0x4f837c26, 32401},
    {(int32_t)0x4fd88fbd, 32436},
    {(int32_t)0x501214a2, 32468},
    {(int32_t)0x504523b9, 32500},
    {(int32_t)0x510bb26a, 32548},
    {(int32_t)0x511fc2e1, 32583},
    {(int32_t)0x5123f80c, 32626},
    {(int32_t)0x51e3c528, 32668},
    {(int32_t)0x520973ae, 32704},
    {(int32_t)0x5239264e, 32740},
    {(int32_t)0x52433039, 32812},
    {(int32_t)0x52c14e5f, 32836},
    {(int32_t)0x53b8afb8, 32885},
    {(int32_t)0x540f6860, 32923},
    {(int32_t)0x54279a2e, 32973},
    {(int32_t)0x5474cbda, 33001},
    {(int32_t)0x547799f3, 33045},
    {(int32_t)0x54cc80d9, 33067},
    {(int32_t)0x550c1a6e, 33118},
    {(int32_t)0x55387f90, 33169},
    {(int32_t)0x5541bbdf, 33210},
    {(int32_t)0x555e5c99, 33277},
    {(int32_t)0x5607474b, 33320},
    {(int32_t)0x56d65dd5, 33338},
    {(int32_t)0x5724a932, 33414},
    {(int32_t)0x57b1a9a2, 33445},
    {(int32_t)0x58579bc2, 33480},
    {(int32_t)0x58fc0a00, 33512},
    {(int32_t)0x594626ce, 33559},
    {(int32_t)0x595d640d, 33606},
    {(int32_t)0x59bec2a2, 33655},
    {(int32_t)0x59e94eb6, 33683},
    {(int32_t)0x5ac6821d, 33726},
    {(int32_t)0x5ade6b35, 33745},
    {(int32_t)0x5b1f536a, 33790},
    {(int32_t)0x5b448a73, 33837},
    {(int32_t)0x5b786ef7, 33876},
    {(int32_t)0x5c49a405, 33929},
    {(int32_t)0x5c9f29a3, 33977},
    {(int32_t)0x5cbd45c8, 34009},
    {(int32_t)0x5cd504e7, 34059},
    {(int32_t)0x5ce02966, 34087},
    {(int32_t)0x5e1b624e, 34119},
    {(int32_t)0x5e3d34fb, 34149},
    {(int32_t)0x5ec2aeb5, 34196},
    {(int32_t)0x5ec5229d, 34217},
    {(int32_t)0x5f0c50e6, 34236},
    {(int32_t)0x603a91fd, 34279},
    {(int32_t)0x6073413d, 34311},
    {(int32_t)0x607c2fed, 34370},
    {(int32_t)0x60c9a4c9, 34411},
    {(int32_t)0x60d4dc4b, 34433},
    {(int32_t)0x619cd093, 34477},
    {(int32_t)0x61bc1078, 34540},
    {(int32_t)0x61d50df8, 34575},
    {(int32_t)0x62bdefab, 34622},
    {(int32_t)0x6308487a, 34662},
    {(int32_t)0x633036a6, 34711},
    {(int32_t)0x633f7034, 34771},
    {(int32_t)0x634056b1, 34807},
    {(int32_t)0x636ee2e7, 34847},
    {(int32_t)0x63e203c3, 34900},
    {(int32_t)0x63e2a3d6, 34961},
    {(int32_t)0x6593964b, 35001},
    {(int32_t)0x65a56615, 35031},
    {(int32_t)0x65f82ade, 35059},
    {(int32_t)0x65fc818b, 35079},
    {(int32_t)0x66a0cead, 35113},
    {(int32_t)0x66e410be, 35153},
    {(int32_t)0x6777387a, 35187},
    {(int32_t)0x680cae7d, 35236},
    {(int32_t)0x681b516f, 35289},
    {(int32_t)0x682804d9, 35324},
    {(int32_t)0x68791032, 35367},
    {(int32_t)0x6981e335, 35423},
    {(int32_t)0x69bacaad, 35451},
    {(int32_t)0x69f0e6a7, 35488},
    {(int32_t)0x6a09a1dd, 35543},
    {(int32_t)0x6aeb6663, 35586},
    {(int32_t)0x6af6515a, 35630},
    {(int32_t)0x6af79000, 35654},
    {(int32_t)0x6c3e5402, 35707},
    {(int32_t)0x6c3f60ce, 35744},
    {(int32_t)0x6c89a49e, 35787},
    {(int32_t)0x6cd67c9d, 35846},
    {(int32_t)0x6cdf9cef, 35897},
    {(int32_t)0x6d0b2f31, 35923},
    {(int32_t)0x6d912019, 35939},
    {(int32_t)0x6dbcb651, 35961},
    {(int32_t)0x6dd689a2, 36001},
    {(int32_t)0x6e017378, 36068},
    {(int32_t)0x6e120a40, 36104},
    {(int32_t)0x6e4122d1, 36126},
    {(int32_t)0x6e41eb76, 36161},
    {(int32_t)0x6f27310a, 36191},
    {(int32_t)0x6f2d94b4, 36218},
    {(int32_t)0x6f7a8174, 36252},
    {(int32_t)0x7028cf80, 36284},
    {(int32_t)0x702954ac, 36326},
    {(int32_t)0x707d30ef, 36365},
    {(int32_t)0x70c6e7b8, 36405},
    {(int32_t)0x70e9b2f1, 36462},
    {(int32_t)0x715d66ad, 36509},
    {(int32_t)0x7173d1c5, 36539},
    {(int32_t)0x717ef6b0, 36584},
    {(int32_t)0x71fb54fe, 36610},
    {(int32_t)0x72175418, 36663},
    {(int32_t)0x72760d0c, 36705},
    {(int32_t)0x72e6b074, 36751},
    {(int32_t)0x732822ea, 36787},
    {(int32_t)0x734e21b8, 36834},
    {(int32_t)0x73580e6f, 36887},
    {(int32_t)0x73802d72, 36930},
    {(int32_t)0x73b60230, 36970},
    {(int32_t)0x73f323cd, 37045},
    {(int32_t)0x744c7232, 37079},
    {(int32_t)0x748f99f5, 37096},
    {(int32_t)0x74bff34a, 37161},
    {(int32_t)0x752f4484, 37214},
    {(int32_t)0x753ccb0e, 37273},
    {(int32_t)0x75d38a0e, 37314},
    {(int32_t)0x7613c945, 37334},
    {(int32_t)0x76470753, 37376},
    {(int32_t)0x76680a3c, 37423},
    {(int32_t)0x76735d3a, 37482},
    {(int32_t)0x76b1effa, 37543},
    {(int32_t)0x7731806e, 37578},
    {(int32_t)0x777e7e3c, 37618},
    {(int32_t)0x7783ed5e, 37641},
    {(int32_t)0x77a1ed5b, 37689},
    {(int32_t)0x77a94375, 37747},
    {(int32_t)0x77aac145, 37774},
    {(int32_t)0x78cd1dc2, 37814},
    {(int32_t)0x790f5df6, 37841},
    {(int32_t)0x79437952, 37892},
    {(int32_t)0x7b09fcdf, 37941},
    {(int32_t)0x7b38c3eb, 37967},
    {(int32_t)0x7b78b06f, 38002},
    {(int32_t)0x7b8fe314, 38048},
    {(int32_t)0x7bed2cb4, 38085},
    {(int32_t)0x7c12a91a, 38141},
    {(int32_t)0x7c339028, 38165},
    {(int32_t)0x7c9dd24f, 38214},
    {(int32_t)0x7d4b68cc, 38247},
    {(int32_t)0x7d899940, 38284},
    {(int32_t)0x7d9bdd68, 38323},
    {(int32_t)0x7e1f1857, 38372},
    {(int32_t)0x7e51df4f, 38399},
    {(int32_t)0x7e543f1e, 38441},
    {(int32_t)0x7e714bf1, 38490},
    {(int32_t)0x7e8654c8, 38542},
    {(int32_t)0x7fbaefc2, 38562},
    {(int32_t)0x7fec1b13, 38616},
};

static const TLMetaClassEntry TLMetaVectorClassEntries[] =
{
    {(int32_t)0x81b9f1ab, 38653},
    {(int32_t)0x81cd6c31, 38670},
    {(int32_t)0x82c42ce6, 38693},
    {(int32_t)0x83dcef33, 38709},
    {(int32_t)0x8f88f766, 38730},
    {(int32_t)0x9a285989, 38750},
    {(int32_t)0x9c1bfedd, 38771},
    {(int32_t)0x9f8a6a9b, 38800},
    {(int32_t)0xa03855ae, 38820},
    {(int32_t)0xa50ca301, 38832},
    {(int32_t)0xa76738ed, 38855},
    {(int32_t)0xa7e59f42, 38885},
    {(int32_t)0xa830f459, 38898},
    {(int32_t)0xb446828f, 38920},
    {(int32_t)0xb65e5bee, 38933},
    {(int32_t)0xb9248009, 38956},
    {(int32_t)0xc734a64e, 38974},
    {(int32_t)0xc98c1f96, 38987},
    {(int32_t)0xcad178a3, 39006},
    {(int32_t)0xce91f80a, 39023},
    {(int32_t)0xd4328679, 39047},
    {(int32_t)0xdb906104, 39073},
    {(int32_t)0xdd3d2416, 39092},
    {(int32_t)0xdebfa479, 39116},
    {(int32_t)0xe02ac2e9, 39138},
    {(int32_t)0xe5b01a50, 39163},
    {(int32_t)0xebe3b36d, 39186},
    {(int32_t)0xf14b7870, 39201},
    {(int32_t)0xf1846a37, 39224},
    {(int32_t)0xf1fb56bc, 39250},
    {(int32_t)0xf66f264a, 39275},
    {(int32_t)0xf7c22b5c, 39294},
    {(int32_t)0xf86deba5, 39323},
    {(int32_t)0xf883ea68, 39343},
    {(int32_t)0x07315861, 39368},
    {(int32_t)0x07c8e948, 39386},
    {(int32_t)0x0a250bcb, 39409},
    {(int32_t)0x11c6d700, 39425},
    {(int32_t)0x125b08dc, 39442},
    {(int32_t)0x150bc354, 39459},
    {(int32_t)0x157a8c0e, 39483},
    {(int32_t)0x16159df8, 39506},
    {(int32_t)0x170924ec, 39527},
    {(int32_t)0x22b50957, 39542},
    {(int32_t)0x2bc1a2d6, 39556},
    {(int32_t)0x36e5fd79, 39572},
    {(int32_t)0x3781ad9d, 39593},
    {(int32_t)0x37d14aa4, 39614},
    {(int32_t)0x3e274d79, 39638},
    {(int32_t)0x400aaf33, 39651},
    {(int32_t)0x4562eb2c, 39668},
    {(int32_t)0x4afd47b6, 39695},
    {(int32_t)0x580b5534, 39714},
    {(int32_t)0x587a3f02, 39732},
    {(int32_t)0x5bb17106, 39754},
    {(int32_t)0x5ccdb726, 39779},
    {(int32_t)0x5f18aac6, 39805},
    {(int32_t)0x651abfef, 39826},
    {(int32_t)0x651d9050, 39841},
    {(int32_t)0x657c9d2b, 39864},
    {(int32_t)0x66e25899, 39882},
    {(int32_t)0x6ddd8116, 39904},
    {(int32_t)0x6ef4189f, 39930},
    {(int32_t)0x789987fd, 39954},
    {(int32_t)0x78a0f60f, 39972},
    {(int32_t)0x7933169d, 39988},
    {(int32_t)0x7f3dd14a, 40006},
};

static const TLMetaClassTable TLMetaClassTableInstance =
{
    TLMetaClassNames,
    TLMetaObjectClassEntries,
    (uint32_t)(sizeof(TLMetaObjectClassEntries) / sizeof(TLMetaObjectClassEntries[0])),
    TLMetaVectorClassEntries,
    (uint32_t)(sizeof(TLMetaVectorClassEntries) / sizeof(TLMetaVectorClassEntries[0]))
};

const TLMetaClassTable *TLgetMetaClassTable()
{
    return &TLMetaClassTableInstance;
}
