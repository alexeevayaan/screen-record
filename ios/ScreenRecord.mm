#import "ScreenRecord.h"
#import "SRViewRecorder.h"

#import <React/RCTBridgeModule.h>

/** The tag JS passes to record the whole window. */
static const NSInteger SRWindowTag = -1;

@implementation ScreenRecord {
  // The recording in progress. One at a time: a second would compete for the main thread.
  SRViewRecorder *_recorder;
}

@synthesize viewRegistry_DEPRECATED = _viewRegistry_DEPRECATED;

// Finding views and drawing them happens on the main thread.
- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (nullable UIView *)windowView
{
  for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
    if (![scene isKindOfClass:UIWindowScene.class]) {
      continue;
    }
    for (UIWindow *window in ((UIWindowScene *)scene).windows) {
      if (window.isKeyWindow) {
        return window;
      }
    }
  }
  return nil;
}

- (void)startRecording:(double)viewTag
            durationMs:(double)durationMs
                 width:(double)width
                   fps:(double)fps
               bitRate:(double)bitRate
               resolve:(RCTPromiseResolveBlock)resolve
                reject:(RCTPromiseRejectBlock)reject
{
  if (_recorder) {
    reject(@"E_BUSY", @"A recording is already in progress", nil);
    return;
  }
  UIView *view = (NSInteger)viewTag == SRWindowTag ? [self windowView]
                                                    : [_viewRegistry_DEPRECATED viewForReactTag:@((NSInteger)viewTag)];
  if (!view) {
    reject(@"E_NO_VIEW", [NSString stringWithFormat:@"No view with tag %ld", (long)viewTag], nil);
    return;
  }
  NSString *name = [NSString stringWithFormat:@"screen-record-%@.mp4", NSUUID.UUID.UUIDString];
  NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
  NSError *error = nil;
  SRViewRecorder *recorder = [[SRViewRecorder alloc] initWithView:view
                                                              url:url
                                                       durationMs:durationMs
                                                            width:(NSInteger)width
                                                              fps:(NSInteger)fps
                                                          bitRate:(NSInteger)bitRate
                                                            error:&error];
  if (!recorder) {
    reject(@"E_RECORDING", error.localizedDescription ?: @"Could not start recording", error);
    return;
  }
  _recorder = recorder;
  __weak ScreenRecord *weakSelf = self;
  [recorder startWithCompletion:^(NSURL *_Nullable result, NSError *_Nullable recordError) {
    ScreenRecord *strongSelf = weakSelf;
    if (strongSelf) {
      strongSelf->_recorder = nil;
    }
    if (result) {
      resolve(result.absoluteString);
    } else {
      reject(@"E_RECORDING", recordError.localizedDescription ?: @"Could not record the video", recordError);
    }
  }];
}

- (void)stopRecording
{
  [_recorder stop];
}

- (NSNumber *)isRecording
{
  return @(_recorder != nil);
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeScreenRecordSpecJSI>(params);
}

+ (NSString *)moduleName
{
  return @"ScreenRecord";
}

@end
