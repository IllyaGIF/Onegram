#import "TGModernViewModel.h"

#import "TGModernView.h"

#import <objc/runtime.h>

@interface TGModernViewModelId : NSObject <NSCopying>

@end

@implementation TGModernViewModelId

- (instancetype)copyWithZone:(NSZone *)__unused zone
{
    return self;
}

@end

@interface TGModernViewModel ()
{
    UIView<TGModernView> *_view;
    
    NSString *_viewIdentifier;
    NSMutableArray *_submodels;
}

@end

@interface TGModernDrawingOperation ()
{
@public
    TGModernDrawingFunction _function;
    CGPoint _origin;
    CGRect _rect;
    id _object;
    id _secondaryObject;
    UIColor *_color;
    CGSize _size;
    CGFloat _value;
    int _flags;
}

@end

@implementation TGModernDrawingOperation

@end

static bool TGModernDrawingObjectsEqual(id lhs, id rhs)
{
    if (lhs == rhs)
        return true;
    if (lhs == nil || rhs == nil)
        return false;
    if ([lhs isKindOfClass:[NSString class]])
        return [rhs isKindOfClass:[NSString class]] && [(NSString *)lhs isEqualToString:(NSString *)rhs];
    if ([lhs isKindOfClass:[UIColor class]])
        return [rhs isKindOfClass:[UIColor class]] && [lhs isEqual:rhs];
    if ([lhs isKindOfClass:[UIFont class]])
        return [rhs isKindOfClass:[UIFont class]] && [lhs isEqual:rhs];
    if ([lhs isKindOfClass:[NSArray class]])
    {
        if (![rhs isKindOfClass:[NSArray class]])
            return false;
        NSArray *lhsArray = lhs;
        NSArray *rhsArray = rhs;
        NSUInteger count = lhsArray.count;
        if (count != rhsArray.count)
            return false;
        for (NSUInteger index = 0; index < count; index++)
        {
            if (!TGModernDrawingObjectsEqual(lhsArray[index], rhsArray[index]))
                return false;
        }
        return true;
    }
    return false;
}

@interface TGModernDrawingRecording ()
{
    NSMutableArray *_operations;
    CGPoint _offset;
}

@end

@implementation TGModernDrawingRecording

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _operations = [[NSMutableArray alloc] initWithCapacity:8];
    }
    return self;
}

- (void)pushOffset:(CGPoint)offset
{
    _offset.x += offset.x;
    _offset.y += offset.y;
}

- (void)popOffset:(CGPoint)offset
{
    _offset.x -= offset.x;
    _offset.y -= offset.y;
}

- (void)addOperationWithFunction:(TGModernDrawingFunction)function rect:(CGRect)rect object:(id)object secondaryObject:(id)secondaryObject color:(UIColor *)color size:(CGSize)size value:(CGFloat)value flags:(int)flags
{
    TGModernDrawingOperation *operation = [[TGModernDrawingOperation alloc] init];
    operation->_function = function;
    operation->_origin = _offset;
    operation->_rect = rect;
    operation->_object = object;
    operation->_secondaryObject = secondaryObject;
    operation->_color = color;
    operation->_size = size;
    operation->_value = value;
    operation->_flags = flags;
    [_operations addObject:operation];
}

- (bool)isEqualToRecording:(TGModernDrawingRecording *)other
{
    if (other == self)
        return true;
    if (other == nil)
        return false;
    NSUInteger count = _operations.count;
    if (count != other->_operations.count)
        return false;
    for (NSUInteger index = 0; index < count; index++)
    {
        TGModernDrawingOperation *lhs = _operations[index];
        TGModernDrawingOperation *rhs = other->_operations[index];
        if (lhs->_function != rhs->_function || lhs->_flags != rhs->_flags || lhs->_value != rhs->_value)
            return false;
        if (!CGPointEqualToPoint(lhs->_origin, rhs->_origin) || !CGRectEqualToRect(lhs->_rect, rhs->_rect) || !CGSizeEqualToSize(lhs->_size, rhs->_size))
            return false;
        if (!TGModernDrawingObjectsEqual(lhs->_object, rhs->_object) || !TGModernDrawingObjectsEqual(lhs->_secondaryObject, rhs->_secondaryObject) || !TGModernDrawingObjectsEqual(lhs->_color, rhs->_color))
            return false;
    }
    return true;
}

- (void)drawInContext:(CGContextRef)context
{
    for (TGModernDrawingOperation *operation in _operations)
    {
        CGPoint origin = operation->_origin;
        CGContextTranslateCTM(context, origin.x, origin.y);
        operation->_function(context, operation);
        CGContextTranslateCTM(context, -origin.x, -origin.y);
    }
}

@end

#if defined(ONEGRAM_DIAGNOSTICS)
static Class TGModernDrawingRecordingFailedClass = Nil;

Class TGModernDrawingRecordingTakeFailedClass(void)
{
    Class result = TGModernDrawingRecordingFailedClass;
    TGModernDrawingRecordingFailedClass = Nil;
    return result;
}

typedef struct
{
    const void *key;
    bool isPhase;
    CFAbsoluteTime inclusive;
    CFAbsoluteTime children;
    int count;
} TGModernViewModelBindTraceEntry;

enum { TGModernViewModelBindTraceCapacity = 48 };
static TGModernViewModelBindTraceEntry TGModernViewModelBindTraceEntries[TGModernViewModelBindTraceCapacity];
static int TGModernViewModelBindTraceEntryCount = 0;
static int TGModernViewModelBindTraceDepth = 0;

static TGModernViewModelBindTraceEntry *TGModernViewModelBindTraceEntryFor(const void *key, bool isPhase)
{
    for (int index = 0; index < TGModernViewModelBindTraceEntryCount; index++)
    {
        if (TGModernViewModelBindTraceEntries[index].key == key && TGModernViewModelBindTraceEntries[index].isPhase == isPhase)
            return &TGModernViewModelBindTraceEntries[index];
    }
    if (TGModernViewModelBindTraceEntryCount >= TGModernViewModelBindTraceCapacity)
        return NULL;
    TGModernViewModelBindTraceEntry *entry = &TGModernViewModelBindTraceEntries[TGModernViewModelBindTraceEntryCount++];
    memset(entry, 0, sizeof(TGModernViewModelBindTraceEntry));
    entry->key = key;
    entry->isPhase = isPhase;
    return entry;
}

bool TGModernViewModelBindTraceActive(void)
{
    return TGModernViewModelBindTraceDepth > 0 && [NSThread isMainThread];
}

void TGModernViewModelBindTraceBegin(void)
{
    if (TGModernViewModelBindTraceDepth == 0)
        TGModernViewModelBindTraceEntryCount = 0;
    TGModernViewModelBindTraceDepth++;
}

void TGModernViewModelBindTraceAddPhase(const char *phase, CFAbsoluteTime duration)
{
    if (!TGModernViewModelBindTraceActive())
        return;
    TGModernViewModelBindTraceEntry *entry = TGModernViewModelBindTraceEntryFor(phase, true);
    if (entry == NULL)
        return;
    entry->inclusive += duration;
    entry->count++;
}

static void TGModernViewModelBindTraceAddModel(Class modelClass, Class parentClass, CFAbsoluteTime duration)
{
    if (!TGModernViewModelBindTraceActive())
        return;
    TGModernViewModelBindTraceEntry *entry = TGModernViewModelBindTraceEntryFor((__bridge const void *)modelClass, false);
    if (entry != NULL)
    {
        entry->inclusive += duration;
        entry->count++;
    }
    TGModernViewModelBindTraceEntry *parentEntry = TGModernViewModelBindTraceEntryFor((__bridge const void *)parentClass, false);
    if (parentEntry != NULL)
        parentEntry->children += duration;
}

NSString *TGModernViewModelBindTraceEnd(Class rootClass, CFAbsoluteTime rootDuration)
{
    if (TGModernViewModelBindTraceDepth > 0)
        TGModernViewModelBindTraceDepth--;
    if (TGModernViewModelBindTraceDepth != 0)
        return nil;
    
    if (rootClass != Nil)
    {
        TGModernViewModelBindTraceEntry *rootEntry = TGModernViewModelBindTraceEntryFor((__bridge const void *)rootClass, false);
        if (rootEntry != NULL)
        {
            rootEntry->inclusive += rootDuration;
            rootEntry->count++;
        }
    }
    
    int order[TGModernViewModelBindTraceCapacity];
    double values[TGModernViewModelBindTraceCapacity];
    int count = TGModernViewModelBindTraceEntryCount;
    for (int index = 0; index < count; index++)
    {
        TGModernViewModelBindTraceEntry *entry = &TGModernViewModelBindTraceEntries[index];
        order[index] = index;
        values[index] = entry->isPhase ? entry->inclusive : (entry->inclusive - entry->children);
    }
    for (int i = 1; i < count; i++)
    {
        int current = order[i];
        int j = i - 1;
        while (j >= 0 && values[order[j]] < values[current])
        {
            order[j + 1] = order[j];
            j--;
        }
        order[j + 1] = current;
    }
    
    NSMutableString *result = [[NSMutableString alloc] init];
    int printed = 0;
    for (int i = 0; i < count && printed < 8; i++)
    {
        TGModernViewModelBindTraceEntry *entry = &TGModernViewModelBindTraceEntries[order[i]];
        double value = values[order[i]] * 1000.0;
        if (value < 0.5)
            break;
        const char *name = entry->isPhase ? (const char *)entry->key : class_getName((__bridge Class)entry->key);
        [result appendFormat:@"%s%s=%.1f/%d", printed == 0 ? "" : " ", name, value, entry->count];
        printed++;
    }
    TGModernViewModelBindTraceEntryCount = 0;
    return result;
}
#endif

static char TGModernViewModelGestureRecognizerInUseKey;

id TGModernViewModelAcquireGestureRecognizer(UIView *view, const void *poolKey, Class recognizerClass, id target, SEL action)
{
    if (view == nil)
        return nil;
    
    UIGestureRecognizer *pooledRecognizer = objc_getAssociatedObject(view, poolKey);
    if (pooledRecognizer != nil && objc_getAssociatedObject(pooledRecognizer, &TGModernViewModelGestureRecognizerInUseKey) == nil)
    {
        if (pooledRecognizer.view == view && [pooledRecognizer class] == recognizerClass && pooledRecognizer.state == UIGestureRecognizerStatePossible)
        {
            [pooledRecognizer addTarget:target action:action];
            pooledRecognizer.enabled = true;
            objc_setAssociatedObject(pooledRecognizer, &TGModernViewModelGestureRecognizerInUseKey, (__bridge id)kCFBooleanTrue, OBJC_ASSOCIATION_ASSIGN);
            return pooledRecognizer;
        }
        
        if (pooledRecognizer.view == view)
            [view removeGestureRecognizer:pooledRecognizer];
        objc_setAssociatedObject(view, poolKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        pooledRecognizer = nil;
    }
    
    UIGestureRecognizer *recognizer = [[recognizerClass alloc] initWithTarget:target action:action];
    objc_setAssociatedObject(recognizer, &TGModernViewModelGestureRecognizerInUseKey, (__bridge id)kCFBooleanTrue, OBJC_ASSOCIATION_ASSIGN);
    if (pooledRecognizer == nil)
        objc_setAssociatedObject(view, poolKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [view addGestureRecognizer:recognizer];
    return recognizer;
}

void TGModernViewModelRelinquishGestureRecognizer(UIGestureRecognizer *recognizer, const void *poolKey, id target, SEL action)
{
    if (recognizer == nil)
        return;
    
    [recognizer removeTarget:target action:action];
    recognizer.delegate = nil;
    objc_setAssociatedObject(recognizer, &TGModernViewModelGestureRecognizerInUseKey, nil, OBJC_ASSOCIATION_ASSIGN);
    
    UIView *view = recognizer.view;
    if (view != nil && objc_getAssociatedObject(view, poolKey) == recognizer)
        recognizer.enabled = false;
    else
        [view removeGestureRecognizer:recognizer];
}

static NSString *TGModernViewModelIdentifierForViewClass(Class viewClass)
{
    if (viewClass == Nil)
        return nil;
    static CFMutableDictionaryRef identifiers = NULL;
    if (identifiers == NULL)
        identifiers = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    NSString *identifier = (__bridge NSString *)CFDictionaryGetValue(identifiers, (__bridge const void *)viewClass);
    if (identifier == nil)
    {
        identifier = NSStringFromClass(viewClass);
        if (identifier != nil)
            CFDictionarySetValue(identifiers, (__bridge const void *)viewClass, (__bridge const void *)identifier);
    }
    return identifier;
}

@implementation TGModernViewModel

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _alpha = 1.0f;
        _modelId = [[TGModernViewModelId alloc] init];
    }
    return self;
}

- (bool)hasNoView
{
    return _modelFlags.hasNoView;
}

- (void)setHasNoView:(bool)hasNoView
{
    _modelFlags.hasNoView = hasNoView;
}

- (bool)skipDrawInContext
{
    return _modelFlags.skipDrawInContext;
}

- (void)setSkipDrawInContext:(bool)skipDrawInContext
{
    _modelFlags.skipDrawInContext = skipDrawInContext;
}

- (bool)disableSubmodelAutomaticBinding
{
    return _modelFlags.disableSubmodelAutomaticBinding;
}

- (void)setDisableSubmodelAutomaticBinding:(bool)disableSubmodelAutomaticBinding
{
    _modelFlags.disableSubmodelAutomaticBinding = disableSubmodelAutomaticBinding;
}

- (bool)viewUserInteractionDisabled
{
    return _modelFlags.viewUserInteractionDisabled;
}

- (void)setViewUserInteractionDisabled:(bool)viewUserInteractionDisabled
{
    if (_modelFlags.viewUserInteractionDisabled != viewUserInteractionDisabled)
    {
        _modelFlags.viewUserInteractionDisabled = viewUserInteractionDisabled;
        _view.userInteractionEnabled = !viewUserInteractionDisabled;
    }
}

- (Class)viewClass
{
    return nil;
}

- (UIView<TGModernView> *)_dequeueView:(TGModernViewStorage *)viewStorage
{
    return [self _dequeueView:viewStorage preferredSuperview:nil];
}

- (UIView<TGModernView> *)_dequeueView:(TGModernViewStorage *)viewStorage preferredSuperview:(UIView *)preferredSuperview
{
    if (_viewIdentifier == nil)
        _viewIdentifier = TGModernViewModelIdentifierForViewClass([self viewClass]);
    
    UIView<TGModernView> *view = [viewStorage dequeueViewWithIdentifier:_viewIdentifier viewStateIdentifier:_viewStateIdentifier preferredSuperview:preferredSuperview];
    if (view == nil)
    {
        view = [[[self viewClass] alloc] init];
        [view setViewIdentifier:_viewIdentifier];
    }
    
    return view;
}

- (UIView<TGModernView> *)boundView
{
    return _view;
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
#if defined(ONEGRAM_DIAGNOSTICS)
    bool trace = TGModernViewModelBindTraceActive();
    CFAbsoluteTime traceTime = trace ? CFAbsoluteTimeGetCurrent() : 0.0;
#endif
    if (!_modelFlags.hasNoView)
        _view = [self _dequeueView:viewStorage preferredSuperview:container];
#if defined(ONEGRAM_DIAGNOSTICS)
    if (trace)
    {
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        TGModernViewModelBindTraceAddPhase("dequeue", now - traceTime);
        traceTime = now;
    }
#endif
    
    if (_view != nil || _modelFlags.hasNoView)
    {
        if (!_modelFlags.hasNoView)
        {
#if defined(ONEGRAM_DIAGNOSTICS)
            const char *attachPhase = _view.superview == container ? "attach.inplace" : (_view.superview == nil ? "attach.new" : "attach.moved");
#endif
            if (_view.superview == container)
                [container bringSubviewToFront:_view];
            else
                [container addSubview:_view];
#if defined(ONEGRAM_DIAGNOSTICS)
            if (trace)
            {
                CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
                TGModernViewModelBindTraceAddPhase(attachPhase, now - traceTime);
                traceTime = now;
            }
#endif
            
            if (isnan(_frame.origin.x))
                _frame.origin.x = 0;
            if (isnan(_frame.origin.y))
                _frame.origin.y = 0;
            
            [_view setFrame:CGRectOffset(_frame, _parentOffset.x, _parentOffset.y)];
            [_view setAlpha:_alpha];
            [_view setHidden:_hidden];
            
            _view.userInteractionEnabled = !_modelFlags.viewUserInteractionDisabled;
#if defined(ONEGRAM_DIAGNOSTICS)
            if (trace)
                TGModernViewModelBindTraceAddPhase("geometry", CFAbsoluteTimeGetCurrent() - traceTime);
#endif
        }

        bool disableSubmodelAutomaticBinding = _modelFlags.disableSubmodelAutomaticBinding;
        
        for (TGModernViewModel *submodel in self.submodels)
        {
            if (!disableSubmodelAutomaticBinding || submodel.skipDrawInContext)
            {
#if defined(ONEGRAM_DIAGNOSTICS)
                CFAbsoluteTime submodelStartTime = trace ? CFAbsoluteTimeGetCurrent() : 0.0;
#endif
                [submodel bindViewToContainer:_modelFlags.hasNoView ? container : _view viewStorage:viewStorage];
#if defined(ONEGRAM_DIAGNOSTICS)
                if (trace)
                    TGModernViewModelBindTraceAddModel([submodel class], [self class], CFAbsoluteTimeGetCurrent() - submodelStartTime);
#endif
            }
        }
    }
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    if (_unbindAction)
        _unbindAction();
    
    for (TGModernViewModel *submodel in self.submodels)
    {
        [submodel unbindView:viewStorage];
    }
    
    if (_view != nil)
    {
        if (viewStorage != nil)
            [viewStorage parkView:_view];
        else
            [_view removeFromSuperview];
        _view = nil;
    }
}

- (void)moveViewToContainer:(UIView *)container
{
    if (!_modelFlags.hasNoView)
    {
        if (_view != nil)
            [container addSubview:_view];
    }
    else
    {
        bool disableSubmodelAutomaticBinding = _modelFlags.disableSubmodelAutomaticBinding;
        
        for (TGModernViewModel *submodel in self.submodels)
        {
            if (!disableSubmodelAutomaticBinding || submodel.skipDrawInContext)
                [submodel moveViewToContainer:container];
        }
    }
}

- (void)_offsetBoundViews:(CGSize)offset
{
    if (!_modelFlags.hasNoView)
    {
        if (_view != nil)
            _view.frame = CGRectOffset(_view.frame, offset.width, offset.height);
    }
    else
    {
        bool disableSubmodelAutomaticBinding = _modelFlags.disableSubmodelAutomaticBinding;
        
        for (TGModernViewModel *submodel in self.submodels)
        {
            if (!disableSubmodelAutomaticBinding || submodel.skipDrawInContext)
                [submodel _offsetBoundViews:offset];
        }
    }
}

- (void)setFrame:(CGRect)frame
{
    _frame = frame;
    
    if (_view != nil)
        [_view setFrame:CGRectOffset(_frame, _parentOffset.x, _parentOffset.y)];
}

- (void)setParentOffset:(CGPoint)parentOffset
{
    _parentOffset = parentOffset;
}

- (void)setAlpha:(float)alpha
{
    _alpha = alpha;
    
    if (_view != nil)
        [_view setAlpha:alpha];
}

- (void)setHidden:(bool)hidden
{
    _hidden = hidden;
    
    if (_view != nil)
        [_view setHidden:hidden];
}

- (void)drawInContext:(CGContextRef)context
{
    if (_modelFlags.skipDrawInContext || _hidden || _alpha < FLT_EPSILON)
        return;
    
    [self drawSubmodelsInContext:context];
}

- (void)drawSubmodelsInContext:(CGContextRef)context
{
    for (TGModernViewModel *submodel in self.submodels)
    {
        CGRect frame = submodel.frame;
        CGContextTranslateCTM(context, frame.origin.x, frame.origin.y);
        [submodel drawInContext:context];
        CGContextTranslateCTM(context, -frame.origin.x, -frame.origin.y);
    }
}

- (bool)drawsInContextWithImplementationOfClass:(Class)implementingClass
{
    static IMP baseDrawSubmodelsImplementation = NULL;
    if (baseDrawSubmodelsImplementation == NULL)
        baseDrawSubmodelsImplementation = [TGModernViewModel instanceMethodForSelector:@selector(drawSubmodelsInContext:)];
    if ([self methodForSelector:@selector(drawSubmodelsInContext:)] != baseDrawSubmodelsImplementation)
        return false;
    return [self methodForSelector:@selector(drawInContext:)] == [implementingClass instanceMethodForSelector:@selector(drawInContext:)];
}

- (bool)recordDrawing:(TGModernDrawingRecording *)recording
{
    if (![self drawsInContextWithImplementationOfClass:[TGModernViewModel class]])
        return false;
    return [self recordBaseDrawing:recording];
}

- (bool)recordBaseDrawing:(TGModernDrawingRecording *)recording
{
    if (_modelFlags.skipDrawInContext || _hidden || _alpha < FLT_EPSILON)
        return true;
    return [self recordSubmodelsDrawing:recording];
}

- (bool)recordSubmodelsDrawing:(TGModernDrawingRecording *)recording
{
    for (TGModernViewModel *submodel in self.submodels)
    {
        CGPoint origin = submodel.frame.origin;
        [recording pushOffset:origin];
        bool recorded = [submodel recordDrawing:recording];
        [recording popOffset:origin];
        if (!recorded)
        {
#if defined(ONEGRAM_DIAGNOSTICS)
            if (TGModernDrawingRecordingFailedClass == Nil)
                TGModernDrawingRecordingFailedClass = [submodel class];
#endif
            return false;
        }
    }
    return true;
}

- (void)sizeToFit
{
}

- (CGRect)bounds
{
    return CGRectMake(0, 0, _frame.size.width, _frame.size.height);
}

- (NSArray *)submodels
{
    return _submodels;
}

- (bool)containsSubmodel:(TGModernViewModel *)model
{
    return _submodels != nil && [_submodels containsObject:model];
}

- (void)addSubmodel:(TGModernViewModel *)model
{
    if (model == nil)
        return;
    
    if (_submodels == nil)
        _submodels = [[NSMutableArray alloc] init];
    
    [_submodels addObject:model];
}

- (void)insertSubmodel:(TGModernViewModel *)model belowSubmodel:(TGModernViewModel *)belowSubmodel {
    if (model == nil)
        return;
    
    if (_submodels == nil)
        _submodels = [[NSMutableArray alloc] init];
    
    NSUInteger index = [_submodels indexOfObject:belowSubmodel];
    if (index != NSNotFound)
        [_submodels insertObject:model atIndex:index];
    else
        [_submodels addObject:model];
}

- (void)insertSubmodel:(TGModernViewModel *)model aboveSubmodel:(TGModernViewModel *)aboveSubmodel
{
    if (model == nil)
        return;
    
    if (_submodels == nil)
        _submodels = [[NSMutableArray alloc] init];
    
    NSUInteger index = [_submodels indexOfObject:aboveSubmodel];
    if (index != NSNotFound)
        [_submodels insertObject:model atIndex:index + 1];
    else
        [_submodels addObject:model];
}

- (void)removeSubmodel:(TGModernViewModel *)model viewStorage:(TGModernViewStorage *)viewStorage
{
    if (model == nil)
        return;
    
    if ([_submodels containsObject:model])
    {
        [model unbindView:viewStorage];
        [_submodels removeObject:model];
    }
}

- (void)layoutForContainerSize:(CGSize)__unused containerSize
{
}

- (void)collectBoundModelViewFramesRecursively:(NSMutableDictionary *)dict
{
    if (_modelId != nil && _view != nil)
        dict[_modelId] = [NSValue valueWithCGRect:_view.frame];
    
    for (TGModernViewModel *submodel in _submodels)
    {
        [submodel collectBoundModelViewFramesRecursively:dict];
    }
}

- (void)collectBoundModelViewFramesRecursively:(NSMutableDictionary *)dict ifPresentInDict:(NSMutableDictionary *)anotherDict
{
    if (_modelId != nil && _view != nil && anotherDict[_modelId] != nil)
        dict[_modelId] = [NSValue valueWithCGRect:_view.frame];
    
    for (TGModernViewModel *submodel in _submodels)
    {
        [submodel collectBoundModelViewFramesRecursively:dict];
    }
}

- (void)restoreBoundModelViewFramesRecursively:(NSMutableDictionary *)dict
{
    if (_modelId != nil && _view != nil)
    {
        NSValue *value = dict[_modelId];
        if (value != nil)
            _view.frame = [value CGRectValue];
    }
    
    for (TGModernViewModel *submodel in _submodels)
    {
        [submodel restoreBoundModelViewFramesRecursively:dict];
    }
}

@end
