import { findNodeHandle } from 'react-native';

import NativeScreenRecord from './NativeScreenRecord';

/** A ref to the view to record (as from `useRef`), or its native tag. */
export type RecordTarget =
  number | { current: Parameters<typeof findNodeHandle>[0] };

export type RecordOptions = {
  /** How long to record, in milliseconds. 0 records until `stopRecording()`. Defaults to 5000. */
  durationMs?: number;
  /** The video's width in pixels; the height follows the view's proportions. Defaults to 1080. */
  width?: number;
  /** Frames per second, at most. Defaults to 30. */
  fps?: number;
  /** Average bit rate of the H.264 video, in bits per second. Defaults to 10 Mbit/s. */
  bitRate?: number;
};

const DEFAULTS = {
  durationMs: 5000,
  width: 1080,
  fps: 30,
  bitRate: 10_000_000,
};

/** The tag the native side records the whole window for. */
const WINDOW = -1;

/**
 * Recordings asked for here that haven't finished. The native side starts a recording on the main thread, a moment
 * after it's asked to, and only knows of it from then on.
 */
let pending = 0;

function record(tag: number, options: RecordOptions) {
  const recording = NativeScreenRecord.startRecording(
    tag,
    options.durationMs ?? DEFAULTS.durationMs,
    options.width ?? DEFAULTS.width,
    options.fps ?? DEFAULTS.fps,
    options.bitRate ?? DEFAULTS.bitRate
  );
  pending += 1;
  const finish = () => {
    pending -= 1;
  };
  recording.then(finish, finish);
  return recording;
}

/**
 * Records what a view shows, animations and all, into an H.264 MP4 without sound. Resolves to the URI of a new
 * temporary file once it's written: move it to keep it. The view is recorded as it's drawn on screen, so it must be on
 * screen while recording. One recording at a time.
 *
 * ```tsx
 * const ref = useRef<ComponentRef<typeof View>>(null);
 * const uri = await recordView(ref, { durationMs: 3000 });
 * ```
 */
export function recordView(
  target: RecordTarget,
  options: RecordOptions = {}
): Promise<string> {
  const tag =
    typeof target === 'number' ? target : findNodeHandle(target.current);
  if (tag == null) {
    return Promise.reject(
      new Error('react-native-screen-record: the view to record is not mounted')
    );
  }
  return record(tag, options);
}

/** Records the whole app window, like `recordView` does a view. */
export function recordScreen(options: RecordOptions = {}): Promise<string> {
  return record(WINDOW, options);
}

/** Ends the recording in progress early. Its promise resolves with what was recorded until now. */
export function stopRecording() {
  NativeScreenRecord.stopRecording();
}

/** Whether a recording is in progress, from the moment `recordView` or `recordScreen` is called until it settles. */
export function isRecording(): boolean {
  return pending > 0 || NativeScreenRecord.isRecording();
}
