#import "PGPhotoHistogramGenerator.h"
#import "PGPhotoHistogram.h"

@implementation PGPhotoHistogramGenerator

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        __weak PGPhotoHistogramGenerator *weakSelf = self;
        
        self.newFrameAvailableBlock = ^
        {
            __strong PGPhotoHistogramGenerator *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            NSUInteger lumHist[256];
            NSUInteger redHist[256];
            NSUInteger greenHist[256];
            NSUInteger blueHist[256];
            
            memset(lumHist, 0, 256 * sizeof(NSUInteger));
            memset(redHist, 0, 256 * sizeof(NSUInteger));
            memset(greenHist, 0, 256 * sizeof(NSUInteger));
            memset(blueHist, 0, 256 * sizeof(NSUInteger));
            
            NSInteger width = (NSInteger)strongSelf.imageSize.width;
            NSInteger height = (NSInteger)strongSelf.imageSize.height;
            PGByteColorVector *pixels = (PGByteColorVector *)strongSelf.rawBytesForImage;
            if (pixels == NULL)
                return;
            bool swapRedBlue = [GPUImageContext supportsFastTextureUpload];
            
            for (NSInteger y = 0; y < height; y++)
            {
                NSInteger offset = width * y;
                
                for (NSInteger x = 0; x < width; x++)
                {
                    PGByteColorVector color = pixels[offset + x];
                    if (swapRedBlue)
                    {
                        GLubyte tmp = color.red;
                        color.red = color.blue;
                        color.blue = tmp;
                    }
                    NSInteger luma = (NSInteger)(color.red * 0.3 + color.green * 0.59 + color.blue * 0.11);
                    lumHist[luma]++;
                    redHist[color.red]++;
                    greenHist[color.green]++;
                    blueHist[color.blue]++;
                }
            }
            
            if (strongSelf.histogramReady != nil)
                strongSelf.histogramReady([[PGPhotoHistogram alloc] initWithLuminanceCArray:lumHist redCArray:redHist greenCArray:greenHist blueCArray:blueHist]);
        };
    }
    return self;
}

@end
