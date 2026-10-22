#import "TGSimpleImageView.h"

#import <objc/runtime.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/Freedom.h"

@implementation TGSimpleImageView

static void TGSimpleImageViewDidMoveFromWindow(__unused id self, __unused SEL _cmd, __unused id fromWindow, __unused id toWindow)
{
}

static id TGSimpleImageViewTraitCollection(__unused id self, __unused SEL _cmd)
{
    return nil;
}

static void TGSimpleImageViewTraitCollectionDidChange(__unused id self, __unused SEL _cmd, __unused id previousTraitCollection)
{
}

+ (void)load
{
    @autoreleasepool
    {
        if (iosMajorVersion() >= 13)
            return;
        
        FreedomDecoration instanceDecorations[] =
        {
            { .name = 0xb286f41U,
                .imp = (IMP)&TGSimpleImageViewDidMoveFromWindow,
                .newIdentifier = FreedomIdentifierEmpty,
                .newEncoding = FreedomIdentifierEmpty
            }
        };
    
        freedomClassAutoDecorateExplicit([self class], 0, NULL, 0, instanceDecorations, sizeof(instanceDecorations) / sizeof(instanceDecorations[0]));
        
        if (iosMajorVersion() >= 8)
        {
            class_addMethod(self, @selector(traitCollection), (IMP)&TGSimpleImageViewTraitCollection, "@@:");
            class_addMethod(self, @selector(traitCollectionDidChange:), (IMP)&TGSimpleImageViewTraitCollectionDidChange, "v@:@");
        }
    }
}

@end
