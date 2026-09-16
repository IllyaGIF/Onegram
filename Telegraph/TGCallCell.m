#import "TGCallCell.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTelegraph.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"
#import "TGDialogListCellEditingControls.h"

#import "TGPresentation.h"

static UIImage *TGCallCellBrandedIOS6HighResolutionImage(NSString *name)
{
    NSString *path = [[NSBundle mainBundle] pathForResource:[name stringByAppendingString:@"@3x"] ofType:@"png" inDirectory:@"ios6style"];
    if (path.length == 0)
        path = [[NSBundle mainBundle] pathForResource:[name stringByAppendingString:@"@3x"] ofType:@"png"];
    UIImage *image = path.length == 0 ? nil : [UIImage imageWithContentsOfFile:path];
    if (image != nil && image.CGImage != NULL)
        return [UIImage imageWithCGImage:image.CGImage scale:3.0f orientation:UIImageOrientationUp];
    return [TGPresentation brandedIOS6ResourceImage:name];
}

static UIImage *TGCallCellBrandedIOS6TypeIcon(NSString *name, bool destructive)
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });

    NSString *key = [NSString stringWithFormat:@"%@:%d", name, destructive ? 1 : 0];
    UIImage *cachedImage = nil;
    @synchronized(cache)
    {
        cachedImage = [cache objectForKey:key];
    }
    if (cachedImage != nil)
        return cachedImage;

    UIImage *mask = TGCallCellBrandedIOS6HighResolutionImage(name);
    if (mask == nil)
        return nil;

    CGSize size = CGSizeMake(16.0f, 16.0f);
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect rect = CGRectMake(0.0f, 0.0f, 16.0f, 16.0f);
    [mask drawInRect:rect];
    CGContextSetBlendMode(context, kCGBlendModeSourceIn);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat components[12];
    if (destructive)
    {
        components[0] = 1.0f;
        components[1] = 0.50f;
        components[2] = 0.50f;
        components[3] = 1.0f;
        components[4] = 0.98f;
        components[5] = 0.12f;
        components[6] = 0.12f;
        components[7] = 1.0f;
        components[8] = 0.78f;
        components[9] = 0.0f;
        components[10] = 0.0f;
        components[11] = 1.0f;
    }
    else
    {
        components[0] = 0.82f;
        components[1] = 0.82f;
        components[2] = 0.82f;
        components[3] = 1.0f;
        components[4] = 0.62f;
        components[5] = 0.62f;
        components[6] = 0.62f;
        components[7] = 1.0f;
        components[8] = 0.40f;
        components[9] = 0.40f;
        components[10] = 0.40f;
        components[11] = 1.0f;
    }
    CGFloat locations[] = {0.0f, 0.45f, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 3);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, size.height), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (image != nil)
    {
        @synchronized(cache)
        {
            [cache setObject:image forKey:key];
        }
    }
    return image;
}


static UIImage *TGCallCellBrandedIOS6InfoIcon(void)
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *source = TGImageNamed(@"ModernNavigationComposeButtonIcon.png");
        if (source == nil)
            source = [TGPresentation classicIOS6ResourceImage:@"ComposeMessageIcon"];
        if (source == nil)
            return;

        CGSize size = CGSizeMake(20.0f, 20.0f);
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGRect rect = CGRectMake(0.0f, 0.0f, size.width, size.height);
        [source drawInRect:rect];
        CGContextSetBlendMode(context, kCGBlendModeSourceIn);

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGFloat components[] = {
            0.78f, 0.78f, 0.78f, 1.0f,
            0.43f, 0.43f, 0.43f, 1.0f
        };
        CGFloat locations[] = {0.0f, 1.0f};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, size.height), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);

        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

@interface TGCallCell ()
{
    CALayer *_separatorLayer;
 
    TGDialogListCellEditingControls *_wrapView;
    UIImageView *_typeIcon;
    TGLetteredAvatarView *_avatarView;
    CALayer *_avatarShadowLayer;
    
    UILabel *_nameLabel;
    UILabel *_subLabel;
    UILabel *_dateLabel;
    
    TGModernButton *_infoButton;
    
    TGCallGroup *_callGroup;
}
@end

@implementation TGCallCell

@dynamic deletePressed;

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        if (iosMajorVersion() >= 7)
        {
            self.contentView.superview.clipsToBounds = false;
        }
        
        if (iosMajorVersion() <= 6 || [TGPresentation brandedIOS6Style]) {
            _separatorLayer = [[CALayer alloc] init];
            _separatorLayer.backgroundColor = TGSeparatorColor().CGColor;
            [self.layer addSublayer:_separatorLayer];
        }
        
        self.selectedBackgroundView = [[UIView alloc] init];
        
        _wrapView = [[TGDialogListCellEditingControls alloc] init];
        _wrapView.clipsToBounds = true;
        [_wrapView setLabelOnly:true];
        [self addSubview:_wrapView];
        
        _typeIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 34, 56)];
        _typeIcon.contentMode = UIViewContentModeCenter;
        [_wrapView addSubview:_typeIcon];
        
        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(10, 7 - TGScreenPixel, 62 + TGScreenPixel, 62 + TGScreenPixel)];
        [_avatarView setSingleFontSize:18.0f doubleFontSize:18.0f useBoldFont:false];
        _avatarView.fadeTransition = cpuCoreCount() > 1;
        [_wrapView addSubview:_avatarView];

        _avatarShadowLayer = [[CALayer alloc] init];
        _avatarShadowLayer.hidden = true;
        [_wrapView.layer insertSublayer:_avatarShadowLayer below:_avatarView.layer];
        
        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [TGPresentation brandedIOS6Style] ? TGBoldSystemFontOfSize(15.0f) : TGSystemFontOfSize(17.0f);
        _nameLabel.textColor = UIColorRGB(0x000000);
        if ([TGPresentation brandedIOS6Style])
        {
            _nameLabel.shadowColor = UIColorRGBA(0xffffff, 0.85f);
            _nameLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        }
        [_wrapView addSubview:_nameLabel];
        
        CGFloat subtitleFontSize = [TGPresentation brandedIOS6Style] ? 11.0f : 14.0f;
        
        _subLabel = [[UILabel alloc] init];
        _subLabel.font = TGSystemFontOfSize(subtitleFontSize);
        _subLabel.textColor = UIColorRGB(0x8e8e93);
        if ([TGPresentation brandedIOS6Style])
        {
            _subLabel.shadowColor = UIColorRGBA(0xffffff, 0.9f);
            _subLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        }
        [_wrapView addSubview:_subLabel];
        
        _dateLabel = [[UILabel alloc] init];
        _dateLabel.font = TGSystemFontOfSize(subtitleFontSize);
        _dateLabel.textColor = UIColorRGB(0x8e8e93);
        if ([TGPresentation brandedIOS6Style])
        {
            _dateLabel.shadowColor = UIColorRGBA(0xffffff, 0.9f);
            _dateLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        }
        [_wrapView addSubview:_dateLabel];
        
        _infoButton = [[TGModernButton alloc] init];
        _infoButton.adjustsImageWhenHighlighted = false;
        [_infoButton setImage:[TGPresentation brandedIOS6Style] ? TGCallCellBrandedIOS6InfoIcon() : TGImageNamed(@"CallInfoIcon") forState:UIControlStateNormal];
        [_infoButton addTarget:self action:@selector(infoButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_wrapView addSubview:_infoButton];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    
    [_wrapView setPresentation:presentation];
    
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
    self.backgroundColor = brandedIOS6Style ? UIColorRGB(0xfcfcfc) : (self.inSettings ? presentation.pallete.collectionMenuCellBackgroundColor : presentation.pallete.backgroundColor);
    
    _nameLabel.font = brandedIOS6Style ? TGBoldSystemFontOfSize(15.0f) : TGSystemFontOfSize(17.0f);
    CGFloat subtitleFontSize = brandedIOS6Style ? 11.0f : 14.0f;
    _subLabel.font = TGSystemFontOfSize(subtitleFontSize);
    _dateLabel.font = TGSystemFontOfSize(subtitleFontSize);
    [self updateName];
    _subLabel.backgroundColor = self.backgroundColor;
    _subLabel.textColor = brandedIOS6Style ? UIColorRGB(0x6b6b6b) : presentation.pallete.secondaryTextColor;
    _dateLabel.textColor = brandedIOS6Style ? UIColorRGB(0x5f5f5f) : presentation.pallete.secondaryTextColor;
    _dateLabel.backgroundColor = self.backgroundColor;
    [_infoButton setImage:brandedIOS6Style ? TGCallCellBrandedIOS6InfoIcon() : presentation.images.callsInfoIcon forState:UIControlStateNormal];
    if (!brandedIOS6Style)
        _typeIcon.image = presentation.images.callsOutgoingIcon;

    _nameLabel.shadowColor = brandedIOS6Style ? UIColorRGBA(0xffffff, 0.85f) : nil;
    _nameLabel.shadowOffset = brandedIOS6Style ? CGSizeMake(0.0f, 1.0f) : CGSizeZero;
    _subLabel.shadowColor = brandedIOS6Style ? UIColorRGBA(0xffffff, 0.9f) : nil;
    _subLabel.shadowOffset = brandedIOS6Style ? CGSizeMake(0.0f, 1.0f) : CGSizeZero;
    _dateLabel.shadowColor = brandedIOS6Style ? UIColorRGBA(0xffffff, 0.9f) : nil;
    _dateLabel.shadowOffset = brandedIOS6Style ? CGSizeMake(0.0f, 1.0f) : CGSizeZero;
    _nameLabel.backgroundColor = self.backgroundColor;

    _avatarShadowLayer.hidden = !brandedIOS6Style;
    _separatorLayer.backgroundColor = brandedIOS6Style ? UIColorRGB(0x9f9f9f).CGColor : presentation.pallete.separatorColor.CGColor;
    self.selectedBackgroundView.backgroundColor = presentation.pallete.selectionColor;
}

- (void)setDeletePressed:(void (^)(void))deletePressed
{
    _wrapView.requestDelete = deletePressed;
}

- (void)prepareForReuse
{
    [_wrapView setExpanded:false animated:false];
    
    [super prepareForReuse];
}

- (void)updateName
{
    TGUser *peer = _callGroup.peer;
    
    UIColor *nameColor = _callGroup.failed ? _presentation.pallete.destructiveColor : _presentation.pallete.textColor;
    
    if (iosMajorVersion() < 6)
    {
        if (_callGroup.messages.count > 1)
        {
            _nameLabel.text = [NSString stringWithFormat:
                               TGLocalized(@"Call.GroupFormat"),
                               peer.displayName,
                               [NSString stringWithFormat:@"%d", (int)_callGroup.messages.count]];
        }
        else
        {
            _nameLabel.text = peer.displayName;
        }
        
        _nameLabel.textColor = nameColor;
        return;
    }
    
    if (_callGroup.messages.count > 1)
    {
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineBreakMode = NSLineBreakByTruncatingMiddle;
        
        NSDictionary *attributes = style == nil ? @{
            NSForegroundColorAttributeName: _presentation.pallete.textColor,
            NSFontAttributeName: _nameLabel.font
        } : @{
            NSForegroundColorAttributeName: _presentation.pallete.textColor,
            NSFontAttributeName: _nameLabel.font,
            NSParagraphStyleAttributeName: style
        };
        NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:TGLocalized(@"Call.GroupFormat"), peer.displayName, [NSString stringWithFormat:@"%d", (int)_callGroup.messages.count]] attributes:attributes];
        
        if (_callGroup.failed)
        {
            NSRange nameRange = [text.string rangeOfString:peer.displayName];
            if (nameRange.location != NSNotFound)
                [text addAttribute:NSForegroundColorAttributeName value:nameColor range:nameRange];
        }
        
        _nameLabel.attributedText = text;
    }
    else
    {
        _nameLabel.text = peer.displayName;
        _nameLabel.textColor = nameColor;
    }
}

- (void)setupWithCallGroup:(TGCallGroup *)group
{
    _callGroup = group;
    
    TGUser *peer = group.peer;
    
    TGMessage *message = group.message;
    
    [_wrapView setLeftButtonTypes:@[] rightButtonTypes:@[ @(TGDialogListCellEditingControlsDelete) ]];
    
    [self updateName];
    [_nameLabel sizeToFit];
    
    _dateLabel.text = [TGDateUtils stringForMessageListDate:(int)message.date];
    [_dateLabel sizeToFit];
    
    if ([TGPresentation brandedIOS6Style])
    {
        TGMessage *callMessage = group.message;
        int reason = [callMessage.actionInfo.actionData[@"reason"] intValue];
        bool missed = group.failed || reason == TGCallDiscardReasonMissed || reason == TGCallDiscardReasonBusy;
        NSString *iconName = missed ? @"telephone-x-fill" : (group.outgoing ? @"telephone-outbound-fill" : @"telephone-inbound-fill");
        _typeIcon.hidden = false;
        _typeIcon.contentMode = UIViewContentModeScaleAspectFit;
        _typeIcon.image = TGCallCellBrandedIOS6TypeIcon(iconName, missed);
        _typeIcon.layer.shadowColor = [UIColor blackColor].CGColor;
        _typeIcon.layer.shadowOpacity = 0.28f;
        _typeIcon.layer.shadowRadius = 0.5f;
        _typeIcon.layer.shadowOffset = CGSizeMake(0.0f, 1.0f);
    }
    else
    {
        _typeIcon.hidden = !group.outgoing;
    }
    _subLabel.text = group.displayType;
    [_subLabel sizeToFit];
    
    CGFloat diameter = [TGPresentation brandedIOS6Style] ? 45.0f : (TGIsPad() ? 45.0f : 40.0f);
    
    UIImage *placeholder = [self.presentation.images avatarPlaceholderWithDiameter:diameter];    
    bool animateState = false;
    if (peer.photoUrlSmall.length != 0)
    {
        _avatarView.fadeTransitionDuration = animateState ? 0.14 : 0.3;
        if (![peer.photoFullUrlSmall isEqualToString:_avatarView.currentUrl])
        {
            if (animateState)
            {
                UIImage *currentImage = [_avatarView currentImage];
                [_avatarView loadImage:peer.photoFullUrlSmall filter:[TGPresentation brandedIOS6Style] ? @"scale:45x45" : (TGIsPad() ? @"circle:45x45" : @"circle:40x40") placeholder:(currentImage != nil ? currentImage : placeholder) forceFade:true];
            }
            else
                [_avatarView loadImage:peer.photoFullUrlSmall filter:[TGPresentation brandedIOS6Style] ? @"scale:45x45" : (TGIsPad() ? @"circle:45x45" : @"circle:40x40") placeholder:placeholder];
        }
    }
    else
    {
        [_avatarView loadUserPlaceholderWithSize:CGSizeMake(diameter, diameter) uid:(int32_t)peer.uid firstName:peer.firstName lastName:peer.lastName placeholder:placeholder];
    }

    if ([TGPresentation brandedIOS6Style])
    {
        _avatarView.clipsToBounds = true;
        _avatarView.layer.cornerRadius = 7.0f;
        _avatarView.layer.borderWidth = 1.0f;
        _avatarView.layer.borderColor = UIColorRGBA(0x686868, 0.85f).CGColor;
        _avatarShadowLayer.hidden = false;
        _avatarShadowLayer.backgroundColor = UIColorRGB(0xfcfcfc).CGColor;
        _avatarShadowLayer.cornerRadius = 7.0f;
        _avatarShadowLayer.shadowColor = [UIColor blackColor].CGColor;
        _avatarShadowLayer.shadowOpacity = 0.45f;
        _avatarShadowLayer.shadowRadius = 1.5f;
        _avatarShadowLayer.shadowOffset = CGSizeMake(0.0f, 1.5f);
    }

    [self setNeedsLayout];
}

- (void)infoButtonPressed
{
    if (self.infoPressed != nil)
        self.infoPressed();
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat contentOffset = self.contentView.frame.origin.x;
    CGFloat contentWidth = self.contentView.frame.size.width;
    
    [_wrapView setExpandable:contentOffset <= FLT_EPSILON];
    
    static Class separatorClass = nil;
    static dispatch_once_t onceToken2;
    dispatch_once(&onceToken2, ^{
        separatorClass = NSClassFromString(TGEncodeText(@"`VJUbcmfWjfxDfmmTfqbsbupsWjfx", -1));
    });
    for (UIView *subview in self.subviews) {
        if (subview.class == separatorClass) {
            CGRect frame = subview.frame;
            if (_isLastCell) {
                frame.size.width = self.bounds.size.width;
                frame.origin.x = 0.0f;
            } else {
                if (contentOffset > FLT_EPSILON) {
                    frame.size.width = self.bounds.size.width - 122.0f;
                    frame.origin.x = 122.0f;
                } else {
                    frame.size.width = self.bounds.size.width - 86.0f;
                    frame.origin.x = 86.0f;
                }
            }
            if (!CGRectEqualToRect(subview.frame, frame)) {
                subview.frame = frame;
            }
            break;
        }
    }
    
    static CGSize screenSize;
    static CGFloat widescreenWidth;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        screenSize = TGScreenSize();
        widescreenWidth = MAX(screenSize.width, screenSize.height);
    });
    
    CGSize rawSize = self.frame.size;
    CGSize size = rawSize;
    if (!TGIsPad())
    {
        if ([TGViewController hasTallScreen])
        {
            size.width = contentWidth;
        }
        else
        {
            if (rawSize.width >= widescreenWidth - FLT_EPSILON)
                size.width = screenSize.height - contentOffset;
            else
                size.width = screenSize.width - contentOffset;
        }
    }
    else
        size.width = rawSize.width - contentOffset;
    
    _wrapView.frame = CGRectMake(contentOffset, 0.0f, size.width, size.height);

    if ([TGPresentation brandedIOS6Style])
    {
        CGFloat separatorHeight = 1.0f;
        _separatorLayer.frame = CGRectMake(0.0f, self.frame.size.height - separatorHeight, self.frame.size.width, separatorHeight);
        _avatarView.frame = CGRectMake(7.0f, 6.0f, 45.0f, 45.0f);
        _avatarView.clipsToBounds = true;
        _avatarView.layer.cornerRadius = 7.0f;
        _avatarShadowLayer.frame = _avatarView.frame;
        _avatarShadowLayer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_avatarShadowLayer.bounds cornerRadius:7.0f].CGPath;
        _nameLabel.font = TGBoldSystemFontOfSize(15.0f);
        _subLabel.font = TGSystemFontOfSize(11.0f);
        _dateLabel.font = TGSystemFontOfSize(11.0f);
        [_dateLabel sizeToFit];
        CGFloat left = 57.0f;
        _dateLabel.frame = CGRectMake(size.width - _dateLabel.frame.size.width - 10.0f, 8.0f, _dateLabel.frame.size.width, 15.0f);
        CGSize nameSize = [_nameLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 20.0f)];
        CGFloat maximumNameWidth = MAX(0.0f, CGRectGetMinX(_dateLabel.frame) - left - 31.0f);
        CGFloat nameWidth = MIN(CGCeil(nameSize.width), maximumNameWidth);
        _nameLabel.frame = CGRectMake(left, 5.0f, nameWidth, 20.0f);
        _typeIcon.frame = CGRectMake(CGRectGetMaxX(_nameLabel.frame) + 4.0f, 7.0f, 16.0f, 16.0f);
        _subLabel.frame = CGRectMake(left, 31.0f, MAX(0.0f, size.width - left - 43.0f), 16.0f);
        _infoButton.frame = CGRectMake(size.width - 39.0f, 24.0f, 31.0f, 31.0f);
        _infoButton.imageView.layer.shadowColor = [UIColor blackColor].CGColor;
        _infoButton.imageView.layer.shadowOpacity = 0.35f;
        _infoButton.imageView.layer.shadowRadius = 0.75f;
        _infoButton.imageView.layer.shadowOffset = CGSizeMake(0.0f, 1.0f);
        return;
    }
    
    CGFloat separatorHeight = TGScreenPixel;
    CGFloat separatorInset = 86.0f;

    _separatorLayer.frame = CGRectMake(separatorInset, self.frame.size.height - separatorHeight, self.frame.size.width - separatorInset, separatorHeight);

    CGRect frame = self.selectedBackgroundView.frame;
    frame.origin.y = -1;
    frame.size.height = self.frame.size.height + 1;
    self.selectedBackgroundView.frame = frame;
    
    CGFloat leftPadding = TGIsPad() ? 36.0f : 34.0f;
    if (self.editing)
        leftPadding += 2;
    
    CGRect avatarFrame = CGRectMake(leftPadding, 8.0f, 40, 40);
    if (TGIsPad())
        avatarFrame = CGRectMake(leftPadding, 6.0f, 45, 45);
    
    if (!CGRectEqualToRect(_avatarView.frame, avatarFrame))
        _avatarView.frame = avatarFrame;
    
    leftPadding = CGRectGetMaxX(avatarFrame) + 12.0f;
    
    _dateLabel.frame = CGRectMake(size.width - _dateLabel.frame.size.width - 48.0f, 20.0f, _dateLabel.frame.size.width, _dateLabel.frame.size.height);
    
    _nameLabel.frame = CGRectMake(leftPadding, 8.0f, _dateLabel.frame.origin.x - leftPadding - 8.0f, _nameLabel.frame.size.height);
    _subLabel.frame = CGRectMake(leftPadding, 31.0f, _dateLabel.frame.origin.x - leftPadding - 8.0f, _subLabel.frame.size.height);
    
    _infoButton.frame = CGRectMake(size.width - 48.0f, 0, 48.0f, 56.0f);
}

- (void)setIsLastCell:(bool)isLastCell {
    if (_isLastCell != isLastCell) {
        _isLastCell = isLastCell;
        [self setNeedsLayout];
    }
}

- (bool)isEditingControlsExpanded {
    return [_wrapView isExpanded];
}

- (void)setEditingConrolsExpanded:(bool)expanded animated:(bool)animated {
    [_wrapView setExpanded:expanded animated:animated];
}

@end


@implementation TGCallGroup

- (instancetype)initWithMessages:(NSArray *)messages peer:(TGUser *)peer failed:(bool)failed
{
    self = [super init];
    if (self != nil)
    {
        _messages = messages;
        _peer = peer;
        _failed = failed;
    }
    return self;
}

- (NSString *)identifier
{
    return [NSString stringWithFormat:@"%d_%d", _peer.uid, self.message.mid];
}

- (TGMessage *)message
{
    return _messages.firstObject;
}

- (bool)outgoing
{
    for (TGMessage *message in _messages)
    {
        if (message.outgoing)
            return true;
    }
    return false;
}

typedef enum {
    TGCallDisplayTypeOutgoing,
    TGCallDisplayTypeIncoming,
    TGCallDisplayTypeCancelled,
    TGCallDisplayTypeMissed
} TGCallDisplayType;

- (NSString *)stringForDisplayType:(TGCallDisplayType)type
{
    switch (type)
    {
        case TGCallDisplayTypeOutgoing:
            return TGLocalized(@"Notification.CallOutgoingShort");
            
        case TGCallDisplayTypeIncoming:
            return TGLocalized(@"Notification.CallIncomingShort");
            
        case TGCallDisplayTypeCancelled:
            return TGLocalized(@"Notification.CallCanceledShort");
            
        case TGCallDisplayTypeMissed:
            return TGLocalized(@"Notification.CallMissedShort");
            
        default:
            return nil;
    }
}

- (NSString *)displayType
{
    if (self.failed)
        return TGLocalized(@"Notification.CallMissedShort");
    
    NSString *finalType = @"";
    NSMutableSet *types = [[NSMutableSet alloc] init];
    for (TGMessage *message in self.messages)
    {
        bool outgoing = message.outgoing;
        int reason = [message.actionInfo.actionData[@"reason"] intValue];
        bool missed = reason == TGCallDiscardReasonMissed || reason == TGCallDiscardReasonBusy;
        
        TGCallDisplayType type = missed ? (outgoing ? TGCallDisplayTypeCancelled : TGCallDisplayTypeMissed) : (outgoing ? TGCallDisplayTypeOutgoing : TGCallDisplayTypeIncoming);
        
        [types addObject:@(type)];
    }
    
    if (types.count > 1)
        [types removeObject:@(TGCallDisplayTypeCancelled)];
    
    NSArray *typesArray = [types sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"self" ascending:true]]];
    for (NSNumber *typeValue in typesArray)
    {
        NSString *type = [self stringForDisplayType:(TGCallDisplayType)typeValue.integerValue];
        if (finalType.length == 0)
            finalType = type;
        else
            finalType = [finalType stringByAppendingFormat:@", %@", type];
    }
    
    if (self.messages.count == 1)
    {
        TGMessage *message = self.message;
        int reason = [message.actionInfo.actionData[@"reason"] intValue];
        bool missed = reason == TGCallDiscardReasonMissed || reason == TGCallDiscardReasonBusy;
        
        int callDuration = [message.actionInfo.actionData[@"duration"] intValue];
        NSString *duration = missed || callDuration < 1 ? nil : [TGStringUtils stringForShortCallDurationSeconds:callDuration];
        finalType = duration != nil ? [NSString stringWithFormat:TGLocalized(@"Notification.CallTimeFormat"), finalType, duration] : finalType;
    }
    
    return finalType;
}

@end
