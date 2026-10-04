#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SRViewRecorderCompletion)(NSURL *_Nullable url, NSError *_Nullable error);

/**
 * Records a view into an H.264 MP4: on every screen refresh (at most `fps` times a second), the view's hierarchy is
 * drawn into a pixel buffer, the way a snapshot of it is taken, and appended with the time since the recording started.
 * Drawing the hierarchy includes Metal-backed views (Skia, maps, video), at what they last showed on screen. A view
 * that isn't on screen has its layers rendered instead, which leaves out Metal-backed content.
 */
@interface SRViewRecorder : NSObject

/**
 * @param durationMs How long to record; 0 or less records until `stop`.
 * @param width The video's width in pixels; the height follows the view's proportions.
 */
- (nullable instancetype)initWithView:(UIView *)view
                                  url:(NSURL *)url
                           durationMs:(double)durationMs
                                width:(NSInteger)width
                                  fps:(NSInteger)fps
                              bitRate:(NSInteger)bitRate
                                error:(NSError **)error;

/** Starts recording on the main thread. `completion` gets the file once it's written, on the main thread. */
- (void)startWithCompletion:(SRViewRecorderCompletion)completion;

/** Ends the recording before its duration is up. */
- (void)stop;

@end

NS_ASSUME_NONNULL_END
