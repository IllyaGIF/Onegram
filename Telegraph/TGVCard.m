#import "TGVCard.h"

@interface TGVCardValue ()
{
@protected
    ABPropertyID _property;
}

- (void)writeValueInPerson:(ABRecordRef)person;

@end

@implementation TGVCardValue

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        arc4random_buf(&_uniqueId, sizeof(int64_t));
    }
    return self;
}

- (ABPropertyID)property
{
    return _property;
}

- (void)writeValueInPerson:(ABRecordRef)__unused person
{
}

@end

@implementation TGVCardValueString

- (instancetype)initWithProperty:(ABPropertyID)property string:(NSString *)string
{
    self = [super init];
    if (self != nil)
    {
        _property = property;
        _value = string;
    }
    return self;
}

- (void)writeValueInPerson:(ABRecordRef)person
{
    if (_value.length > 0)
        ABRecordSetValue(person, _property, (__bridge CFTypeRef)(_value), NULL);
}

@end

@implementation TGVCardValueDate

- (instancetype)initWithProperty:(ABPropertyID)property date:(NSDate *)date
{
    self = [super init];
    if (self != nil)
    {
        _property = property;
        _value = date;
    }
    return self;
}

- (void)writeValueInPerson:(ABRecordRef)person
{
    if (_value != nil)
        ABRecordSetValue(person, _property, (__bridge CFTypeRef)(_value), NULL);
}

@end

@implementation TGVCardValueArrayItem

- (instancetype)initWithLabel:(NSString *)label value:(id)value
{
    self = [super init];
    if (self != nil)
    {
        arc4random_buf(&_uniqueId, sizeof(int64_t));
        _label = label;
        _value = value;
    }
    return self;
}

@end

@implementation TGVCardValueArray

- (instancetype)initWithProperty:(ABPropertyID)property values:(NSArray *)values objectType:(Class)objectType
{
    self = [super init];
    if (self != nil)
    {
        _property = property;
        _values = values;
        _objectType = objectType;
    }
    return self;
}

- (void)writeValueInPerson:(ABRecordRef)person
{
    if (_values.count > 0) {
        ABMutableMultiValueRef multiValue = ABMultiValueCreateMutable(_objectType == [NSString class] ? kABMultiStringPropertyType : kABMultiDictionaryPropertyType);
        
        for (TGVCardValueArrayItem *value in _values) {
            ABMultiValueAddValueAndLabel(multiValue, (__bridge CFTypeRef)(value.value), (__bridge CFStringRef)(value.label), NULL);
        };
        ABRecordSetValue(person, _property, multiValue, nil);
        
        CFRelease(multiValue);
    }
}

@end

static NSString *TGVCardEscapeString(NSString *string)
{
    if (string.length == 0)
        return @"";

    NSString *result = [string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    result = [result stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\\n"];
    result = [result stringByReplacingOccurrencesOfString:@"\r" withString:@"\\n"];
    result = [result stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    result = [result stringByReplacingOccurrencesOfString:@";" withString:@"\\;"];
    result = [result stringByReplacingOccurrencesOfString:@"," withString:@"\\,"];
    return result;
}

static NSString *TGVCardUnescapeString(NSString *string)
{
    if (string.length == 0)
        return @"";

    NSMutableString *result = [[NSMutableString alloc] init];
    NSUInteger length = string.length;
    for (NSUInteger i = 0; i < length; i++)
    {
        unichar c = [string characterAtIndex:i];
        if (c == '\\' && i + 1 < length)
        {
            unichar n = [string characterAtIndex:++i];
            if (n == 'n' || n == 'N')
                [result appendString:@"\n"];
            else
                [result appendFormat:@"%C", n];
        }
        else
        {
            [result appendFormat:@"%C", c];
        }
    }
    return result;
}

static NSArray *TGVCardSplitEscapedString(NSString *string, unichar separator)
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSMutableString *current = [[NSMutableString alloc] init];
    bool escaped = false;
    for (NSUInteger i = 0; i < string.length; i++)
    {
        unichar c = [string characterAtIndex:i];
        if (escaped)
        {
            [current appendString:@"\\"];
            [current appendFormat:@"%C", c];
            escaped = false;
        }
        else if (c == '\\')
        {
            escaped = true;
        }
        else if (c == separator)
        {
            [result addObject:[current copy]];
            [current setString:@""];
        }
        else
        {
            [current appendFormat:@"%C", c];
        }
    }
    if (escaped)
        [current appendString:@"\\"];
    [result addObject:[current copy]];
    return result;
}

static int TGVCardHexValue(unichar c)
{
    if (c >= '0' && c <= '9')
        return (int)(c - '0');
    if (c >= 'a' && c <= 'f')
        return (int)(c - 'a' + 10);
    if (c >= 'A' && c <= 'F')
        return (int)(c - 'A' + 10);
    return -1;
}

static NSString *TGVCardDecodeQuotedPrintable(NSString *string, NSString *charset)
{
    NSMutableData *data = [[NSMutableData alloc] init];
    NSData *utf8 = [string dataUsingEncoding:NSUTF8StringEncoding];
    const uint8_t *bytes = utf8.bytes;
    NSUInteger length = utf8.length;
    for (NSUInteger i = 0; i < length; i++)
    {
        if (bytes[i] == '=' && i + 2 < length)
        {
            int high = TGVCardHexValue((unichar)bytes[i + 1]);
            int low = TGVCardHexValue((unichar)bytes[i + 2]);
            if (high >= 0 && low >= 0)
            {
                uint8_t value = (uint8_t)((high << 4) | low);
                [data appendBytes:&value length:1];
                i += 2;
                continue;
            }
        }
        [data appendBytes:&bytes[i] length:1];
    }

    NSStringEncoding encoding = NSUTF8StringEncoding;
    if (charset.length > 0)
    {
        CFStringEncoding cfEncoding = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)charset);
        if (cfEncoding != kCFStringEncodingInvalidId)
            encoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
    }

    NSString *result = [[NSString alloc] initWithData:data encoding:encoding];
    if (result == nil && encoding != NSISOLatin1StringEncoding)
        result = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    return result == nil ? @"" : result;
}

static NSData *TGVCardDecodeBase64String(NSString *string)
{
    static const signed char table[256] = {
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,62,-1,-1,-1,63,
        52,53,54,55,56,57,58,59,60,61,-1,-1,-1,-2,-1,-1,
        -1,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,
        15,16,17,18,19,20,21,22,23,24,25,-1,-1,-1,-1,-1,
        -1,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,
        41,42,43,44,45,46,47,48,49,50,51,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    };

    NSData *ascii = [string dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:true];
    const uint8_t *input = ascii.bytes;
    NSMutableData *output = [[NSMutableData alloc] init];
    int value = 0;
    int bits = -8;
    for (NSUInteger i = 0; i < ascii.length; i++)
    {
        signed char decoded = table[input[i]];
        if (decoded == -2)
            break;
        if (decoded < 0)
            continue;
        value = (value << 6) | decoded;
        bits += 6;
        if (bits >= 0)
        {
            uint8_t byte = (uint8_t)((value >> bits) & 0xff);
            [output appendBytes:&byte length:1];
            bits -= 8;
        }
    }
    return output;
}

static NSString *TGVCardEncodeBase64Data(NSData *data)
{
    static const char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const uint8_t *bytes = data.bytes;
    NSUInteger length = data.length;
    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:((length + 2) / 3) * 4];
    for (NSUInteger i = 0; i < length; i += 3)
    {
        uint32_t value = (uint32_t)bytes[i] << 16;
        if (i + 1 < length)
            value |= (uint32_t)bytes[i + 1] << 8;
        if (i + 2 < length)
            value |= bytes[i + 2];
        [result appendFormat:@"%c%c%c%c", table[(value >> 18) & 63], table[(value >> 12) & 63], i + 1 < length ? table[(value >> 6) & 63] : '=', i + 2 < length ? table[value & 63] : '='];
    }
    return result;
}

static NSArray *TGVCardEntriesFromString(NSString *string)
{
    NSString *normalized = [string stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    NSArray *physicalLines = [normalized componentsSeparatedByString:@"\n"];
    NSMutableArray *logicalLines = [[NSMutableArray alloc] init];
    for (NSString *line in physicalLines)
    {
        if (line.length > 0 && ([line characterAtIndex:0] == ' ' || [line characterAtIndex:0] == '\t') && logicalLines.count > 0)
        {
            NSString *previous = [logicalLines lastObject];
            [logicalLines removeLastObject];
            [logicalLines addObject:[previous stringByAppendingString:[line substringFromIndex:1]]];
        }
        else if (logicalLines.count > 0 && [[logicalLines lastObject] hasSuffix:@"="])
        {
            NSString *previous = [logicalLines lastObject];
            [logicalLines removeLastObject];
            [logicalLines addObject:[[previous substringToIndex:previous.length - 1] stringByAppendingString:line]];
        }
        else
        {
            [logicalLines addObject:line];
        }
    }

    NSMutableArray *entries = [[NSMutableArray alloc] init];
    for (NSString *line in logicalLines)
    {
        NSRange colonRange = [line rangeOfString:@":"];
        if (colonRange.location == NSNotFound)
            continue;

        NSString *header = [line substringToIndex:colonRange.location];
        NSString *value = [line substringFromIndex:colonRange.location + 1];
        NSArray *headerComponents = [header componentsSeparatedByString:@";"];
        if (headerComponents.count == 0)
            continue;

        NSString *nameComponent = headerComponents[0];
        NSString *group = nil;
        NSString *name = nameComponent;
        NSRange dotRange = [nameComponent rangeOfString:@"." options:NSBackwardsSearch];
        if (dotRange.location != NSNotFound)
        {
            group = [nameComponent substringToIndex:dotRange.location];
            name = [nameComponent substringFromIndex:dotRange.location + 1];
        }
        name = name.uppercaseString;

        NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
        for (NSUInteger i = 1; i < headerComponents.count; i++)
        {
            NSString *component = headerComponents[i];
            NSRange equalRange = [component rangeOfString:@"="];
            NSString *key = @"TYPE";
            NSString *parameterValue = component;
            if (equalRange.location != NSNotFound)
            {
                key = [[component substringToIndex:equalRange.location] uppercaseString];
                parameterValue = [component substringFromIndex:equalRange.location + 1];
            }
            if ([parameterValue hasPrefix:@"\""] && [parameterValue hasSuffix:@"\""] && parameterValue.length >= 2)
                parameterValue = [parameterValue substringWithRange:NSMakeRange(1, parameterValue.length - 2)];
            NSArray *parts = [parameterValue componentsSeparatedByString:@","];
            NSMutableArray *values = [parameters objectForKey:key];
            if (values == nil)
            {
                values = [[NSMutableArray alloc] init];
                [parameters setObject:values forKey:key];
            }
            for (NSString *part in parts)
            {
                if (part.length > 0)
                    [values addObject:part];
            }
        }

        [entries addObject:@{ @"name": name, @"group": group == nil ? @"" : group, @"parameters": parameters, @"value": value }];
    }
    return entries;
}

static NSString *TGVCardDecodedEntryValue(NSDictionary *entry)
{
    NSDictionary *parameters = [entry objectForKey:@"parameters"];
    NSArray *encodings = [parameters objectForKey:@"ENCODING"];
    NSString *value = [entry objectForKey:@"value"];
    for (NSString *encoding in encodings)
    {
        if ([encoding caseInsensitiveCompare:@"QUOTED-PRINTABLE"] == NSOrderedSame)
        {
            NSArray *charsets = [parameters objectForKey:@"CHARSET"];
            NSString *charset = charsets.count == 0 ? nil : [charsets objectAtIndex:0];
            return TGVCardDecodeQuotedPrintable(value, charset);
        }
    }
    return value;
}

static NSString *TGVCardLabelForEntry(NSDictionary *entry, NSDictionary *groupLabels, ABPropertyID property)
{
    NSString *group = [entry objectForKey:@"group"];
    NSString *groupLabel = [groupLabels objectForKey:group];
    if (groupLabel.length > 0)
        return groupLabel;

    NSDictionary *parameters = [entry objectForKey:@"parameters"];
    NSArray *types = [parameters objectForKey:@"TYPE"];
    for (NSString *typeValue in types)
    {
        NSString *type = typeValue.uppercaseString;
        if ([type isEqualToString:@"HOME"])
            return (__bridge NSString *)kABHomeLabel;
        if ([type isEqualToString:@"WORK"])
            return (__bridge NSString *)kABWorkLabel;
        if ([type isEqualToString:@"CELL"] || [type isEqualToString:@"MOBILE"])
            return property == kABPersonPhoneProperty ? (__bridge NSString *)kABPersonPhoneMobileLabel : (__bridge NSString *)kABOtherLabel;
        if ([type isEqualToString:@"IPHONE"])
            return property == kABPersonPhoneProperty ? (__bridge NSString *)kABPersonPhoneIPhoneLabel : (__bridge NSString *)kABOtherLabel;
        if ([type isEqualToString:@"MAIN"])
            return property == kABPersonPhoneProperty ? (__bridge NSString *)kABPersonPhoneMainLabel : (__bridge NSString *)kABOtherLabel;
        if (![type isEqualToString:@"VOICE"] && ![type isEqualToString:@"INTERNET"] && ![type isEqualToString:@"PREF"])
            return typeValue;
    }
    return (__bridge NSString *)kABOtherLabel;
}

static NSString *TGVCardTypeForLabel(NSString *label, ABPropertyID property, bool *custom)
{
    if (custom != NULL)
        *custom = false;
    if (label.length == 0)
        return @"OTHER";

    NSString *lower = label.lowercaseString;
    if ([lower rangeOfString:@"mobile"].location != NSNotFound || [lower rangeOfString:@"cell"].location != NSNotFound)
        return property == kABPersonPhoneProperty ? @"CELL" : @"OTHER";
    if ([lower rangeOfString:@"iphone"].location != NSNotFound)
        return property == kABPersonPhoneProperty ? @"IPHONE" : @"OTHER";
    if ([lower rangeOfString:@"main"].location != NSNotFound)
        return property == kABPersonPhoneProperty ? @"MAIN" : @"OTHER";
    if ([lower rangeOfString:@"home"].location != NSNotFound)
        return @"HOME";
    if ([lower rangeOfString:@"work"].location != NSNotFound)
        return @"WORK";
    if ([lower rangeOfString:@"other"].location != NSNotFound)
        return @"OTHER";

    if (custom != NULL)
        *custom = true;
    return @"OTHER";
}

static void TGVCardAppendLabeledValue(NSMutableString *result, NSString *name, ABPropertyID property, TGVCardValueArrayItem *item, NSUInteger *itemIndex, NSString *value)
{
    bool custom = false;
    NSString *type = TGVCardTypeForLabel(item.label, property, &custom);
    if (custom)
    {
        NSString *group = [NSString stringWithFormat:@"item%lu", (unsigned long)(*itemIndex)++];
        [result appendFormat:@"%@.%@;TYPE=%@:%@\r\n", group, name, type, TGVCardEscapeString(value)];
        [result appendFormat:@"%@.X-ABLabel:%@\r\n", group, TGVCardEscapeString(item.label)];
    }
    else
    {
        [result appendFormat:@"%@;TYPE=%@:%@\r\n", name, type, TGVCardEscapeString(value)];
    }
}

static NSString *TGVCardSerialize(TGVCard *card, ABRecordRef person)
{
    NSMutableString *result = [[NSMutableString alloc] init];
    [result appendString:@"BEGIN:VCARD\r\nVERSION:3.0\r\n"];

    NSString *firstName = card.firstName.value ?: @"";
    NSString *lastName = card.lastName.value ?: @"";
    NSString *middleName = card.middleName.value ?: @"";
    NSString *prefix = card.prefix.value ?: @"";
    NSString *suffix = card.suffix.value ?: @"";
    [result appendFormat:@"N:%@;%@;%@;%@;%@\r\n", TGVCardEscapeString(lastName), TGVCardEscapeString(firstName), TGVCardEscapeString(middleName), TGVCardEscapeString(prefix), TGVCardEscapeString(suffix)];

    NSMutableArray *formattedName = [[NSMutableArray alloc] init];
    if (prefix.length > 0)
        [formattedName addObject:prefix];
    if (firstName.length > 0)
        [formattedName addObject:firstName];
    if (middleName.length > 0)
        [formattedName addObject:middleName];
    if (lastName.length > 0)
        [formattedName addObject:lastName];
    if (suffix.length > 0)
        [formattedName addObject:suffix];
    NSString *fn = [formattedName componentsJoinedByString:@" "];
    if (fn.length == 0)
        fn = card.organization.value.length > 0 ? card.organization.value : @"Unnamed";
    [result appendFormat:@"FN:%@\r\n", TGVCardEscapeString(fn)];

    if (card.organization.value.length > 0 || card.department.value.length > 0)
        [result appendFormat:@"ORG:%@;%@\r\n", TGVCardEscapeString(card.organization.value ?: @""), TGVCardEscapeString(card.department.value ?: @"")];
    if (card.jobTitle.value.length > 0)
        [result appendFormat:@"TITLE:%@\r\n", TGVCardEscapeString(card.jobTitle.value)];

    NSUInteger itemIndex = 1;
    for (TGVCardValueArrayItem *item in card.phones.values)
        TGVCardAppendLabeledValue(result, @"TEL", kABPersonPhoneProperty, item, &itemIndex, item.value);
    for (TGVCardValueArrayItem *item in card.emails.values)
        TGVCardAppendLabeledValue(result, @"EMAIL", kABPersonEmailProperty, item, &itemIndex, item.value);
    for (TGVCardValueArrayItem *item in card.urls.values)
        TGVCardAppendLabeledValue(result, @"URL", kABPersonURLProperty, item, &itemIndex, item.value);

    for (TGVCardValueArrayItem *item in card.addresses.values)
    {
        NSDictionary *address = item.value;
        NSArray *parts = @[ [address objectForKey:@"PO Box"] ?: @"", [address objectForKey:@"Extended"] ?: @"", [address objectForKey:@"Street"] ?: @"", [address objectForKey:@"City"] ?: @"", [address objectForKey:@"State"] ?: @"", [address objectForKey:@"ZIP"] ?: @"", [address objectForKey:@"Country"] ?: @"" ];
        NSMutableArray *escaped = [[NSMutableArray alloc] initWithCapacity:parts.count];
        for (NSString *part in parts)
            [escaped addObject:TGVCardEscapeString(part)];
        bool custom = false;
        NSString *type = TGVCardTypeForLabel(item.label, kABPersonAddressProperty, &custom);
        if (custom)
        {
            NSString *group = [NSString stringWithFormat:@"item%lu", (unsigned long)itemIndex++];
            [result appendFormat:@"%@.ADR;TYPE=%@:%@\r\n", group, type, [escaped componentsJoinedByString:@";"]];
            [result appendFormat:@"%@.X-ABLabel:%@\r\n", group, TGVCardEscapeString(item.label)];
        }
        else
        {
            [result appendFormat:@"ADR;TYPE=%@:%@\r\n", type, [escaped componentsJoinedByString:@";"]];
        }
    }

    if (card.birthday.value != nil)
    {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        formatter.dateFormat = @"yyyy-MM-dd";
        [result appendFormat:@"BDAY:%@\r\n", [formatter stringFromDate:card.birthday.value]];
    }

    for (TGVCardValueArrayItem *item in card.socialProfiles.values)
    {
        NSDictionary *profile = item.value;
        NSString *service = [profile objectForKey:@"service"] ?: @"";
        NSString *username = [profile objectForKey:@"username"] ?: @"";
        NSString *url = [profile objectForKey:@"url"] ?: @"";
        if (url.length == 0 && username.length > 0)
            url = username;
        [result appendFormat:@"X-SOCIALPROFILE;TYPE=%@;X-USER=%@:%@\r\n", TGVCardEscapeString(service), TGVCardEscapeString(username), TGVCardEscapeString(url)];
    }

    for (TGVCardValueArrayItem *item in card.instantMessengers.values)
    {
        NSDictionary *im = item.value;
        NSString *service = [im objectForKey:@"service"] ?: @"";
        NSString *username = [im objectForKey:@"username"] ?: @"";
        [result appendFormat:@"IMPP;X-SERVICE-TYPE=%@:%@\r\n", TGVCardEscapeString(service), TGVCardEscapeString(username)];
    }

    if (person != NULL)
    {
        CFDataRef imageDataRef = ABPersonCopyImageData(person);
        if (imageDataRef != NULL)
        {
            NSData *imageData = (__bridge NSData *)imageDataRef;
            if (imageData.length > 0)
                [result appendFormat:@"PHOTO;ENCODING=b:%@\r\n", TGVCardEncodeBase64Data(imageData)];
            CFRelease(imageDataRef);
        }
    }

    [result appendString:@"END:VCARD\r\n"];
    return result;
}

NSData *TGVCardDataFromPerson(ABRecordRef person)
{
    if (person == NULL)
        return nil;

    if (iosMajorVersion() >= 5)
    {
        NSArray *people = @[ (__bridge id)person ];
        CFDataRef dataRef = ABPersonCreateVCardRepresentationWithPeople((__bridge CFArrayRef)people);
        return dataRef == NULL ? nil : CFBridgingRelease(dataRef);
    }

    TGVCard *card = [[TGVCard alloc] initWithPerson:person];
    NSString *string = TGVCardSerialize(card, person);
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}

NSString *TGVCardStringFromPerson(ABRecordRef person)
{
    NSData *data = TGVCardDataFromPerson(person);
    if (data.length == 0)
        return nil;
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [string stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
}

static ABRecordRef TGVCardCreatePersonFromCard(TGVCard *card)
{
    if (card == nil)
        return NULL;

    ABRecordRef person = ABPersonCreate();
    if (card.firstName != nil)
        [card.firstName writeValueInPerson:person];
    if (card.lastName != nil)
        [card.lastName writeValueInPerson:person];
    if (card.middleName != nil)
        [card.middleName writeValueInPerson:person];
    if (card.prefix != nil)
        [card.prefix writeValueInPerson:person];
    if (card.suffix != nil)
        [card.suffix writeValueInPerson:person];
    if (card.organization != nil)
        [card.organization writeValueInPerson:person];
    if (card.jobTitle != nil)
        [card.jobTitle writeValueInPerson:person];
    if (card.department != nil)
        [card.department writeValueInPerson:person];
    if (card.phones != nil)
        [card.phones writeValueInPerson:person];
    if (card.emails != nil)
        [card.emails writeValueInPerson:person];
    if (card.urls != nil)
        [card.urls writeValueInPerson:person];
    if (card.addresses != nil)
        [card.addresses writeValueInPerson:person];
    if (card.birthday != nil)
        [card.birthday writeValueInPerson:person];
    if (iosMajorVersion() >= 5 && card.socialProfiles != nil)
        [card.socialProfiles writeValueInPerson:person];
    if (card.instantMessengers != nil)
        [card.instantMessengers writeValueInPerson:person];
    return person;
}

ABRecordRef TGVCardCreatePersonFromData(NSData *data)
{
    if (data.length == 0)
        return NULL;

    if (iosMajorVersion() >= 5)
    {
        ABAddressBookRef book = ABAddressBookCreate();
        ABRecordRef defaultSource = book == NULL ? NULL : ABAddressBookCopyDefaultSource(book);
        CFArrayRef people = ABPersonCreatePeopleInSourceWithVCardRepresentation(defaultSource, (__bridge CFDataRef)data);
        ABRecordRef person = NULL;
        if (people != NULL && CFArrayGetCount(people) > 0)
        {
            person = (ABRecordRef)CFArrayGetValueAtIndex(people, 0);
            if (person != NULL)
                CFRetain(person);
        }
        if (people != NULL)
            CFRelease(people);
        if (defaultSource != NULL)
            CFRelease(defaultSource);
        if (book != NULL)
            CFRelease(book);
        return person;
    }

    TGVCard *card = [[TGVCard alloc] initWithData:data];
    if (card == nil)
        return NULL;

    ABRecordRef person = TGVCardCreatePersonFromCard(card);
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string == nil)
        string = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (string.length > 0)
    {
        NSArray *entries = TGVCardEntriesFromString(string);
        for (NSDictionary *entry in entries)
        {
            if (![[entry objectForKey:@"name"] isEqualToString:@"PHOTO"])
                continue;

            NSDictionary *parameters = [entry objectForKey:@"parameters"];
            NSArray *encodings = [parameters objectForKey:@"ENCODING"];
            bool base64 = false;
            for (NSString *encoding in encodings)
            {
                if ([encoding caseInsensitiveCompare:@"B"] == NSOrderedSame || [encoding caseInsensitiveCompare:@"BASE64"] == NSOrderedSame)
                {
                    base64 = true;
                    break;
                }
            }
            if (base64)
            {
                NSData *imageData = TGVCardDecodeBase64String([entry objectForKey:@"value"]);
                if (imageData.length > 0)
                    ABPersonSetImageData(person, (__bridge CFDataRef)imageData, NULL);
            }
            break;
        }
    }
    return person;
}

@implementation TGVCard

- (instancetype)initWithString:(NSString *)string
{
    if (string.length == 0)
        return nil;
    
    return [self initWithData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (instancetype)initWithData:(NSData *)data
{
    if (iosMajorVersion() >= 5)
    {
        ABRecordRef person = TGVCardCreatePersonFromData(data);
        if (person == NULL)
            return nil;
        self = [self initWithPerson:person];
        CFRelease(person);
        return self;
    }

    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string == nil)
        string = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (string.length == 0)
        return nil;

    self = [super init];
    if (self == nil)
        return nil;

    NSArray *entries = TGVCardEntriesFromString(string);
    NSMutableDictionary *groupLabels = [[NSMutableDictionary alloc] init];
    for (NSDictionary *entry in entries)
    {
        NSString *entryName = [entry objectForKey:@"name"];
        NSString *entryGroup = [entry objectForKey:@"group"];
        if ([entryName isEqualToString:@"X-ABLABEL"] && entryGroup.length > 0)
            [groupLabels setObject:TGVCardUnescapeString(TGVCardDecodedEntryValue(entry)) forKey:entryGroup];
    }

    NSMutableArray *phones = [[NSMutableArray alloc] init];
    NSMutableArray *emails = [[NSMutableArray alloc] init];
    NSMutableArray *urls = [[NSMutableArray alloc] init];
    NSMutableArray *addresses = [[NSMutableArray alloc] init];
    NSMutableArray *socialProfiles = [[NSMutableArray alloc] init];
    NSMutableArray *instantMessengers = [[NSMutableArray alloc] init];
    NSString *formattedName = nil;

    for (NSDictionary *entry in entries)
    {
        NSString *name = [entry objectForKey:@"name"];
        NSString *rawValue = TGVCardDecodedEntryValue(entry);
        if ([name isEqualToString:@"N"])
        {
            NSArray *parts = TGVCardSplitEscapedString(rawValue, ';');
            NSString *(^part)(NSUInteger) = ^NSString *(NSUInteger index) {
                return index < parts.count ? TGVCardUnescapeString([parts objectAtIndex:index]) : @"";
            };
            NSString *last = part(0);
            NSString *first = part(1);
            NSString *middle = part(2);
            NSString *prefix = part(3);
            NSString *suffix = part(4);
            if (first.length > 0)
                _firstName = [[TGVCardValueString alloc] initWithProperty:kABPersonFirstNameProperty string:first];
            if (last.length > 0)
                _lastName = [[TGVCardValueString alloc] initWithProperty:kABPersonLastNameProperty string:last];
            if (middle.length > 0)
                _middleName = [[TGVCardValueString alloc] initWithProperty:kABPersonMiddleNameProperty string:middle];
            if (prefix.length > 0)
                _prefix = [[TGVCardValueString alloc] initWithProperty:kABPersonPrefixProperty string:prefix];
            if (suffix.length > 0)
                _suffix = [[TGVCardValueString alloc] initWithProperty:kABPersonSuffixProperty string:suffix];
        }
        else if ([name isEqualToString:@"FN"])
        {
            formattedName = TGVCardUnescapeString(rawValue);
        }
        else if ([name isEqualToString:@"ORG"])
        {
            NSArray *parts = TGVCardSplitEscapedString(rawValue, ';');
            if (parts.count > 0)
            {
                NSString *value = TGVCardUnescapeString([parts objectAtIndex:0]);
                if (value.length > 0)
                    _organization = [[TGVCardValueString alloc] initWithProperty:kABPersonOrganizationProperty string:value];
            }
            if (parts.count > 1)
            {
                NSString *value = TGVCardUnescapeString([parts objectAtIndex:1]);
                if (value.length > 0)
                    _department = [[TGVCardValueString alloc] initWithProperty:kABPersonDepartmentProperty string:value];
            }
        }
        else if ([name isEqualToString:@"TITLE"])
        {
            NSString *value = TGVCardUnescapeString(rawValue);
            if (value.length > 0)
                _jobTitle = [[TGVCardValueString alloc] initWithProperty:kABPersonJobTitleProperty string:value];
        }
        else if ([name isEqualToString:@"TEL"] || [name isEqualToString:@"EMAIL"] || [name isEqualToString:@"URL"])
        {
            ABPropertyID property = [name isEqualToString:@"TEL"] ? kABPersonPhoneProperty : ([name isEqualToString:@"EMAIL"] ? kABPersonEmailProperty : kABPersonURLProperty);
            NSString *value = TGVCardUnescapeString(rawValue);
            if (value.length > 0)
            {
                NSString *label = TGVCardLabelForEntry(entry, groupLabels, property);
                TGVCardValueArrayItem *item = [[TGVCardValueArrayItem alloc] initWithLabel:label value:value];
                NSMutableArray *target = [name isEqualToString:@"TEL"] ? phones : ([name isEqualToString:@"EMAIL"] ? emails : urls);
                [target addObject:item];
            }
        }
        else if ([name isEqualToString:@"ADR"])
        {
            NSArray *parts = TGVCardSplitEscapedString(rawValue, ';');
            NSMutableDictionary *address = [[NSMutableDictionary alloc] init];
            NSArray *keys = @[ @"PO Box", @"Extended", @"Street", @"City", @"State", @"ZIP", @"Country" ];
            for (NSUInteger i = 0; i < MIN(parts.count, keys.count); i++)
            {
                NSString *value = TGVCardUnescapeString([parts objectAtIndex:i]);
                if (value.length > 0)
                    [address setObject:value forKey:[keys objectAtIndex:i]];
            }
            if (address.count > 0)
            {
                NSString *label = TGVCardLabelForEntry(entry, groupLabels, kABPersonAddressProperty);
                [addresses addObject:[[TGVCardValueArrayItem alloc] initWithLabel:label value:address]];
            }
        }
        else if ([name isEqualToString:@"BDAY"])
        {
            NSString *value = TGVCardUnescapeString(rawValue);
            NSDate *date = nil;
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            NSArray *formats = @[ @"yyyy-MM-dd", @"yyyyMMdd" ];
            for (NSString *format in formats)
            {
                formatter.dateFormat = format;
                date = [formatter dateFromString:value];
                if (date != nil)
                    break;
            }
            if (date == nil && [value hasPrefix:@"--"] && value.length >= 6)
            {
                formatter.dateFormat = @"yyyy-MM-dd";
                date = [formatter dateFromString:[@"1604-" stringByAppendingString:[value substringFromIndex:2]]];
            }
            if (date != nil)
                _birthday = [[TGVCardValueDate alloc] initWithProperty:kABPersonBirthdayProperty date:date];
        }
        else if ([name isEqualToString:@"X-SOCIALPROFILE"])
        {
            NSDictionary *parameters = [entry objectForKey:@"parameters"];
            NSArray *typeValues = [parameters objectForKey:@"TYPE"];
            NSArray *userValues = [parameters objectForKey:@"X-USER"];
            NSString *service = typeValues.count == 0 ? nil : [typeValues objectAtIndex:0];
            NSString *username = userValues.count == 0 ? nil : [userValues objectAtIndex:0];
            NSString *url = TGVCardUnescapeString(rawValue);
            if (username.length == 0 && url.length > 0)
                username = url.lastPathComponent;
            NSMutableDictionary *profile = [[NSMutableDictionary alloc] init];
            if (service.length > 0)
                [profile setObject:service.lowercaseString forKey:@"service"];
            if (username.length > 0)
                [profile setObject:username forKey:@"username"];
            if (url.length > 0)
                [profile setObject:url forKey:@"url"];
            if (profile.count > 0)
                [socialProfiles addObject:[[TGVCardValueArrayItem alloc] initWithLabel:(__bridge NSString *)kABOtherLabel value:profile]];
        }
        else if ([name isEqualToString:@"IMPP"])
        {
            NSDictionary *parameters = [entry objectForKey:@"parameters"];
            NSArray *serviceValues = [parameters objectForKey:@"X-SERVICE-TYPE"];
            NSString *service = serviceValues.count == 0 ? nil : [serviceValues objectAtIndex:0];
            if (service.length == 0)
            {
                NSArray *typeValues = [parameters objectForKey:@"TYPE"];
                service = typeValues.count == 0 ? nil : [typeValues objectAtIndex:0];
            }
            NSString *username = TGVCardUnescapeString(rawValue);
            NSRange schemeRange = [username rangeOfString:@":"];
            if (schemeRange.location != NSNotFound && schemeRange.location + 1 < username.length)
            {
                if (service.length == 0)
                    service = [username substringToIndex:schemeRange.location];
                username = [username substringFromIndex:schemeRange.location + 1];
            }
            NSMutableDictionary *im = [[NSMutableDictionary alloc] init];
            if (service.length > 0)
                [im setObject:service forKey:@"service"];
            if (username.length > 0)
                [im setObject:username forKey:@"username"];
            if (im.count > 0)
                [instantMessengers addObject:[[TGVCardValueArrayItem alloc] initWithLabel:(__bridge NSString *)kABOtherLabel value:im]];
        }
    }

    if (_firstName == nil && _lastName == nil && formattedName.length > 0)
        _firstName = [[TGVCardValueString alloc] initWithProperty:kABPersonFirstNameProperty string:formattedName];
    if (phones.count > 0)
        _phones = [[TGVCardValueArray alloc] initWithProperty:kABPersonPhoneProperty values:phones objectType:[NSString class]];
    if (emails.count > 0)
        _emails = [[TGVCardValueArray alloc] initWithProperty:kABPersonEmailProperty values:emails objectType:[NSString class]];
    if (urls.count > 0)
        _urls = [[TGVCardValueArray alloc] initWithProperty:kABPersonURLProperty values:urls objectType:[NSString class]];
    if (addresses.count > 0)
        _addresses = [[TGVCardValueArray alloc] initWithProperty:kABPersonAddressProperty values:addresses objectType:[NSDictionary class]];
    if (socialProfiles.count > 0)
        _socialProfiles = [[TGVCardValueArray alloc] initWithProperty:kABPersonSocialProfileProperty values:socialProfiles objectType:[NSDictionary class]];
    if (instantMessengers.count > 0)
        _instantMessengers = [[TGVCardValueArray alloc] initWithProperty:kABPersonInstantMessageProperty values:instantMessengers objectType:[NSDictionary class]];

    return self;
}

- (instancetype)initWithPerson:(ABRecordRef)person
{
    self = [super init];
    if (self != nil)
    {
        TGVCardValueString *(^getStringValueProperty)(ABPropertyID) = ^TGVCardValueString *(ABPropertyID property) {
            NSString *value = (__bridge_transfer NSString *)ABRecordCopyValue(person, property);
            if (value.length > 0) {
                return [[TGVCardValueString alloc] initWithProperty:property string:value];
            } else {
                return nil;
            }
        };
        
        TGVCardValueDate *(^getDateValueProperty)(ABPropertyID) = ^TGVCardValueDate *(ABPropertyID property) {
            NSDate *value = (__bridge_transfer NSDate *)ABRecordCopyValue(person, property);
            if (value != nil) {
                return [[TGVCardValueDate alloc] initWithProperty:property date:value];
            } else {
                return nil;
            }
        };
        
        void (^getMultiValuePropertyValues)(ABPropertyID, NSMutableArray *) = ^(ABPropertyID property, NSMutableArray *array) {
            ABMultiValueRef values = ABRecordCopyValue(person, property);
            NSInteger valueCount = (values == NULL) ? 0 : ABMultiValueGetCount(values);
            
            for (CFIndex i = 0; i < valueCount; i++) {
                NSString *label = (__bridge_transfer NSString *)(ABMultiValueCopyLabelAtIndex(values, i));
                id value = (__bridge_transfer id)(ABMultiValueCopyValueAtIndex(values, i));

                TGVCardValueArrayItem *item = [[TGVCardValueArrayItem alloc] initWithLabel:label value:value];
                if (item != nil) {
                    [array addObject:item];
                }
            }
            
            if (values != NULL)
                CFRelease(values);
        };
        
        TGVCardValueArray *(^getMultiStringValueProperty)(ABPropertyID) = ^TGVCardValueArray *(ABPropertyID property) {
            NSMutableArray *array = [[NSMutableArray alloc] init];
            getMultiValuePropertyValues(property, array);
            
            if (array.count > 0) {
                return [[TGVCardValueArray alloc] initWithProperty:property values:array objectType:[NSString class]];
            } else {
                return nil;
            }
        };
        
        TGVCardValueArray *(^getMultiDictionaryValueProperty)(ABPropertyID) = ^TGVCardValueArray *(ABPropertyID property) {
            NSMutableArray *array = [[NSMutableArray alloc] init];
            getMultiValuePropertyValues(property, array);
            
            if (array.count > 0) {
                return [[TGVCardValueArray alloc] initWithProperty:property values:array objectType:[NSDictionary class]];
            } else {
                return nil;
            }
        };
        
        _firstName = getStringValueProperty(kABPersonFirstNameProperty);
        _lastName = getStringValueProperty(kABPersonLastNameProperty);
        _middleName = getStringValueProperty(kABPersonMiddleNameProperty);
        _prefix = getStringValueProperty(kABPersonPrefixProperty);
        _suffix = getStringValueProperty(kABPersonSuffixProperty);
        _organization = getStringValueProperty(kABPersonOrganizationProperty);
        _jobTitle = getStringValueProperty(kABPersonJobTitleProperty);
        _department = getStringValueProperty(kABPersonDepartmentProperty);
        _phones = getMultiStringValueProperty(kABPersonPhoneProperty);
        _emails = getMultiStringValueProperty(kABPersonEmailProperty);
        _urls = getMultiStringValueProperty(kABPersonURLProperty);
        _addresses = getMultiDictionaryValueProperty(kABPersonAddressProperty);
        _birthday = getDateValueProperty(kABPersonBirthdayProperty);
        if (iosMajorVersion() >= 5)
            _socialProfiles = getMultiDictionaryValueProperty(kABPersonSocialProfileProperty);
        _instantMessengers = getMultiDictionaryValueProperty(kABPersonInstantMessageProperty);
        
    }
    return self;
}

- (NSString *)fileName
{
    if (self.firstName.value.length > 0 || self.lastName.value.length > 0)
    {
        NSMutableArray *components = [[NSMutableArray alloc] init];
        if (self.firstName.value.length > 0)
            [components addObject:self.firstName.value];
        if (self.lastName.value.length > 0)
            [components addObject:self.lastName.value];
        return [components componentsJoinedByString:@" "];
    }
    else if (self.organization.value.length > 0)
    {
        return self.organization.value;
    }
    else
    {
        return @"card";
    }
}

- (bool)isPrimitive
{
    if (_organization != nil)
        return false;
    if (_jobTitle != nil)
        return false;
    if (_department != nil)
        return false;
    if (_phones.values.count > 1)
        return false;
    if (_emails.values.count > 0)
        return false;
    if (_urls.values.count > 0)
        return false;
    if (_addresses.values.count > 0)
        return false;
    if (_birthday != nil)
        return false;
    if (_socialProfiles.values.count > 0)
        return false;
    if (_instantMessengers.values.count > 0)
        return false;
    return true;
}

- (instancetype)vcardBySkippingItemsWithIds:(NSSet *)uniqueIds
{
    return [self vcardByCopying:false withIds:uniqueIds];
}

- (instancetype)vcardByKeepingItemsWithIds:(NSSet *)uniqueIds
{
    return [self vcardByCopying:true withIds:uniqueIds];
}

- (instancetype)vcardByCopying:(bool)keep withIds:(NSSet *)uniqueIds
{
    TGVCard *vcard = [[TGVCard alloc] init];
    vcard->_firstName = _firstName;
    vcard->_lastName = _lastName;
    
    vcard->_middleName = _middleName;
    vcard->_prefix = _prefix;
    vcard->_suffix = _suffix;
    
    if ((keep && [uniqueIds containsObject:@(_organization.uniqueId)]) || (!keep && ![uniqueIds containsObject:@(_organization.uniqueId)]))
        vcard->_organization = _organization;
    if ((keep && [uniqueIds containsObject:@(_jobTitle.uniqueId)]) || (!keep && ![uniqueIds containsObject:@(_jobTitle.uniqueId)]))
        vcard->_jobTitle = _jobTitle;
    if ((keep && [uniqueIds containsObject:@(_department.uniqueId)]) || (!keep && ![uniqueIds containsObject:@(_jobTitle.uniqueId)]))
        vcard->_department = _department;
    
    void (^processValues)(TGVCardValueArray *, TGVCardValueArray **) = ^(TGVCardValueArray *origin, TGVCardValueArray **target) {
        NSMutableArray *values = [[NSMutableArray alloc] init];
        for (TGVCardValueArrayItem *value in origin.values) {
            if ((keep && [uniqueIds containsObject:@(value.uniqueId)]) || (!keep && ![uniqueIds containsObject:@(value.uniqueId)])) {
                [values addObject:value];
            }
        }
        if (values.count > 0) {
           *target = [[TGVCardValueArray alloc] initWithProperty:origin.property values:values objectType:origin.objectType];
        }
    };

    TGVCardValueArray *phones = nil;
    processValues(_phones, &phones);
    vcard->_phones = phones;
    
    TGVCardValueArray *emails = nil;
    processValues(_emails, &emails);
    vcard->_emails = emails;
    
    TGVCardValueArray *urls = nil;
    processValues(_urls, &urls);
    vcard->_urls = urls;
    
    TGVCardValueArray *addresses = nil;
    processValues(_addresses, &addresses);
    vcard->_addresses = addresses;
        
    if ((keep && [uniqueIds containsObject:@(_birthday.uniqueId)]) || (!keep && ![uniqueIds containsObject:@(_birthday.uniqueId)]))
        vcard->_birthday = _birthday;
    
    TGVCardValueArray *socialProfiles = nil;
    processValues(_socialProfiles, &socialProfiles);
    vcard->_socialProfiles = socialProfiles;
    
    TGVCardValueArray *instantMessengers = nil;
    processValues(_instantMessengers, &instantMessengers);
    vcard->_instantMessengers = instantMessengers;
    
    return vcard;
}

- (NSString *)vcardString
{
    if (iosMajorVersion() < 5)
        return [TGVCardSerialize(self, NULL) stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];

    ABRecordRef person = TGVCardCreatePersonFromCard(self);
    NSString *vcard = TGVCardStringFromPerson(person);
    if (person != NULL)
        CFRelease(person);
    return vcard;
}

@end
