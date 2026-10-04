#import "SRRecordingGeometry.h"

#import <math.h>

CGSize SRVideoSize(NSInteger width, CGSize viewSize)
{
  NSInteger pixelWidth = MAX(2, width / 2 * 2);
  if (viewSize.width <= 0 || viewSize.height <= 0) {
    return CGSizeMake(pixelWidth, pixelWidth);
  }
  NSInteger pixelHeight = MAX(2, (NSInteger)lround(pixelWidth * viewSize.height / viewSize.width / 2) * 2);
  return CGSizeMake(pixelWidth, pixelHeight);
}

CGRect SRSourceRect(CGSize viewSize, CGSize videoSize)
{
  CGFloat aspect = videoSize.width / videoSize.height;
  if (viewSize.width / viewSize.height > aspect) {
    CGFloat width = viewSize.height * aspect;
    return CGRectMake((viewSize.width - width) / 2, 0, width, viewSize.height);
  }
  CGFloat height = viewSize.width / aspect;
  return CGRectMake(0, (viewSize.height - height) / 2, viewSize.width, height);
}

BOOL SRFrameDue(double time, double lastFrameTime, double frameInterval)
{
  // A little early is fine: the display's refreshes don't line up exactly with the frame rate.
  return time - lastFrameTime >= frameInterval * 0.9;
}
