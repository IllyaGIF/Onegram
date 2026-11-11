#ifndef OG_COMPAT_CONTACTS_H
#define OG_COMPAT_CONTACTS_H

#import <Foundation/Foundation.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
#import <Contacts/CNContact.h>
#import <Contacts/CNContactFormatter.h>
#import <Contacts/CNContactVCardSerialization.h>
#import <Contacts/CNLabeledValue.h>
#import <Contacts/CNMutableContact.h>
#import <Contacts/CNPhoneNumber.h>
#import <Contacts/CNMutablePostalAddress.h>
#import <Contacts/CNContactProperty.h>
#import <Contacts/CNContactStore.h>
#import <Contacts/CNGroup.h>
#import <Contacts/CNContainer.h>
#else

typedef NSInteger CNContactFormatterStyle;
#define CNContactFormatterStyleFullName 0

@interface CNPhoneNumber : NSObject
@property (nonatomic, copy) NSString *stringValue;
+ (instancetype)phoneNumberWithStringValue:(NSString *)stringValue;
- (instancetype)initWithStringValue:(NSString *)stringValue;
@end

@interface CNLabeledValue : NSObject
@property (nonatomic, copy) NSString *label;
@property (nonatomic, retain) id value;
+ (instancetype)labeledValueWithLabel:(NSString *)label value:(id)value;
@end

@interface CNMutablePostalAddress : NSObject
@property (nonatomic, copy) NSString *street;
@property (nonatomic, copy) NSString *city;
@property (nonatomic, copy) NSString *state;
@property (nonatomic, copy) NSString *postalCode;
@property (nonatomic, copy) NSString *country;
@property (nonatomic, copy) NSString *ISOCountryCode;
@end

@interface CNMutableContact : NSObject
@property (nonatomic, copy) NSString *givenName;
@property (nonatomic, copy) NSString *familyName;
@property (nonatomic, copy) NSArray *phoneNumbers;
@property (nonatomic, copy) NSArray *postalAddresses;
@end

@interface CNContactVCardSerialization : NSObject
+ (NSData *)dataWithContacts:(NSArray *)contacts error:(NSError **)error;
@end

@interface CNContactFormatter : NSObject
+ (NSString *)stringFromContact:(CNMutableContact *)contact style:(CNContactFormatterStyle)style;
@end

#endif

#endif
