#import "TGCallBackgroundView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "UIImage+ImageEffects.h"

#import "TGCallSession.h"
#import "TGDatabase.h"
#import "TGMediaSignals.h"

@interface TGCallBackgroundView ()
{
    SMetaDisposable *_disposable;
    TGUser *_user;
    
    bool _big;
    bool _legacyMode;
    
    UIImageView *_transitionView;
    UIView *_dimView;
}
@end

@implementation TGCallBackgroundView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self != nil)
    {
        _legacyMode = iosMajorVersion() <= 7;
        
        self.contentMode = UIViewContentModeScaleAspectFill;
        self.clipsToBounds = true;
        self.userInteractionEnabled = false;
        
        self.backgroundColor = UIColorRGB(0x244f74);
        
        _dimView = [[UIView alloc] initWithFrame:self.bounds];
        
        _dimView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;
        
        _dimView.userInteractionEnabled = false;
        
        if (_legacyMode)
        {
            _dimView.backgroundColor =
            [UIColor colorWithWhite:0.0f alpha:0.52f];
        }
        else
        {
            _dimView.backgroundColor =
            [UIColor colorWithWhite:0.0f alpha:0.4f];
        }
        
        [self addSubview:_dimView];
    }
    
    return self;
}

- (void)setState:(TGCallSessionState *)state
{
    if (_disposable != nil)
        return;
    
    if (_user != nil)
        return;

    TGUser *displayPeer = state.peer;
    if ((displayPeer == nil || displayPeer.uid == 0) && state.stateData.peerId != 0)
        displayPeer = [TGDatabaseInstance() loadUser:(int32_t)state.stateData.peerId];

    if (displayPeer == nil)
        return;

    _user = displayPeer;

    if (iosMajorVersion() == 8)
    {
        [super setImage:nil];
        self.backgroundColor = UIColorRGB(0x244f74);
        _dimView.hidden = false;

        return;
    }

    if (displayPeer.photoUrlSmall.length == 0)
    {
        if (_legacyMode)
        {
            [super setImage:nil];
            
            self.backgroundColor = UIColorRGB(0x244f74);
            
            _dimView.hidden = false;
            
            if (self.imageChanged != nil)
                self.imageChanged(nil);
            
            return;
        }
        
        CGSize screenSize = TGScreenSize();
        
        CGFloat height = screenSize.height;
        
        if (height < 1.0f)
            height = [UIScreen mainScreen].bounds.size.height;
        
        if (height < 1.0f)
            height = 480.0f;
        
        UIGraphicsBeginImageContextWithOptions(
                                               CGSizeMake(8.0f, height),
                                               true,
                                               0.0f
                                               );
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        UIImage *backgroundImage = nil;
        
        if (context != NULL)
        {
            CGColorRef colors[2] =
            {
                UIColorRGB(0x466f92).CGColor,
                UIColorRGB(0x244f74).CGColor
            };
            
            CFArrayRef colorsArray =
            CFArrayCreate(kCFAllocatorDefault,
                          (const void **)colors,
                          2,
                          &kCFTypeArrayCallBacks);
            
            CGFloat locations[2] =
            {
                0.0f,
                1.0f
            };
            
            CGColorSpaceRef colorSpace =
            CGColorSpaceCreateDeviceRGB();
            
            CGGradientRef gradient =
            CGGradientCreateWithColors(colorSpace,
                                       colorsArray,
                                       locations);
            
            if (gradient != NULL)
            {
                CGContextDrawLinearGradient(
                                            context,
                                            gradient,
                                            CGPointMake(0.0f, 0.0f),
                                            CGPointMake(0.0f, height),
                                            0
                                            );
                
                CGGradientRelease(gradient);
            }
            
            CGColorSpaceRelease(colorSpace);
            CFRelease(colorsArray);
            
            backgroundImage =
            UIGraphicsGetImageFromCurrentImageContext();
        }
        
        UIGraphicsEndImageContext();
        
        if (backgroundImage != nil)
        {
            [self setImage:backgroundImage
                       big:true
                     empty:true];
        }
        else
        {
            [super setImage:nil];
            self.backgroundColor = UIColorRGB(0x244f74);
            
            if (self.imageChanged != nil)
                self.imageChanged(nil);
        }
        
        _dimView.hidden = true;
        
        return;
    }
    
    SSignal *smallSignal =
    [[TGMediaSignals avatarPathWithReference:
      [[TGImageFileReference alloc]
       initWithUrl:state.peer.photoFullUrlSmall]]
     map:^UIImage *(NSString *path)
     {
         UIImage *image =
         [UIImage imageWithContentsOfFile:path];
         
         if (_legacyMode)
             return image;
         
         return [image applyBlurWithRadius:4.0f
                                 tintColor:nil
                     saturationDeltaFactor:1.0f
                                 maskImage:nil];
     }];
    
    SSignal *bigSignal =
    [[TGMediaSignals avatarPathWithReference:
      [[TGImageFileReference alloc]
       initWithUrl:displayPeer.photoFullUrlBig]]
     map:^UIImage *(NSString *path)
     {
         return [UIImage imageWithContentsOfFile:path];
     }];
    
    SSignal *signal =
    [SSignal combineSignals:@[smallSignal, bigSignal]
          withInitialStates:@[[NSNull null], [NSNull null]]];
    
    __weak TGCallBackgroundView *weakSelf = self;
    
    _disposable = [[SMetaDisposable alloc] init];
    
    [_disposable setDisposable:
     [[signal deliverOn:[SQueue mainQueue]]
      startWithNext:^(NSArray *next)
      {
          __strong TGCallBackgroundView *strongSelf = weakSelf;
          
          if (strongSelf == nil)
              return;
          
          id firstObject =
          next.count > 0 ? [next objectAtIndex:0] : nil;
          
          id lastObject =
          next.count > 1 ? [next objectAtIndex:1] : nil;
          
          UIImage *smallImage =
          [firstObject isKindOfClass:[NSNull class]]
          ? nil
          : firstObject;
          
          UIImage *bigImage =
          [lastObject isKindOfClass:[NSNull class]]
          ? nil
          : lastObject;
          
          if (bigImage != nil)
          {
              [strongSelf setImage:bigImage
                               big:true
                             empty:false];
          }
          else if (smallImage != nil)
          {
              [strongSelf setImage:smallImage
                               big:false
                             empty:false];
          }
      }]];
}

- (void)setImage:(UIImage *)image big:(bool)big empty:(bool)empty
{
    if (self.image != nil && !_big && big)
    {
        _transitionView =
        [[UIImageView alloc] initWithFrame:self.bounds];
        
        _transitionView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;
        
        _transitionView.contentMode =
        UIViewContentModeScaleAspectFill;
        
        _transitionView.image = self.image;
        
        [self insertSubview:_transitionView
               belowSubview:_dimView];
        
        [UIView animateWithDuration:0.15
                         animations:^
         {
             _transitionView.alpha = 0.0f;
         }
                         completion:^(__unused BOOL finished)
         {
             [_transitionView removeFromSuperview];
             _transitionView = nil;
         }];
    }
    
    if (big && !_big)
        _big = true;
    
    [self setImage:image empty:empty];
}

- (void)setImage:(UIImage *)image empty:(bool)empty
{
    [super setImage:image];
    
    if (image != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        
        _dimView.hidden = false;
    }
    else
    {
        self.backgroundColor = UIColorRGB(0x244f74);
        _dimView.hidden = false;
    }
    
    [self bringSubviewToFront:_dimView];
    
    if (self.imageChanged != nil)
        self.imageChanged(empty ? nil : image);
}

@end