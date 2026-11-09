#import <Foundation/Foundation.h>

@class SSignal;

typedef enum {
    TGOnegramTranslatorProviderGoogle = 0,
    TGOnegramTranslatorProviderMicrosoft = 1,
    TGOnegramTranslatorProviderDeepL = 2,
    TGOnegramTranslatorProviderLLM = 3
} TGOnegramTranslatorProvider;

@interface TGOnegramTranslation : NSObject

@property (nonatomic, readonly) NSString *text;
@property (nonatomic, readonly) NSString *sourceLanguage;
@property (nonatomic, readonly) NSString *targetLanguage;

@end

@interface TGOnegramTranslator : NSObject

+ (NSArray *)providerTitles;
+ (NSArray *)languageCodes;
+ (NSString *)displayNameForLanguage:(NSString *)code;
+ (NSString *)targetLanguage;
+ (NSString *)detectedLanguageForText:(NSString *)text;
+ (bool)shouldOfferTranslationForText:(NSString *)text;

+ (SSignal *)translateText:(NSString *)text;

@end
