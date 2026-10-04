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

function record(tag: number, options: RecordOptions) {
  return NativeScreenRecord.startRecording(
    tag,
    options.durationMs ?? DEFAULTS.durationMs,
    options.width ?? DEFAULTS.width,
    options.fps ?? DEFAULTS.fps,
    options.bitRate ?? DEFAULTS.bitRate
  );
}

/**
 * Records what a view shows, animations and all, into an H.264 MP4 without sound. Resolves to the file's URI (in the
 * app's cache) once it's written. The view is recorded as it's drawn on screen, so it must be on screen while
 * recording. One recording at a time.
 *
 * ```tsx
 * const ref = useRef<View>(null);
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

export function isRecording(): boolean {
  return NativeScreenRecord.isRecording();
}
