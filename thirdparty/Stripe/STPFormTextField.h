//
//  STPFormTextField.h
//  Stripe
//
//  Created by Jack Flintermann on 7/16/15.
//  Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class STPFormTextField;

typedef NS_ENUM(NSInteger, STPFormTextFieldAutoFormattingBehavior) {
    STPFormTextFieldAutoFormattingBehaviorNone,
    STPFormTextFieldAutoFormattingBehaviorPhoneNumbers,
    STPFormTextFieldAutoFormattingBehaviorCardNumbers,
    STPFormTextFieldAutoFormattingBehaviorExpiration,
};

@protocol STPFormTextFieldDelegate <UITextFieldDelegate>
@optional
- (void)formTextFieldDidBackspaceOnEmpty:(STPFormTextField *_Nonnull)formTextField;
- (NSAttributedString *_Nonnull)formTextField:(STPFormTextField *_Nonnull)formTextField
           modifyIncomingTextChange:(NSAttributedString *_Nonnull)input;
- (void)formTextFieldTextDidChange:(STPFormTextField *_Nonnull)textField;
@end

@interface STPFormTextField : UITextField

@property(nonatomic, readwrite) UIColor *_Nullable defaultColor;
@property(nonatomic, readwrite) UIColor *_Nullable errorColor;
@property(nonatomic, readwrite) UIColor *_Nullable placeholderColor;

@property(nonatomic, readwrite, assign)BOOL selectionEnabled; // defaults to NO
@property(nonatomic, readwrite, assign)BOOL preservesContentsOnPaste; // defaults to NO
@property(nonatomic, readwrite, assign)STPFormTextFieldAutoFormattingBehavior autoFormattingBehavior;
@property(nonatomic, readwrite, assign)BOOL validText;
@property(nonatomic, readwrite, unsafe_unretained)id<STPFormTextFieldDelegate>formDelegate;

- (BOOL)hasText;
- (void)insertText:(NSString *)text;

- (CGSize)measureTextSize;

@end
