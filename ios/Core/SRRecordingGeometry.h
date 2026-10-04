#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 * The video's size in pixels for a view of `viewSize` points: `width` wide (made even, at least 2) and as tall as the
 * view's proportions make it, rounded to an even number, as H.264 needs.
 */
CGSize SRVideoSize(NSInteger width, CGSize viewSize);

/**
 * The part of a view of `viewSize` points that's recorded into a video of `videoSize` pixels: all of it, trimmed
 * evenly on two sides to the video's proportions, which rounding can make slightly different from the view's.
 */
CGRect SRSourceRect(CGSize viewSize, CGSize videoSize);

/** Whether a frame is due `time` seconds into the recording, the last one having been added at `lastFrameTime`. */
BOOL SRFrameDue(double time, double lastFrameTime, double frameInterval);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
