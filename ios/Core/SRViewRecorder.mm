#import "SRViewRecorder.h"
#import "SRRecordingGeometry.h"

#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const SRErrorDomain = @"ScreenRecord";

static NSError *SRError(NSString *reason)
{
  return [NSError errorWithDomain:SRErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey : reason}];
}

@implementation SRViewRecorder {
  UIView *_view;
  NSURL *_url;
  AVAssetWriter *_writer;
  AVAssetWriterInput *_input;
  AVAssetWriterInputPixelBufferAdaptor *_adaptor;
  size_t _pixelWidth;
  size_t _pixelHeight;
  // The part of the view recorded, in its points: all of it, trimmed to the video's proportions.
  CGRect _source;
  double _duration;
  double _frameInterval;
  CGColorSpaceRef _colorSpace;

  CADisplayLink *_link;
  CFTimeInterval _startTime;
  double _lastFrameTime;
  BOOL _finishing;
  SRViewRecorderCompletion _completion;
}

- (nullable instancetype)initWithView:(UIView *)view
                                  url:(NSURL *)url
                           durationMs:(double)durationMs
                                width:(NSInteger)width
                                  fps:(NSInteger)fps
                              bitRate:(NSInteger)bitRate
                                error:(NSError **)error
{
  if (self = [super init]) {
    CGRect bounds = view.bounds;
    if (bounds.size.width <= 0 || bounds.size.height <= 0) {
      if (error) {
        *error = SRError(@"the view has no size");
      }
      return nil;
    }
    CGSize videoSize = SRVideoSize(width, bounds.size);
    _pixelWidth = (size_t)videoSize.width;
    _pixelHeight = (size_t)videoSize.height;
    _source = SRSourceRect(bounds.size, videoSize);
    _view = view;
    _url = url;
    _duration = durationMs / 1000;
    _frameInterval = 1.0 / MAX(1, fps);
    _lastFrameTime = -INFINITY;
    _colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);

    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    _writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:error];
    if (!_writer) {
      return nil;
    }
    _input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                outputSettings:@{
                                                  AVVideoCodecKey : AVVideoCodecTypeH264,
                                                  AVVideoWidthKey : @(_pixelWidth),
                                                  AVVideoHeightKey : @(_pixelHeight),
                                                  AVVideoColorPropertiesKey : @{
                                                    AVVideoColorPrimariesKey : AVVideoColorPrimaries_ITU_R_709_2,
                                                    AVVideoTransferFunctionKey : AVVideoTransferFunction_ITU_R_709_2,
                                                    AVVideoYCbCrMatrixKey : AVVideoYCbCrMatrix_ITU_R_709_2,
                                                  },
                                                  AVVideoCompressionPropertiesKey : @{
                                                    AVVideoAverageBitRateKey : @(MAX(100000, bitRate)),
                                                    AVVideoProfileLevelKey : AVVideoProfileLevelH264HighAutoLevel,
                                                    AVVideoMaxKeyFrameIntervalKey : @(MAX(1, fps)),
                                                  },
                                                }];
    _input.expectsMediaDataInRealTime = YES;
    _adaptor = [AVAssetWriterInputPixelBufferAdaptor
        assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_input
                                   sourcePixelBufferAttributes:@{
                                     (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                     (id)kCVPixelBufferWidthKey : @(_pixelWidth),
                                     (id)kCVPixelBufferHeightKey : @(_pixelHeight),
                                     (id)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
                                   }];
    if (![_writer canAddInput:_input]) {
      if (error) {
        *error = SRError(@"the video writer refused the settings");
      }
      return nil;
    }
    [_writer addInput:_input];
  }
  return self;
}

- (void)dealloc
{
  CGColorSpaceRelease(_colorSpace);
}

- (void)startWithCompletion:(SRViewRecorderCompletion)completion
{
  if (![_writer startWriting]) {
    completion(nil, _writer.error ?: SRError(@"the video writer didn't start"));
    return;
  }
  [_writer startSessionAtSourceTime:kCMTimeZero];
  _completion = [completion copy];
  float fps = (float)(1 / _frameInterval);
  _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
  _link.preferredFrameRateRange = CAFrameRateRangeMake(MIN(fps, 30), fps, fps);
  [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stop
{
  [self finish];
}

- (void)tick:(CADisplayLink *)link
{
  if (_startTime == 0) {
    _startTime = link.timestamp;
  }
  double time = link.timestamp - _startTime;
  if (_duration > 0 && time >= _duration) {
    [self finish];
    return;
  }
  // The display may refresh faster than the video's frame rate.
  if (!SRFrameDue(time, _lastFrameTime, _frameInterval) || !_input.readyForMoreMediaData) {
    return;
  }
  CVPixelBufferRef buffer = [self drawFrame];
  if (!buffer) {
    return;
  }
  if ([_adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMakeWithSeconds(time, 600)]) {
    _lastFrameTime = time;
  }
  CVPixelBufferRelease(buffer);
}

/** The view as it's on screen now, in a new pixel buffer the caller releases. */
- (nullable CVPixelBufferRef)drawFrame CF_RETURNS_RETAINED
{
  CVPixelBufferPoolRef pool = _adaptor.pixelBufferPool;
  if (!pool) {
    return nil;
  }
  CVPixelBufferRef buffer = NULL;
  if (CVPixelBufferPoolCreatePixelBuffer(NULL, pool, &buffer) != kCVReturnSuccess || !buffer) {
    return nil;
  }
  CVPixelBufferLockBaseAddress(buffer, 0);
  CGContextRef context = CGBitmapContextCreate(
      CVPixelBufferGetBaseAddress(buffer),
      _pixelWidth,
      _pixelHeight,
      8,
      CVPixelBufferGetBytesPerRow(buffer),
      _colorSpace,
      (CGBitmapInfo)kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
  if (context) {
    CGContextSetFillColorWithColor(context, UIColor.blackColor.CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, _pixelWidth, _pixelHeight));
    // UIKit draws from the top left; Core Graphics from the bottom left.
    CGContextTranslateCTM(context, 0, _pixelHeight);
    CGContextScaleCTM(context, 1, -1);
    CGFloat scale = _pixelWidth / _source.size.width;
    CGContextScaleCTM(context, scale, scale);
    CGContextTranslateCTM(context, -_source.origin.x, -_source.origin.y);
    UIGraphicsPushContext(context);
    // Draws what's on screen, GPU-drawn views included. A view that isn't on screen (no window, or one that isn't
    // shown) draws nothing that way, so its layers are rendered instead.
    if (![_view drawViewHierarchyInRect:_view.bounds afterScreenUpdates:NO]) {
      [_view.layer renderInContext:context];
    }
    UIGraphicsPopContext();
    CGContextRelease(context);
  }
  CVPixelBufferUnlockBaseAddress(buffer, 0);
  if (!context) {
    CVPixelBufferRelease(buffer);
    return nil;
  }
  return buffer;
}

- (void)finish
{
  if (_finishing) {
    return;
  }
  _finishing = YES;
  [_link invalidate];
  _link = nil;
  if (_lastFrameTime < 0) {
    // Stopped before the first frame: there's nothing to write.
    [_writer cancelWriting];
    [self complete:nil error:SRError(@"no frames were recorded")];
    return;
  }
  [_input markAsFinished];
  AVAssetWriter *writer = _writer;
  NSURL *url = _url;
  [writer finishWritingWithCompletionHandler:^{
    NSError *error = writer.status == AVAssetWriterStatusCompleted
        ? nil
        : (writer.error ?: SRError(@"the video couldn't be written"));
    dispatch_async(dispatch_get_main_queue(), ^{
      [self complete:error ? nil : url error:error];
    });
  }];
}

- (void)complete:(nullable NSURL *)url error:(nullable NSError *)error
{
  SRViewRecorderCompletion completion = _completion;
  _completion = nil;
  if (completion) {
    completion(url, error);
  }
}

@end
