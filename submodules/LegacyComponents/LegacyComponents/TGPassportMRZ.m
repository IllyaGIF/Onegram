#import "TGPassportMRZ.h"

@interface NSData (OGCompatBase64Decoding)
- (instancetype)initWithBase64EncodedString:(NSString *)base64String options:(NSUInteger)options;
@end

const NSUInteger TGPassportTD1Length = 30;
const NSUInteger TGPassportTD23Length = 44;
NSString *const TGPassportEmptyCharacter = @"<";

@implementation TGPassportMRZ

+ (instancetype)parseBarcodePayload:(NSString *)data
{
    if (data.length == 0)
        return nil;
    
    if ([data rangeOfString:@"ANSI "].location != NSNotFound)
    {
        NSMutableDictionary *fields = [[NSMutableDictionary alloc] init];
        [data enumerateLinesUsingBlock:^(NSString *line, BOOL *stop)
        {
            if (line.length >= 4 && [line hasPrefix:@"D"])
                [fields setValue:[line substringFromIndex:3] forKey:[line substringToIndex:3]];
        }];
        
        if (fields.count == 0)
            return nil;
        
        TGPassportMRZ *result = [[TGPassportMRZ alloc] init];
        result->_documentType = @"DL";
        result->_issuingCountry = [fields valueForKey:@"DCG"];
        result->_documentNumber = [fields valueForKey:@"DCF"];
        result->_firstName = [fields valueForKey:@"DAC"] ?: [fields valueForKey:@"DCT"];
        result->_lastName = [fields valueForKey:@"DCS"] ?: [fields valueForKey:@"DAB"];
        result->_middleName = [fields valueForKey:@"DAD"];
        
        NSString *genderCode = [fields valueForKey:@"DBC"];
        if ([genderCode isEqualToString:@"1"])
            result->_gender = @"M";
        else if ([genderCode isEqualToString:@"2"])
            result->_gender = @"F";
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"MMddyyyy"];
        
        NSString *expiryText = [fields valueForKey:@"DBA"];
        if (expiryText.length > 0)
            result->_expiryDate = [formatter dateFromString:expiryText];
        
        NSString *birthText = [fields valueForKey:@"DBB"];
        if (birthText.length > 0)
            result->_birthDate = [formatter dateFromString:birthText];
        
        return result;
    }
    else
    {
        NSCharacterSet *invertedBase64CharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="] invertedSet];
        
        if ([data rangeOfCharacterFromSet:invertedBase64CharacterSet].location != NSNotFound)
            return nil;
        
        NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:data options:0];
        if (decodedData.length == 0)
            return nil;
        
        NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSWindowsCP1251StringEncoding];
        if (decodedString.length == 0)
            return nil;
        
        NSArray *components = [decodedString componentsSeparatedByString:@"|"];
        if (components.count < 7)
            return nil;
        
        TGPassportMRZ *result = [[TGPassportMRZ alloc] init];
        result->_documentType = @"DL";
        result->_issuingCountry = @"RUS";
        result->_nationality = @"RUS";
        result->_documentNumber = [components objectAtIndex:0];
        
        NSString *nativeFirst = [components objectAtIndex:4];
        NSString *nativeLast = [components objectAtIndex:3];
        NSString *nativeMiddle = [components objectAtIndex:5];
        result->_nativeFirstName = nativeFirst;
        result->_firstName = [self transliterateRussianName:nativeFirst];
        result->_nativeLastName = nativeLast;
        result->_lastName = [self transliterateRussianName:nativeLast];
        result->_nativeMiddleName = nativeMiddle;
        result->_middleName = [self transliterateRussianName:nativeMiddle];
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyyMMdd"];
        
        if ([[components objectAtIndex:6] length] > 0)
            result->_birthDate = [dateFormatter dateFromString:[components objectAtIndex:6]];
        if ([[components objectAtIndex:2] length] > 0)
            result->_expiryDate = [dateFormatter dateFromString:[components objectAtIndex:2]];
        
        return result;
    }

    return nil;
}

+ (NSString *)sliceOfLine:(NSString *)line from:(NSUInteger)from length:(NSUInteger)length
{
    return [line substringWithRange:NSMakeRange(from, length)];
}

+ (NSInteger)checkValueOfLine:(NSString *)line at:(NSUInteger)column
{
    return [[self ensureNumberString:[self sliceOfLine:line from:column length:1]] integerValue];
}

+ (void)fillNamesOf:(TGPassportMRZ *)result fromFullName:(NSString *)fullName
{
    NSArray *names = [[fullName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:TGPassportEmptyCharacter]] componentsSeparatedByString:@"<<"];
    result->_lastName = [self nameString:[names objectAtIndex:0]];
    result->_firstName = [self nameString:[names lastObject]];
}

+ (void)fillHeadOf:(TGPassportMRZ *)result fromLine:(NSString *)line
{
    result->_documentType = [line substringToIndex:1];
    result->_documentSubtype = [self cleanString:[self sliceOfLine:line from:1 length:1]];
    result->_issuingCountry = [self cleanString:[self sliceOfLine:line from:2 length:3]];
}

+ (NSString *)genderOfLine:(NSString *)line at:(NSUInteger)column
{
    NSString *value = [self sliceOfLine:line from:column length:1];
    return [value isEqualToString:TGPassportEmptyCharacter] ? nil : value;
}

+ (instancetype)parseLines:(NSArray *)lines
{
    if (lines.count == 2)
    {
        NSString *upper = [lines objectAtIndex:0];
        NSString *lower = [lines objectAtIndex:1];
        if (upper.length != TGPassportTD23Length || lower.length != TGPassportTD23Length)
            return nil;
        
        TGPassportMRZ *result = [[TGPassportMRZ alloc] init];
        [self fillHeadOf:result fromLine:upper];
        [self fillNamesOf:result fromFullName:[self sliceOfLine:upper from:5 length:39]];
        
        NSString *documentNumber = [self ensureNumberString:[lower substringToIndex:9]];
        NSInteger documentNumberCheck = [self checkValueOfLine:lower at:9];
        if ([self isDataValid:documentNumber check:documentNumberCheck])
            result->_documentNumber = documentNumber;
        
        result->_nationality = [self sliceOfLine:lower from:10 length:3];
        NSString *birthDate = [self ensureNumberString:[self sliceOfLine:lower from:13 length:6]];
        NSInteger birthDateCheck = [self checkValueOfLine:lower at:19];
        if ([self isDataValid:birthDate check:birthDateCheck])
            result->_birthDate = [self dateFromString:birthDate];
        
        result->_gender = [self genderOfLine:lower at:20];
        
        NSString *expiryDate = [self ensureNumberString:[self sliceOfLine:lower from:21 length:6]];
        NSInteger expiryDateCheck = [self checkValueOfLine:lower at:27];
        if ([self isDataValid:expiryDate check:expiryDateCheck])
            result->_expiryDate = [self dateFromString:expiryDate];
        
        NSString *optional1 = [self sliceOfLine:lower from:28 length:14];
        NSString *optional1CheckString = [self ensureNumberString:[self sliceOfLine:lower from:42 length:1]];
        NSInteger optional1CheckValue = [optional1CheckString isEqualToString:TGPassportEmptyCharacter] ? 0 : [optional1CheckString integerValue];
        if ([self isDataValid:optional1 check:optional1CheckValue])
            result->_optional1 = [self cleanString:optional1];
        
        NSString *data = [NSString stringWithFormat:@"%@%d%@%d%@%d%@%@", documentNumber, (int)documentNumberCheck, birthDate, (int)birthDateCheck, expiryDate, (int)expiryDateCheck, optional1, optional1CheckString];
        if ([self isDataValid:data check:[self checkValueOfLine:lower at:43]])
        {
            if ([result->_documentType isEqualToString:@"P"] && [result->_documentSubtype isEqualToString:@"N"] && [result->_issuingCountry isEqualToString:@"RUS"])
            {
                NSString *lastName = [self transliterateRussianMRZString:result->_lastName];
                result->_nativeLastName = lastName;
                result->_lastName = [self transliterateRussianName:lastName];
                NSString *firstName = [self transliterateRussianMRZString:result->_firstName];
                result->_nativeFirstName = firstName;
                result->_firstName = [self transliterateRussianName:firstName];
                
                NSString *lastSeriesDigit = [optional1 substringToIndex:1];
                NSMutableString *fullDocumentNo = [[NSMutableString alloc] init];
                [fullDocumentNo insertString:[result->_documentNumber substringToIndex:3] atIndex:0];
                [fullDocumentNo appendString:lastSeriesDigit];
                [fullDocumentNo appendString:[result->_documentNumber substringFromIndex:3]];
                result->_documentNumber = fullDocumentNo;
            }
            
            
            result->_mrz = [lines componentsJoinedByString:@"\n"];
            return result;
        }
    }
    else if (lines.count == 3)
    {
        NSString *top = [lines objectAtIndex:0];
        NSString *middle = [lines objectAtIndex:1];
        NSString *bottom = [lines objectAtIndex:2];
        if (top.length != TGPassportTD1Length || middle.length != TGPassportTD1Length || bottom.length != TGPassportTD1Length)
            return nil;
        
        TGPassportMRZ *result = [[TGPassportMRZ alloc] init];
        [self fillHeadOf:result fromLine:top];
        
        NSString *documentNumber = [self ensureNumberString:[self sliceOfLine:top from:5 length:9]];
        NSInteger documentNumberCheck = [self checkValueOfLine:top at:14];
        if ([self isDataValid:documentNumber check:documentNumberCheck])
            result->_documentNumber = documentNumber;
        
        result->_optional1 = [self cleanString:[self sliceOfLine:top from:15 length:15]];
        
        NSString *birthDate = [self ensureNumberString:[middle substringToIndex:6]];
        NSInteger birthDateCheck = [[self sliceOfLine:middle from:6 length:1] integerValue];
        if ([self isDataValid:birthDate check:birthDateCheck])
            result->_birthDate = [self dateFromString:birthDate];
        
        result->_gender = [self genderOfLine:middle at:7];
        
        NSString *expiryDate = [self ensureNumberString:[self sliceOfLine:middle from:8 length:6]];
        NSInteger expiryDateCheck = [self checkValueOfLine:middle at:14];
        if ([self isDataValid:expiryDate check:expiryDateCheck])
            result->_expiryDate = [self dateFromString:expiryDate];
        
        result->_nationality = [self sliceOfLine:middle from:15 length:3];
        result->_optional2 = [self sliceOfLine:middle from:18 length:11];
        
        [self fillNamesOf:result fromFullName:[self ensureAlphaString:bottom]];
        result->_mrz = [lines componentsJoinedByString:@"\n"];
        
        return result;
    }
    return nil;
}

+ (NSDateFormatter *)dateFormatter
{
    static dispatch_once_t onceToken;
    static NSDateFormatter *dateFormatter;
    dispatch_once(&onceToken, ^
    {
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"YYMMdd";
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    });
    return dateFormatter;
}


+ (NSDate *)dateFromString:(NSString *)string
{
    return [[self dateFormatter] dateFromString:string];
}

+ (NSString *)cleanString:(NSString *)string
{
    return [string stringByReplacingOccurrencesOfString:TGPassportEmptyCharacter withString:@""];
}

+ (NSString *)nameString:(NSString *)string
{
    return [string stringByReplacingOccurrencesOfString:TGPassportEmptyCharacter withString:@" "];
}

+ (NSString *)ensureNumberString:(NSString *)string
{
    return [[[[string stringByReplacingOccurrencesOfString:@"O" withString:@"0"] stringByReplacingOccurrencesOfString:@"U" withString:@"0"] stringByReplacingOccurrencesOfString:@"Q" withString:@"0"] stringByReplacingOccurrencesOfString:@"J" withString:@"0"];
}

+ (NSString *)ensureAlphaString:(NSString *)string
{
    NSCharacterSet *validChars = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ<"];
    NSCharacterSet *invalidChars = [validChars invertedSet];
    
    string = [string stringByReplacingOccurrencesOfString:@"0" withString:@"O"];
    return  [self string:string byReplacingCharactersInSet:invalidChars withString:TGPassportEmptyCharacter];
}

+ (NSString *)string:(NSString *)string byReplacingCharactersInSet:(NSCharacterSet *)charSet withString:(NSString *)aString {
    NSMutableString *s = [NSMutableString stringWithCapacity:string.length];
    for (NSUInteger i = 0; i < string.length; ++i) {
        unichar c = [string characterAtIndex:i];
        if (![charSet characterIsMember:c]) {
            [s appendFormat:@"%C", c];
        } else {
            [s appendString:aString];
        }
    }
    return s;
}

+ (NSString *)transliterateRussianMRZString:(NSString *)string
{
    NSDictionary *map = @
    {
        @"A": @"А",
        @"B": @"Б",
        @"V": @"В",
        @"G": @"Г",
        @"D": @"Д",
        @"E": @"Е",
        @"2": @"Ё",
        @"J": @"Ж",
        @"Z": @"З",
        @"I": @"И",
        @"Q": @"Й",
        @"K": @"К",
        @"L": @"Л",
        @"M": @"М",
        @"N": @"Н",
        @"O": @"О",
        @"P": @"П",
        @"R": @"Р",
        @"S": @"С",
        @"T": @"Т",
        @"U": @"У",
        @"F": @"Ф",
        @"H": @"Х",
        @"C": @"Ц",
        @"3": @"Ч",
        @"4": @"Ш",
        @"W": @"Щ",
        @"X": @"Ъ",
        @"Y": @"Ы",
        @"9": @"Ь",
        @"6": @"Э",
        @"7": @"Ю",
        @"8": @"Я",
        @" ": @" "
    };
    
    NSMutableString *result = [[NSMutableString alloc] init];
    [string enumerateSubstringsInRange:NSMakeRange(0, string.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, __unused NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL *stop)
    {
        if (substring == nil)
            return;
        
        NSString *letter = map[substring];
        if (letter != nil)
            [result appendString:letter];
    }];
    return result;
}

+ (NSString *)transliterateRussianName:(NSString *)string
{
    NSDictionary *map = @
    {
        @"А": @"A",
        @"Б": @"B",
        @"В": @"V",
        @"Г": @"G",
        @"Д": @"D",
        @"Е": @"E",
        @"Ё": @"E",
        @"Ж": @"ZH",
        @"З": @"Z",
        @"И": @"I",
        @"Й": @"I",
        @"К": @"K",
        @"Л": @"L",
        @"М": @"M",
        @"Н": @"N",
        @"О": @"O",
        @"П": @"P",
        @"Р": @"R",
        @"С": @"S",
        @"Т": @"T",
        @"У": @"U",
        @"Ф": @"F",
        @"Х": @"KH",
        @"Ц": @"TS",
        @"Ч": @"CH",
        @"Ш": @"SH",
        @"Щ": @"SHCH",
        @"Ъ": @"IE",
        @"Ы": @"Y",
        @"Ь": @"",
        @"Э": @"E",
        @"Ю": @"IU",
        @"Я": @"IA",
        @" ": @" "
    };
    
    NSMutableString *result = [[NSMutableString alloc] init];
    [string enumerateSubstringsInRange:NSMakeRange(0, string.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, __unused NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL *stop)
     {
         if (substring == nil)
             return;
         
         NSString *letter = map[substring];
         if (letter != nil)
             [result appendString:letter];
     }];
    return result;
}

+ (bool)isDataValid:(NSString *)data check:(NSInteger)check
{
    int32_t sum = 0;
    uint8_t w[3] = { 7, 3, 1 };
    
    for (NSUInteger i = 0; i < data.length; i++)
    {
        unichar c = [data characterAtIndex:i];
        NSInteger d = 0;
        if (c >= '0' && c <= '9')
            d = c - '0';
        else if (c >= 'A' && c <= 'Z')
            d = (10 + c) - 'A';
        else if (c != '<')
            return false;
        
        sum += d * w[i % 3];
    }
    
    if (sum % 10 != check)
        return false;
    
    return true;
}

@end
