#import "TGRichMessageTLParser.h"

#import "TLMetaClassStore.h"
#import "TLChat$channel.h"
#import "NSInputStream+TL.h"

#import "TGRichMessage.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGPeerIdAdapter.h"

static const int32_t TGRichTLVector = (int32_t)0x1cb5c415;
static const int TGRichTLMaximumDepth = 48;

class TGRichTLReader
{
public:
    NSInputStream *is;
    id<TLSerializationEnvironment> environment;
    NSError *error;
    int depth;

    TGRichTLReader(NSInputStream *is_, id<TLSerializationEnvironment> environment_) : is(is_), environment(environment_), error(nil), depth(0)
    {
    }

    bool ok() const
    {
        return error == nil;
    }

    void fail(NSString *reason)
    {
        if (error == nil)
            error = [[NSError alloc] initWithDomain:@"TL" code:-1 userInfo:@{NSLocalizedDescriptionKey: reason}];
    }

    int32_t readInt32()
    {
        if (!ok())
            return 0;
        bool failed = false;
        int32_t value = [is readInt32:&failed];
        if (failed)
            fail(@"RichMessage: unexpected end of stream");
        return value;
    }

    int64_t readInt64()
    {
        if (!ok())
            return 0;
        bool failed = false;
        int64_t value = [is readInt64:&failed];
        if (failed)
            fail(@"RichMessage: unexpected end of stream");
        return value;
    }

    double readDouble()
    {
        if (!ok())
            return 0.0;
        bool failed = false;
        double value = [is readDouble:&failed];
        if (failed)
            fail(@"RichMessage: unexpected end of stream");
        return value;
    }

    NSString *readString()
    {
        if (!ok())
            return nil;
        bool failed = false;
        NSString *value = [is readString:&failed];
        if (failed)
            fail(@"RichMessage: unexpected end of stream");
        return value ?: @"";
    }

    NSData *readBytes()
    {
        if (!ok())
            return nil;
        bool failed = false;
        NSData *value = [is readBytes:&failed];
        if (failed)
            fail(@"RichMessage: unexpected end of stream");
        return value;
    }

    id readObjectWithSignature(int32_t signature)
    {
        if (!ok())
            return nil;
        NSError *objectError = nil;
        id object = TLMetaClassStore::constructObject(is, signature, environment, nil, &objectError);
        if (objectError != nil)
            error = objectError;
        else if (object == nil)
            fail([[NSString alloc] initWithFormat:@"RichMessage: unknown constructor 0x%08x", signature]);
        return object;
    }

    id readObject()
    {
        int32_t signature = readInt32();
        return ok() ? readObjectWithSignature(signature) : nil;
    }

    int32_t readVectorCount()
    {
        int32_t signature = readInt32();
        if (!ok())
            return 0;
        if (signature != TGRichTLVector)
        {
            fail([[NSString alloc] initWithFormat:@"RichMessage: expected vector, got 0x%08x", signature]);
            return 0;
        }
        int32_t count = readInt32();
        if (ok() && count < 0)
        {
            fail(@"RichMessage: negative vector length");
            return 0;
        }
        return count;
    }

    bool enter()
    {
        if (depth >= TGRichTLMaximumDepth)
        {
            fail(@"RichMessage: nesting is too deep");
            return false;
        }
        depth++;
        return true;
    }

    void leave()
    {
        depth--;
    }
};

static TGRichMessageText *TGRichTLReadText(TGRichTLReader &reader);
static TGRichMessageBlock *TGRichTLReadBlock(TGRichTLReader &reader);

static TGRichMessageText *TGRichTLText(TGRichMessageTextKind kind, NSString *string, NSArray *texts, int64_t identifier, int32_t value, int32_t flags, CGSize size, TGRichMessageButton *button)
{
    return [[TGRichMessageText alloc] initWithKind:kind string:string texts:texts identifier:identifier value:value flags:flags size:size button:button];
}

static NSArray *TGRichTLWrap(TGRichMessageText *text)
{
    return text == nil ? @[] : @[text];
}

static int32_t TGRichTLReadButtonStyle(TGRichTLReader &reader)
{
    int32_t signature = reader.readInt32();
    if (!reader.ok())
        return 0;
    if (signature != (int32_t)0x03c610bd)
    {
        reader.readObjectWithSignature(signature);
        return 0;
    }
    return reader.readInt32() & 0xf;
}

static TGRichMessageButton *TGRichTLReadButtonType(TGRichTLReader &reader, TGRichMessageText *text, int32_t style)
{
    int32_t signature = reader.readInt32();
    if (!reader.ok())
        return nil;

    TGRichMessageButtonAction action = TGRichMessageButtonActionUnsupported;
    NSString *string = nil;
    NSData *data = nil;
    int64_t identifier = 0;
    bool samePeer = false;
    bool requiresPassword = false;

    switch (signature)
    {
        case (int32_t)0xeca4f8d4:
            action = TGRichMessageButtonActionUrl;
            string = reader.readString();
            break;
        case (int32_t)0xbfd02da2:
        {
            action = TGRichMessageButtonActionUrlAuth;
            int32_t flags = reader.readInt32();
            if (flags & (1 << 0))
                reader.readString();
            string = reader.readString();
            identifier = reader.readInt32();
            break;
        }
        case (int32_t)0x9961bcb4:
        {
            action = TGRichMessageButtonActionUrlAuth;
            int32_t flags = reader.readInt32();
            if (flags & (1 << 1))
                reader.readString();
            string = reader.readString();
            if (flags & (1 << 2))
                reader.readObject();
            break;
        }
        case (int32_t)0x3bcab5b4:
            action = TGRichMessageButtonActionWebView;
            string = reader.readString();
            break;
        case (int32_t)0x2955bc38:
        {
            action = TGRichMessageButtonActionCallback;
            int32_t flags = reader.readInt32();
            requiresPassword = (flags & (1 << 0)) != 0;
            data = reader.readBytes();
            break;
        }
        case (int32_t)0x5cd3709d:
            action = TGRichMessageButtonActionGame;
            break;
        case (int32_t)0x48bad7a5:
            action = TGRichMessageButtonActionBuy;
            break;
        case (int32_t)0x93773ff5:
        {
            action = TGRichMessageButtonActionSwitchInline;
            int32_t flags = reader.readInt32();
            samePeer = (flags & (1 << 0)) != 0;
            string = reader.readString();
            if (flags & (1 << 1))
            {
                int32_t count = reader.readVectorCount();
                for (int32_t i = 0; i < count && reader.ok(); i++)
                {
                    int32_t peerType = reader.readInt32();
                    switch (peerType)
                    {
                        case (int32_t)0x3081ed9d:
                        case (int32_t)0x833c0fac:
                        case (int32_t)0xd766c50a:
                        case (int32_t)0x5ec4be43:
                        case (int32_t)0x6334ee9a:
                        case (int32_t)0x0e3b2d0c:
                            break;
                        default:
                            reader.readObjectWithSignature(peerType);
                            break;
                    }
                }
            }
            break;
        }
        case (int32_t)0x3fa33fcf:
            action = TGRichMessageButtonActionUserProfile;
            identifier = reader.readInt64();
            break;
        case (int32_t)0x53f3ce5a:
            action = TGRichMessageButtonActionUserProfile;
            reader.readObject();
            break;
        case (int32_t)0xb41d3272:
            action = TGRichMessageButtonActionCopy;
            string = reader.readString();
            break;
        case (int32_t)0xa438619d:
            action = TGRichMessageButtonActionDisabled;
            break;
        default:
            reader.readObjectWithSignature(signature);
            break;
    }

    if (!reader.ok())
        return nil;
    return [[TGRichMessageButton alloc] initWithText:text action:action string:string data:data identifier:identifier samePeer:samePeer requiresPassword:requiresPassword style:style];
}

static TGRichMessageButton *TGRichTLReadPageButton(TGRichTLReader &reader)
{
    int32_t signature = reader.readInt32();
    if (!reader.ok())
        return nil;
    if (signature != (int32_t)0x692a5488)
    {
        reader.readObjectWithSignature(signature);
        return nil;
    }
    int32_t flags = reader.readInt32();
    TGRichMessageText *text = TGRichTLReadText(reader);
    TGRichMessageButton *button = TGRichTLReadButtonType(reader, text, 0);
    int32_t style = 0;
    if (flags & (1 << 0))
        style = TGRichTLReadButtonStyle(reader);
    if (!reader.ok() || button == nil)
        return nil;
    return [[TGRichMessageButton alloc] initWithText:button.text action:button.action string:button.string data:button.data identifier:button.identifier samePeer:button.samePeer requiresPassword:button.requiresPassword style:style];
}

static NSArray *TGRichTLReadTexts(TGRichTLReader &reader)
{
    int32_t count = reader.readVectorCount();
    NSMutableArray *texts = [[NSMutableArray alloc] init];
    for (int32_t i = 0; i < count && reader.ok(); i++)
    {
        TGRichMessageText *text = TGRichTLReadText(reader);
        if (text != nil)
            [texts addObject:text];
    }
    return texts;
}

static TGRichMessageText *TGRichTLReadText(TGRichTLReader &reader)
{
    if (!reader.enter())
        return nil;

    int32_t signature = reader.readInt32();
    TGRichMessageText *result = nil;

    TGRichMessageTextKind wrapperKind = TGRichMessageTextKindEmpty;
    switch (signature)
    {
        case (int32_t)0x6724abc4: wrapperKind = TGRichMessageTextKindBold; break;
        case (int32_t)0xd912a59c: wrapperKind = TGRichMessageTextKindItalic; break;
        case (int32_t)0xc12622c4: wrapperKind = TGRichMessageTextKindUnderline; break;
        case (int32_t)0x9bf8bb95: wrapperKind = TGRichMessageTextKindStrike; break;
        case (int32_t)0x6c3f19b9: wrapperKind = TGRichMessageTextKindFixed; break;
        case (int32_t)0xed6a8504: wrapperKind = TGRichMessageTextKindSubscript; break;
        case (int32_t)0xc7fb5e01: wrapperKind = TGRichMessageTextKindSuperscript; break;
        case (int32_t)0x034b8621: wrapperKind = TGRichMessageTextKindMarked; break;
        case (int32_t)0x4c2a5d62: wrapperKind = TGRichMessageTextKindSpoiler; break;
        case (int32_t)0xcd24cf44: wrapperKind = TGRichMessageTextKindMention; break;
        case (int32_t)0x519524ea: wrapperKind = TGRichMessageTextKindHashtag; break;
        case (int32_t)0x02ff29d3: wrapperKind = TGRichMessageTextKindBotCommand; break;
        case (int32_t)0x7b9e1801: wrapperKind = TGRichMessageTextKindCashtag; break;
        case (int32_t)0xac6a83aa: wrapperKind = TGRichMessageTextKindAutoUrl; break;
        case (int32_t)0xc556a45d: wrapperKind = TGRichMessageTextKindAutoEmail; break;
        case (int32_t)0x24c26789: wrapperKind = TGRichMessageTextKindAutoPhone; break;
        case (int32_t)0xb956812d: wrapperKind = TGRichMessageTextKindBankCard; break;
        default: break;
    }

    if (reader.ok() && wrapperKind != TGRichMessageTextKindEmpty)
    {
        TGRichMessageText *child = TGRichTLReadText(reader);
        result = TGRichTLText(wrapperKind, nil, TGRichTLWrap(child), 0, 0, 0, CGSizeZero, nil);
    }
    else if (reader.ok())
    {
        switch (signature)
        {
            case (int32_t)0xdc3d824f:
                result = TGRichTLText(TGRichMessageTextKindEmpty, nil, nil, 0, 0, 0, CGSizeZero, nil);
                break;
            case (int32_t)0x744694e0:
                result = TGRichTLText(TGRichMessageTextKindPlain, reader.readString(), nil, 0, 0, 0, CGSizeZero, nil);
                break;
            case (int32_t)0x3c2884c1:
            {
                TGRichMessageText *child = TGRichTLReadText(reader);
                NSString *url = reader.readString();
                int64_t webpageId = reader.readInt64();
                result = TGRichTLText(TGRichMessageTextKindUrl, url, TGRichTLWrap(child), webpageId, 0, 0, CGSizeZero, nil);
                break;
            }
            case (int32_t)0xde5a0dd6:
            {
                TGRichMessageText *child = TGRichTLReadText(reader);
                NSString *email = reader.readString();
                result = TGRichTLText(TGRichMessageTextKindEmail, email, TGRichTLWrap(child), 0, 0, 0, CGSizeZero, nil);
                break;
            }
            case (int32_t)0x7e6260d7:
                result = TGRichTLText(TGRichMessageTextKindConcat, nil, TGRichTLReadTexts(reader), 0, 0, 0, CGSizeZero, nil);
                break;
            case (int32_t)0x1ccb966a:
            {
                TGRichMessageText *child = TGRichTLReadText(reader);
                NSString *phone = reader.readString();
                result = TGRichTLText(TGRichMessageTextKindPhone, phone, TGRichTLWrap(child), 0, 0, 0, CGSizeZero, nil);
                break;
            }
            case (int32_t)0x081ccf4f:
            {
                int64_t documentId = reader.readInt64();
                int32_t width = reader.readInt32();
                int32_t height = reader.readInt32();
                result = TGRichTLText(TGRichMessageTextKindImage, nil, nil, documentId, 0, 0, CGSizeMake(MAX(0, width), MAX(0, height)), nil);
                break;
            }
            case (int32_t)0x35553762:
            {
                TGRichMessageText *child = TGRichTLReadText(reader);
                NSString *name = reader.readString();
                result = TGRichTLText(TGRichMessageTextKindAnchor, name, TGRichTLWrap(child), 0, 0, 0, CGSizeZero, nil);
                break;
            }
            case (int32_t)0x9d2eac97:
                result = TGRichTLText(TGRichMessageTextKindMath, reader.readString(), nil, 0, 0, 0, CGSizeZero, nil);
                break;
            case (int32_t)0xa26156c0:
            {
                int64_t documentId = reader.readInt64();
                NSString *alt = reader.readString();
                result = TGRichTLText(TGRichMessageTextKindCustomEmoji, alt, nil, documentId, 0, 0, CGSizeZero, nil);
                break;
            }
            case (int32_t)0x01a9fbfc:
            {
                TGRichMessageText *child = TGRichTLReadText(reader);
                int64_t userId = reader.readInt64();
                result = TGRichTLText(TGRichMessageTextKindMentionName, nil, TGRichTLWrap(child), userId, 0, 0, CGSizeZero, nil);
                break;
            }
            case (int32_t)0xa5b45e2b:
            {
                int32_t flags = reader.readInt32();
                TGRichMessageText *child = TGRichTLReadText(reader);
                int32_t date = reader.readInt32();
                result = TGRichTLText(TGRichMessageTextKindDate, nil, TGRichTLWrap(child), 0, date, flags, CGSizeZero, nil);
                break;
            }
            case (int32_t)0x9686cb50:
            {
                TGRichMessageText *child = TGRichTLReadText(reader);
                TGRichMessageText *oldText = TGRichTLReadText(reader);
                NSMutableArray *texts = [[NSMutableArray alloc] init];
                [texts addObject:child ?: TGRichTLText(TGRichMessageTextKindEmpty, nil, nil, 0, 0, 0, CGSizeZero, nil)];
                if (oldText != nil)
                    [texts addObject:oldText];
                result = TGRichTLText(TGRichMessageTextKindDiff, nil, texts, 0, 0, 0, CGSizeZero, nil);
                break;
            }
            case (int32_t)0xafc79cd6:
            {
                int32_t flags = reader.readInt32();
                TGRichMessageText *child = TGRichTLReadText(reader);
                TGRichMessageButton *button = TGRichTLReadButtonType(reader, child, 0);
                int32_t style = 0;
                if (flags & (1 << 0))
                    style = TGRichTLReadButtonStyle(reader);
                if (button != nil)
                    button = [[TGRichMessageButton alloc] initWithText:child action:button.action string:button.string data:button.data identifier:button.identifier samePeer:button.samePeer requiresPassword:button.requiresPassword style:style];
                result = TGRichTLText(TGRichMessageTextKindButton, nil, TGRichTLWrap(child), 0, 0, 0, CGSizeZero, button);
                break;
            }
            default:
                reader.readObjectWithSignature(signature);
                result = TGRichTLText(TGRichMessageTextKindEmpty, nil, nil, 0, 0, 0, CGSizeZero, nil);
                break;
        }
    }

    reader.leave();
    return reader.ok() ? result : nil;
}

static void TGRichTLReadCaption(TGRichTLReader &reader, TGRichMessageBlock *block)
{
    int32_t signature = reader.readInt32();
    if (!reader.ok())
        return;
    if (signature != (int32_t)0x6f747657)
    {
        reader.readObjectWithSignature(signature);
        return;
    }
    block.caption = TGRichTLReadText(reader);
    block.credit = TGRichTLReadText(reader);
}

static NSArray *TGRichTLReadBlocks(TGRichTLReader &reader)
{
    int32_t count = reader.readVectorCount();
    NSMutableArray *blocks = [[NSMutableArray alloc] init];
    for (int32_t i = 0; i < count && reader.ok(); i++)
    {
        TGRichMessageBlock *block = TGRichTLReadBlock(reader);
        if (block != nil)
            [blocks addObject:block];
    }
    return blocks;
}

static NSArray *TGRichTLReadListItems(TGRichTLReader &reader)
{
    int32_t count = reader.readVectorCount();
    NSMutableArray *items = [[NSMutableArray alloc] init];
    for (int32_t i = 0; i < count && reader.ok(); i++)
    {
        int32_t signature = reader.readInt32();
        if (!reader.ok())
            break;
        switch (signature)
        {
            case (int32_t)0x2f58683c:
            {
                int32_t flags = reader.readInt32();
                TGRichMessageText *text = TGRichTLReadText(reader);
                if (reader.ok())
                    [items addObject:[[TGRichMessageListItem alloc] initWithFlags:flags & 0x3 number:nil text:text blocks:nil value:0 numberingType:nil]];
                break;
            }
            case (int32_t)0x63ca67aa:
            {
                int32_t flags = reader.readInt32();
                NSArray *blocks = TGRichTLReadBlocks(reader);
                if (reader.ok())
                    [items addObject:[[TGRichMessageListItem alloc] initWithFlags:flags & 0x3 number:nil text:nil blocks:blocks value:0 numberingType:nil]];
                break;
            }
            case (int32_t)0x15031189:
            case (int32_t)0x8ff2d5f0:
            {
                int32_t flags = reader.readInt32();
                NSString *number = nil;
                if (flags & (1 << 2))
                    number = reader.readString();
                TGRichMessageText *text = nil;
                NSArray *blocks = nil;
                if (signature == (int32_t)0x15031189)
                    text = TGRichTLReadText(reader);
                else
                    blocks = TGRichTLReadBlocks(reader);
                int32_t value = 0;
                if (flags & (1 << 3))
                    value = reader.readInt32();
                NSString *type = nil;
                if (flags & (1 << 4))
                    type = reader.readString();
                if (reader.ok())
                    [items addObject:[[TGRichMessageListItem alloc] initWithFlags:flags & 0xf number:number text:text blocks:blocks value:value numberingType:type]];
                break;
            }
            default:
                reader.readObjectWithSignature(signature);
                break;
        }
    }
    return items;
}

static NSArray *TGRichTLReadTableRows(TGRichTLReader &reader)
{
    int32_t count = reader.readVectorCount();
    NSMutableArray *rows = [[NSMutableArray alloc] init];
    for (int32_t i = 0; i < count && reader.ok(); i++)
    {
        int32_t signature = reader.readInt32();
        if (!reader.ok())
            break;
        if (signature != (int32_t)0xe0c0c5e5)
        {
            reader.readObjectWithSignature(signature);
            continue;
        }
        int32_t cellCount = reader.readVectorCount();
        NSMutableArray *cells = [[NSMutableArray alloc] init];
        for (int32_t j = 0; j < cellCount && reader.ok(); j++)
        {
            int32_t cellSignature = reader.readInt32();
            if (!reader.ok())
                break;
            if (cellSignature != (int32_t)0x34566b6a)
            {
                reader.readObjectWithSignature(cellSignature);
                continue;
            }
            int32_t flags = reader.readInt32();
            TGRichMessageText *text = nil;
            if (flags & (1 << 7))
                text = TGRichTLReadText(reader);
            int32_t colspan = 1;
            if (flags & (1 << 1))
                colspan = reader.readInt32();
            int32_t rowspan = 1;
            if (flags & (1 << 2))
                rowspan = reader.readInt32();
            if (reader.ok())
                [cells addObject:[[TGRichMessageTableCell alloc] initWithFlags:flags & 0x79 text:text colspan:MIN(64, colspan) rowspan:MIN(256, rowspan)]];
        }
        if (reader.ok())
            [rows addObject:cells];
    }
    return rows;
}

static NSArray *TGRichTLReadRelatedArticles(TGRichTLReader &reader)
{
    int32_t count = reader.readVectorCount();
    NSMutableArray *articles = [[NSMutableArray alloc] init];
    for (int32_t i = 0; i < count && reader.ok(); i++)
    {
        int32_t signature = reader.readInt32();
        if (!reader.ok())
            break;
        if (signature != (int32_t)0xb390dc08)
        {
            reader.readObjectWithSignature(signature);
            continue;
        }
        int32_t flags = reader.readInt32();
        NSString *url = reader.readString();
        int64_t webpageId = reader.readInt64();
        NSString *title = (flags & (1 << 0)) ? reader.readString() : nil;
        NSString *description = (flags & (1 << 1)) ? reader.readString() : nil;
        int64_t photoId = (flags & (1 << 2)) ? reader.readInt64() : 0;
        NSString *author = (flags & (1 << 3)) ? reader.readString() : nil;
        int32_t publishedDate = (flags & (1 << 4)) ? reader.readInt32() : 0;
        if (reader.ok())
            [articles addObject:[[TGRichMessageRelatedArticle alloc] initWithUrl:url webpageId:webpageId title:title articleDescription:description photoId:photoId author:author publishedDate:publishedDate]];
    }
    return articles;
}

static void TGRichTLReadGeoPoint(TGRichTLReader &reader, TGRichMessageBlock *block, bool input)
{
    int32_t signature = reader.readInt32();
    if (!reader.ok())
        return;
    if (!input && signature == (int32_t)0xb2a2f663)
    {
        int32_t flags = reader.readInt32();
        block.longitude = reader.readDouble();
        block.latitude = reader.readDouble();
        reader.readInt64();
        if (flags & (1 << 0))
            reader.readInt32();
    }
    else if (input && signature == (int32_t)0x48222faf)
    {
        int32_t flags = reader.readInt32();
        block.latitude = reader.readDouble();
        block.longitude = reader.readDouble();
        if (flags & (1 << 0))
            reader.readInt32();
    }
    else if (signature == (int32_t)0x1117dd5f || signature == (int32_t)0xe4c123d6)
    {
        block.kind = TGRichMessageBlockKindUnsupported;
    }
    else
    {
        reader.readObjectWithSignature(signature);
        block.kind = TGRichMessageBlockKindUnsupported;
    }
}

static TGRichMessageBlock *TGRichTLTextBlock(TGRichTLReader &reader, TGRichMessageBlockKind kind, int32_t level)
{
    TGRichMessageBlock *block = [[TGRichMessageBlock alloc] initWithKind:kind];
    block.level = level;
    block.text = TGRichTLReadText(reader);
    return block;
}

static TGRichMessageBlock *TGRichTLReadBlock(TGRichTLReader &reader)
{
    if (!reader.enter())
        return nil;

    int32_t signature = reader.readInt32();
    TGRichMessageBlock *block = nil;

    if (reader.ok())
    {
        switch (signature)
        {
            case (int32_t)0x13567e8a:
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindUnsupported];
                break;
            case (int32_t)0x70abc3fd:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindTitle, 0);
                break;
            case (int32_t)0x8ffa9a1f:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindSubtitle, 0);
                break;
            case (int32_t)0xbaafe5e0:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindAuthorDate, 0);
                block.date = reader.readInt32();
                break;
            case (int32_t)0xbfd064ec:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindHeading, 2);
                break;
            case (int32_t)0xf12bb6e1:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindHeading, 3);
                break;
            case (int32_t)0xbaff072f:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindHeading, 1);
                break;
            case (int32_t)0x096b2aec:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindHeading, 2);
                break;
            case (int32_t)0x67e731ad:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindHeading, 3);
                break;
            case (int32_t)0xb532772b:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindHeading, 4);
                break;
            case (int32_t)0xdbbe6c6a:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindHeading, 5);
                break;
            case (int32_t)0x682a41a9:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindHeading, 6);
                break;
            case (int32_t)0x1e148390:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindKicker, 0);
                break;
            case (int32_t)0x467a0766:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindParagraph, 0);
                break;
            case (int32_t)0xc070d93e:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindPreformatted, 0);
                block.string = reader.readString();
                break;
            case (int32_t)0x48870999:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindFooter, 0);
                break;
            case (int32_t)0x3c29a3e2:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindThinking, 0);
                break;
            case (int32_t)0xdb20b188:
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindDivider];
                break;
            case (int32_t)0xce0d37b0:
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindAnchor];
                block.string = reader.readString();
                break;
            case (int32_t)0xe4e88011:
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindList];
                block.items = TGRichTLReadListItems(reader);
                break;
            case (int32_t)0x1fd6f6c1:
            {
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindOrderedList];
                int32_t flags = reader.readInt32();
                block.items = TGRichTLReadListItems(reader);
                if (flags & (1 << 0))
                    block.start = reader.readInt32();
                if (flags & (1 << 1))
                    block.string = reader.readString();
                block.flags = flags & 0x7;
                break;
            }
            case (int32_t)0x263d7c26:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindBlockquote, 0);
                block.secondaryText = TGRichTLReadText(reader);
                break;
            case (int32_t)0x66d1670b:
            {
                int32_t flags = reader.readInt32();
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindBlockquote, 0);
                block.secondaryText = TGRichTLReadText(reader);
                block.flags = flags & TGRichMessageBlockFlagBlockquoteCollapsed;
                break;
            }
            case (int32_t)0x0e6e47c4:
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindBlockquoteBlocks];
                block.blocks = TGRichTLReadBlocks(reader);
                block.secondaryText = TGRichTLReadText(reader);
                break;
            case (int32_t)0x4f4456d3:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindPullquote, 0);
                block.secondaryText = TGRichTLReadText(reader);
                break;
            case (int32_t)0x1759c560:
            {
                int32_t flags = reader.readInt32();
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindPhoto];
                block.flags = flags & TGRichMessageBlockFlagPhotoSpoiler;
                block.identifier = reader.readInt64();
                TGRichTLReadCaption(reader, block);
                if (flags & (1 << 0))
                {
                    block.string = reader.readString();
                    block.secondaryIdentifier = reader.readInt64();
                }
                break;
            }
            case (int32_t)0x7c8fe7b6:
            {
                int32_t flags = reader.readInt32();
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindVideo];
                block.flags = flags & 0x7;
                block.identifier = reader.readInt64();
                TGRichTLReadCaption(reader, block);
                break;
            }
            case (int32_t)0x39f23300:
            {
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindCover];
                TGRichMessageBlock *cover = TGRichTLReadBlock(reader);
                block.blocks = cover == nil ? @[] : @[cover];
                break;
            }
            case (int32_t)0xa8718dc5:
            {
                int32_t flags = reader.readInt32();
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindEmbed];
                block.flags = flags & (TGRichMessageBlockFlagEmbedFullWidth | TGRichMessageBlockFlagEmbedAllowScrolling);
                if (flags & (1 << 1))
                    block.string = reader.readString();
                if (flags & (1 << 2))
                    block.secondaryString = reader.readString();
                if (flags & (1 << 4))
                    block.identifier = reader.readInt64();
                if (flags & (1 << 5))
                {
                    int32_t width = reader.readInt32();
                    int32_t height = reader.readInt32();
                    block.size = CGSizeMake(MAX(0, width), MAX(0, height));
                }
                TGRichTLReadCaption(reader, block);
                break;
            }
            case (int32_t)0xf259a80b:
            {
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindEmbedPost];
                block.string = reader.readString();
                block.secondaryIdentifier = reader.readInt64();
                block.identifier = reader.readInt64();
                block.secondaryString = reader.readString();
                block.date = reader.readInt32();
                block.blocks = TGRichTLReadBlocks(reader);
                TGRichTLReadCaption(reader, block);
                break;
            }
            case (int32_t)0x65a0fa4d:
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindCollage];
                block.blocks = TGRichTLReadBlocks(reader);
                TGRichTLReadCaption(reader, block);
                break;
            case (int32_t)0x031f9590:
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindSlideshow];
                block.blocks = TGRichTLReadBlocks(reader);
                TGRichTLReadCaption(reader, block);
                break;
            case (int32_t)0xef1751b5:
            {
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindChannel];
                id chat = reader.readObject();
                if ([chat isKindOfClass:[TLChat$channel class]])
                {
                    TLChat$channel *channel = chat;
                    block.identifier = TGPeerIdFromChannelId(channel.n_id);
                    block.secondaryIdentifier = channel.access_hash;
                    block.string = channel.title;
                    block.secondaryString = channel.username;
                }
                break;
            }
            case (int32_t)0x804361ea:
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindAudio];
                block.identifier = reader.readInt64();
                TGRichTLReadCaption(reader, block);
                break;
            case (int32_t)0x38fa3ba3:
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindDocument];
                block.identifier = reader.readInt64();
                TGRichTLReadCaption(reader, block);
                break;
            case (int32_t)0xbf4dea82:
            {
                int32_t flags = reader.readInt32();
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindTable];
                block.flags = flags & 0x7;
                block.text = TGRichTLReadText(reader);
                block.rows = TGRichTLReadTableRows(reader);
                break;
            }
            case (int32_t)0x76768bed:
            {
                int32_t flags = reader.readInt32();
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindDetails];
                block.flags = flags & TGRichMessageBlockFlagDetailsOpen;
                block.blocks = TGRichTLReadBlocks(reader);
                block.text = TGRichTLReadText(reader);
                break;
            }
            case (int32_t)0x16115a96:
                block = TGRichTLTextBlock(reader, TGRichMessageBlockKindRelatedArticles, 0);
                block.articles = TGRichTLReadRelatedArticles(reader);
                break;
            case (int32_t)0xa44f3ef6:
            case (int32_t)0x574b617f:
            {
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindMap];
                TGRichTLReadGeoPoint(reader, block, signature == (int32_t)0x574b617f);
                block.zoom = reader.readInt32();
                int32_t width = reader.readInt32();
                int32_t height = reader.readInt32();
                block.size = CGSizeMake(MAX(0, width), MAX(0, height));
                TGRichTLReadCaption(reader, block);
                break;
            }
            case (int32_t)0x59080c20:
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindMath];
                block.string = reader.readString();
                break;
            case (int32_t)0x6d640318:
            {
                int32_t flags = reader.readInt32();
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindButtonRow];
                block.flags = flags & 0x7;
                int32_t count = reader.readVectorCount();
                NSMutableArray *buttons = [[NSMutableArray alloc] init];
                for (int32_t i = 0; i < count && reader.ok(); i++)
                {
                    TGRichMessageButton *button = TGRichTLReadPageButton(reader);
                    if (button != nil)
                        [buttons addObject:button];
                }
                block.buttons = buttons;
                break;
            }
            default:
                reader.readObjectWithSignature(signature);
                block = [[TGRichMessageBlock alloc] initWithKind:TGRichMessageBlockKindUnsupported];
                break;
        }
    }

    reader.leave();
    return reader.ok() ? block : nil;
}

static NSArray *TGRichTLReadObjects(TGRichTLReader &reader)
{
    int32_t count = reader.readVectorCount();
    NSMutableArray *objects = [[NSMutableArray alloc] init];
    for (int32_t i = 0; i < count && reader.ok(); i++)
    {
        id object = reader.readObject();
        if (object != nil)
            [objects addObject:object];
    }
    return objects;
}

TGRichMessage *TGRichMessageReadTL(NSInputStream *is, id<TLSerializationEnvironment> environment, NSArray **photos, NSArray **documents, NSError **error)
{
    TGRichTLReader reader(is, environment);

    int32_t signatureOrFlags = reader.readInt32();
    int32_t flags = 0;
    if (reader.ok())
    {
        if (signatureOrFlags == (int32_t)0xbaf39d8b)
            flags = reader.readInt32();
        else if (signatureOrFlags >= 0 && signatureOrFlags < 0x10000)
            flags = signatureOrFlags;
        else
            reader.fail([[NSString alloc] initWithFormat:@"RichMessage: unexpected constructor 0x%08x", signatureOrFlags]);
    }

    NSArray *blocks = TGRichTLReadBlocks(reader);
    NSArray *photoObjects = TGRichTLReadObjects(reader);
    NSArray *documentObjects = TGRichTLReadObjects(reader);

    if (!reader.ok())
    {
        if (error != NULL)
            *error = reader.error;
        return nil;
    }

    if (photos != NULL)
        *photos = photoObjects;
    if (documents != NULL)
        *documents = documentObjects;

    return [[TGRichMessage alloc] initWithRtl:(flags & (1 << 0)) != 0 part:(flags & (1 << 1)) != 0 blocks:blocks photos:nil documents:nil];
}
