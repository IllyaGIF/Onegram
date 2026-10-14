#import "TGRichMessage.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageMediaAttachment.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDocumentMediaAttachment.h"

static NSArray *TGRichMessageDecodeArray(NSCoder *coder, NSString *key)
{
    id value = [coder decodeObjectForKey:key];
    return [value isKindOfClass:[NSArray class]] ? value : nil;
}

static NSString *TGRichMessageDecodeString(NSCoder *coder, NSString *key)
{
    id value = [coder decodeObjectForKey:key];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static void TGRichMessageAppendParagraph(NSMutableString *result, NSString *paragraph)
{
    if (paragraph.length == 0)
        return;
    if (result.length != 0)
        [result appendString:@"\n"];
    [result appendString:paragraph];
}

@implementation TGRichMessageText

- (instancetype)initWithKind:(TGRichMessageTextKind)kind string:(NSString *)string texts:(NSArray *)texts identifier:(int64_t)identifier value:(int32_t)value flags:(int32_t)flags size:(CGSize)size button:(TGRichMessageButton *)button
{
    self = [super init];
    if (self != nil)
    {
        _kind = kind;
        _string = string;
        _texts = texts;
        _identifier = identifier;
        _value = value;
        _flags = flags;
        _size = size;
        _button = button;
    }
    return self;
}

+ (instancetype)plainText:(NSString *)string
{
    return [[TGRichMessageText alloc] initWithKind:TGRichMessageTextKindPlain string:string texts:nil identifier:0 value:0 flags:0 size:CGSizeZero button:nil];
}

+ (instancetype)textWithKind:(TGRichMessageTextKind)kind text:(TGRichMessageText *)text
{
    return [[TGRichMessageText alloc] initWithKind:kind string:nil texts:text == nil ? nil : @[text] identifier:0 value:0 flags:0 size:CGSizeZero button:nil];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    TGRichMessageButton *button = [aDecoder decodeObjectForKey:@"b"];
    return [self initWithKind:(TGRichMessageTextKind)[aDecoder decodeInt32ForKey:@"k"] string:TGRichMessageDecodeString(aDecoder, @"s") texts:TGRichMessageDecodeArray(aDecoder, @"t") identifier:[aDecoder decodeInt64ForKey:@"i"] value:[aDecoder decodeInt32ForKey:@"v"] flags:[aDecoder decodeInt32ForKey:@"f"] size:CGSizeMake([aDecoder decodeInt32ForKey:@"w"], [aDecoder decodeInt32ForKey:@"h"]) button:[button isKindOfClass:[TGRichMessageButton class]] ? button : nil];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:(int32_t)_kind forKey:@"k"];
    if (_string != nil)
        [aCoder encodeObject:_string forKey:@"s"];
    if (_texts != nil)
        [aCoder encodeObject:_texts forKey:@"t"];
    if (_identifier != 0)
        [aCoder encodeInt64:_identifier forKey:@"i"];
    if (_value != 0)
        [aCoder encodeInt32:_value forKey:@"v"];
    if (_flags != 0)
        [aCoder encodeInt32:_flags forKey:@"f"];
    if (_size.width > 0.0f || _size.height > 0.0f)
    {
        [aCoder encodeInt32:(int32_t)_size.width forKey:@"w"];
        [aCoder encodeInt32:(int32_t)_size.height forKey:@"h"];
    }
    if (_button != nil)
        [aCoder encodeObject:_button forKey:@"b"];
}

- (TGRichMessageText *)text
{
    return _texts.count == 0 ? nil : _texts[0];
}

- (bool)isEmpty
{
    switch (_kind)
    {
        case TGRichMessageTextKindEmpty:
            return true;
        case TGRichMessageTextKindPlain:
            return _string.length == 0;
        case TGRichMessageTextKindImage:
        case TGRichMessageTextKindMath:
        case TGRichMessageTextKindCustomEmoji:
        case TGRichMessageTextKindButton:
            return false;
        default:
            break;
    }
    for (TGRichMessageText *text in _texts)
    {
        if (![text isEmpty])
            return false;
    }
    return true;
}

- (NSString *)plainText
{
    switch (_kind)
    {
        case TGRichMessageTextKindEmpty:
        case TGRichMessageTextKindImage:
            return @"";
        case TGRichMessageTextKindPlain:
            return _string ?: @"";
        case TGRichMessageTextKindMath:
            return _string ?: @"";
        case TGRichMessageTextKindCustomEmoji:
            return _string ?: @"";
        case TGRichMessageTextKindDiff:
            return [[self text] plainText] ?: @"";
        case TGRichMessageTextKindButton:
            return [[self text] plainText] ?: @"";
        default:
        {
            NSMutableString *result = [[NSMutableString alloc] init];
            for (TGRichMessageText *text in _texts)
            {
                NSString *part = [text plainText];
                if (part.length != 0)
                    [result appendString:part];
            }
            return result;
        }
    }
}

@end

@implementation TGRichMessageButton

- (instancetype)initWithText:(TGRichMessageText *)text action:(TGRichMessageButtonAction)action string:(NSString *)string data:(NSData *)data identifier:(int64_t)identifier samePeer:(bool)samePeer requiresPassword:(bool)requiresPassword style:(int32_t)style
{
    self = [super init];
    if (self != nil)
    {
        _text = text;
        _action = action;
        _string = string;
        _data = data;
        _identifier = identifier;
        _samePeer = samePeer;
        _requiresPassword = requiresPassword;
        _style = style;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    TGRichMessageText *text = [aDecoder decodeObjectForKey:@"t"];
    NSData *data = [aDecoder decodeObjectForKey:@"d"];
    return [self initWithText:[text isKindOfClass:[TGRichMessageText class]] ? text : nil action:(TGRichMessageButtonAction)[aDecoder decodeInt32ForKey:@"a"] string:TGRichMessageDecodeString(aDecoder, @"s") data:[data isKindOfClass:[NSData class]] ? data : nil identifier:[aDecoder decodeInt64ForKey:@"i"] samePeer:[aDecoder decodeBoolForKey:@"sp"] requiresPassword:[aDecoder decodeBoolForKey:@"rp"] style:[aDecoder decodeInt32ForKey:@"st"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (_text != nil)
        [aCoder encodeObject:_text forKey:@"t"];
    [aCoder encodeInt32:(int32_t)_action forKey:@"a"];
    if (_string != nil)
        [aCoder encodeObject:_string forKey:@"s"];
    if (_data != nil)
        [aCoder encodeObject:_data forKey:@"d"];
    [aCoder encodeInt64:_identifier forKey:@"i"];
    [aCoder encodeBool:_samePeer forKey:@"sp"];
    [aCoder encodeBool:_requiresPassword forKey:@"rp"];
    [aCoder encodeInt32:_style forKey:@"st"];
}

@end

@implementation TGRichMessageBlock

- (instancetype)initWithKind:(TGRichMessageBlockKind)kind
{
    self = [super init];
    if (self != nil)
    {
        _kind = kind;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [self initWithKind:(TGRichMessageBlockKind)[aDecoder decodeInt32ForKey:@"k"]];
    if (self != nil)
    {
        _level = [aDecoder decodeInt32ForKey:@"l"];
        _flags = [aDecoder decodeInt32ForKey:@"f"];
        id text = [aDecoder decodeObjectForKey:@"t"];
        _text = [text isKindOfClass:[TGRichMessageText class]] ? text : nil;
        id secondaryText = [aDecoder decodeObjectForKey:@"st"];
        _secondaryText = [secondaryText isKindOfClass:[TGRichMessageText class]] ? secondaryText : nil;
        id caption = [aDecoder decodeObjectForKey:@"c"];
        _caption = [caption isKindOfClass:[TGRichMessageText class]] ? caption : nil;
        id credit = [aDecoder decodeObjectForKey:@"cr"];
        _credit = [credit isKindOfClass:[TGRichMessageText class]] ? credit : nil;
        _string = TGRichMessageDecodeString(aDecoder, @"s");
        _secondaryString = TGRichMessageDecodeString(aDecoder, @"ss");
        _identifier = [aDecoder decodeInt64ForKey:@"i"];
        _secondaryIdentifier = [aDecoder decodeInt64ForKey:@"si"];
        _date = [aDecoder decodeInt32ForKey:@"d"];
        _start = [aDecoder decodeInt32ForKey:@"sn"];
        _blocks = TGRichMessageDecodeArray(aDecoder, @"b");
        _items = TGRichMessageDecodeArray(aDecoder, @"it");
        _rows = TGRichMessageDecodeArray(aDecoder, @"r");
        _buttons = TGRichMessageDecodeArray(aDecoder, @"bt");
        _articles = TGRichMessageDecodeArray(aDecoder, @"a");
        _latitude = [aDecoder decodeDoubleForKey:@"la"];
        _longitude = [aDecoder decodeDoubleForKey:@"lo"];
        _zoom = [aDecoder decodeInt32ForKey:@"z"];
        _size = CGSizeMake([aDecoder decodeInt32ForKey:@"w"], [aDecoder decodeInt32ForKey:@"h"]);
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:(int32_t)_kind forKey:@"k"];
    [aCoder encodeInt32:_level forKey:@"l"];
    [aCoder encodeInt32:_flags forKey:@"f"];
    if (_text != nil)
        [aCoder encodeObject:_text forKey:@"t"];
    if (_secondaryText != nil)
        [aCoder encodeObject:_secondaryText forKey:@"st"];
    if (_caption != nil)
        [aCoder encodeObject:_caption forKey:@"c"];
    if (_credit != nil)
        [aCoder encodeObject:_credit forKey:@"cr"];
    if (_string != nil)
        [aCoder encodeObject:_string forKey:@"s"];
    if (_secondaryString != nil)
        [aCoder encodeObject:_secondaryString forKey:@"ss"];
    [aCoder encodeInt64:_identifier forKey:@"i"];
    [aCoder encodeInt64:_secondaryIdentifier forKey:@"si"];
    [aCoder encodeInt32:_date forKey:@"d"];
    [aCoder encodeInt32:_start forKey:@"sn"];
    if (_blocks != nil)
        [aCoder encodeObject:_blocks forKey:@"b"];
    if (_items != nil)
        [aCoder encodeObject:_items forKey:@"it"];
    if (_rows != nil)
        [aCoder encodeObject:_rows forKey:@"r"];
    if (_buttons != nil)
        [aCoder encodeObject:_buttons forKey:@"bt"];
    if (_articles != nil)
        [aCoder encodeObject:_articles forKey:@"a"];
    [aCoder encodeDouble:_latitude forKey:@"la"];
    [aCoder encodeDouble:_longitude forKey:@"lo"];
    [aCoder encodeInt32:_zoom forKey:@"z"];
    [aCoder encodeInt32:(int32_t)_size.width forKey:@"w"];
    [aCoder encodeInt32:(int32_t)_size.height forKey:@"h"];
}

- (NSString *)plainText
{
    NSMutableString *result = [[NSMutableString alloc] init];
    switch (_kind)
    {
        case TGRichMessageBlockKindPreformatted:
        case TGRichMessageBlockKindTitle:
        case TGRichMessageBlockKindSubtitle:
        case TGRichMessageBlockKindHeading:
        case TGRichMessageBlockKindKicker:
        case TGRichMessageBlockKindParagraph:
        case TGRichMessageBlockKindFooter:
        case TGRichMessageBlockKindThinking:
            TGRichMessageAppendParagraph(result, [_text plainText]);
            break;
        case TGRichMessageBlockKindAuthorDate:
            TGRichMessageAppendParagraph(result, [_text plainText]);
            break;
        case TGRichMessageBlockKindBlockquote:
        case TGRichMessageBlockKindPullquote:
            TGRichMessageAppendParagraph(result, [_text plainText]);
            TGRichMessageAppendParagraph(result, [_secondaryText plainText]);
            break;
        case TGRichMessageBlockKindMath:
            TGRichMessageAppendParagraph(result, _string);
            break;
        case TGRichMessageBlockKindList:
        case TGRichMessageBlockKindOrderedList:
        {
            NSInteger index = 0;
            for (TGRichMessageListItem *item in _items)
            {
                NSMutableString *itemText = [[NSMutableString alloc] init];
                if (item.flags & TGRichMessageListItemFlagCheckbox)
                    [itemText appendString:(item.flags & TGRichMessageListItemFlagChecked) ? @"☑ " : @"☐ "];
                else if (_kind == TGRichMessageBlockKindOrderedList)
                    [itemText appendFormat:@"%@. ", item.number.length != 0 ? item.number : [[NSString alloc] initWithFormat:@"%d", (int)(((_flags & TGRichMessageBlockFlagOrderedListHasStart) ? _start : 1) + index)]];
                else
                    [itemText appendString:@"• "];
                if (item.text != nil)
                    [itemText appendString:[item.text plainText]];
                else
                {
                    NSMutableString *blocksText = [[NSMutableString alloc] init];
                    for (TGRichMessageBlock *block in item.blocks)
                        TGRichMessageAppendParagraph(blocksText, [block plainText]);
                    [itemText appendString:blocksText];
                }
                TGRichMessageAppendParagraph(result, itemText);
                index++;
            }
            break;
        }
        case TGRichMessageBlockKindTable:
        {
            TGRichMessageAppendParagraph(result, [_text plainText]);
            for (NSArray *row in _rows)
            {
                NSMutableArray *cells = [[NSMutableArray alloc] init];
                for (TGRichMessageTableCell *cell in row)
                    [cells addObject:[cell.text plainText] ?: @""];
                TGRichMessageAppendParagraph(result, [cells componentsJoinedByString:@"\t"]);
            }
            break;
        }
        case TGRichMessageBlockKindDetails:
        case TGRichMessageBlockKindBlockquoteBlocks:
        case TGRichMessageBlockKindCover:
        case TGRichMessageBlockKindEmbedPost:
        case TGRichMessageBlockKindCollage:
        case TGRichMessageBlockKindSlideshow:
            TGRichMessageAppendParagraph(result, [_text plainText]);
            for (TGRichMessageBlock *block in _blocks)
                TGRichMessageAppendParagraph(result, [block plainText]);
            TGRichMessageAppendParagraph(result, [_caption plainText]);
            break;
        case TGRichMessageBlockKindRelatedArticles:
            TGRichMessageAppendParagraph(result, [_text plainText]);
            for (TGRichMessageRelatedArticle *article in _articles)
                TGRichMessageAppendParagraph(result, article.title.length != 0 ? article.title : article.url);
            break;
        case TGRichMessageBlockKindButtonRow:
        {
            NSMutableArray *titles = [[NSMutableArray alloc] init];
            for (TGRichMessageButton *button in _buttons)
            {
                NSString *title = [button.text plainText];
                if (title.length != 0)
                    [titles addObject:title];
            }
            TGRichMessageAppendParagraph(result, [titles componentsJoinedByString:@" | "]);
            break;
        }
        case TGRichMessageBlockKindChannel:
            TGRichMessageAppendParagraph(result, _string);
            break;
        default:
            TGRichMessageAppendParagraph(result, [_caption plainText]);
            break;
    }
    return result;
}

@end

@implementation TGRichMessageListItem

- (instancetype)initWithFlags:(int32_t)flags number:(NSString *)number text:(TGRichMessageText *)text blocks:(NSArray *)blocks value:(int32_t)value numberingType:(NSString *)numberingType
{
    self = [super init];
    if (self != nil)
    {
        _flags = flags;
        _number = number;
        _text = text;
        _blocks = blocks;
        _value = value;
        _numberingType = numberingType;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    id text = [aDecoder decodeObjectForKey:@"t"];
    return [self initWithFlags:[aDecoder decodeInt32ForKey:@"f"] number:TGRichMessageDecodeString(aDecoder, @"n") text:[text isKindOfClass:[TGRichMessageText class]] ? text : nil blocks:TGRichMessageDecodeArray(aDecoder, @"b") value:[aDecoder decodeInt32ForKey:@"v"] numberingType:TGRichMessageDecodeString(aDecoder, @"ty")];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:_flags forKey:@"f"];
    if (_number != nil)
        [aCoder encodeObject:_number forKey:@"n"];
    if (_text != nil)
        [aCoder encodeObject:_text forKey:@"t"];
    if (_blocks != nil)
        [aCoder encodeObject:_blocks forKey:@"b"];
    [aCoder encodeInt32:_value forKey:@"v"];
    if (_numberingType != nil)
        [aCoder encodeObject:_numberingType forKey:@"ty"];
}

@end

@implementation TGRichMessageTableCell

- (instancetype)initWithFlags:(int32_t)flags text:(TGRichMessageText *)text colspan:(int32_t)colspan rowspan:(int32_t)rowspan
{
    self = [super init];
    if (self != nil)
    {
        _flags = flags;
        _text = text;
        _colspan = MAX(1, colspan);
        _rowspan = MAX(1, rowspan);
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    id text = [aDecoder decodeObjectForKey:@"t"];
    return [self initWithFlags:[aDecoder decodeInt32ForKey:@"f"] text:[text isKindOfClass:[TGRichMessageText class]] ? text : nil colspan:[aDecoder decodeInt32ForKey:@"cs"] rowspan:[aDecoder decodeInt32ForKey:@"rs"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:_flags forKey:@"f"];
    if (_text != nil)
        [aCoder encodeObject:_text forKey:@"t"];
    [aCoder encodeInt32:_colspan forKey:@"cs"];
    [aCoder encodeInt32:_rowspan forKey:@"rs"];
}

@end

@implementation TGRichMessageRelatedArticle

- (instancetype)initWithUrl:(NSString *)url webpageId:(int64_t)webpageId title:(NSString *)title articleDescription:(NSString *)articleDescription photoId:(int64_t)photoId author:(NSString *)author publishedDate:(int32_t)publishedDate
{
    self = [super init];
    if (self != nil)
    {
        _url = url;
        _webpageId = webpageId;
        _title = title;
        _articleDescription = articleDescription;
        _photoId = photoId;
        _author = author;
        _publishedDate = publishedDate;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithUrl:TGRichMessageDecodeString(aDecoder, @"u") webpageId:[aDecoder decodeInt64ForKey:@"w"] title:TGRichMessageDecodeString(aDecoder, @"t") articleDescription:TGRichMessageDecodeString(aDecoder, @"d") photoId:[aDecoder decodeInt64ForKey:@"p"] author:TGRichMessageDecodeString(aDecoder, @"a") publishedDate:[aDecoder decodeInt32ForKey:@"pd"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (_url != nil)
        [aCoder encodeObject:_url forKey:@"u"];
    [aCoder encodeInt64:_webpageId forKey:@"w"];
    if (_title != nil)
        [aCoder encodeObject:_title forKey:@"t"];
    if (_articleDescription != nil)
        [aCoder encodeObject:_articleDescription forKey:@"d"];
    [aCoder encodeInt64:_photoId forKey:@"p"];
    if (_author != nil)
        [aCoder encodeObject:_author forKey:@"a"];
    [aCoder encodeInt32:_publishedDate forKey:@"pd"];
}

@end

@implementation TGRichMessage

- (instancetype)initWithRtl:(bool)rtl part:(bool)part blocks:(NSArray *)blocks photos:(NSDictionary *)photos documents:(NSDictionary *)documents
{
    self = [super init];
    if (self != nil)
    {
        _rtl = rtl;
        _part = part;
        _blocks = blocks ?: @[];
        _photos = photos ?: @{};
        _documents = documents ?: @{};
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    id photos = [aDecoder decodeObjectForKey:@"p"];
    id documents = [aDecoder decodeObjectForKey:@"d"];
    return [self initWithRtl:[aDecoder decodeBoolForKey:@"rtl"] part:[aDecoder decodeBoolForKey:@"part"] blocks:TGRichMessageDecodeArray(aDecoder, @"b") photos:[photos isKindOfClass:[NSDictionary class]] ? photos : nil documents:[documents isKindOfClass:[NSDictionary class]] ? documents : nil];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeBool:_rtl forKey:@"rtl"];
    [aCoder encodeBool:_part forKey:@"part"];
    [aCoder encodeObject:_blocks forKey:@"b"];
    [aCoder encodeObject:_photos forKey:@"p"];
    [aCoder encodeObject:_documents forKey:@"d"];
}

- (TGImageMediaAttachment *)photoWithId:(int64_t)photoId
{
    if (photoId == 0)
        return nil;
    id photo = _photos[@(photoId)];
    return [photo isKindOfClass:[TGImageMediaAttachment class]] ? photo : nil;
}

- (TGDocumentMediaAttachment *)documentWithId:(int64_t)documentId
{
    if (documentId == 0)
        return nil;
    id document = _documents[@(documentId)];
    return [document isKindOfClass:[TGDocumentMediaAttachment class]] ? document : nil;
}

- (NSString *)plainText
{
    NSMutableString *result = [[NSMutableString alloc] init];
    for (TGRichMessageBlock *block in _blocks)
        TGRichMessageAppendParagraph(result, [block plainText]);
    return result;
}

@end
