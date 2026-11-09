#import "TGCollectionItem.h"

typedef enum {
    TGProfileActionIconMessage = 0,
    TGProfileActionIconCall,
    TGProfileActionIconMute,
    TGProfileActionIconUnmute,
    TGProfileActionIconShare,
    TGProfileActionIconLeave,
    TGProfileActionIconMore,
    TGProfileActionIconAddMember,
    TGProfileActionIconSearch,
    TGProfileActionIconEdit,
    TGProfileActionIconCamera,
    TGProfileActionIconProfile,
    TGProfileActionIconGift,
    TGProfileActionIconStory,
    TGProfileActionIconSettings,
    TGProfileActionIconBolt,
    TGProfileActionIconHeart,
    TGProfileActionIconHeartFilled
} TGProfileActionIcon;

@interface TGProfileAction : NSObject

@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, readonly) TGProfileActionIcon icon;
@property (nonatomic, readonly) SEL action;
@property (nonatomic, readonly) bool destructive;
@property (nonatomic, readonly) bool selected;
@property (nonatomic, copy, readonly) void (^handler)(void);

- (instancetype)initWithTitle:(NSString *)title icon:(TGProfileActionIcon)icon action:(SEL)action;
- (instancetype)initWithTitle:(NSString *)title icon:(TGProfileActionIcon)icon selected:(bool)selected handler:(void (^)(void))handler;
- (instancetype)initWithTitle:(NSString *)title icon:(TGProfileActionIcon)icon action:(SEL)action destructive:(bool)destructive;

+ (instancetype)notificationsActionMuted:(bool)muted muteAction:(SEL)muteAction unmuteAction:(SEL)unmuteAction;

@end

@interface TGProfileActionsCollectionItem : TGCollectionItem

@property (nonatomic, weak) id target;
@property (nonatomic, strong) NSArray *actions;
@property (nonatomic, strong) NSArray *extraActions;
@property (nonatomic, strong) UIColor *buttonColor;
@property (nonatomic, copy) NSDictionary *buttonStyle;

- (instancetype)initWithTarget:(id)target;

- (UIView *)sourceViewForActionWithSelector:(SEL)action;

@end
