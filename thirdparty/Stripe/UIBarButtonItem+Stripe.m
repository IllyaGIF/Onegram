//
//  UIBarButtonItem+Stripe.m
//  Stripe
//
//  Created by Jack Flintermann on 5/18/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "UIBarButtonItem+Stripe.h"
#import "STPImageLibrary.h"
#import "STPImageLibrary+Private.h"
#import "STPTheme.h"

@implementation UIBarButtonItem (Stripe)

+ (instancetype)stp_backButtonItemWithTitle:(NSString *)title
                                      style:(UIBarButtonItemStyle)style
                                     target:(id)target
                                     action:(SEL)action {
    UIBarButtonItem *item = [[self alloc] initWithTitle:title
                                                             style:style
                                                            target:target
                                                            action:action];
    UIImage *chevron = [STPImageLibrary leftChevronIcon];
    CGFloat yPadding = (30 - chevron.size.height) / 2;
    UIImage *paddedChevron = [STPImageLibrary paddedImageWithInsets:UIEdgeInsetsMake(yPadding, 0, yPadding, 30)
                                                           forImage:chevron];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    [item setBackgroundImage:paddedChevron forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
#else
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:paddedChevron forState:UIControlStateNormal];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [button sizeToFit];
    button.frame = CGRectMake(0.0f, 0.0f, MAX(44.0f, button.frame.size.width), 30.0f);
    item.customView = button;
#endif
    return item;
}

- (void)stp_setTheme:(STPTheme *)theme {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    UIImage *image = [self backgroundImageForState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    if (image) {
        UIImage *enabledImage = [STPImageLibrary imageWithTintColor:theme.accentColor forImage:image];
        UIImage *disabledImage = [STPImageLibrary imageWithTintColor:theme.secondaryForegroundColor forImage:image];
        [self setBackgroundImage:enabledImage forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [self setBackgroundImage:disabledImage forState:UIControlStateDisabled barMetrics:UIBarMetricsDefault];
    }
    
    self.tintColor = self.enabled ? theme.accentColor : theme.secondaryForegroundColor;
    [self setTitleTextAttributes:@{
                                   NSFontAttributeName: self.style == UIBarButtonItemStylePlain ? theme.font : theme.emphasisFont,
                                   NSForegroundColorAttributeName: theme.accentColor,
                                   }
                        forState:UIControlStateNormal];
    [self setTitleTextAttributes:@{
                                   NSFontAttributeName: self.style == UIBarButtonItemStylePlain ? theme.font : theme.emphasisFont,
                                   NSForegroundColorAttributeName: theme.secondaryForegroundColor,
                                   }
                        forState:UIControlStateDisabled];
#else
    UIButton *button = [self.customView isKindOfClass:[UIButton class]] ? (UIButton *)self.customView : nil;
    if (button == nil && self.title.length != 0) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setTitle:self.title forState:UIControlStateNormal];
        [button addTarget:self.target action:self.action forControlEvents:UIControlEventTouchUpInside];
        [button sizeToFit];
        button.frame = CGRectMake(0.0f, 0.0f, MAX(44.0f, button.frame.size.width), 30.0f);
        self.customView = button;
    }
    if (button != nil) {
        UIImage *image = [button imageForState:UIControlStateNormal];
        if (image != nil) {
            [button setImage:[STPImageLibrary imageWithTintColor:theme.accentColor forImage:image] forState:UIControlStateNormal];
            [button setImage:[STPImageLibrary imageWithTintColor:theme.secondaryForegroundColor forImage:image] forState:UIControlStateDisabled];
        }
        button.titleLabel.font = self.style == UIBarButtonItemStylePlain ? theme.font : theme.emphasisFont;
        [button setTitleColor:theme.accentColor forState:UIControlStateNormal];
        [button setTitleColor:theme.secondaryForegroundColor forState:UIControlStateDisabled];
        button.enabled = self.enabled;
    }
#endif
}

@end

void linkUIBarButtonItemCategory(void){}
