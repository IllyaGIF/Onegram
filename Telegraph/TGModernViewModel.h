/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

#import "TGModernViewStorage.h"

@protocol TGModernView;

@class TGModernDrawingOperation;

typedef void (*TGModernDrawingFunction)(CGContextRef context, TGModernDrawingOperation *operation);

@interface TGModernDrawingOperation : NSObject

@property (nonatomic, readonly) TGModernDrawingFunction function;
@property (nonatomic, readonly) CGPoint origin;
@property (nonatomic, readonly) CGRect rect;
@property (nonatomic, strong, readonly) id object;
@property (nonatomic, strong, readonly) id secondaryObject;
@property (nonatomic, strong, readonly) UIColor *color;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGFloat value;
@property (nonatomic, readonly) int flags;

@end

@interface TGModernDrawingRecording : NSObject

- (void)pushOffset:(CGPoint)offset;
- (void)popOffset:(CGPoint)offset;
- (void)addOperationWithFunction:(TGModernDrawingFunction)function rect:(CGRect)rect object:(id)object secondaryObject:(id)secondaryObject color:(UIColor *)color size:(CGSize)size value:(CGFloat)value flags:(int)flags;

- (bool)isEqualToRecording:(TGModernDrawingRecording *)other;
- (void)drawInContext:(CGContextRef)context;

@end

#if defined(ONEGRAM_DIAGNOSTICS)
#ifdef __cplusplus
extern "C" {
#endif
Class TGModernDrawingRecordingTakeFailedClass(void);
void TGModernViewModelBindTraceBegin(void);
NSString *TGModernViewModelBindTraceEnd(Class rootClass, CFAbsoluteTime rootDuration);
void TGModernViewModelBindTraceAddPhase(const char *phase, CFAbsoluteTime duration);
bool TGModernViewModelBindTraceActive(void);
#ifdef __cplusplus
}
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif
id TGModernViewModelAcquireGestureRecognizer(UIView *view, const void *poolKey, Class recognizerClass, id target, SEL action);
void TGModernViewModelRelinquishGestureRecognizer(UIGestureRecognizer *recognizer, const void *poolKey, id target, SEL action);
#ifdef __cplusplus
}
#endif

@interface TGModernViewModel : NSObject
{
    @private
    struct {
        int hasNoView : 1;
        int skipDrawInContext : 1;
        int disableSubmodelAutomaticBinding : 1;
        int viewUserInteractionDisabled : 1;
    } _modelFlags;
}

@property (nonatomic, strong) id modelId;

@property (nonatomic, strong) NSString *viewStateIdentifier;

@property (nonatomic) CGRect frame;
@property (nonatomic) CGPoint parentOffset;
@property (nonatomic) float alpha;
@property (nonatomic) bool hidden;

@property (nonatomic, strong, readonly) NSArray *submodels;

@property (nonatomic, copy) void (^unbindAction)();

- (bool)hasNoView;
- (void)setHasNoView:(bool)hasNoView;

- (bool)skipDrawInContext;
- (void)setSkipDrawInContext:(bool)skipDrawInContext;

- (bool)disableSubmodelAutomaticBinding;
- (void)setDisableSubmodelAutomaticBinding:(bool)disableSubmodelAutomaticBinding;

- (bool)viewUserInteractionDisabled;
- (void)setViewUserInteractionDisabled:(bool)viewUserInteractionDisabled;

- (Class)viewClass;
- (UIView<TGModernView> *)_dequeueView:(TGModernViewStorage *)viewStorage;
- (UIView<TGModernView> *)_dequeueView:(TGModernViewStorage *)viewStorage preferredSuperview:(UIView *)preferredSuperview;

- (UIView<TGModernView> *)boundView;
- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage;
- (void)unbindView:(TGModernViewStorage *)viewStorage;
- (void)moveViewToContainer:(UIView *)container;

- (void)_offsetBoundViews:(CGSize)offset;

- (void)drawInContext:(CGContextRef)context;
- (void)drawSubmodelsInContext:(CGContextRef)context;

- (bool)recordDrawing:(TGModernDrawingRecording *)recording;
- (bool)recordBaseDrawing:(TGModernDrawingRecording *)recording;
- (bool)recordSubmodelsDrawing:(TGModernDrawingRecording *)recording;
- (bool)drawsInContextWithImplementationOfClass:(Class)implementingClass;

- (void)sizeToFit;
- (CGRect)bounds;

- (bool)containsSubmodel:(TGModernViewModel *)model;
- (void)addSubmodel:(TGModernViewModel *)model;
- (void)insertSubmodel:(TGModernViewModel *)model belowSubmodel:(TGModernViewModel *)belowSubmodel;
- (void)insertSubmodel:(TGModernViewModel *)model aboveSubmodel:(TGModernViewModel *)aboveSubmodel;
- (void)removeSubmodel:(TGModernViewModel *)model viewStorage:(TGModernViewStorage *)viewStorage;
- (void)layoutForContainerSize:(CGSize)containerSize;

- (void)collectBoundModelViewFramesRecursively:(NSMutableDictionary *)dict;
- (void)collectBoundModelViewFramesRecursively:(NSMutableDictionary *)dict ifPresentInDict:(NSMutableDictionary *)anotherDict;
- (void)restoreBoundModelViewFramesRecursively:(NSMutableDictionary *)dict;

@end
